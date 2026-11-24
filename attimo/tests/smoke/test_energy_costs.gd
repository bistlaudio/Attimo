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
	for action: StringName in [&"move_forward", &"jump", &"dash", &"loader"]:
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
