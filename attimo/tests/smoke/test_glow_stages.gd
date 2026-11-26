extends RefCounted
## CAM-04 / D-11, D-46: two shared glow stages on every Interactable (the shot ready stage left with the shot, D-45): idle, and target when
## set_glow_stage(TARGET) marks it. Only Interactables use the two glow resources.

const Fixtures := preload("res://tests/fixtures.gd")

const LEVER_SCENE: String = "res://scenes/mechanisms/lever.tscn"
const GYM_SCENE: String = "res://scenes/test/movement_gym.tscn"
const GLOW_IDLE: String = "res://resources/mechanisms/glow_idle.tres"
const GLOW_TARGET: String = "res://resources/mechanisms/glow_target.tres"
const SHIPPED_TPS: int = 60

var _nodes: Array[Node] = []
var _player: PlayerController


func run(tree: SceneTree, check: Callable) -> void:
	# The runner calls us from _initialize, before the root is inside the tree.
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	for path: String in [GLOW_IDLE, GLOW_TARGET]:
		check.call(ResourceLoader.exists(path), "%s exists" % path)
	check.call(not ResourceLoader.exists("res://resources/mechanisms/glow_aim.tres"), "the old glow_aim.tres is gone")
	check.call(not ResourceLoader.exists("res://resources/mechanisms/glow_shot_ready.tres"), "D-46: glow_shot_ready.tres is gone")
	if not ResourceLoader.exists(GLOW_IDLE) or not ResourceLoader.exists(GLOW_TARGET):
		return
	await _scenario_stages(tree, check)
	await _scenario_gym(tree, check)


func _lens(lever: Node) -> MeshInstance3D:
	return lever.get_node("Handle/GlowLens") as MeshInstance3D


func _scenario_stages(tree: SceneTree, check: Callable) -> void:
	var idle: Material = load(GLOW_IDLE) as Material
	var target: Material = load(GLOW_TARGET) as Material
	_nodes.append(Fixtures.spawn_floor(tree.root, Vector3(200.0, 1.0, 200.0)))
	var lever: Node3D = Fixtures.spawn_scene(tree.root, LEVER_SCENE, Vector3(40.0, 0.0, 40.0))
	var second: Node3D = Fixtures.spawn_scene(tree.root, LEVER_SCENE, Vector3(-40.0, 0.0, 40.0))
	_nodes.append(lever)
	_nodes.append(second)
	await Fixtures.wait_physics(tree, 2)
	check.call(_lens(lever).material_override == idle, "(1) the lens glows with glow_idle with no hand in the world")
	check.call(_lens(lever).material_override == _lens(second).material_override, "(1) two levers share the same material instance")
	# A player with a hand changes nothing: there is no shot ready stage any more.
	_player = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	_nodes.append(_player)
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.wait_process(tree, 3)
	check.call(_lens(lever).material_override == idle and _lens(second).material_override == idle, "(2) with a player in the world every lever still glows idle")
	var first: Interactable = lever.get_node("Interactable") as Interactable
	first.set_glow_stage(Interactable.GlowStage.TARGET)
	check.call(_lens(lever).material_override == target and first.glow_stage == Interactable.GlowStage.TARGET, "(3) the TARGET stage switches the lens to glow_target")
	check.call(_lens(second).material_override == idle, "(3) the other lever stays at glow_idle")
	first.set_glow_stage(Interactable.GlowStage.IDLE)
	check.call(_lens(lever).material_override == idle, "(4) the IDLE stage restores glow_idle")
	check.call(Interactable.GlowStage.keys() == ["IDLE", "TARGET"], "(5) the glow stages are IDLE and TARGET only (%s)" % str(Interactable.GlowStage.keys()))
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
	await tree.process_frame


func _scenario_gym(tree: SceneTree, check: Callable) -> void:
	var glows: Array[Material] = [load(GLOW_IDLE) as Material, load(GLOW_TARGET) as Material]
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
	check.call(glowing >= 1, "(7) the gym has glowing interactables (%d)" % glowing)
	check.call(stray.is_empty(), "(7) every glow mesh belongs to an Interactable (stray: %s)" % ", ".join(stray))
	gym.queue_free()
	await tree.process_frame
	await tree.process_frame
