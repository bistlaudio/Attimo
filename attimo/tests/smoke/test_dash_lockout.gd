extends RefCounted
## Quick 261120-dik: dash lockouts and blocked-dash feedback. A dash press is refused (consumed, never buffered) while aiming,
## during the Jump 3 / long jump stage 3 pirouette, in the landing window after touchdown and in the take-off window after a
## jump. A refused press emits EventBus.dash_blocked once, kicks the ProceduralPose twitch (no velocity, no dash clip), and
## spends neither the cooldown nor the air dash charge. A press outside every lockout dashes as before. The dash crossfades
## (dash_in_blend, dash_in_blend_air, dash_out_blend) are written to the animation edges by MannequinAnimator.
## Every expectation derives from player.config; scenarios that change numbers use a duplicate of the config.

const Fixtures := preload("res://tests/fixtures.gd")
## The animation node of the unaimed ground dash: Slide only while Dash.SLIDE_PRESENTATION is on.
const UNAIMED_DASH: StringName = &"Slide" if preload("res://scripts/player/states/dash.gd").SLIDE_PRESENTATION else &"Dash"
const SHIPPED_TPS: int = 60
const TWITCH_TOLERANCE_DEG: float = 0.1

var _bus: Node
var _blocked: Array[Dictionary] = []
var _dashes: Array[bool] = []
var _on_blocked: Callable
var _on_dash: Callable
var _floor: StaticBody3D


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_takeoff(tree, check)
	await _scenario_landing(tree, check)
	await _scenario_pirouette(tree, check)
	await _scenario_aim(tree, check)
	await _scenario_twitch(tree, check)
	await _scenario_open_dash(tree, check)
	await _scenario_blends(tree, check)


## Fresh recorders, a floor and a player on a private copy of the config.
func _begin(tree: SceneTree, position: Vector3 = Vector3.ZERO) -> PlayerController:
	_blocked = []
	_dashes = []
	_on_blocked = func(blocked_position: Vector3, reason: StringName) -> void: _blocked.append({"position": blocked_position, "reason": reason})
	_on_dash = func(_position: Vector3, _direction: Vector3, in_air: bool) -> void: _dashes.append(in_air)
	_bus.connect(&"dash_blocked", _on_blocked)
	_bus.connect(&"dash_started", _on_dash)
	_floor = Fixtures.spawn_floor(tree.root, Vector3(60.0, 1.0, 120.0))
	var player: PlayerController = Fixtures.spawn_player(tree.root, position)
	player.config = player.config.duplicate() as MovementConfig
	await Fixtures.wait_physics(tree, 10)
	return player


func _end(player: PlayerController) -> void:
	for action: StringName in [&"move_forward", &"jump", &"dash", &"aim"]:
		Fixtures.send_action_event(action, false)
		Input.action_release(action)
	_bus.disconnect(&"dash_blocked", _on_blocked)
	_bus.disconnect(&"dash_started", _on_dash)
	_on_blocked = Callable()
	_on_dash = Callable()
	player.queue_free()
	_floor.queue_free()
	await player.tree_exited


## True when exactly one dash_blocked fact was recorded and it carries `reason`.
func _only_reason(reason: StringName) -> bool:
	return _blocked.size() == 1 and _blocked[0]["reason"] == reason


## True when exactly one dash_started fact was recorded and its in_air flag is `in_air`.
func _only_dash(in_air: bool) -> bool:
	return _dashes.size() == 1 and _dashes[0] == in_air


func _reasons() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: Dictionary in _blocked:
		result.append(entry["reason"])
	return result


## Spent state of a refused press: no cooldown and the air dash charge intact.
func _unspent(player: PlayerController) -> bool:
	return player.dash_cooldown_timer == 0.0 and player.air_dash_available


# A press right after a jump take-off is refused; nothing fires after the window; outside it the air dash works.
func _scenario_takeoff(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	Fixtures.send_action_event(&"jump", true)
	var up: int = await Fixtures.wait_until(tree, func() -> bool: return player.dash_takeoff_lock_timer > 0.0, 10)
	check.call(up >= 0, "(t1) a jump take-off starts the take-off lockout (%.2f s)" % player.dash_takeoff_lock_timer)
	check.call(player.dash_takeoff_lock_timer <= player.config.dash_block_takeoff, "(t1) the lockout lasts at most dash_block_takeoff %.2f s (got %.3f)" % [player.config.dash_block_takeoff, player.dash_takeoff_lock_timer])
	await Fixtures.tap_action(tree, &"dash")
	check.call(_only_reason(&"takeoff"), "(t2) the press inside the take-off window emits dash_blocked once with the takeoff reason (got %s)" % [_reasons()])
	check.call(_dashes.is_empty() and player.state_machine.current.name != &"Dash", "(t2) no dash starts inside the take-off window")
	check.call(_unspent(player), "(t2) the refused press spends neither the cooldown nor the air dash")
	await Fixtures.wait_physics(tree, Fixtures.lock_ticks(player.config) + 2)
	check.call(_dashes.is_empty(), "(t3) the refused press was not buffered: no dash fires after the window ends")
	check.call(not player.is_grounded() and player.dash_locked_reason() == &"", "(t3) the player is still in the air and no lockout applies")
	await Fixtures.tap_action(tree, &"dash")
	var dashing: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 4)
	check.call(dashing >= 0 and _only_dash(true), "(t4) a press after the window starts the air dash (dashes %s)" % [_dashes])
	check.call(_blocked.size() == 1, "(t4) the allowed press emits no dash_blocked (got %d)" % _blocked.size())
	await _end(player)


# A press on the touchdown tick is refused and a held key does not fire when the window ends.
func _scenario_landing(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	await Fixtures.tap_action(tree, &"jump")
	var landed: int = await Fixtures.wait_until(tree, func() -> bool: return player.dash_landing_lock_timer > 0.0, 120)
	check.call(landed >= 0, "(l1) touchdown starts the landing lockout")
	Input.action_press(&"dash")
	await Fixtures.wait_physics(tree, 3)
	check.call(_only_reason(&"landing"), "(l2) the press in the landing window emits dash_blocked once with the landing reason (got %s)" % [_reasons()])
	check.call(_dashes.is_empty() and player.state_machine.current.name != &"Dash", "(l2) no dash starts in the landing window")
	check.call(_unspent(player) and player.is_grounded(), "(l2) the refused press spends neither the cooldown nor the air dash")
	await Fixtures.wait_physics(tree, Fixtures.lock_ticks(player.config) + 4)
	check.call(_dashes.is_empty() and _blocked.size() == 1, "(l3) the key held through the window does not dash when it ends (no buffer): dashes %d, blocked %d" % [_dashes.size(), _blocked.size()])
	Input.action_release(&"dash")
	await Fixtures.wait_physics(tree, 2)
	await Fixtures.tap_action(tree, &"dash")
	var dashing: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 4)
	check.call(dashing >= 0 and _only_dash(false), "(l4) a new press after the window starts the ground dash (dashes %s)" % [_dashes])
	await _end(player)


# Jump 3 pirouette: the press is refused until the spin ends (take-off window off, so only the pirouette locks).
func _scenario_pirouette(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree, Vector3(0.0, 0.0, 50.0))
	player.config.dash_block_takeoff = 0.0
	var pose: ProceduralPose = player.get_node("ProceduralPose") as ProceduralPose
	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - player.config.run_speed) < 0.05, 120)
	for i: int in 2:
		await _held_jump(tree, player)
	Fixtures.send_action_event(&"jump", true)
	var spinning: int = await Fixtures.wait_until(tree, func() -> bool: return pose.spinning, 20)
	check.call(spinning >= 0 and player.chain_stage == 3, "(p1) Jump 3 starts the pirouette (stage %d)" % player.chain_stage)
	Fixtures.send_action_event(&"jump", false)
	await Fixtures.wait_physics(tree, 4)
	check.call(player.dash_locked_reason() == &"pirouette", "(p1) the pirouette is the lock reason (got %s)" % player.dash_locked_reason())
	await Fixtures.tap_action(tree, &"dash")
	check.call(_only_reason(&"pirouette"), "(p2) the press during the pirouette emits dash_blocked once with the pirouette reason (got %s)" % [_reasons()])
	check.call(_dashes.is_empty() and _unspent(player), "(p2) no dash, cooldown and air dash unspent")
	await Fixtures.wait_until(tree, func() -> bool: return player.is_grounded(), 240)
	await Fixtures.wait_physics(tree, 3)
	check.call(_dashes.is_empty(), "(p3) nothing fires when the pirouette has ended (no buffer)")
	await _end(player)


## Holds jump to the apex, releases it and waits for the touchdown.
func _held_jump(tree: SceneTree, player: PlayerController) -> void:
	Fixtures.send_action_event(&"jump", true)
	await Fixtures.wait_until(tree, func() -> bool: return not player.is_grounded() and player.vertical_speed <= 0.0, 120)
	Fixtures.send_action_event(&"jump", false)
	await Fixtures.wait_until(tree, func() -> bool: return player.is_grounded(), 240)


# Aim blocks the dash on the ground and in the air, and a refused press does not touch a running cooldown.
func _scenario_aim(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	check.call(player.dash_locked_reason() == &"", "(a1) no lockout at rest")
	Input.action_press(&"aim")
	await Fixtures.wait_physics(tree, 4)
	check.call(player.dash_locked_reason() == &"aim" and not player.can_dash(), "(a1) aim is a lock reason and can_dash is false")
	await Fixtures.tap_action(tree, &"dash")
	check.call(_only_reason(&"aim") and _dashes.is_empty(), "(a2) an aimed press on the ground is refused with the aim reason (got %s)" % [_reasons()])
	check.call(_unspent(player), "(a2) the aimed press spends no cooldown")
	Input.action_release(&"aim")
	await Fixtures.wait_physics(tree, 4)
	await Fixtures.tap_action(tree, &"dash")
	var dashing: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 4)
	check.call(dashing >= 0 and _only_dash(false), "(a3) after releasing aim the dash works (dashes %s)" % [_dashes])
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name != &"Dash", 40)
	var cooldown_before: float = player.dash_cooldown_timer
	Input.action_press(&"aim")
	await Fixtures.wait_physics(tree, 3)
	await Fixtures.tap_action(tree, &"dash")
	check.call(_blocked.size() == 2 and player.dash_cooldown_timer < cooldown_before, "(a4) a refused press during a cooldown does not reset it (%.3f s before, %.3f after, blocked %d)" % [cooldown_before, player.dash_cooldown_timer, _blocked.size()])
	Input.action_release(&"aim")
	await _end(player)


# The twitch: a half sine kick of dash_blocked_twitch_deg, forward, no motion and no dash clip, back to exactly 0.
func _scenario_twitch(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	var pose: ProceduralPose = player.get_node("ProceduralPose") as ProceduralPose
	var mannequin: Node3D = player.get_node("VisualRoot/Mannequin") as Node3D
	var animator: MannequinAnimator = player.get_node("MannequinAnimator") as MannequinAnimator
	check.call(pose.twitch_angle == 0.0 and mannequin.transform == Transform3D.IDENTITY, "(w1) at rest there is no twitch and the Mannequin transform is identity")
	var start_position: Vector3 = player.global_position
	var yaw: float = player.visual_root.rotation.y
	Input.action_press(&"aim")
	await Fixtures.wait_physics(tree, 4)
	Input.action_press(&"dash")
	var peak: float = 0.0
	var peak_tilt: float = 0.0
	var max_lean: float = 0.0
	var max_speed: float = 0.0
	var finite: bool = true
	var ticks: int = int(ceil(config.dash_blocked_twitch_time * float(SHIPPED_TPS))) + 6
	for i: int in ticks:
		await tree.physics_frame
		if i == 1:
			Input.action_release(&"dash")
		peak = maxf(peak, pose.twitch_angle)
		max_lean = maxf(max_lean, pose.lean_angle)
		max_speed = maxf(max_speed, player.horizontal_speed())
		finite = finite and mannequin.transform.basis.x.is_finite() and mannequin.transform.basis.y.is_finite() and mannequin.transform.basis.z.is_finite()
		var tilt: Vector3 = player.visual_root.global_basis * (mannequin.transform.basis * Vector3.UP)
		peak_tilt = maxf(peak_tilt, tilt.dot(player.visual_root.global_basis.z))
	check.call(absf(rad_to_deg(peak) - config.dash_blocked_twitch_deg) < TWITCH_TOLERANCE_DEG, "(w2) the twitch peaks at dash_blocked_twitch_deg %.1f (got %.3f deg)" % [config.dash_blocked_twitch_deg, rad_to_deg(peak)])
	check.call(peak_tilt > 0.5 * sin(deg_to_rad(config.dash_blocked_twitch_deg)), "(w2) the twitch kicks the body forward (tilt toward the facing %.3f)" % peak_tilt)
	check.call(max_lean == 0.0, "(w3) the twitch leaves the dash lean alone (lean %.3f)" % max_lean)
	check.call(max_speed < 0.01 and player.global_position.distance_to(start_position) < 0.01, "(w3) the twitch does not move the body (speed %.3f m/s)" % max_speed)
	check.call(is_equal_approx(player.visual_root.rotation.y, yaw), "(w3) the twitch does not turn the facing")
	check.call(animator.last_travel == &"Locomotion" and not MannequinAnimator.DASH_NODES.has(animator.last_travel), "(w3) no dash clip is shown (animation node %s)" % animator.last_travel)
	check.call(finite, "(w3) every written Mannequin basis is finite")
	check.call(pose.twitch_angle == 0.0 and player.dash_twitch_timer == 0.0, "(w4) the twitch decays to exactly 0 within dash_blocked_twitch_time plus 6 ticks (got %.4f)" % pose.twitch_angle)
	check.call(mannequin.transform == Transform3D.IDENTITY, "(w4) the Mannequin transform is identity again")
	# Two presses are two facts.
	await Fixtures.tap_action(tree, &"dash")
	check.call(_blocked.size() == 2, "(w5) each refused press is one dash_blocked fact (got %d)" % _blocked.size())
	check.call(_blocked[0]["position"] is Vector3, "(w5) dash_blocked carries the position")
	Input.action_release(&"aim")
	await _end(player)


# Outside every lockout the dash is unchanged: one dash_started, dash_speed, no dash_blocked.
func _scenario_open_dash(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - player.config.run_speed) < 0.05, 120)
	check.call(player.dash_locked_reason() == &"" and player.can_dash(), "(o1) no lockout and the dash is available while running")
	await Fixtures.tap_action(tree, &"dash")
	await Fixtures.wait_physics(tree, 2)
	check.call(_only_dash(false) and _blocked.is_empty(), "(o2) one ground dash_started and no dash_blocked (dashes %s, blocked %d)" % [_dashes, _blocked.size()])
	check.call(absf(player.horizontal_speed() - player.config.dash_speed) < 0.1, "(o2) the dash runs at dash_speed (got %.2f)" % player.horizontal_speed())
	# A refusal by the cooldown or the spent air dash is not a lockout: no feedback.
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name != &"Dash", 40)
	await Fixtures.tap_action(tree, &"dash")
	check.call(_blocked.is_empty() and _dashes.size() == 1, "(o3) a press during the cooldown is refused silently (blocked %d)" % _blocked.size())
	await _end(player)


# The dash crossfades live in MovementConfig and are written to the edges just before each travel.
func _scenario_blends(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	var animator: MannequinAnimator = player.get_node("MannequinAnimator") as MannequinAnimator
	check.call(is_equal_approx(animator.blend_time_for(&"Locomotion", &"Dash"), config.dash_in_blend), "(b1) the ground locomotion into a dash uses dash_in_blend %.2f" % config.dash_in_blend)
	for from_node: StringName in [&"Jump", &"Jump2", &"LongJump", &"Fall"]:
		check.call(is_equal_approx(animator.blend_time_for(from_node, &"Dash"), config.dash_in_blend_air), "(b2) %s into a dash uses dash_in_blend_air %.2f" % [from_node, config.dash_in_blend_air])
	for to_node: StringName in [&"Fall", &"Locomotion", &"LongJump"]:
		check.call(is_equal_approx(animator.blend_time_for(&"Dash", to_node), config.dash_out_blend), "(b3) Dash into %s uses dash_out_blend %.2f" % [to_node, config.dash_out_blend])
	check.call(animator.blend_time_for(&"Locomotion", &"Jump") < 0.0 and animator.blend_time_for(&"Slide", &"Locomotion") < 0.0 and animator.blend_time_for(&"Locomotion", &"Slide") < 0.0, "(b4) other edges and the Slide edges keep the tree's own crossfade")
	check.call(config.dash_in_blend < config.dash_in_blend_air and config.dash_out_blend > config.dash_in_blend_air, "(b5) the shipped blends are softer than before: in %.2f ground, %.2f air, out %.2f" % [config.dash_in_blend, config.dash_in_blend_air, config.dash_out_blend])

	var root: AnimationNodeBlendTree = Fixtures.animation_tree(player).tree_root as AnimationNodeBlendTree
	var land: AnimationNodeOneShot = root.get_node(&"Land") as AnimationNodeOneShot
	var idle_break: AnimationNodeOneShot = root.get_node(&"IdleBreak") as AnimationNodeOneShot
	check.call(land.fadeout_time > 0.0 and idle_break.fadeout_time > 0.0, "(b6) the landing overlay (%.2f s) and the idle break (%.2f s) fade out instead of vanishing" % [land.fadeout_time, idle_break.fadeout_time])

	if UNAIMED_DASH == &"Dash":
		config.dash_in_blend = 0.2
		config.dash_out_blend = 0.3
		Input.action_press(&"move_forward")
		await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - config.run_speed) < 0.05, 120)
		await Fixtures.tap_action(tree, &"dash")
		await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 4)
		var machine: AnimationNodeStateMachine = root.get_node(&"StateMachine") as AnimationNodeStateMachine
		check.call(is_equal_approx(_edge_blend(machine, &"Locomotion", &"Dash"), 0.2), "(b7) the Locomotion to Dash edge picked up the live dash_in_blend 0.2 (got %.3f)" % _edge_blend(machine, &"Locomotion", &"Dash"))
		await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name != &"Dash", 40)
		check.call(is_equal_approx(_edge_blend(machine, &"Dash", &"Locomotion"), 0.3), "(b7) the Dash to Locomotion edge picked up the live dash_out_blend 0.3 (got %.3f)" % _edge_blend(machine, &"Dash", &"Locomotion"))
		# Put the shared tree resource back to the shipped numbers.
		var shipped: MovementConfig = load("res://resources/player/movement_default.tres") as MovementConfig
		_edge_set(machine, &"Locomotion", &"Dash", shipped.dash_in_blend)
		_edge_set(machine, &"Dash", &"Locomotion", shipped.dash_out_blend)
	await _end(player)


func _edge_blend(machine: AnimationNodeStateMachine, from_node: StringName, to_node: StringName) -> float:
	for i: int in machine.get_transition_count():
		if machine.get_transition_from(i) == from_node and machine.get_transition_to(i) == to_node:
			return machine.get_transition(i).xfade_time
	return -1.0


func _edge_set(machine: AnimationNodeStateMachine, from_node: StringName, to_node: StringName, value: float) -> void:
	for i: int in machine.get_transition_count():
		if machine.get_transition_from(i) == from_node and machine.get_transition_to(i) == to_node:
			machine.get_transition(i).xfade_time = value
