class_name HandController
extends Node
## The hand: charge, cooldown and module routing by registry id (HAND-01, D-05, D-07, D-24). It fires from the hip: there is no aim hold (D-15).
## Child of the Player. It names no module class: modules come from the registry and are driven through HandModule.
## It never writes movement state.

signal module_changed(def: HandModuleDef)

@export var registry: ModuleRegistry
@export var default_module_id: StringName = &"remote_trigger"
## Seconds after a shot before the next charge may start (D-07).
@export_range(0.0, 2.0, 0.05) var hand_cooldown: float = 0.25
## Reach in m of a tap shot (the shortest range; it grows with the charge up to hand_big_range, D-17).
@export_range(1.0, 60.0, 0.5) var hand_small_range: float = 15.0
## Reach in m of a fully charged shot.
@export_range(1.0, 60.0, 0.5) var hand_big_range: float = 25.0

## Cone half angle in degrees within which a valid Interactable snaps the pulse (D-14, CAM-05).
@export_range(0.5, 10.0, 0.1) var hand_assist_angle: float = 3.5
## The current target is kept until it leaves hand_assist_angle times this factor (hysteresis).
@export_range(1.0, 3.0, 0.05) var hand_assist_hold_factor: float = 1.6
## A candidate replaces the current target only when it is this many degrees closer to the crosshair.
@export_range(0.0, 5.0, 0.1) var hand_assist_switch_margin: float = 1.0
## Seconds a target that failed (angle or line of sight) is still held before it is released.
@export_range(0.0, 0.5, 0.01) var hand_assist_drop_delay: float = 0.1
## Reach in m of near contact, measured from the player origin to the Interactable point (D-08).
@export_range(0.5, 5.0, 0.1) var hand_near_range: float = 2.2
## Seconds the arm stays out after a pulse (presentation only).
@export_range(0.0, 1.0, 0.05) var hand_shot_arm_time: float = 0.25
## Energy a tap shot costs; below it the shot is refused and the arm flickers grey (D-18).
@export_range(1.0, 50.0, 0.5) var hand_shot_cost_min: float = 10.0
## Energy a fully charged shot costs in total (D-17).
@export_range(1.0, 100.0, 0.5) var hand_shot_cost_max: float = 25.0
## Seconds the charge takes from hand_shot_cost_min to hand_shot_cost_max once it started.
@export_range(0.1, 3.0, 0.05) var hand_shot_charge_time: float = 0.8
## Seconds the button must be held before the charge starts draining (a shorter press is a tap).
@export_range(0.0, 0.5, 0.01) var hand_shot_tap_time: float = 0.12
## Flight speed of the shot in m/s.
@export_range(5.0, 120.0, 1.0) var hand_shot_speed: float = 40.0
## Degrees per second the shot turns toward a locked target (the bend, D-19).
@export_range(0.0, 2000.0, 10.0) var hand_shot_turn_rate: float = 540.0
## The shot is BIG (opens heavy mechanisms) from this much energy spent (D-24).
@export_range(1.0, 100.0, 0.5) var hand_shot_big_energy: float = 25.0
## Reach in m of the Extractor, measured from the chest to the energy source (ENRG-02).
@export_range(1.0, 10.0, 0.5) var hand_extract_range: float = 4.0
## Cone half angle in degrees around the crosshair direction inside which the Extractor finds a source.
@export_range(5.0, 90.0, 1.0) var hand_extract_angle: float = 35.0

var active_def: HandModuleDef = null
var active_module: HandModule = null
var charging: bool = false
var charge_ratio: float = 0.0
var cooldown_left: float = 0.0
var shots_fired: int = 0
## The aim assist, a child created in _ready.
var targeting: Targeting = null
## True while the arm is stretched out: near contact, shortly after a pulse, the Loader hold (D-27). Presentation state of the hand.
var arm_out: bool = false
## The world point the stretched arm points at (the near target, else the last pulse point).
var arm_out_point: Vector3 = Vector3.ZERO
## True while the shot module is equipped (plan 05-04 adds the energy condition): Interactables glow SHOT_READY. Changes emit
## EventBus.shot_ready_changed.
var shot_ready: bool = false
## The Interactable held by near contact, or null.
var near_target: Interactable = null
## The nearest near-contact Interactable in reach while no contact is held (the HUD E prompt), else null (D-02).
var prompt_target: Interactable = null

var _shot_arm_left: float = 0.0
var _player: PlayerController = null
var _context: HandContext = HandContext.new()
var _use_active: bool = false


func _ready() -> void:
	add_to_group(&"hand_controller")
	targeting = Targeting.new()
	targeting.name = &"Targeting"
	add_child(targeting)
	_player = get_parent() as PlayerController
	if _player == null:
		set_physics_process(false)
		return
	EventBus.shot_fired.connect(_on_shot_fired)
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
		_use_active = false
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
	_update_shot_ready()
	if targeting != null and not module.uses_targeting():
		targeting.release()
	return true


## Equips the module `step` places along cycle_ids(), wrapping around. A debug-only module is never reached by cycling (T-05-13).
func cycle(step: int) -> void:
	var ids: Array[StringName] = cycle_ids()
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


## Registry ids the wheel and the module keys reach: available_ids() without the debug-only defs (Pitfall 6).
func cycle_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if registry == null:
		return result
	for def: HandModuleDef in registry.modules:
		if def != null and not def.debug_only:
			result.append(def.id)
	return result


## Starts the shot cooldown for `seconds` (modules call it when they fire).
func start_cooldown(seconds: float) -> void:
	if is_finite(seconds):
		cooldown_left = maxf(cooldown_left, seconds)


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	_update_shot_ready()
	_context.rig = _player.camera_rig()
	# The assist runs first, so a shot decided on this tick reads this tick's target (Pitfall 7).
	if targeting != null and active_module != null:
		if active_module.uses_targeting():
			targeting.update(delta)
		else:
			targeting.release()
	_tick_near(delta)
	_shot_arm_left = maxf(_shot_arm_left - delta, 0.0)
	var loader_hold: bool = _player.loader_active()
	var module_arm: bool = active_module != null and active_module.holds_arm_out()
	arm_out = near_target != null or _shot_arm_left > 0.0 or loader_hold or module_arm
	if module_arm and near_target == null and not loader_hold:
		var module_point: Vector3 = active_module.arm_point()
		if module_point.is_finite():
			arm_out_point = module_point
	if loader_hold and near_target == null and _context.rig != null:
		# The Loader hold points the arm along the crosshair, where the discharge goes.
		arm_out_point = _context.rig.aim_target_point()
	if Input.is_action_just_pressed(&"module_next"):
		cycle(1)
	elif Input.is_action_just_pressed(&"module_prev"):
		cycle(-1)
	_pick_module_key()
	if active_module == null:
		return
	_route_use(delta)
	charge_ratio = active_module.charge_ratio()
	charging = _use_active and charge_ratio > 0.0


## Routes the use button to the active module: pressed once (not during the cooldown), held every tick, released once.
func _route_use(delta: float) -> void:
	if not _use_active and cooldown_left <= 0.0 and Input.is_action_just_pressed(&"use_hand"):
		_use_active = true
		active_module.on_use_pressed()
	if not _use_active:
		return
	if Input.is_action_just_released(&"use_hand") or not Input.is_action_pressed(&"use_hand"):
		_use_active = false
		active_module.on_use_released()
		return
	active_module.on_use_held(delta)


## Keys 1 and 2 equip the first and second wheel module.
func _pick_module_key() -> void:
	var ids: Array[StringName] = cycle_ids()
	if Input.is_action_just_pressed(&"module_1") and ids.size() > 0:
		equip(ids[0])
	elif Input.is_action_just_pressed(&"module_2") and ids.size() > 1:
		equip(ids[1])


## Recomputes shot_ready (the shot module is the active one) and announces a change once.
func _update_shot_ready() -> void:
	var ready: bool = active_def != null and active_def.id == &"remote_trigger"
	if ready == shot_ready:
		return
	shot_ready = ready
	EventBus.shot_ready_changed.emit(ready)


func _reset_charge() -> void:
	charging = false
	charge_ratio = 0.0


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


func _on_shot_fired(origin: Vector3, direction: Vector3, _energy: float) -> void:
	_shot_arm_left = hand_shot_arm_time
	shots_fired += 1
	if near_target != null:
		return
	if _context.rig != null:
		arm_out_point = _context.rig.aim_target_point()
	elif origin.is_finite() and direction.is_finite():
		arm_out_point = origin + direction * hand_small_range
