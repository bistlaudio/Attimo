class_name LoaderState
extends State
## Loader (HAND-04, ENRG-09, D-01..D-04, D-48..D-50): the right-click hold that stores momentum, pays steps and throws it along the camera
## view. GroundState, AirState, Dash and WallRun enter it through PlayerController.loader_press_starts_loader (which refuses a press at 0
## steps). The state owns the whole body for its duration: enter() stores the velocity, pays step 1, asks TimeFx for the slow world
## (loader_slow_factor) and, in the air, hangs Rino with gravity off. On the ground the run brakes to a stop within loader_skid_time
## (real time). While held, one more step is paid every loader_step_interval of REAL time up to loader_max_steps (an empty clock just
## stops the ring, no refusal). The hold ends on the release of the loader button or at loader_hold_cap of REAL time (tick accounting
## through TimeFx.unscaled, never a wall clock, so tests are deterministic). The discharge goes along PlayerController.loader_direction()
## at LoaderMath.discharge_speed(v, push, n, push_step, k, cap) and then flies a straight gravity-free line (PlayerController.
## begin_straight_flight) of loader_flight_distance[n] plus the overflow; it locks air control for loader_release_control_lock and hands
## over to Fall. It never touches air_dash_available and never calls refill_air_dash (D-03). One use per airborne stretch (D-02): an air
## press spends loader_available, and so does a ground discharge that lifts off, ends off the floor or carries Rino over a ledge
## (loader_ground_throw); landing, a boost ring or the slingshot cage give it back.
## Phase 05.1 (D-01..D-04, D-60): one state serves every source through PlayerController.loader_profile (LoaderProfile, null = ARM). A CAGE
## hold (slingshot core, PlayerController.catch_into_loader) always hangs Rino (even near the floor) and spends no use; it ends on the
## release after the loader button was held at the catch or pressed later (a same-tick tap counts), or at the cap, never on "not
## pressed" alone; its throw is a free 2-step Loader flight (CAGE_STEPS), pays nothing, skips the ground-throw rules and gives the
## Loader use back through refill_loader (never refill_air_dash). Slow factor, cap, control lock, hitstop and the camera stay shared.
## A FIXED hold (steam cannon, D-05) hangs Rino too but has no slow world, no loader_started fact and ignores all input: it pulls him
## to the profile's anchor (the barrel mouth) at FIXED_PULL_SPEED, and at the profile's hold of real time writes exactly
## direction * speed (no entry speed, no sideways part, no energy, no hitstop), emits EventBus.launched,
## locks air control and gives the Loader use back (refill_loader, never the air dash).
## exit() restores gravity_scale, spends the jump buffer and coyote window (the buffer would outlive the slow motion) and releases
## the time scale, so every exit path ends the slow world: release, cap, teleport() and a freed player (_exit_tree).

## The cap compares at this tolerance so 72 ticks of 1/60 s reach 1.2 s exactly despite float error.
const HOLD_EPSILON: float = 0.000001
## FIXED: the pull speed in m/s toward the barrel mouth; fast enough to arrive from anywhere in the trigger within the hold.
const FIXED_PULL_SPEED: float = 30.0
## The slingshot cage throws as a free Loader flight of this many steps (D-60); read, never copied into a config.
const CAGE_STEPS: int = 2

## The velocity stored on enter (horizontal move_velocity plus vertical_speed).
var stored_velocity: Vector3 = Vector3.ZERO
## Seconds of real time the hold has lasted.
var hold_real: float = 0.0
## True when the press started on the floor (a skid), false when it hangs in the air.
var grounded_entry: bool = false
## Physics updates since enter (a diagnostic the tests read for the cap edge).
var update_count: int = 0
## CAGE: true once the loader button was seen held or pressed during the hold (D-02 latch); its release then fires the throw.
var _press_seen: bool = false
## ARM: steps paid so far in this hold, 1..loader_max_steps (the ring of 05.1-12 and the discharge read it).
var steps_loaded: int = 0
## ARM: seconds of real time since the last step was paid (counts toward loader_step_interval).
var _step_timer: float = 0.0


## The source of the current hold: ARM without a profile, else the profile's source.
func source() -> LoaderProfile.Source:
	return LoaderProfile.Source.ARM if actor.loader_profile == null else actor.loader_profile.source


func enter(_previous: StringName) -> void:
	var config: MovementConfig = actor.config
	stored_velocity = Vector3(actor.move_velocity.x, actor.vertical_speed, actor.move_velocity.z)
	if not stored_velocity.is_finite():
		stored_velocity = Vector3.ZERO
	var cage: bool = source() == LoaderProfile.Source.CAGE
	var kit: bool = source() != LoaderProfile.Source.ARM
	# A kit hold hangs Rino wherever it catches, so a ring near the floor freezes instead of skidding (D-01).
	grounded_entry = actor.is_grounded() and not kit
	hold_real = 0.0
	update_count = 0
	_press_seen = cage and _loader_pressed()
	steps_loaded = 0
	_step_timer = 0.0
	if source() == LoaderProfile.Source.ARM and actor.arm_energy.try_spend(1, &"loader"):
		steps_loaded = 1
	actor.consume_jump()
	if not grounded_entry:
		if not kit:
			actor.loader_available = false
		actor.gravity_scale = 0.0
		actor.move_velocity = Vector3.ZERO
		actor.vertical_speed = 0.0
	if source() == LoaderProfile.Source.FIXED:
		return
	TimeFx.request(&"loader", config.loader_slow_factor)
	EventBus.loader_started.emit(actor.global_position, stored_velocity.length(), not grounded_entry)


func exit() -> void:
	actor.loader_profile = null
	actor.gravity_scale = 1.0
	actor.consume_jump()
	TimeFx.release(&"loader")


## A freed player never runs exit(): hand the world back its normal speed here too.
func _exit_tree() -> void:
	if is_instance_valid(TimeFx):
		TimeFx.release(&"loader")


func physics_update(delta: float) -> StringName:
	var config: MovementConfig = actor.config
	var real: float = TimeFx.unscaled(delta)
	hold_real += real
	update_count += 1
	if source() == LoaderProfile.Source.FIXED:
		return _fixed_update(delta)
	if grounded_entry:
		var flat_speed: float = Vector2(stored_velocity.x, stored_velocity.z).length()
		var skid_rate: float = flat_speed / maxf(config.loader_skid_time, 0.01)
		actor.move_velocity = actor.move_velocity.move_toward(Vector3.ZERO, skid_rate * real)
		actor.move_velocity.y = 0.0
		if actor.is_grounded():
			actor.vertical_speed = 0.0
	if source() == LoaderProfile.Source.ARM:
		_pay_steps(real)
	if hold_real >= config.loader_hold_cap - HOLD_EPSILON:
		return _discharge()
	if source() == LoaderProfile.Source.CAGE:
		# D-02 latch: a press seen this tick (or held since the catch) arms the release; "not pressed" alone never fires.
		var pressed: bool = Input.is_action_pressed(&"loader")
		if _loader_pressed():
			_press_seen = true
		if _press_seen and not pressed:
			return _discharge()
		return &""
	if not Input.is_action_pressed(&"loader"):
		return _discharge()
	return &""


## FIXED: no input; pull to the anchor (exact arrival, then rest), launch once the profile's hold of real time has passed.
func _fixed_update(delta: float) -> StringName:
	var profile: LoaderProfile = actor.loader_profile
	if hold_real >= profile.hold - HOLD_EPSILON:
		return _discharge()
	var pull: Vector3 = (profile.anchor - actor.global_position).limit_length(FIXED_PULL_SPEED * delta) / maxf(delta, 0.0001)
	actor.move_velocity = Vector3(pull.x, 0.0, pull.z)
	actor.vertical_speed = pull.y
	return &""


## True when the loader button is held, or was pressed or released since the last tick (a press and a release between two ticks
## is a tap and still counts as a press).
func _loader_pressed() -> bool:
	return Input.is_action_pressed(&"loader") or Input.is_action_just_pressed(&"loader") or Input.is_action_just_released(&"loader")


## 0 at the start of the hold, 1 at loader_hold_cap (presentation, plan 05-02).
func hold_ratio() -> float:
	return clampf(hold_real / maxf(actor.config.loader_hold_cap, 0.01), 0.0, 1.0)


## The stored speed as a share of loader_max_speed, 0 .. 1 (presentation, plan 05-02).
func stored_ratio() -> float:
	return clampf(stored_velocity.length() / maxf(actor.config.loader_max_speed, 0.01), 0.0, 1.0)


## Pays one more step per loader_step_interval of real time until loader_max_steps (D-48). An unaffordable step stops the ring without a
## refusal; the timer waits at the interval, so a step gained during the hold is paid at once.
func _pay_steps(real: float) -> void:
	var config: MovementConfig = actor.config
	if steps_loaded >= config.loader_max_steps:
		return
	var interval: float = maxf(config.loader_step_interval, 0.01)
	_step_timer += real
	while steps_loaded < config.loader_max_steps and _step_timer >= interval - HOLD_EPSILON:
		if not actor.arm_energy.try_spend(1, &"loader"):
			_step_timer = minf(_step_timer, interval)
			return
		steps_loaded += 1
		_step_timer = maxf(_step_timer - interval, 0.0)


## 0..1 progress toward the next step (1 once the hold is full or the clock is empty at the interval); the ring of 05.1-12 reads it.
func step_progress() -> float:
	var config: MovementConfig = actor.config
	if steps_loaded >= config.loader_max_steps:
		return 1.0
	return clampf(_step_timer / maxf(config.loader_step_interval, 0.01), 0.0, 1.0)


## FIXED: the profile speed, never faster than the Loader's own ceiling (T-05.1-05), times the feel-test kit_launch_scale.
func _fixed_speed() -> float:
	return minf(actor.loader_profile.speed, actor.config.loader_max_speed) * actor.kit_launch_scale()


## Throws Rino along the view (D-49, D-50): the speed is written, the straight flight starts, air control is locked, then Fall takes over.
## ARM: n = steps_loaded paid steps. CAGE: a free CAGE_STEPS flight, kit_launch_scale applied BEFORE the cap so the 22 m/s envelope holds.
func _discharge() -> StringName:
	var config: MovementConfig = actor.config
	if source() == LoaderProfile.Source.FIXED:
		return _discharge_fixed()
	var direction: Vector3 = actor.loader_direction()
	var cage: bool = source() == LoaderProfile.Source.CAGE
	var steps: int = CAGE_STEPS if cage else maxi(steps_loaded, 1)
	var stored: float = stored_velocity.length()
	var raw: float = LoaderMath.discharge_speed_uncapped(stored, config.loader_push, steps, config.loader_push_step, config.loader_speed_k)
	if cage:
		raw *= actor.kit_launch_scale()
	var speed: float = minf(raw, maxf(config.loader_max_speed, 0.0))
	var over: float = maxf(raw - config.loader_max_speed, 0.0)
	var distance: float = LoaderMath.flight_distance(steps, over, [config.loader_flight_distance_1, config.loader_flight_distance_2, config.loader_flight_distance_3], config.loader_overflow_gain)
	var velocity: Vector3 = LoaderMath.discharge_velocity(direction, speed)
	actor.move_velocity = Vector3(velocity.x, 0.0, velocity.z)
	actor.vertical_speed = clampf(velocity.y, -config.terminal_speed, config.terminal_speed)
	actor.air_speed_cap = maxf(config.run_speed, actor.horizontal_speed())
	actor.lock_air_control(config.loader_release_control_lock)
	actor.begin_straight_flight(distance, 0 if cage else steps)
	if cage:
		# The cage gives the use back and leaves the air dash alone; it skips the ground-throw rules.
		actor.refill_loader()
	elif grounded_entry:
		# D-02: a ground discharge that lifts off, or one released after the skid left the floor, spends the airborne use. A throw
		# that stays on the floor marks loader_ground_throw, so walking off a ledge with it spends the use too (WR-02).
		if velocity.y > 0.0 or not actor.is_grounded():
			actor.loader_available = false
		else:
			actor.loader_ground_throw = true
	EventBus.loader_released.emit(actor.global_position, direction, speed, steps)
	# D-04 "geladen": the velocity is already written, the world holds for a blink so the release lands sharp. The hitstop is its
	# own TimeFx source; exit() still releases only &"loader".
	TimeFx.pulse(&"loader_hitstop", config.loader_hitstop_scale, config.loader_hitstop_time)
	return &"Fall"


## FIXED (D-05): the launch is exactly direction * speed from the barrel mouth, whatever the entry; only the Loader use comes back.
func _discharge_fixed() -> StringName:
	var config: MovementConfig = actor.config
	var direction: Vector3 = actor.loader_profile.direction.normalized()
	var speed: float = _fixed_speed()
	var velocity: Vector3 = direction * speed
	actor.move_velocity = Vector3(velocity.x, 0.0, velocity.z)
	actor.vertical_speed = clampf(velocity.y, -config.terminal_speed, config.terminal_speed)
	actor.air_speed_cap = maxf(config.run_speed, actor.horizontal_speed())
	actor.lock_air_control(config.loader_release_control_lock)
	actor.refill_loader()
	EventBus.launched.emit(actor.global_position, direction, speed)
	return &"Fall"
