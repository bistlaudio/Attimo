extends RefCounted
## Quick 261118-qi3: the clip variations of the Mannequin. Presentation only: every check also asserts that the FSM is
## never delayed. Tree parameters are read through the MannequinAnimator constants.
##   I1 standing in Idle fires the IdleBreak OneShot after the rolled delay, the playback node stays Locomotion
##   I2 a move press cancels a running break on the same physics frame, the FSM enters Run on its normal tick
##   I3 two consecutive breaks use different clips; holding aim prevents any break
##   R1 the reaction pools are in the library (or dropped on purpose) and pick_reaction never repeats immediately
##   S1 the unaimed Locomotion y is speed / run_speed up to 1, then rises toward 2 up to sprint_anim_full_speed
##   S2 after a ground dash the blend goes above 1, comes back to 1 at run speed; the clip scale caps at run_speed
##   J1 Jump stage 2 travels to Jump2, stages 1 and 3 to Jump, LongJump to LongJump, Fall to Fall, on the call
##   J2 the Jump2 and LongJump windows start at most 2 frames before their crouch bottom
##   L1 landing_kind: roll before hard before soft (soft only into Idle)
##   L2 soft, hard and roll landings show their LandPick input and never delay the next jump

const Fixtures := preload("res://tests/fixtures.gd")
const LIBRARY_PATH: String = "res://assets/animations/rig_medium/rig_medium_library.res"
const SETTLE_FRAMES: int = 20
const BREAK_DELAY_MIN: float = 0.2
const BREAK_DELAY_MAX: float = 0.3
const REACTION_CALLS: int = 50
const HIPS_TRACK: String = "Rig_Medium/Skeleton3D:hips"
const TREE_PATH: String = "res://scenes/player/mannequin_tree.tres"
const ANTICIPATION_FRAMES: float = 2.0
const LAND_WAIT_FRAMES: int = 300
const FADE_FRAMES: int = 10

var _floor: StaticBody3D
var _player: PlayerController
var _animator: MannequinAnimator
var _anim_tree: AnimationTree
var _library: AnimationLibrary


func run(tree: SceneTree, check: Callable) -> void:
	_library = load(LIBRARY_PATH) as AnimationLibrary
	await _scenario_idle_break(tree, check)
	await _scenario_idle_cancel(tree, check)
	await _scenario_idle_variety_and_aim(tree, check)
	await _scenario_reactions(tree, check)
	await _scenario_sprint_table(tree, check)
	await _scenario_sprint_after_dash(tree, check)
	await _scenario_aim_clamp(tree, check)
	await _scenario_jump_nodes(tree, check)
	_scenario_anticipation(check)
	await _scenario_landing_table(tree, check)
	await _scenario_landing_soft(tree, check)
	await _scenario_landing_hard(tree, check)
	await _scenario_landing_roll(tree, check)


# I1: a figure left standing plays an idle break after the rolled delay; the state machine stays in Locomotion.
func _scenario_idle_break(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var tps: int = Engine.physics_ticks_per_second
	var limit: int = ceili(BREAK_DELAY_MAX * float(tps)) + 10 + SETTLE_FRAMES
	var fired: int = await Fixtures.wait_until(tree, func() -> bool: return _break_active(), limit)
	check.call(fired >= 0, "I1 standing in Idle fires the IdleBreak OneShot within %.1f s plus 10 frames (took %d frames)" % [BREAK_DELAY_MAX, fired])
	check.call(_animator.last_idle_break != &"" and _animator.idle_break_pool().has(_animator.last_idle_break), "I1 the break plays a clip of the pool (%s)" % _animator.last_idle_break)
	check.call(Fixtures.playback(_player).get_current_node() == &"Locomotion", "I1 the playback node stays Locomotion during the break")
	check.call(String(_player.state_machine.current.name) == "Idle", "I1 the FSM stays in Idle (the break is an overlay)")
	await _end(tree)


# I2: a move press cancels the running break on the same physics frame and the FSM enters Run on its normal tick.
func _scenario_idle_cancel(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var limit: int = ceili(BREAK_DELAY_MAX * float(Engine.physics_ticks_per_second)) + 10 + SETTLE_FRAMES
	var fired: int = await Fixtures.wait_until(tree, func() -> bool: return _break_active(), limit)
	check.call(fired >= 0, "I2 a break runs before the move press")
	await Fixtures.wait_physics(tree, 10)
	var run_frame: Array[int] = [-1]
	var on_change: Callable = func(_from: StringName, to_state: StringName) -> void:
		if to_state == &"Run" and run_frame[0] < 0:
			run_frame[0] = Engine.get_physics_frames()
	_player.state_machine.state_changed.connect(on_change)
	var press_frame: int = Engine.get_physics_frames()
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 3)
	check.call(_animator.idle_break_cancel_frame >= press_frame and _animator.idle_break_cancel_frame <= press_frame + 1, "I2 the move press requests the break fade-out on the press tick (press %d, cancel %d)" % [press_frame, _animator.idle_break_cancel_frame])
	check.call(run_frame[0] >= 0 and run_frame[0] - press_frame <= 1, "I2 the FSM enters Run on its normal tick (press %d, Run %d)" % [press_frame, run_frame[0]])
	check.call(run_frame[0] < 0 or _animator.idle_break_cancel_frame <= run_frame[0], "I2 the cancel is never later than the Run state change")
	var faded: int = await Fixtures.wait_until(tree, func() -> bool: return not _break_active(), 20)
	check.call(faded >= 0, "I2 the break overlay has faded within 20 frames of the cancel (%d)" % faded)
	_player.state_machine.state_changed.disconnect(on_change)
	Input.action_release(&"move_forward")
	await _end(tree)


# I3: consecutive breaks differ; holding aim keeps any break away.
func _scenario_idle_variety_and_aim(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var tps: int = Engine.physics_ticks_per_second
	var limit: int = ceili(BREAK_DELAY_MAX * float(tps)) + 10 + SETTLE_FRAMES
	var first_fired: int = await Fixtures.wait_until(tree, func() -> bool: return _break_active(), limit)
	var first_clip: StringName = _animator.last_idle_break
	var first_frame: int = _animator.last_idle_break_frame
	var pool_size: int = _animator.idle_break_pool().size()
	# The next break comes after the first clip has ended plus the next delay (clips are at most 2.5 s).
	var second_fired: int = await Fixtures.wait_until(tree, func() -> bool: return _animator.last_idle_break_frame != first_frame, 4 * tps)
	var second_clip: StringName = _animator.last_idle_break
	check.call(first_fired >= 0 and second_fired >= 0, "I3 two breaks fire one after the other (%d, %d frames)" % [first_fired, second_fired])
	if pool_size >= 2:
		check.call(first_clip != second_clip, "I3 two consecutive breaks use different clips (%s, %s)" % [first_clip, second_clip])
	else:
		check.call(first_clip == second_clip, "I3 a one-clip pool repeats its only clip (%s)" % first_clip)

	Input.action_press(&"aim")
	await Fixtures.wait_physics(tree, 2)
	var frame_before: int = _animator.last_idle_break_frame
	await Fixtures.wait_physics(tree, tps)
	check.call(_animator.last_idle_break_frame == frame_before, "I3 holding aim for 1 s fires no break")
	Input.action_release(&"aim")
	await _end(tree)


# R1: the reaction pools live in the library (or in UAL_DROPPED) and the picker never repeats immediately.
func _scenario_reactions(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var dropped: Array[StringName] = _dropped_list()
	var pools: Dictionary[StringName, Array] = {
		&"idle_break": MannequinAnimator.IDLE_BREAK_CLIPS, &"hit": MannequinAnimator.HIT_CLIPS,
		&"death": MannequinAnimator.DEATH_CLIPS, &"interact": MannequinAnimator.INTERACT_CLIPS,
	}
	for pool_name: StringName in pools:
		for clip: StringName in pools[pool_name]:
			check.call(_library.has_animation(clip) or dropped.has(clip), "R1 %s clip %s is in the library or dropped on purpose" % [pool_name, clip])
	for kind: StringName in [&"hit", &"death", &"interact"]:
		var available: int = 0
		for clip: StringName in pools[kind]:
			if _library.has_animation(clip):
				available += 1
		var previous: StringName = &""
		var repeats: int = 0
		var empty: int = 0
		for i: int in REACTION_CALLS:
			var pick: StringName = _animator.pick_reaction(kind)
			if pick == &"":
				empty += 1
			elif pick == previous:
				repeats += 1
			previous = pick
		check.call(empty == 0, "R1 pick_reaction(%s) always returns a clip" % kind)
		if available >= 2:
			check.call(repeats == 0, "R1 pick_reaction(%s) never repeats immediately over %d calls (%d repeats)" % [kind, REACTION_CALLS, repeats])
		else:
			check.call(available == 1, "R1 the %s pool keeps its one KayKit clip" % kind)
	check.call(_animator.pick_reaction(&"unknown") == &"", "R1 pick_reaction returns &\"\" for an unknown kind")
	await _end(tree)


# S1: the unaimed blend y as a table over the speed.
func _scenario_sprint_table(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false)
	var config: MovementConfig = _player.config
	var run: float = config.run_speed
	var full: float = config.sprint_anim_full_speed
	var rows: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(run * 0.5, 0.5), Vector2(run, 1.0), Vector2((run + full) * 0.5, 1.5), Vector2(full, 2.0), Vector2(full * 2.0, 2.0)]
	for row: Vector2 in rows:
		var y: float = _animator.locomotion_y_for(row.x)
		check.call(is_equal_approx(snappedf(y, 0.0001), row.y), "S1 unaimed blend y at %.2f m/s is %.2f (got %.4f)" % [row.x, row.y, y])
	await _end(tree)


# S2: a ground dash that ends at dash_exit_speed with move held pushes the blend above 1, run speed brings it back.
func _scenario_sprint_after_dash(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false)
	var config: MovementConfig = _player.config
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 45)
	await Fixtures.tap_action(tree, &"dash")
	var above: int = 0
	var scale_ok: bool = true
	var scale_seen: bool = false
	for i: int in 40:
		await Fixtures.wait_physics(tree, 1)
		await Fixtures.wait_process(tree, 1)
		if Fixtures.locomotion_blend(_player).y > 1.0001:
			above += 1
		if _animator.last_travel == &"Locomotion" and _player.horizontal_speed() > config.run_speed + 0.01:
			scale_seen = true
			var expected: float = clampf(config.run_speed / config.run_anim_ref_speed, 1.0, config.run_anim_max_scale)
			if not is_equal_approx(_animator.clip_scale(), expected):
				scale_ok = false
	check.call(above >= 1, "S2 the blend y goes above 1 for at least one tick after the dash (%d ticks)" % above)
	check.call(scale_seen and scale_ok, "S2 above run_speed the Locomotion clip scale uses the speed capped at run_speed (seen=%s)" % scale_seen)
	await Fixtures.wait_physics(tree, 60)
	var settled: float = Fixtures.locomotion_blend(_player).y
	check.call(settled <= 1.0001 and settled > 0.9, "S2 at run speed the blend y is back at 1 (got %.3f)" % settled)
	Input.action_release(&"move_forward")
	await _end(tree)


# S1: while aiming the blend stays inside [-1, 1], also right after an aimed dash.
func _scenario_aim_clamp(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false)
	Input.action_press(&"aim")
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 30)
	await Fixtures.tap_action(tree, &"dash")
	var worst: float = 0.0
	for i: int in 40:
		await Fixtures.wait_physics(tree, 1)
		await Fixtures.wait_process(tree, 1)
		worst = maxf(worst, absf(Fixtures.locomotion_blend(_player).y))
	check.call(worst <= 1.0001, "S1 while aiming the blend y stays within [-1, 1] (max %.3f)" % worst)
	Input.action_release(&"move_forward")
	Input.action_release(&"aim")
	await _end(tree)


# J1: Jump 1, 2, 3 of the ground chain and a long jump travel to their nodes on the state-change call.
func _scenario_jump_nodes(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false)
	var calls: Array[Dictionary] = []
	var animator: MannequinAnimator = _animator
	var player: PlayerController = _player
	var recorder: Callable = func(_from: StringName, to_state: StringName) -> void:
		calls.append({"to": to_state, "stage": player.chain_stage, "travel": animator.last_travel, "frame": animator.last_travel_frame, "now": Engine.get_physics_frames()})
	_player.state_machine.state_changed.connect(recorder)
	for jump: int in 3:
		await Fixtures.tap_action(tree, &"jump", 12)
		await _wait_grounded(tree)
	await Fixtures.wait_physics(tree, 40)
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 30)
	await Fixtures.tap_action(tree, &"dash")
	await Fixtures.tap_action(tree, &"jump")
	await _wait_grounded(tree)
	Input.action_release(&"move_forward")
	_player.state_machine.state_changed.disconnect(recorder)
	var stages: Array[int] = []
	var long_jumps: int = 0
	for call: Dictionary in calls:
		var to_state: StringName = call["to"]
		if to_state == &"Jump":
			var stage: int = call["stage"]
			stages.append(stage)
			var expected: StringName = &"Jump2" if stage == 2 else &"Jump"
			check.call(call["travel"] == expected and call["frame"] == call["now"], "J1 Jump stage %d travels to %s inside the call (got %s)" % [stage, expected, call["travel"]])
		elif to_state == &"LongJump":
			long_jumps += 1
			check.call(call["travel"] == &"LongJump" and call["frame"] == call["now"], "J1 LongJump travels to LongJump inside the call (got %s)" % call["travel"])
		elif to_state == &"Fall":
			check.call(call["travel"] == &"Fall" and call["frame"] == call["now"], "J1 Fall travels to Fall inside the call (got %s)" % call["travel"])
	check.call(stages == ([1, 2, 3] as Array[int]), "J1 the ground chain ran stages 1, 2, 3 (got %s)" % [stages])
	check.call(long_jumps == 1, "J1 one long jump was recorded (got %d)" % long_jumps)
	await _end(tree)


# J2: the takeoff windows of Jump2 and LongJump start at most 2 frames before the crouch bottom.
func _scenario_anticipation(check: Callable) -> void:
	var root: AnimationNodeBlendTree = load(TREE_PATH) as AnimationNodeBlendTree
	var machine: AnimationNodeStateMachine = root.get_node(&"StateMachine") as AnimationNodeStateMachine
	for node_name: StringName in [&"Jump2", &"LongJump"]:
		check.call(machine.has_node(node_name), "J2 the state machine has the %s node" % node_name)
		if not machine.has_node(node_name):
			continue
		var node: AnimationNodeAnimation = machine.get_node(node_name) as AnimationNodeAnimation
		var animation: Animation = _library.get_animation(node.animation)
		var track: int = animation.find_track(NodePath(HIPS_TRACK), Animation.TYPE_POSITION_3D)
		check.call(node.use_custom_timeline and node.loop_mode == Animation.LOOP_NONE and track >= 0, "J2 %s plays a non-looping window of a clip with a hips track" % node_name)
		if track < 0:
			continue
		var low_time: float = 0.0
		var low_height: float = INF
		var t: float = 0.0
		while t <= node.start_offset + node.timeline_length + 1e-4:
			var height: float = (animation.position_track_interpolate(track, t) as Vector3).y
			if height < low_height:
				low_height = height
				low_time = t
			t += 1.0 / 60.0
		var limit: float = node.start_offset + ANTICIPATION_FRAMES / 60.0
		check.call(low_time <= limit + 1e-4, "J2 %s crouch bottom at %.3f s is at or before start_offset %.3f + 2 frames" % [node_name, low_time, node.start_offset])


# L1: the landing kind as a table, no physics.
func _scenario_landing_table(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false)
	var config: MovementConfig = _player.config
	var roll: float = config.roll_landing_speed
	var hard: float = config.hard_landing_speed
	var rows: Array = [
		[1.0, 0.0, &"Idle", &"soft"], [1.0, 0.0, &"Run", &""], [hard, 0.0, &"Idle", &"hard"], [hard, 0.0, &"Run", &"hard"],
		[1.0, roll, &"Run", &"roll"], [hard + 5.0, roll + 1.0, &"Idle", &"roll"], [hard - 0.1, roll - 0.1, &"Idle", &"soft"],
		[hard - 0.1, roll - 0.1, &"Run", &""],
	]
	for row: Array in rows:
		var kind: StringName = _animator.landing_kind(row[0], row[1], row[2])
		check.call(kind == row[3], "L1 impact %.1f, horizontal %.1f into %s is '%s' (got '%s')" % [row[0], row[1], row[2], row[3], kind])
	await _end(tree)


# L2 soft: a small hop into Idle.
func _scenario_landing_soft(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false)
	await Fixtures.tap_action(tree, &"jump", 2)
	await _wait_grounded(tree)
	await _check_landing(tree, check, &"soft")
	await _end(tree)


# L2 hard: a drop from 30 m.
func _scenario_landing_hard(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false, Vector3(0.0, 30.0, 0.0))
	await _wait_grounded(tree)
	await _check_landing(tree, check, &"hard")
	await _end(tree)


# L2 roll: a stage 1 long jump lands at about 14 m/s horizontally.
func _scenario_landing_roll(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false)
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 30)
	await Fixtures.tap_action(tree, &"dash")
	await Fixtures.tap_action(tree, &"jump")
	await _wait_airborne(tree)
	await _wait_grounded(tree)
	await _check_landing(tree, check, &"roll")
	Input.action_release(&"move_forward")
	await _end(tree)


## Right after a landing: the expected LandPick kind shows, a jump press on the next tick starts Jump on that tick and
## the Land overlay fades within FADE_FRAMES.
func _check_landing(tree: SceneTree, check: Callable, kind: StringName) -> void:
	check.call(_animator.last_land_kind == kind, "L2 the landing is '%s' (got '%s', impact %.1f, horizontal %.1f)" % [kind, _animator.last_land_kind, _animator.last_impact_speed, _animator.last_landing_horizontal_speed])
	await Fixtures.wait_process(tree, 1)
	check.call(String(_anim_tree.get(MannequinAnimator.P_LAND_PICK_STATE)) == String(kind), "L2 LandPick shows the %s input (got %s)" % [kind, _anim_tree.get(MannequinAnimator.P_LAND_PICK_STATE)])
	var jump_frame: Array[int] = [-1]
	var on_change: Callable = func(_from: StringName, to_state: StringName) -> void:
		if to_state == &"Jump" and jump_frame[0] < 0:
			jump_frame[0] = Engine.get_physics_frames()
	_player.state_machine.state_changed.connect(on_change)
	var press_frame: int = Engine.get_physics_frames()
	Input.action_press(&"jump")
	await Fixtures.wait_physics(tree, 2)
	check.call(jump_frame[0] >= 0 and jump_frame[0] - press_frame <= 1, "L2 after a %s landing a jump press starts Jump on its tick (press %d, Jump %d)" % [kind, press_frame, jump_frame[0]])
	var faded: int = await Fixtures.wait_until(tree, func() -> bool: return not Fixtures.land_active(_player), FADE_FRAMES)
	check.call(faded >= 0, "L2 the %s Land overlay fades within %d ticks of the jump (%d)" % [kind, FADE_FRAMES, faded])
	Input.action_release(&"jump")
	_player.state_machine.state_changed.disconnect(on_change)


func _wait_grounded(tree: SceneTree) -> void:
	await Fixtures.wait_until(tree, func() -> bool: return [&"Idle", &"Run"].has(_player.state_machine.current.name), LAND_WAIT_FRAMES)


func _wait_airborne(tree: SceneTree) -> void:
	await Fixtures.wait_until(tree, func() -> bool: return not [&"Idle", &"Run", &"Dash"].has(_player.state_machine.current.name), LAND_WAIT_FRAMES)


func _break_active() -> bool:
	return bool(_anim_tree.get(MannequinAnimator.P_IDLE_BREAK_ACTIVE))


## The documented drop list of tools/build_animation_library.gd.
func _dropped_list() -> Array[StringName]:
	var script: GDScript = load("res://tools/build_animation_library.gd") as GDScript
	var result: Array[StringName] = []
	for entry: Variant in script.get_script_constant_map().get("UAL_DROPPED", []):
		result.append(StringName(entry))
	return result


## Spawns floor and player (short idle-break delays on a duplicated config when `short_breaks`) and waits a moment.
func _begin(tree: SceneTree, short_breaks: bool = true, spawn: Vector3 = Vector3.ZERO) -> void:
	_floor = Fixtures.spawn_floor(tree.root)
	_player = Fixtures.spawn_player(tree.root, spawn)
	_player.config = _player.config.duplicate() as MovementConfig
	if short_breaks:
		_player.config.idle_break_delay_min = BREAK_DELAY_MIN
		_player.config.idle_break_delay_max = BREAK_DELAY_MAX
	_animator = _player.get_node("MannequinAnimator") as MannequinAnimator
	_anim_tree = Fixtures.animation_tree(_player)
	await Fixtures.wait_physics(tree, 2)


## Releases every action and frees the scenario's nodes.
func _end(tree: SceneTree) -> void:
	for action: StringName in [&"aim", &"jump", &"dash", &"use_hand", &"move_forward", &"move_left", &"move_right", &"move_back"]:
		Input.action_release(action)
	_player.queue_free()
	_floor.queue_free()
	await _player.tree_exited
	await Fixtures.wait_physics(tree, 1)
