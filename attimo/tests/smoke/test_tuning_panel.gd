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
