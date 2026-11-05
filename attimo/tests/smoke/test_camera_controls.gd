extends RefCounted
## CAM-03 / D-16 / D-17: camera controls. Mouse look sign and sensitivity, CameraSettings persistence and
## tampering (T-02-13..15, T-02-23), the converging device-aware auto-follow (A40, A41) and the recenter.
## Test files live under user://test_camera_*.cfg and are deleted at the end of each scenario. Input actions
## and test nodes are released before a scenario returns.

const Fixtures := preload("res://tests/fixtures.gd")

const TEST_PATH_A: String = "user://test_camera_a.cfg"
const TEST_PATH_B: String = "user://test_camera_b.cfg"
const TEST_PATH_C: String = "user://test_camera_c.cfg"


func run(tree: SceneTree, check: Callable) -> void:
	# The runner calls us from _initialize, before the root is inside the tree (global transforms would error).
	await tree.process_frame
	await _scenario_mouse_look(tree, check)
	_scenario_settings_round_trip(check)
	_scenario_settings_tampering(check)
	_scenario_settings_refusals(check)
	await _scenario_device_detection(tree, check)
	await _scenario_forced_on_with_mouse(tree, check)
	await _scenario_forced_on_delay(tree, check)
	await _scenario_converges_sideways(tree, check)
	await _scenario_converges_diagonal(tree, check)
	await _scenario_straight_runs(tree, check)
	await _scenario_auto_keyboard(tree, check)
	await _scenario_auto_joypad(tree, check)
	await _scenario_off_mode(tree, check)


func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Writes a [camera] section with the given body lines and loads it back.
func _load_with(path: String, body: String) -> CameraSettings:
	_write_text(path, "[camera]\n%s\n" % body)
	var loaded: CameraSettings = CameraSettings.load_from(path)
	_cleanup_file(path)
	return loaded


# (a) mouse look: right turns right (yaw down), up looks up (pitch up), sensitivity scales, invert-Y flips.
func _scenario_mouse_look(tree: SceneTree, check: Callable) -> void:
	var target: Node3D = Node3D.new()
	tree.root.add_child(target)
	var rig: CameraRig = Fixtures.spawn_camera_rig(tree.root, target)
	await Fixtures.wait_process(tree, 2)
	var pixels: float = 100.0
	var expected: float = pixels * rig.base_sensitivity

	var yaw_before: float = rig.yaw
	Fixtures.send_mouse_motion(Vector2(pixels, 0.0))
	await Fixtures.wait_process(tree, 1)
	check.call(is_equal_approx(yaw_before - rig.yaw, expected), "(a) mouse right lowers yaw by pixels * base_sensitivity (%.4f)" % (yaw_before - rig.yaw))

	var pitch_before: float = rig.pitch
	Fixtures.send_mouse_motion(Vector2(0.0, -pixels))
	await Fixtures.wait_process(tree, 1)
	check.call(is_equal_approx(rig.pitch - pitch_before, expected), "(a) mouse up raises pitch by the same amount, not inverted (%.4f)" % (rig.pitch - pitch_before))

	var doubled: CameraSettings = CameraSettings.new()
	doubled.sensitivity = 2.0
	rig.apply_settings(doubled)
	yaw_before = rig.yaw
	pitch_before = rig.pitch
	Fixtures.send_mouse_motion(Vector2(pixels, 0.0))
	Fixtures.send_mouse_motion(Vector2(0.0, -pixels))
	await Fixtures.wait_process(tree, 1)
	check.call(is_equal_approx(yaw_before - rig.yaw, expected * 2.0), "(a) sensitivity 2.0 doubles the yaw turn (%.4f)" % (yaw_before - rig.yaw))
	check.call(is_equal_approx(rig.pitch - pitch_before, expected * 2.0), "(a) sensitivity 2.0 doubles the pitch change (%.4f)" % (rig.pitch - pitch_before))

	var inverted: CameraSettings = CameraSettings.new()
	inverted.invert_y = true
	rig.apply_settings(inverted)
	pitch_before = rig.pitch
	Fixtures.send_mouse_motion(Vector2(0.0, -pixels))
	await Fixtures.wait_process(tree, 1)
	check.call(is_equal_approx(rig.pitch - pitch_before, -expected), "(a) invert-Y flips the vertical sign (%.4f)" % (rig.pitch - pitch_before))

	rig.queue_free()
	target.queue_free()
	await tree.process_frame


# (b) save then load returns the same values; other sections survive the save.
func _scenario_settings_round_trip(check: Callable) -> void:
	_cleanup_file(TEST_PATH_A)
	_write_text(TEST_PATH_A, "[audio]\nvolume=0.5\n")
	var written: CameraSettings = CameraSettings.new()
	written.sensitivity = 1.75
	written.invert_y = true
	written.auto_follow_mode = "on"
	var result: Error = written.save_to(TEST_PATH_A)
	check.call(result == OK, "(b) save_to a user:// path returns OK (%d)" % result)
	var loaded: CameraSettings = CameraSettings.load_from(TEST_PATH_A)
	check.call(is_equal_approx(loaded.sensitivity, 1.75), "(b) sensitivity round-trips (%.3f)" % loaded.sensitivity)
	check.call(loaded.invert_y, "(b) invert_y round-trips")
	check.call(loaded.auto_follow_mode == "on", "(b) auto_follow_mode round-trips ('%s')" % loaded.auto_follow_mode)
	var config: ConfigFile = ConfigFile.new()
	config.load(TEST_PATH_A)
	check.call(is_equal_approx(float(config.get_value("audio", "volume", -1.0)), 0.5), "(b) an [audio] section written beforehand survives the save")
	_cleanup_file(TEST_PATH_A)


# (c) tampered or missing files load as clamped or default values (T-02-13, T-02-14, T-02-23).
func _scenario_settings_tampering(check: Callable) -> void:
	var loaded: CameraSettings = _load_with(TEST_PATH_B, "sensitivity=\"fast\"")
	check.call(is_equal_approx(loaded.sensitivity, 1.0), "(c) sensitivity \"fast\" loads as 1.0 (%.3f)" % loaded.sensitivity)
	loaded = _load_with(TEST_PATH_B, "sensitivity=nan")
	check.call(is_equal_approx(loaded.sensitivity, 1.0), "(c) sensitivity nan loads as 1.0 (%.3f)" % loaded.sensitivity)
	loaded = _load_with(TEST_PATH_B, "sensitivity=1e9")
	check.call(is_equal_approx(loaded.sensitivity, 3.0), "(c) sensitivity 1e9 loads as 3.0 (%.3f)" % loaded.sensitivity)
	loaded = _load_with(TEST_PATH_B, "sensitivity=-5")
	check.call(is_equal_approx(loaded.sensitivity, 0.1), "(c) sensitivity -5 loads as 0.1 (%.3f)" % loaded.sensitivity)
	loaded = _load_with(TEST_PATH_B, "invert_y=7")
	check.call(not loaded.invert_y, "(c) invert_y = 7 loads as false")
	loaded = _load_with(TEST_PATH_B, "auto_follow_mode=\"sideways\"")
	check.call(loaded.auto_follow_mode == "auto", "(c) auto_follow_mode \"sideways\" loads as auto ('%s')" % loaded.auto_follow_mode)
	loaded = _load_with(TEST_PATH_B, "auto_follow_mode=\"ON\"")
	check.call(loaded.auto_follow_mode == "auto", "(c) auto_follow_mode \"ON\" loads as auto ('%s')" % loaded.auto_follow_mode)
	loaded = _load_with(TEST_PATH_B, "auto_follow_mode=5")
	check.call(loaded.auto_follow_mode == "auto", "(c) auto_follow_mode 5 loads as auto ('%s')" % loaded.auto_follow_mode)
	loaded = _load_with(TEST_PATH_B, "auto_follow_mode=\"off\"")
	check.call(loaded.auto_follow_mode == "off", "(c) a valid auto_follow_mode \"off\" is kept ('%s')" % loaded.auto_follow_mode)

	loaded = _load_with(TEST_PATH_B, "invert_y=true\nsensitivity=2.5\nauto_follow_mode=\"on\"\nextra=Object(Resource,\"script\":null)")
	check.call(is_equal_approx(loaded.sensitivity, 1.0) and not loaded.invert_y and loaded.auto_follow_mode == "auto", "(c) a file with Object( syntax loads all defaults")

	_cleanup_file(TEST_PATH_C)
	loaded = CameraSettings.load_from(TEST_PATH_C)
	check.call(is_equal_approx(loaded.sensitivity, 1.0) and not loaded.invert_y and loaded.auto_follow_mode == "auto", "(c) a missing file loads all defaults")


# (d) saving outside user:// is refused and creates nothing (T-02-15).
func _scenario_settings_refusals(check: Callable) -> void:
	var settings: CameraSettings = CameraSettings.new()
	var result: Error = settings.save_to("res://x.cfg")
	check.call(result == ERR_INVALID_PARAMETER, "(d) save_to res:// returns ERR_INVALID_PARAMETER (%d)" % result)
	check.call(not FileAccess.file_exists("res://x.cfg"), "(d) no file was created at res://x.cfg")
	result = settings.save_to("user://../escape.cfg")
	check.call(result == ERR_INVALID_PARAMETER, "(d) save_to a user:// path with .. is refused (%d)" % result)
	result = settings.save_to("/tmp/attimo_escape.cfg")
	check.call(result == ERR_INVALID_PARAMETER, "(d) save_to an absolute path is refused (%d)" % result)
	_cleanup_file(TEST_PATH_A)
	_cleanup_file(TEST_PATH_B)
	_cleanup_file(TEST_PATH_C)


# ---------------------------------------------------------------------------------------------------------
# Auto-follow (D-16, A40, A41). Every scenario spawns its own floor, player and rig.
# ---------------------------------------------------------------------------------------------------------

func _spawn(tree: SceneTree, mode: String) -> Array[Node]:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(400, 1, 400))
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	var rig: CameraRig = Fixtures.spawn_camera_rig(tree.root, player)
	var settings: CameraSettings = CameraSettings.new()
	settings.auto_follow_mode = mode
	rig.apply_settings(settings)
	await Fixtures.wait_physics(tree, 10)
	await Fixtures.wait_process(tree, 2)
	rig.notify_look_activity()
	return [floor_body, player, rig]


func _free_all(tree: SceneTree, nodes: Array[Node]) -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		Input.action_release(action)
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame


## Awaits process frames for `seconds` of wall clock time.
func _run_for(tree: SceneTree, seconds: float) -> void:
	var end_msec: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end_msec:
		await tree.process_frame


## Holds `actions` for `seconds` of wall clock time, sampling the rig yaw and the player's horizontal heading every
## frame, then releases them. `mouse_pixels` != 0 sends that horizontal motion before every frame.
## Returns times, yaws, headings (parallel arrays), yaw_start and mouse_events.
func _hold(tree: SceneTree, rig: CameraRig, player: PlayerController, actions: Array[StringName], seconds: float, mouse_pixels: float = 0.0) -> Dictionary:
	var times: PackedFloat64Array = PackedFloat64Array()
	var yaws: PackedFloat64Array = PackedFloat64Array()
	var headings: Array[Vector2] = []
	var mouse_events: int = 0
	var yaw_start: float = rig.yaw
	for action: StringName in actions:
		Input.action_press(action)
	var start_msec: int = Time.get_ticks_msec()
	var elapsed: float = 0.0
	while elapsed < seconds:
		if mouse_pixels != 0.0:
			Fixtures.send_mouse_motion(Vector2(mouse_pixels, 0.0))
			mouse_events += 1
		await tree.process_frame
		elapsed = float(Time.get_ticks_msec() - start_msec) / 1000.0
		times.append(elapsed)
		yaws.append(rig.yaw)
		headings.append(Vector2(player.velocity.x, player.velocity.z))
	for action: StringName in actions:
		Input.action_release(action)
	return {"times": times, "yaws": yaws, "headings": headings, "yaw_start": yaw_start, "mouse_events": mouse_events}


## The yaw of the first sample at or after time `at`.
func _yaw_at(held: Dictionary, at: float) -> float:
	var times: PackedFloat64Array = held["times"]
	var yaws: PackedFloat64Array = held["yaws"]
	for i: int in times.size():
		if times[i] >= at:
			return yaws[i]
	return yaws[yaws.size() - 1]


func _heading_at(held: Dictionary, at: float) -> Vector2:
	var times: PackedFloat64Array = held["times"]
	var headings: Array = held["headings"]
	for i: int in times.size():
		if times[i] >= at:
			return headings[i]
	return headings[headings.size() - 1]


## Largest |yaw - yaw_start| over the samples before time `until`.
func _max_yaw_delta_before(held: Dictionary, until: float) -> float:
	var times: PackedFloat64Array = held["times"]
	var yaws: PackedFloat64Array = held["yaws"]
	var largest: float = 0.0
	for i: int in times.size():
		if times[i] >= until:
			break
		largest = maxf(largest, absf(yaws[i] - float(held["yaw_start"])))
	return largest


func _camera_forward(rig: CameraRig) -> Vector2:
	return Vector2(-rig.global_basis.z.x, -rig.global_basis.z.z)


func _key_event(keycode: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _joypad_button_event(pressed: bool) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _joypad_motion_event(value: float) -> void:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.device = 0
	event.axis = JOY_AXIS_RIGHT_X
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# (e) the last input device follows the events; stick noise below 0.2 is ignored; the mode picks auto_follow_active.
func _scenario_device_detection(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, "auto")
	var rig: CameraRig = nodes[2] as CameraRig
	check.call(rig.last_input_device == CameraRig.InputDevice.KEYBOARD_MOUSE, "(e) the rig starts as KEYBOARD_MOUSE")
	check.call(not rig.auto_follow_active(), "(e) auto with KEYBOARD_MOUSE is not active")
	_joypad_motion_event(0.1)
	check.call(rig.last_input_device == CameraRig.InputDevice.KEYBOARD_MOUSE, "(e) joypad stick noise (0.1) is ignored")
	_joypad_motion_event(0.5)
	check.call(rig.last_input_device == CameraRig.InputDevice.JOYPAD, "(e) a joypad stick beyond 0.2 sets JOYPAD")
	check.call(rig.auto_follow_active(), "(e) auto with JOYPAD is active")
	Fixtures.send_mouse_motion(Vector2(1.0, 0.0))
	check.call(rig.last_input_device == CameraRig.InputDevice.KEYBOARD_MOUSE, "(e) a mouse motion sets KEYBOARD_MOUSE")
	var on: CameraSettings = CameraSettings.new()
	on.auto_follow_mode = "on"
	rig.apply_settings(on)
	check.call(rig.auto_follow_active(), "(e) mode on is active with KEYBOARD_MOUSE")
	var off: CameraSettings = CameraSettings.new()
	off.auto_follow_mode = "off"
	rig.apply_settings(off)
	_joypad_button_event(true)
	_joypad_button_event(false)
	check.call(not rig.auto_follow_active(), "(e) mode off is never active, even after joypad input")
	await _free_all(tree, nodes)


# (f) look input arriving every frame is never fought (forced on).
func _scenario_forced_on_with_mouse(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, "on")
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	var held: Dictionary = await _hold(tree, rig, player, [&"move_right"], 2.5, 1.0)
	var expected: float = float(held["yaw_start"]) - float(held["mouse_events"]) * rig.base_sensitivity
	check.call(absf(rig.yaw - expected) < 1e-3, "(f) running sideways with mouse input every frame: yaw is the mouse contribution only (off by %.5f over %d events)" % [rig.yaw - expected, held["mouse_events"]])
	await _free_all(tree, nodes)


# (g) forced on, no look input: still during the delay, then sideways running pulls the camera along.
func _scenario_forced_on_delay(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, "on")
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	var held: Dictionary = await _hold(tree, rig, player, [&"move_right"], rig.auto_follow_delay + 1.5)
	var early: float = _max_yaw_delta_before(held, rig.auto_follow_delay - 0.1)
	check.call(early < 1e-4, "(g) the yaw does not change during the first auto_follow_delay - 0.1 s (%.6f)" % early)
	var pulled: float = float(held["yaw_start"]) - rig.yaw
	check.call(pulled > 0.3, "(g) by auto_follow_delay + 1.5 s the yaw has decreased by more than 0.3 rad (%.3f)" % pulled)
	await _free_all(tree, nodes)


## Stands auto_follow_delay + 0.1 s, then holds `actions` for 3 s and checks the convergence claims.
func _check_convergence(tree: SceneTree, check: Callable, label: String, actions: Array[StringName]) -> Array[Node]:
	var nodes: Array[Node] = await _spawn(tree, "on")
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	await _run_for(tree, rig.auto_follow_delay + 0.1)
	var held: Dictionary = await _hold(tree, rig, player, actions, 3.0)
	var last_second: float = absf(rig.yaw - _yaw_at(held, 2.0))
	check.call(last_second < 0.02, "%s the yaw changes by less than 0.02 rad over the last second (%.4f)" % [label, last_second])
	var heading: Vector2 = _heading_at(held, 3.0)
	var behind: float = absf(_camera_forward(rig).angle_to(heading))
	check.call(behind < 0.1, "%s the camera ends behind the run, forward within 0.1 rad of the heading (%.3f)" % [label, behind])
	var steered: float = absf(heading.angle_to(_heading_at(held, 0.5)))
	check.call(steered < 0.05, "%s the player's heading stays fixed, no circling (%.3f)" % [label, steered])
	check.call(float(held["yaw_start"]) - rig.yaw > 0.3, "%s the camera did swing (yaw down %.3f)" % [label, float(held["yaw_start"]) - rig.yaw])
	return nodes


# (h) held sideways key converges; the re-base then makes a new key relative to the current view.
func _scenario_converges_sideways(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _check_convergence(tree, check, "(h)", [&"move_right"])
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 30)
	var moving: Vector2 = Vector2(player.velocity.x, player.velocity.z).normalized()
	var alignment: float = moving.dot(_camera_forward(rig).normalized())
	check.call(alignment > 0.95, "(h) after the move key changes, forward runs along the current camera forward (dot %.3f)" % alignment)
	await _free_all(tree, nodes)


# (i) held diagonal converges.
func _scenario_converges_diagonal(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _check_convergence(tree, check, "(i)", [&"move_forward", &"move_right"])
	await _free_all(tree, nodes)


# (j) straight runs and runs toward the camera leave the yaw alone.
func _scenario_straight_runs(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, "on")
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	var held: Dictionary = await _hold(tree, rig, player, [&"move_forward"], 2.5)
	var drift: float = absf(rig.yaw - float(held["yaw_start"]))
	check.call(drift < 0.02, "(j) running straight ahead for 2.5 s leaves the yaw alone (%.4f)" % drift)
	await _free_all(tree, nodes)

	nodes = await _spawn(tree, "on")
	player = nodes[1] as PlayerController
	rig = nodes[2] as CameraRig
	held = await _hold(tree, rig, player, [&"move_back"], rig.auto_follow_delay + 2.0)
	drift = absf(rig.yaw - float(held["yaw_start"]))
	check.call(drift < 0.02, "(j) running toward the camera leaves the yaw alone (%.4f)" % drift)
	await _free_all(tree, nodes)


# (k) auto mode with keyboard and mouse never follows.
func _scenario_auto_keyboard(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, "auto")
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	_key_event(KEY_K, true)
	_key_event(KEY_K, false)
	check.call(rig.last_input_device == CameraRig.InputDevice.KEYBOARD_MOUSE, "(k) a key event leaves the device at KEYBOARD_MOUSE")
	var held: Dictionary = await _hold(tree, rig, player, [&"move_right"], rig.auto_follow_delay + 1.5)
	var drift: float = absf(rig.yaw - float(held["yaw_start"]))
	check.call(drift < 1e-4, "(k) auto with keyboard and mouse: running sideways leaves the yaw alone (%.6f)" % drift)
	await _free_all(tree, nodes)


# (l) auto mode follows after a joypad event and stops again mid-swing after a key event.
func _scenario_auto_joypad(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, "auto")
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	_joypad_button_event(true)
	_joypad_button_event(false)
	check.call(rig.last_input_device == CameraRig.InputDevice.JOYPAD, "(l) a joypad button event sets JOYPAD")
	var held: Dictionary = await _hold(tree, rig, player, [&"move_right"], rig.auto_follow_delay + 0.4)
	var pulled: float = float(held["yaw_start"]) - rig.yaw
	check.call(pulled > 0.3, "(l) auto after a joypad event: by auto_follow_delay + 0.4 s the yaw decreased by more than 0.3 rad (%.3f)" % pulled)
	# The swing is still running (it takes about 1.7 s); a key event must stop it.
	Input.action_press(&"move_right")
	_key_event(KEY_K, true)
	_key_event(KEY_K, false)
	check.call(rig.last_input_device == CameraRig.InputDevice.KEYBOARD_MOUSE, "(l) a key event switches the device to KEYBOARD_MOUSE")
	var yaw_after_key: float = rig.yaw
	await _run_for(tree, 0.5)
	Input.action_release(&"move_right")
	var drift: float = absf(rig.yaw - yaw_after_key)
	check.call(drift < 1e-4, "(l) the follow stops mid-swing after the key event (%.6f)" % drift)
	await _free_all(tree, nodes)


# (m) off mode never follows, even after joypad input.
func _scenario_off_mode(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, "off")
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	_joypad_button_event(true)
	_joypad_button_event(false)
	var held: Dictionary = await _hold(tree, rig, player, [&"move_right"], rig.auto_follow_delay + 1.5)
	var drift: float = absf(rig.yaw - float(held["yaw_start"]))
	check.call(drift < 1e-4, "(m) off mode: running sideways leaves the yaw alone (%.6f)" % drift)
	await _free_all(tree, nodes)
