class_name ReactionToLoad
extends KitBlock
## Reaction to load block (Phase 05.1, KIT-01, KIT-02, D-53, D-17): how an object answers a Loader that flies into it. LOADER_FIELD
## is the turquoise Loader field. It is a solid field on the World layer that never breaks or hides. A sensor box around it, deeper
## than the field on both sides by LEAD (a 22 m/s flight at 10 TPS covers 2.2 m per tick, so it is seen a full tick before it touches
## the field), watches the player. A player in the sensor whose straight flight paid at least config.min_steps steps (a Loader
## discharge; the slingshot cage flight pays 0) is let through: the block adds a collision exception for the field body DIRECTLY
## (a deferred call could land after the contact, which would set is_on_wall and end the flight), asks for scale_speed(1 - brake)
## once (deferred) and shows the ripple cue. Everyone else (walking, a dash, a 1-step Loader, the cage) is softly pushed back through
## push_toward. The exception goes when the player leaves the sensor and in reset(). The block never writes the player's motion (D-17).
## The nature profiles (plan 05.1-21, D-11, D-27) are the same block with another reaction: CRUMBLE (a deck, or a strip of `segments`
## decks, that shakes, falls and respawns), SINK (a deck that gives way under a rider), TIP (a trunk that tips about its middle under a rider,
## below the floor angle), DROP (debris that falls when the player comes close) and BITE (a plant that snaps after a windup). SINK and TIP are
## AnimatableBody3D decks in the group carrying_platform, direct children of the block, ticking after the player (priority 100) with
## carry_velocity_at, the same carry contract as Timed motion. DROP and BITE hurt through a DamagePush child watching a hit area whose shape
## is armed and disarmed here. Nature never helps and never touches energy: nothing here pays the player anything.
## The ripple cue is a `Ripple` child that grows and fades in real time (TimeFx.unscaled), no particles; _process only runs while it shows.

## Metres the sensor reaches beyond the field on each side: loader_max_speed (22 m/s) / 10 TPS plus half a metre.
const LEAD: float = 2.7
## Extra width and height of the sensor beyond the field, so a diagonal approach is seen too.
const SENSOR_MARGIN: float = 1.0
## The soft push only acts this close (m) to the field face; further out the player is only watched.
const PUSH_RANGE: float = 1.2
## Acceleration in m/s^2 of the soft push.
const PUSH_ACCEL: float = 60.0
## Scale of the ripple at its start and at its end.
const RIPPLE_SCALE_FROM: float = 0.9
const RIPPLE_SCALE_TO: float = 1.15

## Nature profiles: where the deck top sits above the block origin (never coplanar with a floor at the origin height).
const TOP_LIP: float = 0.05
## CRUMBLE: shake amplitude in m and how far the mesh drops while falling.
const SHAKE_AMPLITUDE: float = 0.03
const FALL_DROP: float = 1.0
## Height in m of the standing sensor over a deck top and of the footprint box that holds a respawn back.
const SENSE_HEIGHT: float = 0.3
const FOOTPRINT_HEIGHT: float = 2.0
## SINK and TIP tick after the player (the carry contract of Timed motion).
const TICK_AFTER_PLAYER: int = 100
const FALLBACK_FLOOR_ANGLE_DEG: float = 50.0
## The tip stays this many degrees below the player's floor angle.
const FLOOR_ANGLE_MARGIN_DEG: float = 10.0
## DROP: seconds of warning shake before the debris falls, and its fall acceleration in m/s^2.
const DROP_DELAY: float = 0.5
const DROP_GRAVITY: float = 20.0
## BITE: seconds the bite hurts, and how wide the jaws open at the end of the windup.
const BITE_ACTIVE: float = 0.25
const JAW_OPEN_DEG: float = 55.0

enum CrumblePhase { IDLE, ARMED, SHAKE, FALL, GONE }
enum DropState { HANG, WARN, FALL, LANDED }
enum BiteState { IDLE, WINDUP, BITE, COOLDOWN }

## The block's config; the instance works on its own copy (D-12).
@export var config: ReactionToLoadConfig

## The player that is let through right now (until it leaves the sensor), or null.
var _passing: PlayerController = null
var _ripple_left: float = 0.0
var _ripple: MeshInstance3D = null

## Nature state. Decks: the scene's Body is deck 0, CRUMBLE strips duplicate it. Each deck has a standing sensor, CRUMBLE also a footprint.
var _decks: Array[AnimatableBody3D] = []
var _visuals: Array[Node3D] = []
var _visual_rest: Array[Vector3] = []
var _senses: Array[Area3D] = []
var _footprints: Array[Area3D] = []
var _crumble: PackedInt32Array = PackedInt32Array()
var _timers: PackedFloat32Array = PackedFloat32Array()
var _deck_velocity: Vector3 = Vector3.ZERO
var _offset: float = 0.0
var _tip_angle: float = 0.0
var _tip_sign: float = 0.0
var _tip_omega: float = 0.0
var _tip_limit: float = 0.0
var _limit_from_player: bool = false
var _proximity: Area3D = null
var _prop: Node3D = null
var _prop_rest: Vector3 = Vector3.ZERO
var _hit_shape: CollisionShape3D = null
var _state: int = 0
var _state_timer: float = 0.0
var _fall_speed: float = 0.0
var _jaw: Node3D = null

@onready var _field: StaticBody3D = get_node_or_null(^"Field") as StaticBody3D
@onready var _sensor: Area3D = get_node_or_null(^"Sensor") as Area3D


func _ready() -> void:
	if config == null:
		config = ReactionToLoadConfig.new()
	config = own_config(config) as ReactionToLoadConfig
	match config.profile:
		ReactionToLoadConfig.Profile.LOADER_FIELD:
			_ready_field()
		ReactionToLoadConfig.Profile.DROP:
			_ready_drop()
		ReactionToLoadConfig.Profile.BITE:
			_ready_bite()
		_:
			_ready_deck()


func _ready_field() -> void:
	# The block runs before the player in a tick, so the pass exception is in place before the player moves.
	process_physics_priority = -20
	var size: Vector3 = config.field_size
	_field.collision_layer = PhysicsLayers.WORLD
	_field.collision_mask = 0
	_field.position = Vector3(0.0, size.y * 0.5, 0.0)
	_set_box(_field.get_node("CollisionShape3D") as CollisionShape3D, size)
	_sensor.collision_layer = 0
	_sensor.collision_mask = PhysicsLayers.PLAYER
	_sensor.position = _field.position
	_set_box(_sensor.get_node("CollisionShape3D") as CollisionShape3D, Vector3(size.x + SENSOR_MARGIN * 2.0, size.y + SENSOR_MARGIN, size.z + LEAD * 2.0))
	_sensor.body_entered.connect(_on_body_entered)
	_sensor.body_exited.connect(_on_body_exited)
	_ripple = get_node_or_null(^"Ripple") as MeshInstance3D
	_hide_ripple()


func _set_box(shape_node: CollisionShape3D, size: Vector3) -> void:
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box


func _physics_process(delta: float) -> void:
	match config.profile:
		ReactionToLoadConfig.Profile.CRUMBLE:
			_tick_crumble(delta)
			return
		ReactionToLoadConfig.Profile.SINK:
			_tick_sink(delta)
			return
		ReactionToLoadConfig.Profile.TIP:
			_tick_tip(delta)
			return
		ReactionToLoadConfig.Profile.DROP:
			_tick_drop(delta)
			return
		ReactionToLoadConfig.Profile.BITE:
			_tick_bite(delta)
			return
	for body: Node3D in _sensor.get_overlapping_bodies():
		var player: PlayerController = body as PlayerController
		if player != null:
			_react(player)


func _process(delta: float) -> void:
	if _ripple == null or _ripple_left <= 0.0:
		set_process(false)
		return
	_ripple_left = maxf(_ripple_left - TimeFx.unscaled(delta), 0.0)
	if _ripple_left <= 0.0:
		_hide_ripple()
		return
	var progress: float = 1.0 - _ripple_left / config.ripple_time
	_ripple.scale = Vector3.ONE * lerpf(RIPPLE_SCALE_FROM, RIPPLE_SCALE_TO, progress)
	_ripple.transparency = progress


func _on_body_entered(body: Node3D) -> void:
	var player: PlayerController = body as PlayerController
	if player != null:
		_react(player)


func _on_body_exited(body: Node3D) -> void:
	var player: PlayerController = body as PlayerController
	if player != null and player == _passing:
		player.allow_pass_through(_field, false)
		_passing = null


## True when `player` flies a Loader straight flight that paid enough steps to pass.
func can_pass(player: PlayerController) -> bool:
	return player.straight_flight_left > 0.0 and player.straight_flight_steps >= config.min_steps


## One reaction to a player inside the sensor: the pass (once per crossing) or the soft push back.
func _react(player: PlayerController) -> void:
	if _passing == player:
		return
	if can_pass(player):
		_passing = player
		player.allow_pass_through(_field, true)
		player.call_deferred(&"scale_speed", 1.0 - config.brake)
		_show_ripple()
		return
	var normal: Vector3 = global_basis.z.normalized()
	var side: float = (player.global_position - global_position).dot(normal)
	if side < 0.0:
		normal = -normal
	if absf(side) - config.field_size.z * 0.5 <= PUSH_RANGE:
		player.push_toward(normal, config.push_back_speed, PUSH_ACCEL)


func _show_ripple() -> void:
	if _ripple == null:
		return
	_ripple_left = config.ripple_time
	_ripple.scale = Vector3.ONE * RIPPLE_SCALE_FROM
	_ripple.transparency = 0.0
	_ripple.visible = true
	set_process(true)


func _hide_ripple() -> void:
	_ripple_left = 0.0
	if _ripple != null:
		_ripple.visible = false
		_ripple.scale = Vector3.ONE
	set_process(false)


func reset() -> void:
	super.reset()
	if config.profile != ReactionToLoadConfig.Profile.LOADER_FIELD:
		_reset_nature()
		return
	if _passing != null and is_instance_valid(_passing):
		_passing.allow_pass_through(_field, false)
	_passing = null
	_hide_ripple()


# --- Nature profiles (plan 05.1-21) -------------------------------------------------------------------------------------------------


## The decks, deck 0 first (CRUMBLE, SINK, TIP).
func decks() -> Array[AnimatableBody3D]:
	return _decks


## CRUMBLE: the CrumblePhase (as int) of deck `index`, IDLE for a bad index.
func crumble_phase(index: int) -> int:
	return _crumble[index] if index >= 0 and index < _crumble.size() else CrumblePhase.IDLE


## The deck's chord in world space for a rider at `point`: SINK moves straight, TIP turns about the block origin; others carry nobody.
func carry_velocity_at(point: Vector3, delta: float) -> Vector3:
	if delta <= 0.0 or not is_finite(delta) or not point.is_finite():
		return Vector3.ZERO
	if config.profile == ReactionToLoadConfig.Profile.SINK:
		return global_basis * _deck_velocity
	if config.profile == ReactionToLoadConfig.Profile.TIP:
		var relative: Vector3 = point - global_position
		var axis: Vector3 = (global_basis * Vector3.RIGHT).normalized()
		return (Basis(axis, _tip_omega * delta) * relative - relative) / delta
	return Vector3.ZERO


func _ready_deck() -> void:
	var body: AnimatableBody3D = get_node("Body") as AnimatableBody3D
	body.sync_to_physics = false
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var size: Vector3 = config.deck_size
	var shape_node: CollisionShape3D = body.get_node("CollisionShape3D") as CollisionShape3D
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	shape_node.position = Vector3(0.0, TOP_LIP - size.y * 0.5, 0.0)
	var visual: Node3D = body.get_node_or_null("Visual") as Node3D
	if visual != null:
		visual.position = Vector3(0.0, TOP_LIP - size.y * 0.5, 0.0)
		var main: MeshInstance3D = visual.get_child(0) as MeshInstance3D if visual.get_child_count() > 0 else null
		if main != null:
			var mesh: BoxMesh = BoxMesh.new()
			mesh.size = size
			main.mesh = mesh
	_decks.append(body)
	if config.profile == ReactionToLoadConfig.Profile.CRUMBLE:
		for index: int in range(1, config.segments):
			var deck: AnimatableBody3D = body.duplicate() as AnimatableBody3D
			deck.name = "Deck%d" % index
			deck.position = Vector3(0.0, 0.0, -size.z * float(index))
			add_child(deck)
			_decks.append(deck)
	for deck: AnimatableBody3D in _decks:
		var deck_visual: Node3D = deck.get_node_or_null("Visual") as Node3D
		_visuals.append(deck_visual)
		_visual_rest.append(deck_visual.position if deck_visual != null else Vector3.ZERO)
		_senses.append(_make_area(deck, _box(Vector3(size.x, SENSE_HEIGHT, size.z)), Vector3(0.0, TOP_LIP + SENSE_HEIGHT * 0.5 - 0.15, 0.0)))
		if config.profile == ReactionToLoadConfig.Profile.CRUMBLE:
			_footprints.append(_make_area(deck, _box(Vector3(size.x, FOOTPRINT_HEIGHT, size.z)), Vector3(0.0, 0.5, 0.0)))
	_crumble.resize(_decks.size())
	_crumble.fill(CrumblePhase.IDLE)
	_timers.resize(_decks.size())
	_timers.fill(0.0)
	if config.profile != ReactionToLoadConfig.Profile.CRUMBLE:
		for deck: AnimatableBody3D in _decks:
			deck.add_to_group(&"carrying_platform")
		process_physics_priority = TICK_AFTER_PLAYER
	_resolve_tip_limit()


func _ready_drop() -> void:
	_prop = get_node("Debris") as Node3D
	_prop.position = Vector3(0.0, config.drop_height, 0.0)
	_prop_rest = _prop.position
	_hit_shape = _prop.get_node("Hit/CollisionShape3D") as CollisionShape3D
	_hit_shape.disabled = true
	_proximity = _make_area(self, _sphere(config.trigger_radius), Vector3(0.0, 0.9, 0.0))
	_state = DropState.HANG


func _ready_bite() -> void:
	_hit_shape = get_node("Mouth/CollisionShape3D") as CollisionShape3D
	_hit_shape.disabled = true
	_jaw = get_node_or_null(^"Jaws/Upper") as Node3D
	_proximity = _make_area(self, _sphere(config.trigger_radius), Vector3(0.0, 0.9, 0.0))
	_state = BiteState.IDLE


func _box(size: Vector3) -> BoxShape3D:
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	return box


func _sphere(radius: float) -> SphereShape3D:
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	return sphere


## A sensor Area3D under `parent` that sees the player only.
func _make_area(parent: Node3D, shape: Shape3D, center: Vector3) -> Area3D:
	var area: Area3D = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = PhysicsLayers.PLAYER
	var node: CollisionShape3D = CollisionShape3D.new()
	node.shape = shape
	node.position = center
	area.add_child(node)
	parent.add_child(area)
	return area


func _player_in(area: Area3D) -> PlayerController:
	for body: Node3D in area.get_overlapping_bodies():
		var player: PlayerController = body as PlayerController
		if player != null:
			return player
	return null


## Arms or disarms the hit volume (the shape, never the monitoring: DamagePush reads the overlaps every tick).
func _arm_hit(armed: bool) -> void:
	if _hit_shape != null:
		_hit_shape.set_deferred(&"disabled", not armed)


func _tick_crumble(delta: float) -> void:
	for index: int in _decks.size():
		match _crumble[index]:
			CrumblePhase.IDLE:
				if _player_in(_senses[index]) != null:
					_crumble[index] = CrumblePhase.ARMED if config.segments > 1 else CrumblePhase.SHAKE
					_timers[index] = 0.0
			CrumblePhase.ARMED:
				_timers[index] += delta
				if _timers[index] >= config.segment_delay:
					_crumble[index] = CrumblePhase.SHAKE
					_timers[index] = 0.0
			CrumblePhase.SHAKE:
				_timers[index] += delta
				_move_visual(index, Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * SHAKE_AMPLITUDE)
				if _timers[index] >= config.delay:
					_crumble[index] = CrumblePhase.FALL
					_timers[index] = 0.0
					_decks[index].get_node("CollisionShape3D").set_deferred(&"disabled", true)
			CrumblePhase.FALL:
				_timers[index] += delta
				_move_visual(index, Vector3.DOWN * FALL_DROP * minf(_timers[index] / maxf(config.fall_time, 0.01), 1.0))
				if _timers[index] >= config.fall_time:
					_crumble[index] = CrumblePhase.GONE
					_timers[index] = 0.0
					if _visuals[index] != null:
						_visuals[index].visible = false
			CrumblePhase.GONE:
				_timers[index] += delta
				if _timers[index] >= config.respawn_time and _player_in(_footprints[index]) == null:
					_restore_deck(index)


func _move_visual(index: int, shift: Vector3) -> void:
	if _visuals[index] != null:
		_visuals[index].position = _visual_rest[index] + shift


func _restore_deck(index: int) -> void:
	_crumble[index] = CrumblePhase.IDLE
	_timers[index] = 0.0
	_decks[index].get_node("CollisionShape3D").set_deferred(&"disabled", false)
	if _visuals[index] != null:
		_visuals[index].position = _visual_rest[index]
		_visuals[index].visible = true
		_visuals[index].reset_physics_interpolation()


func _tick_sink(delta: float) -> void:
	var occupied: bool = _player_in(_senses[0]) != null
	var before: Vector3 = _decks[0].position
	var speed: float = config.sink_speed if occupied else config.rise_speed
	_offset = move_toward(_offset, -config.sink_depth if occupied else 0.0, speed * delta)
	_decks[0].position = Vector3(0.0, _offset, 0.0)
	_deck_velocity = (_decks[0].position - before) / maxf(delta, 0.0001)


func _tick_tip(delta: float) -> void:
	if not _limit_from_player:
		_resolve_tip_limit()
	var player: PlayerController = _player_in(_senses[0])
	if player != null and _tip_sign == 0.0:
		_tip_sign = 1.0 if _decks[0].to_local(player.global_position).z >= 0.0 else -1.0
	var occupied: bool = player != null
	var rate: float = _tip_limit / maxf(config.tip_time if occupied else config.return_time, 0.05)
	var previous: float = _tip_angle
	_tip_angle = move_toward(_tip_angle, _tip_sign * _tip_limit if occupied else 0.0, rate * delta)
	_tip_omega = (_tip_angle - previous) / maxf(delta, 0.0001)
	_decks[0].transform = Transform3D(Basis(Vector3.RIGHT, _tip_angle), Vector3.ZERO)
	if not occupied and is_zero_approx(_tip_angle):
		_tip_sign = 0.0


## The tip never exceeds the player's floor angle minus a margin, so a rider never slides off by physics.
func _resolve_tip_limit() -> void:
	var cap: float = FALLBACK_FLOOR_ANGLE_DEG
	var player: PlayerController = get_tree().get_first_node_in_group(&"player") as PlayerController if is_inside_tree() else null
	if player != null and player.config != null:
		cap = player.config.floor_max_angle_deg
		_limit_from_player = true
	_tip_limit = deg_to_rad(minf(config.tip_angle_deg, cap - FLOOR_ANGLE_MARGIN_DEG))


func _tick_drop(delta: float) -> void:
	match _state:
		DropState.HANG:
			if _player_in(_proximity) != null:
				_state = DropState.WARN
				_state_timer = 0.0
		DropState.WARN:
			_state_timer += delta
			_prop.position = _prop_rest + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * SHAKE_AMPLITUDE
			if _state_timer >= DROP_DELAY:
				_state = DropState.FALL
				_fall_speed = 0.0
				_prop.position = _prop_rest
				_arm_hit(true)
		DropState.FALL:
			_fall_speed += DROP_GRAVITY * delta
			_prop.position.y = maxf(_prop.position.y - _fall_speed * delta, 0.0)
			if _prop.position.y <= 0.0:
				_state = DropState.LANDED
				_state_timer = 0.0
				_arm_hit(false)
		DropState.LANDED:
			_state_timer += delta
			if _state_timer >= config.respawn_time:
				_restore_drop()


func _restore_drop() -> void:
	_state = DropState.HANG
	_state_timer = 0.0
	_fall_speed = 0.0
	_arm_hit(false)
	if _prop != null:
		_prop.position = _prop_rest
		_prop.reset_physics_interpolation()


func _tick_bite(delta: float) -> void:
	match _state:
		BiteState.IDLE:
			if _player_in(_proximity) != null:
				_state = BiteState.WINDUP
				_state_timer = 0.0
		BiteState.WINDUP:
			_state_timer += delta
			_set_jaw(minf(_state_timer / maxf(config.windup, 0.01), 1.0))
			if _state_timer >= config.windup:
				_state = BiteState.BITE
				_state_timer = 0.0
				_set_jaw(0.0)
				_arm_hit(true)
		BiteState.BITE:
			_state_timer += delta
			if _state_timer >= BITE_ACTIVE:
				_state = BiteState.COOLDOWN
				_state_timer = 0.0
				_arm_hit(false)
		BiteState.COOLDOWN:
			_state_timer += delta
			if _state_timer >= config.cooldown:
				_state = BiteState.IDLE
				_state_timer = 0.0


## Jaw opening 0 (shut) .. 1 (wide), a rotation of the upper jaw pivot.
func _set_jaw(open: float) -> void:
	if _jaw != null:
		_jaw.rotation.x = -deg_to_rad(JAW_OPEN_DEG) * open


func _reset_nature() -> void:
	match config.profile:
		ReactionToLoadConfig.Profile.CRUMBLE:
			for index: int in _decks.size():
				_restore_deck(index)
		ReactionToLoadConfig.Profile.SINK:
			_offset = 0.0
			_deck_velocity = Vector3.ZERO
			_decks[0].position = Vector3.ZERO
			_decks[0].reset_physics_interpolation()
		ReactionToLoadConfig.Profile.TIP:
			_tip_angle = 0.0
			_tip_sign = 0.0
			_tip_omega = 0.0
			_decks[0].transform = Transform3D.IDENTITY
			_decks[0].reset_physics_interpolation()
		ReactionToLoadConfig.Profile.DROP:
			_restore_drop()
		ReactionToLoadConfig.Profile.BITE:
			_state = BiteState.IDLE
			_state_timer = 0.0
			_arm_hit(false)
			_set_jaw(0.0)
