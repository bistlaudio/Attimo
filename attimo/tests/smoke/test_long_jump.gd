extends RefCounted
## MOVE-07 / MOVE-05 / D-05 / D-06 / D-07: the ground-jump chain and the long jump. Jump 1 -> land -> Jump 2 ->
## land -> Jump 3 (the salto, highest) inside the landing window. Dash -> Jump = the dash hop, a long jump at the
## speed of its stage (set, never carried); clean repeats on landing climb the stack 1 -> 2 -> 3 and stay at 3, a miss
## restarts at 1. Every expectation derives from player.config. Scenarios that need other numbers duplicate the config
## first (the shared resource is never mutated). Presses go through the input pipeline
## (Fixtures.send_action_event), actions are released before nodes are freed and the tick rate stays at 60.

const Fixtures := preload("res://tests/fixtures.gd")
const TPS: int = 60
const LIMIT_TICKS: int = 360

var _bus: Node
var _stages: Array[int] = []
var _landed: Array[Vector3] = []
var _jumped: int = 0
var _air_dashes: int = 0
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
	await _scenario_chain_new_after_stage_three(tree, check)
	await _scenario_salto_then_one_air_dash(tree, check)
	await _scenario_plain_long_jump(tree, check)
	await _scenario_hop_stack(tree, check)
	await _scenario_stack_misses(tree, check)
	await _scenario_grace(tree, check)
	await _scenario_set_not_carried(tree, check)
	await _scenario_chain_reset_by_dash_and_hop(tree, check)
	await _scenario_air_dash_then_jump(tree, check)


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


func _on_dash(_position: Vector3, _direction: Vector3, in_air: bool) -> void:
	if in_air:
		_air_dashes += 1


func _on_long(position: Vector3, stage: int) -> void:
	_longs.append({"position": position, "stage": stage, "frame": Engine.get_physics_frames()})


## Fresh recorders, a long floor and a player at `position` (default far down +Z, so a run toward -Z has room).
func _begin(tree: SceneTree, position: Vector3 = Vector3(0.0, 0.0, 70.0)) -> PlayerController:
	_stages = []
	_landed = []
	_longs = []
	_jumped = 0
	_air_dashes = 0
	_bus.connect(&"chain_stage_changed", _on_stage)
	_bus.connect(&"landed", _on_landed)
	_bus.connect(&"jumped", _on_jumped)
	_bus.connect(&"dash_started", _on_dash)
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
	_bus.disconnect(&"dash_started", _on_dash)
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

# D-05 / U4: Jump 1 -> land -> Jump 2 -> land -> Jump 3 (salto), all held: apexes match jump_height,
# jump_2_height, jump_3_height and rise strictly; stages 1, 2, 3.
func _scenario_chain_held(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	await _run_up(tree, player)
	var first: Dictionary = await _held_jump(tree, player)
	var second: Dictionary = await _held_jump(tree, player)
	var third: Dictionary = await _held_jump(tree, player)
	check.call(_stages_are([1, 2, 3]), "(c1) chain_stage_changed gives 1, 2, 3 (got %s)" % [_stages])
	check.call(absf(first.apex - config.jump_height) < 0.1, "(c1) Jump 1 apex %.3f m is within 0.1 of jump_height %.2f" % [first.apex, config.jump_height])
	check.call(absf(second.apex - config.jump_2_height) < 0.1, "(c1) held Jump 2 apex %.3f m is within 0.1 of jump_2_height %.2f" % [second.apex, config.jump_2_height])
	check.call(absf(third.apex - config.jump_3_height) < 0.1, "(c1) held Jump 3 apex %.3f m is within 0.1 of jump_3_height %.2f" % [third.apex, config.jump_3_height])
	check.call(second.apex > first.apex + 0.3 and third.apex > second.apex + 0.3, "(c1) the apexes rise strictly: %.2f < %.2f < %.2f m" % [first.apex, second.apex, third.apex])
	check.call(is_equal_approx(config.jump_height_for_stage(3), config.jump_3_height) and config.jump_3_height > config.jump_2_height and config.jump_2_height > config.jump_height, "(c1) the config rows rise: jump_height < jump_2_height < jump_3_height")
	await _end(player)


# D-04: a tapped Jump 3 is still stage 3, but the release cut applies at once.
func _scenario_chain_tapped(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	await _run_up(tree, player)
	await _held_jump(tree, player)
	await _held_jump(tree, player)
	Fixtures.send_action_event(&"jump", true)
	Fixtures.send_action_event(&"jump", false)
	var tapped: Dictionary = await _fly(tree, player, false)
	check.call(_stages_are([1, 2, 3]), "(c2) a tapped Jump 3 is still stage 3 (got %s)" % [_stages])
	check.call(absf(tapped.apex - config.jump_min_height) < 0.15, "(c2) tapped Jump 3 apex %.3f m is within 0.15 of jump_min_height %.2f" % [tapped.apex, config.jump_min_height])
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
		if released and not pressed_early and Fixtures.will_land_within(player, config.jump_buffer_time * 0.5):
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
	await Fixtures.wait_physics(tree, int(ceil((config.landing_window + 0.1) * float(TPS))))
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


# A8 / U4: a fourth ground jump inside the window, after the salto, starts a new chain at Jump 1.
func _scenario_chain_new_after_stage_three(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	await _run_up(tree, player)
	await _held_jump(tree, player)
	await _held_jump(tree, player)
	await _held_jump(tree, player)
	var fourth: Dictionary = await _held_jump(tree, player)
	check.call(_stages_are([1, 2, 3, 1]), "(c6) a fourth ground jump inside the window is Jump 1 again (got %s)" % [_stages])
	check.call(absf(fourth.apex - config.jump_height) < 0.1, "(c6) its apex %.3f m is within 0.1 of jump_height %.2f" % [fourth.apex, config.jump_height])
	await _end(player)


# U2 / U4: after the Jump 3 salto exactly one air dash fires, and a second press in the same airtime is refused.
func _scenario_salto_then_one_air_dash(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	# Cooldown 0 so only the per-airtime flag can refuse the second dash.
	player.config = player.config.duplicate() as MovementConfig
	player.config.dash_cooldown = 0.0
	await _run_up(tree, player)
	await _held_jump(tree, player)
	await _held_jump(tree, player)
	Fixtures.send_action_event(&"jump", true)
	await Fixtures.wait_until(tree, func() -> bool: return not player.is_grounded() and player.vertical_speed <= 0.0, 120)
	check.call(_stages_are([1, 2, 3]), "(c7) the third jump is the salto (got %s)" % [_stages])
	Fixtures.send_action_event(&"jump", false)
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"dash", false)
	await Fixtures.wait_physics(tree, 3)
	check.call(_air_dashes == 1, "(c7) the first dash after the salto is an air dash (air dashes %d)" % _air_dashes)
	await Fixtures.wait_physics(tree, int(ceil((player.config.dash_time + 0.07) * float(TPS))))
	var airborne: bool = not player.is_grounded()
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"dash", false)
	await Fixtures.wait_physics(tree, 3)
	check.call(airborne, "(c7) the player is still in the air for the second dash press")
	check.call(_air_dashes == 1, "(c7) a second air dash in the same airtime is refused (air dashes %d)" % _air_dashes)
	await _fly(tree, player, false)
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


# D-06 / U5: a jump during a plain ground dash is long jump stage 1 at long_jump_speed_1 (above run speed),
# higher and farther than a normal running jump.
func _scenario_plain_long_jump(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var config: MovementConfig = player.config
	await _run_up(tree, player)
	var normal_takeoff: Vector3 = player.global_position
	var normal: Dictionary = await _held_jump(tree, player)
	var normal_distance: float = _flat_distance(normal_takeoff, normal.land)
	# Let the window of the normal jump run out, so the dash starts a fresh stack.
	await Fixtures.wait_physics(tree, int(ceil((config.landing_window + 0.1) * float(TPS))))
	check.call(player.chain_stage == 0 and player.long_jump_stage == 0, "(l1) chain and stack are empty before the plain dash (%d, %d)" % [player.chain_stage, player.long_jump_stage])

	# Dash alone first; the jump follows on the 3rd tick of the dash.
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"dash", false)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 6)
	await Fixtures.wait_physics(tree, 2)
	var longs_before: int = _longs.size()
	Fixtures.send_action_event(&"jump", true)
	var started: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"LongJump", 6)
	var takeoff_speed: float = player.horizontal_speed()
	check.call(started >= 0, "(l1) a jump during a plain ground dash goes Dash -> LongJump (state %s)" % player.state_machine.current.name)
	check.call(_longs.size() == longs_before + 1 and _longs[_longs.size() - 1].stage == 1, "(l1) long_jumped is emitted once with stage 1 (got %s)" % [_longs])
	if _longs.is_empty():
		await _end(player)
		return
	check.call(absf(takeoff_speed - config.long_jump_speed_1) < 0.1, "(l2) the take-off speed %.2f m/s is long_jump_speed_1 %.1f (within 0.1)" % [takeoff_speed, config.long_jump_speed_1])
	check.call(takeoff_speed > config.run_speed + 1.0, "(l2) and above the run speed %.1f m/s" % config.run_speed)
	check.call(player.chain_stage == 0 and player.long_jump_stage == 1, "(l2) the chain is consumed and the stack is at 1 (chain %d, stack %d)" % [player.chain_stage, player.long_jump_stage])
	var takeoff: Vector3 = _longs[_longs.size() - 1].position
	var flight: Dictionary = await _fly(tree, player, true, takeoff.y)
	var distance: float = _flat_distance(takeoff, flight.land)
	check.call(distance > normal_distance + 2.0, "(l1) the long jump (%.2f m) is farther than a normal running jump (%.2f m)" % [distance, normal_distance])
	check.call(absf(flight.apex - config.long_jump_height_1) < 0.15, "(l1) the apex %.3f m is within 0.15 of long_jump_height_1 %.2f" % [flight.apex, config.long_jump_height_1])
	await _end(player)


# U5: dash + jump on the landing tick of each long jump climbs the stack: stages 1, 2, 3, then 3 again. Take-off
# speeds and apexes match the rows, distances rise over stages 1-3, no tick exceeds 22 m/s.
func _scenario_hop_stack(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree, Vector3(0.0, 0.0, 78.0))
	var config: MovementConfig = player.config
	await _run_up(tree, player)
	var hops: Array[Dictionary] = []
	for i: int in 4:
		hops.append(await _dash_jump(tree, player))
	var all_started: bool = true
	for hop: Dictionary in hops:
		all_started = all_started and hop.started
	check.call(all_started, "(l3) all four dash jumps became long jumps")
	if all_started:
		var stages: Array[int] = []
		for hop: Dictionary in hops:
			stages.append(int(hop.stage))
		check.call(stages == [1, 2, 3, 3], "(l3) long_jumped stages are 1, 2, 3, 3 (got %s)" % [stages])
		for i: int in 4:
			var stage: int = mini(i + 1, 3)
			var hop: Dictionary = hops[i]
			check.call(absf(hop.first_speed - config.long_jump_speed(stage)) < 0.1, "(l3) hop %d takes off at long_jump_speed(%d) %.1f (got %.2f)" % [i + 1, stage, config.long_jump_speed(stage), hop.first_speed])
			check.call(absf(hop.apex - config.long_jump_height(stage)) < 0.15, "(l3) hop %d apex %.3f m is within 0.15 of long_jump_height(%d) %.2f" % [i + 1, hop.apex, stage, config.long_jump_height(stage)])
			check.call(hop.max_speed <= 22.1, "(l3) hop %d never exceeds 22 m/s (max %.2f)" % [i + 1, hop.max_speed])
		check.call(hops[0].distance < hops[1].distance and hops[1].distance < hops[2].distance, "(l3) distances rise over stages 1-3 (%.2f < %.2f < %.2f m)" % [hops[0].distance, hops[1].distance, hops[2].distance])
		check.call(absf(hops[3].distance - hops[2].distance) < 0.3, "(l3) the fourth hop stays at stage 3 (%.2f vs %.2f m)" % [hops[3].distance, hops[2].distance])
	for stage: int in [1, 2, 3]:
		check.call(config.long_jump_speed(stage) <= 22.0, "(l3) the row long_jump_speed(%d) %.1f is at most 22 m/s" % [stage, config.long_jump_speed(stage)])
	await _end(player)


# U5: a miss restarts the stack at stage 1: the window runs out, a normal ground jump in between, or standing still.
func _scenario_stack_misses(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree, Vector3(0.0, 0.0, 78.0))
	var config: MovementConfig = player.config
	await _run_up(tree, player)
	var first: Dictionary = await _dash_jump(tree, player)
	var second: Dictionary = await _dash_jump(tree, player)
	check.call(first.started and second.started and first.stage == 1 and second.stage == 2, "(l4) the stack is at 2 after two clean hops (got %s, %s)" % [first.get("stage"), second.get("stage")])
	# (a) the window runs out while running.
	await Fixtures.wait_physics(tree, int(ceil((config.landing_window + 0.1) * float(TPS))))
	check.call(player.long_jump_stage == 0, "(l4) the stack is empty after the landing window ran out (stack %d)" % player.long_jump_stage)
	var after_timeout: Dictionary = await _dash_jump(tree, player)
	check.call(after_timeout.started and after_timeout.stage == 1, "(l4) the hop after the timeout is stage 1 (got %s)" % after_timeout.get("stage"))
	# (b) a normal jump in between.
	var normal: Dictionary = await _held_jump(tree, player)
	check.call(normal.landed and player.long_jump_stage == 0, "(l4) a normal ground jump clears the stack (stack %d)" % player.long_jump_stage)
	await Fixtures.wait_physics(tree, int(ceil((config.dash_cooldown + 0.1) * float(TPS))))
	var after_jump: Dictionary = await _dash_jump(tree, player)
	check.call(after_jump.started and after_jump.stage == 1, "(l4) the hop after a normal jump is stage 1 (got %s)" % after_jump.get("stage"))
	# (c) standing still.
	Fixtures.send_action_event(&"move_forward", false)
	await Fixtures.wait_physics(tree, int(ceil((config.landing_window + 0.1) * float(TPS))))
	check.call(player.long_jump_stage == 0, "(l4) standing still clears the stack (stack %d)" % player.long_jump_stage)
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
	await Fixtures.wait_physics(tree, int(ceil((config.landing_window + config.dash_cooldown + 0.1) * float(TPS))))

	# (b) late in the grace: the carried speed is below the stage row, so the row is the take-off speed.
	await _dash_and_wait_for_end(tree, player)
	await Fixtures.wait_until(tree, func() -> bool: return player.dash_jump_grace_timer > 1.5 * dt and player.dash_jump_grace_timer <= 2.5 * dt, 20)
	var carried_before: float = player.horizontal_speed()
	Fixtures.send_action_event(&"jump", true)
	var late: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"LongJump", 4)
	var late_speed: float = player.horizontal_speed()
	check.call(late >= 0 and _longs.size() == 2, "(l4) a jump in the last tick of the grace is a long jump (state %s, long_jumped %d)" % [player.state_machine.current.name, _longs.size()])
	check.call(carried_before < config.long_jump_speed(1), "(l4) the speed carried at the press (%.2f) is below the stage 1 row %.1f" % [carried_before, config.long_jump_speed(1)])
	check.call(absf(late_speed - config.long_jump_speed(1)) < 0.1, "(l4) a late-grace jump takes off at long_jump_speed(1): %.2f vs %.1f" % [late_speed, config.long_jump_speed(1)])
	await _fly(tree, player, false)
	await Fixtures.wait_physics(tree, int(ceil((config.landing_window + config.dash_cooldown + 0.1) * float(TPS))))

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


# U5 (Pitfall 12): the stage speed is set, not carried. With dash_speed 30 the take-off is still the stage 1 row.
func _scenario_set_not_carried(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	player.config = player.config.duplicate() as MovementConfig
	player.config.dash_speed = 30.0
	await _run_up(tree, player)
	var fast: Dictionary = await _dash_jump(tree, player)
	check.call(fast.started, "(l6) the dash jump with dash_speed 30 is a long jump")
	if fast.started:
		check.call(absf(fast.first_speed - player.config.long_jump_speed_1) < 0.1, "(l6) the take-off speed %.2f m/s is the stage 1 row %.1f, not the dash speed" % [fast.first_speed, player.config.long_jump_speed_1])
		check.call(fast.max_speed <= 22.1, "(l6) the speed never exceeds 22 m/s during the airtime (max %.2f m/s)" % fast.max_speed)
	await _end(player)


# D-05: a ground dash breaks the ground-jump chain (chain_stage_changed 0); the long jump keeps it at 0.
func _scenario_chain_reset_by_dash_and_hop(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	await _run_up(tree, player)
	await _held_jump(tree, player)
	check.call(player.chain_stage == 1, "(l7) Jump 1 leaves the chain at 1 (stage %d)" % player.chain_stage)
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"dash", false)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 6)
	check.call(player.chain_stage == 0 and _stages_are([1, 0]), "(l7) a ground dash resets the chain (stage %d, facts %s)" % [player.chain_stage, _stages])
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name != &"Dash", 40)
	await Fixtures.wait_physics(tree, 1)
	var hop_count: int = _longs.size()
	Fixtures.send_action_event(&"jump", true)
	await Fixtures.wait_until(tree, func() -> bool: return _longs.size() > hop_count, 6)
	check.call(_longs.size() == hop_count + 1 and player.chain_stage == 0 and player.long_jump_stage == _longs[_longs.size() - 1].stage, "(l7) the long jump leaves the chain at 0 and the stack at its stage (chain %d, stack %d)" % [player.chain_stage, player.long_jump_stage])
	await _fly(tree, player, false)
	await _end(player)


# A1 / U2: an air dash followed by a jump press adds no rise and gives neither jumped nor long_jumped.
func _scenario_air_dash_then_jump(tree: SceneTree, check: Callable) -> void:
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
	var jumped_before: int = _jumped
	Fixtures.send_action_event(&"jump", true)
	var rose: bool = false
	var frames: int = 0
	var landed_before: int = _landed.size()
	while _landed.size() == landed_before and frames < LIMIT_TICKS:
		await tree.physics_frame
		frames += 1
		rose = rose or player.vertical_speed > 0.0
		if frames == 4:
			Fixtures.send_action_event(&"jump", false)
	check.call(not rose, "(l8) a jump press during or after an air dash adds no rise")
	check.call(_jumped == jumped_before and _longs.is_empty(), "(l8) and gives no jumped and no long_jumped (jumped +%d, long_jumped %d)" % [_jumped - jumped_before, _longs.size()])
	await _end(player)
