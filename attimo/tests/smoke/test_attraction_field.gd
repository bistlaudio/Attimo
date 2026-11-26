extends RefCounted
## Plan 05.1-18 (KIT-01, KIT-02, ENRG-07, D-14, D-17, D-23 amended, D-37, D-39): the attraction field is the Force volume RADIAL profile. It pulls
## toward its core; walking out against the pull is always possible and free (T-05.1-54). A fast escape (a dash, a Loader flight, or moving away
## faster than escape_speed) suspends the pull and costs 1 step per started 0.5 s through the EnergyCost component; when the next step cannot be
## paid the pull resumes and one refusal fires. REPEL is cut. Classes are reached by path and get()/call(), so this file compiles before they
## exist (TDD RED).

const Fixtures := preload("res://tests/fixtures.gd")

const FIELD_SCENE: String = "res://scenes/kit/energy/attraction_field.tscn"
const FIELD_PRESET: String = "res://resources/kit/force_volume/attraction_field.tres"
const CONFIG_SCRIPT: String = "res://scripts/kit/configs/force_volume_config.gd"
const SHIPPED_TPS: int = 60
const PROFILE_RADIAL: int = 3
## The field is a sphere of radius size.x / 2 around a core point size.y / 2 above the node (preset 10 x 2 x 10: radius 5, core 1 m up).
const RADIUS: float = 5.0

var _saved_interval: float = 10.0
var _spent: Array = []
var _refused: Array = []
var _bus: Node


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	_bus = tree.root.get_node("EventBus")
	var all_there: bool = true
	for path: String in [FIELD_SCENE, FIELD_PRESET, CONFIG_SCRIPT]:
		var exists: bool = ResourceLoader.exists(path)
		check.call(exists, "%s exists" % path)
		all_there = all_there and exists
	if not all_there:
		return
	_scenario_look(check)
	await _scenario_pull(tree, check)
	await _scenario_walk_out(tree, check)
	await _scenario_dash_out(tree, check)
	await _scenario_empty_escape(tree, check)
	await _scenario_clock(tree, check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _free(tree: SceneTree, nodes: Array) -> void:
	for action: StringName in [&"move_forward", &"move_back", &"dash"]:
		Input.action_release(action)
	if _bus.is_connected(&"energy_spent", _on_spent):
		_bus.disconnect(&"energy_spent", _on_spent)
	if _bus.is_connected(&"energy_refused", _on_refused):
		_bus.disconnect(&"energy_refused", _on_refused)
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _on_spent(amount: int, reason: StringName) -> void:
	_spent.append([reason, amount])


func _on_refused(reason: StringName, needed: int) -> void:
	_refused.append([reason, needed])


func _count(list: Array, reason: StringName) -> int:
	var total: int = 0
	for entry: Array in list:
		if entry[0] == reason:
			total += 1
	return total


func _listen() -> void:
	_spent.clear()
	_refused.clear()
	_bus.connect(&"energy_spent", _on_spent)
	_bus.connect(&"energy_refused", _on_refused)


func _player(tree: SceneTree, at: Vector3) -> PlayerController:
	var player: PlayerController = Fixtures.spawn_player(tree.root, at)
	_saved_interval = player.config.energy_passive_interval
	player.config.energy_passive_interval = 100000.0
	return player


func _restore(player: PlayerController) -> void:
	player.config.energy_passive_interval = _saved_interval


func _glow_count(root: Node) -> int:
	var count: int = 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var script: Script = node.get_script() as Script
		if script != null and String(script.get_global_name()) == "GlowElement":
			count += 1
	return count


func _scenario_look(check: Callable) -> void:
	var config_script: GDScript = load(CONFIG_SCRIPT) as GDScript
	var profiles: Dictionary = config_script.get_script_constant_map().get("Profile", {}) as Dictionary
	check.call(profiles.has("RADIAL") and int(profiles.get("RADIAL", -1)) == PROFILE_RADIAL, "ForceVolumeConfig.Profile has RADIAL (%s)" % [profiles])
	check.call(not profiles.has("REPEL"), "no REPEL profile exists (cut, D-09)")
	var preset: Resource = load(FIELD_PRESET) as Resource
	check.call(int(preset.get("profile")) == PROFILE_RADIAL, "attraction_field.tres: profile RADIAL")
	check.call(float(preset.get("strength")) < 8.5, "attraction_field.tres: the pull target %.1f m/s is below the run speed 8.5 (T-05.1-54)" % float(preset.get("strength")))
	check.call(float(preset.get("escape_speed")) >= 8.5, "attraction_field.tres: escape_speed %.1f is not below the run speed" % float(preset.get("escape_speed")))
	var field: Node3D = (load(FIELD_SCENE) as PackedScene).instantiate() as Node3D
	check.call(int(field.get("layer")) == 1 and int(field.get("energy_relation")) == 1, "attraction field: ENERGY layer, energy relation COSTS")
	check.call(_glow_count(field) >= 1, "attraction field: carries a turquoise GlowElement")
	var costs: int = 0
	for node: Node in field.find_children("*", "", true, false):
		var script: Script = node.get_script() as Script
		if script != null and String(script.get_global_name()) == "EnergyCost":
			costs += 1
			check.call(is_equal_approx(float(node.get("interval")), 0.5) and int(node.get("steps")) == 1 and bool(node.get("pay_on_start")), "attraction field: EnergyCost 1 step per 0.5 s, paid when the escape starts")
	check.call(costs == 1, "attraction field: one EnergyCost child (%d)" % costs)
	field.free()


func _field(tree: SceneTree, config: Resource = null) -> Node3D:
	var field: Node3D = (load(FIELD_SCENE) as PackedScene).instantiate() as Node3D
	if config != null:
		field.set(&"config", config)
	tree.root.add_child(field)
	return field


func _flat_distance(player: PlayerController) -> float:
	return Vector2(player.global_position.x, player.global_position.z).length()


## Standing still inside is pulled toward the core.
func _scenario_pull(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var field: Node3D = _field(tree)
	var player: PlayerController = _player(tree, Vector3(0.0, 0.05, 3.5))
	Fixtures.set_energy(player, 6)
	_listen()
	await Fixtures.wait_physics(tree, 120)
	check.call(_flat_distance(player) < 2.0, "pull: a player standing 3.5 m from the core is pulled to %.2f m after 2 s" % _flat_distance(player))
	check.call(player.arm_energy.value == 6 and _spent.is_empty(), "pull: being pulled costs nothing (%d steps)" % player.arm_energy.value)
	_restore(player)
	await _free(tree, [field, player, floor_body])


## Walking out against the pull always works and is free (T-05.1-54).
func _scenario_walk_out(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var field: Node3D = _field(tree)
	var player: PlayerController = _player(tree, Vector3(0.0, 0.05, 3.0))
	Fixtures.set_energy(player, 6)
	_listen()
	await Fixtures.wait_physics(tree, 10)
	Input.action_press(&"move_back")
	var out: Callable = func() -> bool: return player.global_position.z > RADIUS + 1.0
	var ticks: int = await Fixtures.wait_until(tree, out, 3 * SHIPPED_TPS)
	Input.action_release(&"move_back")
	check.call(ticks >= 0, "walk out: against the pull the player leaves the field within 3 s (z %.2f)" % player.global_position.z)
	check.call(player.arm_energy.value == 6 and _count(_spent, &"escape") == 0, "walk out: the slow escape costs 0 steps (%d left, %d escape payments)" % [player.arm_energy.value, _count(_spent, &"escape")])
	check.call(not bool(field.call(&"is_pull_suspended")), "walk out: running speed never counts as a fast escape")
	_restore(player)
	await _free(tree, [field, player, floor_body])


## A dash out suspends the pull and pays 1 step on top of the dash cost.
func _scenario_dash_out(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var field: Node3D = _field(tree)
	var player: PlayerController = _player(tree, Vector3(0.0, 0.05, 3.0))
	Fixtures.set_energy(player, 6)
	_listen()
	await Fixtures.wait_physics(tree, 10)
	Input.action_press(&"move_back")
	await Fixtures.wait_physics(tree, 4)
	await Fixtures.tap_action(tree, &"dash", 2)
	await Fixtures.wait_physics(tree, 3)
	check.call(bool(field.call(&"is_pull_suspended")), "dash out: the pull is suspended while the paid escape runs")
	check.call(_count(_spent, &"escape") >= 1, "dash out: the escape paid a step (%d payments)" % _count(_spent, &"escape"))
	await Fixtures.wait_physics(tree, 60)
	Input.action_release(&"move_back")
	check.call(player.global_position.z > RADIUS, "dash out: the player is out of the field (z %.2f)" % player.global_position.z)
	check.call(_count(_refused, &"escape") == 0, "dash out: no refusal while the steps last")
	_restore(player)
	await _free(tree, [field, player, floor_body])


## At 0 steps after the dash the escape cannot be paid: the pull resumes and exactly one refusal fires.
func _scenario_empty_escape(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var field: Node3D = _field(tree)
	var player: PlayerController = _player(tree, Vector3(0.0, 0.05, 1.0))
	var dash_cost: int = player.config.dash_cost
	Fixtures.set_energy(player, dash_cost)
	_listen()
	await Fixtures.wait_physics(tree, 10)
	Input.action_press(&"move_back")
	await Fixtures.wait_physics(tree, 4)
	await Fixtures.tap_action(tree, &"dash", 2)
	await Fixtures.wait_physics(tree, 4)
	check.call(player.arm_energy.value == 0, "empty escape: the dash took the last step (%d)" % player.arm_energy.value)
	check.call(not bool(field.call(&"is_pull_suspended")), "empty escape: the pull is not suspended when the escape cannot be paid")
	check.call(_count(_refused, &"escape") == 1, "empty escape: exactly one energy_refused(escape) (%d)" % _count(_refused, &"escape"))
	await Fixtures.wait_physics(tree, 40)
	Input.action_release(&"move_back")
	check.call(_count(_refused, &"escape") == 1, "empty escape: the refusal does not repeat (%d)" % _count(_refused, &"escape"))
	check.call(_count(_spent, &"escape") == 0, "empty escape: nothing was paid for the escape")
	_restore(player)
	await _free(tree, [field, player, floor_body])


## The clock: with a low escape_speed and a wide field, running out counts as a fast escape and costs 1 step per started 0.5 s.
func _scenario_clock(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(120.0, 1.0, 120.0))
	var config: Resource = (load(FIELD_PRESET) as Resource).duplicate()
	config.set(&"size", Vector3(60.0, 2.0, 60.0))
	config.set(&"escape_speed", 2.0)
	var field: Node3D = _field(tree, config)
	var player: PlayerController = _player(tree, Vector3(0.0, 0.05, 2.0))
	Fixtures.set_energy(player, 12)
	_listen()
	await Fixtures.wait_physics(tree, 10)
	Input.action_press(&"move_back")
	await Fixtures.wait_physics(tree, 2 * SHIPPED_TPS)
	Input.action_release(&"move_back")
	var payments: int = _count(_spent, &"escape")
	check.call(payments >= 3 and payments <= 5, "clock: about 2 s of fast escape pay 3 to 5 steps, one per started 0.5 s (%d)" % payments)
	check.call(player.arm_energy.value == 12 - payments, "clock: the clock lost exactly the paid steps (%d left)" % player.arm_energy.value)
	_restore(player)
	await _free(tree, [field, player, floor_body])
