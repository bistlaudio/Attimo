class_name DamagePush
extends Node
## DamagePush component (Phase 05.1, KIT-01, D-14, D-15, D-17): a kit block that pushes the player on contact. A child node of the block,
## next to the Area3D hit volume it is given in `hit_area`. While a player overlaps the volume and the rehit window is over, it asks the
## player for a knock-back through call_deferred(knock_back) (it never writes the player's velocity, D-17) and announces
## EventBus.player_hit(amount, position, source_id), a fact that carries values only: Phase 6 health will read `amount`. There is no
## health and no death from kit damage in this phase (D-15). Users: pendulum, piston wall, steam hammer (05.1-21 adds more).
## Direction: MOTION pushes the way the hit volume is moving (the swing tangent of the pendulum, the slam of the piston wall), flattened;
## it falls back to AWAY (from the volume's centre) when the volume stands still. The push is horizontal plus `push_up`.

enum Direction { AWAY, MOTION }

## A hit volume slower than this (m/s) counts as standing still for the MOTION direction.
const MIN_MOTION_SPEED: float = 0.5

## The volume that hurts. The component sets it to the Hazard layer and masks the Player.
@export var hit_area: Area3D
## Damage reported on the fact, in whole health points (0 reports a harmless push).
@export_range(0, 3, 1) var amount: int = 1
## Horizontal knock-back speed in m/s.
@export_range(1.0, 30.0, 0.5) var push_speed: float = 10.0
## Upward part of the knock-back in m/s.
@export_range(0.0, 15.0, 0.5) var push_up: float = 4.0
## Seconds after a hit before this component may hit again (one hit per contact, no spam).
@export_range(0.05, 2.0, 0.05) var rehit_time: float = 0.5
## MOTION: along the volume's motion; AWAY: from the volume's centre.
@export var direction: Direction = Direction.MOTION

var _rehit_left: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _has_last: bool = false


func _ready() -> void:
	add_to_group(&"mechanism")
	if hit_area == null:
		push_warning("DamagePush %s has no hit_area" % get_path())
		set_physics_process(false)
		return
	hit_area.collision_layer = PhysicsLayers.HAZARD
	hit_area.collision_mask = PhysicsLayers.PLAYER


func _physics_process(delta: float) -> void:
	if hit_area == null or not is_instance_valid(hit_area):
		return
	var now: Vector3 = hit_area.global_position
	if _has_last and delta > 0.0:
		_velocity = (now - _last_position) / delta
	_last_position = now
	_has_last = true
	_rehit_left = maxf(_rehit_left - delta, 0.0)
	if _rehit_left > 0.0:
		return
	for body: Node3D in hit_area.get_overlapping_bodies():
		var player: PlayerController = body as PlayerController
		if player != null:
			_hit(player)
			return


## Back to the load state (FallReset sweep).
func reset() -> void:
	_rehit_left = 0.0
	_velocity = Vector3.ZERO
	_has_last = false


## The flat direction the push goes in for a player at `player_position`: zero only when both rules fail.
func push_direction(player_position: Vector3) -> Vector3:
	if direction == Direction.MOTION:
		var flat: Vector3 = Vector3(_velocity.x, 0.0, _velocity.z)
		if _velocity.length() >= MIN_MOTION_SPEED and flat.length_squared() > 0.0001:
			return flat.normalized()
	var away: Vector3 = player_position - hit_area.global_position
	away.y = 0.0
	if away.length_squared() > 0.0001:
		return away.normalized()
	var forward: Vector3 = -hit_area.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.RIGHT


func _hit(player: PlayerController) -> void:
	var flat: Vector3 = push_direction(player.global_position)
	_rehit_left = rehit_time
	player.call_deferred(&"knock_back", flat * push_speed + Vector3.UP * push_up)
	EventBus.player_hit.emit(amount, player.global_position, _source_id())


## The block's node name, e.g. &"Pendulum" (a name, never a node reference).
func _source_id() -> StringName:
	var block: Node = owner if owner != null else get_parent()
	return StringName(block.name) if block != null else &"unknown"
