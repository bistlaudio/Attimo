extends SceneTree
## Editor-time tool: conforms external animation sources (Mixamo FBX, UAL GLB) into mesh-free .scn files.
## Run: bash attimo/tests/run.sh --tool res://tools/conform_external_clip.gd
## The raw download stays in the reference library outside the Godot project (KayKit/...), FBX never goes inside it
## (test_asset_hygiene). This tool loads the raw file through the engine's document importers, keeps only the
## Skeleton3D, the AnimationPlayer with the single wanted clip and their ancestor nodes, drops every mesh and every
## script, and saves a small .scn that tools/clip_retargeter.gd and tools/build_animation_library.gd read.
## A later clip needs one row in ROWS, then both tools are re-run (docs/ANIMATION-MAP.md, External clips).
## Paths are fixed constants, never arguments (T-qbt-02).

## Row: raw source relative to the repository root, output scene, clip name inside the output, source clip name
## ("" = the single clip that is not RESET).
const ROWS: Array[Dictionary] = [
	{
		"raw": "KayKit/Mixamo/Running Slide.fbx",
		"output": "res://assets/animations/external/mixamo/running_slide.scn",
		"clip": &"Running_Slide",
		# The FBX importer also yields an empty "Take 001" (0 tracks, 3.33 s); the Mixamo take is mixamo_com.
		"source_clip": "mixamo_com",
	},
]
const MIN_BONES: int = 15


func _initialize() -> void:
	for row: Dictionary in ROWS:
		var failure: String = _conform(row)
		if failure != "":
			print("CONFORM: FAILED (%s: %s)" % [row["raw"], failure])
			quit(1)
			return
	print("CONFORM: SAVED")
	quit(0)


## Conforms one row. Returns an empty string on success, otherwise the failure reason.
func _conform(row: Dictionary) -> String:
	var raw_path: String = ProjectSettings.globalize_path("res://").path_join("..").path_join(String(row["raw"])).simplify_path()
	var output: String = String(row["output"])
	var clip: StringName = row["clip"] as StringName
	if not FileAccess.file_exists(raw_path):
		return "raw file missing: %s" % raw_path

	var scene: Node = _load_raw(raw_path)
	if scene == null:
		return "the engine could not load the raw file"
	var skeleton: Skeleton3D = _first_of_type(scene, "Skeleton3D") as Skeleton3D
	var player: AnimationPlayer = _first_of_type(scene, "AnimationPlayer") as AnimationPlayer
	if skeleton == null or player == null:
		scene.free()
		return "no Skeleton3D or no AnimationPlayer in the loaded scene"

	var clips: Array[StringName] = []
	for candidate: StringName in player.get_animation_list():
		if candidate != &"RESET":
			clips.append(candidate)
	print("raw clips: %s" % [clips])
	for candidate: StringName in clips:
		var candidate_animation: Animation = player.get_animation(candidate)
		print("  clip %s: %.4f s, %d tracks" % [candidate, candidate_animation.length, candidate_animation.get_track_count()])
	var chosen: StringName = &""
	var wanted: String = String(row["source_clip"])
	if wanted != "":
		chosen = StringName(wanted)
	elif clips.size() == 1:
		chosen = clips[0]
	if chosen == &"" or not player.has_animation(chosen):
		scene.free()
		return "no single clip to pick (%d candidates)" % clips.size()
	var animation: Animation = player.get_animation(chosen).duplicate() as Animation

	print("skeleton path: %s, bones: %d" % [scene.get_path_to(skeleton), skeleton.get_bone_count()])
	for bone: int in skeleton.get_bone_count():
		print("bone %d %s parent %d rest %s" % [bone, skeleton.get_bone_name(bone), skeleton.get_bone_parent(bone), skeleton.get_bone_rest(bone)])

	# Keep the skeleton and the player and their ancestors; free every other node (meshes, helper nodes, scripts).
	_prune(scene, [skeleton, player])
	for library_name: StringName in player.get_animation_library_list():
		player.remove_animation_library(library_name)
	var library: AnimationLibrary = AnimationLibrary.new()
	animation.loop_mode = Animation.LOOP_NONE
	library.add_animation(clip, animation)
	player.add_animation_library(&"", library)
	_set_owner(scene, scene)

	var packed: PackedScene = PackedScene.new()
	var pack_err: Error = packed.pack(scene)
	scene.free()
	if pack_err != OK:
		return "pack failed (%d)" % pack_err
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
	var save_err: Error = ResourceSaver.save(packed, output)
	if save_err != OK:
		return "save failed (%d)" % save_err

	return _verify(output, clip)


## Loads a .fbx through FBXDocument and a .glb/.gltf through GLTFDocument. Returns the generated scene or null.
func _load_raw(path: String) -> Node:
	var document: GLTFDocument
	var state: GLTFState
	if path.get_extension().to_lower() == "fbx":
		document = FBXDocument.new()
		state = FBXState.new()
	else:
		document = GLTFDocument.new()
		state = GLTFState.new()
	var err: Error = document.append_from_file(path, state, 0)
	if err != OK:
		push_error("append_from_file failed (%d) for %s" % [err, path])
		return null
	return document.generate_scene(state)


## Reloads the saved scene and checks it holds a skeleton, one clip, no mesh and no script (T-qbt-01).
func _verify(output: String, clip: StringName) -> String:
	var packed: PackedScene = load(output) as PackedScene
	if packed == null:
		return "saved scene does not reload"
	var root: Node = packed.instantiate()
	var skeleton: Skeleton3D = _first_of_type(root, "Skeleton3D") as Skeleton3D
	var player: AnimationPlayer = _first_of_type(root, "AnimationPlayer") as AnimationPlayer
	var failure: String = ""
	if skeleton == null or skeleton.get_bone_count() < MIN_BONES:
		failure = "reloaded scene has no skeleton with at least %d bones" % MIN_BONES
	elif player == null or player.get_animation_list().size() != 1 or not player.has_animation(clip):
		failure = "reloaded scene does not hold exactly the clip %s" % clip
	elif _first_of_type(root, "MeshInstance3D") != null:
		failure = "reloaded scene still has a MeshInstance3D"
	elif _first_with_script(root) != null:
		failure = "reloaded scene has a node with a script"
	if failure == "":
		var animation: Animation = player.get_animation(clip)
		print("conformed %s: %d bones, clip %s %.4f s, %d tracks" % [output, skeleton.get_bone_count(), clip, animation.length, animation.get_track_count()])
	root.free()
	return failure


func _first_of_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child: Node in node.get_children():
		var found: Node = _first_of_type(child, type_name)
		if found != null:
			return found
	return null


func _first_with_script(node: Node) -> Node:
	if node.get_script() != null:
		return node
	for child: Node in node.get_children():
		var found: Node = _first_with_script(child)
		if found != null:
			return found
	return null


## Frees every node that is neither a keeper nor an ancestor of a keeper. Keepers keep their own children only when the
## child is a keeper or an ancestor of one, so the skeleton loses its mesh and attachment children.
func _prune(node: Node, keepers: Array[Node]) -> void:
	for child: Node in node.get_children():
		if _keeps(child, keepers):
			_prune(child, keepers)
		else:
			node.remove_child(child)
			child.free()


func _keeps(node: Node, keepers: Array[Node]) -> bool:
	for keeper: Node in keepers:
		if node == keeper or node.is_ancestor_of(keeper):
			return true
	return false


func _set_owner(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_set_owner(child, owner_node)
