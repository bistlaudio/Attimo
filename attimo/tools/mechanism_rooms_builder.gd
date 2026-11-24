extends RefCounted
## Worker of tools/movement_gym_builder.gd: the mechanism rooms (phase 4). The gym is generated, so the rooms live
## here. Pinned worker contract, used by every room worker of this phase: build_into(zone, builder), where `builder` is
## the movement_gym_builder instance. Its helpers are invoked with builder.call(&"_adopt", ...) and so on (a RefCounted
## typed handle has no such methods). Coordinates are on the 1 m grid with 2 m / 4 m modules.
##
## Plan view (x east, z south): the hall east wall sits at x 42.5. The door (Zahnrad-Tor) is its z 0 cell, the tracer lever
## stands on the hall side at (38, -3). Room 2 is the showcase east of the door, x 43..219, z -32..32. A main corridor at z -4..4 runs
## from the west door to the east exit (z 0..4). Seven closed rooms (ZONES, 4 m walls, no ceiling) line it, four north and three
## south, each with one doorway and a door sign; 4 m alleys separate them. They hold the 33 stations, grouped by what the mechanism
## does to the player. The puzzle rooms of tools/puzzle_rooms_builder.gd follow behind the east wall, shifted by PUZZLE_SHIFT_X.

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
## East wall of room 2: the north row of rooms ends at x 215, plus a 4 m alley. The puzzle rooms start behind it.
const ROOM_X_MAX: float = 219.0
## Room 2 spans z -32..32: rooms z 4..28 on each side of the corridor plus a 4 m alley along the outer walls.
const ROOM_Z_HALF: float = 32.0
const TILE: float = 4.0
## Index of the east wall cell (z 0..4) that stays open for the puzzle room doorway: the row whose centre is z 2.
const EAST_DOOR_ROW: int = int(ROOM_Z_HALF / TILE)
## Slot pitch inside a room: every room is a block of 12 m slots, 2 rows deep.
const SLOT_PITCH: float = 12.0
## The main corridor runs from the west door to the east exit at z -4..4. North rooms span z -28..-4, south rooms z 4..28.
const CORRIDOR_HALF: float = 4.0
const ROOM_DEPTH: float = 24.0
## The seven rooms, grouped by what the mechanism does to the player. Each room is a closed box (4 m walls, no ceiling) of
## `cols` x 2 slots from x0, on the north (N) or south (S) side of the corridor, with one doorway into the corridor in slot column
## `door` and a sign over it. Neighbouring rooms are 4 m apart (side alleys). Slot (c, r) of a room: c counts east from x0; r 0 is
## the row at the room's min z (north rooms: the far row, south rooms: the row next to the corridor).
const ZONES: Array[Dictionary] = [
	{"tag": "Ausloeser", "title": "Auslöser & Logik", "side": "N", "x0": 47.0, "cols": 4, "door": 0, "tint": Color(0.55, 0.45, 0.30)},
	{"tag": "Kraft", "title": "Kraftfelder", "side": "N", "x0": 99.0, "cols": 4, "door": 3, "tint": Color(0.20, 0.38, 0.40)},
	{"tag": "Hoch", "title": "Hoch hinaus", "side": "N", "x0": 151.0, "cols": 3, "door": 2, "tint": Color(0.55, 0.55, 0.55)},
	{"tag": "Stossen", "title": "Stoßen", "side": "N", "x0": 191.0, "cols": 2, "door": 0, "tint": Color(0.55, 0.25, 0.20)},
	{"tag": "Wand", "title": "Wand", "side": "S", "x0": 47.0, "cols": 2, "door": 0, "tint": Color(0.60, 0.48, 0.22)},
	{"tag": "Tragen", "title": "Tragen", "side": "S", "x0": 75.0, "cols": 6, "door": 5, "tint": Color(0.32, 0.45, 0.30)},
	{"tag": "Werfen", "title": "Werfen & Tempo", "side": "S", "x0": 151.0, "cols": 4, "door": 2, "tint": Color(0.42, 0.30, 0.45)},
]
## Font size and height of the door sign over each room's doorway (on the corridor side, above the 4 m wall).
const DOOR_SIGN_FONT_SIZE: int = 112
const DOOR_SIGN_HEIGHT: float = 5.2
const ZONE_FLOOR_SCENE: String = "res://scenes/mechanisms/zone_floor.tscn"
## The zone floor scene is a 24 x 24 m overlay; the instance root is scaled to the zone rect.
const ZONE_FLOOR_SIZE: float = 24.0
const HEADER_FONT_SIZE: int = 128
const HEADER_HEIGHT: float = 7.5
## Room-2 respawn near the west door and the reset volume east of the hall reset (x 80).
const RESPAWN_ROOM2: Vector3 = Vector3(47.0, 0.0, 0.0)
const CAPSULE_SCENE: String = "res://scenes/mechanisms/energy_capsule.tscn"
## Auslöser stations whose source is a shot: a capsule stands next to each one (D-18, D-24), so a bonus try never needs a far trip.
const SHOT_STATION_TAGS: Array[String] = ["Valve", "EnergyCore", "LogicAnd", "LogicOr", "LogicTimer"]
const CAPSULE_OFFSET: Vector3 = Vector3(-4.0, 0.0, 2.0)
const CAPSULE_RESPAWN: float = 6.0


## The ZONES row of room `tag`, or an empty Dictionary.
func room(tag: String) -> Dictionary:
	for row: Dictionary in ZONES:
		if String(row["tag"]) == tag:
			return row
	return {}


## Min z of a room: north rooms end at the corridor (z -4), south rooms start there (z 4).
func room_z0(row: Dictionary) -> float:
	return -CORRIDOR_HALF - ROOM_DEPTH if String(row["side"]) == "N" else CORRIDOR_HALF


## Centre of slot (c, r) of room `row`.
func slot(row: Dictionary, c: int, r: int) -> Vector3:
	return Vector3(float(row["x0"]) + SLOT_PITCH * (c + 0.5), 0.0, room_z0(row) + SLOT_PITCH * (r + 0.5))


## World rect (x, z, width, depth) of a room of ZONES.
func zone_rect(row: Dictionary) -> Rect2:
	return Rect2(float(row["x0"]), room_z0(row), SLOT_PITCH * int(row["cols"]), ROOM_DEPTH)


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
	# Auslöser & Logik
	{"tag": "Valve", "zone": "Ausloeser", "slots": [Vector2i(0, 0)], "kind": "valve", "scene": VALVE_SCENE, "text": "Handrad-Ventil (voll geladener Schuss)", "expect": "Erwartet: Ein voll geladener Schuss dreht das Rad, das Tor öffnet"},
	{"tag": "EnergyCore", "zone": "Ausloeser", "slots": [Vector2i(1, 0)], "kind": "core", "scene": CORE_SCENE, "text": "Energiekern (Zeit)", "expect": "Erwartet: Ein Schuss lädt den Kern, das Tor ist kurz offen", "sign_h": 6.6},
	{"tag": "Crank", "zone": "Ausloeser", "slots": [Vector2i(2, 0)], "kind": "crank", "scene": CRANK_SCENE, "text": "Uhrwerk-Kurbel (E halten)", "expect": "Erwartet: E halten öffnet das Tor, loslassen schließt es"},
	{"tag": "PressurePlate", "zone": "Ausloeser", "slots": [Vector2i(0, 1)], "kind": "plate", "scene": PLATE_SCENE, "text": "Druckplatte", "expect": "Erwartet: Tor offen, solange du draufstehst"},
	{"tag": "LogicAnd", "zone": "Ausloeser", "slots": [Vector2i(1, 1)], "kind": "and", "scene": AND_SCENE, "text": "UND: beide Hebel", "expect": "Erwartet: Tor nur offen, wenn beide Hebel an sind", "gate": Vector3(0.0, 0.0, 4.0)},
	{"tag": "LogicOr", "zone": "Ausloeser", "slots": [Vector2i(2, 1)], "kind": "or", "scene": OR_SCENE, "text": "ODER: ein Hebel", "expect": "Erwartet: Ein Hebel reicht, das Tor öffnet", "gate": Vector3(0.0, 0.0, 4.0)},
	{"tag": "LogicTimer", "zone": "Ausloeser", "slots": [Vector2i(3, 1)], "kind": "timer", "scene": TIMER_SCENE, "gate": Vector3(0.0, 0.0, -4.0), "text": "Timer (4 s)", "expect": "Erwartet: Tor bleibt 4 s offen, dann geht es zu"},
	# Kraftfelder (Dauerkraft im Bereich)
	{"tag": "Repulsor", "zone": "Kraft", "slots": [Vector2i(0, 0)], "kind": "mover", "scene": FIELD_SCENE, "text": "Abstoßfeld", "expect": "Erwartet: Das Feld drückt dich vom Kern weg", "y": 3.0, "lever": Vector3(-4.0, 0.0, 4.0), "props": {"mode": ForceField.Mode.REPEL}},
	{"tag": "Attractor", "zone": "Kraft", "slots": [Vector2i(1, 0)], "kind": "mover", "scene": FIELD_SCENE, "text": "Anziehungsfeld", "expect": "Erwartet: Das Feld zieht dich zum Kern", "y": 4.0, "lever": Vector3(-4.0, 0.0, 4.0), "props": {"mode": ForceField.Mode.ATTRACT}},
	{"tag": "WindTunnel", "zone": "Kraft", "slots": [Vector2i(2, 0), Vector2i(3, 0)], "kind": "mover", "scene": WIND_SCENE, "text": "Windkanal", "expect": "Erwartet: Rückenwind trägt dich weiter, der Hebel dreht den Wind", "yaw": -90.0, "lever": Vector3(-4.0, 0.0, 4.0)},
	{"tag": "NozzleUpdraft", "zone": "Kraft", "slots": [Vector2i(0, 1)], "kind": "mover", "scene": NOZZLE_SCENE, "text": "Dampfdüse: Aufwind", "expect": "Erwartet: Im Strahl schwebst du langsam nach oben", "lever": Vector3(-2.5, 0.0, 0.0), "props": {"mode": SteamNozzle.Mode.UPDRAFT}},
	{"tag": "NozzleWall", "zone": "Kraft", "slots": [Vector2i(1, 1)], "kind": "mover", "scene": NOZZLE_SCENE, "text": "Dampfdüse: Wand", "expect": "Erwartet: Der Strahl drückt dich zurück", "yaw": 90.0, "lever": Vector3(0.0, 0.0, -2.5), "props": {"mode": SteamNozzle.Mode.WALL}},
	{"tag": "LowGravity", "zone": "Kraft", "slots": [Vector2i(2, 1)], "kind": "mover", "scene": LOW_GRAVITY_SCENE, "text": "Schwerkraft-Zone", "expect": "Erwartet: Sprünge hoch, weit und langsam", "lever": Vector3(6.5, 0.0, 0.0), "sign_h": 3.2},
	# Hoch hinaus (einmaliger Stoß nach oben)
	{"tag": "Bounce", "zone": "Hoch", "slots": [Vector2i(0, 0)], "kind": "driven", "scene": BOUNCE_SCENE, "text": "Sprungpolster", "expect": "Erwartet: Je tiefer du fällst, desto höher springst du"},
	{"tag": "NozzleJump", "zone": "Hoch", "slots": [Vector2i(0, 1)], "kind": "mover", "scene": NOZZLE_SCENE, "text": "Dampfdüse: Sprung", "expect": "Erwartet: Reinlaufen schleudert dich senkrecht hoch", "lever": Vector3(-2.5, 0.0, 0.0), "props": {"mode": SteamNozzle.Mode.JUMP}},
	{"tag": "Geyser", "zone": "Hoch", "slots": [Vector2i(1, 1)], "kind": "driven", "scene": GEYSER_SCENE, "text": "Druckventil-Geysir", "expect": "Erwartet: Anzeige füllt sich, dann schießt Dampf dich hoch"},
	# Stoßen (Gefahr)
	{"tag": "Pendulum", "zone": "Stossen", "slots": [Vector2i(0, 0)], "kind": "mover", "scene": PENDULUM_SCENE, "text": "Pendel: Knockback", "expect": "Erwartet: Treffer stößt dich weg, kein Schaden", "y": RAISED, "lever": Vector3(2.5, 0.0, 4.0), "sign_h": 7.5},
	{"tag": "PistonWall", "zone": "Stossen", "slots": [Vector2i(1, 0)], "kind": "driven", "scene": PISTON_SCENE, "text": "Kolbenwand", "expect": "Erwartet: Kolben schlägt aus und stößt dich weg", "yaw": 180.0},
	# Wand
	{"tag": "WallRun", "zone": "Wand", "slots": [Vector2i(0, 1), Vector2i(1, 1)], "kind": "driven", "scene": WALL_PAD_SCENE, "text": "Wandlauf-Platte", "expect": "Erwartet: Schnell anlaufen und an der Platte entlang laufen", "offset": Vector3(3.0, 0.0, -3.0), "props": {"mode": WallPad.Mode.WALL_RUN}},
	{"tag": "WallJump", "zone": "Wand", "slots": [Vector2i(0, 0), Vector2i(1, 0)], "kind": "driven", "scene": WALL_PAD_SCENE, "text": "Wandsprung-Platte", "expect": "Erwartet: In der Luft an die Platte, Sprung stößt dich ab", "offset": Vector3(0.0, 0.0, -2.0), "props": {"mode": WallPad.Mode.WALL_JUMP}},
	# Tragen (du stehst drauf)
	{"tag": "RotatingLying", "zone": "Tragen", "slots": [Vector2i(0, 0)], "kind": "mover", "scene": ROTATING_SCENE, "text": "Dreh-Plattform: liegend (Zahnrad)", "expect": "Erwartet: Dreht sich und trägt dich, ohne zu rutschen", "y": RAISED, "lever": Vector3(0.0, 0.0, 5.5), "sign_h": 4.5, "props": {"axis_mode": RotatingPlatform.AxisMode.LYING}},
	{"tag": "RotatingStanding", "zone": "Tragen", "slots": [Vector2i(1, 0)], "kind": "mover", "scene": ROTATING_SCENE, "text": "Dreh-Plattform: stehend (Uhrzeiger)", "expect": "Erwartet: Schwingt hin und her, du bleibst drauf", "y": RAISED, "lever": Vector3(2.5, 0.0, 4.0), "sign_h": 4.5, "props": {"axis_mode": RotatingPlatform.AxisMode.STANDING}},
	{"tag": "RotatingTilting", "zone": "Tragen", "slots": [Vector2i(2, 0)], "kind": "mover", "scene": ROTATING_SCENE, "text": "Dreh-Plattform: kippend", "expect": "Erwartet: Kippt, und du rutschst nicht ab", "y": RAISED, "lever": Vector3(0.0, 0.0, 5.5), "sign_h": 4.5, "props": {"axis_mode": RotatingPlatform.AxisMode.TILTING}},
	{"tag": "Crumbling", "zone": "Tragen", "slots": [Vector2i(3, 0)], "kind": "driven", "scene": CRUMBLING_SCENE, "text": "Bröckel-Plattform", "expect": "Erwartet: Wackelt, fällt runter, kommt nach 3 s zurück", "y": 2.0, "sign_h": 4.2},
	{"tag": "Paternoster", "zone": "Tragen", "slots": [Vector2i(4, 0)], "kind": "mover", "scene": PATERNOSTER_SCENE, "text": "Paternoster", "expect": "Erwartet: Kabinen fahren im Kreis, auf- und abspringen", "y": RAISED, "lever": Vector3(-6.0, 0.0, 4.0)},
	{"tag": "LiftPiston", "zone": "Tragen", "slots": [Vector2i(0, 1)], "kind": "mover", "scene": LIFT_SCENE, "text": "Hub-Plattform: Kolben", "expect": "Erwartet: Hebel an fährt hoch, Hebel aus fährt runter", "y": RAISED, "lever": Vector3(0.0, 0.0, 4.5), "sign_h": 7.0, "props": {"look": LiftPlatform.Look.PISTON}},
	{"tag": "LiftChain", "zone": "Tragen", "slots": [Vector2i(1, 1)], "kind": "mover", "scene": LIFT_SCENE, "text": "Hub-Plattform: Kette", "expect": "Erwartet: Hebel an fährt hoch, Hebel aus fährt runter", "y": RAISED, "lever": Vector3(0.0, 0.0, 4.5), "sign_h": 7.0, "props": {"look": LiftPlatform.Look.CHAIN}},
	{"tag": "ConveyorRun", "zone": "Tragen", "slots": [Vector2i(2, 1), Vector2i(3, 1)], "kind": "mover", "scene": CONVEYOR_SCENE, "text": "Förderband: läuft solange an", "expect": "Erwartet: Das Band trägt dich, der Absprung behält den Schwung", "yaw": -90.0, "lever": Vector3(0.0, 0.0, 3.5), "props": {"behaviour": Mechanism.Behaviour.RUN_WHILE_ON}},
	{"tag": "ConveyorReverse", "zone": "Tragen", "slots": [Vector2i(4, 1), Vector2i(5, 1)], "kind": "mover", "scene": CONVEYOR_SCENE, "text": "Förderband: Hebel kehrt um", "expect": "Erwartet: Läuft immer, der Hebel kehrt die Richtung um", "yaw": -90.0, "lever": Vector3(0.0, 0.0, 3.5), "props": {"behaviour": Mechanism.Behaviour.REVERSE_ON_SIGNAL}},
	# Werfen & Tempo (einmal Tempo in eine Richtung)
	{"tag": "BoostRing", "zone": "Werfen", "slots": [Vector2i(0, 0), Vector2i(1, 0)], "kind": "driven", "scene": BOOST_SCENE, "text": "Boost-Ring", "expect": "Erwartet: Durchfliegen gibt Tempo und lädt den Dash", "y": 2.5},
	{"tag": "Slingshot", "zone": "Werfen", "slots": [Vector2i(3, 0)], "kind": "driven", "scene": SLINGSHOT_SCENE, "text": "Schleuderkern", "expect": "Erwartet: Rein von links oben, raus nach rechts unten", "y": 3.0},
	{"tag": "NozzleCannon", "zone": "Werfen", "slots": [Vector2i(0, 1)], "kind": "mover", "scene": NOZZLE_SCENE, "text": "Dampfdüse: Kanone", "expect": "Erwartet: Wirft dich schräg in Düsenrichtung", "yaw": -90.0, "pitch": 45.0, "lever": Vector3(0.0, 0.0, 2.5), "props": {"mode": SteamNozzle.Mode.CANNON}},
	{"tag": "Tube", "zone": "Werfen", "slots": [Vector2i(3, 1)], "kind": "driven", "scene": TUBE_SCENE, "text": "Rohrpost", "expect": "Erwartet: Rein ins Rohr, am Ende schießt es dich raus", "yaw": -90.0, "offset": Vector3(-8.0, 0.0, 0.0), "props": {"exit_speed": 6.0}},
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
		if SHOT_STATION_TAGS.has(String(row["tag"])):
			var capsule: Node3D = builder.call(&"_instance", zone, CAPSULE_SCENE, "Capsule_%s" % String(row["tag"]), at + CAPSULE_OFFSET) as Node3D
			capsule.set("respawn_time", CAPSULE_RESPAWN)
		entries.append({"tag": StringName(String(row["tag"])), "at": at, "zone": StringName(String(row["zone"]))})
	zone.set_meta(&"stations", entries)


## The station point: a slot, or the midpoint of two slots (half block).
func _station_point(row: Dictionary) -> Vector3:
	var slots: Array = row["slots"] as Array
	var owner_room: Dictionary = room(String(row["zone"]))
	var sum: Vector3 = Vector3.ZERO
	for item: Variant in slots:
		var cell: Vector2i = item as Vector2i
		sum += slot(owner_room, cell.x, cell.y)
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
	# The hall east wall ends at z 34; room 2 reaches z 32, so the plug only doubles the hall wall there (kept as the corner piece).
	builder.call(&"_wall", zone, "Room2WallWestPlug", WALL_X, ROOM_Z_HALF, 90.0)


func _build_door(zone: Node3D, builder: RefCounted) -> void:
	# _yaw(90) = Basis(UP, +90 deg) maps local -X to world +Z: the open gate slides along +z inside the wall plane,
	# into the WallEast_1 segment (z 2..6) beside the doorway, never into room 2 or the hall.
	var gate: Node3D = builder.call(&"_instance", zone, GATE_SCENE, "ZahnradTor", Vector3(WALL_X, 0.0, 0.0), builder.call(&"_yaw", 90.0)) as Node3D
	var lever: Node3D = builder.call(&"_instance", zone, LEVER_SCENE, "TracerLever", Vector3(38.0, 0.0, -3.0)) as Node3D
	gate.set("source", lever)
	builder.call(&"_label", zone, "Label_Tracer", "Fernauslöser: LMB tippen", Vector3(38.0, 2.4, -3.0))
	builder.call(&"_label", zone, "Label_Room2", "Raum 2", Vector3(WALL_X, 5.0, 0.0))


## Room decor (D-04, D-12), all under the group ZoneDecor so that the stations stay the only mechanism children of the zone: a tint
## overlay ZoneFloor_<tag>, the room's own four walls RoomWall_* (4 m tiles on the rect edges, no ceiling) with one 4 m doorway
## into the corridor, a door sign DoorSign_<tag> over that doorway and a large header ZoneHeader_<tag> over the room centre.
## Stores the metadata `zones` the layout test reads.
func _build_zones(zone: Node3D, builder: RefCounted) -> void:
	var decor: Node3D = builder.call(&"_group", zone, "ZoneDecor") as Node3D
	var entries: Array = []
	var wall: int = 0
	for row: Dictionary in ZONES:
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
		# The corridor-side edge (north rooms: max z, south rooms: min z) and the x of the doorway tile.
		var north: bool = String(row["side"]) == "N"
		var corridor_z: float = rect.end.y if north else rect.position.y
		var far_z: float = rect.position.y if north else rect.end.y
		var door_x: float = rect.position.x + SLOT_PITCH * (int(row["door"]) + 0.5)
		var along: int = roundi(rect.size.x / TILE)
		for k: int in along:
			var x: float = rect.position.x + TILE * (k + 0.5)
			builder.call(&"_wall", decor, "RoomWall_%d" % wall, x, far_z, 0.0)
			wall += 1
			if absf(x - door_x) < 0.01:
				continue
			builder.call(&"_wall", decor, "RoomWall_%d" % wall, x, corridor_z, 0.0)
			wall += 1
		var across: int = roundi(rect.size.y / TILE)
		for k: int in across:
			var z: float = rect.position.y + TILE * (k + 0.5)
			builder.call(&"_wall", decor, "RoomWall_%d" % wall, rect.position.x, z, 90.0)
			builder.call(&"_wall", decor, "RoomWall_%d" % (wall + 1), rect.end.x, z, 90.0)
			wall += 2
		# The door sign hangs over the doorway, 1 m out into the corridor.
		var sign_z: float = corridor_z + (1.0 if north else -1.0)
		builder.call(&"_label", decor, "DoorSign_%s" % tag, String(row["title"]), Vector3(door_x, DOOR_SIGN_HEIGHT, sign_z), DOOR_SIGN_FONT_SIZE)
	zone.set_meta(&"zones", entries)


## Room-2 safety net (T-04.1-13): a FallReset under x 81..ROOM_X_MAX + 30 (east of the hall reset's x 80 edge) that returns the player to
## Respawn_Room2 near the west door. The puzzle rooms carry their own resets above it.
func _build_room_reset(zone: Node3D, builder: RefCounted) -> void:
	var marker: Marker3D = Marker3D.new()
	builder.call(&"_adopt", zone, marker, "Respawn_Room2", RESPAWN_ROOM2)
	var rig: Node3D = (builder.get(&"_root") as Node).get_node("CameraRig") as Node3D
	var reset_x0: float = 81.0
	var reset_x1: float = ROOM_X_MAX + 30.0
	var centre: Vector3 = Vector3((reset_x0 + reset_x1) * 0.5, -30.0, 0.0)
	var area: FallReset = builder.call(&"_fall_reset", "FallResetRoom2", centre, Vector3(reset_x1 - reset_x0, 4.0, 132.0), marker, rig) as FallReset
	builder.call(&"_adopt", zone, area, "FallResetRoom2", centre)
	builder.call(&"_owner_children", area)
