extends RefCounted
## Tracer: Input action jump -> FSM Idle -> Jump -> Idle, EventBus.jumped emitted exactly once, body never moves (D-09).

const Fixtures := preload("res://tests/fixtures.gd")


func run(tree: SceneTree, check: Callable) -> void:
	var bus: Node = tree.root.get_node("EventBus")
	var jumped_positions: Array[Vector3] = []
	var transitions: Array[Array] = []
	bus.connect(&"jumped", func(position: Vector3) -> void: jumped_positions.append(position))
	bus.connect(&"movement_state_changed", func(from_state: StringName, to_state: StringName) -> void: transitions.append([from_state, to_state]))

	var spawn: Vector3 = Vector3.ZERO
	var player: PlayerController = Fixtures.spawn_player(tree.root, spawn)

	await Fixtures.wait_physics(tree, 10)
	check.call(player.state_machine.current.name == &"Idle", "starts in Idle")
	check.call(jumped_positions.size() == 0, "no jumped fact before input")
	check.call(transitions.size() >= 1 and transitions[0][0] == &"" and transitions[0][1] == &"Idle", "setup emitted movement_state_changed '' -> Idle")

	await Fixtures.tap_action(tree, &"jump")

	check.call(jumped_positions.size() == 1, "exactly one jumped fact after pressing jump (got %d)" % jumped_positions.size())
	var saw_idle_to_jump: bool = false
	for t: Array in transitions:
		if t[0] == &"Idle" and t[1] == &"Jump":
			saw_idle_to_jump = true
	check.call(saw_idle_to_jump, "movement_state_changed Idle -> Jump recorded")
	check.call(player.state_machine.current.name == &"Jump", "current state is Jump")

	await Fixtures.wait_physics(tree, 45)
	check.call(player.state_machine.current.name == &"Idle", "back in Idle after the jump timer")
	check.call(jumped_positions.size() == 1, "jumped fact still exactly one")

	check.call(player.global_position == spawn and player.velocity == Vector3.ZERO, "D-09: position unchanged and velocity zero")

	player.queue_free()
	await tree.process_frame
