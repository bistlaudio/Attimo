extends RefCounted
## Shared helpers for smoke tests. Load with: const Fixtures := preload("res://tests/fixtures.gd")
## Phase 2 players move for real, so tests build their own ground with spawn_floor / spawn_box.

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"


## A static box on the World layer: one BoxShape3D, no mesh. `center` is the middle of the box.
static func spawn_box(root: Node, size: Vector3, center: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	root.add_child(body)
	return body


## A flat floor whose top face is centered at `top_center` (default: y = 0 under the origin).
static func spawn_floor(root: Node, size: Vector3 = Vector3(60, 1, 60), top_center: Vector3 = Vector3.ZERO) -> StaticBody3D:
	return spawn_box(root, size, top_center - Vector3(0.0, size.y * 0.5, 0.0))


static func spawn_player(root: Node, position: Vector3) -> PlayerController:
	var scene: PackedScene = load(PLAYER_SCENE) as PackedScene
	var player: PlayerController = scene.instantiate() as PlayerController
	player.position = position
	root.add_child(player)
	player.reset_physics_interpolation()
	return player


const CAMERA_RIG_SCENE: String = "res://scenes/camera/camera_rig.tscn"


## Instances the CameraRig as a sibling of `target` under `root`. Mouse capture is off (headless).
static func spawn_camera_rig(root: Node, target: Node3D) -> CameraRig:
	var scene: PackedScene = load(CAMERA_RIG_SCENE) as PackedScene
	var rig: CameraRig = scene.instantiate() as CameraRig
	rig.target = target
	rig.require_mouse_capture = false
	root.add_child(rig)
	# Default settings, so no test depends on the developer's saved user://settings.cfg (02-10).
	rig.apply_settings(CameraSettings.new())
	rig.snap_to_target()
	return rig


## True when the player is not rising and a walkable floor is hit within `seconds` of predicted motion
## (current horizontal velocity, current fall speed, fall gravity). Tests use it to time a press shortly
## before landing; the game itself no longer predicts landings.
static func will_land_within(player: PlayerController, seconds: float) -> bool:
	if player.vertical_speed > 0.0 or seconds <= 0.0:
		return false
	var config: MovementConfig = player.config
	var drop: float = absf(player.vertical_speed) * seconds + 0.5 * config.fall_gravity() * seconds * seconds
	var motion: Vector3 = player.move_velocity * seconds + Vector3.DOWN * drop
	var hit: KinematicCollision3D = KinematicCollision3D.new()
	if not player.test_move(player.global_transform, motion, hit):
		return false
	return hit.get_normal().angle_to(Vector3.UP) <= player.floor_max_angle


## Sends an InputEventAction through the input pipeline (reaches _input, unlike Input.action_press).
static func send_action_event(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## Sends a relative mouse motion through the input pipeline.
static func send_mouse_motion(relative: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.relative = relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()


static func wait_physics(tree: SceneTree, frames: int) -> void:
	for i: int in frames:
		await tree.physics_frame


static func wait_process(tree: SceneTree, frames: int) -> void:
	for i: int in frames:
		await tree.process_frame


static func tap_action(tree: SceneTree, action: StringName, frames: int = 2) -> void:
	Input.action_press(action)
	await wait_physics(tree, frames)
	Input.action_release(action)


## Awaits physics frames until `condition` returns true. Returns the frames waited, or -1 on timeout.
static func wait_until(tree: SceneTree, condition: Callable, max_physics_frames: int) -> int:
	var waited: int = 0
	while waited <= max_physics_frames:
		if condition.call():
			return waited
		await tree.physics_frame
		waited += 1
	return -1
