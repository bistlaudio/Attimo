extends RefCounted
## MECH-03 / D-16 / D-18 / D-21: Foerderband eases through its speed changes and never launches the rider; the Pendel
## knocks the player away once per rehit window and is a hazard without damage.

const Fixtures := preload("res://tests/fixtures.gd")

const CONVEYOR_SCENE: String = "res://scenes/mechanisms/conveyor.tscn"
const PENDULUM_SCENE: String = "res://scenes/mechanisms/pendulum.tscn"
const SHIPPED_TPS: int = 60

var _knocks: int = 0


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	EventBus.knocked_back.connect(_on_knocked)
	await _scenario_conveyor_run(tree, check)
	await _scenario_conveyor_reverse(tree, check)
	await _scenario_conveyor_on_floor(tree, check)
	await _scenario_pendulum(tree, check)
	await _scenario_pendulum_stop(tree, check)
	EventBus.knocked_back.disconnect(_on_knocked)


func _on_knocked(_position: Vector3, _impulse: Vector3) -> void:
	_knocks += 1


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _spawn(path: String, check: Callable) -> Node3D:
	if not ResourceLoader.exists(path):
		check.call(false, "scene %s exists" % path)
		return null
	return (load(path) as PackedScene).instantiate() as Node3D


# RUN_WHILE_ON: off is still, on reaches the speed along the direction; toggling never launches the rider.
func _scenario_conveyor_run(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	var conveyor: Conveyor = _spawn(CONVEYOR_SCENE, check) as Conveyor
	if conveyor == null:
		await _free(tree, [source])
		return
	conveyor.source = source
	tree.root.add_child(conveyor)
	var belt: StaticBody3D = conveyor.get_node("Belt") as StaticBody3D
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 20)
	check.call(belt.constant_linear_velocity.length() < 0.001, "RUN_WHILE_ON: off gives constant_linear_velocity zero")
	check.call(belt.collision_layer == PhysicsLayers.WORLD, "the belt is on WORLD")
	var limit: float = conveyor.speed + player.config.run_speed
	var worst: float = 0.0
	var previous: Vector3 = player.global_position
	var dt: float = 1.0 / float(SHIPPED_TPS)
	for toggle: int in 4:
		source.set_active(toggle % 2 == 0)
		for i: int in 30:
			await Fixtures.wait_physics(tree, 1)
			worst = maxf(worst, (player.global_position - previous).length() / dt)
			previous = player.global_position
			if toggle == 0 and i == 29:
				var along: float = belt.constant_linear_velocity.dot((belt.global_basis * conveyor.direction).normalized())
				check.call(absf(along - conveyor.speed) < 0.05, "RUN_WHILE_ON: on reaches %.1f m/s along its direction (%.3f)" % [conveyor.speed, along])
	check.call(worst < limit, "toggling on and off never gives the rider more than %.1f m/s (worst %.2f)" % [limit, worst])
	await _free(tree, [conveyor, player, source])


# REVERSE_ON_SIGNAL: the belt always runs and the signal reverses it through a ramp.
func _scenario_conveyor_reverse(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	var conveyor: Conveyor = _spawn(CONVEYOR_SCENE, check) as Conveyor
	if conveyor == null:
		await _free(tree, [source])
		return
	conveyor.behaviour = Mechanism.Behaviour.REVERSE_ON_SIGNAL
	conveyor.source = source
	tree.root.add_child(conveyor)
	var belt: StaticBody3D = conveyor.get_node("Belt") as StaticBody3D
	var axis: Vector3 = (belt.global_basis * conveyor.direction).normalized()
	await Fixtures.wait_physics(tree, 30)
	var before: float = belt.constant_linear_velocity.dot(axis)
	source.set_active(true)
	var worst_step: float = 0.0
	var previous: float = before
	for i: int in 30:
		await Fixtures.wait_physics(tree, 1)
		var now: float = belt.constant_linear_velocity.dot(axis)
		worst_step = maxf(worst_step, absf(now - previous))
		previous = now
	check.call(before > 2.9 and previous < -2.9, "REVERSE_ON_SIGNAL runs and reverses (%.2f -> %.2f)" % [before, previous])
	check.call(worst_step < conveyor.speed * 0.5, "the reversal is eased (largest step %.3f m/s per tick)" % worst_step)
	await _free(tree, [conveyor, source])


# D-05 / MOVE-08: a belt whose node sits on a floor tile at the same height carries an idle rider at belt speed and the rider keeps
# the belt momentum when jumping off. At HEAD the belt top was coplanar with the floor top, the engine took the floor tile as the
# supporting body and get_platform_velocity() stayed zero (RESEARCH, conveyor probe).
func _scenario_conveyor_on_floor(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	source.set_active(true)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var conveyor: Conveyor = _spawn(CONVEYOR_SCENE, check) as Conveyor
	if conveyor == null:
		await _free(tree, [source, floor_body])
		return
	conveyor.source = source
	tree.root.add_child(conveyor)
	var belt: StaticBody3D = conveyor.get_node("Belt") as StaticBody3D
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.1, 6.0))
	await Fixtures.wait_physics(tree, 30)
	var axis: Vector3 = (belt.global_basis * conveyor.direction).normalized()
	var start: Vector3 = player.global_position
	await Fixtures.wait_physics(tree, 60)
	var carried: float = (player.global_position - start).dot(axis)
	check.call(carried >= conveyor.speed * 0.8, "an idle rider on the belt is carried %.2f m in 1 s (belt %.1f m/s, at least %.2f)" % [carried, conveyor.speed, conveyor.speed * 0.8])
	var platform_velocity: Vector3 = player.get_platform_velocity()
	check.call(platform_velocity.distance_to(belt.constant_linear_velocity) < 0.2, "get_platform_velocity() is the belt velocity (%s vs %s)" % [str(platform_velocity), str(belt.constant_linear_velocity)])
	Input.action_press(&"jump")
	var airborne_along: float = 0.0
	for i: int in 20:
		await Fixtures.wait_physics(tree, 1)
		if not player.is_grounded():
			airborne_along = player.move_velocity.dot(axis)
			break
	Input.action_release(&"jump")
	check.call(airborne_along >= conveyor.speed * 0.8, "jumping off keeps the belt momentum on the first airborne tick (%.2f m/s along the belt, belt %.1f)" % [airborne_along, conveyor.speed])
	await _free(tree, [conveyor, player, floor_body, source])


# The pendulum knocks a player in its path once, then waits rehit_cooldown.
func _scenario_pendulum(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	source.set_active(true)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var pendulum: Pendulum = _spawn(PENDULUM_SCENE, check) as Pendulum
	if pendulum == null:
		await _free(tree, [source, floor_body])
		return
	pendulum.source = source
	tree.root.add_child(pendulum)
	var arm: AnimatableBody3D = pendulum.get_node("Arm") as AnimatableBody3D
	var hit: Area3D = pendulum.get_node("Arm/Hit") as Area3D
	check.call(arm.collision_layer == PhysicsLayers.WORLD, "the pendulum arm is on WORLD")
	check.call(hit.collision_layer == PhysicsLayers.HAZARD and hit.collision_mask == PhysicsLayers.PLAYER, "the hit area is on HAZARD and masks the Player")
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(2.5, 0.0, 0.0))
	_knocks = 0
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return _knocks >= 1, 2 * SHIPPED_TPS)
	check.call(waited >= 0, "the pendulum knocks the player within 2 s (%d ticks)" % waited)
	var window: int = int(pendulum.rehit_cooldown * float(SHIPPED_TPS)) - 6
	await Fixtures.wait_physics(tree, window)
	check.call(_knocks == 1, "no second knock inside the rehit cooldown (%d knocks)" % _knocks)
	await _free(tree, [pendulum, player, floor_body, source])


# RUN_WHILE_ON: the signal off lets the swing finish at the bottom and stop there.
func _scenario_pendulum_stop(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	var pendulum: Pendulum = _spawn(PENDULUM_SCENE, check) as Pendulum
	if pendulum == null:
		await _free(tree, [source])
		return
	pendulum.source = source
	tree.root.add_child(pendulum)
	source.set_active(true)
	await Fixtures.wait_physics(tree, 100)
	var swinging: bool = absf(pendulum.current_angle()) > 0.05
	source.set_active(false)
	await Fixtures.wait_physics(tree, 4 * SHIPPED_TPS)
	var angle_a: float = pendulum.current_angle()
	await Fixtures.wait_physics(tree, 30)
	check.call(swinging, "the pendulum swings while the signal is on")
	check.call(absf(angle_a) < 0.03 and absf(pendulum.current_angle() - angle_a) < 0.001, "signal off: the pendulum stops at the bottom (angle %.3f)" % angle_a)
	await _free(tree, [pendulum, source])
