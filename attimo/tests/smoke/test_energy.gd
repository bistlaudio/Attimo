extends RefCounted
## Plan 05-03 (ENRG-01, T-05-08, T-05-09): ArmEnergy is the single owner of the arm energy. The value stays in 0 .. 100 whatever
## is sent (gain past 100, spends below 0, NAN and INF), core_fill maps the value onto the four cores, the silent APIs make no refusal
## fact, and energy_changed is quantised (once per whole-number change, at most once per physics tick).

const Fixtures := preload("res://tests/fixtures.gd")
const SHIPPED_TPS: int = 60

var _bus: Node
var _changed: Array[float] = []
var _refused: Array[StringName] = []
var _moto: Array[bool] = []
var _on_changed: Callable
var _on_refused: Callable
var _on_moto: Callable


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
	_moto = []
	_on_moto = func(active: bool) -> void: _moto.append(active)
	_bus.connect(&"moto_changed", _on_moto)

	_scenario_core_fill(check, arm)
	_scenario_clamps(check, arm)
	_scenario_non_finite(check, arm)
	await _scenario_quantised(tree, check, arm)
	await _scenario_respawn(tree, check, player)
	_scenario_moto_hysteresis(check, arm)
	await _scenario_moto_buffs(tree, check, player)

	_bus.disconnect(&"moto_changed", _on_moto)
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


# Moto Perpetuo: on at >= moto_threshold, off only below moto_threshold - moto_exit_margin, moto_changed only on flips.
func _scenario_moto_hysteresis(check: Callable, arm: ArmEnergy) -> void:
	var config: MovementConfig = (arm.get_parent() as PlayerController).config
	check.call(is_equal_approx(config.moto_threshold, 50.0) and is_equal_approx(config.moto_exit_margin, 2.5), "(m0) the shipped Moto numbers are 50 and 2.5")
	arm.reset_to(0.0)
	_moto.clear()
	arm.reset_to(49.9)
	check.call(not arm.is_moto() and _moto.is_empty(), "(m1) 49.9 stays off")
	arm.gain(0.2, &"test")
	check.call(arm.is_moto() and _moto == [true], "(m2) crossing 50 turns Moto on with one moto_changed(true) (got %s)" % [_moto])
	arm.reset_to(47.6)
	check.call(arm.is_moto() and _moto == [true], "(m3) 47.6 stays on (hysteresis)")
	arm.reset_to(47.4)
	check.call(not arm.is_moto() and _moto == [true, false], "(m4) 47.4 turns off with one moto_changed(false) (got %s)" % [_moto])
	arm.reset_to(50.0)
	check.call(arm.is_moto(), "(m5) exactly 50.0 turns on")
	arm.reset_to(0.0)
	_moto.clear()
	arm.reset_to(49.0)
	for i: int in 20:
		arm.reset_to(51.0 if i % 2 == 0 else 49.0)
	check.call(_moto.size() <= 2, "(m6) oscillating between 49 and 51 flips at most twice (got %d)" % _moto.size())
	arm.reset_to(0.0)
	check.call(not arm.is_moto(), "(m7) an empty arm is off")
	_moto.clear()
	arm.reset_to(100.0)
	arm.drain(100.0, &"test")
	check.call(_moto == [true, false], "(m8) a drain through the threshold flips off once (got %s)" % [_moto])


# Moto buffs: ground run target speed, Jump 3 height and the gravity scale restored after the jump.
func _scenario_moto_buffs(tree: SceneTree, check: Callable, player: PlayerController) -> void:
	var arm: ArmEnergy = player.arm_energy
	var config: MovementConfig = player.config
	arm.reset_to(0.0)
	check.call(is_equal_approx(player.ground_target_speed(Vector3.FORWARD), config.run_speed), "(b1) the run target speed is run_speed without Moto")
	arm.reset_to(60.0)
	check.call(is_equal_approx(player.ground_target_speed(Vector3.FORWARD), config.run_speed * (1.0 + config.moto_run_bonus)), "(b1) the run target speed is run_speed * (1 + moto_run_bonus) in Moto (got %.3f)" % player.ground_target_speed(Vector3.FORWARD))
	# Jump 3 in Moto: held jump from a standing start reaches moto_jump_height and leaves gravity_scale at 1.0.
	player.teleport(Vector3(0.0, 0.0, 0.0))
	await Fixtures.wait_physics(tree, 6)
	arm.reset_to(60.0)
	# Standing still resets the chain, so the buffed Jump 3 is taken from a run.
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 40)
	player.chain_stage = 2
	player.combo_timer = 1.0
	var start_y: float = player.global_position.y
	Fixtures.send_action_event(&"jump", true)
	var apex: float = start_y
	var saw_scale: bool = false
	for i: int in 120:
		await tree.physics_frame
		apex = maxf(apex, player.global_position.y)
		if player.state_machine.current.name == &"Jump" and is_equal_approx(player.gravity_scale, config.moto_jump_gravity_scale):
			saw_scale = true
		if player.vertical_speed < -1.0:
			break
	Fixtures.send_action_event(&"jump", false)
	Input.action_release(&"move_forward")
	check.call(saw_scale, "(b2) Jump 3 in Moto runs with moto_jump_gravity_scale")
	check.call(absf((apex - start_y) - config.moto_jump_height) < 0.15, "(b2) Jump 3 in Moto reaches moto_jump_height %.2f (got %.3f)" % [config.moto_jump_height, apex - start_y])
	await Fixtures.wait_until(tree, func() -> bool: return player.is_grounded(), 240)
	check.call(player.gravity_scale == 1.0, "(b3) gravity_scale is 1.0 after the Moto jump (got %.3f)" % player.gravity_scale)
