extends SceneTree
## Editor-time tool: merges the wanted KayKit Rig_Medium clips into one AnimationLibrary and sets loop modes.
## Run: bash attimo/tests/run.sh --tool res://tools/build_animation_library.gd
## Later phases extend SOURCES / WANTED (CombatRanged etc.) and re-run; the output is regenerated deterministically.

const SOURCES: Array[String] = [
	"res://assets/animations/rig_medium/Rig_Medium_General.glb",
	"res://assets/animations/rig_medium/Rig_Medium_MovementBasic.glb",
	"res://assets/animations/rig_medium/Rig_Medium_MovementAdvanced.glb",
]
const OUTPUT: String = "res://assets/animations/rig_medium/rig_medium_library.res"
const WANTED: Array[StringName] = [&"Idle_A", &"Running_A", &"Jump_Start", &"Jump_Idle", &"Jump_Land", &"Dodge_Forward"]
## KayKit clips import as non-looping (Pitfall 2), so the looping set is declared here.
const LOOPING: Array[StringName] = [&"Idle_A", &"Running_A", &"Jump_Idle"]


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
	var err: Error = ResourceSaver.save(library, OUTPUT)
	print("saved %s (%d clips) err=%d" % [OUTPUT, library.get_animation_list().size(), err])
	quit(0 if err == OK else 1)
