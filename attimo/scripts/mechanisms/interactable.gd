class_name Interactable
extends Node
## Stub, filled in Task 2.

signal triggered(hit: PulseHit)
signal near_started()
signal near_held(delta: float)
signal near_ended()

@export var accepted_modules: Array[StringName] = [&"remote_trigger"]
@export var accepts_shot: bool = true
@export var accepts_near: bool = false
@export var min_pulse: PulseHit.Size = PulseHit.Size.SMALL
@export var hit_body: CollisionObject3D
@export var aim_point: Node3D
@export var glow_meshes: Array[MeshInstance3D] = []


func accepts_module(_id: StringName) -> bool:
	return false


func can_accept(_kind: PulseHit.Kind, _size: PulseHit.Size) -> bool:
	return false


func try_trigger(_hit: PulseHit) -> bool:
	return false


func near_begin() -> bool:
	return false


func near_hold(_delta: float) -> void:
	pass


func near_end() -> void:
	pass


func target_point() -> Vector3:
	return Vector3.ZERO


static func from_collider(_collider: Object) -> Interactable:
	return null
