class_name HandController
extends Node
## Stub, filled in Task 2.

signal module_changed(def: HandModuleDef)

@export var registry: ModuleRegistry
@export var default_module_id: StringName = &"remote_trigger"
@export_range(0.05, 2.0, 0.05) var hand_charge_threshold: float = 0.4
@export_range(0.0, 2.0, 0.05) var hand_cooldown: float = 0.25
@export_range(1.0, 60.0, 0.5) var hand_small_range: float = 15.0
@export_range(1.0, 60.0, 0.5) var hand_big_range: float = 25.0

var active_def: HandModuleDef = null
var active_module: HandModule = null
var charging: bool = false
var charge_ratio: float = 0.0
var cooldown_left: float = 0.0
var shots_fired: int = 0


func equip(_id: StringName) -> bool:
	return false


func cycle(_step: int) -> void:
	pass


func available_ids() -> Array[StringName]:
	return []
