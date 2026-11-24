extends RefCounted
## Plan 05-03 (ENRG-03, D-12): the cost of the injected moves and the silent base fallbacks. An air dash costs air_dash_cost and does
## not fire below it (dash_blocked with reason energy plus one energy_refused per press); the ground dash is always free. The dash hop
## pays long_jump_cost from stage 2 and falls back to stage 1 without any refusal fact (see the hop and wall run scenarios below).

const Fixtures := preload("res://tests/fixtures.gd")
const SHIPPED_TPS: int = 60

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
	await _scenario_air_dash_paid(tree, check)
	await _scenario_air_dash_refused(tree, check)
	await _scenario_ground_dash_free(tree, check)
	await _scenario_hop_costs(tree, check)
	await _scenario_wall_run_costs(tree, check)


func _begin(tree: SceneTree, position: Vector3 = Vector3.ZERO) -> PlayerController:
	_blocked = []
	_refused = []
	_spent = []
	_on_blocked = func(_position: Vector3, reason: StringName) -> void: _blocked.append(reason)
	_on_refused = func(reason: StringName, needed: float) -> void: _refused.append({"reason": reason, "needed": needed})
	_on_spent = func(amount: float, reason: StringName) -> void: _spent.append({"amount": amount, "reason": reason})
	_bus.connect(&"dash_blocked", _on_blocked)
	_bus.connect(&"energy_refused", _on_refused)
	_bus.connect(&"energy_spent", _on_spent)
	_floor = Fixtures.spawn_floor(tree.root, Vector3(60.0, 1.0, 120.0))
	var player: PlayerController = Fixtures.spawn_player(tree.root, position)
	await Fixtures.wait_physics(tree, 8)
	return player


func _end(player: PlayerController) -> void:
	for action: StringName in [&"move_forward", &"jump", &"dash", &"loader", &"charge"]:
		Fixtures.send_action_event(action, false)
		Input.action_release(action)
	_bus.disconnect(&"dash_blocked", _on_blocked)
	_bus.disconnect(&"energy_refused", _on_refused)
	_bus.disconnect(&"energy_spent", _on_spent)
	player.queue_free()
	_floor.queue_free()
	await player.tree_exited


## Lifts the player into the air (a jump) so an air dash press is possible.
func _into_air(tree: SceneTree, player: PlayerController) -> void:
	Fixtures.send_action_event(&"jump", true)
	await Fixtures.wait_until(tree, func() -> bool: return not player.is_grounded() and player.vertical_speed > 0.0, 10)
	Fixtures.send_action_event(&"jump", false)


# Energy exactly air_dash_cost: the air dash fires and leaves 0.0.
func _scenario_air_dash_paid(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var cost: float = player.config.air_dash_cost
	await _into_air(tree, player)
	Fixtures.set_energy(player, cost)
	check.call(player.dash_locked_reason() == &"", "(a1) with exactly the cost the air dash is not locked")
	await Fixtures.tap_action(tree, &"dash")
	var dashing: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 4)
	check.call(dashing >= 0, "(a1) the air dash fires at energy == cost")
	check.call(is_equal_approx(player.arm_energy.value, 0.0), "(a1) it leaves 0.0 (got %.3f)" % player.arm_energy.value)
	var air_spends: Array[Dictionary] = _spent.filter(func(entry: Dictionary) -> bool: return entry["reason"] == &"air_dash")
	check.call(air_spends.size() == 1 and is_equal_approx(float(air_spends[0]["amount"]), cost), "(a1) one energy_spent(%.1f, air_dash) fact (got %s)" % [cost, _spent])
	check.call(_blocked.is_empty() and _refused.is_empty(), "(a1) a paid air dash gives no blocked or refused fact")
	await _end(player)


# Just below the cost: no dash, one dash_blocked(energy) and one energy_refused per press, nothing spent.
func _scenario_air_dash_refused(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var cost: float = player.config.air_dash_cost
	await _into_air(tree, player)
	Fixtures.set_energy(player, cost - 0.01)
	check.call(player.dash_locked_reason() == &"energy", "(b1) just below the cost the reason is energy (got %s)" % player.dash_locked_reason())
	await Fixtures.tap_action(tree, &"dash", 1)
	await Fixtures.wait_physics(tree, 1)
	check.call(player.state_machine.current.name != &"Dash", "(b2) the air dash does not fire")
	check.call(_blocked.size() == 1 and _blocked[0] == &"energy", "(b2) exactly one dash_blocked with reason energy (got %s)" % [_blocked])
	check.call(_refused.size() == 1 and _refused[0]["reason"] == &"air_dash" and is_equal_approx(float(_refused[0]["needed"]), cost), "(b2) exactly one energy_refused(air_dash, %.1f) (got %s)" % [cost, _refused])
	check.call(player.air_dash_available and player.dash_cooldown_timer == 0.0, "(b3) the air dash charge and the cooldown stay unspent")
	check.call(is_equal_approx(player.arm_energy.value, cost - 0.01), "(b3) the energy stays (got %.3f)" % player.arm_energy.value)
	await _end(player)


# The ground dash costs nothing, even with an empty arm.
func _scenario_ground_dash_free(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	Fixtures.set_energy(player, 0.0)
	check.call(player.dash_locked_reason() == &"", "(g1) the ground dash is not locked at 0.0")
	await Fixtures.tap_action(tree, &"dash")
	var dashing: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 4)
	check.call(dashing >= 0 and _blocked.is_empty() and _refused.is_empty(), "(g1) the ground dash fires at 0.0 without any refusal")
	check.call(_spent.is_empty(), "(g1) the ground dash spends nothing (got %s)" % [_spent])
	await _end(player)


# The dash hop: stage 1 is free, stages 2 and 3 pay long_jump_cost; without the energy the hop silently becomes stage 1.
func _scenario_hop_costs(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var cost: float = player.config.long_jump_cost
	Fixtures.set_energy(player, 0.0)
	player.long_jump_stage = 0
	check.call(player.advance_long_jump_stage() == 1 and player.arm_energy.value == 0.0, "(h1) stage 1 is free, even at 0.0")
	Fixtures.set_energy(player, cost)
	player.long_jump_stage = 1
	check.call(player.advance_long_jump_stage() == 2 and player.long_jump_stage == 2, "(h2) with exactly %.1f the hop reaches stage 2" % cost)
	check.call(is_equal_approx(player.arm_energy.value, 0.0), "(h2) it leaves 0.0 (got %.3f)" % player.arm_energy.value)
	var hop_spends: Array[Dictionary] = _spent.filter(func(entry: Dictionary) -> bool: return entry["reason"] == &"dash_hop")
	check.call(hop_spends.size() == 1 and is_equal_approx(float(hop_spends[0]["amount"]), cost), "(h2) one energy_spent(%.1f, dash_hop) fact (got %s)" % [cost, _spent])
	_blocked.clear()
	_refused.clear()
	_spent.clear()
	Fixtures.set_energy(player, cost - 0.1)
	player.long_jump_stage = 1
	var stage: int = player.advance_long_jump_stage()
	check.call(stage == 1 and player.long_jump_stage == 1, "(h3) with %.1f the hop silently becomes stage 1 (got %d)" % [cost - 0.1, stage])
	check.call(is_equal_approx(player.arm_energy.value, cost - 0.1) and _spent.is_empty(), "(h3) nothing was spent")
	check.call(_refused.is_empty() and _blocked.is_empty(), "(h3) no energy_refused and no dash_blocked on the fallback")
	Fixtures.set_energy(player, 2.0 * cost)
	player.long_jump_stage = 1
	var second: int = player.advance_long_jump_stage()
	var third: int = player.advance_long_jump_stage()
	check.call(second == 2 and third == 3 and is_equal_approx(player.arm_energy.value, 0.0), "(h4) 30 pays stages 2 and 3 (got %d and %d, value %.2f)" % [second, third, player.arm_energy.value])
	await _end(player)


const PAD_SCENE: String = "res://scenes/mechanisms/wall_pad.tscn"


## A floor, an active wall-run pad and a player launched at it. Returns [player, floor, source, pad].
func _wall_setup(tree: SceneTree, energy: float) -> Array:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var pad: WallPad = (load(PAD_SCENE) as PackedScene).instantiate() as WallPad
	pad.mode = WallPad.Mode.WALL_RUN
	pad.source = source
	tree.root.add_child(pad)
	source.set_active(true)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(-7.0, 2.0, 2.25))
	await Fixtures.wait_physics(tree, 3)
	Fixtures.set_energy(player, energy)
	player.launch_along(Vector3(0.6, 0.2, -0.8), 10.0, false)
	return [player, floor_body, source, pad]


func _wall_free(tree: SceneTree, parts: Array) -> void:
	for node: Variant in [parts[1], parts[2], parts[3], parts[0]]:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


# A wall run is free for wall_run_free_time, then drains wall_run_cost_per_second; a dry arm ends it into Fall with no refusal fact.
func _scenario_wall_run_costs(tree: SceneTree, check: Callable) -> void:
	_blocked = []
	_refused = []
	var on_refused: Callable = func(reason: StringName, needed: float) -> void: _refused.append({"reason": reason, "needed": needed})
	_bus.connect(&"energy_refused", on_refused)
	# Empty arm: the free window runs, then the run ends into Fall. The pad's 10 m/s still earns the passive charge, so the run
	# lasts a few ticks past the free window and far less than wall_run_time.
	var parts: Array = await _wall_setup(tree, 0.0)
	var player: PlayerController = parts[0] as PlayerController
	var config: MovementConfig = player.config
	var entered: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallRun", 20)
	check.call(entered >= 0, "(w0) the run starts")
	var ticks: int = 0
	while player.state_machine.current.name == &"WallRun" and ticks < 120:
		await tree.physics_frame
		ticks += 1
	var run_time: float = float(ticks) / SHIPPED_TPS
	check.call(player.state_machine.current.name == &"Fall", "(w1) a dry arm ends the run into Fall (%s)" % player.state_machine.current.name)
	check.call(run_time >= config.wall_run_free_time - 0.05 and run_time < config.wall_run_time - 0.15, "(w1) the run lasts the free window %.2f s plus a few ticks, not wall_run_time %.2f (got %.3f s)" % [config.wall_run_free_time, config.wall_run_time, run_time])
	check.call(_refused.is_empty(), "(w1) the run ending dry emits no energy_refused")
	await _wall_free(tree, parts)

	# Full arm: lasts wall_run_time and pays (wall_run_time - free) * cost per second.
	parts = await _wall_setup(tree, 60.0)
	player = parts[0] as PlayerController
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallRun", 20)
	var start_value: float = player.arm_energy.value
	var start_ticks: int = 0
	while player.state_machine.current.name == &"WallRun" and start_ticks < 120:
		await tree.physics_frame
		start_ticks += 1
	var expected: float = (config.wall_run_time - config.wall_run_free_time) * config.wall_run_cost_per_second
	var spent: float = start_value - player.arm_energy.value
	# The passive charge at the pad speed earns a little back while the drain runs.
	var passive_back: float = config.energy_passive_rate_min * config.wall_run_time
	check.call(float(start_ticks) / SHIPPED_TPS >= config.wall_run_time - 0.1, "(w2) with energy the run lasts about wall_run_time (%.3f s)" % [float(start_ticks) / SHIPPED_TPS])
	check.call(spent > expected - passive_back - 0.5 and spent < expected + 0.5, "(w2) the run costs about %.2f (spent %.2f, passive back up to %.2f)" % [expected, spent, passive_back])
	await _wall_free(tree, parts)

	# Jumping off is always free: empty arm, past the free window, still a WallJump.
	parts = await _wall_setup(tree, 0.0)
	player = parts[0] as PlayerController
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallRun", 20)
	Fixtures.send_action_event(&"jump", true)
	var jumped: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallJump", 6)
	Fixtures.send_action_event(&"jump", false)
	check.call(jumped >= 0, "(w3) a jump off the pad at energy 0 is still a WallJump")
	check.call(_refused.is_empty(), "(w3) it emits no energy_refused")
	await _wall_free(tree, parts)
	_bus.disconnect(&"energy_refused", on_refused)
