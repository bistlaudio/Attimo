extends RefCounted
## MECH-01 / D-15, D-17, D-26: the Mechanism base follows its Trigger, runs the signal through _on_signal once per change,
## announces mechanism_changed, re-reads the source on reset without firing, and the exported source ref survives a pack round trip.
## Since plan 05.1-13 the signal driver is a plain Trigger fixture (the lever, valve and gear gate are cut, D-46) and the
## observing mechanism is a test-local Sink.

const Fixtures := preload("res://tests/fixtures.gd")

const SHIPPED_TPS: int = 60
const TIMER_SCENE: String = "res://scenes/mechanisms/logic_timer.tscn"

var _announced: Array[bool] = []


## A Mechanism that only records its signal changes.
class Sink extends Mechanism:
	var seen: Array[bool] = []

	func _on_signal(on: bool) -> void:
		seen.append(on)


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await tree.process_frame
	await _scenario_follow(tree, check)
	await _scenario_initial(tree, check)
	await _scenario_reset(tree, check)
	await _scenario_round_trip(tree, check)


func _on_changed(_node: Node, on: bool) -> void:
	_announced.append(on)


func _sink(tree: SceneTree, driver: Trigger) -> Sink:
	var sink: Sink = Sink.new()
	sink.source = driver
	tree.root.add_child(sink)
	return sink


func _free_all(tree: SceneTree, nodes: Array[Node]) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
	await tree.process_frame


func _scenario_follow(tree: SceneTree, check: Callable) -> void:
	var bus: Node = tree.root.get_node("EventBus")
	var driver: Trigger = Fixtures.spawn_signal_driver(tree.root)
	var sink: Sink = _sink(tree, driver)
	_announced.clear()
	bus.connect(&"mechanism_changed", _on_changed)
	check.call(not sink.signal_on and sink.is_in_group(&"mechanism"), "the mechanism starts off and joins the group mechanism")
	driver.set_active(true)
	check.call(sink.signal_on and sink.seen == [true], "the signal turning on reaches _on_signal once (%s)" % str(sink.seen))
	driver.set_active(true)
	check.call(sink.seen == [true], "an equal signal does not fire _on_signal again")
	driver.set_active(false)
	check.call(not sink.signal_on and sink.seen == [true, false], "the signal turning off reaches _on_signal (%s)" % str(sink.seen))
	check.call(_announced == [true, false], "mechanism_changed is announced for every change (%s)" % str(_announced))
	bus.disconnect(&"mechanism_changed", _on_changed)
	await _free_all(tree, [driver, sink])


func _scenario_initial(tree: SceneTree, check: Callable) -> void:
	var driver: Trigger = Fixtures.spawn_signal_driver(tree.root, true)
	var sink: Sink = _sink(tree, driver)
	check.call(driver.is_active and sink.signal_on, "a driver that starts active turns the mechanism on at _ready")
	await _free_all(tree, [driver, sink])


func _scenario_reset(tree: SceneTree, check: Callable) -> void:
	var driver: Trigger = Fixtures.spawn_signal_driver(tree.root, true)
	var sink: Sink = _sink(tree, driver)
	driver.set_active(false)
	check.call(not sink.signal_on, "the mechanism follows the driver off")
	sink.seen.clear()
	sink.reset()
	check.call(not sink.signal_on and sink.seen.is_empty(), "reset re-reads the source without firing _on_signal")
	driver.reset()
	check.call(driver.is_active and sink.signal_on, "a source that resets later corrects the mechanism through active_changed")
	await _free_all(tree, [driver, sink])


func _scenario_round_trip(tree: SceneTree, check: Callable) -> void:
	if not ResourceLoader.exists(TIMER_SCENE):
		check.call(false, "%s exists" % TIMER_SCENE)
		return
	var root: Node3D = Node3D.new()
	root.name = "Rooms"
	var driver: Trigger = Trigger.new()
	driver.name = "Driver"
	root.add_child(driver)
	driver.owner = root
	var timer: LogicTimer = (load(TIMER_SCENE) as PackedScene).instantiate() as LogicTimer
	timer.name = "Timer"
	root.add_child(timer)
	timer.owner = root
	timer.source = driver
	var packed: PackedScene = PackedScene.new()
	check.call(packed.pack(root) == OK, "the room root packs")
	var copy: Node = packed.instantiate()
	var new_timer: LogicTimer = copy.get_node("Timer") as LogicTimer
	check.call(new_timer != null and new_timer.source != null and new_timer.source == copy.get_node("Driver"), "the exported source survives a pack round trip")
	copy.free()
	root.free()
