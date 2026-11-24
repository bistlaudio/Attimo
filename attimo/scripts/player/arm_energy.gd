class_name ArmEnergy
extends Node
## The single owner of the arm energy (checklist item 12: one owner with spend and gain APIs). Only this class writes `value`;
## states, modules and mechanisms ask can_afford and try_spend (all or nothing), drain (partial) and gain (income), and learn the
## outcome from the EventBus facts, which carry numbers and never node references. Child of the Player.
##
## Fallback rule (D-12, ENRG-03): spend, drain and gain are SILENT on failure. Only `refuse` makes a refusal visible, and only moves
## that do not fire (the air dash, the shot) call it. A base move that falls back (a dash hop that becomes stage 1, a wall run that
## runs dry) never calls refuse, so there is never a failure cue for it.
## Every API ignores non-finite amounts and keeps the value inside 0 .. MAX_ENERGY (T-05-08).
## energy_changed is quantised (T-05-09): once when the whole number changes or after a discrete spend or reset, at most once per
## physics tick, so the passive charge at 60 Hz never floods the EventLog.

## Energy of one core, the respawn value and the Loader bonus cost.
const CORE_SIZE: float = 25.0
## Number of cores on the arm.
const CORE_COUNT: int = 4
## Most energy the arm holds (CORE_COUNT cores).
const MAX_ENERGY: float = 100.0
## Smallest span of the passive curve (T-05-10: no division by zero when full speed is tuned onto the start speed).
const MIN_SPAN: float = 0.01

## Current energy, 0 .. MAX_ENERGY. Starts as one core (the respawn value).
var value: float = CORE_SIZE

## True while the arm is held in the charge posture: the charge button is down in Idle without move input (D-06).
var charging: bool = false

var _moto: bool = false
var _charge_total: float = 0.0
var _last_floor: int = int(CORE_SIZE)
var _emit_frame: int = -1
var _pending_emit: bool = false


## True when `amount` can be paid in full. A non-finite or negative amount cannot.
func can_afford(amount: float) -> bool:
	return is_finite(amount) and amount >= 0.0 and value >= amount


## Pays `amount` all or nothing. On success emits EventBus.energy_spent(amount, reason) and energy_changed(value) and returns true;
## on failure nothing changes, nothing is emitted and false comes back (the caller decides what the refusal looks like).
func try_spend(amount: float, reason: StringName) -> bool:
	if not can_afford(amount):
		return false
	_write(value - amount)
	EventBus.energy_spent.emit(amount, reason)
	_announce(true)
	return true


## Pays as much of `amount` as the arm holds (a partial spend: the wall run per tick). Returns what was taken. Silent: a dry arm
## returns 0.0 and the caller decides what happens (no refusal fact). A non-finite or negative amount takes nothing.
func drain(amount: float, reason: StringName) -> float:
	if not is_finite(amount) or amount <= 0.0:
		return 0.0
	var taken: float = minf(amount, value)
	if taken <= 0.0:
		return 0.0
	_write(value - taken)
	EventBus.energy_spent.emit(taken, reason)
	_announce(false)
	return taken


## Adds `amount` (income), clamped to MAX_ENERGY. Returns what was added. Silent apart from the quantised energy_changed; sources
## and the charge button report one EventBus.energy_gained at the end of a continuous gain. `source` names the income (&"passive",
## &"charge", the Extractor in plan 05-04).
func gain(amount: float, _source: StringName) -> float:
	if not is_finite(amount) or amount <= 0.0:
		return 0.0
	var added: float = minf(amount, MAX_ENERGY - value)
	if added <= 0.0:
		return 0.0
	_write(value + added)
	_announce(false)
	return added


## Makes a refusal visible: emits EventBus.energy_refused(reason, needed). The ONLY refusal path, called only by moves that do not
## fire (the air dash, the shot), never by a base move that falls back.
func refuse(reason: StringName, needed: float) -> void:
	if not is_finite(needed):
		return
	EventBus.energy_refused.emit(reason, needed)


## Sets the energy to `new_value` (clamped to 0 .. MAX_ENERGY; a non-finite value is ignored) and emits energy_changed.
func reset_to(new_value: float) -> void:
	if not is_finite(new_value):
		return
	_write(new_value)
	_announce(true)


## Respawn and checkpoint rule: exactly one core.
func reset_to_checkpoint() -> void:
	reset_to(CORE_SIZE)


## Fill of core `index` (0 .. CORE_COUNT - 1), 0.0 (empty) .. 1.0 (full): the cores fill one after the other from index 0.
func core_fill(index: int) -> float:
	return clampf((value - float(index) * CORE_SIZE) / CORE_SIZE, 0.0, 1.0)


## Passive charge in energy per second at `horizontal_speed` (D-05): 0 below energy_passive_start_speed, then the rate rises from
## energy_passive_rate_min to energy_passive_rate_max up to energy_passive_full_speed and stays there. Horizontal speed only.
func passive_rate(horizontal_speed: float, config: MovementConfig) -> float:
	if not is_finite(horizontal_speed) or horizontal_speed < config.energy_passive_start_speed:
		return 0.0
	var span: float = maxf(config.energy_passive_full_speed - config.energy_passive_start_speed, MIN_SPAN)
	var t: float = clampf((horizontal_speed - config.energy_passive_start_speed) / span, 0.0, 1.0)
	return lerpf(config.energy_passive_rate_min, config.energy_passive_rate_max, t)


## Per physics tick, called by PlayerController before the states run: the passive charge from the horizontal speed (paused in the
## Loader and Capture states: the speed there is stored or carried, not earned) and the charge button. The button adds
## energy_charge_rate while it is held in Idle with no move input (`still`); anything else stops it at once, and the total of one
## charge run is reported once as energy_gained(total, &"charge") when it stops.
func tick(delta: float, horizontal_speed: float, state_name: StringName, still: bool) -> void:
	var config: MovementConfig = _config()
	if config != null and state_name != &"Loader" and state_name != &"Capture":
		gain(passive_rate(horizontal_speed, config) * delta, &"passive")
	var wants_charge: bool = config != null and state_name == &"Idle" and still and Input.is_action_pressed(&"charge")
	if wants_charge and value < MAX_ENERGY:
		_charge_total += gain(config.energy_charge_rate * delta, &"charge")
		charging = true
	else:
		charging = false
		if _charge_total > 0.0:
			EventBus.energy_gained.emit(_charge_total, &"charge")
			_charge_total = 0.0
	if _pending_emit:
		_announce(false)


func _config() -> MovementConfig:
	var player: PlayerController = get_parent() as PlayerController
	return null if player == null else player.config


## True while Moto Perpetuo is on: from moto_threshold up, off only below moto_threshold - moto_exit_margin (hysteresis, A9).
func is_moto() -> bool:
	return _moto


## The single write path of `value`. Also settles Moto Perpetuo, so a flip is emitted at once, only on a flip.
func _write(new_value: float) -> void:
	value = clampf(new_value, 0.0, MAX_ENERGY)
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


## Emits energy_changed when the whole number changed (or `force` after a discrete spend or reset), at most once per physics frame;
## a second change in the same frame is sent by the next tick.
func _announce(force: bool) -> void:
	var whole: int = floori(value)
	if not force and whole == _last_floor and not _pending_emit:
		return
	var frame: int = Engine.get_physics_frames()
	if frame == _emit_frame:
		_pending_emit = true
		return
	_emit_frame = frame
	_pending_emit = false
	_last_floor = whole
	EventBus.energy_changed.emit(value)
