extends RefCounted
## Worker of tools/movement_gym_builder.gd: Zone_KitEnergy, the energy layer area of the kit showroom (Phase 05.1, D-28, D-29),
## x 155..227 east of the steampunk area. A new zone: it is NOT the Phase 5 Zone_Energy west of the Loader room, which keeps its
## layout (D-30). Contract: build_into(zone, builder); the shell comes from tools/kit_area_shell.gd. Generated, never hand-edited.
## Energy = turquoise, costs or is amplified (decision). Platforms are neutral, so the area has no Role_Platforms.
##
## Plan view: the Energy source stations (capsule, broken machine) stand under Role_Mechanisms; the other stations (each a Station_<object> with an "Erwartet:" sign, a capsule beside every
## target station) arrive with their blocks in plans 08-19:
##   north  Role_Environment (columns 0..1)  Role_Obstacles (columns 3..4)
##   south  Role_Boosters (columns 0..1)     Role_Mechanisms (columns 2..4)

const KitAreaShell := preload("res://tools/kit_area_shell.gd")

const CAPSULE_SCENE: String = "res://scenes/kit/energy/energy_capsule.tscn"
const MACHINE_SCENE: String = "res://scenes/kit/energy/broken_machine.tscn"
const FIELD_SCENE: String = "res://scenes/kit/energy/loader_field.tscn"
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
	var groups: Dictionary = _shell.build_shell(zone, builder, "Energie: kostet oder verstärkt", KitAreaShell.ENERGY_X.x, KitAreaShell.ENERGY_X.y, ROLES, TINT, signs)
	if groups.has("Mechanisms"):
		_build_energy_sources(groups["Mechanisms"] as Node3D, builder)
	if groups.has("Obstacles"):
		_build_loader_field(groups["Obstacles"] as Node3D, builder)


## Energy source (plan 05.1-10, D-42): the capsule (+3, dark, refills) and the broken machine (+5 in about 2 s), each on its own
## station, one slot (12 m) apart. Both refill so the station can be tried again.
func _build_energy_sources(role: Node3D, builder: RefCounted) -> void:
	var capsule_at: Vector3 = _slot("S", 2, 1)
	var capsule: Node3D = _shell.station(role, builder, "EnergyCapsule", capsule_at, "Energiekapsel", "Erwartet: Linksklick halten: Strahl zur Kapsel, +3 Stufen, Kapsel wird dunkel und füllt sich wieder")
	var capsule_node: Node3D = builder.call(&"_instance", capsule, CAPSULE_SCENE, "Capsule", Vector3.ZERO) as Node3D
	capsule_node.call("set_respawn", KitAreaShell.CAPSULE_RESPAWN)
	var machine: Node3D = _shell.station(role, builder, "BrokenMachine", _slot("S", 3, 1), "Kaputte Maschine", "Erwartet: Linksklick halten: +5 Stufen in etwa 2 s")
	var machine_node: Node3D = builder.call(&"_instance", machine, MACHINE_SCENE, "Machine", Vector3.ZERO) as Node3D
	machine_node.call("set_respawn", KitAreaShell.CAPSULE_RESPAWN)


## Loader field (plan 05.1-13, D-53), Station_LoaderField under Role_Obstacles: a field across the slot lane, the plane facing the corridor (south); the capsule beside it feeds the
## Loader. Only a Loader with at least 2 paid steps glides through (and slows down), everything else bounces off softly.
func _build_loader_field(role: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = _slot("N", 3, 0)
	var station: Node3D = _shell.station(role, builder, "LoaderField", at, "Loader-Feld", "Erwartet: Nur ein Loader mit mindestens 2 Stufen gleitet hindurch und wird langsamer; alles andere prallt sanft ab")
	builder.call(&"_instance", station, FIELD_SCENE, "LoaderField", Vector3.ZERO)
	_shell.capsule_beside(station, builder, at + Vector3(0.0, 0.0, 4.0))


## Slot (column, row) on `side` of this area.
func _slot(side: String, column: int, row: int) -> Vector3:
	return _shell.slot(KitAreaShell.ENERGY_X.x, side, column, row)
