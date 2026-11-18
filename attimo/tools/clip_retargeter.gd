extends RefCounted
## Generic clip retargeter: brings an animation from any humanoid source skeleton (Mixamo, the Quaternius UAL, or
## Rig_Medium itself) onto the Mannequin's Rig_Medium skeleton. Used by tools/build_animation_library.gd (bake) and
## tests/smoke/test_retarget.gd (guards). Preload it, no class_name:
##   const ClipRetargeter := preload("res://tools/clip_retargeter.gd")
##
## Pivot vocabulary: Godot's SkeletonProfileHumanoid. A source skeleton is described by a "family" map (source bone
## name to profile bone name), the Mannequin by PROFILE_TO_RIG_MEDIUM, both applied through BoneMap objects. A new
## source family needs one const map here; a new clip of a known family needs no code (docs/ANIMATION-MAP.md, External
## clips).
##
## Method (independent of each skeleton's local bone axes, so a T-pose source and an A-pose source both work):
##  1. Rest alignment: for every mapped bone b take the rest direction from b to the next bone along PROFILE_TAIL that
##     is mapped on both skeletons, in character space. A_b is the shortest rotation from the source to the target
##     rest direction; Q_ref = A_b * (source rest global rotation).
##  2. Transfer: target global rotation = (source global rotation(t) * Q_ref^-1) * (target rest global rotation).
##     A swing correction then turns the target bone-to-tail direction exactly onto the source one (this matters when
##     the source has an extra bone between two mapped ones, like the Mixamo Spine1), keeping the twist of step 2.
##  3. Bones without a mapping on both skeletons hold their rest rotation relative to their parent.
##  4. Hips position: x and z stay at rest when pin_horizontal is true (the dash moves the body in code); y by floor
##     contact: the lowest foot or toes joint of the pose sits where the source's lowest joint sat, relative to its rest
##     contact, scaled by the hips height ratio, and never so low that a foot or toes joint sinks below its rest height
##     by more than FLOOR_MARGIN_SHARE of the hips height (the ankle clearance of the two rigs differs).
## Character space is the Skeleton3D's transform relative to its scene root times the bone pose; rotations use
## orthonormalized bases so unit scales of imported files cancel.

const FAMILY_MIXAMO: StringName = &"mixamo"
const FAMILY_UAL: StringName = &"ual"
const FAMILY_RIG_MEDIUM: StringName = &"rig_medium"

## SkeletonProfileHumanoid bone to Rig_Medium bone. hand.l and hand.r (the short palm bone) and every bone without
## an entry hold their rest rotation.
const PROFILE_TO_RIG_MEDIUM: Dictionary[StringName, StringName] = {
	&"Root": &"root",
	&"Hips": &"hips",
	&"Spine": &"spine",
	&"UpperChest": &"chest",
	&"Head": &"head",
	&"LeftUpperArm": &"upperarm.l",
	&"LeftLowerArm": &"lowerarm.l",
	&"LeftHand": &"wrist.l",
	&"LeftUpperLeg": &"upperleg.l",
	&"LeftLowerLeg": &"lowerleg.l",
	&"LeftFoot": &"foot.l",
	&"LeftToes": &"toes.l",
	&"RightUpperArm": &"upperarm.r",
	&"RightLowerArm": &"lowerarm.r",
	&"RightHand": &"wrist.r",
	&"RightUpperLeg": &"upperleg.r",
	&"RightLowerLeg": &"lowerleg.r",
	&"RightFoot": &"foot.r",
	&"RightToes": &"toes.r",
}

## Mixamo bone (name after normalize_name) to profile bone. Spine1 has no Rig_Medium counterpart and is bridged by the
## swing correction.
const MIXAMO_TO_PROFILE: Dictionary[StringName, StringName] = {
	&"Hips": &"Hips",
	&"Spine": &"Spine",
	&"Spine1": &"Chest",
	&"Spine2": &"UpperChest",
	&"Neck": &"Neck",
	&"Head": &"Head",
	&"LeftShoulder": &"LeftShoulder",
	&"LeftArm": &"LeftUpperArm",
	&"LeftForeArm": &"LeftLowerArm",
	&"LeftHand": &"LeftHand",
	&"LeftUpLeg": &"LeftUpperLeg",
	&"LeftLeg": &"LeftLowerLeg",
	&"LeftFoot": &"LeftFoot",
	&"LeftToeBase": &"LeftToes",
	&"RightShoulder": &"RightShoulder",
	&"RightArm": &"RightUpperArm",
	&"RightForeArm": &"RightLowerArm",
	&"RightHand": &"RightHand",
	&"RightUpLeg": &"RightUpperLeg",
	&"RightLeg": &"RightLowerLeg",
	&"RightFoot": &"RightFoot",
	&"RightToeBase": &"RightToes",
}

## Quaternius Universal Animation Library bone (UE-style skeleton) to profile bone. Ready for later clips, no clip
## uses it yet.
const UAL_TO_PROFILE: Dictionary[StringName, StringName] = {
	&"root": &"Root",
	&"pelvis": &"Hips",
	&"spine_01": &"Spine",
	&"spine_02": &"Chest",
	&"spine_03": &"UpperChest",
	&"neck_01": &"Neck",
	&"Head": &"Head",
	&"clavicle_l": &"LeftShoulder",
	&"upperarm_l": &"LeftUpperArm",
	&"lowerarm_l": &"LeftLowerArm",
	&"hand_l": &"LeftHand",
	&"thigh_l": &"LeftUpperLeg",
	&"calf_l": &"LeftLowerLeg",
	&"foot_l": &"LeftFoot",
	&"ball_l": &"LeftToes",
	&"clavicle_r": &"RightShoulder",
	&"upperarm_r": &"RightUpperArm",
	&"lowerarm_r": &"RightLowerArm",
	&"hand_r": &"RightHand",
	&"thigh_r": &"RightUpperLeg",
	&"calf_r": &"RightLowerLeg",
	&"foot_r": &"RightFoot",
	&"ball_r": &"RightToes",
}

## The main chain of the humanoid profile: a bone to the next bone that gives its direction. SkeletonProfile's own
## get_bone_tail() is empty for most bones, so the chain lives here. Bones without an entry keep the rotation transfer
## only.
const PROFILE_TAIL: Dictionary[StringName, StringName] = {
	&"Hips": &"Spine",
	&"Spine": &"Chest",
	&"Chest": &"UpperChest",
	&"UpperChest": &"Neck",
	&"Neck": &"Head",
	&"LeftShoulder": &"LeftUpperArm",
	&"LeftUpperArm": &"LeftLowerArm",
	&"LeftLowerArm": &"LeftHand",
	&"LeftUpperLeg": &"LeftLowerLeg",
	&"LeftLowerLeg": &"LeftFoot",
	&"LeftFoot": &"LeftToes",
	&"RightShoulder": &"RightUpperArm",
	&"RightUpperArm": &"RightLowerArm",
	&"RightLowerArm": &"RightHand",
	&"RightUpperLeg": &"RightLowerLeg",
	&"RightLowerLeg": &"RightFoot",
	&"RightFoot": &"RightToes",
}

## Facing correction per family in degrees about the vertical axis, applied to the source before the transfer. All
## three families face +Z like the Mannequin (test_retarget direction parity catches a wrong value).
const FACING_YAW_DEG: Dictionary[StringName, float] = {
	&"mixamo": 0.0,
	&"ual": 0.0,
	&"rig_medium": 0.0,
}

## Profile bones that define the floor contact of the hips height.
const FOOT_PROFILE_BONES: Array[StringName] = [&"LeftFoot", &"LeftToes", &"RightFoot", &"RightToes"]
## Profile bones every source has to provide; a missing one fails the retarget.
const REQUIRED_PROFILE_BONES: Array[StringName] = [
	&"Hips", &"Spine", &"Head",
	&"LeftUpperArm", &"LeftLowerArm", &"RightUpperArm", &"RightLowerArm",
	&"LeftUpperLeg", &"LeftLowerLeg", &"LeftFoot", &"RightUpperLeg", &"RightLowerLeg", &"RightFoot",
]
const SAMPLE_RATE: float = 30.0
## Most a foot or toes joint may sink below its rest height, as a share of the target's rest hips height.
const FLOOR_MARGIN_SHARE: float = 0.08
const MIN_DIRECTION_LENGTH: float = 0.00001
## Tracks the retargeter writes are Rig_Medium-like: rotation for every bone, position for the hips and for root bones.
const PROFILE_HIPS: StringName = &"Hips"


## Per mapped bone data of one retarget run.
class BonePair extends RefCounted:
	var profile_bone: StringName = &""
	var source: int = -1
	var target: int = -1
	var source_tail: int = -1
	var target_tail: int = -1
	var q_ref_inverse: Quaternion = Quaternion.IDENTITY
	var target_rest_rotation: Quaternion = Quaternion.IDENTITY
	## Rest direction from the target bone to its tail joint in the frame of the target bone's rest rotation.
	var tail_local: Vector3 = Vector3.ZERO


## Maps a source family's bone names to profile bone names. The rig_medium family is the inverse of
## PROFILE_TO_RIG_MEDIUM. Unknown family: empty dictionary.
static func family_to_profile(family: StringName) -> Dictionary[StringName, StringName]:
	if family == FAMILY_MIXAMO:
		return MIXAMO_TO_PROFILE
	if family == FAMILY_UAL:
		return UAL_TO_PROFILE
	var result: Dictionary[StringName, StringName] = {}
	if family == FAMILY_RIG_MEDIUM:
		for profile_bone: StringName in PROFILE_TO_RIG_MEDIUM:
			result[PROFILE_TO_RIG_MEDIUM[profile_bone]] = profile_bone
	return result


## The name a family map is keyed by. Mixamo names lose the "mixamorig", an optional digit string and one ":" or "_"
## (the engine imports "mixamorig:Hips" as "mixamorig_Hips"). Other families use the name as it is.
static func normalize_name(family: StringName, bone_name: String) -> StringName:
	if family != FAMILY_MIXAMO or not bone_name.begins_with("mixamorig"):
		return StringName(bone_name)
	var rest: String = bone_name.substr("mixamorig".length())
	while not rest.is_empty() and rest[0] >= "0" and rest[0] <= "9":
		rest = rest.substr(1)
	if not rest.is_empty() and (rest[0] == ":" or rest[0] == "_"):
		rest = rest.substr(1)
	return StringName(rest)


## A BoneMap on SkeletonProfileHumanoid for `family` on `skeleton`: every bone the family knows is entered under its
## profile name. Profile bones the skeleton does not have stay empty.
static func build_bone_map(skeleton: Skeleton3D, family: StringName) -> BoneMap:
	var bone_map: BoneMap = BoneMap.new()
	bone_map.profile = SkeletonProfileHumanoid.new()
	var names: Dictionary[StringName, StringName] = family_to_profile(family)
	for bone: int in skeleton.get_bone_count():
		var actual: String = skeleton.get_bone_name(bone)
		var normalized: StringName = normalize_name(family, actual)
		if names.has(normalized):
			bone_map.set_skeleton_bone_name(names[normalized], StringName(actual))
	return bone_map


## The Skeleton3D's transform relative to `root` (the root's own transform is not included). Works without the nodes
## being in a tree.
static func to_character_space(skeleton: Skeleton3D, root: Node) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var node: Node = skeleton
	while node != null and node != root:
		if node is Node3D:
			result = (node as Node3D).transform * result
		node = node.get_parent()
	return result


## Character-space transform of every bone at `time` of `animation` (null: rest pose). Bones without a track use their
## rest. The nodes need not be in a tree; no Skeleton3D pose cache is read.
static func sample_globals(skeleton: Skeleton3D, skeleton_to_character: Transform3D, animation: Animation, time: float) -> Array[Transform3D]:
	var count: int = skeleton.get_bone_count()
	var rotation_tracks: PackedInt32Array = PackedInt32Array()
	var position_tracks: PackedInt32Array = PackedInt32Array()
	rotation_tracks.resize(count)
	position_tracks.resize(count)
	rotation_tracks.fill(-1)
	position_tracks.fill(-1)
	if animation != null:
		for track: int in animation.get_track_count():
			var path: NodePath = animation.track_get_path(track)
			if path.get_subname_count() == 0:
				continue
			var bone: int = skeleton.find_bone(path.get_subname(0))
			if bone == -1:
				continue
			var type: int = animation.track_get_type(track)
			if type == Animation.TYPE_ROTATION_3D:
				rotation_tracks[bone] = track
			elif type == Animation.TYPE_POSITION_3D:
				position_tracks[bone] = track
	var globals: Array[Transform3D] = []
	globals.resize(count)
	for bone: int in hierarchy_order(skeleton):
		var rest: Transform3D = skeleton.get_bone_rest(bone)
		var rotation: Quaternion = rest.basis.get_rotation_quaternion()
		var position: Vector3 = rest.origin
		if rotation_tracks[bone] != -1:
			rotation = animation.rotation_track_interpolate(rotation_tracks[bone], time)
		if position_tracks[bone] != -1:
			position = animation.position_track_interpolate(position_tracks[bone], time)
		var local: Transform3D = Transform3D(Basis(rotation), position)
		var parent: int = skeleton.get_bone_parent(bone)
		globals[bone] = (skeleton_to_character if parent == -1 else globals[parent]) * local
	return globals


## Bone indices with every parent before its children.
static func hierarchy_order(skeleton: Skeleton3D) -> PackedInt32Array:
	var order: PackedInt32Array = PackedInt32Array()
	var placed: Dictionary[int, bool] = {}
	var count: int = skeleton.get_bone_count()
	while order.size() < count:
		var progressed: bool = false
		for bone: int in count:
			if placed.has(bone):
				continue
			var parent: int = skeleton.get_bone_parent(bone)
			if parent == -1 or placed.has(parent):
				order.append(bone)
				placed[bone] = true
				progressed = true
		if not progressed:
			break
	return order


## Retargets `clip` (an animation of the skeleton in `source_root`) of `family` onto `target_skeleton`. Track paths are
## track_prefix + bone name, for example "Rig_Medium/Skeleton3D:". Returns null (after push_error) when a required bone
## has no mapping or a key is not finite.
static func retarget(source_root: Node, clip: Animation, family: StringName, target_skeleton: Skeleton3D, target_to_character: Transform3D, track_prefix: String, pin_horizontal: bool) -> Animation:
	var source_skeleton: Skeleton3D = _find_skeleton(source_root)
	if source_skeleton == null or clip == null:
		push_error("retarget: no source skeleton or no clip")
		return null
	var source_to_character: Transform3D = to_character_space(source_skeleton, source_root)
	var source_map: BoneMap = build_bone_map(source_skeleton, family)
	var target_map: BoneMap = build_bone_map(target_skeleton, FAMILY_RIG_MEDIUM)
	var yaw: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(FACING_YAW_DEG.get(family, 0.0)))), Vector3.ZERO)

	var source_rest: Array[Transform3D] = _yawed(sample_globals(source_skeleton, source_to_character, null, 0.0), yaw)
	var target_rest: Array[Transform3D] = sample_globals(target_skeleton, target_to_character, null, 0.0)

	# Pair every profile bone that exists on both skeletons.
	var pairs: Dictionary[StringName, BonePair] = {}
	var pair_of_target: Array[BonePair] = []
	pair_of_target.resize(target_skeleton.get_bone_count())
	for profile_bone: StringName in PROFILE_TO_RIG_MEDIUM:
		var source_bone: int = source_skeleton.find_bone(source_map.get_skeleton_bone_name(profile_bone))
		var target_bone: int = target_skeleton.find_bone(target_map.get_skeleton_bone_name(profile_bone))
		if source_bone == -1 or target_bone == -1:
			continue
		var pair: BonePair = BonePair.new()
		pair.profile_bone = profile_bone
		pair.source = source_bone
		pair.target = target_bone
		pairs[profile_bone] = pair
		pair_of_target[target_bone] = pair
	for required: StringName in REQUIRED_PROFILE_BONES:
		if not pairs.has(required):
			push_error("retarget: family %s has no bone for the required profile bone %s" % [family, required])
			return null

	# Rest alignment (step 1).
	for profile_bone: StringName in pairs:
		var pair: BonePair = pairs[profile_bone]
		var tail: StringName = PROFILE_TAIL.get(profile_bone, &"")
		while tail != &"" and not pairs.has(tail):
			tail = PROFILE_TAIL.get(tail, &"")
		var alignment: Quaternion = Quaternion.IDENTITY
		var target_rest_rotation: Quaternion = target_rest[pair.target].basis.get_rotation_quaternion()
		if tail != &"":
			var tail_pair: BonePair = pairs[tail]
			pair.source_tail = tail_pair.source
			pair.target_tail = tail_pair.target
			var source_direction: Vector3 = source_rest[pair.source_tail].origin - source_rest[pair.source].origin
			var target_direction: Vector3 = target_rest[pair.target_tail].origin - target_rest[pair.target].origin
			if source_direction.length() > MIN_DIRECTION_LENGTH and target_direction.length() > MIN_DIRECTION_LENGTH:
				alignment = AimPoseModifier.rotation_between(source_direction, target_direction)
				pair.tail_local = target_rest_rotation.inverse() * target_direction
			else:
				pair.source_tail = -1
				pair.target_tail = -1
		pair.q_ref_inverse = (alignment * source_rest[pair.source].basis.get_rotation_quaternion()).inverse()
		pair.target_rest_rotation = target_rest_rotation

	# Floor contact references.
	var source_feet: PackedInt32Array = PackedInt32Array()
	var target_feet: PackedInt32Array = PackedInt32Array()
	for profile_bone: StringName in FOOT_PROFILE_BONES:
		if pairs.has(profile_bone):
			source_feet.append((pairs[profile_bone] as BonePair).source)
			target_feet.append((pairs[profile_bone] as BonePair).target)
	var hips_pair: BonePair = pairs[PROFILE_HIPS]
	var hips: int = hips_pair.target
	var hips_parent: int = target_skeleton.get_bone_parent(hips)
	var height_ratio: float = target_rest[hips].origin.y / maxf(source_rest[hips_pair.source].origin.y, 0.0001)
	var source_floor_rest: float = _lowest(source_rest, source_feet)
	var target_floor_rest: float = _lowest(target_rest, target_feet)
	var source_hips_start: Vector3 = Vector3.ZERO

	# Output animation.
	var animation: Animation = Animation.new()
	animation.length = clip.length
	animation.loop_mode = Animation.LOOP_NONE
	animation.step = 1.0 / SAMPLE_RATE
	var rotation_tracks: PackedInt32Array = PackedInt32Array()
	var position_tracks: PackedInt32Array = PackedInt32Array()
	var bone_count: int = target_skeleton.get_bone_count()
	rotation_tracks.resize(bone_count)
	position_tracks.resize(bone_count)
	position_tracks.fill(-1)
	for bone: int in bone_count:
		var path: NodePath = NodePath(track_prefix + target_skeleton.get_bone_name(bone))
		rotation_tracks[bone] = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(rotation_tracks[bone], path)
		animation.track_set_interpolation_type(rotation_tracks[bone], Animation.INTERPOLATION_LINEAR)
		if bone == hips or target_skeleton.get_bone_parent(bone) == -1:
			position_tracks[bone] = animation.add_track(Animation.TYPE_POSITION_3D)
			animation.track_set_path(position_tracks[bone], path)
			animation.track_set_interpolation_type(position_tracks[bone], Animation.INTERPOLATION_LINEAR)
		var scale_track: int = animation.add_track(Animation.TYPE_SCALE_3D)
		animation.track_set_path(scale_track, path)
		animation.scale_track_insert_key(scale_track, 0.0, Vector3.ONE)

	var times: PackedFloat32Array = PackedFloat32Array()
	var steps: int = int(floor(clip.length * SAMPLE_RATE + 0.001))
	for step: int in steps + 1:
		times.append(float(step) / SAMPLE_RATE)
	if clip.length - times[times.size() - 1] > 0.001:
		times.append(clip.length)

	var order: PackedInt32Array = hierarchy_order(target_skeleton)
	var character_rotation: Quaternion = target_to_character.basis.get_rotation_quaternion()
	var previous: Array[Quaternion] = []
	previous.resize(bone_count)
	for time_index: int in times.size():
		var time: float = times[time_index]
		var source_globals: Array[Transform3D] = _yawed(sample_globals(source_skeleton, source_to_character, clip, time), yaw)
		if time_index == 0:
			source_hips_start = source_globals[hips_pair.source].origin

		# Steps 2 and 3: character-space global rotation of every target bone.
		var global_rotation: Array[Quaternion] = []
		global_rotation.resize(bone_count)
		for bone: int in order:
			var parent: int = target_skeleton.get_bone_parent(bone)
			var pair: BonePair = pair_of_target[bone]
			if pair != null:
				var delta: Quaternion = source_globals[pair.source].basis.get_rotation_quaternion() * pair.q_ref_inverse
				var rotation: Quaternion = delta * pair.target_rest_rotation
				if pair.source_tail != -1:
					var want: Vector3 = source_globals[pair.source_tail].origin - source_globals[pair.source].origin
					var have: Vector3 = rotation * pair.tail_local
					if want.length() > MIN_DIRECTION_LENGTH and have.length() > MIN_DIRECTION_LENGTH:
						rotation = AimPoseModifier.rotation_between(have, want) * rotation
				global_rotation[bone] = rotation.normalized()
			else:
				var rest_local: Quaternion = target_skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
				global_rotation[bone] = (character_rotation if parent == -1 else global_rotation[parent]) * rest_local

		# Local rotations and the pose with the hips at rest, for the floor contact.
		var local_rotation: Array[Quaternion] = []
		local_rotation.resize(bone_count)
		var pose_globals: Array[Transform3D] = []
		pose_globals.resize(bone_count)
		for bone: int in order:
			var parent: int = target_skeleton.get_bone_parent(bone)
			var local: Quaternion = (character_rotation.inverse() if parent == -1 else global_rotation[parent].inverse()) * global_rotation[bone]
			local = local.normalized()
			if time_index > 0 and previous[bone].dot(local) < 0.0:
				local = Quaternion(-local.x, -local.y, -local.z, -local.w)
			local_rotation[bone] = local
			previous[bone] = local
			var local_transform: Transform3D = Transform3D(Basis(local), target_skeleton.get_bone_rest(bone).origin)
			pose_globals[bone] = (Transform3D.IDENTITY if parent == -1 else pose_globals[parent]) * local_transform
		var pose_character: Array[Transform3D] = []
		pose_character.resize(bone_count)
		for bone: int in bone_count:
			pose_character[bone] = target_to_character * pose_globals[bone]

		# Step 4: hips position.
		var offset: Vector3 = Vector3.ZERO
		offset.y = target_floor_rest + height_ratio * (_lowest(source_globals, source_feet) - source_floor_rest) - _lowest(pose_character, target_feet)
		# No foot or toes joint may sink below its rest height by more than FLOOR_MARGIN_SHARE of the hips height: the
		# Mannequin's ankle sits much higher above its sole than the source's, so the contact rule alone would push the
		# ankle through the floor when the foot is not flat.
		for foot_index: int in target_feet.size():
			var foot_bone: int = target_feet[foot_index]
			offset.y = maxf(offset.y, target_rest[foot_bone].origin.y - FLOOR_MARGIN_SHARE * target_rest[hips].origin.y - pose_character[foot_bone].origin.y)
		if not pin_horizontal:
			var travelled: Vector3 = source_globals[hips_pair.source].origin - source_hips_start
			offset.x = travelled.x * height_ratio
			offset.z = travelled.z * height_ratio
		var hips_character: Vector3 = target_rest[hips].origin + offset
		var parent_global: Transform3D = Transform3D.IDENTITY if hips_parent == -1 else pose_globals[hips_parent]
		var hips_local: Vector3 = parent_global.affine_inverse() * (target_to_character.affine_inverse() * hips_character)

		for bone: int in bone_count:
			var value: Quaternion = local_rotation[bone]
			if not (is_finite(value.x) and is_finite(value.y) and is_finite(value.z) and is_finite(value.w)):
				push_error("retarget: non-finite rotation for %s at %.3f s" % [target_skeleton.get_bone_name(bone), time])
				return null
			animation.rotation_track_insert_key(rotation_tracks[bone], time, value)
			if position_tracks[bone] != -1:
				var position: Vector3 = hips_local if bone == hips else target_skeleton.get_bone_rest(bone).origin
				if not position.is_finite():
					push_error("retarget: non-finite hips position at %.3f s" % time)
					return null
				if bone == hips or time_index == 0:
					animation.position_track_insert_key(position_tracks[bone], time, position)
	return animation


## Lowest character-space height of the listed bones; 0 for an empty list.
static func _lowest(globals: Array[Transform3D], bones: PackedInt32Array) -> float:
	if bones.is_empty():
		return 0.0
	var lowest: float = INF
	for bone: int in bones:
		lowest = minf(lowest, globals[bone].origin.y)
	return lowest


static func _yawed(globals: Array[Transform3D], yaw: Transform3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	result.resize(globals.size())
	for index: int in globals.size():
		result[index] = yaw * globals[index]
	return result


static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null
