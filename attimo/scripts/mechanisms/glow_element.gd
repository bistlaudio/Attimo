class_name GlowElement
extends MeshInstance3D
## Shared glow lens of every mechanism (D-07, HAND-07): a faceted core built from primitive meshes, framed by a brass bezel
## (a child MeshInstance3D named Bezel), one style per mechanic. This node is the part whose material_override the glow
## stages (Interactable) or the scene (glow_energy.tres) set; the bezel never is. Meshes are built once per style and
## cached, so every instance shares the same core Mesh and bezel Mesh. Primitives only: no imports, no custom shaders.

enum Style { DIAMOND, HUB, COG, CAGE, RING, GRATE, CHEVRON }

const BRASS: StandardMaterial3D = preload("res://resources/mechanisms/look_brass.tres")
const BEZEL_NAME: String = "Bezel"

@export var style: Style = Style.DIAMOND
## Uniform scale of the element (the unscaled element is about 0.3 m wide).
@export var size: float = 1.0

static var _cores: Dictionary = {}
static var _bezels: Dictionary = {}


func _ready() -> void:
	if has_node(BEZEL_NAME):
		return
	mesh = core_mesh(style)
	if not is_equal_approx(size, 1.0):
		scale *= size
	var bezel: MeshInstance3D = MeshInstance3D.new()
	bezel.name = BEZEL_NAME
	bezel.mesh = bezel_mesh(style)
	bezel.material_override = BRASS
	add_child(bezel)


## The shared faceted core Mesh of a style.
static func core_mesh(of_style: Style) -> ArrayMesh:
	if not _cores.has(of_style):
		_cores[of_style] = _faceted(_core_parts(of_style))
	return _cores[of_style]


## The shared bezel Mesh of a style.
static func bezel_mesh(of_style: Style) -> ArrayMesh:
	if not _bezels.has(of_style):
		_bezels[of_style] = _faceted(_bezel_parts(of_style))
	return _bezels[of_style]


static func _box(dimensions: Vector3) -> BoxMesh:
	var box: BoxMesh = BoxMesh.new()
	box.size = dimensions
	return box


static func _cylinder(radius: float, height: float, segments: int) -> CylinderMesh:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.rings = 1
	return cylinder


static func _torus(inner: float, outer: float, rings: int, ring_segments: int) -> TorusMesh:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = rings
	torus.ring_segments = ring_segments
	return torus


static func _at(position: Vector3, basis: Basis = Basis.IDENTITY) -> Transform3D:
	return Transform3D(basis, position)


## A box rotated 45 degrees on two axes: the gem.
static func _gem_basis() -> Basis:
	return Basis(Vector3.RIGHT, PI * 0.25) * Basis(Vector3.FORWARD, PI * 0.25)


static func _core_parts(of_style: Style) -> Array:
	match of_style:
		Style.DIAMOND:
			return [[_box(Vector3(0.14, 0.14, 0.14)), _at(Vector3.ZERO, _gem_basis())]]
		Style.HUB:
			return [[_cylinder(0.08, 0.1, 8), _at(Vector3.ZERO)]]
		Style.COG:
			return [[_cylinder(0.07, 0.1, 6), _at(Vector3.ZERO)]]
		Style.CAGE:
			return [[_box(Vector3(0.14, 0.14, 0.14)), _at(Vector3.ZERO, _gem_basis())]]
		Style.RING:
			return [[_torus(0.05, 0.09, 8, 6), _at(Vector3.ZERO)]]
		Style.GRATE:
			return [[_box(Vector3(0.24, 0.03, 0.16)), _at(Vector3.ZERO)]]
		Style.CHEVRON:
			return [[_prism_arrow(), _at(Vector3.ZERO, Basis(Vector3.RIGHT, -PI * 0.5))]]
	return []


static func _prism_arrow() -> PrismMesh:
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.2, 0.2, 0.04)
	return prism


static func _bezel_parts(of_style: Style) -> Array:
	var parts: Array = []
	match of_style:
		Style.DIAMOND:
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					parts.append([_box(Vector3(0.03, 0.26, 0.03)), _at(Vector3(sx * 0.12, 0.0, sz * 0.12))])
			parts.append([_box(Vector3(0.28, 0.03, 0.28)), _at(Vector3(0.0, -0.14, 0.0))])
			parts.append([_box(Vector3(0.28, 0.03, 0.28)), _at(Vector3(0.0, 0.14, 0.0))])
		Style.HUB:
			for index: int in 4:
				var spin: Basis = Basis(Vector3.UP, index * PI * 0.5)
				parts.append([_box(Vector3(0.12, 0.03, 0.03)), _at(spin * Vector3(0.11, 0.0, 0.0), spin)])
			parts.append([_cylinder(0.05, 0.12, 8), _at(Vector3.ZERO)])
		Style.COG:
			parts.append([_torus(0.09, 0.14, 8, 8), _at(Vector3.ZERO)])
			for index: int in 8:
				var spin: Basis = Basis(Vector3.UP, index * PI * 0.25)
				parts.append([_box(Vector3(0.05, 0.07, 0.04)), _at(spin * Vector3(0.165, 0.0, 0.0), spin)])
		Style.CAGE:
			parts.append([_box(Vector3(0.3, 0.025, 0.025)), _at(Vector3.ZERO)])
			parts.append([_box(Vector3(0.025, 0.3, 0.025)), _at(Vector3.ZERO)])
			parts.append([_box(Vector3(0.025, 0.025, 0.3)), _at(Vector3.ZERO)])
			parts.append([_cylinder(0.09, 0.03, 8), _at(Vector3(0.0, -0.15, 0.0))])
			parts.append([_cylinder(0.09, 0.03, 8), _at(Vector3(0.0, 0.15, 0.0))])
		Style.RING:
			parts.append([_torus(0.11, 0.14, 8, 8), _at(Vector3.ZERO)])
			for index: int in 3:
				var spin: Basis = Basis(Vector3.UP, index * TAU / 3.0)
				parts.append([_box(Vector3(0.05, 0.06, 0.04)), _at(spin * Vector3(0.17, 0.0, 0.0), spin)])
		Style.GRATE:
			parts.append([_box(Vector3(0.28, 0.03, 0.03)), _at(Vector3(0.0, 0.0, 0.1))])
			parts.append([_box(Vector3(0.28, 0.03, 0.03)), _at(Vector3(0.0, 0.0, -0.1))])
			parts.append([_box(Vector3(0.03, 0.03, 0.2)), _at(Vector3(0.13, 0.0, 0.0))])
			parts.append([_box(Vector3(0.03, 0.03, 0.2)), _at(Vector3(-0.13, 0.0, 0.0))])
			for index: int in 3:
				parts.append([_box(Vector3(0.02, 0.025, 0.2)), _at(Vector3((index - 1) * 0.07, 0.03, 0.0))])
		Style.CHEVRON:
			parts.append([_box(Vector3(0.28, 0.03, 0.03)), _at(Vector3(0.0, -0.025, 0.11))])
			parts.append([_box(Vector3(0.28, 0.03, 0.03)), _at(Vector3(0.0, -0.025, -0.11))])
			parts.append([_box(Vector3(0.03, 0.03, 0.25)), _at(Vector3(0.14, -0.025, 0.0))])
			parts.append([_box(Vector3(0.03, 0.03, 0.25)), _at(Vector3(-0.14, -0.025, 0.0))])
	return parts


## Combines [PrimitiveMesh, Transform3D] parts into one ArrayMesh with hard (per-face) normals.
static func _faceted(parts: Array) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	for part: Array in parts:
		var primitive: PrimitiveMesh = part[0]
		var placement: Transform3D = part[1]
		var arrays: Array = primitive.get_mesh_arrays()
		var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for corner: int in range(0, indices.size() - 2, 3):
			var a: Vector3 = placement * source[indices[corner]]
			var b: Vector3 = placement * source[indices[corner + 1]]
			var c: Vector3 = placement * source[indices[corner + 2]]
			var face: Vector3 = (c - a).cross(b - a)  # Godot primitives wind clockwise (WR-04)
			if face.length_squared() < 0.0000001:
				continue
			face = face.normalized()
			vertices.append_array([a, b, c])
			normals.append_array([face, face, face])
	var combined: Array = []
	combined.resize(Mesh.ARRAY_MAX)
	combined[Mesh.ARRAY_VERTEX] = vertices
	combined[Mesh.ARRAY_NORMAL] = normals
	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, combined)
	return result
