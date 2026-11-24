class_name FallReset
extends Area3D
## A gym kill-zone: a player entering the volume is put back at the respawn marker with zero motion and one core of arm energy (PlayerController.respawn).
## Sits on the Hazard layer and masks the Player layer. The teleport and the camera snap run deferred,
## never inside the physics flush that reports the overlap (T-02-08).

## Where the player reappears.
@export var respawn: Node3D
## Optional: snapped to the player right after the teleport.
@export var camera_rig: CameraRig
## Optional (puzzle rooms): after the teleport every node of the group `mechanism` below this node gets reset(), so a room
## starts again from its load state. Null keeps the plain respawn.
@export var reset_root: Node3D


func _ready() -> void:
	collision_layer = PhysicsLayers.HAZARD
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player: PlayerController = body as PlayerController
	if player == null or respawn == null:
		return
	player.call_deferred(&"respawn", respawn.global_position)
	if reset_root != null:
		call_deferred(&"_sweep_room")
	if camera_rig != null:
		camera_rig.call_deferred(&"snap_to_target")


## reset() on every mechanism node under reset_root (deferred, after the overlap callback; the order is the tree order).
func _sweep_room() -> void:
	if reset_root == null or not is_instance_valid(reset_root):
		return
	for node: Node in get_tree().get_nodes_in_group(&"mechanism"):
		if reset_root.is_ancestor_of(node) and node.has_method(&"reset"):
			node.call(&"reset")
