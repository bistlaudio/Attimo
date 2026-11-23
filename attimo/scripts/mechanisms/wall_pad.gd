class_name WallPad
extends Mechanism
## Wandplatte (MOVE-12, MECH-04 D/E, D-09): a glowing brass-framed panel that the player can wall-run along (WALL_RUN) or kick off
## with a wall-jump (WALL_JUMP). While the signal is on the Panel body joins the group wall_run_surface or wall_jump_surface; the
## PlayerController and its FSM states do the rest. Only pads count, a plain wall never starts either move. The pad never moves
## the player itself and never writes its velocity (D-06): it is an engine collision body plus a group tag.

enum Mode { WALL_RUN, WALL_JUMP }

@export var mode: Mode = Mode.WALL_RUN

@onready var _panel: StaticBody3D = $Panel
@onready var _inlay: MeshInstance3D = $Inlay


func _ready() -> void:
	_panel.collision_layer = PhysicsLayers.WORLD
	_panel.collision_mask = 0
	_inlay.visible = false
	super._ready()


## The group the panel joins while the pad is on.
func surface_group() -> StringName:
	return &"wall_run_surface" if mode == Mode.WALL_RUN else &"wall_jump_surface"


func reset() -> void:
	super.reset()
	_apply(signal_on)


func _on_signal(on: bool) -> void:
	_apply(on)


func _apply(on: bool) -> void:
	_panel.remove_from_group(&"wall_run_surface")
	_panel.remove_from_group(&"wall_jump_surface")
	if on:
		_panel.add_to_group(surface_group())
	_inlay.visible = on
