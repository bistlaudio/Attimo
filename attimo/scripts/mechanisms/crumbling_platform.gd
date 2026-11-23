class_name CrumblingPlatform
extends Mechanism
## Crumbling platform (MECH-04 I): a platform that gives way. The first step while the signal is on starts SHAKE, then it drops
## away (collision off, the mesh falls 1 m) and respawns after respawn_delay once nobody is inside its footprint, so it never
## reappears inside a player. It moves nobody: the player just loses or regains the floor. Timing runs on physics-tick
## accumulators (no Tween). Its top sits 0.05 m above the node origin (coplanar rule). reset() restores IDLE.

enum Phase { IDLE, SHAKE, FALL, GONE }

@export var size: Vector3 = Vector3(4.0, 0.5, 4.0)
@export_range(0.1, 3.0, 0.05) var shake_time: float = 0.6
@export_range(0.1, 3.0, 0.05) var fall_time: float = 0.5
@export_range(0.5, 10.0, 0.1) var respawn_delay: float = 3.0

const TOP_LIP: float = 0.05
const SHAKE_AMPLITUDE: float = 0.03
const DROP_DISTANCE: float = 1.0

var phase: Phase = Phase.IDLE

var _timer: float = 0.0
var _mesh_rest: Vector3 = Vector3.ZERO

@onready var _shape: CollisionShape3D = $Body/CollisionShape3D
@onready var _mesh: MeshInstance3D = $Body/Mesh
@onready var _sensor: Area3D = $Sensor
@onready var _footprint: Area3D = $Footprint


func _ready() -> void:
	($Body as StaticBody3D).collision_layer = PhysicsLayers.WORLD
	($Body as StaticBody3D).collision_mask = 0
	var centre_y: float = TOP_LIP - size.y * 0.5
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_shape.position = Vector3(0.0, centre_y, 0.0)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_mesh.mesh = mesh
	_mesh.position = Vector3(0.0, centre_y, 0.0)
	_mesh_rest = _mesh.position
	_set_box(_sensor, Vector3(size.x, 0.25, size.z), Vector3(0.0, 0.125, 0.0))
	_set_box(_footprint, Vector3(size.x, 2.0, size.z), Vector3(0.0, 0.5, 0.0))
	super._ready()


func _physics_process(delta: float) -> void:
	match phase:
		Phase.IDLE:
			if signal_on and _player_in(_sensor):
				phase = Phase.SHAKE
				_timer = 0.0
		Phase.SHAKE:
			_timer += delta
			_mesh.position = _mesh_rest + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * SHAKE_AMPLITUDE
			if _timer >= shake_time:
				phase = Phase.FALL
				_timer = 0.0
				_shape.set_deferred(&"disabled", true)
		Phase.FALL:
			_timer += delta
			_mesh.position = _mesh_rest + Vector3.DOWN * DROP_DISTANCE * minf(_timer / maxf(fall_time, 0.01), 1.0)
			if _timer >= fall_time:
				phase = Phase.GONE
				_timer = 0.0
				_mesh.visible = false
		Phase.GONE:
			_timer += delta
			if _timer >= respawn_delay and not _player_in(_footprint):
				_restore()


func reset() -> void:
	super.reset()
	_restore()


func _restore() -> void:
	phase = Phase.IDLE
	_timer = 0.0
	_shape.set_deferred(&"disabled", false)
	_mesh.position = _mesh_rest
	_mesh.visible = true


func _player_in(area: Area3D) -> bool:
	for body: Node3D in area.get_overlapping_bodies():
		if body is PlayerController:
			return true
	return false


func _set_box(area: Area3D, box_size: Vector3, centre: Vector3) -> void:
	area.collision_layer = 0
	area.collision_mask = PhysicsLayers.PLAYER
	var box: BoxShape3D = BoxShape3D.new()
	box.size = box_size
	var shape_node: CollisionShape3D = area.get_node("CollisionShape3D") as CollisionShape3D
	shape_node.shape = box
	shape_node.position = centre
