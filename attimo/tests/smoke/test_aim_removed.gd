extends RefCounted
## ENRG-04 guard (phase 05, D-15, D-19, D-26): aim mode stays removed. No `aim` input action, no aim_changed fact, no
## PlayerController.aiming, no goggle HUD (hud_visible, Lens overlay, goggle_lens.gdshader), no aim camera sources on the CameraRig,
## and no script line outside a comment names the removed API. The names that survive on purpose are listed in ALLOWED_NAMES: they
## mean the target point of an Interactable, the crosshair ray or the dormant arm layer, not aim mode.

const CROSSHAIR_SCENE: String = "res://scenes/ui/crosshair.tscn"
const LENS_SHADER_PATH: String = "res://scripts/ui/goggle_lens.gdshader"
const PLAYER_SCRIPT: String = "res://scripts/player/player_controller.gd"
const CROSSHAIR_SCRIPT: String = "res://scripts/ui/crosshair.gd"
const CAMERA_RIG_SCRIPT: String = "res://scripts/camera/camera_rig.gd"
const SCAN_ROOTS: Array[String] = ["res://scripts", "res://autoload"]
## Tokens that no non-comment script line may contain.
const FORBIDDEN_TOKENS: Array[String] = ["aim_changed", "aim_fov_delta", "aim_shoulder_offset", "hud_visible"]
## Names that stay (documentation for the next reader, also used by the self-check).
const ALLOWED_NAMES: Array[String] = [
	"aim_target_point", "aim_ray", "aim_direction_from", "aim_ray_start", "aim_point", "AimPoint", "AimPoseModifier", "aim_layer_blend_time",
]


func run(_tree: SceneTree, check: Callable) -> void:
	check.call(not InputMap.has_action(&"aim"), "there is no aim input action (the right mouse button is the loader)")
	check.call(InputMap.has_action(&"loader"), "the loader action took the right mouse button over")

	var bus_script: Script = load("res://autoload/event_bus.gd") as Script
	var signal_names: Array[String] = []
	for info: Dictionary in bus_script.get_script_signal_list():
		signal_names.append(str(info["name"]))
	check.call(not signal_names.has("aim_changed"), "the EventBus declares no aim_changed signal")
	for gone: String in ["shot_ready_changed", "shot_fired", "shot_fully_charged", "pulse_fired"]:
		check.call(not signal_names.has(gone), "D-45: the EventBus declares no %s signal" % gone)

	check.call(not _script_has_property(PLAYER_SCRIPT, "aiming"), "PlayerController has no property aiming")
	check.call(not _script_has_property(CROSSHAIR_SCRIPT, "hud_visible"), "Crosshair has no property hud_visible")
	for property: String in ["aim_weight", "look_sensitivity_multiplier", "aim_fov_delta", "aim_shoulder_offset"]:
		check.call(not _script_has_property(CAMERA_RIG_SCRIPT, property), "CameraRig has no property %s" % property)

	var packed: PackedScene = load(CROSSHAIR_SCENE) as PackedScene
	check.call(packed != null, "crosshair.tscn loads")
	if packed != null:
		var crosshair: Node = packed.instantiate()
		check.call(crosshair.get_node_or_null(^"Lens") == null, "the Crosshair scene has no Lens child")
		crosshair.free()
	check.call(not FileAccess.file_exists(LENS_SHADER_PATH), "goggle_lens.gdshader does not exist")

	var scanned: int = 0
	var offenders: Array[String] = []
	for root: String in SCAN_ROOTS:
		var paths: Array[String] = []
		_collect(root, paths)
		for path: String in paths:
			scanned += 1
			var hits: Array[String] = _forbidden_hits(FileAccess.get_file_as_string(path))
			for hit: String in hits:
				offenders.append("%s: %s" % [path, hit])
	check.call(scanned > 40, "the scan covered the game scripts (%d files)" % scanned)
	check.call(offenders.is_empty(), "no script line outside a comment names the removed aim API (%s)" % [offenders])

	# The scan can fail: a synthetic offending line is found, a comment and the allowed names are not.
	check.call(_forbidden_hits("var x: bool = hud_visible\n").size() == 1, "self-check: a code line with hud_visible is found")
	check.call(_forbidden_hits("EventBus.aim_changed.connect(f)\n").size() == 1, "self-check: a code line with aim_changed is found")
	check.call(_forbidden_hits("## aim_changed used to live here\n# aim_fov_delta\n").is_empty(), "self-check: comment lines are skipped")
	var allowed_line: String = "\n".join(ALLOWED_NAMES)
	check.call(_forbidden_hits(allowed_line).is_empty(), "self-check: the allowed names are not flagged")


## True when the script declares a property called `property`.
func _script_has_property(script_path: String, property: String) -> bool:
	var script: Script = load(script_path) as Script
	if script == null:
		return false
	for info: Dictionary in script.get_script_property_list():
		if str(info["name"]) == property:
			return true
	return false


## The non-comment lines of `source` that contain a forbidden token, as "line N: token".
func _forbidden_hits(source: String) -> Array[String]:
	var hits: Array[String] = []
	var lines: PackedStringArray = source.split("\n")
	for i: int in lines.size():
		var code: String = lines[i]
		var comment_at: int = code.find("#")
		if comment_at >= 0:
			code = code.substr(0, comment_at)
		for token: String in FORBIDDEN_TOKENS:
			if code.contains(token):
				hits.append("line %d: %s" % [i + 1, token])
	return hits


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect("%s/%s" % [dir_path, sub], out)
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			out.append("%s/%s" % [dir_path, file_name])
