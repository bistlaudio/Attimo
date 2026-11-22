extends RefCounted
## D-20 / D-21 / D-22: the narrow PlayerController entry points mechanisms use: launch_along, push_toward and knock_back.
## One-shot impulses are called directly here (the tests run outside the physics flush); mechanisms use call_deferred.

const Fixtures := preload("res://tests/fixtures.gd")

const SHIPPED_TPS: int = 60

var _launched: Array[float] = []
var _knocked: Array[Vector3] = []


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	EventBus.launched.connect(_on_launched)
	EventBus.knocked_back.connect(_on_knocked)
	await _scenario_apex(tree, check)
	await _scenario_air_sideways(tree, check)
	await _scenario_dash_leave(tree, check)
	await _scenario_knock_back(tree, check)
	await _scenario_push(tree, check)
	EventBus.launched.disconnect(_on_launched)
	EventBus.knocked_back.disconnect(_on_knocked)


func _on_launched(_position: Vector3, _direction: Vector3, speed: float) -> void:
	_launched.append(speed)


func _on_knocked(_position: Vector3, impulse: Vector3) -> void:
	_knocked.append(impulse)


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


# launch_along(UP, 12) from the ground reaches the same apex three times in a row (D-20).
func _scenario_apex(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 10)
	var apexes: Array[float] = []
	for trial: int in 3:
		var start_y: float = player.global_position.y
		player.launch_along(Vector3.UP, 12.0)
		var apex: float = start_y
		for i: int in 120:
			await Fixtures.wait_physics(tree, 1)
			apex = maxf(apex, player.global_position.y)
			if i > 5 and player.is_grounded():
				break
		apexes.append(apex - start_y)
		await Fixtures.wait_physics(tree, 10)
	check.call(apexes[0] > 1.5, "launch_along(UP, 12) rises %.2f m" % apexes[0])
	check.call(absf(apexes[1] - apexes[0]) < 0.05 and absf(apexes[2] - apexes[0]) < 0.05, "the apex repeats within 0.05 m (%.3f, %.3f, %.3f)" % [apexes[0], apexes[1], apexes[2]])
	await _free(tree, [floor_body, player])


# From the air the sideways momentum stays; the air dash charge and the launched fact behave.
func _scenario_air_sideways(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 30.0, 0.0))
	await Fixtures.wait_physics(tree, 4)
	player.move_velocity = Vector3(5.0, 0.0, 0.0)
	var charge_before: bool = player.air_dash_available
	var facts_before: int = _launched.size()
	player.launch_along(Vector3.UP, 8.0)
	check.call(absf(player.move_velocity.x - 5.0) < 0.001, "the sideways speed stays 5 after a launch (%.3f)" % player.move_velocity.x)
	check.call(absf(player.vertical_speed - 8.0) < 0.001, "the speed along the launch direction is exactly 8 (%.3f)" % player.vertical_speed)
	check.call(player.air_dash_available == charge_before, "the air dash charge is untouched by a launch")
	check.call(_launched.size() == facts_before + 1, "a launch emits the launched fact once")
	var speed_before: float = player.vertical_speed
	player.launch_along(Vector3(NAN, 0.0, 0.0), 5.0)
	player.launch_along(Vector3.UP, INF)
	player.launch_along(Vector3.ZERO, 5.0)
	check.call(player.vertical_speed == speed_before and _launched.size() == facts_before + 1, "a non-finite or zero launch is ignored")
	await _free(tree, [player])


# A launch or a knock-back during a Dash leaves the Dash for Fall on the same tick (Pitfall 4).
func _scenario_dash_leave(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 10)
	Input.action_press(&"dash")
	var dashing: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 10)
	Input.action_release(&"dash")
	check.call(dashing >= 0, "the dash press starts the Dash")
	player.launch_along(Vector3.UP, 10.0)
	check.call(player.state_machine.current.name == &"Fall", "a launch during a Dash leaves it for Fall (%s)" % player.state_machine.current.name)
	check.call(player.gravity_scale == 1.0, "the Dash exit restored the gravity scale")
	await Fixtures.wait_physics(tree, 90)
	Input.action_press(&"dash")
	dashing = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 30)
	Input.action_release(&"dash")
	player.knock_back(Vector3(4.0, 2.0, 0.0))
	check.call(dashing >= 0 and player.state_machine.current.name == &"Fall", "a knock-back during a Dash leaves it for Fall")
	await _free(tree, [floor_body, player])


# knock_back(8, 4, 0) on the ground moves the player at least 2 m within 0.5 s and enters Fall.
func _scenario_knock_back(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 10)
	var start_x: float = player.global_position.x
	var facts_before: int = _knocked.size()
	player.knock_back(Vector3(8.0, 4.0, 0.0))
	check.call(player.state_machine.current.name == &"Fall", "a knock-back enters Fall")
	check.call(_knocked.size() == facts_before + 1 and _knocked[_knocked.size() - 1] == Vector3(8.0, 4.0, 0.0), "a knock-back emits the knocked_back fact with the impulse")
	await Fixtures.wait_physics(tree, 30)
	check.call(player.global_position.x - start_x >= 2.0, "the knock-back moved the player %.2f m in 0.5 s (>= 2)" % (player.global_position.x - start_x))
	var facts: int = _knocked.size()
	player.knock_back(Vector3(NAN, 0.0, 0.0))
	check.call(_knocked.size() == facts, "a non-finite knock-back is ignored")
	await _free(tree, [floor_body, player])


# push_toward(UP, 6, 60) every tick lifts to about 6 m/s and holds it; the call itself changes nothing.
func _scenario_push(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 10)
	player.push_toward(Vector3.UP, 6.0, 60.0)
	check.call(player.vertical_speed == 0.0, "push_toward only records a request, the velocity is untouched on the call")
	await Fixtures.wait_physics(tree, 2)
	var peak: float = 0.0
	var ticks_near: int = 0
	for i: int in 60:
		player.push_toward(Vector3.UP, 6.0, 60.0)
		await Fixtures.wait_physics(tree, 1)
		peak = maxf(peak, player.vertical_speed)
		if i >= 20 and player.vertical_speed > 5.0:
			ticks_near += 1
	check.call(peak > 5.0 and peak < 6.5, "the push raises vertical_speed to about 6 (peak %.2f)" % peak)
	check.call(ticks_near >= 35, "and holds it (%d of 40 ticks above 5)" % ticks_near)
	check.call(player.state_machine.current.name == &"Fall", "a push that lifts the player off the floor ends in Fall")
	await _free(tree, [floor_body, player])
