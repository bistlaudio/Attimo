extends RefCounted
## D-21 live metrics overlay: hidden at start, toggled by debug_metrics, per-airtime jump height and distance,
## dash record, F6 tick-rate cycle 60 -> 120 -> 10 -> 60, a LatencyProbe child. Each scenario spawns a fresh
## player so jump-chain state never leaks between scenarios. Tick rate is restored to 60.

const Fixtures := preload("res://tests/fixtures.gd")
const OVERLAY_SCENE: String = "res://scenes/debug/metrics_overlay.tscn"
const APEX_TOLERANCE: float = 0.1

var _floor: StaticBody3D
var _player: PlayerController
var _overlay: MetricsOverlay


func run(tree: SceneTree, check: Callable) -> void:
	await _scenario_toggle_and_probe(tree, check)
	await _scenario_standing_jump(tree, check)
	await _scenario_running_jump(tree, check)
	await _scenario_dash(tree, check)
	await _scenario_tick_rate(tree, check)
	Engine.physics_ticks_per_second = 60


func _begin(tree: SceneTree) -> void:
	_floor = Fixtures.spawn_floor(tree.root)
	_player = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	var scene: PackedScene = load(OVERLAY_SCENE) as PackedScene
	_overlay = scene.instantiate() as MetricsOverlay
	tree.root.add_child(_overlay)


func _end(tree: SceneTree) -> void:
	Input.action_release(&"move_forward")
	_overlay.queue_free()
	_player.queue_free()
	_floor.queue_free()
	await tree.process_frame


func _tap(action: StringName) -> void:
	Fixtures.send_action_event(action, true)
	Fixtures.send_action_event(action, false)


func _scenario_toggle_and_probe(tree: SceneTree, check: Callable) -> void:
	_begin(tree)
	await Fixtures.wait_physics(tree, 5)
	check.call(not _overlay.visible, "(1) the overlay starts hidden")
	_tap(&"debug_metrics")
	check.call(_overlay.visible, "(1) a debug_metrics press shows the overlay")
	_tap(&"debug_metrics")
	check.call(not _overlay.visible, "(1) a second debug_metrics press hides it")
	check.call(_overlay.latency_probe != null and _overlay.latency_probe is LatencyProbe, "(1) the overlay has a LatencyProbe child")
	await _end(tree)


func _scenario_standing_jump(tree: SceneTree, check: Callable) -> void:
	_begin(tree)
	await Fixtures.wait_physics(tree, 10)
	Fixtures.send_action_event(&"jump", true)
	await Fixtures.wait_physics(tree, 5)
	var landed: int = await Fixtures.wait_until(tree, func() -> bool: return _overlay.last_jump.has("height") and _player.is_grounded(), 240)
	Fixtures.send_action_event(&"jump", false)
	check.call(landed >= 0, "(2) a held standing jump closes an airtime record")
	var jump: Dictionary = _overlay.last_jump
	check.call(jump.get("kind", "") == "jump", "(2) the record kind is 'jump' (got '%s')" % jump.get("kind", ""))
	var expected: float = _player.config.jump_height
	check.call(absf(jump.get("height", -1.0) - expected) <= APEX_TOLERANCE, "(2) height %.3f m is within %.1f of jump_height %.2f" % [jump.get("height", -1.0), APEX_TOLERANCE, expected])
	check.call(jump.get("distance", 99.0) < 0.2, "(2) a standing jump travels less than 0.2 m (got %.3f)" % jump.get("distance", 99.0))
	check.call(jump.get("airtime", 0.0) > 0.2, "(2) airtime is recorded in seconds (got %.3f)" % jump.get("airtime", 0.0))
	await _end(tree)


func _scenario_running_jump(tree: SceneTree, check: Callable) -> void:
	_begin(tree)
	await Fixtures.wait_physics(tree, 10)
	Input.action_press(&"move_forward")
	Fixtures.send_action_event(&"jump", true)
	await Fixtures.wait_physics(tree, 5)
	var landed: int = await Fixtures.wait_until(tree, func() -> bool: return _overlay.last_jump.has("height") and _player.is_grounded(), 240)
	Fixtures.send_action_event(&"jump", false)
	check.call(landed >= 0, "(3) a running jump closes an airtime record")
	check.call(_overlay.last_jump.get("distance", 0.0) > 2.0, "(3) a jump while holding move_forward travels more than 2.0 m (got %.3f)" % _overlay.last_jump.get("distance", 0.0))
	await _end(tree)


func _scenario_dash(tree: SceneTree, check: Callable) -> void:
	_begin(tree)
	await Fixtures.wait_physics(tree, 10)
	Fixtures.send_action_event(&"dash", true)
	await Fixtures.wait_physics(tree, 3)
	Fixtures.send_action_event(&"dash", false)
	var closed: int = await Fixtures.wait_until(tree, func() -> bool: return _overlay.last_dash.has("distance"), 120)
	check.call(closed >= 0, "(4) a dash press on the floor closes a dash record")
	check.call(_overlay.last_dash.get("distance", -1.0) >= 0.0, "(4) the dash distance is at least 0 (got %.3f)" % _overlay.last_dash.get("distance", -1.0))
	check.call(_overlay.last_dash.get("in_air", true) == false, "(4) the dash started on the floor (in_air false)")
	await _end(tree)


func _scenario_tick_rate(tree: SceneTree, check: Callable) -> void:
	_begin(tree)
	Engine.physics_ticks_per_second = 60
	await Fixtures.wait_physics(tree, 3)
	var seen: Array[int] = []
	for i: int in 3:
		_tap(&"debug_tick_rate")
		seen.append(Engine.physics_ticks_per_second)
		await Fixtures.wait_physics(tree, 2)
	check.call(seen == [120, 10, 60], "(5) debug_tick_rate cycles 60 -> 120 -> 10 -> 60 (got %s)" % [seen])
	Engine.physics_ticks_per_second = 60
	await _end(tree)
