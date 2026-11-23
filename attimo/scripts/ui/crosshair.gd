class_name Crosshair
extends CanvasLayer
## Reticle and goggle HUD (D-13, D-01, D-02, CAM-02, CAM-04, CAM-06): lines drawn in code plus one lens shader.
## The reticle is always on: outside aim mode only a small centre dot and a thin ring. While the aim button is held
## (hud_visible, driven by EventBus.aim_changed, gameplay never calls it) the goggle HUD shows a full-screen lens overlay
## (goggle_lens.gdshader: two round lenses, dark vignette outside, thick brass rim with rivets) that snaps in with a
## small overshoot and a HUD jolt, a big reticle ring with notches and a slowly rotating gear ring (faster while the big
## pulse charges), a charge arc, and a brass module plate at the bottom centre with the active module name.
## Everything is sized from the screen height (ui_reference_height), so it keeps its proportions at any resolution.
## The camera jolt on aim press lives in CameraRig (goggle snap), not here.
## The reticle is cream with no target, turquoise on a valid target (a second outer ring when the target needs the big
## pulse) and dimmed with a diagonal stroke for an invalid or out-of-range target. It dims during the shot cooldown.
## The NearPrompt child is a cream "E" keycap over HandController.prompt_target (the nearest grabbable lever or crank in
## reach); it hides during near contact, out of range and when the point is behind the camera.
## It polls the hand_controller group (read only, it never drives the hand). The Reticle and NearPrompt children ignore
## the mouse, so the HUD never eats gameplay or F2 panel clicks.

## Radius of the centre dot in pixels.
@export var dot_radius: float = 2.0
## Radius of the thin ring in pixels.
@export var ring_radius: float = 18.0
## Line width of the ring in pixels.
@export var ring_width: float = 2.5
## Length of the four notches on the ring in pixels.
@export var notch_length: float = 7.0
## Screen height in pixels at which the pixel sizes below apply 1:1; the HUD scales with height / this.
@export var ui_reference_height: float = 720.0
@export_group("Gear ring")
## Gap between the reticle ring and the gear ring in pixels.
@export var gear_gap: float = 9.0
## Length of the gear teeth in pixels.
@export var gear_tooth_length: float = 6.0
## Number of gear teeth.
@export var gear_teeth: int = 16
## Idle rotation of the gear ring in degrees per second.
@export var gear_speed_deg: float = 25.0
## Extra rotation speed at full charge in degrees per second.
@export var gear_charge_speed_deg: float = 420.0
@export_group("Lens")
## Seconds the lens overlay takes to snap in (overshoot included) and to snap out.
@export var lens_open_time: float = 0.18
@export var lens_close_time: float = 0.1
## Overlay scale at the start of the snap-in (1.0 = no zoom).
@export var lens_intro_scale: float = 1.15
## HUD jolt on aim press: amplitude in pixels and duration in seconds.
@export var hud_jolt_pixels: float = 9.0
@export var hud_jolt_time: float = 0.2
@export_group("Module plate")
## Size of the brass module plate in pixels, its distance from the bottom edge and the font size.
@export var plate_size: Vector2 = Vector2(280.0, 44.0)
@export var plate_bottom_gap: float = 36.0
@export var plate_font_size: int = 22
@export var plate_fill: Color = Color(0.3, 0.21, 0.09, 0.92)
@export var plate_border: Color = Color(0.78, 0.58, 0.25, 1.0)
@export_group("")
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
const NOTCH_ANGLES_DEG: Array[float] = [45.0, 135.0, 225.0, 315.0]
const OUTER_RING_GAP: float = 5.0
const CHARGE_RING_GAP: float = 8.0
const RIVET_RADIUS: float = 3.5
const LENS_SHADER: String = "res://scripts/ui/goggle_lens.gdshader"
const IDLE_RING_WIDTH: float = 1.05
const BACK_OVERSHOOT: float = 1.70158
const COOLDOWN_ALPHA: float = 0.5
const INVALID_ALPHA: float = 0.35
const PROMPT_LIFT: float = 0.35
const PROMPT_FONT_SIZE: int = 16

var _cooldown_dim: bool = false
var _prompt_style: StyleBoxFlat
var _lens: ColorRect
var _lens_material: ShaderMaterial
var _open_t: float = 0.0
var _gear_angle: float = 0.0
var _jolt_left: float = 0.0
var _jolt_clock: float = 0.0
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
	_build_lens()
	EventBus.aim_changed.connect(_on_aim_changed)


func _process(delta: float) -> void:
	_update_lens(delta)
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
	if active:
		_jolt_left = hud_jolt_time
		_jolt_clock = 0.0
	_reticle.queue_redraw()


## The lens overlay is a full-screen ColorRect with the goggle shader, behind the reticle, ignoring the mouse.
func _build_lens() -> void:
	_lens = ColorRect.new()
	_lens.name = "Lens"
	_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lens.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lens.visible = false
	_lens_material = ShaderMaterial.new()
	_lens_material.shader = load(LENS_SHADER) as Shader
	_lens.material = _lens_material
	add_child(_lens)
	move_child(_lens, 0)


## Snap-in (back ease, small overshoot) and snap-out of the lens, the HUD jolt and the gear rotation.
func _update_lens(delta: float) -> void:
	var goal: float = 1.0 if hud_visible else 0.0
	var time: float = lens_open_time if hud_visible else lens_close_time
	_open_t = move_toward(_open_t, goal, delta / maxf(time, 0.01))
	var eased: float = _open_t * _open_t
	if hud_visible:
		var shifted: float = _open_t - 1.0
		eased = 1.0 + (BACK_OVERSHOOT + 1.0) * shifted * shifted * shifted + BACK_OVERSHOOT * shifted * shifted
	var jolt: Vector2 = Vector2.ZERO
	if _jolt_left > 0.0:
		_jolt_left = maxf(_jolt_left - delta, 0.0)
		_jolt_clock += delta
		var decay: float = _jolt_left / maxf(hud_jolt_time, 0.01)
		jolt = Vector2(sin(_jolt_clock * 71.0), cos(_jolt_clock * 93.0)) * hud_jolt_pixels * decay * decay
	_reticle.position = jolt
	if _lens == null:
		return
	_lens.visible = _open_t > 0.0
	if not _lens.visible or _lens.size.y <= 0.0:
		return
	_lens_material.set_shader_parameter(&"open", eased)
	_lens_material.set_shader_parameter(&"aspect", _lens.size.x / _lens.size.y)
	_lens_material.set_shader_parameter(&"shake", jolt / _lens.size.y)
	_lens_material.set_shader_parameter(&"intro_scale", lens_intro_scale)
	if hud_visible:
		_gear_angle += deg_to_rad(gear_speed_deg + gear_charge_speed_deg * charge * charge) * delta
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
	var tint: Color = lock_color if locked else color
	if state == Targeting.State.INVALID:
		tint = Color(color.r, color.g, color.b, INVALID_ALPHA)
	if _cooldown_dim:
		tint.a *= COOLDOWN_ALPHA
	if not hud_visible:
		var idle: Color = Color(color.r, color.g, color.b, color.a * idle_alpha)
		_reticle.draw_circle(centre, dot_radius + OUTLINE_EXTRA * 0.5, outline_color)
		_reticle.draw_circle(centre, dot_radius, idle)
		_arc(centre, idle_ring_radius, 0.0, TAU, idle, IDLE_RING_WIDTH)
		return
	_draw_ring(centre, tint)
	_draw_gear(centre, tint)
	if charge > 0.0:
		var charge_radius: float = (ring_radius + gear_gap + gear_tooth_length + CHARGE_RING_GAP) * _u
		_arc(centre, charge_radius, -PI * 0.5, -PI * 0.5 + TAU * charge, lock_color, ring_width * _u)
	_draw_module_plate(size)


func _draw_ring(centre: Vector2, tint: Color) -> void:
	var radius: float = ring_radius * _u
	var width: float = ring_width * _u
	_reticle.draw_circle(centre, (dot_radius * 1.5 + OUTLINE_EXTRA * 0.5) * _u, outline_color)
	_reticle.draw_circle(centre, dot_radius * 1.5 * _u, tint)
	_arc(centre, radius, 0.0, TAU, tint, width)
	for angle_deg: float in NOTCH_ANGLES_DEG:
		var direction: Vector2 = Vector2.from_angle(deg_to_rad(angle_deg))
		_line(centre + direction * radius, centre + direction * (radius + notch_length * _u), tint, width)
	if state == Targeting.State.VALID_BIG:
		_arc(centre, radius + OUTER_RING_GAP * _u, 0.0, TAU, tint, width * 0.7)
	if state == Targeting.State.INVALID:
		var reach: float = radius + notch_length * _u
		_line(centre + Vector2(-reach, reach), centre + Vector2(reach, -reach), tint, width)


## Gear ring around the reticle: a thin circle with short radial teeth that turns (faster while charging).
func _draw_gear(centre: Vector2, tint: Color) -> void:
	var radius: float = (ring_radius + gear_gap) * _u
	var tooth: float = gear_tooth_length * _u
	_arc(centre, radius, 0.0, TAU, tint, ring_width * 0.6 * _u)
	var count: int = maxi(gear_teeth, 1)
	for i: int in count:
		var direction: Vector2 = Vector2.from_angle(_gear_angle + TAU * float(i) / float(count))
		_line(centre + direction * radius, centre + direction * (radius + tooth), tint, ring_width * 1.4 * _u)


func _rivet(at: Vector2) -> void:
	_reticle.draw_circle(at, (RIVET_RADIUS + OUTLINE_EXTRA * 0.5) * _u, outline_color)
	_reticle.draw_circle(at, RIVET_RADIUS * _u, plate_border)


## Brass plate at the bottom centre with the active module name.
func _draw_module_plate(size: Vector2) -> void:
	if module_name.is_empty():
		return
	var plate: Vector2 = plate_size * _u
	var rect: Rect2 = Rect2(Vector2((size.x - plate.x) * 0.5, size.y - plate_bottom_gap * _u - plate.y), plate)
	_reticle.draw_rect(rect.grow(2.0 * _u), outline_color, true)
	_reticle.draw_rect(rect, plate_fill, true)
	_reticle.draw_rect(rect, plate_border, false, 3.0 * _u)
	_reticle.draw_rect(rect.grow(-6.0 * _u), plate_border.darkened(0.45), false, 1.0 * _u)
	_rivet(rect.position + Vector2(plate.y * 0.5, plate.y * 0.5))
	_rivet(rect.position + Vector2(plate.x - plate.y * 0.5, plate.y * 0.5))
	var font: Font = ThemeDB.fallback_font
	var font_size: int = int(plate_font_size * _u)
	var baseline: Vector2 = Vector2(rect.position.x, rect.position.y + plate.y * 0.5 + font_size * 0.35)
	_reticle.draw_string_outline(font, baseline, module_name, HORIZONTAL_ALIGNMENT_CENTER, plate.x, font_size, 4, outline_color)
	_reticle.draw_string(font, baseline, module_name, HORIZONTAL_ALIGNMENT_CENTER, plate.x, font_size, color)


## A line with a dark outline under it.
func _line(from: Vector2, to: Vector2, tint: Color, width: float) -> void:
	_reticle.draw_line(from, to, outline_color, width + OUTLINE_EXTRA, true)
	_reticle.draw_line(from, to, tint, width, true)


## An arc with a dark outline under it.
func _arc(centre: Vector2, radius: float, start: float, end: float, tint: Color, width: float) -> void:
	_reticle.draw_arc(centre, radius, start, end, RING_POINTS, outline_color, width + OUTLINE_EXTRA, true)
	_reticle.draw_arc(centre, radius, start, end, RING_POINTS, tint, width, true)
