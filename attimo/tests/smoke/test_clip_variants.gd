extends RefCounted
## Quick 261118-qi3: the clip variations of the Mannequin. Presentation only: every check also asserts that the FSM is
## never delayed. Tree parameters are read through the MannequinAnimator constants.
##   I1 standing in Idle fires the IdleBreak OneShot after the rolled delay, the playback node stays Locomotion
##   I2 a move press cancels a running break on the same physics frame, the FSM enters Run on its normal tick
##   I3 two consecutive breaks use different clips; holding aim prevents any break
##   R1 the reaction pools are in the library (or dropped on purpose) and pick_reaction never repeats immediately

const Fixtures := preload("res://tests/fixtures.gd")
const LIBRARY_PATH: String = "res://assets/animations/rig_medium/rig_medium_library.res"
const SETTLE_FRAMES: int = 20
const BREAK_DELAY_MIN: float = 0.2
const BREAK_DELAY_MAX: float = 0.3
const REACTION_CALLS: int = 50

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


func _break_active() -> bool:
	return bool(_anim_tree.get(MannequinAnimator.P_IDLE_BREAK_ACTIVE))


## The documented drop list of tools/build_animation_library.gd.
func _dropped_list() -> Array[StringName]:
	var script: GDScript = load("res://tools/build_animation_library.gd") as GDScript
	var result: Array[StringName] = []
	for entry: Variant in script.get_script_constant_map().get("UAL_DROPPED", []):
		result.append(StringName(entry))
	return result


## Spawns floor and player with short idle-break delays (on a duplicated config) and waits until it has settled.
func _begin(tree: SceneTree) -> void:
	_floor = Fixtures.spawn_floor(tree.root)
	_player = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	_player.config = _player.config.duplicate() as MovementConfig
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
