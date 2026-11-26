class_name Crosshair
extends CanvasLayer
## Reticle (D-01, D-15, CAM-04, CAM-06, D-45): lines drawn in code. The reticle is always on and always the same small look: a centre dot
## and a thin ring in cream at idle alpha. The shot is gone (D-45), so there is no target state, no charge ring and no cooldown dim. Everything is sized from the screen height (ui_reference_height), so it keeps its proportions at any resolution.
## While the Loader holds (D-14) a DOUBLE ring turns counter-clockwise around the reticle: the outer arc fills with the stored speed
## (stored / loader_max_speed), the inner arc with the hold time (hold / loader_hold_cap). It is turquoise with a full core and grey
## without one. It advances in real time (TimeFx.unscaled).
## Phase 05.1 (D-01, D-05, D-26): the Loader ring reads LoaderState.source(). ARM keeps the double ring above. A CAGE hold (slingshot)
## draws a brass PRESSURE GAUGE instead: a still dial with tick marks and a needle at the stored speed (stored_ratio, the outer ring's
## value), plus a thin inner arc for the hold time; brass (LoaderLook.BRASS_COLOR) whatever the core, because the cage spends no
## energy and turquoise means energy. A FIXED hold (steam cannon, 0.2 s, no input) shows no ring at all. loader_ring_style() tells the
## shapes apart for the tests (double / gauge).
## The NearPrompt child is a cream "E" keycap over HandController.prompt_target (the nearest grabbable lever in
## reach); it hides during near contact, out of range and when the point is behind the camera.
## It polls the hand_controller group (read only, it never drives the hand). The Reticle and NearPrompt children ignore
## the mouse, so the HUD never eats gameplay or F2 panel clicks.

## Radius of the centre dot in pixels.
@export var dot_radius: float = 2.0
## Radius of the thin ring in pixels.
@export var ring_radius: float = 5.0
## Line width of the ring in pixels.
@export var ring_width: float = 1.05
## Screen height in pixels at which the pixel sizes apply 1:1; the HUD scales with height / this.
@export var ui_reference_height: float = 720.0
## Alpha factor of the reticle with no target.
@export var idle_alpha: float = 0.6
## Normal colour (cream, the UI accent colour).
@export var color: Color = Color(0.96, 0.93, 0.85, 0.9)
## Turquoise of the Loader ring with a full core.
@export var lock_color: Color = Color(0.25, 0.9, 0.85, 1.0)
## Degrees per second the Loader double ring turns counter-clockwise (real time).
@export var loader_ring_speed_deg: float = 90.0
## Dark outline colour under every line, so the HUD reads on bright sky.
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.55)

## Loader double ring (D-14): shown while the Loader holds. The angle (radians) starts at the top and DECREASES (counter-clockwise on screen).
var loader_ring_visible: bool = false
var loader_ring_angle: float = -PI * 0.5
var loader_ring_stored: float = 0.0
var loader_ring_hold: float = 0.0
var loader_ring_tint: Color = Color(0.25, 0.9, 0.85, 1.0)
## True while the ring on screen is the cage's pressure gauge; loader_gauge_needle is its needle, 0 .. 1 (the stored ratio).
var loader_ring_gauge: bool = false
var loader_gauge_needle: float = 0.0
## Ring styles of the Loader differ by shape, not by colour alone (colour-blind safe, D-14): the arm's double ring and the cage's pressure
## gauge (loader_ring_style() returns the one on screen).
const LOADER_RING_DOUBLE: StringName = &"double"
const LOADER_RING_GAUGE: StringName = &"gauge"
## Pressure gauge: the dial spans GAUGE_SWEEP radians clockwise from GAUGE_START (lower left, through the top, to lower right), with
## GAUGE_TICKS tick marks; the needle runs from the reticle ring out past the dial.
const GAUGE_START: float = PI * 0.75
const GAUGE_SWEEP: float = PI * 1.5
const GAUGE_TICKS: int = 7
const GAUGE_TICK_LENGTH: float = 3.0
const RING_POINTS: int = 48
const OUTLINE_EXTRA: float = 2.0
const LOADER_OUTER_GAP: float = 14.0
const LOADER_INNER_GAP: float = 9.0
## The smallest drawn arc of a Loader ring (radians), so the turning is visible at an empty ring.
const LOADER_MIN_SWEEP: float = 0.35
const PROMPT_LIFT: float = 0.35
const PROMPT_FONT_SIZE: int = 16

var _prompt_style: StyleBoxFlat
var _u: float = 1.0

@onready var _reticle: Control = $Reticle
@onready var _prompt: Control = $NearPrompt


func _ready() -> void:
	visible = true
	_prompt_style = StyleBoxFlat.new()
	_prompt_style.bg_color = color
	_prompt_style.border_color = outline_color
	_prompt_style.set_border_width_all(2)
	_prompt_style.set_corner_radius_all(5)
	_prompt.visible = false
	_prompt.draw.connect(_draw_prompt)
	_reticle.draw.connect(_draw_reticle)


func _process(delta: float) -> void:
	_update_loader_ring(delta)
	var hand: HandController = get_tree().get_first_node_in_group(&"hand_controller") as HandController
	_update_prompt(hand)


## Polls the player (read only): shows the Loader double ring while the Loader holds and turns it counter-clockwise in real time.
func _update_loader_ring(delta: float) -> void:
	var player: PlayerController = get_tree().get_first_node_in_group(&"player") as PlayerController
	var state: LoaderState = null if player == null else player.loader_state()
	# D-05: the cannon's FIXED hold has no input, so it shows no ring.
	var active: bool = player != null and state != null and player.loader_active() and state.source() != LoaderProfile.Source.FIXED
	if not active:
		if loader_ring_visible:
			loader_ring_visible = false
			loader_ring_gauge = false
			loader_ring_angle = -PI * 0.5
			_reticle.queue_redraw()
		return
	loader_ring_visible = true
	loader_ring_stored = state.stored_ratio()
	loader_ring_hold = state.hold_ratio()
	loader_ring_gauge = state.source() == LoaderProfile.Source.CAGE
	if loader_ring_gauge:
		# D-01 / D-26: a still brass gauge, never turquoise and never the grey empty-arm colour.
		loader_gauge_needle = loader_ring_stored
		loader_ring_tint = LoaderLook.BRASS_COLOR
	else:
		loader_ring_angle -= deg_to_rad(loader_ring_speed_deg) * TimeFx.unscaled(delta)
		loader_ring_tint = lock_color
	_reticle.queue_redraw()


## The style of the Loader ring on screen: LOADER_RING_GAUGE for a cage hold, LOADER_RING_DOUBLE for the arm, &"" with no ring.
func loader_ring_style() -> StringName:
	if not loader_ring_visible:
		return &""
	return LOADER_RING_GAUGE if loader_ring_gauge else LOADER_RING_DOUBLE


## Places the E keycap over HandController.prompt_target, hidden without a finite point in front of the camera.
func _update_prompt(hand: HandController) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var point: Vector3 = Vector3(INF, INF, INF) if hand == null else hand.prompt_point()
	if camera == null or not point.is_finite() or camera.is_position_behind(point):
		_prompt.visible = false
		return
	_prompt.position = camera.unproject_position(point + Vector3.UP * PROMPT_LIFT) - _prompt.size * 0.5
	_prompt.visible = true


func _draw_prompt() -> void:
	_prompt.draw_style_box(_prompt_style, Rect2(Vector2.ZERO, _prompt.size))
	var font: Font = ThemeDB.fallback_font
	var baseline: Vector2 = Vector2(0.0, _prompt.size.y * 0.5 + PROMPT_FONT_SIZE * 0.35)
	_prompt.draw_string(font, baseline, "E", HORIZONTAL_ALIGNMENT_CENTER, _prompt.size.x, PROMPT_FONT_SIZE, Color(0.12, 0.1, 0.08, 1.0))


func _draw_reticle() -> void:
	var size: Vector2 = _reticle.size
	_u = clampf(size.y / maxf(ui_reference_height, 1.0), 0.75, 3.0)
	var centre: Vector2 = size * 0.5
	var tint: Color = Color(color.r, color.g, color.b, color.a * idle_alpha)
	var radius: float = ring_radius * _u
	_reticle.draw_circle(centre, (dot_radius + OUTLINE_EXTRA * 0.5) * _u, outline_color)
	_reticle.draw_circle(centre, dot_radius * _u, tint)
	_arc(centre, radius, 0.0, TAU, tint, ring_width * _u)
	if loader_ring_visible:
		if loader_ring_gauge:
			_draw_gauge(centre, radius)
		else:
			_draw_loader_ring(centre, radius)


## The Loader double ring: a dim track and a filling arc per ring, the arcs rotate counter-clockwise (the angle decreases).
func _draw_loader_ring(centre: Vector2, radius: float) -> void:
	var outer: float = radius + LOADER_OUTER_GAP * _u
	var inner: float = radius + LOADER_INNER_GAP * _u
	var track: Color = Color(loader_ring_tint.r, loader_ring_tint.g, loader_ring_tint.b, 0.25)
	_arc(centre, outer, 0.0, TAU, track, ring_width * _u)
	_arc(centre, inner, 0.0, TAU, track, ring_width * _u)
	var outer_sweep: float = maxf(TAU * loader_ring_stored, LOADER_MIN_SWEEP)
	var inner_sweep: float = maxf(TAU * loader_ring_hold, LOADER_MIN_SWEEP)
	_arc(centre, outer, loader_ring_angle, loader_ring_angle + outer_sweep, loader_ring_tint, ring_width * 1.6 * _u)
	_arc(centre, inner, loader_ring_angle, loader_ring_angle + inner_sweep, loader_ring_tint, ring_width * 1.2 * _u)


## The cage's pressure gauge (D-01): a brass dial over GAUGE_SWEEP with tick marks, a needle at the stored speed and a thin inner arc
## that fills with the hold time. It does not turn: a gauge reads, the arm ring spins.
func _draw_gauge(centre: Vector2, radius: float) -> void:
	var dial: float = radius + LOADER_OUTER_GAP * _u
	var inner: float = radius + LOADER_INNER_GAP * _u
	var track: Color = Color(loader_ring_tint.r, loader_ring_tint.g, loader_ring_tint.b, 0.35)
	_arc(centre, dial, GAUGE_START, GAUGE_START + GAUGE_SWEEP, loader_ring_tint, ring_width * 1.6 * _u)
	for i: int in GAUGE_TICKS:
		var tick_angle: float = GAUGE_START + GAUGE_SWEEP * float(i) / float(GAUGE_TICKS - 1)
		var tick: Vector2 = Vector2(cos(tick_angle), sin(tick_angle))
		_line(centre + tick * dial, centre + tick * (dial + GAUGE_TICK_LENGTH * _u), loader_ring_tint, ring_width * _u)
	_arc(centre, inner, GAUGE_START, GAUGE_START + GAUGE_SWEEP, track, ring_width * _u)
	_arc(centre, inner, GAUGE_START, GAUGE_START + maxf(GAUGE_SWEEP * loader_ring_hold, LOADER_MIN_SWEEP), loader_ring_tint, ring_width * 1.2 * _u)
	var needle_angle: float = GAUGE_START + GAUGE_SWEEP * clampf(loader_gauge_needle, 0.0, 1.0)
	var needle: Vector2 = Vector2(cos(needle_angle), sin(needle_angle))
	_line(centre + needle * (radius + 2.0 * _u), centre + needle * (dial + GAUGE_TICK_LENGTH * _u), loader_ring_tint, ring_width * 1.4 * _u)


## A line with a dark outline under it.
func _line(from: Vector2, to: Vector2, tint: Color, width: float) -> void:
	_reticle.draw_line(from, to, outline_color, width + OUTLINE_EXTRA, true)
	_reticle.draw_line(from, to, tint, width, true)


## An arc with a dark outline under it.
func _arc(centre: Vector2, radius: float, start: float, end: float, tint: Color, width: float) -> void:
	_reticle.draw_arc(centre, radius, start, end, RING_POINTS, outline_color, width + OUTLINE_EXTRA, true)
	_reticle.draw_arc(centre, radius, start, end, RING_POINTS, tint, width, true)
