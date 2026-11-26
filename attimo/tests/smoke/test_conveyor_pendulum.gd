extends RefCounted
## MECH-03 / D-16 / D-18 / D-21: the Pendel knocks the player away once per rehit window and is a hazard without damage. The belt
## (Foerderband) was replaced by the speed pad (plan 05.1-16, D-25, test_impulse); platform carry stays in test_platforms.

const Fixtures := preload("res://tests/fixtures.gd")

const PENDULUM_SCENE: String = "res://scenes/mechanisms/pendulum.tscn"
const SHIPPED_TPS: int = 60

var _knocks: int = 0


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	EventBus.knocked_back.connect(_on_knocked)
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
