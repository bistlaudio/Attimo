extends RefCounted
## Worker of tools/movement_gym_builder.gd: Zone_KitNature, the overgrown nature layer area of the kit showroom (Phase 05.1, D-28,
## D-29), x 231..291, the last area along the corridor. Contract: build_into(zone, builder); the shell comes from
## tools/kit_area_shell.gd. Generated, never hand-edited. Nature = world and danger, free, never helps you (resistance): no
## Role_Boosters and no Role_Mechanisms.
##
## Plan view: role groups only for now; the stations (each a Station_<object> with an "Erwartet:" sign) arrive with their blocks in
## plans 08-19:
##   south  Role_Platforms (columns 0..3)
##   north  Role_Environment (columns 0..1)  Role_Obstacles (columns 2..3)
## The east wall stays closed until the mixed course (Zone_KitCourse, x 295..395) lands in plan 20; the fall reset reaches
## NATURE_RESET_EAST past the east wall so a throw over it is still caught (plan 20 shrinks it when the course gets its own reset).

const KitAreaShell := preload("res://tools/kit_area_shell.gd")

const TINT: Color = Color(0.30, 0.42, 0.25)
const ROLES: Array[String] = ["Platforms", "Environment", "Obstacles"]
const NATURE_RESET_EAST: float = 30.0

var _shell: KitAreaShell = KitAreaShell.new()


func build_into(zone: Node3D, builder: RefCounted) -> void:
	var signs: Dictionary = {
		"Platforms": _slot("S", 1, 0) + Vector3(6.0, 0.0, -5.0),
		"Environment": _slot("N", 0, 1) + Vector3(6.0, 0.0, 5.0),
		"Obstacles": _slot("N", 2, 1) + Vector3(6.0, 0.0, 5.0),
	}
	_shell.build_shell(zone, builder, "Natur: Welt und Gefahr", KitAreaShell.NATURE_X.x, KitAreaShell.NATURE_X.y, ROLES, TINT, signs, false, NATURE_RESET_EAST)


## Slot (column, row) on `side` of this area.
func _slot(side: String, column: int, row: int) -> Vector3:
	return _shell.slot(KitAreaShell.NATURE_X.x, side, column, row)
