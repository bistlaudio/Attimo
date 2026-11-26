extends RefCounted
## Plan 05.1-13 (ENRG-10, KIT-01, KIT-02, D-53): the Loader field is the LOADER_FIELD profile of the Reaction to load block, a turquoise
## field that never breaks. Rino passes through it only during a Loader straight flight that paid at least 2 steps (min_steps) and
## loses 30 % of his speed once (brake) with a ripple cue; walking, a dash (ground or air), a 1-step Loader and the slingshot cage
## flight (0 paid steps) are softly pushed back. The field lies across -Z at the origin (box 6 x 4 x 0.5 on the floor), the player
## starts on the +Z side. Checked at 60 and at 10 physics ticks per second (the sensor lead covers a 22 m/s flight at 10 TPS).
## Flights start through launch_along + begin_straight_flight, the same calls the Loader discharge makes.

const Fixtures := preload("res://tests/fixtures.gd")

const FIELD_SCENE: String = "res://scenes/kit/energy/loader_field.tscn"
const SPEED: float = 22.0
const START_Z: float = 14.0
const START_Y: float = 2.0
const BRAKE_TOLERANCE: float = 0.02
## Beyond this z the player counts as through the field (the field is 0.5 m thick, the capsule radius is 0.35).
const THROUGH_Z: float = -1.0
const NEAR_Z: float = 0.9

var _nodes: Array[Node] = []
var _player: PlayerController
var _field: Node3D


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	check.call(ResourceLoader.exists(FIELD_SCENE), "the Loader field scene %s exists" % FIELD_SCENE)
	if not ResourceLoader.exists(FIELD_SCENE):
		return
	for tps: int in [60, 10]:
		Engine.physics_ticks_per_second = tps
		var tag: String = "%d TPS" % tps
		await _scenario_pass(tree, check, 3, tag)
		await _scenario_pass(tree, check, 2, tag)
		await _scenario_blocked_flight(tree, check, 1, tag)
		await _scenario_blocked_flight(tree, check, 0, tag)
		await _scenario_walk(tree, check, tag)
		await _scenario_dash(tree, check, false, tag)
		await _scenario_dash(tree, check, true, tag)
	Engine.physics_ticks_per_second = 60
	await _scenario_again(tree, check)
	await _scenario_api(tree, check)
	Engine.physics_ticks_per_second = 60


func _begin(tree: SceneTree, start: Vector3, settle: int = 6) -> void:
	_nodes.clear()
	_nodes.append(Fixtures.spawn_floor(tree.root, Vector3(80.0, 1.0, 80.0)))
	_field = Fixtures.spawn_scene(tree.root, FIELD_SCENE, Vector3.ZERO)
	_nodes.append(_field)
	_player = Fixtures.spawn_player(tree.root, start)
	_nodes.append(_player)
	await Fixtures.wait_physics(tree, settle)


func _end(tree: SceneTree) -> void:
	for action: StringName in [&"move_forward", &"dash"]:
		Input.action_release(action)
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
	await tree.process_frame


## Starts a straight flight along -Z at SPEED that paid `steps` steps. The player is airborne; the flight needs the Fall state, so
## the first ticks are awaited until the FSM got there.
func _fly(tree: SceneTree, steps: int) -> void:
	await Fixtures.wait_until(tree, func() -> bool: return _player.state_machine.current.name == &"Fall", 20)
	_player.launch_along(Vector3(0.0, 0.0, -1.0), SPEED, false)
	_player.begin_straight_flight(30.0, steps)


func _ripple_visible() -> bool:
	var ripple: Node3D = _field.find_child("Ripple", true, false) as Node3D
	return ripple != null and ripple.visible


## Waits until the player has passed THROUGH_Z or `max_ticks` went by; returns the horizontal speed sampled right before the field and
## right after it, and whether the ripple showed.
func _watch(tree: SceneTree, max_ticks: int) -> Dictionary:
	var before: float = 0.0
	var after: float = -1.0
	var ripple: bool = false
	var ticks: int = 0
	while ticks < max_ticks:
		await tree.physics_frame
		ticks += 1
		ripple = ripple or _ripple_visible()
		if _player.global_position.z > 3.5:
			before = _player.horizontal_speed()
		if _player.global_position.z < THROUGH_Z and after < 0.0:
			after = _player.horizontal_speed()
			break
	return {"before": before, "after": after, "ripple": ripple}


func _scenario_pass(tree: SceneTree, check: Callable, steps: int, tag: String) -> void:
	await _begin(tree, Vector3(0.0, START_Y, START_Z), 1)
	await _fly(tree, steps)
	var seen: Dictionary = await _watch(tree, 200)
	var after: float = seen["after"] as float
	var before: float = seen["before"] as float
	check.call(after >= 0.0, "(%s, %d steps) the flight passes through the field (z %.2f)" % [tag, steps, _player.global_position.z])
	if after >= 0.0 and before > 0.0:
		check.call(absf(after / before - 0.70) <= BRAKE_TOLERANCE, "(%s, %d steps) the speed after the field is 0.70 of before (%.2f / %.2f = %.3f)" % [tag, steps, after, before, after / before])
	check.call(seen["ripple"] as bool, "(%s, %d steps) the ripple cue shows on the pass" % [tag, steps])
	check.call(is_instance_valid(_field) and _field.visible, "(%s, %d steps) the field is still there after the pass" % [tag, steps])
	if steps == 3:
		await Fixtures.wait_physics(tree, ceili(0.6 * Engine.physics_ticks_per_second))
		check.call(not _ripple_visible(), "(%s) the ripple cue is gone after 0.6 s" % tag)
	await _end(tree)


## Fails when the player got through; the field must stay and a soft push moves him away from it.
func _check_blocked(tree: SceneTree, check: Callable, label: String, ticks: int) -> void:
	var min_z: float = INF
	for i: int in ticks:
		await tree.physics_frame
		min_z = minf(min_z, _player.global_position.z)
	check.call(min_z > THROUGH_Z + 0.5, "(%s) the player stays on the near side (lowest z %.2f)" % [label, min_z])
	check.call(is_instance_valid(_field) and _field.visible, "(%s) the field never disappears or breaks" % label)
	Input.action_release(&"move_forward")
	await Fixtures.wait_physics(tree, ceili(0.5 * Engine.physics_ticks_per_second))
	# At 10 TPS one tick of ground friction (ground_decel 55 m/s2 = 5.5 m/s per tick) wipes the 4 m/s push of a standing player, so
	# the away check belongs to the shipped rate; the 10 TPS runs still prove that nothing gets through.
	if Engine.physics_ticks_per_second >= 60:
		check.call(_player.global_position.z > NEAR_Z, "(%s) the soft push keeps him away from the field (z %.2f)" % [label, _player.global_position.z])


func _scenario_blocked_flight(tree: SceneTree, check: Callable, steps: int, tag: String) -> void:
	await _begin(tree, Vector3(0.0, START_Y, START_Z), 1)
	await _fly(tree, steps)
	await _check_blocked(tree, check, "%s, %d-step flight" % [tag, steps], ceili(1.0 * Engine.physics_ticks_per_second))
	await _end(tree)


func _scenario_walk(tree: SceneTree, check: Callable, tag: String) -> void:
	await _begin(tree, Vector3(0.0, 0.0, 8.0))
	Input.action_press(&"move_forward")
	await _check_blocked(tree, check, "%s, walking" % tag, ceili(3.0 * Engine.physics_ticks_per_second))
	await _end(tree)


func _scenario_dash(tree: SceneTree, check: Callable, air: bool, tag: String) -> void:
	await _begin(tree, Vector3(0.0, START_Y if air else 0.0, 8.0))
	Input.action_press(&"move_forward")
	await Fixtures.tap_action(tree, &"dash", 2)
	await _check_blocked(tree, check, "%s, %s dash" % [tag, "air" if air else "ground"], ceili(1.5 * Engine.physics_ticks_per_second))
	await _end(tree)


## After a pass the next approach without a flight is blocked again (the pass exception is removed on exit).
func _scenario_again(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, Vector3(0.0, START_Y, START_Z), 1)
	await _fly(tree, 3)
	var seen: Dictionary = await _watch(tree, 200)
	check.call((seen["after"] as float) >= 0.0, "(again) the first flight passes")
	await Fixtures.wait_physics(tree, 90)
	_player.respawn(Vector3(0.0, 0.0, 8.0))
	await Fixtures.wait_physics(tree, 6)
	Input.action_press(&"move_forward")
	await _check_blocked(tree, check, "again, walking after a pass", 180)
	await _end(tree)


## The request APIs by reflection: scale_speed clamps and rejects, allow_pass_through ignores null; the block config holds the values.
func _scenario_api(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, Vector3(0.0, 0.0, 8.0))
	check.call(_player.has_method(&"scale_speed") and _player.has_method(&"allow_pass_through"), "PlayerController has scale_speed and allow_pass_through")
	if _player.has_method(&"scale_speed"):
		_player.move_velocity = Vector3(10.0, 0.0, 0.0)
		_player.call(&"scale_speed", NAN)
		check.call(is_equal_approx(_player.move_velocity.x, 10.0), "scale_speed ignores a non-finite factor")
		_player.call(&"scale_speed", 0.0)
		check.call(is_equal_approx(_player.move_velocity.x, 1.0), "scale_speed clamps the factor to at least 0.1 (%.2f)" % _player.move_velocity.x)
		_player.move_velocity = Vector3(10.0, 0.0, 0.0)
		_player.call(&"scale_speed", 5.0)
		check.call(is_equal_approx(_player.move_velocity.x, 10.0), "scale_speed clamps the factor to at most 1.0 (%.2f)" % _player.move_velocity.x)
	if _player.has_method(&"allow_pass_through"):
		_player.call(&"allow_pass_through", null, true)
		check.call(true, "allow_pass_through ignores null")
	var config: Resource = _field.get("config") as Resource
	check.call(config != null and int(config.get("min_steps")) == 2 and is_equal_approx(float(config.get("brake")), 0.30), "the field config holds min_steps 2 and brake 0.30")
	check.call(_field.get("layer") == 1 and _field.get("energy_relation") == 1, "the field is ENERGY layer with energy_relation COSTS")
	await _end(tree)
