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


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	_bus.connect(&"jumped", _on_jumped)
	_bus.connect(&"landed", _on_landed)

	await _scenario_hold_and_tap(tree, check)
	await _scenario_tick_rate(tree, check)
	await _scenario_coyote(tree, check)
	await _scenario_buffer_keeps_speed(tree, check)
	await _scenario_buffer_released(tree, check)

	_bus.disconnect(&"jumped", _on_jumped)
	_bus.disconnect(&"landed", _on_landed)


func _on_jumped(_position: Vector3) -> void:
	_jumped.append(Engine.get_physics_frames())


func _on_landed(_position: Vector3, _impact_speed: float) -> void:
	_landed.append(Engine.get_physics_frames())


func _reset() -> void:
	_jumped.clear()
	_landed.clear()


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
## Returns the jumped count caused by that tap.
func _coyote_case(tree: SceneTree, offset: int) -> int:
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
	var count: int = _jumped.size() if airborne else -1
	Input.action_release(&"move_forward")
	await _free_all(tree, [ledge, player])
	return count


# (c) coyote edge: coyote_time - 2 ticks is a ground jump, coyote_time + 3 ticks is not (D-09).
func _scenario_coyote(tree: SceneTree, check: Callable) -> void:
	var config: MovementConfig = (load("res://resources/player/movement_default.tres") as MovementConfig)
	var tps: float = float(Engine.physics_ticks_per_second)
	var inside: int = int(floor(config.coyote_time * tps)) - 2
	var outside: int = int(ceil(config.coyote_time * tps)) + 3
	var inside_jumps: int = await _coyote_case(tree, inside)
	var outside_jumps: int = await _coyote_case(tree, outside)
	check.call(inside_jumps == 1, "(c) a jump %d ticks after walking off a ledge is a ground jump (jumped=%d)" % [inside, inside_jumps])
	check.call(outside_jumps == 0, "(c) a jump %d ticks after walking off a ledge is not a ground jump (jumped=%d)" % [outside, outside_jumps])


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
