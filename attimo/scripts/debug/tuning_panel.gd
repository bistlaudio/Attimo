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
var _sliders: Dictionary[StringName, HSlider] = {}
var _value_labels: Dictionary[StringName, Label] = {}

@onready var _rows: VBoxContainer = %Rows


func _ready() -> void:
	visible = false
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
	if _config != null:
		return
	var player: PlayerController = get_tree().get_first_node_in_group(&"player") as PlayerController
	if player != null and player.config != null:
		_config = player.config
		_build_rows()


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
