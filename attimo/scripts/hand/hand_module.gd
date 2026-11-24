class_name HandModule
extends Node
## Base class of hand modules. Modules own behaviour only: no mesh, the arm never changes (D-24).

var ctx: HandContext = null


## Called once after the module became a child of the HandController.
func activate(context: HandContext) -> void:
	ctx = context


## Called before the module is freed.
func deactivate() -> void:
	pass


## True when the use button charges (small versus big) for this module.
func wants_charge() -> bool:
	return false


## The use button was released. `big` is true when the charge passed the threshold.
func on_use_released(_big: bool) -> void:
	pass
