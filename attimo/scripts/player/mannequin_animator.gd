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


func _ready() -> void:
	_playback = animation_tree.get(P_PLAYBACK) as AnimationNodeStateMachinePlayback
	last_travel = &"Locomotion"
	_dash_state = state_machine.get_node_or_null(^"Dash")
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
	animation_tree.set(P_TIME_SCALE, 1.0)
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


func _locomotion_target() -> Vector2:
	var run_speed: float = maxf(player.config.run_speed, 0.001)
	return Vector2(0.0, clampf(player.horizontal_speed() / run_speed, 0.0, 1.0))
