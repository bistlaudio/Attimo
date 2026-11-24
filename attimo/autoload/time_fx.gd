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

## Smallest scale a request can reach. The engine wants a time scale above 0.
const MIN_SCALE: float = 0.05

var _requests: Dictionary[StringName, float] = {}


## Asks for the time scale `scale` on behalf of `source`. A second call of the same source replaces its request.
func request(source: StringName, scale: float) -> void:
	if not is_finite(scale):
		return
	_requests[source] = clampf(scale, MIN_SCALE, 1.0)
	_apply()


## Gives back the request of `source`. Unknown sources are ignored.
func release(source: StringName) -> void:
	if _requests.erase(source):
		_apply()


## Gives back every request: the world runs at 1.0 again.
func clear_all() -> void:
	_requests.clear()
	_apply()


## The seconds of REAL time that the scaled `delta` of a process or physics tick stands for.
func unscaled(delta: float) -> float:
	return delta / maxf(Engine.time_scale, 0.01)


## The sources that hold a request right now (for tests and the debug overlay).
func active_sources() -> Array[StringName]:
	var sources: Array[StringName] = []
	for source: StringName in _requests:
		sources.append(source)
	return sources


func _apply() -> void:
	var lowest: float = 1.0
	for scale: float in _requests.values():
		lowest = minf(lowest, scale)
	Engine.time_scale = lowest


func _exit_tree() -> void:
	Engine.time_scale = 1.0
