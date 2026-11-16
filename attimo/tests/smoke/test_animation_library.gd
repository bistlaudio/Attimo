extends RefCounted
## FOUND-05: the merged Rig_Medium library holds exactly the six demo clips with correct loop modes,
## and the clips bind to the Mannequin skeleton without retargeting.

const LIBRARY_PATH: String = "res://assets/animations/rig_medium/rig_medium_library.res"
const MANNEQUIN_GLB: String = "res://assets/characters/mannequin/Mannequin_Medium.glb"
const LENGTH_TOLERANCE: float = 0.02
const ROOT_TRACK: NodePath = ^"Rig_Medium/Skeleton3D:root"
const PINNED_CLIPS: Array[StringName] = [&"Dodge_Forward", &"Dodge_Left", &"Dodge_Right", &"Dodge_Backward"]
const PIN_TOLERANCE: float = 0.001


func run(_tree: SceneTree, check: Callable) -> void:
	var library: AnimationLibrary = load(LIBRARY_PATH) as AnimationLibrary
	check.call(library != null, "rig_medium_library.res loads as AnimationLibrary")
	if library == null:
		return

	var expected: Array[StringName] = [&"Idle_A", &"Running_A", &"Jump_Start", &"Jump_Idle", &"Jump_Land", &"Dodge_Forward", &"Ranged_1H_Aiming",
		&"Running_Strafe_Left", &"Running_Strafe_Right", &"Walking_Backwards", &"Dodge_Left", &"Dodge_Right", &"Dodge_Backward"]
	var names: Array[StringName] = library.get_animation_list()
	check.call(names.size() == expected.size(), "library holds exactly %d clips (got %d)" % [expected.size(), names.size()])
	for clip: StringName in expected:
		check.call(library.has_animation(clip), "library has clip %s" % clip)
	check.call(not library.has_animation(&"T-Pose"), "library has no T-Pose")

	for clip: StringName in [&"Idle_A", &"Running_A", &"Jump_Idle", &"Running_Strafe_Left", &"Running_Strafe_Right", &"Walking_Backwards"]:
		check.call(library.has_animation(clip) and library.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, "%s loops" % clip)
	for clip: StringName in [&"Jump_Start", &"Jump_Land", &"Dodge_Forward", &"Ranged_1H_Aiming", &"Dodge_Left", &"Dodge_Right", &"Dodge_Backward"]:
		check.call(library.has_animation(clip) and library.get_animation(clip).loop_mode == Animation.LOOP_NONE, "%s does not loop" % clip)

	var lengths: Dictionary[StringName, float] = {
		&"Jump_Start": 0.6, &"Dodge_Forward": 0.4, &"Idle_A": 1.067, &"Running_A": 0.8, &"Jump_Land": 0.667, &"Ranged_1H_Aiming": 1.067,
		&"Running_Strafe_Left": 0.8, &"Running_Strafe_Right": 0.8, &"Walking_Backwards": 1.067,
		&"Dodge_Left": 0.4, &"Dodge_Right": 0.4, &"Dodge_Backward": 0.4,
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

	for clip: StringName in PINNED_CLIPS:
		_check_root_pinned(library, clip, check)
	_check_strafe_yaw(library, &"Running_Strafe_Right", check)
	_check_strafe_yaw(library, &"Running_Strafe_Left", check)

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


## Pitfall 5: every key of the root position track equals key 0, and key 0 has no horizontal offset.
func _check_root_pinned(library: AnimationLibrary, clip: StringName, check: Callable) -> void:
	if not library.has_animation(clip):
		return
	var animation: Animation = library.get_animation(clip)
	var track: int = animation.find_track(ROOT_TRACK, Animation.TYPE_POSITION_3D)
	check.call(track != -1, "%s has a root position track" % clip)
	if track == -1:
		return
	var first: Vector3 = animation.track_get_key_value(track, 0)
	check.call(Vector2(first.x, first.z).length() < 0.01, "%s root key 0 has horizontal length %.4f below 0.01" % [clip, Vector2(first.x, first.z).length()])
	var worst: float = 0.0
	for key: int in animation.track_get_key_count(track):
		var value: Vector3 = animation.track_get_key_value(track, key)
		worst = maxf(worst, value.distance_to(first))
	check.call(worst <= PIN_TOLERANCE, "%s root position keys stay within %.4f m of key 0 (worst %.4f)" % [clip, PIN_TOLERANCE, worst])


## The strafe direction lives in the root yaw, so the pin must not touch the rotation track.
func _check_strafe_yaw(library: AnimationLibrary, clip: StringName, check: Callable) -> void:
	if not library.has_animation(clip):
		return
	var animation: Animation = library.get_animation(clip)
	var track: int = animation.find_track(ROOT_TRACK, Animation.TYPE_ROTATION_3D)
	check.call(track != -1, "%s keeps a root rotation track" % clip)
	if track == -1:
		return
	var rotation: Quaternion = animation.rotation_track_interpolate(track, animation.length * 0.5)
	var yaw: float = absf(rad_to_deg(rotation.get_euler().y))
	check.call(yaw >= 45.0 and yaw <= 75.0, "%s root yaw at half length is %.1f degrees (45 to 75)" % [clip, yaw])


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null
