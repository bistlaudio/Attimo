class_name PistonWall
extends Mechanism
## Piston punch wall, Kolbenwand (MECH-05, D-11, D-06): a steam piston head that telegraphs, slams out along its local -Z and
## retracts, over and over while the signal is on. A player in front of it is knocked away once per slam (a punch, no damage).
## Cycle: IDLE (waits `interval`), TELEGRAPH (the head shudders, a glow strip shows the reach), SLAM, HOLD, RETRACT. The head is
## an AnimatableBody3D on the World layer that syncs to physics; its front Hit area sits on the Hazard layer. The knock goes
## through call_deferred(knock_back); this script never writes the player's velocity (D-06). The head bottom is 0.05 m above
## the node origin (coplanar rule).

enum Phase { IDLE, TELEGRAPH, SLAM, HOLD, RETRACT }

## Seconds between the end of one retract and the start of the next telegraph.
@export_range(0.2, 10.0, 0.1) var interval: float = 2.0
@export_range(0.1, 2.0, 0.05) var telegraph_time: float = 0.4
@export_range(0.05, 1.0, 0.01) var slam_time: float = 0.12
@export_range(0.0, 2.0, 0.05) var hold_time: float = 0.3
@export_range(0.1, 3.0, 0.05) var retract_time: float = 0.8
## How far the head travels along -Z in m.
@export_range(0.5, 8.0, 0.1) var reach: float = 3.0
@export_range(1.0, 30.0, 0.5) var knock_strength: float = 12.0
@export_range(0.0, 15.0, 0.5) var knock_up: float = 4.0

const SHUDDER_AMPLITUDE: float = 0.03

var phase: Phase = Phase.IDLE

var _timer: float = 0.0
var _extension: float = 0.0
var _knocked: Array[Node] = []

@onready var _head: AnimatableBody3D = $Head
@onready var _hit: Area3D = $Head/Hit
@onready var _strip: Node3D = $TelegraphStrip


func _ready() -> void:
	_head.sync_to_physics = true
	_head.collision_layer = PhysicsLayers.WORLD
	_head.collision_mask = 0
	_hit.collision_layer = PhysicsLayers.HAZARD
	_hit.collision_mask = PhysicsLayers.PLAYER
	var strip_mesh: MeshInstance3D = $TelegraphStrip/Mesh as MeshInstance3D
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(2.0, 0.04, reach)
	strip_mesh.mesh = box
	strip_mesh.position = Vector3(0.0, 0.03, -0.5 - reach * 0.5)
	_apply()
	super._ready()


func _physics_process(delta: float) -> void:
	match phase:
		Phase.IDLE:
			if signal_on:
				_timer += delta
				if _timer >= interval:
					_enter(Phase.TELEGRAPH)
		Phase.TELEGRAPH:
			_timer += delta
			if not signal_on:
				_enter(Phase.IDLE)
			elif _timer >= telegraph_time:
				_enter(Phase.SLAM)
		Phase.SLAM:
			_timer += delta
			_extension = clampf(_timer / maxf(slam_time, 0.01), 0.0, 1.0)
			_knock_overlapping()
			if _timer >= slam_time:
				_enter(Phase.HOLD)
		Phase.HOLD:
			_timer += delta
			_knock_overlapping()
			if _timer >= hold_time or not signal_on:
				_enter(Phase.RETRACT)
		Phase.RETRACT:
			_timer += delta
			_extension = clampf(1.0 - _timer / maxf(retract_time, 0.01), 0.0, 1.0)
			if _timer >= retract_time:
				_extension = 0.0
				_enter(Phase.IDLE)
	_apply()


func reset() -> void:
	super.reset()
	_enter(Phase.IDLE)
	_extension = 0.0
	_apply()
	_head.reset_physics_interpolation()


func _enter(next: Phase) -> void:
	phase = next
	_timer = 0.0
	if next == Phase.SLAM:
		_knocked.clear()
	if next == Phase.IDLE:
		_extension = 0.0


## Knocks every player in the Hit area that was not already knocked by this slam.
func _knock_overlapping() -> void:
	var push: Vector3 = -global_basis.z
	push.y = 0.0
	if push.length_squared() < 0.0001:
		return
	push = push.normalized()
	for body: Node3D in _hit.get_overlapping_bodies():
		var player: PlayerController = body as PlayerController
		if player == null or _knocked.has(player):
			continue
		_knocked.append(player)
		player.call_deferred(&"knock_back", push * knock_strength + Vector3.UP * knock_up)


func _apply() -> void:
	var shudder: Vector3 = Vector3.ZERO
	if phase == Phase.TELEGRAPH:
		shudder = Vector3(randf_range(-1.0, 1.0), 0.0, 0.0) * SHUDDER_AMPLITUDE
	_head.position = Vector3(0.0, 0.0, -reach * _extension) + shudder
	_strip.visible = phase == Phase.TELEGRAPH
