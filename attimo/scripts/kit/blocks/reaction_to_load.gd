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

## The block's config; the instance works on its own copy (D-12).
@export var config: ReactionToLoadConfig

## The player that is let through right now (until it leaves the sensor), or null.
var _passing: PlayerController = null
var _ripple_left: float = 0.0
var _ripple: MeshInstance3D = null

@onready var _field: StaticBody3D = $Field
@onready var _sensor: Area3D = $Sensor


func _ready() -> void:
	# The block runs before the player in a tick, so the pass exception is in place before the player moves.
	process_physics_priority = -20
	if config == null:
		config = ReactionToLoadConfig.new()
	config = own_config(config) as ReactionToLoadConfig
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


func _physics_process(_delta: float) -> void:
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
	if _passing != null and is_instance_valid(_passing):
		_passing.allow_pass_through(_field, false)
	_passing = null
	_hide_ripple()
