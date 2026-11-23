class_name HandController
extends Node
## The hand: aim-gated charge, cooldown and module routing by registry id (HAND-01, D-02, D-05, D-07, D-24).
## Child of the Player. It names no module class: modules come from the registry and are driven through HandModule.
## It never writes movement state.

signal module_changed(def: HandModuleDef)

@export var registry: ModuleRegistry
@export var default_module_id: StringName = &"remote_trigger"
## Seconds the use button must be held for a big pulse (D-05).
@export_range(0.05, 2.0, 0.05) var hand_charge_threshold: float = 0.4
## Seconds after a shot before the next charge may start (D-07).
@export_range(0.0, 2.0, 0.05) var hand_cooldown: float = 0.25
## Reach in m of a small pulse, measured from the player origin to the hit point (D-03).
@export_range(1.0, 60.0, 0.5) var hand_small_range: float = 15.0
## Reach in m of a big pulse.
@export_range(1.0, 60.0, 0.5) var hand_big_range: float = 25.0

## Cone half angle in degrees within which a valid Interactable snaps the pulse (D-14, CAM-05).
@export_range(0.5, 10.0, 0.1) var hand_assist_angle: float = 3.5
## The current target is kept until it leaves hand_assist_angle times this factor (hysteresis).
@export_range(1.0, 3.0, 0.05) var hand_assist_hold_factor: float = 1.6
## A candidate replaces the current target only when it is this many degrees closer to the crosshair.
@export_range(0.0, 5.0, 0.1) var hand_assist_switch_margin: float = 1.0
## Seconds a target that failed (angle or line of sight) is still held before it is released.
@export_range(0.0, 0.5, 0.01) var hand_assist_drop_delay: float = 0.1
## Look sensitivity factor while a valid target is held (sticky aim, D-14).
@export_range(0.2, 1.0, 0.05) var hand_sticky_factor: float = 0.6
## Rate in 1/s at which the sticky factor eases in and out.
@export_range(1.0, 20.0, 0.5) var hand_sticky_rate: float = 6.0
## Reach in m of near contact, measured from the player origin to the Interactable point (D-08).
@export_range(0.5, 5.0, 0.1) var hand_near_range: float = 2.2
## Seconds the arm stays out after a pulse (presentation only).
@export_range(0.0, 1.0, 0.05) var hand_shot_arm_time: float = 0.25
## DEBUG: use_hand fires without aim (bypasses D-02). Turn off before verification, the D-02 smoke tests expect it off.
@export var debug_fire_without_aim: bool = true

var active_def: HandModuleDef = null
var active_module: HandModule = null
var charging: bool = false
var charge_ratio: float = 0.0
var cooldown_left: float = 0.0
var shots_fired: int = 0
## The aim assist, a child created in _ready.
var targeting: Targeting = null
## True while the arm is stretched out: aiming, shortly after a pulse, near contact. Presentation state of the hand.
var arm_out: bool = false
## The world point the stretched arm points at (the near target, else the last pulse point).
var arm_out_point: Vector3 = Vector3.ZERO
## The Interactable held by near contact, or null.
var near_target: Interactable = null
## The nearest near-contact Interactable in reach while no contact is held (the HUD E prompt), else null (D-02).
var prompt_target: Interactable = null

var _shot_arm_left: float = 0.0
var _player: PlayerController = null
var _context: HandContext = HandContext.new()
var _charge_time: float = 0.0


func _ready() -> void:
	add_to_group(&"hand_controller")
	targeting = Targeting.new()
	targeting.name = &"Targeting"
	add_child(targeting)
	_player = get_parent() as PlayerController
	if _player == null:
		set_physics_process(false)
		return
	EventBus.pulse_fired.connect(_on_pulse_fired)
	_context.player = _player
	_context.controller = self
	equip(default_module_id)


## Equips the registry module `id`. False for an unknown id, a debug-only module in a release build, or no registry.
func equip(id: StringName) -> bool:
	if registry == null:
		return false
	var def: HandModuleDef = registry.find(id)
	if def == null or def.scene == null:
		return false
	if def.debug_only and not OS.is_debug_build():
		return false
	var module: HandModule = def.scene.instantiate() as HandModule
	if module == null:
		return false
	if active_module != null:
		active_module.deactivate()
		remove_child(active_module)
		active_module.queue_free()
	_reset_charge()
	active_def = def
	active_module = module
	add_child(module)
	_context.rig = _player.camera_rig() if _player != null else null
	module.activate(_context)
	module_changed.emit(def)
	EventBus.hand_module_changed.emit(def.id)
	return true


## Equips the module `step` places along available_ids(), wrapping around.
func cycle(step: int) -> void:
	var ids: Array[StringName] = available_ids()
	if ids.is_empty():
		return
	var index: int = ids.find(active_def.id) if active_def != null else -1
	index = posmod(index + step, ids.size())
	equip(ids[index])


## Registry ids that can be equipped in this build, in registry order.
func available_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if registry == null:
		return result
	for def: HandModuleDef in registry.modules:
		if def != null and (not def.debug_only or OS.is_debug_build()):
			result.append(def.id)
	return result


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	_context.rig = _player.camera_rig()
	# The assist runs first, so a shot decided on this tick reads this tick's target (Pitfall 7).
	if targeting != null:
		targeting.update(delta)
	# Near contact does not depend on aim (D-08), it works while aiming too.
	_tick_near(delta)
	_shot_arm_left = maxf(_shot_arm_left - delta, 0.0)
	arm_out = near_target != null or _shot_arm_left > 0.0 or _player.aiming
	if not _player.aiming and not debug_fire_without_aim:
		# D-02: nothing fires without aim, and releasing aim mid-charge cancels the shot.
		_reset_charge()
		return
	if Input.is_action_just_pressed(&"module_next"):
		cycle(1)
	elif Input.is_action_just_pressed(&"module_prev"):
		cycle(-1)
	if active_module == null:
		return
	if not charging and cooldown_left <= 0.0 and Input.is_action_just_pressed(&"use_hand"):
		charging = true
		_charge_time = 0.0
	if not charging:
		return
	if active_module.wants_charge():
		_charge_time += delta
		charge_ratio = clampf(_charge_time / hand_charge_threshold, 0.0, 1.0)
	if Input.is_action_just_released(&"use_hand"):
		# D-05: the shot happens on release, there is no auto-fire at the threshold.
		var big: bool = active_module.wants_charge() and _charge_time >= hand_charge_threshold
		_reset_charge()
		cooldown_left = hand_cooldown
		shots_fired += 1
		active_module.on_use_released(big)


func _reset_charge() -> void:
	charging = false
	charge_ratio = 0.0
	_charge_time = 0.0


## Near contact (D-08, D-09, D-10): interact next to an Interactable that accepts it starts the contact, holding interact
## keeps it, releasing it (or leaving hand_near_range) ends it. Presentation reads arm_out and the facts on the bus.
func _tick_near(delta: float) -> void:
	if near_target != null and not is_instance_valid(near_target):
		near_target = null
		EventBus.near_contact_changed.emit(false, arm_out_point)
	if near_target == null:
		# D-02: the HUD prompt marks the grabbable Interactable in reach, independent of input and of aim.
		prompt_target = _nearest_near_target()
		if Input.is_action_just_pressed(&"interact"):
			var candidate: Interactable = _nearest_near_target()
			if candidate != null and candidate.near_begin():
				near_target = candidate
				prompt_target = null
				arm_out_point = candidate.target_point()
				EventBus.near_contact_changed.emit(true, arm_out_point)
		return
	prompt_target = null
	if Input.is_action_pressed(&"interact") and _in_near_range(near_target):
		arm_out_point = near_target.target_point()
		near_target.near_hold(delta)
		return
	var ended: Interactable = near_target
	near_target = null
	ended.near_end()
	EventBus.near_contact_changed.emit(false, ended.target_point())


## The world point the E prompt hangs over, or (INF, INF, INF) when there is no prompt target.
func prompt_point() -> Vector3:
	if prompt_target == null or not is_instance_valid(prompt_target):
		return Vector3(INF, INF, INF)
	return prompt_target.target_point()


## The nearest Interactable in group interactable that accepts near contact and is within hand_near_range, or null.
func _nearest_near_target() -> Interactable:
	var best: Interactable = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"interactable"):
		var candidate: Interactable = node as Interactable
		if candidate == null or not candidate.accepts_near or not _in_near_range(candidate):
			continue
		var distance: float = _player.global_position.distance_to(candidate.target_point())
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _in_near_range(candidate: Interactable) -> bool:
	var point: Vector3 = candidate.target_point()
	return point.is_finite() and _player.global_position.distance_to(point) <= hand_near_range


func _on_pulse_fired(_origin: Vector3, point: Vector3, _size: int, _hit_valid: bool) -> void:
	_shot_arm_left = hand_shot_arm_time
	if near_target == null and point.is_finite():
		arm_out_point = point
