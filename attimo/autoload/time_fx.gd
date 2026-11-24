extends Node
## TimeFx: the sole writer of Engine.time_scale (GAME-FEEL rule: assign, never multiply). A source (the Loader now, a hitstop
## in Phase 11) asks for a scale with request(source, scale) and gives it back with release(source); the lowest live request wins and
## the world runs at 1.0 when none is left. Every exit path of a source must release: the Loader state does it in exit() and in
## _exit_tree(), this node restores 1.0 when it leaves the tree and tests call clear_all() in their teardown, so a slow world can
## never outlive its cause.
##
## Slow motion scales every delta (_process and _physics_process), not the physics tick rate. Anything that has to run in real time
## (the Loader hold clock, the free camera, HUD rings) reads unscaled(delta). A scale is clamped to MIN_SCALE .. 1.0 and a
## non-finite request is ignored, so a bad slider can neither freeze the game nor speed it up.
## Engine fact (probed headless in 4.7.2, WR-01): the main loop reads Engine.time_scale ONCE at the start of an iteration and scales
## every physics step and the process step of that iteration with it. A write mid-iteration only lands in the next one, so unscaled()
## divides by the scale captured at the start of the current iteration (the process frame number tells iterations apart), never by
## the value just written.

## Smallest scale a request can reach. The engine wants a time scale above 0.
const MIN_SCALE: float = 0.05

var _requests: Dictionary[StringName, float] = {}
## Per source: the id of its latest pulse, so a late timer of an older pulse never gives back a newer request.
var _pulse_ids: Dictionary[StringName, int] = {}
var _pulse_counter: int = 0
## The time scale that produced the deltas of the current main-loop iteration, and the process frame it was captured in.
var _frame_scale: float = 1.0
var _frame_scale_frame: int = -1


## Asks for the time scale `scale` on behalf of `source`. A second call of the same source replaces its request.
func request(source: StringName, scale: float) -> void:
	if not is_finite(scale):
		return
	_requests[source] = clampf(scale, MIN_SCALE, 1.0)
	_apply()


## A short slow-down of `real_seconds` of REAL time (the hitstop of the Loader release): request(source, scale), and a timer that
## ignores the time scale gives it back. The timer only releases its own pulse: after clear_all() or a newer pulse of the same
## source a late callback changes nothing. A non-finite or non-positive duration or scale is ignored.
func pulse(source: StringName, scale: float, real_seconds: float) -> void:
	if not is_finite(scale) or not is_finite(real_seconds) or real_seconds <= 0.0 or not is_inside_tree():
		return
	request(source, scale)
	_pulse_counter += 1
	var id: int = _pulse_counter
	_pulse_ids[source] = id
	# process_always, not in physics, ignores the time scale (RESEARCH A4): the duration is real seconds.
	get_tree().create_timer(real_seconds, true, false, true).timeout.connect(_end_pulse.bind(source, id))


func _end_pulse(source: StringName, id: int) -> void:
	if _pulse_ids.get(source, -1) != id:
		return
	_pulse_ids.erase(source)
	release(source)


## Gives back the request of `source`. Unknown sources are ignored.
func release(source: StringName) -> void:
	if _requests.erase(source):
		_apply()


## Gives back every request: the world runs at 1.0 again.
func clear_all() -> void:
	_requests.clear()
	_pulse_ids.clear()
	_apply()


## The seconds of REAL time that the scaled `delta` of a process or physics tick stands for.
## Divides by the scale of the current iteration, so the frame a request or release lands in is not over-counted.
func unscaled(delta: float) -> float:
	_sync_frame_scale()
	return delta / maxf(_frame_scale, 0.01)


## The sources that hold a request right now (for tests and the debug overlay).
func active_sources() -> Array[StringName]:
	var sources: Array[StringName] = []
	for source: StringName in _requests:
		sources.append(source)
	return sources


## Records the engine scale once per iteration, before anything in that iteration writes it (this node is the sole writer).
func _sync_frame_scale() -> void:
	var frame: int = Engine.get_process_frames()
	if frame != _frame_scale_frame:
		_frame_scale_frame = frame
		_frame_scale = Engine.time_scale


func _apply() -> void:
	_sync_frame_scale()
	var lowest: float = 1.0
	for scale: float in _requests.values():
		lowest = minf(lowest, scale)
	Engine.time_scale = lowest


func _exit_tree() -> void:
	Engine.time_scale = 1.0
