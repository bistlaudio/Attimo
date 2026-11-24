extends RefCounted
## Plan 05-03 (ENRG-01, T-05-08, T-05-09): ArmEnergy is the single owner of the arm energy. The value stays in 0 .. 100 whatever
## is sent (gain past 100, spends below 0, NAN and INF), core_fill maps the value onto the four cores, the silent APIs make no refusal
## fact, and energy_changed is quantised (once per whole-number change, at most once per physics tick).

const Fixtures := preload("res://tests/fixtures.gd")
const SHIPPED_TPS: int = 60

var _bus: Node
var _changed: Array[float] = []
var _refused: Array[StringName] = []
var _on_changed: Callable
var _on_refused: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	Engine.physics_ticks_per_second = SHIPPED_TPS
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 4)
	var arm: ArmEnergy = player.arm_energy
	_changed = []
	_refused = []
	_on_changed = func(value: float) -> void: _changed.append(value)
	_on_refused = func(reason: StringName, _needed: float) -> void: _refused.append(reason)
	_bus.connect(&"energy_changed", _on_changed)
	_bus.connect(&"energy_refused", _on_refused)

	_scenario_core_fill(check, arm)
	_scenario_clamps(check, arm)
	_scenario_non_finite(check, arm)
	await _scenario_quantised(tree, check, arm)
	await _scenario_respawn(tree, check, player)

	_bus.disconnect(&"energy_changed", _on_changed)
	_bus.disconnect(&"energy_refused", _on_refused)
	player.queue_free()
	floor_body.queue_free()
	await player.tree_exited


func _scenario_core_fill(check: Callable, arm: ArmEnergy) -> void:
	var table: Dictionary = {
		0.0: [0.0, 0.0, 0.0, 0.0],
		10.0: [0.4, 0.0, 0.0, 0.0],
		25.0: [1.0, 0.0, 0.0, 0.0],
		50.0: [1.0, 1.0, 0.0, 0.0],
		62.5: [1.0, 1.0, 0.5, 0.0],
		100.0: [1.0, 1.0, 1.0, 1.0],
	}
	for energy: float in table:
		arm.reset_to(energy)
		var expected: Array = table[energy]
		var ok: bool = true
		for i: int in 4:
			ok = ok and is_equal_approx(arm.core_fill(i), float(expected[i]))
		check.call(ok, "(f1) core_fill at %.1f is %s (got %s)" % [energy, expected, [arm.core_fill(0), arm.core_fill(1), arm.core_fill(2), arm.core_fill(3)]])


func _scenario_clamps(check: Callable, arm: ArmEnergy) -> void:
	arm.reset_to(25.0)
	var added: float = arm.gain(200.0, &"test")
	check.call(is_equal_approx(added, 75.0) and is_equal_approx(arm.value, 100.0), "(c1) gain(200) from 25 adds 75 and stops at 100 (added %.2f, value %.2f)" % [added, arm.value])
	arm.reset_to(25.0)
	var taken: float = arm.drain(40.0, &"test")
	check.call(is_equal_approx(taken, 25.0) and is_equal_approx(arm.value, 0.0), "(c2) drain(40) from 25 takes 25 and stops at 0 (taken %.2f, value %.2f)" % [taken, arm.value])
	arm.reset_to(25.0)
	_refused.clear()
	check.call(not arm.try_spend(30.0, &"test") and is_equal_approx(arm.value, 25.0), "(c3) try_spend(30) at 25 fails and leaves 25")
	check.call(_refused.is_empty(), "(c3) a failed try_spend is silent (no energy_refused)")
	check.call(arm.try_spend(25.0, &"test") and is_equal_approx(arm.value, 0.0), "(c4) try_spend(25) at 25 pays everything")
	arm.reset_to(-50.0)
	check.call(arm.value == 0.0, "(c5) reset_to(-50) clamps to 0")
	arm.reset_to(500.0)
	check.call(arm.value == 100.0, "(c5) reset_to(500) clamps to 100")
	check.call(arm.gain(-5.0, &"test") == 0.0 and arm.drain(-5.0, &"test") == 0.0, "(c6) a negative gain or drain changes nothing")


func _scenario_non_finite(check: Callable, arm: ArmEnergy) -> void:
	arm.reset_to(40.0)
	for bad: float in [NAN, INF, -INF]:
		arm.gain(bad, &"test")
		arm.drain(bad, &"test")
		arm.try_spend(bad, &"test")
		arm.reset_to(bad)
		arm.refuse(&"test", bad)
	check.call(is_equal_approx(arm.value, 40.0), "(n1) NAN and INF change nothing (value %.2f)" % arm.value)
	check.call(not arm.can_afford(NAN) and not arm.can_afford(INF), "(n1) a non-finite amount cannot be afforded")
	check.call(_refused.is_empty(), "(n1) refuse ignores a non-finite need")


# energy_changed: once when the whole number changes, once per discrete spend or reset, never twice in one physics tick.
func _scenario_quantised(tree: SceneTree, check: Callable, arm: ArmEnergy) -> void:
	await Fixtures.wait_physics(tree, 2)
	arm.reset_to(10.0)
	await Fixtures.wait_physics(tree, 2)
	_changed.clear()
	arm.gain(0.3, &"test")
	check.call(_changed.is_empty(), "(q1) a gain inside one whole number emits nothing (got %d)" % _changed.size())
	await Fixtures.wait_physics(tree, 2)
	arm.gain(1.0, &"test")
	check.call(_changed.size() == 1, "(q2) a gain over a whole number emits once (got %d)" % _changed.size())
	await Fixtures.wait_physics(tree, 2)
	_changed.clear()
	arm.gain(3.0, &"test")
	arm.drain(1.0, &"test")
	arm.gain(2.0, &"test")
	check.call(_changed.size() == 1, "(q3) several changes in one tick emit once at once (got %d)" % _changed.size())
	await Fixtures.wait_physics(tree, 2)
	check.call(_changed.size() == 2 and is_equal_approx(_changed[1], arm.value), "(q3) the next tick sends the pending change with the final value (got %s, value %.2f)" % [_changed, arm.value])
	_changed.clear()
	await Fixtures.wait_physics(tree, 2)
	arm.reset_to(arm.value)
	check.call(_changed.size() == 1, "(q4) a reset to the same value still emits (a discrete event)")
	await Fixtures.wait_physics(tree, 2)
	# One second of passive charge at 18 m/s is 6 per second: about 6 emits, never one per tick.
	_changed.clear()
	arm.reset_to(0.0)
	await Fixtures.wait_physics(tree, 2)
	_changed.clear()
	for i: int in SHIPPED_TPS:
		arm.tick(1.0 / SHIPPED_TPS, 18.0, &"Run", false)
		await tree.physics_frame
	check.call(_changed.size() >= 5 and _changed.size() <= 8, "(q5) one second of passive charge emits about 6 times, not once per tick (got %d)" % _changed.size())


# The respawn rule: exactly one core, from empty and from full (also through PlayerController.respawn).
func _scenario_respawn(tree: SceneTree, check: Callable, player: PlayerController) -> void:
	var arm: ArmEnergy = player.arm_energy
	arm.reset_to(0.0)
	player.respawn(Vector3(0.0, 0.0, 0.0))
	check.call(is_equal_approx(arm.value, 25.0), "(r1) respawn from 0 gives exactly 25 (got %.2f)" % arm.value)
	arm.reset_to(100.0)
	player.respawn(Vector3(0.0, 0.0, 0.0))
	check.call(is_equal_approx(arm.value, 25.0), "(r1) respawn from 100 gives exactly 25 (got %.2f)" % arm.value)
	await Fixtures.wait_physics(tree, 2)
