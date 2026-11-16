extends SceneTree
## Editor-time tool: builds the Mannequin AnimationTree root (an AnimationNodeBlendTree) and saves it as a text .tres.
## Run: bash attimo/tests/run.sh --tool res://tools/build_mannequin_tree.gd
## Layout: StateMachine (Locomotion BlendSpace2D, Jump, Fall, Dash, DashLeft, DashRight, DashBack) -> TimeScale ->
## Land (OneShot, input 1 = LandClip) -> Aim (Blend2 with an upper-body bone filter, input 1 = AimClip) -> output.
## There is no Land state: landing is an overlay that a move input fades out (D-08, no landing lock).

const OUTPUT: String = "res://scenes/player/mannequin_tree.tres"
const LIBRARY: String = "res://assets/animations/rig_medium/rig_medium_library.res"
const XFADE_TIME: float = 0.1
## Skeleton path prefix for bone filters (the aim layer).
const SKEL: String = "Rig_Medium/Skeleton3D:"

## Bones the aim layer takes over (D-11). Never hips or root: the pelvis and the root yaw stay with locomotion so the
## legs keep their clip and the strafe direction (research Pattern 5). The handslot bones do not exist on the
## Mannequin; a filter entry for a missing bone matches nothing and is harmless (A-07-2: drop them if an engine
## warning ever appears).
const UPPER_BONES: Array[String] = [
	"spine", "chest", "head",
	"upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l",
	"upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r",
]
## Ranged_1H_Aiming is a raise followed by a hold. The node plays only the hold (0.6 s .. 1.0 s) and never loops, so
## the raise does not replay (Pitfall 4).
const AIM_HOLD_START: float = 0.6
const AIM_HOLD_LENGTH: float = 0.4

## Jump_Start is cut at the crouch bottom (0.25 s) so the jump shows at most two frames of anticipation.
const JUMP_START_OFFSET: float = 0.25
const JUMP_START_LENGTH: float = 0.35
const LAND_FADE_IN: float = 0.05
const LAND_FADE_OUT: float = 0.1
const LAND_LENGTH: float = 0.3

var _used_clips: Array[StringName] = []


func _initialize() -> void:
	var machine: AnimationNodeStateMachine = _build_machine()

	var tree: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	tree.add_node(&"StateMachine", machine, Vector2(0, 0))
	tree.add_node(&"TimeScale", AnimationNodeTimeScale.new(), Vector2(260, 0))
	var land: AnimationNodeOneShot = AnimationNodeOneShot.new()
	land.fadein_time = LAND_FADE_IN
	land.fadeout_time = LAND_FADE_OUT
	tree.add_node(&"Land", land, Vector2(520, 0))
	var land_clip: AnimationNodeAnimation = _clip(&"Jump_Land")
	land_clip.use_custom_timeline = true
	land_clip.timeline_length = LAND_LENGTH
	land_clip.stretch_time_scale = true
	land_clip.loop_mode = Animation.LOOP_NONE
	tree.add_node(&"LandClip", land_clip, Vector2(260, 160))
	var aim: AnimationNodeBlend2 = AnimationNodeBlend2.new()
	aim.filter_enabled = true
	for bone: String in UPPER_BONES:
		aim.set_filter_path(NodePath(SKEL + bone), true)
	tree.add_node(&"Aim", aim, Vector2(780, 0))
	var aim_clip: AnimationNodeAnimation = _clip(&"Ranged_1H_Aiming")
	aim_clip.use_custom_timeline = true
	aim_clip.start_offset = AIM_HOLD_START
	aim_clip.timeline_length = AIM_HOLD_LENGTH
	aim_clip.loop_mode = Animation.LOOP_NONE
	tree.add_node(&"AimClip", aim_clip, Vector2(520, 160))

	# connect_node(input_node, input_index, output_node): the node named first receives the output of the last.
	tree.connect_node(&"TimeScale", 0, &"StateMachine")
	tree.connect_node(&"Land", 0, &"TimeScale")
	tree.connect_node(&"Land", 1, &"LandClip")
	tree.connect_node(&"Aim", 0, &"Land")
	tree.connect_node(&"Aim", 1, &"AimClip")
	tree.connect_node(&"output", 0, &"Aim")

	var missing: StringName = _first_missing_clip()
	if missing != &"":
		print("TREE: FAILED (missing clip %s)" % missing)
		quit(1)
		return

	var err: Error = ResourceSaver.save(tree, OUTPUT)
	print("TREE: SAVED %s err=%d" % [OUTPUT, err])
	quit(0 if err == OK else 1)


func _build_machine() -> AnimationNodeStateMachine:
	var machine: AnimationNodeStateMachine = AnimationNodeStateMachine.new()

	var locomotion: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
	locomotion.min_space = Vector2(-1.0, -1.0)
	locomotion.max_space = Vector2(1.0, 1.0)
	locomotion.sync_mode = AnimationNodeBlendSpace2D.SYNC_MODE_CYCLIC_MUTABLE
	locomotion.add_blend_point(_clip(&"Idle_A"), Vector2(0.0, 0.0), -1, &"idle")
	locomotion.add_blend_point(_clip(&"Running_A"), Vector2(0.0, 1.0), -1, &"run")
	# x = strafe (left -1, right +1), y = forward (back -1, run +1). Outside aim the animator only writes x = 0. The
	# BlendSpace2D needs triangles to output anything (two collinear points play no clip, measured on 4.7.2); the
	# four outer points around idle give it a full triangulation.
	locomotion.add_blend_point(_clip(&"Running_Strafe_Left"), Vector2(-1.0, 0.0), -1, &"strafe_l")
	locomotion.add_blend_point(_clip(&"Running_Strafe_Right"), Vector2(1.0, 0.0), -1, &"strafe_r")
	locomotion.add_blend_point(_clip(&"Walking_Backwards"), Vector2(0.0, -1.0), -1, &"back")

	var jump: AnimationNodeAnimation = _clip(&"Jump_Start")
	jump.use_custom_timeline = true
	jump.start_offset = JUMP_START_OFFSET
	jump.timeline_length = JUMP_START_LENGTH
	jump.stretch_time_scale = false
	jump.loop_mode = Animation.LOOP_NONE

	machine.add_node(&"Locomotion", locomotion, Vector2(300, 100))
	machine.add_node(&"Jump", jump, Vector2(560, 0))
	machine.add_node(&"Fall", _clip(&"Jump_Idle"), Vector2(560, 200))
	machine.add_node(&"Dash", _clip(&"Dodge_Forward"), Vector2(40, 200))

	# AUTO alone fires on the first frame, so the entry edge is the only auto edge. No at-end edge out of Jump:
	# travel() honours an at-end switch and would hold the jump pose after the FSM already says Fall (A-01-2).
	machine.add_transition(&"Start", &"Locomotion", _auto_edge())

	# One direct immediate edge per ordered pair (the engine allows only one), so travel() never plays intermediates.
	var states: Array[StringName] = [&"Locomotion", &"Jump", &"Fall", &"Dash"]
	for from_state: StringName in states:
		for to_state: StringName in states:
			if from_state != to_state:
				machine.add_transition(from_state, to_state, _manual_edge())
	return machine


func _clip(clip_name: StringName) -> AnimationNodeAnimation:
	var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	node.animation = clip_name
	if not _used_clips.has(clip_name):
		_used_clips.append(clip_name)
	return node


func _first_missing_clip() -> StringName:
	var library: AnimationLibrary = load(LIBRARY) as AnimationLibrary
	if library == null:
		return &"<library %s not loadable>" % LIBRARY
	for clip_name: StringName in _used_clips:
		if not library.has_animation(clip_name):
			return clip_name
	return &""


func _auto_edge() -> AnimationNodeStateMachineTransition:
	var edge: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
	edge.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	edge.xfade_time = XFADE_TIME
	return edge


func _manual_edge() -> AnimationNodeStateMachineTransition:
	var edge: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
	edge.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
	edge.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	edge.xfade_time = XFADE_TIME
	return edge
