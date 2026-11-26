extends RefCounted
## Worker of tools/movement_gym_builder.gd: Zone_KitSteampunk, the steampunk layer area of the kit showroom (Phase 05.1, D-28, D-29),
## x 43..151 right behind the hall's east door. Contract: build_into(zone, builder); the shell (floor, walls, header, reset, role
## groups) comes from tools/kit_area_shell.gd. Generated, never hand-edited. Steampunk = free and mechanical, it helps you (timing).
##
## Plan view (slot (column, row), see kit_area_shell.gd; every station a Station_<object> with an "Erwartet:" sign):
##   south, Role_Platforms   ClockHand (1, 0)  TiltPlate (2, 0)   (slot (0, 0) holds the clock hand's stepped ledge)
##   south, Role_Boosters    WallJump twin (3..4, 0)  WallRun (3, 1)  WallRunSteam (4, 1)  SteamCannon (5, 1)  Slingshot (6, 0, out of the cannon line)
##   north, Role_Environment Updraft (0, 1)  Geyser (1, 1)  SteamStream (2, 1)   (plan 05.1-15, force volumes, +1 step per use)
##   south, Role_Boosters    BoostRing (0, 1)  SpeedPad (1, 1)  BouncePad (2, 1)   (plan 05.1-16, impulse, +1 step per use)
##   north                   Role_Obstacles, Role_Mechanisms: empty until their blocks land (plans 16-19)
## Each station keeps the offsets, heights and sign spots it had in the old mechanism rooms (plans 01-04), relative to its slot point.

const KitAreaShell := preload("res://tools/kit_area_shell.gd")

## Timed motion looks (plan 05.1-04): the always-on clock hand (SWEEP) and tilt plate (TILT). The pivot stands at
## TimedMotion.min_pivot_height of the preset, so the swept deck never dips into the floor (D-07).
const CLOCK_HAND_SCENE: String = "res://scenes/kit/steampunk/clock_hand_platform.tscn"
const CLOCK_HAND_PRESET: String = "res://resources/kit/timed_motion/clock_hand.tres"
const TILT_PLATE_SCENE: String = "res://scenes/kit/steampunk/tilting_platform.tscn"
const TILT_PLATE_PRESET: String = "res://resources/kit/timed_motion/tilting_platform.tres"
## The stepped start ledge of a Timed motion station: no step is higher than this (the held plain jump reaches 2.0 m,
## docs/MOVEMENT-METRICS.md), and the top step stays this far under the pivot so it is never coplanar with the deck.
const DECK_STEP_MAX: float = 1.5
const DECK_LEDGE_GAP: float = 0.25
## Wall surface looks (plan 05.1-03): plain brass and steam look, wall-run 4 x 12 m and wall-jump 8 x 12 m.
const WALL_PAD_SCENE: String = "res://scenes/kit/steampunk/wall_pad.tscn"
const WALL_PAD_STEAM_SCENE: String = "res://scenes/kit/steampunk/wall_pad_steam.tscn"
const WALL_JUMP_PAD_SCENE: String = "res://scenes/kit/steampunk/wall_jump_pad.tscn"
const WALL_JUMP_PAD_STEAM_SCENE: String = "res://scenes/kit/steampunk/wall_jump_pad_steam.tscn"
## Wall-jump twin (D-06): the two pads stand this far apart centre to centre (the faces TWIN_FACE_GAP_MIN apart).
const WALL_TWIN_PITCH: float = WallSurface.TWIN_FACE_GAP_MIN + WallSurface.PANEL_THICKNESS
## Catch & launch looks (plans 05.1-01 / 02): the brass cage (FREE_AIM) and the steam cannon (FIXED, yaw only).
const SLINGSHOT_SCENE: String = "res://scenes/kit/steampunk/slingshot_core.tscn"
const STEAM_CANNON_SCENE: String = "res://scenes/kit/steampunk/steam_cannon.tscn"
const SLINGSHOT_HANG: float = 3.0
## Force volume looks (plan 05.1-15, D-09, D-43, D-61): updraft, geyser and steam stream, each GIVES +1 step per use.
const UPDRAFT_SCENE: String = "res://scenes/kit/steampunk/updraft.tscn"
const GEYSER_SCENE: String = "res://scenes/kit/steampunk/geyser.tscn"
const STEAM_STREAM_SCENE: String = "res://scenes/kit/steampunk/steam_stream.tscn"
## Impulse looks (plan 05.1-16, D-10, D-25, D-43): boost ring (air-dash counterpart), speed pad (dash-hop counterpart, replaces the
## conveyors) and bounce pad, each GIVES +1 step per use.
const BOOST_RING_SCENE: String = "res://scenes/kit/steampunk/boost_ring.tscn"
const SPEED_PAD_SCENE: String = "res://scenes/kit/steampunk/speed_pad.tscn"
const BOUNCE_PAD_SCENE: String = "res://scenes/kit/steampunk/bounce_pad.tscn"
## The ring hangs at this height over the station floor (its radius is 1.6 m, so the lowest point stays 0.2 m up).
const RING_HEIGHT: float = 1.8
const TINT: Color = Color(0.55, 0.45, 0.30)
const ROLES: Array[String] = ["Platforms", "Environment", "Obstacles", "Boosters", "Mechanisms"]

var _shell: KitAreaShell = KitAreaShell.new()


func build_into(zone: Node3D, builder: RefCounted) -> void:
	var x0: float = KitAreaShell.STEAMPUNK_X.x
	var signs: Dictionary = {
		"Platforms": _slot("S", 1, 0) + Vector3(0.0, 0.0, -5.0),
		"Boosters": _slot("S", 4, 0) + Vector3(6.0, 0.0, -5.0),
		"Environment": _slot("N", 1, 1) + Vector3(0.0, 0.0, 5.0),
		"Obstacles": _slot("N", 4, 1) + Vector3(0.0, 0.0, 5.0),
		"Mechanisms": _slot("N", 6, 1) + Vector3(0.0, 0.0, 5.0),
	}
	var groups: Dictionary = _shell.build_shell(zone, builder, "Steampunk: frei und mechanisch", x0, KitAreaShell.STEAMPUNK_X.y, ROLES, TINT, signs)
	if not groups.has("Platforms") or not groups.has("Boosters") or not groups.has("Environment"):
		return
	_build_platforms(groups["Platforms"] as Node3D, builder)
	_build_boosters(groups["Boosters"] as Node3D, builder)
	_build_environment(groups["Environment"] as Node3D, builder)


## Slot (column, row) on `side` of this area.
func _slot(side: String, column: int, row: int) -> Vector3:
	return _shell.slot(KitAreaShell.STEAMPUNK_X.x, side, column, row)


func _station(role: Node3D, builder: RefCounted, object_name: String, at: Vector3, title: String, expect: String, sign_offset: Vector3) -> Node3D:
	return _shell.station(role, builder, object_name, at, title, expect, sign_offset)


# --- Role_Platforms ------------------------------------------------------------------------------------------------------------------


## Timed motion (plan 05.1-04, D-07): always on, no source; the pivot stands at TimedMotion.min_pivot_height of the preset and a
## stepped ledge of floor tiles leads up to the fixed point of the deck (the hand's pivot end, the plate's axis edge).
func _build_platforms(role: Node3D, builder: RefCounted) -> void:
	var expect: String = "Erwartet: Läuft immer, schwingt hin und her, du bleibst auf dem Deck"
	var hand: Node3D = _station(role, builder, "ClockHand", _slot("S", 1, 0), "Uhrzeiger-Plattform", expect, Vector3(2.5, 4.5, 4.0))
	var hand_y: float = _deck_pivot_height(CLOCK_HAND_PRESET)
	builder.call(&"_instance", hand, CLOCK_HAND_SCENE, "ClockHand", Vector3(0.0, hand_y, 0.0))
	# The clock hand points +z from its pivot; the ledge stands behind the pivot end (the deck's lower edge swings +-0.5 * sin(limit)
	# there, so the top step keeps 0.5 m off) and steps down westward into the free slot (0, 0).
	_deck_stairs(hand, builder, "ClockHand", hand_y, Vector3(0.0, 0.0, -2.5), Vector3(-4.0, 0.0, 0.0))

	var plate: Node3D = _station(role, builder, "TiltPlate", _slot("S", 2, 0), "Kipp-Plattform", expect, Vector3(0.0, 4.5, 5.5))
	var plate_y: float = _deck_pivot_height(TILT_PLATE_PRESET)
	builder.call(&"_instance", plate, TILT_PLATE_SCENE, "TiltPlate", Vector3(0.0, plate_y, 0.0))
	# The plate rocks about its x axis; the midpoint of its west edge stays put, so the ledge stands west of it and steps down southward.
	_deck_stairs(plate, builder, "TiltPlate", plate_y, Vector3(-6.5, 0.0, 0.0), Vector3(0.0, 0.0, 4.0))


## The pivot height of a Timed motion station on the area floor (top y 0): TimedMotion.min_pivot_height of its preset (D-07).
func _deck_pivot_height(preset_path: String) -> float:
	var motion: TimedMotionConfig = load(preset_path) as TimedMotionConfig
	return TimedMotion.min_pivot_height(motion, 0.0)


## A stepped ledge of stacked floor tiles up to just under a Timed motion pivot, local to the station: the first column at `first`
## holds the top step (DECK_LEDGE_GAP or more under the pivot, rounded down to 0.5 m), each further column `step` away is one equal
## step lower, and no step is higher than DECK_STEP_MAX.
func _deck_stairs(station: Node3D, builder: RefCounted, tag: String, pivot_y: float, first: Vector3, step: Vector3) -> void:
	var highest: float = floorf((pivot_y - DECK_LEDGE_GAP) * 2.0) * 0.5
	var columns: int = maxi(ceili(highest / DECK_STEP_MAX), 1)
	for column: int in columns:
		var top: float = highest * float(columns - column) / float(columns)
		var cell: Vector3 = first + step * float(column)
		var layer: int = 0
		while top - float(layer) > 0.0:
			builder.call(&"_floor_tile", station, "%sStep_%d_%d" % [tag, column, layer], cell.x, top - float(layer), cell.z)
			layer += 1


# --- Role_Boosters -------------------------------------------------------------------------------------------------------------------


func _build_boosters(role: Node3D, builder: RefCounted) -> void:
	_build_wall_pads(role, builder)
	_build_catch_launch(role, builder)
	_build_impulses(role, builder)


## Wall surface (plan 05.1-03, D-06). The plain pad and its steam look stand side by side, parallel, 6 m apart, over the same x span
## (parity station); each is a wall-run surface on both faces. The wall-jump twin: two 8 m pads with WallSurface.TWIN_FACE_GAP_MIN
## between the faces, centred on the station point, so a held kick reaches the far pad instead of sailing over it. The far pad of the
## twin wears the steam look, so the twin is the wall-jump parity check as well. All always on, no source.
func _build_wall_pads(role: Node3D, builder: RefCounted) -> void:
	var run_expect: String = "Erwartet: Beide Platten laufen und springen genau gleich"
	var run: Node3D = _station(role, builder, "WallRun", _slot("S", 3, 1), "Wandlauf-Platte", run_expect, Vector3(-3.0, 3.2, -5.0))
	builder.call(&"_instance", run, WALL_PAD_SCENE, "WallRun", Vector3(9.0, 0.0, -3.0))
	var steam: Node3D = _station(role, builder, "WallRunSteam", _slot("S", 4, 1), "Wandlauf-Platte (Dampf-Look)", run_expect, Vector3(-15.0, 3.2, 0.0))
	builder.call(&"_instance", steam, WALL_PAD_STEAM_SCENE, "WallRunSteam", Vector3(-3.0, 0.0, 3.0))

	var twin_at: Vector3 = (_slot("S", 3, 0) + _slot("S", 4, 0)) * 0.5
	var twin: Node3D = _station(role, builder, "WallJump", twin_at, "Wandsprung-Platten (Messing und Dampf)", "Erwartet: Abstoßen trägt dich zur Gegenwand, nicht darüber; beide Platten gleich", Vector3(-8.0, 4.2, 0.0))
	var near: Vector3 = Vector3(3.0, 0.0, -WALL_TWIN_PITCH * 0.5)
	builder.call(&"_instance", twin, WALL_JUMP_PAD_SCENE, "WallJump", near)
	builder.call(&"_instance", twin, WALL_JUMP_PAD_STEAM_SCENE, "WallJump2", near + Vector3(0.0, 0.0, WALL_TWIN_PITCH))


## Catch & launch (plans 05.1-01 / 02). The cannon is yaw only: the barrel pitch lives in its config, never on the node; yaw -90
## points the barrel east, along the free row toward the area's east wall. The cage hangs SLINGSHOT_HANG over the floor.
func _build_catch_launch(role: Node3D, builder: RefCounted) -> void:
	var cannon: Node3D = _station(role, builder, "SteamCannon", _slot("S", 5, 1), "Dampfkanone", "Erwartet: Fängt dich am Rohr, kurz Halt, dann immer der gleiche Bogen; +1 Stufe", Vector3(-4.0, 3.2, 4.0))
	builder.call(&"_instance", cannon, STEAM_CANNON_SCENE, "SteamCannon", Vector3.ZERO, builder.call(&"_yaw", -90.0))
	var cage: Node3D = _station(role, builder, "Slingshot", _slot("S", 6, 0), "Schleuderkern (wie der Loader)", "Erwartet: Fängt dich nur, wenn du mitten durch den Ring fliegst; Zeitlupe, Rechtsklick loslassen wirft dich gerade in Blickrichtung; +1 Stufe", Vector3(-4.0, 3.2, 4.0))
	builder.call(&"_instance", cage, SLINGSHOT_SCENE, "Slingshot", Vector3(0.0, SLINGSHOT_HANG, 0.0))


## Impulse (plan 05.1-16, D-10, D-25). Ring: axis +x, hangs RING_HEIGHT up, fly through it along x. Pad: forward is -z, run over it from
## the south. Bounce pad: land on it; the higher the drop the higher the bounce.
func _build_impulses(role: Node3D, builder: RefCounted) -> void:
	var ring: Node3D = _station(role, builder, "BoostRing", _slot("S", 0, 1), "Boost-Ring", "Erwartet: Im Flug durchfliegen: Schub und der Luft-Dash ist wieder da; +1 Stufe", Vector3(0.0, 4.4, 0.0))
	builder.call(&"_instance", ring, BOOST_RING_SCENE, "Ring", Vector3(0.0, RING_HEIGHT, 0.0))
	var pad: Node3D = _station(role, builder, "SpeedPad", _slot("S", 1, 1), "Speed-Pad", "Erwartet: Drüberlaufen gibt einen kurzen Schub wie ein Dash-Hop, gratis; +1 Stufe", Vector3(0.0, 3.2, -3.0))
	builder.call(&"_instance", pad, SPEED_PAD_SCENE, "Pad", Vector3(0.0, 0.0, 0.0))
	var bounce: Node3D = _station(role, builder, "BouncePad", _slot("S", 2, 1), "Sprungplatte", "Erwartet: Wirft dich hoch; +1 Stufe", Vector3(0.0, 3.2, -3.0))
	builder.call(&"_instance", bounce, BOUNCE_PAD_SCENE, "Pad", Vector3(0.0, 0.0, 0.0))


# --- Role_Environment ----------------------------------------------------------------------------------------------------------------


## Force volumes (plan 05.1-15): updraft, geyser and steam stream stand in the north row next to the corridor. The stream blows along
## the station's local -z, away from its vent at +z; the stations are 12 m apart (one slot each).
func _build_environment(role: Node3D, builder: RefCounted) -> void:
	var updraft: Node3D = _station(role, builder, "Updraft", _slot("N", 0, 1), "Aufwind", "Erwartet: Dampf trägt dich nach oben; +1 Stufe beim Hineinfliegen", Vector3(0.0, 5.4, 0.0))
	builder.call(&"_instance", updraft, UPDRAFT_SCENE, "Updraft", Vector3.ZERO)
	var geyser: Node3D = _station(role, builder, "Geyser", _slot("N", 1, 1), "Geysir", "Erwartet: Stößt im Takt; wer im Stoß steht, fliegt hoch; +1 Stufe", Vector3(0.0, 4.4, 0.0))
	builder.call(&"_instance", geyser, GEYSER_SCENE, "Geyser", Vector3.ZERO)
	var stream: Node3D = _station(role, builder, "SteamStream", _slot("N", 2, 1), "Dampfstrom", "Erwartet: Schiebt dich seitlich mit; +1 Stufe", Vector3(-4.0, 3.2, 0.0))
	builder.call(&"_instance", stream, STEAM_STREAM_SCENE, "SteamStream", Vector3.ZERO)
