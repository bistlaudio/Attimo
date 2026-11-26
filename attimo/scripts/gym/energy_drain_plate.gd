class_name EnergyDrainPlate
extends Area3D
## GYM ONLY (never part of the level, T-05-15): a flat plate that empties the arm when the player steps on it, so the energy test area can
## show the base version of an injected move (arm at 0) one step away from the charged version (a capsule next to it).
## It asks the owner through ArmEnergy.reset_to, deferred (never inside the physics flush that reports the overlap) and never writes the
## energy value directly. Sits on the Hazard layer and masks the Player layer like FallReset. The level (Phase 7) is built from the
## kit of Phase 5.1, which does not include this node.


func _ready() -> void:
	collision_layer = PhysicsLayers.HAZARD
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player: PlayerController = body as PlayerController
	if player == null or player.arm_energy == null:
		return
	player.arm_energy.call_deferred(&"reset_to", 0)
