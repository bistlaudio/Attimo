extends RefCounted
## HAND-02 / D-45, D-46: the Interactable contract after the shot is gone. It is near contact only: accepts_near decides,
## near_begin / near_hold / near_end run it, the hit body sits on the Interactable layer and carries the back reference.


func run(tree: SceneTree, check: Callable) -> void:
	var bus: Node = tree.root.get_node("EventBus")
	var triggered_events: Array = []
	var on_triggered: Callable = func(_node: Node, kind: int) -> void: triggered_events.append(kind)
	bus.connect(&"interactable_triggered", on_triggered)

	var thing: Node3D = Node3D.new()
	var body: StaticBody3D = StaticBody3D.new()
	body.position = Vector3(1.0, 2.0, 3.0)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	thing.add_child(body)
	var target: Interactable = Interactable.new()
	target.hit_body = body
	thing.add_child(target)
	tree.root.add_child(thing)
	await tree.process_frame

	check.call(target.is_in_group(&"interactable"), "the node is in group interactable")
	check.call(body.collision_layer == PhysicsLayers.INTERACTABLE and body.collision_mask == 0, "the hit body is on the Interactable layer with mask 0")
	check.call(Interactable.from_collider(body) == target, "from_collider returns the component")
	check.call(Interactable.from_collider(null) == null, "from_collider(null) is null")
	check.call(target.target_point().is_equal_approx(Vector3(1.0, 2.0, 3.0)), "target_point falls back to the hit body position")

	var names: Array[String] = []
	for property: Dictionary in target.get_property_list():
		names.append(str(property["name"]))
	check.call(not names.has("accepts_shot") and not names.has("min_pulse") and not names.has("accepted_modules"), "D-46: no accepts_shot, min_pulse or accepted_modules property")
	check.call(not target.has_signal(&"triggered") and not target.has_method(&"try_trigger") and not target.has_method(&"can_accept"), "D-46: no triggered signal, try_trigger or can_accept")
	check.call(target.accepts_near == false, "accepts_near is off by default")

	var near_started: Array = []
	var near_held: Array = []
	var near_ended: Array = []
	target.near_started.connect(func() -> void: near_started.append(1))
	target.near_held.connect(func(_delta: float) -> void: near_held.append(1))
	target.near_ended.connect(func() -> void: near_ended.append(1))
	check.call(not target.near_begin() and triggered_events.is_empty() and near_started.is_empty(), "near_begin on accepts_near false returns false and emits nothing")
	target.accepts_near = true
	check.call(target.near_begin(), "near_begin on an accepts_near target returns true")
	# Kind 1 is the near contact (the value PulseHit.Kind.NEAR had).
	check.call(near_started.size() == 1 and triggered_events == [1], "near_begin emits near_started and interactable_triggered(NEAR) once")
	target.near_hold(0.016)
	target.near_end()
	check.call(near_held.size() == 1 and near_ended.size() == 1, "near_hold and near_end emit near_held and near_ended")

	bus.disconnect(&"interactable_triggered", on_triggered)
	thing.queue_free()
	await tree.process_frame

