class_name LowGravityZone
extends Mechanism
## Schwerkraft-Zone (MECH-04 K, D-06): a box volume in which gravity is scaled down, so jumps become high, far and slow. Active
## means the signal is on (RUN_WHILE_ON) or always (REVERSE_ON_SIGNAL). While active, every tick it asks each overlapping player
## for a lower gravity through PlayerController.request_gravity_scale. The request is per tick and cleared by the player after its
## move, so leaving the zone needs no restore step. This script never writes the player's velocity or gravity_scale (D-06).

## Gravity factor inside the zone (1.0 = normal). The player clamps it to 0.05..1.0.
@export_range(0.05, 1.0, 0.05) var low_gravity_scale: float = 0.35
## Volume size in m: x and z centred on the node, y from the floor up.
@export var size: Vector3 = Vector3(10.0, 12.0, 10.0)

@onready var _volume: Area3D = $Volume
@onready var _field: Node3D = $Field


func _ready() -> void:
	_volume.collision_layer = 0
	_volume.collision_mask = PhysicsLayers.PLAYER
	var shape_node: CollisionShape3D = $Volume/CollisionShape3D as CollisionShape3D
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	shape_node.position = Vector3(0.0, size.y * 0.5, 0.0)
	_layout_visuals()
	_field.visible = is_active()
	super._ready()


func _physics_process(_delta: float) -> void:
	if not is_active():
		return
	for body: Node3D in _volume.get_overlapping_bodies():
		var player: PlayerController = body as PlayerController
		if player != null:
			player.request_gravity_scale(low_gravity_scale)


## True while the zone acts: the signal is on, or always for REVERSE_ON_SIGNAL.
func is_active() -> bool:
	return behaviour == Behaviour.REVERSE_ON_SIGNAL or signal_on


func reset() -> void:
	super.reset()
	_field.visible = is_active()


func _on_signal(_on: bool) -> void:
	_field.visible = is_active()


## Fits the corner posts and the floor ring to `size`.
func _layout_visuals() -> void:
	var half_x: float = size.x * 0.5
	var half_z: float = size.z * 0.5
	($PostNW as Node3D).position = Vector3(-half_x, 0.0, -half_z)
	($PostNE as Node3D).position = Vector3(half_x, 0.0, -half_z)
	($PostSW as Node3D).position = Vector3(-half_x, 0.0, half_z)
	($PostSE as Node3D).position = Vector3(half_x, 0.0, half_z)
	var north: Node3D = $Field/RingNorth as Node3D
	var south: Node3D = $Field/RingSouth as Node3D
	var west: Node3D = $Field/RingWest as Node3D
	var east: Node3D = $Field/RingEast as Node3D
	north.position = Vector3(0.0, 0.02, -half_z + 0.15)
	south.position = Vector3(0.0, 0.02, half_z - 0.15)
	west.position = Vector3(-half_x + 0.15, 0.02, 0.0)
	east.position = Vector3(half_x - 0.15, 0.02, 0.0)
	north.scale = Vector3(size.x / 10.0, 1.0, 1.0)
	south.scale = Vector3(size.x / 10.0, 1.0, 1.0)
	west.scale = Vector3(1.0, 1.0, size.z / 10.0)
	east.scale = Vector3(1.0, 1.0, size.z / 10.0)
