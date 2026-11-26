class_name LogicThreshold
extends Trigger
## Threshold node (Phase 05.1, KIT-04, D-13, D-47): turns the level of an energy core into one switch signal. On while `source.level >= min_level`,
## so one core with three LogicThreshold nodes (levels 1, 2, 3) switches three outputs one after the other. Invisible in game, like the other logic
## nodes; it extends Trigger, so receivers and the AND / OR / timer nodes take it as a source. A missing source keeps it off with one warning.
## set_active emits only on a change, so a wiring loop cannot recurse.

## The Trigger whose level is read (an energy core).
@export var source: Trigger
## The level at which this node switches on (1 .. 3).
@export_range(1, 3, 1) var min_level: int = 1


func _ready() -> void:
	super._ready()
	if source == null:
		push_warning("LogicThreshold %s has no source" % name)
		return
	source.level_changed.connect(_recompute)
	_recompute()


func reset() -> void:
	super.reset()
	_recompute()


func _recompute(_level: int = 0) -> void:
	set_active(source != null and is_instance_valid(source) and source.level >= min_level)
