extends RefCounted
## D-16 / D-20: the Dampfduese modes. JUMP launches once per entry, UPDRAFT and WALL push every tick. The volume is
## an Area3D on no layer that masks the player.

const Fixtures := preload("res://tests/fixtures.gd")

const NOZZLE_SCENE: String = "res://scenes/mechanisms/steam_nozzle.tscn"
const SHIPPED_TPS: int = 60

var _facts: Array[Vector3] = []


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	EventBus.launched.connect(_on_launched)
	await _scenario_jump(tree, check)
	await _scenario_updraft(tree, check)
	await _scenario_wall(tree, check)
	EventBus.launched.disconnect(_on_launched)


func _on_launched(_position: Vector3, direction: Vector3, _speed: float) -> void:
	_facts.append(direction)


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _nozzle(tree: SceneTree, check: Callable, mode: SteamNozzle.Mode, source: SignalSource) -> SteamNozzle:
	if not ResourceLoader.exists(NOZZLE_SCENE):
		check.call(false, "scene %s exists" % NOZZLE_SCENE)
		return null
	var nozzle: SteamNozzle = (load(NOZZLE_SCENE) as PackedScene).instantiate() as SteamNozzle
	nozzle.mode = mode
	nozzle.source = source
	return nozzle


# JUMP: one launched fact per entry however long the player stays inside (Pitfall 6). A tiny launch keeps the player in.
func _scenario_jump(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	source.set_active(true)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var nozzle: SteamNozzle = _nozzle(tree, check, SteamNozzle.Mode.JUMP, source)
	if nozzle == null:
		await _free(tree, [source, floor_body])
		return
	nozzle.launch_speed = 1.0
	tree.root.add_child(nozzle)
	var volume: Area3D = nozzle.get_node("Volume") as Area3D
	check.call(volume.collision_layer == 0 and volume.collision_mask == PhysicsLayers.PLAYER, "the volume is an Area3D on no layer that masks the Player")
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	_facts.clear()
	await Fixtures.wait_physics(tree, SHIPPED_TPS)
	check.call(_facts.size() == 1, "JUMP launches once per entry, not every tick (%d launches in 1 s)" % _facts.size())
	await _free(tree, [nozzle, player, floor_body, source])


# UPDRAFT: the vertical speed approaches updraft_speed while inside.
func _scenario_updraft(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	source.set_active(true)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var nozzle: SteamNozzle = _nozzle(tree, check, SteamNozzle.Mode.UPDRAFT, source)
	if nozzle == null:
		await _free(tree, [source, floor_body])
		return
	tree.root.add_child(nozzle)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	var peak: float = 0.0
	for i: int in 40:
		await Fixtures.wait_physics(tree, 1)
		peak = maxf(peak, player.vertical_speed)
	check.call(peak > 0.8 * nozzle.updraft_speed, "UPDRAFT lifts toward %.1f m/s (peak %.2f)" % [nozzle.updraft_speed, peak])
	await _free(tree, [nozzle, player, floor_body, source])


# WALL: pushes back along the nozzle direction (+X for a yaw of -90 degrees).
func _scenario_wall(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	source.set_active(true)
	var nozzle: SteamNozzle = _nozzle(tree, check, SteamNozzle.Mode.WALL, source)
	if nozzle == null:
		await _free(tree, [source])
		return
	nozzle.rotation.y = -PI * 0.5
	tree.root.add_child(nozzle)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 1.5, 0.0))
	var start_x: float = player.global_position.x
	await Fixtures.wait_physics(tree, 20)
	check.call(player.global_position.x - start_x > 0.3, "WALL pushes the player along the nozzle direction (%.2f m)" % (player.global_position.x - start_x))
	await _free(tree, [nozzle, player, source])
