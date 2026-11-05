class_name MovingPlatform
extends AnimatableBody3D
## A gym helper: a platform that moves on a fixed path so the movement tests and the movement gym can
## prove platform carry (MOVE-08, D-13). Phase 4 builds the real mechanisms; this is not one of them.
## It moves only inside the physics tick with sync_to_physics on, so the engine reports its velocity to
## the CharacterBody3D standing on it.

enum Mode { LINEAR, CIRCLE }

@export var mode: Mode = Mode.LINEAR
## LINEAR: the platform ping-pongs between its start and start + travel.
@export var travel: Vector3 = Vector3(8.0, 0.0, 0.0)
## Speed in m/s along the path (LINEAR) or tangential (CIRCLE).
@export_range(0.1, 20.0, 0.1) var speed: float = 3.0
## CIRCLE: the circle's centre is start - Vector3(radius, 0, 0).
@export_range(0.5, 50.0, 0.1) var radius: float = 4.0

var _start: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0


func _ready() -> void:
	sync_to_physics = true
	add_to_group(&"moving_platform")
	_start = global_position


func _physics_process(delta: float) -> void:
	_elapsed += delta
	match mode:
		Mode.LINEAR:
			var length: float = travel.length()
			if length < 0.0001:
				return
			global_position = _start + travel / length * pingpong(_elapsed * speed, length)
		Mode.CIRCLE:
			var centre: Vector3 = _start - Vector3(radius, 0.0, 0.0)
			var angle: float = _elapsed * speed / radius
			global_position = centre + Vector3(cos(angle), 0.0, sin(angle)) * radius
