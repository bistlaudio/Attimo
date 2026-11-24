extends RefCounted
## Plan 05.1-02 (KIT-03, D-04, D-05, D-17): the steam cannon is the FIXED profile of the Catch & launch block. It catches Rino at the
## breech into the Loader state with a FIXED LoaderProfile, pulls him to the barrel mouth, holds fixed_hold (no slow motion, no
## input) and launches along the barrel at fixed_speed, whatever the entry. The old nozzle cannon tilted its trigger with the barrel
## and kept the sideways entry velocity, so its apex ranged from 0.42 m to 3.07 m (RESEARCH "Pre-Planning Reproductions" 1); this
## test enters from behind, the front and both sides at run and at dash speed and asserts the same launch velocity (0.01 m/s) and
## the same apex (0.05 m). It also checks the hold length (12 ticks +-1 at 60 TPS), that Engine.time_scale stays 1.0, that RMB does
## nothing during the hold, the refill of the Loader use only (unattended decision 5), the untouched arm energy and air dash, the
## launched fact, the launch point at the barrel mouth, and that standing next to the breech never fires. New config fields
## (fixed_pitch_deg, muzzle_offset) and LoaderState.source() are read by reflection, so the RED run fails on behaviour.

const Fixtures := preload("res://tests/fixtures.gd")

const KIT_SCENE: String = "res://scenes/kit/steampunk/steam_cannon.tscn"
const PROFILE_SCRIPT: String = "res://scripts/player/loader_profile.gd"
const SHIPPED_TPS: int = 60
## The station yaw of the gym row: the barrel points along +X.
const YAW_DEG: float = -90.0
## Horizontal start distance from the breech centre (the catch overlap begins at trigger radius + capsule radius = 1.7 m).
const START_DISTANCE: float = 3.2
const APEX_TICKS: int = 120
const VELOCITY_TOLERANCE: float = 0.01
const APEX_TOLERANCE: float = 0.05
## The launch point may sit this far from the barrel mouth (one pull step of float error).
const MOUTH_TOLERANCE: float = 0.05
const ENERGY: float = 25.0

var _bus: Node
var _launches: Array[Dictionary] = []
var _spent: Array[float] = []
var _player: PlayerController
var _on_launched: Callable
var _on_spent: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await tree.process_frame
	check.call(ResourceLoader.exists(KIT_SCENE), "the steam cannon scene %s exists" % KIT_SCENE)
	check.call(_profile_source("FIXED") >= 0, "LoaderProfile.Source has a FIXED value")
	if not ResourceLoader.exists(KIT_SCENE):
		return
	var results: Array[Dictionary] = []
	var entries: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
	var names: Array[String] = ["behind", "front", "left side", "right side"]
	var index: int = 0
	for e: int in entries.size():
		for dash: bool in [false, true]:
			var result: Dictionary = await _entry_run(tree, check, entries[e], dash, index % 2 == 1, "%s %s" % [names[e], "dash" if dash else "run"])
			if not result.is_empty():
				results.append(result)
			index += 1
	check.call(results.size() == 8, "all 8 entries launch (%d)" % results.size())
	if results.size() >= 2:
		var first: Dictionary = results[0]
		var worst_velocity: float = 0.0
		var apex_min: float = INF
		var apex_max: float = -INF
		for result: Dictionary in results:
			worst_velocity = maxf(worst_velocity, ((result["velocity"] as Vector3) - (first["velocity"] as Vector3)).length())
			apex_min = minf(apex_min, result["apex"] as float)
			apex_max = maxf(apex_max, result["apex"] as float)
		check.call(worst_velocity <= VELOCITY_TOLERANCE, "every entry launches with the same velocity (worst difference %.4f m/s)" % worst_velocity)
		check.call(apex_max - apex_min <= APEX_TOLERANCE, "every entry reaches the same apex (%.3f .. %.3f m)" % [apex_min, apex_max])
	await _scenario_beside(tree, check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


## A LoaderProfile.Source value by name, or -1 while it does not exist.
func _profile_source(key: String) -> int:
	if not ResourceLoader.exists(PROFILE_SCRIPT):
		return -1
	var script: GDScript = load(PROFILE_SCRIPT) as GDScript
	var sources: Dictionary = script.get_script_constant_map().get("Source", {}) as Dictionary
	return int(sources.get(key, -1))


func _source_of(player: PlayerController) -> int:
	var state: LoaderState = player.loader_state()
	if state == null or not state.has_method(&"source"):
		return -1
	return int(state.call(&"source"))


func _is_loader(player: PlayerController) -> bool:
	return player.state_machine.current.name == &"Loader"


## A config number of the cannon by reflection, or `fallback` while the field does not exist.
func _config_float(cannon: Node3D, key: String, fallback: float) -> float:
	var config: Resource = cannon.get("config") as Resource
	if config == null or not key in config:
		return fallback
	return float(config.get(key))


## The expected barrel direction: the yaw-only forward of the block pitched up by fixed_pitch_deg.
func _barrel(cannon: Node3D) -> Vector3:
	var pitch: float = deg_to_rad(_config_float(cannon, "fixed_pitch_deg", 45.0))
	var forward: Vector3 = -cannon.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	return (forward * cos(pitch) + Vector3.UP * sin(pitch)).normalized()


func _spawn(tree: SceneTree) -> Array[Node]:
	_launches = []
	_spent = []
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(300.0, 1.0, 300.0))
	var cannon: Node3D = (load(KIT_SCENE) as PackedScene).instantiate() as Node3D
	cannon.rotation.y = deg_to_rad(YAW_DEG)
	tree.root.add_child(cannon)
	_player = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 40.0))
	Fixtures.set_energy(_player, ENERGY)
	_on_launched = func(position: Vector3, direction: Vector3, speed: float) -> void:
		var state: LoaderState = _player.loader_state()
		_launches.append({
			"position": position,
			"direction": direction,
			"speed": speed,
			"velocity": Vector3(_player.move_velocity.x, _player.vertical_speed, _player.move_velocity.z),
			"energy": _player.arm_energy.value,
			"dash_available": _player.air_dash_available,
			"update_count": state.update_count if state != null else -1,
		})
	_on_spent = func(amount: float, _reason: StringName) -> void: _spent.append(amount)
	_bus.connect(&"launched", _on_launched)
	_bus.connect(&"energy_spent", _on_spent)
	await Fixtures.wait_physics(tree, 3)
	return [floor_body, cannon, _player]


func _despawn(tree: SceneTree, nodes: Array[Node]) -> void:
	for action: StringName in [&"loader", &"move_forward", &"jump", &"dash"]:
		Input.action_release(action)
	_bus.disconnect(&"launched", _on_launched)
	_bus.disconnect(&"energy_spent", _on_spent)
	_on_launched = Callable()
	_on_spent = Callable()
	Fixtures.restore_time()
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
	await tree.process_frame


## One entry: the player slides into the breech along `direction` at run or dash speed. Returns {velocity, apex} or {}.
func _entry_run(tree: SceneTree, check: Callable, direction: Vector3, dash: bool, press_rmb: bool, name: String) -> Dictionary:
	var nodes: Array[Node] = await _spawn(tree)
	var cannon: Node3D = nodes[1] as Node3D
	var player: PlayerController = _player
	var config: MovementConfig = player.config
	var speed: float = config.dash_speed if dash else config.run_speed
	var breech: Vector3 = cannon.global_position
	player.teleport(breech - direction * START_DISTANCE)
	await tree.physics_frame
	player.launch_along(direction, speed, false)
	_launches.clear()
	var entered: int = await Fixtures.wait_until(tree, func() -> bool: return _is_loader(player), 40)
	check.call(entered >= 0, "(%s) entering the breech catches Rino into the Loader (state %s)" % [name, player.state_machine.current.name])
	if entered < 0:
		await _despawn(tree, nodes)
		return {}
	check.call(_source_of(player) == _profile_source("FIXED"), "(%s) the Loader source is FIXED (got %d)" % [name, _source_of(player)])
	var state: LoaderState = player.loader_state()
	var entry_speed: float = state.stored_velocity.length()
	var energy_at_catch: float = player.arm_energy.value
	var slow: bool = false
	var guard: int = 0
	while _launches.is_empty() and guard < 60:
		if Engine.time_scale != 1.0:
			slow = true
		if state.update_count == 3:
			# Off the floor now: spend both airborne uses, so the launch must give back the Loader use and leave the dash spent.
			player.loader_available = false
			player.air_dash_available = false
		if press_rmb and state.update_count == 3:
			Input.action_press(&"loader")
		if press_rmb and state.update_count == 7:
			Input.action_release(&"loader")
		await tree.physics_frame
		guard += 1
	Input.action_release(&"loader")
	check.call(not slow and Engine.time_scale == 1.0, "(%s) Engine.time_scale stays 1.0 during the hold (no slow motion)" % name)
	check.call(_launches.size() == 1, "(%s) one launched fact (got %d)" % [name, _launches.size()])
	if _launches.size() != 1:
		await _despawn(tree, nodes)
		return {}
	var launch: Dictionary = _launches[0]
	var hold_ticks: int = roundi(_config_float(cannon, "fixed_hold", 0.2) * SHIPPED_TPS)
	var held: int = int(launch["update_count"])
	check.call(absi(held - hold_ticks) <= 1, "(%s) the hold lasts fixed_hold = %d ticks +-1 (got %d)" % [name, hold_ticks, held])
	var fixed_speed: float = _config_float(cannon, "fixed_speed", 14.0)
	var barrel: Vector3 = _barrel(cannon)
	var velocity: Vector3 = launch["velocity"] as Vector3
	check.call(absf(velocity.length() - fixed_speed) <= VELOCITY_TOLERANCE, "(%s) the launch speed is fixed_speed %.2f (got %.3f, entry %.2f)" % [name, fixed_speed, velocity.length(), entry_speed])
	check.call((velocity - barrel * fixed_speed).length() <= VELOCITY_TOLERANCE, "(%s) the launch goes exactly along the barrel (%s vs %s)" % [name, velocity, barrel * fixed_speed])
	var fact_direction: Vector3 = launch["direction"] as Vector3
	check.call((fact_direction.normalized() - barrel).length() < 0.001 and absf((launch["speed"] as float) - fixed_speed) < 0.001, "(%s) the launched fact carries the barrel direction and fixed_speed (%s, %.2f)" % [name, fact_direction, launch["speed"] as float])
	var mouth: Vector3 = breech + barrel * _config_float(cannon, "muzzle_offset", 1.2)
	var from_mouth: float = (launch["position"] as Vector3).distance_to(mouth)
	check.call(from_mouth <= MOUTH_TOLERANCE, "(%s) the launch point is the barrel mouth (%.3f m away)" % [name, from_mouth])
	check.call(player.loader_available, "(%s) the cannon gives the Loader use back" % name)
	check.call(launch["dash_available"] == false and player.air_dash_available == false, "(%s) the air dash stays spent (unattended decision 5)" % name)
	check.call(absf((launch["energy"] as float) - energy_at_catch) < 0.0001 and _spent.is_empty(), "(%s) the arm energy is untouched (%.3f -> %.3f, spent %s)" % [name, energy_at_catch, launch["energy"] as float, _spent])
	check.call(player.air_control_lock_timer > 0.0, "(%s) air control is locked after the launch" % name)
	if dash:
		check.call(entry_speed > config.run_speed + 2.0, "(%s) the dash entry is faster than a run (%.2f)" % [name, entry_speed])
	var apex: float = player.global_position.y
	for i: int in APEX_TICKS:
		await tree.physics_frame
		apex = maxf(apex, player.global_position.y)
	await _despawn(tree, nodes)
	return {"velocity": velocity, "apex": apex}


## Standing next to the breech (just outside the trigger) never fires.
func _scenario_beside(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree)
	var cannon: Node3D = nodes[1] as Node3D
	var radius: float = _config_float(cannon, "radius", 1.2)
	_player.teleport(cannon.global_position + Vector3(0.0, 0.0, radius + 0.9))
	_launches.clear()
	var caught: bool = false
	for i: int in 60:
		await tree.physics_frame
		if _is_loader(_player):
			caught = true
	check.call(not caught and _launches.is_empty(), "standing next to the breech never fires (caught %s, %d launches)" % [caught, _launches.size()])
	await _despawn(tree, nodes)
