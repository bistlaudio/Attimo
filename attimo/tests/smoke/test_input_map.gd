extends RefCounted
## FOUND-02 guard: the full D-15 Input Map is bound for keyboard and mouse, no gamepad event is bound
## (slots are reserved in docs/CONVENTIONS.md), and game code never polls raw input devices.

const ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"look_left", &"look_right", &"look_up", &"look_down",
	&"jump", &"dash", &"aim", &"use_hand", &"interact",
	&"module_next", &"module_prev", &"pause", &"debug_event_log",
	&"camera_recenter", &"debug_tuning", &"debug_metrics", &"debug_tick_rate",
]
const LOOK_ACTIONS: Array[StringName] = [&"look_left", &"look_right", &"look_up", &"look_down"]
## Game code roots scanned for raw input polling. res://tests is excluded: this file names the tokens.
const SCAN_ROOTS: Array[String] = ["res://autoload", "res://scripts", "res://scenes"]
const FORBIDDEN_TOKENS: Array[String] = [
	"Input.is_key_pressed", "is_physical_key_pressed", "is_mouse_button_pressed", "get_joy",
]


func run(_tree: SceneTree, check: Callable) -> void:
	for action: StringName in ACTIONS:
		var exists: bool = InputMap.has_action(action)
		check.call(exists, "action exists: %s" % action)
		if not exists:
			continue
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		if LOOK_ACTIONS.has(action):
			check.call(events.is_empty(), "%s has no events (Phase 2 reads mouse motion, Phase 13 binds the stick)" % action)
		else:
			check.call(not events.is_empty(), "%s has at least one binding" % action)
		var all_kbm: bool = true
		var all_device_any: bool = true
		for event: InputEvent in events:
			if not (event is InputEventKey or event is InputEventMouseButton):
				all_kbm = false
			if event.device != -1:
				all_device_any = false
		check.call(all_kbm, "%s binds only key or mouse-button events (no gamepad, D-15)" % action)
		check.call(all_device_any, "%s events use device -1 (all devices)" % action)

	# Only the project's own actions are checked: the built-in ui_* actions ship with gamepad events.
	var joypad_events: int = 0
	for action: StringName in ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				joypad_events += 1
	check.call(joypad_events == 0, "no project action has a gamepad event (found %d)" % joypad_events)

	_check_specific_bindings(check)
	_scan_for_raw_polling(check)


func _check_specific_bindings(check: Callable) -> void:
	check.call(_has_physical_key(&"jump", KEY_SPACE), "jump maps to physical key Space")
	check.call(_has_physical_key(&"debug_event_log", KEY_F3), "debug_event_log contains physical key F3")
	check.call(_has_physical_key(&"debug_event_log", KEY_QUOTELEFT), "debug_event_log contains physical key QuoteLeft")
	var dash_events: Array[InputEvent] = InputMap.action_get_events(&"dash")
	check.call(dash_events.size() == 1, "dash has exactly one event (Left Shift, U3)")
	var dash_key: InputEventKey = dash_events[0] as InputEventKey if dash_events.size() > 0 else null
	check.call(dash_key != null and dash_key.physical_keycode == KEY_SHIFT, "the dash event is the physical Shift key")
	check.call(dash_key != null and dash_key.location == KEY_LOCATION_LEFT, "the dash event is the left Shift key")
	check.call(not InputMap.has_action(&"sprint"), "there is no sprint action (U1)")
	check.call(not _has_physical_key(&"dash", KEY_Q), "Q does not dash")
	check.call(not _has_physical_key(&"dash", KEY_CTRL), "Left Ctrl does not dash")
	check.call(_has_physical_key(&"interact", KEY_E), "interact maps to E")
	check.call(_has_physical_key(&"pause", KEY_ESCAPE), "pause maps to Escape")
	check.call(_has_physical_key(&"move_forward", KEY_W), "move_forward maps to W")
	check.call(_has_physical_key(&"move_back", KEY_S), "move_back maps to S")
	check.call(_has_physical_key(&"move_left", KEY_A), "move_left maps to A")
	check.call(_has_physical_key(&"move_right", KEY_D), "move_right maps to D")
	check.call(_has_mouse_button(&"aim", MOUSE_BUTTON_RIGHT), "aim maps to right mouse button")
	check.call(_has_mouse_button(&"use_hand", MOUSE_BUTTON_LEFT), "use_hand maps to left mouse button")
	check.call(_has_mouse_button(&"module_next", MOUSE_BUTTON_WHEEL_DOWN), "module_next maps to wheel down")
	check.call(_has_mouse_button(&"module_prev", MOUSE_BUTTON_WHEEL_UP), "module_prev maps to wheel up")
	check.call(_has_mouse_button(&"camera_recenter", MOUSE_BUTTON_MIDDLE), "camera_recenter maps to the middle mouse button")
	check.call(_has_physical_key(&"debug_tuning", KEY_F2), "debug_tuning contains physical key F2")
	check.call(_has_physical_key(&"debug_tuning", KEY_8), "debug_tuning contains physical key 8")
	check.call(_has_physical_key(&"debug_metrics", KEY_F4), "debug_metrics contains physical key F4")
	check.call(_has_physical_key(&"debug_metrics", KEY_9), "debug_metrics contains physical key 9")
	check.call(_has_physical_key(&"debug_tick_rate", KEY_F6), "debug_tick_rate contains physical key F6")
	check.call(_has_physical_key(&"debug_tick_rate", KEY_0), "debug_tick_rate contains physical key 0")


func _has_physical_key(action: StringName, keycode: Key) -> bool:
	if not InputMap.has_action(action):
		return false
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.physical_keycode == keycode:
			return true
	return false


func _has_mouse_button(action: StringName, button: MouseButton) -> bool:
	if not InputMap.has_action(action):
		return false
	for event: InputEvent in InputMap.action_get_events(action):
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event != null and mouse_event.button_index == button:
			return true
	return false


func _scan_for_raw_polling(check: Callable) -> void:
	var paths: Array[String] = []
	for root: String in SCAN_ROOTS:
		_collect(root, paths)
	paths.sort()
	check.call(paths.size() > 0, "raw-polling scan found game scripts (got %d)" % paths.size())
	var clean: bool = true
	for path: String in paths:
		var source: String = FileAccess.get_file_as_string(path)
		for token: String in FORBIDDEN_TOKENS:
			if source.contains(token):
				clean = false
				check.call(false, "raw input polling '%s' in %s (use Input Map actions)" % [token, path])
	check.call(clean, "no game script polls raw keys, mouse buttons or joypads (%d scanned)" % paths.size())


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect("%s/%s" % [dir_path, sub], out)
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			out.append("%s/%s" % [dir_path, file_name])
