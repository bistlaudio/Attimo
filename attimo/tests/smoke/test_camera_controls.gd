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
	await _scenario_mouse_look(tree, check)
	_scenario_settings_round_trip(check)
	_scenario_settings_tampering(check)
	_scenario_settings_refusals(check)


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
