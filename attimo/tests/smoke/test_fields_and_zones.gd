extends RefCounted
## MECH-04 K (D-06): the gravity request API (the zone is a Force volume now). MECH-04 A, B: the repulsor and attractor (ForceField); the wind tunnel became the steam stream force volume (plan 05.1-15, test_force_volume).

const Fixtures := preload("res://tests/fixtures.gd")

const FIELD_SCENE: String = "res://scenes/mechanisms/force_field.tscn"
const SHIPPED_TPS: int = 60


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_gravity_requests(tree, check)
	await _scenario_repulsor(tree, check)
	await _scenario_attractor(tree, check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


## The player-side gravity request contract (T-04.1-01): bad and out-of-range requests, cleared after the move. The gravity zone
## itself became the Force volume GRAVITY profile (plan 05.1-16, test_amplification).
func _scenario_gravity_requests(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 20)
	player.request_gravity_scale(NAN)
	player.request_gravity_scale(INF)
	check.call(player._zone_gravity_scale == 1.0, "a non-finite gravity request changes nothing")
	player.request_gravity_scale(0.0)
	check.call(is_equal_approx(player._zone_gravity_scale, 0.05), "a request below 0.05 is clamped to 0.05 (%.3f)" % player._zone_gravity_scale)
	await Fixtures.wait_physics(tree, 2)
	check.call(player._zone_gravity_scale == 1.0, "the request is cleared after the move, no restore step needed")
	player.request_gravity_scale(5.0)
	check.call(player._zone_gravity_scale == 1.0, "a request above 1.0 is clamped to 1.0")
	await _free(tree, [player, floor_body])


func _field(tree: SceneTree, check: Callable, mode: ForceField.Mode, source: SignalSource, at: Vector3) -> ForceField:
	var field: ForceField = (load(FIELD_SCENE) as PackedScene).instantiate() as ForceField
	field.mode = mode
	field.source = source
	field.position = at
	tree.root.add_child(field)
	var volume: Area3D = field.get_node("Volume") as Area3D
	check.call(volume.collision_layer == 0 and volume.collision_mask == PhysicsLayers.PLAYER, "the field volume is an Area3D on no layer that masks the Player")
	return field


# Repulsor: with the source on an airborne player 1.5 m beside the centre is pushed at least 2 m farther away (horizontally)
# within 1 s; with the source off it only falls. (A grounded player is held by ground friction, the same as for the steam wall.)
func _scenario_repulsor(tree: SceneTree, check: Callable) -> void:
	for on: bool in [true, false]:
		var source: SignalSource = SignalSource.new()
		tree.root.add_child(source)
		var field: ForceField = _field(tree, check, ForceField.Mode.REPEL, source, Vector3(0.0, 3.0, 0.0))
		var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(1.5, 2.0, 0.0))
		source.set_active(on)
		await Fixtures.wait_physics(tree, SHIPPED_TPS)
		var flat: float = Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(field.global_position.x, field.global_position.z))
		if on:
			check.call(flat - 1.5 >= 2.0, "repulsor on: the player ends %.2f m farther from the centre axis (at least 2)" % (flat - 1.5))
		else:
			check.call(flat - 1.5 < 0.3, "repulsor off: the player does not move away (%.2f m)" % (flat - 1.5))
		await _free(tree, [field, player, source])


# Attractor: with the source on a player released 4 m away is held at the core without oscillating; off, it falls.
func _scenario_attractor(tree: SceneTree, check: Callable) -> void:
	for on: bool in [true, false]:
		var source: SignalSource = SignalSource.new()
		tree.root.add_child(source)
		source.set_active(on)
		var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
		var field: ForceField = _field(tree, check, ForceField.Mode.ATTRACT, source, Vector3(0.0, 4.0, 0.0))
		var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(4.0, 3.0, 0.0))
		var max_speed_late: float = 0.0
		for i: int in 2 * SHIPPED_TPS:
			await Fixtures.wait_physics(tree, 1)
			if i > SHIPPED_TPS + 20:
				var v: Vector3 = Vector3(player.move_velocity.x, player.vertical_speed, player.move_velocity.z)
				max_speed_late = maxf(max_speed_late, v.length())
		var dist: float = (player.global_position + Vector3.UP).distance_to(field.global_position)
		if on:
			check.call(dist <= field.core_radius + 0.5, "attractor on: after 2 s the player is %.2f m from the centre (within %.2f)" % [dist, field.core_radius + 0.5])
			check.call(max_speed_late < 3.0, "attractor on: the late 3D speed stays below 3 m/s (%.2f), no oscillation" % max_speed_late)
		else:
			check.call(dist > 3.0 and player.global_position.y < 2.0, "attractor off: the player falls normally (%.2f m away, y %.2f)" % [dist, player.global_position.y])
		await _free(tree, [field, player, floor_body, source])
