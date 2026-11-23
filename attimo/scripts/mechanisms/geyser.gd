class_name Geyser
extends Mechanism
## Pressure-valve geyser, Druckventil-Geysir (MECH-05, D-11, D-06): a vent that charges for `charge_time` (a gauge needle climbs)
## and then erupts for `erupt_time`, throwing every player standing in its column upward once per eruption. Cycle: CHARGE, ERUPT,
## CHARGE... while the signal is on; with the signal off the charge is held at 0. The launch goes through
## call_deferred(launch_along); each player is launched once per eruption (the list is cleared on the next CHARGE), so a column
## never relaunches in a loop. This script never writes the player's velocity (D-06). No particles: a pale column mesh shows the steam.

enum Phase { CHARGE, ERUPT }

@export_range(0.2, 10.0, 0.1) var charge_time: float = 3.0
@export_range(0.1, 3.0, 0.05) var erupt_time: float = 0.6
@export_range(5.0, 40.0, 0.5) var eruption_speed: float = 24.0
@export_range(0.5, 4.0, 0.1) var column_radius: float = 1.5
@export_range(1.0, 8.0, 0.1) var column_height: float = 3.0

const NEEDLE_MIN: float = deg_to_rad(-120.0)
const NEEDLE_MAX: float = deg_to_rad(120.0)

var phase: Phase = Phase.CHARGE

var _timer: float = 0.0
var _launched: Array[Node] = []

@onready var _column: Area3D = $Column
@onready var _steam: MeshInstance3D = $Steam
@onready var _needle: Node3D = $Gauge/Needle


func _ready() -> void:
	_column.collision_layer = 0
	_column.collision_mask = PhysicsLayers.PLAYER
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = column_radius
	cylinder.height = column_height
	var shape_node: CollisionShape3D = $Column/CollisionShape3D as CollisionShape3D
	shape_node.shape = cylinder
	shape_node.position = Vector3(0.0, column_height * 0.5, 0.0)
	var steam: CylinderMesh = CylinderMesh.new()
	steam.top_radius = column_radius * 0.8
	steam.bottom_radius = column_radius * 0.8
	steam.height = column_height
	steam.radial_segments = 8
	_steam.mesh = steam
	_steam.position = Vector3(0.0, column_height * 0.5, 0.0)
	_apply()
	super._ready()


func _physics_process(delta: float) -> void:
	if not signal_on:
		if phase != Phase.CHARGE or _timer > 0.0:
			_begin_charge()
		_apply()
		return
	_timer += delta
	if phase == Phase.CHARGE:
		if _timer >= charge_time:
			phase = Phase.ERUPT
			_timer = 0.0
	if phase == Phase.ERUPT:
		_launch_column()
		if _timer >= erupt_time:
			_begin_charge()
	_apply()


## 0 at the start of a charge to 1 when it erupts; 1 during the eruption.
func charge_ratio() -> float:
	if phase == Phase.ERUPT:
		return 1.0
	return clampf(_timer / maxf(charge_time, 0.01), 0.0, 1.0)


func is_erupting() -> bool:
	return phase == Phase.ERUPT


func reset() -> void:
	super.reset()
	_begin_charge()
	_apply()


func _begin_charge() -> void:
	phase = Phase.CHARGE
	_timer = 0.0
	_launched.clear()


## Launches every player in the column that was not launched yet during this eruption.
func _launch_column() -> void:
	for body: Node3D in _column.get_overlapping_bodies():
		var player: PlayerController = body as PlayerController
		if player == null or _launched.has(player):
			continue
		_launched.append(player)
		player.call_deferred(&"launch_along", Vector3.UP, eruption_speed)


func _apply() -> void:
	_needle.rotation.z = lerpf(NEEDLE_MAX, NEEDLE_MIN, charge_ratio())
	_steam.visible = phase == Phase.ERUPT
