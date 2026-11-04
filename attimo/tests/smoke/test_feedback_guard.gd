extends RefCounted
## FEEL-01 / D-10 guard. Gameplay only states facts: no direct feedback calls, no particle nodes, no state in the bus.
## Read-only: scans fixed res:// folders through FileAccess, writes nothing.
## The scan includes comments on purpose, so gameplay comments must avoid these words too.

const GAMEPLAY_DIRS: Array[String] = ["res://scripts/core", "res://scripts/player", "res://autoload"]
const SCENE_DIR: String = "res://scenes"
const BUS_PATH: String = "res://autoload/event_bus.gd"
const JUMP_PATH: String = "res://scripts/player/states/jump.gd"
const STATE_MACHINE_PATH: String = "res://scripts/core/state_machine.gd"
const REQUIRED_FACTS: Array[String] = ["jumped", "landed", "dash_started", "movement_state_changed"]

## Forbidden feedback tokens (case-sensitive substring match).
const FORBIDDEN_TOKENS: Array[String] = [
	"AudioStreamPlayer",
	"GPUParticles",
	"CPUParticles",
	"create_tween",
	"Tween",
	"Engine.time_scale",
	"shake",
]


func _collect(dir_path: String, extension: String, into: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect("%s/%s" % [dir_path, sub], extension, into)
	for file_name: String in dir.get_files():
		if file_name.ends_with(extension):
			into.append("%s/%s" % [dir_path, file_name])


func run(_tree: SceneTree, check: Callable) -> void:
	_scan_gameplay_feedback(check)
	_scan_particles(check)
	_check_bus_purity(check)
	_check_emission_sanity(check)


func _scan_gameplay_feedback(check: Callable) -> void:
	var files: Array[String] = []
	for dir_path: String in GAMEPLAY_DIRS:
		_collect(dir_path, ".gd", files)
	check.call(not files.is_empty(), "gameplay scan found scripts to scan")
	var hits: int = 0
	for path: String in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			for token: String in FORBIDDEN_TOKENS:
				if lines[i].contains(token):
					hits += 1
					check.call(false, "%s:%d uses forbidden feedback token '%s'" % [path, i + 1, token])
	check.call(hits == 0, "no direct feedback calls in %d gameplay scripts (%d tokens checked)" % [files.size(), FORBIDDEN_TOKENS.size()])


func _scan_particles(check: Callable) -> void:
	var scenes: Array[String] = []
	_collect(SCENE_DIR, ".tscn", scenes)
	var hits: int = 0
	for path: String in scenes:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			var line: String = lines[i]
			if not line.begins_with("[node "):
				continue
			var marker: int = line.find("type=\"")
			if marker < 0:
				continue
			var type_name: String = line.substr(marker + 6).get_slice("\"", 0)
			if type_name.contains("Particles"):
				hits += 1
				check.call(false, "%s:%d contains particle node type '%s'" % [path, i + 1, type_name])
	check.call(hits == 0, "no particle nodes in %d scenes" % scenes.size())


func _check_bus_purity(check: Callable) -> void:
	var lines: PackedStringArray = FileAccess.get_file_as_string(BUS_PATH).split("\n")
	var violations: int = 0
	var checked: int = 0
	for i: int in lines.size():
		var line: String = lines[i].strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		checked += 1
		if not (line.begins_with("extends ") or line.begins_with("signal ")):
			violations += 1
			check.call(false, "%s:%d is not a signal (bus holds facts only): %s" % [BUS_PATH, i + 1, line])
	check.call(checked > 0 and violations == 0, "event bus holds only extends and signal lines (%d code lines)" % checked)

	var bus_script: GDScript = load(BUS_PATH) as GDScript
	var names: Array[String] = []
	for sig: Dictionary in bus_script.get_script_signal_list():
		names.append(String(sig.name))
	for fact: String in REQUIRED_FACTS:
		check.call(names.has(fact), "bus declares required fact '%s'" % fact)


func _check_emission_sanity(check: Callable) -> void:
	check.call(FileAccess.get_file_as_string(JUMP_PATH).contains("EventBus.jumped.emit"), "jump.gd emits EventBus.jumped")
	check.call(FileAccess.get_file_as_string(STATE_MACHINE_PATH).contains("EventBus.movement_state_changed.emit"), "state_machine.gd emits EventBus.movement_state_changed")
