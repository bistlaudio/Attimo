extends RefCounted
## HAND-02 / D-03, D-09, D-25: the Interactable contract. accepts_module and can_accept decide, try_trigger and
## near_begin enforce them, the hit body sits on the Interactable layer and carries the back reference.


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

	check.call(target.accepts_module(&"remote_trigger") and not target.accepts_module(&"dummy"), "default accepts remote_trigger only")
	var received: Array = []
	target.triggered.connect(func(hit: PulseHit) -> void: received.append(hit))
	check.call(not target.try_trigger(_hit(PulseHit.Kind.SHOT, PulseHit.Size.SMALL, &"dummy")), "a dummy hit is rejected")
	check.call(received.is_empty() and triggered_events.is_empty(), "a rejected hit emits nothing")

	var good: PulseHit = _hit(PulseHit.Kind.SHOT, PulseHit.Size.BIG, &"remote_trigger")
	good.point = Vector3(4.0, 5.0, 6.0)
	good.direction = Vector3(0.0, 0.0, -1.0)
	good.distance = 7.5
	good.collider = body
	check.call(target.try_trigger(good), "an accepted hit returns true")
	check.call(received.size() == 1 and received[0] == good, "triggered carries the same PulseHit")
	var kept: PulseHit = received[0] as PulseHit if received.size() == 1 else null
	check.call(kept != null and kept.size == PulseHit.Size.BIG and kept.point == Vector3(4.0, 5.0, 6.0) and kept.collider == body and is_equal_approx(kept.distance, 7.5), "size, point, collider and distance are intact")
	check.call(triggered_events == [int(PulseHit.Kind.SHOT)], "EventBus.interactable_triggered fired once with kind SHOT")

	target.accepts_shot = false
	check.call(not target.can_accept(PulseHit.Kind.SHOT, PulseHit.Size.BIG), "accepts_shot false rejects SHOT")
	target.accepts_shot = true
	target.min_pulse = PulseHit.Size.BIG
	check.call(not target.can_accept(PulseHit.Kind.SHOT, PulseHit.Size.SMALL), "min_pulse BIG rejects a small SHOT")
	check.call(target.can_accept(PulseHit.Kind.SHOT, PulseHit.Size.BIG), "min_pulse BIG accepts a big SHOT")
	check.call(not target.can_accept(PulseHit.Kind.NEAR, PulseHit.Size.BIG), "accepts_near false rejects NEAR")
	target.accepts_near = true
	check.call(target.can_accept(PulseHit.Kind.NEAR, PulseHit.Size.SMALL), "NEAR ignores the pulse size")

	triggered_events.clear()
	var near_started: Array = []
	target.near_started.connect(func() -> void: near_started.append(1))
	check.call(target.near_begin(), "near_begin on an accepts_near target returns true")
	check.call(near_started.size() == 1 and triggered_events == [int(PulseHit.Kind.NEAR)], "near_begin emits near_started and interactable_triggered(NEAR) once")
	target.accepts_near = false
	triggered_events.clear()
	check.call(not target.near_begin() and triggered_events.is_empty(), "near_begin on accepts_near false returns false and emits nothing")

	bus.disconnect(&"interactable_triggered", on_triggered)
	thing.queue_free()
	await tree.process_frame


func _hit(kind: PulseHit.Kind, size: PulseHit.Size, module_id: StringName) -> PulseHit:
	var hit: PulseHit = PulseHit.new()
	hit.kind = kind
	hit.size = size
	hit.module_id = module_id
	return hit
