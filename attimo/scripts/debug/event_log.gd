class_name EventLog
extends CanvasLayer
## Debug-only overlay: a live, timestamped log of every EventBus fact (D-12).
## Not an autoload; a scene that the test scene instances. Release builds drop it (REL-03, Phase 15).
## It connects to every signal the EventBus declares, so facts added in later phases appear with no edit here.
## Toggle with the debug_event_log action. The overlay starts hidden.

const MAX_LINES: int = 14

## Public so the smoke tests can read it.
var lines: Array[String] = []

@onready var _label: RichTextLabel = %Lines


func _ready() -> void:
	for sig: Dictionary in EventBus.get_script().get_script_signal_list():
		EventBus.connect(sig.name, _on_fact.bind(sig.name))
	visible = false


## Variadic handler: bind() appends the signal name last, so pop it off the end.
func _on_fact(...args: Array) -> void:
	var fact: StringName = args.pop_back()
	lines.append("[%7.2f] %s %s" % [Time.get_ticks_msec() / 1000.0, fact, args])
	if lines.size() > MAX_LINES:
		lines.pop_front()
	_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_event_log"):
		visible = not visible
