class_name RemoteTrigger
extends HandModule
## Fernausloeser (HAND-03): an instant pulse along the crosshair ray. It builds a PulseHit and calls
## Interactable.try_trigger synchronously (D-04). World geometry occludes because the first hit wins (D-06).
## An empty or invalid shot still fires and emits the fact.

const CHEST_HEIGHT: float = 1.3
const RAY_MARGIN: float = 10.0


func wants_charge() -> bool:
	return true


func on_use_released(big: bool) -> void:
	if ctx == null or ctx.player == null or ctx.controller == null:
		return
	var controller: HandController = ctx.controller
	var player: PlayerController = ctx.player
	var size: PulseHit.Size = PulseHit.Size.BIG if big else PulseHit.Size.SMALL
	var reach: float = controller.hand_big_range if big else controller.hand_small_range
	var mask: int = PhysicsLayers.WORLD | PhysicsLayers.INTERACTABLE
	var chest: Vector3 = player.global_position + Vector3.UP * CHEST_HEIGHT
	var forward: Vector3 = player.visual_root.global_basis.z.normalized()
	var hit: Dictionary = {}
	if ctx.rig != null:
		forward = -ctx.rig.camera.global_basis.z.normalized()
		hit = ctx.rig.aim_ray(mask, controller.hand_big_range + RAY_MARGIN)
	else:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(chest, chest + forward * (controller.hand_big_range + RAY_MARGIN), mask)
		query.collide_with_areas = false
		hit = player.get_world_3d().direct_space_state.intersect_ray(query)
	var point: Vector3 = chest + forward * reach
	var collider: Object = null
	if not hit.is_empty() and (hit["position"] as Vector3).is_finite():
		point = hit["position"] as Vector3
		collider = hit["collider"] as Object
	if not point.is_finite():
		point = chest + Vector3.UP * 0.001
	var offset: Vector3 = point - chest
	var pulse: PulseHit = PulseHit.new()
	pulse.size = size
	pulse.kind = PulseHit.Kind.SHOT
	pulse.module_id = controller.active_def.id if controller.active_def != null else &""
	pulse.origin = chest
	pulse.point = point
	pulse.direction = offset.normalized() if offset.length() > 0.0001 else forward
	pulse.collider = collider
	pulse.distance = player.global_position.distance_to(point)
	var target: Interactable = Interactable.from_collider(collider)
	var valid: bool = target != null and pulse.distance <= reach and target.can_accept(PulseHit.Kind.SHOT, size) and target.accepts_module(pulse.module_id)
	if valid:
		valid = target.try_trigger(pulse)
	EventBus.pulse_fired.emit(chest, point, int(size), valid)
