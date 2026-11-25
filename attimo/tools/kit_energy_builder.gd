extends RefCounted
## Worker of tools/movement_gym_builder.gd: Zone_KitEnergy, the energy layer area of the kit showroom (Phase 05.1, D-28, D-29),
## x 155..227 east of the steampunk area. A new zone: it is NOT the Phase 5 Zone_Energy west of the Loader room, which keeps its
## layout (D-30). Contract: build_into(zone, builder); the shell comes from tools/kit_area_shell.gd. Generated, never hand-edited.
## Energy = turquoise, costs or is amplified (decision). Platforms are neutral, so the area has no Role_Platforms.
##
## Plan view: role groups only for now; the stations (each a Station_<object> with an "Erwartet:" sign, a capsule beside every
## target station) arrive with their blocks in plans 08-19:
##   north  Role_Environment (columns 0..1)  Role_Obstacles (columns 3..4)
##   south  Role_Boosters (columns 0..1)     Role_Mechanisms (columns 2..4)

const KitAreaShell := preload("res://tools/kit_area_shell.gd")

const TINT: Color = Color(0.16, 0.40, 0.42)
const ROLES: Array[String] = ["Environment", "Obstacles", "Boosters", "Mechanisms"]

var _shell: KitAreaShell = KitAreaShell.new()


func build_into(zone: Node3D, builder: RefCounted) -> void:
	var signs: Dictionary = {
		"Environment": _slot("N", 0, 1) + Vector3(6.0, 0.0, 5.0),
		"Obstacles": _slot("N", 3, 1) + Vector3(6.0, 0.0, 5.0),
		"Boosters": _slot("S", 0, 0) + Vector3(6.0, 0.0, -5.0),
		"Mechanisms": _slot("S", 3, 0) + Vector3(0.0, 0.0, -5.0),
	}
	_shell.build_shell(zone, builder, "Energie: kostet oder verstärkt", KitAreaShell.ENERGY_X.x, KitAreaShell.ENERGY_X.y, ROLES, TINT, signs)


## Slot (column, row) on `side` of this area.
func _slot(side: String, column: int, row: int) -> Vector3:
	return _shell.slot(KitAreaShell.ENERGY_X.x, side, column, row)
