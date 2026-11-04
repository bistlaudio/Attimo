extends RefCounted
## FOUND-05: the merged Rig_Medium library holds exactly the six demo clips with correct loop modes,
## and the clips bind to the Mannequin skeleton without retargeting.

const LIBRARY_PATH: String = "res://assets/animations/rig_medium/rig_medium_library.res"
const MANNEQUIN_GLB: String = "res://assets/characters/mannequin/Mannequin_Medium.glb"
const LENGTH_TOLERANCE: float = 0.02


func run(_tree: SceneTree, check: Callable) -> void:
	var library: AnimationLibrary = load(LIBRARY_PATH) as AnimationLibrary
	check.call(library != null, "rig_medium_library.res loads as AnimationLibrary")
	if library == null:
		return

	var expected: Array[StringName] = [&"Idle_A", &"Running_A", &"Jump_Start", &"Jump_Idle", &"Jump_Land", &"Dodge_Forward"]
	var names: Array[StringName] = library.get_animation_list()
	check.call(names.size() == expected.size(), "library holds exactly %d clips (got %d)" % [expected.size(), names.size()])
	for clip: StringName in expected:
		check.call(library.has_animation(clip), "library has clip %s" % clip)
	check.call(not library.has_animation(&"T-Pose"), "library has no T-Pose")

	for clip: StringName in [&"Idle_A", &"Running_A", &"Jump_Idle"]:
		check.call(library.has_animation(clip) and library.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, "%s loops" % clip)
	for clip: StringName in [&"Jump_Start", &"Jump_Land", &"Dodge_Forward"]:
		check.call(library.has_animation(clip) and library.get_animation(clip).loop_mode == Animation.LOOP_NONE, "%s does not loop" % clip)

	var lengths: Dictionary[StringName, float] = {
		&"Jump_Start": 0.6, &"Dodge_Forward": 0.4, &"Idle_A": 1.067, &"Running_A": 0.8, &"Jump_Land": 0.667,
	}
	for clip: StringName in lengths:
		if library.has_animation(clip):
			var length: float = library.get_animation(clip).length
			check.call(absf(length - lengths[clip]) <= LENGTH_TOLERANCE, "%s length %.3f is %.3f +- %.2f" % [clip, length, lengths[clip], LENGTH_TOLERANCE])

	if library.has_animation(&"Idle_A"):
		var idle: Animation = library.get_animation(&"Idle_A")
		var all_bound: bool = idle.get_track_count() > 0
		for i: int in idle.get_track_count():
			if not str(idle.track_get_path(i)).begins_with("Rig_Medium/Skeleton3D:"):
				all_bound = false
		check.call(all_bound, "every Idle_A track path begins with Rig_Medium/Skeleton3D: (no retargeting)")

	var scene: PackedScene = load(MANNEQUIN_GLB) as PackedScene
	check.call(scene != null, "Mannequin_Medium.glb loads")
	if scene == null:
		return
	var mannequin: Node = scene.instantiate()
	var skeleton: Skeleton3D = _find_skeleton(mannequin)
	check.call(skeleton != null, "Mannequin has a Skeleton3D")
	if skeleton != null:
		check.call(skeleton.find_bone("hips") != -1, "bone hips exists")
		check.call(skeleton.find_bone("hand.r") != -1, "bone hand.r exists")
		check.call(skeleton.find_bone("hand.l") != -1, "bone hand.l exists")
		check.call(skeleton.find_bone("handslot.r") == -1, "handslot.r is absent (use BoneAttachment3D on hand.r)")
	mannequin.free()


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null
