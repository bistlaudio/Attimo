class_name AimPoseModifier
extends SkeletonModifier3D
## Arm-direction solver for aim mode (D-11, CAM-02): after the AnimationMixer has posed the skeleton, rotates the
## spine, the chest and (for any remainder) the right upper arm so the shoulder-to-hand direction points at the aim
## point. The aim point is set from outside (MannequinAnimator: camera origin + camera forward * converge_distance,
## which accounts for the shoulder-to-crosshair parallax; Phase 4 can replace it with a ray hit through
## set_aim_point). The Skeleton3D blends the result by `influence`, which the animator sets to the aim weight, so the
## correction fades in and out with the aim layer and the clip pose is untouched at influence 0.
##
## The torso (spine share first, chest second, together at most max_twist_deg) takes the correction; whatever is left
## goes to the upper arm, so the arm still reaches the target when the clip needs more than the torso may twist (the
## aim strafe right case, research Pitfall 3). Reading bone poses from outside returns the unmodified animation pose
## (research Pitfall 11), so the solver records its own results: last_error_deg, last_twist_deg, last_target_dir.

const BONE_SPINE: StringName = &"spine"
const BONE_CHEST: StringName = &"chest"
const BONE_UPPER_ARM: StringName = &"upperarm.r"
const BONE_HAND: StringName = &"hand.r"
## Below this arm-to-target distance (m) the frame is skipped (no stable direction).
const MIN_TARGET_LENGTH: float = 0.001
## Dot product below which two directions count as exactly opposite for rotation_between().
const OPPOSITE_DOT: float = -0.9999

## Share of the torso rotation the spine takes; the chest takes the rest of the budget.
@export_range(0.0, 1.0, 0.05) var spine_share: float = 0.4
## Most the spine and chest together may rotate toward the target, in degrees. The upper arm takes any remainder.
@export_range(0.0, 120.0, 1.0) var max_twist_deg: float = 70.0
## Distance in front of the camera of the aim point the animator feeds, in metres.
@export_range(1.0, 100.0, 0.5) var converge_distance: float = 15.0

## Angle between the solved arm and the target direction after the last solve, in degrees (read-only for others).
var last_error_deg: float = 0.0
## Torso rotation (spine plus chest) applied in the last solve, in degrees.
var last_twist_deg: float = 0.0
## The last target direction (shoulder to aim point) in skeleton space, normalized.
var last_target_dir: Vector3 = Vector3(0.0, 0.0, 1.0)

var _aim_point: Vector3 = Vector3.ZERO
var _has_aim_point: bool = false


## Sets the world-space point the right arm points at.
func set_aim_point(world: Vector3) -> void:
	if not world.is_finite():
		return
	_aim_point = world
	_has_aim_point = true


## The shortest rotation taking direction `from` onto direction `to`. Exactly opposite inputs have no unique
## shortest rotation (Quaternion(from, to) is undefined there), so they rotate PI about an axis perpendicular to
## `from`. A zero-length input gives the identity.
static func rotation_between(from: Vector3, to: Vector3) -> Quaternion:
	var a: Vector3 = from.normalized()
	var b: Vector3 = to.normalized()
	if a.length_squared() < 0.5 or b.length_squared() < 0.5:
		return Quaternion.IDENTITY
	if a.dot(b) < OPPOSITE_DOT:
		var axis: Vector3 = a.cross(Vector3.UP)
		if axis.length_squared() < 0.000001:
			axis = a.cross(Vector3.RIGHT)
		return Quaternion(axis.normalized(), PI)
	return Quaternion(a, b)


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null or not _has_aim_point:
		return
	var spine: int = skeleton.find_bone(BONE_SPINE)
	var chest: int = skeleton.find_bone(BONE_CHEST)
	var upper_arm: int = skeleton.find_bone(BONE_UPPER_ARM)
	var hand: int = skeleton.find_bone(BONE_HAND)
	if spine < 0 or chest < 0 or upper_arm < 0 or hand < 0:
		return
	var point: Vector3 = skeleton.global_transform.affine_inverse() * _aim_point
	var want: Vector3 = _want(skeleton, upper_arm, point)
	if want == Vector3.ZERO:
		return
	last_target_dir = want

	# Torso: the spine takes its share of the budgeted rotation, then the chest takes the rest toward the target.
	var needed: Quaternion = rotation_between(_arm(skeleton, upper_arm, hand), want)
	var budget: float = minf(needed.get_angle(), deg_to_rad(max_twist_deg))
	var spine_rot: Quaternion = _toward(needed, budget * spine_share)
	_rotate(skeleton, spine, spine_rot)
	want = _want(skeleton, upper_arm, point)
	if want == Vector3.ZERO:
		return
	var chest_budget: float = maxf(budget - spine_rot.get_angle(), 0.0)
	var chest_rot: Quaternion = _toward(rotation_between(_arm(skeleton, upper_arm, hand), want), chest_budget)
	_rotate(skeleton, chest, chest_rot)
	last_twist_deg = rad_to_deg(spine_rot.get_angle() + chest_rot.get_angle())

	want = _want(skeleton, upper_arm, point)
	if want == Vector3.ZERO:
		return
	last_error_deg = rad_to_deg(_arm(skeleton, upper_arm, hand).angle_to(want))


## Skeleton-space direction from the right shoulder to `point`, or ZERO when too close to give a direction.
func _want(skeleton: Skeleton3D, upper_arm: int, point: Vector3) -> Vector3:
	var offset: Vector3 = point - skeleton.get_bone_global_pose(upper_arm).origin
	if not offset.is_finite() or offset.length() < MIN_TARGET_LENGTH:
		return Vector3.ZERO
	return offset.normalized()


## Skeleton-space direction from the right shoulder to the right hand.
func _arm(skeleton: Skeleton3D, upper_arm: int, hand: int) -> Vector3:
	return (skeleton.get_bone_global_pose(hand).origin - skeleton.get_bone_global_pose(upper_arm).origin).normalized()


## `turn` shortened (about the same axis) to at most `max_angle` radians.
static func _toward(turn: Quaternion, max_angle: float) -> Quaternion:
	var angle: float = turn.get_angle()
	if angle <= max_angle or angle < 0.000001:
		return turn
	return Quaternion.IDENTITY.slerp(turn, max_angle / angle)


## Applies a skeleton-space rotation to a bone: parent_basis.inverse() * (R * parent_basis * local). A non-finite
## input or result is never written.
func _rotate(skeleton: Skeleton3D, bone: int, turn: Quaternion) -> void:
	if not turn.is_finite():
		return
	var parent: int = skeleton.get_bone_parent(bone)
	var parent_rot: Quaternion = Quaternion.IDENTITY
	if parent >= 0:
		parent_rot = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var local: Quaternion = skeleton.get_bone_pose_rotation(bone)
	var result: Quaternion = (parent_rot.inverse() * turn * parent_rot * local).normalized()
	if not result.is_finite():
		return
	skeleton.set_bone_pose_rotation(bone, result)
