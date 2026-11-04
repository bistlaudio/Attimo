extends SceneTree
## Editor-time tool: builds the Mannequin AnimationTree state machine and saves it as a text .tres.
## Run: bash attimo/tests/run.sh --tool res://tools/build_mannequin_state_machine.gd
## States: Locomotion (BlendSpace1D idle 0 .. run 1), Jump, Fall, Land, Dash.

const OUTPUT: String = "res://scenes/player/mannequin_state_machine.tres"
const XFADE_TIME: float = 0.1

var _machine: AnimationNodeStateMachine


func _initialize() -> void:
	_machine = AnimationNodeStateMachine.new()

	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = 1.0
	locomotion.add_blend_point(_clip(&"Idle_A"), 0.0, -1, &"idle")
	locomotion.add_blend_point(_clip(&"Running_A"), 1.0, -1, &"run")

	_machine.add_node(&"Locomotion", locomotion, Vector2(300, 100))
	_machine.add_node(&"Jump", _clip(&"Jump_Start"), Vector2(560, 0))
	_machine.add_node(&"Fall", _clip(&"Jump_Idle"), Vector2(560, 200))
	_machine.add_node(&"Land", _clip(&"Jump_Land"), Vector2(300, 300))
	_machine.add_node(&"Dash", _clip(&"Dodge_Forward"), Vector2(40, 200))

	# Auto-advance edges. AUTO alone fires on the first frame (Pitfall 3), so they switch at the clip end.
	_machine.add_transition(&"Start", &"Locomotion", _auto_edge(false))
	_machine.add_transition(&"Jump", &"Fall", _auto_edge(true))
	_machine.add_transition(&"Land", &"Locomotion", _auto_edge(true))

	# Direct edges so travel() never plays intermediate clips (Pitfall 4).
	var direct: Array[Array] = [
		[&"Locomotion", &"Jump"], [&"Locomotion", &"Fall"], [&"Locomotion", &"Dash"],
		[&"Jump", &"Locomotion"], [&"Jump", &"Land"], [&"Jump", &"Dash"],
		[&"Fall", &"Locomotion"], [&"Fall", &"Land"], [&"Fall", &"Dash"], [&"Fall", &"Jump"],
		[&"Land", &"Jump"], [&"Land", &"Fall"], [&"Land", &"Dash"],
		[&"Dash", &"Locomotion"], [&"Dash", &"Fall"], [&"Dash", &"Jump"],
	]
	for edge: Array in direct:
		_machine.add_transition(edge[0] as StringName, edge[1] as StringName, _manual_edge())

	var err: Error = ResourceSaver.save(_machine, OUTPUT)
	print("saved %s err=%d" % [OUTPUT, err])
	quit(0 if err == OK else 1)


func _clip(clip_name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = clip_name
	return node


func _auto_edge(at_end: bool) -> AnimationNodeStateMachineTransition:
	var edge := AnimationNodeStateMachineTransition.new()
	edge.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	if at_end:
		edge.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	edge.xfade_time = XFADE_TIME
	return edge


func _manual_edge() -> AnimationNodeStateMachineTransition:
	var edge := AnimationNodeStateMachineTransition.new()
	edge.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
	edge.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	edge.xfade_time = XFADE_TIME
	return edge
