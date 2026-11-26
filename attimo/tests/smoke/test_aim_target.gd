extends RefCounted
## CAM-02 crosshair aim (quick 261118-qbt): the aim target is the world point under the screen-centre crosshair.
## CameraRig.aim_target_point() / aim_direction_from() are the accessors the arm solver and the Phase 4 beam read;
## MannequinAnimator feeds the AimPoseModifier from them. Pure ray start (t1), the open-space fallback (t2), a World hit
## on the camera centre ray (t3), the direction accessor (t4) and the full wiring with parallax (t5).
## Actions are released and the nodes freed at the end of each scenario.

const Fixtures := preload("res://tests/fixtures.gd")
const SHIPPED_TPS: int = 60
const MODIFIER_PATH: String = "VisualRoot/Mannequin/Rig_Medium/Skeleton3D/AimPoseModifier"
const SKELETON_PATH: String = "VisualRoot/Mannequin/Rig_Medium/Skeleton3D"
const POINT_TOLERANCE: float = 0.001
const FACE_TOLERANCE: float = 0.05
const ERROR_LIMIT_DEG: float = 1.0
const PARALLAX_MIN_DEG: float = 1.0
const SETTLE_FRAMES: int = 6
## Shorter than the Loader hold cap (72 ticks), so the arm is still out when the solver is read.
const AIM_FRAMES: int = 40

## Records the camera position and aim point in _process at the default priority (like the animator that feeds the arm).
class EarlyReader extends Node:
	var rig: CameraRig
	var camera_position: Vector3 = Vector3.ZERO
	var aim_point: Vector3 = Vector3.ZERO

	func _process(_delta: float) -> void:
		camera_position = rig.camera.global_position
		aim_point = rig.aim_target_point()


## Same reads after everything else (priority 200): what the rig finally produced this frame.
class LateReader extends EarlyReader:
	func _init() -> void:
		process_priority = 200


var _floor: StaticBody3D
var _player: PlayerController
var _rig: CameraRig


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await Fixtures.wait_physics(tree, 2)
	_scenario_ray_start(check)
	await _scenario_open_space(tree, check)
	await _scenario_world_hit(tree, check)
	await _scenario_direction(tree, check)
	await _scenario_wiring(tree, check)
	await _scenario_frame_order(tree, check)
	await _scenario_pole(tree, check)


func _begin(tree: SceneTree) -> void:
	_floor = Fixtures.spawn_floor(tree.root, Vector3(60.0, 1.0, 60.0))
	_player = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	_rig = Fixtures.spawn_camera_rig(tree.root, _player)
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.wait_process(tree, 2)


func _end(tree: SceneTree, extra: Array[Node] = []) -> void:
	Input.action_release(&"loader")
	Fixtures.send_action_event(&"loader", false)
	Fixtures.restore_time()
	for node: Node in [_player, _rig, _floor] + extra:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame


# (t1) the ray starts level with the character and never behind the lens.
func _scenario_ray_start(check: Callable) -> void:
	var origin: Vector3 = Vector3(1.0, 2.0, 3.0)
	var forward: Vector3 = Vector3(0.0, 0.0, -1.0)
	var ahead: Vector3 = CameraRig.aim_ray_start(origin, forward, origin + forward * 3.0)
	check.call(ahead.distance_to(origin + forward * 3.0) < POINT_TOLERANCE, "(t1) a pivot 3 m ahead on the ray starts the ray there (got %s)" % ahead)
	var behind: Vector3 = CameraRig.aim_ray_start(origin, forward, origin - forward * 2.0)
	check.call(behind.distance_to(origin) < POINT_TOLERANCE, "(t1) a pivot behind the lens starts the ray at the lens (got %s)" % behind)
	var off_ray: Vector3 = CameraRig.aim_ray_start(origin, forward, origin + forward * 4.0 + Vector3(2.0, 1.0, 0.0))
	check.call(off_ray.distance_to(origin + forward * 4.0) < POINT_TOLERANCE, "(t1) a pivot off the ray starts at its projection (got %s)" % off_ray)


# (t2) nothing in the way: the target is the ray end and no hit is reported.
func _scenario_open_space(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	_rig.pitch = _rig.pitch_max
	await Fixtures.wait_process(tree, SETTLE_FRAMES)
	var point: Vector3 = _rig.aim_target_point()
	var expected: Vector3 = _rig.camera.global_position - _rig.camera.global_basis.z.normalized() * _rig.crosshair_ray_length
	check.call(point.distance_to(expected) < POINT_TOLERANCE, "(t2) open space: the target is camera + forward * crosshair_ray_length (off by %.4f m)" % point.distance_to(expected))
	check.call(not _rig.last_aim_hit and _rig.last_aim_collider == null, "(t2) open space: last_aim_hit is false and there is no collider")
	await _end(tree)


# (t3) a World box 8 m in front of the lens: the target lies on its near face and on the camera centre ray.
func _scenario_world_hit(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	_rig.pitch = 0.0
	await Fixtures.wait_process(tree, SETTLE_FRAMES)
	var camera_position: Vector3 = _rig.camera.global_position
	var forward: Vector3 = -_rig.camera.global_basis.z.normalized()
	var box: StaticBody3D = Fixtures.spawn_box(_floor.get_parent(), Vector3(10.0, 10.0, 2.0), camera_position + forward * 9.0)
	await Fixtures.wait_physics(tree, 2)
	var point: Vector3 = _rig.aim_target_point()
	var face_distance: float = absf((point - (camera_position + forward * 8.0)).dot(forward))
	var line_distance: float = (point - camera_position).cross(forward).length()
	check.call(face_distance < FACE_TOLERANCE, "(t3) the target lies on the near face of the box (%.4f m off)" % face_distance)
	check.call(line_distance < POINT_TOLERANCE, "(t3) the target lies on the camera centre ray (%.5f m off the line)" % line_distance)
	check.call(_rig.last_aim_hit and _rig.last_aim_collider == box, "(t3) last_aim_hit is true and the collider is the box")
	await _end(tree, [box])


# (t4) aim_direction_from is a unit vector from the origin to the target point.
func _scenario_direction(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	await Fixtures.wait_process(tree, SETTLE_FRAMES)
	var origin: Vector3 = _player.global_position + Vector3(0.3, 1.2, 0.0)
	var direction: Vector3 = _rig.aim_direction_from(origin)
	var expected: Vector3 = (_rig.aim_target_point() - origin).normalized()
	check.call(absf(direction.length() - 1.0) < POINT_TOLERANCE, "(t4) the direction is unit length (%.5f)" % direction.length())
	check.call(direction.distance_to(expected) < POINT_TOLERANCE, "(t4) the direction points from the origin to the target point (off by %.5f)" % direction.distance_to(expected))
	var at_target: Vector3 = _rig.aim_direction_from(_rig.aim_target_point())
	check.call(at_target.is_finite() and absf(at_target.length() - 1.0) < POINT_TOLERANCE, "(t4) at the target itself the direction is still a finite unit vector")
	await _end(tree)


# (t5) with the arm out for the Loader hold the solver receives the crosshair target point (HandController.arm_out_point), so
# the arm direction (shoulder to point) differs from the camera forward by the parallax and the solver still reaches it.
func _scenario_wiring(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var wall: StaticBody3D = Fixtures.spawn_box(_floor.get_parent(), Vector3(20.0, 10.0, 1.0), Vector3(0.0, 5.0, -4.0))
	await Fixtures.wait_physics(tree, 2)
	var modifier: AimPoseModifier = _player.get_node(MODIFIER_PATH) as AimPoseModifier
	check.call(modifier != null, "(t5) the AimPoseModifier exists under the Mannequin skeleton")
	if modifier == null:
		await _end(tree, [wall])
		return
	Input.action_press(&"loader")
	await Fixtures.wait_physics(tree, AIM_FRAMES)
	await Fixtures.wait_process(tree, SETTLE_FRAMES)
	var target: Vector3 = _rig.aim_target_point()
	check.call(_rig.last_aim_hit and _rig.last_aim_collider == wall, "(t5) the crosshair ray hits the wall")
	check.call(modifier.aim_point().distance_to(target) < POINT_TOLERANCE, "(t5) the solver received the crosshair target point (off by %.5f m)" % modifier.aim_point().distance_to(target))
	check.call(modifier.last_error_deg < ERROR_LIMIT_DEG, "(t5) the arm reaches the target within %.1f degrees (error %.3f)" % [ERROR_LIMIT_DEG, modifier.last_error_deg])
	var skeleton: Skeleton3D = _player.get_node(SKELETON_PATH) as Skeleton3D
	var shoulder: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("upperarm.r"))).origin
	var arm_direction: Vector3 = (target - shoulder).normalized()
	var camera_forward: Vector3 = -_rig.camera.global_basis.z.normalized()
	var parallax: float = rad_to_deg(arm_direction.angle_to(camera_forward))
	check.call(parallax > PARALLAX_MIN_DEG, "(t5) the shoulder-to-point direction differs from the camera forward by %.2f degrees (> %.0f)" % [parallax, PARALLAX_MIN_DEG])
	await _end(tree, [wall])


# (t6, WR-01) the rig updates before the Player and every default-priority reader: a node placed BEFORE the rig in the tree
# sees the same camera position and aim point as a reader that runs after everything, even while the view is turning.
func _scenario_frame_order(tree: SceneTree, check: Callable) -> void:
	_floor = Fixtures.spawn_floor(tree.root, Vector3(60.0, 1.0, 60.0))
	_player = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	var early: EarlyReader = EarlyReader.new()
	tree.root.add_child(early)
	_rig = Fixtures.spawn_camera_rig(tree.root, _player)
	early.rig = _rig
	var late: LateReader = LateReader.new()
	late.rig = _rig
	tree.root.add_child(late)
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.wait_process(tree, 2)
	check.call(_rig.process_priority < _player.process_priority, "(t6) the rig runs before the Player (priority %d vs %d)" % [_rig.process_priority, _player.process_priority])
	var worst_camera: float = 0.0
	var worst_point: float = 0.0
	for i: int in SETTLE_FRAMES:
		_rig.yaw += 0.2
		_rig.pitch = clampf(_rig.pitch + 0.05, _rig.pitch_min, _rig.pitch_max)
		await Fixtures.wait_process(tree, 1)
		worst_camera = maxf(worst_camera, early.camera_position.distance_to(late.camera_position))
		worst_point = maxf(worst_point, early.aim_point.distance_to(late.aim_point))
	check.call(worst_camera < POINT_TOLERANCE, "(t6) a reader ahead of the rig in tree order sees the current camera position (off by %.5f m)" % worst_camera)
	check.call(worst_point < POINT_TOLERANCE, "(t6) a reader ahead of the rig in tree order sees the current aim point (off by %.5f m)" % worst_point)
	await _end(tree, [early, late])


# (t7) D-52: at the 89 degree limit the aim target and the Loader direction stay finite and within 1 degree of straight up.
func _scenario_pole(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	_rig.pitch = _rig.pitch_max
	await Fixtures.wait_process(tree, SETTLE_FRAMES)
	var point: Vector3 = _rig.aim_target_point()
	check.call(point.is_finite(), "(t7) the aim target is finite at the pitch limit (%s)" % point)
	var direction: Vector3 = _player.loader_direction()
	check.call(direction.is_finite() and direction.length() > 0.99, "(t7) the Loader direction is finite at the pitch limit (%s)" % direction)
	var angle: float = rad_to_deg(direction.angle_to(Vector3.UP))
	check.call(angle < 1.0 + 0.0001 + 0.0, "(t7) the Loader direction is within 1 degree of straight up (%.2f deg)" % angle)
	var aim_angle: float = rad_to_deg((point - _rig.camera.global_position).angle_to(Vector3.UP))
	check.call(aim_angle < 1.0 + 0.0001 + 0.0 or point.distance_to(_rig.camera.global_position) < 0.001, "(t7) the aim target lies within 1 degree of straight up (%.2f deg)" % aim_angle)
	await _end(tree)
