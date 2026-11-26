class_name Receiver
extends Node
## Receiver component (Phase 05.1, KIT-01, D-13, D-14): lets a kit block be switched by a Trigger. A child node of the block; the block
## asks `is_on()` (Timed motion SWITCHED, Impulse pad) and may listen to `switched`. RUN_WHILE_ON follows the source (on while it is on),
## REVERSE_ON_SIGNAL flips on every rising edge (D-18 of Phase 4). It replaces Mechanism.source for kit blocks. Exactly two users: the
## drawbridge and the switched speed pad. The component only reads the source; a missing source warns once and stays off.

enum Behaviour { RUN_WHILE_ON, REVERSE_ON_SIGNAL }

## Fired when the receiver turns on or off.
signal switched(on: bool)

## The Trigger (or logic node) that switches this receiver.
@export var source: Trigger
## RUN_WHILE_ON follows the source; REVERSE_ON_SIGNAL flips on each rising edge.
@export var behaviour: Behaviour = Behaviour.RUN_WHILE_ON

var _on: bool = false


func _ready() -> void:
	add_to_group(&"mechanism")
	if source == null:
		push_warning("Receiver %s has no source" % get_path())
		return
	source.active_changed.connect(_on_source_changed)
	_read_source()


func is_on() -> bool:
	return _on


## Back to the load state, WR-05 pattern: RUN_WHILE_ON re-reads the source (an always-on source does not emit again on its own reset),
## REVERSE_ON_SIGNAL clears the toggle. Does not fire `switched` for the re-read value of a running source.
func reset() -> void:
	if behaviour == Behaviour.RUN_WHILE_ON and source != null and is_instance_valid(source):
		_set_on(source.is_active)
	else:
		_set_on(false)


func _read_source() -> void:
	if behaviour == Behaviour.RUN_WHILE_ON:
		_set_on(source.is_active)
	elif source.is_active:
		_set_on(true)


func _on_source_changed(active: bool) -> void:
	if behaviour == Behaviour.RUN_WHILE_ON:
		_set_on(active)
	elif active:
		_set_on(not _on)


func _set_on(value: bool) -> void:
	if value == _on:
		return
	_on = value
	switched.emit(value)
