class_name EnergyHud
extends CanvasLayer
## Energy HUD (D-13, ENRG-05): top left, drawn in code in the crosshair's style (steel rim, dark plate, turquoise fill). Four core
## chambers show the arm energy with partial fill and mirror the diegetic cores on the forearm. Next to them: a Moto Perpetuo badge
## (lit while the arm is in Moto), the name plate of the active hand module and, below, a momentum gauge (horizontal speed 0..24 m/s,
## marks at run speed, the dash exit speed and the Loader maximum, the part
## above run speed tinted turquoise; the energy clock face replaces the chambers in 05.1-09) with a charge indicator while the charge button works. A slot to the right of the chambers
## stays free for the health of Phase 6.
## It polls the player, its ArmEnergy and the HandController read only every frame, never writes gameplay state, ignores the mouse and
## sits below the crosshair (layer 10) and the debug overlays (100+). Everything is sized from the screen height (ui_reference_height).
## Animation uses TimeFx.unscaled, so it keeps its real-time speed during the Loader slow motion.

## Screen height in pixels at which the pixel sizes apply 1:1; the HUD scales with height / this.
@export var ui_reference_height: float = 720.0
## Turquoise of the energy fill (the energy colour of the arm cores).
@export var fill_color: Color = Color(0.25, 0.9, 0.85, 1.0)
## Steel rim colour of a chamber.
@export var rim_color: Color = Color(0.62, 0.65, 0.7, 1.0)
## Dark plate colour behind the chambers.
@export var plate_color: Color = Color(0.1, 0.11, 0.13, 0.72)
## Cream of the text and the marks (the UI accent colour).
@export var text_color: Color = Color(0.96, 0.93, 0.85, 0.9)
## Dark outline colour under every line, so the HUD reads on bright sky.
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.55)
## Top of the momentum gauge in m/s (the fastest mark, the Loader maximum 22, sits below it).
@export var gauge_max_speed: float = 24.0

const MARGIN: float = 16.0
const CHAMBER_SIZE: Vector2 = Vector2(30.0, 18.0)
const CHAMBER_GAP: float = 5.0
const PLATE_PAD: float = 7.0
const BADGE_SIZE: Vector2 = Vector2(118.0, 18.0)
const PLATE_GAP: float = 8.0
const HEALTH_SLOT_SIZE: Vector2 = Vector2(120.0, 18.0)
const GAUGE_RADIUS: float = 34.0
const GAUGE_START: float = PI * 0.75
const GAUGE_SWEEP: float = PI * 1.5
const FONT_SIZE: int = 13
const SMALL_FONT_SIZE: int = 11

## The Control everything is drawn on.
var panel: Control
## True while the Moto Perpetuo badge is lit (the arm is in Moto).
var is_moto_shown: bool = false
## The display name of the active hand module (empty without one).
var module_name: String = ""
## The horizontal speed shown by the gauge needle, m/s.
var speed_gauge_value: float = 0.0
## The speeds of the gauge marks in m/s: run speed, dash exit speed, Loader maximum.
var gauge_marks: Array[float] = []
## True while the charge button charges the arm.
var charging_shown: bool = false

var _fills: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _split_speed: float = 7.0
var _u: float = 1.0
var _time: float = 0.0


func _ready() -> void:
	layer = 9
	panel = $Panel as Control
	panel.draw.connect(_draw_panel)


func _process(delta: float) -> void:
	_time += TimeFx.unscaled(delta)
	var changed: bool = _poll()
	if changed or charging_shown or is_moto_shown:
		panel.queue_redraw()


## Fill of chamber `index` as last read from the arm (0.0 .. 1.0); 0.0 without a player.
func chamber_fill(index: int) -> float:
	if index < 0 or index >= _fills.size():
		return 0.0
	return _fills[index]


## The rectangle of the four chambers plate in panel pixels (at the current UI scale).
func chambers_rect() -> Rect2:
	var scale: float = _scale()
	var origin: Vector2 = Vector2(MARGIN, MARGIN) * scale
	var width: float = (CHAMBER_SIZE.x * _fills.size() + CHAMBER_GAP * (_fills.size() - 1) + PLATE_PAD * 2.0) * scale
	return Rect2(origin, Vector2(width, (CHAMBER_SIZE.y + PLATE_PAD * 2.0) * scale))


## The empty slot to the right of the chambers where Phase 6 puts the health.
func health_slot_rect() -> Rect2:
	var chambers: Rect2 = chambers_rect()
	var scale: float = _scale()
	return Rect2(Vector2(chambers.end.x + PLATE_GAP * scale, chambers.position.y), HEALTH_SLOT_SIZE * scale)


func _scale() -> float:
	var height: float = ui_reference_height if panel == null else panel.size.y
	return clampf(height / maxf(ui_reference_height, 1.0), 0.75, 3.0)


## Reads the arm, the hand and the config (read only). Returns true when anything drawn changed.
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
	var moto: bool = player != null and player.arm_energy != null and player.arm_energy.is_moto()
	var charging: bool = player != null and player.arm_energy != null and player.arm_energy.charging
	var speed: float = 0.0 if player == null else player.horizontal_speed()
	var hand: HandController = get_tree().get_first_node_in_group(&"hand_controller") as HandController
	var module: String = "" if hand == null or hand.active_def == null else hand.active_def.display_name
	if moto != is_moto_shown or charging != charging_shown or module != module_name or not is_equal_approx(speed, speed_gauge_value):
		changed = true
	is_moto_shown = moto
	charging_shown = charging
	module_name = module
	speed_gauge_value = speed
	if player != null:
		var config: MovementConfig = player.config
		gauge_marks = [config.run_speed, config.dash_exit_speed, config.loader_max_speed]
		_split_speed = config.run_speed
	return changed


func _draw_panel() -> void:
	_u = _scale()
	var plate: Rect2 = chambers_rect()
	panel.draw_rect(plate, plate_color)
	for i: int in _fills.size():
		var rect: Rect2 = Rect2(plate.position + Vector2(PLATE_PAD * _u + i * (CHAMBER_SIZE.x + CHAMBER_GAP) * _u, PLATE_PAD * _u), CHAMBER_SIZE * _u)
		_draw_chamber(rect, _fills[i])
	# The Moto badge and the module plate sit under the chambers; the health slot to the right stays empty (Phase 6).
	var badge: Rect2 = Rect2(Vector2(plate.position.x, plate.end.y + PLATE_GAP * _u), BADGE_SIZE * _u)
	_draw_badge(badge)
	var module_rect: Rect2 = Rect2(Vector2(badge.end.x + PLATE_GAP * _u, badge.position.y), Vector2(112.0, BADGE_SIZE.y) * _u)
	_draw_text_plate(module_rect, module_name if module_name != "" else "-", text_color)
	_draw_gauge(Vector2(plate.position.x + (GAUGE_RADIUS + 6.0) * _u, badge.end.y + (GAUGE_RADIUS + 16.0) * _u))


## One chamber: dark well, turquoise fill from the left by the fill, steel rim with a dark outline.
func _draw_chamber(rect: Rect2, fill: float) -> void:
	panel.draw_rect(rect, Color(0.04, 0.05, 0.06, 0.9))
	if fill > 0.0:
		panel.draw_rect(Rect2(rect.position, Vector2(rect.size.x * fill, rect.size.y)), fill_color)
	panel.draw_rect(rect.grow(1.0 * _u), outline_color, false, 2.0 * _u)
	panel.draw_rect(rect, rim_color, false, 1.5 * _u)


## The Moto Perpetuo badge: dark with a steel rim while off, turquoise rim and fill while the arm is in Moto.
func _draw_badge(rect: Rect2) -> void:
	panel.draw_rect(rect, plate_color)
	if is_moto_shown:
		panel.draw_rect(rect.grow(-2.0 * _u), Color(fill_color.r, fill_color.g, fill_color.b, 0.35))
	panel.draw_rect(rect.grow(1.0 * _u), outline_color, false, 2.0 * _u)
	panel.draw_rect(rect, fill_color if is_moto_shown else rim_color, false, 1.5 * _u)
	var label: Color = text_color if is_moto_shown else Color(text_color.r, text_color.g, text_color.b, 0.45)
	_draw_text(rect, "Moto Perpetuo", label, SMALL_FONT_SIZE)


func _draw_text_plate(rect: Rect2, text: String, tint: Color) -> void:
	panel.draw_rect(rect, plate_color)
	panel.draw_rect(rect.grow(1.0 * _u), outline_color, false, 2.0 * _u)
	panel.draw_rect(rect, rim_color, false, 1.5 * _u)
	_draw_text(rect, text, tint, SMALL_FONT_SIZE)


func _draw_text(rect: Rect2, text: String, tint: Color, font_size: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var size: int = int(round(font_size * _u))
	var baseline: Vector2 = Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5 + size * 0.35)
	panel.draw_string(font, baseline + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, outline_color)
	panel.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, tint)


## The momentum gauge: an arc 0 .. gauge_max_speed, the part above run speed tinted turquoise, a tick per config
## speed, a needle at the horizontal speed and the speed as a number; a pulsing dot beside it while the charge button charges.
func _draw_gauge(centre: Vector2) -> void:
	var radius: float = GAUGE_RADIUS * _u
	var width: float = 4.0 * _u
	var limit: float = maxf(gauge_max_speed, 1.0)
	var start_ratio: float = clampf(_split_speed / limit, 0.0, 1.0)
	var split: float = GAUGE_START + GAUGE_SWEEP * start_ratio
	var end_angle: float = GAUGE_START + GAUGE_SWEEP
	panel.draw_arc(centre, radius, GAUGE_START, end_angle, 48, outline_color, width + 2.0 * _u, true)
	panel.draw_arc(centre, radius, GAUGE_START, split, 32, rim_color, width, true)
	panel.draw_arc(centre, radius, split, end_angle, 32, fill_color, width, true)
	for mark: float in gauge_marks:
		var angle: float = GAUGE_START + GAUGE_SWEEP * clampf(mark / limit, 0.0, 1.0)
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		panel.draw_line(centre + direction * (radius - 6.0 * _u), centre + direction * (radius + 5.0 * _u), outline_color, 3.0 * _u, true)
		panel.draw_line(centre + direction * (radius - 5.0 * _u), centre + direction * (radius + 4.0 * _u), text_color, 1.5 * _u, true)
	var needle_angle: float = GAUGE_START + GAUGE_SWEEP * clampf(speed_gauge_value / limit, 0.0, 1.0)
	var needle: Vector2 = Vector2(cos(needle_angle), sin(needle_angle))
	panel.draw_line(centre, centre + needle * (radius - 3.0 * _u), outline_color, 3.5 * _u, true)
	panel.draw_line(centre, centre + needle * (radius - 3.0 * _u), text_color, 2.0 * _u, true)
	panel.draw_circle(centre, 3.0 * _u, text_color)
	var label_rect: Rect2 = Rect2(centre + Vector2(-radius, radius * 0.45), Vector2(radius * 2.0, 14.0 * _u))
	_draw_text(label_rect, "%.1f m/s" % speed_gauge_value, text_color, SMALL_FONT_SIZE)
	if charging_shown:
		var pulse: float = 0.6 + 0.4 * sin(_time * TAU * 2.0)
		panel.draw_circle(centre + Vector2(radius + 12.0 * _u, 0.0), 5.0 * _u, Color(fill_color.r, fill_color.g, fill_color.b, pulse))
