class_name EnergyHud
extends CanvasLayer
## Energy HUD (D-13, ENRG-05): top left, drawn in code in the crosshair's style (steel rim, dark plate, turquoise fill). Four core
## chambers show the arm energy with partial fill and mirror the diegetic cores on the forearm. It polls the player and its ArmEnergy
## read only every frame, never writes gameplay state, ignores the mouse and sits below the crosshair (layer 10) and the debug
## overlays (100+). Everything is sized from the screen height (ui_reference_height). Animation uses TimeFx.unscaled, so it keeps
## its real-time speed during the Loader slow motion.

## Screen height in pixels at which the pixel sizes apply 1:1; the HUD scales with height / this.
@export var ui_reference_height: float = 720.0
## Turquoise of the energy fill (the energy colour of the arm cores).
@export var fill_color: Color = Color(0.25, 0.9, 0.85, 1.0)
## Steel rim colour of a chamber.
@export var rim_color: Color = Color(0.62, 0.65, 0.7, 1.0)
## Dark plate colour behind the chambers.
@export var plate_color: Color = Color(0.1, 0.11, 0.13, 0.72)
## Dark outline colour under every line, so the HUD reads on bright sky.
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.55)

const MARGIN: float = 16.0
const CHAMBER_SIZE: Vector2 = Vector2(30.0, 18.0)
const CHAMBER_GAP: float = 5.0
const PLATE_PAD: float = 7.0
const PLATE_LEFT_FIRST: float = 0.0

## The Control everything is drawn on.
var panel: Control

var _fills: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _u: float = 1.0
var _time: float = 0.0


func _ready() -> void:
	layer = 9
	panel = $Panel as Control
	panel.draw.connect(_draw_panel)


func _process(delta: float) -> void:
	_time += TimeFx.unscaled(delta)
	var changed: bool = _poll()
	if changed:
		panel.queue_redraw()


## Fill of chamber `index` as last read from the arm (0.0 .. 1.0); 0.0 without a player.
func chamber_fill(index: int) -> float:
	if index < 0 or index >= _fills.size():
		return 0.0
	return _fills[index]


## Reads the arm (read only). Returns true when anything drawn changed.
func _poll() -> bool:
	var player: PlayerController = get_tree().get_first_node_in_group(&"player") as PlayerController
	var changed: bool = false
	for i: int in _fills.size():
		var fill: float = 0.0
		if player != null and player.arm_energy != null:
			fill = player.arm_energy.core_fill(i)
		if not is_equal_approx(fill, _fills[i]):
			_fills[i] = fill
			changed = true
	return changed


func _draw_panel() -> void:
	_u = clampf(panel.size.y / maxf(ui_reference_height, 1.0), 0.75, 3.0)
	var origin: Vector2 = Vector2(MARGIN, MARGIN) * _u
	var chambers_width: float = (CHAMBER_SIZE.x * _fills.size() + CHAMBER_GAP * (_fills.size() - 1)) * _u
	var plate: Rect2 = Rect2(origin, Vector2(chambers_width + PLATE_PAD * 2.0 * _u, CHAMBER_SIZE.y * _u + PLATE_PAD * 2.0 * _u))
	panel.draw_rect(plate, plate_color)
	for i: int in _fills.size():
		var rect: Rect2 = Rect2(origin + Vector2(PLATE_PAD * _u + i * (CHAMBER_SIZE.x + CHAMBER_GAP) * _u, PLATE_PAD * _u), CHAMBER_SIZE * _u)
		_draw_chamber(rect, _fills[i])


## One chamber: dark well, turquoise fill from the left by the fill, steel rim with a dark outline.
func _draw_chamber(rect: Rect2, fill: float) -> void:
	panel.draw_rect(rect, Color(0.04, 0.05, 0.06, 0.9))
	if fill > 0.0:
		panel.draw_rect(Rect2(rect.position, Vector2(rect.size.x * fill, rect.size.y)), fill_color)
	panel.draw_rect(rect.grow(1.0 * _u), outline_color, false, 2.0 * _u)
	panel.draw_rect(rect, rim_color, false, 1.5 * _u)
