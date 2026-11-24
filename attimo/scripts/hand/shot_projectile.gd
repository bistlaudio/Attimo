class_name ShotProjectile
extends Node3D
## The flying shot of the hand (D-17, never a beam). It has no physics body: each physics tick it steps along its direction and casts
## a ray from the previous to the next position on World and Interactable (a swept test, so 40 m/s cannot tunnel, T-05-12). With a
## locked target it turns toward the target point by at most turn_rate degrees per second (the bend, D-19). It frees itself at its
## range or on its first hit and emits EventBus.pulse_fired once. On a hit it builds a PulseHit with the energy spent and the size
## derived from it and triggers the Interactable through the unchanged HAND-02 contract. At most MAX_LIVE projectiles exist (T-05-11).

const MAX_LIVE: int = 4
const MIN_RADIUS: float = 0.12
const MAX_RADIUS: float = 0.3
const SHOT_COLOR: Color = Color(0.25, 0.9, 0.85, 1.0)

var _direction: Vector3 = Vector3.FORWARD
var _speed: float = 40.0
var _range: float = 15.0
var _travelled: float = 0.0
var _energy: float = 0.0
var _big_threshold: float = 25.0
var _turn_rate: float = 0.0
var _module_id: StringName = &""
var _origin: Vector3 = Vector3.ZERO
var _target: Interactable = null
var _shooter: Node3D = null
var _done: bool = false


func _ready() -> void:
	add_to_group(&"shot_projectile")
	var alive: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group(&"shot_projectile"):
		if not node.is_queued_for_deletion():
			alive.append(node)
	# The oldest go first, the new one is last in the group.
	while alive.size() > MAX_LIVE:
		alive.pop_front().queue_free()


## Launches the shot from `origin` along `direction`. Non-finite input frees the projectile at once (T-05-12). `charge` is the 0..1
## charge ratio and only scales the look.
func setup(origin: Vector3, direction: Vector3, energy: float, speed: float, max_range: float, target: Interactable, turn_rate_deg: float, module_id: StringName, big_threshold: float, shooter: Node3D, charge: float = 0.0) -> void:
	if not (origin.is_finite() and direction.is_finite() and is_finite(energy) and is_finite(speed) and is_finite(max_range) and is_finite(turn_rate_deg) and is_finite(big_threshold)) or direction.length_squared() < 0.000001 or speed <= 0.0 or max_range <= 0.0:
		_done = true
		queue_free()
		return
	_origin = origin
	_direction = direction.normalized()
	_energy = energy
	_speed = minf(speed, 120.0)
	_range = max_range
	_target = target
	_turn_rate = deg_to_rad(maxf(turn_rate_deg, 0.0))
	_module_id = module_id
	_big_threshold = big_threshold
	_shooter = shooter
	global_position = origin
	_build_look(clampf(charge, 0.0, 1.0) if is_finite(charge) else 0.0)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if _target != null and is_instance_valid(_target) and _turn_rate > 0.0:
		_bend(delta)
	var step: float = minf(_speed * delta, _range - _travelled)
	var previous: Vector3 = global_position
	var next: Vector3 = previous + _direction * step
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(previous, next, PhysicsLayers.WORLD | PhysicsLayers.INTERACTABLE)
	query.collide_with_areas = false
	if _shooter != null and is_instance_valid(_shooter) and _shooter is CollisionObject3D:
		query.exclude = [(_shooter as CollisionObject3D).get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (hit["position"] as Vector3).is_finite():
		_impact(hit)
		return
	global_position = next
	_travelled += step
	if _travelled >= _range - 0.0001:
		_finish(global_position, false)


## Turns the flight direction toward the target point by at most the turn rate this tick.
func _bend(delta: float) -> void:
	var offset: Vector3 = _target.target_point() - global_position
	if not offset.is_finite() or offset.length_squared() < 0.0004:
		return
	var wanted: Vector3 = offset.normalized()
	var angle: float = _direction.angle_to(wanted)
	var limit: float = _turn_rate * delta
	if angle <= limit or angle < 0.0001:
		_direction = wanted
	else:
		_direction = _direction.slerp(wanted, limit / angle).normalized()


func _impact(hit: Dictionary) -> void:
	var point: Vector3 = hit["position"] as Vector3
	var collider: Object = hit["collider"] as Object
	var size: PulseHit.Size = PulseHit.size_for_energy(_energy, _big_threshold)
	var pulse: PulseHit = PulseHit.new()
	pulse.energy = _energy
	pulse.size = size
	pulse.kind = PulseHit.Kind.SHOT
	pulse.module_id = _module_id
	pulse.origin = _origin
	pulse.point = point
	pulse.direction = _direction
	pulse.collider = collider
	var from: Vector3 = _shooter.global_position if _shooter != null and is_instance_valid(_shooter) else _origin
	pulse.distance = from.distance_to(point)
	var valid: bool = false
	var interactable: Interactable = Interactable.from_collider(collider)
	if interactable != null and interactable.can_accept(PulseHit.Kind.SHOT, size) and interactable.accepts_module(_module_id):
		valid = interactable.try_trigger(pulse)
	_finish(point, valid)


func _finish(point: Vector3, valid: bool) -> void:
	_done = true
	EventBus.pulse_fired.emit(_origin, point, int(PulseHit.size_for_energy(_energy, _big_threshold)), valid)
	queue_free()


func _build_look(charge: float) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = SHOT_COLOR
	var radius: float = lerpf(MIN_RADIUS, MAX_RADIUS, charge)
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = &"Ball"
	mesh.mesh = sphere
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
