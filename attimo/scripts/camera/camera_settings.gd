class_name CameraSettings
extends RefCounted
## Player-facing camera settings (CAM-03): mouse sensitivity, invert-Y and the auto-follow mode.
## Plain data. Persisted only with ConfigFile in the [camera] section of user://settings.cfg; never a
## Resource, never a script, nothing is loaded from user:// with load() or ResourceLoader (T-02-14).
## Every value read from disk is type-checked and clamped, so a hand-edited or damaged file cannot break
## the camera (T-02-13, T-02-23). The F2 tuning panel (02-12) and the Phase 7 settings menu reuse this class.

const DEFAULT_PATH: String = "user://settings.cfg"
const SECTION: String = "camera"
const SENSITIVITY_MIN: float = 0.1
const SENSITIVITY_MAX: float = 3.0
const DEFAULT_SENSITIVITY: float = 1.0
## Order used by the 02-12 selector.
const AUTO_FOLLOW_MODES: Array[String] = ["auto", "on", "off"]
const DEFAULT_AUTO_FOLLOW_MODE: String = "auto"
## A28: text containing any of these is rejected before ConfigFile parses it (defense in depth).
const FORBIDDEN_SYNTAX: Array[String] = ["Object(", "Resource(", "SubResource(", "ExtResource("]

## Multiplier on CameraRig.base_sensitivity, clamped to SENSITIVITY_MIN..SENSITIVITY_MAX on load.
var sensitivity: float = DEFAULT_SENSITIVITY
## true flips the vertical mouse look.
var invert_y: bool = false
## One of AUTO_FOLLOW_MODES: "auto" follows only after joypad input, "on" always, "off" never (A41).
var auto_follow_mode: String = DEFAULT_AUTO_FOLLOW_MODE


## Loads the [camera] section of `path`. A missing, unreadable, unparsable or suspicious file gives defaults;
## single bad values give the default (or the clamped value) for that field only.
static func load_from(path: String = DEFAULT_PATH) -> CameraSettings:
	var result: CameraSettings = CameraSettings.new()
	if not FileAccess.file_exists(path):
		return result
	var text: String = FileAccess.get_file_as_string(path)
	if _has_forbidden_syntax(text):
		return result
	var config: ConfigFile = ConfigFile.new()
	if config.parse(text) != OK:
		return result

	var raw_sensitivity: Variant = _read(config, "sensitivity")
	var sensitivity_type: int = typeof(raw_sensitivity)
	if sensitivity_type == TYPE_FLOAT or sensitivity_type == TYPE_INT:
		var value: float = float(raw_sensitivity)
		if is_finite(value):
			result.sensitivity = clampf(value, SENSITIVITY_MIN, SENSITIVITY_MAX)

	var raw_invert: Variant = _read(config, "invert_y")
	if typeof(raw_invert) == TYPE_BOOL:
		result.invert_y = bool(raw_invert)

	var raw_mode: Variant = _read(config, "auto_follow_mode")
	var mode_type: int = typeof(raw_mode)
	if mode_type == TYPE_STRING or mode_type == TYPE_STRING_NAME:
		var mode: String = String(raw_mode)
		if AUTO_FOLLOW_MODES.has(mode):
			result.auto_follow_mode = mode
	return result


## Writes the three values into the [camera] section of `path`, keeping every other section. Refuses any path
## outside user:// (or containing ..) with ERR_INVALID_PARAMETER and writes nothing.
func save_to(path: String = DEFAULT_PATH) -> Error:
	if not path.begins_with("user://") or path.contains(".."):
		return ERR_INVALID_PARAMETER
	var config: ConfigFile = ConfigFile.new()
	if FileAccess.file_exists(path):
		var existing: String = FileAccess.get_file_as_string(path)
		# A suspicious file is replaced rather than parsed; a damaged one simply fails to load (ignored).
		if not _has_forbidden_syntax(existing):
			config.parse(existing)
	config.set_value(SECTION, "sensitivity", sensitivity)
	config.set_value(SECTION, "invert_y", invert_y)
	config.set_value(SECTION, "auto_follow_mode", auto_follow_mode)
	return config.save(path)


## The value of `key` in the [camera] section, or null when it is absent (ConfigFile.get_value logs an error for null defaults).
static func _read(config: ConfigFile, key: String) -> Variant:
	if not config.has_section_key(SECTION, key):
		return null
	return config.get_value(SECTION, key)


static func _has_forbidden_syntax(text: String) -> bool:
	for token: String in FORBIDDEN_SYNTAX:
		if text.contains(token):
			return true
	return false
