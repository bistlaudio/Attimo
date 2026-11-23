class_name BoostRing
extends Mechanism
## Boost ring (MECH-04 G, D-06): a ring in the air. Flying through it raises the speed along the ring axis to at least
## boost_speed (never slows a faster player, a crossing against the axis boosts against it) and gives the air dash back. The
## trigger is a thick cylinder along the axis (at least 1 m) so a dash or terminal-speed fall cannot tunnel through it.
## Active means the signal is on. One-shots go through call_deferred; this script never writes the player's velocity (D-06).

@export_range(0.5, 4.0, 0.1) var ring_radius: float = 1.5
## Trigger depth along the axis in m.
@export_range(1.0, 3.0, 0.1) var thickness: float = 1.2
@export_range(5.0, 40.0, 0.5) var boost_speed: float = 20.0
## Seconds after a boost before the ring accepts the next crossing (one crossing counts once).
@export_range(0.0, 2.0, 0.05) var rearm_time: float = 0.3

var _armed: bool = true
var _rearm_timer: float = 0.0

@onready var _trigger: Area3D = $Trigger


func _ready() -> void:
	_trigger.collision_layer = 0
	_trigger.collision_mask = PhysicsLayers.PLAYER
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = ring_radius
	cylinder.height = maxf(thickness, 1.0)
	($Trigger/CollisionShape3D as CollisionShape3D).shape = cylinder
	_trigger.body_entered.connect(_on_body_entered)
	super._ready()


func _physics_process(delta: float) -> void:
	_rearm_timer = maxf(_rearm_timer - delta, 0.0)
	if _rearm_timer <= 0.0:
		_armed = true


## World direction of the ring axis (local +X).
func axis() -> Vector3:
	return global_basis.x.normalized()


func reset() -> void:
	super.reset()
	_armed = true
	_rearm_timer = 0.0


func _on_body_entered(body: Node3D) -> void:
	var player: PlayerController = body as PlayerController
	if player == null or not signal_on or not _armed:
		return
	_armed = false
	_rearm_timer = rearm_time
	var direction: Vector3 = axis()
	var velocity: Vector3 = Vector3(player.move_velocity.x, player.vertical_speed, player.move_velocity.z)
	var side: float = signf(velocity.dot(direction))
	if side == 0.0:
		side = 1.0
	player.call_deferred(&"boost_along", direction * side, boost_speed, 0.0)
	player.call_deferred(&"refill_air_dash")
