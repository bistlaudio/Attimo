class_name ArmEnergy
extends Node
## The single owner of the arm energy (checklist item 12: one owner with spend and gain APIs). The energy is a clock of 12 whole
## steps (D-34): every cost and every income is a whole number of steps and time appears only as tick intervals. Only this class
## writes `value`; states, modules and mechanisms ask can_afford and try_spend (all or nothing) and gain (income), and learn the
## outcome from the EventBus facts, which carry numbers and never node references. Child of the Player.
##
## Fallback rule (D-12, ENRG-03): spend and gain are SILENT on failure. Only `refuse` makes a refusal visible, and only moves that do
## not fire (the dash, the air dash, the wall-run start, the wall jump) call it. A base move that falls back (a dash hop that becomes
## stage 1, a wall run whose 1 s tick cannot be paid) never calls refuse.
## Every API ignores non-finite or non-positive amounts and keeps the value inside 0 .. MAX_STEPS (T-05-08, T-05.1-24).
## energy_changed is quantised (T-05-09): at most once per physics tick, a second change in the same tick is sent by the next tick.
## Income (D-42): ONE accumulator, two rates. Always +1 every energy_passive_interval; while R is held standing still in Idle +1 every
## energy_charge_interval INSTEAD (never stacking). Moves that cost steps never add one (D-41).

## Steps of one core (a quarter of the clock).
const CORE_STEPS: int = 3
## Number of cores on the arm.
const CORE_COUNT: int = 4
## Most energy the arm holds (CORE_COUNT cores of CORE_STEPS).
const MAX_STEPS: int = 12
## Steps at start and at a respawn (D-36).
const CHECKPOINT_STEPS: int = 3
## Smallest tick interval the accumulator divides by (T-05.1-23: no division by zero for a tuned-to-zero interval).
const MIN_INTERVAL: float = 0.01

## Current energy in whole steps, 0 .. MAX_STEPS. Starts as the respawn value.
var value: int = CHECKPOINT_STEPS

## True while the arm is held in the charge posture: the charge button is down in Idle without move input (D-06).
var charging: bool = false

var _moto: bool = false
var _progress: float = 0.0
var _last_value: int = CHECKPOINT_STEPS
var _emit_frame: int = -1
var _pending_emit: bool = false


## True when `steps` can be paid in full. A negative amount cannot.
func can_afford(steps: int) -> bool:
	return steps >= 0 and value >= steps


## Pays `steps` all or nothing. On success emits EventBus.energy_spent(steps, reason) and energy_changed(value) and returns true;
## on failure nothing changes, nothing is emitted and false comes back (the caller decides what the refusal looks like).
func try_spend(steps: int, reason: StringName) -> bool:
	if not can_afford(steps):
		return false
	if steps == 0:
		return true
	_write(value - steps)
	EventBus.energy_spent.emit(steps, reason)
	_announce(true)
	return true


## Adds `steps` (income), clamped to MAX_STEPS. Returns what was added. Silent apart from the quantised energy_changed; the timed
## income (tick) reports energy_gained(1, &"passive" or &"charge") and a source reports one energy_gained(total, source) at the end
## of a continuous gain (the Extractor).
func gain(steps: int, _source: StringName) -> int:
	if steps <= 0:
		return 0
	var added: int = mini(steps, MAX_STEPS - value)
	if added <= 0:
		return 0
	_write(value + added)
	_announce(false)
	return added


## Makes a refusal visible: emits EventBus.energy_refused(reason, needed). The ONLY refusal path, called only by moves that do not
## fire, never by a base move that falls back.
func refuse(reason: StringName, needed: int) -> void:
	EventBus.energy_refused.emit(reason, needed)


## Sets the energy to `steps` (clamped to 0 .. MAX_STEPS), zeroes the tick accumulator and emits energy_changed.
func reset_to(steps: int) -> void:
	_progress = 0.0
	_write(steps)
	_announce(true)


## Respawn and checkpoint rule: exactly CHECKPOINT_STEPS (3).
func reset_to_checkpoint() -> void:
	reset_to(CHECKPOINT_STEPS)


## Fill of core `index` (0 .. CORE_COUNT - 1), 0.0 (empty) .. 1.0 (full): the cores fill one after the other from index 0.
func core_fill(index: int) -> float:
	return clampi(value - index * CORE_STEPS, 0, CORE_STEPS) / float(CORE_STEPS)


## Progress 0 .. 1 toward the next timed step (the HUD clock face reads it); 0 when the clock is full.
func tick_progress() -> float:
	if value >= MAX_STEPS:
		return 0.0
	return clampf(_progress, 0.0, 1.0)


## Per physics tick, called by PlayerController before the states run (D-42): one accumulator that fills toward the next step. The
## rate is energy_charge_interval while R is held in Idle with no move input (`still`), energy_passive_interval otherwise (also in
## the Loader). Never both. Progress is a share of one step, so a rate change keeps what has been earned. A full clock adds nothing.
func tick(delta: float, state_name: StringName, still: bool) -> void:
	var config: MovementConfig = _config()
	if config == null or not is_finite(delta) or delta <= 0.0:
		return
	var wants_charge: bool = state_name == &"Idle" and still and Input.is_action_pressed(&"charge")
	charging = wants_charge and value < MAX_STEPS
	if value >= MAX_STEPS:
		_progress = 0.0
	else:
		var interval: float = config.energy_charge_interval if wants_charge else config.energy_passive_interval
		_progress += delta / maxf(interval, MIN_INTERVAL)
		if _progress >= 1.0 - 1e-6:
			_progress = maxf(_progress - 1.0, 0.0)
			var source: StringName = &"charge" if wants_charge else &"passive"
			if gain(1, source) > 0:
				EventBus.energy_gained.emit(1, source)
	if _pending_emit:
		_announce(false)


func _config() -> MovementConfig:
	var player: PlayerController = get_parent() as PlayerController
	return null if player == null else player.config


## True while Moto Perpetuo is on: from moto_threshold up, off only below moto_threshold - moto_exit_margin (hysteresis, A9).
func is_moto() -> bool:
	return _moto


## The single write path of `value`. Also settles Moto Perpetuo, so a flip is emitted at once, only on a flip.
func _write(new_value: int) -> void:
	value = clampi(new_value, 0, MAX_STEPS)
	var config: MovementConfig = _config()
	if config == null:
		return
	var wanted: bool = _moto
	if not _moto and value >= config.moto_threshold:
		wanted = true
	elif _moto and value < config.moto_threshold - config.moto_exit_margin:
		wanted = false
	if wanted != _moto:
		_moto = wanted
		EventBus.moto_changed.emit(_moto)


## Emits energy_changed when the value changed (or `force` after a discrete spend or reset), at most once per physics frame; a second
## change in the same frame is sent by the next tick.
func _announce(force: bool) -> void:
	if not force and value == _last_value and not _pending_emit:
		return
	var frame: int = Engine.get_physics_frames()
	if frame == _emit_frame:
		_pending_emit = true
		return
	_emit_frame = frame
	_pending_emit = false
	_last_value = value
	EventBus.energy_changed.emit(value)
