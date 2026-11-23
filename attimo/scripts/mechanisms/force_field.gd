class_name ForceField
extends Mechanism
## Repulsor and attractor (MECH-04 A, B, D-06): a sphere volume that pushes a player radially away from its centre (REPEL) or pulls
## the player to the centre and holds them there (ATTRACT). Active means the signal is on (RUN_WHILE_ON, lever-driven). While
## active, every tick it calls PlayerController.push_toward for each overlapping player; the request is consumed in the player's
## own tick, so leaving the field needs no restore step. This script never writes the player's velocity (D-06).

enum Mode { REPEL, ATTRACT }

## Share of pull_accel the approach profile plans to brake with (the rest is margin for gravity and tick quantisation).
const BRAKE_SHARE: float = 0.35

@export var mode: Mode = Mode.REPEL
## Field radius in m.
@export_range(1.0, 12.0, 0.5) var radius: float = 5.0
## REPEL: target speed away from the centre and the acceleration at the centre (it fades toward the rim).
@export_range(1.0, 30.0, 0.5) var repel_speed: float = 12.0
@export_range(1.0, 200.0, 1.0) var repel_accel: float = 80.0
## ATTRACT: top speed toward the centre and the acceleration; the acceleration must beat the rise gravity (34) to hold a player up.
@export_range(1.0, 30.0, 0.5) var pull_speed: float = 10.0
@export_range(1.0, 200.0, 1.0) var pull_accel: float = 60.0
## ATTRACT: inside this distance the player is damped to a standstill instead of pulled (no oscillation through the centre).
@export_range(0.1, 3.0, 0.05) var core_radius: float = 0.6

@onready var _volume: Area3D = $Volume
@onready var _orb: Node3D = $Orb


func _ready() -> void:
	_volume.collision_layer = 0
	_volume.collision_mask = PhysicsLayers.PLAYER
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	($Volume/CollisionShape3D as CollisionShape3D).shape = sphere
	_orb.visible = is_active()
	super._ready()


func _physics_process(_delta: float) -> void:
	if not is_active():
		return
	for body: Node3D in _volume.get_overlapping_bodies():
		var player: PlayerController = body as PlayerController
		if player == null:
			continue
		var offset: Vector3 = (player.global_position + Vector3.UP) - global_position
		var dist: float = offset.length()
		if dist < 0.05:
			continue
		var away: Vector3 = offset / dist
		if mode == Mode.REPEL:
			player.push_toward(away, repel_speed, repel_accel * clampf(1.0 - dist / radius, 0.2, 1.0))
		elif dist > core_radius:
			# Approach speed limited by what the pull can brake (Pitfall 6): a linear fade overshoots the core at high speed.
			var braking: float = sqrt(2.0 * pull_accel * BRAKE_SHARE * (dist - core_radius))
			player.push_toward(-away, minf(pull_speed, braking), pull_accel)
			# Sideways speed (gravity, an earlier throw) is damped too, or the player orbits the centre instead of settling.
			var velocity: Vector3 = Vector3(player.move_velocity.x, player.vertical_speed, player.move_velocity.z)
			var sideways: Vector3 = velocity - away * velocity.dot(away)
			if sideways.length_squared() > 0.0001:
				player.push_toward(sideways.normalized(), 0.0, pull_accel)
		else:
			# Core: damp every axis to a standstill so the player rests at the centre instead of swinging through it.
			player.push_toward(Vector3.UP, 0.0, pull_accel)
			player.push_toward(Vector3.RIGHT, 0.0, pull_accel)
			player.push_toward(Vector3.BACK, 0.0, pull_accel)


## True while the field acts: the signal is on.
func is_active() -> bool:
	return signal_on


func reset() -> void:
	super.reset()
	_orb.visible = is_active()


func _on_signal(_on: bool) -> void:
	_orb.visible = is_active()
