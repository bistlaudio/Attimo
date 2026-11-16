extends RefCounted
## MOVE-09 / D-01 / D-04 / D-05 / D-07: ProceduralPose writes a lean and a spin onto the Mannequin child of VisualRoot
## inside the physics tick (DEV-01). A ground dash leans the body toward the dash direction about the hip pivot and the
## lean flows into the held long-jump stretch without a dip; an air dash does not lean; Jump 3 and long jump stage 3
## spin once and finish before touchdown; with aim held at take-off no pirouette starts, and an aim press or an air
## dash during a pirouette finishes it cleanly (DEV-03). Every expectation derives from player.config. Actions are
## released and the tick rate stays at 60 before nodes are freed.

const Fixtures := preload("res://tests/fixtures.gd")
const TPS: int = 60
const LEAN_TOLERANCE_DEG: float = 1.0
const PIVOT_TOLERANCE: float = 0.001
const LEAN_IN_TICKS: int = 6
const OUT_EXTRA_TICKS: int = 3
const UP_TILT_MIN: float = 0.2
const LIMIT_TICKS: int = 360
const SPIN_SEEN_MIN: float = 5.5
const STEP_EPSILON: float = 1e-4
const MID_FLIGHT_TICKS: int = 6

var _floor: StaticBody3D
## Mutable state of the per-tick callbacks (lambdas copy plain variables, a Dictionary is shared).
var _scratch: Dictionary = {}


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = TPS
	await _scenario_rest_and_dash_lean(tree, check)
	await _scenario_stretch_continuity(tree, check)
	await _scenario_air_dash_upright(tree, check)
	await _scenario_jump_chain_spin(tree, check)
	await _scenario_cut_jump_3(tree, check)
	await _scenario_long_jump_stages(tree, check)
	await _scenario_aim_gate(tree, check)
	await _scenario_aim_lean(tree, check)
	await _scenario_air_dash_finish(tree, check)
	await _scenario_aim_press_finish(tree, check)


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


# --- helpers --------------------------------------------------------------------------------------------------

## One row of the per-tick log.
func _sample(player: PlayerController) -> Dictionary:
	var pose: ProceduralPose = _pose(player)
	var basis: Basis = _mannequin(player).transform.basis
	return {
		"state": player.state_machine.current.name,
		"lean": pose.lean_angle,
		"spin": pose.spin_angle,
		"spinning": pose.spinning,
		"grounded": player.is_grounded(),
		"aiming": player.aiming,
		"finite": basis.x.is_finite() and basis.y.is_finite() and basis.z.is_finite() and _mannequin(player).transform.origin.is_finite(),
	}


## Holds move_forward and waits until the player runs at run speed.
func _run_up(tree: SceneTree, player: PlayerController) -> void:
	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - player.config.run_speed) < 0.05, 120)


## Follows a flight that was already started (press sent) until the next touchdown, one log row per tick. With `hold`
## the jump button is released at the apex. `on_tick` (optional) gets the tick number and the log.
func _flight(tree: SceneTree, player: PlayerController, hold: bool = true, on_tick: Callable = Callable()) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var left_ground: bool = false
	var released: bool = false
	var ticks: int = 0
	while ticks < LIMIT_TICKS:
		await tree.physics_frame
		ticks += 1
		rows.append(_sample(player))
		if on_tick.is_valid():
			on_tick.call(ticks, rows)
		if not player.is_grounded():
			left_ground = true
		if hold and not released and ticks > 2 and player.vertical_speed <= 0.0:
			Fixtures.send_action_event(&"jump", false)
			released = true
		if left_ground and player.is_grounded():
			break
	if not released:
		Fixtures.send_action_event(&"jump", false)
	return rows


## Presses jump, waits for Jump and flies the whole jump. Returns the log and whether the pose spun on the entry tick.
func _jump(tree: SceneTree, player: PlayerController, hold: bool = true, tap: bool = false, on_tick: Callable = Callable()) -> Dictionary:
	Fixtures.send_action_event(&"jump", true)
	if tap:
		Fixtures.send_action_event(&"jump", false)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Jump", 8)
	var entry_spinning: bool = _pose(player).spinning
	var stage: int = player.chain_stage
	var rows: Array[Dictionary] = await _flight(tree, player, hold and not tap, on_tick)
	return {"rows": rows, "entry_spinning": entry_spinning, "stage": stage}


## Dash plus jump: a long jump. Returns the log, the stage and whether the pose spun on the entry tick.
func _hop(tree: SceneTree, player: PlayerController, on_tick: Callable = Callable()) -> Dictionary:
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"jump", true)
	Fixtures.send_action_event(&"dash", false)
	var started: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"LongJump", 12)
	if started < 0:
		Fixtures.send_action_event(&"jump", false)
		return {"rows": [] as Array[Dictionary], "entry_spinning": false, "stage": 0, "started": false}
	var entry_spinning: bool = _pose(player).spinning
	var stage: int = player.long_jump_stage
	var rows: Array[Dictionary] = await _flight(tree, player, true, on_tick)
	return {"rows": rows, "entry_spinning": entry_spinning, "stage": stage, "started": true}


func _max_of(rows: Array[Dictionary], key: String) -> float:
	var biggest: float = 0.0
	for row: Dictionary in rows:
		biggest = maxf(biggest, float(row[key]))
	return biggest


func _any_spinning(rows: Array[Dictionary]) -> bool:
	for row: Dictionary in rows:
		if bool(row.spinning):
			return true
	return false


func _all_finite(rows: Array[Dictionary]) -> bool:
	for row: Dictionary in rows:
		if not bool(row.finite):
			return false
	return true


## The spin is complete at touchdown or completes within pirouette_finish_time plus 2 ticks after it.
func _completes_by_touchdown(tree: SceneTree, player: PlayerController) -> bool:
	var pose: ProceduralPose = _pose(player)
	var budget: int = int(ceil(player.config.pirouette_finish_time * float(TPS))) + 2
	return await Fixtures.wait_until(tree, func() -> bool: return not pose.spinning and pose.spin_angle == 0.0, budget) >= 0


## Index of the first row whose state is `state_name`, or -1.
func _first_state(rows: Array[Dictionary], state_name: StringName) -> int:
	for i: int in rows.size():
		if rows[i].state == state_name:
			return i
	return -1


## True when no row from `from` on has a smaller spin angle than the row before it while the spin runs.
func _spin_never_snaps_back(rows: Array[Dictionary], from: int) -> bool:
	for i: int in range(maxi(from, 1), rows.size()):
		if bool(rows[i].spinning) and bool(rows[i - 1].spinning) and float(rows[i].spin) < float(rows[i - 1].spin):
			return false
	return true


# D-04: Dash -> long jump keeps the lean continuous into the held stretch, the stretch holds through Fall until
# landing and eases out afterwards.
func _scenario_stretch_continuity(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	var pose: ProceduralPose = _pose(player)
	await _run_up(tree, player)
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"jump", true)
	Fixtures.send_action_event(&"dash", false)
	var rows: Array[Dictionary] = await _flight(tree, player, true)
	var step: float = deg_to_rad(config.stretch_lean_deg) / config.lean_in_time / float(TPS)
	var biggest_step: float = 0.0
	var dipped: bool = false
	var reached_stretch: bool = false
	var held_in_fall: bool = false
	for i: int in rows.size():
		var lean: float = float(rows[i].lean)
		if i > 0:
			var change: float = lean - float(rows[i - 1].lean)
			if not reached_stretch:
				biggest_step = maxf(biggest_step, absf(change))
				dipped = dipped or change < -STEP_EPSILON
		if absf(rad_to_deg(lean) - config.stretch_lean_deg) < LEAN_TOLERANCE_DEG:
			reached_stretch = true
		if rows[i].state == &"Fall" and not bool(rows[i].grounded) and absf(rad_to_deg(lean) - config.stretch_lean_deg) < LEAN_TOLERANCE_DEG:
			held_in_fall = true
	check.call(biggest_step <= step + STEP_EPSILON, "(s1) the lean change per tick never exceeds the ease-in step (%.4f of %.4f rad)" % [biggest_step, step])
	check.call(not dipped, "(s1) the lean never dips below the dash lean on the way to the stretch (D-04)")
	check.call(reached_stretch, "(s1) the lean reaches stretch_lean_deg %.0f during the long jump" % config.stretch_lean_deg)
	check.call(held_in_fall, "(s1) the stretch is held after LongJump turns into Fall, until landing")
	var out_budget: int = int(ceil(config.stretch_lean_deg / config.stretch_lean_deg * config.lean_out_time * float(TPS))) + OUT_EXTRA_TICKS
	var upright: int = await Fixtures.wait_until(tree, func() -> bool: return pose.lean_angle == 0.0, out_budget)
	check.call(upright >= 0, "(s1) the stretch eases out after landing within %d ticks (got %.2f deg)" % [out_budget, rad_to_deg(pose.lean_angle)])
	check.call(not _any_spinning(rows), "(s1) long jump stage 1 only stretches, it does not spin (D-05)")
	check.call(_all_finite(rows), "(s1) every written Mannequin basis is finite")
	await _end(player)


# D-02: an air dash adds no lean.
func _scenario_air_dash_upright(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var pose: ProceduralPose = _pose(player)
	await _run_up(tree, player)
	Fixtures.send_action_event(&"jump", true)
	await Fixtures.wait_until(tree, func() -> bool: return not player.is_grounded() and player.vertical_speed <= 0.5, 60)
	Fixtures.send_action_event(&"jump", false)
	await Fixtures.tap_action(tree, &"dash")
	var in_dash: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 6)
	var biggest: float = 0.0
	var dash_ticks: int = 0
	while player.state_machine.current.name == &"Dash" and dash_ticks < 40:
		biggest = maxf(biggest, pose.lean_angle)
		await tree.physics_frame
		dash_ticks += 1
	check.call(in_dash >= 0 and dash_ticks > 3, "(a1) the air dash ran (%d ticks)" % dash_ticks)
	check.call(biggest == 0.0, "(a1) an air dash adds no lean (D-02), biggest lean %.2f deg" % rad_to_deg(biggest))
	await _fly_out(tree, player)
	await _end(player)


## Lets a flight in progress end.
func _fly_out(tree: SceneTree, player: PlayerController) -> void:
	await Fixtures.wait_until(tree, func() -> bool: return player.is_grounded(), LIMIT_TICKS)
	Fixtures.send_action_event(&"jump", false)


# D-05 / D-07: Jump 1 and 2 do not spin; a held Jump 3 spins once from its entry tick and is complete by touchdown.
func _scenario_jump_chain_spin(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var pose: ProceduralPose = _pose(player)
	await _run_up(tree, player)
	var first: Dictionary = await _jump(tree, player)
	var second: Dictionary = await _jump(tree, player)
	check.call(not _any_spinning(first.rows) and not first.entry_spinning, "(j1) Jump 1 never spins")
	check.call(not _any_spinning(second.rows) and not second.entry_spinning, "(j1) Jump 2 never spins")
	var third: Dictionary = await _jump(tree, player)
	var rows: Array[Dictionary] = third.rows
	check.call(third.stage == 3 and third.entry_spinning, "(j2) Jump 3 starts spinning on its entry tick (stage %d)" % third.stage)
	check.call(_max_of(rows, "spin") > SPIN_SEEN_MIN, "(j2) the spin angle gets past %.1f rad (max %.2f)" % [SPIN_SEEN_MIN, _max_of(rows, "spin")])
	var done: bool = not pose.spinning and pose.spin_angle == 0.0
	check.call(done or await _completes_by_touchdown(tree, player), "(j2) the spin is complete at touchdown or within pirouette_finish_time plus 2 ticks")
	check.call(_spin_never_snaps_back(rows, 0), "(j2) the spin angle only grows while it runs")
	check.call(_all_finite(rows), "(j2) every written Mannequin basis is finite")
	check.call(is_zero_approx(player.visual_root.rotation.x) and is_zero_approx(player.visual_root.rotation.z), "(j2) VisualRoot is never tilted by the spin (DEV-01)")
	await _end(player)


# D-04 / D-07: a released (cut) Jump 3 still completes its spin by touchdown.
func _scenario_cut_jump_3(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var pose: ProceduralPose = _pose(player)
	await _run_up(tree, player)
	await _jump(tree, player)
	await _jump(tree, player)
	var third: Dictionary = await _jump(tree, player, false, true)
	var rows: Array[Dictionary] = third.rows
	check.call(third.stage == 3 and third.entry_spinning, "(c1) a tapped Jump 3 still spins (stage %d)" % third.stage)
	var done: bool = not pose.spinning and pose.spin_angle == 0.0
	check.call(done or await _completes_by_touchdown(tree, player), "(c1) the cut Jump 3 completes its spin by touchdown")
	check.call(_all_finite(rows), "(c1) every written Mannequin basis is finite")
	await _end(player)


# D-05: long jump stages 1 and 2 only stretch, stage 3 spins; the nesting switch changes the written basis.
func _scenario_long_jump_stages(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var pose: ProceduralPose = _pose(player)
	await _run_up(tree, player)
	_scratch = {"compared": false, "differs": false, "finite": true}
	var hop_1: Dictionary = await _hop(tree, player)
	var hop_2: Dictionary = await _hop(tree, player)
	var hop_3: Dictionary = await _hop(tree, player, _compare_nesting.bind(pose))
	check.call(hop_1.started and hop_2.started and hop_3.started, "(l1) all three dash jumps became long jumps")
	check.call(hop_1.stage == 1 and hop_2.stage == 2 and hop_3.stage == 3, "(l1) the stages are 1, 2, 3 (got %d, %d, %d)" % [hop_1.stage, hop_2.stage, hop_3.stage])
	check.call(not _any_spinning(hop_1.rows) and not hop_1.entry_spinning and not _any_spinning(hop_2.rows) and not hop_2.entry_spinning, "(l1) long jump stages 1 and 2 only stretch (D-05)")
	check.call(hop_3.entry_spinning and _max_of(hop_3.rows, "spin") > SPIN_SEEN_MIN, "(l2) stage 3 spins from its entry tick, max spin %.2f rad" % _max_of(hop_3.rows, "spin"))
	var done: bool = not pose.spinning and pose.spin_angle == 0.0
	check.call(done or await _completes_by_touchdown(tree, player), "(l2) the stage 3 spin is complete by touchdown")
	check.call(bool(_scratch.compared) and bool(_scratch.differs), "(l3) spin_about_body_axis true and false give different Mannequin bases for the same lean and spin")
	check.call(bool(_scratch.finite) and _all_finite(hop_3.rows), "(l3) every written basis is finite")
	await _end(player)


## Per-tick hook: once during the spin with a lean, compares both nestings for the same lean and spin.
func _compare_nesting(_tick: int, rows: Array[Dictionary], pose: ProceduralPose) -> void:
	if bool(_scratch.compared) or not pose.spinning or pose.lean_angle < 0.5 or pose.spin_angle < 1.0 or pose.spin_angle > 5.0:
		return
	var corkscrew: Basis = pose.pose_basis()
	pose.spin_about_body_axis = not pose.spin_about_body_axis
	var other: Basis = pose.pose_basis()
	pose.spin_about_body_axis = not pose.spin_about_body_axis
	_scratch.compared = true
	_scratch.differs = not corkscrew.is_equal_approx(other)
	_scratch.finite = corkscrew.x.is_finite() and corkscrew.y.is_finite() and corkscrew.z.is_finite() and other.x.is_finite() and other.y.is_finite() and other.z.is_finite()


# DEV-03: with aim held at take-off neither Jump 3 nor long jump stage 3 starts a pirouette.
func _scenario_aim_gate(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	await _run_up(tree, player)
	await _jump(tree, player)
	await _jump(tree, player)
	Fixtures.send_action_event(&"aim", true)
	var third: Dictionary = await _jump(tree, player)
	check.call(third.stage == 3 and bool(third.rows[0].aiming), "(g1) Jump 3 took off with aim held (stage %d)" % third.stage)
	check.call(not third.entry_spinning and not _any_spinning(third.rows), "(g1) no pirouette starts when aim is held at take-off, Jump 3 (DEV-03)")
	check.call(_all_finite(third.rows), "(g1) every written Mannequin basis is finite")
	Fixtures.send_action_event(&"aim", false)
	await _end(player)

	player = await _begin(tree)
	await _run_up(tree, player)
	await _hop(tree, player)
	await _hop(tree, player)
	Fixtures.send_action_event(&"aim", true)
	var hop_3: Dictionary = await _hop(tree, player)
	check.call(hop_3.started and hop_3.stage == 3 and not hop_3.entry_spinning and not _any_spinning(hop_3.rows), "(g2) no pirouette starts when aim is held at take-off, long jump stage 3 (DEV-03)")
	Fixtures.send_action_event(&"aim", false)
	await _end(player)


# Checkpoint item 3: while aiming a ground dash lean peaks at dash_lean_deg * aim_lean_scale.
func _scenario_aim_lean(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	var pose: ProceduralPose = _pose(player)
	Fixtures.send_action_event(&"aim", true)
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 30)
	await Fixtures.tap_action(tree, &"dash")
	var peak: float = 0.0
	var ticks: int = 0
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 6)
	while player.state_machine.current.name == &"Dash" and ticks < 40:
		peak = maxf(peak, pose.lean_angle)
		await tree.physics_frame
		ticks += 1
	var expected: float = config.dash_lean_deg * config.aim_lean_scale
	check.call(absf(rad_to_deg(peak) - expected) < LEAN_TOLERANCE_DEG, "(m1) the aiming dash lean peaks at dash_lean_deg * aim_lean_scale %.1f deg (got %.2f)" % [expected, rad_to_deg(peak)])
	Fixtures.send_action_event(&"aim", false)
	await _end(player)


# DEV-03: an air dash during a running pirouette finishes the remaining spin within pirouette_finish_time.
func _scenario_air_dash_finish(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	await _run_up(tree, player)
	await _jump(tree, player)
	await _jump(tree, player)
	var third: Dictionary = await _jump(tree, player, true, false, _press_dash_mid_flight)
	var rows: Array[Dictionary] = third.rows
	var dash_index: int = _first_state(rows, &"Dash")
	check.call(dash_index >= 0, "(d1) the air dash started during the Jump 3 pirouette")
	if dash_index >= 0:
		var budget: int = dash_index + int(ceil(player.config.pirouette_finish_time * float(TPS))) + 2
		var finished_at: int = -1
		for i: int in range(dash_index, rows.size()):
			if not bool(rows[i].spinning):
				finished_at = i
				break
		check.call(finished_at >= 0 and finished_at <= budget, "(d1) the air dash finishes the spin within pirouette_finish_time plus 2 ticks (DEV-03): row %d of budget %d" % [finished_at, budget])
		check.call(_spin_never_snaps_back(rows, 0), "(d1) the spin angle only grows on the way, no snap back (DEV-03)")
		check.call(_max_of(rows.slice(0, dash_index + 1), "spin") < TAU, "(d1) the spin was still running when the air dash began")
	check.call(_all_finite(rows), "(d1) every written Mannequin basis is finite")
	await _end(player)


func _press_dash_mid_flight(tick: int, _rows: Array[Dictionary]) -> void:
	if tick == MID_FLIGHT_TICKS:
		Fixtures.send_action_event(&"dash", true)
		Fixtures.send_action_event(&"dash", false)


# DEV-03: an aim press during a running Jump 3 pirouette finishes the remaining spin within pirouette_finish_time.
func _scenario_aim_press_finish(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	await _run_up(tree, player)
	await _jump(tree, player)
	await _jump(tree, player)
	var third: Dictionary = await _jump(tree, player, true, false, _press_aim_mid_flight)
	var rows: Array[Dictionary] = third.rows
	var aim_index: int = -1
	for i: int in rows.size():
		if bool(rows[i].aiming):
			aim_index = i
			break
	check.call(aim_index >= 0 and bool(rows[maxi(aim_index, 0)].spinning), "(h1) aim was pressed during the Jump 3 pirouette")
	if aim_index >= 0:
		var budget: int = aim_index + int(ceil(player.config.pirouette_finish_time * float(TPS))) + 2
		var finished_at: int = -1
		for i: int in range(aim_index, rows.size()):
			if not bool(rows[i].spinning):
				finished_at = i
				break
		check.call(finished_at >= 0 and finished_at <= budget, "(h1) the aim press finishes the spin within pirouette_finish_time plus 2 ticks (DEV-03): row %d of budget %d" % [finished_at, budget])
		check.call(_spin_never_snaps_back(rows, 0), "(h1) the spin angle only grows on the way, no snap back (DEV-03)")
	check.call(_all_finite(rows), "(h1) every written Mannequin basis is finite")
	Fixtures.send_action_event(&"aim", false)
	await _end(player)


func _press_aim_mid_flight(tick: int, _rows: Array[Dictionary]) -> void:
	if tick == MID_FLIGHT_TICKS:
		Fixtures.send_action_event(&"aim", true)
