extends RefCounted
## Phase 05.1 plan 08 (ENRG-07, D-37 to D-40): every ability pays whole steps and an unpaid one never fires. Dash and air dash cost 1,
## the dash hop stages 2 and 3 cost +1 each and silently fall back to stage 1, a wall run costs 2 on entry then 1 every 1 s (an unpaid
## tick drops into Fall without a refusal), a wall jump costs 1. An unpaid dash, air dash, wall-run start or wall jump emits exactly one
## energy_refused per attempt (wall-run start once per wall contact; a wall jump consumes the buffered press).

const Fixtures := preload("res://tests/fixtures.gd")
const SHIPPED_TPS: int = 60
const RUN_PAD: String = "res://scenes/kit/steampunk/wall_pad.tscn"
const JUMP_PAD: String = "res://scenes/kit/steampunk/wall_jump_pad.tscn"

var _bus: Node
var _floor: StaticBody3D
var _blocked: Array[StringName] = []
var _refused: Array[Dictionary] = []
var _spent: Array[Dictionary] = []
var _on_blocked: Callable
var _on_refused: Callable
var _on_spent: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_ground_dash(tree, check)
	await _scenario_air_dash(tree, check)
	await _scenario_hop_costs(tree, check)
	await _scenario_wall_run_entry(tree, check)
	await _scenario_wall_run_tick(tree, check)
	await _scenario_wall_jump(tree, check)


func _begin(tree: SceneTree, position: Vector3 = Vector3.ZERO) -> PlayerController:
	_blocked = []
	_refused = []
	_spent = []
	_on_blocked = func(_position: Vector3, reason: StringName) -> void: _blocked.append(reason)
	_on_refused = func(reason: StringName, needed: int) -> void: _refused.append({"reason": reason, "needed": needed})
	_on_spent = func(amount: int, reason: StringName) -> void: _spent.append({"amount": amount, "reason": reason})
	_bus.connect(&"dash_blocked", _on_blocked)
	_bus.connect(&"energy_refused", _on_refused)
	_bus.connect(&"energy_spent", _on_spent)
	_floor = Fixtures.spawn_floor(tree.root, Vector3(60.0, 1.0, 120.0))
	var player: PlayerController = Fixtures.spawn_player(tree.root, position)
	# A private config with the passive tick out of reach: the exact counts below never see a timed step.
	player.config = player.config.duplicate() as MovementConfig
	player.config.energy_passive_interval = 100000.0
	await Fixtures.wait_physics(tree, 8)
	return player


func _end(player: PlayerController, extra: Array = []) -> void:
	for action: StringName in [&"move_forward", &"jump", &"dash", &"loader", &"charge"]:
		Fixtures.send_action_event(action, false)
		Input.action_release(action)
	_bus.disconnect(&"dash_blocked", _on_blocked)
	_bus.disconnect(&"energy_refused", _on_refused)
	_bus.disconnect(&"energy_spent", _on_spent)
	for node: Variant in extra:
		if is_instance_valid(node):
			(node as Node).queue_free()
	player.queue_free()
	_floor.queue_free()
	await player.tree_exited


## Lifts the player into the air (a jump) so an air dash press is possible.
func _into_air(tree: SceneTree, player: PlayerController) -> void:
	Fixtures.send_action_event(&"jump", true)
	await Fixtures.wait_until(tree, func() -> bool: return not player.is_grounded() and player.vertical_speed > 0.0, 10)
	Fixtures.send_action_event(&"jump", false)


func _spends(reason: StringName) -> Array[Dictionary]:
	return _spent.filter(func(entry: Dictionary) -> bool: return entry["reason"] == reason)


func _refusals(reason: StringName) -> Array[Dictionary]:
	return _refused.filter(func(entry: Dictionary) -> bool: return entry["reason"] == reason)


# Ground dash: 1 step paid leaves 0; at 0 the dash does not start and exactly one refusal comes.
func _scenario_ground_dash(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	check.call(player.config.dash_cost == 1 and player.config.air_dash_cost == 1 and player.config.long_jump_cost == 1, "(g0) dash, air dash and hop stage costs are 1 step")
	Fixtures.set_energy(player, 1)
	await Fixtures.tap_action(tree, &"dash")
	var dashing: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 4)
	check.call(dashing >= 0 and player.arm_energy.value == 0, "(g1) a ground dash at 1 step fires and leaves 0 (value %d)" % player.arm_energy.value)
	check.call(_spends(&"dash").size() == 1 and _spends(&"dash")[0]["amount"] == 1, "(g1) one energy_spent(1, dash) (got %s)" % [_spent])
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name != &"Dash", 30)
	await Fixtures.wait_physics(tree, 30)
	_refused.clear()
	Fixtures.set_energy(player, 0)
	await Fixtures.tap_action(tree, &"dash", 1)
	await Fixtures.wait_physics(tree, 2)
	check.call(player.state_machine.current.name != &"Dash", "(g2) a ground dash at 0 does not start (%s)" % player.state_machine.current.name)
	check.call(_refusals(&"dash").size() == 1 and _refusals(&"dash")[0]["needed"] == 1 and _refused.size() == 1, "(g2) exactly one energy_refused(dash, 1) (got %s)" % [_refused])
	check.call(player.dash_cooldown_timer == 0.0, "(g2) the refused dash spends no cooldown")
	await _end(player)


# Air dash: paid at exactly the cost, refused (one fact) below it.
func _scenario_air_dash(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	await _into_air(tree, player)
	Fixtures.set_energy(player, 1)
	check.call(player.dash_locked_reason() == &"", "(a1) with exactly the cost the air dash is not locked")
	await Fixtures.tap_action(tree, &"dash")
	var dashing: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 4)
	check.call(dashing >= 0 and player.arm_energy.value == 0, "(a1) the air dash fires and leaves 0 (value %d)" % player.arm_energy.value)
	check.call(_spends(&"air_dash").size() == 1 and _spends(&"air_dash")[0]["amount"] == 1, "(a1) one energy_spent(1, air_dash) (got %s)" % [_spent])
	check.call(_refused.is_empty(), "(a1) a paid air dash gives no refusal")
	await _end(player)

	player = await _begin(tree)
	await _into_air(tree, player)
	Fixtures.set_energy(player, 0)
	check.call(player.dash_locked_reason() == &"energy", "(b1) at 0 the reason is energy (got %s)" % player.dash_locked_reason())
	await Fixtures.tap_action(tree, &"dash", 1)
	await Fixtures.wait_physics(tree, 1)
	check.call(player.state_machine.current.name != &"Dash", "(b2) the air dash does not fire")
	check.call(_blocked.size() == 1 and _blocked[0] == &"energy", "(b2) exactly one dash_blocked with reason energy (got %s)" % [_blocked])
	check.call(_refused.size() == 1 and _refused[0]["reason"] == &"air_dash" and _refused[0]["needed"] == 1, "(b2) exactly one energy_refused(air_dash, 1) (got %s)" % [_refused])
	check.call(player.air_dash_available and player.dash_cooldown_timer == 0.0 and player.arm_energy.value == 0, "(b3) the air dash charge, the cooldown and the energy stay")
	await _end(player)


# The dash hop: stage 1 is free; stages 2 and 3 pay +1 each and fall back to stage 1 silently.
func _scenario_hop_costs(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	Fixtures.set_energy(player, 0)
	player.long_jump_stage = 0
	check.call(player.advance_long_jump_stage() == 1 and player.arm_energy.value == 0, "(h1) stage 1 is free, even at 0")
	Fixtures.set_energy(player, 1)
	player.long_jump_stage = 1
	check.call(player.advance_long_jump_stage() == 2 and player.arm_energy.value == 0, "(h2) stage 2 costs 1 step and leaves 0")
	check.call(_spends(&"dash_hop").size() == 1 and _spends(&"dash_hop")[0]["amount"] == 1, "(h2) one energy_spent(1, dash_hop) (got %s)" % [_spent])
	_refused.clear()
	_blocked.clear()
	_spent.clear()
	Fixtures.set_energy(player, 0)
	player.long_jump_stage = 1
	var stage: int = player.advance_long_jump_stage()
	check.call(stage == 1 and player.long_jump_stage == 1 and player.arm_energy.value == 0 and _spent.is_empty(), "(h3) at 0 the hop silently becomes stage 1 (got %d)" % stage)
	check.call(_refused.is_empty() and _blocked.is_empty(), "(h3) no refusal and no dash_blocked on the fallback")
	Fixtures.set_energy(player, 2)
	player.long_jump_stage = 1
	var second: int = player.advance_long_jump_stage()
	var third: int = player.advance_long_jump_stage()
	check.call(second == 2 and third == 3 and player.arm_energy.value == 0, "(h4) 2 steps pay stages 2 and 3 (got %d and %d, value %d)" % [second, third, player.arm_energy.value])
	await _end(player)


## A floor-less setup: the pad, a player launched at it. Returns [player, pad]. `pad_scene` picks the run or the jump pad.
func _wall_setup(tree: SceneTree, pad_scene: String, steps: int) -> Array:
	_blocked = []
	_refused = []
	_spent = []
	_on_blocked = func(_position: Vector3, reason: StringName) -> void: _blocked.append(reason)
	_on_refused = func(reason: StringName, needed: int) -> void: _refused.append({"reason": reason, "needed": needed})
	_on_spent = func(amount: int, reason: StringName) -> void: _spent.append({"amount": amount, "reason": reason})
	_bus.connect(&"dash_blocked", _on_blocked)
	_bus.connect(&"energy_refused", _on_refused)
	_bus.connect(&"energy_spent", _on_spent)
	_floor = Fixtures.spawn_floor(tree.root)
	var pad: WallSurface = (load(pad_scene) as PackedScene).instantiate() as WallSurface
	tree.root.add_child(pad)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(-7.0, 2.0, 2.25))
	player.config = player.config.duplicate() as MovementConfig
	player.config.energy_passive_interval = 100000.0
	await Fixtures.wait_physics(tree, 3)
	Fixtures.set_energy(player, steps)
	player.launch_along(Vector3(0.6, 0.2, -0.8), 10.0, false)
	return [player, pad]


func _in_state(player: PlayerController, state_name: StringName) -> bool:
	return player.state_machine.current.name == state_name


# Wall-run entry: 2 steps leave 0; 1 step does not start the run and refuses once per wall contact, not per tick.
func _scenario_wall_run_entry(tree: SceneTree, check: Callable) -> void:
	var parts: Array = await _wall_setup(tree, RUN_PAD, 2)
	var player: PlayerController = parts[0] as PlayerController
	var entered: int = await Fixtures.wait_until(tree, func() -> bool: return _in_state(player, &"WallRun"), 20)
	check.call(entered >= 0 and player.arm_energy.value == 0, "(w1) a wall run at 2 steps starts and the entry leaves 0 (value %d)" % player.arm_energy.value)
	check.call(_spends(&"wall_run").size() >= 1 and _spends(&"wall_run")[0]["amount"] == 2, "(w1) the entry is energy_spent(2, wall_run) (got %s)" % [_spent])
	check.call(_refused.is_empty(), "(w1) a paid entry refuses nothing")
	await _end(player, parts)

	parts = await _wall_setup(tree, RUN_PAD, 1)
	player = parts[0] as PlayerController
	var started: bool = false
	for i: int in 30:
		await tree.physics_frame
		started = started or _in_state(player, &"WallRun")
	check.call(not started and player.arm_energy.value == 1, "(w2) a wall run at 1 step does not start and costs nothing")
	check.call(_refusals(&"wall_run").size() == 1 and _refusals(&"wall_run")[0]["needed"] == 2, "(w2) exactly one energy_refused(wall_run, 2) over 30 ticks of sliding the pad (got %s)" % [_refused])
	await _end(player, parts)


# The 1 s tick: paid it spends 1; unpaid it drops into Fall at once without a refusal.
func _scenario_wall_run_tick(tree: SceneTree, check: Callable) -> void:
	var parts: Array = await _wall_setup(tree, RUN_PAD, 3)
	var player: PlayerController = parts[0] as PlayerController
	var config: MovementConfig = player.config
	var entered: int = await Fixtures.wait_until(tree, func() -> bool: return _in_state(player, &"WallRun"), 20)
	check.call(entered >= 0, "(t0) the run starts")
	var ticks: int = 0
	while _in_state(player, &"WallRun") and ticks < 150:
		await tree.physics_frame
		ticks += 1
	check.call(player.arm_energy.value == 0, "(t1) entry 2 plus one 1 s tick of 1 spend 3 steps (value %d)" % player.arm_energy.value)
	check.call(float(ticks) / SHIPPED_TPS >= config.wall_run_time - 0.1, "(t1) a paid run lasts about wall_run_time (%.3f s)" % [float(ticks) / SHIPPED_TPS])
	check.call(_spends(&"wall_run").size() == 2 and _spends(&"wall_run")[1]["amount"] == 1, "(t1) two wall_run spends: the entry 2 and one tick 1 (got %s)" % [_spent])
	await _end(player, parts)

	parts = await _wall_setup(tree, RUN_PAD, 2)
	player = parts[0] as PlayerController
	await Fixtures.wait_until(tree, func() -> bool: return _in_state(player, &"WallRun"), 20)
	ticks = 0
	while _in_state(player, &"WallRun") and ticks < 150:
		await tree.physics_frame
		ticks += 1
	var run_time: float = float(ticks) / SHIPPED_TPS
	check.call(_in_state(player, &"Fall"), "(t2) an unpaid 1 s tick drops into Fall (%s)" % player.state_machine.current.name)
	check.call(absf(run_time - config.wall_run_tick_interval) < 0.1 and run_time < config.wall_run_time - 0.05, "(t2) at the tick time %.2f s, before wall_run_time (got %.3f s)" % [config.wall_run_tick_interval, run_time])
	check.call(_refused.is_empty(), "(t2) the drop emits no energy_refused")
	await _end(player, parts)


# Wall jump: 1 step paid leaves 0; at 0 no WallJump, one refusal, and the press is consumed (no ground jump on landing).
func _scenario_wall_jump(tree: SceneTree, check: Callable) -> void:
	var parts: Array = await _wall_setup(tree, JUMP_PAD, 1)
	var player: PlayerController = parts[0] as PlayerController
	await Fixtures.wait_physics(tree, 8)
	Fixtures.send_action_event(&"jump", true)
	var jumped: int = await Fixtures.wait_until(tree, func() -> bool: return _in_state(player, &"WallJump"), 12)
	Fixtures.send_action_event(&"jump", false)
	check.call(jumped >= 0 and player.arm_energy.value == 0, "(j1) a wall jump at 1 step fires and leaves 0 (value %d)" % player.arm_energy.value)
	check.call(_spends(&"wall_jump").size() == 1 and _spends(&"wall_jump")[0]["amount"] == 1, "(j1) one energy_spent(1, wall_jump) (got %s)" % [_spent])
	await _end(player, parts)

	parts = await _wall_setup(tree, JUMP_PAD, 0)
	player = parts[0] as PlayerController
	await Fixtures.wait_physics(tree, 8)
	Fixtures.send_action_event(&"jump", true)
	var fired: bool = false
	for i: int in 12:
		await tree.physics_frame
		fired = fired or _in_state(player, &"WallJump")
	Fixtures.send_action_event(&"jump", false)
	check.call(not fired, "(j2) a wall jump at 0 steps does not fire")
	check.call(_refusals(&"wall_jump").size() == 1 and _refusals(&"wall_jump")[0]["needed"] == 1, "(j2) exactly one energy_refused(wall_jump, 1) (got %s)" % [_refused])
	check.call(not player.wants_jump(), "(j2) the buffered press is consumed")
	await _end(player, parts)
