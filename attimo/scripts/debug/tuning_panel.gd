class_name TuningPanel
extends CanvasLayer
## Debug-only live tuning panel (MOVE-10, D-23): one slider per MovementConfig float, bound to the live shared
## resource of the first node in group "player", so a change acts on the running player at once. Release builds
## drop it (REL-03). debug_tuning (F2 / 8) toggles it, hidden at start; showing it frees the mouse and hiding it
## recaptures the mouse (never in a headless run).
## A generated "Hand" section tunes the HandController's hand_* range floats the same way (D-05, D-14); they are never saved.
## A generated "Kit" section (plan 05.1-05, D-05, D-12) tunes the nearest kit block: every KIT_SCAN_INTERVAL of real time (not per
## frame, T-05.1-15) it finds the nearest node of group kit_block within KIT_RANGE of the player and, when that changes, rebuilds one
## slider per range float of the block's `config` under "Kit: <node name>". The sliders write the block's own duplicated config
## (KitBlock.own_config), never a loaded resource (a config with a resource_path is refused, T-05.1-14) and are never saved. Values
## a block reads only in _ready (trigger radius, barrel pitch) change on the next load; values read at use time act at once.
## Gameplay code never calls the panel. The panel never writes anything to user://, and it never saves the
## shared res:// config outside the editor (T-02-16).

const LABEL_WIDTH: float = 150.0
const VALUE_WIDTH: float = 52.0
const SLIDER_WIDTH: float = 150.0
## Kit section: real seconds between two nearest-block scans, and the scan reach in m around the player.
const KIT_SCAN_INTERVAL: float = 0.25
const KIT_RANGE: float = 8.0

## Where the camera settings are saved (user:// only, CameraSettings.save_to refuses anything else).
@export var settings_path: String = CameraSettings.DEFAULT_PATH

var _config: MovementConfig
var _rig: CameraRig
var _sliders: Dictionary[StringName, HSlider] = {}
var _value_labels: Dictionary[StringName, Label] = {}
var _hand: HandController
var _hand_rows: VBoxContainer
var _hand_sliders: Dictionary[StringName, HSlider] = {}
var _hand_value_labels: Dictionary[StringName, Label] = {}
var _kit_rows: VBoxContainer
var _kit_block: Node3D
var _kit_config: Resource
var _kit_sliders: Dictionary[StringName, HSlider] = {}
var _kit_value_labels: Dictionary[StringName, Label] = {}
var _kit_scan_left: float = 0.0
## True between drag_started and drag_ended of the sensitivity slider: ticks apply to the rig but do not save (WR-04).
var _sensitivity_dragging: bool = false

@onready var _rows: VBoxContainer = %Rows
@onready var _sensitivity_slider: HSlider = %SensitivitySlider
@onready var _sensitivity_value: Label = %SensitivityValue
@onready var _invert_y_check: CheckBox = %InvertYCheck
@onready var _auto_follow_selector: OptionButton = %AutoFollowSelector
@onready var _save_button: Button = %SaveButton


func _ready() -> void:
	visible = false
	# The hand rows live in their own container after the movement rows, so build order does not matter.
	_hand_rows = VBoxContainer.new()
	_rows.get_parent().add_child(_hand_rows)
	_kit_rows = VBoxContainer.new()
	_rows.get_parent().add_child(_kit_rows)
	# The camera controls take their range and choices from CameraSettings, so panel and settings cannot disagree.
	_sensitivity_slider.min_value = CameraSettings.SENSITIVITY_MIN
	_sensitivity_slider.max_value = CameraSettings.SENSITIVITY_MAX
	for mode: String in CameraSettings.AUTO_FOLLOW_MODES:
		_auto_follow_selector.add_item(mode.capitalize())
	_sensitivity_slider.drag_started.connect(func() -> void: _sensitivity_dragging = true)
	_sensitivity_slider.drag_ended.connect(_on_sensitivity_drag_ended)
	_sensitivity_slider.value_changed.connect(_on_sensitivity_slider_changed)
	_invert_y_check.toggled.connect(set_invert_y)
	_auto_follow_selector.item_selected.connect(_on_auto_follow_selected)
	# A15: the shared res:// config is only ever saved from the editor.
	_save_button.disabled = not OS.has_feature("editor")
	_save_button.pressed.connect(_on_save_pressed)
	# Deferred, so the scene order of panel, player and rig does not matter.
	_bind.call_deferred()


## Number of movement sliders: one per MovementConfig float with an editor range hint.
func row_count() -> int:
	return _sliders.size()


## Moves the slider of `property` (clamped to its range) and with it the live config value.
## An unknown property is ignored.
func set_value(property: StringName, value: float) -> void:
	var slider: HSlider = _sliders.get(property) as HSlider
	if slider == null:
		return
	slider.set_value_no_signal(value)
	_apply(slider.value, property, _config, _value_labels)


## Number of hand sliders: one per HandController float named hand_* with an editor range hint.
func hand_row_count() -> int:
	return _hand_sliders.size()


## Moves the slider of the hand `property` (clamped to its range) and with it the live HandController value.
## An unknown property is ignored. Never saved.
func set_hand_value(property: StringName, value: float) -> void:
	var slider: HSlider = _hand_sliders.get(property) as HSlider
	if slider == null or _hand == null:
		return
	slider.set_value_no_signal(value)
	_apply(slider.value, property, _hand, _hand_value_labels)


## Number of kit sliders: one per range float of the nearest kit block's config (0 with no block within KIT_RANGE).
func kit_row_count() -> int:
	return _kit_sliders.size()


## Moves the slider of the kit `property` (clamped to its range) and with it the bound block's own config value (D-12: the node-local
## duplicate, never the preset). An unknown property is ignored. Never saved.
func set_kit_value(property: StringName, value: float) -> void:
	var slider: HSlider = _kit_sliders.get(property) as HSlider
	if slider == null or _kit_config == null:
		return
	slider.set_value_no_signal(value)
	_apply(slider.value, property, _kit_config, _kit_value_labels)


## Polls the nearest kit block every KIT_SCAN_INTERVAL of real time, shown or hidden, so the section is ready when F2 opens.
func _process(delta: float) -> void:
	_kit_scan_left -= TimeFx.unscaled(delta)
	if _kit_scan_left > 0.0:
		return
	_kit_scan_left = KIT_SCAN_INTERVAL
	var nearest: Node3D = _nearest_kit_block()
	if nearest != _kit_block or (_kit_block != null and not is_instance_valid(_kit_block)):
		_bind_kit(nearest)


## The nearest kit block within KIT_RANGE of the player whose config is a node-local copy, or null.
func _nearest_kit_block() -> Node3D:
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return null
	var best: Node3D = null
	var best_distance: float = KIT_RANGE
	for node: Node in get_tree().get_nodes_in_group(&"kit_block"):
		var block: Node3D = node as Node3D
		if block == null or not is_instance_valid(block) or not block.is_inside_tree():
			continue
		var config: Resource = block.get(&"config") as Resource
		# T-05.1-14 / D-12: a config that still points at a loaded file is shared; never bind it.
		if config == null or not config.resource_path.is_empty():
			continue
		var distance: float = block.global_position.distance_to(player.global_position)
		if distance <= best_distance:
			best = block
			best_distance = distance
	return best


## Rebuilds the Kit section for `block` (null clears it).
func _bind_kit(block: Node3D) -> void:
	for child: Node in _kit_rows.get_children():
		_kit_rows.remove_child(child)
		child.queue_free()
	_kit_sliders.clear()
	_kit_value_labels.clear()
	_kit_block = block
	_kit_config = null if block == null else block.get(&"config") as Resource
	if _kit_config == null:
		_kit_block = null
		return
	var header: Label = Label.new()
	header.text = "Kit: %s" % block.name
	_kit_rows.add_child(header)
	for info: Dictionary in _kit_config.get_property_list():
		if (info.type != TYPE_FLOAT and info.type != TYPE_INT) or (info.usage & PROPERTY_USAGE_EDITOR) == 0 or info.hint != PROPERTY_HINT_RANGE:
			continue
		_add_row(_kit_config, info.name as StringName, info.hint_string as String, _kit_rows, _kit_sliders, _kit_value_labels)


## Sets the mouse sensitivity multiplier (clamped to the CameraSettings range), applies it to the rig and saves it.
func set_sensitivity(value: float) -> void:
	_set_sensitivity(value, true)


## Slider ticks while dragging reach the rig at once, the file is written when the drag ends (WR-04). Keyboard steps and
## clicks outside a drag save at once.
func _on_sensitivity_slider_changed(value: float) -> void:
	_set_sensitivity(value, not _sensitivity_dragging)


func _on_sensitivity_drag_ended(_value_changed: bool) -> void:
	_sensitivity_dragging = false
	var updated: CameraSettings = _copy_rig_settings()
	if updated != null:
		_save_camera_settings(updated)


func _set_sensitivity(value: float, save: bool) -> void:
	var clamped: float = clampf(value, CameraSettings.SENSITIVITY_MIN, CameraSettings.SENSITIVITY_MAX)
	_sensitivity_slider.set_value_no_signal(clamped)
	_sensitivity_value.text = _format(clamped)
	var updated: CameraSettings = _copy_rig_settings()
	if updated == null:
		return
	updated.sensitivity = clamped
	_apply_camera_settings(updated, save)


## Flips the vertical mouse look, applies it to the rig and saves it.
func set_invert_y(enabled: bool) -> void:
	_invert_y_check.set_pressed_no_signal(enabled)
	var updated: CameraSettings = _copy_rig_settings()
	if updated == null:
		return
	updated.invert_y = enabled
	_apply_camera_settings(updated)


## Sets the auto-follow mode (A41), applies it to the rig and saves it. A mode outside
## CameraSettings.AUTO_FOLLOW_MODES is refused: nothing changes and the selector keeps showing the rig's mode.
func set_auto_follow_mode(mode: String) -> void:
	var index: int = CameraSettings.AUTO_FOLLOW_MODES.find(mode)
	if index < 0:
		_sync_camera_controls()
		return
	_auto_follow_selector.select(index)
	var updated: CameraSettings = _copy_rig_settings()
	if updated == null:
		return
	updated.auto_follow_mode = mode
	_apply_camera_settings(updated)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"debug_tuning"):
		_set_shown(not visible)
		_kit_scan_left = 0.0


func _set_shown(shown: bool) -> void:
	visible = shown
	if shown:
		_bind()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _bind() -> void:
	if _config == null:
		var player: PlayerController = get_tree().get_first_node_in_group(&"player") as PlayerController
		if player != null and player.config != null:
			_config = player.config
			_build_rows()
	if _rig == null:
		_rig = _find_rig()
		_sync_camera_controls()
	if _hand == null:
		_hand = get_tree().get_first_node_in_group(&"hand_controller") as HandController
		if _hand != null:
			_build_hand_rows()


## The CameraRig that owns the viewport's current camera, found by walking up its parents.
func _find_rig() -> CameraRig:
	var node: Node = get_viewport().get_camera_3d()
	while node != null:
		var rig: CameraRig = node as CameraRig
		if rig != null:
			return rig
		node = node.get_parent()
	return null


## Shows the rig's current settings in the camera controls without triggering a change.
func _sync_camera_controls() -> void:
	if _rig == null or _rig.settings == null:
		return
	_sensitivity_slider.set_value_no_signal(_rig.settings.sensitivity)
	_sensitivity_value.text = _format(_rig.settings.sensitivity)
	_invert_y_check.set_pressed_no_signal(_rig.settings.invert_y)
	var index: int = CameraSettings.AUTO_FOLLOW_MODES.find(_rig.settings.auto_follow_mode)
	if index >= 0:
		_auto_follow_selector.select(index)


## A copy of the rig's settings to change (CameraSettings is plain data), or null without a rig.
func _copy_rig_settings() -> CameraSettings:
	if _rig == null or _rig.settings == null:
		return null
	var copy: CameraSettings = CameraSettings.new()
	copy.sensitivity = _rig.settings.sensitivity
	copy.invert_y = _rig.settings.invert_y
	copy.auto_follow_mode = _rig.settings.auto_follow_mode
	return copy


## Gives the rig the changed settings and saves them to settings_path (D-19, CAM-03).
func _apply_camera_settings(updated: CameraSettings, save: bool = true) -> void:
	_rig.apply_settings(updated)
	if save:
		_save_camera_settings(updated)


## Writes the settings to settings_path and warns when that fails (read-only or full user directory), WR-04.
func _save_camera_settings(updated: CameraSettings) -> void:
	var err: Error = updated.save_to(settings_path)
	if err != OK:
		push_warning("TuningPanel: could not save camera settings to %s (error %d)" % [settings_path, err])


func _on_auto_follow_selected(index: int) -> void:
	if index >= 0 and index < CameraSettings.AUTO_FOLLOW_MODES.size():
		set_auto_follow_mode(CameraSettings.AUTO_FOLLOW_MODES[index])


## Writes the live MovementConfig back to its own res:// file. Editor only (A15, T-02-16); never user://.
func _on_save_pressed() -> void:
	if not OS.has_feature("editor") or _config == null:
		return
	if not _config.resource_path.begins_with("res://"):
		return
	ResourceSaver.save(_config, _config.resource_path)


func _build_rows() -> void:
	for info: Dictionary in _config.get_property_list():
		var usage: int = info.usage
		if (usage & PROPERTY_USAGE_GROUP) != 0:
			var header: Label = Label.new()
			header.text = "- %s -" % info.name
			_rows.add_child(header)
			continue
		if (info.type != TYPE_FLOAT and info.type != TYPE_INT) or (usage & PROPERTY_USAGE_EDITOR) == 0 or info.hint != PROPERTY_HINT_RANGE:
			continue
		_add_row(_config, info.name as StringName, info.hint_string as String, _rows, _sliders, _value_labels)


## The "Hand" section: one row per HandController float named hand_* with an editor range hint.
func _build_hand_rows() -> void:
	var header: Label = Label.new()
	header.text = "- Hand -"
	_hand_rows.add_child(header)
	for info: Dictionary in _hand.get_property_list():
		var property: StringName = info.name as StringName
		if (info.type != TYPE_FLOAT and info.type != TYPE_INT) or (info.usage & PROPERTY_USAGE_EDITOR) == 0 or info.hint != PROPERTY_HINT_RANGE:
			continue
		if not String(property).begins_with("hand_"):
			continue
		_add_row(_hand, property, info.hint_string as String, _hand_rows, _hand_sliders, _hand_value_labels)


## Adds a label, slider and value label for the float `property` of `target` to `parent`.
func _add_row(target: Object, property: StringName, hint_string: String, parent: Control,
		sliders: Dictionary[StringName, HSlider], labels: Dictionary[StringName, Label]) -> void:
	var parts: PackedStringArray = hint_string.split(",")
	var row: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = String(property)
	name_label.custom_minimum_size.x = LABEL_WIDTH
	row.add_child(name_label)

	var slider: HSlider = HSlider.new()
	slider.min_value = parts[0].to_float()
	slider.max_value = parts[1].to_float()
	if parts.size() > 2:
		slider.step = parts[2].to_float()
	slider.custom_minimum_size.x = SLIDER_WIDTH
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.set_value_no_signal(target.get(property))
	slider.value_changed.connect(_apply.bind(property, target, labels))
	row.add_child(slider)

	var value_label: Label = Label.new()
	value_label.custom_minimum_size.x = VALUE_WIDTH
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = "%d" % roundi(slider.value) if typeof(target.get(property)) == TYPE_INT else _format(slider.value)
	row.add_child(value_label)

	parent.add_child(row)
	sliders[property] = slider
	labels[property] = value_label


## Writes `value` into the live `target` (D-23: one tunable resource, or the HandController for the hand rows) and
## refreshes the value label.
func _apply(value: float, property: StringName, target: Object, labels: Dictionary[StringName, Label]) -> void:
	# An int property (the energy step costs) stores a whole number; the slider step is 1 but a script call may pass 2.4.
	if typeof(target.get(property)) == TYPE_INT:
		target.set(property, roundi(value))
		(labels[property] as Label).text = "%d" % roundi(value)
		return
	target.set(property, value)
	(labels[property] as Label).text = _format(value)


func _format(value: float) -> String:
	return "%.2f" % value
