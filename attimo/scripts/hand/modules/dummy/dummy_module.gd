class_name DummyModule
extends HandModule
## Debug-only module that proves "one folder plus one registry entry" (D-24). It counts the callbacks and does nothing else.

var use_count: int = 0
var press_count: int = 0
var held_ticks: int = 0
var deactivated: bool = false
## The callbacks in the order they arrived: &"pressed", &"held" (once per tick), &"released".
var log: Array[StringName] = []


func on_use_pressed() -> void:
	press_count += 1
	log.append(&"pressed")


func on_use_held(_delta: float) -> void:
	held_ticks += 1
	log.append(&"held")


func on_use_released() -> void:
	use_count += 1
	log.append(&"released")


func deactivate() -> void:
	deactivated = true
