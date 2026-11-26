extends RefCounted
## Worker of tools/movement_gym_builder.gd: Zone_KitNature, the overgrown nature layer area of the kit showroom (Phase 05.1, D-28,
## D-29), x 231..291, the last area along the corridor. Contract: build_into(zone, builder); the shell comes from
## tools/kit_area_shell.gd. Generated, never hand-edited. Nature = world and danger, free, never helps you (resistance): no
## Role_Boosters and no Role_Mechanisms.
##
## Plan view: the stations (each a Station_<object> with an "Erwartet:" sign) arrive with their blocks in plans 15-19:
##   south  Role_Platforms (columns 0..3)
##   north  Role_Environment (columns 0..1: LeafStorm (0, 1), ResinPool (1, 1))  Role_Obstacles (columns 2..3)
## The east wall stays closed until the mixed course (Zone_KitCourse, x 295..395) lands in plan 20; the fall reset reaches
## NATURE_RESET_EAST past the east wall so a throw over it is still caught (plan 20 shrinks it when the course gets its own reset).

const KitAreaShell := preload("res://tools/kit_area_shell.gd")

const TINT: Color = Color(0.30, 0.42, 0.25)
const ROLES: Array[String] = ["Platforms", "Environment", "Obstacles"]
const NATURE_RESET_EAST: float = 30.0

## Force volume looks (plan 05.1-15, D-26, D-27): the leaf storm resists in gusts, the resin pool drags the run. Both are free.
const LEAF_STORM_SCENE: String = "res://scenes/kit/nature/leaf_storm.tscn"
const RESIN_POOL_SCENE: String = "res://scenes/kit/nature/resin_pool.tscn"

var _shell: KitAreaShell = KitAreaShell.new()


func build_into(zone: Node3D, builder: RefCounted) -> void:
	var signs: Dictionary = {
		"Platforms": _slot("S", 1, 0) + Vector3(6.0, 0.0, -5.0),
		"Environment": _slot("N", 0, 1) + Vector3(6.0, 0.0, 5.0),
		"Obstacles": _slot("N", 2, 1) + Vector3(6.0, 0.0, 5.0),
	}
	var groups: Dictionary = _shell.build_shell(zone, builder, "Natur: Welt und Gefahr", KitAreaShell.NATURE_X.x, KitAreaShell.NATURE_X.y, ROLES, TINT, signs, false, NATURE_RESET_EAST)
	if groups.has("Environment"):
		_build_environment(groups["Environment"] as Node3D, builder)


## The leaf storm blows along +z at yaw 0, against the approach from the corridor (the player walks north, -z, into the north row); the
## resin pool sits one slot east of it.
func _build_environment(role: Node3D, builder: RefCounted) -> void:
	var storm: Node3D = _shell.station(role, builder, "LeafStorm", _slot("N", 0, 1), "Blättersturm", "Erwartet: Böen drücken gegen deine Laufrichtung, du kommst trotzdem durch", Vector3(-4.5, 4.4, 0.0))
	builder.call(&"_instance", storm, LEAF_STORM_SCENE, "LeafStorm", Vector3.ZERO)
	var pool: Node3D = _shell.station(role, builder, "ResinPool", _slot("N", 1, 1), "Harzlache", "Erwartet: Klebt an den Füßen, du wirst langsamer", Vector3(-3.5, 3.2, 0.0))
	builder.call(&"_instance", pool, RESIN_POOL_SCENE, "ResinPool", Vector3.ZERO)


## Slot (column, row) on `side` of this area.
func _slot(side: String, column: int, row: int) -> Vector3:
	return _shell.slot(KitAreaShell.NATURE_X.x, side, column, row)
