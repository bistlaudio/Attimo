class_name HandController
extends Node
## The hand: near contact and module routing by registry id (HAND-01, D-24, D-45). The shot is gone; left click runs the Extractor, the module
## system stays in code but dormant (the Extractor is the only wheel module). There is no aim hold (D-15).
## Child of the Player. It names no module class: modules come from the registry and are driven through HandModule.
## It never writes movement state.

signal module_changed(def: HandModuleDef)

@export var registry: ModuleRegistry
@export var default_module_id: StringName = &"extractor"
## Reach in m of near contact, measured from the player origin to the Interactable point (D-08).
@export_range(0.5, 5.0, 0.1) var hand_near_range: float = 2.2
## Reach in m of the Extractor, measured from the chest to the energy source (ENRG-02).
@export_range(1.0, 10.0, 0.5) var hand_extract_range: float = 4.0
## Cone half angle in degrees around the crosshair direction inside which the Extractor finds a source.
@export_range(5.0, 90.0, 1.0) var hand_extract_angle: float = 35.0

var active_def: HandModuleDef = null
var active_module: HandModule = null
## True while the arm is stretched out: near contact, the Extractor, the Loader hold (D-27). Presentation state of the hand.
var arm_out: bool = false
## The world point the stretched arm points at (the near target, else the module point).
var arm_out_point: Vector3 = Vector3.ZERO
## The Interactable held by near contact, or null.
var near_target: Interactable = null
## The nearest near-contact Interactable in reach while no contact is held (the HUD E prompt), else null (D-02).
var prompt_target: Interactable = null

var _player: PlayerController = null
var _context: HandContext = HandContext.new()
var _use_active: bool = false


func _ready() -> void:
	add_to_group(&"hand_controller")
	_player = get_parent() as PlayerController
	if _player == null:
		set_physics_process(false)
		return
	_context.player = _player
	_context.controller = self
	equip(default_module_id)


## Equips the registry module `id`. False for an unknown id, a debug-only module in a release build, or no registry. Equipping the id that is
## already active is a no-op that returns true, so a stray key press never tears down a running extraction (T-05.1-20).
func equip(id: StringName) -> bool:
	if registry == null:
		return false
	if active_def != null and active_module != null and active_def.id == id:
		return true
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
	active_def = def
	active_module = module
	add_child(module)
	_context.rig = _player.camera_rig() if _player != null else null
	module.activate(_context)
	module_changed.emit(def)
	EventBus.hand_module_changed.emit(def.id)
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


func _physics_process(delta: float) -> void:
	_context.rig = _player.camera_rig()
	_tick_near(delta)
	var loader_hold: bool = _player.loader_active()
	var module_arm: bool = active_module != null and active_module.holds_arm_out()
	arm_out = near_target != null or loader_hold or module_arm
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


## Routes the use button to the active module: pressed once, held every tick, released once.
func _route_use(delta: float) -> void:
	if not _use_active and Input.is_action_just_pressed(&"use_hand"):
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
