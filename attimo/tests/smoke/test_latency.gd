extends RefCounted
## FEEL-06 / D-22: software latency from a jump or dash input event to its gameplay fact, at 60 and 120 TPS.
## The LatencyProbe stamps the press in _input and the fact on the bus, so the number is the input-to-state path only
## (no display, compositor or USB latency, see MOVEMENT-METRICS.md). Target: median <= 66 ms, hard limit: every sample <= 100 ms.
## Both bounds are asserted; a failure is a real defect, never a threshold to relax.

const Fixtures := preload("res://tests/fixtures.gd")

const TICK_RATES: Array[int] = [60, 120]
const PRESSES: int = 5
const TARGET_MEDIAN_MS: float = 66.0
const HARD_LIMIT_MS: float = 100.0
const PATH_SLACK_MS: float = 5.0
## Press phase offsets in seconds, so the presses land at different points of the physics tick.
const PHASE_OFFSETS: Array[float] = [0.0, 0.0037, 0.0071, 0.0113, 0.0149]


func run(tree: SceneTree, check: Callable) -> void:
	for tps: int in TICK_RATES:
		Engine.physics_ticks_per_second = tps
		await _run_rate(tree, check, tps)
	Engine.physics_ticks_per_second = 60


func _run_rate(tree: SceneTree, check: Callable, tps: int) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	var probe: LatencyProbe = LatencyProbe.new()
	tree.root.add_child(probe)
	await Fixtures.wait_physics(tree, tps / 4)
	var path_bound_ms: float = 2.0 * 1000.0 / float(tps) + PATH_SLACK_MS

	# Jump: press, wait for the sample, release, let the player land before the next press.
	for i: int in PRESSES:
		var before: int = probe.jump_samples_ms.size()
		await tree.create_timer(PHASE_OFFSETS[i]).timeout
		Fixtures.send_action_event(&"jump", true)
		await Fixtures.wait_until(tree, func() -> bool: return probe.jump_samples_ms.size() > before, tps / 2)
		Fixtures.send_action_event(&"jump", false)
		await Fixtures.wait_until(tree, func() -> bool: return player.is_grounded() and player.state_machine.current.name == &"Idle", tps * 4)
	_assert_kind(check, probe, &"jump", tps, path_bound_ms)

	# A fact without a preceding press adds no sample.
	var jump_count: int = probe.jump_samples_ms.size()
	var bus: Node = tree.root.get_node("EventBus")
	bus.emit_signal(&"jumped", Vector3.ZERO)
	check.call(probe.jump_samples_ms.size() == jump_count, "%d TPS: a jumped fact without a press adds no sample" % tps)

	# Dash: press, wait for the sample, release, wait for the ground state and the cooldown.
	var cooldown_ticks: int = ceili((player.config.dash_cooldown + 0.1) * float(tps))
	for i: int in PRESSES:
		var before: int = probe.dash_samples_ms.size()
		await tree.create_timer(PHASE_OFFSETS[i]).timeout
		Fixtures.send_action_event(&"dash", true)
		await Fixtures.wait_until(tree, func() -> bool: return probe.dash_samples_ms.size() > before, tps / 2)
		Fixtures.send_action_event(&"dash", false)
		await Fixtures.wait_until(tree, func() -> bool: return player.is_grounded() and player.state_machine.current.name in [&"Idle", &"Run"], tps * 4)
		await Fixtures.wait_physics(tree, cooldown_ticks)
	_assert_kind(check, probe, &"dash", tps, path_bound_ms)

	probe.queue_free()
	player.queue_free()
	floor_body.queue_free()
	await tree.process_frame


func _assert_kind(check: Callable, probe: LatencyProbe, kind: StringName, tps: int, path_bound_ms: float) -> void:
	var samples: PackedFloat64Array = probe.jump_samples_ms if kind == &"jump" else probe.dash_samples_ms
	var summary: Dictionary = probe.summary(kind)
	var label: String = "%d TPS %s" % [tps, kind]
	check.call(summary.count == PRESSES, "%s: %d presses produce %d samples (got %d)" % [label, PRESSES, PRESSES, summary.count])
	var worst_path: float = 0.0
	for sample: float in samples:
		worst_path = maxf(worst_path, sample)
	check.call(worst_path <= path_bound_ms, "%s: every sample is within 2 ticks + %.0f ms = %.1f ms (worst %.2f ms)" % [label, PATH_SLACK_MS, path_bound_ms, worst_path])
	var median_ok: bool = summary.count > 0 and summary.median_ms <= TARGET_MEDIAN_MS
	var max_ok: bool = summary.count > 0 and summary.max_ms <= HARD_LIMIT_MS
	check.call(median_ok, "%s: median %.2f ms is within the %.1f ms target" % [label, summary.median_ms, TARGET_MEDIAN_MS])
	check.call(max_ok, "%s: max %.2f ms is within the %.1f ms hard limit" % [label, summary.max_ms, HARD_LIMIT_MS])
	if median_ok and max_ok and summary.count == PRESSES:
		print("LATENCY %s: count=%d median=%.2f ms max=%.2f ms TARGET MET (<= 66 ms median, <= 100 ms max)" % [label, summary.count, summary.median_ms, summary.max_ms])
