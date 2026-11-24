class_name CatchLaunch
extends KitBlock
## Catch & launch block (Phase 05.1, KIT-03, D-01..D-05, D-17): a trigger sphere that catches a player who enters it and hands the
## hold to the player's own Loader state. FREE_AIM (slingshot cage) asks PlayerController.catch_into_loader with a CAGE LoaderProfile
## whose min_push is read from the player's MovementConfig at catch time (never copied), so the cage plays exactly like the Loader:
## same slow world, cap, free camera and throw math, minus bonus, energy and redirect cooldown. FIXED (steam cannon, D-05) asks for a
## FIXED LoaderProfile: Rino is pulled to the barrel mouth (muzzle_offset along the barrel), held fixed_hold with no slow motion and
## no input, and launched along the barrel at fixed_speed whatever the entry. The barrel direction is the block's yaw-only forward
## pitched up by fixed_pitch_deg; the trigger is never pitched (the old nozzle cannon tilted its volume with the barrel), and an
## optional `Barrel` child is pitched to match. The overlap callback runs inside the physics flush, so the request goes through
## call_deferred; the block never writes the player's velocity. Arming: ARMED -> CAPTURING (while the caught hold runs) -> COOLDOWN
## (rearm_time, and not while a player is inside the radius) -> ARMED; MAX_WAIT ends a stuck CAPTURING (T-05.1-02, T-05.1-06). A
## player already in a Loader hold is not caught (T-05.1-04).

enum Phase { ARMED, CAPTURING, COOLDOWN }

## Longest wait in s for a caught hold to end before the block rearms anyway.
const MAX_WAIT: float = 6.0
## Seconds the caught hold has to show up in the player's state before a missing one counts as ended.
const START_GRACE: float = 0.1

## The block's config; the instance works on its own copy (D-12).
@export var config: CatchLaunchConfig

var _phase: Phase = Phase.ARMED
var _timer: float = 0.0
var _captured: PlayerController = null
## The LoaderProfile source this block's last catch asked for (CAGE or FIXED).
var _issued: LoaderProfile.Source = LoaderProfile.Source.CAGE

@onready var _trigger: Area3D = $Trigger


func _ready() -> void:
	if config == null:
		config = CatchLaunchConfig.new()
	config = own_config(config) as CatchLaunchConfig
	_trigger.collision_layer = 0
	_trigger.collision_mask = PhysicsLayers.PLAYER
	var shape_node: CollisionShape3D = $Trigger/CollisionShape3D as CollisionShape3D
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = config.radius
	shape_node.shape = sphere
	_trigger.body_entered.connect(_on_body_entered)
	var barrel: Node3D = get_node_or_null(^"Barrel") as Node3D
	if barrel != null and config.profile == CatchLaunchConfig.Profile.FIXED:
		barrel.rotation = Vector3(deg_to_rad(config.fixed_pitch_deg), 0.0, 0.0)


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.CAPTURING:
			_timer += delta
			if (_timer > START_GRACE and not _holding()) or _timer > MAX_WAIT:
				_phase = Phase.COOLDOWN
				_timer = config.rearm_time
		Phase.COOLDOWN:
			_timer -= delta
			if _timer <= 0.0 and not _player_inside():
				_phase = Phase.ARMED
				_captured = null


## True while the block catches.
func is_armed() -> bool:
	return _phase == Phase.ARMED


func reset() -> void:
	super.reset()
	_phase = Phase.ARMED
	_timer = 0.0
	_captured = null


## The profile handed to the player for this block's catch: FREE_AIM a CAGE hold with the player's loader_min_push, FIXED a hold at
## the barrel mouth that launches along the barrel at fixed_speed after fixed_hold.
func profile_for(player: PlayerController) -> LoaderProfile:
	if config.profile != CatchLaunchConfig.Profile.FIXED:
		return LoaderProfile.cage(player.config.loader_min_push)
	var profile: LoaderProfile = LoaderProfile.new()
	profile.source = LoaderProfile.Source.FIXED
	profile.direction = barrel_direction()
	profile.anchor = muzzle_point()
	profile.speed = config.fixed_speed
	profile.hold = config.fixed_hold
	return profile


## FIXED: the unit launch direction, the block's yaw-only forward (-Z) pitched up by fixed_pitch_deg.
func barrel_direction() -> Vector3:
	var forward: Vector3 = -global_basis.z
	forward.y = 0.0
	if not forward.is_finite() or forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	var pitch: float = deg_to_rad(config.fixed_pitch_deg)
	return (forward.normalized() * cos(pitch) + Vector3.UP * sin(pitch)).normalized()


## FIXED: the world point Rino's origin is pulled to and launched from (the barrel mouth).
func muzzle_point() -> Vector3:
	return global_position + barrel_direction() * config.muzzle_offset


func _on_body_entered(body: Node3D) -> void:
	var player: PlayerController = body as PlayerController
	if player == null or _phase != Phase.ARMED or player.loader_active():
		return
	var profile: LoaderProfile = profile_for(player)
	_phase = Phase.CAPTURING
	_timer = 0.0
	_captured = player
	_issued = profile.source
	player.call_deferred(&"catch_into_loader", profile)


## True while the caught player is in a Loader hold of the source this block asked for.
func _holding() -> bool:
	if _captured == null or not is_instance_valid(_captured) or not _captured.loader_active():
		return false
	var state: LoaderState = _captured.loader_state()
	return state != null and state.source() == _issued


func _player_inside() -> bool:
	for body: Node3D in _trigger.get_overlapping_bodies():
		if body is PlayerController:
			return true
	return false
