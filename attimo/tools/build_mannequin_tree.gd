extends SceneTree
## Editor-time tool: builds the Mannequin AnimationTree root (an AnimationNodeBlendTree) and saves it as a text .tres.
## Run: bash attimo/tests/run.sh --tool res://tools/build_mannequin_tree.gd
## Layout: StateMachine (Locomotion BlendSpace2D, Jump, Fall, Dash, DashLeft, DashRight, DashBack, Slide) -> TimeScale ->
## IdleBreak (OneShot, input 1 = IdleBreakPick, a Transition over the idle break clips) ->
## Land (OneShot, input 1 = LandClip) -> Aim (Blend2 with an upper-body bone filter, input 1 = Shoot) -> output.
## Shoot is a OneShot: input 0 = AimMachine (Enter, Hold, Exit of the UAL Spell hand clips), input 1 = ShootClip.
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
## Ranged_1H_Aiming is a raise (0.0 s .. 0.6 s) followed by a hold. It is the KayKit fallback of the UAL Spell set (the
## quick 261118-qi3 spell hand; the UAL Spell clips are dropped, see UAL_DROPPED): Enter plays the raise, Hold and Shoot
## play the hold window (Pitfall 4: the raise does not replay), Exit plays AIM_EXIT_FALLBACK_LENGTH of the hold and the
## layer fade lowers the arm.
const AIM_RAISE_LENGTH: float = 0.6
const AIM_HOLD_START: float = 0.6
const AIM_HOLD_LENGTH: float = 0.4
const AIM_EXIT_FALLBACK_LENGTH: float = 0.1
const SHOOT_FADE_IN: float = 0.05
## Idle breaks (quick 261118-qi3): a OneShot over the whole body while the figure stands in Idle. The animator picks the
## clip through IdleBreakPick (inputs named after the clips) and fades the break out on any action.
const IDLE_BREAK_CLIPS: Array[StringName] = [&"Idle_B", &"UAL_Idle_Loop"]
const IDLE_BREAK_FADE_IN: float = 0.2
const IDLE_BREAK_FADE_OUT: float = 0.1
const SHOOT_FADE_OUT: float = 0.1
## UAL clip (library key UAL_<clip>) to the KayKit clip its node plays when the library lacks the UAL clip (dropped by the
## bone-sanity gate, tools/build_animation_library.gd UAL_DROPPED). The tool prints every fallback it used.
const FALLBACK: Dictionary[StringName, StringName] = {
	&"UAL_Spell_Simple_Enter": &"Ranged_1H_Aiming",
	&"UAL_Spell_Simple_Idle_Loop": &"Ranged_1H_Aiming",
	&"UAL_Spell_Simple_Shoot": &"Ranged_1H_Aiming",
	&"UAL_Spell_Simple_Exit": &"Ranged_1H_Aiming",
	&"UAL_Sprint_Loop": &"Running_A",
	&"UAL_Jump_Land": &"Jump_Land",
	&"UAL_Roll": &"Jump_Land",
	&"UAL_Idle_Loop": &"Idle_A",
}

## Jump_Start is cut at the crouch bottom (0.25 s) so the jump shows at most two frames of anticipation.
const JUMP_START_OFFSET: float = 0.25
const JUMP_START_LENGTH: float = 0.35
const LAND_FADE_IN: float = 0.05
const LAND_FADE_OUT: float = 0.1
const LAND_LENGTH: float = 0.3

## Running_Slide (retargeted Mixamo clip, quick 261118-qbt) is a run-in, the drop, a long low slide and a get-up. The node
## plays only the drop and the start of the low pose. Measured on the baked clip (tools/build_animation_library.gd prints
## the hips height share of rest per key): the last key with the hips at or above 95 % of rest before the drop is
## 0.0667 s (1.019); the minimum is 0.300 s (0.480, a drop of 0.54); the first key within 10 % of the drop of the
## minimum is 0.300 s; plus 0.1 s of the low hold ends the window at 0.400 s (0.596 of rest, below 80 %). The window of
## 0.3333 s is stretched to dash_time (0.18 s) by the animator, a playback scale of 1.85 (at most 4). Never the run-in
## steps or the get-up.
const SLIDE_START: float = 0.0667
const SLIDE_LENGTH: float = 0.3333
## Only the drop (SLIDE_START to the hips minimum at 0.300 s) is stretched to dash_time, about 1.3x instead of the
## whole window at 1.85x (developer 2026-11-18: "too fast"). The rest of the window holds the low pose. Stored as
## metadata "drop_length" on the Slide node; MannequinAnimator reads it.
const SLIDE_DROP_LENGTH: float = 0.2333
## Crossfades of the Slide edges (developer 2026-11-18: the slide popped in and out). Presentation only: the travel
## still happens on the state change frame.
const SLIDE_XFADE_IN: float = 0.1
const SLIDE_XFADE_OUT: float = 0.15

var _used_clips: Array[StringName] = []
var _library: AnimationLibrary


func _initialize() -> void:
	_library = load(LIBRARY) as AnimationLibrary
	if _library == null:
		print("TREE: FAILED (library %s not loadable)" % LIBRARY)
		quit(1)
		return
	var machine: AnimationNodeStateMachine = _build_machine()

	var tree: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	tree.add_node(&"StateMachine", machine, Vector2(0, 0))
	tree.add_node(&"TimeScale", AnimationNodeTimeScale.new(), Vector2(260, 0))
	var idle_break: AnimationNodeOneShot = AnimationNodeOneShot.new()
	idle_break.fadein_time = IDLE_BREAK_FADE_IN
	idle_break.fadeout_time = IDLE_BREAK_FADE_OUT
	tree.add_node(&"IdleBreak", idle_break, Vector2(390, 0))
	var break_clips: Array[StringName] = _idle_break_clips()
	var pick: AnimationNodeTransition = AnimationNodeTransition.new()
	pick.xfade_time = 0.0
	pick.input_count = break_clips.size()
	for i: int in break_clips.size():
		pick.set_input_name(i, String(break_clips[i]))
	tree.add_node(&"IdleBreakPick", pick, Vector2(390, 160))
	for i: int in break_clips.size():
		tree.add_node(StringName("IdleBreak_%s" % break_clips[i]), _single_cycle(break_clips[i]), Vector2(130, 160 + 120 * i))
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
	# sync: the spell hand machine keeps running at layer weight 0, so Enter starts on the press frame, not on the first
	# frame with a non-zero weight.
	aim.sync = true
	for bone: String in UPPER_BONES:
		aim.set_filter_path(NodePath(SKEL + bone), true)
	tree.add_node(&"Aim", aim, Vector2(780, 0))
	var shoot: AnimationNodeOneShot = AnimationNodeOneShot.new()
	shoot.fadein_time = SHOOT_FADE_IN
	shoot.fadeout_time = SHOOT_FADE_OUT
	tree.add_node(&"Shoot", shoot, Vector2(780, 160))
	tree.add_node(&"AimMachine", _build_aim_machine(), Vector2(520, 160))
	tree.add_node(&"ShootClip", _spell_clip(&"UAL_Spell_Simple_Shoot", AIM_HOLD_START, AIM_HOLD_LENGTH), Vector2(520, 320))

	# connect_node(input_node, input_index, output_node): the node named first receives the output of the last.
	tree.connect_node(&"TimeScale", 0, &"StateMachine")
	tree.connect_node(&"IdleBreak", 0, &"TimeScale")
	tree.connect_node(&"IdleBreak", 1, &"IdleBreakPick")
	for i: int in break_clips.size():
		tree.connect_node(&"IdleBreakPick", i, StringName("IdleBreak_%s" % break_clips[i]))
	tree.connect_node(&"Land", 0, &"IdleBreak")
	tree.connect_node(&"Land", 1, &"LandClip")
	tree.connect_node(&"Aim", 0, &"Land")
	tree.connect_node(&"Shoot", 0, &"AimMachine")
	tree.connect_node(&"Shoot", 1, &"ShootClip")
	tree.connect_node(&"Aim", 1, &"Shoot")
	tree.connect_node(&"output", 0, &"Aim")

	var missing: StringName = _first_missing_clip()
	if missing != &"":
		print("TREE: FAILED (missing clip %s)" % missing)
		quit(1)
		return

	var err: Error = ResourceSaver.save(tree, OUTPUT)
	print("TREE: SAVED %s err=%d" % [OUTPUT, err])
	quit(0 if err == OK else 1)


## The spell hand: Enter (raise), Hold (loop), Exit (lower). The animator starts the machine at Enter on the aim press and
## travels to Exit on the release. An at-end edge is intended inside this sub-machine: Enter hands over to Hold.
func _build_aim_machine() -> AnimationNodeStateMachine:
	var machine: AnimationNodeStateMachine = AnimationNodeStateMachine.new()
	machine.add_node(&"Enter", _spell_clip(&"UAL_Spell_Simple_Enter", 0.0, AIM_RAISE_LENGTH), Vector2(300, 0))
	machine.add_node(&"Hold", _spell_clip(&"UAL_Spell_Simple_Idle_Loop", AIM_HOLD_START, AIM_HOLD_LENGTH, true), Vector2(560, 0))
	# The Exit fallback is a short hold: the lowering is the layer fade (PLAY_MODE_BACKWARD with a custom timeline froze
	# at the window end on 4.7.2, measured, so the raise cannot simply be reversed).
	machine.add_node(&"Exit", _spell_clip(&"UAL_Spell_Simple_Exit", AIM_HOLD_START, AIM_EXIT_FALLBACK_LENGTH), Vector2(300, 160))
	machine.add_transition(&"Start", &"Hold", _auto_edge())
	var at_end: AnimationNodeStateMachineTransition = _auto_edge()
	at_end.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	machine.add_transition(&"Enter", &"Hold", at_end)
	machine.add_transition(&"Enter", &"Exit", _manual_edge())
	machine.add_transition(&"Hold", &"Exit", _manual_edge())
	machine.add_transition(&"Exit", &"Enter", _manual_edge())
	return machine


## An animation node for a UAL clip. When the library lacks it, the KayKit FALLBACK clip plays its window
## (fallback_start, fallback_length) instead and the tool says so.
func _spell_clip(ual_clip: StringName, fallback_start: float, fallback_length: float, loop: bool = false) -> AnimationNodeAnimation:
	if _library.has_animation(ual_clip):
		return _clip(ual_clip)
	var kaykit: StringName = FALLBACK[ual_clip]
	print("TREE: fallback %s -> %s" % [ual_clip, kaykit])
	var node: AnimationNodeAnimation = _clip(kaykit)
	node.use_custom_timeline = true
	node.start_offset = fallback_start
	node.timeline_length = fallback_length
	node.stretch_time_scale = false
	node.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return node


## The idle break clips the library has (a dropped UAL clip leaves only the KayKit ones).
func _idle_break_clips() -> Array[StringName]:
	var result: Array[StringName] = []
	for clip: StringName in IDLE_BREAK_CLIPS:
		if _library.has_animation(clip):
			result.append(clip)
		else:
			print("TREE: idle break %s missing, skipped" % clip)
	return result


## A node that plays `clip_name` exactly once, also when the clip loops (a loop plays one cycle as a break).
func _single_cycle(clip_name: StringName) -> AnimationNodeAnimation:
	var node: AnimationNodeAnimation = _clip(clip_name)
	node.use_custom_timeline = true
	node.start_offset = 0.0
	node.timeline_length = _library.get_animation(clip_name).length
	node.stretch_time_scale = false
	node.loop_mode = Animation.LOOP_NONE
	return node


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
	# The aimed dashes (D-12): the animator picks the node by the dash direction relative to the facing.
	machine.add_node(&"DashLeft", _clip(&"Dodge_Left"), Vector2(40, 320))
	machine.add_node(&"DashRight", _clip(&"Dodge_Right"), Vector2(300, 320))
	machine.add_node(&"DashBack", _clip(&"Dodge_Backward"), Vector2(560, 320))
	# The unaimed ground dash (DEV-04): the animator picks it through Dash.slide.
	var slide: AnimationNodeAnimation = _clip(&"Running_Slide")
	slide.use_custom_timeline = true
	slide.start_offset = SLIDE_START
	slide.timeline_length = SLIDE_LENGTH
	slide.stretch_time_scale = false
	slide.loop_mode = Animation.LOOP_NONE
	slide.set_meta(&"drop_length", SLIDE_DROP_LENGTH)
	machine.add_node(&"Slide", slide, Vector2(300, 440))

	# AUTO alone fires on the first frame, so the entry edge is the only auto edge. No at-end edge out of Jump:
	# travel() honours an at-end switch and would hold the jump pose after the FSM already says Fall (A-01-2).
	machine.add_transition(&"Start", &"Locomotion", _auto_edge())

	# One direct immediate edge per ordered pair (the engine allows only one), so travel() never plays intermediates.
	var states: Array[StringName] = [&"Locomotion", &"Jump", &"Fall", &"Dash", &"DashLeft", &"DashRight", &"DashBack", &"Slide"]
	for from_state: StringName in states:
		for to_state: StringName in states:
			if from_state != to_state:
				var edge: AnimationNodeStateMachineTransition = _manual_edge()
				if to_state == &"Slide":
					edge.xfade_time = SLIDE_XFADE_IN
				elif from_state == &"Slide":
					edge.xfade_time = SLIDE_XFADE_OUT
				machine.add_transition(from_state, to_state, edge)
	return machine


func _clip(clip_name: StringName) -> AnimationNodeAnimation:
	var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	node.animation = clip_name
	if not _used_clips.has(clip_name):
		_used_clips.append(clip_name)
	return node


func _first_missing_clip() -> StringName:
	for clip_name: StringName in _used_clips:
		if not _library.has_animation(clip_name):
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
