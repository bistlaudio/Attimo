class_name Extractor
extends HandModule
## Extraktor (ENRG-02, D-07, D-11): hold the use button with an energy source (capsule, broken machine) near the crosshair and the
## arm drains it. The source must be within hand_extract_range of the chest and within hand_extract_angle of the crosshair
## direction; the arm never takes more than it can hold and the source keeps the rest. Only ArmEnergy.gain writes the arm (T-05-14).
## Rino may move while extracting. One energy_gained(total, &"extractor") is sent when a drain run ends.

const CHEST_HEIGHT: float = 1.3

var _source: EnergySource = null
var _draining: bool = false
var _run_total: float = 0.0


func on_use_pressed() -> void:
	_run_total = 0.0


func on_use_held(delta: float) -> void:
	if ctx == null or ctx.player == null or ctx.controller == null:
		return
	var arm: ArmEnergy = ctx.player.arm_energy
	var room: float = ArmEnergy.MAX_ENERGY - arm.value
	var source: EnergySource = _pick_source() if room > 0.0 else null
	if source == null:
		_end_run()
		return
	var taken: float = source.extract(delta, room)
	if taken > 0.0:
		_run_total += arm.gain(taken, &"extractor")
		_source = source
		_draining = true
	else:
		_end_run()


func on_use_released() -> void:
	_end_run()


func deactivate() -> void:
	_end_run()


func holds_arm_out() -> bool:
	return _draining


func arm_point() -> Vector3:
	if _draining and is_instance_valid(_source):
		return _source.target_point()
	return super.arm_point()


## Ends a drain run: one energy_gained fact for the total, the arm goes back.
func _end_run() -> void:
	_draining = false
	_source = null
	if _run_total > 0.0:
		EventBus.energy_gained.emit(_run_total, &"extractor")
	_run_total = 0.0


## The available source with the smallest angle to the crosshair direction inside hand_extract_angle and hand_extract_range, or null.
func _pick_source() -> EnergySource:
	var player: PlayerController = ctx.player
	var controller: HandController = ctx.controller
	var chest: Vector3 = player.global_position + Vector3.UP * CHEST_HEIGHT
	var forward: Vector3 = player.visual_root.global_basis.z.normalized()
	if ctx.rig != null and ctx.rig.camera != null:
		forward = ctx.rig.aim_direction_from(chest)
	var best: EnergySource = null
	var best_angle: float = INF
	for node: Node in player.get_tree().get_nodes_in_group(&"energy_source"):
		var candidate: EnergySource = node as EnergySource
		if candidate == null or not candidate.is_inside_tree() or not candidate.is_available():
			continue
		var offset: Vector3 = candidate.target_point() - chest
		if not offset.is_finite() or offset.length() > controller.hand_extract_range:
			continue
		var angle: float = 0.0 if offset.length_squared() < 0.000001 else rad_to_deg(acos(clampf(forward.dot(offset.normalized()), -1.0, 1.0)))
		if angle <= controller.hand_extract_angle and angle < best_angle:
			best = candidate
			best_angle = angle
	return best
