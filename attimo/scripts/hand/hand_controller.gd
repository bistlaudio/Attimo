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

var active_def: HandModuleDef = null
var active_module: HandModule = null
var charging: bool = false
var charge_ratio: float = 0.0
var cooldown_left: float = 0.0
var shots_fired: int = 0

var _player: PlayerController = null
var _context: HandContext = HandContext.new()
var _charge_time: float = 0.0


func _ready() -> void:
	add_to_group(&"hand_controller")
	_player = get_parent() as PlayerController
	if _player == null:
		set_physics_process(false)
		return
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
	if not _player.aiming:
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
