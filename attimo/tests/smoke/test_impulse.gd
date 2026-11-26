extends RefCounted
## Plan 05.1-16 (KIT-01, KIT-02, ENRG-08, D-10, D-11, D-25, D-43): the Impulse block and its three free boosters. The boost ring (air-dash
## counterpart) keeps the old ring numbers and refills the air dash, the speed pad (dash-hop counterpart, steam boost-nozzle look) gives a
## short forward boost on the ground, the bounce pad keeps the old drop-height bounce. Each gives +1 step per use with a per-block
## cooldown. The block is reached by path and by get()/call(), so this file compiles before the classes exist (TDD RED).

const Fixtures := preload("res://tests/fixtures.gd")

const RING_SCENE: String = "res://scenes/kit/steampunk/boost_ring.tscn"
const PAD_SCENE: String = "res://scenes/kit/steampunk/speed_pad.tscn"
const BOUNCE_SCENE: String = "res://scenes/kit/steampunk/bounce_pad.tscn"
const BLOCK_SCRIPT: String = "res://scripts/kit/blocks/impulse.gd"
const CONFIG_SCRIPT: String = "res://scripts/kit/configs/impulse_config.gd"
const SHIPPED_TPS: int = 60
## The old ring numbers (D-09): boost_speed 20 m/s.
const RING_SPEED: float = 20.0

var _income: int = 0
var _launched: int = 0
var _boosted: int = 0
var _refilled: int = 0
var _on_income: Callable
var _on_launched: Callable
var _on_boosted: Callable
var _on_refilled: Callable


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	var all_there: bool = true
	for path: String in [BLOCK_SCRIPT, CONFIG_SCRIPT, RING_SCENE, PAD_SCENE, BOUNCE_SCENE]:
		var exists: bool = ResourceLoader.exists(path)
		check.call(exists, "%s exists" % path)
		all_there = all_there and exists
	if not all_there:
		return
	var script: GDScript = load(BLOCK_SCRIPT) as GDScript
	check.call(String(script.get_global_name()) == "Impulse", "impulse.gd declares class_name Impulse")
	var profiles: Dictionary = (load(CONFIG_SCRIPT) as GDScript).get_script_constant_map().get("Profile", {}) as Dictionary
	check.call(profiles.has("BOOST") and profiles.has("PAD") and profiles.has("BOUNCE"), "ImpulseConfig.Profile has BOOST, PAD, BOUNCE (%s)" % [profiles])
	_begin(tree)
	await _scenario_ring(tree, check)
	await _scenario_pad(tree, check)
	await _scenario_bounce(tree, check)
	_end(tree)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _begin(tree: SceneTree) -> void:
	_on_income = func(_position: Vector3, _steps: int, _source: StringName) -> void: _income += 1
	_on_launched = func(_position: Vector3, _direction: Vector3, _speed: float) -> void: _launched += 1
	_on_boosted = func(_position: Vector3, _direction: Vector3, _speed: float) -> void: _boosted += 1
	_on_refilled = func(_position: Vector3) -> void: _refilled += 1
	var bus: Node = tree.root.get_node("EventBus")
	bus.connect(&"income_granted", _on_income)
	bus.connect(&"launched", _on_launched)
	bus.connect(&"boosted", _on_boosted)
	bus.connect(&"dash_refilled", _on_refilled)


func _end(tree: SceneTree) -> void:
	var bus: Node = tree.root.get_node("EventBus")
	bus.disconnect(&"income_granted", _on_income)
	bus.disconnect(&"launched", _on_launched)
	bus.disconnect(&"boosted", _on_boosted)
	bus.disconnect(&"dash_refilled", _on_refilled)


func _free(tree: SceneTree, nodes: Array) -> void:
	Input.action_release(&"move_forward")
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


## A floating player that flies along `axis` at `speed` through a ring at the origin and returns after it passed.
func _fly_through(tree: SceneTree, ring: Node3D, axis: Vector3, speed: float, energy: int) -> PlayerController:
	var start: Vector3 = ring.global_position - axis * 4.0
	var player: PlayerController = Fixtures.spawn_player(tree.root, start)
	Fixtures.set_energy(player, energy)
	await Fixtures.wait_physics(tree, 2)
	player.move_velocity = Vector3(axis.x, 0.0, axis.z) * speed
	player.vertical_speed = 0.0
	player.air_dash_available = false
	player.air_speed_cap = maxf(player.config.run_speed, speed)
	_boosted = 0
	_refilled = 0
	_income = 0
	for i: int in ceili(8.0 / maxf(speed, 1.0) * SHIPPED_TPS) + 6:
		player.vertical_speed = 0.0
		await Fixtures.wait_physics(tree, 1)
	return player


func _scenario_ring(tree: SceneTree, check: Callable) -> void:
	var ring: Node3D = (load(RING_SCENE) as PackedScene).instantiate() as Node3D
	tree.root.add_child(ring)
	await Fixtures.wait_physics(tree, 3)
	var config: Resource = ring.get("config") as Resource
	check.call(config != null and is_equal_approx(float(config.get("speed")), RING_SPEED), "ring keeps the old boost speed %.0f m/s (config %s)" % [RING_SPEED, config])
	check.call(int(ring.get("energy_relation")) == 3 and int(ring.get("layer")) == 0, "boost ring is a STEAMPUNK GIVES object")
	var volume: Area3D = ring.get_node_or_null("Volume") as Area3D
	check.call(volume != null and volume.collision_layer == 0 and volume.collision_mask == PhysicsLayers.PLAYER, "ring: the volume is an Area3D on no layer that masks the Player")
	var scale: float = 1.0
	var slow: PlayerController = await _fly_through(tree, ring, Vector3.RIGHT, 8.0, 3)
	scale = slow.kit_launch_scale()
	check.call(slow.move_velocity.x >= RING_SPEED * scale - 0.1, "ring: crossing at 8 m/s leaves with %.2f m/s along +X (at least %.1f)" % [slow.move_velocity.x, RING_SPEED * scale - 0.1])
	check.call(_boosted == 1 and _refilled == 1, "ring: one boost and one dash refill per crossing (%d, %d)" % [_boosted, _refilled])
	check.call(slow.air_dash_available, "ring: the air dash is available again right after crossing")
	check.call(slow.arm_energy.value == 4 and _income == 1, "ring: +1 step per use (energy %d, income facts %d)" % [slow.arm_energy.value, _income])
	await _free(tree, [slow])
	# Same crossing again straight away: boosted again after the rearm, but inside the income cooldown there is no second step.
	var again: PlayerController = await _fly_through(tree, ring, Vector3.RIGHT, 8.0, 3)
	check.call(again.arm_energy.value == 3 and _income == 0, "ring: a second crossing inside the cooldown gives no step (energy %d, facts %d)" % [again.arm_energy.value, _income])
	await _free(tree, [again])
	var fast: PlayerController = await _fly_through(tree, ring, Vector3.RIGHT, 26.0, 3)
	check.call(fast.move_velocity.x >= 25.5, "ring: crossing at 26 m/s keeps %.2f m/s (never slows)" % fast.move_velocity.x)
	await _free(tree, [fast])
	var back: PlayerController = await _fly_through(tree, ring, Vector3.LEFT, 8.0, 3)
	check.call(back.move_velocity.x <= -(RING_SPEED * scale - 0.1), "ring: crossing along -X boosts along -X (%.2f m/s)" % back.move_velocity.x)
	await _free(tree, [back, ring])


func _scenario_pad(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var pad: Node3D = (load(PAD_SCENE) as PackedScene).instantiate() as Node3D
	tree.root.add_child(pad)
	var config: Resource = pad.get("config") as Resource
	check.call(config != null and int(pad.get("energy_relation")) == 3, "speed pad is a GIVES object with a config")
	var add: float = float(config.get("add")) if config != null else 3.0
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 9.0))
	Fixtures.set_energy(player, 3)
	await Fixtures.wait_physics(tree, 10)
	_income = 0
	Input.action_press(&"move_forward")
	var peak: float = 0.0
	for i: int in 120:
		await Fixtures.wait_physics(tree, 1)
		peak = maxf(peak, player.horizontal_speed())
	check.call(peak >= player.config.run_speed + add - 0.3, "pad: running over it peaks at %.2f m/s (at least run %.1f + add %.1f - 0.3)" % [peak, player.config.run_speed, add])
	check.call(player.arm_energy.value == 4 and _income == 1, "pad: +1 step per use (energy %d, facts %d)" % [player.arm_energy.value, _income])
	await _free(tree, [pad, player, floor_body])
	# A control run without a pad never reaches that speed.
	var control_floor: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var control: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 9.0))
	await Fixtures.wait_physics(tree, 10)
	Input.action_press(&"move_forward")
	var control_peak: float = 0.0
	for i: int in 120:
		await Fixtures.wait_physics(tree, 1)
		control_peak = maxf(control_peak, control.horizontal_speed())
	check.call(control_peak < peak - 1.0, "pad: without the pad the same run stays slower (%.2f vs %.2f m/s)" % [control_peak, peak])
	await _free(tree, [control, control_floor])


## Drops a player from `drop` m above the pad top at (x, 0) and returns the apex height above the top of the next rise (-1: no launch).
func _drop_apex(tree: SceneTree, top: float, drop: float, at_x: float) -> float:
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
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var pad: Node3D = (load(BOUNCE_SCENE) as PackedScene).instantiate() as Node3D
	tree.root.add_child(pad)
	await Fixtures.wait_physics(tree, 3)
	var config: Resource = pad.get("config") as Resource
	check.call(config != null and int(pad.get("energy_relation")) == 3, "bounce pad is a GIVES object with a config")
	var top: float = pad.global_position.y + float((config.get("size") as Vector3).y)
	var min_bounce: float = float(config.get("speed"))
	var high: float = await _drop_apex(tree, top, 6.0, 0.0)
	var low: float = await _drop_apex(tree, top, 2.0, 0.0)
	var hop: float = await _drop_apex(tree, top, 0.5, 0.0)
	check.call(high > low and low > 0.0, "bounce: a 6 m drop bounces higher (%.2f m) than a 2 m drop (%.2f m)" % [high, low])
	check.call(high < 6.0 + 0.5, "bounce: restitution 1.0 returns about the drop height and gains no energy (6 m drop -> %.2f m)" % high)
	var floor_apex: float = min_bounce * min_bounce / 68.0
	check.call(hop >= floor_apex - 0.2, "bounce: a 0.5 m hop still bounces at least the minimum (%.2f m, floor %.2f m)" % [hop, floor_apex])
	var body: StaticBody3D = pad.get_node_or_null("Body") as StaticBody3D
	check.call(body != null and body.collision_layer == PhysicsLayers.WORLD, "the pad body is on the World layer")
	var beside: float = await _drop_apex(tree, top, 3.0, 6.0)
	check.call(beside < 0.0 and _launched == 0, "bounce: a landing next to the pad does not bounce (launched %d)" % _launched)
	await _free(tree, [pad])
	# Income: a fresh pad, two bounces in a row, +1 step once.
	var income_pad: Node3D = (load(BOUNCE_SCENE) as PackedScene).instantiate() as Node3D
	tree.root.add_child(income_pad)
	await Fixtures.wait_physics(tree, 3)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, top + 2.0, 0.0))
	Fixtures.set_energy(player, 3)
	_income = 0
	await Fixtures.wait_physics(tree, 150)
	check.call(player.arm_energy.value == 4 and _income == 1, "bounce: +1 step per use, a second bounce inside the cooldown gives none (energy %d, facts %d)" % [player.arm_energy.value, _income])
	await _free(tree, [income_pad, player, floor_body])
