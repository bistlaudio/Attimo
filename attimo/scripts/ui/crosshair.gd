class_name Crosshair
extends CanvasLayer
## Reticle and goggle HUD (D-13, D-01, D-02, CAM-02, CAM-04, CAM-06): thin white lines drawn in code, no image asset.
## The reticle is always on: outside aim mode only a small centre dot and a thin ring. While the aim button is held
## (hud_visible, driven by EventBus.aim_changed, gameplay never calls it) the goggle HUD adds the rim arcs with rivets at
## the left and right screen edges, the four gear notches, a charge arc while the big pulse charges, and a module frame
## at the bottom centre with the active module name.
## The reticle is cream with no target, turquoise on a valid target (a second outer ring when the target needs the big
## pulse) and dimmed with a diagonal stroke for an invalid or out-of-range target. It dims during the shot cooldown.
## The NearPrompt child is a cream "E" keycap over HandController.prompt_target (the nearest grabbable lever or crank in
## reach); it hides during near contact, out of range and when the point is behind the camera.
## It polls the hand_controller group (read only, it never drives the hand). The Reticle and NearPrompt children ignore
## the mouse, so the HUD never eats gameplay or F2 panel clicks.

## Radius of the centre dot in pixels.
@export var dot_radius: float = 2.0
## Radius of the thin ring in pixels.
@export var ring_radius: float = 8.0
## Line width of the ring in pixels.
@export var ring_width: float = 1.5
## Radius of the thin idle ring (no goggle HUD) in pixels.
@export var idle_ring_radius: float = 5.0
## Alpha of the idle reticle outside aim mode.
@export var idle_alpha: float = 0.6
## Normal colour (cream, the UI accent colour).
@export var color: Color = Color(0.96, 0.93, 0.85, 0.9)
## Lock colour (turquoise: valid target and charge arc).
@export var lock_color: Color = Color(0.25, 0.9, 0.85, 1.0)
## Dark outline colour under every line, so the HUD reads on bright sky.
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.55)

## True while the reticle shows a valid target (turquoise).
var locked: bool = false
## True while the goggle HUD is shown (aim held). The reticle itself is always visible.
var hud_visible: bool = false
## The Targeting.State shown by the reticle, the charge ratio of the big pulse and the active module name.
var state: int = Targeting.State.NONE
var charge: float = 0.0
var module_name: String = ""

const RING_POINTS: int = 48
const OUTLINE_EXTRA: float = 2.0
const NOTCH_LENGTH: float = 3.0
const NOTCH_ANGLES_DEG: Array[float] = [45.0, 135.0, 225.0, 315.0]
const OUTER_RING_GAP: float = 5.0
const CHARGE_RING_GAP: float = 9.0
const RIM_RADIUS_FACTOR: float = 0.62
const RIM_INSET: float = 28.0
const RIM_HALF_SPAN_DEG: float = 24.0
const RIVET_RADIUS: float = 2.5
const FRAME_SIZE: Vector2 = Vector2(160.0, 26.0)
const FRAME_BOTTOM_GAP: float = 24.0
const FRAME_FONT_SIZE: int = 14
const COOLDOWN_ALPHA: float = 0.5
const INVALID_ALPHA: float = 0.35
const PROMPT_LIFT: float = 0.35
const PROMPT_FONT_SIZE: int = 16

var _cooldown_dim: bool = false
var _prompt_style: StyleBoxFlat

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
	EventBus.aim_changed.connect(_on_aim_changed)


func _process(_delta: float) -> void:
	var hand: HandController = get_tree().get_first_node_in_group(&"hand_controller") as HandController
	_update_prompt(hand)
	if hand == null:
		return
	if not hud_visible:
		set_state(Targeting.State.NONE)
		set_charge(0.0)
		set_cooldown_dim(false)
		return
	if hand.targeting != null:
		set_state(hand.targeting.state)
	set_charge(hand.charge_ratio)
	set_cooldown_dim(hand.cooldown_left > 0.0)
	if hand.active_def != null:
		set_module_name(hand.active_def.display_name)


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


## Sets the module name shown in the frame at the bottom centre.
func set_module_name(text: String) -> void:
	if text == module_name:
		return
	module_name = text
	_reticle.queue_redraw()


func _on_aim_changed(active: bool) -> void:
	hud_visible = active
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
	var centre: Vector2 = size * 0.5
	var tint: Color = lock_color if locked else color
	if state == Targeting.State.INVALID:
		tint = Color(color.r, color.g, color.b, INVALID_ALPHA)
	if _cooldown_dim:
		tint.a *= COOLDOWN_ALPHA
	if not hud_visible:
		var idle: Color = Color(color.r, color.g, color.b, color.a * idle_alpha)
		_reticle.draw_circle(centre, dot_radius + OUTLINE_EXTRA * 0.5, outline_color)
		_reticle.draw_circle(centre, dot_radius, idle)
		_arc(centre, idle_ring_radius, 0.0, TAU, idle, ring_width * 0.7)
		return
	_draw_rim(size)
	_draw_ring(centre, tint)
	if charge > 0.0:
		_arc(centre, ring_radius + CHARGE_RING_GAP, -PI * 0.5, -PI * 0.5 + TAU * charge, lock_color, ring_width)
	_draw_module_frame(size)


func _draw_ring(centre: Vector2, tint: Color) -> void:
	_reticle.draw_circle(centre, dot_radius + OUTLINE_EXTRA * 0.5, outline_color)
	_reticle.draw_circle(centre, dot_radius, tint)
	_arc(centre, ring_radius, 0.0, TAU, tint, ring_width)
	for angle_deg: float in NOTCH_ANGLES_DEG:
		var direction: Vector2 = Vector2.from_angle(deg_to_rad(angle_deg))
		_line(centre + direction * ring_radius, centre + direction * (ring_radius + NOTCH_LENGTH), tint, ring_width)
	if state == Targeting.State.VALID_BIG:
		_arc(centre, ring_radius + OUTER_RING_GAP, 0.0, TAU, tint, ring_width * 0.7)
	if state == Targeting.State.INVALID:
		var reach: float = ring_radius + NOTCH_LENGTH
		_line(centre + Vector2(-reach, reach), centre + Vector2(reach, -reach), tint, ring_width)


## Two thin arcs hugging the left and right screen edges, with three rivets each.
func _draw_rim(size: Vector2) -> void:
	var radius: float = size.y * RIM_RADIUS_FACTOR
	var span: float = deg_to_rad(RIM_HALF_SPAN_DEG)
	var left_centre: Vector2 = Vector2(RIM_INSET - radius, size.y * 0.5)
	var right_centre: Vector2 = Vector2(size.x - RIM_INSET + radius, size.y * 0.5)
	_arc(left_centre, radius, -span, span, color, ring_width)
	_arc(right_centre, radius, PI - span, PI + span, color, ring_width)
	for fraction: float in [-0.8, 0.0, 0.8]:
		_rivet(left_centre + Vector2.from_angle(span * fraction) * radius)
		_rivet(right_centre + Vector2.from_angle(PI + span * fraction) * radius)


func _rivet(at: Vector2) -> void:
	_reticle.draw_circle(at, RIVET_RADIUS + OUTLINE_EXTRA * 0.5, outline_color)
	_reticle.draw_circle(at, RIVET_RADIUS, color)


func _draw_module_frame(size: Vector2) -> void:
	if module_name.is_empty():
		return
	var rect: Rect2 = Rect2(Vector2((size.x - FRAME_SIZE.x) * 0.5, size.y - FRAME_BOTTOM_GAP - FRAME_SIZE.y), FRAME_SIZE)
	_reticle.draw_rect(rect, outline_color, false, ring_width + OUTLINE_EXTRA)
	_reticle.draw_rect(rect, color, false, ring_width)
	var font: Font = ThemeDB.fallback_font
	var baseline: Vector2 = Vector2(rect.position.x, rect.position.y + FRAME_SIZE.y * 0.5 + FRAME_FONT_SIZE * 0.35)
	_reticle.draw_string_outline(font, baseline, module_name, HORIZONTAL_ALIGNMENT_CENTER, FRAME_SIZE.x, FRAME_FONT_SIZE, 3, outline_color)
	_reticle.draw_string(font, baseline, module_name, HORIZONTAL_ALIGNMENT_CENTER, FRAME_SIZE.x, FRAME_FONT_SIZE, color)


## A line with a dark outline under it.
func _line(from: Vector2, to: Vector2, tint: Color, width: float) -> void:
	_reticle.draw_line(from, to, outline_color, width + OUTLINE_EXTRA, true)
	_reticle.draw_line(from, to, tint, width, true)


## An arc with a dark outline under it.
func _arc(centre: Vector2, radius: float, start: float, end: float, tint: Color, width: float) -> void:
	_reticle.draw_arc(centre, radius, start, end, RING_POINTS, outline_color, width + OUTLINE_EXTRA, true)
	_reticle.draw_arc(centre, radius, start, end, RING_POINTS, tint, width, true)
