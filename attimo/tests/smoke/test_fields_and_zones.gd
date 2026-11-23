extends RefCounted
## MECH-04 K (D-06): the low-gravity zone. Inside the volume a held full jump rises at least twice as high, switching the
## source off restores the normal apex (no restore step), and the zone only uses PlayerController.request_gravity_scale (the
## Dash-owned gravity_scale stays untouched). MECH-04 A, B, J: the repulsor and attractor (ForceField) and the wind tunnel.

const Fixtures := preload("res://tests/fixtures.gd")

const ZONE_SCENE: String = "res://scenes/mechanisms/low_gravity_zone.tscn"
const FIELD_SCENE: String = "res://scenes/mechanisms/force_field.tscn"
const WIND_SCENE: String = "res://scenes/mechanisms/wind_tunnel.tscn"
const SHIPPED_TPS: int = 60


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_low_gravity(tree, check)
	await _scenario_repulsor(tree, check)
	await _scenario_attractor(tree, check)
	await _scenario_wind(tree, check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


## Holds the jump button through a full jump and returns [apex height, airborne ticks]. The player ends back on the floor.
func _held_jump(tree: SceneTree, player: PlayerController) -> Array[float]:
	var start_y: float = player.global_position.y
	var apex: float = 0.0
	var air_ticks: float = 0.0
	Input.action_press(&"jump")
	for i: int in 400:
		await Fixtures.wait_physics(tree, 1)
		if i > 3 and player.is_grounded():
			break
		apex = maxf(apex, player.global_position.y - start_y)
		air_ticks += 1.0
	Input.action_release(&"jump")
	await Fixtures.wait_physics(tree, 30)
	return [apex, air_ticks]


func _scenario_low_gravity(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var zone: LowGravityZone = (load(ZONE_SCENE) as PackedScene).instantiate() as LowGravityZone
	zone.source = source
	tree.root.add_child(zone)
	var volume: Area3D = zone.get_node("Volume") as Area3D
	check.call(volume.collision_layer == 0 and volume.collision_mask == PhysicsLayers.PLAYER, "the zone volume is an Area3D on no layer that masks the Player")
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 20)

	var out: Array[float] = await _held_jump(tree, player)
	check.call(out[0] > 1.5, "a held jump outside rises %.2f m (zone off)" % out[0])

	source.set_active(true)
	await Fixtures.wait_physics(tree, 5)
	var inside: Array[float] = await _held_jump(tree, player)
	check.call(inside[0] >= 2.0 * out[0], "inside the zone the same held jump rises %.2f m, at least 2x %.2f m" % [inside[0], out[0]])
	check.call(inside[1] > out[1], "and stays airborne longer (%d vs %d ticks)" % [int(inside[1]), int(out[1])])

	source.set_active(false)
	await Fixtures.wait_physics(tree, 5)
	var again: Array[float] = await _held_jump(tree, player)
	check.call(absf(again[0] - out[0]) <= 0.1 * out[0], "switched off again, the apex is back to %.2f m (was %.2f m)" % [again[0], out[0]])

	# Bad and out-of-range requests (T-04.1-01).
	player.request_gravity_scale(NAN)
	player.request_gravity_scale(INF)
	check.call(player._zone_gravity_scale == 1.0, "a non-finite gravity request changes nothing")
	player.request_gravity_scale(0.0)
	check.call(is_equal_approx(player._zone_gravity_scale, 0.05), "a request below 0.05 is clamped to 0.05 (%.3f)" % player._zone_gravity_scale)
	await Fixtures.wait_physics(tree, 2)
	check.call(player._zone_gravity_scale == 1.0, "the request is cleared after the move, no restore step needed")
	player.request_gravity_scale(5.0)
	check.call(player._zone_gravity_scale == 1.0, "a request above 1.0 is clamped to 1.0")

	# An air dash inside the zone: the zone leaves the state-owned gravity_scale alone.
	source.set_active(true)
	await Fixtures.wait_physics(tree, 5)
	await Fixtures.tap_action(tree, &"jump", 3)
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.tap_action(tree, &"dash", 3)
	check.call(player.state_machine.current.name == &"Dash", "an air dash starts inside the zone (%s)" % player.state_machine.current.name)
	check.call(is_equal_approx(player.gravity_scale, player.config.air_dash_gravity_scale), "during the dash gravity_scale is the dash value (%.2f), not the zone factor" % player.gravity_scale)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name != &"Dash", 40)
	check.call(player.gravity_scale == 1.0, "after the air dash gravity_scale is 1.0 (%.2f)" % player.gravity_scale)

	await _free(tree, [zone, player, floor_body, source])


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


## Runs along -Z, starts a held jump at z = 5 and returns how far (along -Z) the jump carried. tunnel_mode: 0 none, 1 tailwind, 2 headwind.
func _wind_jump(tree: SceneTree, check: Callable, tunnel_mode: int) -> float:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(60, 1, 80))
	var tunnel: WindTunnel = null
	if tunnel_mode > 0:
		tunnel = (load(WIND_SCENE) as PackedScene).instantiate() as WindTunnel
		tunnel.source = source
		tree.root.add_child(tunnel)
		var volume: Area3D = tunnel.get_node("Volume") as Area3D
		check.call(volume.collision_layer == 0 and volume.collision_mask == PhysicsLayers.PLAYER, "the wind volume is an Area3D on no layer that masks the Player")
		source.set_active(tunnel_mode == 2)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 14.0))
	await Fixtures.wait_physics(tree, 15)
	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return player.global_position.z <= 5.0, 400)
	var start_z: float = player.global_position.z
	Input.action_press(&"jump")
	for i: int in 400:
		await Fixtures.wait_physics(tree, 1)
		if i > 3 and player.is_grounded():
			break
	var distance: float = start_z - player.global_position.z
	Input.action_release(&"jump")
	Input.action_release(&"move_forward")
	await _free(tree, [tunnel, player, floor_body, source])
	return distance


func _scenario_wind(tree: SceneTree, check: Callable) -> void:
	var plain: float = await _wind_jump(tree, check, 0)
	var tail: float = await _wind_jump(tree, check, 1)
	var head: float = await _wind_jump(tree, check, 2)
	check.call(plain > 2.0, "without wind the run-jump covers %.2f m" % plain)
	check.call(tail >= plain + 2.0, "tailwind: the jump covers %.2f m, at least 2 m more than %.2f m" % [tail, plain])
	check.call(head <= plain - 1.0, "headwind (lever flipped): the jump covers %.2f m, at least 1 m less than %.2f m" % [head, plain])
