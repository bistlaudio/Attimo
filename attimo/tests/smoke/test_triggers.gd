extends RefCounted
## MECH-01 / D-10, D-15, D-45: the Handrad-Ventil (toggle by near contact, turning wheel) and the Energiekern
## (self-timed, restarts on a new near contact). The shot is gone, so near contact is the only way in. The Uhrwerk-Kurbel was cut in plan 05.1-06 (D-09, KIT-04).

const Fixtures := preload("res://tests/fixtures.gd")

const VALVE_SCENE: String = "res://scenes/mechanisms/valve.tscn"
const CORE_SCENE: String = "res://scenes/mechanisms/energy_core.tscn"
const SHIPPED_TPS: int = 60


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	for path: String in [VALVE_SCENE, CORE_SCENE]:
		if not ResourceLoader.exists(path):
			check.call(false, "%s exists" % path)
			return
	await _scenario_valve(tree, check)
	await _scenario_core(tree, check)


func _interactable(node: Node) -> Interactable:
	return node.get_node("Interactable") as Interactable


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _scenario_valve(tree: SceneTree, check: Callable) -> void:
	var valve: Valve = Fixtures.spawn_scene(tree.root, VALVE_SCENE, Vector3(0.0, 0.0, 40.0)) as Valve
	await Fixtures.wait_physics(tree, 2)
	var interactable: Interactable = _interactable(valve)
	check.call(interactable.accepts_near, "valve: it accepts near contact")
	check.call(not valve.is_active, "valve: starts off")
	var wheel: Node3D = valve.get_node("Wheel") as Node3D
	var before: Basis = wheel.transform.basis
	check.call(interactable.near_begin(), "valve: a near contact is accepted")
	check.call(valve.is_active, "valve: the contact turns it on")
	await Fixtures.wait_physics(tree, 30)
	check.call(not wheel.transform.basis.is_equal_approx(before), "valve: the wheel turned within 0.5 s")
	interactable.near_begin()
	check.call(not valve.is_active, "valve: a second contact turns it off")
	await _free(tree, [valve])


func _scenario_core(tree: SceneTree, check: Callable) -> void:
	var core: EnergyCore = Fixtures.spawn_scene(tree.root, CORE_SCENE, Vector3(0.0, 0.0, 40.0)) as EnergyCore
	core.core_duration = 1.0
	await Fixtures.wait_physics(tree, 2)
	var interactable: Interactable = _interactable(core)
	check.call(interactable.accepts_near, "core: near contact is its only way in (D-45)")
	check.call(interactable.near_begin(), "core: a near contact is accepted")
	check.call(core.is_active, "core: on after the contact")
	await Fixtures.wait_physics(tree, 30)
	check.call(core.is_active, "core: still on at half time")
	interactable.near_begin()
	await Fixtures.wait_physics(tree, 42)
	check.call(core.is_active, "core: a new contact at half time restarts the full duration")
	await Fixtures.wait_physics(tree, 24)
	check.call(not core.is_active, "core: off after core_duration plus slack")
	await _free(tree, [core])
