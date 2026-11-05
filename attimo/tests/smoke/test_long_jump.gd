extends RefCounted
## MOVE-07 / D-05 / D-06 / D-07: the ground-jump chain and the long jump. Jump 1 -> land -> Jump 2 (higher)
## inside the landing window, Dash -> Jump = a long jump that carries the dash speed (bounded) and grows with
## the chain stage. Every expectation derives from player.config. Scenarios that need other numbers duplicate
## the config first (the shared resource is never mutated). Presses go through the input pipeline
## (Fixtures.send_action_event), actions are released before nodes are freed and the tick rate stays at 60.

const Fixtures := preload("res://tests/fixtures.gd")
const TPS: int = 60
const LIMIT_TICKS: int = 360

var _bus: Node
var _stages: Array[int] = []
var _landed: Array[Vector3] = []
var _jumped: int = 0
var _doubles: int = 0
var _longs: Array[Dictionary] = []
var _floor: StaticBody3D


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	Engine.physics_ticks_per_second = TPS
	await _scenario_chain_held(tree, check)
	await _scenario_chain_tapped(tree, check)
	await _scenario_chain_buffered(tree, check)
	await _scenario_chain_timeout(tree, check)
	await _scenario_chain_standing(tree, check)
	await _scenario_chain_new_after_stage_two(tree, check)
	await _scenario_plain_long_jump(tree, check)
	await _scenario_grace(tree, check)
	await _scenario_stage_distances(tree, check)
	await _scenario_cap(tree, check)
	await _scenario_air_dash_is_double(tree, check)


# --- recorders and helpers ------------------------------------------------------------------------------

func _on_stage(stage: int) -> void:
	_stages.append(stage)


## True when the recorded chain stages equal `expected` exactly.
func _stages_are(expected: Array) -> bool:
	return Array(_stages) == expected


func _on_landed(position: Vector3, _impact: float) -> void:
	_landed.append(position)


func _on_jumped(_position: Vector3) -> void:
	_jumped += 1


func _on_double(_position: Vector3) -> void:
	_doubles += 1


func _on_long(position: Vector3, stage: int) -> void:
	_longs.append({"position": position, "stage": stage, "frame": Engine.get_physics_frames()})


## Fresh recorders, a long floor and a player at `position` (default far down +Z, so a run toward -Z has room).
func _begin(tree: SceneTree, position: Vector3 = Vector3(0.0, 0.0, 70.0)) -> PlayerController:
	_stages = []
	_landed = []
	_longs = []
	_jumped = 0
	_doubles = 0
	_bus.connect(&"chain_stage_changed", _on_stage)
	_bus.connect(&"landed", _on_landed)
	_bus.connect(&"jumped", _on_jumped)
	_bus.connect(&"double_jumped", _on_double)
	_bus.connect(&"long_jumped", _on_long)
	_floor = Fixtures.spawn_floor(tree.root, Vector3(60.0, 1.0, 160.0))
	var player: PlayerController = Fixtures.spawn_player(tree.root, position)
	await Fixtures.wait_physics(tree, 8)
	return player


## Releases every action, disconnects the recorders and frees the scenario nodes.
func _end(player: PlayerController) -> void:
	for action: StringName in [&"move_forward", &"jump", &"dash"]:
		Fixtures.send_action_event(action, false)
		Input.action_release(action)
	_bus.disconnect(&"chain_stage_changed", _on_stage)
	_bus.disconnect(&"landed", _on_landed)
	_bus.disconnect(&"jumped", _on_jumped)
	_bus.disconnect(&"double_jumped", _on_double)
	_bus.disconnect(&"long_jumped", _on_long)
	player.queue_free()
	_floor.queue_free()
	await player.tree_exited


## Holds move_forward and waits until the player runs at run speed.
func _run_up(tree: SceneTree, player: PlayerController) -> void:
	Fixtures.send_action_event(&"move_forward", true)
	await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - player.config.run_speed) < 0.05, 120)


## Follows an airtime that was already started (press sent) until the next landed fact. With `hold` the
## jump button stays down until the apex and is released there; without it the caller releases. Returns the
## apex height above the take-off and the landing position.
func _fly(tree: SceneTree, player: PlayerController, hold: bool = true, origin_y: float = NAN) -> Dictionary:
	var landed_before: int = _landed.size()
	var start_y: float = player.global_position.y if is_nan(origin_y) else origin_y
	var max_y: float = player.global_position.y
	var max_speed: float = player.horizontal_speed()
	var released: bool = false
	var frames: int = 0
	while _landed.size() == landed_before and frames < LIMIT_TICKS:
		await tree.physics_frame
		frames += 1
		max_y = maxf(max_y, player.global_position.y)
		max_speed = maxf(max_speed, player.horizontal_speed())
		if hold and not released and frames > 2 and player.vertical_speed <= 0.0:
			Fixtures.send_action_event(&"jump", false)
			released = true
	if not released:
		Fixtures.send_action_event(&"jump", false)
	var land_position: Vector3 = _landed[_landed.size() - 1] if _landed.size() > landed_before else player.global_position
	return {"apex": max_y - start_y, "land": land_position, "landed": _landed.size() > landed_before, "max_speed": max_speed}


## Presses jump (held) and flies one whole held jump.
func _held_jump(tree: SceneTree, player: PlayerController) -> Dictionary:
	Fixtures.send_action_event(&"jump", true)
	return await _fly(tree, player, true)


# --- Task 1: the chain ------------------------------------------------------------------------------------

# D-05: Jump 1 held -> land -> Jump 2 held reaches chain_jump_height, above Jump 1; stages 1 then 2.
func _scenario_chain_held(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	await _run_up(tree, player)
	var first: Dictionary = await _held_jump(tree, player)
	var second: Dictionary = await _held_jump(tree, player)
	check.call(_stages_are([1, 2]), "(c1) chain_stage_changed gives 1 then 2 (got %s)" % [_stages])
	check.call(absf(first.apex - config.jump_height) < 0.1, "(c1) Jump 1 apex %.3f m is within 0.1 of jump_height %.2f" % [first.apex, config.jump_height])
	check.call(absf(second.apex - config.chain_jump_height) < 0.1, "(c1) held Jump 2 apex %.3f m is within 0.1 of chain_jump_height %.2f" % [second.apex, config.chain_jump_height])
	check.call(second.apex > first.apex + 0.3, "(c1) Jump 2 (%.2f m) is higher than Jump 1 (%.2f m)" % [second.apex, first.apex])
	await _end(player)


# D-04: a tapped Jump 2 is still stage 2, but the release cut applies at once.
func _scenario_chain_tapped(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	await _run_up(tree, player)
	await _held_jump(tree, player)
	Fixtures.send_action_event(&"jump", true)
	Fixtures.send_action_event(&"jump", false)
	var tapped: Dictionary = await _fly(tree, player, false)
	check.call(_stages_are([1, 2]), "(c2) a tapped Jump 2 is still stage 2 (got %s)" % [_stages])
	check.call(absf(tapped.apex - config.jump_min_height) < 0.15, "(c2) tapped Jump 2 apex %.3f m is within 0.15 of jump_min_height %.2f" % [tapped.apex, config.jump_min_height])
	await _end(player)


# A press just before landing (inside the buffer) becomes Jump 2 as well.
func _scenario_chain_buffered(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	await _run_up(tree, player)
	Fixtures.send_action_event(&"jump", true)
	var landed_before: int = _landed.size()
	var frames: int = 0
	var released: bool = false
	var pressed_early: bool = false
	while _landed.size() == landed_before and frames < LIMIT_TICKS:
		await tree.physics_frame
		frames += 1
		if not released and frames > 2 and player.vertical_speed <= 0.0:
			Fixtures.send_action_event(&"jump", false)
			released = true
		if released and not pressed_early and player.will_land_within(config.jump_buffer_time * 0.5):
			Fixtures.send_action_event(&"jump", true)
			pressed_early = true
	check.call(pressed_early, "(c3) the early press was sent while the body was about to land")
	await Fixtures.wait_physics(tree, 6)
	check.call(_stages_are([1, 2]), "(c3) a buffered press before landing becomes Jump 2 (got %s)" % [_stages])
	Fixtures.send_action_event(&"jump", false)
	await _end(player)


# D-07: the window runs out -> chain_stage_changed(0), and the next held jump is Jump 1 again.
func _scenario_chain_timeout(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	await _run_up(tree, player)
	await _held_jump(tree, player)
	await Fixtures.wait_physics(tree, int(ceil((config.chain_window + 0.1) * float(TPS))))
	check.call(_stages_are([1, 0]), "(c4) the stage resets to 0 when the landing window runs out (got %s)" % [_stages])
	var later: Dictionary = await _held_jump(tree, player)
	check.call(absf(later.apex - config.jump_height) < 0.1, "(c4) the jump after the timeout peaks at jump_height (%.3f vs %.2f)" % [later.apex, config.jump_height])
	check.call(_stages_are([1, 0, 1]), "(c4) and starts a new chain at 1 (got %s)" % [_stages])
	await _end(player)


# D-07: standing still on the ground resets the chain at once.
func _scenario_chain_standing(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	await _held_jump(tree, player)
	await Fixtures.wait_physics(tree, 2)
	check.call(_stages_are([1, 0]), "(c5) a standing Jump 1 resets the chain within 2 ticks after landing (got %s)" % [_stages])
	await _end(player)


# A8: a ground jump at stage 2 inside the window starts a new chain at Jump 1.
func _scenario_chain_new_after_stage_two(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	await _run_up(tree, player)
	await _held_jump(tree, player)
	await _held_jump(tree, player)
	var third: Dictionary = await _held_jump(tree, player)
	check.call(_stages_are([1, 2, 1]), "(c6) a third ground jump inside the window is Jump 1 again (got %s)" % [_stages])
	check.call(absf(third.apex - config.jump_height) < 0.1, "(c6) its apex %.3f m is within 0.1 of jump_height %.2f" % [third.apex, config.jump_height])
	await _end(player)


# --- Task 2: the long jump ----------------------------------------------------------------------------------

## Horizontal (x, z) distance between two positions.
func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Dash and jump pressed on the same tick (the jump stays held), then follows the long jump to its landing.
## Returns the stage, take-off to landing distance, apex above the take-off, the horizontal speed on the first
## tick of LongJump and the highest horizontal speed of the airtime.
func _dash_jump(tree: SceneTree, player: PlayerController) -> Dictionary:
	var longs_before: int = _longs.size()
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"jump", true)
	Fixtures.send_action_event(&"dash", false)
	var started: int = await Fixtures.wait_until(tree, func() -> bool: return _longs.size() > longs_before, 12)
	if started < 0:
		Fixtures.send_action_event(&"jump", false)
		return {"started": false}
	var event: Dictionary = _longs[_longs.size() - 1]
	var first_speed: float = player.horizontal_speed()
	var flight: Dictionary = await _fly(tree, player, true, (event.position as Vector3).y)
	return {
		"started": true,
		"stage": event.stage,
		"distance": _flat_distance(event.position, flight.land),
		"apex": flight.apex,
		"first_speed": first_speed,
		"max_speed": flight.max_speed,
	}


# D-06: a jump during a plain ground dash is a stage 0 long jump that carries the dash speed and is
# farther and flatter than a normal running jump.
func _scenario_plain_long_jump(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	await _run_up(tree, player)
	var normal_takeoff: Vector3 = player.global_position
	var normal: Dictionary = await _held_jump(tree, player)
	var normal_distance: float = _flat_distance(normal_takeoff, normal.land)
	# Let the window of the normal jump run out, so the dash starts a plain chain.
	await Fixtures.wait_physics(tree, int(ceil((config.chain_window + 0.1) * float(TPS))))
	check.call(player.chain_stage == 0, "(l1) the chain is empty before the plain dash (stage %d)" % player.chain_stage)

	# Dash alone first; the jump follows on the 3rd tick of the dash.
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"dash", false)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 6)
	await Fixtures.wait_physics(tree, 2)
	var longs_before: int = _longs.size()
	Fixtures.send_action_event(&"jump", true)
	var started: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"LongJump", 6)
	var carried: float = player.horizontal_speed()
	check.call(started >= 0, "(l1) a jump during a plain ground dash goes Dash -> LongJump (state %s)" % player.state_machine.current.name)
	check.call(_longs.size() == longs_before + 1 and _longs[_longs.size() - 1].stage == 0, "(l1) long_jumped is emitted once with stage 0 (got %s)" % [_longs])
	if _longs.is_empty():
		await _end(player)
		return
	var expected_speed: float = minf(maxf(config.dash_speed, config.long_jump_speed(0)), config.long_jump_speed_cap)
	check.call(absf(carried - expected_speed) < 0.1, "(l2) the take-off speed %.2f m/s is the carried dash speed %.2f (within 0.1)" % [carried, expected_speed])
	check.call(player.chain_stage == 0, "(l2) the chain is consumed (stage %d)" % player.chain_stage)
	var takeoff: Vector3 = _longs[_longs.size() - 1].position
	var flight: Dictionary = await _fly(tree, player, true, takeoff.y)
	var distance: float = _flat_distance(takeoff, flight.land)
	check.call(distance > normal_distance + 2.0, "(l1) the long jump (%.2f m) is farther than a normal running jump (%.2f m)" % [distance, normal_distance])
	check.call(flight.apex < normal.apex - 0.3, "(l1) and flatter: apex %.2f m vs %.2f m" % [flight.apex, normal.apex])
	check.call(absf(flight.apex - config.long_jump_height(0)) < 0.1, "(l1) the apex %.3f m is within 0.1 of long_jump_height(0) %.2f" % [flight.apex, config.long_jump_height(0)])
	await _end(player)


# D-06: a jump within dash_jump_grace of a ground dash is a long jump; after the grace it is a normal jump.
func _scenario_grace(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	var dt: float = 1.0 / float(TPS)
	await _run_up(tree, player)

	# (a) early in the grace.
	await _dash_and_wait_for_end(tree, player)
	check.call(player.dash_jump_grace_timer > 0.0, "(l3) the grace timer runs after a ground dash ended (%.3f s)" % player.dash_jump_grace_timer)
	await Fixtures.wait_physics(tree, 1)
	Fixtures.send_action_event(&"jump", true)
	var early: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"LongJump", 4)
	check.call(early >= 0 and _longs.size() == 1, "(l3) a jump early in the grace is a long jump (state %s, long_jumped %d)" % [player.state_machine.current.name, _longs.size()])
	var flight: Dictionary = await _fly(tree, player, false)
	check.call(flight.landed, "(l3) the early grace long jump lands")
	await Fixtures.wait_physics(tree, int(ceil((config.chain_window + config.dash_cooldown + 0.1) * float(TPS))))

	# (b) late in the grace: the carried speed is below the stage row, so the row is the take-off speed.
	await _dash_and_wait_for_end(tree, player)
	await Fixtures.wait_until(tree, func() -> bool: return player.dash_jump_grace_timer > 1.5 * dt and player.dash_jump_grace_timer <= 2.5 * dt, 20)
	var carried_before: float = player.horizontal_speed()
	Fixtures.send_action_event(&"jump", true)
	var late: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"LongJump", 4)
	var late_speed: float = player.horizontal_speed()
	check.call(late >= 0 and _longs.size() == 2, "(l4) a jump in the last tick of the grace is a long jump (state %s, long_jumped %d)" % [player.state_machine.current.name, _longs.size()])
	check.call(carried_before < config.long_jump_speed(0), "(l4) the speed carried at the press (%.2f) is below the stage 0 row %.1f" % [carried_before, config.long_jump_speed(0)])
	check.call(absf(late_speed - config.long_jump_speed(0)) < 0.1, "(l4) a late-grace jump takes off at long_jump_speed(0): %.2f vs %.1f" % [late_speed, config.long_jump_speed(0)])
	await _fly(tree, player, false)
	await Fixtures.wait_physics(tree, int(ceil((config.chain_window + config.dash_cooldown + 0.1) * float(TPS))))

	# (c) after the grace a jump is a normal Jump.
	await _dash_and_wait_for_end(tree, player)
	await Fixtures.wait_until(tree, func() -> bool: return player.dash_jump_grace_timer <= 0.0, 30)
	await Fixtures.wait_physics(tree, 3)
	var jumped_before: int = _jumped
	Fixtures.send_action_event(&"jump", true)
	var normal: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Jump", 4)
	check.call(normal >= 0 and _longs.size() == 2 and _jumped == jumped_before + 1, "(l5) a jump after the grace is a normal Jump (state %s, long_jumped %d)" % [player.state_machine.current.name, _longs.size()])
	await _fly(tree, player, false)
	await _end(player)


## A ground dash pressed while running, followed until the Dash state ends.
func _dash_and_wait_for_end(tree: SceneTree, player: PlayerController) -> void:
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"dash", false)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 6)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name != &"Dash", 40)


# D-05: Dash -> Jump after no jump, Jump 1 and Jump 1 + Jump 2 gives stages 0, 1, 2 and growing distances.
func _scenario_stage_distances(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	await _run_up(tree, player)
	var small: Dictionary = await _dash_jump(tree, player)
	await Fixtures.wait_physics(tree, int(ceil((config.chain_window + config.dash_cooldown + 0.1) * float(TPS))))
	await _run_up(tree, player)
	await _held_jump(tree, player)
	var mid: Dictionary = await _dash_jump(tree, player)
	await Fixtures.wait_physics(tree, int(ceil((config.chain_window + config.dash_cooldown + 0.1) * float(TPS))))
	await _run_up(tree, player)
	await _held_jump(tree, player)
	await _held_jump(tree, player)
	var maximum: Dictionary = await _dash_jump(tree, player)
	check.call(small.started and mid.started and maximum.started, "(l6) all three dash jumps became long jumps")
	if small.started and mid.started and maximum.started:
		check.call(small.stage == 0 and mid.stage == 1 and maximum.stage == 2, "(l6) long_jumped stages are 0, 1, 2 (got %d, %d, %d)" % [small.stage, mid.stage, maximum.stage])
		check.call(small.distance < mid.distance and mid.distance < maximum.distance, "(l6) distances order small < mid < max (%.2f < %.2f < %.2f m)" % [small.distance, mid.distance, maximum.distance])
		check.call(small.apex < mid.apex and mid.apex < maximum.apex, "(l6) apexes order small < mid < max (%.2f < %.2f < %.2f m)" % [small.apex, mid.apex, maximum.apex])
		check.call(absf(maximum.apex - config.long_jump_height(2)) < 0.1, "(l6) the max long jump apex %.3f m is within 0.1 of long_jump_height(2) %.2f" % [maximum.apex, config.long_jump_height(2)])
		check.call(player.chain_stage == 0, "(l6) the chain is consumed after the max long jump (stage %d)" % player.chain_stage)
	await _end(player)


# Pitfall 12: the carry is bounded. With dash_speed 30 and a cap of 24 the take-off is 24, never above.
func _scenario_cap(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	player.config = player.config.duplicate() as MovementConfig
	player.config.dash_speed = 30.0
	player.config.long_jump_speed_cap = 24.0
	await _run_up(tree, player)
	var capped: Dictionary = await _dash_jump(tree, player)
	check.call(capped.started, "(l7) the dash jump with dash_speed 30 is a long jump")
	if capped.started:
		check.call(absf(capped.first_speed - 24.0) < 0.1, "(l7) the take-off speed %.2f m/s equals long_jump_speed_cap 24 (within 0.1)" % capped.first_speed)
		check.call(capped.max_speed <= 24.1, "(l7) the speed never exceeds the cap during the airtime (max %.2f m/s)" % capped.max_speed)
	await _end(player)


# A1: an air dash followed by a jump is the double jump, never a long jump.
func _scenario_air_dash_is_double(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	await _run_up(tree, player)
	Fixtures.send_action_event(&"jump", true)
	await Fixtures.wait_physics(tree, 8)
	Fixtures.send_action_event(&"jump", false)
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"dash", false)
	var dashing: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 6)
	check.call(dashing >= 0, "(l8) the air dash starts (state %s)" % player.state_machine.current.name)
	await Fixtures.wait_physics(tree, 2)
	Fixtures.send_action_event(&"jump", true)
	var doubled: int = await Fixtures.wait_until(tree, func() -> bool: return _doubles > 0, 8)
	check.call(doubled >= 0 and _doubles == 1, "(l8) jump -> air dash -> jump gives double_jumped (%d)" % _doubles)
	check.call(_longs.is_empty(), "(l8) and no long_jumped (%d)" % _longs.size())
	await _fly(tree, player, false)
	await _end(player)
