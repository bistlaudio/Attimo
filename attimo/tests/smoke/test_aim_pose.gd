extends RefCounted
## CAM-02 (D-11): the AimPoseModifier points the right arm at the camera convergence point. The modifier's own
## records (last_error_deg, last_twist_deg, last_target_dir) are asserted, because reading bone poses from outside
## returns the unmodified animation pose (research Pitfall 11).

const Fixtures := preload("res://tests/fixtures.gd")
const SHIPPED_TPS: int = 60
const MODIFIER_PATH: String = "VisualRoot/Mannequin/Rig_Medium/Skeleton3D/AimPoseModifier"
const AIM_BLEND_FRAMES: int = 60
const SETTLE_FRAMES: int = 30
const SOLVE_FRAMES: int = 10
const ERROR_LIMIT_DEG: float = 1.0
const HOLD_FRAMES: int = 45
const TWIST_SLACK_DEG: float = 0.01
const CLAMP_TOLERANCE_DEG: float = 0.5
const OPPOSITE_TOLERANCE_DEG: float = 0.1
## Locomotion cases: input action, label. The empty action is idle.
const LOCOMOTION_CASES: Array[Array] = [
	[&"", "idle"],
	[&"move_forward", "running forward"],
	[&"move_left", "strafing left"],
	[&"move_right", "strafing right"],
	[&"move_back", "walking backwards"],
]

var _floor: StaticBody3D
var _player: PlayerController
var _rig: CameraRig
var _animator: MannequinAnimator
var _modifier: AimPoseModifier


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	# The camera rig needs a tree that has finished starting up (it reads global transforms when it snaps).
	await Fixtures.wait_physics(tree, 2)
	_scenario_rotation_between(check)
	await _scenario_idle(tree, check)
	for entry: Array in LOCOMOTION_CASES:
		await _scenario_locomotion(tree, check, entry[0] as StringName, entry[1] as String)
	await _scenario_pitch(tree, check, true)
	await _scenario_pitch(tree, check, false)
	await _scenario_twist_zero(tree, check)
	await _scenario_behind(tree, check)


# T-03-12: opposite directions give a finite rotation that still maps the first onto the second.
func _scenario_rotation_between(check: Callable) -> void:
	var pairs: Array[Array] = [
		[Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0), "+Z to -Z"],
		[Vector3.UP, Vector3.DOWN, "UP to DOWN"],
		[Vector3.RIGHT, Vector3.LEFT, "RIGHT to LEFT"],
		[Vector3(0.3, -0.5, 0.8), Vector3(-0.3, 0.5, -0.8), "a skew pair"],
	]
	for pair: Array in pairs:
		var from: Vector3 = pair[0] as Vector3
		var to: Vector3 = pair[1] as Vector3
		var turn: Quaternion = AimPoseModifier.rotation_between(from, to)
		var error_deg: float = rad_to_deg((turn * from.normalized()).angle_to(to.normalized()))
		check.call(turn.is_finite() and error_deg < OPPOSITE_TOLERANCE_DEG, "(r1) rotation_between %s is finite and lands %.4f deg from the target" % [pair[2], error_deg])
	var same: Quaternion = AimPoseModifier.rotation_between(Vector3.FORWARD, Vector3.FORWARD)
	check.call(same.is_finite() and absf(same.get_angle()) < 0.001, "(r2) equal directions give the identity")
	var zero: Quaternion = AimPoseModifier.rotation_between(Vector3.ZERO, Vector3.UP)
	check.call(zero.is_finite() and absf(zero.get_angle()) < 0.001, "(r3) a zero-length input gives the identity, not NaN")


# Tracer: aim weight -> modifier influence, camera aim point -> arm error, release -> influence back to 0.
func _scenario_idle(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	check.call(_modifier != null, "(a1) the Mannequin skeleton has an AimPoseModifier")
	if _modifier == null:
		await _end(tree)
		return
	check.call(is_zero_approx(_modifier.influence), "(a2) the influence is 0 before aiming (got %.3f)" % _modifier.influence)
	Input.action_press(&"aim")
	var blended: int = await Fixtures.wait_until(tree, func() -> bool: return is_equal_approx(_animator.aim_weight, 1.0), AIM_BLEND_FRAMES)
	check.call(blended >= 0, "(a3) holding aim brings the aim weight to 1.0 (took %d frames)" % blended)
	await Fixtures.wait_physics(tree, SOLVE_FRAMES)
	check.call(is_equal_approx(_modifier.influence, 1.0), "(a4) the influence follows the aim weight (got %.3f)" % _modifier.influence)
	check.call(_modifier.last_target_dir.is_finite() and is_equal_approx(_modifier.last_target_dir.length(), 1.0), "(a5) last_target_dir is finite and normalized (got %s)" % _modifier.last_target_dir)
	check.call(_modifier.last_error_deg < ERROR_LIMIT_DEG, "(a6) idle aim: the arm is %.3f deg from the target (limit %.1f)" % [_modifier.last_error_deg, ERROR_LIMIT_DEG])
	Input.action_release(&"aim")
	var released: int = await Fixtures.wait_until(tree, func() -> bool: return is_zero_approx(_modifier.influence), AIM_BLEND_FRAMES)
	check.call(released >= 0, "(a7) releasing aim brings the influence back to 0 (took %d frames)" % released)
	await _end(tree)


# Aim while idle or moving: the arm reaches the target and the torso stays inside the budget (strafe right needs the
# upper arm: the clamp is active and the error is still small).
func _scenario_locomotion(tree: SceneTree, check: Callable, action: StringName, label: String) -> void:
	await _begin(tree)
	Input.action_press(&"aim")
	if action != &"":
		Input.action_press(action)
	await Fixtures.wait_physics(tree, HOLD_FRAMES)
	_check_solved(check, "(l) %s" % label)
	check.call(_modifier.last_twist_deg <= _modifier.max_twist_deg + TWIST_SLACK_DEG, "(l) %s: the torso twist %.2f deg stays within max_twist_deg %.0f" % [label, _modifier.last_twist_deg, _modifier.max_twist_deg])
	if action == &"move_right":
		check.call(absf(_modifier.last_twist_deg - _modifier.max_twist_deg) < CLAMP_TOLERANCE_DEG, "(l) %s: the clamp is active (twist %.2f deg of %.0f)" % [label, _modifier.last_twist_deg, _modifier.max_twist_deg])
	await _end(tree)


# The camera pitch limits: the aim point is far above or below the horizon.
func _scenario_pitch(tree: SceneTree, check: Callable, lowest: bool) -> void:
	await _begin(tree)
	var label: String = "pitch_min" if lowest else "pitch_max"
	_rig.pitch = _rig.pitch_min if lowest else _rig.pitch_max
	Input.action_press(&"aim")
	await Fixtures.wait_physics(tree, HOLD_FRAMES)
	check.call(is_equal_approx(_rig.pitch, _rig.pitch_min if lowest else _rig.pitch_max), "(p) the rig sits at %s (got %.2f)" % [label, _rig.pitch])
	_check_solved(check, "(p) idle aim at %s" % label)
	await _end(tree)


# With the torso budget at 0 the upper arm does all the work.
func _scenario_twist_zero(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	_modifier.max_twist_deg = 0.0
	Input.action_press(&"aim")
	await Fixtures.wait_physics(tree, HOLD_FRAMES)
	_check_solved(check, "(z) max_twist_deg 0")
	check.call(is_zero_approx(_modifier.last_twist_deg), "(z) the torso twist is 0 (got %.4f)" % _modifier.last_twist_deg)
	await _end(tree)


# An aim point behind the character (an arm that needs far more than the torso budget): finite, solved by the upper arm.
func _scenario_behind(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	Input.action_press(&"aim")
	await Fixtures.wait_until(tree, func() -> bool: return is_equal_approx(_animator.aim_weight, 1.0), AIM_BLEND_FRAMES)
	await Fixtures.wait_physics(tree, SOLVE_FRAMES)
	var camera: Camera3D = _player.get_viewport().get_camera_3d()
	_animator.set_process(false)
	_modifier.set_aim_point(camera.global_position + camera.global_basis.z * _modifier.converge_distance)
	await Fixtures.wait_physics(tree, SOLVE_FRAMES)
	_check_solved(check, "(b) aim point behind the character")
	check.call(_modifier.last_twist_deg <= _modifier.max_twist_deg + TWIST_SLACK_DEG, "(b) the torso twist %.2f deg stays within the budget" % _modifier.last_twist_deg)
	_modifier.set_aim_point(Vector3(NAN, 0.0, 0.0))
	await Fixtures.wait_physics(tree, SOLVE_FRAMES)
	check.call(_modifier.last_target_dir.is_finite() and _modifier.last_error_deg < ERROR_LIMIT_DEG, "(b) a non-finite aim point is ignored (target %s)" % _modifier.last_target_dir)
	_animator.set_process(true)
	await _end(tree)


## The shared asserts: full influence, finite normalized target, arm error under the limit.
func _check_solved(check: Callable, label: String) -> void:
	check.call(is_equal_approx(_modifier.influence, 1.0), "%s: the influence is 1.0 (got %.3f)" % [label, _modifier.influence])
	check.call(_modifier.last_target_dir.is_finite() and is_equal_approx(_modifier.last_target_dir.length(), 1.0), "%s: the target direction is finite and normalized" % label)
	check.call(is_finite(_modifier.last_error_deg) and _modifier.last_error_deg < ERROR_LIMIT_DEG, "%s: the arm is %.3f deg from the target (limit %.1f), twist %.1f deg" % [label, _modifier.last_error_deg, ERROR_LIMIT_DEG, _modifier.last_twist_deg])


## Spawns floor, player and a camera rig (aim needs a camera frame) and waits until the scene has settled.
func _begin(tree: SceneTree) -> void:
	_floor = Fixtures.spawn_floor(tree.root)
	_player = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	_rig = Fixtures.spawn_camera_rig(tree.root, _player)
	await Fixtures.wait_physics(tree, SETTLE_FRAMES)
	_animator = _player.get_node("MannequinAnimator") as MannequinAnimator
	_modifier = _player.get_node_or_null(MODIFIER_PATH) as AimPoseModifier


## Releases every action and frees the scenario's nodes.
func _end(tree: SceneTree) -> void:
	for action: StringName in [&"aim", &"jump", &"dash", &"move_forward", &"move_left", &"move_right", &"move_back"]:
		Input.action_release(action)
		Fixtures.send_action_event(action, false)
	_rig.queue_free()
	_player.queue_free()
	_floor.queue_free()
	await _player.tree_exited
	await Fixtures.wait_physics(tree, 1)
