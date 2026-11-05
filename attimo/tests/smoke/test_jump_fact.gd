extends RefCounted
## Input action jump -> FSM Idle -> Jump -> Fall -> Idle on real physics: EventBus.jumped is emitted exactly once,
## a held jump peaks at config.jump_height and one landed with a real impact speed follows.

const Fixtures := preload("res://tests/fixtures.gd")
const APEX_TOLERANCE: float = 0.1
const FLOOR_TOLERANCE: float = 0.05


func run(tree: SceneTree, check: Callable) -> void:
	var bus: Node = tree.root.get_node("EventBus")
	var jumped_positions: Array[Vector3] = []
	var landed: Array[float] = []
	var transitions: Array[Array] = []
	var on_jumped: Callable = func(position: Vector3) -> void: jumped_positions.append(position)
	var on_landed: Callable = func(_position: Vector3, impact_speed: float) -> void: landed.append(impact_speed)
	var on_transition: Callable = func(from_state: StringName, to_state: StringName) -> void: transitions.append([from_state, to_state])
	bus.connect(&"jumped", on_jumped)
	bus.connect(&"landed", on_landed)
	bus.connect(&"movement_state_changed", on_transition)

	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)

	await Fixtures.wait_physics(tree, 10)
	check.call(player.state_machine.current.name == &"Idle", "starts in Idle")
	check.call(jumped_positions.size() == 0, "no jumped fact before input")
	check.call(landed.size() == 0, "no landed fact before input")
	check.call(transitions.size() >= 1 and transitions[0][0] == &"" and transitions[0][1] == &"Idle", "setup emitted movement_state_changed '' -> Idle")

	# Hold jump until the apex, recording the highest point.
	Input.action_press(&"jump")
	await Fixtures.wait_physics(tree, 2)
	check.call(jumped_positions.size() == 1, "exactly one jumped fact after pressing jump (got %d)" % jumped_positions.size())
	var saw_idle_to_jump: bool = false
	for t: Array in transitions:
		if t[0] == &"Idle" and t[1] == &"Jump":
			saw_idle_to_jump = true
	check.call(saw_idle_to_jump, "movement_state_changed Idle -> Jump recorded")

	var max_y: float = 0.0
	var ticks: int = 0
	while landed.is_empty() and ticks < 120:
		await Fixtures.wait_physics(tree, 1)
		max_y = maxf(max_y, player.global_position.y)
		ticks += 1
	Input.action_release(&"jump")
	var expected: float = player.config.jump_height
	check.call(absf(max_y - expected) < APEX_TOLERANCE, "held jump apex %.3f m is within %.1f of jump_height %.2f" % [max_y, APEX_TOLERANCE, expected])

	var settled: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Idle", 120)
	check.call(settled >= 0, "back in Idle after the real fall (current %s)" % player.state_machine.current.name)
	check.call(landed.size() == 1, "exactly one landed fact (got %d)" % landed.size())
	check.call(landed.size() == 1 and landed[0] > 0.0, "landed carries a real impact speed above 0 (%.2f m/s)" % (landed[0] if landed.size() > 0 else -1.0))
	check.call(absf(player.global_position.y) < FLOOR_TOLERANCE, "the player stands on the floor top (y=%.3f)" % player.global_position.y)
	check.call(jumped_positions.size() == 1, "jumped fact still exactly one")

	bus.disconnect(&"jumped", on_jumped)
	bus.disconnect(&"landed", on_landed)
	bus.disconnect(&"movement_state_changed", on_transition)
	player.queue_free()
	floor_body.queue_free()
	await tree.process_frame
