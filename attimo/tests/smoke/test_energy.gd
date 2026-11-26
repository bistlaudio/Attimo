extends RefCounted
## Phase 05.1 plan 08 (D-34, D-36, ENRG-06): ArmEnergy is the single owner of the arm energy, a clock of 12 whole steps. The value is an
## int and stays in 0 .. 12 whatever is sent, core_fill maps it onto the four cores of 3 steps, the silent APIs make no refusal fact,
## energy_changed is quantised (at most once per physics tick), respawn gives 3 steps and Moto Perpetuo is on at 6, off below 5.

const Fixtures := preload("res://tests/fixtures.gd")
const SHIPPED_TPS: int = 60

var _bus: Node
var _changed: Array[int] = []
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
	# A huge passive interval keeps the tick out of the exact-value checks (the tick has its own test, test_energy_income).
	player.config = player.config.duplicate() as MovementConfig
	player.config.energy_passive_interval = 100000.0
	_changed = []
	_refused = []
	_on_changed = func(value: int) -> void: _changed.append(value)
	_on_refused = func(reason: StringName, _needed: int) -> void: _refused.append(reason)
	_bus.connect(&"energy_changed", _on_changed)
	_bus.connect(&"energy_refused", _on_refused)
	_moto = []
	_on_moto = func(active: bool) -> void: _moto.append(active)
	_bus.connect(&"moto_changed", _on_moto)

	_scenario_constants(check, arm, player)
	_scenario_core_fill(check, arm)
	_scenario_clamps(check, arm)
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


func _scenario_constants(check: Callable, arm: ArmEnergy, player: PlayerController) -> void:
	check.call(arm.get(&"MAX_STEPS") == 12 and arm.get(&"CORE_STEPS") == 3 and arm.get(&"CHECKPOINT_STEPS") == 3, "(k1) MAX_STEPS 12, CORE_STEPS 3, CHECKPOINT_STEPS 3")
	check.call(typeof(arm.value) == TYPE_INT, "(k2) the energy value is an int (type %d)" % typeof(arm.value))
	var names: Array[String] = []
	for entry: Dictionary in (player.config as Object).get_property_list():
		names.append(String(entry["name"]))
	var gone: Array[String] = ["energy_passive_start_speed", "energy_passive_full_speed", "energy_passive_rate_min", "energy_passive_rate_max", "energy_charge_rate", "wall_run_free_time", "wall_run_cost_per_second"]
	var left: Array[String] = gone.filter(func(n: String) -> bool: return names.has(n))
	check.call(left.is_empty(), "(k3) no float energy rate is left in MovementConfig (found %s)" % [left])
	check.call(player.config.moto_threshold == 6 and player.config.moto_exit_margin == 1, "(k4) the shipped Moto numbers are 6 and 1")


func _scenario_core_fill(check: Callable, arm: ArmEnergy) -> void:
	var table: Dictionary = {
		0: [0.0, 0.0, 0.0, 0.0],
		1: [1.0 / 3.0, 0.0, 0.0, 0.0],
		2: [2.0 / 3.0, 0.0, 0.0, 0.0],
		3: [1.0, 0.0, 0.0, 0.0],
		6: [1.0, 1.0, 0.0, 0.0],
		8: [1.0, 1.0, 2.0 / 3.0, 0.0],
		12: [1.0, 1.0, 1.0, 1.0],
	}
	for energy: int in table:
		arm.reset_to(energy)
		var expected: Array = table[energy]
		var ok: bool = true
		for i: int in 4:
			ok = ok and is_equal_approx(arm.core_fill(i), float(expected[i]))
		check.call(ok, "(f1) core_fill at %d is %s (got %s)" % [energy, expected, [arm.core_fill(0), arm.core_fill(1), arm.core_fill(2), arm.core_fill(3)]])


func _scenario_clamps(check: Callable, arm: ArmEnergy) -> void:
	arm.reset_to(3)
	var added: int = arm.gain(20, &"test")
	check.call(added == 9 and arm.value == 12, "(c1) gain(20) from 3 adds 9 and stops at 12 (added %d, value %d)" % [added, arm.value])
	arm.reset_to(3)
	_refused.clear()
	check.call(not arm.try_spend(4, &"test") and arm.value == 3, "(c3) try_spend(4) at 3 fails and leaves 3 (all or nothing)")
	check.call(_refused.is_empty(), "(c3) a failed try_spend is silent (no energy_refused)")
	check.call(arm.try_spend(3, &"test") and arm.value == 0, "(c4) try_spend(3) at 3 pays everything")
	arm.reset_to(-5)
	check.call(arm.value == 0, "(c5) reset_to(-5) clamps to 0")
	arm.reset_to(50)
	check.call(arm.value == 12, "(c5) reset_to(50) clamps to 12")
	check.call(arm.gain(-5, &"test") == 0 and arm.gain(0, &"test") == 0, "(c6) a negative or zero gain changes nothing")
	check.call(not arm.can_afford(-1), "(c6) a negative cost cannot be afforded")
	arm.reset_to(5)
	arm.refuse(&"test", 1)
	check.call(_refused == [&"test"] and arm.value == 5, "(c7) refuse emits exactly one energy_refused and changes nothing")


# energy_changed: once per change, never twice in one physics tick (the second change is sent by the next tick).
func _scenario_quantised(tree: SceneTree, check: Callable, arm: ArmEnergy) -> void:
	await Fixtures.wait_physics(tree, 2)
	arm.reset_to(4)
	await Fixtures.wait_physics(tree, 2)
	_changed.clear()
	arm.gain(1, &"test")
	check.call(_changed.size() == 1 and _changed[0] == 5, "(q1) a gain emits once with the new value (got %s)" % [_changed])
	await Fixtures.wait_physics(tree, 2)
	_changed.clear()
	arm.gain(3, &"test")
	arm.try_spend(1, &"test")
	arm.gain(2, &"test")
	check.call(_changed.size() == 1, "(q3) several changes in one tick emit once at once (got %d)" % _changed.size())
	await Fixtures.wait_physics(tree, 2)
	check.call(_changed.size() == 2 and _changed[1] == arm.value, "(q3) the next tick sends the pending change with the final value (got %s, value %d)" % [_changed, arm.value])
	_changed.clear()
	await Fixtures.wait_physics(tree, 2)
	arm.reset_to(arm.value)
	check.call(_changed.size() == 1, "(q4) a reset to the same value still emits (a discrete event)")
	await Fixtures.wait_physics(tree, 2)


# The respawn rule: exactly 3 steps, from empty and from full (also through PlayerController.respawn).
func _scenario_respawn(tree: SceneTree, check: Callable, player: PlayerController) -> void:
	var arm: ArmEnergy = player.arm_energy
	arm.reset_to(0)
	player.respawn(Vector3(0.0, 0.0, 0.0))
	check.call(arm.value == 3, "(r1) respawn from 0 gives exactly 3 (got %d)" % arm.value)
	arm.reset_to(12)
	player.respawn(Vector3(0.0, 0.0, 0.0))
	check.call(arm.value == 3, "(r1) respawn from 12 gives exactly 3 (got %d)" % arm.value)
	await Fixtures.wait_physics(tree, 2)


# Moto Perpetuo: on at >= 6, off only below 5, moto_changed only on flips.
func _scenario_moto_hysteresis(check: Callable, arm: ArmEnergy) -> void:
	arm.reset_to(0)
	_moto.clear()
	arm.reset_to(5)
	check.call(not arm.is_moto() and _moto.is_empty(), "(m1) 5 stays off")
	arm.gain(1, &"test")
	check.call(arm.is_moto() and _moto == [true], "(m2) reaching 6 turns Moto on with one moto_changed(true) (got %s)" % [_moto])
	arm.reset_to(5)
	check.call(arm.is_moto() and _moto == [true], "(m3) 5 stays on (hysteresis)")
	arm.reset_to(4)
	check.call(not arm.is_moto() and _moto == [true, false], "(m4) 4 turns off with one moto_changed(false) (got %s)" % [_moto])
	arm.reset_to(6)
	check.call(arm.is_moto(), "(m5) exactly 6 turns on")
	arm.reset_to(0)
	_moto.clear()
	arm.reset_to(5)
	for i: int in 20:
		arm.reset_to(7 if i % 2 == 0 else 5)
	check.call(_moto.size() <= 2, "(m6) oscillating between 5 and 7 flips at most twice (got %d)" % _moto.size())
	arm.reset_to(0)
	check.call(not arm.is_moto(), "(m7) an empty arm is off")
	_moto.clear()
	arm.reset_to(12)
	arm.try_spend(12, &"test")
	check.call(_moto == [true, false], "(m8) a spend through the threshold flips off once (got %s)" % [_moto])


# Moto buffs: ground run target speed, Jump 3 height and the gravity scale restored after the jump.
func _scenario_moto_buffs(tree: SceneTree, check: Callable, player: PlayerController) -> void:
	var arm: ArmEnergy = player.arm_energy
	var config: MovementConfig = player.config
	arm.reset_to(0)
	check.call(is_equal_approx(player.ground_target_speed(Vector3.FORWARD), config.run_speed), "(b1) the run target speed is run_speed without Moto")
	arm.reset_to(8)
	check.call(is_equal_approx(player.ground_target_speed(Vector3.FORWARD), config.run_speed * (1.0 + config.moto_run_bonus)), "(b1) the run target speed is run_speed * (1 + moto_run_bonus) in Moto (got %.3f)" % player.ground_target_speed(Vector3.FORWARD))
	# Jump 3 in Moto: held jump from a standing start reaches moto_jump_height and leaves gravity_scale at 1.0.
	player.teleport(Vector3(0.0, 0.0, 0.0))
	await Fixtures.wait_physics(tree, 6)
	arm.reset_to(8)
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
	# WR-05: a tapped Jump 3 in Moto is never lower than a tapped normal Jump 3 (the cut follows the heavier rise).
	var normal_tap: float = await _tapped_jump_3(tree, player, 0)
	var moto_tap: float = await _tapped_jump_3(tree, player, 8)
	check.call(normal_tap > 0.0 and absf(normal_tap - config.jump_min_height) < 0.15, "(b4) a tapped normal Jump 3 reaches about jump_min_height %.2f (got %.3f)" % [config.jump_min_height, normal_tap])
	check.call(moto_tap >= normal_tap - 0.03, "(b4) a tapped Moto Jump 3 is not lower than a tapped normal Jump 3 (moto %.3f, normal %.3f)" % [moto_tap, normal_tap])



## Apex height of a Jump 3 whose button is released after one tick, at `energy` (8 = Moto on, 0 = off), taken from a run.
func _tapped_jump_3(tree: SceneTree, player: PlayerController, energy: int) -> float:
	player.teleport(Vector3(0.0, 0.0, 0.0))
	await Fixtures.wait_physics(tree, 6)
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 40)
	player.arm_energy.reset_to(energy)
	player.chain_stage = 2
	player.combo_timer = 1.0
	var start_y: float = player.global_position.y
	Fixtures.send_action_event(&"jump", true)
	await tree.physics_frame
	Fixtures.send_action_event(&"jump", false)
	var apex: float = start_y
	for i: int in 120:
		await tree.physics_frame
		apex = maxf(apex, player.global_position.y)
		if player.vertical_speed < -1.0:
			break
	Input.action_release(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return player.is_grounded(), 240)
	return apex - start_y
