class_name MetricsOverlay
extends CanvasLayer
## Debug-only live metrics (D-21): jump height and distance per airtime, dash distance, chain stage, the latency
## summaries of its LatencyProbe child, and the tick-rate cycle for the low-rate camera check (D-22).
## It only listens to EventBus facts and reads the player, gameplay code never calls it. Release builds drop it (REL-03).
## debug_metrics (F4 / 9) toggles it, hidden at start. debug_tick_rate (F6 / 0) moves
## Engine.physics_ticks_per_second through TICK_RATES, the only values it can ever set.
## Place it after the player in the scene so it samples after the move.

## The fixed tick-rate cycle: 60 -> 120 -> 10 -> 60.
const TICK_RATES: Array[int] = [60, 120, 10]
const HISTORY_SIZE: int = 5

## The last closed airtime: {kind: String, height: float, distance: float, airtime: float}. Empty until one closes.
var last_jump: Dictionary = {}
## The last closed dash: {distance: float, in_air: bool, duration: float}. Empty until one closes.
var last_dash: Dictionary = {}
## The ground-jump chain stage from the last chain_stage_changed fact.
var chain_stage: int = 0
## The most recent closed airtimes, newest last.
var history: Array[Dictionary] = []

var _player: PlayerController
var _airborne: bool = false
var _last_ground_position: Vector3 = Vector3.ZERO
var _max_y: float = 0.0
var _air_time: float = 0.0
var _kind: String = ""
var _pending_kind: String = ""
var _dash_active: bool = false
var _dash_start: Vector3 = Vector3.ZERO
var _dash_in_air: bool = false
var _dash_time: float = 0.0

@onready var latency_probe: LatencyProbe = $LatencyProbe
@onready var _label: RichTextLabel = %Lines


func _ready() -> void:
	visible = false
	EventBus.jumped.connect(_on_jumped)
	EventBus.long_jumped.connect(_on_long_jumped)
	EventBus.dash_started.connect(_on_dash_started)
	EventBus.movement_state_changed.connect(_on_state_changed)
	EventBus.chain_stage_changed.connect(_on_chain_stage_changed)
	# Deferred, so the scene order of overlay and player does not matter.
	_find_player.call_deferred()


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as PlayerController
	if _player != null:
		_last_ground_position = _player.global_position


func _physics_process(delta: float) -> void:
	if _player == null:
		_find_player()
		return
	if _dash_active:
		_dash_time += delta
	var grounded: bool = _player.is_grounded()
	if not grounded and not _airborne:
		_begin_airtime()
	elif grounded and _airborne:
		_end_airtime()
	elif grounded:
		_last_ground_position = _player.global_position
	if _airborne:
		_air_time += delta
		_max_y = maxf(_max_y, _player.global_position.y)


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"debug_metrics"):
		visible = not visible
	elif event.is_action_pressed(&"debug_tick_rate"):
		var index: int = TICK_RATES.find(Engine.physics_ticks_per_second)
		Engine.physics_ticks_per_second = TICK_RATES[(index + 1) % TICK_RATES.size()]


func _begin_airtime() -> void:
	_airborne = true
	_air_time = 0.0
	_max_y = _player.global_position.y
	_kind = _pending_kind if _pending_kind != "" else "walk-off"
	_pending_kind = ""


func _end_airtime() -> void:
	_airborne = false
	last_jump = {
		"kind": _kind,
		"height": _max_y - _last_ground_position.y,
		"distance": Vector2(_player.global_position.x - _last_ground_position.x, _player.global_position.z - _last_ground_position.z).length(),
		"airtime": _air_time,
	}
	history.append(last_jump)
	if history.size() > HISTORY_SIZE:
		history.pop_front()
	_last_ground_position = _player.global_position


## A jump fact before the take-off names the airtime, one during it is appended to the kind.
func _note_jump(label: String) -> void:
	if _airborne:
		_kind = "%s+%s" % [_kind, label]
	else:
		_pending_kind = label


func _on_jumped(_position: Vector3) -> void:
	_note_jump("jump")


func _on_long_jumped(_position: Vector3, stage: int) -> void:
	_note_jump("long %d" % stage)


func _on_dash_started(position: Vector3, _direction: Vector3, in_air: bool) -> void:
	_dash_active = true
	_dash_start = position
	_dash_in_air = in_air
	_dash_time = 0.0


func _on_state_changed(from_state: StringName, _to_state: StringName) -> void:
	if from_state != &"Dash" or not _dash_active or _player == null:
		return
	_dash_active = false
	var offset: Vector3 = _player.global_position - _dash_start
	last_dash = {
		"distance": Vector2(offset.x, offset.z).length(),
		"in_air": _dash_in_air,
		"duration": _dash_time,
	}


func _on_chain_stage_changed(stage: int) -> void:
	chain_stage = stage


func _refresh() -> void:
	var lines: Array[String] = []
	lines.append("Tick rate: %d TPS (F6 cycles)   accumulated input: %s" % [Engine.physics_ticks_per_second, Input.use_accumulated_input])
	if last_jump.is_empty():
		lines.append("Jump: none yet")
	else:
		lines.append("Jump [%s]: height %.2f m, distance %.2f m, airtime %.2f s" % [last_jump.kind, last_jump.height, last_jump.distance, last_jump.airtime])
	if last_dash.is_empty():
		lines.append("Dash: none yet")
	else:
		lines.append("Dash: distance %.2f m, %s, %.2f s" % [last_dash.distance, "air" if last_dash.in_air else "ground", last_dash.duration])
	lines.append("Chain stage: %d" % chain_stage)
	var stack_stage: int = 0 if _player == null else _player.long_jump_stage
	var speed: float = 0.0 if _player == null else _player.horizontal_speed()
	lines.append("Long jump stage: %d" % stack_stage)
	lines.append("Speed: %.1f m/s" % speed)
	lines.append(_latency_line("Latency jump", &"jump"))
	lines.append(_latency_line("Latency dash", &"dash"))
	var frame_text: String = "n/a" if latency_probe.last_frame_ms < 0.0 else "%.1f ms" % latency_probe.last_frame_ms
	lines.append("Fact to drawn frame: %s" % frame_text)
	_label.text = "\n".join(lines)


func _latency_line(title: String, kind: StringName) -> String:
	var summary: Dictionary = latency_probe.summary(kind)
	if summary.count == 0:
		return "%s: no samples" % title
	return "%s: n=%d median %.1f ms, max %.1f ms" % [title, summary.count, summary.median_ms, summary.max_ms]
