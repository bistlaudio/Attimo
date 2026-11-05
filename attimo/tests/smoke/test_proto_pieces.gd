extends RefCounted
## Prototype Bits wrappers: solid World geometry with one box collision that matches the mesh.
## Static checks only (extents, grid, origin) plus a static downward ray query; nothing moves (D-09).

const WORLD_LAYER_MASK: int = 1
const TOLERANCE: float = 0.01
const RAY_HEIGHT: float = 10.0

## Wrapper scene path -> expected top-face height in metres.
const WRAPPERS: Dictionary = {
	"res://scenes/proto/primitive_floor.tscn": 1.0,
	"res://scenes/proto/primitive_wall.tscn": 4.0,
	"res://scenes/proto/primitive_cube_small.tscn": 2.0,
	"res://scenes/proto/primitive_pillar.tscn": 4.0,
	"res://scenes/proto/primitive_beam.tscn": 1.0,
}

const SLOPE_PATH: String = "res://scenes/proto/primitive_slope.tscn"
const SLOPE_ANGLE_TOLERANCE_DEG: float = 1.0


func run(tree: SceneTree, check: Callable) -> void:
	for path: String in WRAPPERS:
		var expected_top: float = WRAPPERS[path] as float
		await _check_wrapper(tree, check, path, expected_top)
	await _check_slope(tree, check)


func _check_wrapper(tree: SceneTree, check: Callable, path: String, expected_top: float) -> void:
	var label: String = path.get_file().get_basename()
	var scene: PackedScene = load(path) as PackedScene
	check.call(scene != null, "%s loads" % label)
	if scene == null:
		return
	var body: StaticBody3D = scene.instantiate() as StaticBody3D
	check.call(body != null, "%s root is a StaticBody3D" % label)
	if body == null:
		return
	check.call(body.collision_layer == WORLD_LAYER_MASK, "%s collision_layer is World (1), got %d" % [label, body.collision_layer])
	check.call(body.collision_mask == 0, "%s collision_mask is 0, got %d" % [label, body.collision_mask])

	var shapes: Array[CollisionShape3D] = []
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			shapes.append(child as CollisionShape3D)
	check.call(shapes.size() == 1, "%s has exactly one CollisionShape3D (got %d)" % [label, shapes.size()])
	if shapes.size() != 1:
		body.free()
		return
	var box: BoxShape3D = shapes[0].shape as BoxShape3D
	check.call(box != null, "%s collision shape is a BoxShape3D (no trimesh)" % label)
	if box == null:
		body.free()
		return

	# Transform-aware extents need the nodes in the tree, at the origin.
	tree.root.add_child(body)
	body.global_position = Vector3.ZERO

	var shape_aabb: AABB = AABB(shapes[0].position - box.size * 0.5, box.size)
	var mesh_aabb: AABB = _merged_mesh_aabb(body)
	check.call(mesh_aabb.size != Vector3.ZERO, "%s has visible mesh geometry" % label)
	check.call(_near(shape_aabb.position, mesh_aabb.position), "%s box min %s matches mesh min %s" % [label, shape_aabb.position, mesh_aabb.position])
	check.call(_near(shape_aabb.size, mesh_aabb.size), "%s box size %s matches mesh size %s" % [label, shape_aabb.size, mesh_aabb.size])
	check.call(absf(mesh_aabb.position.y) <= TOLERANCE, "%s origin is at the bottom (mesh min y = %.3f)" % [label, mesh_aabb.position.y])
	check.call(absf(mesh_aabb.position.x + mesh_aabb.size.x * 0.5) <= TOLERANCE and absf(mesh_aabb.position.z + mesh_aabb.size.z * 0.5) <= TOLERANCE,
		"%s origin is at the horizontal centre" % label)
	for axis: int in 3:
		var extent: float = mesh_aabb.size[axis]
		check.call(absf(extent - roundf(extent)) <= TOLERANCE, "%s extent on axis %d is a whole metre (%.3f)" % [label, axis, extent])

	# Static ray probe: the collision is live in the physics space.
	await tree.physics_frame
	await tree.physics_frame
	var space: PhysicsDirectSpaceState3D = tree.root.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(0.0, RAY_HEIGHT, 0.0), Vector3(0.0, -RAY_HEIGHT, 0.0), WORLD_LAYER_MASK)
	var hit: Dictionary = space.intersect_ray(query)
	check.call(not hit.is_empty(), "%s ray hits the body" % label)
	if not hit.is_empty():
		check.call(hit["collider"] == body, "%s ray hit is the wrapper itself" % label)
		var hit_y: float = (hit["position"] as Vector3).y
		check.call(absf(hit_y - expected_top) <= TOLERANCE, "%s top face at y=%.3f, expected %.3f" % [label, hit_y, expected_top])

	body.free()
	await tree.process_frame


## The 45 degree wedge rises toward -X: top y = 2 - x over x in [-2, 2]. One convex shape, no box, no trimesh.
func _check_slope(tree: SceneTree, check: Callable) -> void:
	var scene: PackedScene = load(SLOPE_PATH) as PackedScene
	check.call(scene != null, "primitive_slope loads")
	if scene == null:
		return
	var body: StaticBody3D = scene.instantiate() as StaticBody3D
	check.call(body != null, "primitive_slope root is a StaticBody3D")
	if body == null:
		return
	check.call(body.collision_layer == WORLD_LAYER_MASK, "primitive_slope collision_layer is World (1), got %d" % body.collision_layer)
	check.call(body.collision_mask == 0, "primitive_slope collision_mask is 0, got %d" % body.collision_mask)
	var shapes: Array[CollisionShape3D] = []
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			shapes.append(child as CollisionShape3D)
	check.call(shapes.size() == 1, "primitive_slope has exactly one CollisionShape3D (got %d)" % shapes.size())
	if shapes.size() != 1:
		body.free()
		return
	var convex: ConvexPolygonShape3D = shapes[0].shape as ConvexPolygonShape3D
	check.call(convex != null, "primitive_slope collision shape is a ConvexPolygonShape3D (no box, no trimesh)")
	if convex == null:
		body.free()
		return
	check.call(convex.points.size() == 6, "primitive_slope convex shape has 6 points (got %d)" % convex.points.size())

	tree.root.add_child(body)
	body.global_position = Vector3.ZERO
	await tree.physics_frame
	await tree.physics_frame
	var space: PhysicsDirectSpaceState3D = tree.root.get_world_3d().direct_space_state
	var expected: Dictionary = {0.0: 2.0, -1.0: 3.0}
	for x: float in expected:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(x, RAY_HEIGHT, 0.0), Vector3(x, -RAY_HEIGHT, 0.0), WORLD_LAYER_MASK)
		var hit: Dictionary = space.intersect_ray(query)
		check.call(not hit.is_empty(), "primitive_slope ray at x=%.1f hits the body" % x)
		if hit.is_empty():
			continue
		var hit_y: float = (hit["position"] as Vector3).y
		check.call(absf(hit_y - (expected[x] as float)) <= TOLERANCE, "primitive_slope surface at x=%.1f is y=%.3f, expected %.3f" % [x, hit_y, expected[x] as float])
		var angle_deg: float = rad_to_deg((hit["normal"] as Vector3).angle_to(Vector3.UP))
		check.call(absf(angle_deg - 45.0) <= SLOPE_ANGLE_TOLERANCE_DEG, "primitive_slope normal at x=%.1f is 45 degrees from up (got %.2f), walkable under floor_max_angle 50" % [x, angle_deg])

	body.free()
	await tree.process_frame


func _near(a: Vector3, b: Vector3) -> bool:
	return absf(a.x - b.x) <= TOLERANCE and absf(a.y - b.y) <= TOLERANCE and absf(a.z - b.z) <= TOLERANCE


func _merged_mesh_aabb(root: Node3D) -> AABB:
	var merged: AABB = AABB()
	var have_any: bool = false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi: MeshInstance3D = node as MeshInstance3D
			var world_aabb: AABB = mi.global_transform * mi.get_aabb()
			if have_any:
				merged = merged.merge(world_aabb)
			else:
				merged = world_aabb
				have_any = true
		stack.append_array(node.get_children())
	return merged
