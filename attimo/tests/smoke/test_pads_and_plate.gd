extends RefCounted
## MECH-04 I (D-06): the crumbling platform (the pressure plate was cut in plan 05.1-06, D-09; the bounce pad and boost ring became
## Impulse kit objects in plan 05.1-16, see test_impulse). Driven by an active Trigger stub. Real player, real geometry, 60 Hz.

const Fixtures := preload("res://tests/fixtures.gd")

const CRUMBLE_SCENE: String = "res://scenes/mechanisms/crumbling_platform.tscn"
const SHIPPED_TPS: int = 60


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_crumble(tree, check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _on_source() -> Trigger:
	var source: Trigger = Trigger.new()
	source.start_active = true
	return source


func _instance(path: String, source: Trigger, at: Vector3) -> Node3D:
	var node: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	node.set("source", source)
	node.position = at
	return node


func _crumble(tree: SceneTree, source: Trigger, at: Vector3) -> CrumblingPlatform:
	var platform: CrumblingPlatform = _instance(CRUMBLE_SCENE, source, at) as CrumblingPlatform
	platform.shake_time = 0.3
	platform.fall_time = 0.3
	platform.respawn_delay = 1.5
	tree.root.add_child(platform)
	return platform


func _scenario_crumble(tree: SceneTree, check: Callable) -> void:
	var source: Trigger = _on_source()
	tree.root.add_child(source)
	var platform: CrumblingPlatform = _crumble(tree, source, Vector3(0.0, 5.0, 0.0))
	var shape: CollisionShape3D = platform.get_node("Body/CollisionShape3D") as CollisionShape3D
	await Fixtures.wait_physics(tree, 5)
	check.call(platform.phase == CrumblingPlatform.Phase.IDLE and not shape.disabled, "crumble: IDLE with collision on at the start")
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 5.5, 0.0))
	await Fixtures.wait_until(tree, func() -> bool: return platform.phase != CrumblingPlatform.Phase.IDLE, 60)
	check.call(platform.phase == CrumblingPlatform.Phase.SHAKE, "crumble: the first step starts SHAKE")
	await Fixtures.wait_physics(tree, 6)
	check.call(not shape.disabled and player.global_position.y > 5.0, "crumble: the body still collides during SHAKE (player y %.2f)" % player.global_position.y)
	await Fixtures.wait_physics(tree, ceili((platform.shake_time + platform.fall_time) * SHIPPED_TPS) + 6)
	check.call(shape.disabled, "crumble: after shake_time + fall_time the collision shape is disabled")
	check.call(player.global_position.y < 4.0, "crumble: an unsupported player falls through (y %.2f)" % player.global_position.y)
	check.call(platform.phase == CrumblingPlatform.Phase.GONE or platform.phase == CrumblingPlatform.Phase.FALL, "crumble: the platform is gone (%d)" % platform.phase)
	# Someone inside the footprint keeps it gone beyond respawn_delay.
	var hold_ticks: int = ceili((platform.respawn_delay + 0.7) * SHIPPED_TPS)
	for i: int in hold_ticks:
		player.global_position = Vector3(0.0, 5.5, 0.0)
		player.move_velocity = Vector3.ZERO
		player.vertical_speed = 0.0
		await Fixtures.wait_physics(tree, 1)
	check.call(shape.disabled and platform.phase == CrumblingPlatform.Phase.GONE, "crumble: it does not respawn while a player overlaps the footprint")
	player.global_position = Vector3(20.0, 0.0, 0.0)
	await Fixtures.wait_physics(tree, 40)
	check.call(not shape.disabled and platform.phase == CrumblingPlatform.Phase.IDLE, "crumble: after respawn_delay with an empty footprint the collision is back")
	# reset() restores IDLE with collision on.
	platform.phase = CrumblingPlatform.Phase.GONE
	shape.disabled = true
	platform.reset()
	await Fixtures.wait_physics(tree, 2)
	check.call(platform.phase == CrumblingPlatform.Phase.IDLE and not shape.disabled, "crumble: reset() restores IDLE with collision on")
	await _free(tree, [player, platform, source])
