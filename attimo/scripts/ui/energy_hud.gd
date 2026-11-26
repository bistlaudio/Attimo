class_name EnergyHud
extends CanvasLayer
## Energy HUD (D-35, ENRG-06): top left, drawn in code in the crosshair's style (steel rim, dark plate, turquoise fill). The arm
## energy is a clock face with 12 step marks (every third one longer: the four arm cores of 3 steps), a turquoise pie fill up to the
## hour hand and a thin second hand for the progress of the timed income (hidden at 12). The hand rests on whole steps only: it klacks
## back on a spend and ticks forward on an income. Every EventBus.energy_refused shakes the clock, flashes it red and plays an empty
## klack (D-39). Below it: a Moto Perpetuo badge (lit while the arm is in Moto), the name plate of the active hand module and a
## momentum gauge (horizontal speed 0..24 m/s, marks at run speed, the dash exit speed and the Loader maximum, the part above run
## speed tinted turquoise) with a charge indicator while the charge button works. A slot to the right of the clock stays free for
## the health of Phase 6.
## It polls the player, its ArmEnergy and the HandController read only every frame, never writes gameplay state, ignores the mouse and
## sits below the crosshair (layer 10) and the debug overlays (100+). Everything is sized from the screen height (ui_reference_height).
## Animation uses TimeFx.unscaled, so it keeps its real-time speed during the Loader slow motion.

## Screen height in pixels at which the pixel sizes apply 1:1; the HUD scales with height / this.
@export var ui_reference_height: float = 720.0
## Turquoise of the energy fill (the energy colour of the arm cores).
@export var fill_color: Color = Color(0.25, 0.9, 0.85, 1.0)
## Steel rim colour of the clock and the plates.
@export var rim_color: Color = Color(0.62, 0.65, 0.7, 1.0)
## Dark plate colour behind the clock.
@export var plate_color: Color = Color(0.1, 0.11, 0.13, 0.72)
## Cream of the text and the marks (the UI accent colour).
@export var text_color: Color = Color(0.96, 0.93, 0.85, 0.9)
## Dark outline colour under every line, so the HUD reads on bright sky.
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.55)
## Top of the momentum gauge in m/s (the fastest mark, the Loader maximum 22, sits below it).
@export var gauge_max_speed: float = 24.0

const MARGIN: float = 16.0
const CLOCK_RADIUS: float = 30.0
const PLATE_PAD: float = 7.0
const CLOCK_STEPS: int = 12
## Seconds the hand needs to klack back on a spend (with an overshoot) and to tick forward on an income.
const KLACK_TIME: float = 0.12
const TICK_TIME: float = 0.15
## Refusal cue durations in seconds and the shake amplitude in reference pixels.
const SHAKE_TIME: float = 0.35
const FLASH_TIME: float = 0.25
const SHAKE_AMPLITUDE: float = 4.0
const REFUSAL_RED: Color = Color(1.0, 0.18, 0.15, 1.0)
const KLACK_HZ: float = 140.0
const KLACK_SECONDS: float = 0.07
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

var _steps: int = 0
var _second_progress: float = 0.0
var _angle: float = -PI * 0.5
var _anim_from: float = -PI * 0.5
var _anim_to: float = -PI * 0.5
var _anim_time: float = 1.0
var _anim_duration: float = TICK_TIME
var _anim_back: bool = false
var _shake_left: float = 0.0
var _flash_left: float = 0.0
var _klack_tone: PlaceholderTone
var _split_speed: float = 7.0
var _u: float = 1.0
var _time: float = 0.0


func _ready() -> void:
	layer = 9
	panel = $Panel as Control
	panel.draw.connect(_draw_panel)
	_klack_tone = PlaceholderTone.new()
	_klack_tone.name = &"KlackTone"
	add_child(_klack_tone)
	EventBus.energy_refused.connect(_on_energy_refused)


func _exit_tree() -> void:
	if EventBus.energy_refused.is_connected(_on_energy_refused):
		EventBus.energy_refused.disconnect(_on_energy_refused)


func _process(delta: float) -> void:
	var dt: float = TimeFx.unscaled(delta)
	_time += dt
	var changed: bool = _poll()
	if _step_animation(dt):
		changed = true
	if _shake_left > 0.0 or _flash_left > 0.0:
		_shake_left = maxf(_shake_left - dt, 0.0)
		_flash_left = maxf(_flash_left - dt, 0.0)
		changed = true
	if changed or charging_shown or is_moto_shown:
		panel.queue_redraw()


## The hour hand angle in radians for a whole number of steps: 12 o'clock at 0, clockwise (screen space, y down).
func hand_angle_for(steps: int) -> float:
	return -PI * 0.5 + TAU * float(clampi(steps, 0, CLOCK_STEPS)) / float(CLOCK_STEPS)


## The hour hand angle as drawn this frame (animating after a change, else exactly hand_angle_for(whole step)).
func displayed_angle() -> float:
	return _angle


## True once the hand has stopped on its whole step (no animation running).
func hand_at_rest() -> bool:
	return _anim_time >= 1.0


## True while the timed income runs (below 12); the second hand is hidden at a full clock.
func second_hand_visible() -> bool:
	return _steps < CLOCK_STEPS


## The second hand angle in radians: one turn is one timed step (ArmEnergy.tick_progress()).
func second_hand_angle() -> float:
	return -PI * 0.5 + TAU * _second_progress


## Seconds of the refusal cue (shake) left, 0.0 at rest.
func refusal_time_left() -> float:
	return _shake_left


## The current shake offset of the clock in reference pixels (a decaying sine), ZERO at rest.
func shake_offset() -> Vector2:
	if _shake_left <= 0.0:
		return Vector2.ZERO
	var progress: float = 1.0 - _shake_left / SHAKE_TIME
	return Vector2(sin(progress * TAU * 4.0) * SHAKE_AMPLITUDE * (1.0 - progress), 0.0)


## The red share 0..1 of the refusal flash.
func flash_amount() -> float:
	return clampf(_flash_left / FLASH_TIME, 0.0, 1.0)


## The turquoise fill colour as drawn now (lerped toward red during a refusal flash).
func current_fill_color() -> Color:
	return fill_color.lerp(REFUSAL_RED, flash_amount())


## A refusal restarts the one shake timer and the one flash timer (never stacks, T-05.1-26) and klacks.
func _on_energy_refused(_reason: StringName, _needed: int) -> void:
	_shake_left = SHAKE_TIME
	_flash_left = FLASH_TIME
	if _klack_tone != null:
		_klack_tone.beep(KLACK_HZ, KLACK_SECONDS)
	if panel != null:
		panel.queue_redraw()


## Starts a hand move toward `steps` from wherever the hand is now: a klack (back, overshoot) or a tick (forward).
func _set_target_steps(steps: int) -> void:
	_anim_from = _angle
	_anim_to = hand_angle_for(steps)
	_anim_back = steps < _steps
	_anim_duration = KLACK_TIME if _anim_back else TICK_TIME
	_anim_time = 0.0
	_steps = steps


## Advances the hand animation in real time. Returns true while it moved.
func _step_animation(dt: float) -> bool:
	if _anim_time >= 1.0:
		return false
	_anim_time = minf(_anim_time + dt / maxf(_anim_duration, 0.01), 1.0)
	if _anim_time >= 1.0:
		_angle = _anim_to
		return true
	var eased: float = _anim_time
	if _anim_back:
		# ease-out-back: a short overshoot past the new step, then it settles (the klack)
		var c: float = 1.70158
		var x: float = _anim_time - 1.0
		eased = 1.0 + (c + 1.0) * x * x * x + c * x * x
	else:
		eased = 1.0 - (1.0 - _anim_time) * (1.0 - _anim_time)
	_angle = lerpf(_anim_from, _anim_to, eased)
	return true


## The rectangle of the clock plate in panel pixels (at the current UI scale), without the shake offset.
func clock_rect() -> Rect2:
	var scale: float = _scale()
	var origin: Vector2 = Vector2(MARGIN, MARGIN) * scale
	var side: float = (CLOCK_RADIUS + PLATE_PAD) * 2.0 * scale
	return Rect2(origin, Vector2(side, side))


## The empty slot to the right of the clock where Phase 6 puts the health.
func health_slot_rect() -> Rect2:
	var clock: Rect2 = clock_rect()
	var scale: float = _scale()
	return Rect2(Vector2(clock.end.x + PLATE_GAP * scale, clock.position.y), HEALTH_SLOT_SIZE * scale)


func _scale() -> float:
	var height: float = ui_reference_height if panel == null else panel.size.y
	return clampf(height / maxf(ui_reference_height, 1.0), 0.75, 3.0)


## Reads the arm, the hand and the config (read only). Returns true when anything drawn changed.
func _poll() -> bool:
	var player: PlayerController = get_tree().get_first_node_in_group(&"player") as PlayerController
	var changed: bool = false
	var steps: int = 0
	var progress: float = 0.0
	if player != null and player.arm_energy != null:
		steps = clampi(player.arm_energy.value, 0, CLOCK_STEPS)
		progress = player.arm_energy.tick_progress()
	if steps != _steps:
		_set_target_steps(steps)
		changed = true
	if not is_equal_approx(progress, _second_progress):
		_second_progress = progress
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
	var plate: Rect2 = clock_rect()
	_draw_clock(plate)
	# The Moto badge and the module plate sit under the clock; the health slot to the right stays empty (Phase 6).
	var badge: Rect2 = Rect2(Vector2(plate.position.x, plate.end.y + PLATE_GAP * _u), BADGE_SIZE * _u)
	_draw_badge(badge)
	var module_rect: Rect2 = Rect2(Vector2(badge.end.x + PLATE_GAP * _u, badge.position.y), Vector2(112.0, BADGE_SIZE.y) * _u)
	_draw_text_plate(module_rect, module_name if module_name != "" else "-", text_color)
	_draw_gauge(Vector2(plate.position.x + (GAUGE_RADIUS + 6.0) * _u, badge.end.y + (GAUGE_RADIUS + 16.0) * _u))


## The clock: dark plate, turquoise pie from 12 o'clock up to the hour hand, 12 marks (every third longer), steel rim, hour hand and
## the thin second hand. A refusal shakes it and tints the fill and rim red.
func _draw_clock(plate: Rect2) -> void:
	var shake: Vector2 = shake_offset() * _u
	panel.draw_set_transform(shake)
	var centre: Vector2 = plate.get_center()
	var radius: float = CLOCK_RADIUS * _u
	var flash: float = flash_amount()
	var fill: Color = current_fill_color()
	var rim: Color = rim_color.lerp(REFUSAL_RED, flash)
	panel.draw_rect(plate, plate_color)
	panel.draw_circle(centre, radius, Color(0.04, 0.05, 0.06, 0.9))
	var start: float = -PI * 0.5
	var sweep: float = _angle - start
	if sweep > 0.01:
		var points: PackedVector2Array = PackedVector2Array([centre])
		var segments: int = maxi(int(ceil(sweep / TAU * 48.0)), 2)
		for i: int in segments + 1:
			var a: float = start + sweep * float(i) / float(segments)
			points.append(centre + Vector2(cos(a), sin(a)) * radius * 0.94)
		panel.draw_colored_polygon(points, Color(fill.r, fill.g, fill.b, 0.85))
	for i: int in CLOCK_STEPS:
		var a: float = start + TAU * float(i) / float(CLOCK_STEPS)
		var dir: Vector2 = Vector2(cos(a), sin(a))
		var long_mark: bool = i % 3 == 0
		var inner: float = radius * (0.68 if long_mark else 0.82)
		panel.draw_line(centre + dir * inner, centre + dir * radius, outline_color, 3.0 * _u, true)
		panel.draw_line(centre + dir * inner, centre + dir * radius, text_color, (2.0 if long_mark else 1.2) * _u, true)
	panel.draw_arc(centre, radius, 0.0, TAU, 48, outline_color, 3.5 * _u, true)
	panel.draw_arc(centre, radius, 0.0, TAU, 48, rim, 1.8 * _u, true)
	var hand_dir: Vector2 = Vector2(cos(_angle), sin(_angle))
	panel.draw_line(centre, centre + hand_dir * radius * 0.78, outline_color, 4.5 * _u, true)
	panel.draw_line(centre, centre + hand_dir * radius * 0.78, text_color, 2.8 * _u, true)
	if second_hand_visible():
		var sa: float = second_hand_angle()
		var sdir: Vector2 = Vector2(cos(sa), sin(sa))
		panel.draw_line(centre, centre + sdir * radius * 0.9, outline_color, 2.2 * _u, true)
		panel.draw_line(centre, centre + sdir * radius * 0.9, fill.lightened(0.3), 1.0 * _u, true)
	panel.draw_circle(centre, 3.0 * _u, text_color)
	panel.draw_set_transform(Vector2.ZERO)


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
