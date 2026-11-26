class_name HandModule
extends Node
## Base class of hand modules. Modules own behaviour only: no mesh, the arm never changes (D-24).
## The HandController routes the use button to the active module through the callbacks below: on_use_pressed once on the press,
## on_use_held every physics tick while the button stays down, on_use_released once on the release.
## A module that owns an energy effect talks to ArmEnergy only through gain / try_spend / refuse, never by writing the value.

var ctx: HandContext = null


## Called once after the module became a child of the HandController.
func activate(context: HandContext) -> void:
	ctx = context


## Called before the module is freed (also while the button is still held: a switch mid-hold ends the run).
func deactivate() -> void:
	pass


## The use button went down.
func on_use_pressed() -> void:
	pass


## The use button is down; called every physics tick after the press, `delta` in seconds.
func on_use_held(_delta: float) -> void:
	pass


## The use button was released.
func on_use_released() -> void:
	pass


## 0..1 progress of the module's charge for the crosshair ring (0 when it does not charge).
func charge_ratio() -> float:
	return 0.0


## True while the module wants the arm stretched out (a drain, a charge).
func holds_arm_out() -> bool:
	return false


## The world point the stretched arm points at while holds_arm_out() is true, or (INF, INF, INF) for none.
func arm_point() -> Vector3:
	return Vector3(INF, INF, INF)

