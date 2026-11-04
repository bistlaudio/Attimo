extends RefCounted
## D-12 debug event log: starts hidden, auto-connects to every EventBus signal, caps at 14 lines, toggles on debug_event_log, is not an autoload.

const LOG_SCENE: String = "res://scenes/debug/event_log.tscn"


func _press(tree: SceneTree, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"debug_event_log"
	event.pressed = pressed
	tree.root.push_input(event)


func run(tree: SceneTree, check: Callable) -> void:
	var bus: Node = tree.root.get_node("EventBus")
	var scene: PackedScene = load(LOG_SCENE) as PackedScene
	check.call(scene != null, "event_log.tscn loads")
	var log_node: EventLog = scene.instantiate() as EventLog
	tree.root.add_child(log_node)
	await tree.process_frame

	check.call(not log_node.visible, "overlay starts hidden")

	# Auto-connect: every script signal on the bus has a connection targeting the log node.
	var signal_list: Array[Dictionary] = bus.get_script().get_script_signal_list()
	check.call(signal_list.size() >= 4, "bus declares at least four signals (got %d)" % signal_list.size())
	for sig: Dictionary in signal_list:
		var connected: bool = false
		for connection: Dictionary in bus.get_signal_connection_list(sig.name):
			var target: Callable = connection.callable
			if target.get_object() == log_node:
				connected = true
		check.call(connected, "log is connected to signal %s" % sig.name)

	# Content: one of each fact, in order.
	var order: Array[StringName] = [&"jumped", &"landed", &"dash_started", &"movement_state_changed"]
	bus.emit_signal(&"jumped", Vector3(1, 2, 3))
	bus.emit_signal(&"landed", Vector3.ZERO, 6.5)
	bus.emit_signal(&"dash_started", Vector3.ZERO, Vector3.FORWARD, true)
	bus.emit_signal(&"movement_state_changed", &"Idle", &"Jump")
	check.call(log_node.lines.size() == 4, "four facts produce four lines (got %d)" % log_node.lines.size())
	for i: int in mini(order.size(), log_node.lines.size()):
		check.call(log_node.lines[i].contains(String(order[i])), "line %d contains %s" % [i, order[i]])
	if log_node.lines.size() > 0:
		check.call(log_node.lines[0].contains("1.0, 2.0, 3.0"), "payload is shown in the line")
		check.call(log_node.lines[0].begins_with("["), "line starts with a timestamp")

	# Cap.
	for i: int in 20:
		bus.emit_signal(&"jumped", Vector3.ZERO)
	check.call(log_node.lines.size() == EventLog.MAX_LINES, "lines capped at MAX_LINES (got %d)" % log_node.lines.size())
	check.call(not log_node.lines[0].contains("landed"), "oldest line was dropped")
	var label: RichTextLabel = log_node.get_node("%Lines") as RichTextLabel
	check.call(label.text == "\n".join(log_node.lines), "label text equals the lines joined by newlines")

	# Toggle.
	_press(tree, true)
	check.call(log_node.visible, "debug_event_log press shows the overlay")
	_press(tree, false)
	_press(tree, true)
	check.call(not log_node.visible, "second press hides the overlay again")

	# Not an autoload.
	var autoloads: Array[String] = []
	for prop: Dictionary in ProjectSettings.get_property_list():
		var prop_name: String = prop.name
		if prop_name.begins_with("autoload/"):
			autoloads.append(prop_name)
	check.call(autoloads == ["autoload/EventBus"], "only EventBus is an autoload (got %s)" % [autoloads])

	log_node.queue_free()
	await tree.process_frame
