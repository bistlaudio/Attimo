extends SceneTree
## Headless smoke runner. Auto-discovers res://tests/smoke/test_*.gd.
## Each test: extends RefCounted, func run(tree: SceneTree, check: Callable) -> void (may await).
## Optional comma-separated substring filter via user args: godot ... -s res://tests/run_smoke.gd -- name1,name2

const SMOKE_DIR: String = "res://tests/smoke"

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	await _run()
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("PASS [%s] %s" % [_current, message])
	else:
		_failed += 1
		printerr("FAIL [%s] %s" % [_current, message])


func _run() -> void:
	var files: Array[String] = []
	var dir: DirAccess = DirAccess.open(SMOKE_DIR)
	if dir == null:
		_current = "runner"
		_check(false, "cannot open %s" % SMOKE_DIR)
		print("SMOKE SUMMARY: tests=0 passed=%d failed=%d" % [_passed, _failed])
		return
	for file_name: String in dir.get_files():
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			files.append(file_name)
	files.sort()

	var filters: PackedStringArray = PackedStringArray()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if user_args.size() > 0 and user_args[0] != "":
		filters = user_args[0].split(",", false)
	if filters.size() > 0:
		var selected: Array[String] = []
		for file_name: String in files:
			for f: String in filters:
				if file_name.contains(f):
					selected.append(file_name)
					break
		files = selected
		if files.is_empty():
			_current = "runner"
			_check(false, "filter '%s' matches no test file" % user_args[0])
			print("SMOKE SUMMARY: tests=0 passed=%d failed=%d" % [_passed, _failed])
			return

	var count: int = 0
	for file_name: String in files:
		_current = file_name.get_basename()
		var script: GDScript = load("%s/%s" % [SMOKE_DIR, file_name]) as GDScript
		if script == null or not script.can_instantiate():
			_check(false, "test script failed to load: %s" % file_name)
			continue
		var test: RefCounted = script.new() as RefCounted
		count += 1
		await test.call(&"run", self, _check)
	_current = "runner"
	print("SMOKE SUMMARY: tests=%d passed=%d failed=%d" % [count, _passed, _failed])
