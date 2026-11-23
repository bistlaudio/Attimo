class_name SlingshotCore
extends Mechanism
## Schleuderkern (MECH-04 C, D-10): a glowing core that catches a player who enters its radius, pulls them to its centre and throws
## them out through the point mirror of the entry offset, so entering from the upper left leaves to the lower right and a second
## entry angle gives the mirrored second direction. The exit pitch never goes below min_exit_pitch_deg (a throw from straight above
## still leaves nearly level), and the exit speed is the entry speed times boost, clamped to min_exit_speed..max_exit_speed.
## Active means the signal is on (RUN_WHILE_ON) or always (REVERSE_ON_SIGNAL). D-06: this script only requests the capture through
## PlayerController.capture_along (call_deferred, the overlap callback runs inside the physics flush) and never writes the player's
## velocity. After a capture it stays disarmed until the player was released, rearm_time passed and no player is inside the radius.

enum Phase { ARMED, CAPTURING, COOLDOWN }

## Trigger radius in m.
@export_range(1.0, 6.0, 0.1) var radius: float = 2.5
## Speed in m/s at which the player is pulled to the centre.
@export_range(2.0, 40.0, 0.5) var pull_speed: float = 14.0
## Seconds the player is held at the centre before the throw.
@export_range(0.0, 1.0, 0.01) var hold_time: float = 0.12
## Smallest exit speed in m/s.
@export_range(1.0, 40.0, 0.5) var min_exit_speed: float = 12.0
## Factor on the entry speed.
@export_range(0.5, 3.0, 0.05) var boost: float = 1.15
## Largest exit speed in m/s.
@export_range(1.0, 40.0, 0.5) var max_exit_speed: float = 26.0
## Lowest exit pitch in degrees (negative is downward, D-10).
@export_range(-60.0, 0.0, 1.0) var min_exit_pitch_deg: float = -20.0
## Seconds after the release before the core catches again.
@export_range(0.0, 5.0, 0.1) var rearm_time: float = 1.0

## Longest wait in s for a capture to end before the core rearms anyway.
const MAX_WAIT: float = 6.0
## Seconds the capture has to show up in the player's state before a missing one counts as ended.
const START_GRACE: float = 0.1

var _phase: Phase = Phase.ARMED
var _timer: float = 0.0
var _captured: PlayerController = null

@onready var _trigger: Area3D = $Trigger
@onready var _glow: Node3D = $Glow


func _ready() -> void:
	_trigger.collision_layer = 0
	_trigger.collision_mask = PhysicsLayers.PLAYER
	var shape_node: CollisionShape3D = $Trigger/CollisionShape3D as CollisionShape3D
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	shape_node.shape = sphere
	_trigger.body_entered.connect(_on_body_entered)
	_glow.visible = is_active()
	super._ready()


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.CAPTURING:
			_timer += delta
			var in_capture: bool = _captured != null and is_instance_valid(_captured) and _captured.state_machine.current.name == &"Capture"
			if (_timer > START_GRACE and not in_capture) or _timer > MAX_WAIT:
				_phase = Phase.COOLDOWN
				_timer = rearm_time
		Phase.COOLDOWN:
			_timer -= delta
			if _timer <= 0.0 and not _player_inside():
				_phase = Phase.ARMED
				_captured = null


## True while the core acts: the signal is on, or always for REVERSE_ON_SIGNAL.
func is_active() -> bool:
	return behaviour == Behaviour.REVERSE_ON_SIGNAL or signal_on


## The exit velocity for a player at `player_position` (origin) moving with `entry_velocity` (3D): the point mirror of the chest
## offset, pitch-clamped, at the clamped boosted speed. Public so tests and the station labels can read the rule.
func exit_velocity_for(player_position: Vector3, entry_velocity: Vector3, facing: Vector3) -> Vector3:
	var offset: Vector3 = (player_position + Vector3.UP) - global_position
	var heading: Vector3 = -offset
	if offset.length() < 0.3:
		heading = -entry_velocity if entry_velocity.length() > 0.01 else -facing
	var direction: Vector3 = heading.normalized()
	var min_pitch: float = deg_to_rad(min_exit_pitch_deg)
	if asin(clampf(direction.y, -1.0, 1.0)) < min_pitch:
		var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
		if flat.length_squared() < 0.0001:
			flat = Vector3(facing.x, 0.0, facing.z)
		if flat.length_squared() < 0.0001:
			flat = Vector3.FORWARD
		direction = flat.normalized() * cos(min_pitch) + Vector3.UP * sin(min_pitch)
	var speed: float = clampf(maxf(entry_velocity.length(), min_exit_speed) * boost, min_exit_speed, max_exit_speed)
	return direction * speed


func reset() -> void:
	super.reset()
	_phase = Phase.ARMED
	_timer = 0.0
	_captured = null
	_glow.visible = is_active()


func _on_signal(_on: bool) -> void:
	_glow.visible = is_active()


func _on_body_entered(body: Node3D) -> void:
	var player: PlayerController = body as PlayerController
	if player == null or not is_active() or _phase != Phase.ARMED:
		return
	var entry: Vector3 = Vector3(player.move_velocity.x, player.vertical_speed, player.move_velocity.z)
	var exit_velocity: Vector3 = exit_velocity_for(player.global_position, entry, player.visual_root.global_basis.z)
	_phase = Phase.CAPTURING
	_timer = 0.0
	_captured = player
	player.call_deferred(&"capture_along", PackedVector3Array([global_position - Vector3.UP]), pull_speed, hold_time, exit_velocity)


func _player_inside() -> bool:
	for body: Node3D in _trigger.get_overlapping_bodies():
		if body is PlayerController:
			return true
	return false
