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
	await _check_pulse(tree, check, fx)


# Plan 05-02 (D-04): pulse(source, scale, real_seconds) is a short slow-down that ends by itself in REAL time and only ever
# releases its own request.
func _check_pulse(tree: SceneTree, check: Callable, fx: Node) -> void:
	await tree.process_frame
	fx.call(&"clear_all")
	fx.call(&"pulse", &"hit", 0.05, 0.05)
	check.call(Engine.time_scale == 0.05, "pulse(hit, 0.05, 0.05) sets the time scale at once (got %.3f)" % Engine.time_scale)
	var ticks: int = 0
	while Engine.time_scale != 1.0 and ticks < 30:
		await tree.physics_frame
		ticks += 1
	check.call(Engine.time_scale == 1.0 and ticks <= 6, "the pulse ends within 6 physics ticks of real time (%d ticks, scale %.3f)" % [ticks, Engine.time_scale])

	# A pulse while a lower request is active keeps the lower one, and gives it back untouched.
	fx.call(&"request", &"low", 0.1)
	fx.call(&"pulse", &"hit", 0.5, 0.05)
	check.call(Engine.time_scale == 0.1, "a pulse above a lower request keeps the lower scale (got %.3f)" % Engine.time_scale)
	await tree.create_timer(0.12, true, false, true).timeout
	check.call(Engine.time_scale == 0.1 and not (fx.call(&"active_sources") as Array).has(&"hit"), "after the pulse the lower request is still in force (got %.3f)" % Engine.time_scale)
	fx.call(&"clear_all")

	# clear_all() during a pulse restores 1.0 and the later callback changes nothing, not even a newer request of the same source.
	fx.call(&"pulse", &"hit", 0.05, 0.05)
	fx.call(&"clear_all")
	check.call(Engine.time_scale == 1.0, "clear_all during a pulse restores 1.0 (got %.3f)" % Engine.time_scale)
	fx.call(&"request", &"hit", 0.3)
	await tree.create_timer(0.1, true, false, true).timeout
	check.call(Engine.time_scale == 0.3, "the late timer of a cleared pulse does not release a newer request (got %.3f)" % Engine.time_scale)
	fx.call(&"clear_all")

	# Bad input is ignored.
	fx.call(&"pulse", &"bad", 0.05, 0.0)
	fx.call(&"pulse", &"bad", NAN, 0.05)
	fx.call(&"pulse", &"bad", 0.05, INF)
	check.call(Engine.time_scale == 1.0 and (fx.call(&"active_sources") as Array).is_empty(), "a zero, NAN or INF pulse changes nothing (got %.3f)" % Engine.time_scale)
