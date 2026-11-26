extends RefCounted
## Plan 05.1-17 (KIT-01, D-13, D-14): the Trigger block (the kit emitter, the atomic rename of the old emitter base) and the Receiver component.
## Trigger keeps the old contract (active_changed, is_active, set_active that emits only on change, start_active, reset). The invisible
## AND / OR / timer nodes extend Trigger and keep their behaviour. A Receiver child follows its source (RUN_WHILE_ON) or flips on every
## rising edge (REVERSE_ON_SIGNAL); a missing source warns once and stays off. Classes are reached by path, so this file compiles
## before they exist (TDD RED).

const TRIGGER_SCRIPT: String = "res://scripts/kit/blocks/trigger.gd"
const CONFIG_SCRIPT: String = "res://scripts/kit/configs/trigger_config.gd"
const RECEIVER_SCRIPT: String = "res://scripts/kit/components/receiver.gd"
const LOGIC_SCRIPTS: Dictionary = {
	"LogicAnd": "res://scripts/kit/logic/logic_and.gd",
	"LogicOr": "res://scripts/kit/logic/logic_or.gd",
	"LogicTimer": "res://scripts/kit/logic/logic_timer.gd",
}
const OLD_SOURCE: String = "res://scripts/mechanisms/" + "signal" + "_source.gd"
const SHIPPED_TPS: int = 60

var _edges: Array[bool] = []


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	check.call(not ResourceLoader.exists(OLD_SOURCE), "the old emitter script is gone (atomic rename, D-13)")
	var all_there: bool = true
	for path: String in [TRIGGER_SCRIPT, CONFIG_SCRIPT, RECEIVER_SCRIPT]:
		var exists: bool = ResourceLoader.exists(path)
		check.call(exists, "%s exists" % path)
		all_there = all_there and exists
	if not all_there:
		return
	var trigger_script: GDScript = load(TRIGGER_SCRIPT) as GDScript
	var receiver_script: GDScript = load(RECEIVER_SCRIPT) as GDScript
	check.call(String(trigger_script.get_global_name()) == "Trigger", "trigger.gd declares class_name Trigger")
	check.call(String(receiver_script.get_global_name()) == "Receiver", "receiver.gd declares class_name Receiver")
	check.call(_chain(trigger_script).has("KitBlock"), "Trigger extends KitBlock (%s)" % [_chain(trigger_script)])
	var profiles: Dictionary = (load(CONFIG_SCRIPT) as GDScript).get_script_constant_map().get("Profile", {}) as Dictionary
	check.call(profiles.has("CHARGE_GATE"), "TriggerConfig.Profile has CHARGE_GATE (%s)" % [profiles])
	for logic: String in LOGIC_SCRIPTS:
		var path: String = String(LOGIC_SCRIPTS[logic])
		check.call(ResourceLoader.exists(path), "%s lives in the kit: %s" % [logic, path])
		if ResourceLoader.exists(path):
			check.call(_chain(load(path) as GDScript).has("Trigger"), "%s extends Trigger (%s)" % [logic, _chain(load(path) as GDScript)])
	_scenario_contract(tree, check, trigger_script)
	await _scenario_receiver_follow(tree, check, trigger_script, receiver_script)
	await _scenario_receiver_toggle(tree, check, trigger_script, receiver_script)
	await _scenario_receiver_reset(tree, check, trigger_script, receiver_script)
	await _scenario_receiver_missing(tree, check, receiver_script)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _chain(script: GDScript) -> Array[String]:
	var chain: Array[String] = []
	var current: Script = script
	while current != null:
		var global_name: String = String(current.get_global_name())
		if global_name != "":
			chain.append(global_name)
		current = current.get_base_script()
	return chain


func _record(active: bool) -> void:
	_edges.append(active)


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _trigger(tree: SceneTree, script: GDScript, start_active: bool = false) -> Node3D:
	var node: Node3D = script.new() as Node3D
	node.set(&"start_active", start_active)
	tree.root.add_child(node)
	return node


func _scenario_contract(tree: SceneTree, check: Callable, script: GDScript) -> void:
	var node: Node3D = _trigger(tree, script)
	_edges.clear()
	node.connect(&"active_changed", _record)
	check.call(not bool(node.get("is_active")), "a plain Trigger starts off")
	node.call(&"set_active", true)
	node.call(&"set_active", true)
	check.call(bool(node.get("is_active")) and _edges == [true], "set_active(true) twice emits once (%s)" % [_edges])
	node.call(&"set_active", false)
	check.call(not bool(node.get("is_active")) and _edges == [true, false], "set_active(false) emits the falling edge (%s)" % [_edges])
	check.call(node.is_in_group(&"mechanism") and node.is_in_group(&"kit_block"), "a Trigger joins the groups mechanism and kit_block")
	node.set(&"start_active", true)
	node.call(&"reset")
	check.call(bool(node.get("is_active")), "reset() returns to start_active")
	node.free()
	var on: Node3D = _trigger(tree, script, true)
	check.call(bool(on.get("is_active")), "start_active comes up on")
	on.free()


func _receiver(tree: SceneTree, script: GDScript, source: Node, behaviour: int) -> Node:
	var host: Node3D = Node3D.new()
	tree.root.add_child(host)
	var receiver: Node = script.new() as Node
	receiver.set(&"source", source)
	receiver.set(&"behaviour", behaviour)
	host.add_child(receiver)
	return receiver


func _behaviour(script: GDScript, name: String) -> int:
	return int((script.get_script_constant_map().get("Behaviour", {}) as Dictionary).get(name, -1))


func _scenario_receiver_follow(tree: SceneTree, check: Callable, trigger_script: GDScript, receiver_script: GDScript) -> void:
	var source: Node3D = _trigger(tree, trigger_script)
	var receiver: Node = _receiver(tree, receiver_script, source, _behaviour(receiver_script, "RUN_WHILE_ON"))
	check.call(not bool(receiver.call(&"is_on")), "RUN_WHILE_ON: off while the source is off")
	var seen: Array[bool] = []
	receiver.connect(&"switched", func(on: bool) -> void: seen.append(on))
	source.call(&"set_active", true)
	check.call(bool(receiver.call(&"is_on")), "RUN_WHILE_ON: on while the source is on")
	source.call(&"set_active", false)
	check.call(not bool(receiver.call(&"is_on")) and seen == [true, false], "RUN_WHILE_ON: off again, switched fired for both edges (%s)" % [seen])
	var late: Node3D = _trigger(tree, trigger_script, true)
	var late_receiver: Node = _receiver(tree, receiver_script, late, _behaviour(receiver_script, "RUN_WHILE_ON"))
	check.call(bool(late_receiver.call(&"is_on")), "RUN_WHILE_ON: a source already on at load switches the receiver on")
	await _free(tree, [receiver.get_parent(), late_receiver.get_parent(), source, late])


func _scenario_receiver_toggle(tree: SceneTree, check: Callable, trigger_script: GDScript, receiver_script: GDScript) -> void:
	var source: Node3D = _trigger(tree, trigger_script)
	var receiver: Node = _receiver(tree, receiver_script, source, _behaviour(receiver_script, "REVERSE_ON_SIGNAL"))
	check.call(not bool(receiver.call(&"is_on")), "REVERSE_ON_SIGNAL: starts off")
	source.call(&"set_active", true)
	check.call(bool(receiver.call(&"is_on")), "REVERSE_ON_SIGNAL: the first rising edge flips it on")
	source.call(&"set_active", false)
	check.call(bool(receiver.call(&"is_on")), "REVERSE_ON_SIGNAL: a falling edge changes nothing")
	source.call(&"set_active", true)
	check.call(not bool(receiver.call(&"is_on")), "REVERSE_ON_SIGNAL: the second rising edge flips it back off")
	await _free(tree, [receiver.get_parent(), source])


## WR-05 pattern: reset re-reads an always-on source instead of leaving the receiver dead.
func _scenario_receiver_reset(tree: SceneTree, check: Callable, trigger_script: GDScript, receiver_script: GDScript) -> void:
	var source: Node3D = _trigger(tree, trigger_script, true)
	var receiver: Node = _receiver(tree, receiver_script, source, _behaviour(receiver_script, "RUN_WHILE_ON"))
	check.call(bool(receiver.call(&"is_on")), "reset scenario: an always-on source drives the receiver on")
	receiver.call(&"reset")
	check.call(bool(receiver.call(&"is_on")), "reset(): the receiver re-reads an always-on source and stays on")
	await _free(tree, [receiver.get_parent(), source])


func _scenario_receiver_missing(tree: SceneTree, check: Callable, receiver_script: GDScript) -> void:
	var receiver: Node = _receiver(tree, receiver_script, null, _behaviour(receiver_script, "RUN_WHILE_ON"))
	await tree.process_frame
	check.call(not bool(receiver.call(&"is_on")), "a Receiver without a source stays off (and warns once)")
	await _free(tree, [receiver.get_parent()])
