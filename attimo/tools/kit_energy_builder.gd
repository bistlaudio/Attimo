extends RefCounted
## Worker of tools/movement_gym_builder.gd: Zone_KitEnergy, the energy layer area of the kit showroom (Phase 05.1, D-28, D-29),
## x 155..227 east of the steampunk area. A new zone: it is NOT the Phase 5 Zone_Energy west of the Loader room, which keeps its
## layout (D-30). Contract: build_into(zone, builder); the shell comes from tools/kit_area_shell.gd. Generated, never hand-edited.
## Energy = turquoise, costs or is amplified (decision). Platforms are neutral, so the area has no Role_Platforms.
##
## Plan view (05.1-18): the Energy core station (Station_EnergyCore, a core and three outputs) at N(1, 0), the AND station at S(0, 1), the OR station
## at S(4, 0) (all three under Role_Mechanisms), the Attraction field station at N(4, 1) under Role_Environment. The Charge gate station (plan 05.1-17) stands at S(2, 0) under Role_Mechanisms; the Energy source stations (capsule, broken machine) stand under Role_Mechanisms; the other stations (each a Station_<object> with an "Erwartet:" sign, a capsule beside every
## target station) arrive with their blocks in plans 08-19:
##   north  Role_Environment (columns 0..1)  Role_Obstacles (columns 3..4)
##   south  Role_Boosters (columns 0..1)     Role_Mechanisms (columns 2..4)

const KitAreaShell := preload("res://tools/kit_area_shell.gd")

const CAPSULE_SCENE: String = "res://scenes/kit/energy/energy_capsule.tscn"
const MACHINE_SCENE: String = "res://scenes/kit/energy/broken_machine.tscn"
const FIELD_SCENE: String = "res://scenes/kit/energy/loader_field.tscn"
const BOUNCE_CORE_SCENE: String = "res://scenes/kit/energy/bounce_pad_core.tscn"
const GRAVITY_ZONE_SCENE: String = "res://scenes/kit/energy/gravity_zone.tscn"
const CORE_SCENE: String = "res://scenes/kit/energy/energy_core.tscn"
const GATE_SCENE: String = "res://scenes/kit/energy/charge_gate.tscn"
const FIELD_SCENE_ATTRACTION: String = "res://scenes/kit/energy/attraction_field.tscn"
const THRESHOLD_SCRIPT: String = "res://scripts/kit/logic/logic_threshold.gd"
const AND_SCENE: String = "res://scenes/mechanisms/logic_and.tscn"
const OR_SCENE: String = "res://scenes/mechanisms/logic_or.tscn"
const TIMER_SCENE: String = "res://scenes/mechanisms/logic_timer.tscn"
const DRAWBRIDGE_SCENE: String = "res://scenes/kit/steampunk/drawbridge.tscn"
const SWITCHED_PAD_SCENE: String = "res://scenes/kit/steampunk/speed_pad_switched.tscn"
## Top in m of the near and far ledges (the drawbridge hinge height) and of the higher ledge behind the second bridge.
const LEDGE_TOP: float = 1.5
const HIGH_LEDGE_TOP: float = 2.0
const STEP_TOP: float = 0.5
## Seconds the gate keeps the OR station's pad switched (it only reads while the player stands in the gate).
const OR_PAD_HOLD: float = 5.0
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
		_build_charge_gate(groups["Mechanisms"] as Node3D, builder)
		_build_energy_core(groups["Mechanisms"] as Node3D, builder)
		_build_logic_and(groups["Mechanisms"] as Node3D, builder)
		_build_logic_or(groups["Mechanisms"] as Node3D, builder)
	if groups.has("Obstacles"):
		_build_loader_field(groups["Obstacles"] as Node3D, builder)
	if groups.has("Boosters"):
		_build_bounce_core(groups["Boosters"] as Node3D, builder)
	if groups.has("Environment"):
		_build_gravity_zone(groups["Environment"] as Node3D, builder)
		_build_attraction_field(groups["Environment"] as Node3D, builder)


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


## Amplification (plan 05.1-16, D-24): the bounce pad with core (Role_Boosters) and the gravity zone (Role_Environment). Neither spends
## energy; the fuller the clock, the higher the bounce and the longer the float. A capsule stands beside each.
func _build_bounce_core(role: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = _slot("S", 0, 0)
	var station: Node3D = _shell.station(role, builder, "BouncePadCore", at, "Sprungplatte mit Kern", "Erwartet: Je voller die Uhr, desto höher; verbraucht nichts", Vector3(0.0, 3.2, -3.0))
	builder.call(&"_instance", station, BOUNCE_CORE_SCENE, "Pad", Vector3.ZERO)
	_shell.capsule_beside(station, builder, at + Vector3(4.5, 0.0, 0.0))


func _build_gravity_zone(role: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = _slot("N", 0, 1)
	var station: Node3D = _shell.station(role, builder, "GravityZone", at, "Schwerezone", "Erwartet: Je voller die Uhr, desto länger schwebst du; verbraucht nichts", Vector3(0.0, 5.2, 0.0))
	builder.call(&"_instance", station, GRAVITY_ZONE_SCENE, "Zone", Vector3.ZERO)
	_shell.capsule_beside(station, builder, at + Vector3(0.0, 0.0, 5.5))


## Charge gate (plan 05.1-17, D-21, D-47), Station_ChargeGate under Role_Mechanisms at S(2, 0), the bridge running east over a pit: the gate
## only checks the steps (never spends them) and, through an invisible 10 s timer, folds a drawbridge down. A capsule stands beside it.
func _build_charge_gate(role: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = _slot("S", 2, 0)
	var station: Node3D = _shell.station(role, builder, "ChargeGate", at, "Ladetor", "Erwartet: Prüft nur, verbraucht nichts: mit mindestens 6 Stufen im Bogen klappt die Brücke 10 s lang herunter", Vector3(-4.0, 8.6, 0.0))
	_shell.bridge_course(station, builder, "Gate")
	_shell.capsule_beside(station, builder, at + Vector3(-6.0, 0.0, 6.5))


## Energy core (plan 05.1-18, D-20 amended, D-37, D-47), Station_EnergyCore under Role_Mechanisms on a near ledge (top 1.5 m). Holding E at the core pays
## 1 step per 0.4 s and the paid steps stay on the core; at 3 / 6 / 9 steps three LogicThreshold outputs switch one more piece each: level 1 folds the
## east drawbridge down over the pit, level 2 switches the speed pad that points at it, level 3 folds the north drawbridge down to a ledge half a metre
## higher. No output is a door. A capsule stands at the foot of the ledge.
func _build_energy_core(role: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = Vector3(179.0, 0.0, -8.0)
	var station: Node3D = _shell.station(role, builder, "EnergyCore", at, "Energiekern", "Erwartet: E halten zahlt 1 Stufe pro Tick ein; bei 3 / 6 / 9 schaltet je ein weiteres Stück; das Eingezahlte bleibt", Vector3(-4.0, 8.6, 0.0))
	for x: float in [-6.0, -2.0]:
		for z: float in [-2.0, 2.0]:
			_shell.call(&"_ledge", station, builder, "Near_%d_%d" % [int(x), int(z)], x, z, LEDGE_TOP)
	for x: float in [10.0, 14.0]:
		for z: float in [-2.0, 2.0]:
			_shell.call(&"_ledge", station, builder, "Far_%d_%d" % [int(x), int(z)], x, z, LEDGE_TOP)
	for x: float in [-6.0, -2.0]:
		for z: float in [-14.0, -18.0]:
			_shell.call(&"_ledge", station, builder, "High_%d_%d" % [int(x), int(-z)], x, z, HIGH_LEDGE_TOP)
	_shell.call(&"_ledge", station, builder, "Step", -6.0, 6.0, STEP_TOP)
	var core: Node3D = builder.call(&"_instance", station, CORE_SCENE, "Core", Vector3(-6.5, LEDGE_TOP, 0.0)) as Node3D
	var east: Basis = builder.call(&"_yaw", 90.0) as Basis
	var north: Basis = builder.call(&"_yaw", 180.0) as Basis
	var pad: Node3D = builder.call(&"_instance", station, SWITCHED_PAD_SCENE, "Pad", Vector3(-3.0, LEDGE_TOP, 0.0), builder.call(&"_yaw", -90.0)) as Node3D
	var bridge_a: Node3D = builder.call(&"_instance", station, DRAWBRIDGE_SCENE, "BridgeEast", Vector3(0.0, LEDGE_TOP, 0.0), east) as Node3D
	var bridge_b: Node3D = builder.call(&"_instance", station, DRAWBRIDGE_SCENE, "BridgeNorth", Vector3(-4.0, LEDGE_TOP, -4.0), north) as Node3D
	var outputs: Array[Node3D] = [bridge_a, pad, bridge_b]
	for index: int in outputs.size():
		var threshold: Node3D = _threshold(station, builder, "Level%d" % (index + 1), core, index + 1)
		_shell.wire_receiver(outputs[index], builder, threshold)
	_shell.capsule_beside(station, builder, at + Vector3(-10.0, 0.0, 0.0))


## AND station (plan 05.1-18, GAME-DESIGN 6.9), Station_LogicAnd under Role_Mechanisms: two energy cores on a near ledge and one drawbridge east over the pit.
## The bridge folds down only while both cores have at least level 1 (3 paid steps each).
func _build_logic_and(role: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = Vector3(167.0, 0.0, 22.0)
	var station: Node3D = _shell.station(role, builder, "LogicAnd", at, "Zwei Kerne, eine Brücke", "Erwartet: Erst wenn beide Kerne Stufe 1 haben, kommt die Brücke", Vector3(-4.0, 6.6, 0.0))
	for x: float in [-6.0, -2.0]:
		for z: float in [-2.0, 2.0]:
			_shell.call(&"_ledge", station, builder, "Near_%d_%d" % [int(x), int(z)], x, z, LEDGE_TOP)
	for x: float in [10.0, 14.0]:
		for z: float in [-2.0, 2.0]:
			_shell.call(&"_ledge", station, builder, "Far_%d_%d" % [int(x), int(z)], x, z, LEDGE_TOP)
	_shell.call(&"_ledge", station, builder, "Step", -6.0, 6.0, STEP_TOP)
	var core_a: Node3D = builder.call(&"_instance", station, CORE_SCENE, "CoreA", Vector3(-6.5, LEDGE_TOP, -1.8)) as Node3D
	var core_b: Node3D = builder.call(&"_instance", station, CORE_SCENE, "CoreB", Vector3(-6.5, LEDGE_TOP, 1.8)) as Node3D
	var gate: Node3D = builder.call(&"_instance", station, AND_SCENE, "And", Vector3(-4.0, LEDGE_TOP, 0.0)) as Node3D
	gate.visible = false
	var sources: Array[Trigger] = [core_a as Trigger, core_b as Trigger]
	gate.set(&"sources", sources)
	var east: Basis = builder.call(&"_yaw", 90.0) as Basis
	var bridge: Node3D = builder.call(&"_instance", station, DRAWBRIDGE_SCENE, "Bridge", Vector3(0.0, LEDGE_TOP, 0.0), east) as Node3D
	_shell.wire_receiver(bridge, builder, gate)
	_shell.capsule_beside(station, builder, at + Vector3(-10.0, 0.0, 0.0))


## OR station (plan 05.1-18, GAME-DESIGN 6.9), Station_LogicOr under Role_Mechanisms: a charge gate OR an energy core switches a speed pad. The gate only reads
## while the player stands in it, so an invisible 5 s timer keeps its signal; the core keeps its level by itself. The pad points north (-z), the gate and the core
## stand 7 m south of it.
func _build_logic_or(role: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = Vector3(213.0, 0.0, 16.0)
	var station: Node3D = _shell.station(role, builder, "LogicOr", at, "Tor oder Kern", "Erwartet: Eins von beiden reicht für das Speed-Pad: das Tor mit 6 Stufen für 5 s, der Kern mit 3 eingezahlten Stufen dauerhaft", Vector3(0.0, 4.6, 7.0))
	var gate: Node3D = builder.call(&"_instance", station, GATE_SCENE, "Gate", Vector3(0.0, 0.0, 7.0)) as Node3D
	var timer: Node3D = builder.call(&"_instance", station, TIMER_SCENE, "Timer", Vector3(0.0, 0.0, 7.0)) as Node3D
	timer.visible = false
	timer.set(&"source", gate)
	timer.set(&"hold_time", OR_PAD_HOLD)
	var core: Node3D = builder.call(&"_instance", station, CORE_SCENE, "Core", Vector3(4.6, 0.0, 7.0)) as Node3D
	var either: Node3D = builder.call(&"_instance", station, OR_SCENE, "Or", Vector3(0.0, 0.0, 7.0)) as Node3D
	either.visible = false
	var sources: Array[Trigger] = [timer as Trigger, core as Trigger]
	either.set(&"sources", sources)
	var pad: Node3D = builder.call(&"_instance", station, SWITCHED_PAD_SCENE, "Pad", Vector3.ZERO) as Node3D
	_shell.wire_receiver(pad, builder, either)
	_shell.capsule_beside(station, builder, at + Vector3(-5.5, 0.0, 7.0))


## Attraction field (plan 05.1-18, D-23 amended), Station_AttractionField under Role_Environment: a sphere of radius 5 around a core on a foot. Walking out
## against the pull is free; a fast escape costs steps. A capsule stands just outside the sphere, so the clock can be filled before the test.
func _build_attraction_field(role: Node3D, builder: RefCounted) -> void:
	var at: Vector3 = Vector3(213.0, 0.0, -10.0)
	var station: Node3D = _shell.station(role, builder, "AttractionField", at, "Anziehungsfeld", "Erwartet: Hinauslaufen geht immer und kostet nichts; schnell entkommen (Dash, Loader) kostet 1 Stufe pro halbe Sekunde", Vector3(0.0, 6.4, 0.0))
	builder.call(&"_instance", station, FIELD_SCENE_ATTRACTION, "Field", Vector3.ZERO)
	_shell.capsule_beside(station, builder, at + Vector3(8.0, 0.0, 0.0))


## An invisible LogicThreshold of `core` at `level`, as a child of `station`.
func _threshold(station: Node3D, builder: RefCounted, node_name: String, core: Node3D, level: int) -> Node3D:
	var node: Node3D = (load(THRESHOLD_SCRIPT) as GDScript).new() as Node3D
	node.visible = false
	node.set(&"source", core)
	node.set(&"min_level", level)
	builder.call(&"_adopt", station, node, node_name, Vector3.ZERO)
	return node


## Slot (column, row) on `side` of this area.
func _slot(side: String, column: int, row: int) -> Vector3:
	return _shell.slot(KitAreaShell.ENERGY_X.x, side, column, row)
