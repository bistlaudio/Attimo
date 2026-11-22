extends RefCounted
## CAM-04 / D-11, D-12: three shared glow stages on every Interactable. Idle at rest, aim while aiming, target when it
## is the assist target. Only Interactables use the three glow resources.

const Fixtures := preload("res://tests/fixtures.gd")

const LEVER_SCENE: String = "res://scenes/mechanisms/lever.tscn"
const GYM_SCENE: String = "res://scenes/test/movement_gym.tscn"
const GLOW_IDLE: String = "res://resources/mechanisms/glow_idle.tres"
const GLOW_AIM: String = "res://resources/mechanisms/glow_aim.tres"
const GLOW_TARGET: String = "res://resources/mechanisms/glow_target.tres"
const SHIPPED_TPS: int = 60
const AIM_SETTLE_FRAMES: int = 180

var _nodes: Array[Node] = []
var _player: PlayerController
var _rig: CameraRig


func run(tree: SceneTree, check: Callable) -> void:
	# The runner calls us from _initialize, before the root is inside the tree.
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	for path: String in [GLOW_IDLE, GLOW_AIM, GLOW_TARGET]:
		check.call(ResourceLoader.exists(path), "%s exists" % path)
	if not ResourceLoader.exists(GLOW_IDLE) or not ResourceLoader.exists(GLOW_AIM) or not ResourceLoader.exists(GLOW_TARGET):
		return
	await _scenario_stages(tree, check)
	await _scenario_gym(tree, check)


func _lens(lever: Node) -> MeshInstance3D:
	return lever.get_node("Handle/GlowLens") as MeshInstance3D


func _line_point(distance: float) -> Vector3:
	var camera: Camera3D = _rig.camera
	var forward: Vector3 = -camera.global_basis.z.normalized()
	var start: Vector3 = CameraRig.aim_ray_start(camera.global_position, forward, _rig.global_position)
	var best: Vector3 = start
	var best_error: float = INF
	var t: float = 0.0
	while t < 80.0:
		var point: Vector3 = start + forward * t
		var error: float = absf(point.distance_to(_player.global_position) - distance)
		if error < best_error:
			best_error = error
			best = point
		t += 0.02
	return best


func _move_lever(lever: Node3D, point: Vector3) -> void:
	var interactable: Interactable = lever.get_node("Interactable") as Interactable
	lever.global_position = point - (interactable.hit_body.global_position - lever.global_position)


func _scenario_stages(tree: SceneTree, check: Callable) -> void:
	var idle: Material = load(GLOW_IDLE) as Material
	var aim: Material = load(GLOW_AIM) as Material
	var target: Material = load(GLOW_TARGET) as Material
	_nodes.append(Fixtures.spawn_floor(tree.root, Vector3(200.0, 1.0, 200.0)))
	_player = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	_nodes.append(_player)
	_rig = Fixtures.spawn_camera_rig(tree.root, _player)
	_nodes.append(_rig)
	_rig.pitch = 0.0
	var lever: Node3D = Fixtures.spawn_scene(tree.root, LEVER_SCENE, Vector3(40.0, 0.0, 40.0))
	var second: Node3D = Fixtures.spawn_scene(tree.root, LEVER_SCENE, Vector3(-40.0, 0.0, 40.0))
	_nodes.append(lever)
	_nodes.append(second)
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.wait_process(tree, 3)
	check.call(_lens(lever).material_override == idle, "(1) the lens glows with glow_idle at rest")
	check.call(_lens(lever).material_override == _lens(second).material_override, "(1) two levers share the same material instance")
	Input.action_press(&"aim")
	var frames: int = 0
	while _rig.aim_weight < 0.999 and frames < AIM_SETTLE_FRAMES:
		await tree.process_frame
		frames += 1
	await Fixtures.wait_physics(tree, 6)
	check.call(_lens(lever).material_override == aim, "(2) the lens glows with glow_aim while aiming")
	_move_lever(lever, _line_point(8.0))
	await Fixtures.wait_physics(tree, 8)
	check.call(_lens(lever).material_override == target, "(3) the targeted lever glows with glow_target")
	check.call(_lens(second).material_override == aim, "(3) the other lever stays at glow_aim")
	_move_lever(lever, Vector3(40.0, 0.0, 40.0))
	await Fixtures.wait_physics(tree, 20)
	check.call(_lens(lever).material_override == aim, "(4) a lost target falls back to glow_aim")
	Input.action_release(&"aim")
	await Fixtures.wait_physics(tree, 6)
	check.call(_lens(lever).material_override == idle, "(5) the glow is back to glow_idle when aim ends")
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
	await tree.process_frame


func _scenario_gym(tree: SceneTree, check: Callable) -> void:
	var glows: Array[Material] = [load(GLOW_IDLE) as Material, load(GLOW_AIM) as Material, load(GLOW_TARGET) as Material]
	var gym: Node = (load(GYM_SCENE) as PackedScene).instantiate()
	tree.root.add_child(gym)
	await Fixtures.wait_physics(tree, 3)
	var listed: Array[MeshInstance3D] = []
	for node: Node in tree.get_nodes_in_group(&"interactable"):
		var interactable: Interactable = node as Interactable
		if interactable != null and gym.is_ancestor_of(interactable):
			listed.append_array(interactable.glow_meshes)
	var glowing: int = 0
	var stray: PackedStringArray = PackedStringArray()
	var stack: Array[Node] = [gym]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh != null and glows.has(mesh.material_override):
			glowing += 1
			if not listed.has(mesh):
				stray.append(str(gym.get_path_to(mesh)))
	check.call(glowing >= 1, "(6) the gym has glowing interactables (%d)" % glowing)
	check.call(stray.is_empty(), "(6) every glow mesh belongs to an Interactable (stray: %s)" % ", ".join(stray))
	gym.queue_free()
	await tree.process_frame
	await tree.process_frame
