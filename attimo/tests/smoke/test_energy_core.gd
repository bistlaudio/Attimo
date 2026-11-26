extends RefCounted
## Plan 05.1-18 (KIT-01, KIT-02, KIT-03, ENRG-07, D-14, D-20 amended, D-37, D-39, D-47): the energy core is a Trigger profile with a pay-in. Holding
## E beside it pays 1 step per 0.4 s (the EnergyCost component), letting go stops, the paid amount persists on the node, and the thresholds 3 / 6 / 9
## are the levels 1 / 2 / 3 that a LogicThreshold node turns into switch signals. At 0 steps the pay-in is refused once per hold. The core never gives
## steps back. EnergyCost: whole steps per interval, the first payment after the first interval (pay_on_start off) or at once (on), one refusal per
## episode, positive minimum for steps and interval (T-05.1-56). Classes are reached by path and get()/call(), so this file compiles before they exist
## (TDD RED).

const Fixtures := preload("res://tests/fixtures.gd")

const CORE_SCENE: String = "res://scenes/kit/energy/energy_core.tscn"
const CORE_PRESET: String = "res://resources/kit/trigger/energy_core.tres"
const COST_SCRIPT: String = "res://scripts/kit/components/energy_cost.gd"
const THRESHOLD_SCRIPT: String = "res://scripts/kit/logic/logic_threshold.gd"
const SHIPPED_TPS: int = 60
## The core stands 1.2 m ahead of the player: its aim point stays inside hand_near_range (2.2 m).
const CORE_AT: Vector3 = Vector3(0.0, 0.0, 1.2)
const PROFILE_ENERGY_CORE: int = 1

var _saved_interval: float = 10.0
var _refusals: Array = []
var _levels: Array[int] = []
var _bus: Node


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	_bus = tree.root.get_node("EventBus")
	var all_there: bool = true
	for path: String in [CORE_SCENE, CORE_PRESET, COST_SCRIPT, THRESHOLD_SCRIPT]:
		var exists: bool = ResourceLoader.exists(path)
		check.call(exists, "%s exists" % path)
		all_there = all_there and exists
	if not all_there:
		return
	_scenario_component(check)
	await _scenario_cost_ticks(tree, check)
	_scenario_look(tree, check)
	await _scenario_pay_in(tree, check)
	await _scenario_refusal(tree, check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _free(tree: SceneTree, nodes: Array) -> void:
	for action: StringName in [&"interact", &"move_forward", &"move_back"]:
		Input.action_release(action)
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _on_refused(reason: StringName, needed: int) -> void:
	_refusals.append([reason, needed])


func _refused_count(reason: StringName) -> int:
	var count: int = 0
	for entry: Array in _refusals:
		if entry[0] == reason:
			count += 1
	return count


## The property range minimum of a script export (hint_string "min,max,step").
func _range_min(script: GDScript, field: String) -> float:
	for property: Dictionary in script.get_script_property_list():
		if String(property["name"]) == field and int(property["hint"]) == PROPERTY_HINT_RANGE:
			return String(property["hint_string"]).split(",")[0].to_float()
	return -1.0


func _scenario_component(check: Callable) -> void:
	var script: GDScript = load(COST_SCRIPT) as GDScript
	check.call(String(script.get_global_name()) == "EnergyCost", "energy_cost.gd declares class_name EnergyCost")
	check.call(_range_min(script, "interval") > 0.0, "EnergyCost: the interval has a positive range minimum (T-05.1-56, %.2f)" % _range_min(script, "interval"))
	check.call(_range_min(script, "steps") >= 1.0, "EnergyCost: steps has a minimum of 1 (%.1f)" % _range_min(script, "steps"))
	var threshold: GDScript = load(THRESHOLD_SCRIPT) as GDScript
	check.call(String(threshold.get_global_name()) == "LogicThreshold", "logic_threshold.gd declares class_name LogicThreshold")


## EnergyCost on its own: the end-of-interval and the pay-on-start timing, whole steps, one refusal per episode.
func _scenario_cost_ticks(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = _player(tree, Vector3(0.0, 0.05, 0.0))
	_refusals.clear()
	_bus.connect(&"energy_refused", _on_refused)
	var cost: Node = (load(COST_SCRIPT) as GDScript).new() as Node
	cost.set(&"steps", 1)
	cost.set(&"interval", 0.5)
	cost.set(&"pay_on_start", false)
	tree.root.add_child(cost)
	Fixtures.set_energy(player, 5)
	var delta: float = 1.0 / float(SHIPPED_TPS)
	for tick_index: int in 72:
		cost.call(&"tick", player, delta, &"test_end")
	check.call(player.arm_energy.value == 3, "EnergyCost end-of-interval: 72 ticks of 1/60 s (1.2 s) at 0.5 s pay 2 steps, the first after 0.5 s (%d left)" % player.arm_energy.value)
	cost.call(&"end_episode")
	cost.set(&"pay_on_start", true)
	Fixtures.set_energy(player, 5)
	var first: bool = bool(cost.call(&"tick", player, delta, &"test_start"))
	check.call(first and player.arm_energy.value == 4, "EnergyCost pay-on-start: the very first tick pays 1 step (%d left)" % player.arm_energy.value)
	for tick_index: int in 28:
		cost.call(&"tick", player, delta, &"test_start")
	check.call(player.arm_energy.value == 4, "EnergyCost pay-on-start: no second payment before the interval is over (%d left)" % player.arm_energy.value)
	for tick_index: int in 3:
		cost.call(&"tick", player, delta, &"test_start")
	check.call(player.arm_energy.value == 3, "EnergyCost pay-on-start: the second payment comes after 0.5 s (%d left)" % player.arm_energy.value)
	# Whole steps, one refusal per episode.
	cost.call(&"end_episode")
	cost.set(&"steps", 2)
	Fixtures.set_energy(player, 1)
	var paid: bool = bool(cost.call(&"tick", player, delta, &"test_refuse"))
	for tick_index: int in 130:
		cost.call(&"tick", player, delta, &"test_refuse")
	check.call(not paid and player.arm_energy.value == 1, "EnergyCost: 2 steps are all or nothing, 1 step stays (%d)" % player.arm_energy.value)
	check.call(_refused_count(&"test_refuse") == 1, "EnergyCost: exactly one refusal per episode (%d)" % _refused_count(&"test_refuse"))
	cost.call(&"end_episode")
	cost.call(&"tick", player, delta, &"test_refuse")
	check.call(_refused_count(&"test_refuse") == 2, "EnergyCost: a new episode may refuse again (%d)" % _refused_count(&"test_refuse"))
	_bus.disconnect(&"energy_refused", _on_refused)
	_restore(player)
	await _free(tree, [cost, player, floor_body])


func _glow_count(root: Node) -> int:
	var count: int = 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var script: Script = node.get_script() as Script
		if script != null and String(script.get_global_name()) == "GlowElement":
			count += 1
	return count


func _scenario_look(tree: SceneTree, check: Callable) -> void:
	var preset: Resource = load(CORE_PRESET) as Resource
	var thresholds: PackedInt32Array = preset.get("thresholds") as PackedInt32Array
	check.call(int(preset.get("profile")) == PROFILE_ENERGY_CORE, "energy_core.tres: profile ENERGY_CORE (%d)" % int(preset.get("profile")))
	check.call(thresholds == PackedInt32Array([3, 6, 9]), "energy_core.tres: thresholds 3 / 6 / 9 (%s)" % [thresholds])
	var core: Node3D = (load(CORE_SCENE) as PackedScene).instantiate() as Node3D
	check.call(int(core.get("layer")) == 1 and int(core.get("energy_relation")) == 1, "energy core: ENERGY layer, energy relation COSTS (D-16)")
	check.call(_glow_count(core) >= 1, "energy core: carries a turquoise GlowElement")
	check.call(core.find_children("*", "Interactable", true, false).size() == 1, "energy core: one Interactable child")
	var cost_nodes: Array[Node] = []
	for node: Node in core.find_children("*", "", true, false):
		var script: Script = node.get_script() as Script
		if script != null and String(script.get_global_name()) == "EnergyCost":
			cost_nodes.append(node)
	check.call(cost_nodes.size() == 1, "energy core: one EnergyCost child (%d)" % cost_nodes.size())
	if cost_nodes.size() == 1:
		check.call(is_equal_approx(float(cost_nodes[0].get("interval")), 0.4) and int(cost_nodes[0].get("steps")) == 1, "energy core: pays 1 step per 0.4 s (F2 start value)")
		check.call(not bool(cost_nodes[0].get("pay_on_start")), "energy core: the first step is paid after the first interval")
	var interactable: Interactable = core.find_children("*", "Interactable", true, false)[0] as Interactable
	check.call(interactable.accepts_near, "energy core: near contact (hold E) is its way in")
	core.free()


func _player(tree: SceneTree, at: Vector3) -> PlayerController:
	var player: PlayerController = Fixtures.spawn_player(tree.root, at)
	_saved_interval = player.config.energy_passive_interval
	player.config.energy_passive_interval = 100000.0
	return player


func _restore(player: PlayerController) -> void:
	player.config.energy_passive_interval = _saved_interval


func _on_level(level: int) -> void:
	_levels.append(level)


func _hold(tree: SceneTree, seconds: float) -> void:
	await Fixtures.hold_action(tree, &"interact", seconds)
	await Fixtures.wait_physics(tree, 4)


func _scenario_pay_in(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(200.0, 1.0, 200.0))
	var player: PlayerController = _player(tree, Vector3.ZERO)
	var rig: CameraRig = Fixtures.spawn_camera_rig(tree.root, player)
	rig.pitch = 0.0
	var core: Node3D = Fixtures.spawn_scene(tree.root, CORE_SCENE, CORE_AT)
	var second: Node = (load(THRESHOLD_SCRIPT) as GDScript).new() as Node
	second.set(&"source", core)
	second.set(&"min_level", 2)
	tree.root.add_child(second)
	_levels.clear()
	core.connect(&"level_changed", _on_level)
	Fixtures.set_energy(player, 9)
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.wait_process(tree, 3)
	await _hold(tree, 1.25)
	check.call(int(core.get("paid")) == 3, "core: holding E for 1.25 s pays 3 steps (%d)" % int(core.get("paid")))
	check.call(int(core.get("level")) == 1 and bool(core.get("is_active")), "core: 3 paid steps are level 1 and active (%d)" % int(core.get("level")))
	check.call(_levels == [1], "core: level_changed(1) fired once (%s)" % [_levels])
	check.call(player.arm_energy.value == 6, "core: the 3 steps came off the clock (%d, expected 6)" % player.arm_energy.value)
	check.call(not bool(second.get("is_active")), "threshold node min_level 2: still off at level 1")
	await Fixtures.wait_physics(tree, 60)
	check.call(int(core.get("paid")) == 3 and player.arm_energy.value == 6, "core: letting go stops paying (paid %d, energy %d)" % [int(core.get("paid")), player.arm_energy.value])
	await _hold(tree, 0.9)
	check.call(int(core.get("paid")) == 5, "core: holding on later continues from the 3 paid (paid %d, expected 5)" % int(core.get("paid")))
	check.call(int(core.get("level")) == 1, "core: 5 paid steps are still level 1")
	await _hold(tree, 0.5)
	check.call(int(core.get("paid")) == 6 and int(core.get("level")) == 2, "core: 6 paid steps are level 2 (paid %d, level %d)" % [int(core.get("paid")), int(core.get("level"))])
	check.call(bool(second.get("is_active")), "threshold node min_level 2: on at level 2")
	check.call(_levels == [1, 2], "core: level_changed fired 1 then 2 (%s)" % [_levels])
	Fixtures.set_energy(player, 9)
	await _hold(tree, 1.3)
	check.call(int(core.get("paid")) == 9 and int(core.get("level")) == 3, "core: 9 paid steps are level 3 (paid %d, level %d)" % [int(core.get("paid")), int(core.get("level"))])
	var after_nine: int = player.arm_energy.value
	await _hold(tree, 1.0)
	check.call(int(core.get("paid")) == 9 and player.arm_energy.value == after_nine, "core: at level 3 it takes nothing more (paid %d, energy %d, expected %d)" % [int(core.get("paid")), player.arm_energy.value, after_nine])
	check.call(after_nine == 6, "core: the core never adds steps (%d, expected 6)" % after_nine)
	core.call(&"reset")
	check.call(int(core.get("paid")) == 0 and int(core.get("level")) == 0 and not bool(core.get("is_active")), "core: reset() empties it again (the reset sweep rule)")
	core.disconnect(&"level_changed", _on_level)
	await _free(tree, [second, core, rig, player, floor_body])


func _scenario_refusal(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(200.0, 1.0, 200.0))
	var player: PlayerController = _player(tree, Vector3.ZERO)
	var rig: CameraRig = Fixtures.spawn_camera_rig(tree.root, player)
	rig.pitch = 0.0
	var core: Node3D = Fixtures.spawn_scene(tree.root, CORE_SCENE, CORE_AT)
	_refusals.clear()
	_bus.connect(&"energy_refused", _on_refused)
	Fixtures.set_energy(player, 0)
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.wait_process(tree, 3)
	await _hold(tree, 1.5)
	check.call(int(core.get("paid")) == 0 and player.arm_energy.value == 0, "refusal: at 0 steps nothing is paid (paid %d)" % int(core.get("paid")))
	check.call(_refused_count(&"core") == 1, "refusal: exactly one energy_refused(core) per hold (%d)" % _refused_count(&"core"))
	check.call(_refusals.size() > 0 and int(_refusals[0][1]) == 1, "refusal: it names the 1 step needed")
	await _hold(tree, 1.5)
	check.call(_refused_count(&"core") == 2, "refusal: a second hold refuses once more (%d)" % _refused_count(&"core"))
	_bus.disconnect(&"energy_refused", _on_refused)
	_restore(player)
	await _free(tree, [core, rig, player, floor_body])
