class_name SteamNozzle
extends Mechanism
## Dampfduese (MECH-03, D-16, D-20): an updraft column that holds the player up while active. Plan 05.1-03 (D-06, KIT-04) cut the
## one-shot launch and the push-back modes: the push-back wall became the steam look of the Wall surface block
## (scenes/kit/steampunk/wall_pad_steam.tscn), the cannon moved to the Catch & launch block (plan 05.1-02). UPDRAFT keeps its stored
## value 1 so a saved mode keeps its meaning; it becomes a force volume in plan 05.1-09. Active means the signal is on (RUN_WHILE_ON)
## or always (REVERSE_ON_SIGNAL). The push calls push_toward straight from this _physics_process, which only records a request the
## player consumes in its own tick. This script never writes the player's velocity.

enum Mode { UPDRAFT = 1 }

@export var mode: Mode = Mode.UPDRAFT
## UPDRAFT: target speed along the direction.
@export_range(1.0, 20.0, 0.5) var updraft_speed: float = 6.0
## UPDRAFT: acceleration; must beat the rise gravity (34) to lift.
@export_range(1.0, 120.0, 1.0) var updraft_accel: float = 60.0

@onready var _volume: Area3D = $Volume
@onready var _column: MeshInstance3D = $Column


func _ready() -> void:
	_volume.collision_layer = 0
	_volume.collision_mask = PhysicsLayers.PLAYER
	_column.rotation = Vector3.ZERO
	_column.position = Vector3(0.0, 2.0, 0.0)
	_column.visible = is_active()
	super._ready()


func _physics_process(_delta: float) -> void:
	if not is_active():
		return
	for body: Node3D in _volume.get_overlapping_bodies():
		var player: PlayerController = body as PlayerController
		if player != null:
			player.push_toward(push_direction(), updraft_speed, updraft_accel)


## True while the nozzle acts: the signal is on, or always for REVERSE_ON_SIGNAL.
func is_active() -> bool:
	return behaviour == Behaviour.REVERSE_ON_SIGNAL or signal_on


## World direction of the push: straight up.
func push_direction() -> Vector3:
	return Vector3.UP


func reset() -> void:
	super.reset()
	_column.visible = is_active()


func _on_signal(_on: bool) -> void:
	_column.visible = is_active()
