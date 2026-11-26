extends RefCounted
## Phase 05.1 plan 22 (KIT-02, KIT-04, D-31 amended, D-46, T-05.1-65): the mixed course Zone_KitCourse (x 295..395) combines all three layers
## in one route: clock hand -> slingshot -> resin pool -> energy core paying a drawbridge -> collapse strip -> goal. Every gap is checked
## against docs/MOVEMENT-METRICS.md (read from the doc, never typed here): at most the reach of the move minus GAP_MARGIN, every step up at
## most the full-jump apex minus APEX_MARGIN. Footholds are read from the real gym nodes (ledge tiles are 4 m floor tiles named
## <Tag>_<layer>, stairs <Tag>_<column>_<layer>), moving parts from their presets, so a moved ledge fails here.

const Fixtures := preload("res://tests/fixtures.gd")

const GYM_SCENE: String = "res://scenes/test/movement_gym.tscn"
const DOC_RELATIVE_PATH: String = "../docs/MOVEMENT-METRICS.md"
const COURSE_X: Vector2 = Vector2(295.0, 395.0)
const ZONE: String = "Zone_KitCourse"
const STATION: String = "Station_KitCourse"
const TILE_HALF: float = 2.0
const GAP_MARGIN: float = 1.0
const APEX_MARGIN: float = 0.3
## A straight flight keeps this much of its length in reserve.
const STRAIGHT_MARGIN: float = 0.5
## Two parts of the route that should touch may be this far apart (m).
const TOUCH: float = 0.5

const SCENE_HAND: String = "res://scenes/kit/steampunk/clock_hand_platform.tscn"
const SCENE_SLINGSHOT: String = "res://scenes/kit/steampunk/slingshot_core.tscn"
const SCENE_POOL: String = "res://scenes/kit/nature/resin_pool.tscn"
const SCENE_CORE: String = "res://scenes/kit/energy/energy_core.tscn"
const SCENE_BRIDGE: String = "res://scenes/kit/steampunk/drawbridge.tscn"
const SCENE_COLLAPSE: String = "res://scenes/kit/nature/collapse.tscn"
const SCENE_CAPSULE: String = "res://scenes/kit/energy/energy_capsule.tscn"
const ROUTE: Array[String] = [SCENE_HAND, SCENE_SLINGSHOT, SCENE_POOL, SCENE_CORE, SCENE_BRIDGE, SCENE_COLLAPSE]
const HAND_PRESET: String = "res://resources/kit/timed_motion/clock_hand.tres"
const BRIDGE_PRESET: String = "res://resources/kit/timed_motion/drawbridge.tres"
const COLLAPSE_PRESET: String = "res://resources/kit/reaction_to_load/collapse.tres"


func run(tree: SceneTree, check: Callable) -> void:
	var packed: PackedScene = load(GYM_SCENE) as PackedScene
	check.call(packed != null, "the movement gym loads")
	if packed == null:
		return
	var gym: Node = packed.instantiate()
	tree.root.add_child(gym)
	await Fixtures.wait_physics(tree, 2)
	var zone: Node3D = gym.get_node_or_null(ZONE) as Node3D
	check.call(zone != null, "the gym has %s" % ZONE)
	if zone != null:
		var station: Node3D = zone.find_child(STATION, true, false) as Node3D
		check.call(station != null, "%s exists under %s" % [STATION, ZONE])
		_check_zone(zone, check)
		if station != null:
			_check_route(zone, station, check)
			_check_footholds(station, check)
			_check_wiring(station, check)
	gym.queue_free()
	await gym.tree_exited


func _global_name(node: Node) -> String:
	var script: Script = node.get_script() as Script
	return "" if script == null else String(script.get_global_name())


# --- Doc numbers -----------------------------------------------------------------------------------------------------------------------


func _doc() -> String:
	var path: String = ProjectSettings.globalize_path("res://").path_join(DOC_RELATIVE_PATH).simplify_path()
	return FileAccess.get_file_as_string(path)


## The cells of the table row whose first cell is `label`.
func _row(doc: String, label: String) -> PackedStringArray:
	for line: String in doc.split("\n"):
		if line.begins_with("| %s |" % label):
			var cells: PackedStringArray = PackedStringArray()
			for cell: String in line.split("|", false):
				cells.append(cell.strip_edges())
			return cells
	return PackedStringArray()


func _number_before(text: String, unit: String) -> float:
	var regex: RegEx = RegEx.new()
	regex.compile("([0-9]+\\.?[0-9]*) %s" % unit)
	var found: RegExMatch = regex.search(text)
	return float(found.get_string(1)) if found != null else -1.0


# --- Zone ------------------------------------------------------------------------------------------------------------------------------


func _check_zone(zone: Node3D, check: Callable) -> void:
	var range_meta: Variant = zone.get_meta(&"x_range", null)
	check.call(range_meta is Vector2 and (range_meta as Vector2).is_equal_approx(COURSE_X), "%s spans x %s (%s)" % [ZONE, COURSE_X, str(range_meta)])
	var respawn: Marker3D = zone.get_node_or_null("Respawn_%s" % ZONE) as Marker3D
	check.call(respawn != null and respawn.global_position.x >= COURSE_X.x and respawn.global_position.x <= COURSE_X.y, "%s has its own Respawn inside the course" % ZONE)
	var reset: FallReset = zone.get_node_or_null("FallReset_%s" % ZONE) as FallReset
	check.call(reset != null, "%s has its own FallReset" % ZONE)
	check.call(zone.get_node_or_null("Role_Course") != null, "%s has the role group Role_Course" % ZONE)


# --- Route order and layers ------------------------------------------------------------------------------------------------------------


func _instances(station: Node3D) -> Dictionary:
	var by_scene: Dictionary = {}
	for child: Node in station.get_children():
		if child.scene_file_path != "" and child is Node3D:
			by_scene[child.scene_file_path] = child
	return by_scene


func _check_route(zone: Node3D, station: Node3D, check: Callable) -> void:
	var at: Vector3 = station.global_position
	check.call(at.x >= COURSE_X.x and at.x <= COURSE_X.y, "%s stands inside the course x range (%.1f)" % [STATION, at.x])
	var expect: Label3D = station.get_node_or_null("Label_KitCourse_Expect") as Label3D
	check.call(expect != null and expect.text.begins_with("Erwartet:"), "the start sign starts with 'Erwartet:'")
	var by_scene: Dictionary = _instances(station)
	var last_index: int = -1
	var last_x: float = -INF
	var folders: Dictionary = {}
	for scene: String in ROUTE:
		check.call(by_scene.has(scene), "the course instances %s" % scene)
		if not by_scene.has(scene):
			continue
		var node: Node3D = by_scene[scene] as Node3D
		check.call(node.get_index() > last_index, "%s comes after the previous object in route order" % scene)
		check.call(node.position.x > last_x, "%s lies further along +x than the previous object (%.1f > %.1f)" % [scene, node.position.x, last_x])
		last_index = node.get_index()
		last_x = node.position.x
		folders[scene.trim_prefix("res://scenes/kit/").get_slice("/", 0)] = true
	check.call(folders.has("steampunk") and folders.has("energy") and folders.has("nature"), "the course holds an object of each layer (%s)" % str(folders.keys()))
	check.call(by_scene.has(SCENE_CAPSULE), "an energy capsule stands in the course")
	if by_scene.has(SCENE_CAPSULE) and by_scene.has(SCENE_CORE):
		check.call((by_scene[SCENE_CAPSULE] as Node3D).position.x < (by_scene[SCENE_CORE] as Node3D).position.x, "the capsule stands before the energy core")


# --- Footholds against the metrics -----------------------------------------------------------------------------------------------------


## The box of the ledge tiles named <tag>_<layer>: x0, x1 (m, station local) and top.
func _ledge(station: Node3D, tag: String) -> Dictionary:
	var x0: float = INF
	var x1: float = -INF
	var top: float = -INF
	for child: Node in station.get_children():
		var tile: Node3D = child as Node3D
		if tile == null or not tile.name.begins_with("%s_" % tag):
			continue
		x0 = minf(x0, tile.position.x - TILE_HALF)
		x1 = maxf(x1, tile.position.x + TILE_HALF)
		top = maxf(top, tile.position.y + 1.0)
	return {"x0": x0, "x1": x1, "top": top, "found": x0 != INF}


## The stair columns of tag <tag>: column index -> {x0, x1, top}.
func _stairs(station: Node3D, tag: String) -> Dictionary:
	var columns: Dictionary = {}
	for child: Node in station.get_children():
		var tile: Node3D = child as Node3D
		if tile == null or not tile.name.begins_with("%s_" % tag):
			continue
		var column: int = int(tile.name.trim_prefix("%s_" % tag).get_slice("_", 0))
		var entry: Dictionary = columns.get(column, {"x0": INF, "x1": -INF, "top": -INF}) as Dictionary
		entry["x0"] = minf(float(entry["x0"]), tile.position.x - TILE_HALF)
		entry["x1"] = maxf(float(entry["x1"]), tile.position.x + TILE_HALF)
		entry["top"] = maxf(float(entry["top"]), tile.position.y + 1.0)
		columns[column] = entry
	return columns


func _check_footholds(station: Node3D, check: Callable) -> void:
	var doc: String = _doc()
	var run_row: PackedStringArray = _row(doc, "Full jump (run)")
	var apex_row: PackedStringArray = _row(doc, "Full jump (standing)")
	var sling_row: PackedStringArray = _row(doc, "Slingshot (free 2 steps, standing entry)")
	check.call(run_row.size() > 2 and apex_row.size() > 1 and sling_row.size() > 2, "the metrics doc has the jump and slingshot rows")
	if run_row.size() <= 2 or apex_row.size() <= 1 or sling_row.size() <= 2:
		return
	var run_reach: float = float(run_row[2])
	var apex: float = float(apex_row[1])
	var sling_reach: float = _number_before(sling_row[2], "m reach")
	var sling_straight: float = _number_before(sling_row[2], "m straight")
	check.call(run_reach > 0.0 and apex > 0.0 and sling_reach > 0.0 and sling_straight > 0.0, "the doc numbers parse (%.2f, %.2f, %.2f, %.2f)" % [run_reach, apex, sling_reach, sling_straight])
	var max_gap: float = run_reach - GAP_MARGIN
	var max_rise: float = apex - APEX_MARGIN
	var by_scene: Dictionary = _instances(station)
	if not by_scene.has(SCENE_HAND) or not by_scene.has(SCENE_SLINGSHOT) or not by_scene.has(SCENE_BRIDGE) or not by_scene.has(SCENE_COLLAPSE):
		return
	var hand: Node3D = by_scene[SCENE_HAND] as Node3D
	var cage: Node3D = by_scene[SCENE_SLINGSHOT] as Node3D
	var bridge: Node3D = by_scene[SCENE_BRIDGE] as Node3D
	var collapse: Node3D = by_scene[SCENE_COLLAPSE] as Node3D

	# Start: stairs from the floor up to the clock hand's pivot end.
	var stairs: Dictionary = _stairs(station, "HandStep")
	check.call(stairs.size() >= 2, "stairs lead up to the clock hand (%d columns)" % stairs.size())
	var columns: Array = stairs.keys()
	columns.sort()
	columns.reverse()
	var below_top: float = 0.0
	for column: Variant in columns:
		var entry: Dictionary = stairs[column] as Dictionary
		check.call(float(entry["top"]) - below_top <= max_rise + 0.001, "stair column %s rises %.2f m, at most %.2f" % [column, float(entry["top"]) - below_top, max_rise])
		below_top = float(entry["top"])
	if not columns.is_empty():
		var top_step: Dictionary = stairs[columns[columns.size() - 1]] as Dictionary
		var near_edge: float = float(top_step["x1"])
		check.call(hand.position.x - near_edge <= max_gap, "the top stair is %.2f m from the hand's pivot, at most %.2f" % [hand.position.x - near_edge, max_gap])
		check.call(hand.position.y > float(top_step["top"]), "the pivot stands over the top stair (%.2f > %.2f)" % [hand.position.y, float(top_step["top"])])

	# Clock hand tip -> slingshot ledge (run jump); at the sweep limit the tip is closest to the pivot, so the gap is largest there.
	var hand_cfg: TimedMotionConfig = load(HAND_PRESET) as TimedMotionConfig
	var sling_ledge: Dictionary = _ledge(station, "SlingLedge")
	check.call(bool(sling_ledge["found"]), "the slingshot ledge exists")
	if hand_cfg != null and bool(sling_ledge["found"]):
		var tip_far: float = hand.position.x + hand_cfg.hand_length * cos(deg_to_rad(hand_cfg.sweep_limit_deg))
		var gap: float = float(sling_ledge["x0"]) - tip_far
		check.call(gap <= max_gap, "hand tip -> slingshot ledge: worst gap %.2f m, at most %.2f (run jump)" % [gap, max_gap])
		check.call(float(sling_ledge["x0"]) - (hand.position.x + hand_cfg.hand_length) >= 0.0, "the slingshot ledge stands beyond the hand's tip")
		check.call(maxf(float(sling_ledge["top"]) - hand.position.y, 0.0) <= max_rise, "the slingshot ledge is within one jump of the hand")

	# Slingshot ledge -> cage -> landing ledge: the free 2-step straight flight.
	var land: Dictionary = _ledge(station, "LandLedge")
	check.call(bool(land["found"]), "the landing ledge exists")
	if bool(sling_ledge["found"]) and bool(land["found"]):
		check.call(cage.position.x >= float(sling_ledge["x0"]) and cage.position.x <= float(sling_ledge["x1"]), "the cage hangs over the slingshot ledge")
		check.call(cage.position.y - float(sling_ledge["top"]) <= 3.0 + 0.001 and cage.position.y > float(sling_ledge["top"]), "the cage hangs within reach of a jump from the ledge (%.2f m)" % (cage.position.y - float(sling_ledge["top"])))
		var sling_gap: float = float(land["x0"]) - float(sling_ledge["x1"])
		check.call(sling_gap <= sling_reach - GAP_MARGIN, "slingshot ledge -> landing ledge: gap %.2f m, at most %.2f (reach)" % [sling_gap, sling_reach - GAP_MARGIN])
		var to_edge: float = Vector2(float(land["x0"]) - cage.position.x, cage.position.y - float(land["top"])).length()
		check.call(to_edge <= sling_straight - STRAIGHT_MARGIN, "the landing edge lies %.2f m from the cage, inside the %.2f m straight flight (minus %.1f)" % [to_edge, sling_straight, STRAIGHT_MARGIN])

	# Landing ledge -> pool and core ledge (run jump down).
	var core_ledge: Dictionary = _ledge(station, "CoreLedge")
	check.call(bool(core_ledge["found"]), "the pool and core ledge exists")
	if bool(land["found"]) and bool(core_ledge["found"]):
		var drop_gap: float = float(core_ledge["x0"]) - float(land["x1"])
		check.call(drop_gap <= max_gap, "landing ledge -> core ledge: gap %.2f m, at most %.2f" % [drop_gap, max_gap])
		check.call(maxf(float(core_ledge["top"]) - float(land["top"]), 0.0) <= max_rise, "the core ledge is not higher than one jump above the landing ledge")
		if by_scene.has(SCENE_POOL) and by_scene.has(SCENE_CORE):
			var pool: Node3D = by_scene[SCENE_POOL] as Node3D
			var core: Node3D = by_scene[SCENE_CORE] as Node3D
			check.call(pool.position.x > float(core_ledge["x0"]) and pool.position.x < core.position.x, "the resin pool lies on the ledge before the core")
			check.call(core.position.x > float(core_ledge["x0"]) and core.position.x < float(core_ledge["x1"]), "the core stands on the ledge")
			check.call(absf(core.position.y - float(core_ledge["top"])) < 0.01 and absf(pool.position.y - float(core_ledge["top"])) < 0.01, "pool and core stand on the ledge top")
	# From the floor onto the core ledge: a half step or a jump of at most max_rise (the capsule lies on the floor).
	var step: Dictionary = _ledge(station, "CoreStep")
	var floor_rise: float = float(core_ledge["top"]) - (float(step["top"]) if bool(step["found"]) else 0.0)
	check.call(not bool(core_ledge["found"]) or floor_rise <= max_rise, "the core ledge is reachable from the floor in steps of at most %.2f (%.2f)" % [max_rise, floor_rise])

	# Core ledge -> drawbridge -> far ledge: the bridge is the foothold while it is down (hinge at the ledge edge, deck to the far ledge).
	var bridge_cfg: TimedMotionConfig = load(BRIDGE_PRESET) as TimedMotionConfig
	var far: Dictionary = _ledge(station, "BridgeFar")
	check.call(bool(far["found"]), "the ledge behind the bridge exists")
	if bool(core_ledge["found"]) and bool(far["found"]) and bridge_cfg != null:
		check.call(absf(bridge.position.x - float(core_ledge["x1"])) <= TOUCH, "the hinge stands at the core ledge's edge (%.2f vs %.2f)" % [bridge.position.x, float(core_ledge["x1"])])
		check.call(absf(float(far["x0"]) - (bridge.position.x + bridge_cfg.hand_length)) <= TOUCH, "the folded deck ends at the far ledge (%.2f vs %.2f)" % [bridge.position.x + bridge_cfg.hand_length, float(far["x0"])])
		check.call(absf(float(far["top"]) - float(core_ledge["top"])) < 0.01 and absf(bridge.position.y - float(core_ledge["top"])) < 0.01, "ledges and hinge share one height")
		check.call(bridge.basis.z.dot(Vector3.RIGHT) > 0.99, "the bridge folds down toward +x")

	# Far ledge -> collapse strip -> goal ledge: contiguous, ending on a goal platform.
	var collapse_cfg: ReactionToLoadConfig = load(COLLAPSE_PRESET) as ReactionToLoadConfig
	var goal: Dictionary = _ledge(station, "GoalLedge")
	check.call(bool(goal["found"]), "the goal platform exists")
	if collapse_cfg != null and bool(far["found"]) and bool(goal["found"]):
		check.call(collapse_cfg.segments == 6, "the collapse strip has 6 segments (%d)" % collapse_cfg.segments)
		check.call((-collapse.basis.z).dot(Vector3.RIGHT) > 0.99, "the collapse strip runs toward +x")
		var start: float = collapse.position.x - collapse_cfg.deck_size.z * 0.5
		var end: float = start + collapse_cfg.deck_size.z * float(collapse_cfg.segments)
		check.call(absf(start - float(far["x1"])) <= TOUCH, "the strip starts at the far ledge (%.2f vs %.2f)" % [start, float(far["x1"])])
		check.call(absf(float(goal["x0"]) - end) <= TOUCH, "the strip ends at the goal platform (%.2f vs %.2f)" % [end, float(goal["x0"])])
		check.call(absf(float(goal["top"]) - float(far["top"])) < 0.01, "far ledge and goal platform share one height")
		check.call(station.global_position.x + float(goal["x1"]) <= COURSE_X.y, "the goal platform ends inside the course (x %.1f)" % (station.global_position.x + float(goal["x1"])))
	if not columns.is_empty():
		var first_step: Dictionary = stairs[columns[0]] as Dictionary
		check.call(station.global_position.x + float(first_step["x0"]) >= COURSE_X.x, "the first stair starts inside the course")


# --- Wiring (D-46: the drawbridge is switched by the energy core) ----------------------------------------------------------------------


func _check_wiring(station: Node3D, check: Callable) -> void:
	var by_scene: Dictionary = _instances(station)
	if not by_scene.has(SCENE_CORE) or not by_scene.has(SCENE_BRIDGE):
		return
	var core: Node = by_scene[SCENE_CORE] as Node
	var bridge: Node = by_scene[SCENE_BRIDGE] as Node
	var thresholds: Array[Node] = []
	for node: Node in station.find_children("*", "", true, false):
		if _global_name(node) == "LogicThreshold":
			thresholds.append(node)
	check.call(thresholds.size() == 1, "the course holds one LogicThreshold (%d)" % thresholds.size())
	if thresholds.size() != 1:
		return
	check.call(thresholds[0].get("source") == core and int(thresholds[0].get("min_level")) == 1, "the LogicThreshold reads the core at level 1")
	var receiver: Node = bridge.get_node_or_null(^"Receiver")
	check.call(receiver != null and receiver.get("source") == thresholds[0], "the drawbridge Receiver is wired to the LogicThreshold")
	for node: Node in station.find_children("*", "", true, false):
		if _global_name(node) == "Receiver":
			check.call(node.get("source") != null, "the Receiver %s has a wired source" % node.name)
