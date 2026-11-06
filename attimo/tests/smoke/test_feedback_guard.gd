extends RefCounted
## FEEL-01 / D-10 guard. Gameplay only states facts: no direct feedback calls, no particle nodes, no state in the bus.
## Read-only: scans fixed res:// folders through FileAccess, writes nothing.
## The scan includes comments on purpose, so gameplay comments must avoid these words too.

const GAMEPLAY_DIRS: Array[String] = ["res://scripts/core", "res://scripts/player", "res://autoload"]
const SCENE_DIR: String = "res://scenes"
const BUS_PATH: String = "res://autoload/event_bus.gd"
const JUMP_PATH: String = "res://scripts/player/states/jump.gd"
const STATE_MACHINE_PATH: String = "res://scripts/core/state_machine.gd"
## The one placeholder-particle exception: the hit puff scene of the debug folder, spawned by scripts/debug/hit_puffs.gd
## from EventBus facts only. Every other scene with a particle node still fails, and gameplay code must not name it.
const PARTICLE_SCENE_ALLOWLIST: Array[String] = ["res://scenes/debug/hit_puff.tscn"]
const PUFF_TOKENS: Array[String] = ["hit_puff", "HitPuff"]
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
	var puff_refs: int = 0
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		for token: String in PUFF_TOKENS:
			if text.contains(token):
				puff_refs += 1
				check.call(false, "%s references the debug hit puff '%s'; only scripts/debug may" % [path, token])
	check.call(puff_refs == 0, "no gameplay script references the debug hit puff")


func _scan_particles(check: Callable) -> void:
	var scenes: Array[String] = []
	_collect(SCENE_DIR, ".tscn", scenes)
	var hits: int = 0
	var allowed: int = 0
	for path: String in scenes:
		if PARTICLE_SCENE_ALLOWLIST.has(path):
			allowed += 1
			continue
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
	check.call(allowed == PARTICLE_SCENE_ALLOWLIST.size(), "the allowlisted particle scene exists (%d of %d found)" % [allowed, PARTICLE_SCENE_ALLOWLIST.size()])
	check.call(hits == 0, "no particle nodes in %d scenes (%d allowlisted)" % [scenes.size(), allowed])


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
