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

var _floor: StaticBody3D
var _player: PlayerController
var _rig: CameraRig
var _animator: MannequinAnimator
var _modifier: AimPoseModifier


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	# The camera rig needs a tree that has finished starting up (it reads global transforms when it snaps).
	await Fixtures.wait_physics(tree, 2)
	await _scenario_idle(tree, check)


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
