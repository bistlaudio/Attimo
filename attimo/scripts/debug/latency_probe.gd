class_name LatencyProbe
extends Node
## Debug-only latency probe (FEEL-06, D-22). Stamps every jump and dash press in _input and measures the time to the
## matching gameplay fact on the EventBus, so the number is the input-to-state path and nothing else. It never touches
## gameplay code: nothing calls it, it only listens. Release builds drop it (REL-03, Phase 15).
## The figure excludes display, compositor and USB latency. After a fact it also records the time to the first drawn
## frame (last_frame_ms); that signal may never fire headless, so the value stays -1.0 there.

## A press whose fact never came (a jump press in mid-air, where there is no air jump) must not match a much later fact.
const STALE_USEC: int = 500000

## Milliseconds from a jump press to the jumped / long_jumped fact, one entry per press.
var jump_samples_ms: PackedFloat64Array = PackedFloat64Array()
## Milliseconds from a dash press to the dash_started fact, one entry per press.
var dash_samples_ms: PackedFloat64Array = PackedFloat64Array()
## Milliseconds from the last fact to the first frame drawn after it, -1.0 if no frame was drawn since.
var last_frame_ms: float = -1.0

var _jump_stamp_usec: int = -1
var _dash_stamp_usec: int = -1
var _frame_fact_usec: int = -1


func _ready() -> void:
	EventBus.jumped.connect(_on_jump_fact)
	EventBus.long_jumped.connect(_on_jump_fact)
	EventBus.dash_started.connect(_on_dash_fact)


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"jump"):
		_jump_stamp_usec = Time.get_ticks_usec()
	elif event.is_action_pressed(&"dash"):
		_dash_stamp_usec = Time.get_ticks_usec()


## {count: int, median_ms: float, max_ms: float} for kind &"jump" or &"dash".
func summary(kind: StringName) -> Dictionary:
	var samples: PackedFloat64Array = jump_samples_ms if kind == &"jump" else dash_samples_ms
	if samples.is_empty():
		return {"count": 0, "median_ms": 0.0, "max_ms": 0.0}
	var sorted: PackedFloat64Array = samples.duplicate()
	sorted.sort()
	var middle: int = sorted.size() / 2
	var median: float = sorted[middle] if sorted.size() % 2 == 1 else (sorted[middle - 1] + sorted[middle]) * 0.5
	return {"count": sorted.size(), "median_ms": median, "max_ms": sorted[sorted.size() - 1]}


func clear() -> void:
	jump_samples_ms.clear()
	dash_samples_ms.clear()
	last_frame_ms = -1.0


## Variadic: the jump facts have different signatures (position, or position and stage).
func _on_jump_fact(..._args: Array) -> void:
	var elapsed: float = _elapsed_ms(_jump_stamp_usec)
	_jump_stamp_usec = -1
	if elapsed >= 0.0:
		jump_samples_ms.append(elapsed)
		_watch_next_frame()


func _on_dash_fact(..._args: Array) -> void:
	var elapsed: float = _elapsed_ms(_dash_stamp_usec)
	_dash_stamp_usec = -1
	if elapsed >= 0.0:
		dash_samples_ms.append(elapsed)
		_watch_next_frame()


## Milliseconds since `stamp_usec`, or -1.0 when there is no pending press or it is stale.
func _elapsed_ms(stamp_usec: int) -> float:
	if stamp_usec < 0:
		return -1.0
	var age: int = Time.get_ticks_usec() - stamp_usec
	if age > STALE_USEC:
		return -1.0
	return float(age) / 1000.0


func _watch_next_frame() -> void:
	_frame_fact_usec = Time.get_ticks_usec()
	if not RenderingServer.frame_post_draw.is_connected(_on_frame_drawn):
		RenderingServer.frame_post_draw.connect(_on_frame_drawn, CONNECT_ONE_SHOT)


func _on_frame_drawn() -> void:
	last_frame_ms = float(Time.get_ticks_usec() - _frame_fact_usec) / 1000.0
