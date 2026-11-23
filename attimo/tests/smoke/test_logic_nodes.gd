extends RefCounted
## MECH-02 / D-23: AND, OR and Timer truth tables, chaining, sources already active at load, and the
## Array[SignalSource] export round trip through PackedScene.pack (A1).

const Fixtures := preload("res://tests/fixtures.gd")

const AND_SCENE: String = "res://scenes/mechanisms/logic_and.tscn"
const OR_SCENE: String = "res://scenes/mechanisms/logic_or.tscn"
const TIMER_SCENE: String = "res://scenes/mechanisms/logic_timer.tscn"
const LEVER_SCENE: String = "res://scenes/mechanisms/lever.tscn"
const GATE_SCENE: String = "res://scenes/mechanisms/gear_gate.tscn"
const SHIPPED_TPS: int = 60
const OPEN_TICKS: int = 30

var _changes: Array[bool] = []


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_and(tree, check)
	await _scenario_or(tree, check)
	await _scenario_timer(tree, check)
	await _scenario_chain(tree, check)
	await _scenario_initial(tree, check)
	await _scenario_null_source(tree, check)
	await _scenario_round_trip(tree, check)
	await _scenario_scenes(tree, check)


func _source(tree: SceneTree) -> SignalSource:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	return source


func _typed(list: Array) -> Array[SignalSource]:
	var typed: Array[SignalSource] = []
	for item: Variant in list:
		typed.append(item as SignalSource)
	return typed


func _record(active: bool) -> void:
	_changes.append(active)


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _scenario_and(tree: SceneTree, check: Callable) -> void:
	var a: SignalSource = _source(tree)
	var b: SignalSource = _source(tree)
	var node: LogicAnd = LogicAnd.new()
	node.sources = _typed([a, b])
	tree.root.add_child(node)
	_changes.clear()
	node.active_changed.connect(_record)
	check.call(not node.is_active, "AND: off/off is off")
	a.set_active(true)
	check.call(not node.is_active, "AND: on/off is off")
	b.set_active(true)
	check.call(node.is_active, "AND: on/on is on")
	a.set_active(false)
	check.call(not node.is_active, "AND: back to off/on is off")
	check.call(_changes == [true, false], "AND emits only on change (%s)" % str(_changes))
	check.call(node.is_in_group(&"mechanism"), "AND joins group mechanism")
	b.set_active(true)
	check.call(_changes == [true, false], "AND does not re-emit for an equal value")
	await _free(tree, [a, b, node])


func _scenario_or(tree: SceneTree, check: Callable) -> void:
	var a: SignalSource = _source(tree)
	var b: SignalSource = _source(tree)
	var node: LogicOr = LogicOr.new()
	node.sources = _typed([a, b])
	tree.root.add_child(node)
	_changes.clear()
	node.active_changed.connect(_record)
	check.call(not node.is_active, "OR: off/off is off")
	a.set_active(true)
	check.call(node.is_active, "OR: on/off is on")
	b.set_active(true)
	check.call(node.is_active, "OR: on/on is on")
	a.set_active(false)
	check.call(node.is_active, "OR: off/on is on")
	b.set_active(false)
	check.call(not node.is_active, "OR: off/off is off again")
	check.call(_changes == [true, false], "OR emits only on change (%s)" % str(_changes))
	await _free(tree, [a, b, node])


func _timer(tree: SceneTree, source: SignalSource, hold: float, retrigger: bool) -> LogicTimer:
	var node: LogicTimer = LogicTimer.new()
	node.source = source
	node.hold_time = hold
	node.retriggerable = retrigger
	tree.root.add_child(node)
	return node


func _scenario_timer(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = _source(tree)
	var node: LogicTimer = _timer(tree, source, 0.5, true)
	await Fixtures.wait_physics(tree, 2)
	check.call(not node.is_active, "Timer: off before an edge")
	source.set_active(true)
	check.call(node.is_active, "Timer: a rising edge turns it on")
	await Fixtures.wait_physics(tree, 18)
	check.call(node.is_active, "Timer: still on at 0.3 s")
	source.set_active(false)
	await Fixtures.wait_physics(tree, 3)
	check.call(node.is_active, "Timer: the falling edge does not turn it off")
	await Fixtures.wait_physics(tree, 20)
	check.call(not node.is_active, "Timer: off after hold_time")
	# Retriggerable: a second edge at 0.3 s restarts the time.
	source.set_active(true)
	await Fixtures.wait_physics(tree, 18)
	source.set_active(false)
	source.set_active(true)
	await Fixtures.wait_physics(tree, 21)
	check.call(node.is_active, "Timer: a retriggerable restart keeps it on past the first period")
	await Fixtures.wait_physics(tree, 20)
	check.call(not node.is_active, "Timer: off one period after the restart")
	await _free(tree, [source, node])
	# Not retriggerable.
	var source2: SignalSource = _source(tree)
	var fixed: LogicTimer = _timer(tree, source2, 0.5, false)
	await Fixtures.wait_physics(tree, 2)
	source2.set_active(true)
	await Fixtures.wait_physics(tree, 18)
	source2.set_active(false)
	source2.set_active(true)
	await Fixtures.wait_physics(tree, 18)
	check.call(not fixed.is_active, "Timer: without retriggerable a second edge does not restart")
	await _free(tree, [source2, fixed])


func _scenario_chain(tree: SceneTree, check: Callable) -> void:
	var a: SignalSource = _source(tree)
	var b: SignalSource = _source(tree)
	var c: SignalSource = _source(tree)
	var or_node: LogicOr = LogicOr.new()
	or_node.sources = _typed([a, b])
	tree.root.add_child(or_node)
	var and_node: LogicAnd = LogicAnd.new()
	and_node.sources = _typed([or_node, c])
	tree.root.add_child(and_node)
	check.call(not and_node.is_active, "chain: AND(OR(a, b), c) starts off")
	b.set_active(true)
	check.call(not and_node.is_active, "chain: b alone is not enough")
	c.set_active(true)
	check.call(and_node.is_active, "chain: b and c turn it on")
	b.set_active(false)
	check.call(not and_node.is_active, "chain: b off turns it off")
	a.set_active(true)
	check.call(and_node.is_active, "chain: a and c turn it on")
	await _free(tree, [a, b, c, or_node, and_node])


func _scenario_initial(tree: SceneTree, check: Callable) -> void:
	var a: SignalSource = _source(tree)
	var b: SignalSource = _source(tree)
	a.set_active(true)
	b.set_active(true)
	var and_node: LogicAnd = LogicAnd.new()
	and_node.sources = _typed([a, b])
	tree.root.add_child(and_node)
	var or_node: LogicOr = LogicOr.new()
	or_node.sources = _typed([a])
	tree.root.add_child(or_node)
	check.call(and_node.is_active and or_node.is_active, "sources already active at _ready start the logic node active")
	await _free(tree, [a, b, and_node, or_node])


func _scenario_null_source(tree: SceneTree, check: Callable) -> void:
	var a: SignalSource = _source(tree)
	var and_node: LogicAnd = LogicAnd.new()
	and_node.sources = _typed([null, a])
	tree.root.add_child(and_node)
	a.set_active(true)
	check.call(and_node.is_active, "T-04-07: a null entry is skipped and the valid source counts")
	var empty: LogicAnd = LogicAnd.new()
	tree.root.add_child(empty)
	check.call(not empty.is_active, "T-04-07: an AND with no sources stays off")
	var orphan: LogicTimer = LogicTimer.new()
	tree.root.add_child(orphan)
	check.call(not orphan.is_active, "T-04-07: a Timer without a source stays off")
	await _free(tree, [a, and_node, empty, orphan])


func _scenario_round_trip(tree: SceneTree, check: Callable) -> void:
	for path: String in [AND_SCENE, LEVER_SCENE, GATE_SCENE]:
		if not ResourceLoader.exists(path):
			check.call(false, "%s exists" % path)
			return
	var root: Node3D = Node3D.new()
	root.name = "Rooms"
	var lever_a: Lever = (load(LEVER_SCENE) as PackedScene).instantiate() as Lever
	lever_a.name = "LeverA"
	var lever_b: Lever = (load(LEVER_SCENE) as PackedScene).instantiate() as Lever
	lever_b.name = "LeverB"
	lever_b.position = Vector3(10.0, 0.0, 0.0)
	var and_node: LogicAnd = (load(AND_SCENE) as PackedScene).instantiate() as LogicAnd
	and_node.name = "And"
	var gate: GearGate = (load(GATE_SCENE) as PackedScene).instantiate() as GearGate
	gate.name = "Gate"
	gate.position = Vector3(0.0, 0.0, 30.0)
	for node: Node in [lever_a, lever_b, and_node, gate]:
		root.add_child(node)
		node.owner = root
	var wired: Array[SignalSource] = [lever_a, lever_b]
	and_node.set("sources", wired)
	gate.source = and_node
	var packed: PackedScene = PackedScene.new()
	check.call(packed.pack(root) == OK, "the logic room packs")
	root.free()
	var copy: Node3D = packed.instantiate() as Node3D
	tree.root.add_child(copy)
	var new_and: LogicAnd = copy.get_node("And") as LogicAnd
	var new_a: Lever = copy.get_node("LeverA") as Lever
	var new_b: Lever = copy.get_node("LeverB") as Lever
	var new_gate: GearGate = copy.get_node("Gate") as GearGate
	check.call(new_and.sources.size() == 2, "the AND sources array keeps 2 entries (%d)" % new_and.sources.size())
	check.call(new_and.sources.size() == 2 and new_and.sources[0] == new_a and new_and.sources[1] == new_b, "the AND sources point at the new lever instances")
	check.call(new_gate.source == new_and, "the gate source points at the new AND")
	await Fixtures.wait_physics(tree, 2)
	var hit: PulseHit = PulseHit.new()
	hit.module_id = &"remote_trigger"
	(new_a.get_node("Interactable") as Interactable).try_trigger(hit)
	await Fixtures.wait_physics(tree, OPEN_TICKS)
	check.call(not new_gate.is_open(), "one lever does not open the AND gate")
	(new_b.get_node("Interactable") as Interactable).try_trigger(hit)
	await Fixtures.wait_physics(tree, OPEN_TICKS)
	check.call(new_gate.is_open(), "both levers open the AND gate after the round trip (A1)")
	await _free(tree, [copy])


func _scenario_scenes(tree: SceneTree, check: Callable) -> void:
	for path: String in [AND_SCENE, OR_SCENE, TIMER_SCENE]:
		if not ResourceLoader.exists(path):
			check.call(false, "%s exists" % path)
			continue
		var node: Node = (load(path) as PackedScene).instantiate()
		var only_lamp: bool = true
		for mesh_node: Node in node.find_children("*", "MeshInstance3D", true, false):
			only_lamp = only_lamp and mesh_node is GlowElement
		check.call(only_lamp, "%s has no mesh except its GlowElement lamp (04.1-04 look pass)" % path.get_file())
		node.free()
	if ResourceLoader.exists(TIMER_SCENE):
		var timer: LogicTimer = (load(TIMER_SCENE) as PackedScene).instantiate() as LogicTimer
		check.call(timer != null and is_equal_approx(timer.hold_time, 3.0), "logic_timer.tscn is a LogicTimer with hold_time 3")
		timer.free()
