extends RefCounted
## D-16 / D-20: the Dampfduese. Plan 05.1-03 cut the launch and push-back modes (D-06, KIT-04); only UPDRAFT is left, which lifts
## every tick until plan 05.1-09 turns it into a force volume. The volume is an Area3D on no layer that masks the player.

const Fixtures := preload("res://tests/fixtures.gd")

const NOZZLE_SCENE: String = "res://scenes/mechanisms/steam_nozzle.tscn"
const SHIPPED_TPS: int = 60


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_updraft(tree, check)


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
	var volume: Area3D = nozzle.get_node("Volume") as Area3D
	check.call(volume.collision_layer == 0 and volume.collision_mask == PhysicsLayers.PLAYER, "the volume is an Area3D on no layer that masks the Player")
	check.call(SteamNozzle.Mode.size() == 1 and nozzle.mode == SteamNozzle.Mode.UPDRAFT, "UPDRAFT is the only nozzle mode and the default (%s)" % [SteamNozzle.Mode.keys()])
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	var peak: float = 0.0
	for i: int in 40:
		await Fixtures.wait_physics(tree, 1)
		peak = maxf(peak, player.vertical_speed)
	check.call(peak > 0.8 * nozzle.updraft_speed, "UPDRAFT lifts toward %.1f m/s (peak %.2f)" % [nozzle.updraft_speed, peak])
	await _free(tree, [nozzle, player, floor_body, source])
