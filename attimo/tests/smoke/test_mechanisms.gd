extends RefCounted
## MECH-01 / D-15, D-17, D-19, D-26: the Lever toggles on every accepted hit, the Zahnrad-Tor follows its signal, never
## closes on the player, and the door instance pinned at yaw 90 slides along world +z. Plus the single-ref pack round trip.

const Fixtures := preload("res://tests/fixtures.gd")

const LEVER_SCENE: String = "res://scenes/mechanisms/lever.tscn"
const GATE_SCENE: String = "res://scenes/mechanisms/gear_gate.tscn"
const SHIPPED_TPS: int = 60
## 0.3 s open time plus slack, in ticks.
const OPEN_TICKS: int = 21
const SETTLE_TICKS: int = 30


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	if not ResourceLoader.exists(LEVER_SCENE) or not ResourceLoader.exists(GATE_SCENE):
		check.call(false, "lever.tscn and gear_gate.tscn exist")
		return
	await _scenario_lever(tree, check)
	await _scenario_gate(tree, check)
	await _scenario_pinned_door(tree, check)
	await _scenario_walk_through(tree, check)
	await _scenario_doorway_guard(tree, check)
	_scenario_round_trip(tree, check)


func _free_all(tree: SceneTree, nodes: Array[Node]) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
	await tree.process_frame


func _hit() -> PulseHit:
	var hit: PulseHit = PulseHit.new()
	hit.module_id = &"remote_trigger"
	hit.size = PulseHit.Size.SMALL
	return hit


func _lever(tree: SceneTree, position: Vector3) -> Lever:
	return Fixtures.spawn_scene(tree.root, LEVER_SCENE, position) as Lever


func _gate(tree: SceneTree, lever: Lever, position: Vector3, yaw_degrees: float = 0.0) -> GearGate:
	var gate: GearGate = (load(GATE_SCENE) as PackedScene).instantiate() as GearGate
	gate.source = lever
	gate.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), position)
	tree.root.add_child(gate)
	return gate


func _interactable(lever: Lever) -> Interactable:
	return lever.get_node("Interactable") as Interactable


func _scenario_lever(tree: SceneTree, check: Callable) -> void:
	var lever: Lever = _lever(tree, Vector3.ZERO)
	var stay: Lever = _lever(tree, Vector3(10.0, 0.0, 0.0))
	stay.stays_on = true
	await Fixtures.wait_physics(tree, 2)
	check.call(not lever.is_active, "the lever starts off")
	_interactable(lever).try_trigger(_hit())
	check.call(lever.is_active, "the first accepted hit turns it on")
	_interactable(lever).try_trigger(_hit())
	check.call(not lever.is_active, "the second turns it off")
	_interactable(lever).try_trigger(_hit())
	check.call(lever.is_active, "the third turns it on again")
	_interactable(stay).try_trigger(_hit())
	_interactable(stay).try_trigger(_hit())
	check.call(stay.is_active, "a stays_on lever stays on after a second hit")
	var changes: Array = []
	lever.active_changed.connect(func(active: bool) -> void: changes.append(active))
	lever.set_active(true)
	check.call(changes.is_empty(), "set_active emits only on change")
	lever.reset()
	check.call(not lever.is_active and changes == [false], "reset turns the lever off")
	await _free_all(tree, [lever, stay])


func _scenario_gate(tree: SceneTree, check: Callable) -> void:
	var lever: Lever = _lever(tree, Vector3(10.0, 0.0, 10.0))
	var gate: GearGate = _gate(tree, lever, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 3)
	var closed_centre: Vector3 = gate.gate_aabb().get_center()
	check.call(not gate.is_open(), "the gate starts closed")
	lever.set_active(true)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return gate.is_open(), OPEN_TICKS)
	check.call(waited >= 0, "the gate opens within 0.35 s of the signal (waited %d ticks)" % waited)
	lever.set_active(false)
	waited = await Fixtures.wait_until(tree, func() -> bool: return not gate.is_open(), OPEN_TICKS)
	check.call(waited >= 0, "the gate leaves the open state when the signal goes off")
	await Fixtures.wait_physics(tree, SETTLE_TICKS)
	check.call(gate.gate_aabb().get_center().distance_to(closed_centre) < 0.05, "the gate is closed again after the settle time")
	await _free_all(tree, [lever, gate])


func _scenario_pinned_door(tree: SceneTree, check: Callable) -> void:
	var lever: Lever = _lever(tree, Vector3(38.0, 0.0, -3.0))
	var gate: GearGate = _gate(tree, lever, Vector3(42.5, 0.0, 0.0), 90.0)
	await Fixtures.wait_physics(tree, 3)
	var closed_centre: Vector3 = gate.gate_aabb().get_center()
	lever.set_active(true)
	await Fixtures.wait_physics(tree, SETTLE_TICKS)
	var open_centre: Vector3 = gate.gate_aabb().get_center()
	check.call(not gate.gate_aabb().intersects(gate.doorway_aabb()), "the open gate box does not overlap the doorway box")
	check.call(absf(open_centre.x - closed_centre.x) < 0.01, "the yaw 90 gate moves along world z only (dx %.3f)" % (open_centre.x - closed_centre.x))
	check.call(open_centre.z - closed_centre.z > 4.0, "the yaw 90 gate slides toward world +z (dz %.2f)" % (open_centre.z - closed_centre.z))
	await _free_all(tree, [lever, gate])


func _walk(tree: SceneTree, open: bool) -> float:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(60.0, 1.0, 60.0))
	var lever: Lever = _lever(tree, Vector3(0.0, 0.0, 10.0))
	var gate: GearGate = _gate(tree, lever, Vector3.ZERO, 90.0)
	if open:
		lever.set_active(true)
	await Fixtures.wait_physics(tree, SETTLE_TICKS)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(-3.0, 0.0, 0.0))
	await Fixtures.wait_physics(tree, 10)
	await Fixtures.hold_action(tree, &"move_right", 1.5)
	var x: float = player.global_position.x
	await _free_all(tree, [player, lever, gate, floor_body])
	return x


func _scenario_walk_through(tree: SceneTree, check: Callable) -> void:
	var x_open: float = await _walk(tree, true)
	check.call(x_open > 2.0, "a player crosses the open doorway (x %.2f)" % x_open)
	var x_closed: float = await _walk(tree, false)
	check.call(x_closed < 0.0, "a player stays west of the closed gate (x %.2f)" % x_closed)


func _scenario_doorway_guard(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(60.0, 1.0, 60.0))
	var lever: Lever = _lever(tree, Vector3(10.0, 0.0, 10.0))
	var gate: GearGate = _gate(tree, lever, Vector3.ZERO)
	lever.set_active(true)
	await Fixtures.wait_physics(tree, SETTLE_TICKS)
	var closed_centre: Vector3 = gate.gate_aabb().get_center() - gate.slide_offset
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.1, 0.0))
	await Fixtures.wait_physics(tree, 10)
	lever.set_active(false)
	await Fixtures.wait_physics(tree, SETTLE_TICKS)
	check.call(gate.is_open(), "the gate stays open while the player overlaps the doorway")
	check.call(gate.gate_aabb().get_center().distance_to(closed_centre) > 3.0, "the gate did not move into the player")
	player.teleport(Vector3(0.0, 0.1, 10.0))
	await Fixtures.wait_physics(tree, 35)
	check.call(gate.gate_aabb().get_center().distance_to(closed_centre) < 0.05, "the gate closes after the player left the doorway")
	await _free_all(tree, [player, lever, gate, floor_body])


func _scenario_round_trip(tree: SceneTree, check: Callable) -> void:
	var root: Node3D = Node3D.new()
	root.name = "Rooms"
	var lever: Lever = (load(LEVER_SCENE) as PackedScene).instantiate() as Lever
	lever.name = "Lever"
	root.add_child(lever)
	lever.owner = root
	var gate: GearGate = (load(GATE_SCENE) as PackedScene).instantiate() as GearGate
	gate.name = "Gate"
	root.add_child(gate)
	gate.owner = root
	gate.source = lever
	var packed: PackedScene = PackedScene.new()
	check.call(packed.pack(root) == OK, "the room root packs")
	var copy: Node = packed.instantiate()
	var new_gate: GearGate = copy.get_node("Gate") as GearGate
	var new_lever: Node = copy.get_node("Lever")
	check.call(new_gate != null and new_gate.source != null and new_gate.source == new_lever, "the gate source survives a pack round trip")
	copy.free()
	root.free()
