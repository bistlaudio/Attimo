extends RefCounted
## MOVE-09 / ROADMAP criterion 4: the animation never makes control wait for a clip. Every travelling state change
## travels the tree on the same physics frame (inside the state_changed call), a landing never locks control, a jump
## shows at most 2 frames of anticipation, and the one deliberate presentation delay, the air-dash pose hold
## (DEV-02), never delays the FSM, steering or landing. A recorder connected after the scene is ready runs after the
## animator's handler and stores what the animator shows inside each state_changed call. Tick counts come from
## physics frames, never from wall clock (Pitfall 12: headless animation time is wall clock, so scenarios that count
## animation time run the tree in manual mode and advance it once per physics frame).

const Fixtures := preload("res://tests/fixtures.gd")
## The animation node of the unaimed ground dash: Slide only while Dash.SLIDE_PRESENTATION is on (off since 2026-11-18).
const UNAIMED_DASH: StringName = &"Slide" if preload("res://scripts/player/states/dash.gd").SLIDE_PRESENTATION else &"Dash"
const SHIPPED_TPS: int = 60
const LIBRARY_PATH: String = "res://assets/animations/rig_medium/rig_medium_library.res"
const TREE_PATH: String = "res://scenes/player/mannequin_tree.tres"
const HIPS_TRACK: String = "Rig_Medium/Skeleton3D:hips"
const ANTICIPATION_FRAMES: float = 2.0
const SAMPLE_STEP: float = 1.0 / 120.0
const LAND_FADE_TICKS: int = 10
const DROP_HEIGHT: float = 30.0
const STEER_GAIN_MIN: float = 0.5
const STEER_TICKS: int = 10

var _calls: Array[Dictionary] = []
var _recorder: Callable
var _machine: StateMachine
var _floor: StaticBody3D
var _player: PlayerController
var _animator: MannequinAnimator
var _anim_tree: AnimationTree
var _rig: CameraRig


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_same_frame(tree, check)
	await _scenario_jump_fall_visible(tree, check)
	await _scenario_landing(tree, check)
	_scenario_anticipation(check)
	await _scenario_air_dash_hold(tree, check)
	await _scenario_hold_timeout_and_steering(tree, check)
	await _scenario_ledge(tree, check)


# Idle -> Jump and Run -> Dash travel inside their own state_changed call and the visible node follows.
func _scenario_same_frame(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, Fixtures.spawn_floor(tree.root), Vector3.ZERO)
	# Let the tree leave its Start node first: a jump in the first frames after spawn is seen late by the tree.
	await Fixtures.wait_physics(tree, 30)
	await Fixtures.tap_action(tree, &"jump")
	var jump_call: int = _find(&"Idle", &"Jump")
	check.call(jump_call >= 0, "(2) Idle -> Jump was recorded (calls %s)" % [_names()])
	if jump_call >= 0:
		_check_same_frame(check, "(2) Idle -> Jump", _calls[jump_call], &"Jump")
		await Fixtures.wait_process(tree, 2)
		var node: StringName = Fixtures.playback(_player).get_current_node()
		check.call(node == &"Jump" or _find(&"Jump", &"Fall") >= 0, "(2) the visible node follows Jump within 2 process frames (got %s)" % node)
	await Fixtures.wait_until(tree, func() -> bool: return _player.is_grounded() and _player.state_machine.current.name == &"Idle", 120)
	await Fixtures.wait_physics(tree, 40)
	_calls.clear()
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.tap_action(tree, &"dash")
	var dash_call: int = _find(&"Run", &"Dash")
	check.call(dash_call >= 0, "(2) Run -> Dash was recorded (calls %s)" % [_names()])
	if dash_call >= 0:
		_check_same_frame(check, "(2) Run -> Dash", _calls[dash_call], UNAIMED_DASH)
		await Fixtures.wait_process(tree, 2)
		var dash_node: StringName = Fixtures.playback(_player).get_current_node()
		check.call(dash_node == UNAIMED_DASH, "(2) the visible node follows the unaimed ground dash node within 2 process frames (got %s)" % dash_node)
	await _end(tree)


func _check_same_frame(check: Callable, label: String, entry: Dictionary, node: StringName) -> void:
	check.call(entry["travel"] == node, "%s: last_travel is %s inside the call (got %s)" % [label, node, entry["travel"]])
	check.call(entry["travel_frame"] == entry["frame"], "%s: last_travel_frame %d equals the physics frame %d of the call" % [label, entry["travel_frame"], entry["frame"]])


# A tap jump's Jump -> Fall arrives before the cut Jump clip ends and the visible node is Fall at the first advance
# after that tick: Jump -> Fall has no at-end edge, so it is not a second exception (A-01-2).
func _scenario_jump_fall_visible(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, Fixtures.spawn_floor(tree.root), Vector3.ZERO)
	var previous_mode: AnimationMixer.AnimationCallbackModeProcess = _anim_tree.callback_mode_process
	_anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var cut_ticks: int = int(round(_jump_node(_anim_tree.tree_root).timeline_length * float(Engine.physics_ticks_per_second)))
	Input.action_press(&"jump")
	await _step(tree, 2)
	Input.action_release(&"jump")
	var node_at_detection: StringName = &""
	for i: int in 60:
		await _step(tree, 1)
		if _find(&"Jump", &"Fall") >= 0:
			node_at_detection = Fixtures.playback(_player).get_current_node()
			break
	var start_call: int = _find(&"Idle", &"Jump")
	var fall_call: int = _find(&"Jump", &"Fall")
	check.call(start_call >= 0 and fall_call >= 0, "(3) a tap jump records Idle -> Jump and Jump -> Fall (calls %s)" % [_names()])
	if start_call >= 0 and fall_call >= 0:
		var gap: int = int(_calls[fall_call]["frame"]) - int(_calls[start_call]["frame"])
		check.call(gap < cut_ticks, "(3) Jump -> Fall comes %d ticks after Idle -> Jump, before the cut clip ends (%d ticks)" % [gap, cut_ticks])
		_check_same_frame(check, "(3) Jump -> Fall", _calls[fall_call], &"Fall")
		check.call(node_at_detection == &"Fall", "(3) the visible node is Fall at the first advance after that tick, not when the clip ends (got %s)" % node_at_detection)
	_anim_tree.callback_mode_process = previous_mode
	await _end(tree)


# Landing into Idle fires the Land overlay and a move input fades it out within LAND_FADE_TICKS manual steps.
func _scenario_landing(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, Fixtures.spawn_floor(tree.root), Vector3.ZERO)
	var previous_mode: AnimationMixer.AnimationCallbackModeProcess = _anim_tree.callback_mode_process
	_anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var root: AnimationNodeBlendTree = _anim_tree.tree_root as AnimationNodeBlendTree
	var machine: AnimationNodeStateMachine = root.get_node(&"StateMachine") as AnimationNodeStateMachine
	check.call(not machine.has_node(&"Land"), "(4) the state machine has no node named Land")
	Input.action_press(&"jump")
	await _step(tree, 2)
	Input.action_release(&"jump")
	var landed: bool = false
	for i: int in 120:
		await _step(tree, 1)
		if _find(&"Fall", &"Idle") >= 0:
			landed = true
			break
	check.call(landed, "(4) the jump ends in Idle (calls %s)" % [_names()])
	check.call(Fixtures.land_active(_player), "(4) landing into Idle sets parameters/Land/active")
	Input.action_press(&"move_forward")
	var faded: int = -1
	for i: int in LAND_FADE_TICKS + 1:
		if not Fixtures.land_active(_player):
			faded = i
			break
		await _step(tree, 1)
	check.call(faded >= 0, "(4) a move input fades the Land overlay out within %d ticks, so a landing never locks control (took %d)" % [LAND_FADE_TICKS, faded])
	_anim_tree.callback_mode_process = previous_mode
	await _end(tree)


# The crouch bottom of Jump_Start lies at or before the Jump node's start_offset plus 2 frames.
func _scenario_anticipation(check: Callable) -> void:
	var library: AnimationLibrary = load(LIBRARY_PATH) as AnimationLibrary
	check.call(library != null and library.has_animation(&"Jump_Start"), "(5) the library holds Jump_Start")
	if library == null or not library.has_animation(&"Jump_Start"):
		return
	var animation: Animation = library.get_animation(&"Jump_Start")
	var track: int = animation.find_track(NodePath(HIPS_TRACK), Animation.TYPE_POSITION_3D)
	check.call(track >= 0, "(5) Jump_Start has the hips position track %s" % HIPS_TRACK)
	if track < 0:
		return
	var low_time: float = 0.0
	var low_height: float = INF
	var t: float = 0.0
	while t <= animation.length:
		var height: float = (animation.position_track_interpolate(track, t) as Vector3).y
		if height < low_height:
			low_height = height
			low_time = t
		t += SAMPLE_STEP
	var start_offset: float = _jump_node(load(TREE_PATH) as AnimationNodeBlendTree).start_offset
	var limit: float = start_offset + ANTICIPATION_FRAMES / float(SHIPPED_TPS)
	check.call(low_time <= limit + 1e-4, "(5) the crouch bottom at %.3f s is at or before start_offset %.3f + 2 frames = %.3f s" % [low_time, start_offset, limit])


# Air dash from a low tap jump: Dash -> Fall holds the Dodge node, the landing travels on the landing frame.
func _scenario_air_dash_hold(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, Fixtures.spawn_floor(tree.root), Vector3.ZERO)
	await Fixtures.tap_action(tree, &"jump")
	await Fixtures.wait_physics(tree, Fixtures.lock_ticks(_player.config))
	await Fixtures.tap_action(tree, &"dash")
	var exited: int = await Fixtures.wait_until(tree, func() -> bool: return _find(&"Dash", &"Fall") >= 0, 30)
	check.call(exited >= 0, "(1) the dash exit was recorded within 30 ticks")
	await Fixtures.wait_process(tree, 2)
	if _find(&"Fall", &"Idle") < 0:
		var held: StringName = Fixtures.playback(_player).get_current_node()
		check.call(held == &"Dash", "(1) two process frames after the exit the tree is still on the dash node (got %s)" % held)
	var landed: int = await Fixtures.wait_until(tree, func() -> bool: return _find(&"Fall", &"Idle") >= 0, 120)
	check.call(landed >= 0, "(1) the air dash jump ends in Idle (calls %s)" % [_names()])
	var exit_call: int = _find(&"Dash", &"Fall")
	check.call(exit_call >= 0, "(1) the air dash exits into Fall")
	if exit_call >= 0:
		var entry: Dictionary = _calls[exit_call]
		check.call(entry["holding"] == true, "(1) air_dash_holding is true inside the Dash -> Fall call")
		check.call(entry["travel"] == &"Dash", "(1) last_travel is still the dash node inside the Dash -> Fall call (got %s)" % entry["travel"])
	var land_call: int = _find(&"Fall", &"Idle")
	if land_call >= 0:
		var land: Dictionary = _calls[land_call]
		check.call(land["holding"] == false, "(1) air_dash_holding is false inside the landing call")
		_check_same_frame(check, "(1) landing", land, &"Locomotion")
		var active: int = await Fixtures.wait_until(tree, func() -> bool: return Fixtures.land_active(_player), 10)
		check.call(active >= 0, "(1) landing into Idle fires the Land overlay")
	await _end(tree)


# Long fall: the hold times out after air_dash_hold_time() ticks, the FSM is not delayed and air steering acts.
func _scenario_hold_timeout_and_steering(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, Fixtures.spawn_floor(tree.root), Vector3(0.0, DROP_HEIGHT, 0.0), true)
	var tps: float = float(Engine.physics_ticks_per_second)
	var falling: int = await Fixtures.wait_until(tree, func() -> bool: return _player.state_machine.current.name == &"Fall", 60)
	check.call(falling >= 0, "(6) the player spawned high up is in Fall")
	await Fixtures.tap_action(tree, &"dash")
	var exited: int = await Fixtures.wait_until(tree, func() -> bool: return _find(&"Dash", &"Fall") >= 0, 30)
	check.call(exited >= 0, "(6) the air dash exits into Fall")
	if exited < 0:
		await _end(tree)
		return
	var entered_call: int = _find(&"Fall", &"Dash")
	var exit_call: int = _find(&"Dash", &"Fall")
	var exit_frame: int = int(_calls[exit_call]["frame"])
	var dash_ticks: int = exit_frame - int(_calls[entered_call]["frame"])
	var expected_dash_ticks: int = ceili(_player.config.dash_time * tps)
	check.call(absi(dash_ticks - expected_dash_ticks) <= 1, "(7) the FSM enters Fall %d ticks after Dash entry, expected %d within 1 (the hold does not delay it)" % [dash_ticks, expected_dash_ticks])
	check.call(_calls[exit_call]["holding"] == true, "(7) the hold is active at that exit")
	# Steering during the hold: left of the camera, measured against the velocity at the exit.
	var yaw: float = _rig.steering_yaw()
	var left: Vector3 = -Vector3(cos(yaw), 0.0, -sin(yaw))
	var baseline: float = _player.move_velocity.dot(left)
	Input.action_press(&"move_left")
	var steered: int = await Fixtures.wait_until(tree, func() -> bool: return _animator.air_dash_holding and _player.move_velocity.dot(left) - baseline > STEER_GAIN_MIN, STEER_TICKS)
	check.call(steered >= 0, "(7) holding move_left during the hold adds more than %.1f m/s along the camera's left within %d ticks (gain %.2f)" % [STEER_GAIN_MIN, STEER_TICKS, _player.move_velocity.dot(left) - baseline])
	Input.action_release(&"move_left")
	var ended: int = await Fixtures.wait_until(tree, func() -> bool: return not _animator.air_dash_holding, 60)
	check.call(ended >= 0, "(6) the hold ends by itself in a long fall")
	var hold_ticks: int = int(round(_animator.air_dash_hold_time() * tps))
	var travel_ticks: int = _animator.last_travel_frame - exit_frame
	check.call(_animator.last_travel == &"Fall", "(6) the hold ends with a travel to Fall (got %s)" % _animator.last_travel)
	check.call(absi(travel_ticks - hold_ticks) <= 1, "(6) the hold ended %d ticks after the dash exit, expected %d within 1" % [travel_ticks, hold_ticks])
	check.call(Engine.get_physics_frames() - _animator.last_travel_frame <= 2, "(6) last_travel_frame is the frame of that travel")
	await _end(tree)


# A ground dash that runs off a ledge and ends airborne does not hold: Fall is travelled on the exit call.
func _scenario_ledge(tree: SceneTree, check: Callable) -> void:
	var platform: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(4.0, 1.0, 4.0))
	await _begin(tree, platform, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 5)
	await Fixtures.tap_action(tree, &"dash")
	var exited: int = await Fixtures.wait_until(tree, func() -> bool: return _find(&"Dash", &"Fall") >= 0, 30)
	check.call(exited >= 0, "(8) a ground dash off a 4 m platform ends in Fall (calls %s)" % [_names()])
	var exit_call: int = _find(&"Dash", &"Fall")
	if exit_call >= 0:
		check.call(_calls[exit_call]["holding"] == false, "(8) air_dash_holding is false for a ground dash that ends airborne")
		_check_same_frame(check, "(8) ledge exit", _calls[exit_call], &"Fall")
	await _end(tree)


## Spawns the player on `ground`, waits until the scene is ready and starts the recorder. With `with_rig` a
## CameraRig gives input_direction() a camera frame.
func _begin(tree: SceneTree, ground: StaticBody3D, position: Vector3, with_rig: bool = false) -> void:
	_floor = ground
	_player = Fixtures.spawn_player(tree.root, position)
	_rig = Fixtures.spawn_camera_rig(tree.root, _player) if with_rig else null
	# The scene is ready after the first frame; the recorder joins after the animator's own connection.
	await Fixtures.wait_physics(tree, 2)
	_animator = _player.get_node("MannequinAnimator") as MannequinAnimator
	_anim_tree = Fixtures.animation_tree(_player)
	_record()
	await Fixtures.wait_physics(tree, 3)


## Releases every action, drops the recorder and frees the scenario's nodes.
func _end(tree: SceneTree) -> void:
	for action: StringName in [&"jump", &"dash", &"move_forward", &"move_left", &"move_right", &"move_back"]:
		Input.action_release(action)
		Fixtures.send_action_event(action, false)
	_stop_recording()
	if _rig != null:
		_rig.queue_free()
		_rig = null
	_player.queue_free()
	_floor.queue_free()
	await _player.tree_exited
	await Fixtures.wait_physics(tree, 1)


## One physics frame, then one manual advance of the AnimationTree (only meaningful in manual mode).
func _step(tree: SceneTree, frames: int) -> void:
	for i: int in frames:
		await tree.physics_frame
		_anim_tree.advance(1.0 / float(SHIPPED_TPS))


## Records every state_changed call: from, to, the animator's view and the physics frame, all read inside the call.
func _record() -> void:
	_calls = []
	_machine = _player.state_machine
	var animator: MannequinAnimator = _animator
	_recorder = func(from_state: StringName, to_state: StringName) -> void:
		_calls.append({
			"from": from_state,
			"to": to_state,
			"travel": animator.last_travel,
			"travel_frame": animator.last_travel_frame,
			"holding": animator.air_dash_holding,
			"frame": Engine.get_physics_frames(),
		})
	_machine.state_changed.connect(_recorder)


func _stop_recording() -> void:
	if _machine != null and _machine.state_changed.is_connected(_recorder):
		_machine.state_changed.disconnect(_recorder)
	# The lambda captures self; drop it so this RefCounted test object is not kept alive by a cycle.
	_recorder = Callable()
	_machine = null


## Index of the first recorded call from -> to, or -1.
func _find(from_state: StringName, to_state: StringName) -> int:
	for i: int in _calls.size():
		if _calls[i]["from"] == from_state and _calls[i]["to"] == to_state:
			return i
	return -1


func _names() -> Array[String]:
	var names: Array[String] = []
	for entry: Dictionary in _calls:
		names.append("%s->%s" % [entry["from"], entry["to"]])
	return names


## The Jump node of a tree root (cut clip length and start offset are read from the tree, never typed).
func _jump_node(root: AnimationRootNode) -> AnimationNodeAnimation:
	var blend: AnimationNodeBlendTree = root as AnimationNodeBlendTree
	var machine: AnimationNodeStateMachine = blend.get_node(&"StateMachine") as AnimationNodeStateMachine
	return machine.get_node(&"Jump") as AnimationNodeAnimation
