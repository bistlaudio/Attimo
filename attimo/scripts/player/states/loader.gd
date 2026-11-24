class_name LoaderState
extends State
## Loader (HAND-04, D-01..D-04): the right-click hold that stores momentum and throws it along the camera view. GroundState, AirState,
## Dash and WallRun enter it through PlayerController.loader_press_starts_loader; Capture never does. The state owns the whole body for
## its duration, like Capture: enter() stores the velocity, asks TimeFx for the slow world (loader_slow_factor) and, in the air, hangs
## Rino with gravity off. On the ground the run brakes to a stop within loader_skid_time (real time). The hold ends on the release
## of the loader button or at loader_hold_cap of REAL time (tick accounting through TimeFx.unscaled, never a wall clock, so tests are
## deterministic). The discharge goes along PlayerController.loader_direction() at LoaderMath.discharge_speed(...); the bonus costs one
## full core and is decided HERE at the release (A7: below a core the arm counts as empty, the redirect cooldown starts). It locks air
## control for loader_release_control_lock and hands over to Fall. It never touches air_dash_available and never calls
## refill_air_dash (D-03: the Loader is independent of the air dash). One use per airborne stretch (D-02): an air press spends
## loader_available, and so does a ground discharge that lifts off; landing, a boost ring or the slingshot give it back.
## exit() restores gravity_scale, spends the jump buffer and coyote window (the buffer would outlive the slow motion) and releases
## the time scale, so every exit path ends the slow world: release, cap, teleport() and a freed player (_exit_tree).

## The cap compares at this tolerance so 72 ticks of 1/60 s reach 1.2 s exactly despite float error.
const HOLD_EPSILON: float = 0.000001

## The velocity stored on enter (horizontal move_velocity plus vertical_speed).
var stored_velocity: Vector3 = Vector3.ZERO
## Seconds of real time the hold has lasted.
var hold_real: float = 0.0
## True when the press started on the floor (a skid), false when it hangs in the air.
var grounded_entry: bool = false
## Physics updates since enter (a diagnostic the tests read for the cap edge).
var update_count: int = 0


func enter(_previous: StringName) -> void:
	var config: MovementConfig = actor.config
	stored_velocity = Vector3(actor.move_velocity.x, actor.vertical_speed, actor.move_velocity.z)
	if not stored_velocity.is_finite():
		stored_velocity = Vector3.ZERO
	grounded_entry = actor.is_grounded()
	hold_real = 0.0
	update_count = 0
	actor.consume_jump()
	if not grounded_entry:
		actor.loader_available = false
		actor.gravity_scale = 0.0
		actor.move_velocity = Vector3.ZERO
		actor.vertical_speed = 0.0
	TimeFx.request(&"loader", config.loader_slow_factor)
	EventBus.loader_started.emit(actor.global_position, stored_velocity.length(), not grounded_entry)


func exit() -> void:
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
	if grounded_entry:
		var flat_speed: float = Vector2(stored_velocity.x, stored_velocity.z).length()
		var skid_rate: float = flat_speed / maxf(config.loader_skid_time, 0.01)
		actor.move_velocity = actor.move_velocity.move_toward(Vector3.ZERO, skid_rate * real)
		actor.move_velocity.y = 0.0
		if actor.is_grounded():
			actor.vertical_speed = 0.0
	if not Input.is_action_pressed(&"loader") or hold_real >= config.loader_hold_cap - HOLD_EPSILON:
		return _discharge()
	return &""


## 0 at the start of the hold, 1 at loader_hold_cap (presentation, plan 05-02).
func hold_ratio() -> float:
	return clampf(hold_real / maxf(actor.config.loader_hold_cap, 0.01), 0.0, 1.0)


## The stored speed as a share of loader_max_speed, 0 .. 1 (presentation, plan 05-02).
func stored_ratio() -> float:
	return clampf(stored_velocity.length() / maxf(actor.config.loader_max_speed, 0.01), 0.0, 1.0)


## True when the arm can pay the bonus right now (a full core). The release decides again with the energy of that moment.
func bonus_ready() -> bool:
	return actor.arm_energy.can_afford(actor.config.loader_bonus_cost)


## The velocity a release right now would give (the same math as the discharge, with the bonus when it is affordable).
func preview_velocity() -> Vector3:
	var config: MovementConfig = actor.config
	var bonus: float = config.loader_bonus_speed if bonus_ready() else 0.0
	var speed: float = LoaderMath.discharge_speed(stored_velocity.length(), config.loader_min_push, bonus, config.loader_max_speed)
	return LoaderMath.discharge_velocity(actor.loader_direction(), speed)


## Throws Rino along the view: the bonus is paid here, the velocity is written, air control is locked, then Fall takes over.
func _discharge() -> StringName:
	var config: MovementConfig = actor.config
	var direction: Vector3 = actor.loader_direction()
	var bonus: bool = actor.arm_energy.try_spend(config.loader_bonus_cost, &"loader")
	var speed: float = LoaderMath.discharge_speed(stored_velocity.length(), config.loader_min_push, config.loader_bonus_speed if bonus else 0.0, config.loader_max_speed)
	var velocity: Vector3 = LoaderMath.discharge_velocity(direction, speed)
	actor.move_velocity = Vector3(velocity.x, 0.0, velocity.z)
	actor.vertical_speed = clampf(velocity.y, -config.terminal_speed, config.terminal_speed)
	actor.air_speed_cap = maxf(config.run_speed, actor.horizontal_speed())
	actor.lock_air_control(config.loader_release_control_lock)
	if not bonus:
		actor.loader_cooldown_timer = config.loader_redirect_cooldown
	if grounded_entry and velocity.y > 0.0:
		actor.loader_available = false
	EventBus.loader_released.emit(actor.global_position, direction, speed, bonus)
	return &"Fall"
