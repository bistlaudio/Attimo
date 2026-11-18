extends RefCounted
## Quick 261118-qbt: the generic retarget path (tools/clip_retargeter.gd, BoneMap on SkeletonProfileHumanoid) that brings
## external clips (Mixamo, later the Quaternius UAL) onto Rig_Medium. Guards the maps (r1), the math by a round trip
## (r2), the direction parity of the Running_Slide limbs (r3), the slide depth and floor contact (r4) and the mesh-free
## conformed source (r5, T-qbt-01). Read-only: fixed res:// paths, nothing is written.

const ClipRetargeter := preload("res://tools/clip_retargeter.gd")

const MANNEQUIN_GLB: String = "res://assets/characters/mannequin/Mannequin_Medium.glb"
const LIBRARY_PATH: String = "res://assets/animations/rig_medium/rig_medium_library.res"
const SLIDE_SOURCE: String = "res://assets/animations/external/mixamo/running_slide.scn"
const SLIDE_CLIP: StringName = &"Running_Slide"
const ROUND_TRIP_TOLERANCE_DEG: float = 0.5
const PARITY_TOLERANCE_DEG: float = 2.0
const HIPS_PLANE_TOLERANCE: float = 0.001
const SLIDE_DEPTH_MAX_SHARE: float = 0.8
const FOOT_SINK_MAX_SHARE: float = 0.1
## Limb pairs for the direction parity: from-bone, to-bone as profile names. The spine pair crosses the unmapped Spine1.
const PARITY_PAIRS: Array[Array] = [
	[&"LeftUpperArm", &"LeftLowerArm"], [&"LeftLowerArm", &"LeftHand"],
	[&"RightUpperArm", &"RightLowerArm"], [&"RightLowerArm", &"RightHand"],
	[&"LeftUpperLeg", &"LeftLowerLeg"], [&"LeftLowerLeg", &"LeftFoot"],
	[&"RightUpperLeg", &"RightLowerLeg"], [&"RightLowerLeg", &"RightFoot"],
	[&"Spine", &"UpperChest"],
]
const FOOT_BONES: Array[StringName] = [&"foot.l", &"toes.l", &"foot.r", &"toes.r"]


func run(_tree: SceneTree, check: Callable) -> void:
	_check_maps(check)
	_check_round_trip(check)
	_check_conformed_source(check)
	_check_slide(check)


## (r1) every map entry names a real profile bone, a real Mannequin bone or a real source bone.
func _check_maps(check: Callable) -> void:
	var profile: SkeletonProfileHumanoid = SkeletonProfileHumanoid.new()
	var profile_names: Array[StringName] = []
	for index: int in profile.bone_size:
		profile_names.append(profile.get_bone_name(index))

	var bad_profile: int = 0
	var bad_target: int = 0
	var target_skeleton: Skeleton3D = null
	var mannequin: Node = (load(MANNEQUIN_GLB) as PackedScene).instantiate()
	target_skeleton = _find_skeleton(mannequin)
	for profile_bone: StringName in ClipRetargeter.PROFILE_TO_RIG_MEDIUM:
		if not profile_names.has(profile_bone):
			bad_profile += 1
		if target_skeleton.find_bone(ClipRetargeter.PROFILE_TO_RIG_MEDIUM[profile_bone]) == -1:
			bad_target += 1
	check.call(bad_profile == 0, "r1: every Rig_Medium map key is a SkeletonProfileHumanoid bone (%d bad)" % bad_profile)
	check.call(bad_target == 0, "r1: every Rig_Medium map value exists on the Mannequin skeleton (%d bad)" % bad_target)

	var bad_family: int = 0
	for family_map: Dictionary in [ClipRetargeter.MIXAMO_TO_PROFILE, ClipRetargeter.UAL_TO_PROFILE]:
		for source_bone: StringName in family_map:
			if not profile_names.has(family_map[source_bone]):
				bad_family += 1
	check.call(bad_family == 0, "r1: every mixamo and ual map value is a SkeletonProfileHumanoid bone (%d bad)" % bad_family)
	for profile_bone: StringName in ClipRetargeter.PROFILE_TAIL:
		check.call(profile_names.has(profile_bone) and profile_names.has(ClipRetargeter.PROFILE_TAIL[profile_bone]), "r1: tail chain entry %s is a profile bone pair" % profile_bone)

	check.call(ClipRetargeter.normalize_name(&"mixamo", "mixamorig:Hips") == &"Hips", "r1: mixamorig:Hips normalizes to Hips")
	check.call(ClipRetargeter.normalize_name(&"mixamo", "mixamorig_Hips") == &"Hips", "r1: mixamorig_Hips normalizes to Hips")
	check.call(ClipRetargeter.normalize_name(&"mixamo", "mixamorig1:Hips") == &"Hips", "r1: mixamorig1:Hips normalizes to Hips")
	check.call(ClipRetargeter.normalize_name(&"ual", "spine_01") == &"spine_01", "r1: ual names are used as they are")
	mannequin.free()

	var scene: PackedScene = load(SLIDE_SOURCE) as PackedScene
	check.call(scene != null, "r1: running_slide.scn loads")
	if scene == null:
		return
	var source: Node = scene.instantiate()
	var source_skeleton: Skeleton3D = _find_skeleton(source)
	var bone_map: BoneMap = ClipRetargeter.build_bone_map(source_skeleton, &"mixamo")
	var unresolved: Array[StringName] = []
	for source_bone: StringName in ClipRetargeter.MIXAMO_TO_PROFILE:
		var profile_bone: StringName = ClipRetargeter.MIXAMO_TO_PROFILE[source_bone]
		if bone_map.get_skeleton_bone_name(profile_bone) == &"" or source_skeleton.find_bone(bone_map.get_skeleton_bone_name(profile_bone)) == -1:
			unresolved.append(source_bone)
	check.call(unresolved.is_empty(), "r1: the mixamo family resolves every bone on running_slide.scn (unresolved %s)" % [unresolved])
	source.free()


## (r2) Idle_A retargeted from the Rig_Medium family onto Rig_Medium reproduces every mapped rotation key.
func _check_round_trip(check: Callable) -> void:
	var library: AnimationLibrary = load(LIBRARY_PATH) as AnimationLibrary
	var source: Node = (load(MANNEQUIN_GLB) as PackedScene).instantiate()
	var target: Node = (load(MANNEQUIN_GLB) as PackedScene).instantiate()
	var source_skeleton: Skeleton3D = _find_skeleton(source)
	var target_skeleton: Skeleton3D = _find_skeleton(target)
	var idle: Animation = library.get_animation(&"Idle_A")
	var result: Animation = ClipRetargeter.retarget(source, idle, &"rig_medium", target_skeleton, ClipRetargeter.to_character_space(target_skeleton, target), "Rig_Medium/Skeleton3D:", false)
	check.call(result != null, "r2: the round trip produces an animation")
	if result == null:
		source.free()
		target.free()
		return
	var source_to_character: Transform3D = ClipRetargeter.to_character_space(source_skeleton, source)
	var worst: float = 0.0
	var compared: int = 0
	var mapped: Dictionary = ClipRetargeter.PROFILE_TO_RIG_MEDIUM
	for profile_bone: StringName in mapped:
		var bone_name: StringName = mapped[profile_bone]
		var track: int = result.find_track(NodePath("Rig_Medium/Skeleton3D:%s" % bone_name), Animation.TYPE_ROTATION_3D)
		var original: int = idle.find_track(NodePath("Rig_Medium/Skeleton3D:%s" % bone_name), Animation.TYPE_ROTATION_3D)
		if track == -1 or original == -1:
			continue
		for key: int in result.track_get_key_count(track):
			var time: float = result.track_get_key_time(track, key)
			var got: Quaternion = result.track_get_key_value(track, key)
			var expected: Quaternion = idle.rotation_track_interpolate(original, time)
			worst = maxf(worst, rad_to_deg(got.angle_to(expected)))
			compared += 1
	check.call(compared > 100, "r2: the round trip compared %d rotation keys" % compared)
	check.call(worst <= ROUND_TRIP_TOLERANCE_DEG, "r2: round trip rotation error %.3f degrees is at most %.1f" % [worst, ROUND_TRIP_TOLERANCE_DEG])
	check.call(source_to_character.basis.is_finite(), "r2: the character-space transform is finite")
	source.free()
	target.free()


## (r5) the conformed source holds only Node3D, Skeleton3D and AnimationPlayer nodes and no script (T-qbt-01).
func _check_conformed_source(check: Callable) -> void:
	var scene: PackedScene = load(SLIDE_SOURCE) as PackedScene
	if scene == null:
		check.call(false, "r5: running_slide.scn loads")
		return
	var root: Node = scene.instantiate()
	var offenders: Array[String] = []
	_collect_offenders(root, offenders)
	check.call(offenders.is_empty(), "r5: running_slide.scn holds only Node3D, Skeleton3D, AnimationPlayer and no script (%s)" % [offenders])
	var player: AnimationPlayer = _find_player(root)
	check.call(player != null and player.get_animation_list().size() == 1 and player.has_animation(SLIDE_CLIP), "r5: running_slide.scn holds exactly the clip Running_Slide")
	root.free()


## (r3) limb direction parity and (r4) slide depth and floor contact, on the baked Running_Slide of the library.
func _check_slide(check: Callable) -> void:
	var library: AnimationLibrary = load(LIBRARY_PATH) as AnimationLibrary
	if library == null or not library.has_animation(SLIDE_CLIP):
		check.call(false, "r3: the library holds Running_Slide")
		return
	var baked: Animation = library.get_animation(SLIDE_CLIP)
	var source: Node = (load(SLIDE_SOURCE) as PackedScene).instantiate()
	var target: Node = (load(MANNEQUIN_GLB) as PackedScene).instantiate()
	var source_skeleton: Skeleton3D = _find_skeleton(source)
	var target_skeleton: Skeleton3D = _find_skeleton(target)
	var source_clip: Animation = _find_player(source).get_animation(SLIDE_CLIP)
	var source_to_character: Transform3D = ClipRetargeter.to_character_space(source_skeleton, source)
	var target_to_character: Transform3D = ClipRetargeter.to_character_space(target_skeleton, target)
	var source_map: BoneMap = ClipRetargeter.build_bone_map(source_skeleton, &"mixamo")
	var target_map: BoneMap = ClipRetargeter.build_bone_map(target_skeleton, &"rig_medium")

	# (r3) direction parity at every key of the baked clip.
	var track: int = baked.find_track(NodePath("Rig_Medium/Skeleton3D:hips"), Animation.TYPE_ROTATION_3D)
	check.call(track != -1, "r3: the baked clip has a hips rotation track")
	var worst: float = 0.0
	var worst_pair: String = ""
	var keys: int = baked.track_get_key_count(track) if track != -1 else 0
	for key: int in keys:
		var time: float = baked.track_get_key_time(track, key)
		var source_globals: Array[Transform3D] = ClipRetargeter.sample_globals(source_skeleton, source_to_character, source_clip, time)
		var target_globals: Array[Transform3D] = ClipRetargeter.sample_globals(target_skeleton, target_to_character, baked, time)
		for pair: Array in PARITY_PAIRS:
			var from_source: int = source_skeleton.find_bone(source_map.get_skeleton_bone_name(pair[0]))
			var to_source: int = source_skeleton.find_bone(source_map.get_skeleton_bone_name(pair[1]))
			var from_target: int = target_skeleton.find_bone(target_map.get_skeleton_bone_name(pair[0]))
			var to_target: int = target_skeleton.find_bone(target_map.get_skeleton_bone_name(pair[1]))
			if from_source == -1 or to_source == -1 or from_target == -1 or to_target == -1:
				continue
			var source_direction: Vector3 = (source_globals[to_source].origin - source_globals[from_source].origin).normalized()
			var target_direction: Vector3 = (target_globals[to_target].origin - target_globals[from_target].origin).normalized()
			var angle: float = rad_to_deg(source_direction.angle_to(target_direction))
			if angle > worst:
				worst = angle
				worst_pair = "%s->%s at %.3f s" % [pair[0], pair[1], time]
	check.call(keys > 40 and worst <= PARITY_TOLERANCE_DEG, "r3: limb directions match the source within %.1f degrees over %d keys (worst %.3f, %s)" % [PARITY_TOLERANCE_DEG, keys, worst, worst_pair])

	# (r4) the dash moves the body in code, so the hips stay in place; the slide is deep; no foot goes through the floor.
	var rest: Array[Transform3D] = ClipRetargeter.sample_globals(target_skeleton, target_to_character, null, 0.0)
	var hips: int = target_skeleton.find_bone("hips")
	var rest_hips: Vector3 = rest[hips].origin
	var plane_error: float = 0.0
	var deepest: float = INF
	var sink: float = 0.0
	for key: int in keys:
		var time: float = baked.track_get_key_time(track, key)
		var globals: Array[Transform3D] = ClipRetargeter.sample_globals(target_skeleton, target_to_character, baked, time)
		plane_error = maxf(plane_error, Vector2(globals[hips].origin.x - rest_hips.x, globals[hips].origin.z - rest_hips.z).length())
		deepest = minf(deepest, globals[hips].origin.y)
		for foot: StringName in FOOT_BONES:
			var index: int = target_skeleton.find_bone(foot)
			sink = maxf(sink, rest[index].origin.y - globals[index].origin.y)
	check.call(plane_error <= HIPS_PLANE_TOLERANCE, "r4: hips x and z stay at rest (worst %.4f m)" % plane_error)
	check.call(deepest <= rest_hips.y * SLIDE_DEPTH_MAX_SHARE, "r4: the deepest hips height %.3f m is at most %.0f %% of rest %.3f m" % [deepest, SLIDE_DEPTH_MAX_SHARE * 100.0, rest_hips.y])
	check.call(sink <= rest_hips.y * FOOT_SINK_MAX_SHARE, "r4: no foot or toes joint sinks more than %.0f %% of the rest hips height (worst %.3f m, limit %.3f m)" % [FOOT_SINK_MAX_SHARE * 100.0, sink, rest_hips.y * FOOT_SINK_MAX_SHARE])
	source.free()
	target.free()


func _collect_offenders(node: Node, offenders: Array[String]) -> void:
	var allowed: bool = node.get_class() == "Node3D" or node is Skeleton3D or node is AnimationPlayer
	if not allowed or node.get_script() != null:
		offenders.append("%s:%s" % [node.name, node.get_class()])
	for child: Node in node.get_children():
		_collect_offenders(child, offenders)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_player(child)
		if found != null:
			return found
	return null
