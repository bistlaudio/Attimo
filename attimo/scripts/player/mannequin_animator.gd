class_name MannequinAnimator
extends Node
## Presents FSM state on the Mannequin: maps the LOCAL StateMachine.state_changed signal to AnimationTree travel,
## the Locomotion blend and the Land overlay. Animation shows state; it is not feedback in the D-10 sense.
## The tree root is a BlendTree (tools/build_mannequin_tree.gd): StateMachine -> TimeScale -> Land OneShot -> Aim
## (upper-body layer) -> output. The state machine has one dash node per Dodge clip; dash_node_for() picks it (the aimed nodes are dormant).
## The upper-body layer is the arm (quick 261118-qi3, driven by HandController.arm_out since phase 05, D-27): when the hand reports
## the arm stretched out (near contact, a shot, the Loader hold) the AimMachine starts at Enter on the same physics frame, Hold
## loops while the arm is out, a pulse_fired fires the Shoot OneShot, the arm coming back travels to Exit and the layer fades
## out after the Exit clip. There is no aim hold any more; the layer stays until the Phase 6 hand poses replace it.
## Idle breaks (quick 261118-qi3): standing still in Idle for a rolled delay (MovementConfig idle_break_delay_min/max)
## fires the IdleBreak OneShot with a clip picked by a VariantPicker (never the same one twice in a row). Any gameplay
## action or state change fades it out on that same physics frame; the FSM never waits for it.
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
## The landing variant of the Land overlay (inputs soft, hard, roll) and the input it shows.
const P_LAND_PICK: StringName = &"parameters/LandPick/transition_request"
const P_LAND_PICK_STATE: StringName = &"parameters/LandPick/current_state"
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
const IDLE_CANCEL_ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"dash", &"loader", &"use_hand", &"interact"]
## The AimPoseModifier node, relative to the Mannequin node (the AnimationTree's parent).
const AIM_MODIFIER_PATH: NodePath = ^"Rig_Medium/Skeleton3D/AimPoseModifier"

## The dash nodes that take the dash crossfades (dash_in_blend, dash_in_blend_air, dash_out_blend). Slide keeps its own edges.
const DASH_NODES: Array[StringName] = [&"Dash", &"DashLeft", &"DashRight", &"DashBack"]

## The dash nodes of the state machine and the Dodge clip each plays; the clip length is stretched to dash_time.
## Dash is the ground and the air dash; DashLeft, DashRight and DashBack are dormant tree nodes (there is no aimed dash any more, D-27). Slide is the unaimed ground
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
	&"LongJump": &"LongJump",
	&"Fall": &"Fall",
	&"Dash": &"Dash",
	&"WallRun": &"Locomotion",
	&"WallJump": &"Jump",
	&"Capture": &"Fall",
	&"Loader": &"Fall",
}

## States that count as airborne for the landing check (Landing into Idle plays the Land overlay).
const AIRBORNE_STATES: Array[StringName] = [&"Jump", &"Fall", &"LongJump", &"WallJump"]

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
## Weight of the upper-body arm layer, 0 (locomotion only) to 1 (arm pose), eased over aim_layer_blend_time.
var aim_weight: float = 0.0
## Weight of the Aim layer in the tree (P_AIM, read-only for others): 1 while the arm is out and while the Exit clip lowers the
## hand, eased at the aim_weight rate. aim_weight is the solver influence, this is the pose layer.
var layer_weight: float = 0.0
## The clip of the last idle break and the physics frame it fired on; the frame of the last break cancel (read-only).
var last_idle_break: StringName = &""
var last_idle_break_frame: int = -1
var idle_break_cancel_frame: int = -1
## The kind of the last landing overlay (&"soft", &"hard", &"roll") and the landing it was chosen from (read-only).
var last_land_kind: StringName = &""
var last_impact_speed: float = 0.0
var last_landing_horizontal_speed: float = 0.0

var _playback: AnimationNodeStateMachinePlayback
## The hand of this player (read only): arm_out raises the arm layer, arm_out_point is where the arm points.
var _hand: HandController
## The spell hand state machine (Enter, Hold, Exit) inside the Aim layer; null when the tree has none.
var _aim_machine: AnimationNodeStateMachinePlayback
var _was_arm_out: bool = false
## Seconds of the Exit clip still to play after the arm came back; the layer stays at weight 1 until it has run out.
var _exit_left: float = 0.0
var _exit_length: float = 0.0
var _picker: VariantPicker
## Pool name to the clips of that pool the library has.
var _pools: Dictionary[StringName, Array] = {}
var _fsm_state: StringName = &""
var _has_idle_break: bool = false
var _has_jump2: bool = false
var _has_sprint: bool = false
## The facts of the EventBus.landed of this player, consumed by the next landing state change.
var _landed_pending: bool = false
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
## The state machine's direct edges by "from>to" (one per ordered pair), so the dash crossfades can be set per travel.
var _edges: Dictionary[StringName, AnimationNodeStateMachineTransition] = {}


func _ready() -> void:
	_playback = animation_tree.get(P_PLAYBACK) as AnimationNodeStateMachinePlayback
	if _playback == null:
		push_warning("MannequinAnimator: AnimationTree has no StateMachine playback; state travel is off")
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
	_hand = player.get_node_or_null(^"HandController") as HandController
	state_machine.state_changed.connect(_on_state_changed)
	EventBus.landed.connect(_on_landed)
	EventBus.pulse_fired.connect(_on_pulse_fired)
	var tree_root: AnimationNodeBlendTree = animation_tree.tree_root as AnimationNodeBlendTree
	if tree_root != null and tree_root.has_node(&"StateMachine"):
		var machine: AnimationNodeStateMachine = tree_root.get_node(&"StateMachine") as AnimationNodeStateMachine
		_has_jump2 = machine.has_node(&"Jump2")
		for i: int in machine.get_transition_count():
			_edges[StringName("%s>%s" % [machine.get_transition_from(i), machine.get_transition_to(i)])] = machine.get_transition(i)
		var locomotion: AnimationNodeBlendSpace2D = machine.get_node(&"Locomotion") as AnimationNodeBlendSpace2D
		_has_sprint = locomotion != null and locomotion.max_space.y > 1.0


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


## The arm going out (HandController.arm_out: near contact, a shot, the Loader hold) starts the spell hand at Enter on the
## physics frame it turns true, the arm coming back travels to Exit and starts the exit countdown that keeps the layer up until
## the lowering has played.
func _update_aim_edge(delta: float) -> void:
	var arm_out: bool = _arm_up()
	if arm_out and not _was_arm_out:
		_exit_left = 0.0
		if _aim_machine != null:
			_aim_machine.start(&"Enter", true)
	elif not arm_out and _was_arm_out:
		_exit_left = _exit_length
		if _aim_machine != null:
			_aim_machine.travel(&"Exit")
	elif _exit_left > 0.0:
		_exit_left = maxf(_exit_left - delta, 0.0)
	_was_arm_out = arm_out


## The shot of the hand happened (EventBus.pulse_fired, on release after charge and cooldown): fire the Shoot OneShot.
func _on_pulse_fired(_origin: Vector3, _point: Vector3, _size: int, _hit_valid: bool) -> void:
	play_hand_shot()


## True while the arm layer is up: the hand reports the arm stretched out (near contact, a shot, the Loader hold; D-27). Only the
## Aim layer weight and the solver target use it.
func _arm_up() -> bool:
	return _hand != null and _hand.arm_out


## Fires the Shoot OneShot of the spell hand.
func play_hand_shot() -> void:
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
	# The arm layer blends in real time, so the Loader hold (a slow world) raises the arm as fast as any other moment.
	var real: float = TimeFx.unscaled(delta)
	var blend_time: float = maxf(player.config.aim_layer_blend_time, 0.001)
	var arm_up: bool = _arm_up()
	aim_weight = move_toward(aim_weight, 1.0 if arm_up else 0.0, real / blend_time)
	var layer_target: float = 1.0 if (arm_up or _exit_left > 0.0) else 0.0
	layer_weight = move_toward(layer_weight, layer_target, real / blend_time)
	animation_tree.set(P_AIM, layer_weight)
	_feed_aim_modifier()


## Fades the arm solver with the arm weight and points it at HandController.arm_out_point (the near target, the last shot point or
## the crosshair point during the Loader hold). The solver aims from the shoulder, so the hand lies on the shoulder-to-point line
## and the camera-to-character parallax is corrected. Without a hand the fallback is the crosshair target point of the rig, and
## without a rig the camera origin plus forward times converge_distance.
func _feed_aim_modifier() -> void:
	if _aim_modifier == null:
		return
	_aim_modifier.influence = aim_weight
	if aim_weight <= 0.0:
		return
	if _hand != null:
		_aim_modifier.set_aim_point(_hand.arm_out_point)
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
	if to_state == &"Jump" and player.chain_stage == 2 and _has_jump2:
		# Jump 2 of the ground chain has its own take (chain_stage is set before state_changed fires).
		node = &"Jump2"
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
			if _playback != null:
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
	# _playback is null when the tree is inactive or has no StateMachine node; the rest of the handler must still run (WR-03).
	if _playback != null:
		apply_blend(_playback.get_current_node(), node)
		_playback.travel(node)
	last_travel = node
	last_travel_frame = Engine.get_physics_frames()


## The crossfade in seconds the edge `from_node` to `to_node` should use, or -1 to keep the tree's own value. Into a dash
## clip: dash_in_blend from the ground locomotion, dash_in_blend_air from a jump, long jump or fall. Out of a dash clip:
## dash_out_blend. Slide keeps its own edges (quick 261120-dik).
func blend_time_for(from_node: StringName, to_node: StringName) -> float:
	var config: MovementConfig = player.config
	if from_node == &"Slide" or to_node == &"Slide":
		return -1.0
	if DASH_NODES.has(from_node):
		return config.dash_out_blend
	if DASH_NODES.has(to_node):
		return config.dash_in_blend if from_node == &"Locomotion" else config.dash_in_blend_air
	return -1.0


## Writes the crossfade of the edge `from_node` to `to_node` just before the travel (live-tunable: the F2 sliders change the
## config, the next travel picks it up). The tree resource is shared, but every writer uses the same config. Presentation only.
func apply_blend(from_node: StringName, to_node: StringName) -> void:
	var blend: float = blend_time_for(from_node, to_node)
	if blend < 0.0:
		return
	var edge: AnimationNodeStateMachineTransition = _edges.get(StringName("%s>%s" % [from_node, to_node]))
	if edge != null:
		edge.xfade_time = blend


## Remembers the impact and the horizontal speed of this player's touchdown (EventBus.landed fires one tick before the
## air state hands over to Idle or Run).
func _on_landed(_position: Vector3, impact_speed: float) -> void:
	last_impact_speed = impact_speed
	last_landing_horizontal_speed = player.horizontal_speed()
	_landed_pending = true


## The landing overlay kind: &"roll" from roll_landing_speed horizontally, else &"hard" from hard_landing_speed impact,
## else &"soft" into Idle, else &"" (no overlay). Presentation only (D-08): the overlay never locks control.
func landing_kind(impact_speed: float, horizontal_speed: float, to_state: StringName) -> StringName:
	var config: MovementConfig = player.config
	var branches: Array[Dictionary] = [
		{"when": horizontal_speed >= config.roll_landing_speed, "options": [&"roll"] as Array[StringName]},
		{"when": impact_speed >= config.hard_landing_speed, "options": [&"hard"] as Array[StringName]},
		{"when": to_state == &"Idle", "options": [&"soft"] as Array[StringName]},
	]
	return _picker.pick_first(&"landing", branches)


## A landing (airborne state to Idle or Run) with a kind fires the overlay with that LandPick input. Any other change
## fades it, but only while it is running or about to run, so a move, jump or dash input never waits for it (D-08).
func _update_land(from_state: StringName, to_state: StringName) -> void:
	if AIRBORNE_STATES.has(from_state) and (to_state == &"Idle" or to_state == &"Run"):
		var impact: float = last_impact_speed if _landed_pending else 0.0
		var horizontal: float = last_landing_horizontal_speed if _landed_pending else player.horizontal_speed()
		_landed_pending = false
		var kind: StringName = landing_kind(impact, horizontal, to_state)
		if kind != &"":
			last_land_kind = kind
			animation_tree.set(P_LAND_PICK, String(kind))
			animation_tree.set(P_LAND_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			return
	var pending: bool = int(animation_tree.get(P_LAND_REQUEST)) == AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	if bool(animation_tree.get(P_LAND_ACTIVE)) or pending:
		animation_tree.set(P_LAND_REQUEST, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


## The Locomotion BlendSpace2D target. x is forced to 0 and y is the speed share of run_speed, so the facing lagging the input
## during a turn never shows strafe clips (D-09). The strafe and backwards points of the tree stay dormant (aim strafe is gone).
func _locomotion_target() -> Vector2:
	return Vector2(0.0, locomotion_y_for(player.horizontal_speed()))


## The unaimed Locomotion blend y for a horizontal speed: speed / run_speed up to 1 (Running_A), then rising toward 2
## (UAL Sprint_Loop) between run_speed and sprint_anim_full_speed. The sprint range exists only when the tree has the
## sprint point. There is no sprint input and no sprint state: only dash and dash-hop momentum get there.
func locomotion_y_for(speed: float) -> float:
	var config: MovementConfig = player.config
	var run_speed: float = maxf(config.run_speed, 0.001)
	if speed <= run_speed or not _has_sprint:
		return clampf(speed / run_speed, 0.0, 1.0)
	var span: float = maxf(config.sprint_anim_full_speed - run_speed, 0.001)
	return 1.0 + clampf((speed - run_speed) / span, 0.0, 1.0)


## The dash node: Slide for a dash shown as the slide (Dash.slide, Running_Slide, DEV-04), otherwise Dash (Dodge_Forward). The
## DashLeft, DashRight and DashBack nodes are dormant tree nodes since the aim strafe is gone (D-27).
func dash_node_for(_direction: Vector3, slide: bool = false) -> StringName:
	if slide:
		return &"Slide"
	return &"Dash"


## Playback speed of the whole state machine. A ground dash plays its Dodge clip in exactly dash_time; an air dash
## plays it at 1x, also during the DEV-02 pose hold (the node is still the dash node and in_air still true then), so
## the held pose never speeds up (D-02). In Locomotion the run clip plays faster with ground speed, between 1x and
## run_anim_max_scale, with the speed capped at run_speed (above it the Sprint_Loop blend carries the extra speed).
## Everything else plays at 1x. A non-finite result falls back to 1.0 (T-03-11).
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
		var speed: float = minf(player.horizontal_speed(), config.run_speed)
		result = clampf(speed / maxf(config.run_anim_ref_speed, 0.001), 1.0, maxf(config.run_anim_max_scale, 1.0))
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


## Counts still time in Idle and fires an idle break at the rolled delay. Not counting while a break plays; any action
## or a non-Idle state cancels on this same call.
func _update_idle_break(delta: float) -> void:
	if not _has_idle_break:
		return
	if _idle_break_fading and not bool(animation_tree.get(P_IDLE_BREAK_ACTIVE)):
		_idle_break_fading = false
	var pool: Array[StringName] = idle_break_pool()
	if pool.is_empty():
		return
	if _fsm_state != &"Idle" or _cancel_action_pressed():
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
