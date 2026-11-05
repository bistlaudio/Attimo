extends SceneTree
## Editor-time tool: generates the movement gym (D-20) and writes it as a text scene, the Phase 2 main scene.
## Run: bash attimo/tests/run.sh --tool res://tools/build_movement_gym.gd
## Prints "GYM: WRITTEN (<path>)" and exits 0, or "GYM: FAILED (<reason>)" and exits 1.
## The node tree is built by tools/movement_gym_builder.gd, loaded at run time: this script is compiled before the
## autoloads exist, so it must not name a type that touches EventBus. Re-running reproduces the same file.

const BUILDER_PATH: String = "res://tools/movement_gym_builder.gd"
const OUTPUT: String = "res://scenes/test/movement_gym.tscn"


func _initialize() -> void:
	var script: GDScript = load(BUILDER_PATH) as GDScript
	if script == null or not script.can_instantiate():
		_fail("cannot load %s" % BUILDER_PATH)
		return
	var builder: RefCounted = script.new() as RefCounted
	var root: Node = builder.call(&"build") as Node
	if root == null:
		_fail(str(builder.get(&"failure")))
		return
	var packed: PackedScene = PackedScene.new()
	var pack_err: Error = packed.pack(root)
	if pack_err != OK:
		root.free()
		_fail("pack error %d" % pack_err)
		return
	var save_err: Error = ResourceSaver.save(packed, OUTPUT)
	root.free()
	if save_err != OK:
		_fail("save error %d" % save_err)
		return
	var strip_err: String = _strip_unique_ids()
	if strip_err != "":
		_fail(strip_err)
		return
	print("GYM: WRITTEN (%s)" % OUTPUT)
	quit(0)


## PackedScene.pack() stamps every node with a random unique_id, which would make each run differ. The ids are
## optional in the text format (Godot assigns them on the next editor save), so they are removed to keep the file
## reproducible.
func _strip_unique_ids() -> String:
	var text: String = FileAccess.get_file_as_string(OUTPUT)
	if text == "":
		return "cannot read back %s" % OUTPUT
	var pattern: RegEx = RegEx.create_from_string(" unique_id=\\d+")
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file == null:
		return "cannot rewrite %s" % OUTPUT
	file.store_string(pattern.sub(text, "", true))
	file.close()
	return ""


func _fail(reason: String) -> void:
	print("GYM: FAILED (%s)" % reason)
	quit(1)
