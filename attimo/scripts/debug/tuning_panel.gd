class_name TuningPanel
extends CanvasLayer
## Debug-only live tuning panel (MOVE-10, D-23): one slider per MovementConfig float, bound to the live shared
## resource of the first node in group "player", so a change acts on the running player at once. Release builds
## drop it (REL-03). debug_tuning (F2 / 8) toggles it, hidden at start; showing it frees the mouse and hiding it
## recaptures the mouse (never in a headless run).
## Gameplay code never calls the panel. The panel never writes anything to user://, and it never saves the
## shared res:// config outside the editor (T-02-16).

const LABEL_WIDTH: float = 150.0
const VALUE_WIDTH: float = 52.0
const SLIDER_WIDTH: float = 150.0

## Where the camera settings are saved (user:// only, CameraSettings.save_to refuses anything else).
@export var settings_path: String = CameraSettings.DEFAULT_PATH

var _config: MovementConfig
var _rig: CameraRig
var _sliders: Dictionary[StringName, HSlider] = {}
var _value_labels: Dictionary[StringName, Label] = {}

@onready var _rows: VBoxContainer = %Rows
@onready var _sensitivity_slider: HSlider = %SensitivitySlider
@onready var _sensitivity_value: Label = %SensitivityValue
@onready var _invert_y_check: CheckBox = %InvertYCheck
@onready var _auto_follow_selector: OptionButton = %AutoFollowSelector
@onready var _save_button: Button = %SaveButton


func _ready() -> void:
	visible = false
	# The camera controls take their range and choices from CameraSettings, so panel and settings cannot disagree.
	_sensitivity_slider.min_value = CameraSettings.SENSITIVITY_MIN
	_sensitivity_slider.max_value = CameraSettings.SENSITIVITY_MAX
	for mode: String in CameraSettings.AUTO_FOLLOW_MODES:
		_auto_follow_selector.add_item(mode.capitalize())
	_sensitivity_slider.value_changed.connect(set_sensitivity)
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
	_apply(slider.value, property)


## Sets the mouse sensitivity multiplier (clamped to the CameraSettings range), applies it to the rig and saves it.
func set_sensitivity(value: float) -> void:
	var clamped: float = clampf(value, CameraSettings.SENSITIVITY_MIN, CameraSettings.SENSITIVITY_MAX)
	_sensitivity_slider.set_value_no_signal(clamped)
	_sensitivity_value.text = _format(clamped)
	var updated: CameraSettings = _copy_rig_settings()
	if updated == null:
		return
	updated.sensitivity = clamped
	_apply_camera_settings(updated)


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
func _apply_camera_settings(updated: CameraSettings) -> void:
	_rig.apply_settings(updated)
	updated.save_to(settings_path)


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
		if info.type != TYPE_FLOAT or (usage & PROPERTY_USAGE_EDITOR) == 0 or info.hint != PROPERTY_HINT_RANGE:
			continue
		_add_row(info.name as StringName, info.hint_string as String)


func _add_row(property: StringName, hint_string: String) -> void:
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
	slider.set_value_no_signal(_config.get(property))
	slider.value_changed.connect(_apply.bind(property))
	row.add_child(slider)

	var value_label: Label = Label.new()
	value_label.custom_minimum_size.x = VALUE_WIDTH
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = _format(slider.value)
	row.add_child(value_label)

	_rows.add_child(row)
	_sliders[property] = slider
	_value_labels[property] = value_label


## Writes `value` into the live config (D-23: one tunable resource) and refreshes the value label.
func _apply(value: float, property: StringName) -> void:
	_config.set(property, value)
	(_value_labels[property] as Label).text = _format(value)


func _format(value: float) -> String:
	return "%.2f" % value
