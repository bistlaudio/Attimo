class_name RemoteTrigger
extends HandModule
## Der Schuss (HAND-03, D-17, D-18; id stays remote_trigger so every Interactable's accepted_modules keeps working). A flying
## projectile, never a beam. The press pays hand_shot_cost_min (a tap); below that the shot is refused and the arm flickers grey.
## Holding past hand_shot_tap_time drains energy up to hand_shot_cost_max in hand_shot_charge_time (a Samus-style charge) and tells
## shot_fully_charged once; running dry keeps what was spent so far. The release fires: range grows with the charge, the payload is the
## energy spent, and a locked target bends the shot in (D-19). The size derives from the energy (PulseHit.size_for_energy).
## Paid energy is never lost silently: a module switch mid-charge (deactivate) or a shot that cannot spawn gives the energy spent so
## far back to the arm and reports it once as energy_gained(amount, &"shot_refund") (ArmEnergy stays all or nothing, CR-01).

const CHEST_HEIGHT: float = 1.3
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/hand/shot_projectile.tscn")

var _active: bool = false
var _spent: float = 0.0
## The part of _spent drained by the charge, reported once as energy_spent at the release or the refund (WR-03).
var _drained: float = 0.0
var _held: float = 0.0
var _dry: bool = false
var _full: bool = false


func on_use_pressed() -> void:
	_active = false
	if ctx == null or ctx.player == null or ctx.controller == null:
		return
	var controller: HandController = ctx.controller
	var arm: ArmEnergy = ctx.player.arm_energy
	if not arm.try_spend(controller.hand_shot_cost_min, &"shot"):
		# D-18: below the minimum the shot does not fire; only this path makes the lack visible.
		arm.refuse(&"shot", controller.hand_shot_cost_min)
		return
	_active = true
	_spent = controller.hand_shot_cost_min
	_drained = 0.0
	_held = 0.0
	_dry = false
	_full = false


func on_use_held(delta: float) -> void:
	if not _active or _dry or ctx == null or ctx.controller == null:
		return
	var controller: HandController = ctx.controller
	_held += delta
	if _held < controller.hand_shot_tap_time or _spent >= controller.hand_shot_cost_max:
		return
	var rate: float = (controller.hand_shot_cost_max - controller.hand_shot_cost_min) / maxf(controller.hand_shot_charge_time, 0.01)
	var want: float = minf(rate * delta, controller.hand_shot_cost_max - _spent)
	var taken: float = ctx.player.arm_energy.drain(want, &"shot")
	_spent += taken
	_drained += taken
	if taken < want - 0.0001:
		_dry = true
	if _spent >= controller.hand_shot_cost_max - 0.0001:
		_spent = controller.hand_shot_cost_max
		if not _full:
			_full = true
			EventBus.shot_fully_charged.emit(ctx.player.global_position + Vector3.UP * CHEST_HEIGHT)


func on_use_released() -> void:
	if not _active:
		return
	_active = false
	_fire()


## A switch mid-charge never fires a surprise shot: the energy paid so far goes back to the arm.
func deactivate() -> void:
	if _active:
		_refund()
	_active = false
	_spent = 0.0
	_held = 0.0


func charge_ratio() -> float:
	if not _active or ctx == null or ctx.controller == null:
		return 0.0
	return _ratio(ctx.controller)


func holds_arm_out() -> bool:
	return _active and ctx != null and ctx.controller != null and _held >= ctx.controller.hand_shot_tap_time


func arm_point() -> Vector3:
	if ctx != null and ctx.rig != null and ctx.rig.camera != null:
		return ctx.rig.aim_target_point()
	return super.arm_point()


func uses_targeting() -> bool:
	return true


func _ratio(controller: HandController) -> float:
	return clampf((_spent - controller.hand_shot_cost_min) / maxf(controller.hand_shot_cost_max - controller.hand_shot_cost_min, 0.01), 0.0, 1.0)


## Launches the projectile along the crosshair; the locked target (if any) bends it in.
func _fire() -> void:
	var controller: HandController = ctx.controller
	var player: PlayerController = ctx.player
	var chest: Vector3 = player.global_position + Vector3.UP * CHEST_HEIGHT
	var direction: Vector3 = player.visual_root.global_basis.z.normalized()
	if ctx.rig != null and ctx.rig.camera != null:
		direction = ctx.rig.aim_direction_from(chest)
	var ratio: float = _ratio(controller)
	var reach: float = lerpf(controller.hand_small_range, controller.hand_big_range, ratio)
	var target: Interactable = null
	var targeting: Targeting = controller.targeting
	if targeting != null and is_instance_valid(targeting.target) and (targeting.state == Targeting.State.VALID or targeting.state == Targeting.State.VALID_BIG):
		target = targeting.target
	var projectile: ShotProjectile = PROJECTILE_SCENE.instantiate() as ShotProjectile
	var parent: Node = player.get_parent()
	if projectile == null or parent == null or not direction.is_finite():
		# No shot can leave the hand: give the paid energy back instead of losing it (CR-01).
		if projectile != null:
			projectile.free()
		_refund()
		_held = 0.0
		return
	var spent: float = _spent
	_spent = 0.0
	_held = 0.0
	_report_drained()
	controller.start_cooldown(controller.hand_cooldown)
	parent.add_child(projectile)
	var module_id: StringName = controller.active_def.id if controller.active_def != null else &"remote_trigger"
	projectile.setup(chest, direction, spent, controller.hand_shot_speed, reach, target, controller.hand_shot_turn_rate, module_id, controller.hand_shot_big_energy, player, ratio)
	EventBus.shot_fired.emit(chest, direction, spent)


## Gives the energy paid for the current charge back to the arm and reports the amount once (energy_gained, &"shot_refund").
func _refund() -> void:
	_report_drained()
	var paid: float = _spent
	_spent = 0.0
	if paid <= 0.0 or ctx == null or ctx.player == null or ctx.player.arm_energy == null:
		return
	var back: float = ctx.player.arm_energy.gain(paid, &"shot_refund")
	if back > 0.0:
		EventBus.energy_gained.emit(back, &"shot_refund")


## Sends the charge drain as one energy_spent(total, &"shot"); the press already reported the tap cost through try_spend.
func _report_drained() -> void:
	var drained: float = _drained
	_drained = 0.0
	if ctx != null and ctx.player != null and ctx.player.arm_energy != null:
		ctx.player.arm_energy.report_spent(drained, &"shot")
