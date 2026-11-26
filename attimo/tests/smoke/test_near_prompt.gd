extends RefCounted
## CAM-06 / D-02: an "E" keycap (Crosshair/NearPrompt) floats over the nearest near-contact Interactable in reach. It
## hides during near contact, out of range and for non-accepting interactables, follows HandController.prompt_target, and ignores the mouse.
## The reticle itself is always drawn (no aim hold, no goggle HUD, D-15).

const Fixtures := preload("res://tests/fixtures.gd")

const CROSSHAIR_SCENE: String = "res://scenes/ui/crosshair.tscn"
const SHIPPED_TPS: int = 60
const NEAR_POSITION: Vector3 = Vector3(0.0, 0.0, 1.2)
const PIXEL_TOLERANCE: float = 3.0

var _nodes: Array[Node] = []
var _player: PlayerController
var _rig: CameraRig
var _hand: HandController
var _crosshair: Crosshair
var _prompt: Control


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _begin(tree)
	var interactable: Interactable = _target(tree, NEAR_POSITION)
	await _settle(tree)
	check.call(_prompt != null, "the Crosshair has a NearPrompt child")
	if _prompt == null:
		await _end(tree)
		return
	check.call(_prompt.mouse_filter == Control.MOUSE_FILTER_IGNORE, "NearPrompt ignores the mouse (T-04.1-10)")
	check.call(_hand.prompt_target == interactable, "(1) prompt_target is the target in reach")
	check.call(_prompt.visible, "(1) the prompt shows")
	var camera: Camera3D = tree.root.get_viewport().get_camera_3d()
	check.call(camera != null, "(1) a current camera exists")
	if camera != null:
		var expected: Vector2 = camera.unproject_position(interactable.target_point() + Vector3.UP * 0.35)
		var centre: Vector2 = _prompt.position + _prompt.size * 0.5
		check.call(centre.distance_to(expected) <= PIXEL_TOLERANCE, "(1) the prompt centre sits over the target point (%s vs %s)" % [str(centre), str(expected)])

	# (2) near contact hides it, releasing shows it again.
	Input.action_press(&"interact")
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.wait_process(tree, 2)
	check.call(_hand.prompt_target == null and not _prompt.visible, "(2) the prompt hides during near contact")
	Input.action_release(&"interact")
	await Fixtures.wait_physics(tree, 40)
	await Fixtures.wait_process(tree, 2)
	check.call(_hand.prompt_target != null and _prompt.visible, "(2) the prompt is back after the release")

	# (4) out of range.
	(interactable.get_parent() as Node3D).global_position = Vector3(0.0, 0.0, 4.0)
	await Fixtures.wait_physics(tree, 4)
	await Fixtures.wait_process(tree, 2)
	check.call(_hand.prompt_target == null and not _prompt.visible, "(4) a target 4 m away shows no prompt")
	await _end(tree)

	# (5) nearest of two.
	await _begin(tree)
	var near_target: Interactable = _target(tree, NEAR_POSITION)
	var far_target: Interactable = _target(tree, Vector3(0.0, 0.0, 1.9))
	await _settle(tree)
	check.call(_hand.prompt_target == near_target, "(5) the nearer of two targets gets the prompt")
	check.call(far_target != null, "(5) the second target exists")
	await _end(tree)

	# (6) not accepting.
	await _begin(tree)
	var plain: Interactable = _target(tree, NEAR_POSITION)
	plain.accepts_near = false
	await _settle(tree)
	check.call(_hand.prompt_target == null and not _prompt.visible, "(6) an Interactable without near contact has no prompt")
	await _end(tree)


func _begin(tree: SceneTree) -> void:
	_nodes.clear()
	_nodes.append(Fixtures.spawn_floor(tree.root, Vector3(200.0, 1.0, 200.0)))
	_player = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	_nodes.append(_player)
	_rig = Fixtures.spawn_camera_rig(tree.root, _player)
	_nodes.append(_rig)
	_rig.pitch = 0.0
	_hand = _player.get_node("HandController") as HandController
	_crosshair = (load(CROSSHAIR_SCENE) as PackedScene).instantiate() as Crosshair
	tree.root.add_child(_crosshair)
	_nodes.append(_crosshair)
	_prompt = _crosshair.get_node_or_null("NearPrompt") as Control
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.wait_process(tree, 3)


func _settle(tree: SceneTree) -> void:
	await Fixtures.wait_physics(tree, 4)
	await Fixtures.wait_process(tree, 3)


func _target(tree: SceneTree, position: Vector3) -> Interactable:
	var target: Interactable = Fixtures.spawn_near_target(tree.root, position)
	_nodes.append(target.get_parent())
	return target


func _end(tree: SceneTree) -> void:
	for action: StringName in [&"interact"]:
		Input.action_release(action)
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
	await tree.process_frame
