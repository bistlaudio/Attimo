extends RefCounted
## Worker of tools/movement_gym_builder.gd: the mechanism rooms (phase 4). The gym is generated, so the rooms live
## here. Pinned worker contract, used by every room worker of this phase: build_into(zone, builder), where `builder` is
## the movement_gym_builder instance. Its helpers are invoked with builder.call(&"_adopt", ...) and so on (a RefCounted
## typed handle has no such methods). Coordinates are on the 1 m grid with 2 m / 4 m modules.
##
## Plan view (x east, z south): the hall east wall sits at x 42.5. The door (Zahnrad-Tor) is its z 0 cell, the tracer lever
## stands on the hall side at (38, -3). Room 2 is the shell east of the door, x 43..75, z -16..16.

const GATE_SCENE: String = "res://scenes/mechanisms/gear_gate.tscn"
const LEVER_SCENE: String = "res://scenes/mechanisms/lever.tscn"
const BEAM_SCENE: String = "res://scenes/proto/primitive_beam.tscn"
const WALL_X: float = 42.5
const ROOM_X_MIN: float = 43.0
const ROOM_X_MAX: float = 75.0
const ROOM_Z_HALF: float = 16.0
const TILE: float = 4.0


func build_into(zone: Node3D, builder: RefCounted) -> void:
	_build_room_shell(zone, builder)
	_build_door(zone, builder)
	build_showcase_stations(zone, builder)


## The extension point for later plans: showcase stations along the room walls (04-03, 04-04, 04-05).
func build_showcase_stations(_zone: Node3D, _builder: RefCounted) -> void:
	pass


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
		var z: float = -ROOM_Z_HALF + TILE * 0.5 + TILE * row
		builder.call(&"_wall", zone, "Room2WallEast_%d" % row, ROOM_X_MAX + 0.5, z, 90.0, 0.0)
	# The hall floor ends at x 42 and room 2 starts at x 43: a 1 m threshold closes the wall cell between them.
	builder.call(&"_instance", zone, BEAM_SCENE, "Room2Threshold", Vector3(WALL_X, -1.0, 0.0), builder.call(&"_yaw", 90.0))


func _build_door(zone: Node3D, builder: RefCounted) -> void:
	# _yaw(90) = Basis(UP, +90 deg) maps local -X to world +Z: the open gate slides along +z inside the wall plane,
	# into the WallEast_1 segment (z 2..6) beside the doorway, never into room 2 or the hall.
	var gate: Node3D = builder.call(&"_instance", zone, GATE_SCENE, "ZahnradTor", Vector3(WALL_X, 0.0, 0.0), builder.call(&"_yaw", 90.0)) as Node3D
	var lever: Node3D = builder.call(&"_instance", zone, LEVER_SCENE, "TracerLever", Vector3(38.0, 0.0, -3.0)) as Node3D
	gate.set("source", lever)
	builder.call(&"_label", zone, "Label_Tracer", "Fernauslöser: RMB halten, LMB tippen", Vector3(38.0, 2.4, -3.0))
	builder.call(&"_label", zone, "Label_Room2", "Raum 2", Vector3(WALL_X, 5.0, 0.0))
