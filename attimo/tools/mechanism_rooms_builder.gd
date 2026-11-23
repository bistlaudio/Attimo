extends RefCounted
## Worker of tools/movement_gym_builder.gd: the mechanism rooms (phase 4). The gym is generated, so the rooms live
## here. Pinned worker contract, used by every room worker of this phase: build_into(zone, builder), where `builder` is
## the movement_gym_builder instance. Its helpers are invoked with builder.call(&"_adopt", ...) and so on (a RefCounted
## typed handle has no such methods). Coordinates are on the 1 m grid with 2 m / 4 m modules.
##
## Plan view (x east, z south): the hall east wall sits at x 42.5. The door (Zahnrad-Tor) is its z 0 cell, the tracer lever
## stands on the hall side at (38, -3). Room 2 is the showcase hall east of the door, x 43..163, z -36..36 (120 m x 72 m, 04.1-05,
## D-04). A 12 m slot grid (SLOT_PITCH) holds nine zones (ZONES) and 33 stations; a street at z -12..12 runs from the west door to
## the east exit (z 0..4). The puzzle rooms of tools/puzzle_rooms_builder.gd follow behind its east wall, shifted by PUZZLE_SHIFT_X.

const GATE_SCENE: String = "res://scenes/mechanisms/gear_gate.tscn"
const LEVER_SCENE: String = "res://scenes/mechanisms/lever.tscn"
const BEAM_SCENE: String = "res://scenes/proto/primitive_beam.tscn"
const PILLAR_SCENE: String = "res://scenes/proto/primitive_pillar.tscn"
const VALVE_SCENE: String = "res://scenes/mechanisms/valve.tscn"
const CORE_SCENE: String = "res://scenes/mechanisms/energy_core.tscn"
const CRANK_SCENE: String = "res://scenes/mechanisms/crank.tscn"
const AND_SCENE: String = "res://scenes/mechanisms/logic_and.tscn"
const OR_SCENE: String = "res://scenes/mechanisms/logic_or.tscn"
const TIMER_SCENE: String = "res://scenes/mechanisms/logic_timer.tscn"
const ROTATING_SCENE: String = "res://scenes/mechanisms/rotating_platform.tscn"
const LIFT_SCENE: String = "res://scenes/mechanisms/lift_platform.tscn"
const CONVEYOR_SCENE: String = "res://scenes/mechanisms/conveyor.tscn"
const NOZZLE_SCENE: String = "res://scenes/mechanisms/steam_nozzle.tscn"
const PENDULUM_SCENE: String = "res://scenes/mechanisms/pendulum.tscn"
const LOW_GRAVITY_SCENE: String = "res://scenes/mechanisms/low_gravity_zone.tscn"
const PLATE_SCENE: String = "res://scenes/mechanisms/pressure_plate.tscn"
const GEYSER_SCENE: String = "res://scenes/mechanisms/geyser.tscn"
const PISTON_SCENE: String = "res://scenes/mechanisms/piston_wall.tscn"
const WALL_PAD_SCENE: String = "res://scenes/mechanisms/wall_pad.tscn"
const FIELD_SCENE: String = "res://scenes/mechanisms/force_field.tscn"
const SLINGSHOT_SCENE: String = "res://scenes/mechanisms/slingshot_core.tscn"
const TUBE_SCENE: String = "res://scenes/mechanisms/pneumatic_tube.tscn"
const WIND_SCENE: String = "res://scenes/mechanisms/wind_tunnel.tscn"
const CRUMBLING_SCENE: String = "res://scenes/mechanisms/crumbling_platform.tscn"
const PATERNOSTER_SCENE: String = "res://scenes/mechanisms/paternoster.tscn"
const BOOST_SCENE: String = "res://scenes/mechanisms/boost_ring.tscn"
const BOUNCE_SCENE: String = "res://scenes/mechanisms/bounce_pad.tscn"
## Height of the raised moving stations (Dreh-Plattform, Hub-Plattform, Pendel walkway): their bodies are 0.5 m thick, so the
## deck stays clear of the floor tiles and the rider really stands on the moving body. No moving body's top face may be coplanar
## with a floor tile (the engine would pick the tile as the supporting body); belts carry a 0.05 m lip above their node origin.
const RAISED: float = 1.0
const WALL_X: float = 42.5
const ROOM_X_MIN: float = 43.0
## Room 2 was x 43..75 (04-03) and grew to x 115 in 04-04 for the moving stations; the puzzle rooms start behind it.
const ROOM_X_MAX: float = 163.0
const ROOM_Z_HALF: float = 36.0
const TILE: float = 4.0
## Index of the east wall cell (z 0..4) that stays open for the puzzle room doorway: the row whose centre is z 2.
const EAST_DOOR_ROW: int = int(ROOM_Z_HALF / TILE)
## Slot grid (D-04): slot(i, j) = (49 + 12 i, 0, -30 + 12 j), i 0..9, j 0..5.
const SLOT_PITCH: float = 12.0
const SLOT_X0: float = 49.0
const SLOT_Z0: float = -30.0
## The nine zones: slot block i0..i1 x j0..j1, header title and floor tint. Open floor (no zone) is i6..7 j2..3 and i8..9.
const ZONES: Array[Dictionary] = [
	{"tag": "Wand", "title": "Wand", "i0": 0, "j0": 0, "i1": 1, "j1": 1, "tint": Color(0.60, 0.48, 0.22)},
	{"tag": "Felder", "title": "Felder & Schleuder", "i0": 2, "j0": 0, "i1": 3, "j1": 1, "tint": Color(0.20, 0.38, 0.40)},
	{"tag": "Gefahren", "title": "Gefahren", "i0": 4, "j0": 0, "i1": 5, "j1": 0, "tint": Color(0.55, 0.25, 0.20)},
	{"tag": "Dampf", "title": "Dampf", "i0": 4, "j0": 1, "i1": 5, "j1": 3, "tint": Color(0.55, 0.55, 0.55)},
	{"tag": "Umwelt", "title": "Umwelt", "i0": 6, "j0": 0, "i1": 7, "j1": 1, "tint": Color(0.35, 0.48, 0.58)},
	{"tag": "Trigger", "title": "Trigger", "i0": 0, "j0": 2, "i1": 1, "j1": 3, "tint": Color(0.55, 0.45, 0.30)},
	{"tag": "Logik", "title": "Logik", "i0": 2, "j0": 2, "i1": 3, "j1": 3, "tint": Color(0.30, 0.36, 0.48)},
	{"tag": "Plattformen", "title": "Plattformen", "i0": 0, "j0": 4, "i1": 3, "j1": 5, "tint": Color(0.32, 0.45, 0.30)},
	{"tag": "Tempo", "title": "Sprung & Tempo", "i0": 4, "j0": 4, "i1": 7, "j1": 5, "tint": Color(0.42, 0.30, 0.45)},
]
const ZONE_FLOOR_SCENE: String = "res://scenes/mechanisms/zone_floor.tscn"
## The zone floor scene is a 24 x 24 m overlay; the instance root is scaled to the zone rect.
const ZONE_FLOOR_SIZE: float = 24.0
const HEADER_FONT_SIZE: int = 128
const HEADER_HEIGHT: float = 7.5
## Room-2 respawn near the west door and the reset volume east of the hall reset (x 80).
const RESPAWN_ROOM2: Vector3 = Vector3(47.0, 0.0, 0.0)


func slot(i: int, j: int) -> Vector3:
	return Vector3(SLOT_X0 + SLOT_PITCH * i, 0.0, SLOT_Z0 + SLOT_PITCH * j)


## World rect (x, z, width, depth) of a zone row of ZONES.
func zone_rect(row: Dictionary) -> Rect2:
	var x0: float = ROOM_X_MIN + SLOT_PITCH * int(row["i0"])
	var z0: float = -ROOM_Z_HALF + SLOT_PITCH * int(row["j0"])
	var width: float = SLOT_PITCH * (int(row["i1"]) - int(row["i0"]) + 1)
	var depth: float = SLOT_PITCH * (int(row["j1"]) - int(row["j0"]) + 1)
	return Rect2(x0, z0, width, depth)


func build_into(zone: Node3D, builder: RefCounted) -> void:
	_build_room_shell(zone, builder)
	_build_zones(zone, builder)
	_build_room_reset(zone, builder)
	_build_door(zone, builder)
	build_showcase_stations(zone, builder)
	_build_puzzle_rooms(zone, builder)


## The three puzzle rooms (04-05) start behind room 2's east wall, in their own worker.
func _build_puzzle_rooms(zone: Node3D, builder: RefCounted) -> void:
	var script: GDScript = load("res://tools/puzzle_rooms_builder.gd") as GDScript
	if script == null or not script.can_instantiate():
		builder.set(&"failure", "cannot load res://tools/puzzle_rooms_builder.gd")
		return
	var worker: RefCounted = script.new() as RefCounted
	worker.call(&"build_into", zone, builder)


## Showcase stations (D-03, D-04): 33 stations on the slot grid, one row of STATIONS each, grouped by zone. Every station node is a
## DIRECT child of the zone under its tag name (the gym tests iterate the direct children); its geometry props (pillars, steps,
## walkways) go into ZoneDecor. Every sign has two lines: Label_<tag> and Label_<tag>_Expect ("Erwartet: ...").
## kinds: valve, core, crank, plate (self-triggered, with a gate), and / or / timer (logic, with a gate), mover (own lever at `lever`
## from the station point), driven (always-on Driver<tag> SignalSource, sign at the lever position).
## Row keys: tag, zone, slots (one slot, or two for a half block: the midpoint), kind, scene, text, expect, and optional y (node
## height), yaw / pitch (degrees), offset (node offset from the station point), lever (lever offset), sign_h, gate (gate offset),
## props (properties set on the mechanism).
const STATIONS: Array[Dictionary] = [
	# Trigger
	{"tag": "Valve", "zone": "Trigger", "slots": [Vector2i(0, 2)], "kind": "valve", "scene": VALVE_SCENE, "text": "Handrad-Ventil (großer Puls)", "expect": "Erwartet: Großer Puls dreht das Rad, das Tor öffnet"},
	{"tag": "EnergyCore", "zone": "Trigger", "slots": [Vector2i(1, 2)], "kind": "core", "scene": CORE_SCENE, "text": "Energiekern (Zeit)", "expect": "Erwartet: Puls lädt den Kern, das Tor ist kurz offen", "sign_h": 6.6},
	{"tag": "Crank", "zone": "Trigger", "slots": [Vector2i(0, 3)], "kind": "crank", "scene": CRANK_SCENE, "text": "Uhrwerk-Kurbel (E halten)", "expect": "Erwartet: E halten öffnet das Tor, loslassen schließt es"},
	{"tag": "PressurePlate", "zone": "Trigger", "slots": [Vector2i(1, 3)], "kind": "plate", "scene": PLATE_SCENE, "text": "Druckplatte", "expect": "Erwartet: Tor offen, solange du draufstehst"},
	# Logik
	{"tag": "LogicAnd", "zone": "Logik", "slots": [Vector2i(2, 2)], "kind": "and", "scene": AND_SCENE, "text": "UND: beide Hebel", "expect": "Erwartet: Tor nur offen, wenn beide Hebel an sind", "gate": Vector3(0.0, 0.0, 4.0)},
	{"tag": "LogicOr", "zone": "Logik", "slots": [Vector2i(3, 2)], "kind": "or", "scene": OR_SCENE, "text": "ODER: ein Hebel", "expect": "Erwartet: Ein Hebel reicht, das Tor öffnet", "gate": Vector3(0.0, 0.0, 4.0)},
	{"tag": "LogicTimer", "zone": "Logik", "slots": [Vector2i(2, 3)], "kind": "timer", "scene": TIMER_SCENE, "text": "Timer (4 s)", "expect": "Erwartet: Tor bleibt 4 s offen, dann geht es zu"},
	# Dampf
	{"tag": "NozzleCannon", "zone": "Dampf", "slots": [Vector2i(4, 1)], "kind": "mover", "scene": NOZZLE_SCENE, "text": "Dampfdüse: Kanone", "expect": "Erwartet: Wirft dich schräg in Düsenrichtung", "yaw": -90.0, "pitch": 45.0, "lever": Vector3(0.0, 0.0, 2.5), "props": {"mode": SteamNozzle.Mode.CANNON}},
	{"tag": "NozzleJump", "zone": "Dampf", "slots": [Vector2i(4, 2)], "kind": "mover", "scene": NOZZLE_SCENE, "text": "Dampfdüse: Sprung", "expect": "Erwartet: Reinlaufen schleudert dich senkrecht hoch", "lever": Vector3(-2.5, 0.0, 0.0), "props": {"mode": SteamNozzle.Mode.JUMP}},
	{"tag": "NozzleUpdraft", "zone": "Dampf", "slots": [Vector2i(5, 2)], "kind": "mover", "scene": NOZZLE_SCENE, "text": "Dampfdüse: Aufwind", "expect": "Erwartet: Im Strahl schwebst du langsam nach oben", "lever": Vector3(-2.5, 0.0, 0.0), "props": {"mode": SteamNozzle.Mode.UPDRAFT}},
	{"tag": "Geyser", "zone": "Dampf", "slots": [Vector2i(4, 3)], "kind": "driven", "scene": GEYSER_SCENE, "text": "Druckventil-Geysir", "expect": "Erwartet: Anzeige füllt sich, dann schießt Dampf dich hoch"},
	{"tag": "NozzleWall", "zone": "Dampf", "slots": [Vector2i(5, 3)], "kind": "mover", "scene": NOZZLE_SCENE, "text": "Dampfdüse: Wand", "expect": "Erwartet: Der Strahl drückt dich zurück", "yaw": 90.0, "lever": Vector3(0.0, 0.0, -2.5), "props": {"mode": SteamNozzle.Mode.WALL}},
	# Gefahren
	{"tag": "Pendulum", "zone": "Gefahren", "slots": [Vector2i(4, 0)], "kind": "mover", "scene": PENDULUM_SCENE, "text": "Pendel: Knockback", "expect": "Erwartet: Treffer stößt dich weg, kein Schaden", "y": RAISED, "lever": Vector3(2.5, 0.0, 4.0), "sign_h": 7.5},
	{"tag": "PistonWall", "zone": "Gefahren", "slots": [Vector2i(5, 0)], "kind": "driven", "scene": PISTON_SCENE, "text": "Kolbenwand", "expect": "Erwartet: Kolben schlägt aus und stößt dich weg", "yaw": 180.0},
	# Wand
	{"tag": "WallRun", "zone": "Wand", "slots": [Vector2i(0, 0), Vector2i(1, 0)], "kind": "driven", "scene": WALL_PAD_SCENE, "text": "Wandlauf-Platte", "expect": "Erwartet: Schnell anlaufen und an der Platte entlang laufen", "offset": Vector3(3.0, 0.0, -3.0), "props": {"mode": WallPad.Mode.WALL_RUN}},
	{"tag": "WallJump", "zone": "Wand", "slots": [Vector2i(0, 1), Vector2i(1, 1)], "kind": "driven", "scene": WALL_PAD_SCENE, "text": "Wandsprung-Platte", "expect": "Erwartet: In der Luft an die Platte, Sprung stößt dich ab", "offset": Vector3(0.0, 0.0, -2.0), "props": {"mode": WallPad.Mode.WALL_JUMP}},
	# Felder
	{"tag": "Repulsor", "zone": "Felder", "slots": [Vector2i(2, 0)], "kind": "mover", "scene": FIELD_SCENE, "text": "Abstoßfeld", "expect": "Erwartet: Das Feld drückt dich vom Kern weg", "y": 3.0, "lever": Vector3(-4.0, 0.0, 4.0), "props": {"mode": ForceField.Mode.REPEL}},
	{"tag": "Attractor", "zone": "Felder", "slots": [Vector2i(3, 0)], "kind": "mover", "scene": FIELD_SCENE, "text": "Anziehungsfeld", "expect": "Erwartet: Das Feld zieht dich zum Kern", "y": 4.0, "lever": Vector3(-4.0, 0.0, 4.0), "props": {"mode": ForceField.Mode.ATTRACT}},
	{"tag": "Slingshot", "zone": "Felder", "slots": [Vector2i(2, 1)], "kind": "driven", "scene": SLINGSHOT_SCENE, "text": "Schleuderkern", "expect": "Erwartet: Rein von links oben, raus nach rechts unten", "y": 3.0},
	{"tag": "Tube", "zone": "Felder", "slots": [Vector2i(3, 1)], "kind": "driven", "scene": TUBE_SCENE, "text": "Rohrpost", "expect": "Erwartet: Rein ins Rohr, am Ende schießt es dich raus", "yaw": -90.0, "offset": Vector3(-8.0, 0.0, 0.0), "props": {"exit_speed": 6.0}},
	# Umwelt
	{"tag": "WindTunnel", "zone": "Umwelt", "slots": [Vector2i(6, 0), Vector2i(7, 0)], "kind": "mover", "scene": WIND_SCENE, "text": "Windkanal", "expect": "Erwartet: Rückenwind trägt dich weiter, der Hebel dreht den Wind", "yaw": -90.0, "lever": Vector3(-4.0, 0.0, 4.0)},
	{"tag": "LowGravity", "zone": "Umwelt", "slots": [Vector2i(6, 1)], "kind": "mover", "scene": LOW_GRAVITY_SCENE, "text": "Schwerkraft-Zone", "expect": "Erwartet: Sprünge hoch, weit und langsam", "lever": Vector3(0.0, 0.0, 6.5), "sign_h": 3.2},
	# Plattformen
	{"tag": "RotatingLying", "zone": "Plattformen", "slots": [Vector2i(0, 4)], "kind": "mover", "scene": ROTATING_SCENE, "text": "Dreh-Plattform: liegend (Zahnrad)", "expect": "Erwartet: Dreht sich und trägt dich, ohne zu rutschen", "y": RAISED, "lever": Vector3(0.0, 0.0, 5.5), "sign_h": 4.5, "props": {"axis_mode": RotatingPlatform.AxisMode.LYING}},
	{"tag": "RotatingStanding", "zone": "Plattformen", "slots": [Vector2i(1, 4)], "kind": "mover", "scene": ROTATING_SCENE, "text": "Dreh-Plattform: stehend (Uhrzeiger)", "expect": "Erwartet: Schwingt hin und her, du bleibst drauf", "y": RAISED, "lever": Vector3(2.5, 0.0, 4.0), "sign_h": 4.5, "props": {"axis_mode": RotatingPlatform.AxisMode.STANDING}},
	{"tag": "RotatingTilting", "zone": "Plattformen", "slots": [Vector2i(2, 4)], "kind": "mover", "scene": ROTATING_SCENE, "text": "Dreh-Plattform: kippend", "expect": "Erwartet: Kippt, und du rutschst nicht ab", "y": RAISED, "lever": Vector3(0.0, 0.0, 5.5), "sign_h": 4.5, "props": {"axis_mode": RotatingPlatform.AxisMode.TILTING}},
	{"tag": "Crumbling", "zone": "Plattformen", "slots": [Vector2i(3, 4)], "kind": "driven", "scene": CRUMBLING_SCENE, "text": "Bröckel-Plattform", "expect": "Erwartet: Wackelt, fällt runter, kommt nach 3 s zurück", "y": 2.0, "sign_h": 4.2},
	{"tag": "LiftPiston", "zone": "Plattformen", "slots": [Vector2i(0, 5)], "kind": "mover", "scene": LIFT_SCENE, "text": "Hub-Plattform: Kolben", "expect": "Erwartet: Hebel an fährt hoch, Hebel aus fährt runter", "y": RAISED, "lever": Vector3(0.0, 0.0, 4.5), "sign_h": 7.0, "props": {"look": LiftPlatform.Look.PISTON}},
	{"tag": "LiftChain", "zone": "Plattformen", "slots": [Vector2i(1, 5)], "kind": "mover", "scene": LIFT_SCENE, "text": "Hub-Plattform: Kette", "expect": "Erwartet: Hebel an fährt hoch, Hebel aus fährt runter", "y": RAISED, "lever": Vector3(0.0, 0.0, 4.5), "sign_h": 7.0, "props": {"look": LiftPlatform.Look.CHAIN}},
	{"tag": "Paternoster", "zone": "Plattformen", "slots": [Vector2i(2, 5)], "kind": "mover", "scene": PATERNOSTER_SCENE, "text": "Paternoster", "expect": "Erwartet: Kabinen fahren im Kreis, auf- und abspringen", "y": RAISED, "lever": Vector3(-6.0, 0.0, 4.0)},
	# Sprung & Tempo
	{"tag": "BoostRing", "zone": "Tempo", "slots": [Vector2i(4, 4), Vector2i(5, 4)], "kind": "driven", "scene": BOOST_SCENE, "text": "Boost-Ring", "expect": "Erwartet: Durchfliegen gibt Tempo und lädt den Dash", "y": 2.5},
	{"tag": "Bounce", "zone": "Tempo", "slots": [Vector2i(6, 4)], "kind": "driven", "scene": BOUNCE_SCENE, "text": "Sprungpolster", "expect": "Erwartet: Je tiefer du fällst, desto höher springst du"},
	{"tag": "ConveyorRun", "zone": "Tempo", "slots": [Vector2i(4, 5), Vector2i(5, 5)], "kind": "mover", "scene": CONVEYOR_SCENE, "text": "Förderband: läuft solange an", "expect": "Erwartet: Das Band trägt dich, der Absprung behält den Schwung", "yaw": -90.0, "lever": Vector3(0.0, 0.0, 3.5), "props": {"behaviour": Mechanism.Behaviour.RUN_WHILE_ON}},
	{"tag": "ConveyorReverse", "zone": "Tempo", "slots": [Vector2i(6, 5), Vector2i(7, 5)], "kind": "mover", "scene": CONVEYOR_SCENE, "text": "Förderband: Hebel kehrt um", "expect": "Erwartet: Läuft immer, der Hebel kehrt die Richtung um", "yaw": -90.0, "lever": Vector3(0.0, 0.0, 3.5), "props": {"behaviour": Mechanism.Behaviour.REVERSE_ON_SIGNAL}},
]
## Default offset of a gate from its station point and of a lever (and sign) of a mover or driven station.
const GATE_OFFSET: Vector3 = Vector3(4.0, 0.0, 0.0)
const LEVER_OFFSET: Vector3 = Vector3(-4.0, 0.0, 4.0)


func build_showcase_stations(zone: Node3D, builder: RefCounted) -> void:
	var entries: Array = []
	for row: Dictionary in STATIONS:
		var at: Vector3 = _station_point(row)
		_place_station(zone, builder, row, at)
		_station_extras(zone, builder, String(row["tag"]), at)
		entries.append({"tag": StringName(String(row["tag"])), "at": at, "zone": StringName(String(row["zone"]))})
	zone.set_meta(&"stations", entries)


## The station point: a slot, or the midpoint of two slots (half block).
func _station_point(row: Dictionary) -> Vector3:
	var slots: Array = row["slots"] as Array
	var sum: Vector3 = Vector3.ZERO
	for item: Variant in slots:
		var cell: Vector2i = item as Vector2i
		sum += slot(cell.x, cell.y)
	return sum / float(slots.size())


func _row_basis(row: Dictionary) -> Basis:
	var yaw: float = deg_to_rad(float(row.get("yaw", 0.0)))
	var pitch: float = deg_to_rad(float(row.get("pitch", 0.0)))
	return Basis.from_euler(Vector3(pitch, yaw, 0.0))


func _place_station(zone: Node3D, builder: RefCounted, row: Dictionary, at: Vector3) -> void:
	var tag: String = String(row["tag"])
	var scene: String = String(row["scene"])
	var text: String = String(row["text"])
	var expect: String = String(row["expect"])
	var height: float = float(row.get("y", 0.0))
	var node_at: Vector3 = at + (row.get("offset", Vector3.ZERO) as Vector3) + Vector3(0.0, height, 0.0)
	var basis: Basis = _row_basis(row)
	var props: Dictionary = row.get("props", {}) as Dictionary
	var gate_offset: Vector3 = row.get("gate", GATE_OFFSET) as Vector3
	match String(row["kind"]):
		"valve", "crank", "plate":
			var trigger: Node3D = builder.call(&"_instance", zone, scene, tag, node_at) as Node3D
			_station_gate(zone, builder, at + gate_offset, tag, trigger)
			_sign(zone, builder, tag, text, at, float(row.get("sign_h", 2.8)), expect)
		"core":
			builder.call(&"_instance", _props(zone), PILLAR_SCENE, "CorePillar", at)
			var core: Node3D = builder.call(&"_instance", zone, scene, tag, Vector3(at.x, 4.0, at.z)) as Node3D
			_station_gate(zone, builder, at + gate_offset, tag, core)
			_sign(zone, builder, tag, text, at, float(row.get("sign_h", 2.8)), expect)
		"and", "or":
			_station_logic(zone, builder, row, at)
		"timer":
			var lever: Node3D = builder.call(&"_instance", zone, LEVER_SCENE, "Lever%s" % tag, at) as Node3D
			var timer: Node3D = builder.call(&"_instance", zone, scene, tag, at) as Node3D
			timer.set("source", lever)
			timer.set("hold_time", 4.0)
			_station_gate(zone, builder, at + gate_offset, tag, timer)
			_sign(zone, builder, tag, text, at, 2.8, expect)
		"mover":
			var lever_at: Vector3 = at + (row.get("lever", LEVER_OFFSET) as Vector3)
			_station_mover(zone, builder, tag, scene, node_at, basis, lever_at, props, text, float(row.get("sign_h", 3.2)), expect)
		"driven":
			_station_driven(zone, builder, tag, scene, node_at, basis, props, text, expect, float(row.get("sign_h", 3.2)), at + LEVER_OFFSET)
		_:
			builder.set(&"failure", "unknown station kind %s" % String(row["kind"]))


## ZoneDecor: the group of zone decor and station props (steps, pillars, walkways).
func _props(zone: Node3D) -> Node3D:
	return zone.get_node("ZoneDecor") as Node3D


## A gate at `gate_at`, wired to `source`, named Gate_<tag>. Returns the gate.
func _station_gate(zone: Node3D, builder: RefCounted, gate_at: Vector3, tag: String, source: Node3D) -> Node3D:
	var gate: Node3D = builder.call(&"_instance", zone, GATE_SCENE, "Gate_%s" % tag, Vector3(gate_at.x, 0.0, gate_at.z)) as Node3D
	gate.set("source", source)
	return gate


## A station sign Label_<tag>. With `expect` (D-03) a second, smaller line Label_<tag>_Expect hangs 0.7 m below it; its text starts
## with "Erwartet:" and says what should happen when the player tries the station.
func _sign(zone: Node3D, builder: RefCounted, tag: String, text: String, at: Vector3, height: float = 2.8, expect: String = "") -> void:
	builder.call(&"_label", zone, "Label_%s" % tag, text, Vector3(at.x, height, at.z))
	if expect != "":
		builder.call(&"_label", zone, "Label_%s_Expect" % tag, expect, Vector3(at.x, height - 0.7, at.z), 40)


## Two levers feeding a LogicAnd or LogicOr node (row kind and / or) that drives the gate.
func _station_logic(zone: Node3D, builder: RefCounted, row: Dictionary, at: Vector3) -> void:
	var tag: String = String(row["tag"])
	var lever_a: Node3D = builder.call(&"_instance", zone, LEVER_SCENE, "Lever%sA" % tag, Vector3(at.x - 2.0, 0.0, at.z)) as Node3D
	var lever_b: Node3D = builder.call(&"_instance", zone, LEVER_SCENE, "Lever%sB" % tag, Vector3(at.x + 2.0, 0.0, at.z)) as Node3D
	var logic: Node3D = builder.call(&"_instance", zone, String(row["scene"]), tag, Vector3(at.x, 0.0, at.z)) as Node3D
	var wired: Array[SignalSource] = [lever_a as SignalSource, lever_b as SignalSource]
	logic.set("sources", wired)
	_station_gate(zone, builder, at + (row.get("gate", GATE_OFFSET) as Vector3), tag, logic)
	_sign(zone, builder, tag, String(row["text"]), at, 2.8, String(row["expect"]))


## One moving mechanism wired to a fresh lever, with its sign. `props` are set on the mechanism before it is saved.
func _station_mover(zone: Node3D, builder: RefCounted, tag: String, scene: String, at: Vector3, basis: Basis, lever_at: Vector3, props: Dictionary, text: String, sign_height: float = 3.2, expect: String = "") -> void:
	var lever: Node3D = builder.call(&"_instance", zone, LEVER_SCENE, "Lever%s" % tag, Vector3(lever_at.x, 0.0, lever_at.z)) as Node3D
	var mechanism: Node3D = builder.call(&"_instance", zone, scene, tag, at, basis) as Node3D
	mechanism.set("source", lever)
	for key: Variant in props:
		mechanism.set(String(key), props[key])
	_sign(zone, builder, tag, text, Vector3(lever_at.x, 0.0, lever_at.z), sign_height, expect)


## A self-running mechanism: an always-on Driver<tag> SignalSource is added BEFORE the mechanism (puzzle-room pattern), so it is
## ready first and the mechanism finds an active source.
func _station_driven(zone: Node3D, builder: RefCounted, tag: String, scene: String, at: Vector3, basis: Basis, props: Dictionary, text: String, expect: String, sign_height: float, sign_at: Vector3) -> void:
	var driver: SignalSource = SignalSource.new()
	driver.start_active = true
	builder.call(&"_adopt", zone, driver, "Driver%s" % tag, Vector3(at.x, 0.0, at.z))
	var mechanism: Node3D = builder.call(&"_instance", zone, scene, tag, at, basis) as Node3D
	mechanism.set("source", driver)
	for key: Variant in props:
		mechanism.set(String(key), props[key])
	_sign(zone, builder, tag, text, Vector3(sign_at.x, 0.0, sign_at.z), sign_height, expect)


## Station-specific geometry and second parts, all inside the station's zone.
func _station_extras(zone: Node3D, builder: RefCounted, tag: String, at: Vector3) -> void:
	var props: Node3D = _props(zone)
	var yaw_z: Basis = builder.call(&"_yaw", 90.0) as Basis
	match tag:
		"EnergyCore":
			pass
		"Pendulum":
			# The Pendel hangs over a narrow 2 m walkway (two beams, 1 m high); the bob swings across it just above the deck.
			builder.call(&"_instance", props, BEAM_SCENE, "PendulumWalkA", at + Vector3(0.0, 0.0, -2.0), yaw_z)
			builder.call(&"_instance", props, BEAM_SCENE, "PendulumWalkB", at + Vector3(0.0, 0.0, 2.0), yaw_z)
		"WallJump":
			# Two WALL_JUMP pads face each other 4 m apart along z, so the player can kick from one to the other.
			var second: Node3D = builder.call(&"_instance", zone, WALL_PAD_SCENE, "WallJump2", at + Vector3(0.0, 0.0, 2.0)) as Node3D
			second.set("mode", WallPad.Mode.WALL_JUMP)
			second.set("source", zone.get_node("DriverWallJump"))
		"Crumbling":
			# The deck is 2 m up: a 1 m beam step flush with its south edge makes it reachable with a normal jump.
			builder.call(&"_instance", props, BEAM_SCENE, "CrumblingStep", at + Vector3(0.0, 0.0, 2.5))
		"Bounce":
			# A 4 m ledge west-to-east of stacked floor tiles (unit steps 1, 2, 3, 4 m) to drop onto the pad from.
			var column: int = 0
			for step: int in [4, 3, 2, 1]:
				var x: float = at.x + 4.0 + 4.0 * column
				for top: int in range(1, step + 1):
					builder.call(&"_floor_tile", props, "BounceStep_%d_%d" % [column, top], x, float(top), at.z)
				column += 1


func _build_room_shell(zone: Node3D, builder: RefCounted) -> void:
	var columns: int = roundi((ROOM_X_MAX - ROOM_X_MIN) / TILE)
	var rows: int = roundi(ROOM_Z_HALF * 2.0 / TILE)
	for column: int in columns:
		var x: float = ROOM_X_MIN + TILE * 0.5 + TILE * column
		for row: int in rows:
			var z: float = -ROOM_Z_HALF + TILE * 0.5 + TILE * row
			builder.call(&"_floor_tile", zone, "Room2Floor_%d_%d" % [column, row], x, 0.0, z)
		builder.call(&"_wall", zone, "Room2WallNorth_%d" % column, x, -ROOM_Z_HALF - 0.5, 0.0, 0.0)
		builder.call(&"_wall", zone, "Room2WallSouth_%d" % column, x, ROOM_Z_HALF + 0.5, 0.0, 0.0)
	for row: int in rows:
		# The z 0..4 cell (row 4) is the doorway into the puzzle rooms (EntryGate of puzzle_rooms_builder).
		if row == EAST_DOOR_ROW:
			continue
		var z: float = -ROOM_Z_HALF + TILE * 0.5 + TILE * row
		builder.call(&"_wall", zone, "Room2WallEast_%d" % row, ROOM_X_MAX + 0.5, z, 90.0, 0.0)
	# The hall floor ends at x 42 and room 2 starts at x 43: a 1 m threshold closes the wall cell between them.
	builder.call(&"_instance", zone, BEAM_SCENE, "Room2Threshold", Vector3(WALL_X, -1.0, 0.0), builder.call(&"_yaw", 90.0))
	# The hall east wall ends at z 34 and room 2 reaches z 36: the plug closes the 2 m gap on the west side.
	builder.call(&"_wall", zone, "Room2WallWestPlug", WALL_X, ROOM_Z_HALF, 90.0)


func _build_door(zone: Node3D, builder: RefCounted) -> void:
	# _yaw(90) = Basis(UP, +90 deg) maps local -X to world +Z: the open gate slides along +z inside the wall plane,
	# into the WallEast_1 segment (z 2..6) beside the doorway, never into room 2 or the hall.
	var gate: Node3D = builder.call(&"_instance", zone, GATE_SCENE, "ZahnradTor", Vector3(WALL_X, 0.0, 0.0), builder.call(&"_yaw", 90.0)) as Node3D
	var lever: Node3D = builder.call(&"_instance", zone, LEVER_SCENE, "TracerLever", Vector3(38.0, 0.0, -3.0)) as Node3D
	gate.set("source", lever)
	builder.call(&"_label", zone, "Label_Tracer", "Fernauslöser: RMB halten, LMB tippen", Vector3(38.0, 2.4, -3.0))
	builder.call(&"_label", zone, "Label_Room2", "Raum 2", Vector3(WALL_X, 5.0, 0.0))


## Zone decor (D-04, D-12), all under the group ZoneDecor so that the stations stay the only mechanism children of the zone: a tint
## overlay ZoneFloor_<tag>, low divider beams with walk-through gaps on every border between two zones (or a zone and open floor)
## and a large header sign ZoneHeader_<tag>. Stores the metadata `zones` the layout test reads.
func _build_zones(zone: Node3D, builder: RefCounted) -> void:
	var decor: Node3D = builder.call(&"_group", zone, "ZoneDecor") as Node3D
	var entries: Array = []
	# Cell grid of the zone index per 12 m slot (-1 open floor), used for the borders.
	var columns: int = roundi((ROOM_X_MAX - ROOM_X_MIN) / SLOT_PITCH)
	var rows: int = roundi(ROOM_Z_HALF * 2.0 / SLOT_PITCH)
	var cells: Dictionary = {}
	for index: int in ZONES.size():
		var row: Dictionary = ZONES[index]
		var rect: Rect2 = zone_rect(row)
		var tag: String = String(row["tag"])
		var centre: Vector2 = rect.get_center()
		var floor_node: MeshInstance3D = builder.call(&"_instance", decor, ZONE_FLOOR_SCENE, "ZoneFloor_%s" % tag, Vector3(centre.x, 0.01, centre.y), Basis.IDENTITY.scaled(Vector3(rect.size.x / ZONE_FLOOR_SIZE, 1.0, rect.size.y / ZONE_FLOOR_SIZE))) as MeshInstance3D
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = row["tint"] as Color
		material.roughness = 0.9
		floor_node.material_override = material
		var header_name: String = "ZoneHeader_%s" % tag
		builder.call(&"_label", decor, header_name, String(row["title"]), Vector3(centre.x, HEADER_HEIGHT, centre.y), HEADER_FONT_SIZE)
		entries.append({"tag": tag, "title": String(row["title"]), "rect": rect, "header": NodePath("ZoneDecor/%s" % header_name)})
		for i: int in range(int(row["i0"]), int(row["i1"]) + 1):
			for j: int in range(int(row["j0"]), int(row["j1"]) + 1):
				cells[Vector2i(i, j)] = index
	var divider: int = 0
	for i: int in columns:
		for j: int in rows:
			var here: int = int(cells.get(Vector2i(i, j), -1))
			# East border of this cell (borders along z, yaw 90) and south border (along x).
			if i + 1 < columns and int(cells.get(Vector2i(i + 1, j), -1)) != here:
				var x: float = ROOM_X_MIN + SLOT_PITCH * (i + 1)
				var z: float = -ROOM_Z_HALF + SLOT_PITCH * (j + 0.5)
				builder.call(&"_instance", decor, BEAM_SCENE, "Divider_%d" % divider, Vector3(x, 0.0, z), builder.call(&"_yaw", 90.0))
				divider += 1
			if j + 1 < rows and int(cells.get(Vector2i(i, j + 1), -1)) != here:
				var x2: float = ROOM_X_MIN + SLOT_PITCH * (i + 0.5)
				var z2: float = -ROOM_Z_HALF + SLOT_PITCH * (j + 1)
				builder.call(&"_instance", decor, BEAM_SCENE, "Divider_%d" % divider, Vector3(x2, 0.0, z2))
				divider += 1
	zone.set_meta(&"zones", entries)


## Room-2 safety net (T-04.1-13): a FallReset under x 81..193 (east of the hall reset's x 80 edge) that returns the player to
## Respawn_Room2 near the west door. The puzzle rooms carry their own resets above it.
func _build_room_reset(zone: Node3D, builder: RefCounted) -> void:
	var marker: Marker3D = Marker3D.new()
	builder.call(&"_adopt", zone, marker, "Respawn_Room2", RESPAWN_ROOM2)
	var rig: Node3D = (builder.get(&"_root") as Node).get_node("CameraRig") as Node3D
	var area: FallReset = builder.call(&"_fall_reset", "FallResetRoom2", Vector3(137.0, -30.0, 0.0), Vector3(112.0, 4.0, 132.0), marker, rig) as FallReset
	builder.call(&"_adopt", zone, area, "FallResetRoom2", Vector3(137.0, -30.0, 0.0))
	builder.call(&"_owner_children", area)
