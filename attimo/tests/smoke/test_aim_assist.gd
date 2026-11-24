extends RefCounted
## CAM-05 / D-03, D-06, D-14, D-19: the aim assist is always on (hip fire, no button held). It snaps a valid Interactable inside
## hand_assist_angle onto the crosshair, keeps it with hysteresis, never slows the mouse and never moves the camera.

const Fixtures := preload("res://tests/fixtures.gd")

const LEVER_SCENE: String = "res://scenes/mechanisms/lever.tscn"
const SHIPPED_TPS: int = 60
const SETTLE_TICKS: int = 6
## Where a lever spawns before it is moved onto the line: away from the player, whose capsule its base would push.
const PARK: Vector3 = Vector3(300.0, 0.0, 300.0)

var _nodes: Array[Node] = []
var _player: PlayerController
var _rig: CameraRig
var _hand: HandController


func run(tree: SceneTree, check: Callable) -> void:
	# The runner calls us from _initialize, before the root is inside the tree.
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_dummy_invalid(tree, check)
	await _scenario_snap(tree, check)
	await _scenario_hysteresis(tree, check)
	await _scenario_states(tree, check)
	await _scenario_no_slowdown(tree, check)


func _begin(tree: SceneTree) -> void:
	_nodes.clear()
	_nodes.append(Fixtures.spawn_floor(tree.root, Vector3(200.0, 1.0, 200.0)))
	_player = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	_nodes.append(_player)
	_rig = Fixtures.spawn_camera_rig(tree.root, _player)
	_nodes.append(_rig)
	_rig.pitch = 0.0
	_hand = _player.get_node("HandController") as HandController
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.wait_process(tree, 3)
	await Fixtures.wait_physics(tree, SETTLE_TICKS)
	await Fixtures.wait_process(tree, 3)


func _end(tree: SceneTree) -> void:
	Input.action_release(&"use_hand")
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
	await tree.process_frame


## The point on the crosshair line whose distance from the player origin is `distance`, turned by `yaw_deg` degrees
## about the camera position (so the angle to the crosshair is exactly that).
func _point(distance: float, yaw_deg: float = 0.0) -> Vector3:
	var camera: Camera3D = _rig.camera
	var forward: Vector3 = -camera.global_basis.z.normalized()
	var start: Vector3 = CameraRig.aim_ray_start(camera.global_position, forward, _rig.global_position)
	var best: Vector3 = start
	var best_error: float = INF
	var t: float = 0.0
	while t < 80.0:
		var point: Vector3 = start + forward * t
		var error: float = absf(point.distance_to(_player.global_position) - distance)
		if error < best_error:
			best_error = error
			best = point
		t += 0.02
	return camera.global_position + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * (best - camera.global_position)


## A lever whose hit body sits at `point` (the hit body is also its target point: the aim point is cleared).
func _lever_at(tree: SceneTree, point: Vector3) -> Lever:
	var lever: Lever = Fixtures.spawn_scene(tree.root, LEVER_SCENE, PARK) as Lever
	var interactable: Interactable = lever.get_node("Interactable") as Interactable
	interactable.aim_point = null
	lever.global_position = point - (interactable.hit_body.global_position - lever.global_position)
	_nodes.append(lever)
	return lever


func _interactable(lever: Lever) -> Interactable:
	return lever.get_node("Interactable") as Interactable


func _scenario_dummy_invalid(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	check.call(_hand != null and _hand.targeting != null, "(1) the HandController owns a Targeting child")
	if _hand == null or _hand.targeting == null:
		await _end(tree)
		return
	var lever: Lever = _lever_at(tree, _point(8.0))
	await Fixtures.wait_physics(tree, 3)
	check.call(_hand.equip(&"dummy"), "(1) the dummy module equips")
	await Fixtures.wait_physics(tree, 6)
	check.call(_hand.targeting.state == Targeting.State.INVALID, "(1) a lever the module does not accept reads INVALID (state %d)" % _hand.targeting.state)
	await Fixtures.tap_action(tree, &"use_hand", 2)
	await Fixtures.wait_physics(tree, 4)
	check.call(not lever.is_active, "(1) a tap with the dummy module leaves the lever unchanged")
	await _end(tree)


func _scenario_snap(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var lever: Lever = _lever_at(tree, _point(8.0))
	await Fixtures.wait_physics(tree, 6)
	check.call(_hand.targeting.target == _interactable(lever), "(2) the lever on the crosshair is the target")
	check.call(_hand.targeting.state == Targeting.State.VALID, "(2) a small-pulse lever in range is VALID (state %d)" % _hand.targeting.state)
	lever.global_position = _point(8.0, 3.0) - (_interactable(lever).hit_body.global_position - lever.global_position)
	await Fixtures.wait_physics(tree, 8)
	check.call(_hand.targeting.target == _interactable(lever), "(2) a lever 3 degrees off the crosshair is still selected (snap)")
	await Fixtures.tap_action(tree, &"use_hand", 2)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return lever.is_active, 60)
	check.call(waited >= 0, "(2) a tap hits the snapped lever although the crosshair misses its body (the shot bends in)")
	await Fixtures.wait_physics(tree, 30)
	lever.global_position = _point(8.0, 6.0) - (_interactable(lever).hit_body.global_position - lever.global_position)
	await Fixtures.wait_physics(tree, 20)
	check.call(_hand.targeting.target == null and _hand.targeting.state == Targeting.State.NONE, "(2) a lever 6 degrees off is not a target")
	await _end(tree)


func _scenario_hysteresis(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	_lever_at(tree, _point(12.0, 1.5))
	_lever_at(tree, _point(12.0, -2.5))
	await Fixtures.wait_physics(tree, 6)
	var changes: int = 0
	var previous: Interactable = _hand.targeting.target
	for i: int in 60:
		_rig.yaw += deg_to_rad(0.02)
		await Fixtures.wait_physics(tree, 1)
		var current: Interactable = _hand.targeting.target
		if current != null and previous != null and current != previous:
			changes += 1
		if current != null:
			previous = current
	check.call(previous != null, "(3) one of the two close levers is the target")
	check.call(changes <= 1, "(3) the target changes at most once during a slow sweep between two neighbours (changes %d)" % changes)
	await _end(tree)


func _scenario_states(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var big: Lever = _lever_at(tree, _point(8.0))
	_interactable(big).min_pulse = PulseHit.Size.BIG
	await Fixtures.wait_physics(tree, 6)
	check.call(_hand.targeting.state == Targeting.State.VALID_BIG, "(4) a lever that needs the big pulse reads VALID_BIG (state %d)" % _hand.targeting.state)
	big.queue_free()
	await Fixtures.wait_physics(tree, 12)

	var no_shot: Lever = _lever_at(tree, _point(8.0))
	_interactable(no_shot).accepts_shot = false
	await Fixtures.wait_physics(tree, 8)
	check.call(_hand.targeting.state == Targeting.State.INVALID, "(4) a lever that does not accept the shot reads INVALID (state %d, target %s)" % [_hand.targeting.state, str(_hand.targeting.target)])
	check.call(_hand.targeting.target == null, "(4) the cone never selects it as the target")
	no_shot.queue_free()
	await Fixtures.wait_physics(tree, 12)

	var far: Lever = _lever_at(tree, _point(18.0))
	await Fixtures.wait_physics(tree, 8)
	check.call(_hand.targeting.state == Targeting.State.VALID_BIG, "(4) a small-pulse lever at 18 m needs the big pulse (VALID_BIG, state %d)" % _hand.targeting.state)
	far.queue_free()
	await Fixtures.wait_physics(tree, 12)

	var out: Lever = _lever_at(tree, _point(30.0))
	await Fixtures.wait_physics(tree, 8)
	check.call(_hand.targeting.state == Targeting.State.INVALID, "(4) a lever at 30 m is out of range (INVALID, state %d)" % _hand.targeting.state)
	out.queue_free()
	await _end(tree)

# D-19: the mouse is never slowed (the sticky aim slowdown is gone): the same mouse motion turns the camera by the same
# angle with and without a held target, and the assist itself never rotates the camera.
func _scenario_no_slowdown(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var pixels: float = 40.0
	var yaw_before: float = _rig.yaw
	Fixtures.send_mouse_motion(Vector2(pixels, 0.0))
	var free_turn: float = yaw_before - _rig.yaw
	check.call(is_equal_approx(free_turn, pixels * _rig.base_sensitivity * _rig.settings.sensitivity), "(5) free look turns by pixels * base_sensitivity (%.4f)" % free_turn)
	var lever: Lever = _lever_at(tree, _point(8.0))
	await Fixtures.wait_physics(tree, 18)
	check.call(_hand.targeting.target == _interactable(lever), "(5) a valid target is held with no button pressed")
	await Fixtures.wait_physics(tree, 12)
	yaw_before = _rig.yaw
	var pitch_before: float = _rig.pitch
	await Fixtures.wait_physics(tree, 12)
	check.call(is_equal_approx(_rig.yaw, yaw_before) and is_equal_approx(_rig.pitch, pitch_before), "(5) the assist leaves yaw and pitch untouched")
	Fixtures.send_mouse_motion(Vector2(pixels, 0.0))
	var held_turn: float = yaw_before - _rig.yaw
	check.call(is_equal_approx(held_turn, free_turn), "(5) the same motion turns the same with a held target, there is no sticky slowdown (%.4f vs %.4f)" % [held_turn, free_turn])
	await _end(tree)
