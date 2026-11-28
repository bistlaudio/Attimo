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
	# The smoke tests check the designed launch numbers; the feel-test multiplier (kit_launch_scale, 1.8 in the shipped config) is
	# neutral here. test_player_launch checks the multiplier itself.
	player.config.kit_launch_scale = 1.0
	player.position = position
	root.add_child(player)
	player.reset_physics_interpolation()
	return player


## Signed distance in m of a Mannequin bone ("head" by default) from a wall face given by a point on it and its outward normal (05.1-03,
## D-06; 05.1-09 D-40 compares head and hips). Positive in front of the face. NAN when the skeleton or the bone is missing.
static func bone_to_wall_distance(player: PlayerController, wall_point: Vector3, wall_normal: Vector3, bone_name: String = "head") -> float:
	var mannequin: Node = player.get_node_or_null("VisualRoot/Mannequin")
	if mannequin == null:
		return NAN
	var skeletons: Array[Node] = mannequin.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return NAN
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	var bone: int = skeleton.find_bone(bone_name)
	if bone < 0:
		return NAN
	var head: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
	return (head - wall_point).dot(wall_normal.normalized())


## Signed local y in m of the player's feet (its origin) above the top face of `deck_body` (05.1-04, D-07): the player origin in the
## deck's frame minus the top of the deck's first BoxShape3D (shape position y + half its height). NAN without a box shape.
static func deck_offset(player: PlayerController, deck_body: CollisionObject3D) -> float:
	var top: float = NAN
	for child: Node in deck_body.get_children():
		var shape_node: CollisionShape3D = child as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			top = shape_node.position.y + (shape_node.shape as BoxShape3D).size.y * 0.5
			break
	if is_nan(top):
		return NAN
	return (deck_body.global_transform.affine_inverse() * player.global_position).y - top


const PROBE_SOURCE: String = "extends Node\nvar hook: Callable\nfunc _physics_process(_delta: float) -> void:\n\tif hook.is_valid():\n\t\thook.call()\n"


## A plain Node under `root` that calls `hook` every physics tick at `priority` (05.1-04). Priority 50 samples after the player
## (0) has moved and before a reference-frame carrier (100) moves, so the rider and the deck pose of one tick are read together.
static func spawn_physics_probe(root: Node, priority: int, hook: Callable) -> Node:
	var script: GDScript = GDScript.new()
	script.source_code = PROBE_SOURCE
	script.reload()
	var probe: Node = Node.new()
	probe.set_script(script)
	probe.set(&"hook", hook)
	probe.process_physics_priority = priority
	root.add_child(probe)
	return probe


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


## The Mannequin's AnimationTree under the player's VisualRoot.
static func animation_tree(player: PlayerController) -> AnimationTree:
	return player.get_node("VisualRoot/Mannequin/AnimationTree") as AnimationTree


## The playback object of the tree's state machine (the Land overlay is not a state).
static func playback(player: PlayerController) -> AnimationNodeStateMachinePlayback:
	return animation_tree(player).get(MannequinAnimator.P_PLAYBACK) as AnimationNodeStateMachinePlayback


## The Locomotion BlendSpace2D position: x strafe, y forward weight (idle 0 .. run 1).
static func locomotion_blend(player: PlayerController) -> Vector2:
	return animation_tree(player).get(MannequinAnimator.P_LOCOMOTION) as Vector2


## True while the Land OneShot overlay plays.
static func land_active(player: PlayerController) -> bool:
	return bool(animation_tree(player).get(MannequinAnimator.P_LAND_ACTIVE))


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


## Awaits process frames until Engine.time_scale is back at 1.0, or `timeout_seconds` of REAL time have passed. The release hitstop of the
## Loader is a real-time timer (TimeFx.pulse), so a fixed count of physics ticks races with it when ticks bunch up under machine load; waiting
## on the condition does not. Returns whether the time scale is 1.0.
static func wait_time_scale_restored(tree: SceneTree, timeout_seconds: float = 2.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Engine.time_scale != 1.0 and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	return Engine.time_scale == 1.0


## Awaits physics frames until `condition` returns true. Returns the frames waited, or -1 on timeout.
static func wait_until(tree: SceneTree, condition: Callable, max_physics_frames: int) -> int:
	var waited: int = 0
	while waited <= max_physics_frames:
		if condition.call():
			return waited
		await tree.physics_frame
		waited += 1
	return -1


## Holds `action` for `seconds` of physics time, then releases it.
static func hold_action(tree: SceneTree, action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await wait_physics(tree, ceili(seconds * Engine.physics_ticks_per_second))
	Input.action_release(action)


## Instances the scene at `path` under `root` at `position`.
static func spawn_scene(root: Node, path: String, position: Vector3) -> Node3D:
	var scene: PackedScene = load(path) as PackedScene
	var node: Node3D = scene.instantiate() as Node3D
	node.position = position
	root.add_child(node)
	return node


## Sets the arm energy of `player` in whole steps (0 .. 12) through its owner, ArmEnergy (the only writer of the value). reset_to
## also zeroes the tick accumulator, so a test never inherits half a passive tick.
static func set_energy(player: PlayerController, steps: int) -> void:
	player.arm_energy.reset_to(steps)


## Gives back every TimeFx request, so a test that held the Loader cannot leave the world in slow motion.
static func restore_time() -> void:
	var time_fx: Node = Engine.get_main_loop().root.get_node("TimeFx")
	time_fx.call(&"clear_all")


## A plain Trigger under `root` that starts `active` (05.1-13): the signal driver for logic-node tests, replacing the cut lever.
static func spawn_signal_driver(root: Node, active: bool = false) -> Trigger:
	var source: Trigger = Trigger.new()
	source.start_active = active
	root.add_child(source)
	return source


## A bare Interactable that accepts near contact (05.1-13): the near-contact target, replacing the cut lever. It sits on a holder
## Node3D at `at` (the holder is the Interactable's parent, free it to remove the target) with a 0.6 m hit body on the Interactable layer.
static func spawn_near_target(root: Node, at: Vector3) -> Interactable:
	var holder: Node3D = Node3D.new()
	holder.position = at
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.6, 0.6, 0.6)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0.0, 1.1, 0.0)
	holder.add_child(body)
	var target: Interactable = Interactable.new()
	target.accepts_near = true
	target.hit_body = body
	target.aim_point = body
	holder.add_child(target)
	root.add_child(holder)
	return target
