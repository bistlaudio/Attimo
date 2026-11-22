class_name Pendulum
extends Mechanism
## Pendel (MECH-03, D-21): a swinging arm with a cube bob. The Hit area on the bob knocks the player away hard in the swing
## direction with an upward part (the pendulum supplies it, Pitfall 5), interrupts a dash, can throw the player off a platform and
## deals no damage (Phase 6 adds damage). Frame: this node stands on the floor, the pivot is ARM_PIVOT_HEIGHT above it, the arm
## swings in the local XY plane. RUN_WHILE_ON swings while the signal is on and eases to a stop at the bottom,
## REVERSE_ON_SIGNAL always swings and the signal reverses the swing direction. The knock goes through call_deferred.

## Height of the pivot above this node.
const ARM_PIVOT_HEIGHT: float = 5.0
## Seconds a start or a reversal takes.
const RAMP_TIME: float = 0.4
## A bob slower than this (rad/s) does not knock.
const MIN_KNOCK_OMEGA: float = 0.1

@export_range(10.0, 80.0, 1.0) var swing_deg: float = 60.0
## Seconds of one full swing there and back.
@export_range(0.5, 8.0, 0.1) var period: float = 2.4
@export_range(1.0, 30.0, 0.5) var knock_strength: float = 10.0
@export_range(0.0, 15.0, 0.5) var knock_up: float = 4.0
## Seconds before the same pendulum may knock again.
@export_range(0.0, 3.0, 0.05) var rehit_cooldown: float = 0.5

var _phase: float = 0.0
var _factor: float = 0.0
var _angle: float = 0.0
var _omega: float = 0.0
var _rehit_timer: float = 0.0

@onready var _arm: AnimatableBody3D = $Arm
@onready var _hit: Area3D = $Arm/Hit


func _ready() -> void:
	_arm.sync_to_physics = true
	_hit.collision_layer = PhysicsLayers.HAZARD
	_hit.collision_mask = PhysicsLayers.PLAYER
	_hit.body_entered.connect(_on_body_entered)
	_apply()
	super._ready()


func _physics_process(delta: float) -> void:
	_rehit_timer = maxf(_rehit_timer - delta, 0.0)
	var rate: float = TAU / maxf(period, 0.1)
	var running: bool = behaviour == Behaviour.REVERSE_ON_SIGNAL or signal_on
	if running:
		var wanted: float = 1.0
		if behaviour == Behaviour.REVERSE_ON_SIGNAL and signal_on:
			wanted = -1.0
		_factor = move_toward(_factor, wanted, delta / RAMP_TIME)
		_phase = wrapf(_phase + rate * _factor * delta, -PI, PI)
	elif _factor != 0.0:
		_settle(rate, delta)
	var previous: float = _angle
	_angle = deg_to_rad(swing_deg) * sin(_phase)
	_omega = (_angle - previous) / maxf(delta, 0.0001)
	_apply()
	if _rehit_timer <= 0.0 and absf(_omega) > MIN_KNOCK_OMEGA:
		for body: Node3D in _hit.get_overlapping_bodies():
			_try_knock(body)


## Current signed angle of the arm in radians.
func current_angle() -> float:
	return _angle


func reset() -> void:
	super.reset()
	_phase = 0.0
	_factor = 0.0
	_angle = 0.0
	_omega = 0.0
	_rehit_timer = 0.0
	_apply()
	_arm.reset_physics_interpolation()


## Signal off: keep swinging in the same direction, slow down toward the next bottom (a multiple of PI in the phase) and stop there.
func _settle(rate: float, delta: float) -> void:
	var direction: float = signf(_factor)
	var ahead: float = _phase * direction
	var remaining: float = ceilf(ahead / PI - 0.0001) * PI - ahead
	var desired: float = clampf(remaining / (PI * 0.5), 0.0, 1.0) * direction
	_factor = move_toward(_factor, desired, delta / RAMP_TIME)
	var step: float = rate * absf(_factor) * delta
	if remaining < 0.02 or step >= remaining:
		_phase = wrapf(_phase + direction * remaining, -PI, PI)
		_factor = 0.0
	else:
		_phase = wrapf(_phase + direction * step, -PI, PI)


func _apply() -> void:
	_arm.position = Vector3(0.0, ARM_PIVOT_HEIGHT, 0.0)
	_arm.rotation = Vector3(0.0, 0.0, _angle)


func _on_body_entered(body: Node3D) -> void:
	if _rehit_timer <= 0.0 and absf(_omega) > MIN_KNOCK_OMEGA:
		_try_knock(body)


## Knock direction: the swing tangent at the bob, flattened. The impulse is that direction times knock_strength plus knock_up.
func _try_knock(body: Node3D) -> void:
	var player: PlayerController = body as PlayerController
	if player == null:
		return
	var tangent: Vector3 = _arm.global_basis * Vector3(cos(_angle), sin(_angle), 0.0) * signf(_omega)
	tangent.y = 0.0
	if tangent.length_squared() < 0.0001:
		return
	_rehit_timer = rehit_cooldown
	player.call_deferred(&"knock_back", tangent.normalized() * knock_strength + Vector3.UP * knock_up)
