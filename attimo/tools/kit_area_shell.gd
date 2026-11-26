extends RefCounted
## Shared shell of the kit layer areas (Phase 05.1, D-28, D-29): the gym's showroom behind the hall's east door. Used by the layer
## workers tools/kit_steampunk_builder.gd, kit_energy_builder.gd and kit_nature_builder.gd (and the mixed course of plan 20), each of
## them a worker of tools/movement_gym_builder.gd with the contract build_into(zone, builder); the builder's helpers are reached with
## builder.call(&"_instance", ...) and so on. Generated, never hand-edited.
##
## Plan view (x east, z south, 4 m tile lattice, every area z -32..32; gym placement decision, unattended decision 6):
##   hall east wall x 42.5, its z -2..2 cell is a plain doorway (no gate); a 1 m threshold beam closes the x 42..43 seam.
##   corridor z -4..4 runs east through every area; between two areas a 4 m connector (one tile column, corridor tiles only).
##   Zone_KitSteampunk x 43..151 | connector x 151..155 | Zone_KitEnergy x 155..227 | connector x 227..231 | Zone_KitNature x 231..291
##   Zone_KitCourse x 295..395 follows in plan 20; until then the nature area's east wall is closed.
## Slots: SLOT_PITCH 12 m, two rows per side: north rows z -28..-4 (row 0 = far, z -22; row 1 = by the corridor, z -10), south rows
## z 4..28 (row 0 = by the corridor, z 10; row 1 = far, z 22); column c of an area starts SLOT_MARGIN east of the area's west edge.
## Every station is a Station_<object> group under its Role_<Name> group, placed at its station point, with a title sign and an
## "Erwartet: ..." sign (D-28); stations only, no teach / test / twist beats in this phase (D-32).

const TILE: float = 4.0
const CORRIDOR_HALF: float = 4.0
const Z_HALF: float = 32.0
const SLOT_PITCH: float = 12.0
const SLOT_MARGIN: float = 4.0
const ROW_DEPTH: float = 24.0
## Area x spans (west edge, east edge).
const STEAMPUNK_X: Vector2 = Vector2(43.0, 151.0)
const ENERGY_X: Vector2 = Vector2(155.0, 227.0)
const NATURE_X: Vector2 = Vector2(231.0, 291.0)
const COURSE_X: Vector2 = Vector2(295.0, 395.0)
## The hall's east wall line and the east edge of the hall's fall reset (FallResetHall spans x -80..80): an area reset starts east of
## it so the two volumes never overlap.
const HALL_WALL_X: float = 42.5
const HALL_RESET_X_MAX: float = 80.0
const RESET_Y: float = -30.0
const RESET_DEPTH: float = 132.0
const BEAM_SCENE: String = "res://scenes/proto/primitive_beam.tscn"
const ZONE_FLOOR_SCENE: String = "res://scenes/mechanisms/zone_floor.tscn"
## The zone floor overlay is 24 x 24 m; the instance is scaled to the area rect.
const ZONE_FLOOR_SIZE: float = 24.0
const CAPSULE_SCENE: String = "res://scenes/kit/energy/energy_capsule.tscn"
const CAPSULE_RESPAWN: float = 6.0
const HEADER_FONT_SIZE: int = 128
const HEADER_HEIGHT: float = 7.5
const ROLE_FONT_SIZE: int = 96
const ROLE_SIGN_HEIGHT: float = 5.2
const EXPECT_FONT_SIZE: int = 40
const EXPECT_DROP: float = 0.7
const EXPECT_PREFIX: String = "Erwartet:"
## Signal stations (plan 05.1-17): the gate -> timer -> drawbridge course and the gate -> timer -> switched speed pad course.
const GATE_SCENE: String = "res://scenes/kit/energy/charge_gate.tscn"
const TIMER_SCENE: String = "res://scenes/mechanisms/logic_timer.tscn"
const DRAWBRIDGE_SCENE: String = "res://scenes/kit/steampunk/drawbridge.tscn"
const SWITCHED_PAD_SCENE: String = "res://scenes/kit/steampunk/speed_pad_switched.tscn"
## Ledge tops of the bridge course in m: a half step (0.5) leads up to the ledges (1.5, a plain held jump reaches 2.0).
const LEDGE_TOP: float = 1.5
const STEP_TOP: float = 0.5
## Seconds the drawbridge stays down after the gate switched, and the switched pad stays live.
const BRIDGE_HOLD: float = 10.0
const PAD_HOLD: float = 5.0
## Role group name suffix -> sign text.
const ROLE_TITLES: Dictionary = {
	"Platforms": "Plattformen",
	"Environment": "Umgebung",
	"Obstacles": "Hindernisse",
	"Boosters": "Booster",
	"Mechanisms": "Mechanismen",
}


## The centre of slot (column, row) on side "N" or "S" of the area that starts at `area_x0`.
func slot(area_x0: float, side: String, column: int, row: int) -> Vector3:
	var z0: float = -CORRIDOR_HALF - ROW_DEPTH if side == "N" else CORRIDOR_HALF
	return Vector3(area_x0 + SLOT_MARGIN + SLOT_PITCH * (column + 0.5), 0.0, z0 + SLOT_PITCH * (row + 0.5))


## Floor, walls, corridor doorways, header, tint, fall reset and one Role_<Name> group per role (with a role sign). `roles` are the
## ROLE_TITLES keys; `role_signs` maps a role to its sign position (default: spread along the corridor). With `east_open` the east
## wall keeps its corridor cells open; `reset_east` is how far the fall reset reaches past the east edge. Returns role -> group.
func build_shell(zone: Node3D, builder: RefCounted, title: String, x_min: float, x_max: float, roles: Array[String], tint: Color, role_signs: Dictionary = {}, east_open: bool = true, reset_east: float = 0.0) -> Dictionary:
	zone.set_meta(&"x_range", Vector2(x_min, x_max))
	_build_floor(zone, builder, x_min, x_max)
	_build_walls(zone, builder, x_min, x_max, east_open)
	_build_decor(zone, builder, title, x_min, x_max, tint)
	_build_reset(zone, builder, x_min, x_max, reset_east)
	var groups: Dictionary = {}
	for index: int in roles.size():
		var role: String = roles[index]
		if not ROLE_TITLES.has(role):
			builder.set(&"failure", "unknown kit role %s" % role)
			return groups
		var group: Node3D = builder.call(&"_group", zone, "Role_%s" % role) as Node3D
		var default_at: Vector3 = Vector3(x_min + (x_max - x_min) * (index + 0.5) / roles.size(), 0.0, 0.0)
		var at: Vector3 = role_signs.get(role, default_at) as Vector3
		builder.call(&"_label", group, "RoleSign_%s" % role, String(ROLE_TITLES[role]), Vector3(at.x, ROLE_SIGN_HEIGHT, at.z), ROLE_FONT_SIZE)
		groups[role] = group
	return groups


## A station group Station_<object_name> under `role_group` at the station point `at`, with a title sign Label_<object_name> and the
## expectation sign Label_<object_name>_Expect EXPECT_DROP below it (`sign_offset` is local to the station). `expect` must start with
## "Erwartet:". Children of the station use local positions.
func station(role_group: Node3D, builder: RefCounted, object_name: String, at: Vector3, title: String, expect: String, sign_offset: Vector3 = Vector3(0.0, 3.2, 0.0)) -> Node3D:
	if not expect.begins_with(EXPECT_PREFIX):
		builder.set(&"failure", "station %s: the expectation sign must start with '%s' (%s)" % [object_name, EXPECT_PREFIX, expect])
	var node: Node3D = builder.call(&"_group", role_group, "Station_%s" % object_name) as Node3D
	node.position = at
	builder.call(&"_label", node, "Label_%s" % object_name, title, sign_offset)
	builder.call(&"_label", node, "Label_%s_Expect" % object_name, expect, sign_offset - Vector3(0.0, EXPECT_DROP, 0.0), EXPECT_FONT_SIZE)
	return node


## The gate -> timer -> drawbridge course in the station's local frame, the bridge running east (+x): a near ledge (x -8..0) with the charge
## gate in the middle, the hinge at its edge (x 0), an 8 m deck and a far ledge (x 8..16), a half step to the near ledge on its north side.
## The timer (invisible, BRIDGE_HOLD s) keeps the bridge down while the player crosses; the receiver's source is wired here. The station
## origin is the hinge column; the pit under the deck is the area floor, 1.5 m down.
func bridge_course(station_node: Node3D, builder: RefCounted, tag: String) -> void:
	for x: float in [-6.0, -2.0]:
		for z: float in [-2.0, 2.0]:
			_ledge(station_node, builder, "%sNear_%d_%d" % [tag, int(x), int(z)], x, z, LEDGE_TOP)
	for x: float in [10.0, 14.0]:
		for z: float in [-2.0, 2.0]:
			_ledge(station_node, builder, "%sFar_%d_%d" % [tag, int(x), int(z)], x, z, LEDGE_TOP)
	_ledge(station_node, builder, "%sStep" % tag, -6.0, -6.0, STEP_TOP)
	var east: Basis = builder.call(&"_yaw", 90.0) as Basis
	var gate: Node3D = builder.call(&"_instance", station_node, GATE_SCENE, "Gate", Vector3(-4.0, LEDGE_TOP, 0.0), east) as Node3D
	var timer: Node3D = builder.call(&"_instance", station_node, TIMER_SCENE, "Timer", Vector3(-4.0, LEDGE_TOP, 0.0)) as Node3D
	timer.visible = false
	timer.set(&"source", gate)
	timer.set(&"hold_time", BRIDGE_HOLD)
	var bridge: Node3D = builder.call(&"_instance", station_node, DRAWBRIDGE_SCENE, "Drawbridge", Vector3(0.0, LEDGE_TOP, 0.0), east) as Node3D
	wire_receiver(bridge, builder, timer)


## The gate -> timer -> switched speed pad course: the pad at the station origin (forward -z), the gate 7 m south of it, the timer
## keeps the pad live for PAD_HOLD s after the gate switched.
func pad_course(station_node: Node3D, builder: RefCounted) -> void:
	var gate: Node3D = builder.call(&"_instance", station_node, GATE_SCENE, "Gate", Vector3(0.0, 0.0, 7.0)) as Node3D
	var timer: Node3D = builder.call(&"_instance", station_node, TIMER_SCENE, "Timer", Vector3(0.0, 0.0, 7.0)) as Node3D
	timer.visible = false
	timer.set(&"source", gate)
	timer.set(&"hold_time", PAD_HOLD)
	var pad: Node3D = builder.call(&"_instance", station_node, SWITCHED_PAD_SCENE, "Pad", Vector3.ZERO) as Node3D
	wire_receiver(pad, builder, timer)


## Points the Receiver inside the instance `block` at `source`. The block becomes an editable instance, so the saved scene keeps the
## wiring as an override of the instanced child; a missing Receiver fails the build.
func wire_receiver(block: Node3D, builder: RefCounted, source: Node3D) -> void:
	var receiver: Node = block.get_node_or_null(^"Receiver")
	if receiver == null:
		builder.set(&"failure", "%s has no Receiver to wire" % block.name)
		return
	var root: Node = builder.get(&"_root") as Node
	# Editable children: only then does pack() save the child as an override of the instance (the Receiver keeps the instance root as its
	# owner; giving it the gym as owner saved a second, new Receiver next to the instanced one).
	root.set_editable_instance(block, true)
	receiver.set(&"source", source)


## A stack of floor tiles from `top` down to the floor (one tile every metre), centred at (x, z) of the station.
func _ledge(station_node: Node3D, builder: RefCounted, tag: String, x: float, z: float, top: float) -> void:
	var layer: int = 0
	while top - float(layer) > 0.0:
		builder.call(&"_floor_tile", station_node, "%s_%d" % [tag, layer], x, top - float(layer), z)
		layer += 1


## An energy capsule with a respawn beside a target station (every target station keeps one, D-19), at the global point `at`.
func capsule_beside(station_node: Node3D, builder: RefCounted, at: Vector3, respawn: float = CAPSULE_RESPAWN) -> Node3D:
	var capsule: Node3D = builder.call(&"_instance", station_node, CAPSULE_SCENE, "Capsule", at - station_node.position) as Node3D
	capsule.call("set_respawn", respawn)
	return capsule


## Floor tiles over the area rect plus, west of it, the corridor tiles of the connector (or the threshold beam at the hall wall).
func _build_floor(zone: Node3D, builder: RefCounted, x_min: float, x_max: float) -> void:
	var columns: int = roundi((x_max - x_min) / TILE)
	var rows: int = roundi(Z_HALF * 2.0 / TILE)
	for column: int in columns:
		var x: float = x_min + TILE * (column + 0.5)
		for row: int in rows:
			builder.call(&"_floor_tile", zone, "Floor_%d_%d" % [column, row], x, 0.0, -Z_HALF + TILE * (row + 0.5))
	if x_min - TILE * 0.5 < HALL_WALL_X:
		# The hall floor ends at x 42 and the area starts at x 43: a 1 m threshold closes the wall cell between them.
		builder.call(&"_instance", zone, BEAM_SCENE, "Threshold", Vector3(HALL_WALL_X, -1.0, 0.0), builder.call(&"_yaw", 90.0))
		return
	var connector_x: float = x_min - TILE * 0.5
	for index: int in 2:
		var z: float = -CORRIDOR_HALF + TILE * (index + 0.5)
		builder.call(&"_floor_tile", zone, "ConnectorFloor_%d" % index, connector_x, 0.0, z)
	builder.call(&"_wall", zone, "ConnectorWallNorth", connector_x, -CORRIDOR_HALF - 0.5, 0.0)
	builder.call(&"_wall", zone, "ConnectorWallSouth", connector_x, CORRIDOR_HALF + 0.5, 0.0)


## 4 m walls round the area, 0.5 m outside its edges. The west wall leaves the corridor cells open (at the hall the hall's own east
## wall is the west wall); the east wall too while `east_open`.
func _build_walls(zone: Node3D, builder: RefCounted, x_min: float, x_max: float, east_open: bool) -> void:
	var columns: int = roundi((x_max - x_min) / TILE)
	for column: int in columns:
		var x: float = x_min + TILE * (column + 0.5)
		builder.call(&"_wall", zone, "AreaWallNorth_%d" % column, x, -Z_HALF - 0.5, 0.0)
		builder.call(&"_wall", zone, "AreaWallSouth_%d" % column, x, Z_HALF + 0.5, 0.0)
	var rows: int = roundi(Z_HALF * 2.0 / TILE)
	var at_hall: bool = x_min - TILE * 0.5 < HALL_WALL_X
	for row: int in rows:
		var z: float = -Z_HALF + TILE * (row + 0.5)
		var corridor: bool = absf(z) < CORRIDOR_HALF
		if not at_hall and not corridor:
			builder.call(&"_wall", zone, "AreaWallWest_%d" % row, x_min - 0.5, z, 90.0)
		if not (east_open and corridor):
			builder.call(&"_wall", zone, "AreaWallEast_%d" % row, x_max + 0.5, z, 90.0)


## A tint overlay AreaFloor in the layer colour and a large header AreaHeader over the area centre.
func _build_decor(zone: Node3D, builder: RefCounted, title: String, x_min: float, x_max: float, tint: Color) -> void:
	var centre_x: float = (x_min + x_max) * 0.5
	var scale: Vector3 = Vector3((x_max - x_min) / ZONE_FLOOR_SIZE, 1.0, Z_HALF * 2.0 / ZONE_FLOOR_SIZE)
	var overlay: MeshInstance3D = builder.call(&"_instance", zone, ZONE_FLOOR_SCENE, "AreaFloor", Vector3(centre_x, 0.01, 0.0), Basis.IDENTITY.scaled(scale)) as MeshInstance3D
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.9
	overlay.material_override = material
	builder.call(&"_label", zone, "AreaHeader", title, Vector3(centre_x, HEADER_HEIGHT, 0.0), HEADER_FONT_SIZE)


## T-05.1-19: a FallReset under the area and its west connector (x_min - TILE .. x_max + reset_east) that returns the player to Respawn_<zone> at the area's west
## corridor entry. It starts east of the hall reset so the two never overlap.
func _build_reset(zone: Node3D, builder: RefCounted, x_min: float, x_max: float, reset_east: float) -> void:
	var marker: Marker3D = Marker3D.new()
	builder.call(&"_adopt", zone, marker, "Respawn_%s" % zone.name, Vector3(x_min + SLOT_MARGIN, 0.0, 0.0))
	var rig: Node3D = (builder.get(&"_root") as Node).get_node("CameraRig") as Node3D
	var x0: float = maxf(x_min - TILE, HALL_RESET_X_MAX + 1.0)
	var x1: float = x_max + reset_east
	var centre: Vector3 = Vector3((x0 + x1) * 0.5, RESET_Y, 0.0)
	var area: FallReset = builder.call(&"_fall_reset", "FallReset_%s" % zone.name, centre, Vector3(x1 - x0, 4.0, RESET_DEPTH), marker, rig) as FallReset
	builder.call(&"_adopt", zone, area, "FallReset_%s" % zone.name, centre)
	builder.call(&"_owner_children", area)
