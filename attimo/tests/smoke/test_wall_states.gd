extends RefCounted
## MOVE-12 (D-09): wall-run and wall-jump on pads only. A WallRun starts in the air against a pad in group wall_run_surface with at
## least wall_run_min_speed of horizontal speed, runs along the pad with scaled gravity for wall_run_time, ends at the pad's end,
## and cannot restart for wall_run_cooldown. A plain wall never starts it. Task 2 adds the WallJump scenarios to this file.

const Fixtures := preload("res://tests/fixtures.gd")

const PAD_SCENE: String = "res://scenes/mechanisms/wall_pad.tscn"
const SHIPPED_TPS: int = 60
## Player start 1.5 m in front of the pad face (face at z = 0.25, capsule radius 0.5).
const START_Z: float = 2.25


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_run_basics(tree, check)
	await _scenario_run_entry_from_jump(tree, check)
	await _scenario_teleport_ends_run(tree, check)
	await _scenario_run_end_and_cooldown(tree, check)
	await _scenario_rejections(tree, check)
	await _scenario_dash_and_landing(tree, check)
	await _scenario_wall_jump_from_run(tree, check)
	await _scenario_wall_jump_pads(tree, check)
	await _scenario_lean(tree, check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


## A floor, an active pad (mode 0 = WALL_RUN, 1 = WALL_JUMP) and a player in the air at (x, 2, START_Z). Returns [floor, source, pad, player].
func _setup(tree: SceneTree, mode: int, x: float) -> Array:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var pad: WallPad = (load(PAD_SCENE) as PackedScene).instantiate() as WallPad
	pad.mode = mode as WallPad.Mode
	pad.source = source
	tree.root.add_child(pad)
	source.set_active(true)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(x, 2.0, START_Z))
	await Fixtures.wait_physics(tree, 3)
	# These scenarios measure the injected wall run, not its cost: enough for a full run, below Moto Perpetuo (50).
	Fixtures.set_energy(player, 40.0)
	return [floor_body, source, pad, player]


func _launch_at_pad(player: PlayerController, speed: float) -> void:
	player.launch_along(Vector3(0.6, 0.2, -0.8), speed, false)


## True when the player is in state `state_name` on any tick of the next `ticks` ticks.
func _ever_in(tree: SceneTree, player: PlayerController, state_name: StringName, ticks: int) -> bool:
	for i: int in ticks:
		await tree.physics_frame
		if player.state_machine.current.name == state_name:
			return true
	return false


func _scenario_run_basics(tree: SceneTree, check: Callable) -> void:
	var started: Array[int] = [0]
	var on_started: Callable = func(_p: Vector3, _n: Vector3) -> void: started[0] += 1
	EventBus.wall_run_started.connect(on_started)
	var parts: Array = await _setup(tree, 0, -7.0)
	var pad: WallPad = parts[2] as WallPad
	var player: PlayerController = parts[3] as PlayerController
	var panel: Node = pad.get_node("Panel")
	check.call(panel.is_in_group(&"wall_run_surface") and not panel.is_in_group(&"wall_jump_surface"), "an active WALL_RUN pad puts its panel in group wall_run_surface only")
	pad.reset()
	check.call(pad.signal_on and panel.is_in_group(&"wall_run_surface"), "reset() keeps a pad on while its source is on (WR-05)")
	_launch_at_pad(player, 10.0)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallRun", 20)
	check.call(waited >= 0, "a 10 m/s approach at an active wall-run pad enters WallRun within 20 ticks (%d)" % waited)
	var start_x: float = player.global_position.x
	var start_vy: float = player.vertical_speed
	check.call(player.gravity_scale == player.config.wall_run_gravity_scale, "during WallRun gravity_scale is wall_run_gravity_scale (%.2f)" % player.gravity_scale)
	await Fixtures.wait_physics(tree, 30)
	check.call(player.state_machine.current.name == &"WallRun", "still in WallRun after 0.5 s (%s)" % player.state_machine.current.name)
	check.call(absf(player.vertical_speed - start_vy) < 3.0, "vertical speed changed %.2f m/s in 0.5 s (gravity scaled, under 3)" % (player.vertical_speed - start_vy))
	waited = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name != &"WallRun", 80)
	check.call(waited >= 0 and player.state_machine.current.name == &"Fall", "WallRun hands over to Fall at wall_run_time (%s)" % player.state_machine.current.name)
	var travelled: float = player.global_position.x - start_x
	check.call(travelled >= 8.0, "the player ran %.2f m along the pad (at least 8)" % travelled)
	check.call(player.gravity_scale == 1.0, "gravity_scale is 1.0 after the exit (%.2f)" % player.gravity_scale)
	check.call(started[0] == 1, "wall_run_started fired once per run (%d)" % started[0])
	EventBus.wall_run_started.disconnect(on_started)
	await _free(tree, parts)


## CR-01: a wall-run entered from a jump take-off (vertical speed near jump_speed) starts with wall_run_entry_rise, not with the
## jump's rise, so the pad does not launch the player over its top.
func _scenario_run_entry_from_jump(tree: SceneTree, check: Callable) -> void:
	var parts: Array = await _setup(tree, 0, -7.0)
	var player: PlayerController = parts[3] as PlayerController
	player.teleport(Vector3(-7.0, 1.0, 1.0))
	await Fixtures.wait_physics(tree, 2)
	var take_off: Vector3 = Vector3(6.0, 11.0, -8.0)
	player.launch_along(take_off.normalized(), take_off.length(), false)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallRun", 20)
	check.call(waited >= 0, "a jump-speed take-off at a wall-run pad enters WallRun (%d)" % waited)
	var rise: float = player.config.wall_run_entry_rise
	check.call(player.vertical_speed <= rise + 0.01, "the first WallRun tick rises at most wall_run_entry_rise (%.2f m/s, cap %.2f)" % [player.vertical_speed, rise])
	var entry_y: float = player.global_position.y
	var apex: float = entry_y
	for i: int in int(player.config.wall_run_time * SHIPPED_TPS) + 20:
		await tree.physics_frame
		apex = maxf(apex, player.global_position.y)
	check.call(apex - entry_y < 1.0, "the wall-run from a jump climbs %.2f m (under 1 m, no super-jump)" % (apex - entry_y))
	await _free(tree, parts)


## WR-02: a teleport (respawn) during WallRun hands the FSM to Fall and restores gravity_scale, so the run does not continue.
func _scenario_teleport_ends_run(tree: SceneTree, check: Callable) -> void:
	var parts: Array = await _setup(tree, 0, -7.0)
	var player: PlayerController = parts[3] as PlayerController
	_launch_at_pad(player, 10.0)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallRun", 20)
	check.call(waited >= 0, "teleport scenario: WallRun starts (%d)" % waited)
	player.teleport(Vector3(-7.0, 3.0, 6.0))
	check.call(player.state_machine.current.name == &"Fall" and player.gravity_scale == 1.0, "a teleport during WallRun hands over to Fall with gravity_scale 1.0 (%s, %.2f)" % [player.state_machine.current.name, player.gravity_scale])
	check.call(player.move_velocity == Vector3.ZERO and player.vertical_speed == 0.0, "the teleport leaves no motion behind")
	await _free(tree, parts)


func _scenario_run_end_and_cooldown(tree: SceneTree, check: Callable) -> void:
	var parts: Array = await _setup(tree, 0, -1.0)
	var player: PlayerController = parts[3] as PlayerController
	_launch_at_pad(player, 10.0)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallRun", 20)
	check.call(waited >= 0, "run-end scenario: WallRun starts (%d)" % waited)
	var ticks_in_run: int = 0
	while player.state_machine.current.name == &"WallRun" and ticks_in_run < 120:
		await tree.physics_frame
		ticks_in_run += 1
	var run_time: float = float(ticks_in_run) / SHIPPED_TPS
	check.call(player.state_machine.current.name == &"Fall" and run_time < player.config.wall_run_time - 0.1, "at the pad's end the run drops to Fall after %.2f s (before wall_run_time %.2f)" % [run_time, player.config.wall_run_time])
	check.call(player.wall_run_cooldown_timer > 0.0, "the cooldown runs after the exit (%.2f s)" % player.wall_run_cooldown_timer)
	check.call(not player.can_wall_run(), "can_wall_run is false during the cooldown")
	var again: bool = await _ever_in(tree, player, &"WallRun", 15)
	check.call(not again, "the same pad is not re-entered within the cooldown")
	await _free(tree, parts)


func _scenario_rejections(tree: SceneTree, check: Callable) -> void:
	var parts: Array = await _setup(tree, 0, -7.0)
	var player: PlayerController = parts[3] as PlayerController
	_launch_at_pad(player, 4.0)
	var entered: bool = await _ever_in(tree, player, &"WallRun", 40)
	check.call(not entered, "a 4 m/s approach does not start WallRun (below wall_run_min_speed)")
	await _free(tree, parts)

	# A plain wall without the group.
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var wall: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(12.0, 4.0, 0.5), Vector3(0.0, 2.0, 0.0))
	var plain_player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(-7.0, 2.0, START_Z))
	await Fixtures.wait_physics(tree, 3)
	_launch_at_pad(plain_player, 10.0)
	var plain_entered: bool = await _ever_in(tree, plain_player, &"WallRun", 40)
	check.call(not plain_entered, "a plain wall without a pad group never starts WallRun")
	check.call(plain_player.wall_contact_age < 1.0 or plain_player.wall_collider == wall, "the plain wall was touched (bookkeeping sees it)")
	await _free(tree, [floor_body, wall, plain_player])


func _scenario_dash_and_landing(tree: SceneTree, check: Callable) -> void:
	var parts: Array = await _setup(tree, 0, -7.0)
	var player: PlayerController = parts[3] as PlayerController
	_launch_at_pad(player, 10.0)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallRun", 20)
	await Fixtures.wait_physics(tree, 4)
	await Fixtures.tap_action(tree, &"dash", 3)
	var dashed: bool = player.state_machine.current.name == &"Dash" or await _ever_in(tree, player, &"Dash", 3)
	check.call(dashed, "a dash press during WallRun enters Dash (%s)" % player.state_machine.current.name)
	check.call(player.gravity_scale != player.config.wall_run_gravity_scale or player.gravity_scale == player.config.air_dash_gravity_scale, "the WallRun gravity scale is gone after leaving WallRun")
	await _free(tree, parts)

	# Landing during a run: normal gravity, no entry rise, a low start.
	var parts_b: Array = await _setup(tree, 0, -7.0)
	var low_player: PlayerController = parts_b[3] as PlayerController
	low_player.config = low_player.config.duplicate() as MovementConfig
	low_player.config.wall_run_gravity_scale = 1.0
	low_player.config.wall_run_entry_rise = 0.0
	low_player.config.wall_run_time = 3.0
	low_player.teleport(Vector3(-7.0, 1.8, START_Z))
	await Fixtures.wait_physics(tree, 2)
	low_player.launch_along(Vector3(0.6, 0.0, -0.8), 10.0, false)
	var in_run: int = await Fixtures.wait_until(tree, func() -> bool: return low_player.state_machine.current.name == &"WallRun", 20)
	check.call(in_run >= 0, "landing scenario: WallRun starts low over the floor (%d)" % in_run)
	var landed: int = await Fixtures.wait_until(tree, func() -> bool: return low_player.state_machine.current.name == &"Run" or low_player.state_machine.current.name == &"Idle", 60)
	check.call(landed >= 0 and low_player.is_grounded(), "landing during WallRun goes to Run or Idle (%s)" % low_player.state_machine.current.name)
	await _free(tree, parts_b)


## Waits until the player has touched the wall this very tick (wall_contact_age 0) or `ticks` ran out. True on contact.
func _wait_contact(tree: SceneTree, player: PlayerController, ticks: int) -> bool:
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return player.wall_contact_age == 0.0, ticks)
	return waited >= 0


func _scenario_wall_jump_from_run(tree: SceneTree, check: Callable) -> void:
	var jumped: Array[int] = [0]
	var on_jumped: Callable = func(_p: Vector3, _d: Vector3) -> void: jumped[0] += 1
	EventBus.wall_jumped.connect(on_jumped)
	var parts: Array = await _setup(tree, 0, -7.0)
	var player: PlayerController = parts[3] as PlayerController
	var animator: MannequinAnimator = player.get_node("MannequinAnimator") as MannequinAnimator
	_launch_at_pad(player, 10.0)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallRun", 20)
	await Fixtures.wait_physics(tree, 6)
	Input.action_press(&"jump")
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallJump", 6)
	check.call(waited >= 0, "a jump press during WallRun enters WallJump (%d)" % waited)
	var normal: Vector3 = player.wall_normal
	var flat: Vector3 = Vector3(player.move_velocity.x, 0.0, player.move_velocity.z)
	check.call(flat.dot(normal) > 0.5 * flat.length(), "the first WallJump tick points away from the wall (out %.2f of %.2f m/s)" % [flat.dot(normal), flat.length()])
	check.call(player.vertical_speed > 0.0, "and upward (%.2f m/s)" % player.vertical_speed)
	check.call(player.air_control_lock_timer > 0.0, "air control is locked (%.2f s)" % player.air_control_lock_timer)
	check.call(player.wall_run_cooldown_timer > 0.0, "the wall-run cooldown runs after the jump (%.2f s)" % player.wall_run_cooldown_timer)
	check.call(jumped[0] == 1, "wall_jumped fired once (%d)" % jumped[0])
	check.call(animator.last_travel == &"Jump", "the animator travelled to Jump (%s)" % animator.last_travel)
	var base_y: float = player.global_position.y
	var apex: float = base_y
	for i: int in 90:
		await tree.physics_frame
		apex = maxf(apex, player.global_position.y)
		if player.vertical_speed <= 0.0:
			break
	Input.action_release(&"jump")
	check.call(absf((apex - base_y) - player.config.wall_jump_height) < 0.4, "the held kick rises %.2f m (wall_jump_height %.2f, within 0.4)" % [apex - base_y, player.config.wall_jump_height])
	var regrabbed: bool = await _ever_in(tree, player, &"WallRun", 10)
	check.call(not regrabbed, "no wall-run re-grab right after the wall-jump")
	EventBus.wall_jumped.disconnect(on_jumped)
	await _free(tree, parts)


func _scenario_wall_jump_pads(tree: SceneTree, check: Callable) -> void:
	# A WALL_JUMP pad: a slow approach touches it, a jump press kicks off.
	var parts: Array = await _setup(tree, 1, -2.0)
	var player: PlayerController = parts[3] as PlayerController
	var panel: Node = (parts[2] as WallPad).get_node("Panel")
	check.call(panel.is_in_group(&"wall_jump_surface") and not panel.is_in_group(&"wall_run_surface"), "an active WALL_JUMP pad puts its panel in group wall_jump_surface only")
	player.launch_along(Vector3(0.2, 0.2, -0.8), 6.0, false)
	var touched: bool = await _wait_contact(tree, player, 40)
	check.call(touched, "the player touches the wall-jump pad")
	Input.action_press(&"jump")
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallJump", 6)
	Input.action_release(&"jump")
	check.call(waited >= 0, "a jump press in the air against a wall-jump pad enters WallJump (%d)" % waited)
	var no_run: bool = not (await _ever_in(tree, player, &"WallRun", 10))
	check.call(no_run, "a wall-jump pad never starts a wall-run")
	await _free(tree, parts)

	# A WALL_RUN pad without speed: a jump press is no wall-jump (the run needs the speed).
	var run_parts: Array = await _setup(tree, 0, -2.0)
	var slow: PlayerController = run_parts[3] as PlayerController
	slow.teleport(Vector3(-2.0, 2.5, 1.4))
	await Fixtures.wait_physics(tree, 2)
	slow.launch_along(Vector3(0.2, 0.2, -0.8), 4.0, false)
	touched = await _wait_contact(tree, slow, 40)
	check.call(touched, "the slow player touches the wall-run pad")
	Input.action_press(&"jump")
	var kicked: bool = await _ever_in(tree, slow, &"WallJump", 8)
	Input.action_release(&"jump")
	check.call(not kicked, "a jump press against a wall-run pad without speed is no wall-jump")
	await _free(tree, run_parts)

	# A plain wall.
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var wall: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(12.0, 4.0, 0.5), Vector3(0.0, 2.0, 0.0))
	var plain: PlayerController = Fixtures.spawn_player(tree.root, Vector3(-2.0, 2.0, START_Z))
	await Fixtures.wait_physics(tree, 3)
	plain.launch_along(Vector3(0.2, 0.2, -0.8), 6.0, false)
	touched = await _wait_contact(tree, plain, 40)
	check.call(touched, "the player touches the plain wall")
	Input.action_press(&"jump")
	kicked = await _ever_in(tree, plain, &"WallJump", 8)
	Input.action_release(&"jump")
	check.call(not kicked, "a plain wall never starts a WallJump")
	await _free(tree, [floor_body, wall, plain])


func _scenario_lean(tree: SceneTree, check: Callable) -> void:
	var parts: Array = await _setup(tree, 0, -7.0)
	var player: PlayerController = parts[3] as PlayerController
	var mannequin: Node3D = player.get_node("VisualRoot/Mannequin") as Node3D
	_launch_at_pad(player, 10.0)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallRun", 20)
	await Fixtures.wait_physics(tree, 10)
	var toward_wall: float = mannequin.global_basis.y.normalized().dot(-player.wall_normal)
	# 05.1-03: the roll lean is clamped by head clearance (about 4.4 degrees instead of wall_run_lean_deg 18), so the check asks only
	# for a tilt toward the wall, not for a minimum angle.
	check.call(toward_wall > 0.0, "during WallRun the body tilts toward the wall (up dot -normal = %.3f)" % toward_wall)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name != &"WallRun", 80)
	await Fixtures.wait_physics(tree, 18)
	var upright: float = mannequin.global_basis.y.normalized().dot(-player.wall_normal)
	check.call(absf(upright) < 0.02, "0.3 s after the run the body is upright again (%.3f)" % upright)
	await _free(tree, parts)
