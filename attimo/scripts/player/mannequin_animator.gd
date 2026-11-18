class_name MannequinAnimator
extends Node
## Presents FSM state on the Mannequin: maps the LOCAL StateMachine.state_changed signal to AnimationTree travel,
## the Locomotion blend and the Land overlay. Animation shows state; it is not feedback in the D-10 sense.
## The tree root is a BlendTree (tools/build_mannequin_tree.gd): StateMachine -> TimeScale -> Land OneShot -> Aim
## (upper-body layer) -> output. The state machine has one dash node per Dodge clip; dash_node_for() picks it (D-12).
## The aim layer is the spell hand (quick 261118-qi3): an aim press starts the AimMachine at Enter on the same physics
## frame, Hold loops while aim is held, use_hand while aiming fires the Shoot OneShot, a release travels to Exit and the
## layer fades out after the Exit clip.
## Idle breaks (quick 261118-qi3): standing still in Idle for a rolled delay (MovementConfig idle_break_delay_min/max)
## fires the IdleBreak OneShot with a clip picked by a VariantPicker (never the same one twice in a row). Any gameplay
## action, aim or state change fades it out on that same physics frame; the FSM never waits for it.
##
## Air-dash pose hold (DEV-02, D-02 "Dodge held as a pose in the air"): when the FSM leaves a Dash that started in
## the air into Fall, the animator keeps the dash node. The Dodge clip plays on at 1x and holds its last frame,
## because it does not loop. The hold ends at the first of two things. Landing, or any other state change out of
## Fall, travels on that same call. Otherwise the animator travels to Fall itself once air_dash_hold_time() has
## passed since the Dash exit. A ground dash that ends in the air (ran off a ledge) does not hold. The hold is
## presentation only: it reads the Dash node's in_air, writes only AnimationTree parameters and never delays the
## FSM, steering, landing or any input.

## Parameter paths of the generated tree. Tests and later layers read them through these constants.
const P_PLAYBACK: StringName = &"parameters/StateMachine/playback"
const P_LOCOMOTION: StringName = &"parameters/StateMachine/Locomotion/blend_position"
const P_TIME_SCALE: StringName = &"parameters/TimeScale/scale"
const P_LAND_REQUEST: StringName = &"parameters/Land/request"
const P_LAND_ACTIVE: StringName = &"parameters/Land/active"
const P_AIM: StringName = &"parameters/Aim/blend_amount"
const P_AIM_PLAYBACK: StringName = &"parameters/AimMachine/playback"
const P_SHOOT_REQUEST: StringName = &"parameters/Shoot/request"
const P_IDLE_BREAK_REQUEST: StringName = &"parameters/IdleBreak/request"
const P_IDLE_BREAK_ACTIVE: StringName = &"parameters/IdleBreak/active"
const P_IDLE_BREAK_PICK: StringName = &"parameters/IdleBreakPick/transition_request"
## Variant pools (quick 261118-qi3). _ready filters each to the clips the library has, so a dropped clip vanishes.
const IDLE_BREAK_CLIPS: Array[StringName] = [&"Idle_B", &"UAL_Idle_Loop"]
## Reserved pools: library and picker only, no tree node plays them yet (Phase 4 hit and death, Phase 6 interact).
const HIT_CLIPS: Array[StringName] = [&"Hit_A", &"Hit_B", &"UAL_Hit_Chest", &"UAL_Hit_Head"]
const DEATH_CLIPS: Array[StringName] = [&"Death_A", &"Death_B", &"UAL_Death01"]
const INTERACT_CLIPS: Array[StringName] = [&"Interact", &"UAL_Interact"]
## Actions that cancel an idle break (camera look does not).
const IDLE_CANCEL_ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"dash", &"aim", &"use_hand", &"interact"]
## The AimPoseModifier node, relative to the Mannequin node (the AnimationTree's parent).
const AIM_MODIFIER_PATH: NodePath = ^"Rig_Medium/Skeleton3D/AimPoseModifier"

## The dash nodes of the state machine and the Dodge clip each plays; the clip length is stretched to dash_time.
## Dash is the air dash and the aimed forward dash, the others are the aimed dashes (D-12). Slide is the unaimed ground
## dash (DEV-04): the retargeted Running_Slide, picked through Dash.slide.
const DASH_CLIPS: Dictionary[StringName, StringName] = {
	&"Dash": &"Dodge_Forward",
	&"DashLeft": &"Dodge_Left",
	&"DashRight": &"Dodge_Right",
	&"DashBack": &"Dodge_Backward",
	&"Slide": &"Running_Slide",
}

const STATE_TO_ANIM: Dictionary[StringName, StringName] = {
	&"Idle": &"Locomotion",
	&"Run": &"Locomotion",
	&"Jump": &"Jump",
	&"LongJump": &"Jump",
	&"Fall": &"Fall",
	&"Dash": &"Dash",
}

## States that count as airborne for the landing check (Landing into Idle plays the Land overlay).
const AIRBORNE_STATES: Array[StringName] = [&"Jump", &"Fall", &"LongJump"]

@export var state_machine: StateMachine
@export var animation_tree: AnimationTree
@export var player: PlayerController

## The animation node of the last travel and the physics frame it was requested on (read by the timing guard).
var last_travel: StringName = &""
var last_travel_frame: int = -1
## True while the Dodge pose of an air dash is held past the Dash state's exit (read-only for others).
var air_dash_holding: bool = false
## True while the Slide pose is held past the end of the ground dash (read-only for others). Like DEV-02 this is
## presentation only: the FSM is already in Run or Idle and steering, jump and dash respond at once; any state change
## other than the dash ending into Run or Idle ends the hold on the same call.
var slide_holding: bool = false

## Seconds the Slide pose stays after the 0.18 s ground dash, so the slide reads (developer 2026-11-18: "too short").
const SLIDE_HOLD_TIME: float = 0.3
## The Slide window plays at this fixed speed: the 0.233 s drop reaches the floor in about 0.15 s, inside the 0.18 s
## dash (developer 2026-11-18: 1.85x was rushed, 1.0x took too long to reach the floor), then the low pose holds.
const SLIDE_PLAYBACK_SCALE: float = 1.6
## Weight of the upper-body aim layer, 0 (locomotion only) to 1 (aim pose), eased over aim_layer_blend_time.
var aim_weight: float = 0.0
## Weight of the Aim layer in the tree (P_AIM, read-only for others): 1 while aiming and while the Exit clip lowers the
## hand, eased at the aim_weight rate. aim_weight is the solver influence, this is the pose layer.
var layer_weight: float = 0.0
## The clip of the last idle break and the physics frame it fired on; the frame of the last break cancel (read-only).
var last_idle_break: StringName = &""
var last_idle_break_frame: int = -1
var idle_break_cancel_frame: int = -1

var _playback: AnimationNodeStateMachinePlayback
## The spell hand state machine (Enter, Hold, Exit) inside the Aim layer; null when the tree has none.
var _aim_machine: AnimationNodeStateMachinePlayback
var _was_aiming: bool = false
## Seconds of the Exit clip still to play after an aim release; the layer stays at weight 1 until it has run out.
var _exit_left: float = 0.0
var _exit_length: float = 0.0
var _picker: VariantPicker
## Pool name to the clips of that pool the library has.
var _pools: Dictionary[StringName, Array] = {}
var _fsm_state: StringName = &""
var _has_idle_break: bool = false
var _idle_still: float = 0.0
## The rolled delay of the next idle break; negative until rolled (rolled on the first still tick, so a live config
## change applies to the next break).
var _idle_delay: float = -1.0
## True from a fade-out request until the OneShot reports inactive (it stays active while it fades).
var _idle_break_fading: bool = false
## The arm-direction solver under the Mannequin skeleton; null when the scene has none (the feed is then off).
var _aim_modifier: AimPoseModifier
var _loco_blend: Vector2 = Vector2.ZERO
var _loco_target: Vector2 = Vector2.ZERO
var _hold_left: float = 0.0
var _slide_hold_left: float = 0.0
var _dash_state: Node
## Length in seconds of each dash node's Dodge clip, read once in _ready (Pitfall 6).
var _dash_lengths: Dictionary[StringName, float] = {}


func _ready() -> void:
	_playback = animation_tree.get(P_PLAYBACK) as AnimationNodeStateMachinePlayback
	last_travel = &"Locomotion"
	_dash_state = state_machine.get_node_or_null(^"Dash")
	var clip_player: AnimationPlayer = animation_tree.get_node_or_null(animation_tree.anim_player) as AnimationPlayer
	for dash_node: StringName in DASH_CLIPS:
		var clip: StringName = DASH_CLIPS[dash_node]
		if clip_player != null and clip_player.has_animation(clip):
			_dash_lengths[dash_node] = clip_player.get_animation(clip).length
	# The Slide node plays a window of its clip, so the playback scale uses the window length.
	var slide_length: float = _slide_window_length()
	if slide_length > 0.0:
		_dash_lengths[&"Slide"] = slide_length
	_aim_machine = animation_tree.get(P_AIM_PLAYBACK) as AnimationNodeStateMachinePlayback
	_exit_length = _aim_exit_length(clip_player)
	_picker = VariantPicker.new()
	var pool_sources: Dictionary[StringName, Array] = {&"idle_break": IDLE_BREAK_CLIPS, &"hit": HIT_CLIPS, &"death": DEATH_CLIPS, &"interact": INTERACT_CLIPS}
	for pool_name: StringName in pool_sources:
		var available: Array[StringName] = []
		for clip: StringName in pool_sources[pool_name]:
			if clip_player != null and clip_player.has_animation(clip):
				available.append(clip)
		_pools[pool_name] = available
	var root: AnimationNodeBlendTree = animation_tree.tree_root as AnimationNodeBlendTree
	_has_idle_break = root != null and root.has_node(&"IdleBreak") and root.has_node(&"IdleBreakPick")
	if state_machine.current != null:
		_fsm_state = state_machine.current.name
	var mannequin: Node = animation_tree.get_parent()
	if mannequin != null:
		_aim_modifier = mannequin.get_node_or_null(AIM_MODIFIER_PATH) as AimPoseModifier
	state_machine.state_changed.connect(_on_state_changed)


## timeline_length of the tree's Slide node in seconds, 0 when the tree has none.
func _slide_window_length() -> float:
	var root: AnimationNodeBlendTree = animation_tree.tree_root as AnimationNodeBlendTree
	if root == null or not root.has_node(&"StateMachine"):
		return 0.0
	var machine: AnimationNodeStateMachine = root.get_node(&"StateMachine") as AnimationNodeStateMachine
	if machine == null or not machine.has_node(&"Slide"):
		return 0.0
	var node: AnimationNodeAnimation = machine.get_node(&"Slide") as AnimationNodeAnimation
	if node == null or not node.use_custom_timeline:
		return 0.0
	# Only the drop into the low pose is stretched to dash_time (metadata from the tree tool); the window rest holds it.
	return float(node.get_meta(&"drop_length", node.timeline_length))


## Length in seconds of the tree's Exit node (the whole clip, or its window), 0 when the tree has none.
func _aim_exit_length(clip_player: AnimationPlayer) -> float:
	var root: AnimationNodeBlendTree = animation_tree.tree_root as AnimationNodeBlendTree
	if root == null or not root.has_node(&"AimMachine"):
		return 0.0
	var machine: AnimationNodeStateMachine = root.get_node(&"AimMachine") as AnimationNodeStateMachine
	if machine == null or not machine.has_node(&"Exit"):
		return 0.0
	var node: AnimationNodeAnimation = machine.get_node(&"Exit") as AnimationNodeAnimation
	if node == null:
		return 0.0
	if node.use_custom_timeline:
		return node.timeline_length
	if clip_player != null and clip_player.has_animation(node.animation):
		return clip_player.get_animation(node.animation).length
	return 0.0


## Counts the air-dash hold down and hands over to the Fall loop when it runs out. The aim edge and the hand shot run
## first so they never depend on the hold.
func _physics_process(delta: float) -> void:
	_update_aim_edge(delta)
	if Input.is_action_just_pressed(&"use_hand"):
		play_hand_shot()
	_update_idle_break(delta)
	if slide_holding:
		_slide_hold_left -= delta
		if _slide_hold_left <= 0.0:
			slide_holding = false
			_travel_to(&"Locomotion")
	if not air_dash_holding:
		return
	_hold_left -= delta
	if _hold_left <= 0.0:
		air_dash_holding = false
		_travel_to(&"Fall")


## The aim press starts the spell hand at Enter on the physics frame the FSM's aiming flag turns true, the release travels
## to Exit and starts the exit countdown that keeps the layer up until the lowering has played.
func _update_aim_edge(delta: float) -> void:
	var aiming: bool = player.aiming
	if aiming and not _was_aiming:
		_exit_left = 0.0
		if _aim_machine != null:
			_aim_machine.start(&"Enter", true)
	elif not aiming and _was_aiming:
		_exit_left = _exit_length
		if _aim_machine != null:
			_aim_machine.travel(&"Exit")
	elif _exit_left > 0.0:
		_exit_left = maxf(_exit_left - delta, 0.0)
	_was_aiming = aiming


## Fires the Shoot OneShot of the spell hand. Only while aiming: outside aim the layer weight is 0 and hip-fire
## presentation is Phase 4. Stand-in until Phase 4 emits a hand fact (the hand does not exist yet): it is called from the
## use_hand poll in _physics_process.
func play_hand_shot() -> void:
	if player.aiming:
		animation_tree.set(P_SHOOT_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## The hold length in seconds (MovementConfig.air_dash_hold_time, live-tunable).
func air_dash_hold_time() -> float:
	return player.config.air_dash_hold_time


func _process(delta: float) -> void:
	if last_travel == &"Locomotion":
		_loco_target = _locomotion_target()
	_loco_blend = _loco_blend.move_toward(_loco_target, player.config.locomotion_blend_rate * delta)
	animation_tree.set(P_LOCOMOTION, _loco_blend)
	animation_tree.set(P_TIME_SCALE, clip_scale())
	var blend_time: float = maxf(player.config.aim_layer_blend_time, 0.001)
	aim_weight = move_toward(aim_weight, 1.0 if player.aiming else 0.0, delta / blend_time)
	var layer_target: float = 1.0 if (player.aiming or _exit_left > 0.0) else 0.0
	layer_weight = move_toward(layer_weight, layer_target, delta / blend_time)
	animation_tree.set(P_AIM, layer_weight)
	_feed_aim_modifier()


## Fades the arm solver with the aim weight and points it at the crosshair target point (D-11): the world point under
## the screen centre (CameraRig.aim_target_point()). The solver aims from the shoulder, so the hand lies on the
## shoulder-to-point line and the camera-to-character parallax is corrected. Without a rig the fallback is the camera
## origin plus forward times converge_distance.
func _feed_aim_modifier() -> void:
	if _aim_modifier == null:
		return
	_aim_modifier.influence = aim_weight
	if aim_weight <= 0.0:
		return
	var rig: CameraRig = player.camera_rig()
	if rig != null:
		_aim_modifier.set_aim_point(rig.aim_target_point())
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		_aim_modifier.set_aim_point(camera.global_position - camera.global_basis.z * _aim_modifier.converge_distance)


func _on_state_changed(from_state: StringName, to_state: StringName) -> void:
	_fsm_state = to_state
	_cancel_idle_break()
	var node: StringName = STATE_TO_ANIM.get(to_state, &"Locomotion")
	if node == &"Dash":
		var slide: bool = _dash_state != null and bool(_dash_state.get(&"slide"))
		node = dash_node_for(player.last_dash_direction, slide)
	if from_state == &"Dash" and last_travel == &"Slide" and (to_state == &"Run" or to_state == &"Idle"):
		# Keep the Slide node: the slide pose stays SLIDE_HOLD_TIME past the dash end (presentation only).
		slide_holding = true
		_slide_hold_left = SLIDE_HOLD_TIME
		air_dash_holding = false
	elif from_state == &"Dash" and to_state == &"Fall" and _dash_state != null and bool(_dash_state.get(&"in_air")):
		# Keep the dash node: the Dodge clip plays on and holds its last frame (DEV-02).
		air_dash_holding = true
		_hold_left = air_dash_hold_time()
	else:
		var was_holding: bool = air_dash_holding
		air_dash_holding = false
		slide_holding = false
		if node != last_travel:
			_travel_to(node)
		elif was_holding:
			# The held node is the new target (cannot happen with the shipped FSM): play it again from frame 0.
			_playback.start(node, true)
			last_travel_frame = Engine.get_physics_frames()
	_update_land(from_state, to_state)
	# Step the blend once on the same call so an Idle -> Run change shows a non-zero run weight on this frame.
	if node == &"Locomotion":
		_loco_target = _locomotion_target()
	var step: float = player.config.locomotion_blend_rate / float(Engine.physics_ticks_per_second)
	_loco_blend = _loco_blend.move_toward(_loco_target, step)
	animation_tree.set(P_LOCOMOTION, _loco_blend)
	# The clip speed changes with the node, so it is written on this same call as well.
	animation_tree.set(P_TIME_SCALE, clip_scale())


## Travels the state machine to `node` and records it with the physics frame of the request.
func _travel_to(node: StringName) -> void:
	_playback.travel(node)
	last_travel = node
	last_travel_frame = Engine.get_physics_frames()


## Landing into Idle fires the overlay. Any other change fades it, but only while it is running or about to run,
## so a move, jump or dash input never waits for the crouch. Landing into Run fires nothing.
func _update_land(from_state: StringName, to_state: StringName) -> void:
	if to_state == &"Idle" and AIRBORNE_STATES.has(from_state):
		animation_tree.set(P_LAND_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		return
	var pending: bool = int(animation_tree.get(P_LAND_REQUEST)) == AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	if bool(animation_tree.get(P_LAND_ACTIVE)) or pending:
		animation_tree.set(P_LAND_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


## The Locomotion BlendSpace2D target. Outside aim x is forced to 0 and y is the speed share of run_speed, so the facing
## lagging the input during a turn never shows strafe clips (D-09). While aiming the facing is the camera, so the
## velocity in the facing frame picks the clip: x strafe (left -1, right +1), y forward (back -1, forward +1). The
## divisor is the ground target speed of the current direction, so the aim run, which is slower than run_speed, still
## reaches the full run clip, and the slower back-pedal reaches the full backward clip.
func _locomotion_target() -> Vector2:
	if not player.aiming:
		var run_speed: float = maxf(player.config.run_speed, 0.001)
		return Vector2(0.0, clampf(player.horizontal_speed() / run_speed, 0.0, 1.0))
	var flat: Vector3 = Vector3(player.move_velocity.x, 0.0, player.move_velocity.z)
	var local: Vector3 = player.visual_root.global_basis.inverse() * flat
	# The Mannequin faces +Z and its left is +X, so a left strafe has positive local x and negative blend x.
	var divisor: float = maxf(player.ground_target_speed(flat.normalized()), 0.01)
	var target: Vector2 = Vector2(-local.x, local.z) / divisor
	return Vector2(clampf(target.x, -1.0, 1.0), clampf(target.y, -1.0, 1.0))


## The dash node for a dash in world-space `direction` (D-12). `slide` is Dash.slide: the unaimed ground dash is Slide
## (Running_Slide, DEV-04). Otherwise, outside aim, and for a near-zero direction, every dash is Dash (Dodge_Forward). While aiming the facing is the camera, so the dominant axis of the direction in the facing
## frame picks the clip: +Z Dash, -Z DashBack, +X DashLeft (the Mannequin's left is +X), -X DashRight.
func dash_node_for(direction: Vector3, slide: bool = false) -> StringName:
	if slide and not player.aiming:
		return &"Slide"
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if not player.aiming or flat.length_squared() < 0.0001:
		return &"Dash"
	var local: Vector3 = player.visual_root.global_basis.inverse() * flat
	if absf(local.x) > absf(local.z):
		return &"DashLeft" if local.x > 0.0 else &"DashRight"
	return &"Dash" if local.z >= 0.0 else &"DashBack"


## Playback speed of the whole state machine. A ground dash plays its Dodge clip in exactly dash_time; an air dash
## plays it at 1x, also during the DEV-02 pose hold (the node is still the dash node and in_air still true then), so
## the held pose never speeds up (D-02). In Locomotion the run clip plays faster with ground speed, between 1x and
## run_anim_max_scale. Everything else plays at 1x. A non-finite result falls back to 1.0 (T-03-11).
func clip_scale() -> float:
	var config: MovementConfig = player.config
	var result: float = 1.0
	if last_travel == &"Slide":
		result = SLIDE_PLAYBACK_SCALE
	elif DASH_CLIPS.has(last_travel):
		var in_air: bool = _dash_state != null and bool(_dash_state.get(&"in_air"))
		if not in_air:
			result = float(_dash_lengths.get(last_travel, 0.4)) / maxf(config.dash_time, 0.001)
	elif last_travel == &"Locomotion":
		result = clampf(player.horizontal_speed() / maxf(config.run_anim_ref_speed, 0.001), 1.0, maxf(config.run_anim_max_scale, 1.0))
	return result if is_finite(result) else 1.0


## The idle break clips this animator can play (the pool filtered to the library).
func idle_break_pool() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_pools.get(&"idle_break", []))
	return result


## A clip of the reserved reaction pool `kind` (&"hit", &"death", &"interact"), random without an immediate repeat;
## &"" for an unknown kind or an empty pool. No tree node plays these yet: Phase 4 and 6 add the states.
func pick_reaction(kind: StringName) -> StringName:
	if kind == &"idle_break" or not _pools.has(kind):
		return &""
	var options: Array[StringName] = []
	options.assign(_pools[kind])
	return _picker.pick(kind, options)


## Counts still time in Idle and fires an idle break at the rolled delay. Not counting while a break plays; any action,
## aim or a non-Idle state cancels on this same call.
func _update_idle_break(delta: float) -> void:
	if not _has_idle_break:
		return
	if _idle_break_fading and not bool(animation_tree.get(P_IDLE_BREAK_ACTIVE)):
		_idle_break_fading = false
	var pool: Array[StringName] = idle_break_pool()
	if pool.is_empty():
		return
	if _fsm_state != &"Idle" or player.aiming or _cancel_action_pressed():
		_cancel_idle_break()
		return
	if _idle_break_running():
		return
	if _idle_delay < 0.0:
		_idle_delay = _picker.delay(player.config.idle_break_delay_min, player.config.idle_break_delay_max)
	_idle_still += delta
	if _idle_still < _idle_delay:
		return
	var clip: StringName = _picker.pick(&"idle_break", pool)
	animation_tree.set(P_IDLE_BREAK_PICK, String(clip))
	animation_tree.set(P_IDLE_BREAK_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_idle_break_fading = false
	last_idle_break = clip
	last_idle_break_frame = Engine.get_physics_frames()
	_idle_still = 0.0
	_idle_delay = -1.0


## Resets the still count and fades a running or requested break out.
func _cancel_idle_break() -> void:
	_idle_still = 0.0
	_idle_delay = -1.0
	if _has_idle_break and _idle_break_running():
		animation_tree.set(P_IDLE_BREAK_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		_idle_break_fading = true
		idle_break_cancel_frame = Engine.get_physics_frames()


## True while the IdleBreak OneShot plays or a fire request is pending (not while it already fades out).
func _idle_break_running() -> bool:
	if int(animation_tree.get(P_IDLE_BREAK_REQUEST)) == AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE:
		return true
	return not _idle_break_fading and bool(animation_tree.get(P_IDLE_BREAK_ACTIVE))


func _cancel_action_pressed() -> bool:
	for action: StringName in IDLE_CANCEL_ACTIONS:
		if Input.is_action_pressed(action):
			return true
	return false
