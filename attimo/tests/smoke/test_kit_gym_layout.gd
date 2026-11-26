extends RefCounted
## Phase 05.1 (KIT-04, D-28, D-29, D-30, D-32): the showroom is the gym. Behind the hall's east door the old mechanism rooms gave way to
## three layer areas (tools/kit_area_shell.gd + one kit_<layer>_builder.gd each), Zone_KitSteampunk, Zone_KitEnergy (a new zone, not
## the Phase 5 Zone_Energy) and Zone_KitNature, along the corridor z -4..4. Each area has its role groups (Role_<Name>), every
## Station_* in a Zone_Kit* subtree sits under a role group, lies inside its area rect and carries an "Erwartet:" sign, and every kit
## object scene registered in test_kit_coupling.gd KIT_OBJECTS is instanced under a station of its layer's area. No node anywhere in
## the gym instances a cut scene (CUT_SCENES; later plans append the scenes they delete). Zone_Loader and Zone_Energy stay (D-30).

const Fixtures := preload("res://tests/fixtures.gd")

const GYM_SCENE: String = "res://scenes/test/movement_gym.tscn"
## The registry lives in the coupling test; it is read from there, never copied.
const COUPLING_TEST: String = "res://tests/smoke/test_kit_coupling.gd"
const KIT_ROOT: String = "res://scenes/kit/"
## Area rects (x, z, width, depth) from the gym placement decision (unattended decision 6): the areas line the corridor z -4..4
## behind the hall's east door, x 43..151, 155..227 and 231..291, each z -32..32. Hard coded here so the test does not just read the
## builder back.
const AREAS: Dictionary = {
	"Zone_KitSteampunk": Rect2(43.0, -32.0, 108.0, 64.0),
	"Zone_KitEnergy": Rect2(155.0, -32.0, 72.0, 64.0),
	"Zone_KitNature": Rect2(231.0, -32.0, 60.0, 64.0),
}
## Folder under res://scenes/kit/ -> the area that shows its objects.
const LAYER_AREAS: Dictionary = {
	"steampunk": "Zone_KitSteampunk",
	"energy": "Zone_KitEnergy",
	"nature": "Zone_KitNature",
}
## The role groups each area must have (the cube is sparse: nature has no boosters or mechanisms, energy platforms are neutral).
const AREA_ROLES: Dictionary = {
	"Zone_KitSteampunk": ["Role_Platforms", "Role_Environment", "Role_Obstacles", "Role_Boosters", "Role_Mechanisms"],
	"Zone_KitEnergy": ["Role_Environment", "Role_Obstacles", "Role_Boosters", "Role_Mechanisms"],
	"Zone_KitNature": ["Role_Platforms", "Role_Environment", "Role_Obstacles"],
}
## Scenes that left the kit (D-09). Compared as full paths: scenes/kit/steampunk/ reuses some file names (slingshot_core, wall_pad).
const CUT_SCENES: Array[String] = [
	"res://scenes/mechanisms/lever.tscn",
	"res://scenes/mechanisms/valve.tscn",
	"res://scenes/mechanisms/gear_gate.tscn",
	"res://scenes/mechanisms/lift_platform.tscn",
	"res://scenes/mechanisms/crank.tscn",
	"res://scenes/mechanisms/pressure_plate.tscn",
	"res://scenes/mechanisms/pneumatic_tube.tscn",
	"res://scenes/mechanisms/conveyor.tscn",
	"res://scenes/mechanisms/crumbling_platform.tscn",
	"res://scenes/mechanisms/pendulum.tscn",
	"res://scenes/mechanisms/piston_wall.tscn",
	"res://scenes/mechanisms/rotating_platform.tscn",
	"res://scenes/mechanisms/paternoster.tscn",
	"res://scenes/mechanisms/slingshot_core.tscn",
	"res://scenes/mechanisms/wall_pad.tscn",
	"res://scenes/mechanisms/steam_nozzle.tscn",
	"res://scenes/mechanisms/geyser.tscn",
	"res://scenes/mechanisms/wind_tunnel.tscn",
	"res://scenes/mechanisms/energy_capsule.tscn",
	"res://scenes/mechanisms/broken_machine.tscn",
	"res://scenes/mechanisms/boost_ring.tscn",
	"res://scenes/mechanisms/bounce_pad.tscn",
	"res://scenes/mechanisms/low_gravity_zone.tscn",
	"res://scenes/mechanisms/energy_core.tscn",
	"res://scenes/mechanisms/force_field.tscn",
]


func run(tree: SceneTree, check: Callable) -> void:
	var packed: PackedScene = load(GYM_SCENE) as PackedScene
	check.call(packed != null, "the movement gym loads")
	if packed == null:
		return
	var gym: Node = packed.instantiate()
	tree.root.add_child(gym)
	await Fixtures.wait_physics(tree, 2)
	_check_zones(gym, check)
	for area: String in AREAS:
		var zone: Node3D = gym.get_node_or_null(area) as Node3D
		if zone != null:
			_check_roles(zone, check)
			_check_stations(zone, AREAS[area] as Rect2, check)
	_check_registry(gym, check)
	_check_signal_stations(gym, check)
	_check_energy_stations(gym, check)
	_check_platform_stations(gym, check)
	_check_obstacle_stations(gym, check)
	_check_nature_stations(gym, check)
	_check_cut_scenes(gym, check)
	gym.queue_free()
	await gym.tree_exited


## D-28 / D-29 / D-30: the three layer areas exist, the old mechanism rooms are gone, the Phase 5 zones stay.
func _check_zones(gym: Node, check: Callable) -> void:
	for area: String in AREAS:
		check.call(gym.get_node_or_null(area) != null, "the gym has %s" % area)
	check.call(gym.get_node_or_null("Zone_MechanismRooms") == null, "Zone_MechanismRooms is gone (D-29)")
	check.call(gym.get_node_or_null("Zone_Loader") != null, "Zone_Loader stays (D-30)")
	check.call(gym.get_node_or_null("Zone_Energy") != null, "Zone_Energy stays (D-30)")


func _check_roles(zone: Node3D, check: Callable) -> void:
	for role: Variant in AREA_ROLES[str(zone.name)] as Array:
		check.call(zone.get_node_or_null(str(role)) != null, "%s has the role group %s" % [zone.name, role])


## Every Station_* below the area: under a Role_* group, inside the area rect, with a Label3D whose text contains "Erwartet:".
func _check_stations(zone: Node3D, rect: Rect2, check: Callable) -> void:
	var stations: Array[Node] = zone.find_children("Station_*", "Node3D", true, false)
	for node: Node in stations:
		var station: Node3D = node as Node3D
		var label: String = "%s/%s" % [zone.name, zone.get_path_to(station)]
		check.call(station.get_parent() != null and str(station.get_parent().name).begins_with("Role_"), "%s sits directly under a Role_* group" % label)
		var at: Vector3 = station.global_position
		check.call(rect.has_point(Vector2(at.x, at.z)), "%s lies inside the area rect %s (at %s)" % [label, rect, at])
		var expects: bool = false
		for child: Node in station.get_children():
			var sign_label: Label3D = child as Label3D
			if sign_label != null and sign_label.text.contains("Erwartet:"):
				expects = true
		check.call(expects, "%s has an 'Erwartet:' sign" % label)


## Every KIT_OBJECTS scene of layer X is instanced under at least one station of Zone_Kit<X>.
func _check_registry(gym: Node, check: Callable) -> void:
	var script: GDScript = load(COUPLING_TEST) as GDScript
	check.call(script != null, "the coupling test %s loads" % COUPLING_TEST)
	if script == null:
		return
	var constants: Dictionary = script.get_script_constant_map()
	check.call(constants.has("KIT_OBJECTS"), "the coupling test defines KIT_OBJECTS")
	var registry: Dictionary = constants.get("KIT_OBJECTS", {}) as Dictionary
	check.call(not registry.is_empty(), "KIT_OBJECTS is not empty (%d)" % registry.size())
	for path: Variant in registry:
		var scene: String = str(path)
		var folder: String = scene.trim_prefix(KIT_ROOT).get_slice("/", 0)
		check.call(LAYER_AREAS.has(folder), "%s lies in a layer folder (%s)" % [scene, folder])
		if not LAYER_AREAS.has(folder):
			continue
		var zone: Node = gym.get_node_or_null(str(LAYER_AREAS[folder]))
		var found: bool = false
		if zone != null:
			for station: Node in zone.find_children("Station_*", "Node3D", true, false):
				for node: Node in station.find_children("*", "", true, false):
					if node.scene_file_path == scene:
						found = true
						break
				if found:
					break
		check.call(found, "%s is instanced under a station of %s" % [scene, LAYER_AREAS[folder]])


## Plan 05.1-19: the three always-on platform stations stand once in the steampunk area, each with a Timed motion instance.
func _check_platform_stations(gym: Node, check: Callable) -> void:
	var zone: Node = gym.get_node_or_null("Zone_KitSteampunk")
	for station_name: String in ["Station_Paternoster", "Station_RailCart", "Station_PistonSteps"]:
		var found: Array[Node] = zone.find_children(station_name, "Node3D", true, false) if zone != null else []
		check.call(found.size() == 1, "%s exists once under Zone_KitSteampunk" % station_name)
		if found.size() != 1:
			continue
		var blocks: int = 0
		for node: Node in found[0].find_children("*", "", true, false):
			if _global_name(node) == "TimedMotion":
				blocks += 1
		check.call(blocks == 1, "%s holds one Timed motion block (%d)" % [station_name, blocks])


## Plan 05.1-20: the three obstacle stations stand once under Role_Obstacles of the steampunk area, each with a Timed motion block and a DamagePush.
func _check_obstacle_stations(gym: Node, check: Callable) -> void:
	var zone: Node = gym.get_node_or_null("Zone_KitSteampunk")
	var role: Node = zone.find_child("Role_Obstacles", true, false) if zone != null else null
	check.call(role != null, "Zone_KitSteampunk has Role_Obstacles")
	for station_name: String in ["Station_Pendulum", "Station_PistonWall", "Station_SteamHammer"]:
		var found: Array[Node] = role.find_children(station_name, "Node3D", true, false) if role != null else []
		check.call(found.size() == 1, "%s exists once under Role_Obstacles" % station_name)
		if found.size() != 1:
			continue
		var blocks: int = 0
		var pushes: int = 0
		for node: Node in found[0].find_children("*", "", true, false):
			var name_of: String = _global_name(node)
			if name_of == "TimedMotion":
				blocks += 1
			elif name_of == "DamagePush":
				pushes += 1
		check.call(blocks == 1 and pushes == 1, "%s holds one Timed motion block and one DamagePush (%d, %d)" % [station_name, blocks, pushes])


## Plan 05.1-21: the six Reaction to load nature stations stand once under Zone_KitNature (platforms and obstacles), each with one block.
const NATURE_STATIONS: Dictionary = {
	"Station_CrumblingPlatform": "Role_Platforms",
	"Station_SinkingDebris": "Role_Platforms",
	"Station_TippingTrunk": "Role_Platforms",
	"Station_Collapse": "Role_Obstacles",
	"Station_FallingDebris": "Role_Obstacles",
	"Station_SnapBloom": "Role_Obstacles",
}


func _check_nature_stations(gym: Node, check: Callable) -> void:
	var zone: Node = gym.get_node_or_null("Zone_KitNature")
	for station_name: String in NATURE_STATIONS:
		var role: Node = zone.find_child(String(NATURE_STATIONS[station_name]), true, false) if zone != null else null
		var found: Array[Node] = role.find_children(station_name, "Node3D", true, false) if role != null else []
		check.call(found.size() == 1, "%s exists once under %s of Zone_KitNature" % [station_name, NATURE_STATIONS[station_name]])
		if found.size() != 1:
			continue
		var blocks: int = 0
		for node: Node in found[0].find_children("*", "", true, false):
			if _global_name(node) == "ReactionToLoad":
				blocks += 1
		check.call(blocks == 1, "%s holds one Reaction to load block (%d)" % [station_name, blocks])


func _check_cut_scenes(gym: Node, check: Callable) -> void:
	var hits: PackedStringArray = PackedStringArray()
	var stack: Array[Node] = [gym]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if CUT_SCENES.has(node.scene_file_path):
			hits.append("%s (%s)" % [gym.get_path_to(node), node.scene_file_path])
	check.call(hits.is_empty(), "no gym node instances a cut scene (%s)" % ", ".join(hits))


## Plan 05.1-17: the signal stations exist and every Receiver in them is wired (a Receiver without a source would sit silently dead).
const SIGNAL_STATIONS: Dictionary = {
	"Station_Drawbridge": "Zone_KitSteampunk",
	"Station_SwitchedSpeedPad": "Zone_KitSteampunk",
	"Station_ChargeGate": "Zone_KitEnergy",
}


func _check_signal_stations(gym: Node, check: Callable) -> void:
	for station_name: String in SIGNAL_STATIONS:
		var zone: Node = gym.get_node_or_null(str(SIGNAL_STATIONS[station_name]))
		var found: Array[Node] = zone.find_children(station_name, "Node3D", true, false) if zone != null else []
		check.call(found.size() == 1, "%s exists once under %s" % [station_name, SIGNAL_STATIONS[station_name]])
		if found.size() != 1:
			continue
		var gates: int = 0
		for node: Node in found[0].find_children("*", "", true, false):
			var script: Script = node.get_script() as Script
			if script != null and String(script.get_global_name()) == "Receiver":
				check.call(node.get("source") != null, "%s: the Receiver %s has a wired source" % [station_name, node.name])
			if script != null and String(script.get_global_name()) == "Trigger":
				gates += 1
		check.call(gates >= 1, "%s holds a charge gate (Trigger)" % station_name)


## Plan 05.1-18: the paid energy stations. The core station holds one core and three LogicThreshold outputs (levels 1, 2, 3), the AND station two cores
## and a LogicAnd with two wired sources, the OR station a charge gate and a core behind a LogicOr, the field station an attraction field. Every
## Receiver is wired and no output is a door (D-47).
const ENERGY_STATIONS: Array[String] = ["Station_EnergyCore", "Station_LogicAnd", "Station_LogicOr", "Station_AttractionField"]


func _global_name(node: Node) -> String:
	var script: Script = node.get_script() as Script
	return "" if script == null else String(script.get_global_name())


func _check_energy_stations(gym: Node, check: Callable) -> void:
	var zone: Node = gym.get_node_or_null("Zone_KitEnergy")
	var by_name: Dictionary = {}
	for station_name: String in ENERGY_STATIONS:
		var found: Array[Node] = zone.find_children(station_name, "Node3D", true, false) if zone != null else []
		check.call(found.size() == 1, "%s exists once under Zone_KitEnergy" % station_name)
		if found.size() == 1:
			by_name[station_name] = found[0]
	for station_name: String in by_name:
		var cores: int = 0
		var thresholds: Array[int] = []
		var ands: int = 0
		var ors: int = 0
		var gates: int = 0
		var fields: int = 0
		for node: Node in (by_name[station_name] as Node).find_children("*", "", true, false):
			var kind: String = _global_name(node)
			if kind == "Receiver":
				check.call(node.get("source") != null, "%s: the Receiver %s has a wired source" % [station_name, node.name])
			elif kind == "LogicThreshold":
				thresholds.append(int(node.get("min_level")))
				check.call(node.get("source") != null, "%s: the LogicThreshold %s has a source" % [station_name, node.name])
			elif kind == "LogicAnd":
				ands += 1
				var sources: Array = node.get("sources") as Array
				check.call(sources.size() == 2 and not sources.has(null), "%s: the LogicAnd has two wired sources" % station_name)
			elif kind == "LogicOr":
				ors += 1
				var or_sources: Array = node.get("sources") as Array
				check.call(or_sources.size() >= 2 and not or_sources.has(null), "%s: the LogicOr has wired sources" % station_name)
			elif kind == "Trigger":
				var config: Resource = node.get("config") as Resource
				if config != null and int(config.get("profile")) == 1:
					cores += 1
				elif config != null:
					gates += 1
			elif kind == "ForceVolume":
				fields += 1
		match station_name:
			"Station_EnergyCore":
				thresholds.sort()
				check.call(cores == 1 and thresholds == [1, 2, 3], "Station_EnergyCore: one core and LogicThreshold outputs at levels 1, 2, 3 (%d cores, %s)" % [cores, thresholds])
			"Station_LogicAnd":
				check.call(cores == 2 and ands == 1, "Station_LogicAnd: two cores and one LogicAnd (%d cores, %d AND)" % [cores, ands])
			"Station_LogicOr":
				check.call(cores == 1 and gates == 1 and ors == 1, "Station_LogicOr: a charge gate and a core behind one LogicOr (%d cores, %d gates, %d OR)" % [cores, gates, ors])
			"Station_AttractionField":
				check.call(fields == 1, "Station_AttractionField: one attraction field (%d)" % fields)
