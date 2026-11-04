extends RefCounted
## Shared helpers for smoke tests. Load with: const Fixtures := preload("res://tests/fixtures.gd")
## No floor helper: Phase 1 has no movement physics, so player tests need no ground (D-09).

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"


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
