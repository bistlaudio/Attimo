class_name MovementConfig
extends Resource
## The one tunable movement resource (MOVE-10, D-23). Every movement number lives here.
## Fourteen groups in the F2 tuning panel: Run, Air, Gravity, Jump chain, Dash,
## Long jump (dash hop), Timing windows, Floor and platforms, Loader, Energy, Moto Perpetuo, Wall, Pose, Clip playback. Gravity is set directly
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
## Full-hold height of Jump 3 (the highest ground jump) in m; raise it for a taller Jump 3.
@export_range(0.5, 6.0, 0.05) var jump_3_height: float = 4.0
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
## Long jump height at stage 3 (last hop of the combo) in m; raise it for a higher third hop.
@export_range(0.5, 6.0, 0.05) var long_jump_height_3: float = 3.6
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

@export_group("Loader")
## World speed while the Loader is held, as a share of normal (HAND-04); raise it for a gentler slow motion.
@export_range(0.05, 1.0, 0.01) var loader_slow_factor: float = 0.25
## Longest hold in seconds of REAL time before the Loader discharges by itself; raise it for a longer aim.
@export_range(0.2, 3.0, 0.05) var loader_hold_cap: float = 1.2
## Seconds of real time the run brakes to a stop when the Loader is pressed on the ground (D-01); raise it for a softer stop.
@export_range(0.02, 0.5, 0.01) var loader_skid_time: float = 0.1
## Seconds of REAL time between two Loader steps while the button is held (D-48); raise it to make the hold slower to fill.
@export_range(0.05, 2.0, 0.05) var loader_step_interval: float = 0.3
## Most steps one Loader hold can pay (D-48); raise it for a bigger charge.
@export_range(1, 3, 1) var loader_max_steps: int = 3
## Base speed in m/s every discharge adds (D-49: v + push + n * (push_step + k * v)); raise it for a stronger plain push.
@export_range(0.0, 12.0, 0.5) var loader_push: float = 4.0
## Speed in m/s each loaded step adds (D-49); raise it for a bigger gap between 1 and 3 steps.
@export_range(0.0, 8.0, 0.5) var loader_push_step: float = 2.0
## Share of the stored speed each loaded step adds on top (D-49), so momentum counts; raise it to reward a fast approach.
@export_range(0.0, 0.5, 0.01) var loader_speed_k: float = 0.1
## Straight gravity-free flight in m after a 1-step discharge (D-50); raise it for a longer short Loader.
@export_range(1.0, 40.0, 0.5) var loader_flight_distance_1: float = 6.0
## Straight gravity-free flight in m after a 2-step discharge (D-50, also the slingshot cage, D-60); raise it for a longer middle Loader.
@export_range(1.0, 40.0, 0.5) var loader_flight_distance_2: float = 10.0
## Straight gravity-free flight in m after a 3-step discharge (D-50); raise it for a longer full Loader.
@export_range(1.0, 40.0, 0.5) var loader_flight_distance_3: float = 14.0
## Extra flight metres per m/s of speed the loader_max_speed cap cuts off (D-49, D-50); raise it so a fast approach flies further.
@export_range(0.0, 3.0, 0.1) var loader_overflow_gain: float = 1.0
## Fastest discharge in m/s; 22 is the tunnelling and camera envelope (long_jump_speed_3), do not raise it without re-running those tests.
@export_range(8.0, 24.0, 0.5) var loader_max_speed: float = 22.0
## Seconds air control is off after the discharge so steering does not eat the throw (D-03); raise it for a harder throw.
@export_range(0.0, 0.5, 0.01) var loader_release_control_lock: float = 0.15
## "Geladen" cue (D-04): real seconds of the short hitstop right after the release, so the discharge lands sharp; raise it for a heavier release.
@export_range(0.0, 0.2, 0.01) var loader_hitstop_time: float = 0.05
## Time scale during that hitstop (1.0 = no hitstop); lower it for a harder freeze.
@export_range(0.05, 1.0, 0.01) var loader_hitstop_scale: float = 0.05
## "Geladen" cue (D-04): how far in m the camera pulls back at a full hold, eased with the hold (never a cut); raise it for more tension.
@export_range(0.0, 1.5, 0.05) var loader_camera_pullback: float = 0.35

@export_group("Kit")
## FEEL TEST (user request 2026-11-25): multiplier on every kit launch: slingshot cage, steam cannon, bounce pad, geyser and
## boost ring. 1.0 = the designed values; raise it to throw much further and test an exaggerated feel. Above ~1.3 a throw can
## exceed loader_max_speed (22 m/s), the tested tunnelling and camera envelope, so thin walls may be passed at the top end.
@export_range(1.0, 3.0, 0.05) var kit_launch_scale: float = 1.0

@export_group("Energy")
## Steps a ground dash costs (D-37); without them the dash does not fire and the press is refused. Raise it to make the dash rarer.
@export_range(0, 12, 1) var dash_cost: int = 1
## Steps an air dash costs (D-37); without them it does not fire and the press is refused. Raise it to make the air dash rarer.
@export_range(0, 12, 1) var air_dash_cost: int = 1
## Steps the dash hop pays from stage 2 on, each (D-38; stage 1 is free; without them the hop silently stays stage 1). Raise it to make the hop stack rarer.
@export_range(0, 12, 1) var long_jump_cost: int = 1
## Steps a wall run costs on entry (D-37); without them the run does not start and the contact is refused once. Raise it to make wall runs rarer.
@export_range(0, 12, 1) var wall_run_entry_cost: int = 2
## Steps a wall run costs at every tick interval (D-37); an unpaid tick drops the run into Fall without a refusal. Raise it to make long runs costlier.
@export_range(0, 12, 1) var wall_run_tick_cost: int = 1
## Seconds between the wall-run tick payments (D-37); raise it for a cheaper long run.
@export_range(0.1, 3.0, 0.05) var wall_run_tick_interval: float = 1.0
## Steps a wall jump costs (D-37); without them it does not fire and the buffered press is refused and consumed. Raise it to make wall jumps rarer.
@export_range(0, 12, 1) var wall_jump_cost: int = 1
## Seconds for the passive +1 step (D-42); it always runs, also standing and in the Loader. Raise it for a slower free refill (20 s since quick 261127-p64).
@export_range(0.5, 60.0, 0.5) var energy_passive_interval: float = 20.0
## Seconds for +1 step while the charge key (R) is held standing still in Idle (D-42); it replaces the passive tick, never stacks. Raise it for a slower charge (10 s since quick 261127-p64).
@export_range(0.5, 60.0, 0.5) var energy_charge_interval: float = 10.0

@export_group("Moto Perpetuo")
## Steps from which Moto Perpetuo turns on (D-36, two cores); raise it to demand a fuller arm.
@export_range(1, 12, 1) var moto_threshold: int = 6
## Steps below the threshold at which Moto Perpetuo turns off again (hysteresis, A9), so a spend at the edge does not flicker; raise it for a stickier state.
@export_range(0, 4, 1) var moto_exit_margin: int = 1
## Extra share of the ground run speed in Moto Perpetuo (GAME-DESIGN +10 to 15 percent); raise it for a faster Moto run.
@export_range(0.0, 0.3, 0.01) var moto_run_bonus: float = 0.12
## Height in m of Jump 3 in Moto Perpetuo, kept above jump_3_height; raise it for a higher buffed Jump 3.
@export_range(4.0, 8.0, 0.1) var moto_jump_height: float = 5.0
## Gravity factor of the buffed Jump 3 (1 = normal); the take-off speed follows from this and moto_jump_height, so apex height and apex time (Pittman) stay a pair. Raise it for a snappier, shorter jump.
@export_range(1.0, 2.5, 0.05) var moto_jump_gravity_scale: float = 1.45

@export_group("Wall")
## Smallest horizontal speed in m/s that starts a wall-run on contact with a wall-run pad (MOVE-12); raise it to demand a faster approach.
@export_range(2.0, 20.0, 0.1) var wall_run_min_speed: float = 7.0
## Speed along the pad in m/s during a wall-run (never below the entry speed); raise it for a faster run.
@export_range(2.0, 25.0, 0.1) var wall_run_speed: float = 10.0
## Longest wall-run in seconds before the player drops to Fall; raise it for longer runs.
@export_range(0.2, 3.0, 0.05) var wall_run_time: float = 1.1
## Gravity factor during a wall-run (0 = none, 1 = normal); raise it for a heavier run that sinks.
@export_range(0.0, 1.0, 0.05) var wall_run_gravity_scale: float = 0.1
## Upward speed in m/s a wall-run starts with at least; raise it for a run that climbs at the start.
@export_range(0.0, 8.0, 0.1) var wall_run_entry_rise: float = 1.5
## Speed in m/s with which the run presses into the pad so the contact holds; raise it if the run drops off the pad.
@export_range(0.0, 5.0, 0.1) var wall_run_stick_speed: float = 1.5
## Seconds after a wall-run or wall-jump before the next wall-run may start; raise it to stop re-grabs.
@export_range(0.0, 2.0, 0.05) var wall_run_cooldown: float = 0.35
## Seconds a wall contact still counts after the last touch (a run keeps its pad through a one-tick gap); raise it for a more forgiving pad end.
@export_range(0.0, 0.5, 0.01) var wall_contact_grace: float = 0.12
## Speed in m/s of the wall-jump kick away from the wall; raise it for a farther kick.
@export_range(0.0, 20.0, 0.5) var wall_jump_out_speed: float = 9.0
## Height in m of the wall-jump rise (full hold); raise it for a higher kick.
@export_range(0.5, 6.0, 0.1) var wall_jump_height: float = 2.6
## Share of the speed along the wall that a wall-jump keeps; raise it to carry the run into the jump.
@export_range(0.0, 1.0, 0.05) var wall_jump_keep_along: float = 0.5
## Seconds air control is off after a wall-jump so the kick is not eaten; raise it for a harder kick.
@export_range(0.0, 1.0, 0.01) var wall_jump_control_lock: float = 0.18
## Roll lean in degrees of the body during a wall-run, head away from the wall (D-40, presentation only); raise it for a stronger tilt.
@export_range(0.0, 45.0, 0.5) var wall_run_lean_deg: float = 18.0
## Pose-only lateral offset in m of the Mannequin toward the wall during a wall run (D-40): with the lean (head away) the feet read as on
## the wall. About the capsule radius minus a margin; collision is unchanged.
@export_range(0.0, 0.6, 0.05) var wall_run_feet_offset: float = 0.35

@export_group("Pose")
## Forward lean of the body during a ground dash in degrees (D-01); raise it for a harder lean into the dash.
@export_range(0.0, 45.0, 0.5) var dash_lean_deg: float = 10.0
## Seconds the lean takes to build up from upright to the dash lean; lower it for a snappier lean.
@export_range(0.01, 0.5, 0.01) var lean_in_time: float = 0.05
## Seconds the lean takes to ease out from the dash lean to upright, also when a dash hands over to a long jump; raise it for a slower recovery.
@export_range(0.01, 0.5, 0.01) var lean_out_time: float = 0.12
## Seconds before the predicted touchdown at which a pirouette (long jump stage 3, and Jump 3 while ProceduralPose.jump_3_pirouette is on) is finished; raise it for an earlier finish.
@export_range(0.0, 0.3, 0.01) var pirouette_lead_time: float = 0.08
## Seconds the remaining spin takes when a Loader press, an air dash or the landing cuts a pirouette short (DEV-03); raise it for a softer finish.
@export_range(0.01, 0.5, 0.01) var pirouette_finish_time: float = 0.1
## Forward lean kick in degrees that a refused dash press gives (a non-moving twitch); raise it for a stronger blocked signal.
@export_range(0.0, 20.0, 0.5) var dash_blocked_twitch_deg: float = 6.0
## Seconds the blocked-dash twitch lasts (the kick rises and falls inside it); raise it for a slower twitch.
@export_range(0.02, 0.5, 0.01) var dash_blocked_twitch_time: float = 0.1
## Height in m of the point the body leans and spins about (about the hips); raise it to pivot higher up.
@export_range(0.0, 1.5, 0.05) var pose_pivot_height: float = 0.45

@export_group("Clip playback")
## Ground speed in m/s at which Running_A plays at 1x; lower it for a faster-playing run clip, raise it for a slower one.
@export_range(0.5, 20.0, 0.1) var run_anim_ref_speed: float = 4.5
## Cap on the Running_A playback speed (1 = never faster than the clip); raise it for a faster-playing run at full speed.
@export_range(1.0, 4.0, 0.05) var run_anim_max_scale: float = 2.5
## Seconds the upper body takes to blend into the arm pose and back out (near contact, shot, Loader hold); raise it for a slower arm blend.
@export_range(0.01, 1.0, 0.01) var aim_layer_blend_time: float = 0.15
## Speed in 1/s at which the locomotion blend follows the movement (idle 0 .. run 1); raise it for a snappier blend.
@export_range(1.0, 40.0, 0.5) var locomotion_blend_rate: float = 10.0
## Seconds the Dodge pose is held after an air dash ends before the Fall clip takes over (landing ends it earlier, DEV-02); raise it for a longer hold.
@export_range(0.0, 2.0, 0.05) var air_dash_hold_time: float = 0.35
## Crossfade in seconds from the ground locomotion into a dash clip; raise it for a softer dash start on the ground.
@export_range(0.0, 0.5, 0.01) var dash_in_blend: float = 0.06
## Crossfade in seconds from a jump, long jump or fall clip into a dash clip; raise it for a softer dash start in the air.
@export_range(0.0, 0.5, 0.01) var dash_in_blend_air: float = 0.08
## Crossfade in seconds out of a dash clip into whatever follows; raise it for a softer dash exit.
@export_range(0.0, 0.5, 0.01) var dash_out_blend: float = 0.15

@export_group("Clip variants")
## Shortest still time in Idle in seconds before an idle break clip plays (quick 261118-qi3); raise it for rarer breaks.
@export_range(1.0, 30.0, 0.1) var idle_break_delay_min: float = 5.0
## Longest still time in Idle in seconds before an idle break clip plays; the delay is rolled between min and max.
@export_range(1.0, 30.0, 0.1) var idle_break_delay_max: float = 8.0
## Horizontal speed in m/s at which Sprint_Loop fully replaces Running_A in the run blend (dash and dash-hop momentum
## above run_speed); there is no sprint input. Raise it for a later sprint look.
@export_range(9.0, 22.0, 0.1) var sprint_anim_full_speed: float = 12.0
## Vertical impact speed in m/s from which a landing shows the hard landing. Measured fall gravity about 55 m/s^2: the
## 4.0 m Jump 3 lands at about 21 m/s, so 24 means a drop of about 5 m or more; raise it for rarer hard landings.
@export_range(5.0, 40.0, 0.5) var hard_landing_speed: float = 24.0
## Horizontal speed in m/s at touchdown from which a landing shows the roll (presentation only, D-08); raise it for rarer
## rolls.
@export_range(9.0, 22.0, 0.1) var roll_landing_speed: float = 13.0


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
