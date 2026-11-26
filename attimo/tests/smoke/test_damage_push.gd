extends RefCounted
## Plan 05.1-20 (KIT-01, KIT-02, D-09, D-11, D-14, D-15, D-17): the DamagePush component and the steampunk obstacles on Timed motion.
## Pendulum (SWING), piston wall (STAMP along -Z) and steam hammer (STAMP from above) push the player on contact through
## PlayerController.knock_back and announce EventBus.player_hit(amount: int, position: Vector3, source_id: StringName), a fact with values
## only (no node, T-05.1-61). A second contact inside rehit_time reports nothing (T-05.1-60). Kit damage never kills or respawns in this
## phase (D-15): the player stays alive, in the world, and the hammer pushes sideways instead of crushing (T-05.1-59). Real player, real
## geometry, 60 Hz. Classes are reached by path and call() where possible, so the file compiles before DamagePush exists (TDD RED).

const Fixtures := preload("res://tests/fixtures.gd")

const COMPONENT_SCRIPT: String = "res://scripts/kit/components/damage_push.gd"
const PENDULUM_SCENE: String = "res://scenes/kit/steampunk/pendulum.tscn"
const PISTON_SCENE: String = "res://scenes/kit/steampunk/piston_wall.tscn"
const HAMMER_SCENE: String = "res://scenes/kit/steampunk/steam_hammer.tscn"
const PENDULUM_PRESET: String = "res://resources/kit/timed_motion/pendulum.tres"
const PISTON_PRESET: String = "res://resources/kit/timed_motion/piston_wall.tres"
const HAMMER_PRESET: String = "res://resources/kit/timed_motion/steam_hammer.tres"
const SHIPPED_TPS: int = 60
## The pivot of the pendulum stands this high over the floor (the old arm frame, plan 05.1-20 keeps the tuned numbers).
const PENDULUM_PIVOT: float = 5.0
## The hammer's retracted head bottom stands this high over the floor (3 m stroke plus 0.05 m of clearance).
const HAMMER_TOP: float = 3.05

var _hits: Array[Dictionary] = []
var _knocks: int = 0
var _knock_probe: PlayerController = null
var _knock_dir: Vector3 = Vector3.ZERO
var _knock_along: Array[float] = []


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	var component_there: bool = ResourceLoader.exists(COMPONENT_SCRIPT)
	check.call(component_there, "%s exists" % COMPONENT_SCRIPT)
	_check_fact_signature(check)
	_check_profiles(check)
	EventBus.knocked_back.connect(_on_knocked)
	if EventBus.has_signal(&"player_hit"):
		EventBus.connect(&"player_hit", _on_hit)
	await _scenario_pendulum(tree, check)
	await _scenario_piston(tree, check)
	await _scenario_hammer(tree, check)
	await _scenario_rehit(tree, check)
	EventBus.knocked_back.disconnect(_on_knocked)
	if EventBus.has_signal(&"player_hit"):
		EventBus.disconnect(&"player_hit", _on_hit)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _on_knocked(_position: Vector3, _impulse: Vector3) -> void:
	_knocks += 1
	if _knock_probe != null:
		_knock_along.append(Vector3(_knock_probe.move_velocity.x, 0.0, _knock_probe.move_velocity.z).dot(_knock_dir))


func _on_hit(amount: int, position: Vector3, source_id: StringName) -> void:
	_hits.append({"amount": amount, "position": position, "source": source_id})


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _reset_counters() -> void:
	_hits.clear()
	_knocks = 0
	_knock_along.clear()


## player_hit carries int, Vector3 and StringName and no node reference (T-05.1-61, D-17).
func _check_fact_signature(check: Callable) -> void:
	var found: bool = false
	var types: Array[int] = []
	for entry: Dictionary in EventBus.get_signal_list():
		if String(entry["name"]) == "player_hit":
			found = true
			for argument: Dictionary in entry["args"] as Array:
				types.append(int(argument["type"]))
	check.call(found, "EventBus declares player_hit")
	check.call(types == [TYPE_INT, TYPE_VECTOR3, TYPE_STRING_NAME], "player_hit carries (int, Vector3, StringName) and no object (%s)" % [types])


## SWING and STAMP are appended to the Timed motion profile enum, the presets keep the old tuned numbers (D-11, D-09).
func _check_profiles(check: Callable) -> void:
	var config_script: GDScript = load("res://scripts/kit/configs/timed_motion_config.gd") as GDScript
	var profiles: Dictionary = config_script.get_script_constant_map().get("Profile", {}) as Dictionary
	check.call(profiles.has("SWING") and profiles.has("STAMP"), "the Timed motion Profile enum has SWING and STAMP (%s)" % [profiles])
	check.call(int(profiles.get("SWING", -1)) == 5 and int(profiles.get("STAMP", -1)) == 6, "SWING and STAMP are appended after STEPS (5, 6)")
	var pendulum: Resource = load(PENDULUM_PRESET) if ResourceLoader.exists(PENDULUM_PRESET) else null
	check.call(pendulum != null and is_equal_approx(float(pendulum.get(&"swing_amplitude_deg")), 60.0) and is_equal_approx(float(pendulum.get(&"swing_period")), 2.4), "the pendulum preset keeps the old 60 degrees and 2.4 s")
	var piston: Resource = load(PISTON_PRESET) if ResourceLoader.exists(PISTON_PRESET) else null
	var piston_ok: bool = piston != null and is_equal_approx(float(piston.get(&"stamp_distance")), 3.0) and is_equal_approx(float(piston.get(&"stamp_hold")), 0.3)
	check.call(piston_ok and (piston.get(&"stamp_axis") as Vector3).is_equal_approx(Vector3(0.0, 0.0, -1.0)), "the piston wall preset keeps the old 3 m reach along -Z and the 0.3 s hold")
	var hammer: Resource = load(HAMMER_PRESET) if ResourceLoader.exists(HAMMER_PRESET) else null
	var hammer_ok: bool = hammer != null and is_equal_approx(float(hammer.get(&"stamp_distance")), 3.0) and is_equal_approx(float(hammer.get(&"stamp_period")), 2.4) and is_equal_approx(float(hammer.get(&"stamp_hold")), 0.3)
	check.call(hammer_ok and (hammer.get(&"stamp_axis") as Vector3).is_equal_approx(Vector3(0.0, -1.0, 0.0)), "the steam hammer preset stamps down 3 m, period 2.4 s, hold 0.3 s")


func _spawn(path: String, check: Callable, at: Vector3) -> Node3D:
	if not ResourceLoader.exists(path):
		check.call(false, "scene %s exists" % path)
		return null
	return Fixtures.spawn_scene(Engine.get_main_loop().root, path, at)


func _component(block: Node) -> Node:
	for child: Node in block.get_children():
		if child.get_script() != null and String((child.get_script() as GDScript).get_global_name()) == "DamagePush":
			return child
	return null


func _hit_area_ok(block: Node, check: Callable, label: String) -> void:
	var push: Node = _component(block)
	check.call(push != null, "%s carries a DamagePush child" % label)
	if push == null:
		return
	var area: Area3D = push.get(&"hit_area") as Area3D
	check.call(area != null and area.collision_layer == PhysicsLayers.HAZARD and area.collision_mask == PhysicsLayers.PLAYER, "%s: the hit area is on HAZARD and masks the Player" % label)


## Pendulum (SWING): the old amplitude, a hit knocks with the old impulse, reports once, never kills.
func _scenario_pendulum(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var pendulum: Node3D = _spawn(PENDULUM_SCENE, check, Vector3(0.0, PENDULUM_PIVOT, 0.0))
	if pendulum == null:
		await _free(tree, [floor_body])
		return
	_hit_area_ok(pendulum, check, "pendulum")
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(2.5, 0.0, 0.0))
	_reset_counters()
	var peak: float = 0.0
	var waited: int = -1
	for tick: int in 2 * SHIPPED_TPS:
		await Fixtures.wait_physics(tree, 1)
		peak = maxf(peak, absf(float(pendulum.call(&"current_angle"))))
		if _hits.size() >= 1 and waited < 0:
			waited = tick
	check.call(waited >= 0, "pendulum: a hit is reported within 2 s (%d ticks)" % waited)
	check.call(peak > deg_to_rad(40.0) and peak <= deg_to_rad(60.0) + 0.01, "pendulum: the swing keeps the old amplitude (peak %.1f degrees, at most 60)" % rad_to_deg(peak))
	check.call(_hits.size() >= 1 and int(_hits[0]["amount"]) == 1 and StringName(_hits[0]["source"]) == StringName(pendulum.name), "pendulum: player_hit(1, position, &\"%s\") fired (%s)" % [pendulum.name, _hits])
	check.call(_hits.size() == 1, "pendulum: exactly one hit for the first contact (%d)" % _hits.size())
	check.call(_knocks >= 1, "pendulum: the player was knocked back through knock_back (%d)" % _knocks)
	check.call(is_instance_valid(player) and player.global_position.y > -1.0, "pendulum: the player is still alive in the world, no respawn (y %.2f)" % player.global_position.y)
	await _free(tree, [pendulum, player, floor_body])


## Piston wall (STAMP along -Z): rests, slams out, knocks the player in front of it once and reports it.
func _scenario_piston(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var piston: Node3D = _spawn(PISTON_SCENE, check, Vector3.ZERO)
	if piston == null:
		await _free(tree, [floor_body])
		return
	_hit_area_ok(piston, check, "piston wall")
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, -2.0))
	await Fixtures.wait_physics(tree, 5)
	_reset_counters()
	_knock_probe = player
	_knock_dir = Vector3(0.0, 0.0, -1.0)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return _hits.size() >= 1, 8 * SHIPPED_TPS)
	_knock_probe = null
	check.call(waited >= 0, "piston wall: the slam hits the player in front within one cycle (%d ticks)" % waited)
	check.call(_knocks == 1, "piston wall: exactly one knock for the slam (%d)" % _knocks)
	check.call(_knock_along.size() > 0 and _knock_along[0] > 6.0, "piston wall: the speed along the push direction right after the knock is %.2f m/s (above 6)" % (_knock_along[0] if _knock_along.size() > 0 else 0.0))
	check.call(_hits.size() >= 1 and StringName(_hits[0]["source"]) == StringName(piston.name), "piston wall: player_hit names the block (%s)" % [_hits])
	var rest: Vector3 = (piston.call(&"body") as Node3D).position
	check.call(rest.z <= 0.0, "piston wall: the head moves along -Z (z %.2f)" % rest.z)
	await Fixtures.wait_physics(tree, 5 * SHIPPED_TPS)
	var retracted: Vector3 = (piston.call(&"body") as Node3D).position
	check.call(is_instance_valid(player) and player.global_position.y > -1.0, "piston wall: the player is alive in the world, no respawn")
	check.call(retracted.length() <= 3.01, "piston wall: the head never travels past the 3 m reach (%.2f)" % retracted.length())
	await _free(tree, [piston, player, floor_body])


## Steam hammer (STAMP from above): stamps down and rises on its period, a player under it is pushed out sideways, not crushed.
func _scenario_hammer(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var hammer: Node3D = _spawn(HAMMER_SCENE, check, Vector3(0.0, HAMMER_TOP, 0.0))
	if hammer == null:
		await _free(tree, [floor_body])
		return
	_hit_area_ok(hammer, check, "steam hammer")
	var body: Node3D = hammer.call(&"body") as Node3D
	var low: float = 0.0
	var high: float = -INF
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.6, 0.0, 0.0))
	await Fixtures.wait_physics(tree, 5)
	_reset_counters()
	var waited: int = -1
	for tick: int in 6 * SHIPPED_TPS:
		await Fixtures.wait_physics(tree, 1)
		low = minf(low, body.position.y)
		high = maxf(high, body.position.y)
		if _hits.size() >= 1 and waited < 0:
			waited = tick
	check.call(waited >= 0, "steam hammer: a player under it is hit within the cycle (%d ticks)" % waited)
	check.call(low < -2.5 and high >= -0.01, "steam hammer: the head stamps about 3 m down and rises back (%.2f .. %.2f)" % [low, high])
	var flat: Vector2 = Vector2(player.global_position.x - hammer.global_position.x, player.global_position.z - hammer.global_position.z)
	check.call(flat.length() > 1.6, "steam hammer: the player ends outside the 3 m footprint, pushed sideways (%.2f m from the centre)" % flat.length())
	check.call(player.global_position.y > -0.2, "steam hammer: the player is not crushed into the floor (y %.2f)" % player.global_position.y)
	check.call(_hits.size() >= 1 and StringName(_hits[0]["source"]) == StringName(hammer.name), "steam hammer: player_hit names the block (%s)" % [_hits])
	await _free(tree, [hammer, player, floor_body])


## The rehit window: a player held inside the hit area reports once per rehit_time, never every tick (T-05.1-60).
func _scenario_rehit(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var hammer: Node3D = _spawn(HAMMER_SCENE, check, Vector3(0.0, HAMMER_TOP, 0.0))
	if hammer == null:
		await _free(tree, [floor_body])
		return
	var push: Node = _component(hammer)
	if push == null:
		check.call(false, "rehit: the hammer carries a DamagePush")
		await _free(tree, [hammer, floor_body])
		return
	var rehit: float = float(push.get(&"rehit_time"))
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 0.0))
	# Park the player inside the area every tick (no motion of its own is written, only its placement for the test).
	var area: Area3D = push.get(&"hit_area") as Area3D
	_reset_counters()
	var ticks: int = 2 * SHIPPED_TPS
	for tick: int in ticks:
		player.global_position = area.global_position
		await Fixtures.wait_physics(tree, 1)
	var most: int = int(ceil(float(ticks) / (rehit * float(SHIPPED_TPS)))) + 1
	check.call(_hits.size() >= 1 and _hits.size() <= most, "rehit: %d reports in 2 s with a %.2f s rehit window (at most %d)" % [_hits.size(), rehit, most])
	await _free(tree, [hammer, player, floor_body])
