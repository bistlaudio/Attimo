class_name DummyModule
extends HandModule
## Debug-only module that proves "one folder plus one registry entry" (D-24). It counts uses and does nothing else.

var use_count: int = 0


func on_use_released(_big: bool) -> void:
	use_count += 1
