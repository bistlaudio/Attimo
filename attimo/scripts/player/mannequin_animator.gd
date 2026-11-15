class_name MannequinAnimator
extends Node
## Presents FSM state on the Mannequin: maps the LOCAL StateMachine.state_changed signal to AnimationTree travel,
## the Locomotion blend and the Land overlay. Animation shows state; it is not feedback in the D-10 sense.
## The tree root is a BlendTree (tools/build_mannequin_tree.gd): StateMachine -> TimeScale -> Land OneShot -> output.

## Parameter paths of the generated tree. Tests and later layers read them through these constants.
const P_PLAYBACK: StringName = &"parameters/StateMachine/playback"
const P_LOCOMOTION: StringName = &"parameters/StateMachine/Locomotion/blend_position"
const P_TIME_SCALE: StringName = &"parameters/TimeScale/scale"
const P_LAND_REQUEST: StringName = &"parameters/Land/request"
const P_LAND_ACTIVE: StringName = &"parameters/Land/active"

## Locomotion blend speed in blend units per second (idle 0 .. run 1). Moves into MovementConfig in 03-07.
const LOCO_BLEND_RATE: float = 10.0

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

var _playback: AnimationNodeStateMachinePlayback
var _loco_blend: Vector2 = Vector2.ZERO
var _loco_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	_playback = animation_tree.get(P_PLAYBACK) as AnimationNodeStateMachinePlayback
	last_travel = &"Locomotion"
	state_machine.state_changed.connect(_on_state_changed)


func _process(delta: float) -> void:
	if last_travel == &"Locomotion":
		_loco_target = _locomotion_target()
	_loco_blend = _loco_blend.move_toward(_loco_target, LOCO_BLEND_RATE * delta)
	animation_tree.set(P_LOCOMOTION, _loco_blend)
	animation_tree.set(P_TIME_SCALE, 1.0)


func _on_state_changed(from_state: StringName, to_state: StringName) -> void:
	var node: StringName = STATE_TO_ANIM.get(to_state, &"Locomotion")
	if node != last_travel:
		_playback.travel(node)
		last_travel = node
		last_travel_frame = Engine.get_physics_frames()
	_update_land(from_state, to_state)
	# Step the blend once on the same call so an Idle -> Run change shows a non-zero run weight on this frame.
	if node == &"Locomotion":
		_loco_target = _locomotion_target()
	var step: float = LOCO_BLEND_RATE / float(Engine.physics_ticks_per_second)
	_loco_blend = _loco_blend.move_toward(_loco_target, step)
	animation_tree.set(P_LOCOMOTION, _loco_blend)


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
