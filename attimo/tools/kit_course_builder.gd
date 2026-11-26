extends RefCounted
## Worker of tools/movement_gym_builder.gd: Zone_KitCourse, the mixed course of the kit showroom (Phase 05.1 plan 22, D-31 amended, D-46),
## x 295..395, the last area behind the nature area's east corridor. Contract: build_into(zone, builder); the shell (floor, walls, header,
## own Respawn and FallReset, Role_Course) comes from tools/kit_area_shell.gd. Generated, never hand-edited.
##
## One short route along +x that combines the three layers, every gap computed from docs/MOVEMENT-METRICS.md minus a margin (never typed):
##   floor -> stairs up to the pivot of the CLOCK HAND (steampunk, always on) -> run jump from its tip to the SLINGSHOT ledge -> the cage hangs
##   over the ledge edge, a free 2-step straight flight lands on the LANDING ledge -> run jump (down) to the CORE LEDGE with the RESIN POOL
##   (nature, free, slows you) and the ENERGY CORE (energy, pay in with E) -> a LogicThreshold of the core at level 1 folds the DRAWBRIDGE down ->
##   far ledge -> the 6-segment COLLAPSE strip (nature) -> goal platform. A capsule stands on the floor before the core (the core costs steps),
##   a half step leads from the floor to the core ledge. Station-local frame: the hand's pivot is the origin, +x is the route direction.

const KitAreaShell := preload("res://tools/kit_area_shell.gd")

const TINT: Color = Color(0.40, 0.38, 0.34)
const ROLES: Array[String] = ["Course"]
## World x of the clock hand's pivot: the stairs reach 16.5 m west of it (x 296.5), the goal platform ends under 80 m east of it.
const PIVOT_X: float = 313.0
const RESET_EAST: float = 30.0
const DOC_RELATIVE_PATH: String = "../docs/MOVEMENT-METRICS.md"

const CLOCK_HAND_SCENE: String = "res://scenes/kit/steampunk/clock_hand_platform.tscn"
const CLOCK_HAND_PRESET: String = "res://resources/kit/timed_motion/clock_hand.tres"
const DRAWBRIDGE_PRESET: String = "res://resources/kit/timed_motion/drawbridge.tres"
const SLINGSHOT_SCENE: String = "res://scenes/kit/steampunk/slingshot_core.tscn"
const SLINGSHOT_HANG: float = 3.0
const RESIN_POOL_SCENE: String = "res://scenes/kit/nature/resin_pool.tscn"
const CORE_SCENE: String = "res://scenes/kit/energy/energy_core.tscn"
const DRAWBRIDGE_SCENE: String = "res://scenes/kit/steampunk/drawbridge.tscn"
const COLLAPSE_SCENE: String = "res://scenes/kit/nature/collapse.tscn"
const COLLAPSE_PRESET: String = "res://resources/kit/reaction_to_load/collapse.tres"
const THRESHOLD_SCRIPT: String = "res://scripts/kit/logic/logic_threshold.gd"

## Safety margins on the doc numbers: a gap stays this far in m under the reach of its move, a step this far under the full-jump apex.
const GAP_MARGIN: float = 1.0
const APEX_MARGIN: float = 0.3
## A planned gap is this share of the usable (reach minus margin) gap, so the route is generous, never at the limit.
const GAP_SHARE: float = 0.5
## No stair is higher than this (the held plain jump reaches the doc's full-jump apex, minus APEX_MARGIN).
const DECK_STEP_MAX: float = 1.5
const DECK_LEDGE_GAP: float = 0.25
## The slingshot landing ledge stands this far under the slingshot ledge (m), a drop never hurts.
const LANDING_DROP: float = 1.5
const LEDGE_Z: Array[float] = [-2.0, 2.0]
const TILE: float = 4.0
const POOL_OFFSET: float = 3.0
const CORE_BEFORE_HINGE: float = 3.3
const CAPSULE_X_OFFSET: float = 0.7
const COLLAPSE_LIP: float = 0.05

var _shell: KitAreaShell = KitAreaShell.new()


func build_into(zone: Node3D, builder: RefCounted) -> void:
	var numbers: Dictionary = _doc_numbers()
	if numbers.is_empty():
		builder.set(&"failure", "kit course: docs/MOVEMENT-METRICS.md lacks the jump or slingshot rows (run the metrics tool first)")
		return
	var signs: Dictionary = {"Course": Vector3(PIVOT_X - 8.0, 0.0, 8.0)}
	var groups: Dictionary = _shell.build_shell(zone, builder, "Gemischter Parcours: drei Ebenen in einer Route", KitAreaShell.COURSE_X.x, KitAreaShell.COURSE_X.y, ROLES, TINT, signs, false, RESET_EAST)
	if not groups.has("Course"):
		return
	var expect: String = "Erwartet: Uhrzeiger -> Schleuderkern -> Harzlache -> Kern zahlen, Zugbrücke runter -> Einsturz, ohne anzuhalten"
	var station: Node3D = _shell.station(groups["Course"] as Node3D, builder, "KitCourse", Vector3(PIVOT_X, 0.0, 0.0), "Gemischter Parcours", expect, Vector3(-12.0, 4.0, 6.0))
	_build_route(station, builder, numbers)


## The reach numbers of the doc: run jump distance, full-jump apex, slingshot reach and straight flight (all m). Empty when a row is missing.
func _doc_numbers() -> Dictionary:
	var path: String = ProjectSettings.globalize_path("res://").path_join(DOC_RELATIVE_PATH).simplify_path()
	var doc: String = FileAccess.get_file_as_string(path)
	var run: PackedStringArray = _row(doc, "Full jump (run)")
	var apex: PackedStringArray = _row(doc, "Full jump (standing)")
	var sling: PackedStringArray = _row(doc, "Slingshot (free 2 steps, standing entry)")
	if run.size() < 3 or apex.size() < 2 or sling.size() < 3:
		return {}
	var numbers: Dictionary = {
		"run_reach": float(run[2]),
		"apex": float(apex[1]),
		"sling_reach": _number_before(sling[2], "m reach"),
		"sling_straight": _number_before(sling[2], "m straight"),
	}
	for key: Variant in numbers:
		if float(numbers[key]) <= 0.0:
			return {}
	return numbers


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


## One 8 m wide ledge of 4 m tiles from x0 on, `columns` tiles long, tag <tag>_<column>_<row>; returns its east edge.
func _ledge(station: Node3D, builder: RefCounted, tag: String, x0: float, columns: int, top: float) -> float:
	for column: int in columns:
		for row: int in LEDGE_Z.size():
			_shell.call(&"_ledge", station, builder, "%s_%d_%d" % [tag, column, row], x0 + TILE * (float(column) + 0.5), LEDGE_Z[row], top)
	return x0 + TILE * float(columns)


func _build_route(station: Node3D, builder: RefCounted, numbers: Dictionary) -> void:
	var max_gap: float = float(numbers["run_reach"]) - GAP_MARGIN
	var hand_gap: float = max_gap * GAP_SHARE
	var sling_gap: float = (float(numbers["sling_reach"]) - GAP_MARGIN) * GAP_SHARE
	var top: float = KitAreaShell.LEDGE_TOP
	var east: Basis = builder.call(&"_yaw", 90.0) as Basis

	# 1. Clock hand (steampunk): pivot at the minimum height of its preset, a stair of floor tiles leads up behind the pivot.
	var hand_cfg: TimedMotionConfig = load(CLOCK_HAND_PRESET) as TimedMotionConfig
	var pivot_y: float = TimedMotion.min_pivot_height(hand_cfg, 0.0)
	var highest: float = floorf((pivot_y - DECK_LEDGE_GAP) * 2.0) * 0.5
	_hand_stairs(station, builder, highest, minf(DECK_STEP_MAX, float(numbers["apex"]) - APEX_MARGIN))
	builder.call(&"_instance", station, CLOCK_HAND_SCENE, "ClockHand", Vector3(0.0, pivot_y, 0.0), east)

	# 2. Slingshot (steampunk): a ledge a run jump from the hand's tip, the cage hangs over its east edge, a free flight lands further east and lower.
	var sling_x0: float = hand_cfg.hand_length + hand_gap
	var sling_x1: float = _ledge(station, builder, "SlingLedge", sling_x0, 2, highest)
	builder.call(&"_instance", station, SLINGSHOT_SCENE, "Slingshot", Vector3(sling_x1 - 1.0, highest + SLINGSHOT_HANG, 0.0))
	var land_x0: float = sling_x1 + sling_gap
	var land_x1: float = _ledge(station, builder, "LandLedge", land_x0, 2, highest - LANDING_DROP)

	# 3. Pool and core ledge (nature, energy): a run jump down, the pool first, then the core before the hinge.
	var core_x0: float = land_x1 + hand_gap
	var core_x1: float = _ledge(station, builder, "CoreLedge", core_x0, 3, top)
	builder.call(&"_instance", station, RESIN_POOL_SCENE, "ResinPool", Vector3(core_x0 + POOL_OFFSET, top, 0.0))
	var core: Node3D = builder.call(&"_instance", station, CORE_SCENE, "Core", Vector3(core_x1 - CORE_BEFORE_HINGE, top, 0.0)) as Node3D
	# A half step from the floor to the ledge on its south side, the capsule on the floor before the core.
	_shell.call(&"_ledge", station, builder, "CoreStep_0", core_x0 + TILE * 1.5, KitAreaShell.CORE_STEP_Z, KitAreaShell.STEP_TOP)
	_shell.capsule_beside(station, builder, station.position + Vector3(core_x0 + CAPSULE_X_OFFSET, 0.0, KitAreaShell.CORE_STEP_Z + 0.5))

	# 4. Drawbridge (steampunk), switched by the core at level 1 (D-46): the hinge at the ledge edge, the deck down to the far ledge.
	var bridge_cfg: TimedMotionConfig = load(DRAWBRIDGE_PRESET) as TimedMotionConfig
	var bridge: Node3D = builder.call(&"_instance", station, DRAWBRIDGE_SCENE, "Drawbridge", Vector3(core_x1, top, 0.0), east) as Node3D
	var threshold: Node3D = (load(THRESHOLD_SCRIPT) as GDScript).new() as Node3D
	threshold.visible = false
	threshold.set(&"source", core)
	threshold.set(&"min_level", 1)
	builder.call(&"_adopt", station, threshold, "Level1", Vector3.ZERO)
	_shell.wire_receiver(bridge, builder, threshold)
	var far_x0: float = core_x1 + bridge_cfg.hand_length
	var far_x1: float = _ledge(station, builder, "BridgeFar", far_x0, 1, top)

	# 5. Collapse (nature): 6 decks along +x from the far ledge, then the goal platform.
	var collapse_cfg: ReactionToLoadConfig = load(COLLAPSE_PRESET) as ReactionToLoadConfig
	var deck: float = collapse_cfg.deck_size.z
	var strip_x1: float = far_x1 + deck * float(collapse_cfg.segments)
	builder.call(&"_instance", station, COLLAPSE_SCENE, "Collapse", Vector3(far_x1 + deck * 0.5, top - COLLAPSE_LIP, 0.0), builder.call(&"_yaw", -90.0))
	_ledge(station, builder, "GoalLedge", strip_x1, 2, top)


## Stairs of 4 m tiles up to `highest` behind the hand's pivot (the first column at x -2.5, each further column 4 m west and one equal step lower,
## no step above `step_max`). Tag HandStep_<column>_<layer>.
func _hand_stairs(station: Node3D, builder: RefCounted, highest: float, step_max: float) -> void:
	var columns: int = maxi(ceili(highest / step_max), 1)
	for column: int in columns:
		var step_top: float = highest * float(columns - column) / float(columns)
		var x: float = -2.5 - TILE * float(column)
		var layer: int = 0
		while step_top - float(layer) > 0.0:
			builder.call(&"_floor_tile", station, "HandStep_%d_%d" % [column, layer], x, step_top - float(layer), 0.0)
			layer += 1
