extends RefCounted
## CAM-02 / D-09 / D-10: the aim hold. Holding `aim` sets PlayerController.aiming on the same physics tick, announces
## EventBus.aim_changed once per change and pins VisualRoot's yaw to the camera's flat forward with no smoothing. While
## aiming, face() and face_now() do nothing (Dash keeps the crosshair facing), movement steers by the rig's true yaw
## (W runs along the crosshair, A and D strafe), and jump and dash still work. Without a camera aiming changes no
## facing and raises no error. Every expectation derives from player.config. Actions are released and nodes freed at
## the end of each scenario.

const Fixtures := preload("res://tests/fixtures.gd")
const FACING_TOLERANCE_DEG: float = 1.0
const STEER_TOLERANCE_DEG: float = 10.0
const DASH_TOLERANCE_DEG: float = 5.0
const SPEED_TOLERANCE: float = 0.1
const SETTLE_FRAMES: int = 60
const TURN_BACK_FRAMES: int = 30
## SceneTree.physics_frame fires before the tick's _physics_process, so one full tick needs two awaited frames.
const TICK_FRAMES: int = 2

var _bus: Node
var _aim_events: Array[bool] = []
var _on_aim: Callable
var _floor: StaticBody3D
var _rig: CameraRig


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	await tree.process_frame
	await _scenario_hold_and_facing(tree, check)
	await _scenario_strafe(tree, check)
	await _scenario_dash_keeps_facing(tree, check)
	await _scenario_release_hands_back(tree, check)
	await _scenario_no_camera(tree, check)
	await _scenario_speed(tree, check)
	await _scenario_jump_and_dash(tree, check)


# (a) + (b): the flag, the bus fact and the camera-locked facing without smoothing.
func _scenario_hold_and_facing(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	check.call(not player.aiming, "(a) not aiming before the hold")
	Fixtures.send_action_event(&"aim", true)
	await Fixtures.wait_physics(tree, TICK_FRAMES)
	check.call(player.aiming, "(a) the hold sets aiming on the first physics tick")
	check.call(_aim_events == [true], "(a) exactly one aim_changed(true) (got %s)" % [_aim_events])
	await Fixtures.wait_physics(tree, 3)
	check.call(_aim_events == [true], "(a) holding emits no further aim_changed (got %s)" % [_aim_events])
	await Fixtures.wait_process(tree, 1)
	check.call(_facing_error_deg(player, _camera_forward()) < FACING_TOLERANCE_DEG,
		"(b) the facing matches the camera (off by %.2f deg)" % _facing_error_deg(player, _camera_forward()))
	# The camera turns by a big step: the facing follows on the very next tick, no smoothing.
	_rig.yaw += 1.0
	await Fixtures.wait_physics(tree, TICK_FRAMES)
	var expected: Vector3 = Vector3(-sin(_rig.yaw), 0.0, -cos(_rig.yaw))
	check.call(_facing_error_deg(player, expected) < FACING_TOLERANCE_DEG,
		"(b) a camera turn of 1 rad is followed within one tick (off by %.2f deg)" % _facing_error_deg(player, expected))
	await Fixtures.wait_process(tree, 1)
	check.call(_facing_error_deg(player, _camera_forward()) < FACING_TOLERANCE_DEG,
		"(b) the facing still matches the rendered camera (off by %.2f deg)" % _facing_error_deg(player, _camera_forward()))
	await _end(tree, player)


# (c): A strafes along the camera's left while the figure keeps facing the crosshair.
func _scenario_strafe(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	Fixtures.send_action_event(&"aim", true)
	Input.action_press(&"move_left")
	await Fixtures.wait_physics(tree, TURN_BACK_FRAMES)
	await Fixtures.wait_process(tree, 1)
	var left: Vector3 = -_camera_right()
	var velocity: Vector3 = player.move_velocity
	velocity.y = 0.0
	check.call(velocity.length() > 1.0, "(c) the strafe moves the body (speed %.2f)" % velocity.length())
	check.call(rad_to_deg(velocity.angle_to(left)) < STEER_TOLERANCE_DEG,
		"(c) move_left runs along the camera's left (off by %.2f deg)" % rad_to_deg(velocity.angle_to(left)))
	check.call(_facing_error_deg(player, _camera_forward()) < FACING_TOLERANCE_DEG,
		"(c) the figure keeps facing the crosshair while strafing (off by %.2f deg)" % _facing_error_deg(player, _camera_forward()))
	Input.action_release(&"move_left")
	await _end(tree, player)


# (d): a dash in aim goes where the input points and does not turn the figure away from the crosshair.
func _scenario_dash_keeps_facing(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	Fixtures.send_action_event(&"aim", true)
	Input.action_press(&"move_right")
	await Fixtures.wait_physics(tree, 5)
	await Fixtures.tap_action(tree, &"dash")
	check.call(player.state_machine.current.name == &"Dash", "(d) a dash press works while aiming (got %s)" % player.state_machine.current.name)
	var right: Vector3 = _camera_right()
	var direction: Vector3 = player.last_dash_direction
	check.call(rad_to_deg(direction.angle_to(right)) < DASH_TOLERANCE_DEG,
		"(d) the dash goes along the camera's right (off by %.2f deg)" % rad_to_deg(direction.angle_to(right)))
	check.call(_facing_error_deg(player, _camera_forward()) < FACING_TOLERANCE_DEG,
		"(d) the dash leaves the facing on the crosshair (off by %.2f deg)" % _facing_error_deg(player, _camera_forward()))
	Input.action_release(&"move_right")
	await _end(tree, player)


# (e): releasing aim announces once and hands the facing back to face().
func _scenario_release_hands_back(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	Fixtures.send_action_event(&"aim", true)
	await Fixtures.wait_physics(tree, 3)
	Fixtures.send_action_event(&"aim", false)
	await Fixtures.wait_physics(tree, TICK_FRAMES)
	check.call(not player.aiming, "(e) releasing the hold clears aiming on the next tick")
	check.call(_aim_events == [true, false], "(e) exactly one aim_changed(false) (got %s)" % [_aim_events])
	Input.action_press(&"move_right")
	await Fixtures.wait_physics(tree, TURN_BACK_FRAMES)
	await Fixtures.wait_process(tree, 1)
	var right: Vector3 = _camera_right()
	check.call(_facing_error_deg(player, right) < 15.0,
		"(e) after the release the figure turns toward the movement again (off by %.2f deg)" % _facing_error_deg(player, right))
	Input.action_release(&"move_right")
	await _end(tree, player)


# (f): without a camera aiming changes no facing and raises no error; the release hands facing back.
func _scenario_no_camera(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	player.visual_root.rotation.y = 1.0
	_rig.free()
	_rig = null
	await Fixtures.wait_physics(tree, 2)
	check.call(tree.root.get_viewport().get_camera_3d() == null, "(f) the viewport has no camera")
	Fixtures.send_action_event(&"aim", true)
	await Fixtures.wait_physics(tree, 5)
	check.call(player.aiming, "(f) aiming is set without a camera")
	check.call(is_equal_approx(player.visual_root.rotation.y, 1.0), "(f) aiming without a camera leaves the facing alone (yaw %.3f)" % player.visual_root.rotation.y)
	Fixtures.send_action_event(&"aim", false)
	Input.action_press(&"move_right")
	await Fixtures.wait_physics(tree, TURN_BACK_FRAMES)
	var facing: Vector3 = player.visual_root.global_basis.z
	check.call(facing.dot(Vector3.RIGHT) > 0.95, "(f) after the release face() turns the figure toward the movement (facing %s)" % facing)
	Input.action_release(&"move_right")
	await _end(tree, player)


# D-10: ground speed settles at run_speed, run_speed * aim_speed_factor, and the back factor on top for move_back.
func _scenario_speed(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	var config: MovementConfig = player.config
	var aim_speed: float = config.run_speed * config.aim_speed_factor
	var plain: float = await _settled_speed(tree, player, &"move_forward", false)
	check.call(absf(plain - config.run_speed) < SPEED_TOLERANCE, "(g) not aiming: %.3f m/s settles at run_speed %.3f" % [plain, config.run_speed])
	var forward: float = await _settled_speed(tree, player, &"move_forward", true)
	check.call(absf(forward - aim_speed) < SPEED_TOLERANCE, "(g) aiming, move_forward: %.3f m/s settles at run_speed * aim_speed_factor %.3f" % [forward, aim_speed])
	var strafe: float = await _settled_speed(tree, player, &"move_right", true)
	check.call(absf(strafe - aim_speed) < SPEED_TOLERANCE, "(g) aiming, move_right: %.3f m/s, a strafe is not slowed by the back factor (%.3f)" % [strafe, aim_speed])
	var back_speed: float = aim_speed * config.aim_back_speed_factor
	var back: float = await _settled_speed(tree, player, &"move_back", true)
	check.call(absf(back - back_speed) < SPEED_TOLERANCE, "(g) aiming, move_back: %.3f m/s settles at aim speed * aim_back_speed_factor %.3f" % [back, back_speed])
	check.call(back < strafe and strafe < plain, "(g) back (%.2f) < strafe (%.2f) < plain run (%.2f)" % [back, strafe, plain])
	# The target is a pure function of the direction: half behind the facing lands between the strafe and the back speed.
	Fixtures.send_action_event(&"aim", true)
	await Fixtures.wait_physics(tree, TICK_FRAMES)
	var facing: Vector3 = player.visual_root.global_basis.z
	var diagonal: float = player.ground_target_speed(-facing + _camera_right())
	check.call(diagonal < aim_speed and diagonal > back_speed, "(g) a diagonal back step (%.3f) sits between %.3f and %.3f" % [diagonal, back_speed, aim_speed])
	check.call(is_equal_approx(player.ground_target_speed(Vector3.ZERO), aim_speed), "(g) a zero direction returns the aim forward speed")
	await _end(tree, player)


# D-10: aim never blocks movement. A jump enters Jump, a dash enters Dash at the unchanged dash speed.
func _scenario_jump_and_dash(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	var config: MovementConfig = player.config
	Fixtures.send_action_event(&"aim", true)
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 10)
	Input.action_press(&"jump")
	await Fixtures.wait_physics(tree, 4)
	check.call(player.state_machine.current.name == &"Jump", "(h) a jump press enters Jump while aiming (got %s)" % player.state_machine.current.name)
	check.call(player.vertical_speed > 0.0, "(h) the jump rises while aiming (vertical %.2f)" % player.vertical_speed)
	Input.action_release(&"jump")
	var landed: int = await Fixtures.wait_until(tree, func() -> bool: return player.is_grounded() and absf(player.vertical_speed) < 0.01, 240)
	check.call(landed >= 0, "(h) the aim jump lands again")
	await Fixtures.wait_physics(tree, 30)
	await Fixtures.tap_action(tree, &"dash")
	check.call(player.state_machine.current.name == &"Dash", "(h) a dash press enters Dash while aiming (got %s)" % player.state_machine.current.name)
	await Fixtures.wait_physics(tree, 2)
	check.call(absf(player.horizontal_speed() - config.dash_speed) < SPEED_TOLERANCE,
		"(h) the aim dash runs at dash_speed %.2f (got %.2f), unchanged by aim" % [config.dash_speed, player.horizontal_speed()])
	check.call(player.aiming, "(h) the player is still aiming after jump and dash")
	Input.action_release(&"move_forward")
	await _end(tree, player)


## Holds `action` (with aim on or off) for SETTLE_FRAMES and returns the ground speed, then releases it and lets the body stop.
func _settled_speed(tree: SceneTree, player: PlayerController, action: StringName, aim: bool) -> float:
	Fixtures.send_action_event(&"aim", aim)
	Input.action_press(action)
	await Fixtures.wait_physics(tree, SETTLE_FRAMES)
	var speed: float = player.horizontal_speed()
	Input.action_release(action)
	await Fixtures.wait_physics(tree, SETTLE_FRAMES)
	return speed


## Floor, player, camera rig and the aim_changed counter for one scenario.
func _begin(tree: SceneTree) -> PlayerController:
	_aim_events = []
	_on_aim = func(active: bool) -> void: _aim_events.append(active)
	_bus.aim_changed.connect(_on_aim)
	_floor = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.5, 0.0))
	_rig = Fixtures.spawn_camera_rig(tree.root, player)
	return player


func _end(tree: SceneTree, player: PlayerController) -> void:
	Fixtures.send_action_event(&"aim", false)
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"dash", &"jump"]:
		Input.action_release(action)
	await Fixtures.wait_physics(tree, 2)
	_bus.aim_changed.disconnect(_on_aim)
	player.queue_free()
	if _rig != null and is_instance_valid(_rig):
		_rig.queue_free()
	_rig = null
	_floor.queue_free()
	await Fixtures.wait_physics(tree, 2)


## The rendered camera's flat forward.
func _camera_forward() -> Vector3:
	var camera: Camera3D = _rig.get_viewport().get_camera_3d()
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	return forward.normalized()


## The rendered camera's flat right.
func _camera_right() -> Vector3:
	var camera: Camera3D = _rig.get_viewport().get_camera_3d()
	var right: Vector3 = camera.global_basis.x
	right.y = 0.0
	return right.normalized()


## Angle in degrees between the figure's facing (VisualRoot +Z) and `direction`, both flattened.
func _facing_error_deg(player: PlayerController, direction: Vector3) -> float:
	var facing: Vector3 = player.visual_root.global_basis.z
	facing.y = 0.0
	var wanted: Vector3 = direction
	wanted.y = 0.0
	return rad_to_deg(facing.normalized().angle_to(wanted.normalized()))
