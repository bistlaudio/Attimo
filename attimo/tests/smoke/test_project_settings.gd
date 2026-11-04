extends RefCounted
## FOUND-01 guard: exact engine build, project settings, and loadability of every script
## (an untyped script fails to load under untyped_declaration=2, so the sweep proves typing is enforced).

const SWEEP_ROOTS: Array[String] = ["res://autoload", "res://scenes", "res://scripts", "res://tools", "res://tests"]
const MIN_SCRIPTS: int = 7


func run(_tree: SceneTree, check: Callable) -> void:
	var v: Dictionary = Engine.get_version_info()
	check.call(v.major == 4 and v.minor == 7 and v.patch == 2, "engine is 4.7.2 (got %s)" % v.string)
	check.call(v.status == "stable" and v.build == "official", "engine is stable/official (got %s/%s)" % [v.status, v.build])
	check.call(str(v.hash).begins_with("ed1daf0bf"), "engine hash begins ed1daf0bf (got %s)" % str(v.hash))

	check.call(ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics", "physics engine is Jolt Physics")
	check.call(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "forward_plus", "renderer is forward_plus")
	check.call(ProjectSettings.get_setting("physics/common/physics_interpolation") == true, "physics interpolation is on")
	check.call(ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration") == 2, "untyped declarations are errors")

	var features: PackedStringArray = ProjectSettings.get_setting("application/config/features")
	check.call(features.has("4.7") and features.has("Forward Plus"), "config/features contains 4.7 and Forward Plus")
	check.call(ProjectSettings.get_setting("autoload/EventBus") == "*res://autoload/event_bus.gd", "EventBus autoload registered")

	var paths: Array[String] = []
	for root: String in SWEEP_ROOTS:
		_collect(root, paths)
	paths.sort()
	var all_load: bool = true
	for path: String in paths:
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			all_load = false
			check.call(false, "script does not load or instantiate: %s" % path)
	check.call(all_load, "all %d swept scripts load and can_instantiate" % paths.size())
	check.call(paths.size() >= MIN_SCRIPTS, "script sweep found at least %d scripts (got %d)" % [MIN_SCRIPTS, paths.size()])


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect("%s/%s" % [dir_path, sub], out)
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			out.append("%s/%s" % [dir_path, file_name])
