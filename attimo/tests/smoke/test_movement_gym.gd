extends RefCounted
## MOVE-01 / MOVE-08 / CAM-01 (D-20, D-21): the movement gym is the main scene, is generated from Prototype Bits
## wrappers only (no particles, glow or fog), carries exactly one Player and one CameraRig, and has every zone of the
## node contract. The gym is built by tools/build_movement_gym.gd.

const Fixtures := preload("res://tests/fixtures.gd")

const GYM_SCENE: String = "res://scenes/test/movement_gym.tscn"
const PROTO_PREFIX: String = "res://scenes/proto/"
const MECHANISMS_PREFIX: String = "res://scenes/mechanisms/"
const MANNEQUIN_SCENE: String = "res://scenes/player/mannequin.tscn"
const CONTRACT_NODES: Array[String] = [
	"WorldEnvironment", "Sun", "Hall", "Spawn", "Player", "CameraRig",
	"Zone_MeasurementStrip", "Zone_RampsStairs", "Zone_Gaps", "Zone_MovingPlatforms", "Zone_Conveyors",
	"Zone_CameraTests", "Zone_Loader", "FallResetHall", "EventLog", "MetricsOverlay", "TuningPanel", "Crosshair", "EnergyHud", "LoaderLook",
]
const RISER_COUNT: int = 6
const RISER_STEP: float = 0.15
const STEP_TOLERANCE: float = 0.01
const SPAWN_TOLERANCE: float = 0.05
const MIN_RUN_DISTANCE: float = 1.0
const PLATFORM_TICKS: int = 60
const MIN_PLATFORM_TRAVEL: float = 0.5
## Above the middle of the 12 m gap of the gap course's second leg, over the pit.
const PIT_DROP_POSITION: Vector3 = Vector3(-14.0, 3.0, -20.0)
const RESET_TICKS: int = 180
const RESET_TOLERANCE: float = 1.0


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

	var player: PlayerController = _check_composition(gym, check)
	if player != null:
		await _play_through(tree, gym, player, check)

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
			if not _layer_allowed(node as StaticBody3D):
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

	_check_mechanism_rooms(gym, check)
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
	var crosshair: Crosshair = gym.get_node_or_null("Crosshair") as Crosshair
	check.call(crosshair != null and crosshair.visible, "the Crosshair is present and visible")


func _play_through(tree: SceneTree, gym: Node, player: PlayerController, check: Callable) -> void:
	var spawn: Marker3D = gym.get_node("Spawn") as Marker3D
	check.call(player.global_position.distance_to(spawn.global_position) < SPAWN_TOLERANCE, "the player starts at Spawn (got %s)" % player.global_position)
	check.call(player.is_grounded(), "the player spawns grounded")

	# The moving platforms are in motion: each one has left its position of 60 ticks ago.
	var platforms: Array[Node] = tree.get_nodes_in_group(&"moving_platform")
	var before: Dictionary[Node, Vector3] = {}
	for platform: Node in platforms:
		before[platform] = (platform as Node3D).global_position
	await Fixtures.wait_physics(tree, PLATFORM_TICKS)
	var moved: int = 0
	for platform: Node in platforms:
		if (platform as Node3D).global_position.distance_to(before[platform]) > MIN_PLATFORM_TRAVEL:
			moved += 1
	check.call(moved == platforms.size(), "each of the %d moving platforms moved more than %.1f m in %d ticks (moved: %d)" % [platforms.size(), MIN_PLATFORM_TRAVEL, PLATFORM_TICKS, moved])

	# Run: hold move_forward; the player moves away from the camera, along its flattened forward axis.
	var camera: Camera3D = tree.root.get_viewport().get_camera_3d()
	var camera_forward: Vector3 = -camera.global_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var run_start: Vector3 = player.global_position
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 30)
	Input.action_release(&"move_forward")
	var traveled: float = (player.global_position - run_start).dot(camera_forward)
	check.call(traveled > MIN_RUN_DISTANCE, "move_forward: the player ran %.2f m along the camera's forward axis in 30 ticks" % traveled)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Idle", 60)

	# A fall into the gap course returns the player to that course's respawn marker.
	var respawn: Marker3D = gym.get_node("Zone_Gaps/Respawn_Gaps") as Marker3D
	player.teleport(PIT_DROP_POSITION)
	var lowest: float = player.global_position.y
	var returned: int = -1
	for tick: int in RESET_TICKS:
		await tree.physics_frame
		lowest = minf(lowest, player.global_position.y)
		if player.global_position.distance_to(respawn.global_position) < RESET_TOLERANCE:
			returned = tick
			break
	check.call(lowest < -2.0, "the dropped player fell into the pit (lowest y %.1f)" % lowest)
	check.call(returned >= 0, "the FallReset returns the player to the gap course respawn within %d ticks (ticks: %d, at %s)" % [RESET_TICKS, returned, player.global_position])
	await Fixtures.wait_physics(tree, 30)
	check.call(player.is_grounded(), "the player stands on the course start island after the reset")


func _all_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	for child: Node in root.get_children():
		result.append_array(_all_nodes(child))
	return result


func _has_sanctioned_ancestor(node: Node) -> bool:
	var current: Node = node
	while current != null:
		var path: String = current.scene_file_path
		if path.begins_with(PROTO_PREFIX) or path.begins_with(MECHANISMS_PREFIX) or path == MANNEQUIN_SCENE:
			return true
		current = current.get_parent()
	return false


## World, or Interactable for a hit body that carries the back reference or sits under a mechanisms scene.
func _layer_allowed(body: StaticBody3D) -> bool:
	if body.collision_layer == PhysicsLayers.WORLD:
		return true
	if body.collision_layer != PhysicsLayers.INTERACTABLE:
		return false
	if body.has_meta(&"interactable"):
		return true
	var current: Node = body
	while current != null:
		if current.scene_file_path.begins_with(MECHANISMS_PREFIX):
			return true
		current = current.get_parent()
	return false


## The door into room 2 (D-26): a Zahnrad-Tor wired to a Lever in Zone_MechanismRooms, and no WallEast_0.
func _check_mechanism_rooms(gym: Node, check: Callable) -> void:
	var zone: Node = gym.get_node_or_null("Zone_MechanismRooms")
	check.call(zone != null, "the gym has Zone_MechanismRooms")
	if zone == null:
		return
	var gate: GearGate = zone.get_node_or_null("ZahnradTor") as GearGate
	check.call(gate != null, "Zone_MechanismRooms holds a GearGate")
	check.call(gate != null and gate.source is Lever, "the GearGate source is a Lever")
	check.call(gym.find_child("WallEast_0", true, false) == null, "WallEast_0 is absent (the door cell)")
	_check_showcase_stations(zone, check)
	_check_moving_stations(zone, check)
	_check_field_stations(zone, check)


## Room 2 holds a station per trigger and logic node (D-27), and every wired node has its sources (T-04-08).
func _check_showcase_stations(zone: Node, check: Callable) -> void:
	var counts: Dictionary = {"Valve": 0, "EnergyCore": 0, "Crank": 0, "LogicAnd": 0, "LogicOr": 0, "LogicTimer": 0}
	var unwired: int = 0
	for child: Node in zone.get_children():
		if child is Valve:
			counts["Valve"] += 1
		elif child is EnergyCore:
			counts["EnergyCore"] += 1
		elif child is Crank:
			counts["Crank"] += 1
		elif child is LogicAnd or child is LogicOr:
			counts["LogicAnd" if child is LogicAnd else "LogicOr"] += 1
			var sources: Array = child.get("sources")
			if sources.is_empty() or sources.has(null):
				unwired += 1
		elif child is LogicTimer:
			counts["LogicTimer"] += 1
			if (child as LogicTimer).source == null:
				unwired += 1
		if child is Mechanism and (child as Mechanism).source == null:
			unwired += 1
	for kind: String in counts:
		check.call(int(counts[kind]) >= 1, "room 2 has a %s station (%d)" % [kind, int(counts[kind])])
	check.call(unwired == 0, "every Mechanism and logic node in Zone_MechanismRooms is wired (%d unwired)" % unwired)


## Room 2 holds a station per moving mechanism and variant (D-27), each with a source. The group moving_platform stays at its three
## test platforms (checked with the platform scenarios above).
func _check_moving_stations(zone: Node, check: Callable) -> void:
	var axes: Dictionary = {}
	var looks: Dictionary = {}
	var modes: Dictionary = {}
	var behaviours: Dictionary = {}
	var pendulums: int = 0
	var unwired: int = 0
	for child: Node in zone.get_children():
		if child is RotatingPlatform:
			axes[(child as RotatingPlatform).axis_mode] = true
		elif child is LiftPlatform:
			looks[(child as LiftPlatform).look] = true
		elif child is SteamNozzle:
			modes[(child as SteamNozzle).mode] = true
		elif child is Conveyor:
			behaviours[(child as Conveyor).behaviour] = true
		elif child is Pendulum:
			pendulums += 1
		else:
			continue
		if (child as Mechanism).source == null:
			unwired += 1
	check.call(axes.size() == 3, "room 2 has a Dreh-Plattform in all three axis modes (%d)" % axes.size())
	check.call(looks.size() == 2, "room 2 has a Hub-Plattform with both looks (%d)" % looks.size())
	check.call(behaviours.size() == 2, "room 2 has a Foerderband per behaviour (%d)" % behaviours.size())
	check.call(modes.size() == 4, "room 2 has a Dampfduese in all four modes (%d)" % modes.size())
	check.call(pendulums >= 1, "room 2 has a Pendel (%d)" % pendulums)
	check.call(unwired == 0, "every moving mechanism in Zone_MechanismRooms has a source (%d unwired)" % unwired)


## Phase 04.1 stations (MECH-04, MECH-05, MOVE-12): the new mechanisms each have a station with a source in room 2.
func _check_field_stations(zone: Node, check: Callable) -> void:
	var field_modes: Dictionary = {}
	var pad_modes: Dictionary = {}
	var kinds: Dictionary = {"WindTunnel": 0, "LowGravityZone": 0, "SlingshotCore": 0, "PneumaticTube": 0, "BouncePad": 0, "BoostRing": 0, "CrumblingPlatform": 0, "PistonWall": 0, "Geyser": 0, "Paternoster": 0}
	var unwired: int = 0
	var plate_gates: int = 0
	var plates: Array[Node] = []
	for child: Node in zone.get_children():
		if child is PressurePlate:
			plates.append(child)
		if child is GearGate and plates.has((child as GearGate).source):
			plate_gates += 1
		if not child is Mechanism:
			continue
		var mechanism: Mechanism = child as Mechanism
		if mechanism.source == null:
			unwired += 1
		if child is ForceField:
			field_modes[(child as ForceField).mode] = true
		elif child is WallPad:
			pad_modes[(child as WallPad).mode] = true
		for kind: String in kinds:
			if str(child.get_script().get_global_name()) == kind:
				kinds[kind] += 1
	check.call(field_modes.size() == 2, "room 2 has a ForceField in both modes (%d)" % field_modes.size())
	check.call(pad_modes.size() == 2, "room 2 has a WallPad in both modes (%d)" % pad_modes.size())
	for kind: String in kinds:
		check.call(int(kinds[kind]) >= 1, "room 2 has a %s station (%d)" % [kind, int(kinds[kind])])
	check.call(plate_gates >= 1, "room 2 has a PressurePlate that drives a gate (%d)" % plate_gates)
	check.call(unwired == 0, "every new mechanism in Zone_MechanismRooms has a source (%d unwired)" % unwired)
