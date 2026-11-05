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
