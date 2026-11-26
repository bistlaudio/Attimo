extends RefCounted
## Worker of tools/movement_gym_builder.gd: Zone_KitNature, the overgrown nature layer area of the kit showroom (Phase 05.1, D-28,
## D-29), x 231..291, the last area along the corridor. Contract: build_into(zone, builder); the shell comes from
## tools/kit_area_shell.gd. Generated, never hand-edited. Nature = world and danger, free, never helps you (resistance): no
## Role_Boosters and no Role_Mechanisms.
##
## Plan view (plan 05.1-21 adds the six Reaction to load stations: Station_CrumblingPlatform, Station_SinkingDebris and Station_TippingTrunk under
## Role_Platforms (south), Station_Collapse, Station_FallingDebris and Station_SnapBloom under Role_Obstacles (north, columns 2..3)): the stations (each a Station_<object> with an "Erwartet:" sign) arrive with their blocks in plans 15-19:
##   south  Role_Platforms (columns 0..3)
##   north  Role_Environment (columns 0..1: LeafStorm (0, 1), ResinPool (1, 1))  Role_Obstacles (columns 2..3)
## The east wall keeps its corridor cells open (plan 22): the connector x 291..295 leads to the mixed course Zone_KitCourse, which has its own
## fall reset; this area's reset ends at its own east edge.

const KitAreaShell := preload("res://tools/kit_area_shell.gd")

const TINT: Color = Color(0.30, 0.42, 0.25)
const ROLES: Array[String] = ["Platforms", "Environment", "Obstacles"]

## Force volume looks (plan 05.1-15, D-26, D-27): the leaf storm resists in gusts, the resin pool drags the run. Both are free.
const LEAF_STORM_SCENE: String = "res://scenes/kit/nature/leaf_storm.tscn"
const RESIN_POOL_SCENE: String = "res://scenes/kit/nature/resin_pool.tscn"

## Reaction to load looks (plan 05.1-21, D-11, D-26, D-27): all FREE, nothing here pays the player. Decks stand on ledges of floor tiles, the gaps
## stay 1.5 m (a plain jump reaches 4 m or more, docs/MOVEMENT-METRICS.md, minus a 1 m margin). Ledge tops stay within one plain jump (2.0 m) of
## the step below. A sinking deck keeps its lowest point 0.3 m over the floor, a tipping trunk its low end 0.9 m over it.
const CRUMBLING_SCENE: String = "res://scenes/kit/nature/crumbling_platform.tscn"
const COLLAPSE_SCENE: String = "res://scenes/kit/nature/collapse.tscn"
const SINKING_SCENE: String = "res://scenes/kit/nature/sinking_debris.tscn"
const TRUNK_SCENE: String = "res://scenes/kit/nature/tipping_trunk.tscn"
const DEBRIS_SCENE: String = "res://scenes/kit/nature/falling_debris.tscn"
const BLOOM_SCENE: String = "res://scenes/kit/nature/snap_bloom.tscn"
const DECK_TOP: float = 1.0
const SINK_TOP: float = 1.9
const TRUNK_TOP: float = 2.2
const DECK_TOP_LIP: float = 0.05
const LEDGE_X: float = 5.5
const TRUNK_LEDGE_X: float = 6.5
const COLLAPSE_START_Z: float = -8.0
const COLLAPSE_SEGMENTS: int = 6
const COLLAPSE_PITCH: float = 2.0

var _shell: KitAreaShell = KitAreaShell.new()


func build_into(zone: Node3D, builder: RefCounted) -> void:
	var signs: Dictionary = {
		"Platforms": _slot("S", 1, 0) + Vector3(6.0, 0.0, -5.0),
		"Environment": _slot("N", 0, 1) + Vector3(6.0, 0.0, 5.0),
		"Obstacles": _slot("N", 2, 1) + Vector3(6.0, 0.0, 5.0),
	}
	var groups: Dictionary = _shell.build_shell(zone, builder, "Natur: Welt und Gefahr", KitAreaShell.NATURE_X.x, KitAreaShell.NATURE_X.y, ROLES, TINT, signs)
	if groups.has("Environment"):
		_build_environment(groups["Environment"] as Node3D, builder)
	if groups.has("Platforms"):
		_build_platforms(groups["Platforms"] as Node3D, builder)
	if groups.has("Obstacles"):
		_build_obstacles(groups["Obstacles"] as Node3D, builder)


## The leaf storm blows along +z at yaw 0, against the approach from the corridor (the player walks north, -z, into the north row); the
## resin pool sits one slot east of it.
func _build_environment(role: Node3D, builder: RefCounted) -> void:
	var storm: Node3D = _shell.station(role, builder, "LeafStorm", _slot("N", 0, 1), "Blättersturm", "Erwartet: Böen drücken gegen deine Laufrichtung, du kommst trotzdem durch", Vector3(-4.5, 4.4, 0.0))
	builder.call(&"_instance", storm, LEAF_STORM_SCENE, "LeafStorm", Vector3.ZERO)
	var pool: Node3D = _shell.station(role, builder, "ResinPool", _slot("N", 1, 1), "Harzlache", "Erwartet: Klebt an den Füßen, du wirst langsamer", Vector3(-3.5, 3.2, 0.0))
	builder.call(&"_instance", pool, RESIN_POOL_SCENE, "ResinPool", Vector3.ZERO)


## Role_Platforms: Station_CrumblingPlatform, Station_SinkingDebris and Station_TippingTrunk in the south rows. Each deck bridges two ledges.
func _build_platforms(role: Node3D, builder: RefCounted) -> void:
	# Station_CrumblingPlatform: a 4 m deck between two ledges.
	var crumble: Node3D = _shell.station(role, builder, "CrumblingPlatform", _slot("S", 0, 0), "Bröckelnde Plattform", "Erwartet: Bricht kurz nach dem Betreten weg und kommt wieder", Vector3(0.0, 4.2, 0.0))
	builder.call(&"_instance", crumble, CRUMBLING_SCENE, "CrumblingPlatform", Vector3(0.0, DECK_TOP - DECK_TOP_LIP, 0.0))
	_shell._ledge(crumble, builder, "CrumbleLedgeWest", -LEDGE_X, 0.0, DECK_TOP)
	_shell._ledge(crumble, builder, "CrumbleLedgeEast", LEDGE_X, 0.0, DECK_TOP)

	# Station_SinkingDebris: a raft with a step up to its ledge.
	var sink: Node3D = _shell.station(role, builder, "SinkingDebris", _slot("S", 2, 0), "Sinkender Schutt", "Erwartet: Gibt unter deinem Gewicht nach", Vector3(0.0, 5.0, 0.0))
	builder.call(&"_instance", sink, SINKING_SCENE, "SinkingDebris", Vector3(0.0, SINK_TOP - DECK_TOP_LIP, 0.0))
	_shell._ledge(sink, builder, "SinkLedgeWest", -LEDGE_X, 0.0, SINK_TOP)
	_shell._ledge(sink, builder, "SinkLedgeEast", LEDGE_X, 0.0, SINK_TOP)
	_shell._ledge(sink, builder, "SinkStepWest", -LEDGE_X - 4.0, 0.0, SINK_TOP * 0.5)

	# Station_TippingTrunk: a 6 m trunk along x between two ledges, each with a step.
	var trunk: Node3D = _shell.station(role, builder, "TippingTrunk", _slot("S", 1, 1), "Kippender Stamm", "Erwartet: Landest du am Ende, kippt er; er wirft dich nicht ab", Vector3(0.0, 5.8, 0.0))
	builder.call(&"_instance", trunk, TRUNK_SCENE, "TippingTrunk", Vector3(0.0, TRUNK_TOP - DECK_TOP_LIP, 0.0), builder.call(&"_yaw", 90.0))
	_shell._ledge(trunk, builder, "TrunkLedgeWest", -TRUNK_LEDGE_X, 0.0, TRUNK_TOP)
	_shell._ledge(trunk, builder, "TrunkLedgeEast", TRUNK_LEDGE_X, 0.0, TRUNK_TOP)
	_shell._ledge(trunk, builder, "TrunkStepWest", -TRUNK_LEDGE_X - 4.0, 0.0, TRUNK_TOP * 0.5)


## Role_Obstacles: Station_Collapse (a 12 m strip between two ledges, north row 0), Station_FallingDebris and Station_SnapBloom (column 3).
func _build_obstacles(role: Node3D, builder: RefCounted) -> void:
	var collapse_at: Vector3 = Vector3(_slot("N", 2, 0).x, 0.0, COLLAPSE_START_Z)
	# Station_Collapse: a 6 segment strip of 2 m decks between a near and a far ledge.
	var collapse: Node3D = _shell.station(role, builder, "Collapse", collapse_at, "Einsturz", "Erwartet: Der Weg bricht hinter dir weg; bleib in Bewegung", Vector3(0.0, 4.2, -6.0))
	builder.call(&"_instance", collapse, COLLAPSE_SCENE, "Collapse", Vector3(0.0, DECK_TOP - DECK_TOP_LIP, -COLLAPSE_PITCH * 0.5))
	_shell._ledge(collapse, builder, "CollapseLedgeNear", 0.0, 2.0, DECK_TOP)
	_shell._ledge(collapse, builder, "CollapseLedgeFar", 0.0, -COLLAPSE_PITCH * float(COLLAPSE_SEGMENTS) - 2.0, DECK_TOP)

	# Station_FallingDebris: debris hanging 6 m over the station point.
	var debris: Node3D = _shell.station(role, builder, "FallingDebris", _slot("N", 3, 0), "Fallender Schutt", "Erwartet: Fällt, wenn du nahe kommst; ein Treffer stößt dich weg", Vector3(-3.5, 3.4, 0.0))
	builder.call(&"_instance", debris, DEBRIS_SCENE, "FallingDebris", Vector3.ZERO)
	# Station_SnapBloom: a plant at the station point, jaws toward +z.
	var bloom: Node3D = _shell.station(role, builder, "SnapBloom", _slot("N", 3, 1), "Schnappblüte", "Erwartet: Schnappt zu, wenn du nahe kommst; ausweichen oder schnell vorbei", Vector3(-3.5, 3.4, 0.0))
	builder.call(&"_instance", bloom, BLOOM_SCENE, "SnapBloom", Vector3.ZERO)


## Slot (column, row) on `side` of this area.
func _slot(side: String, column: int, row: int) -> Vector3:
	return _shell.slot(KitAreaShell.NATURE_X.x, side, column, row)
