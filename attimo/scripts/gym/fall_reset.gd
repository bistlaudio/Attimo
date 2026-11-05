class_name FallReset
extends Area3D
## A gym kill-zone: a player entering the volume is put back at the respawn marker with zero motion.
## Sits on the Hazard layer and masks the Player layer. The teleport and the camera snap run deferred,
## never inside the physics flush that reports the overlap (T-02-08).

## Where the player reappears.
@export var respawn: Node3D
## Optional: snapped to the player right after the teleport.
@export var camera_rig: CameraRig


func _ready() -> void:
	collision_layer = PhysicsLayers.HAZARD
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player: PlayerController = body as PlayerController
	if player == null or respawn == null:
		return
	player.call_deferred(&"teleport", respawn.global_position)
	if camera_rig != null:
		camera_rig.call_deferred(&"snap_to_target")
