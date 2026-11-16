extends RefCounted
## MOVE-09 / D-01: ProceduralPose writes a lean (and later a spin) onto the Mannequin child of VisualRoot inside the
## physics tick (DEV-01). A ground dash leans the body toward the dash direction about the hip pivot, the lean eases
## out afterwards, and VisualRoot's yaw and the upright pose are never touched. Every expectation derives from
## player.config. Actions are released and the tick rate stays at 60 before nodes are freed.

const Fixtures := preload("res://tests/fixtures.gd")
const TPS: int = 60
const LEAN_TOLERANCE_DEG: float = 1.0
const PIVOT_TOLERANCE: float = 0.001
const LEAN_IN_TICKS: int = 6
const OUT_EXTRA_TICKS: int = 3
const UP_TILT_MIN: float = 0.2

var _floor: StaticBody3D


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = TPS
	await _scenario_rest_and_dash_lean(tree, check)


## Fresh floor (long toward -Z) and a player standing on it.
func _begin(tree: SceneTree, position: Vector3 = Vector3(0.0, 0.0, 70.0)) -> PlayerController:
	_floor = Fixtures.spawn_floor(tree.root, Vector3(60.0, 1.0, 160.0))
	var player: PlayerController = Fixtures.spawn_player(tree.root, position)
	await Fixtures.wait_physics(tree, 8)
	return player


## Releases every action and frees the scenario nodes.
func _end(player: PlayerController) -> void:
	for action: StringName in [&"move_forward", &"jump", &"dash", &"aim"]:
		Fixtures.send_action_event(action, false)
		Input.action_release(action)
	player.queue_free()
	_floor.queue_free()
	await player.tree_exited


func _pose(player: PlayerController) -> ProceduralPose:
	return player.get_node("ProceduralPose") as ProceduralPose


func _mannequin(player: PlayerController) -> Node3D:
	return player.get_node("VisualRoot/Mannequin") as Node3D


# D-01: at rest the Mannequin transform is identity; a ground dash leans it toward the dash direction on its first
# tick, about the hip pivot, without touching VisualRoot; the lean eases out after the dash.
func _scenario_rest_and_dash_lean(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	var pose: ProceduralPose = _pose(player)
	var mannequin: Node3D = _mannequin(player)
	check.call(pose != null and mannequin != null, "(p1) the ProceduralPose node and the Mannequin exist under the Player")
	if pose == null or mannequin == null:
		await _end(player)
		return
	check.call(mannequin.transform == Transform3D.IDENTITY, "(p1) at rest the Mannequin transform is exactly identity")
	check.call(is_zero_approx(player.visual_root.rotation.x) and is_zero_approx(player.visual_root.rotation.z), "(p1) VisualRoot is upright at rest")

	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - config.run_speed) < 0.05, 120)
	await Fixtures.tap_action(tree, &"dash")
	var in_dash: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 6)
	check.call(in_dash >= 0, "(p2) the dash press enters Dash (got %s)" % player.state_machine.current.name)
	check.call(pose.lean_angle > 0.0, "(p2) the lean is above 0 on the first tick of the dash (got %.2f deg)" % rad_to_deg(pose.lean_angle))
	var reached: int = await Fixtures.wait_until(tree, func() -> bool: return absf(rad_to_deg(pose.lean_angle) - config.dash_lean_deg) < LEAN_TOLERANCE_DEG, LEAN_IN_TICKS)
	check.call(reached >= 0, "(p2) the lean reaches dash_lean_deg %.1f within %d ticks (got %.2f deg)" % [config.dash_lean_deg, LEAN_IN_TICKS, rad_to_deg(pose.lean_angle)])

	var pivot: Vector3 = Vector3(0.0, config.pose_pivot_height, 0.0)
	var moved: Vector3 = mannequin.transform * pivot
	check.call(moved.distance_to(pivot) < PIVOT_TOLERANCE, "(p3) the pivot point maps to itself under the Mannequin transform (off by %.4f m)" % moved.distance_to(pivot))
	var tilt: Vector3 = player.visual_root.global_basis * (mannequin.transform.basis * Vector3.UP)
	var dash_direction: Vector3 = Vector3(0.0, 0.0, -1.0)
	check.call(tilt.dot(dash_direction) > UP_TILT_MIN, "(p3) the leaning body tilts its up vector toward the dash direction (dot %.2f)" % tilt.dot(dash_direction))
	var yaw_clean: bool = true
	for i: int in 8:
		await tree.physics_frame
		yaw_clean = yaw_clean and is_zero_approx(player.visual_root.rotation.x) and is_zero_approx(player.visual_root.rotation.z)
	check.call(yaw_clean, "(p3) VisualRoot rotation x and z stay 0 through the dash (DEV-01: the pose lives on the Mannequin)")

	var out_budget: int = int(ceil(config.lean_out_time * float(TPS))) + OUT_EXTRA_TICKS
	var ended: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name != &"Dash", 40)
	check.call(ended >= 0, "(p4) the dash ends (got %s)" % player.state_machine.current.name)
	var upright: int = await Fixtures.wait_until(tree, func() -> bool: return pose.lean_angle == 0.0, out_budget)
	check.call(upright >= 0, "(p4) the lean is 0 within lean_out_time plus %d ticks after the dash (got %.2f deg)" % [OUT_EXTRA_TICKS, rad_to_deg(pose.lean_angle)])
	check.call(mannequin.transform == Transform3D.IDENTITY, "(p4) the Mannequin transform is identity again once upright")
	await _end(player)
