extends RefCounted
## Phase 04.1 plan 05 (D-03, D-04, D-12): the layout contract of the showcase hall (room 2). The builder
## (tools/mechanism_rooms_builder.gd) stores two metadata arrays on Zone_MechanismRooms:
##   zones     Array[Dictionary] {tag, title, rect: Rect2 (x, z, width, depth), header: NodePath}
##   stations  Array[Dictionary] {tag, at: Vector3, zone: StringName}
## The test checks nine zones with tint, dividers and headers, a spacious slot grid (stations 10 m apart at least, 16 m to the
## nearest neighbour at most, 4 m inside their zone), a two-line sign per station, and that no moving or vanishing body is
## coplanar with a floor tile (a downward ray from 1 m above its top must hit the body itself).

const Fixtures := preload("res://tests/fixtures.gd")

const GYM_SCENE: String = "res://scenes/test/movement_gym.tscn"
const ZONE_FLOOR_SCENE: String = "res://scenes/mechanisms/zone_floor.tscn"
const ROOM_MIN: Vector2 = Vector2(43.0, -36.0)
const ROOM_MAX: Vector2 = Vector2(163.0, 36.0)
const ZONE_TAGS: Array[String] = ["Trigger", "Logik", "Dampf", "Gefahren", "Plattformen", "Felder", "Wand", "Tempo", "Umwelt"]
const STATION_TAGS: Array[String] = [
	"Valve", "EnergyCore", "Crank", "PressurePlate", "LogicAnd", "LogicOr", "LogicTimer",
	"NozzleCannon", "NozzleJump", "NozzleUpdraft", "Geyser", "NozzleWall",
	"Pendulum", "PistonWall", "WallRun", "WallJump", "Repulsor", "Attractor", "Slingshot", "Tube",
	"WindTunnel", "LowGravity", "RotatingLying", "RotatingStanding", "RotatingTilting", "Crumbling",
	"LiftPiston", "LiftChain", "Paternoster", "BoostRing", "Bounce", "ConveyorRun", "ConveyorReverse",
]
## Stations that own a gate Gate_<tag>.
const GATE_TAGS: Array[String] = ["Valve", "EnergyCore", "Crank", "PressurePlate", "LogicAnd", "LogicOr", "LogicTimer"]
const MIN_SPACING: float = 10.0
const MAX_NEIGHBOUR: float = 16.0
const EDGE_MARGIN: float = 4.0
const GATE_REACH: float = 6.0
const FLOOR_TILES: int = 540
const MIN_HEADER_FONT: int = 128
const RESPAWN_DOOR_REACH: float = 6.0


func run(tree: SceneTree, check: Callable) -> void:
	var packed: PackedScene = load(GYM_SCENE) as PackedScene
	check.call(packed != null, "the movement gym loads")
	if packed == null:
		return
	var gym: Node = packed.instantiate()
	tree.root.add_child(gym)
	await Fixtures.wait_physics(tree, 30)
	var zone: Node3D = gym.get_node_or_null("Zone_MechanismRooms") as Node3D
	check.call(zone != null, "the gym has Zone_MechanismRooms")
	if zone != null:
		var rects: Dictionary = _check_zones(gym, zone, check)
		_check_room_shell(gym, zone, check)
		# TASK2-ENABLE
	gym.queue_free()
	await gym.tree_exited


# --- zones ----------------------------------------------------------------------------------------------------


## Returns {tag: Rect2}.
func _check_zones(gym: Node, zone: Node3D, check: Callable) -> Dictionary:
	var rects: Dictionary = {}
	var entries: Array = zone.get_meta(&"zones", []) as Array
	check.call(entries.size() == 9, "Zone_MechanismRooms has nine zones in its metadata (got %d)" % entries.size())
	var tints: Array[Color] = []
	var room: Rect2 = Rect2(ROOM_MIN, ROOM_MAX - ROOM_MIN)
	for entry: Variant in entries:
		var data: Dictionary = entry as Dictionary
		var tag: String = str(data.get("tag", ""))
		var rect: Rect2 = data.get("rect", Rect2()) as Rect2
		rects[tag] = rect
		check.call(ZONE_TAGS.has(tag), "zone tag %s is known" % tag)
		check.call(room.encloses(rect), "zone %s lies inside room 2 (%s)" % [tag, rect])
		var header: Label3D = zone.get_node_or_null(data.get("header", NodePath())) as Label3D
		check.call(header != null, "zone %s has a header Label3D" % tag)
		if header != null:
			check.call(header.font_size >= MIN_HEADER_FONT, "zone %s header font size is at least %d (got %d)" % [tag, MIN_HEADER_FONT, header.font_size])
			check.call(header.text == str(data.get("title", "?")), "zone %s header text equals its title" % tag)
		var floor_node: MeshInstance3D = zone.find_child("ZoneFloor_%s" % tag, true, false) as MeshInstance3D
		check.call(floor_node != null, "zone %s has a ZoneFloor_%s" % [tag, tag])
		if floor_node != null:
			check.call(floor_node.scene_file_path == ZONE_FLOOR_SCENE, "ZoneFloor_%s is an instance of zone_floor.tscn" % tag)
			var material: StandardMaterial3D = floor_node.material_override as StandardMaterial3D
			check.call(material != null, "ZoneFloor_%s has a material_override" % tag)
			if material != null:
				tints.append(material.albedo_color)
	for tag: String in ZONE_TAGS:
		check.call(rects.has(tag), "zone %s is present" % tag)
	var keys: Array = rects.keys()
	var overlaps: PackedStringArray = PackedStringArray()
	for a: int in keys.size():
		for b: int in range(a + 1, keys.size()):
			var shrunk: Rect2 = (rects[keys[a]] as Rect2).grow(-0.01)
			if shrunk.intersects((rects[keys[b]] as Rect2).grow(-0.01)):
				overlaps.append("%s/%s" % [keys[a], keys[b]])
	check.call(overlaps.is_empty(), "zone rects do not overlap (%s)" % ", ".join(overlaps))
	var distinct: bool = true
	for a: int in tints.size():
		for b: int in range(a + 1, tints.size()):
			if tints[a].is_equal_approx(tints[b]):
				distinct = false
	check.call(tints.size() == 9 and distinct, "the nine zone tints are pairwise different (%d tints)" % tints.size())

	var dividers: Array[Node3D] = []
	for node: Node in _all(zone.get_node("ZoneDecor")):
		if str(node.name).begins_with("Divider_") and node is Node3D:
			dividers.append(node as Node3D)
	check.call(dividers.size() >= 9, "at least nine Divider_* beams stand on the zone borders (got %d)" % dividers.size())
	# One 4 m beam per 12 m border segment leaves a walkable gap of at least 4 m (here 8 m).
	var segments: Dictionary = {}
	var duplicate: int = 0
	for divider: Node3D in dividers:
		var key: String = "%d_%d" % [roundi(divider.global_position.x), roundi(divider.global_position.z)]
		if segments.has(key):
			duplicate += 1
		segments[key] = true
	check.call(duplicate == 0, "no border segment holds two dividers (%d duplicates)" % duplicate)
	var off_border: PackedStringArray = PackedStringArray()
	for divider: Node3D in dividers:
		if not _on_a_border(divider.global_position, rects):
			off_border.append("%s %s" % [divider.name, divider.global_position])
	check.call(off_border.is_empty(), "every divider stands on a zone border (off: %s)" % ", ".join(off_border))
	return rects


func _on_a_border(point: Vector3, rects: Dictionary) -> bool:
	for tag: Variant in rects:
		var rect: Rect2 = rects[tag] as Rect2
		var on_x: bool = absf(point.x - rect.position.x) < 0.01 or absf(point.x - rect.end.x) < 0.01
		var on_z: bool = absf(point.z - rect.position.y) < 0.01 or absf(point.z - rect.end.y) < 0.01
		var inside_x: bool = point.x >= rect.position.x - 0.01 and point.x <= rect.end.x + 0.01
		var inside_z: bool = point.z >= rect.position.y - 0.01 and point.z <= rect.end.y + 0.01
		if (on_x and inside_z) or (on_z and inside_x):
			return true
	return false


func _check_room_shell(gym: Node, zone: Node3D, check: Callable) -> void:
	var tiles: int = 0
	for child: Node in zone.get_children():
		if str(child.name).begins_with("Room2Floor_"):
			tiles += 1
	check.call(tiles == FLOOR_TILES, "room 2 has %d floor tiles (got %d)" % [FLOOR_TILES, tiles])
	check.call(zone.get_node_or_null("Room2WallWestPlug") != null, "Room2WallWestPlug closes the west wall gap")
	var reset: FallReset = zone.get_node_or_null("FallResetRoom2") as FallReset
	check.call(reset != null, "FallResetRoom2 exists")
	if reset != null:
		check.call(reset.collision_layer == PhysicsLayers.HAZARD, "FallResetRoom2 is on the Hazard layer")
		check.call(reset.respawn != null, "FallResetRoom2 has a respawn marker")
		if reset.respawn != null:
			var respawn: Vector3 = reset.respawn.global_position
			check.call(respawn.x >= ROOM_MIN.x and respawn.x <= ROOM_MAX.x and absf(respawn.z) < ROOM_MAX.y, "the room-2 respawn lies inside room 2 (%s)" % respawn)
			check.call(Vector3(respawn.x, 0.0, respawn.z).distance_to(Vector3(42.5, 0.0, 0.0)) <= RESPAWN_DOOR_REACH, "the room-2 respawn is within %.0f m of the west door" % RESPAWN_DOOR_REACH)


# --- stations -------------------------------------------------------------------------------------------------


func _check_stations(zone: Node3D, rects: Dictionary, check: Callable) -> void:
	var entries: Array = zone.get_meta(&"stations", []) as Array
	check.call(entries.size() == 33, "Zone_MechanismRooms has 33 stations in its metadata (got %d)" % entries.size())
	var points: Array[Vector3] = []
	var tags: Array[String] = []
	for entry: Variant in entries:
		var data: Dictionary = entry as Dictionary
		var tag: String = str(data.get("tag", ""))
		var at: Vector3 = data.get("at", Vector3.ZERO) as Vector3
		var zone_tag: String = str(data.get("zone", ""))
		tags.append(tag)
		points.append(at)
		check.call(STATION_TAGS.has(tag), "station %s is in the station table" % tag)
		var rect: Rect2 = rects.get(zone_tag, Rect2()) as Rect2
		var inside: bool = Rect2(rect.position + Vector2(EDGE_MARGIN, EDGE_MARGIN), rect.size - Vector2(EDGE_MARGIN, EDGE_MARGIN) * 2.0).has_point(Vector2(at.x, at.z))
		check.call(inside, "station %s at %s lies at least %.0f m inside zone %s" % [tag, at, EDGE_MARGIN, zone_tag])
		check.call(zone.get_node_or_null(tag) != null, "station %s is a direct child of Zone_MechanismRooms" % tag)
		var label: Label3D = zone.get_node_or_null("Label_%s" % tag) as Label3D
		check.call(label != null, "station %s has a sign Label_%s" % [tag, tag])
		var expect: Label3D = zone.get_node_or_null("Label_%s_Expect" % tag) as Label3D
		check.call(expect != null, "station %s has the second sign line Label_%s_Expect" % [tag, tag])
		if expect != null:
			check.call(expect.text.begins_with("Erwartet:"), "Label_%s_Expect starts with 'Erwartet:' (got '%s')" % [tag, expect.text])
		if GATE_TAGS.has(tag):
			var gate: Node3D = zone.get_node_or_null("Gate_%s" % tag) as Node3D
			check.call(gate != null and gate.global_position.distance_to(at) <= GATE_REACH, "station %s has Gate_%s within %.0f m" % [tag, tag, GATE_REACH])
	for tag: String in STATION_TAGS:
		check.call(tags.has(tag), "station table row %s is present" % tag)
	var too_close: PackedStringArray = PackedStringArray()
	var lonely: PackedStringArray = PackedStringArray()
	for a: int in points.size():
		var nearest: float = INF
		for b: int in points.size():
			if a == b:
				continue
			var distance: float = points[a].distance_to(points[b])
			nearest = minf(nearest, distance)
			if b > a and distance < MIN_SPACING:
				too_close.append("%s/%s %.1f" % [tags[a], tags[b], distance])
		if nearest > MAX_NEIGHBOUR:
			lonely.append("%s %.1f" % [tags[a], nearest])
	check.call(too_close.is_empty(), "every pair of stations is at least %.0f m apart (%s)" % [MIN_SPACING, ", ".join(too_close)])
	check.call(lonely.is_empty(), "every station has a neighbour within %.0f m (%s)" % [MAX_NEIGHBOUR, ", ".join(lonely)])


# --- coplanar ray guard ---------------------------------------------------------------------------------------


## Top centre of the first box shape under `body` in world space.
func _top_centre(body: CollisionObject3D) -> Vector3:
	for child: Node in body.get_children():
		var shape_node: CollisionShape3D = child as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			var size: Vector3 = (shape_node.shape as BoxShape3D).size
			return shape_node.global_transform * Vector3(0.0, size.y * 0.5, 0.0)
	return Vector3.INF


func _check_ray_guard(tree: SceneTree, gym: Node, check: Callable) -> void:
	await Fixtures.wait_physics(tree, 2)
	var bodies: Array[CollisionObject3D] = []
	for node: Node in _all(gym):
		if node is Conveyor:
			bodies.append(node.get_node("Belt") as CollisionObject3D)
		elif node is LiftPlatform or node is RotatingPlatform or node is CrumblingPlatform:
			bodies.append(node.get_node("Body") as CollisionObject3D)
		elif node is Paternoster:
			for deck: AnimatableBody3D in (node as Paternoster).decks():
				bodies.append(deck)
	check.call(bodies.size() >= 20, "the ray guard covers the moving and vanishing bodies (%d bodies)" % bodies.size())
	var space: PhysicsDirectSpaceState3D = (gym as Node3D).get_world_3d().direct_space_state
	var wrong: PackedStringArray = PackedStringArray()
	for body: CollisionObject3D in bodies:
		var top: Vector3 = _top_centre(body)
		if top == Vector3.INF:
			wrong.append("%s (no box shape)" % gym.get_path_to(body))
			continue
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(top + Vector3.UP, top + Vector3.DOWN * 2.0, PhysicsLayers.WORLD)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or hit["collider"] != body:
			wrong.append(str(gym.get_path_to(body)))
	check.call(wrong.is_empty(), "a ray from 1 m above every moving body hits that body first (wrong: %s)" % ", ".join(wrong))


func _all(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	_collect(root, found)
	return found


func _collect(node: Node, found: Array[Node]) -> void:
	found.append(node)
	for child: Node in node.get_children():
		_collect(child, found)
