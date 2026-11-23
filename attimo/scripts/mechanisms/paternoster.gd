class_name Paternoster
extends Mechanism
## Paternoster (MECH-05, D-11, D-06): open decks that circle on a closed rectangle in the local XY plane, up the +x side, across
## the top, down the -x side and across the bottom, like the cabins of a paternoster lift. Decks are AnimatableBody3D on the
## World layer that sync to physics and only translate (never rotate, always level), so the engine's platform velocity carries a
## rider without sliding. Each deck's node origin is its top face; the bottom run is 0.05 m above this node's origin (coplanar
## rule), so stand the node on a raised base. RUN_WHILE_ON: the speed eases with move_toward over RAMP_TIME. The decks are not in
## any platform group of the movement gym. This script never writes the player's velocity (D-06).

## Seconds a start or a stop takes.
const RAMP_TIME: float = 0.3
## Height of the lowest deck top above the node origin.
const BASE_LIFT: float = 0.05

@export_range(2, 8, 1) var deck_count: int = 4
## Horizontal and vertical size of the loop in m (path of the deck top centre).
@export_range(2.0, 16.0, 0.5) var loop_width: float = 6.0
@export_range(2.0, 24.0, 0.5) var loop_height: float = 8.0
## Travel speed along the loop in m/s.
@export_range(0.2, 6.0, 0.1) var speed: float = 1.5
@export var deck_size: Vector3 = Vector3(2.5, 0.3, 2.5)

var _offset: float = 0.0
var _factor: float = 0.0
var _decks: Array[AnimatableBody3D] = []

@onready var _holder: Node3D = $Decks


func _ready() -> void:
	for index: int in deck_count:
		_decks.append(_build_deck(index))
	_apply()
	super._ready()


func _physics_process(delta: float) -> void:
	_factor = move_toward(_factor, 1.0 if signal_on else 0.0, delta / RAMP_TIME)
	if _factor > 0.0:
		_offset = fposmod(_offset + speed * _factor * delta, _perimeter())
	_apply()


## The deck bodies in order; deck 0 starts at the bottom of the up run.
func decks() -> Array[AnimatableBody3D]:
	return _decks


func reset() -> void:
	super.reset()
	_offset = 0.0
	_factor = 0.0
	_apply()
	for deck: AnimatableBody3D in _decks:
		deck.reset_physics_interpolation()


func _perimeter() -> float:
	return 2.0 * (loop_width + loop_height)


## Local position of a deck top centre at arc length `distance` along the loop, starting at the bottom of the +x side.
func _path(distance: float) -> Vector3:
	var s: float = fposmod(distance, _perimeter())
	var half: float = loop_width * 0.5
	if s < loop_height:
		return Vector3(half, BASE_LIFT + s, 0.0)
	s -= loop_height
	if s < loop_width:
		return Vector3(half - s, BASE_LIFT + loop_height, 0.0)
	s -= loop_width
	if s < loop_height:
		return Vector3(-half, BASE_LIFT + loop_height - s, 0.0)
	s -= loop_height
	return Vector3(-half + s, BASE_LIFT, 0.0)


func _apply() -> void:
	var spacing: float = _perimeter() / float(maxi(deck_count, 1))
	for index: int in _decks.size():
		_decks[index].position = _path(_offset + spacing * index)


func _build_deck(index: int) -> AnimatableBody3D:
	var deck: AnimatableBody3D = AnimatableBody3D.new()
	deck.name = "Deck%d" % index
	deck.collision_layer = PhysicsLayers.WORLD
	deck.collision_mask = 0
	deck.sync_to_physics = true
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = deck_size
	shape_node.shape = box
	shape_node.position = Vector3(0.0, -deck_size.y * 0.5, 0.0)
	deck.add_child(shape_node)
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = deck_size
	mesh_node.mesh = mesh
	mesh_node.position = shape_node.position
	deck.add_child(mesh_node)
	_holder.add_child(deck)
	return deck
