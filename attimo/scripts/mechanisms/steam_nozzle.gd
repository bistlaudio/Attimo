class_name SteamNozzle
extends Mechanism
## Dampfduese (MECH-03, D-16, D-20): throws or pushes the player along a fixed direction while active. Modes: JUMP (up, one launch
## per entry), UPDRAFT (a lift column that holds the player up) and WALL (a push back along -Z). The cannon mode moved to the Catch &
## launch kit block (FIXED profile, scenes/kit/steampunk/steam_cannon.tscn, plan 05.1-02); WALL keeps its value 3 so a stored mode
## keeps its meaning. Active means the signal is on (RUN_WHILE_ON) or always (REVERSE_ON_SIGNAL, where the signal flips the
## WALL direction, D-18). One call rule: one-shot launches go through call_deferred (the overlap callback runs
## inside the physics flush), continuous pushes call push_toward straight from this _physics_process, which only records a
## request the player consumes in its own tick. This script never writes the player's velocity.

enum Mode { JUMP = 0, UPDRAFT = 1, WALL = 3 }

@export var mode: Mode = Mode.JUMP
## JUMP: speed along the direction in m/s.
@export_range(1.0, 30.0, 0.5) var launch_speed: float = 14.0
## UPDRAFT: target speed along the direction.
@export_range(1.0, 20.0, 0.5) var updraft_speed: float = 6.0
## UPDRAFT: acceleration; must beat the rise gravity (34) to lift.
@export_range(1.0, 120.0, 1.0) var updraft_accel: float = 60.0
## WALL: target speed along the direction.
@export_range(1.0, 20.0, 0.5) var wall_speed: float = 8.0
@export_range(1.0, 120.0, 1.0) var wall_accel: float = 60.0
## JUMP: seconds after a launch before the next entry may launch again.
@export_range(0.0, 2.0, 0.05) var launch_cooldown: float = 0.25

var _armed: bool = true
var _cooldown: float = 0.0

@onready var _volume: Area3D = $Volume
@onready var _column: MeshInstance3D = $Column


func _ready() -> void:
	_volume.collision_layer = 0
	_volume.collision_mask = PhysicsLayers.PLAYER
	_volume.body_entered.connect(_on_body_entered)
	_column.rotation = Vector3.ZERO if mode == Mode.JUMP or mode == Mode.UPDRAFT else Vector3(-PI * 0.5, 0.0, 0.0)
	_column.position = Vector3(0.0, 2.0, 0.0) if mode == Mode.JUMP or mode == Mode.UPDRAFT else Vector3(0.0, 0.5, -2.0)
	_column.visible = is_active()
	super._ready()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown <= 0.0:
		_armed = true
	if not is_active():
		return
	if mode == Mode.UPDRAFT or mode == Mode.WALL:
		var speed: float = updraft_speed if mode == Mode.UPDRAFT else wall_speed
		var accel: float = updraft_accel if mode == Mode.UPDRAFT else wall_accel
		for body: Node3D in _volume.get_overlapping_bodies():
			var player: PlayerController = body as PlayerController
			if player != null:
				player.push_toward(push_direction(), speed, accel)


## True while the nozzle acts: the signal is on, or always for REVERSE_ON_SIGNAL.
func is_active() -> bool:
	return behaviour == Behaviour.REVERSE_ON_SIGNAL or signal_on


## World direction of the launch or push.
func push_direction() -> Vector3:
	if mode == Mode.JUMP or mode == Mode.UPDRAFT:
		return Vector3.UP
	var forward: Vector3 = -global_basis.z
	if behaviour == Behaviour.REVERSE_ON_SIGNAL and signal_on:
		forward = -forward
	return forward.normalized()


func reset() -> void:
	super.reset()
	_armed = true
	_cooldown = 0.0
	_column.visible = is_active()


func _on_signal(on: bool) -> void:
	_column.visible = is_active()
	if on and mode == Mode.JUMP:
		# A lever pulled while the player already stands in the volume launches that player once.
		for body: Node3D in _volume.get_overlapping_bodies():
			_try_launch(body)


func _on_body_entered(body: Node3D) -> void:
	_try_launch(body)


func _try_launch(body: Node3D) -> void:
	if mode != Mode.JUMP:
		return
	var player: PlayerController = body as PlayerController
	if player == null or not is_active() or not _armed:
		return
	_armed = false
	_cooldown = launch_cooldown
	player.call_deferred(&"launch_along", push_direction(), launch_speed)
