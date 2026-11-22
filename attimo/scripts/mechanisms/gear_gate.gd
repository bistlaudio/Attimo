class_name GearGate
extends Mechanism
## Stub, filled in Task 3.


@export var slide_offset: Vector3 = Vector3(-4.2, 0.0, 0.0)


func is_open() -> bool:
	return false


func gate_aabb() -> AABB:
	return AABB()


func doorway_aabb() -> AABB:
	return AABB()
