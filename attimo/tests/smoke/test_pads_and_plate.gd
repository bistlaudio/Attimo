extends RefCounted
## MECH-04 F, G, H, I (D-06): the bounce pad, boost ring, pressure plate and crumbling platform. Each is driven by an active
## SignalSource stub and moves the player only through launch_along, boost_along, refill_air_dash or the engine's platform
## handling. Real player, real geometry, 60 Hz.

const Fixtures := preload("res://tests/fixtures.gd")

const BOUNCE_SCENE: String = "res://scenes/mechanisms/bounce_pad.tscn"
const RING_SCENE: String = "res://scenes/mechanisms/boost_ring.tscn"
const PLATE_SCENE: String = "res://scenes/mechanisms/pressure_plate.tscn"
const CRUMBLE_SCENE: String = "res://scenes/mechanisms/crumbling_platform.tscn"
const GATE_SCENE: String = "res://scenes/mechanisms/gear_gate.tscn"
const SHIPPED_TPS: int = 60

var _launched: int = 0
var _boosted: int = 0
var _refilled: int = 0


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	EventBus.launched.connect(_on_launched)
	EventBus.boosted.connect(_on_boosted)
	EventBus.dash_refilled.connect(_on_refilled)
	await _scenario_bounce(tree, check)
	await _scenario_ring(tree, check)
	await _scenario_plate(tree, check)
	await _scenario_crumble(tree, check)
	EventBus.launched.disconnect(_on_launched)
	EventBus.boosted.disconnect(_on_boosted)
	EventBus.dash_refilled.disconnect(_on_refilled)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _on_launched(_position: Vector3, _direction: Vector3, _speed: float) -> void:
	_launched += 1


func _on_boosted(_position: Vector3, _direction: Vector3, _speed: float) -> void:
	_boosted += 1


func _on_refilled(_position: Vector3) -> void:
	_refilled += 1


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _on_source() -> SignalSource:
	var source: SignalSource = SignalSource.new()
	source.start_active = true
	return source


func _instance(path: String, source: SignalSource, at: Vector3) -> Node3D:
	var node: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	node.set("source", source)
	node.position = at
	return node


## Drops a player from `drop` m above the pad top at (x, z) and returns the apex height above the pad top of the next rise.
## -1 when no launch happened.
func _drop_apex(tree: SceneTree, pad: BouncePad, drop: float, at_x: float) -> float:
	var top: float = pad.global_position.y + pad.size.y
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(at_x, top + drop, 0.0))
	_launched = 0
	var apex: float = -1.0
	var landed: bool = false
	for i: int in 240:
		await Fixtures.wait_physics(tree, 1)
		if _launched > 0:
			landed = true
		if landed:
			apex = maxf(apex, player.global_position.y - top)
			if player.vertical_speed < 0.0 and apex > 0.0:
				break
	await _free(tree, [player])
	return apex


func _scenario_bounce(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = _on_source()
	tree.root.add_child(source)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var pad: BouncePad = _instance(BOUNCE_SCENE, source, Vector3.ZERO) as BouncePad
	tree.root.add_child(pad)
	await Fixtures.wait_physics(tree, 3)
	var high: float = await _drop_apex(tree, pad, 6.0, 0.0)
	var low: float = await _drop_apex(tree, pad, 2.0, 0.0)
	var hop: float = await _drop_apex(tree, pad, 0.5, 0.0)
	check.call(high > low and low > 0.0, "bounce: a 6 m drop bounces higher (%.2f m) than a 2 m drop (%.2f m)" % [high, low])
	check.call(high < 6.0 + 0.5, "bounce: restitution 1.0 returns about the drop height and gains no energy (6 m drop -> %.2f m)" % high)
	var floor_apex: float = pad.min_bounce * pad.min_bounce / 68.0
	check.call(hop >= floor_apex - 0.2, "bounce: a 0.5 m hop still bounces at least min_bounce (%.2f m, floor %.2f m)" % [hop, floor_apex])
	check.call(pad.get_node("Body").collision_layer == PhysicsLayers.WORLD, "the pad body is on the World layer")
	# A landing next to the pad (on the floor) does not bounce.
	var beside: float = await _drop_apex(tree, pad, 3.0, 6.0)
	check.call(beside < 0.0 and _launched == 0, "bounce: a landing next to the pad does not bounce (launched %d)" % _launched)
	# A pad whose source is off does not bounce.
	source.set_active(false)
	await Fixtures.wait_physics(tree, 3)
	var off: float = await _drop_apex(tree, pad, 3.0, 0.0)
	check.call(off < 0.0 and _launched == 0, "bounce: with the source off the pad does not bounce (launched %d)" % _launched)
	await _free(tree, [pad, floor_body, source])


## Spawns a floating player (no floor) that flies along `axis` at `speed` through a ring at the origin and returns after it passed.
func _fly_through(tree: SceneTree, ring: BoostRing, axis: Vector3, speed: float) -> PlayerController:
	var start: Vector3 = ring.global_position - axis * 4.0 - Vector3.UP * 1.0
	var player: PlayerController = Fixtures.spawn_player(tree.root, start)
	await Fixtures.wait_physics(tree, 2)
	player.move_velocity = Vector3(axis.x, 0.0, axis.z) * speed
	player.vertical_speed = 0.0
	player.air_dash_available = false
	player.air_speed_cap = maxf(player.config.run_speed, speed)
	_boosted = 0
	_refilled = 0
	var travelled: int = ceili(8.0 / maxf(speed, 1.0) * SHIPPED_TPS) + 6
	for i: int in travelled:
		# No floor: hold the height so gravity does not carry the player out of the ring while it flies.
		player.vertical_speed = 0.0
		await Fixtures.wait_physics(tree, 1)
	return player


func _scenario_ring(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = _on_source()
	tree.root.add_child(source)
	var ring: BoostRing = _instance(RING_SCENE, source, Vector3(0.0, 0.0, 0.0)) as BoostRing
	tree.root.add_child(ring)
	await Fixtures.wait_physics(tree, 3)
	var trigger: Area3D = ring.get_node("Trigger") as Area3D
	check.call(trigger.collision_layer == 0 and trigger.collision_mask == PhysicsLayers.PLAYER, "the ring trigger is an Area3D on no layer that masks the Player")
	var thickness: float = ((trigger.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D).height
	check.call(thickness >= 1.0, "the ring trigger is at least 1 m thick (%.2f m), safe at dash speed" % thickness)

	var slow: PlayerController = await _fly_through(tree, ring, Vector3.RIGHT, 8.0)
	check.call(slow.move_velocity.x >= ring.boost_speed - 0.1, "ring: crossing at 8 m/s leaves with %.2f m/s along +X (at least %.1f)" % [slow.move_velocity.x, ring.boost_speed - 0.1])
	check.call(_boosted == 1 and _refilled == 1, "ring: one boost and one dash refill per crossing (%d, %d)" % [_boosted, _refilled])
	check.call(slow.air_dash_available, "ring: the air dash is available again right after crossing")
	await _free(tree, [slow])

	var fast: PlayerController = await _fly_through(tree, ring, Vector3.RIGHT, 26.0)
	check.call(fast.move_velocity.x >= 25.5, "ring: crossing at 26 m/s keeps %.2f m/s (never slows)" % fast.move_velocity.x)
	await _free(tree, [fast])

	var back: PlayerController = await _fly_through(tree, ring, Vector3.LEFT, 8.0)
	check.call(back.move_velocity.x <= -(ring.boost_speed - 0.1), "ring: crossing along -X boosts along -X (%.2f m/s)" % back.move_velocity.x)
	await _free(tree, [back])

	# Two entries inside the rearm time count once.
	var twice: PlayerController = Fixtures.spawn_player(tree.root, Vector3(-3.0, -1.0, 0.0))
	twice.set_physics_process(false)
	_boosted = 0
	ring._on_body_entered(twice)
	ring._on_body_entered(twice)
	await Fixtures.wait_physics(tree, 3)
	check.call(_boosted == 1, "ring: two crossings within the rearm time count once (%d)" % _boosted)
	await _free(tree, [twice, ring, source])


func _scenario_plate(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var plate: PressurePlate = (load(PLATE_SCENE) as PackedScene).instantiate() as PressurePlate
	plate.position = Vector3(0.0, 0.0, 0.0)
	tree.root.add_child(plate)
	var gate: GearGate = (load(GATE_SCENE) as PackedScene).instantiate() as GearGate
	gate.source = plate
	gate.position = Vector3(0.0, 0.0, -10.0)
	tree.root.add_child(gate)
	var sensor: Area3D = plate.get_node("Sensor") as Area3D
	check.call(sensor.collision_layer == 0 and sensor.collision_mask == PhysicsLayers.PLAYER, "the plate sensor is an Area3D on no layer that masks the Player")
	await Fixtures.wait_physics(tree, 5)
	check.call(not plate.is_active, "plate: not active at rest")
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.1, 0.0))
	var on_ticks: int = await Fixtures.wait_until(tree, func() -> bool: return plate.is_active, 60)
	check.call(on_ticks >= 0 and on_ticks <= 3 and player.is_grounded(), "plate: active within 3 ticks of the player standing on it (%d ticks, grounded %s)" % [on_ticks, player.is_grounded()])
	await Fixtures.wait_physics(tree, 40)
	check.call(plate.is_active and gate.is_open(), "plate: a gate wired to it is open while the player stands on it")
	player.global_position = Vector3(8.0, 0.2, 0.0)
	player.reset_physics_interpolation()
	var off_ticks: int = await Fixtures.wait_until(tree, func() -> bool: return not plate.is_active, 30)
	check.call(off_ticks >= 0 and off_ticks <= 3, "plate: inactive within 3 ticks after the player leaves (%d)" % off_ticks)
	player.global_position = Vector3(0.0, 0.5, 0.0)
	player.reset_physics_interpolation()
	await Fixtures.wait_physics(tree, 30)
	check.call(plate.is_active, "plate: active again after stepping back on")
	player.global_position = Vector3(8.0, 0.2, 0.0)
	await Fixtures.wait_physics(tree, 10)
	plate.set_active(true)
	plate.reset()
	check.call(not plate.is_active, "plate: reset() restores the inactive state")
	await _free(tree, [player, gate, plate, floor_body])


func _crumble(tree: SceneTree, source: SignalSource, at: Vector3) -> CrumblingPlatform:
	var platform: CrumblingPlatform = _instance(CRUMBLE_SCENE, source, at) as CrumblingPlatform
	platform.shake_time = 0.3
	platform.fall_time = 0.3
	platform.respawn_delay = 1.5
	tree.root.add_child(platform)
	return platform


func _scenario_crumble(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = _on_source()
	tree.root.add_child(source)
	var platform: CrumblingPlatform = _crumble(tree, source, Vector3(0.0, 5.0, 0.0))
	var shape: CollisionShape3D = platform.get_node("Body/CollisionShape3D") as CollisionShape3D
	await Fixtures.wait_physics(tree, 5)
	check.call(platform.phase == CrumblingPlatform.Phase.IDLE and not shape.disabled, "crumble: IDLE with collision on at the start")
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 5.5, 0.0))
	await Fixtures.wait_until(tree, func() -> bool: return platform.phase != CrumblingPlatform.Phase.IDLE, 60)
	check.call(platform.phase == CrumblingPlatform.Phase.SHAKE, "crumble: the first step starts SHAKE")
	await Fixtures.wait_physics(tree, 6)
	check.call(not shape.disabled and player.global_position.y > 5.0, "crumble: the body still collides during SHAKE (player y %.2f)" % player.global_position.y)
	await Fixtures.wait_physics(tree, ceili((platform.shake_time + platform.fall_time) * SHIPPED_TPS) + 6)
	check.call(shape.disabled, "crumble: after shake_time + fall_time the collision shape is disabled")
	check.call(player.global_position.y < 4.0, "crumble: an unsupported player falls through (y %.2f)" % player.global_position.y)
	check.call(platform.phase == CrumblingPlatform.Phase.GONE or platform.phase == CrumblingPlatform.Phase.FALL, "crumble: the platform is gone (%d)" % platform.phase)
	# Someone inside the footprint keeps it gone beyond respawn_delay.
	var hold_ticks: int = ceili((platform.respawn_delay + 0.7) * SHIPPED_TPS)
	for i: int in hold_ticks:
		player.global_position = Vector3(0.0, 5.5, 0.0)
		player.move_velocity = Vector3.ZERO
		player.vertical_speed = 0.0
		await Fixtures.wait_physics(tree, 1)
	check.call(shape.disabled and platform.phase == CrumblingPlatform.Phase.GONE, "crumble: it does not respawn while a player overlaps the footprint")
	player.global_position = Vector3(20.0, 0.0, 0.0)
	await Fixtures.wait_physics(tree, 40)
	check.call(not shape.disabled and platform.phase == CrumblingPlatform.Phase.IDLE, "crumble: after respawn_delay with an empty footprint the collision is back")
	# reset() restores IDLE with collision on.
	platform.phase = CrumblingPlatform.Phase.GONE
	shape.disabled = true
	platform.reset()
	await Fixtures.wait_physics(tree, 2)
	check.call(platform.phase == CrumblingPlatform.Phase.IDLE and not shape.disabled, "crumble: reset() restores IDLE with collision on")
	await _free(tree, [player, platform, source])
