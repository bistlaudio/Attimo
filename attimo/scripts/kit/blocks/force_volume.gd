class_name ForceVolume
extends KitBlock
## Force volume block (Phase 05.1, KIT-01, D-10, D-11, D-17): a box Area3D that pushes, launches or slows the player. One script, one
## ForceVolumeConfig (Profile x Timing) per object, a look as an inherited scene. The old steam nozzle updraft, pressure-valve geyser and
## wind tunnel are presets of it (D-09, same numbers); the leaf storm and resin pool are the nature objects (D-26, D-27).
## DIRECTIONAL calls PlayerController.push_toward every tick while on, or launch_along once per pulse and player when `launch_speed` > 0
## (the geyser burst). DRAG calls request_move_scale every tick. Income (D-43, D-61): a GIVES block grants steps on entering a CONTINUOUS
## volume or on a burst that launches the player, through KitBlock.grant_step with its per-block cooldown, so standing inside never
## farms. The block never writes the player's motion itself (D-17). Optional look nodes are driven here: a `Column` (PULSED: visible
## during the pulse) and a `Strips` group (the leaf storm: strips scroll and sway, faster during a gust; plain mesh motion, no particles).

## Smallest volume edge in m (a zero edge would never overlap).
const MIN_EDGE: float = 0.5
## Seconds the burst column takes to grow to full height.
const COLUMN_GROW: float = 0.15

## The block's config; the instance works on its own copy (D-12).
@export var config: ForceVolumeConfig

var _pulse_timer: float = 0.0
var _pulse_is_on: bool = true
var _present: Array[PlayerController] = []
var _launched: Array[PlayerController] = []
var _clock: float = 0.0
var _strip_base: Dictionary = {}

@onready var _volume: Area3D = $Volume
@onready var _column: Node3D = get_node_or_null(^"Column") as Node3D
@onready var _strips: Node3D = get_node_or_null(^"Strips") as Node3D


func _ready() -> void:
	if config == null:
		config = ForceVolumeConfig.new()
	config = own_config(config) as ForceVolumeConfig
	_volume.collision_layer = 0
	_volume.collision_mask = PhysicsLayers.PLAYER
	var size: Vector3 = volume_size()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	var shape_node: CollisionShape3D = $Volume/CollisionShape3D as CollisionShape3D
	shape_node.shape = box
	shape_node.position = Vector3(0.0, size.y * 0.5, 0.0)
	if _strips != null:
		for strip: Node in _strips.get_children():
			var strip_3d: Node3D = strip as Node3D
			if strip_3d != null:
				_strip_base[strip_3d] = strip_3d.position
	_begin_cycle()
	_apply_look()


func _physics_process(delta: float) -> void:
	_tick_pulse(delta)
	var players: Array[PlayerController] = _players_inside()
	var entered: Array[PlayerController] = []
	for player: PlayerController in players:
		if not _present.has(player):
			entered.append(player)
	_present = players
	match config.profile:
		ForceVolumeConfig.Profile.DIRECTIONAL:
			_act_directional(players, entered)
		ForceVolumeConfig.Profile.DRAG:
			for player: PlayerController in players:
				player.request_move_scale(config.move_scale)
	_apply_look()


func _process(delta: float) -> void:
	if _strips == null:
		return
	_clock += delta
	var gust: float = 1.0 if _pulse_is_on else 0.0
	var span: float = volume_size().z
	var wind: Vector3 = config.direction.normalized()
	var index: int = 0
	for strip: Node in _strips.get_children():
		var strip_3d: Node3D = strip as Node3D
		if strip_3d == null or not _strip_base.has(strip_3d):
			continue
		var base: Vector3 = _strip_base[strip_3d]
		var travel: float = fposmod(_clock * (1.5 + 5.0 * gust) + float(index) * 1.7, span) - span * 0.5
		strip_3d.position = Vector3(base.x, base.y + sin(_clock * 3.0 + float(index)) * 0.15, base.z) + wind * travel
		strip_3d.rotation.z = sin(_clock * 4.0 + float(index) * 2.0) * (0.15 + 0.35 * gust)
		index += 1


## The clamped volume size in m.
func volume_size() -> Vector3:
	return Vector3(maxf(config.size.x, MIN_EDGE), maxf(config.size.y, MIN_EDGE), maxf(config.size.z, MIN_EDGE))


## True while the volume acts: always for CONTINUOUS, inside the `pulse_on` window for PULSED.
func is_pulse_on() -> bool:
	return _pulse_is_on


## World push direction (the config direction turned by the node), or ZERO for a zero direction.
func world_direction() -> Vector3:
	var local: Vector3 = config.direction
	if not local.is_finite() or local.length_squared() < 0.0001:
		return Vector3.ZERO
	return (global_basis * local).normalized()


func reset() -> void:
	super.reset()
	_present.clear()
	_begin_cycle()
	_apply_look()


func _begin_cycle() -> void:
	_pulse_timer = 0.0
	_launched.clear()
	_pulse_is_on = config.timing == ForceVolumeConfig.Timing.CONTINUOUS


func _tick_pulse(delta: float) -> void:
	if config.timing != ForceVolumeConfig.Timing.PULSED:
		return
	_pulse_timer += delta
	if _pulse_is_on:
		if _pulse_timer >= config.pulse_on:
			_pulse_is_on = false
			_pulse_timer = 0.0
			_launched.clear()
	elif _pulse_timer >= config.pulse_off:
		_pulse_is_on = true
		_pulse_timer = 0.0
		_launched.clear()


func _players_inside() -> Array[PlayerController]:
	var found: Array[PlayerController] = []
	for body: Node3D in _volume.get_overlapping_bodies():
		var player: PlayerController = body as PlayerController
		if player != null:
			found.append(player)
	return found


func _act_directional(players: Array[PlayerController], entered: Array[PlayerController]) -> void:
	if not _pulse_is_on:
		return
	var direction: Vector3 = world_direction()
	if direction == Vector3.ZERO:
		return
	var pulsed: bool = config.timing == ForceVolumeConfig.Timing.PULSED
	if pulsed and config.launch_speed > 0.0:
		for player: PlayerController in players:
			if _launched.has(player):
				continue
			_launched.append(player)
			player.launch_along(direction, config.launch_speed)
			_give_income(player)
		return
	for player: PlayerController in players:
		player.push_toward(direction, config.strength, config.accel)
	if not pulsed:
		for player: PlayerController in entered:
			_give_income(player)


func _give_income(player: PlayerController) -> void:
	if energy_relation == EnergyRelation.GIVES and config.income_steps > 0:
		grant_step(player, config.income_steps, config.income_cooldown, StringName(name))


## Look nodes that follow the pulse: the burst column shows (and grows) while the volume acts.
func _apply_look() -> void:
	if _column == null:
		return
	if config.timing == ForceVolumeConfig.Timing.PULSED:
		_column.visible = _pulse_is_on
		_column.scale.y = clampf(_pulse_timer / COLUMN_GROW, 0.05, 1.0) if _pulse_is_on else 0.05
	else:
		_column.visible = true
