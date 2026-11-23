class_name PressurePlate
extends SignalSource
## Pressure plate (MECH-04 H): a floor plate that is a SignalSource and is active exactly while a player stands on it. It is
## polled every physics tick (no enter/exit edge to miss), so it follows the player within a tick or two. It moves nobody
## and writes nothing to the player. Not an Interactable (no E prompt); reset() restores the inactive state.

## How far the plate mesh sinks while active, in m.
const SINK_DEPTH: float = 0.06
const SINK_SPEED: float = 0.5

@onready var _sensor: Area3D = $Sensor
@onready var _mesh: Node3D = $Plate/Mesh

var _mesh_rest_y: float = 0.0


func _ready() -> void:
	_sensor.collision_layer = 0
	_sensor.collision_mask = PhysicsLayers.PLAYER
	_mesh_rest_y = _mesh.position.y
	super._ready()


func _physics_process(delta: float) -> void:
	set_active(not _sensor.get_overlapping_bodies().is_empty())
	var wanted: float = _mesh_rest_y - (SINK_DEPTH if is_active else 0.0)
	_mesh.position.y = move_toward(_mesh.position.y, wanted, SINK_SPEED * delta)


func reset() -> void:
	super.reset()
	_mesh.position.y = _mesh_rest_y
