extends RefCounted
## Worker of tools/measure_movement.gd (MOVE-10, FEEL-06, D-21, D-22): drives the real Player headless with scripted
## per-tick inputs, measures every movement verb and the input latency (LatencyProbe) at 60 and 120 TPS, and writes
## docs/MOVEMENT-METRICS.md. It lives in its own file because a SceneTree script given to -s is compiled before the
## autoloads exist: any type that touches EventBus (PlayerController, LatencyProbe, Fixtures) would fail to compile there.
## The measure_movement.gd loader loads this script at run time, like run_smoke.gd loads the tests.
## Run: bash attimo/tests/run.sh --tool res://tools/measure_movement.gd
## run(tree) returns the failure messages: empty means "MEASURE: PASSED" (latency bounds, ordering invariants and the
## 22 m/s long-jump envelope hold, success criterion 5, Pitfall 12). The doc is written either way, so a failing run still
## shows its numbers.
## Measurements run at 60 TPS on flat ground with a level take-off and landing; a distance is take-off to landing of
## the body origin (A32). Times have tick resolution (1/60 s). The gym markings (02-14) are the manual cross-check.

const Fixtures := preload("res://tests/fixtures.gd")

const TPS: int = 60
## Fixed output path relative to the project root (attimo/); same idiom as test_conventions. Nothing selects it at runtime.
const DOC_RELATIVE_PATH: String = "../docs/MOVEMENT-METRICS.md"
const REGENERATE_COMMAND: String = "bash attimo/tests/run.sh --tool res://tools/measure_movement.gd"
const CONFIG_PATH: String = "res://resources/player/movement_default.tres"
const BEAM_SCENE: String = "res://scenes/proto/primitive_beam.tscn"
const SLOPE_SCENE: String = "res://scenes/proto/primitive_slope.tscn"

## A long floor; the player starts far down +Z so a run toward -Z has room for the longest scenario.
const FLOOR_SIZE: Vector3 = Vector3(60.0, 1.0, 300.0)
const START: Vector3 = Vector3(0.0, 0.0, 140.0)
const LIMIT_TICKS: int = 360

const TARGET_MEDIAN_MS: float = 66.0
const HARD_LIMIT_MS: float = 100.0
const LATENCY_PRESSES: int = 10
const LATENCY_TICK_RATES: Array[int] = [60, 120]
## Press phase offsets in seconds, so the presses land at different points of the physics tick.
const PHASE_OFFSETS: Array[float] = [0.0, 0.0037, 0.0071, 0.0113, 0.0149, 0.0023, 0.0059, 0.0097, 0.0131, 0.0167]
const STEP_HEIGHTS: Array[float] = [0.10, 0.15, 0.20, 0.25]
## The speed the camera and tunnelling tests cover; no long jump may exceed it (T-261106-01).
const LONG_JUMP_SPEED_LIMIT: float = 22.0
## Slack above that limit and around a stage row when checking take-off speeds (the tick-sampled speed is not exact).
const CAP_SLACK: float = 0.1

const TAKEOFF_KINDS: Array[StringName] = [&"jumped", &"long_jumped"]
const RELEASE_ACTIONS: Array[StringName] = [&"move_forward", &"move_left", &"jump", &"dash"]

var _tree: SceneTree
var _bus: Node
var _log: Array[Dictionary] = []
var _floor: StaticBody3D
var _extras: Array[Node] = []
var _failures: PackedStringArray = PackedStringArray()


## Runs every measurement, writes the doc and returns the failure messages (empty when everything holds).
func run(tree: SceneTree) -> PackedStringArray:
	_tree = tree
	await _main()
	return _failures


func _main() -> void:
	Engine.physics_ticks_per_second = TPS
	_bus = _tree.root.get_node("EventBus")
	var config: MovementConfig = load(CONFIG_PATH) as MovementConfig
	if config == null:
		_failures.append("cannot load %s" % CONFIG_PATH)
		return

	print("MEASURE: ground")
	var ground: Dictionary = await _measure_ground()
	print("MEASURE: jumps")
	var jumps: Dictionary = await _measure_jumps()
	print("MEASURE: dashes")
	var dashes: Dictionary = await _measure_dashes()
	print("MEASURE: long jumps")
	var longs: Dictionary = await _measure_long_jumps()
	print("MEASURE: floor limits")
	var floors: Dictionary = await _measure_floor_limits()
	var latency: Dictionary = {}
	for tps: int in LATENCY_TICK_RATES:
		for accumulate: bool in [true, false]:
			print("MEASURE: latency %d TPS accumulated input %s" % [tps, accumulate])
			latency["%d_%s" % [tps, accumulate]] = await _measure_latency(tps, accumulate)
	Engine.physics_ticks_per_second = TPS
	Input.use_accumulated_input = true

	_check_invariants(config, jumps, longs, latency)
	_write_doc(config, ground, jumps, dashes, longs, floors, latency)


# --- recorders and helpers ------------------------------------------------------------------------------

func _on_jumped(position: Vector3) -> void:
	_record(&"jumped", position, 0)


func _on_long_jumped(position: Vector3, stage: int) -> void:
	_record(&"long_jumped", position, stage)


func _on_landed(position: Vector3, _impact_speed: float) -> void:
	_record(&"landed", position, 0)


func _on_dash_started(position: Vector3, _direction: Vector3, in_air: bool) -> void:
	_record(&"dash_started", position, 1 if in_air else 0)


func _record(kind: StringName, position: Vector3, stage: int) -> void:
	_log.append({"kind": kind, "pos": position, "stage": stage, "frame": Engine.get_physics_frames()})


func _count(kind: StringName) -> int:
	var n: int = 0
	for entry: Dictionary in _log:
		if entry["kind"] == kind:
			n += 1
	return n


func _last(kind: StringName) -> Dictionary:
	for i: int in range(_log.size() - 1, -1, -1):
		if _log[i]["kind"] == kind:
			return _log[i]
	return {}


func _takeoff_count() -> int:
	var n: int = 0
	for entry: Dictionary in _log:
		if TAKEOFF_KINDS.has(entry["kind"]):
			n += 1
	return n


func _last_takeoff() -> Dictionary:
	for i: int in range(_log.size() - 1, -1, -1):
		if TAKEOFF_KINDS.has(_log[i]["kind"]):
			return _log[i]
	return {}


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


## Fresh log, a long floor and a player at `position`.
func _begin(position: Vector3 = START) -> PlayerController:
	_log = []
	_extras = []
	_bus.connect(&"jumped", _on_jumped)
	_bus.connect(&"long_jumped", _on_long_jumped)
	_bus.connect(&"landed", _on_landed)
	_bus.connect(&"dash_started", _on_dash_started)
	_floor = Fixtures.spawn_floor(_tree.root, FLOOR_SIZE)
	var player: PlayerController = Fixtures.spawn_player(_tree.root, position)
	await Fixtures.wait_physics(_tree, 8)
	return player


## Releases every action, disconnects the recorders and frees the scenario nodes.
func _end(player: PlayerController) -> void:
	_release_all()
	_bus.disconnect(&"jumped", _on_jumped)
	_bus.disconnect(&"long_jumped", _on_long_jumped)
	_bus.disconnect(&"landed", _on_landed)
	_bus.disconnect(&"dash_started", _on_dash_started)
	for extra: Node in _extras:
		if is_instance_valid(extra):
			extra.queue_free()
	player.queue_free()
	_floor.queue_free()
	await player.tree_exited


func _release_all() -> void:
	for action: StringName in RELEASE_ACTIONS:
		Fixtures.send_action_event(action, false)
		Input.action_release(action)


## Holds move_forward and waits until the player runs at the run speed.
func _run_up(player: PlayerController) -> void:
	Input.action_press(&"move_forward")
	var target: float = player.config.run_speed
	await Fixtures.wait_until(_tree, func() -> bool: return absf(player.horizontal_speed() - target) < 0.05, 240)


func _state_is(player: PlayerController, state: StringName) -> bool:
	return player.state_machine.current.name == state


## Follows an airtime that already started (press sent) until the next landed fact. With `hold` the jump button
## stays down until the apex and is released there. `takeoff` is the take-off fact record.
func _fly(player: PlayerController, takeoff: Dictionary, hold: bool) -> Dictionary:
	var takeoff_pos: Vector3 = takeoff["pos"]
	var takeoff_frame: int = takeoff["frame"]
	var landed_before: int = _count(&"landed")
	var max_y: float = player.global_position.y
	var apex_frame: int = Engine.get_physics_frames()
	var max_speed: float = player.horizontal_speed()
	var released: bool = false
	var frames: int = 0
	while _count(&"landed") == landed_before and frames < LIMIT_TICKS:
		await _tree.physics_frame
		frames += 1
		if player.global_position.y > max_y:
			max_y = player.global_position.y
			apex_frame = Engine.get_physics_frames()
		max_speed = maxf(max_speed, player.horizontal_speed())
		if hold and not released and frames > 2 and player.vertical_speed <= 0.0:
			Fixtures.send_action_event(&"jump", false)
			released = true
	if not released:
		Fixtures.send_action_event(&"jump", false)
	var landed: bool = _count(&"landed") > landed_before
	var land_pos: Vector3 = player.global_position
	var land_frame: int = Engine.get_physics_frames()
	if landed:
		var land: Dictionary = _last(&"landed")
		land_pos = land["pos"]
		land_frame = land["frame"]
	return {
		"started": true,
		"landed": landed,
		"apex": max_y - takeoff_pos.y,
		"distance": _flat(takeoff_pos, land_pos),
		"air": float(land_frame - takeoff_frame) / float(TPS),
		# The sample after tick t is taken at frame t + 1.
		"rise": float(apex_frame - 1 - takeoff_frame) / float(TPS),
		"max_speed": max_speed,
		"takeoff": takeoff,
	}


func _empty_flight() -> Dictionary:
	return {"started": false, "landed": false, "apex": 0.0, "distance": 0.0, "air": 0.0, "rise": 0.0, "max_speed": 0.0, "entry_speed": 0.0, "first_speed": 0.0, "stage": 0}


## One ground jump from the current state: press (held, or a tap that releases in the same tick), take-off, flight.
func _jump_flight(player: PlayerController, tap: bool) -> Dictionary:
	var entry_speed: float = player.horizontal_speed()
	var before: int = _takeoff_count()
	Fixtures.send_action_event(&"jump", true)
	if tap:
		Fixtures.send_action_event(&"jump", false)
	var waited: int = await Fixtures.wait_until(_tree, func() -> bool: return _takeoff_count() > before, 12)
	if waited < 0:
		Fixtures.send_action_event(&"jump", false)
		_fail("a jump press did not take off")
		return _empty_flight()
	var flight: Dictionary = await _fly(player, _last_takeoff(), not tap)
	flight["entry_speed"] = entry_speed
	return flight


# --- ground ---------------------------------------------------------------------------------------------

func _measure_ground() -> Dictionary:
	var player: PlayerController = await _begin()
	var config: MovementConfig = player.config
	var result: Dictionary = {"run_top": 0.0, "run_time": -1.0}
	Input.action_press(&"move_forward")
	for tick: int in 120:
		await _tree.physics_frame
		var run_top: float = result["run_top"]
		result["run_top"] = maxf(run_top, player.horizontal_speed())
		var run_time: float = result["run_time"]
		if run_time < 0.0 and absf(player.horizontal_speed() - config.run_speed) < 0.05:
			result["run_time"] = float(tick + 1) / float(TPS)
	await _end(player)
	return result


# --- jumps ----------------------------------------------------------------------------------------------

func _measure_jumps() -> Dictionary:
	var out: Dictionary = {}

	var player: PlayerController = await _begin()
	out["tap_standing"] = await _jump_flight(player, true)
	await _end(player)

	player = await _begin()
	out["full_standing"] = await _jump_flight(player, false)
	await _end(player)

	player = await _begin()
	await _run_up(player)
	out["tap_run"] = await _jump_flight(player, true)
	await _end(player)

	player = await _begin()
	await _run_up(player)
	out["full_run"] = await _jump_flight(player, false)
	await _end(player)

	# Jump 1, 2 and 3 (salto) held, each pressed on the landing tick of the one before inside the landing window.
	player = await _begin()
	await _run_up(player)
	out["jump_1"] = await _jump_flight(player, false)
	out["jump_2"] = await _jump_flight(player, false)
	out["jump_3"] = await _jump_flight(player, false)
	await _end(player)
	return out


# --- dashes ---------------------------------------------------------------------------------------------

func _measure_dashes() -> Dictionary:
	var out: Dictionary = {}

	var player: PlayerController = await _begin()
	await _run_up(player)
	out["ground"] = await _dash(player)
	await _end(player)

	player = await _begin()
	await _run_up(player)
	Fixtures.send_action_event(&"jump", true)
	var before: int = _takeoff_count()
	await Fixtures.wait_until(_tree, func() -> bool: return _takeoff_count() > before, 12)
	# Wait until the press is older than the jump buffer: the dash then starts from a plain airtime.
	await Fixtures.wait_physics(_tree, ceili(player.config.jump_buffer_time * float(TPS)) + 3)
	var air: Dictionary = await _dash(player)
	Fixtures.send_action_event(&"jump", false)
	await Fixtures.wait_until(_tree, func() -> bool: return player.is_grounded(), LIMIT_TICKS)
	out["air"] = air
	await _end(player)
	return out


## One dash (press and release in the same tick) from the current state, followed to the end of the Dash state.
func _dash(player: PlayerController) -> Dictionary:
	var result: Dictionary = {"started": false, "distance": 0.0, "duration": 0.0, "exit_speed": 0.0, "altitude": 0.0, "entry_speed": player.horizontal_speed()}
	var before: int = _count(&"dash_started")
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"dash", false)
	var started: int = await Fixtures.wait_until(_tree, func() -> bool: return _count(&"dash_started") > before and _state_is(player, &"Dash"), 12)
	if started < 0:
		_fail("a dash press did not start a dash")
		return result
	var start: Dictionary = _last(&"dash_started")
	var start_pos: Vector3 = start["pos"]
	var ticks: int = 0
	while _state_is(player, &"Dash") and ticks < 60:
		await _tree.physics_frame
		ticks += 1
	result["started"] = true
	result["distance"] = _flat(start_pos, player.global_position)
	result["duration"] = float(ticks) / float(TPS)
	result["exit_speed"] = player.horizontal_speed()
	result["altitude"] = player.global_position.y - start_pos.y
	return result


# --- chain and long jump ---------------------------------------------------------------------------------

func _measure_long_jumps() -> Dictionary:
	var out: Dictionary = {}
	# One hop streak: dash + jump on every landing tick gives stages 1, 2, 3 and then 3 again.
	var player: PlayerController = await _begin()
	await _run_up(player)
	for hop: int in 4:
		out["hop_%d" % (hop + 1)] = await _dash_jump(player)
	await _end(player)
	# The last tick of the grace after a dash, from a fresh run-up (stage 1).
	player = await _begin()
	await _run_up(player)
	out["grace_1"] = await _grace_jump(player)
	await _end(player)
	return out


## Dash and jump pressed on the same tick (the jump stays held), then follows the long jump to its landing.
func _dash_jump(player: PlayerController) -> Dictionary:
	var before: int = _count(&"long_jumped")
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"jump", true)
	Fixtures.send_action_event(&"dash", false)
	var waited: int = await Fixtures.wait_until(_tree, func() -> bool: return _count(&"long_jumped") > before, 12)
	if waited < 0:
		Fixtures.send_action_event(&"jump", false)
		_fail("a dash plus jump on one tick did not give long_jumped")
		return _empty_flight()
	return await _finish_long_jump(player)


## A ground dash, then the jump in the last tick of the grace window.
func _grace_jump(player: PlayerController) -> Dictionary:
	var dt: float = 1.0 / float(TPS)
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"dash", false)
	await Fixtures.wait_until(_tree, func() -> bool: return _state_is(player, &"Dash"), 6)
	await Fixtures.wait_until(_tree, func() -> bool: return not _state_is(player, &"Dash"), 40)
	var in_window: int = await Fixtures.wait_until(_tree, func() -> bool: return player.dash_jump_grace_timer > 1.5 * dt and player.dash_jump_grace_timer <= 2.5 * dt, 20)
	if in_window < 0:
		_fail("the dash-jump grace window was not reached")
		return _empty_flight()
	var before: int = _count(&"long_jumped")
	Fixtures.send_action_event(&"jump", true)
	var waited: int = await Fixtures.wait_until(_tree, func() -> bool: return _count(&"long_jumped") > before, 6)
	if waited < 0:
		Fixtures.send_action_event(&"jump", false)
		_fail("a jump in the last grace tick did not give long_jumped")
		return _empty_flight()
	return await _finish_long_jump(player)


func _finish_long_jump(player: PlayerController) -> Dictionary:
	var event: Dictionary = _last(&"long_jumped")
	var first_speed: float = player.horizontal_speed()
	var flight: Dictionary = await _fly(player, event, true)
	flight["stage"] = event["stage"]
	flight["first_speed"] = first_speed
	flight["entry_speed"] = first_speed
	return flight


# --- floor limits ----------------------------------------------------------------------------------------

func _measure_floor_limits() -> Dictionary:
	var out: Dictionary = {}
	for height: float in STEP_HEIGHTS:
		out["step_%.2f" % height] = await _measure_step(height)
	out["slope"] = await _measure_slope()
	var player: PlayerController = await _begin()
	var capsule: CapsuleShape3D = null
	for node: Node in player.find_children("*", "CollisionShape3D", true, false):
		var shape: CollisionShape3D = node as CollisionShape3D
		if shape != null and shape.shape is CapsuleShape3D:
			capsule = shape.shape as CapsuleShape3D
			break
	if capsule != null:
		out["radius"] = capsule.radius
		out["height"] = capsule.height
	else:
		out["radius"] = 0.0
		out["height"] = 0.0
		_fail("the player has no CapsuleShape3D")
	await _end(player)
	return out


## A single Primitive_Beam riser of `height`, run at from 6 m at the default run speed, no jump pressed.
func _measure_step(height: float) -> Dictionary:
	var player: PlayerController = await _begin(Vector3(6.0, 0.0, 0.0))
	var beam: StaticBody3D = (load(BEAM_SCENE) as PackedScene).instantiate() as StaticBody3D
	beam.rotation.y = PI / 2.0
	beam.position = Vector3(0.0, height - 1.0, 0.0)
	_tree.root.add_child(beam)
	_extras.append(beam)
	await Fixtures.wait_physics(_tree, 3)
	Input.action_press(&"move_left")
	var climbed: bool = false
	for tick: int in 120:
		await _tree.physics_frame
		if player.is_grounded() and absf(player.global_position.x) < 0.4 and player.global_position.y >= height - 0.05:
			climbed = true
			break
	var jumped: int = _count(&"jumped")
	var stopped_x: float = player.global_position.x
	await _end(player)
	return {"climbed": climbed, "jumped": jumped, "x": stopped_x}


## The 45 degree Primitive_Slope (4 m high, rising toward -X) up to a plateau, at the default run speed.
func _measure_slope() -> Dictionary:
	var player: PlayerController = await _begin(Vector3(8.0, 0.0, 0.0))
	var slope: StaticBody3D = (load(SLOPE_SCENE) as PackedScene).instantiate() as StaticBody3D
	_tree.root.add_child(slope)
	_extras.append(slope)
	_extras.append(Fixtures.spawn_box(_tree.root, Vector3(8.0, 4.0, 4.0), Vector3(-6.0, 2.0, 0.0)))
	await Fixtures.wait_physics(_tree, 3)
	Input.action_press(&"move_left")
	var reached_tick: int = -1
	for tick: int in 6 * TPS:
		await _tree.physics_frame
		if player.global_position.x < -3.0 and player.global_position.y > 3.9:
			reached_tick = tick + 1
			break
	await _end(player)
	return {"reached": reached_tick >= 0, "seconds": float(reached_tick) / float(TPS)}


# --- latency ---------------------------------------------------------------------------------------------

func _measure_latency(tps: int, accumulate: bool) -> Dictionary:
	Engine.physics_ticks_per_second = tps
	Input.use_accumulated_input = accumulate
	# Starts far down -Z: a dash without input goes toward +Z (the facing) and ten dashes must stay on the floor.
	var player: PlayerController = await _begin(Vector3(0.0, 0.0, -100.0))
	var probe: LatencyProbe = LatencyProbe.new()
	_tree.root.add_child(probe)
	await Fixtures.wait_physics(_tree, tps / 4)

	# Jump: press, wait for the sample, release, let the player land before the next press.
	for i: int in LATENCY_PRESSES:
		var before: int = probe.jump_samples_ms.size()
		await _tree.create_timer(PHASE_OFFSETS[i]).timeout
		Fixtures.send_action_event(&"jump", true)
		await Fixtures.wait_until(_tree, func() -> bool: return probe.jump_samples_ms.size() > before, tps / 2)
		Fixtures.send_action_event(&"jump", false)
		await Fixtures.wait_until(_tree, func() -> bool: return player.is_grounded() and _state_is(player, &"Idle"), tps * 4)

	# Dash: press, wait for the sample, release, wait for the ground state and the cooldown.
	var cooldown_ticks: int = ceili((player.config.dash_cooldown + 0.1) * float(tps))
	for i: int in LATENCY_PRESSES:
		var before: int = probe.dash_samples_ms.size()
		await _tree.create_timer(PHASE_OFFSETS[i]).timeout
		Fixtures.send_action_event(&"dash", true)
		await Fixtures.wait_until(_tree, func() -> bool: return probe.dash_samples_ms.size() > before, tps / 2)
		Fixtures.send_action_event(&"dash", false)
		await Fixtures.wait_until(_tree, func() -> bool: return player.is_grounded() and (_state_is(player, &"Idle") or _state_is(player, &"Run")), tps * 4)
		await Fixtures.wait_physics(_tree, cooldown_ticks)

	var result: Dictionary = {"jump": probe.summary(&"jump"), "dash": probe.summary(&"dash")}
	probe.queue_free()
	await _end(player)
	Engine.physics_ticks_per_second = TPS
	Input.use_accumulated_input = true
	return result


# --- invariants -----------------------------------------------------------------------------------------

func _check_invariants(config: MovementConfig, jumps: Dictionary, longs: Dictionary, latency: Dictionary) -> void:
	var tap: Dictionary = jumps["tap_standing"]
	var full: Dictionary = jumps["full_standing"]
	var tap_apex: float = tap["apex"]
	var full_apex: float = full["apex"]
	if not (tap_apex < full_apex):
		_fail("tap jump apex %.3f m is not below the held jump apex %.3f m" % [tap_apex, full_apex])

	var apex_1: float = jumps["jump_1"]["apex"]
	var apex_2: float = jumps["jump_2"]["apex"]
	var apex_3: float = jumps["jump_3"]["apex"]
	if not (apex_1 < apex_2 and apex_2 < apex_3):
		_fail("chain jump apexes are not ordered Jump 1 < Jump 2 < Jump 3 (%.2f, %.2f, %.2f m)" % [apex_1, apex_2, apex_3])

	var distances: Array[float] = []
	var apexes: Array[float] = []
	for hop: int in 4:
		var entry: Dictionary = longs["hop_%d" % (hop + 1)]
		var stage: int = mini(hop + 1, 3)
		if not bool(entry["started"]):
			continue
		var first_speed: float = entry["first_speed"]
		var max_speed: float = entry["max_speed"]
		if int(entry["stage"]) != stage:
			_fail("long jump hop %d has stage %d, expected %d" % [hop + 1, int(entry["stage"]), stage])
		if absf(first_speed - config.long_jump_speed(stage)) > CAP_SLACK:
			_fail("long jump stage %d take-off speed %.2f m/s is not the row long_jump_speed_%d %.1f" % [stage, first_speed, stage, config.long_jump_speed(stage)])
		if first_speed > LONG_JUMP_SPEED_LIMIT + CAP_SLACK or max_speed > LONG_JUMP_SPEED_LIMIT + CAP_SLACK:
			_fail("long jump hop %d speed %.2f m/s exceeds the %.0f m/s envelope" % [hop + 1, maxf(first_speed, max_speed), LONG_JUMP_SPEED_LIMIT])
		if hop < 3:
			distances.append(float(entry["distance"]))
			apexes.append(float(entry["apex"]))
	var grace: Dictionary = longs["grace_1"]
	if bool(grace["started"]) and (float(grace["first_speed"]) > LONG_JUMP_SPEED_LIMIT + CAP_SLACK or float(grace["max_speed"]) > LONG_JUMP_SPEED_LIMIT + CAP_SLACK):
		_fail("the last-grace-tick long jump exceeds the %.0f m/s envelope" % LONG_JUMP_SPEED_LIMIT)
	if distances.size() == 3 and not (distances[0] < distances[1] and distances[1] < distances[2]):
		_fail("long jump distances are not ordered stage 1 < 2 < 3 (%.2f, %.2f, %.2f m)" % [distances[0], distances[1], distances[2]])
	if apexes.size() == 3 and not (apexes[0] < apexes[1] and apexes[1] < apexes[2]):
		_fail("long jump apexes are not ordered stage 1 < 2 < 3 (%.2f, %.2f, %.2f m)" % [apexes[0], apexes[1], apexes[2]])

	for tps: int in LATENCY_TICK_RATES:
		for accumulate: bool in [true, false]:
			var run: Dictionary = latency["%d_%s" % [tps, accumulate]]
			for kind: String in ["jump", "dash"]:
				var summary: Dictionary = run[kind]
				var count: int = summary["count"]
				var median: float = summary["median_ms"]
				var maximum: float = summary["max_ms"]
				var label: String = "latency %s %d TPS (accumulated input %s)" % [kind, tps, accumulate]
				if count < LATENCY_PRESSES:
					_fail("%s: only %d of %d samples" % [label, count, LATENCY_PRESSES])
				if median > TARGET_MEDIAN_MS:
					_fail("%s: median %.2f ms exceeds the %.0f ms target" % [label, median, TARGET_MEDIAN_MS])
				if maximum > HARD_LIMIT_MS:
					_fail("%s: a sample of %.2f ms exceeds the %.0f ms hard limit" % [label, maximum, HARD_LIMIT_MS])


# --- document -------------------------------------------------------------------------------------------

func _row(cells: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for cell: Variant in cells:
		parts.append(str(cell))
	return "| %s |" % " | ".join(parts)


func _jump_row(label: String, flight: Dictionary, note: String = "") -> String:
	return _row([label, "%.2f" % float(flight["apex"]), "%.2f" % float(flight["distance"]), "%.2f" % float(flight["air"]), "%.2f" % float(flight["rise"]), "%.2f" % float(flight["entry_speed"]), note])


func _long_row(label: String, flight: Dictionary, note: String = "") -> String:
	return _row([label, int(flight["stage"]), "%.2f" % float(flight["apex"]), "%.2f" % float(flight["distance"]), "%.2f" % float(flight["first_speed"]), "%.2f" % float(flight["air"]), note])


## "%.2f" without a negative zero ("-0.00") for values that are zero within the display precision.
func _signed_zero_safe(value: float) -> String:
	return "0.00" if absf(value) < 0.005 else "%.2f" % value


func _ticks(seconds: float) -> int:
	return roundi(seconds * float(TPS))


func _verdict(median: float, maximum: float) -> String:
	if maximum > HARD_LIMIT_MS:
		return "OVER the 100 ms hard limit"
	if median > TARGET_MEDIAN_MS:
		return "OVER the 66 ms target"
	return "Target met (median <= 66 ms, max <= 100 ms)"


func _grid_row(label: String, flight: Dictionary) -> String:
	var distance: float = flight["distance"]
	var apex: float = flight["apex"]
	return _row([label, "%.2f" % distance, floori(distance), "%.2f" % (distance / 4.0), "%.1f" % (floorf((apex + 0.01) * 10.0) / 10.0)])


func _write_doc(config: MovementConfig, ground: Dictionary, jumps: Dictionary, dashes: Dictionary, longs: Dictionary, floors: Dictionary, latency: Dictionary) -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("# Movement Metrics")
	lines.append("")
	lines.append("Generated by tools/measure_movement.gd on %s with Godot %s. Regenerate with `%s`." % [Time.get_date_string_from_system(), str(Engine.get_version_info()["string"]), REGENERATE_COMMAND])
	lines.append("")
	lines.append("Every number comes from the real Player driven headless with scripted per-tick inputs at %d TPS on flat ground. A distance is take-off to landing of the body origin (the feet), a height is the apex above the take-off point, times have tick resolution (1/%d s). The gym markings (02-14) are the manual cross-check. If movement_default.tres is retuned, regenerate this file: test_movement_metrics fails on a stale config snapshot." % [TPS, TPS])
	lines.append("")

	lines.append("## Ground")
	lines.append("")
	lines.append("| Verb | Speed (m/s) | Time to speed (s) | Note |")
	lines.append("|---|---|---|---|")
	lines.append(_row(["Run speed", "%.2f" % float(ground["run_top"]), "%.2f" % float(ground["run_time"]), "move_forward held from standing, run_speed %.1f" % config.run_speed]))
	lines.append("")

	lines.append("## Jump")
	lines.append("")
	lines.append("| Verb | Height (m) | Distance (m) | Airtime (s) | Rise to apex (s) | Entry speed (m/s) | Note |")
	lines.append("|---|---|---|---|---|---|---|")
	lines.append(_jump_row("Tap jump", jumps["tap_standing"], "standing, press and release on one tick"))
	lines.append(_jump_row("Tap jump (run)", jumps["tap_run"], "at run speed"))
	lines.append(_jump_row("Full jump (standing)", jumps["full_standing"], "held to the apex"))
	lines.append(_jump_row("Full jump (run)", jumps["full_run"], "held to the apex, at run speed"))
	lines.append(_jump_row("Jump 2 (chain)", jumps["jump_2"], "pressed on the landing tick of Jump 1 (Jump 1 for comparison: %.2f m, %.2f m)" % [float(jumps["jump_1"]["apex"]), float(jumps["jump_1"]["distance"])]))
	lines.append(_jump_row("Jump 3 (salto)", jumps["jump_3"], "pressed on the landing tick of Jump 2, the highest ground jump; a fourth jump inside the window is Jump 1 again"))
	lines.append("")

	lines.append("## Air options and dash")
	lines.append("")
	lines.append("| Verb | Distance (m) | Duration (s) | Exit speed (m/s) | Altitude change (m) | Entry speed (m/s) | Note |")
	lines.append("|---|---|---|---|---|---|---|")
	var ground_dash: Dictionary = dashes["ground"]
	var air_dash: Dictionary = dashes["air"]
	lines.append(_row(["Ground dash", "%.2f" % float(ground_dash["distance"]), "%.2f" % float(ground_dash["duration"]), "%.2f" % float(ground_dash["exit_speed"]), _signed_zero_safe(float(ground_dash["altitude"])), "%.2f" % float(ground_dash["entry_speed"]), "dash_speed %.1f for dash_time %.2f s while running" % [config.dash_speed, config.dash_time]]))
	lines.append(_row(["Air dash", "%.2f" % float(air_dash["distance"]), "%.2f" % float(air_dash["duration"]), "%.2f" % float(air_dash["exit_speed"]), _signed_zero_safe(float(air_dash["altitude"])), "%.2f" % float(air_dash["entry_speed"]), "one per airtime, air_dash_gravity_scale %.2f" % config.air_dash_gravity_scale]))
	lines.append("")

	lines.append("## Long jump (dash hop)")
	lines.append("")
	lines.append("The long jump is the dash hop: a jump during a ground dash or within dash_jump_grace after it. Its speed is set per stage (long_jump_speed_1/2/3), never carried from the dash. Stage 1 is the first hop; each clean repeat (a ground dash started inside the landing window after touchdown, then a jump) climbs to stage 2 and 3 and then stays at 3; a miss (window runs out, standing still, a normal jump in between) restarts at stage 1. The speeds are capped by an export maximum of %.0f m/s, the envelope the camera and tunnelling tests cover. Take-off speed is the horizontal speed on the first tick of the long jump. One hop streak is measured: dash + jump on the landing tick of each hop." % LONG_JUMP_SPEED_LIMIT)
	lines.append("")
	lines.append("| Verb | Stage | Height (m) | Distance (m) | Take-off speed (m/s) | Airtime (s) | Note |")
	lines.append("|---|---|---|---|---|---|---|")
	lines.append(_long_row("Long jump stage 1", longs["hop_1"], "dash + jump on one tick from a run, long_jump_speed_1 %.1f m/s" % config.long_jump_speed_1))
	lines.append(_long_row("Long jump stage 2", longs["hop_2"], "dash + jump on the landing tick of stage 1, long_jump_speed_2 %.1f m/s" % config.long_jump_speed_2))
	lines.append(_long_row("Long jump stage 3", longs["hop_3"], "dash + jump on the landing tick of stage 2, long_jump_speed_3 %.1f m/s" % config.long_jump_speed_3))
	lines.append(_long_row("Long jump stage 3 (repeat)", longs["hop_4"], "a further clean hop stays at stage 3"))
	lines.append(_long_row("Long jump (last grace tick)", longs["grace_1"], "jump in the last tick of dash_jump_grace, stage 1 row applies"))
	lines.append("")

	lines.append("## Timing windows")
	lines.append("")
	lines.append("| Window | Seconds | Ticks at 60 TPS |")
	lines.append("|---|---|---|")
	lines.append(_row(["Coyote time", "%.3f" % config.coyote_time, _ticks(config.coyote_time)]))
	lines.append(_row(["Jump buffer", "%.3f" % config.jump_buffer_time, _ticks(config.jump_buffer_time)]))
	lines.append(_row(["Landing window", "%.3f" % config.landing_window, _ticks(config.landing_window)]))
	lines.append(_row(["Dash cooldown", "%.3f" % config.dash_cooldown, _ticks(config.dash_cooldown)]))
	lines.append(_row(["Dash-jump grace", "%.3f" % config.dash_jump_grace, _ticks(config.dash_jump_grace)]))
	lines.append(_row(["Dash duration", "%.3f" % config.dash_time, _ticks(config.dash_time)]))
	lines.append("")

	lines.append("## Floor limits")
	lines.append("")
	var radius: float = floors["radius"]
	var theory: float = radius * (1.0 - cos(deg_to_rad(config.floor_max_angle_deg)))
	lines.append("Capsule radius %.2f m, height %.2f m. floor_max_angle %.0f degrees. The theoretical step a capsule of this radius climbs by sliding up its rounded bottom is r x (1 - cos(angle)) = %.2f m; taller ledges need a jump. A step is a Primitive_Beam riser run at from 6 m at run speed with no jump pressed." % [radius, float(floors["height"]), config.floor_max_angle_deg, theory])
	lines.append("")
	lines.append("| Probe | Result | Detail |")
	lines.append("|---|---|---|")
	for height: float in STEP_HEIGHTS:
		var step: Dictionary = floors["step_%.2f" % height]
		var climbed: bool = step["climbed"]
		var detail: String = "stood on the riser top without a jump" if climbed else "stopped at x %.2f, riser not climbed" % float(step["x"])
		lines.append(_row(["Step %.2f m" % height, "climbed" if climbed else "blocked", detail]))
	var slope: Dictionary = floors["slope"]
	var slope_ok: bool = slope["reached"]
	lines.append(_row(["Slope 45 degrees", "walkable" if slope_ok else "not climbed", ("plateau 4 m up reached in %.2f s at run speed" % float(slope["seconds"])) if slope_ok else "the plateau was not reached in 6 s"]))
	lines.append("")

	lines.append("## Latency")
	lines.append("")
	lines.append("Software latency from the input event (stamped in _input by LatencyProbe) to the gameplay fact on the EventBus: jump press to jumped, dash press to dash_started. %d presses per cell, spread over different points of the physics tick. Each cell shows the median and the maximum in ms, with Input.use_accumulated_input on (the default) and off (RESEARCH A9). Targets: median <= %.0f ms, every sample <= %.0f ms (FEEL-06)." % [LATENCY_PRESSES, TARGET_MEDIAN_MS, HARD_LIMIT_MS])
	lines.append("")
	lines.append("Display, compositor and USB latency are outside the software measurement (D-22). End-to-end hardware latency stays a flagged human item in the 02-14 sign-off.")
	lines.append("")
	lines.append("| Action | Accumulated input on: median (ms) | on: max (ms) | off: median (ms) | off: max (ms) | Verdict |")
	lines.append("|---|---|---|---|---|---|")
	for kind: String in ["jump", "dash"]:
		for tps: int in LATENCY_TICK_RATES:
			var on: Dictionary = (latency["%d_true" % tps] as Dictionary)[kind]
			var off: Dictionary = (latency["%d_false" % tps] as Dictionary)[kind]
			var worst_median: float = maxf(float(on["median_ms"]), float(off["median_ms"]))
			var worst_max: float = maxf(float(on["max_ms"]), float(off["max_ms"]))
			lines.append(_row(["Latency %s %d TPS" % [kind, tps], "%.2f" % float(on["median_ms"]), "%.2f" % float(on["max_ms"]), "%.2f" % float(off["median_ms"]), "%.2f" % float(off["max_ms"]), _verdict(worst_median, worst_max)]))
	lines.append("")

	lines.append("## Grid cross-check")
	lines.append("")
	lines.append("How the numbers map onto the 1 m grid and the 4 m kit pieces. The widest gap assumes the take-off at the edge and the landing with the origin on the far edge at the same height, rounded down to whole metres; leave a safety margin for real levels. The tallest ledge is the apex, rounded down to 0.1 m (with 0.01 m tolerance, so 1.999 reads 2.0).")
	lines.append("")
	lines.append("| Verb | Distance (m) | Widest gap (1 m grid) | 4 m modules | Tallest ledge (m) |")
	lines.append("|---|---|---|---|---|")
	lines.append(_grid_row("Run jump", jumps["full_run"]))
	lines.append(_grid_row("Jump 2 chain jump", jumps["jump_2"]))
	lines.append(_grid_row("Jump 3 salto", jumps["jump_3"]))
	lines.append(_grid_row("Long jump stage 1 gap", longs["hop_1"]))
	lines.append(_grid_row("Long jump stage 2 gap", longs["hop_2"]))
	lines.append(_grid_row("Long jump stage 3 gap", longs["hop_3"]))
	lines.append("")

	lines.append("## Config snapshot")
	lines.append("")
	lines.append("Every MovementConfig float of res://resources/player/movement_default.tres at generation time.")
	lines.append("")
	lines.append("| Field | Value |")
	lines.append("|---|---|")
	for info: Dictionary in config.get_property_list():
		if int(info["type"]) != TYPE_FLOAT or (int(info["usage"]) & PROPERTY_USAGE_EDITOR) == 0:
			continue
		var field: String = str(info["name"])
		lines.append("| `%s` | %.3f |" % [field, float(config.get(field))])
	lines.append("")

	var path: String = ProjectSettings.globalize_path("res://").path_join(DOC_RELATIVE_PATH).simplify_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string("\n".join(lines))
	file.close()
	print("MEASURE: wrote %s" % path)
