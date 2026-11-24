class_name WallSurface
extends KitBlock
## Wall surface block (Phase 05.1, KIT-01, D-06, D-09): a panel the player can wall-run along (WALL_RUN) or kick off with a
## wall-jump (WALL_JUMP). The Panel body joins the group wall_run_surface or wall_jump_surface; the PlayerController and its
## WallRun / WallJump states do the rest with their MovementConfig values. Only surfaces count, a plain wall never starts either
## move. The block is always on (no signal source, D-13), never moves the player and never writes its velocity (04.1 D-06): it is an
## engine collision body plus a group tag. A look (plain brass inlay, steam columns) is an inherited scene that only adds meshes, so
## every look of one preset plays the same (D-06 parity).
##
## The block sizes the panel from its config in _ready: a per-instance BoxShape3D and plate mesh (never the scene's shared
## sub-resources, T-05.1-10) and the optional frame bars FrameTop / FrameBottom / FrameLeft / FrameRight. The panel stands on the
## block origin, centred along x, PANEL_THICKNESS deep along z, so its faces sit at z = +-PANEL_THICKNESS / 2.

## Layout rule for a wall-jump twin (research A3, test_wall_surface): at least this gap in m between the two facing panel faces, so a
## held kick reaches the far pad near the top of its arc instead of falling short and turning into a plain jump.
const TWIN_FACE_GAP_MIN: float = 6.0
## Layout rule for a wall-jump pad: at least this tall in m, so a held kick (rise about 2.6 m) from a reachable height is caught by
## the far pad instead of clearing it (the old 4 m pads flung the player over the far pad).
const JUMP_PAD_HEIGHT_MIN: float = 8.0
## Panel depth in m (z).
const PANEL_THICKNESS: float = 0.5
## Frame bar cross section in m (the bars stick out a little past both faces).
const FRAME_BAR: float = 0.2
const FRAME_DEPTH: float = 0.7

## The block's config; the instance works on its own copy (D-12).
@export var config: WallSurfaceConfig

@onready var _panel: StaticBody3D = $Panel


func _ready() -> void:
	if config == null:
		config = WallSurfaceConfig.new()
	config = own_config(config) as WallSurfaceConfig
	_panel.collision_layer = PhysicsLayers.WORLD
	_panel.collision_mask = 0
	_size_panel()
	_apply_group()


## The group the panel joins.
func surface_group() -> StringName:
	return &"wall_run_surface" if config.surface == WallSurfaceConfig.Surface.WALL_RUN else &"wall_jump_surface"


## The Panel body (the collider the player touches).
func panel() -> StaticBody3D:
	return _panel


func reset() -> void:
	super.reset()
	_apply_group()


func _apply_group() -> void:
	_panel.remove_from_group(&"wall_run_surface")
	_panel.remove_from_group(&"wall_jump_surface")
	_panel.add_to_group(surface_group())


func _size_panel() -> void:
	var height: float = config.height
	var width: float = config.width
	var centre: Vector3 = Vector3(0.0, height * 0.5, 0.0)
	var shape_node: CollisionShape3D = $Panel/CollisionShape3D as CollisionShape3D
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(width, height, PANEL_THICKNESS)
	shape_node.shape = box
	shape_node.position = centre
	var plate: MeshInstance3D = get_node_or_null(^"Panel/Plate") as MeshInstance3D
	if plate != null:
		plate.mesh = _box_mesh(Vector3(width, height, PANEL_THICKNESS))
		plate.position = centre
	_size_bar(^"FrameTop", Vector3(width + FRAME_BAR, FRAME_BAR, FRAME_DEPTH), Vector3(0.0, height, 0.0))
	_size_bar(^"FrameBottom", Vector3(width + FRAME_BAR, FRAME_BAR, FRAME_DEPTH), Vector3(0.0, FRAME_BAR * 0.5, 0.0))
	_size_bar(^"FrameLeft", Vector3(FRAME_BAR, height + FRAME_BAR, FRAME_DEPTH), Vector3(-width * 0.5, height * 0.5, 0.0))
	_size_bar(^"FrameRight", Vector3(FRAME_BAR, height + FRAME_BAR, FRAME_DEPTH), Vector3(width * 0.5, height * 0.5, 0.0))


func _size_bar(path: NodePath, size: Vector3, at: Vector3) -> void:
	var bar: MeshInstance3D = get_node_or_null(path) as MeshInstance3D
	if bar == null:
		return
	bar.mesh = _box_mesh(size)
	bar.position = at


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh
