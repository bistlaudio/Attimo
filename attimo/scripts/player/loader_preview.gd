class_name LoaderPreview
extends MultiMeshInstance3D
## The dashed trajectory preview of the Loader hold (HAND-04, D-14): where a release right now would carry Rino. It is the NO-INPUT
## ballistic arc (LoaderMath.trajectory, the same math as the discharge): air control after the release lock is not predicted
## (Pitfall 12). Two arcs: the base discharge (stored speed or loader_min_push, no bonus) in cream, and the bonus discharge in
## turquoise, shown only while the arm holds a full core. Every other segment is drawn, so the path reads as dashes. Presentation
## only: it reads the Loader state and never writes the player. The MultiMesh has a fixed instance count (MAX_POINTS) and only
## visible_instance_count changes per frame (T-05-04: bounded work), the paths stop at the first World hit.

## Points per arc and the instance count of the MultiMesh.
const MAX_POINTS: int = 60
## Seconds of flight between two points (60 points are 1.5 s of flight, Pitfall 12).
const STEP: float = 0.025
## Height above the body origin the arc starts at (about the chest).
const START_HEIGHT: float = 0.9
const BASE_COLOR: Color = Color(0.96, 0.93, 0.85, 1.0)
const BONUS_COLOR: Color = Color(0.25, 0.9, 0.85, 1.0)
const DASH_THICKNESS: float = 0.07

var _player: PlayerController


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(DASH_THICKNESS, DASH_THICKNESS, 1.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
	box.material = material
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = box
	multi.instance_count = MAX_POINTS
	multi.visible_instance_count = 0
	multimesh = multi
	visible = false
	_player = get_parent() as PlayerController


func _process(_delta: float) -> void:
	if _player == null or not _player.loader_active():
		visible = false
		multimesh.visible_instance_count = 0
		return
	var state: LoaderState = _player.loader_state()
	if state == null:
		return
	global_transform = Transform3D.IDENTITY
	var config: MovementConfig = _player.config
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = _player.global_position + Vector3.UP * START_HEIGHT
	var used: int = 0
	var base: PackedVector3Array = LoaderMath.trajectory(origin, state.preview_velocity_for(false), config, STEP, MAX_POINTS, space, PhysicsLayers.WORLD)
	used = _draw_dashes(base, BASE_COLOR, used)
	if state.bonus_ready():
		var bonus: PackedVector3Array = LoaderMath.trajectory(origin, state.preview_velocity_for(true), config, STEP, MAX_POINTS, space, PhysicsLayers.WORLD)
		used = _draw_dashes(bonus, BONUS_COLOR, used)
	multimesh.visible_instance_count = used
	visible = used > 0


## Writes one dash per even segment of `points` into the MultiMesh from index `first`; returns the next free index.
func _draw_dashes(points: PackedVector3Array, tint: Color, first: int) -> int:
	var index: int = first
	var segment: int = 0
	while segment < points.size() - 1 and index < MAX_POINTS:
		var from: Vector3 = points[segment]
		var to: Vector3 = points[segment + 1]
		var length: float = from.distance_to(to)
		if length > 0.001:
			var forward: Vector3 = (to - from) / length
			var side: Vector3 = Vector3.UP.cross(forward)
			if side.length_squared() < 0.0001:
				side = Vector3.RIGHT
			side = side.normalized()
			var up: Vector3 = forward.cross(side).normalized()
			var basis: Basis = Basis(side, up, forward * length)
			multimesh.set_instance_transform(index, Transform3D(basis, (from + to) * 0.5))
			multimesh.set_instance_color(index, tint)
			index += 1
		segment += 2
	return index
