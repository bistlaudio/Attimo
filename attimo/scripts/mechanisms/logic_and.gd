class_name LogicAnd
extends SignalSource
## AND node (MECH-02, D-23): on while all its sources are on and it has at least one. Invisible in game. Null entries
## are skipped with one warning (T-04-07); set_active emits only on change, so a wiring loop cannot recurse (T-04-08).

@export var sources: Array[SignalSource] = []


func _ready() -> void:
	super._ready()
	var warned: bool = false
	for source: SignalSource in sources:
		if source == null:
			if not warned:
				push_warning("LogicAnd %s has an empty source entry" % name)
				warned = true
			continue
		source.active_changed.connect(_recompute)
	_recompute()


func _recompute(_active: bool = false) -> void:
	var valid: int = 0
	var all_on: bool = true
	for source: SignalSource in sources:
		if source == null or not is_instance_valid(source):
			continue
		valid += 1
		all_on = all_on and source.is_active
	set_active(valid > 0 and all_on)


func reset() -> void:
	_recompute()
