extends RefCounted
## Phase 4 puzzle rooms (D-26..D-29, ROADMAP criteria 3 and 4): the gym holds Zone_PuzzleRooms with three rooms behind the
## showcase. The test proves the coverage union, the wiring, the soft-lock guards (no stays_on, a FallReset with a room
## sweep), every reachability claim against docs/MOVEMENT-METRICS.md and a scripted solve of each room's signal graph.
##
## Contract the builder (tools/puzzle_rooms_builder.gd) stores on each room node, one source of truth for builder and test:
##   solve_order  Array[NodePath]  triggers (relative to the room) in the order the scripted solve fires them
##   solve_sizes  Array[int]       per trigger: 0 small shot, 1 big shot, -1 near contact (crank wind or near lever)
##   reach_checks Array[Dictionary] {from: NodePath, to: NodePath, rule: &"needs_mechanism" | &"reachable", via: StringName,
##                                   optional from_dy, to_dy (moving extent, metres) and gap_extra (metres)}
##   x_range      Vector2          the room's x extent, the respawn must lie inside

const Fixtures := preload("res://tests/fixtures.gd")

const GYM_SCENE: String = "res://scenes/test/movement_gym.tscn"
const ROOMS: Array[String] = ["PuzzleRoom_1", "PuzzleRoom_2", "PuzzleRoom_3"]
const MODULE: StringName = &"remote_trigger"
const SOLVE_TICKS: int = 60
const SWEEP_TICKS: int = 10
const RESPAWN_TOLERANCE: float = 1.5
const MARGIN: float = 0.3
## ## Long jump (dash hop), row "Long jump stage 3": 15.60 m, the longest horizontal reach of any verb.
const MAX_GAP_REACH: float = 15.6
## ## Jump, row "Jump 3 (pirouette)": 4.00 m, the highest ground jump.
const MAX_JUMP_RISE: float = 4.0
## ## Jump, row "Full jump (run)": 5.52 m distance, 2.00 m height; the single-jump reach a rider can count on.
const JUMP_GAP: float = 5.52
const JUMP_RISE: float = 2.0
## ## Jump, row "Jump 3 (pirouette)": 7.79 m distance, 4.00 m height (needs the jump chain).
const CHAIN_GAP: float = 7.79
## ## Long jump (dash hop), row "Long jump stage 1": 9.10 m distance, 2.00 m height.
const HOP_GAP: float = 9.10
## Horizontal air reach granted to a nozzle launch (air control is a tuning matter for the feel check).
const NOZZLE_GAP: float = 8.0
const UPDRAFT_GAP: float = 6.0
## Rise gravity 34 and fall multiplier 1.3 of resources/player/movement_default.tres (the config is read below).
const CONFIG_PATH: String = "res://resources/player/movement_default.tres"


func run(tree: SceneTree, check: Callable) -> void:
	var packed: PackedScene = load(GYM_SCENE) as PackedScene
	check.call(packed != null, "the movement gym loads")
	if packed == null:
		return
	var gym: Node = packed.instantiate()
	tree.root.add_child(gym)
	await Fixtures.wait_physics(tree, 30)

	_check_hip_fire_signs(gym, check)

	var zone: Node = gym.get_node_or_null("Zone_MechanismRooms/Zone_PuzzleRooms")
	check.call(zone != null, "Zone_PuzzleRooms exists inside Zone_MechanismRooms")
	if zone != null:
		var rooms: Array[Node3D] = []
		for room_name: String in ROOMS:
			var room: Node3D = zone.get_node_or_null(room_name) as Node3D
			check.call(room != null, "%s exists" % room_name)
			if room != null:
				rooms.append(room)
		if rooms.size() == ROOMS.size():
			_check_entry_plane(gym, zone, check)
			_check_union(rooms, check)
			for room: Node3D in rooms:
				_check_wiring(room, check)
				_check_exit_and_reset_nodes(room, check)
				_check_reach(room, check)
			await _check_reset_sweep(tree, gym, rooms[0], check)
			for room: Node3D in rooms:
				await _scripted_solve(tree, room, check)

	gym.queue_free()
	await gym.tree_exited


## D-20: the signs are written for hip fire. The Fernausloeser sign says LMB tap only, and no sign names the removed aim hold.
func _check_hip_fire_signs(gym: Node, check: Callable) -> void:
	var tracer: Label3D = gym.find_child("Label_Tracer", true, false) as Label3D
	check.call(tracer != null and tracer.text == "Fernauslöser: LMB tippen", "the Fernausloeser sign reads 'Fernauslöser: LMB tippen' (got %s)" % [tracer.text if tracer != null else "none"])
	var stale: Array[String] = []
	for node: Node in gym.find_children("*", "Label3D", true, false):
		var text: String = (node as Label3D).text
		if text.contains("RMB halten") or text.to_lower().contains("aim halten"):
			stale.append(text)
	check.call(stale.is_empty(), "no gym sign names the removed aim hold (%s)" % [stale])


## The doorway into puzzle room 1 stands in room 2's east wall plane (the puzzle group is shifted east, 04.1-05).
func _check_entry_plane(gym: Node, zone: Node, check: Callable) -> void:
	var entry: Node3D = zone.get_node_or_null("EntryGate") as Node3D
	var wall: Node3D = gym.get_node_or_null("Zone_MechanismRooms/Room2WallEast_0") as Node3D
	check.call(entry != null and wall != null, "EntryGate and Room2WallEast_0 exist")
	if entry != null and wall != null:
		check.call(absf(entry.global_position.x - wall.global_position.x) < 0.01, "EntryGate (x %.2f) stands in the room-2 east wall plane (x %.2f)" % [entry.global_position.x, wall.global_position.x])


# --- coverage -----------------------------------------------------------------------------------------------


func _collect(node: Node, found: Array[Node]) -> void:
	found.append(node)
	for child: Node in node.get_children():
		_collect(child, found)


func _all(rooms: Array[Node3D]) -> Array[Node]:
	var found: Array[Node] = []
	for room: Node3D in rooms:
		_collect(room, found)
	return found


func _count(nodes: Array[Node], predicate: Callable) -> int:
	var total: int = 0
	for node: Node in nodes:
		if predicate.call(node):
			total += 1
	return total


func _check_union(rooms: Array[Node3D], check: Callable) -> void:
	var nodes: Array[Node] = _all(rooms)
	var kinds: Dictionary = {
		"Lever": func(n: Node) -> bool: return n is Lever,
		"Valve": func(n: Node) -> bool: return n is Valve,
		"EnergyCore": func(n: Node) -> bool: return n is EnergyCore,
		"Crank": func(n: Node) -> bool: return n is Crank,
		"GearGate": func(n: Node) -> bool: return n is GearGate,
		"RotatingPlatform": func(n: Node) -> bool: return n is RotatingPlatform,
		"LiftPlatform": func(n: Node) -> bool: return n is LiftPlatform,
		"Conveyor": func(n: Node) -> bool: return n is Conveyor,
		"SteamNozzle": func(n: Node) -> bool: return n is SteamNozzle,
		"Pendulum": func(n: Node) -> bool: return n is Pendulum,
		"LogicAnd": func(n: Node) -> bool: return n is LogicAnd,
		"LogicOr": func(n: Node) -> bool: return n is LogicOr,
		"LogicTimer": func(n: Node) -> bool: return n is LogicTimer,
	}
	for kind: String in kinds:
		check.call(_count(nodes, kinds[kind]) >= 1, "the puzzle rooms use at least one %s" % kind)
	var big: int = _count(nodes, func(n: Node) -> bool: return n is Interactable and (n as Interactable).min_pulse == PulseHit.Size.BIG)
	check.call(big >= 1, "an Interactable needs the big pulse (min_pulse BIG)")
	var near_only: int = _count(nodes, func(n: Node) -> bool: return n is Interactable and (n as Interactable).accepts_near and not (n as Interactable).accepts_shot)
	check.call(near_only >= 1, "an Interactable accepts near contact only")
	var modes: Dictionary = {}
	for node: Node in nodes:
		if node is SteamNozzle:
			modes[(node as SteamNozzle).mode] = true
	check.call(modes.size() >= 3, "the puzzle rooms use at least three steam nozzle modes (got %d)" % modes.size())


# --- wiring and soft-lock guards ------------------------------------------------------------------------------


func _check_wiring(room: Node3D, check: Callable) -> void:
	var nodes: Array[Node] = []
	_collect(room, nodes)
	var bad_mechanism: int = 0
	var bad_logic: int = 0
	var stays: int = 0
	for node: Node in nodes:
		if node is Mechanism and (node as Mechanism).source == null:
			bad_mechanism += 1
		if (node is LogicAnd and (node as LogicAnd).sources.is_empty()) or (node is LogicOr and (node as LogicOr).sources.is_empty()):
			bad_logic += 1
		if node is LogicAnd:
			for source: SignalSource in (node as LogicAnd).sources:
				if source == null:
					bad_logic += 1
		if node is LogicOr:
			for source: SignalSource in (node as LogicOr).sources:
				if source == null:
					bad_logic += 1
		if node is LogicTimer and (node as LogicTimer).source == null:
			bad_logic += 1
		if (node is Lever and (node as Lever).stays_on) or (node is Valve and (node as Valve).stays_on):
			stays += 1
	check.call(bad_mechanism == 0, "%s: every Mechanism has a source (%d without)" % [room.name, bad_mechanism])
	check.call(bad_logic == 0, "%s: every logic node has resolved sources (%d bad)" % [room.name, bad_logic])
	check.call(stays == 0, "%s: no lever or valve has stays_on (%d)" % [room.name, stays])


func _check_exit_and_reset_nodes(room: Node3D, check: Callable) -> void:
	var gate: GearGate = room.get_node_or_null("ExitGate") as GearGate
	check.call(gate != null, "%s has an ExitGate (GearGate)" % room.name)
	var area: FallReset = room.get_node_or_null("FallReset") as FallReset
	check.call(area != null, "%s has a FallReset" % room.name)
	if area == null:
		return
	check.call(area.reset_root == room, "%s: the FallReset sweeps its own room (reset_root)" % room.name)
	check.call(area.respawn != null, "%s: the FallReset has a respawn marker" % room.name)
	var x_range: Vector2 = room.get_meta(&"x_range", Vector2.ZERO) as Vector2
	check.call(x_range.y > x_range.x, "%s stores x_range" % room.name)
	if area.respawn != null:
		var x: float = area.respawn.global_position.x
		check.call(x >= x_range.x and x <= x_range.y, "%s: the respawn (x %.1f) lies inside the room %s" % [room.name, x, x_range])


# --- reachability ---------------------------------------------------------------------------------------------


## Box AABB (world) of the solid World-layer shapes under `node`: the surface a rider can stand on at load time.
func _surface(node: Node) -> AABB:
	var found: Array[Node] = []
	_collect(node, found)
	var box: AABB = AABB()
	var first: bool = true
	for item: Node in found:
		var shape_node: CollisionShape3D = item as CollisionShape3D
		if shape_node == null or not shape_node.shape is BoxShape3D:
			continue
		var body: CollisionObject3D = shape_node.get_parent() as CollisionObject3D
		if body == null or body is Area3D or (body.collision_layer & PhysicsLayers.WORLD) == 0:
			continue
		var size: Vector3 = (shape_node.shape as BoxShape3D).size
		var world: AABB = shape_node.global_transform * AABB(-size * 0.5, size)
		box = world if first else box.merge(world)
		first = false
	return box


func _gap(a: AABB, b: AABB) -> float:
	var dx: float = maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dz: float = maxf(maxf(a.position.z - b.end.z, b.position.z - a.end.z), 0.0)
	return sqrt(dx * dx + dz * dz)


func _check_reach(room: Node3D, check: Callable) -> void:
	var config: MovementConfig = load(CONFIG_PATH) as MovementConfig
	var checks: Array = room.get_meta(&"reach_checks", []) as Array
	check.call(checks.size() >= 2, "%s stores reach_checks (got %d)" % [room.name, checks.size()])
	for entry: Variant in checks:
		var spec: Dictionary = entry as Dictionary
		var from_node: Node = room.get_node_or_null(spec.get("from", NodePath()) as NodePath)
		var to_node: Node = room.get_node_or_null(spec.get("to", NodePath()) as NodePath)
		var label: String = "%s %s -> %s (%s)" % [room.name, spec.get("from", ""), spec.get("to", ""), spec.get("via", "")]
		check.call(from_node != null and to_node != null, "%s: both nodes exist" % label)
		if from_node == null or to_node == null or config == null:
			continue
		var from_box: AABB = _surface(from_node)
		var to_box: AABB = _surface(to_node)
		var via_name: StringName = spec.get("via", &"") as StringName
		# A nozzle has no standing surface of its own: its volume position is the take-off point.
		var from_is_nozzle: bool = via_name == &"nozzle_apex" or via_name == &"updraft_jump" or via_name == &"cannon"
		check.call((from_box.size != Vector3.ZERO or from_is_nozzle) and to_box.size != Vector3.ZERO, "%s: both have a World surface" % label)
		var from_top: float = from_box.end.y + float(spec.get("from_dy", 0.0))
		var to_top: float = to_box.end.y + float(spec.get("to_dy", 0.0))
		var gap: float = _gap(from_box, to_box) + float(spec.get("gap_extra", 0.0))
		var rise: float = to_top - from_top
		var rule: StringName = spec.get("rule", &"") as StringName
		var via: StringName = spec.get("via", &"") as StringName
		if rule == &"needs_mechanism":
			check.call(gap > MAX_GAP_REACH or rise > MAX_JUMP_RISE, "%s: needs a mechanism (gap %.2f, rise %.2f, limits %.2f / %.2f)" % [label, gap, rise, MAX_GAP_REACH, MAX_JUMP_RISE])
		elif rule == &"reachable":
			var ok: bool = false
			var detail: String = ""
			match via:
				&"jump":
					ok = gap <= JUMP_GAP - MARGIN and rise <= JUMP_RISE - MARGIN
					detail = "single jump %.2f / %.2f" % [JUMP_GAP, JUMP_RISE]
				&"jump_chain":
					ok = gap <= CHAIN_GAP - MARGIN and rise <= MAX_JUMP_RISE - MARGIN
					detail = "jump chain %.2f / %.2f" % [CHAIN_GAP, MAX_JUMP_RISE]
				&"dash_hop":
					ok = gap <= HOP_GAP - MARGIN and rise <= JUMP_RISE - MARGIN
					detail = "dash hop %.2f / %.2f" % [HOP_GAP, JUMP_RISE]
				&"lift_top":
					var lift: LiftPlatform = from_node as LiftPlatform
					var raised: float = from_top + (lift.point_b - lift.point_a).y if lift != null else from_top
					ok = lift != null and absf(raised - to_top) <= MARGIN and gap <= 1.0
					detail = "lift top %.2f against ledge %.2f" % [raised, to_top]
				&"nozzle_apex":
					var nozzle: SteamNozzle = from_node as SteamNozzle
					var apex: float = 0.0
					if nozzle != null:
						apex = nozzle.launch_speed * nozzle.launch_speed / (2.0 * config.rise_gravity)
					var nozzle_gap: float = _gap(AABB(nozzle.global_position, Vector3.ZERO), to_box) if nozzle != null else INF
					ok = nozzle != null and apex - (to_top - nozzle.global_position.y) >= MARGIN and nozzle_gap <= NOZZLE_GAP
					detail = "apex %.2f over %.2f, gap %.2f" % [apex, to_top - (nozzle.global_position.y if nozzle != null else 0.0), nozzle_gap]
				&"updraft_jump":
					var column: SteamNozzle = from_node as SteamNozzle
					var column_height: float = 0.0
					var column_gap: float = INF
					if column != null:
						var volume_shape: CollisionShape3D = column.get_node("Volume/CollisionShape3D") as CollisionShape3D
						column_height = (volume_shape.shape as BoxShape3D).size.y
						column_gap = _gap(AABB(column.global_position, Vector3.ZERO), to_box)
					ok = column != null and column.mode == SteamNozzle.Mode.UPDRAFT and column_height + JUMP_RISE - MARGIN >= to_top - column.global_position.y and column_gap <= UPDRAFT_GAP
					detail = "column %.1f + jump %.1f, gap %.2f" % [column_height, JUMP_RISE, column_gap]
				&"cannon":
					var cannon: SteamNozzle = from_node as SteamNozzle
					var landing_ok: bool = false
					var shot_range: float = 0.0
					if cannon != null and cannon.mode == SteamNozzle.Mode.CANNON:
						var direction: Vector3 = cannon.push_direction()
						var horizontal: float = Vector3(direction.x, 0.0, direction.z).length()
						var vx: float = cannon.launch_speed * horizontal
						var vy: float = cannon.launch_speed * direction.y
						var fall_gravity: float = config.rise_gravity * config.fall_multiplier
						var apex: float = vy * vy / (2.0 * config.rise_gravity)
						var flight: float = vy / config.rise_gravity + sqrt(2.0 * (apex - (to_top - cannon.global_position.y)) / fall_gravity) if apex >= to_top - cannon.global_position.y else 0.0
						shot_range = vx * flight
						var near_edge: float = absf(to_box.position.x - cannon.global_position.x)
						var far_edge: float = absf(to_box.end.x - cannon.global_position.x)
						landing_ok = flight > 0.0 and shot_range <= far_edge - MARGIN and shot_range >= near_edge + MARGIN
					ok = landing_ok
					detail = "cannon range %.2f" % shot_range
			check.call(ok, "%s: reachable (gap %.2f, rise %.2f; %s)" % [label, gap, rise, detail])
		else:
			check.call(false, "%s: unknown rule %s" % [label, rule])


# --- signal solve and reset sweep -----------------------------------------------------------------------------


func _hit(size: int) -> PulseHit:
	var hit: PulseHit = PulseHit.new()
	hit.kind = PulseHit.Kind.SHOT
	hit.size = PulseHit.Size.BIG if size == 1 else PulseHit.Size.SMALL
	hit.module_id = MODULE
	return hit


## Fires one trigger the way the hand would: a shot of `size`, or near contact for -1 (a crank is wound, a near lever touched).
func _fire(trigger: Node, size: int) -> bool:
	var interactable: Interactable = trigger.get_node_or_null("Interactable") as Interactable
	if interactable == null:
		return false
	if size < 0:
		var began: bool = interactable.near_begin()
		interactable.near_hold(0.5)
		interactable.near_end()
		return began
	return interactable.try_trigger(_hit(size))


func _scripted_solve(tree: SceneTree, room: Node3D, check: Callable) -> void:
	var order: Array = room.get_meta(&"solve_order", []) as Array
	var sizes: Array = room.get_meta(&"solve_sizes", []) as Array
	check.call(order.size() >= 1 and order.size() == sizes.size(), "%s stores solve_order and solve_sizes of equal length" % room.name)
	var capsule: EnergySource = room.get_node_or_null(NodePath(str(room.get_meta(&"capsule", &"")))) as EnergySource
	check.call(capsule != null and capsule.respawn_time > 0.0, "%s stores the name of its respawning energy capsule in meta capsule (05-05, D-24)" % room.name)
	var gate: GearGate = room.get_node_or_null("ExitGate") as GearGate
	if gate == null or order.is_empty() or order.size() != sizes.size():
		return
	check.call(not gate.is_open(), "%s: the ExitGate is closed before the solve" % room.name)
	for index: int in order.size():
		var trigger: Node = room.get_node_or_null(order[index] as NodePath)
		check.call(trigger != null, "%s: solve step %d resolves (%s)" % [room.name, index, order[index]])
		if trigger != null:
			check.call(_fire(trigger, int(sizes[index])), "%s: solve step %d (%s) is accepted" % [room.name, index, order[index]])
	await Fixtures.wait_physics(tree, SOLVE_TICKS)
	check.call(gate.is_open(), "%s: the scripted solve opens the ExitGate within 1 s" % room.name)
	var lift: LiftPlatform = room.get_node_or_null("Lift") as LiftPlatform
	if lift != null:
		check.call(lift.signal_on, "%s: the solve raises the lift" % room.name)
	var belt: Conveyor = room.get_node_or_null("Conveyor") as Conveyor
	if belt != null:
		check.call(belt.signal_on, "%s: the crank reverses the conveyor" % room.name)
	_reset_room(room)
	await Fixtures.wait_physics(tree, 2)


func _reset_room(room: Node3D) -> void:
	var nodes: Array[Node] = []
	_collect(room, nodes)
	for node: Node in nodes:
		if node.is_in_group(&"mechanism") and node.has_method(&"reset"):
			node.call(&"reset")


func _check_reset_sweep(tree: SceneTree, gym: Node, room: Node3D, check: Callable) -> void:
	var player: PlayerController = gym.get_node_or_null("Player") as PlayerController
	var area: FallReset = room.get_node_or_null("FallReset") as FallReset
	check.call(player != null and area != null, "the reset sweep has a player and a FallReset")
	if player == null or area == null or area.respawn == null:
		return
	var order: Array = room.get_meta(&"solve_order", []) as Array
	var lever: Lever = null
	var core: EnergyCore = null
	for path: Variant in order:
		var node: Node = room.get_node_or_null(path as NodePath)
		if node is Lever and lever == null:
			lever = node as Lever
		if node is EnergyCore:
			core = node as EnergyCore
	check.call(lever != null and core != null, "%s has a lever and an energy core in its solve order" % room.name)
	if lever == null or core == null:
		return
	_fire(lever, 0)
	_fire(core, 0)
	check.call(lever.is_active and core.remaining > 0.0, "the sweep scenario starts with a lever on and the core running")
	player.teleport(area.global_position)
	await Fixtures.wait_physics(tree, SWEEP_TICKS)
	var distance: float = player.global_position.distance_to(area.respawn.global_position)
	check.call(distance <= RESPAWN_TOLERANCE, "the FallReset puts the player at the room respawn (%.2f m away)" % distance)
	var nodes: Array[Node] = []
	_collect(room, nodes)
	var bad: int = 0
	for node: Node in nodes:
		if not node.is_in_group(&"mechanism"):
			continue
		if node is SignalSource and (node as SignalSource).is_active != bool(node.get("start_active")):
			bad += 1
		if node is EnergyCore and (node as EnergyCore).remaining != 0.0:
			bad += 1
		if node is Mechanism and not (node as Mechanism).signal_on == (node.get("source") != null and (node.get("source") as SignalSource).is_active):
			bad += 1
		if node is GearGate and (node as GearGate).is_open():
			bad += 1
	check.call(bad == 0, "the room sweep puts every mechanism back to its load state (%d off)" % bad)
