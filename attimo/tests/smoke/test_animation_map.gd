extends RefCounted
## MOVE-11 guard: docs/ANIMATION-MAP.md names every state node of player.tscn and every clip that
## mannequin_tree.tres references, every referenced clip exists in the library, and the verbs
## without a clip stay documented as left out. Read-only access on fixed paths (T-03-13).

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const TREE_PATH: String = "res://scenes/player/mannequin_tree.tres"
const LIBRARY_PATH: String = "res://assets/animations/rig_medium/rig_medium_library.res"
## Fixed read-only path, relative to the project root (attimo/).
const DOC_RELATIVE_PATH: String = "../docs/ANIMATION-MAP.md"
const CLIP_LINE_PREFIX: String = "animation = &\""
const LEFT_OUT_TERMS: Array[String] = ["MOVE-12", "MOVE-13", "D-03"]
const RULE_TERMS: Array[String] = ["DEV-01", "DEV-02", "DEV-03", "DEV-04", "air_dash_hold_time", "pirouette_finish_time", "Retarget quality rule"]


func run(_tree: SceneTree, check: Callable) -> void:
	var doc_path: String = ProjectSettings.globalize_path("res://").path_join(DOC_RELATIVE_PATH).simplify_path()
	check.call(FileAccess.file_exists(doc_path), "docs/ANIMATION-MAP.md exists (%s)" % doc_path)
	var doc: String = FileAccess.get_file_as_string(doc_path)
	check.call(doc.length() > 0, "docs/ANIMATION-MAP.md is readable and not empty")

	var states: Array[String] = _state_names()
	check.call(states.size() >= 6, "player.tscn has at least 6 state nodes (got %d)" % states.size())
	var clips: Array[String] = _tree_clips()
	check.call(clips.size() >= 13, "mannequin_tree.tres references at least 13 distinct clips (got %d)" % clips.size())

	var missing_states: Array[String] = _missing(doc, states)
	for state_name: String in states:
		check.call(not missing_states.has(state_name), "map names state `%s`" % state_name)
	var missing_clips: Array[String] = _missing(doc, clips)
	for clip_name: String in clips:
		check.call(not missing_clips.has(clip_name), "map names clip `%s`" % clip_name)

	var library: AnimationLibrary = load(LIBRARY_PATH) as AnimationLibrary
	check.call(library != null, "rig_medium_library.res loads as AnimationLibrary")
	if library != null:
		for clip_name: String in clips:
			check.call(library.has_animation(StringName(clip_name)), "library has the referenced clip %s" % clip_name)
		# M1 (quick 261118-qi3): the map is the whitelist of the library, every library clip is backticked in it.
		var library_clips: Array[String] = []
		for clip_name: StringName in library.get_animation_list():
			library_clips.append(String(clip_name))
		var missing_library: Array[String] = _missing(doc, library_clips)
		for clip_name: String in library_clips:
			check.call(not missing_library.has(clip_name), "M1 map names library clip `%s`" % clip_name)
		# The synthetic doc backticks every library clip except the first.
		var synthetic_doc: String = ""
		for i: int in range(1, library_clips.size()):
			synthetic_doc += "`%s` " % library_clips[i]
		synthetic_doc += library_clips[0] if not library_clips.is_empty() else ""
		check.call(_missing(synthetic_doc, library_clips) == ([library_clips[0]] as Array[String]), "M1 self-check: a doc without one library clip reports exactly that clip")

	for term: String in LEFT_OUT_TERMS:
		check.call(doc.contains(term), "map documents %s (verbs left out)" % term)
	for term: String in RULE_TERMS:
		check.call(doc.contains(term), "map states the rule term %s" % term)
	check.call(doc.count("DEV-03") >= 2, "DEV-03 aim rule appears on at least two rows (Jump 3 and long jump stage 3)")
	check.call(doc.contains("Adding a verb"), "map carries the 'Adding a verb' rule")

	_check_guard_can_fail(check, doc, states)


## Names from `names` that are not backticked in `doc` (pure, so the guard itself can be tested).
func _missing(doc: String, names: Array[String]) -> Array[String]:
	var absent: Array[String] = []
	for entry: String in names:
		if not doc.contains("`%s`" % entry):
			absent.append(entry)
	return absent


func _check_guard_can_fail(check: Callable, doc: String, states: Array[String]) -> void:
	if states.is_empty():
		check.call(false, "self-check needs at least one state name")
		return
	var victim: String = states[0]
	var broken: String = doc.replace("`%s`" % victim, victim)
	var absent: Array[String] = _missing(broken, states)
	check.call(absent == [victim], "self-check: a doc without `%s` reports exactly that state missing" % victim)
	var synthetic: Array[String] = _missing("`A` `B`", ["A", "B", "C"] as Array[String])
	check.call(synthetic == ["C"], "self-check: a synthetic doc lacking one name reports it")
	check.call(_missing(doc, states).is_empty(), "self-check: the real doc has no state missing")


func _state_names() -> Array[String]:
	var names: Array[String] = []
	var scene: PackedScene = load(PLAYER_SCENE) as PackedScene
	if scene == null:
		return names
	var instance: Node = scene.instantiate()
	var machine: Node = instance.get_node_or_null(^"StateMachine")
	if machine != null:
		for child: Node in machine.get_children():
			names.append(String(child.name))
	instance.free()
	return names


func _tree_clips() -> Array[String]:
	var clips: Array[String] = []
	var text: String = FileAccess.get_file_as_string(TREE_PATH)
	for line: String in text.split("\n"):
		var stripped: String = line.strip_edges()
		if not stripped.begins_with(CLIP_LINE_PREFIX):
			continue
		var clip_name: String = stripped.trim_prefix(CLIP_LINE_PREFIX).trim_suffix("\"")
		if not clips.has(clip_name):
			clips.append(clip_name)
	return clips
