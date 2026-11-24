class_name Crosshair
extends CanvasLayer
## Reticle (D-01, D-15, CAM-04, CAM-06): lines drawn in code. The reticle is always on and always the same small look: a centre dot
## and a thin ring (the goggle HUD, lens overlay and module plate left with aim mode in phase 05). It is cream at idle alpha with
## no target, turquoise on a valid target (a second outer ring when the target needs the big pulse), dimmed with a diagonal stroke
## for an invalid or out-of-range target, and it dims during the shot cooldown. A charge arc around the ring shows the shot charge
## (plan 05-04 reshapes it). Everything is sized from the screen height (ui_reference_height), so it keeps its proportions at any
## resolution.
## While the Loader holds (D-14) a DOUBLE ring turns counter-clockwise around the reticle: the outer arc fills with the stored speed
## (stored / loader_max_speed), the inner arc with the hold time (hold / loader_hold_cap). It is turquoise with a full core and grey
## without one. It differs from the single, notched, clockwise shot arc in shape (two rings) and in rotation direction, so the two
## are never told apart by colour alone (colour-blind safe). Both advance in real time (TimeFx.unscaled).
## The NearPrompt child is a cream "E" keycap over HandController.prompt_target (the nearest grabbable lever or crank in
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
## Lock colour (turquoise: valid target and charge arc).
@export var lock_color: Color = Color(0.25, 0.9, 0.85, 1.0)
## Loader ring colour while the arm cannot pay the bonus (grey: the arm is empty). With a full core it uses lock_color.
@export var loader_empty_color: Color = Color(0.55, 0.57, 0.6, 1.0)
## Degrees per second the Loader double ring turns counter-clockwise (real time).
@export var loader_ring_speed_deg: float = 90.0
## Dark outline colour under every line, so the HUD reads on bright sky.
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.55)

## True while the reticle shows a valid target (turquoise).
var locked: bool = false
## The Targeting.State shown by the reticle and the charge ratio of the shot.
var state: int = Targeting.State.NONE
var charge: float = 0.0
## Loader double ring (D-14): shown while the Loader holds. The angle (radians) starts at the top and DECREASES (counter-clockwise on screen).
var loader_ring_visible: bool = false
var loader_ring_angle: float = -PI * 0.5
var loader_ring_stored: float = 0.0
var loader_ring_hold: float = 0.0
var loader_ring_tint: Color = Color(0.25, 0.9, 0.85, 1.0)

const RING_POINTS: int = 48
const OUTLINE_EXTRA: float = 2.0
const OUTER_RING_GAP: float = 4.0
const CHARGE_RING_GAP: float = 7.0
const LOADER_OUTER_GAP: float = 14.0
const LOADER_INNER_GAP: float = 9.0
## The smallest drawn arc of a Loader ring (radians), so the turning is visible at an empty ring.
const LOADER_MIN_SWEEP: float = 0.35
const COOLDOWN_ALPHA: float = 0.5
const INVALID_ALPHA: float = 0.35
const PROMPT_LIFT: float = 0.35
const PROMPT_FONT_SIZE: int = 16

var _cooldown_dim: bool = false
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
	if hand == null:
		return
	if hand.targeting != null:
		set_state(hand.targeting.state)
	set_charge(hand.charge_ratio)
	set_cooldown_dim(hand.cooldown_left > 0.0)


## Polls the player (read only): shows the Loader double ring while the Loader holds and turns it counter-clockwise in real time.
func _update_loader_ring(delta: float) -> void:
	var player: PlayerController = get_tree().get_first_node_in_group(&"player") as PlayerController
	var state: LoaderState = null if player == null else player.loader_state()
	var active: bool = player != null and state != null and player.loader_active()
	if not active:
		if loader_ring_visible:
			loader_ring_visible = false
			loader_ring_angle = -PI * 0.5
			_reticle.queue_redraw()
		return
	loader_ring_visible = true
	loader_ring_angle -= deg_to_rad(loader_ring_speed_deg) * TimeFx.unscaled(delta)
	loader_ring_stored = state.stored_ratio()
	loader_ring_hold = state.hold_ratio()
	loader_ring_tint = lock_color if state.bonus_ready() else loader_empty_color
	_reticle.queue_redraw()


## Sets the reticle state (a Targeting.State value). VALID and VALID_BIG are the turquoise lock.
func set_state(value: int) -> void:
	if value == state:
		return
	state = value
	locked = value == Targeting.State.VALID or value == Targeting.State.VALID_BIG
	_reticle.queue_redraw()


## Marks the ring as locked (turquoise) or unlocked without touching the state.
func set_locked(value: bool) -> void:
	locked = value
	_reticle.queue_redraw()


## Sets the fill of the charge arc, 0..1.
func set_charge(ratio: float) -> void:
	var clamped: float = clampf(ratio, 0.0, 1.0) if is_finite(ratio) else 0.0
	if is_equal_approx(clamped, charge):
		return
	charge = clamped
	_reticle.queue_redraw()


## Dims the reticle during the shot cooldown.
func set_cooldown_dim(dim: bool) -> void:
	if dim == _cooldown_dim:
		return
	_cooldown_dim = dim
	_reticle.queue_redraw()


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
	var tint: Color = lock_color if locked else Color(color.r, color.g, color.b, color.a * idle_alpha)
	if state == Targeting.State.INVALID:
		tint = Color(color.r, color.g, color.b, INVALID_ALPHA)
	if _cooldown_dim:
		tint.a *= COOLDOWN_ALPHA
	var radius: float = ring_radius * _u
	_reticle.draw_circle(centre, (dot_radius + OUTLINE_EXTRA * 0.5) * _u, outline_color)
	_reticle.draw_circle(centre, dot_radius * _u, tint)
	_arc(centre, radius, 0.0, TAU, tint, ring_width * _u)
	if state == Targeting.State.VALID_BIG:
		_arc(centre, radius + OUTER_RING_GAP * _u, 0.0, TAU, tint, ring_width * 0.7 * _u)
	if state == Targeting.State.INVALID:
		var reach: float = radius + 3.0 * _u
		_line(centre + Vector2(-reach, reach), centre + Vector2(reach, -reach), tint, ring_width * _u)
	if charge > 0.0:
		_arc(centre, radius + CHARGE_RING_GAP * _u, -PI * 0.5, -PI * 0.5 + TAU * charge, lock_color, ring_width * 1.3 * _u)
	if loader_ring_visible:
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


## A line with a dark outline under it.
func _line(from: Vector2, to: Vector2, tint: Color, width: float) -> void:
	_reticle.draw_line(from, to, outline_color, width + OUTLINE_EXTRA, true)
	_reticle.draw_line(from, to, tint, width, true)


## An arc with a dark outline under it.
func _arc(centre: Vector2, radius: float, start: float, end: float, tint: Color, width: float) -> void:
	_reticle.draw_arc(centre, radius, start, end, RING_POINTS, outline_color, width + OUTLINE_EXTRA, true)
	_reticle.draw_arc(centre, radius, start, end, RING_POINTS, tint, width, true)
