extends SceneTree
## Editor-time tool: merges the wanted KayKit Rig_Medium clips into one AnimationLibrary and sets loop modes, then bakes
## the RETARGETED external clips (conformed by tools/conform_external_clip.gd) onto Rig_Medium through
## tools/clip_retargeter.gd.
## Run: bash attimo/tests/run.sh --tool res://tools/build_animation_library.gd
## Later phases extend SOURCES / WANTED / RETARGETED and re-run; the output is regenerated deterministically.

const ClipRetargeter := preload("res://tools/clip_retargeter.gd")

const SOURCES: Array[String] = [
	"res://assets/animations/rig_medium/Rig_Medium_General.glb",
	"res://assets/animations/rig_medium/Rig_Medium_MovementBasic.glb",
	"res://assets/animations/rig_medium/Rig_Medium_MovementAdvanced.glb",
	"res://assets/animations/rig_medium/Rig_Medium_CombatRanged.glb",
]
const OUTPUT: String = "res://assets/animations/rig_medium/rig_medium_library.res"
const WANTED: Array[StringName] = [&"Idle_A", &"Running_A", &"Jump_Start", &"Jump_Idle", &"Jump_Land", &"Dodge_Forward", &"Ranged_1H_Aiming",
	&"Running_Strafe_Left", &"Running_Strafe_Right", &"Walking_Backwards", &"Dodge_Left", &"Dodge_Right", &"Dodge_Backward"]
## KayKit clips import as non-looping (Pitfall 2), so the looping set is declared here.
const LOOPING: Array[StringName] = [&"Idle_A", &"Running_A", &"Jump_Idle", &"Running_Strafe_Left", &"Running_Strafe_Right", &"Walking_Backwards"]
## The Dodge clips drift the root bone (Forward +0.25 m, Left/Right 0.5 m, Backward -0.65 m) and snap back. The dash moves the body
## in code, so the root position is pinned to its first key here. Root rotation is left alone: the strafe clips carry their
## direction in the root yaw, and AnimationTree root motion would strip it too (measured 2026-11-14).
const ROOT_PINNED: Array[StringName] = [&"Dodge_Forward", &"Dodge_Left", &"Dodge_Right", &"Dodge_Backward"]
const ROOT_TRACK: NodePath = ^"Rig_Medium/Skeleton3D:root"
const MANNEQUIN: String = "res://assets/characters/mannequin/Mannequin_Medium.glb"
const TRACK_PREFIX: String = "Rig_Medium/Skeleton3D:"
## External clips baked onto Rig_Medium (quick 261118-qbt, DEV-04). Row: clip name, conformed source scene, family of
## tools/clip_retargeter.gd, loop, pin_horizontal (the body is moved in code, so the hips stay in place).
const RETARGETED: Array[Dictionary] = [
	{
		"clip": &"Running_Slide",
		"source": "res://assets/animations/external/mixamo/running_slide.scn",
		"family": &"mixamo",
		"loop": false,
		"pin_horizontal": true,
	},
]


func _initialize() -> void:
	var library := AnimationLibrary.new()
	for path: String in SOURCES:
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			push_error("Cannot load %s" % path)
			quit(1)
			return
		var instance: Node = scene.instantiate()
		var player := instance.get_node("AnimationPlayer") as AnimationPlayer
		for clip: StringName in player.get_animation_list():
			if clip in WANTED:
				var animation := player.get_animation(clip).duplicate() as Animation
				animation.loop_mode = Animation.LOOP_LINEAR if clip in LOOPING else Animation.LOOP_NONE
				library.add_animation(clip, animation)
		instance.free()
	var missing: Array[StringName] = []
	for clip: StringName in WANTED:
		if not library.has_animation(clip):
			missing.append(clip)
	if not missing.is_empty():
		push_error("Missing clips: %s" % [missing])
		quit(1)
		return
	for clip: StringName in ROOT_PINNED:
		var animation: Animation = library.get_animation(clip)
		var track: int = animation.find_track(ROOT_TRACK, Animation.TYPE_POSITION_3D)
		if track == -1 or animation.track_get_key_count(track) == 0:
			push_error("ROOT_PINNED clip %s has no root position track" % clip)
			quit(1)
			return
		var first: Variant = animation.track_get_key_value(track, 0)
		for key: int in animation.track_get_key_count(track):
			animation.track_set_key_value(track, key, first)
	var mannequin: Node = (load(MANNEQUIN) as PackedScene).instantiate()
	var target_skeleton: Skeleton3D = _find_skeleton(mannequin)
	var target_to_character: Transform3D = ClipRetargeter.to_character_space(target_skeleton, mannequin)
	for row: Dictionary in RETARGETED:
		var clip: StringName = row["clip"] as StringName
		var source_root: Node = (load(String(row["source"])) as PackedScene).instantiate()
		var source_player: AnimationPlayer = _find_player(source_root)
		var baked: Animation = null
		if source_player != null and source_player.has_animation(clip):
			baked = ClipRetargeter.retarget(source_root, source_player.get_animation(clip), row["family"] as StringName, target_skeleton, target_to_character, TRACK_PREFIX, bool(row["pin_horizontal"]))
		source_root.free()
		if baked == null:
			push_error("Retarget of %s failed" % clip)
			mannequin.free()
			quit(1)
			return
		baked.loop_mode = Animation.LOOP_LINEAR if bool(row["loop"]) else Animation.LOOP_NONE
		library.add_animation(clip, baked)
		_print_hips_curve(clip, baked, target_skeleton, target_to_character)
	mannequin.free()
	var err: Error = ResourceSaver.save(library, OUTPUT)
	print("saved %s (%d clips) err=%d" % [OUTPUT, library.get_animation_list().size(), err])
	quit(0 if err == OK else 1)


## Prints the hips height of a retargeted clip as a share of the rest height, one line per key (the measurement the
## window of the Slide tree node is chosen from, tools/build_mannequin_tree.gd).
func _print_hips_curve(clip: StringName, animation: Animation, skeleton: Skeleton3D, to_character: Transform3D) -> void:
	var hips: int = skeleton.find_bone("hips")
	var rest: float = ClipRetargeter.sample_globals(skeleton, to_character, null, 0.0)[hips].origin.y
	var track: int = animation.find_track(NodePath(TRACK_PREFIX + "hips"), Animation.TYPE_ROTATION_3D)
	print("%s hips height share of rest %.4f m, %.4f s:" % [clip, rest, animation.length])
	for key: int in animation.track_get_key_count(track):
		var time: float = animation.track_get_key_time(track, key)
		var height: float = ClipRetargeter.sample_globals(skeleton, to_character, animation, time)[hips].origin.y
		print("  t=%.4f hips=%.3f" % [time, height / rest])


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
