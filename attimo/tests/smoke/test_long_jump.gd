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
func _fly(tree: SceneTree, player: PlayerController, hold: bool = true) -> Dictionary:
	var landed_before: int = _landed.size()
	var start_y: float = player.global_position.y
	var max_y: float = start_y
	var released: bool = false
	var frames: int = 0
	while _landed.size() == landed_before and frames < LIMIT_TICKS:
		await tree.physics_frame
		frames += 1
		max_y = maxf(max_y, player.global_position.y)
		if hold and not released and frames > 2 and player.vertical_speed <= 0.0:
			Fixtures.send_action_event(&"jump", false)
			released = true
	if not released:
		Fixtures.send_action_event(&"jump", false)
	var land_position: Vector3 = _landed[_landed.size() - 1] if _landed.size() > landed_before else player.global_position
	return {"apex": max_y - start_y, "land": land_position, "landed": _landed.size() > landed_before}


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
