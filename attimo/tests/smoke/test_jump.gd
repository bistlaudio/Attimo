extends RefCounted
## MOVE-03 / MOVE-04 / MOVE-05: variable jump height, heavier fall, tick-rate independence, coyote time,
## the jump buffer and the double jump. Every expectation derives from player.config.
## Jump presses go through the input pipeline (Fixtures.send_action_event), so a press and a release inside
## one tick reaches the controller as just_pressed with the button already up. Actions are released and the
## tick rate is restored to 60 before nodes are freed.

const Fixtures := preload("res://tests/fixtures.gd")

var _bus: Node
var _jumped: Array[int] = []
var _landed: Array[int] = []
var _double: Array[int] = []
var _double_y: Array[float] = []


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	_bus.connect(&"jumped", _on_jumped)
	_bus.connect(&"landed", _on_landed)
	_bus.connect(&"double_jumped", _on_double_jumped)

	await _scenario_hold_and_tap(tree, check)
	await _scenario_tick_rate(tree, check)
	await _scenario_coyote(tree, check)
	await _scenario_buffer_keeps_speed(tree, check)
	await _scenario_buffer_released(tree, check)
	await _scenario_double_jump_held(tree, check)
	await _scenario_double_jump_tapped(tree, check)
	await _scenario_one_per_airtime(tree, check)
	await _scenario_ledge_double_jump(tree, check)
	await _scenario_near_landing_is_not_double(tree, check)
	await _scenario_spent_press_expires(tree, check)

	_bus.disconnect(&"jumped", _on_jumped)
	_bus.disconnect(&"landed", _on_landed)
	_bus.disconnect(&"double_jumped", _on_double_jumped)


func _on_jumped(_position: Vector3) -> void:
	_jumped.append(Engine.get_physics_frames())


func _on_landed(_position: Vector3, _impact_speed: float) -> void:
	_landed.append(Engine.get_physics_frames())


func _on_double_jumped(position: Vector3) -> void:
	_double.append(Engine.get_physics_frames())
	_double_y.append(position.y)


func _reset() -> void:
	_jumped.clear()
	_landed.clear()
	_double.clear()
	_double_y.clear()


func _press_jump() -> void:
	Fixtures.send_action_event(&"jump", true)


func _release_jump() -> void:
	Fixtures.send_action_event(&"jump", false)


func _tap_jump() -> void:
	Fixtures.send_action_event(&"jump", true)
	Fixtures.send_action_event(&"jump", false)


## A floor and a player standing on it (or `settle` false: dropped from `position`).
func _spawn(tree: SceneTree, position: Vector3, settle: bool = true) -> Array[Node]:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, position)
	if settle:
		await Fixtures.wait_physics(tree, maxi(5, int(Engine.physics_ticks_per_second / 10.0)))
	return [floor_body, player]


func _free_all(tree: SceneTree, nodes: Array[Node]) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame


## Records the jump profile of a jump that was already started: apex height, the frame offsets of take-off
## and apex, and the frame count until the landed fact.
func _record_jump(tree: SceneTree, player: PlayerController) -> Dictionary:
	var takeoff: int = -1
	var apex_frame: int = 0
	var max_y: float = 0.0
	var frames: int = 0
	var limit: int = Engine.physics_ticks_per_second * 4
	while _landed.is_empty() and frames < limit:
		await tree.physics_frame
		frames += 1
		var y: float = player.global_position.y
		if takeoff < 0 and y > 0.01:
			takeoff = frames
		if y > max_y:
			max_y = y
			apex_frame = frames
	return {"apex": max_y, "rise": apex_frame - takeoff, "fall": frames - apex_frame, "frames": frames}


# (a) hold reaches jump_height, a one-tick tap reaches jump_min_height, the fall is heavier (MOVE-03, D-04).
func _scenario_hold_and_tap(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, Vector3.ZERO)
	var player: PlayerController = nodes[1] as PlayerController
	var config: MovementConfig = player.config
	_reset()
	_press_jump()
	var held: Dictionary = await _record_jump(tree, player)
	_release_jump()
	await Fixtures.wait_physics(tree, 3)
	check.call(absf(held.apex - config.jump_height) < 0.1, "(a) held jump apex %.3f m is within 0.1 of jump_height %.2f" % [held.apex, config.jump_height])
	check.call(held.fall < held.rise, "(a) the fall (%d ticks) is shorter than the rise (%d ticks)" % [held.fall, held.rise])
	await _free_all(tree, nodes)

	nodes = await _spawn(tree, Vector3.ZERO)
	player = nodes[1] as PlayerController
	_reset()
	_tap_jump()
	var tapped: Dictionary = await _record_jump(tree, player)
	await Fixtures.wait_physics(tree, 3)
	check.call(absf(tapped.apex - config.jump_min_height) < 0.15, "(a) one-tick tap apex %.3f m is within 0.15 of jump_min_height %.2f" % [tapped.apex, config.jump_min_height])
	check.call(tapped.apex < held.apex - 0.5, "(a) tapping (%.2f m) jumps lower than holding (%.2f m)" % [tapped.apex, held.apex])
	await _free_all(tree, nodes)


# (b) a held jump peaks within g * dt^2 / 8 + 0.03 m of jump_height at 10, 60 and 120 TPS (Pitfall 4).
func _scenario_tick_rate(tree: SceneTree, check: Callable) -> void:
	for tps: int in [10, 60, 120]:
		Engine.physics_ticks_per_second = tps
		await Fixtures.wait_physics(tree, 2)
		var nodes: Array[Node] = await _spawn(tree, Vector3.ZERO)
		var player: PlayerController = nodes[1] as PlayerController
		var config: MovementConfig = player.config
		_reset()
		_press_jump()
		var held: Dictionary = await _record_jump(tree, player)
		_release_jump()
		var tolerance: float = config.gravity() / float(tps * tps) / 8.0 + 0.03
		check.call(absf(held.apex - config.jump_height) <= tolerance, "(b) at %d TPS the held apex %.3f m is within %.3f of jump_height %.2f" % [tps, held.apex, tolerance, config.jump_height])
		await _free_all(tree, nodes)
	Engine.physics_ticks_per_second = 60
	await Fixtures.wait_physics(tree, 2)


## Runs off a ledge, waits `offset` ticks after the player left the floor and taps jump.
## Returns {"jumped": ..., "double": ...}, the facts caused by that tap (-1 when the player never left the ledge).
func _coyote_case(tree: SceneTree, offset: int) -> Dictionary:
	var ledge: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(10, 1, 10), Vector3(0, -0.5, 0))
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0, 0, -2))
	await Fixtures.wait_physics(tree, 5)
	_reset()
	Input.action_press(&"move_forward")
	var left: int = await Fixtures.wait_until(tree, func() -> bool: return not player.is_grounded(), 180)
	await Fixtures.wait_physics(tree, offset)
	var airborne: bool = left >= 0 and not player.is_grounded()
	_tap_jump()
	await Fixtures.wait_physics(tree, 3)
	var result: Dictionary = {
		"jumped": _jumped.size() if airborne else -1,
		"double": _double.size() if airborne else -1,
	}
	Input.action_release(&"move_forward")
	await _free_all(tree, [ledge, player])
	return result


# (c) coyote edge: coyote_time - 2 ticks is a ground jump, coyote_time + 3 ticks is not (D-09).
func _scenario_coyote(tree: SceneTree, check: Callable) -> void:
	var config: MovementConfig = (load("res://resources/player/movement_default.tres") as MovementConfig)
	var tps: float = float(Engine.physics_ticks_per_second)
	var inside: int = int(floor(config.coyote_time * tps)) - 2
	var outside: int = int(ceil(config.coyote_time * tps)) + 3
	var inside_case: Dictionary = await _coyote_case(tree, inside)
	var outside_case: Dictionary = await _coyote_case(tree, outside)
	var inside_jumps: int = inside_case.jumped
	var outside_jumps: int = outside_case.jumped
	check.call(inside_jumps == 1, "(c) a jump %d ticks after walking off a ledge is a ground jump (jumped=%d)" % [inside, inside_jumps])
	check.call(outside_jumps == 0, "(c) a jump %d ticks after walking off a ledge is not a ground jump (jumped=%d)" % [outside, outside_jumps])
	check.call(inside_case.double == 0, "(c) the coyote ground jump leaves the double jump unspent (double_jumped=%d)" % inside_case.double)


## Drops the player from 4 m, taps jump once will_land_within(jump_buffer_time * 0.5) holds, and records
## the speeds around the buffered jump. `forward` holds move_forward, `released` taps (press + release).
func _buffer_case(tree: SceneTree, forward: bool) -> Dictionary:
	var nodes: Array[Node] = await _spawn(tree, Vector3(0.0, 4.0, 0.0), false)
	var player: PlayerController = nodes[1] as PlayerController
	var config: MovementConfig = player.config
	_reset()
	if forward:
		Input.action_press(&"move_forward")
	var tapped: bool = false
	var tap_predicted: bool = false
	var speed_before: float = 0.0
	var frames: int = 0
	while _jumped.is_empty() and frames < 240:
		await tree.physics_frame
		frames += 1
		if _landed.is_empty():
			speed_before = player.horizontal_speed()
		if not tapped and player.vertical_speed < 0.0 and player.will_land_within(config.jump_buffer_time * 0.5):
			tap_predicted = true
			tapped = true
			_tap_jump()
	await Fixtures.wait_physics(tree, 1)
	var speed_after: float = player.horizontal_speed()
	var max_y: float = 0.0
	for i: int in 90:
		await tree.physics_frame
		max_y = maxf(max_y, player.global_position.y)
	var result: Dictionary = {
		"predicted": tap_predicted,
		"landed": _landed[0] if not _landed.is_empty() else -1000,
		"jumped": _jumped[0] if not _jumped.is_empty() else 1000,
		"speed_before": speed_before,
		"speed_after": speed_after,
		"apex": max_y,
		"config": config,
	}
	Input.action_release(&"move_forward")
	await _free_all(tree, nodes)
	return result


# (d) buffer edge: a near-landing press fires on the landing tick and keeps the speed (D-09, A7).
func _scenario_buffer_keeps_speed(tree: SceneTree, check: Callable) -> void:
	var data: Dictionary = await _buffer_case(tree, true)
	var gap: int = data.jumped - data.landed
	check.call(data.predicted, "(d) will_land_within(jump_buffer_time * 0.5) became true while falling")
	check.call(gap >= 0 and gap <= 2, "(d) the buffered jump fires %d ticks after landed (within 2)" % gap)
	check.call(data.speed_after >= 0.98 * data.speed_before, "(d) the buffered jump keeps the horizontal speed (%.2f after, %.2f before)" % [data.speed_after, data.speed_before])
	check.call(data.speed_before > data.config.run_speed - 0.5, "(d) the player was running in the air (%.2f m/s)" % data.speed_before)


# (e) a near-landing tap released before landing gives the tap height (Pitfall 9).
func _scenario_buffer_released(tree: SceneTree, check: Callable) -> void:
	var data: Dictionary = await _buffer_case(tree, false)
	var config: MovementConfig = data.config
	check.call(absf(data.apex - config.jump_min_height) < 0.15, "(e) a buffered tap gives apex %.3f m, within 0.15 of jump_min_height %.2f" % [data.apex, config.jump_min_height])


## Starts a held jump, waits for its apex and releases the button there.
func _jump_to_apex(tree: SceneTree, player: PlayerController) -> void:
	_press_jump()
	await Fixtures.wait_until(tree, func() -> bool: return not player.is_grounded() and player.vertical_speed <= 0.0, 180)
	_release_jump()
	await Fixtures.wait_physics(tree, 1)


## Rise above `start_y` until the next landed fact (or `limit` frames).
func _rise_above(tree: SceneTree, player: PlayerController, start_y: float, limit: int = 240) -> float:
	var max_y: float = start_y
	var frames: int = 0
	while frames < limit:
		await tree.physics_frame
		frames += 1
		max_y = maxf(max_y, player.global_position.y)
		if not _landed.is_empty():
			break
	return max_y - start_y


# (f) a held press at the apex of the first jump rises about double_jump_height (MOVE-05, A19).
func _scenario_double_jump_held(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, Vector3.ZERO)
	var player: PlayerController = nodes[1] as PlayerController
	var config: MovementConfig = player.config
	_reset()
	await _jump_to_apex(tree, player)
	_press_jump()
	await Fixtures.wait_until(tree, func() -> bool: return _double.size() >= 1, 6)
	check.call(_double.size() == 1, "(f) a held press at the apex emits exactly one double_jumped (got %d)" % _double.size())
	var start_y: float = _double_y[0] if not _double_y.is_empty() else 0.0
	var rise: float = await _rise_above(tree, player, start_y)
	check.call(absf(rise - config.double_jump_height) < 0.15, "(f) the held double jump rises %.3f m, within 0.15 of double_jump_height %.2f" % [rise, config.double_jump_height])
	_release_jump()
	await _free_all(tree, nodes)


# (g) the release cut applies to the double jump: a one-tick tap rises about jump_min_height (D-04).
func _scenario_double_jump_tapped(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, Vector3.ZERO)
	var player: PlayerController = nodes[1] as PlayerController
	var config: MovementConfig = player.config
	_reset()
	await _jump_to_apex(tree, player)
	_tap_jump()
	await Fixtures.wait_until(tree, func() -> bool: return _double.size() >= 1, 6)
	check.call(_double.size() == 1, "(g) a tap at the apex emits exactly one double_jumped (got %d)" % _double.size())
	var start_y: float = _double_y[0] if not _double_y.is_empty() else 0.0
	var rise: float = await _rise_above(tree, player, start_y)
	check.call(absf(rise - config.jump_min_height) < 0.15, "(g) the tapped double jump rises %.3f m, within 0.15 of jump_min_height %.2f" % [rise, config.jump_min_height])
	await _free_all(tree, nodes)


# (h) exactly one double jump per airtime, refilled on landing (D-07).
func _scenario_one_per_airtime(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, Vector3.ZERO)
	var player: PlayerController = nodes[1] as PlayerController
	_reset()
	await _jump_to_apex(tree, player)
	_tap_jump()
	await Fixtures.wait_physics(tree, 6)
	check.call(_double.size() == 1, "(h) the first air press emits double_jumped (got %d)" % _double.size())
	_tap_jump()
	await Fixtures.wait_physics(tree, 20)
	check.call(_double.size() == 1, "(h) a second air press in the same airtime emits nothing (got %d)" % _double.size())
	await Fixtures.wait_until(tree, func() -> bool: return not _landed.is_empty(), 240)
	await Fixtures.wait_physics(tree, 8)
	_tap_jump()
	await Fixtures.wait_physics(tree, 8)
	_tap_jump()
	await Fixtures.wait_physics(tree, 4)
	check.call(_jumped.size() == 2 and _double.size() == 2, "(h) after landing a ground jump and an air press emit jumped and double_jumped again (jumped=%d double=%d)" % [_jumped.size(), _double.size()])
	await _free_all(tree, nodes)


# (i) walking off a ledge and pressing past coyote time uses the double jump (A6).
func _scenario_ledge_double_jump(tree: SceneTree, check: Callable) -> void:
	var config: MovementConfig = (load("res://resources/player/movement_default.tres") as MovementConfig)
	var outside: int = int(ceil(config.coyote_time * float(Engine.physics_ticks_per_second))) + 3
	var result: Dictionary = await _coyote_case(tree, outside)
	check.call(result.double == 1 and result.jumped == 0, "(i) a press %d ticks after walking off a ledge is the double jump (double_jumped=%d jumped=%d)" % [outside, result.double, result.jumped])


# (j) a press about to land is a buffered ground jump, not the double jump (A7).
func _scenario_near_landing_is_not_double(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, Vector3.ZERO)
	var player: PlayerController = nodes[1] as PlayerController
	var config: MovementConfig = player.config
	_reset()
	_tap_jump()
	await Fixtures.wait_until(tree, func() -> bool: return player.vertical_speed < 0.0 and player.will_land_within(config.jump_buffer_time * 0.5), 120)
	_tap_jump()
	await Fixtures.wait_until(tree, func() -> bool: return _jumped.size() >= 2, 40)
	await Fixtures.wait_physics(tree, 2)
	check.call(_double.is_empty(), "(j) a press about to land emits no double_jumped (got %d)" % _double.size())
	check.call(_jumped.size() == 2 and not _landed.is_empty() and _jumped[1] >= _landed[0], "(j) the press fires a ground jump on landing (jumped=%d)" % _jumped.size())
	await _free_all(tree, nodes)


# (k) with the double jump spent, a press far above the floor expires (rule 4).
func _scenario_spent_press_expires(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, Vector3.ZERO)
	var player: PlayerController = nodes[1] as PlayerController
	var config: MovementConfig = player.config
	_reset()
	await _jump_to_apex(tree, player)
	_press_jump()
	await Fixtures.wait_until(tree, func() -> bool: return _double.size() >= 1, 6)
	await Fixtures.wait_until(tree, func() -> bool: return player.vertical_speed <= 0.0, 120)
	_release_jump()
	await Fixtures.wait_until(tree, func() -> bool: return player.vertical_speed < 0.0 and not player.will_land_within(config.jump_buffer_time * 3.0), 240)
	var far_above: bool = not player.is_grounded() and not player.will_land_within(config.jump_buffer_time * 3.0)
	_tap_jump()
	await Fixtures.wait_until(tree, func() -> bool: return not _landed.is_empty(), 240)
	await Fixtures.wait_physics(tree, 10)
	check.call(far_above and _double.size() == 1, "(k) the double jump was spent before the late press (double_jumped=%d)" % _double.size())
	check.call(_jumped.size() == 1, "(k) the expired press causes no jump after landing (jumped=%d)" % _jumped.size())
	await _free_all(tree, nodes)
