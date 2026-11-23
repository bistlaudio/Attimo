class_name BouncePad
extends Mechanism
## Bounce pad (MECH-04 F, D-06): a raised pad that throws the player back up with a speed that scales with the landing impact
## (impact * restitution, clamped between min_bounce and max_bounce), so a high drop bounces higher and a small hop still bounces.
## It listens to EventBus.landed (emitted by the player on every floor arrival, independent of tick rate), checks the landing
## spot against its top face and then asks the player through call_deferred(launch_along). It never uses an overlap callback:
## a terminal-speed fall would tunnel through a thin trigger (Pitfall 2). Active means the signal is on. This script never
## writes the player's velocity (D-06).

@export var size: Vector3 = Vector3(3.0, 0.3, 3.0)
## Share of the landing speed that comes back.
@export_range(0.1, 2.0, 0.05) var restitution: float = 1.0
## Bounce speed floor (a hop onto the pad) and cap, in m/s.
@export_range(1.0, 40.0, 0.5) var min_bounce: float = 11.0
@export_range(1.0, 40.0, 0.5) var max_bounce: float = 30.0

@onready var _body: StaticBody3D = $Body


func _ready() -> void:
	_body.collision_layer = PhysicsLayers.WORLD
	_body.collision_mask = 0
	# The top face sits size.y above the node origin (raised, so it is never coplanar with the floor tile under it).
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	var shape_node: CollisionShape3D = $Body/CollisionShape3D as CollisionShape3D
	shape_node.shape = box
	shape_node.position = Vector3(0.0, size.y * 0.5, 0.0)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var mesh_node: MeshInstance3D = $Body/Mesh as MeshInstance3D
	mesh_node.mesh = mesh
	mesh_node.position = Vector3(0.0, size.y * 0.5, 0.0)
	EventBus.landed.connect(_on_landed)
	super._ready()


func _exit_tree() -> void:
	if EventBus.landed.is_connected(_on_landed):
		EventBus.landed.disconnect(_on_landed)


func _on_landed(position: Vector3, impact_speed: float) -> void:
	if not signal_on or not is_finite(impact_speed):
		return
	var local: Vector3 = to_local(position)
	if absf(local.x) > size.x * 0.5 + 0.1 or absf(local.z) > size.z * 0.5 + 0.1:
		return
	if absf(local.y - size.y) > 0.4:
		return
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	var bounce: float = clampf(impact_speed * restitution, min_bounce, max_bounce)
	player.call_deferred(&"launch_along", Vector3.UP, bounce)
