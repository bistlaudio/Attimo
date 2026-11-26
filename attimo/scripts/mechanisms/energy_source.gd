class_name EnergySource
extends Node3D
## Energy source (kit block "energy source", GAME-DESIGN 6.8): a glowing capsule or a broken machine that the Extractor drains
## into the arm. It is the only income object next to the passive charge and the charge button (ENRG-02).
##
## Interface (guardrail 4):
##   exports  amount (whole steps it holds, D-42: capsule 3, broken machine 5), step_interval (seconds between two steps of a drain),
##            respawn_time (seconds until it refills, 0 = never), glow_meshes (meshes switched between glow_energy and glow_off),
##            core (the point the Extractor aims at)
##   calls    take_step() -> int (1 while steps are left, else 0), is_available(), target_point(), reset()
##   signals  EventBus.energy_source_emptied(position, amount) once when the last step is taken
##   groups   energy_source (the Extractor's candidates) and mechanism (FallReset.reset)
## It never touches the player or ArmEnergy: the Extractor takes from here and calls ArmEnergy.gain itself (T-05-14).
## Contract test: tests/smoke/test_extractor.gd.

const GLOW_ON: StandardMaterial3D = preload("res://resources/mechanisms/glow_energy.tres")
const GLOW_OFF: StandardMaterial3D = preload("res://resources/mechanisms/glow_off.tres")
## Whole steps this source holds when full.
@export_range(1, 12, 1) var amount: int = 3
## Seconds between two steps while the Extractor drains it (the capsule is quick, the machine slower).
@export_range(0.05, 5.0, 0.05) var step_interval: float = 0.15
## Seconds after the last drop until it refills; 0 never refills (D-08).
@export_range(0.0, 120.0, 0.5) var respawn_time: float = 0.0
## Meshes whose material the empty and full look switches.
@export var glow_meshes: Array[MeshInstance3D] = []
## The point the Extractor aims at (this node when unset).
@export var core: Node3D

## Runtime state on the node (guardrail 2): what is left, whether it is empty, the refill countdown.
var remaining: int = -1
var empty: bool = false
var _refill_left: float = 0.0


func _ready() -> void:
	add_to_group(&"energy_source")
	add_to_group(&"mechanism")
	_apply_look()


func _physics_process(delta: float) -> void:
	if not empty or respawn_time <= 0.0:
		return
	_refill_left -= delta
	if _refill_left <= 0.0:
		_fill()


## Takes one whole step for the Extractor: returns 1 while steps are left, else 0. Goes empty (dark, one fact) when the last step leaves.
func take_step() -> int:
	if empty or _left() <= 0:
		return 0
	remaining = _left() - 1
	if remaining <= 0:
		remaining = 0
		_go_empty()
	return 1


## True while there are steps to take.
func is_available() -> bool:
	return not empty and _left() > 0


## The world point the Extractor aims at and the arm points to.
func target_point() -> Vector3:
	return core.global_position if core != null else global_position


## Full again at once (FallReset and room resets).
func reset() -> void:
	_fill()


func _left() -> int:
	return amount if remaining < 0 else remaining


func _go_empty() -> void:
	empty = true
	_refill_left = respawn_time
	_apply_look()
	EventBus.energy_source_emptied.emit(global_position, amount)


func _fill() -> void:
	empty = false
	remaining = amount
	_refill_left = 0.0
	_apply_look()


func _apply_look() -> void:
	var material: StandardMaterial3D = GLOW_OFF if empty else GLOW_ON
	for mesh: MeshInstance3D in glow_meshes:
		if is_instance_valid(mesh):
			mesh.material_override = material
