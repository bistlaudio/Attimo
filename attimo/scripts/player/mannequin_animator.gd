class_name MannequinAnimator
extends Node
## Presents FSM state on the Mannequin: maps the LOCAL StateMachine.state_changed signal to AnimationTree travel,
## the Locomotion blend and the Land overlay. Animation shows state; it is not feedback in the D-10 sense.
## The tree root is a BlendTree (tools/build_mannequin_tree.gd): StateMachine -> TimeScale -> Land OneShot -> output.
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

## The clip the dash node plays; its length is stretched to dash_time.
const DODGE_CLIP: StringName = &"Dodge_Forward"

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
## Weight of the upper-body aim layer, 0 (locomotion only) to 1 (aim pose), eased over aim_layer_blend_time.
var aim_weight: float = 0.0

var _playback: AnimationNodeStateMachinePlayback
var _loco_blend: Vector2 = Vector2.ZERO
var _loco_target: Vector2 = Vector2.ZERO
var _hold_left: float = 0.0
var _dash_state: Node
## Length in seconds of the Dodge_Forward clip, read once; the dash clip is stretched to dash_time (Pitfall 6).
var _dodge_length: float = 0.4


func _ready() -> void:
	_playback = animation_tree.get(P_PLAYBACK) as AnimationNodeStateMachinePlayback
	last_travel = &"Locomotion"
	_dash_state = state_machine.get_node_or_null(^"Dash")
	var clip_player: AnimationPlayer = animation_tree.get_node_or_null(animation_tree.anim_player) as AnimationPlayer
	if clip_player != null and clip_player.has_animation(DODGE_CLIP):
		_dodge_length = clip_player.get_animation(DODGE_CLIP).length
	state_machine.state_changed.connect(_on_state_changed)


## Counts the air-dash hold down and hands over to the Fall loop when it runs out.
func _physics_process(delta: float) -> void:
	if not air_dash_holding:
		return
	_hold_left -= delta
	if _hold_left <= 0.0:
		air_dash_holding = false
		_travel_to(&"Fall")


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
	animation_tree.set(P_AIM, aim_weight)


func _on_state_changed(from_state: StringName, to_state: StringName) -> void:
	var node: StringName = STATE_TO_ANIM.get(to_state, &"Locomotion")
	if from_state == &"Dash" and to_state == &"Fall" and _dash_state != null and bool(_dash_state.get(&"in_air")):
		# Keep the dash node: the Dodge clip plays on and holds its last frame (DEV-02).
		air_dash_holding = true
		_hold_left = air_dash_hold_time()
	else:
		var was_holding: bool = air_dash_holding
		air_dash_holding = false
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


## Playback speed of the whole state machine. A ground dash plays its Dodge clip in exactly dash_time; an air dash
## plays it at 1x, also during the DEV-02 pose hold (the node is still the dash node and in_air still true then), so
## the held pose never speeds up (D-02). In Locomotion the run clip plays faster with ground speed, between 1x and
## run_anim_max_scale. Everything else plays at 1x. A non-finite result falls back to 1.0 (T-03-11).
func clip_scale() -> float:
	var config: MovementConfig = player.config
	var result: float = 1.0
	if last_travel == &"Dash":
		var in_air: bool = _dash_state != null and bool(_dash_state.get(&"in_air"))
		if not in_air:
			result = _dodge_length / maxf(config.dash_time, 0.001)
	elif last_travel == &"Locomotion":
		result = clampf(player.horizontal_speed() / maxf(config.run_anim_ref_speed, 0.001), 1.0, maxf(config.run_anim_max_scale, 1.0))
	return result if is_finite(result) else 1.0
