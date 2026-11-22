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
	check.call(ids.has(&"remote_trigger") and ids.has(&"dummy"), "the registry lists remote_trigger and dummy")
	check.call(registry.find(&"nope") == null, "find returns null for an unknown id")
	for def: HandModuleDef in registry.modules:
		var instance: Node = def.scene.instantiate() if def.scene != null else null
		check.call(instance is HandModule, "%s instantiates to a HandModule" % def.id)
		if instance != null:
			check.call(_count_meshes(instance) == 0, "%s carries no MeshInstance3D" % def.id)
			instance.free()

	var bus: Node = tree.root.get_node("EventBus")
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
	check.call(hand.active_def != null and hand.active_def.id == &"remote_trigger", "remote_trigger is equipped by default")
	check.call(hand.active_module is RemoteTrigger, "the active module is a RemoteTrigger")

	check.call(hand.equip(&"dummy"), "equip(dummy) succeeds")
	check.call(hand.active_module is DummyModule, "the active module is the dummy")
	check.call(not hand.equip(&"nope"), "equip of an unknown id fails")
	check.call(hand.active_def.id == &"dummy", "a failed equip keeps the active module")
	check.call(hand.equip(&"remote_trigger"), "equip(remote_trigger) succeeds")
	hand.cycle(1)
	check.call(hand.active_def.id == &"dummy", "cycle(1) from remote_trigger reaches the dummy")
	hand.cycle(1)
	check.call(hand.active_def.id == &"remote_trigger", "cycle wraps around")

	hand.equip(&"dummy")
	var pulses: Array = []
	var on_pulse: Callable = func(_o: Vector3, _p: Vector3, _s: int, _v: bool) -> void: pulses.append(1)
	bus.connect(&"pulse_fired", on_pulse)
	Input.action_press(&"aim")
	await Fixtures.wait_physics(tree, 4)
	await Fixtures.tap_action(tree, &"use_hand", 2)
	await Fixtures.wait_physics(tree, 3)
	var dummy: DummyModule = hand.active_module as DummyModule
	check.call(dummy != null and dummy.use_count == 1, "a tap while aiming reaches the dummy (use_count %d)" % (dummy.use_count if dummy != null else -1))
	check.call(pulses.is_empty(), "the dummy emits no pulse_fired")
	Input.action_release(&"aim")
	Input.action_release(&"use_hand")
	bus.disconnect(&"pulse_fired", on_pulse)
	floor_body.queue_free()
	player.queue_free()
	await tree.process_frame


func _count_meshes(node: Node) -> int:
	var count: int = 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _count_meshes(child)
	return count
