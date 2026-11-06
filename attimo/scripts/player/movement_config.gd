class_name MovementConfig
extends Resource
## The one tunable movement resource (MOVE-10, D-23). Every movement number lives here.
## Eight groups, 34 live sliders in the F2 tuning panel: Run, Air, Gravity, Jump chain, Dash,
## Long jump (dash hop), Timing windows, Floor and platforms. Gravity is set directly
## (rise_gravity, fall_multiplier); jump speeds are derived from the heights, so editing a
## height never changes the fall feel. Every divisor field has a strictly positive minimum (T-02-02).

@export_group("Run")
## The one run speed in m/s; raise it for a faster base pace (there is no separate fast run).
@export_range(1.0, 20.0, 0.1) var run_speed: float = 8.5
## Ground acceleration toward run speed in m/s^2; raise it for a snappier run-up.
@export_range(5.0, 200.0, 1.0) var ground_accel: float = 70.0
## Braking when input is released in m/s^2; raise it for a shorter slide to a stop.
@export_range(5.0, 200.0, 1.0) var ground_decel: float = 55.0
## Braking when input opposes the current velocity in m/s^2; raise it for a shorter skid.
@export_range(5.0, 300.0, 1.0) var turn_decel: float = 90.0
## Facing turn rate in 1/s (VisualRoot yaw lerp); raise it for a character that turns faster.
@export_range(1.0, 40.0, 0.5) var turn_rate: float = 14.0

@export_group("Air")
## Air acceleration toward the air speed cap in m/s^2; raise it for stronger steering in the air.
@export_range(5.0, 200.0, 1.0) var air_accel: float = 45.0
## Air braking without input in m/s^2; raise it to lose speed in the air (0 keeps momentum).
@export_range(0.0, 200.0, 1.0) var air_decel: float = 0.0

@export_group("Gravity")
## Gravity while rising and on the ground in m/s^2; raise it for a snappier rise (jump heights stay as set).
@export_range(10.0, 80.0, 1.0) var rise_gravity: float = 34.0
## Gravity multiplier while falling (1.0 = as light as the rise); raise it for a heavier fall.
@export_range(1.0, 3.0, 0.05) var fall_multiplier: float = 1.3
## Maximum fall speed in m/s; raise it for longer, faster falls.
@export_range(5.0, 80.0, 1.0) var terminal_speed: float = 40.0

@export_group("Jump chain")
## Full-hold height of Jump 1 in m; raise it for a higher first jump.
@export_range(0.5, 6.0, 0.05) var jump_height: float = 2.0
## Full-hold height of Jump 2 of the ground chain in m; raise it for a bigger second hop.
@export_range(0.5, 6.0, 0.05) var jump_2_height: float = 2.6
## Full-hold height of Jump 3 (the salto, the highest ground jump) in m; raise it for a taller salto.
@export_range(0.5, 6.0, 0.05) var jump_3_height: float = 3.4
## Tap height in m (release cuts the rise to this height); raise it for jumps that cut less.
@export_range(0.1, 3.0, 0.05) var jump_min_height: float = 0.8

@export_group("Dash")
## Dash speed in m/s; raise it for a longer, harder dash.
@export_range(5.0, 60.0, 0.5) var dash_speed: float = 22.0
## Dash duration in seconds; raise it for a longer dash.
@export_range(0.05, 1.0, 0.01) var dash_time: float = 0.18
## Seconds before the next dash may start; raise it to dash less often.
@export_range(0.0, 2.0, 0.05) var dash_cooldown: float = 0.4
## Horizontal speed leaving a dash in m/s (never below run speed); raise it to keep more speed after the dash.
@export_range(5.0, 22.0, 0.5) var dash_exit_speed: float = 12.0
## Gravity scale during an air dash; raise it for a dash that sinks (0 = flat dash).
@export_range(0.0, 1.0, 0.05) var air_dash_gravity_scale: float = 0.0

@export_group("Long jump (dash hop)")
## Long jump height at stage 1 (the first dash hop) in m; raise it for a higher first hop.
@export_range(0.5, 6.0, 0.05) var long_jump_height_1: float = 2.0
## Long jump height at stage 2 in m; raise it for a higher second hop.
@export_range(0.5, 6.0, 0.05) var long_jump_height_2: float = 2.5
## Long jump height at stage 3 (top of the stack) in m; raise it for a higher third hop.
@export_range(0.5, 6.0, 0.05) var long_jump_height_3: float = 3.0
## Take-off speed of the stage 1 long jump in m/s; raise it for a longer first hop.
@export_range(5.0, 22.0, 0.5) var long_jump_speed_1: float = 14.0
## Take-off speed of the stage 2 long jump in m/s; raise it for a longer second hop.
@export_range(5.0, 22.0, 0.5) var long_jump_speed_2: float = 16.0
## Take-off speed of the stage 3 long jump in m/s; 22 m/s is the speed the camera and tunnelling tests cover, do not raise it without re-running them.
@export_range(5.0, 22.0, 0.5) var long_jump_speed_3: float = 18.0

@export_group("Timing windows")
## Seconds after leaving a ledge in which a ground jump is still allowed; raise it for a more forgiving ledge.
@export_range(0.0, 0.3, 0.01) var coyote_time: float = 0.1
## Seconds a jump press is remembered before landing; raise it for an easier early press.
@export_range(0.0, 0.3, 0.01) var jump_buffer_time: float = 0.12
## Seconds after touchdown in which the next ground jump advances the chain or the next ground dash keeps the long-jump stack; raise it for an easier rhythm.
@export_range(0.05, 1.5, 0.01) var landing_window: float = 0.35
## Seconds after a dash in which a jump still counts as a long jump; raise it for a more forgiving dash hop.
@export_range(0.0, 0.5, 0.01) var dash_jump_grace: float = 0.15
## Ground speed under which the chain and the long-jump stack reset in m/s; raise it so slow walking breaks the combo.
@export_range(0.0, 5.0, 0.1) var combo_reset_speed: float = 0.5

@export_group("Floor and platforms")
## Lower bound of the speed-scaled floor snap length in m (D-13 band, A35); raise it for a stickier floor.
@export_range(0.3, 0.5, 0.01) var snap_min: float = 0.3
## Upper bound of the speed-scaled floor snap length in m (D-13 band, A35); raise it for a stickier floor at speed.
@export_range(0.3, 0.5, 0.01) var snap_max: float = 0.5
## Steepest walkable floor angle in degrees; raise it to walk up steeper slopes.
@export_range(30.0, 60.0, 1.0) var floor_max_angle_deg: float = 50.0
## Share of the platform's horizontal velocity that carries over when leaving it; raise it for a bigger launch off moving platforms.
@export_range(0.0, 1.5, 0.05) var platform_carry: float = 1.0


## Gravity while falling in m/s^2: rise_gravity * fall_multiplier.
func fall_gravity() -> float:
	return rise_gravity * fall_multiplier


## Take-off speed in m/s that reaches `height` under rise_gravity: v = sqrt(2 * g * h).
func jump_speed(height: float) -> float:
	return sqrt(2.0 * rise_gravity * maxf(height, 0.0))


## Rising speed a released jump is cut down to (tap height).
func cut_speed() -> float:
	return jump_speed(jump_min_height)


## Full-hold height of ground jump `stage` (1, 2 or 3, clamped).
func jump_height_for_stage(stage: int) -> float:
	match clampi(stage, 1, 3):
		1:
			return jump_height
		2:
			return jump_2_height
		_:
			return jump_3_height


## Long jump height for stage 1, 2 or 3 (clamped).
func long_jump_height(stage: int) -> float:
	match clampi(stage, 1, 3):
		1:
			return long_jump_height_1
		2:
			return long_jump_height_2
		_:
			return long_jump_height_3


## Long jump take-off speed in m/s for stage 1, 2 or 3 (clamped).
func long_jump_speed(stage: int) -> float:
	match clampi(stage, 1, 3):
		1:
			return long_jump_speed_1
		2:
			return long_jump_speed_2
		_:
			return long_jump_speed_3
