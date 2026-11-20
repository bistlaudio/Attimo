extends RefCounted
## MOVE-09 / D-01 / D-04 / D-05 / D-07: ProceduralPose writes a lean and a spin onto the Mannequin child of VisualRoot
## inside the physics tick (DEV-01). A ground dash leans the body toward the dash direction about the hip pivot
## (dash_lean_deg, times aim_lean_scale when aim is pressed mid-dash: there is no dash while aiming, quick 261120-dik) and the
## lean eases back to upright when the dash hands over to a long jump (no
## stretch lean); the unaimed ground dash is the retargeted Running_Slide (DEV-04) and the body stays exactly upright;
## an air dash does not lean either; Jump 3 and long jump stage 3
## spin once and finish before touchdown; with aim held at take-off no pirouette starts, an aim press during a pirouette
## finishes it cleanly (DEV-03), and a dash press during a pirouette is refused (dash lockout, quick 261120-dik). Every expectation derives from player.config. Actions are
## released and the tick rate stays at 60 before nodes are freed.

const Fixtures := preload("res://tests/fixtures.gd")
## The animation node of the unaimed ground dash: Slide only while Dash.SLIDE_PRESENTATION is on (off since 2026-11-18).
const UNAIMED_DASH: StringName = &"Slide" if preload("res://scripts/player/states/dash.gd").SLIDE_PRESENTATION else &"Dash"
const TPS: int = 60
const LEAN_TOLERANCE_DEG: float = 1.0
const PIVOT_TOLERANCE: float = 0.001
const LEAN_IN_TICKS: int = 6
const OUT_EXTRA_TICKS: int = 3
## Share of sin(lean) the up vector must tilt toward the dash direction (scales with dash_lean_deg).
const UP_TILT_MIN: float = 0.8
const LIMIT_TICKS: int = 360
const SPIN_SEEN_MIN: float = 5.5
const STEP_EPSILON: float = 1e-4
const MID_FLIGHT_TICKS: int = 6
const SYNTHETIC_LEAN: float = 0.6

var _floor: StaticBody3D
## Mutable state of the per-tick callbacks (lambdas copy plain variables, a Dictionary is shared).
var _scratch: Dictionary = {}


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = TPS
	await _scenario_rest_and_dash_lean(tree, check)
	await _scenario_hop_upright(tree, check)
	await _scenario_air_dash_upright(tree, check)
	await _scenario_jump_chain_spin(tree, check)
	await _scenario_cut_jump_3(tree, check)
	await _scenario_long_jump_stages(tree, check)
	await _scenario_aim_gate(tree, check)
	await _scenario_aim_lean(tree, check)
	await _scenario_air_dash_blocked_in_pirouette(tree, check)
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


# D-01 / DEV-04: at rest the Mannequin transform is identity. The unaimed ground dash is the Slide: lean 0 and an exactly
# identity transform through the dash. An aimed ground dash leans it toward the dash direction on its first tick, about
# the hip pivot, scaled by aim_lean_scale, without touching VisualRoot; the lean eases out after the dash.
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

	# The unaimed ground dash is the Slide (DEV-04): no lean, identity transform.
	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - config.run_speed) < 0.05, 120)
	await Fixtures.tap_action(tree, &"dash")
	var slide_in_dash: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 6)
	check.call(slide_in_dash >= 0, "(p2) the dash press enters Dash (got %s)" % player.state_machine.current.name)
	var is_slide: bool = UNAIMED_DASH == &"Slide"
	check.call(bool(player.state_machine.current.get(&"slide")) == is_slide, "(p2) an unaimed ground dash is marked slide only while the slide presentation is on")
	var slide_lean: float = 0.0
	var slide_identity: bool = true
	var slide_ticks: int = 0
	while player.state_machine.current.name == &"Dash" and slide_ticks < 40:
		slide_lean = maxf(slide_lean, pose.lean_angle)
		slide_identity = slide_identity and mannequin.transform == Transform3D.IDENTITY
		await tree.physics_frame
		slide_ticks += 1
	check.call(slide_ticks > 3, "(p2) the slide dash ran (%d ticks)" % slide_ticks)
	if is_slide:
		check.call(slide_lean == 0.0 and slide_identity, "(p2) the unaimed ground dash keeps the lean at 0 and the Mannequin transform identity (biggest lean %.2f deg)" % rad_to_deg(slide_lean))
	else:
		check.call(rad_to_deg(slide_lean) > config.dash_lean_deg * 0.5, "(p2) the unaimed ground dash leans forward (D-01, biggest lean %.2f deg)" % rad_to_deg(slide_lean))
	await _end(player)

	# An aimed press is refused (quick 261120-dik): no Dash, no lean, only the twitch of the blocked press.
	player = await _begin(tree)
	pose = _pose(player)
	mannequin = _mannequin(player)
	Input.action_press(&"aim")
	await Fixtures.wait_physics(tree, 12)
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 30)
	await Fixtures.tap_action(tree, &"dash")
	check.call(player.state_machine.current.name != &"Dash", "(p2a) the aimed dash press does not enter Dash (got %s)" % player.state_machine.current.name)
	var aimed_lean: float = 0.0
	for i: int in 12:
		await tree.physics_frame
		aimed_lean = maxf(aimed_lean, pose.lean_angle)
	check.call(aimed_lean == 0.0, "(p2a) the refused aimed press adds no dash lean (biggest %.2f deg)" % rad_to_deg(aimed_lean))
	await _end(player)

	# The unaimed ground dash keeps the D-01 lean (Dodge_Forward presentation).
	player = await _begin(tree)
	pose = _pose(player)
	mannequin = _mannequin(player)
	await _run_up(tree, player)
	await Fixtures.tap_action(tree, &"dash")
	var in_dash: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 6)
	check.call(in_dash >= 0, "(p2b) the dash press enters Dash (got %s)" % player.state_machine.current.name)
	var target_deg: float = config.dash_lean_deg
	check.call(pose.lean_angle > 0.0, "(p2b) the lean is above 0 on the first tick of the ground dash (got %.2f deg)" % rad_to_deg(pose.lean_angle))
	var reached: int = await Fixtures.wait_until(tree, func() -> bool: return absf(rad_to_deg(pose.lean_angle) - target_deg) < LEAN_TOLERANCE_DEG, LEAN_IN_TICKS)
	check.call(reached >= 0, "(p2b) the lean reaches dash_lean_deg %.1f within %d ticks (got %.2f deg)" % [target_deg, LEAN_IN_TICKS, rad_to_deg(pose.lean_angle)])

	var pivot: Vector3 = Vector3(0.0, config.pose_pivot_height, 0.0)
	var moved: Vector3 = mannequin.transform * pivot
	check.call(moved.distance_to(pivot) < PIVOT_TOLERANCE, "(p3) the pivot point maps to itself under the Mannequin transform (off by %.4f m)" % moved.distance_to(pivot))
	var tilt: Vector3 = player.visual_root.global_basis * (mannequin.transform.basis * Vector3.UP)
	var dash_direction: Vector3 = Vector3(0.0, 0.0, -1.0)
	check.call(tilt.dot(dash_direction) > UP_TILT_MIN * sin(deg_to_rad(target_deg)), "(p3) the leaning body tilts its up vector toward the dash direction (dot %.2f)" % tilt.dot(dash_direction))
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
	await Fixtures.wait_until(tree, func() -> bool: return player.dash_locked_reason() == &"", 30)
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


# Quick task 261118-okz: Dash -> long jump eases the dash lean back to upright (no held stretch lean). The lean never
# grows past the dash lean, never grows again once the long jump started, is 0 within lean_out_time plus a few ticks
# after the hand-over and stays 0 through the flight and Fall until landing. Unaimed (the slide, DEV-04) the lean is 0
# on every row.
func _scenario_hop_upright(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	var pose: ProceduralPose = _pose(player)
	var tag: String = "(s1)"
	var lean_cap_deg: float = config.dash_lean_deg * (0.0 if UNAIMED_DASH == &"Slide" else 1.0)
	await _run_up(tree, player)
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"jump", true)
	Fixtures.send_action_event(&"dash", false)
	var rows: Array[Dictionary] = await _flight(tree, player, true)
	var entry: int = _first_state(rows, &"LongJump")
	check.call(entry >= 0, tag + " the dash plus jump became a long jump")
	var peak: float = _max_of(rows, "lean")
	check.call(rad_to_deg(peak) <= lean_cap_deg + LEAN_TOLERANCE_DEG, tag + " the lean never exceeds %.1f deg (peak %.2f deg)" % [lean_cap_deg, rad_to_deg(peak)])
	if UNAIMED_DASH == &"Slide":
		check.call(peak == 0.0, tag + " the unaimed dash hop has lean 0 on every row (the slide, DEV-04)")
	if entry >= 0:
		var grew: bool = false
		for i: int in range(entry + 1, rows.size()):
			grew = grew or float(rows[i].lean) > float(rows[i - 1].lean) + STEP_EPSILON
		check.call(not grew, tag + " the lean only eases out once the long jump started")
		var out_budget: int = int(ceil(config.lean_out_time * float(TPS))) + OUT_EXTRA_TICKS
		var upright_row: int = -1
		for i: int in range(entry, rows.size()):
			if float(rows[i].lean) == 0.0:
				upright_row = i
				break
		check.call(upright_row >= 0 and upright_row - entry <= out_budget, tag + " the lean is 0 within lean_out_time plus %d ticks after the hand-over (row %d of budget %d)" % [OUT_EXTRA_TICKS, upright_row - entry, out_budget])
		var stays_upright: bool = upright_row >= 0
		var airborne_upright_rows: int = 0
		for i: int in range(maxi(upright_row, 0), rows.size()):
			stays_upright = stays_upright and float(rows[i].lean) == 0.0
			if not bool(rows[i].grounded):
				airborne_upright_rows += 1
		check.call(stays_upright and airborne_upright_rows > 0, tag + " the body stays upright through the rest of the flight and Fall (%d airborne rows)" % airborne_upright_rows)
	check.call(pose.lean_angle == 0.0, tag + " the lean is 0 at landing (got %.2f deg)" % rad_to_deg(pose.lean_angle))
	check.call(not _any_spinning(rows), tag + " long jump stage 1 does not spin (D-05)")
	check.call(_all_finite(rows), tag + " every written Mannequin basis is finite")
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


# D-05: long jump stages 1 and 2 do not spin, stage 3 spins; the nesting switch changes the written basis.
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
	check.call(not _any_spinning(hop_1.rows) and not hop_1.entry_spinning and not _any_spinning(hop_2.rows) and not hop_2.entry_spinning, "(l1) long jump stages 1 and 2 do not spin (D-05)")
	check.call(hop_3.entry_spinning and _max_of(hop_3.rows, "spin") > SPIN_SEEN_MIN, "(l2) stage 3 spins from its entry tick, max spin %.2f rad" % _max_of(hop_3.rows, "spin"))
	var done: bool = not pose.spinning and pose.spin_angle == 0.0
	check.call(done or await _completes_by_touchdown(tree, player), "(l2) the stage 3 spin is complete by touchdown")
	check.call(bool(_scratch.compared) and bool(_scratch.differs), "(l3) spin_about_body_axis true and false give different Mannequin bases for the same spin and a synthetic lean")
	check.call(bool(_scratch.finite) and _all_finite(hop_3.rows), "(l3) every written basis is finite")
	await _end(player)


## Per-tick hook: once during the spin, compares both nestings for the same spin with a synthetic lean (the long jump
## itself is upright, so the lean is set for the comparison and restored).
func _compare_nesting(_tick: int, _rows: Array[Dictionary], pose: ProceduralPose) -> void:
	if bool(_scratch.compared) or not pose.spinning or pose.spin_angle < 1.0 or pose.spin_angle > 5.0:
		return
	var real_lean: float = pose.lean_angle
	pose.lean_angle = SYNTHETIC_LEAN
	var corkscrew: Basis = pose.pose_basis()
	pose.spin_about_body_axis = not pose.spin_about_body_axis
	var other: Basis = pose.pose_basis()
	pose.spin_about_body_axis = not pose.spin_about_body_axis
	pose.lean_angle = real_lean
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

	# There is no dash while aiming, so aim is pressed during the stage 3 dash, before the jump that turns it into the hop.
	player = await _begin(tree)
	await _run_up(tree, player)
	await _hop(tree, player)
	await _hop(tree, player)
	await Fixtures.wait_until(tree, func() -> bool: return player.dash_locked_reason() == &"", 30)
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"dash", false)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 6)
	Fixtures.send_action_event(&"aim", true)
	await Fixtures.wait_physics(tree, 2)
	Fixtures.send_action_event(&"jump", true)
	var started: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"LongJump", 12)
	var hop_3_stage: int = player.long_jump_stage
	var hop_3_spinning: bool = _pose(player).spinning
	var hop_3_rows: Array[Dictionary] = await _flight(tree, player, true)
	check.call(started >= 0 and hop_3_stage == 3 and not hop_3_spinning and not _any_spinning(hop_3_rows), "(g2) no pirouette starts when aim is held at take-off, long jump stage 3 (DEV-03)")
	Fixtures.send_action_event(&"aim", false)
	await _end(player)


# Checkpoint item 3: a lean that is running while aim is pressed mid-dash eases to dash_lean_deg * aim_lean_scale (aim
# itself never starts a dash, quick 261120-dik).
func _scenario_aim_lean(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	var pose: ProceduralPose = _pose(player)
	await _run_up(tree, player)
	await Fixtures.tap_action(tree, &"dash")
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 6)
	Fixtures.send_action_event(&"aim", true)
	var peak: float = 0.0
	var ticks: int = 0
	while player.state_machine.current.name == &"Dash" and ticks < 40:
		peak = maxf(peak, pose.lean_angle)
		await tree.physics_frame
		ticks += 1
	var expected: float = config.dash_lean_deg * config.aim_lean_scale
	check.call(absf(rad_to_deg(peak) - expected) < LEAN_TOLERANCE_DEG, "(m1) the lean of a dash with aim pressed peaks at dash_lean_deg * aim_lean_scale %.1f deg (got %.2f)" % [expected, rad_to_deg(peak)])
	Fixtures.send_action_event(&"aim", false)
	await _end(player)


# Quick 261120-dik (replaces the DEV-03 air-dash finish): a dash press during a running pirouette is refused, so no Dash
# starts, the spin runs on to its normal end and the refused press emits dash_blocked with the pirouette reason.
func _scenario_air_dash_blocked_in_pirouette(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var reasons: Array[StringName] = []
	var bus: Node = tree.root.get_node("EventBus")
	var on_blocked: Callable = func(_position: Vector3, reason: StringName) -> void: reasons.append(reason)
	bus.connect(&"dash_blocked", on_blocked)
	await _run_up(tree, player)
	await _jump(tree, player)
	await _jump(tree, player)
	var third: Dictionary = await _jump(tree, player, true, false, _press_dash_late_in_spin)
	var rows: Array[Dictionary] = third.rows
	check.call(_first_state(rows, &"Dash") < 0, "(d1) no Dash starts during the Jump 3 pirouette")
	check.call(reasons.has(PlayerController.DASH_LOCK_PIROUETTE), "(d1) a press inside the pirouette emits dash_blocked with the pirouette reason (got %s)" % [reasons])
	check.call(_max_of(rows, "spin") > SPIN_SEEN_MIN, "(d1) the spin still runs through (max %.2f rad)" % _max_of(rows, "spin"))
	check.call(_spin_never_snaps_back(rows, 0), "(d1) the spin angle only grows on the way, no snap back")
	check.call(_all_finite(rows), "(d1) every written Mannequin basis is finite")
	bus.disconnect(&"dash_blocked", on_blocked)
	await _end(player)


## A press well after the take-off lockout, inside the pirouette.
func _press_dash_late_in_spin(tick: int, _rows: Array[Dictionary]) -> void:
	if tick == MID_FLIGHT_TICKS * 2:
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
