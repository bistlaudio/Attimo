class_name PneumaticTube
extends Mechanism
## Rohrpost (MECH-05): a brass tube. Walking into its mouth (P0) carries the player along the path P0..P3 and fires them out of the
## exit mouth (P3) along the last leg. Active means the signal is on (RUN_WHILE_ON) or always (REVERSE_ON_SIGNAL). The tube body has no
## collision: the Capture state moves the player. D-06: this script only requests the capture through PlayerController.capture_along
## (call_deferred) and never writes the player's velocity. A blocked path or an over-long ride releases the player by itself (Capture
## guards). After a ride the mouth stays disarmed until the player was released, rearm_time passed and the mouth is empty.

enum Phase { ARMED, CAPTURING, COOLDOWN }

## Speed in m/s along the path.
@export_range(2.0, 40.0, 0.5) var tube_speed: float = 16.0
## Speed in m/s leaving the exit mouth.
@export_range(2.0, 40.0, 0.5) var exit_speed: float = 14.0
## Seconds after the release before the mouth catches again.
@export_range(0.0, 5.0, 0.1) var rearm_time: float = 1.0

const MAX_WAIT: float = 6.0
const START_GRACE: float = 0.1
## Radius in m of the mouth trigger sphere.
const MOUTH_RADIUS: float = 1.2
## Radius in m of the tube segments.
const TUBE_RADIUS: float = 0.35

var _phase: Phase = Phase.ARMED
var _timer: float = 0.0
var _captured: PlayerController = null

@onready var _mouth: Area3D = $Mouth
@onready var _visual: Node3D = $Visual
@onready var _exit_glow: MeshInstance3D = $ExitGlow


func _ready() -> void:
	_mouth.collision_layer = 0
	_mouth.collision_mask = PhysicsLayers.PLAYER
	var shape_node: CollisionShape3D = $Mouth/CollisionShape3D as CollisionShape3D
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = MOUTH_RADIUS
	shape_node.shape = sphere
	_mouth.position = (get_node("P0") as Node3D).position + Vector3.UP
	_mouth.body_entered.connect(_on_body_entered)
	_build_visual()
	_exit_glow.visible = is_active()
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


## True while the tube acts: the signal is on, or always for REVERSE_ON_SIGNAL.
func is_active() -> bool:
	return behaviour == Behaviour.REVERSE_ON_SIGNAL or signal_on


## The path in world space: the global positions of P0..P3 (the targets of the player origin).
func path_points() -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	for index: int in 4:
		points.append((get_node("P%d" % index) as Node3D).global_position)
	return points


func reset() -> void:
	super.reset()
	_phase = Phase.ARMED
	_timer = 0.0
	_captured = null
	_exit_glow.visible = is_active()


func _on_signal(_on: bool) -> void:
	_exit_glow.visible = is_active()


func _on_body_entered(body: Node3D) -> void:
	var player: PlayerController = body as PlayerController
	if player == null or not is_active() or _phase != Phase.ARMED:
		return
	var points: PackedVector3Array = path_points()
	var exit_direction: Vector3 = (points[3] - points[2]).normalized()
	_phase = Phase.CAPTURING
	_timer = 0.0
	_captured = player
	player.call_deferred(&"capture_along", points, tube_speed, 0.0, exit_direction * exit_speed)


func _player_inside() -> bool:
	for body: Node3D in _mouth.get_overlapping_bodies():
		if body is PlayerController:
			return true
	return false


## Builds the copper tube segments between P0..P3 (no collision) and the exit ring.
func _build_visual() -> void:
	var copper: StandardMaterial3D = StandardMaterial3D.new()
	copper.albedo_color = Color(0.72, 0.42, 0.25)
	copper.metallic = 0.3
	copper.roughness = 0.7
	for index: int in 3:
		var from: Vector3 = (get_node("P%d" % index) as Node3D).position
		var to: Vector3 = (get_node("P%d" % (index + 1)) as Node3D).position
		var segment: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = TUBE_RADIUS
		mesh.bottom_radius = TUBE_RADIUS
		mesh.height = from.distance_to(to)
		mesh.radial_segments = 8
		segment.mesh = mesh
		segment.material_override = copper
		var direction: Vector3 = (to - from).normalized()
		var axis: Vector3 = Vector3.UP.cross(direction)
		var basis: Basis = Basis.IDENTITY
		if axis.length_squared() > 0.0001:
			basis = Basis(axis.normalized(), Vector3.UP.angle_to(direction))
		elif direction.y < 0.0:
			basis = Basis(Vector3.RIGHT, PI)
		segment.transform = Transform3D(basis, (from + to) * 0.5)
		_visual.add_child(segment)
	# The exit ring sits at P3 facing along the last leg.
	var last_direction: Vector3 = ((get_node("P3") as Node3D).position - (get_node("P2") as Node3D).position).normalized()
	var ring_axis: Vector3 = Vector3.UP.cross(last_direction)
	var ring_basis: Basis = Basis.IDENTITY
	if ring_axis.length_squared() > 0.0001:
		ring_basis = Basis(ring_axis.normalized(), Vector3.UP.angle_to(last_direction))
	_exit_glow.transform = Transform3D(ring_basis, (get_node("P3") as Node3D).position)
