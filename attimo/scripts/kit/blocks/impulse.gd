class_name Impulse
extends KitBlock
## Impulse block (Phase 05.1, KIT-01, D-10, D-11, D-24, D-43): a one-shot kick. One script, one ImpulseConfig (Profile BOOST / PAD /
## BOUNCE) per object, a look as an inherited scene. The boost ring (air-dash counterpart: boosts along its axis and gives the air dash
## back), the speed pad (dash-hop counterpart, replaces the conveyors, D-25: a short forward boost on the ground) and the bounce pad are
## presets of it; the bounce pad with core is the same profile with an Amplification child (more steps, higher bounce). BOUNCE listens
## to EventBus.landed and checks the landing spot against its top face instead of using an overlap, because a terminal-speed fall would
## tunnel through a thin trigger. A GIVES block gives steps on use through KitBlock.grant_step with its per-block cooldown. The block
## never writes the player's motion itself, kicks go through call_deferred on the PlayerController request APIs (D-17).

## Smallest trigger edge in m (a zero edge would never overlap).
const MIN_EDGE: float = 0.5
## BOUNCE: how far from the top face a landing still counts, in m.
const TOP_TOLERANCE: float = 0.4

## The block's config; the instance works on its own copy (D-12).
@export var config: ImpulseConfig

var _armed: bool = true
var _rearm_timer: float = 0.0

@onready var _volume: Area3D = $Volume
@onready var _body: StaticBody3D = get_node_or_null(^"Body") as StaticBody3D
@onready var _amplification: Amplification = get_node_or_null(^"Amplification") as Amplification


func _ready() -> void:
	if config == null:
		config = ImpulseConfig.new()
	config = own_config(config) as ImpulseConfig
	_volume.collision_layer = 0
	_volume.collision_mask = PhysicsLayers.PLAYER
	var size: Vector3 = trigger_size()
	match config.profile:
		ImpulseConfig.Profile.BOOST:
			_set_box(size, Vector3.ZERO)
			_volume.body_entered.connect(_on_body_entered)
		ImpulseConfig.Profile.PAD:
			_set_box(size, Vector3(0.0, size.y * 0.5, 0.0))
		ImpulseConfig.Profile.BOUNCE:
			_volume.monitoring = false
			if _body != null:
				_body.collision_layer = PhysicsLayers.WORLD
				_body.collision_mask = 0
				var box: BoxShape3D = BoxShape3D.new()
				box.size = config.size
				var shape_node: CollisionShape3D = $Body/CollisionShape3D as CollisionShape3D
				shape_node.shape = box
				shape_node.position = Vector3(0.0, config.size.y * 0.5, 0.0)
			EventBus.landed.connect(_on_landed)


func _exit_tree() -> void:
	if EventBus.landed.is_connected(_on_landed):
		EventBus.landed.disconnect(_on_landed)


func _physics_process(delta: float) -> void:
	if _rearm_timer > 0.0:
		_rearm_timer = maxf(_rearm_timer - delta, 0.0)
		if _rearm_timer <= 0.0:
			_armed = true
	if config.profile != ImpulseConfig.Profile.PAD or not _armed:
		return
	for body: Node3D in _volume.get_overlapping_bodies():
		var player: PlayerController = body as PlayerController
		if player != null and player.is_grounded():
			_kick(player, Vector3.ZERO)
			return


## The clamped trigger size in m.
func trigger_size() -> Vector3:
	return Vector3(maxf(config.size.x, MIN_EDGE), maxf(config.size.y, MIN_EDGE), maxf(config.size.z, MIN_EDGE))


## World direction of the axis / forward (the config direction turned by the node), or ZERO for a zero direction.
func world_direction() -> Vector3:
	var local: Vector3 = config.direction
	if not local.is_finite() or local.length_squared() < 0.0001:
		return Vector3.ZERO
	return (global_basis * local).normalized()


func reset() -> void:
	super.reset()
	_armed = true
	_rearm_timer = 0.0


func _set_box(size: Vector3, centre: Vector3) -> void:
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	var shape_node: CollisionShape3D = $Volume/CollisionShape3D as CollisionShape3D
	shape_node.shape = box
	shape_node.position = centre


func _on_body_entered(body: Node3D) -> void:
	var player: PlayerController = body as PlayerController
	if player == null or not _armed or config.profile != ImpulseConfig.Profile.BOOST:
		return
	_kick(player, Vector3.ZERO)


func _on_landed(position: Vector3, impact_speed: float) -> void:
	if not _armed or not is_finite(impact_speed):
		return
	var local: Vector3 = to_local(position)
	if absf(local.x) > config.size.x * 0.5 + 0.1 or absf(local.z) > config.size.z * 0.5 + 0.1:
		return
	if absf(local.y - config.size.y) > TOP_TOLERANCE:
		return
	var player: PlayerController = get_tree().get_first_node_in_group(&"player") as PlayerController
	if player == null or player.config == null:
		return
	_kick(player, Vector3(impact_speed, 0.0, 0.0))


## One kick. `landing.x` is the impact speed of a BOUNCE landing.
func _kick(player: PlayerController, landing: Vector3) -> void:
	_armed = false
	_rearm_timer = config.rearm_time
	match config.profile:
		ImpulseConfig.Profile.BOOST:
			var direction: Vector3 = world_direction()
			if direction == Vector3.ZERO:
				return
			var velocity: Vector3 = Vector3(player.move_velocity.x, player.vertical_speed, player.move_velocity.z)
			var side: float = signf(velocity.dot(direction))
			if side == 0.0:
				side = 1.0
			player.call_deferred(&"boost_along", direction * side, config.speed, config.add)
			player.call_deferred(&"refill_air_dash")
		ImpulseConfig.Profile.PAD:
			var forward: Vector3 = world_direction()
			if forward == Vector3.ZERO:
				return
			forward.y = 0.0
			player.call_deferred(&"boost_along", forward.normalized(), config.speed, config.add)
		ImpulseConfig.Profile.BOUNCE:
			# The bounce returns the drop height (times restitution) under the rise gravity. Reusing the impact speed would gain energy on
			# every bounce, because the fall gravity is heavier than the rise gravity (WR-01). launch_along applies the kit scale itself.
			var drop_height: float = landing.x * landing.x / (2.0 * player.config.fall_gravity())
			var amp: float = _amplification.factor(player) if _amplification != null else 1.0
			var bounce: float = minf(maxf(player.config.jump_speed(drop_height * config.restitution), config.speed) * amp, config.max_speed)
			player.call_deferred(&"launch_along", Vector3.UP, bounce)
	if energy_relation == EnergyRelation.GIVES and config.income_steps > 0:
		grant_step(player, config.income_steps, config.income_cooldown, StringName(name))
