class_name WindTunnel
extends Mechanism
## Wind tunnel (MECH-04 J, D-06): a box volume with a steady wind along its local -Z. The wind carries jumps farther (tailwind) or
## shortens them (headwind). Default behaviour REVERSE_ON_SIGNAL: the wind always blows and the signal flips its direction
## (RUN_WHILE_ON blows only while the signal is on). Per tick it calls PlayerController.push_toward for each overlapping player;
## this script never writes the player's velocity (D-06).

## Volume size in m: x and z centred on the node, y from the floor up. The long axis is z.
@export var size: Vector3 = Vector3(6.0, 6.0, 16.0)
## Target speed along the wind and the acceleration toward it.
@export_range(1.0, 30.0, 0.5) var wind_speed: float = 14.0
## wind_accel must beat the air control (air_accel 45) or a held run key cancels a headwind.
@export_range(1.0, 120.0, 1.0) var wind_accel: float = 60.0

@onready var _volume: Area3D = $Volume
@onready var _chevrons: Node3D = $Chevrons


func _ready() -> void:
	_volume.collision_layer = 0
	_volume.collision_mask = PhysicsLayers.PLAYER
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	var shape_node: CollisionShape3D = $Volume/CollisionShape3D as CollisionShape3D
	shape_node.shape = box
	shape_node.position = Vector3(0.0, size.y * 0.5, 0.0)
	var half_x: float = size.x * 0.5
	var half_z: float = size.z * 0.5
	($PostNW as Node3D).position = Vector3(-half_x, 0.0, -half_z)
	($PostNE as Node3D).position = Vector3(half_x, 0.0, -half_z)
	($PostSW as Node3D).position = Vector3(-half_x, 0.0, half_z)
	($PostSE as Node3D).position = Vector3(half_x, 0.0, half_z)
	_apply_chevrons()
	super._ready()


func _physics_process(_delta: float) -> void:
	if not is_active():
		return
	var direction: Vector3 = wind_direction()
	for body: Node3D in _volume.get_overlapping_bodies():
		var player: PlayerController = body as PlayerController
		if player != null:
			player.push_toward(direction, wind_speed, wind_accel)


## True while the wind blows: the signal is on, or always for REVERSE_ON_SIGNAL.
func is_active() -> bool:
	return behaviour == Behaviour.REVERSE_ON_SIGNAL or signal_on


## World direction of the wind: local -Z, flipped while the signal is on under REVERSE_ON_SIGNAL.
func wind_direction() -> Vector3:
	var forward: Vector3 = Vector3(-global_basis.z.x, 0.0, -global_basis.z.z).normalized()
	if behaviour == Behaviour.REVERSE_ON_SIGNAL and signal_on:
		forward = -forward
	return forward


func reset() -> void:
	super.reset()
	_apply_chevrons()


func _on_signal(_on: bool) -> void:
	_apply_chevrons()


func _apply_chevrons() -> void:
	_chevrons.visible = is_active()
	var flipped: bool = behaviour == Behaviour.REVERSE_ON_SIGNAL and signal_on
	_chevrons.rotation = Vector3(0.0, PI if flipped else 0.0, 0.0)
