extends RefCounted
## HAND-01 / D-24: the module registry, equip by id and by module_next, and the dummy module proving that a module is
## one folder plus one registry entry. Module scenes carry no mesh (the arm never changes).

const Fixtures := preload("res://tests/fixtures.gd")

const REGISTRY_PATH: String = "res://resources/hand/module_registry.tres"
const SHIPPED_TPS: int = 60


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	var registry: ModuleRegistry = load(REGISTRY_PATH) as ModuleRegistry
	check.call(registry != null, "module_registry.tres loads as a ModuleRegistry")
	if registry == null:
		return
	var ids: Array[StringName] = registry.ids()
	check.call(ids == [&"extractor", &"dummy"], "the registry lists the extractor and the debug dummy only, no shot module (%s)" % str(ids))
	check.call(not ResourceLoader.exists("res://scripts/hand/modules/remote_trigger/remote_trigger_def.tres"), "D-45: the remote_trigger module is deleted")
	check.call(registry.find(&"nope") == null, "find returns null for an unknown id")
	for def: HandModuleDef in registry.modules:
		var instance: Node = def.scene.instantiate() if def.scene != null else null
		check.call(instance is HandModule, "%s instantiates to a HandModule" % def.id)
		if instance != null:
			check.call(_count_meshes(instance) == 0, "%s carries no MeshInstance3D" % def.id)
			instance.free()

	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 4)
	var hand: HandController = player.get_node_or_null("HandController") as HandController
	check.call(hand != null, "the player has a HandController child")
	if hand == null:
		floor_body.queue_free()
		player.queue_free()
		await tree.process_frame
		return
	check.call(hand.is_in_group(&"hand_controller"), "the controller is in group hand_controller")
	check.call(hand.active_def != null and hand.active_def.id == &"extractor", "the extractor is equipped by default (D-45)")
	check.call(hand.active_module is Extractor, "the active module is an Extractor")
	check.call(hand.cycle_ids() == [&"extractor"], "cycle_ids has exactly the extractor; the dummy is debug-only (%s)" % str(hand.cycle_ids()))
	check.call(hand.cycle_ids().size() == 1, "the module switch is dormant: one wheel module")

	# A same-id equip never rebuilds the module (T-05.1-20).
	var running: HandModule = hand.active_module
	check.call(hand.equip(&"extractor") and is_same(hand.active_module, running), "equip of the already active id keeps the same module instance")
	# Wheel and number keys switch nothing while use_hand is held.
	Input.action_press(&"use_hand")
	await Fixtures.wait_physics(tree, 3)
	await Fixtures.tap_action(tree, &"module_next", 2)
	await Fixtures.tap_action(tree, &"module_prev", 2)
	await Fixtures.tap_action(tree, &"module_1", 2)
	await Fixtures.tap_action(tree, &"module_2", 2)
	await Fixtures.wait_physics(tree, 3)
	check.call(is_same(hand.active_module, running), "module_next, module_prev and the keys 1 and 2 leave the same module while use_hand is held")
	Input.action_release(&"use_hand")
	await Fixtures.wait_physics(tree, 3)

	check.call(hand.equip(&"dummy"), "equip(dummy) succeeds")
	check.call(hand.active_module is DummyModule, "the active module is the dummy")
	check.call(not hand.equip(&"nope"), "equip of an unknown id fails")
	check.call(hand.active_def.id == &"dummy", "a failed equip keeps the active module")
	hand.equip(&"dummy")
	await Fixtures.wait_physics(tree, 4)
	await Fixtures.tap_action(tree, &"use_hand", 2)
	await Fixtures.wait_physics(tree, 3)
	var dummy: DummyModule = hand.active_module as DummyModule
	check.call(dummy != null and dummy.use_count == 1, "a tap reaches the dummy without any hold (use_count %d)" % (dummy.use_count if dummy != null else -1))
	check.call(dummy.press_count == 1 and dummy.log.size() >= 3 and dummy.log[0] == &"pressed" and dummy.log[dummy.log.size() - 1] == &"released", "pressed, held, released reach the module in that order (%s)" % str(dummy.log))
	check.call(dummy.held_ticks >= 1, "on_use_held runs while the button is down (%d ticks)" % dummy.held_ticks)
	Input.action_press(&"use_hand")
	await Fixtures.wait_physics(tree, 3)
	hand.equip(&"extractor")
	check.call(dummy.deactivated, "switching modules mid-hold calls deactivate")
	var untouched: bool = hand.active_module is Extractor
	check.call(untouched, "the new module is active after the switch")
	Input.action_release(&"use_hand")
	floor_body.queue_free()
	player.queue_free()
	await tree.process_frame


func _count_meshes(node: Node) -> int:
	var count: int = 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _count_meshes(child)
	return count
