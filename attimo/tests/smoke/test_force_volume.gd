extends RefCounted
## Plan 05.1-15 (KIT-01, KIT-02, ENRG-08, D-09, D-10, D-11, D-26, D-27, D-43, D-61): the Force volume block and its five objects. Steampunk
## updraft, geyser and steam stream carry the tuned numbers of the old nozzle, geyser and wind tunnel and give +1 step on entering the
## volume (updraft, steam stream) or on a burst that launches the player (geyser), each with the per-block real-time cooldown; standing
## inside never farms steps. Nature leaf storm (PULSED gusts against the route) and resin pool (DRAG, move_scale) never touch energy.
## The block and its config are reached by path and by call()/get(), so this file compiles before the classes exist (TDD RED).

const Fixtures := preload("res://tests/fixtures.gd")

const UPDRAFT_SCENE: String = "res://scenes/kit/steampunk/updraft.tscn"
const GEYSER_SCENE: String = "res://scenes/kit/steampunk/geyser.tscn"
const STREAM_SCENE: String = "res://scenes/kit/steampunk/steam_stream.tscn"
const STORM_SCENE: String = "res://scenes/kit/nature/leaf_storm.tscn"
const RESIN_SCENE: String = "res://scenes/kit/nature/resin_pool.tscn"
const BLOCK_SCRIPT: String = "res://scripts/kit/blocks/force_volume.gd"
const CONFIG_SCRIPT: String = "res://scripts/kit/configs/force_volume_config.gd"
const LOOK_SCRIPT: String = "res://scripts/kit/nature_look.gd"
const SHIPPED_TPS: int = 60
## The tuned numbers of the old scripts that the presets keep (D-09): nozzle updraft_speed / updraft_accel, geyser eruption_speed and
## timing, wind tunnel wind_speed / wind_accel.
const UPDRAFT_SPEED: float = 6.0
const UPDRAFT_ACCEL: float = 60.0
const GEYSER_LAUNCH: float = 24.0
const GEYSER_CHARGE: float = 3.0
const GEYSER_ERUPT: float = 0.6
const STREAM_SPEED: float = 14.0
const STREAM_ACCEL: float = 60.0
const BIG: Vector3 = Vector3(60.0, 8.0, 60.0)

var _income: Array[Dictionary] = []
var _launches: int = 0
var _on_income: Callable
var _on_launched: Callable


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	var all_there: bool = true
	for path: String in [BLOCK_SCRIPT, CONFIG_SCRIPT, LOOK_SCRIPT, UPDRAFT_SCENE, GEYSER_SCENE, STREAM_SCENE, STORM_SCENE, RESIN_SCENE]:
		var exists: bool = ResourceLoader.exists(path)
		check.call(exists, "%s exists" % path)
		all_there = all_there and exists
	if not all_there:
		return
	var script: GDScript = load(BLOCK_SCRIPT) as GDScript
	check.call(String(script.get_global_name()) == "ForceVolume", "force_volume.gd declares class_name ForceVolume")
	var config_script: GDScript = load(CONFIG_SCRIPT) as GDScript
	var constants: Dictionary = config_script.get_script_constant_map()
	var profiles: Dictionary = constants.get("Profile", {}) as Dictionary
	var timings: Dictionary = constants.get("Timing", {}) as Dictionary
	check.call(profiles.has("DIRECTIONAL") and profiles.has("DRAG"), "ForceVolumeConfig.Profile has DIRECTIONAL and DRAG (%s)" % [profiles])
	check.call(timings.has("CONTINUOUS") and timings.has("PULSED"), "ForceVolumeConfig.Timing has CONTINUOUS and PULSED (%s)" % [timings])
	await _scenario_updraft(tree, check)
	await _scenario_geyser(tree, check)
	await _scenario_steam_stream(tree, check)
	await _scenario_no_farming(tree, check)
	await _scenario_leaf_storm(tree, check)
	await _scenario_resin_pool(tree, check)
	_scenario_looks(check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _begin_facts(tree: SceneTree) -> void:
	_income = []
	_launches = 0
	_on_income = func(position: Vector3, steps: int, source_id: StringName) -> void: _income.append({"position": position, "steps": steps, "source": source_id})
	_on_launched = func(_position: Vector3, _direction: Vector3, _speed: float) -> void: _launches += 1
	tree.root.get_node("EventBus").connect(&"income_granted", _on_income)
	tree.root.get_node("EventBus").connect(&"launched", _on_launched)


func _end_facts(tree: SceneTree) -> void:
	tree.root.get_node("EventBus").disconnect(&"income_granted", _on_income)
	tree.root.get_node("EventBus").disconnect(&"launched", _on_launched)


func _free(tree: SceneTree, nodes: Array) -> void:
	Input.action_release(&"move_forward")
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


## The scene's own config copy with `size` set (and further fields from `changes`), assigned before the node enters the tree, so the
## shared preset is never written.
func _spawn(tree: SceneTree, path: String, size: Vector3, changes: Dictionary = {}) -> Node3D:
	var node: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	var config: Resource = (node.get("config") as Resource).duplicate()
	if size != Vector3.ZERO:
		config.set("size", size)
	for key: Variant in changes:
		config.set(String(key), changes[key])
	node.set("config", config)
	tree.root.add_child(node)
	return node


func _scenario_updraft(tree: SceneTree, check: Callable) -> void:
	_begin_facts(tree)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var updraft: Node3D = (load(UPDRAFT_SCENE) as PackedScene).instantiate() as Node3D
	tree.root.add_child(updraft)
	var config: Resource = updraft.get("config") as Resource
	check.call(config != null and is_equal_approx(float(config.get("strength")), UPDRAFT_SPEED) and is_equal_approx(float(config.get("accel")), UPDRAFT_ACCEL), "updraft keeps the old nozzle numbers %.1f m/s / %.0f (config %s)" % [UPDRAFT_SPEED, UPDRAFT_ACCEL, config])
	check.call(int(updraft.get("energy_relation")) == 3 and int(updraft.get("layer")) == 0, "updraft is a STEAMPUNK GIVES object")
	var volume: Area3D = updraft.get_node_or_null("Volume") as Area3D
	check.call(volume != null and volume.collision_layer == 0 and volume.collision_mask == PhysicsLayers.PLAYER, "updraft: the volume is an Area3D on no layer that masks the Player")
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	Fixtures.set_energy(player, 3)
	var peak: float = 0.0
	for i: int in 40:
		await Fixtures.wait_physics(tree, 1)
		peak = maxf(peak, player.vertical_speed)
	check.call(peak > 0.8 * UPDRAFT_SPEED, "updraft lifts toward %.1f m/s (peak %.2f)" % [UPDRAFT_SPEED, peak])
	check.call(player.arm_energy.value == 4 and _income.size() == 1, "updraft: entering gives +1 step once (energy %d, facts %d)" % [player.arm_energy.value, _income.size()])
	# Leave and re-enter inside the cooldown: nothing; after it: +1 again.
	player.teleport(Vector3(12.0, 0.0, 0.0))
	await Fixtures.wait_physics(tree, 30)
	player.teleport(Vector3.ZERO)
	await Fixtures.wait_physics(tree, 20)
	check.call(player.arm_energy.value == 4 and _income.size() == 1, "updraft: a re-entry inside the cooldown gives nothing (energy %d, facts %d)" % [player.arm_energy.value, _income.size()])
	var cooldown: float = float(config.get("income_cooldown")) if config != null else 3.0
	player.teleport(Vector3(12.0, 0.0, 0.0))
	await Fixtures.wait_physics(tree, ceili(cooldown * SHIPPED_TPS) + 20)
	player.teleport(Vector3.ZERO)
	await Fixtures.wait_physics(tree, 20)
	check.call(player.arm_energy.value == 5 and _income.size() == 2, "updraft: after the cooldown a re-entry gives +1 again (energy %d, facts %d)" % [player.arm_energy.value, _income.size()])
	_end_facts(tree)
	await _free(tree, [updraft, player, floor_body])


func _scenario_geyser(tree: SceneTree, check: Callable) -> void:
	_begin_facts(tree)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var preset: Node3D = (load(GEYSER_SCENE) as PackedScene).instantiate() as Node3D
	var preset_config: Resource = preset.get("config") as Resource
	check.call(preset_config != null and is_equal_approx(float(preset_config.get("launch_speed")), GEYSER_LAUNCH) and is_equal_approx(float(preset_config.get("pulse_off")), GEYSER_CHARGE) and is_equal_approx(float(preset_config.get("pulse_on")), GEYSER_ERUPT), "geyser keeps the old rhythm %.1f s charge, %.1f s erupt and the %.0f m/s launch" % [GEYSER_CHARGE, GEYSER_ERUPT, GEYSER_LAUNCH])
	check.call(int(preset.get("energy_relation")) == 3, "geyser is a GIVES object")
	preset.free()
	var geyser: Node3D = _spawn(tree, GEYSER_SCENE, Vector3.ZERO, {"pulse_off": 1.0})
	var inside: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	var outside: PlayerController = Fixtures.spawn_player(tree.root, Vector3(8.0, 0.0, 0.0))
	Fixtures.set_energy(inside, 3)
	var erupted: bool = false
	var apex: float = 0.0
	for i: int in 2 * SHIPPED_TPS:
		await Fixtures.wait_physics(tree, 1)
		if bool(geyser.call(&"is_pulse_on")):
			erupted = true
		apex = maxf(apex, inside.global_position.y)
	check.call(erupted, "geyser: it erupts on its pulse rhythm")
	check.call(_launches == 1, "geyser: one launch per eruption for the player in the column (%d)" % _launches)
	check.call(apex > 6.0, "geyser: the launched player reaches %.2f m (above 6)" % apex)
	check.call(outside.global_position.y < 0.5, "geyser: a player outside the column is not launched (y %.2f)" % outside.global_position.y)
	check.call(inside.arm_energy.value == 4 and _income.size() == 1, "geyser: the launching burst gives +1 step (energy %d, facts %d)" % [inside.arm_energy.value, _income.size()])
	# A second burst inside the 3 s cooldown launches but gives nothing more.
	await Fixtures.wait_physics(tree, SHIPPED_TPS)
	check.call(_income.size() == 1 and inside.arm_energy.value <= 4, "geyser: a burst inside the cooldown gives no second step (facts %d, energy %d)" % [_income.size(), inside.arm_energy.value])
	_end_facts(tree)
	await _free(tree, [geyser, inside, outside, floor_body])


func _scenario_steam_stream(tree: SceneTree, check: Callable) -> void:
	_begin_facts(tree)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var stream: Node3D = (load(STREAM_SCENE) as PackedScene).instantiate() as Node3D
	tree.root.add_child(stream)
	var config: Resource = stream.get("config") as Resource
	check.call(config != null and is_equal_approx(float(config.get("strength")), STREAM_SPEED) and is_equal_approx(float(config.get("accel")), STREAM_ACCEL), "steam stream keeps the old wind tunnel numbers %.0f m/s / %.0f" % [STREAM_SPEED, STREAM_ACCEL])
	check.call(int(stream.get("energy_relation")) == 3, "steam stream is a GIVES object (D-61)")
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 3.0, 0.0))
	Fixtures.set_energy(player, 3)
	var along: Vector3 = Vector3(-stream.global_basis.z.x, 0.0, -stream.global_basis.z.z).normalized()
	var peak: float = 0.0
	for i: int in 25:
		await Fixtures.wait_physics(tree, 1)
		peak = maxf(peak, player.move_velocity.dot(along))
	check.call(peak > 0.7 * STREAM_SPEED, "steam stream pushes along its direction (peak %.2f of %.0f m/s)" % [peak, STREAM_SPEED])
	check.call(player.arm_energy.value == 4 and _income.size() == 1, "steam stream: entering gives +1 step (energy %d, facts %d)" % [player.arm_energy.value, _income.size()])
	_end_facts(tree)
	await _free(tree, [stream, player, floor_body])


## Standing inside a volume for 10 s farms nothing (T-05.1-46): a huge, nearly still steam stream.
func _scenario_no_farming(tree: SceneTree, check: Callable) -> void:
	_begin_facts(tree)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(200, 1, 200))
	var stream: Node3D = _spawn(tree, STREAM_SCENE, BIG, {"strength": 0.1})
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	Fixtures.set_energy(player, 3)
	await Fixtures.wait_physics(tree, 10 * SHIPPED_TPS)
	check.call(_income.size() == 1 and player.arm_energy.value == 4, "standing inside for 10 s gives +1 once, never farms (facts %d, energy %d)" % [_income.size(), player.arm_energy.value])
	_end_facts(tree)
	await _free(tree, [stream, player, floor_body])


## The storm pushes against the run: during a gust the run slows clearly but never reverses, in the lull it recovers; no energy is touched.
func _scenario_leaf_storm(tree: SceneTree, check: Callable) -> void:
	_begin_facts(tree)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(200, 1, 200))
	var storm: Node3D = _spawn(tree, STORM_SCENE, BIG)
	var config: Resource = storm.get("config") as Resource
	check.call(int(storm.get("layer")) == 2 and int(storm.get("energy_relation")) == 0 and int(config.get("income_steps")) == 0, "leaf storm is NATURE, FREE and gives no steps")
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 20.0))
	Fixtures.set_energy(player, 5)
	await Fixtures.wait_physics(tree, 15)
	# The storm blows toward +z (its local direction rotated by the node), the run goes -z: against the route.
	var wind: Vector3 = (storm.global_basis * (config.get("direction") as Vector3)).normalized()
	Input.action_press(&"move_forward")
	var run_dir: Vector3 = Vector3(0.0, 0.0, -1.0)
	var gust_min: float = INF
	var lull_max: float = 0.0
	var gusts: int = 0
	var was_on: bool = false
	for i: int in 4 * SHIPPED_TPS:
		await Fixtures.wait_physics(tree, 1)
		var on: bool = bool(storm.call(&"is_pulse_on"))
		if on and not was_on:
			gusts += 1
		was_on = on
		var speed: float = player.move_velocity.dot(run_dir)
		if i > 20:
			if on:
				gust_min = minf(gust_min, speed)
			else:
				lull_max = maxf(lull_max, speed)
	var run_speed: float = player.config.run_speed
	check.call(wind.dot(run_dir) < -0.5, "the leaf storm blows against the run direction (wind %s)" % [wind])
	check.call(gusts >= 2, "the leaf storm gusts on a rhythm (%d gusts in 4 s)" % gusts)
	check.call(gust_min < run_speed - 1.5, "during a gust the run is clearly slowed (min %.2f of %.2f m/s)" % [gust_min, run_speed])
	check.call(gust_min > 0.5, "a gust slows but never turns the run around (min %.2f)" % gust_min)
	check.call(lull_max > run_speed - 0.7, "between gusts the run recovers (%.2f of %.2f m/s)" % [lull_max, run_speed])
	check.call(player.arm_energy.value == 5 and _income.is_empty(), "the leaf storm never touches energy (energy %d, facts %d)" % [player.arm_energy.value, _income.size()])
	_end_facts(tree)
	await _free(tree, [storm, player, floor_body])


## The resin pool lowers the run to move_scale x run speed (+-5 %) and restores it on leaving; no energy is touched.
func _scenario_resin_pool(tree: SceneTree, check: Callable) -> void:
	_begin_facts(tree)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(300, 1, 300))
	var pool: Node3D = _spawn(tree, RESIN_SCENE, Vector3(20.0, 2.0, 120.0))
	var config: Resource = pool.get("config") as Resource
	var scale: float = float(config.get("move_scale"))
	check.call(int(pool.get("layer")) == 2 and int(pool.get("energy_relation")) == 0 and int(config.get("income_steps")) == 0, "resin pool is NATURE, FREE and gives no steps")
	check.call(is_equal_approx(scale, 0.45), "resin pool move_scale is the F2 start value 0.45 (%.2f)" % scale)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 50.0))
	Fixtures.set_energy(player, 5)
	await Fixtures.wait_physics(tree, 15)
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, SHIPPED_TPS)
	var run_speed: float = player.config.run_speed
	var inside: float = player.horizontal_speed()
	check.call(absf(inside - scale * run_speed) <= 0.05 * run_speed, "inside the pool the run drops to %.2f m/s (%.2f x %.2f, got %.2f)" % [scale * run_speed, scale, run_speed, inside])
	check.call(player.arm_energy.value == 5 and _income.is_empty(), "the resin pool never touches energy (energy %d, facts %d)" % [player.arm_energy.value, _income.size()])
	# Leave the pool at the far end: the run restores.
	player.teleport(Vector3(0.0, 0.0, -80.0))
	await Fixtures.wait_physics(tree, SHIPPED_TPS)
	var after: float = player.horizontal_speed()
	check.call(absf(after - run_speed) <= 0.05 * run_speed, "outside the pool the run is back at %.2f m/s (got %.2f)" % [run_speed, after])
	_end_facts(tree)
	await _free(tree, [pool, player, floor_body])


## D-26: the nature scenes name their meshes for the look pass keywords; the move-scale request exists.
func _scenario_looks(check: Callable) -> void:
	for path: String in [STORM_SCENE, RESIN_SCENE]:
		var root: Node = (load(path) as PackedScene).instantiate()
		var keyed: int = 0
		for node: Node in root.find_children("*", "MeshInstance3D", true, false):
			var lowered: String = String(node.name).to_lower()
			for keyword: String in ["moss", "bark", "resin", "stone"]:
				if lowered.contains(keyword):
					keyed += 1
		check.call(keyed >= 1, "%s has meshes named for the nature look keywords (%d)" % [path, keyed])
		root.free()
	var player_script: GDScript = load("res://scripts/player/player_controller.gd") as GDScript
	var methods: Array[String] = []
	for method: Dictionary in player_script.get_script_method_list():
		methods.append(String(method["name"]))
	check.call(methods.has("request_move_scale"), "PlayerController has request_move_scale")
