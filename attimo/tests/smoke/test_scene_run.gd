extends RefCounted
## FOUND-01 / FOUND-05 / FEEL-01 / MOVE-01 / CAM-01: the Prototype Bits test scene (the Phase 1 backdrop, loaded
## directly; the movement gym owns the main scene since 02-14) is built from sanctioned pieces only, carries the
## follow camera (a top-level CameraRig that is a sibling of the Player with physics interpolation off), and the
## Player runs camera-relative, jumps for real and dashes from Input Map actions while the facts reach the event log.

const Fixtures := preload("res://tests/fixtures.gd")

const TEST_SCENE: String = "res://scenes/test/test_scene.tscn"
const PROTO_PREFIX: String = "res://scenes/proto/"
const MANNEQUIN_SCENE: String = "res://scenes/player/mannequin.tscn"
const SPAWN: Vector3 = Vector3(0.0, 0.0, 4.0)
const SPAWN_TOLERANCE: float = 0.05
const MIN_RUN_DISTANCE: float = 1.0
## The tree follows the FSM after its 0.1 s crossfade, so tests allow a few ticks.
const TREE_TRAVEL_TICKS: int = 15
const AABB_TOLERANCE: float = 0.01

var _bus: Node
var _dashes: Array[Array] = []
var _on_dash: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	var packed: PackedScene = load(TEST_SCENE) as PackedScene
	check.call(packed != null, "test scene loads")
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	tree.root.add_child(scene)
	await Fixtures.wait_physics(tree, 30)

	var player: PlayerController = _check_composition(scene, check)
	_check_walls(scene, check)
	if player != null:
		await _play_through(tree, scene, player, check)

	scene.queue_free()
	await scene.tree_exited


func _check_composition(scene: Node, check: Callable) -> PlayerController:
	var players: Array[Node] = scene.get_tree().get_nodes_in_group(&"player")
	check.call(players.size() == 1, "exactly one node in group player (got %d)" % players.size())
	var player: PlayerController = null
	if players.size() == 1:
		player = players[0] as PlayerController
	check.call(player != null, "the player node is a PlayerController")
	if player != null:
		check.call(player.collision_layer == PhysicsLayers.PLAYER, "player layer is Player (got %d)" % player.collision_layer)
		check.call(player.collision_mask == PhysicsLayers.WORLD, "player mask is World (got %d)" % player.collision_mask)

	var bodies: int = 0
	var meshes: int = 0
	var unsanctioned: int = 0
	var particles: int = 0
	var cameras: Array[Camera3D] = []
	var lights: int = 0
	var environments: Array[Environment] = []
	var logs: Array[EventLog] = []
	for node: Node in _all_nodes(scene):
		if node is StaticBody3D:
			bodies += 1
			check.call((node as StaticBody3D).collision_layer == PhysicsLayers.WORLD, "%s is on the World layer" % scene.get_path_to(node))
		if node is MeshInstance3D:
			meshes += 1
			if not _has_sanctioned_ancestor(node):
				unsanctioned += 1
				check.call(false, "%s has no Prototype Bits or Mannequin ancestor" % scene.get_path_to(node))
		if node is GPUParticles3D or node is CPUParticles3D or node is GPUParticles2D or node is CPUParticles2D:
			particles += 1
		if node is Camera3D:
			cameras.append(node as Camera3D)
		if node is DirectionalLight3D:
			lights += 1
		if node is WorldEnvironment:
			environments.append((node as WorldEnvironment).environment)
		if node is EventLog:
			logs.append(node as EventLog)
	check.call(bodies > 0 and meshes > 0, "scene has static bodies (%d) and meshes (%d)" % [bodies, meshes])
	check.call(unsanctioned == 0, "every mesh sits under a Prototype Bits wrapper or the Mannequin (%d meshes)" % meshes)
	check.call(particles == 0, "no particle node (got %d)" % particles)

	check.call(environments.size() == 1 and environments[0] != null, "exactly one WorldEnvironment with an Environment")
	if environments.size() == 1 and environments[0] != null:
		var env: Environment = environments[0]
		check.call(not env.glow_enabled, "glow is off")
		check.call(not env.fog_enabled, "fog is off")
		check.call(not env.volumetric_fog_enabled, "volumetric fog is off")
		check.call(not env.sdfgi_enabled, "SDFGI is off")
		check.call(env.background_mode == Environment.BG_SKY, "background is the sky")

	check.call(cameras.size() == 1, "exactly one Camera3D (got %d)" % cameras.size())
	if cameras.size() == 1:
		check.call(cameras[0].current, "the camera is current")
		_check_camera_rig(cameras[0], player, check)
	check.call(lights == 1, "exactly one DirectionalLight3D (got %d)" % lights)
	check.call(logs.size() == 1, "an EventLog node exists (got %d)" % logs.size())
	if logs.size() == 1:
		check.call(not logs[0].visible, "the EventLog starts hidden")
	return player


## The only camera sits in a CameraRig that is a top-level, interpolation-off sibling of the Player (D-14, D-18).
func _check_camera_rig(camera: Camera3D, player: PlayerController, check: Callable) -> void:
	var rig: CameraRig = null
	var current: Node = camera.get_parent()
	while current != null and rig == null:
		rig = current as CameraRig
		current = current.get_parent()
	check.call(rig != null, "the camera has a CameraRig ancestor")
	if rig == null:
		return
	check.call(rig.top_level, "the CameraRig is top_level")
	check.call(rig.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "the CameraRig has physics interpolation OFF")
	if player != null:
		check.call(not player.is_ancestor_of(rig), "the CameraRig is not inside the Player subtree")
		check.call(rig.get_parent() == player.get_parent(), "the CameraRig is a sibling of the Player")
		check.call(rig.target == player, "the CameraRig targets the Player")


func _check_walls(scene: Node, check: Callable) -> void:
	var boxes: Array[AABB] = []
	for node: Node in _all_nodes(scene):
		if not node.name.begins_with("Wall"):
			continue
		var body: StaticBody3D = node as StaticBody3D
		if body == null:
			continue
		var shape_node: CollisionShape3D = body.get_node("CollisionShape3D") as CollisionShape3D
		var box: BoxShape3D = shape_node.shape as BoxShape3D
		var local: AABB = AABB(-box.size / 2.0, box.size)
		var world: AABB = shape_node.global_transform * local
		boxes.append(world)
		check.call(absf(world.position.y) <= AABB_TOLERANCE, "%s bottom is at y 0 (got %.3f)" % [node.name, world.position.y])
	check.call(boxes.size() == 20, "20 walls in the ring (got %d)" % boxes.size())
	var overlaps: int = 0
	for i: int in boxes.size():
		for j: int in range(i + 1, boxes.size()):
			var shrunk: AABB = boxes[i].grow(-AABB_TOLERANCE)
			if shrunk.intersects(boxes[j]):
				overlaps += 1
	check.call(overlaps == 0, "no two walls overlap by more than 1 cm (got %d overlapping pairs)" % overlaps)


func _play_through(tree: SceneTree, scene: Node, player: PlayerController, check: Callable) -> void:
	var animation_tree: AnimationTree = player.get_node("VisualRoot/Mannequin/AnimationTree") as AnimationTree
	var playback: AnimationNodeStateMachinePlayback = animation_tree.get(&"parameters/playback") as AnimationNodeStateMachinePlayback
	var log_node: EventLog = null
	for node: Node in _all_nodes(scene):
		if node is EventLog:
			log_node = node as EventLog
	var landed: Array[bool] = []
	var on_landed: Callable = func(_position: Vector3, _impact_speed: float) -> void: landed.append(true)
	_bus.connect(&"landed", on_landed)
	_on_dash = func(position: Vector3, direction: Vector3, in_air: bool) -> void: _dashes.append([position, direction, in_air])
	_bus.connect(&"dash_started", _on_dash)

	check.call(player.global_position.distance_to(SPAWN) < SPAWN_TOLERANCE, "player starts at the spawn point (got %s)" % player.global_position)

	# Run: hold move_forward; the player moves away from the camera (along the camera's flat forward axis).
	var camera: Camera3D = tree.root.get_viewport().get_camera_3d()
	var camera_forward: Vector3 = -camera.global_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var run_start: Vector3 = player.global_position
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 30)
	var traveled: float = (player.global_position - run_start).dot(camera_forward)
	check.call(traveled > MIN_RUN_DISTANCE, "move_forward: the player moved %.2f m away from the camera in 30 ticks" % traveled)
	check.call(playback.get_current_node() == &"Locomotion", "move_forward: tree is in Locomotion (got %s)" % playback.get_current_node())
	var blend: float = animation_tree.get(&"parameters/Locomotion/blend_position") as float
	check.call(is_equal_approx(blend, 1.0), "move_forward: Locomotion blend_position is 1.0 (got %s)" % blend)
	Input.action_release(&"move_forward")
	var stopped: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Idle", 60)
	check.call(stopped >= 0, "releasing move_forward returns to Idle (got %s)" % player.state_machine.current.name)

	# Jump: real physics, ends with a landed fact.
	await Fixtures.tap_action(tree, &"jump")
	var waited: int = 0
	while landed.is_empty() and waited < 120:
		await tree.physics_frame
		waited += 1
	check.call(not landed.is_empty(), "jump ends with a landed fact within 120 frames (waited %d)" % waited)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Idle", 60)
	await Fixtures.wait_physics(tree, 5)

	# Dash: the tree travels to Dash within 3 frames and one dash_started is recorded.
	await Fixtures.tap_action(tree, &"dash")
	var reached_dash: int = await Fixtures.wait_until(tree, func() -> bool: return playback.get_current_node() == &"Dash", TREE_TRAVEL_TICKS)
	check.call(reached_dash >= 0, "dash: tree travels to Dash within %d ticks (got %s)" % [TREE_TRAVEL_TICKS, playback.get_current_node()])
	check.call(_dashes.size() == 1, "dash: exactly one dash_started (got %d)" % _dashes.size())
	await Fixtures.wait_physics(tree, 40)

	# Event log contents.
	check.call(log_node != null, "event log found for the content check")
	if log_node != null:
		var text: String = "\n".join(log_node.lines)
		for fact: String in ["jumped", "landed", "dash_started", "movement_state_changed"]:
			check.call(text.contains(fact), "event log contains %s" % fact)

	_bus.disconnect(&"landed", on_landed)
	_bus.disconnect(&"dash_started", _on_dash)
	_on_dash = Callable()


func _all_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	for child: Node in root.get_children():
		result.append_array(_all_nodes(child))
	return result


func _has_sanctioned_ancestor(node: Node) -> bool:
	var current: Node = node
	while current != null:
		var path: String = current.scene_file_path
		if path.begins_with(PROTO_PREFIX) or path == MANNEQUIN_SCENE:
			return true
		current = current.get_parent()
	return false
