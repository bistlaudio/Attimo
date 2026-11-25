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
## Lever and valve are not listed yet: Zone_Energy uses them until plan 13 swaps them in place.
const CUT_SCENES: Array[String] = [
	"res://scenes/mechanisms/lift_platform.tscn",
	"res://scenes/mechanisms/crank.tscn",
	"res://scenes/mechanisms/pressure_plate.tscn",
	"res://scenes/mechanisms/pneumatic_tube.tscn",
	"res://scenes/mechanisms/conveyor.tscn",
	"res://scenes/mechanisms/rotating_platform.tscn",
	"res://scenes/mechanisms/slingshot_core.tscn",
	"res://scenes/mechanisms/wall_pad.tscn",
	"res://scenes/mechanisms/steam_nozzle.tscn",
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


func _check_cut_scenes(gym: Node, check: Callable) -> void:
	var hits: PackedStringArray = PackedStringArray()
	var stack: Array[Node] = [gym]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if CUT_SCENES.has(node.scene_file_path):
			hits.append("%s (%s)" % [gym.get_path_to(node), node.scene_file_path])
	check.call(hits.is_empty(), "no gym node instances a cut scene (%s)" % ", ".join(hits))
