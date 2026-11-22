class_name GearGate
extends Mechanism
## Zahnrad-Tor (MECH-01): a round gate that rolls aside along its local -X while the signal is on and back when it is off
## (D-19). It never closes while the player stands in the doorway: it waits and closes once the doorway is clear.
## Frame: the disc lies in the local XY plane, the passage runs along local Z.

const DISC_RADIUS: float = 2.0
## Fully open from this progress on.
const OPEN_THRESHOLD: float = 0.99

## Seconds a full open or close takes.
@export_range(0.05, 2.0, 0.05) var open_time: float = 0.3
## Local offset of the open gate; wholly outside the doorway box.
@export var slide_offset: Vector3 = Vector3(-4.2, 0.0, 0.0)

var _progress: float = 0.0
var _closed_position: Vector3 = Vector3.ZERO

@onready var _gate: AnimatableBody3D = $Gate
@onready var _disc: Node3D = $Gate/DiscPivot
@onready var _doorway: Area3D = $Doorway


func _ready() -> void:
	_closed_position = _gate.position
	_gate.sync_to_physics = true
	super._ready()


func _physics_process(delta: float) -> void:
	var goal: float = 1.0 if signal_on else 0.0
	if goal == 0.0 and _progress > 0.0 and _player_in_doorway():
		goal = 1.0
	_progress = move_toward(_progress, goal, delta / maxf(open_time, 0.01))
	_apply()


func is_open() -> bool:
	return _progress >= OPEN_THRESHOLD


func reset() -> void:
	super.reset()
	_progress = 0.0
	_apply()
	_gate.reset_physics_interpolation()


## The gate collision box in world space.
func gate_aabb() -> AABB:
	return _box_aabb($Gate/CollisionShape3D as CollisionShape3D)


## The doorway box in world space.
func doorway_aabb() -> AABB:
	return _box_aabb($Doorway/CollisionShape3D as CollisionShape3D)


func _box_aabb(shape_node: CollisionShape3D) -> AABB:
	var box: BoxShape3D = shape_node.shape as BoxShape3D
	return shape_node.global_transform * AABB(-box.size * 0.5, box.size)


func _player_in_doorway() -> bool:
	for body: Node3D in _doorway.get_overlapping_bodies():
		if body is PlayerController:
			return true
	return false


func _apply() -> void:
	var eased: float = smoothstep(0.0, 1.0, _progress)
	_gate.position = _closed_position + slide_offset * eased
	_disc.rotation.z = slide_offset.length() * eased / DISC_RADIUS
