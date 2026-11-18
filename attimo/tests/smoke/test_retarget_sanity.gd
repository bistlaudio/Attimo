extends RefCounted
## Quick 261118-qi3: the headless bone-sanity gate for every retargeted UAL clip in the Rig_Medium library (the
## "Retarget quality rule" of docs/ANIMATION-MAP.md). A clip that fails is dropped (tools/build_animation_library.gd
## UAL_DROPPED) and its KayKit fallback stays. Read-only: fixed res:// paths, nothing is written.
##   S1 every track path starts with Rig_Medium/Skeleton3D: and names a bone the Mannequin has
##   S2 every bone-to-parent distance stays within 2 percent or 1 cm of rest (no stretched limbs; hips and root move)
##   S3 clearance: the closest approach of hand.l, hand.r, lowerarm.l, lowerarm.r to the head origin and to the
##      hips-to-chest segment is no smaller than the same minimum over all native clips minus CLEARANCE_SLACK
##   S4 upright clips: head above chest above hips, hips height 0.6 to 1.2 times rest
##   S5 upright clips: foot.l and foot.r never go below the native minimum foot height minus FOOT_SLACK
##   S6 loop clips: hips within 0.15 m of rest horizontally, first and last pose within 10 degrees on every bone
##   S7 every clip (also the lying and rolling ones): hips, chest and head never sink below the floor by more than
##      FOOT_SLACK (the retarget floor rule only knows the feet, so a roll can push the body through the floor)

const ClipRetargeter := preload("res://tools/clip_retargeter.gd")

const MANNEQUIN_GLB: String = "res://assets/characters/mannequin/Mannequin_Medium.glb"
const LIBRARY_PATH: String = "res://assets/animations/rig_medium/rig_medium_library.res"
const TRACK_PREFIX: String = "Rig_Medium/Skeleton3D:"
const UAL_PREFIX: String = "UAL_"
## UAL clips of quick 261118-qi3 (13 planned plus Jump_Start as the Jump 2 take), library plus dropped.
const UAL_CLIP_COUNT: int = 14
const SAMPLE_STEP: float = 1.0 / 30.0
const STRETCH_SHARE: float = 0.02
const STRETCH_ABSOLUTE: float = 0.01
const CLEARANCE_SLACK: float = 0.05
const FOOT_SLACK: float = 0.05
const HIPS_MIN_SHARE: float = 0.6
const HIPS_MAX_SHARE: float = 1.2
const LOOP_HIPS_DRIFT: float = 0.15
const LOOP_SEAM_DEG: float = 10.0
## Clips that are not upright by design.
const NOT_UPRIGHT: Array[StringName] = [&"UAL_Roll", &"UAL_Death01"]
const ARM_BONES: Array[StringName] = [&"hand.l", &"hand.r", &"lowerarm.l", &"lowerarm.r"]
const FOOT_BONES: Array[StringName] = [&"foot.l", &"foot.r"]
const BODY_BONES: Array[StringName] = [&"hips", &"chest", &"head"]


func run(_tree: SceneTree, check: Callable) -> void:
	var library: AnimationLibrary = load(LIBRARY_PATH) as AnimationLibrary
	check.call(library != null, "rig_medium_library.res loads")
	var mannequin: Node = (load(MANNEQUIN_GLB) as PackedScene).instantiate()
	var skeleton: Skeleton3D = _find_skeleton(mannequin)
	if library == null or skeleton == null:
		mannequin.free()
		return
	var to_character: Transform3D = ClipRetargeter.to_character_space(skeleton, mannequin)
	var rest: Array[Transform3D] = ClipRetargeter.sample_globals(skeleton, to_character, null, 0.0)
	var rest_hips_height: float = rest[skeleton.find_bone(&"hips")].origin.y

	# Baselines over the native clips (every library clip that is neither UAL nor the retargeted Running_Slide).
	var baseline_clearance: float = INF
	var baseline_foot: float = INF
	for clip: StringName in library.get_animation_list():
		if String(clip).begins_with(UAL_PREFIX) or clip == &"Running_Slide":
			continue
		var metrics: Dictionary = _measure(skeleton, to_character, library.get_animation(clip))
		baseline_clearance = minf(baseline_clearance, float(metrics["clearance"]))
		baseline_foot = minf(baseline_foot, float(metrics["foot"]))
	var clearance_floor: float = baseline_clearance - CLEARANCE_SLACK
	var foot_floor: float = baseline_foot - FOOT_SLACK
	print("SANITY: native clearance min %.3f m (limit %.3f), native foot min %.3f m (limit %.3f)" % [baseline_clearance, clearance_floor, baseline_foot, foot_floor])
	check.call(is_finite(baseline_clearance) and is_finite(baseline_foot), "S0: the native baselines are measured")

	_check_self(skeleton, rest, clearance_floor, check)

	var dropped: Array[StringName] = _dropped_list()
	var gated: int = 0
	for clip: StringName in library.get_animation_list():
		if not String(clip).begins_with(UAL_PREFIX):
			continue
		gated += 1
		var animation: Animation = library.get_animation(clip)
		var bad_paths: int = 0
		for track: int in animation.get_track_count():
			var path: String = str(animation.track_get_path(track))
			if not path.begins_with(TRACK_PREFIX) or skeleton.find_bone(path.substr(TRACK_PREFIX.length())) == -1:
				bad_paths += 1
		check.call(bad_paths == 0 and animation.get_track_count() > 0, "S1 %s: every track binds to a Mannequin bone (%d bad of %d)" % [clip, bad_paths, animation.get_track_count()])
		var metrics: Dictionary = _measure(skeleton, to_character, animation)
		var upright: bool = not NOT_UPRIGHT.has(clip)
		print("SANITY %s: stretch %.4f m, clearance %.3f m, hips %.2f..%.2f of rest, foot min %.3f m, body min %.3f m, upright=%s" % [clip, metrics["stretch"], metrics["clearance"], float(metrics["hips_min"]) / rest_hips_height, float(metrics["hips_max"]) / rest_hips_height, metrics["foot"], metrics["body"], upright])
		check.call(float(metrics["stretch"]) <= 0.0001 or bool(metrics["stretch_ok"]), "S2 %s: no bone stretches beyond %.0f %% or %.0f cm (worst %.4f m)" % [clip, STRETCH_SHARE * 100.0, STRETCH_ABSOLUTE * 100.0, metrics["stretch"]])
		check.call(float(metrics["clearance"]) >= clearance_floor, "S3 %s: arm clearance %.3f m is at least %.3f m" % [clip, metrics["clearance"], clearance_floor])
		if upright:
			check.call(bool(metrics["ordered"]), "S4 %s: head above chest above hips in every sample" % clip)
			check.call(float(metrics["hips_min"]) >= rest_hips_height * HIPS_MIN_SHARE and float(metrics["hips_max"]) <= rest_hips_height * HIPS_MAX_SHARE, "S4 %s: hips height %.2f..%.2f of rest stays in %.1f..%.1f" % [clip, float(metrics["hips_min"]) / rest_hips_height, float(metrics["hips_max"]) / rest_hips_height, HIPS_MIN_SHARE, HIPS_MAX_SHARE])
			check.call(float(metrics["foot"]) >= foot_floor, "S5 %s: lowest foot %.3f m is at least %.3f m" % [clip, metrics["foot"], foot_floor])
		check.call(float(metrics["body"]) >= -FOOT_SLACK, "S7 %s: hips, chest and head stay above the floor (lowest %.3f m, limit %.3f m)" % [clip, metrics["body"], -FOOT_SLACK])
		if animation.loop_mode == Animation.LOOP_LINEAR:
			check.call(float(metrics["hips_drift"]) <= LOOP_HIPS_DRIFT, "S6 %s: hips drift %.3f m horizontally (at most %.2f)" % [clip, metrics["hips_drift"], LOOP_HIPS_DRIFT])
			var seam: float = _seam_degrees(animation)
			check.call(seam <= LOOP_SEAM_DEG, "S6 %s: first and last pose differ by %.2f degrees (at most %.0f)" % [clip, seam, LOOP_SEAM_DEG])
	check.call(gated + dropped.size() == UAL_CLIP_COUNT, "the library holds %d UAL clips and %d are dropped: 14 in total" % [gated, dropped.size()])
	mannequin.free()


## The documented drop list of tools/build_animation_library.gd (read from the script constants, the tool is not run).
func _dropped_list() -> Array[StringName]:
	var script: GDScript = load("res://tools/build_animation_library.gd") as GDScript
	var result: Array[StringName] = []
	for entry: Variant in script.get_script_constant_map().get("UAL_DROPPED", []):
		result.append(StringName(entry))
	return result


## Samples `animation` every 1/30 s and returns the worst values of every metric.
func _measure(skeleton: Skeleton3D, to_character: Transform3D, animation: Animation) -> Dictionary:
	var rest: Array[Transform3D] = ClipRetargeter.sample_globals(skeleton, to_character, null, 0.0)
	var hips: int = skeleton.find_bone(&"hips")
	var chest: int = skeleton.find_bone(&"chest")
	var head: int = skeleton.find_bone(&"head")
	var result: Dictionary = {
		"stretch": 0.0, "stretch_ok": true, "clearance": INF, "foot": INF,
		"hips_min": INF, "hips_max": -INF, "hips_drift": 0.0, "ordered": true, "body": INF,
	}
	var steps: int = int(floor(animation.length / SAMPLE_STEP + 0.001))
	for step: int in steps + 1:
		var time: float = minf(float(step) * SAMPLE_STEP, animation.length)
		var globals: Array[Transform3D] = ClipRetargeter.sample_globals(skeleton, to_character, animation, time)
		for bone: int in skeleton.get_bone_count():
			var parent: int = skeleton.get_bone_parent(bone)
			if parent == -1 or bone == hips:
				continue
			var length: float = globals[bone].origin.distance_to(globals[parent].origin)
			var rest_length: float = rest[bone].origin.distance_to(rest[parent].origin)
			var error: float = absf(length - rest_length)
			result["stretch"] = maxf(float(result["stretch"]), error)
			if error > maxf(STRETCH_ABSOLUTE, STRETCH_SHARE * rest_length):
				result["stretch_ok"] = false
		result["clearance"] = minf(float(result["clearance"]), _clearance(skeleton, globals))
		for foot_name: StringName in FOOT_BONES:
			result["foot"] = minf(float(result["foot"]), globals[skeleton.find_bone(foot_name)].origin.y)
		for body_name: StringName in BODY_BONES:
			result["body"] = minf(float(result["body"]), globals[skeleton.find_bone(body_name)].origin.y)
		var hips_origin: Vector3 = globals[hips].origin
		result["hips_min"] = minf(float(result["hips_min"]), hips_origin.y)
		result["hips_max"] = maxf(float(result["hips_max"]), hips_origin.y)
		result["hips_drift"] = maxf(float(result["hips_drift"]), Vector2(hips_origin.x - rest[hips].origin.x, hips_origin.z - rest[hips].origin.z).length())
		if not (globals[head].origin.y > globals[chest].origin.y and globals[chest].origin.y > hips_origin.y):
			result["ordered"] = false
	return result


## Closest approach of the hands and forearms to the head origin and to the hips-to-chest segment.
func _clearance(skeleton: Skeleton3D, globals: Array[Transform3D]) -> float:
	var head: Vector3 = globals[skeleton.find_bone(&"head")].origin
	var hips: Vector3 = globals[skeleton.find_bone(&"hips")].origin
	var chest: Vector3 = globals[skeleton.find_bone(&"chest")].origin
	var closest: float = INF
	for bone_name: StringName in ARM_BONES:
		var point: Vector3 = globals[skeleton.find_bone(bone_name)].origin
		closest = minf(closest, point.distance_to(head))
		closest = minf(closest, point.distance_to(Geometry3D.get_closest_point_to_segment(point, hips, chest)))
	return closest


## Largest rotation difference in degrees between the first and the last key of any rotation track.
func _seam_degrees(animation: Animation) -> float:
	var worst: float = 0.0
	for track: int in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var first: Quaternion = animation.rotation_track_interpolate(track, 0.0)
		var last: Quaternion = animation.rotation_track_interpolate(track, animation.length)
		worst = maxf(worst, rad_to_deg(first.angle_to(last)))
	return worst


## The gate must be able to fail: a synthetic pose with a hand inside the head violates the clearance limit, a rest
## pose does not.
func _check_self(skeleton: Skeleton3D, rest: Array[Transform3D], clearance_floor: float, check: Callable) -> void:
	var rest_clearance: float = _clearance(skeleton, rest)
	check.call(rest_clearance >= clearance_floor, "self-check: the rest pose passes the clearance limit (%.3f >= %.3f)" % [rest_clearance, clearance_floor])
	var broken: Array[Transform3D] = rest.duplicate()
	var hand: int = skeleton.find_bone(&"hand.l")
	broken[hand] = Transform3D(broken[hand].basis, rest[skeleton.find_bone(&"head")].origin)
	var broken_clearance: float = _clearance(skeleton, broken)
	check.call(broken_clearance < clearance_floor, "self-check: a hand inside the head fails the clearance limit (%.3f < %.3f)" % [broken_clearance, clearance_floor])


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null
