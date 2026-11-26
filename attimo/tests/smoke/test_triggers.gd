extends RefCounted
## MECH-01 / D-10, D-15, D-45: the Energiekern (self-timed, restarts on a new near contact). The shot is gone, so near contact is the only way in. The Uhrwerk-Kurbel was cut in plan 05.1-06 and the Handrad-Ventil in plan 05.1-13 (D-09, D-46, KIT-03, KIT-04).

const Fixtures := preload("res://tests/fixtures.gd")

const CORE_SCENE: String = "res://scenes/mechanisms/energy_core.tscn"
const SHIPPED_TPS: int = 60


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	for path: String in [CORE_SCENE]:
		if not ResourceLoader.exists(path):
			check.call(false, "%s exists" % path)
			return
	await _scenario_core(tree, check)


func _interactable(node: Node) -> Interactable:
	return node.get_node("Interactable") as Interactable


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


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
