extends RefCounted
## Plan 05.1-16 (KIT-01, KIT-02, D-14, D-24, D-43): the Amplification component and its two users. `factor(player)` is 1.0 at 0 steps and
## 1 + gain at 12 steps and only reads the arm. User 1: the bounce pad with core launches higher with more steps. User 2: the gravity
## zone (Force volume GRAVITY profile) floats longer with more steps. Neither ever changes the arm energy. The player-side gravity
## request contract (clamps, state-owned gravity_scale) stays pinned here too. Classes are reached by path, so this file compiles
## before they exist (TDD RED).

const Fixtures := preload("res://tests/fixtures.gd")

const AMP_SCRIPT: String = "res://scripts/kit/components/amplification.gd"
const CORE_SCENE: String = "res://scenes/kit/energy/bounce_pad_core.tscn"
const ZONE_SCENE: String = "res://scenes/kit/energy/gravity_zone.tscn"
const SHIPPED_TPS: int = 60

var _launched: int = 0
var _on_launched: Callable


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	var all_there: bool = true
	for path: String in [AMP_SCRIPT, CORE_SCENE, ZONE_SCENE]:
		var exists: bool = ResourceLoader.exists(path)
		check.call(exists, "%s exists" % path)
		all_there = all_there and exists
	if not all_there:
		return
	check.call(String((load(AMP_SCRIPT) as GDScript).get_global_name()) == "Amplification", "amplification.gd declares class_name Amplification")
	_on_launched = func(_position: Vector3, _direction: Vector3, _speed: float) -> void: _launched += 1
	tree.root.get_node("EventBus").connect(&"launched", _on_launched)
	await _scenario_factor(tree, check)
	await _scenario_core_bounce(tree, check)
	await _scenario_gravity_zone(tree, check)
	await _scenario_dash_in_zone(tree, check)
	tree.root.get_node("EventBus").disconnect(&"launched", _on_launched)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _scenario_factor(tree: SceneTree, check: Callable) -> void:
	var amp: Node = (load(AMP_SCRIPT) as GDScript).new() as Node
	tree.root.add_child(amp)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 50.0, 0.0))
	var gain: float = float(amp.get("gain"))
	Fixtures.set_energy(player, 0)
	check.call(is_equal_approx(float(amp.call("factor", player)), 1.0), "factor is 1.0 at 0 steps")
	Fixtures.set_energy(player, 12)
	check.call(is_equal_approx(float(amp.call("factor", player)), 1.0 + gain), "factor is 1 + gain (%.2f) at 12 steps" % gain)
	check.call(player.arm_energy.value == 12, "reading the factor never changes the arm energy (%d)" % player.arm_energy.value)
	amp.set("gain", 0.0)
	check.call(is_equal_approx(float(amp.call("factor", player)), 1.0), "gain 0 means factor 1.0 at any step count")
	var source: String = (load(AMP_SCRIPT) as GDScript).source_code
	for call_name: String in ["try_spend", ".gain(", "reset_to"]:
		check.call(not source.contains("arm_energy." + call_name), "amplification.gd never calls arm_energy.%s" % call_name)
	await _free(tree, [amp, player])


## Drops from `drop` m above the pad top with `steps` on the clock and returns [apex above the top, energy after].
func _core_apex(tree: SceneTree, top: float, steps: int) -> Array[float]:
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, top + 2.0, 0.0))
	Fixtures.set_energy(player, steps)
	_launched = 0
	var apex: float = -1.0
	for i: int in 240:
		await Fixtures.wait_physics(tree, 1)
		if _launched > 0:
			apex = maxf(apex, player.global_position.y - top)
			if player.vertical_speed < 0.0 and apex > 0.0:
				break
	var energy: float = float(player.arm_energy.value)
	await _free(tree, [player])
	return [apex, energy]


func _scenario_core_bounce(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var pad: Node3D = (load(CORE_SCENE) as PackedScene).instantiate() as Node3D
	tree.root.add_child(pad)
	await Fixtures.wait_physics(tree, 3)
	check.call(int(pad.get("energy_relation")) == 2 and int(pad.get("layer")) == 1, "bounce pad with core is an ENERGY AMPLIFIED object")
	var config: Resource = pad.get("config") as Resource
	var top: float = pad.global_position.y + float((config.get("size") as Vector3).y)
	var empty: Array[float] = await _core_apex(tree, top, 0)
	var full: Array[float] = await _core_apex(tree, top, 12)
	check.call(empty[0] > 0.0 and full[0] > empty[0] + 0.5, "core bounce: 12 steps bounce clearly higher (%.2f m) than 0 steps (%.2f m)" % [full[0], empty[0]])
	check.call(int(full[1]) == 12, "core bounce: the clock does not drop (12 -> %d)" % int(full[1]))
	await _free(tree, [pad, floor_body])


## Ticks a fall from 6 m takes inside the zone, with `steps` on the clock.
func _zone_fall_ticks(tree: SceneTree, steps: int) -> Array[float]:
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 7.0, 0.0))
	Fixtures.set_energy(player, steps)
	var ticks: float = 0.0
	for i: int in 600:
		await Fixtures.wait_physics(tree, 1)
		if i > 3 and player.is_grounded():
			break
		ticks += 1.0
	var energy: float = float(player.arm_energy.value)
	await _free(tree, [player])
	return [ticks, energy]


func _scenario_gravity_zone(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var zone: Node3D = (load(ZONE_SCENE) as PackedScene).instantiate() as Node3D
	tree.root.add_child(zone)
	await Fixtures.wait_physics(tree, 3)
	check.call(int(zone.get("energy_relation")) == 2 and int(zone.get("layer")) == 1, "gravity zone is an ENERGY AMPLIFIED object")
	var zone_config: Resource = zone.get("config") as Resource
	var profiles: Dictionary = (load("res://scripts/kit/configs/force_volume_config.gd") as GDScript).get_script_constant_map().get("Profile", {}) as Dictionary
	check.call(zone_config != null and int(zone_config.get("profile")) == int(profiles.get("GRAVITY", -1)), "gravity zone uses the Force volume GRAVITY profile")
	var empty: Array[float] = await _zone_fall_ticks(tree, 0)
	var full: Array[float] = await _zone_fall_ticks(tree, 12)
	check.call(full[0] > empty[0] + 2.0, "gravity zone: the same fall takes longer with 12 steps (%d ticks) than with 0 (%d ticks)" % [int(full[0]), int(empty[0])])
	check.call(int(full[1]) == 12, "gravity zone: the clock does not drop (12 -> %d)" % int(full[1]))
	await _free(tree, [zone, floor_body])
	# Outside the zone the fall is the normal one (the zone is gone).
	var normal_floor: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var normal: Array[float] = await _zone_fall_ticks(tree, 0)
	check.call(normal[0] < empty[0] - 2.0, "without the zone the fall is faster (%d vs %d ticks)" % [int(normal[0]), int(empty[0])])
	await _free(tree, [normal_floor])


## An air dash inside the zone: the zone leaves the state-owned gravity_scale alone (T-04.1-01).
func _scenario_dash_in_zone(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var zone: Node3D = (load(ZONE_SCENE) as PackedScene).instantiate() as Node3D
	tree.root.add_child(zone)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	Fixtures.set_energy(player, 6)
	await Fixtures.wait_physics(tree, 20)
	await Fixtures.tap_action(tree, &"jump", 3)
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.tap_action(tree, &"dash", 3)
	check.call(player.state_machine.current.name == &"Dash", "an air dash starts inside the zone (%s)" % player.state_machine.current.name)
	check.call(is_equal_approx(player.gravity_scale, player.config.air_dash_gravity_scale), "during the dash gravity_scale is the dash value (%.2f), not the zone factor" % player.gravity_scale)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name != &"Dash", 40)
	check.call(player.gravity_scale == 1.0, "after the air dash gravity_scale is 1.0 (%.2f)" % player.gravity_scale)
	await _free(tree, [zone, player, floor_body])
