extends RefCounted
## MOVE-10 / CAM-03 / D-23: the F2 tuning panel. One slider per MovementConfig float bound to the live resource,
## a camera section (sensitivity, invert-Y, auto-follow mode) on top of CameraSettings, an editor-only Save button.
## The player's config is replaced by a duplicate before the panel binds, so no test ever touches the shared
## res:// resource. The camera settings go to user://test_tuning_settings.cfg, deleted at the end.

const Fixtures := preload("res://tests/fixtures.gd")
const PANEL_SCENE: String = "res://scenes/debug/tuning_panel.tscn"
const CONFIG_PATH: String = "res://resources/player/movement_default.tres"
const TEST_SETTINGS_PATH: String = "user://test_tuning_settings.cfg"


func run(tree: SceneTree, check: Callable) -> void:
	# The runner calls us from _initialize, before the root is inside the tree.
	await tree.process_frame
	await _scenario_toggle(tree, check)
	await _scenario_row_count(tree, check)
	await _scenario_live_retune(tree, check)
	await _scenario_camera_settings(tree, check)
	await _scenario_auto_follow(tree, check)
	await _scenario_save_button(tree, check)
	_cleanup_file(TEST_SETTINGS_PATH)


func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _tap(action: StringName) -> void:
	Fixtures.send_action_event(action, true)
	Fixtures.send_action_event(action, false)


## Floor, a player with its own copy of the config, a camera rig (default settings), then the panel.
func _spawn(tree: SceneTree) -> Array[Node]:
	_cleanup_file(TEST_SETTINGS_PATH)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	player.config = player.config.duplicate() as MovementConfig
	var rig: CameraRig = Fixtures.spawn_camera_rig(tree.root, player)
	var panel: TuningPanel = (load(PANEL_SCENE) as PackedScene).instantiate() as TuningPanel
	panel.settings_path = TEST_SETTINGS_PATH
	tree.root.add_child(panel)
	await Fixtures.wait_physics(tree, 3)
	await Fixtures.wait_process(tree, 2)
	return [floor_body, player, rig, panel]


func _free_all(tree: SceneTree, nodes: Array[Node]) -> void:
	Input.action_release(&"move_forward")
	for node: Node in nodes:
		node.queue_free()
	await tree.process_frame
	_cleanup_file(TEST_SETTINGS_PATH)


func _expected_rows() -> int:
	var count: int = 0
	for info: Dictionary in MovementConfig.new().get_property_list():
		if info.type == TYPE_FLOAT and (info.usage & PROPERTY_USAGE_EDITOR) != 0 and info.hint == PROPERTY_HINT_RANGE:
			count += 1
	return count


# (1) hidden at start, debug_tuning shows it, a second press hides it.
func _scenario_toggle(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree)
	var panel: TuningPanel = nodes[3] as TuningPanel
	check.call(not panel.visible, "(1) the panel starts hidden")
	_tap(&"debug_tuning")
	check.call(panel.visible, "(1) a debug_tuning press shows the panel")
	_tap(&"debug_tuning")
	check.call(not panel.visible, "(1) a second debug_tuning press hides it")
	await _free_all(tree, nodes)


# (2) one row per float property with an editor range hint.
func _scenario_row_count(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree)
	var panel: TuningPanel = nodes[3] as TuningPanel
	var expected: int = _expected_rows()
	check.call(expected > 20, "(2) MovementConfig has many range floats (%d)" % expected)
	check.call(panel.row_count() == expected, "(2) row_count %d equals the MovementConfig float properties %d" % [panel.row_count(), expected])
	await _free_all(tree, nodes)


# (3) set_value moves the live config: the running player reaches the new run speed without a restart.
func _scenario_live_retune(tree: SceneTree, check: Callable) -> void:
	var shared: MovementConfig = load(CONFIG_PATH) as MovementConfig
	var shared_before: float = shared.run_speed
	var nodes: Array[Node] = await _spawn(tree)
	var player: PlayerController = nodes[1] as PlayerController
	var panel: TuningPanel = nodes[3] as TuningPanel
	panel.set_value(&"run_speed", 9.0)
	check.call(is_equal_approx(player.config.run_speed, 9.0), "(3) set_value changes the player's config.run_speed to 9.0 (got %.2f)" % player.config.run_speed)
	Input.action_press(&"move_forward")
	var reached: int = await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - 9.0) <= 0.05, 120)
	check.call(reached >= 0, "(3) the running player reaches 9.0 m/s without a restart (got %.2f)" % player.horizontal_speed())
	check.call(shared.run_speed == shared_before, "(3) the shared res:// config keeps run_speed %.1f (the test used a duplicate)" % shared_before)
	await _free_all(tree, nodes)


# (4) sensitivity and invert-Y reach the rig and the saved file.
func _scenario_camera_settings(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree)
	var rig: CameraRig = nodes[2] as CameraRig
	var panel: TuningPanel = nodes[3] as TuningPanel
	panel.set_sensitivity(2.0)
	panel.set_invert_y(true)
	check.call(is_equal_approx(rig.settings.sensitivity, 2.0), "(4) set_sensitivity(2.0) reaches rig.settings (got %.2f)" % rig.settings.sensitivity)
	check.call(rig.settings.invert_y, "(4) set_invert_y(true) reaches rig.settings")
	var saved: CameraSettings = CameraSettings.load_from(TEST_SETTINGS_PATH)
	check.call(is_equal_approx(saved.sensitivity, 2.0) and saved.invert_y, "(4) both are saved to the panel's settings_path (got %.2f, %s)" % [saved.sensitivity, saved.invert_y])
	var slider: HSlider = panel.get_node("%SensitivitySlider") as HSlider
	check.call(is_equal_approx(slider.min_value, CameraSettings.SENSITIVITY_MIN) and is_equal_approx(slider.max_value, CameraSettings.SENSITIVITY_MAX), "(4) the sensitivity slider range is [%.1f, %.1f]" % [slider.min_value, slider.max_value])
	await _free_all(tree, nodes)


# (5) the Auto-follow selector mirrors CameraSettings.AUTO_FOLLOW_MODES and refuses anything else.
func _scenario_auto_follow(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree)
	var rig: CameraRig = nodes[2] as CameraRig
	var panel: TuningPanel = nodes[3] as TuningPanel
	var selector: OptionButton = panel.get_node("%AutoFollowSelector") as OptionButton
	var modes: Array[String] = CameraSettings.AUTO_FOLLOW_MODES
	check.call(selector.item_count == modes.size(), "(5) the selector has %d items (got %d)" % [modes.size(), selector.item_count])
	var texts: Array[String] = []
	for i: int in selector.item_count:
		texts.append(selector.get_item_text(i).to_lower())
	check.call(texts == modes, "(5) the items follow AUTO_FOLLOW_MODES in order (got %s)" % [texts])
	check.call(selector.selected == modes.find(rig.settings.auto_follow_mode), "(5) it starts on the rig's mode '%s'" % rig.settings.auto_follow_mode)
	panel.set_auto_follow_mode("on")
	check.call(rig.settings.auto_follow_mode == "on" and rig.auto_follow_active(), "(5) set_auto_follow_mode('on') applies it and auto-follow is active")
	check.call(selector.get_item_text(selector.selected) == "On", "(5) the selector shows On")
	check.call(CameraSettings.load_from(TEST_SETTINGS_PATH).auto_follow_mode == "on", "(5) 'on' is saved")
	panel.set_auto_follow_mode("off")
	check.call(not rig.auto_follow_active(), "(5) 'off' makes auto_follow_active false")
	panel.set_auto_follow_mode("sideways")
	check.call(rig.settings.auto_follow_mode == "off", "(5) 'sideways' is refused, the rig keeps 'off' (got '%s')" % rig.settings.auto_follow_mode)
	check.call(CameraSettings.load_from(TEST_SETTINGS_PATH).auto_follow_mode == "off", "(5) the saved value stays 'off'")
	check.call(selector.get_item_text(selector.selected) == "Off", "(5) the selector still shows Off")
	# Choosing an item routes through the same setter.
	selector.item_selected.emit(0)
	check.call(rig.settings.auto_follow_mode == "auto", "(5) choosing the first item sets 'auto' (got '%s')" % rig.settings.auto_follow_mode)
	await _free_all(tree, nodes)


# (6) the Save button is disabled outside the editor.
func _scenario_save_button(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree)
	var panel: TuningPanel = nodes[3] as TuningPanel
	var button: Button = panel.get_node("%SaveButton") as Button
	check.call(OS.has_feature("editor") or button.disabled, "(6) the Save button is disabled when not running from the editor")
	await _free_all(tree, nodes)
