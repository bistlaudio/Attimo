extends RefCounted
## MOVE-01 / MOVE-08 / CAM-01 (D-20, D-21): the movement gym is the main scene, is generated from Prototype Bits
## wrappers only (no particles, glow or fog), carries exactly one Player and one CameraRig, and has every zone of the
## node contract. The gym is built by tools/build_movement_gym.gd.

const Fixtures := preload("res://tests/fixtures.gd")

const GYM_SCENE: String = "res://scenes/test/movement_gym.tscn"
const PROTO_PREFIX: String = "res://scenes/proto/"
const MANNEQUIN_SCENE: String = "res://scenes/player/mannequin.tscn"
const CONTRACT_NODES: Array[String] = [
	"WorldEnvironment", "Sun", "Hall", "Spawn", "Player", "CameraRig",
	"Zone_MeasurementStrip", "Zone_RampsStairs", "Zone_Gaps", "Zone_MovingPlatforms", "Zone_Conveyors",
	"Zone_CameraTests", "FallResetHall", "EventLog", "MetricsOverlay", "TuningPanel",
]
const RISER_COUNT: int = 6
const RISER_STEP: float = 0.15
const STEP_TOLERANCE: float = 0.01


func run(tree: SceneTree, check: Callable) -> void:
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene"))
	check.call(main_scene == GYM_SCENE, "application/run/main_scene is the movement gym (got %s)" % main_scene)
	var packed: PackedScene = load(GYM_SCENE) as PackedScene
	check.call(packed != null, "the movement gym loads")
	if packed == null:
		return
	var gym: Node = packed.instantiate()
	check.call(gym != null and gym.name == &"MovementGym", "the movement gym instantiates as MovementGym")
	tree.root.add_child(gym)
	await Fixtures.wait_physics(tree, 30)

	_check_composition(gym, check)

	gym.queue_free()
	await gym.tree_exited


func _check_composition(gym: Node, check: Callable) -> PlayerController:
	for node_name: String in CONTRACT_NODES:
		check.call(gym.get_node_or_null(node_name) != null, "the gym has a direct child %s" % node_name)

	var players: Array[Node] = gym.get_tree().get_nodes_in_group(&"player")
	check.call(players.size() == 1, "exactly one node in group player (got %d)" % players.size())
	var player: PlayerController = null
	if players.size() == 1:
		player = players[0] as PlayerController
	check.call(player != null, "the player node is a PlayerController")

	var meshes: int = 0
	var unsanctioned: PackedStringArray = PackedStringArray()
	var bodies: int = 0
	var off_world: PackedStringArray = PackedStringArray()
	var particles: int = 0
	var cameras: Array[Camera3D] = []
	var environments: Array[Environment] = []
	var lights: int = 0
	var labels: int = 0
	for node: Node in _all_nodes(gym):
		if node is StaticBody3D:
			bodies += 1
			if (node as StaticBody3D).collision_layer != PhysicsLayers.WORLD:
				off_world.append(str(gym.get_path_to(node)))
		if node is MeshInstance3D:
			meshes += 1
			if not _has_sanctioned_ancestor(node):
				unsanctioned.append(str(gym.get_path_to(node)))
		if node is GPUParticles3D or node is CPUParticles3D or node is GPUParticles2D or node is CPUParticles2D:
			particles += 1
		if node is Camera3D:
			cameras.append(node as Camera3D)
		if node is DirectionalLight3D:
			lights += 1
		if node is Label3D:
			labels += 1
		if node is WorldEnvironment:
			environments.append((node as WorldEnvironment).environment)
	check.call(meshes > 0 and bodies > 0, "the gym has static bodies (%d) and meshes (%d)" % [bodies, meshes])
	check.call(unsanctioned.is_empty(), "every mesh sits under a Prototype Bits wrapper or the Mannequin (unsanctioned: %s)" % ", ".join(unsanctioned))
	check.call(off_world.is_empty(), "every StaticBody3D is on the World layer (off: %s)" % ", ".join(off_world))
	check.call(particles == 0, "no particle node (got %d)" % particles)
	check.call(labels >= 40, "the gym carries Label3D markings (got %d)" % labels)
	check.call(lights == 1, "exactly one DirectionalLight3D (got %d)" % lights)

	check.call(environments.size() == 1 and environments[0] != null, "exactly one WorldEnvironment with an Environment")
	if environments.size() == 1 and environments[0] != null:
		var env: Environment = environments[0]
		check.call(not env.glow_enabled, "glow is off")
		check.call(not env.fog_enabled, "fog is off")
		check.call(not env.volumetric_fog_enabled, "volumetric fog is off")
		check.call(not env.sdfgi_enabled, "SDFGI is off")

	check.call(cameras.size() == 1, "exactly one Camera3D (got %d)" % cameras.size())
	if cameras.size() == 1:
		_check_camera_rig(cameras[0], player, check)

	_check_platforms_and_conveyors(gym, check)
	_check_fall_resets(gym, check)
	_check_risers(gym, check)
	_check_overlays(gym, check)
	return player


## The only camera sits in a CameraRig that is a sibling of the Player and targets it (D-14, D-18).
func _check_camera_rig(camera: Camera3D, player: PlayerController, check: Callable) -> void:
	var rig: CameraRig = null
	var current: Node = camera.get_parent()
	while current != null and rig == null:
		rig = current as CameraRig
		current = current.get_parent()
	check.call(rig != null, "the camera is owned by a CameraRig")
	if rig == null or player == null:
		return
	check.call(not player.is_ancestor_of(rig), "the CameraRig is not inside the Player subtree")
	check.call(rig.get_parent() == player.get_parent(), "the CameraRig is a sibling of the Player")
	check.call(rig.target == player, "the CameraRig targets the Player")


func _check_platforms_and_conveyors(gym: Node, check: Callable) -> void:
	var platforms: Array[Node] = gym.get_tree().get_nodes_in_group(&"moving_platform")
	check.call(platforms.size() == 3, "three MovingPlatform nodes in group moving_platform (got %d)" % platforms.size())
	var linear: int = 0
	var circle: int = 0
	var vertical: int = 0
	for node: Node in platforms:
		var platform: MovingPlatform = node as MovingPlatform
		if platform == null:
			continue
		if platform.mode == MovingPlatform.Mode.CIRCLE:
			circle += 1
		elif absf(platform.travel.y) > 0.5:
			vertical += 1
		else:
			linear += 1
	check.call(linear == 1 and circle == 1 and vertical == 1, "one linear, one circular and one vertical platform (got %d, %d, %d)" % [linear, circle, vertical])

	var conveyors: int = 0
	for node: Node in _all_nodes(gym):
		var body: StaticBody3D = node as StaticBody3D
		if body != null and body.name.begins_with("Conveyor_") and not body.constant_linear_velocity.is_zero_approx():
			conveyors += 1
	check.call(conveyors >= 2, "at least two conveyor bodies move (got %d)" % conveyors)


func _check_fall_resets(gym: Node, check: Callable) -> void:
	var resets: Array[FallReset] = []
	for node: Node in _all_nodes(gym):
		if node is FallReset:
			resets.append(node as FallReset)
	check.call(resets.size() >= 2, "a FallReset under the gap course and one under the hall (got %d)" % resets.size())
	var bad: PackedStringArray = PackedStringArray()
	for reset: FallReset in resets:
		if reset.collision_layer != PhysicsLayers.HAZARD or reset.respawn == null:
			bad.append(reset.name)
	check.call(bad.is_empty(), "every FallReset is on the Hazard layer with a respawn (bad: %s)" % ", ".join(bad))


func _check_risers(gym: Node, check: Callable) -> void:
	var zone: Node = gym.get_node_or_null("Zone_RampsStairs")
	var tops: Array[float] = []
	if zone != null:
		for step: int in range(1, RISER_COUNT + 1):
			var riser: StaticBody3D = zone.get_node_or_null("Riser_%d" % step) as StaticBody3D
			if riser == null:
				continue
			var shape_node: CollisionShape3D = riser.get_node("CollisionShape3D") as CollisionShape3D
			var box: BoxShape3D = shape_node.shape as BoxShape3D
			tops.append(shape_node.global_position.y + box.size.y * 0.5)
	check.call(tops.size() == RISER_COUNT, "the stair flight has %d risers (got %d)" % [RISER_COUNT, tops.size()])
	var steps_ok: bool = tops.size() == RISER_COUNT
	for index: int in range(1, tops.size()):
		if absf(tops[index] - tops[index - 1] - RISER_STEP) > STEP_TOLERANCE:
			steps_ok = false
	check.call(steps_ok, "the riser tops step by 0.15 m (tops %s)" % str(tops))


func _check_overlays(gym: Node, check: Callable) -> void:
	var event_log: EventLog = gym.get_node_or_null("EventLog") as EventLog
	var metrics: MetricsOverlay = gym.get_node_or_null("MetricsOverlay") as MetricsOverlay
	var tuning: TuningPanel = gym.get_node_or_null("TuningPanel") as TuningPanel
	check.call(event_log != null and not event_log.visible, "the EventLog is present and hidden")
	check.call(metrics != null and not metrics.visible, "the MetricsOverlay is present and hidden")
	check.call(tuning != null and not tuning.visible, "the TuningPanel is present and hidden")


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
