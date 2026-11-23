extends RefCounted
## D-20 / D-21 / D-22: the narrow PlayerController entry points mechanisms use: launch_along, push_toward and knock_back.
## 04.1 (D-06) adds refill_air_dash, boost_along, lock_air_control, launch_along with keep_sideways false and the air cap raise
## after pushes; every one ignores non-finite arguments.
## One-shot impulses are called directly here (the tests run outside the physics flush); mechanisms use call_deferred.

const Fixtures := preload("res://tests/fixtures.gd")

const SHIPPED_TPS: int = 60

var _launched: Array[float] = []
var _knocked: Array[Vector3] = []
var _refills: int = 0
var _boosts: Array[float] = []


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	EventBus.launched.connect(_on_launched)
	EventBus.knocked_back.connect(_on_knocked)
	EventBus.dash_refilled.connect(_on_refilled)
	EventBus.boosted.connect(_on_boosted)
	await _scenario_apex(tree, check)
	await _scenario_air_sideways(tree, check)
	await _scenario_dash_leave(tree, check)
	await _scenario_knock_back(tree, check)
	await _scenario_push(tree, check)
	await _scenario_refill_air_dash(tree, check)
	await _scenario_launch_keep_sideways(tree, check)
	await _scenario_boost_along(tree, check)
	await _scenario_lock_air_control(tree, check)
	await _scenario_air_cap_after_push(tree, check)
	await _scenario_new_api_non_finite(tree, check)
	EventBus.launched.disconnect(_on_launched)
	EventBus.knocked_back.disconnect(_on_knocked)
	EventBus.dash_refilled.disconnect(_on_refilled)
	EventBus.boosted.disconnect(_on_boosted)


func _on_launched(_position: Vector3, _direction: Vector3, speed: float) -> void:
	_launched.append(speed)


func _on_knocked(_position: Vector3, impulse: Vector3) -> void:
	_knocked.append(impulse)


func _on_refilled(_position: Vector3) -> void:
	_refills += 1


func _on_boosted(_position: Vector3, _direction: Vector3, speed: float) -> void:
	_boosts.append(speed)


## A player high in the air (no floor), already in Fall, so airborne rules run undisturbed.
func _airborne_player(tree: SceneTree) -> PlayerController:
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 400.0, 0.0))
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Fall", 30)
	return player


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


# refill_air_dash: a spent air dash is back, the cooldown is gone, the second air dash starts, the fact fires once.
func _scenario_refill_air_dash(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _airborne_player(tree)
	await Fixtures.tap_action(tree, &"dash", 3)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name != &"Dash", 40)
	check.call(not player.air_dash_available, "the first air dash spent the charge")
	_refills = 0
	player.refill_air_dash()
	check.call(player.air_dash_available and player.dash_cooldown_timer == 0.0, "refill_air_dash restores the charge and clears the cooldown")
	check.call(_refills == 1, "refill_air_dash emits dash_refilled once (%d)" % _refills)
	await Fixtures.tap_action(tree, &"dash", 3)
	check.call(player.state_machine.current.name == &"Dash", "a second air dash starts after the refill (%s)" % player.state_machine.current.name)
	await _free(tree, [player])


# launch_along(dir, speed, false) drops the sideways part; without the flag it stays (existing behaviour).
func _scenario_launch_keep_sideways(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _airborne_player(tree)
	player.move_velocity = Vector3(5.0, 0.0, 0.0)
	player.launch_along(Vector3.UP, 12.0, false)
	check.call(player.move_velocity.length() < 0.001 and absf(player.vertical_speed - 12.0) < 0.001, "launch_along(UP, 12, false) drops the sideways speed (%s, %.2f up)" % [str(player.move_velocity), player.vertical_speed])
	player.move_velocity = Vector3(5.0, 0.0, 0.0)
	player.launch_along(Vector3.UP, 12.0)
	check.call(absf(player.move_velocity.x - 5.0) < 0.001, "launch_along(UP, 12) keeps the sideways speed 5 (%.3f)" % player.move_velocity.x)
	await _free(tree, [player])


# boost_along: raises the speed along the direction to a minimum, never slows, optionally adds, ends in Fall and says so.
func _scenario_boost_along(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _airborne_player(tree)
	_boosts.clear()
	player.move_velocity = Vector3(8.0, 0.0, 0.0)
	player.boost_along(Vector3.RIGHT, 20.0)
	check.call(absf(player.move_velocity.x - 20.0) < 0.001, "boost_along(RIGHT, 20) from 8 m/s gives 20 (%.3f)" % player.move_velocity.x)
	check.call(player.state_machine.current.name == &"Fall", "boost_along leaves the player in Fall")
	check.call(_boosts.size() == 1 and absf(_boosts[0] - 20.0) < 0.001, "boost_along emits boosted with the new speed (%s)" % str(_boosts))
	check.call(player.air_speed_cap >= 20.0, "the air cap follows the boost (%.2f)" % player.air_speed_cap)
	player.move_velocity = Vector3(25.0, 0.0, 0.0)
	player.boost_along(Vector3.RIGHT, 20.0)
	check.call(absf(player.move_velocity.x - 25.0) < 0.001, "boost_along never slows: 25 m/s stays 25 (%.3f)" % player.move_velocity.x)
	player.move_velocity = Vector3(8.0, 0.0, 0.0)
	player.boost_along(Vector3.RIGHT, 10.0, 6.0)
	check.call(absf(player.move_velocity.x - 14.0) < 0.001, "boost_along(RIGHT, 10, add 6) from 8 gives 14 (%.3f)" % player.move_velocity.x)
	await _free(tree, [player])


# lock_air_control: after a knock-back against held steering the speed stays; without the lock the steering eats it.
func _scenario_lock_air_control(tree: SceneTree, check: Callable) -> void:
	var speeds: Array[float] = []
	for locked: bool in [true, false]:
		var player: PlayerController = await _airborne_player(tree)
		Input.action_press(&"move_left")
		if locked:
			player.lock_air_control(0.2)
		player.knock_back(Vector3(15.0, 4.0, 0.0))
		await Fixtures.wait_physics(tree, 9)
		speeds.append(player.horizontal_speed())
		Input.action_release(&"move_left")
		await _free(tree, [player])
	check.call(speeds[0] > 14.0, "lock_air_control(0.2): the knock-back speed holds against steering (%.2f m/s after 0.15 s)" % speeds[0])
	check.call(speeds[1] < speeds[0] - 3.0, "without the lock the steering slows it (%.2f vs %.2f)" % [speeds[1], speeds[0]])


# A horizontal push in the air raises the air cap, so air control no longer drags the player back to the old cap.
func _scenario_air_cap_after_push(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _airborne_player(tree)
	Input.action_press(&"move_right")
	var peak: float = 0.0
	for i: int in 30:
		player.push_toward(Vector3.RIGHT, 16.0, 60.0)
		await Fixtures.wait_physics(tree, 1)
		peak = maxf(peak, player.horizontal_speed())
	await Fixtures.wait_physics(tree, 18)
	var after: float = player.horizontal_speed()
	Input.action_release(&"move_right")
	check.call(peak > 15.0 and peak < 16.5, "a horizontal push reaches about 16 m/s (peak %.2f)" % peak)
	check.call(after > 14.0, "and holds above 14 m/s 0.3 s after the pushes stop (%.2f)" % after)
	await _free(tree, [player])


# Every new API ignores NAN and INF: nothing changes and no fact is emitted.
func _scenario_new_api_non_finite(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _airborne_player(tree)
	player.move_velocity = Vector3(3.0, 0.0, 0.0)
	player.vertical_speed = -2.0
	var refills: int = _refills
	var boosts: int = _boosts.size()
	var launches: int = _launched.size()
	player.boost_along(Vector3(NAN, 0.0, 0.0), 10.0)
	player.boost_along(Vector3.RIGHT, INF)
	player.boost_along(Vector3.RIGHT, 10.0, NAN)
	player.boost_along(Vector3.ZERO, 10.0)
	player.lock_air_control(NAN)
	player.lock_air_control(INF)
	player.lock_air_control(-1.0)
	player.launch_along(Vector3(NAN, 0.0, 0.0), 5.0, false)
	player.launch_along(Vector3.UP, INF, false)
	check.call(player.move_velocity == Vector3(3.0, 0.0, 0.0) and player.vertical_speed == -2.0, "non-finite boost_along and launch_along arguments change nothing")
	check.call(player.air_control_lock_timer == 0.0, "non-finite or negative lock_air_control arguments change nothing")
	check.call(_boosts.size() == boosts and _launched.size() == launches and _refills == refills, "and emit no fact")
	await _free(tree, [player])
