class_name LogicOr
extends Trigger
## OR node (MECH-02, D-23): on while any of its sources is on. Invisible in game. Null entries are skipped with one
## warning (T-04-07); set_active emits only on change, so a wiring loop cannot recurse (T-04-08).

@export var sources: Array[Trigger] = []


func _ready() -> void:
	super._ready()
	var warned: bool = false
	for source: Trigger in sources:
		if source == null:
			if not warned:
				push_warning("LogicOr %s has an empty source entry" % name)
				warned = true
			continue
		source.active_changed.connect(_recompute)
	_recompute()


func _recompute(_active: bool = false) -> void:
	var any_on: bool = false
	for source: Trigger in sources:
		if source != null and is_instance_valid(source) and source.is_active:
			any_on = true
	set_active(any_on)


func reset() -> void:
	_recompute()
