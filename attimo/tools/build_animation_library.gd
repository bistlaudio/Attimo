extends SceneTree
## Editor-time tool: merges the wanted KayKit Rig_Medium clips into one AnimationLibrary and sets loop modes.
## Run: bash attimo/tests/run.sh --tool res://tools/build_animation_library.gd
## Later phases extend SOURCES / WANTED and re-run; the output is regenerated deterministically.

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
	var err: Error = ResourceSaver.save(library, OUTPUT)
	print("saved %s (%d clips) err=%d" % [OUTPUT, library.get_animation_list().size(), err])
	quit(0 if err == OK else 1)
