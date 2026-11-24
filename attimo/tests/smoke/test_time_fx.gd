extends RefCounted
## Plan 05-01 (HAND-04): TimeFx is the sole writer of Engine.time_scale. The lowest requested scale wins, releasing a source
## gives the next one, clear_all() returns to 1.0, non-finite requests change nothing, a request of 0 clamps to MIN_SCALE and
## unscaled() turns a scaled delta back into real seconds.

const TOLERANCE: float = 1e-6


func run(tree: SceneTree, check: Callable) -> void:
	var fx: Node = tree.root.get_node_or_null("TimeFx")
	check.call(fx != null, "the TimeFx autoload exists")
	if fx == null:
		return
	fx.call(&"clear_all")
	check.call(Engine.time_scale == 1.0, "clear_all leaves the time scale at 1.0 (got %.3f)" % Engine.time_scale)

	fx.call(&"request", &"a", 0.25)
	check.call(Engine.time_scale == 0.25, "request(a, 0.25) sets the time scale to 0.25 (got %.3f)" % Engine.time_scale)
	fx.call(&"request", &"b", 0.5)
	check.call(Engine.time_scale == 0.25, "the lowest request wins: b 0.5 keeps 0.25 (got %.3f)" % Engine.time_scale)
	fx.call(&"release", &"a")
	check.call(Engine.time_scale == 0.5, "releasing a gives the next request, 0.5 (got %.3f)" % Engine.time_scale)
	fx.call(&"clear_all")
	check.call(Engine.time_scale == 1.0, "clear_all returns to 1.0 (got %.3f)" % Engine.time_scale)

	fx.call(&"request", &"nan", NAN)
	check.call(Engine.time_scale == 1.0, "a NAN request changes nothing (got %.3f)" % Engine.time_scale)
	fx.call(&"request", &"inf", INF)
	check.call(Engine.time_scale == 1.0, "an INF request changes nothing (got %.3f)" % Engine.time_scale)
	var sources: Array = fx.call(&"active_sources") as Array
	check.call(sources.is_empty(), "a non-finite request registers no source (got %s)" % [sources])

	var min_scale: float = fx.get(&"MIN_SCALE") as float
	fx.call(&"request", &"c", 0.0)
	check.call(is_equal_approx(min_scale, 0.05) and Engine.time_scale == min_scale, "request(c, 0.0) clamps to MIN_SCALE %.2f (got %.3f)" % [min_scale, Engine.time_scale])
	fx.call(&"release", &"c")
	check.call(Engine.time_scale == 1.0, "releasing the only source returns to 1.0 (got %.3f)" % Engine.time_scale)

	fx.call(&"request", &"d", 0.25)
	var real: float = fx.call(&"unscaled", 1.0 / 240.0) as float
	check.call(absf(real - 1.0 / 60.0) < TOLERANCE, "unscaled(1/240) at scale 0.25 is 1/60 s (got %.7f)" % real)
	sources = fx.call(&"active_sources") as Array
	check.call(sources.size() == 1 and sources[0] == &"d", "active_sources lists the live request (got %s)" % [sources])

	fx.call(&"clear_all")
	check.call(Engine.time_scale == 1.0, "the test leaves the time scale at 1.0 (got %.3f)" % Engine.time_scale)
