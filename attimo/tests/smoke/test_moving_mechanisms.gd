extends RefCounted
## MECH-03 / D-18 / D-22: Dreh-Plattform reversal and Hub-Plattform travel. Both bodies sit on WORLD and never join the gym
## group moving_platform. Rotation carry itself is test_mechanism_carry.

const Fixtures := preload("res://tests/fixtures.gd")

const ROTATING_SCENE: String = "res://scenes/mechanisms/rotating_platform.tscn"
const LIFT_SCENE: String = "res://scenes/mechanisms/lift_platform.tscn"
const SHIPPED_TPS: int = 60
const DIAGNOSTIC_TPS: int = 10


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_reverse(tree, check)
	await _scenario_lift_travel(tree, check)
	await _scenario_layers(tree, check)
	for tps: int in [SHIPPED_TPS, DIAGNOSTIC_TPS]:
		Engine.physics_ticks_per_second = tps
		await _scenario_lift_rider(tree, check, tps)
	Engine.physics_ticks_per_second = SHIPPED_TPS  # the shipped rate, always restored


func _spawn(tree: SceneTree, path: String, check: Callable) -> Node3D:
	if not ResourceLoader.exists(path):
		check.call(false, "scene %s exists" % path)
		return null
	return (load(path) as PackedScene).instantiate() as Node3D


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


# REVERSE_ON_SIGNAL: always runs, the signal reverses the direction through an eased ramp (D-18, D-22).
func _scenario_reverse(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	var platform: RotatingPlatform = _spawn(tree, ROTATING_SCENE, check) as RotatingPlatform
	platform.behaviour = Mechanism.Behaviour.REVERSE_ON_SIGNAL
	platform.source = source
	tree.root.add_child(platform)
	await Fixtures.wait_physics(tree, 40)
	var before: float = platform.angular_velocity()
	check.call(before > 0.9, "REVERSE_ON_SIGNAL runs without a signal (%.2f rad/s)" % before)
	source.set_active(true)
	var worst_step: float = 0.0
	var previous: float = before
	for i: int in 40:
		await Fixtures.wait_physics(tree, 1)
		worst_step = maxf(worst_step, absf(platform.angular_velocity() - previous))
		previous = platform.angular_velocity()
	check.call(previous < -0.9, "the signal reverses the direction (%.2f rad/s)" % previous)
	check.call(worst_step < 0.2, "the reversal is eased, the largest step is %.3f rad/s per tick" % worst_step)
	await _free(tree, [platform, source])


# The lift reaches B while on and A while off.
func _scenario_lift_travel(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	var lift: LiftPlatform = _spawn(tree, LIFT_SCENE, check) as LiftPlatform
	if lift == null:
		await _free(tree, [source])
		return
	lift.source = source
	tree.root.add_child(lift)
	var body: AnimatableBody3D = lift.get_node("Body") as AnimatableBody3D
	await Fixtures.wait_physics(tree, 5)
	source.set_active(true)
	await Fixtures.wait_physics(tree, 3 * SHIPPED_TPS)
	check.call(absf(body.global_position.y - lift.point_b.y) < 0.05, "the lift reaches point B (y %.3f)" % body.global_position.y)
	source.set_active(false)
	await Fixtures.wait_physics(tree, 3 * SHIPPED_TPS)
	check.call(absf(body.global_position.y - lift.point_a.y) < 0.05, "the lift returns to point A (y %.3f)" % body.global_position.y)
	await _free(tree, [lift, source])


func _scenario_layers(tree: SceneTree, check: Callable) -> void:
	var lift: LiftPlatform = _spawn(tree, LIFT_SCENE, check) as LiftPlatform
	var rotating: RotatingPlatform = _spawn(tree, ROTATING_SCENE, check) as RotatingPlatform
	tree.root.add_child(rotating)
	if lift != null:
		tree.root.add_child(lift)
		var lift_body: AnimatableBody3D = lift.get_node("Body") as AnimatableBody3D
		check.call(lift_body.collision_layer == PhysicsLayers.WORLD and not lift_body.is_in_group(&"moving_platform"), "the lift body is on WORLD and not in group moving_platform")
	var body: AnimatableBody3D = rotating.body()
	check.call(body.collision_layer == PhysicsLayers.WORLD and not body.is_in_group(&"moving_platform"), "the rotating platform body is on WORLD and not in group moving_platform")
	await _free(tree, [lift, rotating])


# A rider on a lift A -> B 4 m up at 2 m/s keeps its feet on the top and is not thrown at the stop.
func _scenario_lift_rider(tree: SceneTree, check: Callable, tps: int) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	var lift: LiftPlatform = _spawn(tree, LIFT_SCENE, check) as LiftPlatform
	if lift == null:
		await _free(tree, [source])
		return
	lift.source = source
	lift.point_b = Vector3(0.0, 4.0, 0.0)
	lift.speed = 2.0
	tree.root.add_child(lift)
	var body: AnimatableBody3D = lift.get_node("Body") as AnimatableBody3D
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, maxi(tps / 3, 4))
	source.set_active(true)
	var worst_gap: float = 0.0
	var peak_after: float = 0.0
	var previous_y: float = player.global_position.y
	var dt: float = 1.0 / float(tps)
	var stopped: bool = false
	for i: int in int(4.0 * float(tps)):
		await Fixtures.wait_physics(tree, 1)
		worst_gap = maxf(worst_gap, absf(player.global_position.y - body.global_position.y))
		var rise: float = (player.global_position.y - previous_y) / dt
		previous_y = player.global_position.y
		if body.global_position.y > lift.point_b.y - 0.01:
			stopped = true
		if stopped:
			peak_after = maxf(peak_after, rise)
	var label: String = "at %d TPS" % tps
	check.call(stopped, "the lift reached the top %s" % label)
	# The engine carries the rider with the velocity of the previous step, so it trails the platform by one tick of travel
	# (speed * dt): that tick is allowed on top of the 0.1 m and 0.5 m/s limits (it is 0.03 m at 60 TPS and 0.2 m at 10 TPS).
	var one_tick: float = lift.speed * dt
	check.call(worst_gap < 0.1 + one_tick, "the rider stays within 0.1 m (+ one tick %.3f) of the lift top %s (worst %.3f)" % [one_tick, label, worst_gap])
	check.call(peak_after < 0.5 + one_tick, "the rider is not thrown upward at the stop %s (peak %.3f m/s, limit %.3f)" % [label, peak_after, 0.5 + one_tick])
	await _free(tree, [player, lift, source])
