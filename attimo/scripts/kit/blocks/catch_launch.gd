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
## Steam cues (plan 05.1-05, D-01, D-26, look only, no particles): an optional `SteamPuff` mesh shows briefly on every catch, an
## optional `SteamBlast` greybox column shows on this block's own throw (the CAGE `loader_released` fact or the FIXED `launched` fact
## while this block's hold runs, near the block) and scales out, hidden within BLAST_TIME of real time. The cage turns the blast
## against the throw direction (the exhaust); the cannon's blast sits in its pitched Barrel. Both cues run in real time
## (TimeFx.unscaled), so the slow world and the hitstop do not stretch them, and _process only runs while a cue is shown.

enum Phase { ARMED, CAPTURING, COOLDOWN }

## Longest wait in s for a caught hold to end before the block rearms anyway.
const MAX_WAIT: float = 6.0
## Seconds the caught hold has to show up in the player's state before a missing one counts as ended.
const START_GRACE: float = 0.1
## Real seconds the SteamBlast column shows after a throw (under the 0.3 s look budget) and the SteamPuff after a catch.
const BLAST_TIME: float = 0.22
const PUFF_TIME: float = 0.25
## Scale of a cue mesh at its start and at its end (it grows as it fades out).
const CUE_SCALE_FROM: float = 0.4
const CUE_SCALE_TO: float = 1.3
## Extra metres beyond the trigger radius in which a release fact counts as this block's throw (the cage freezes Rino where his
## capsule first touches the sphere, up to about one capsule radius outside it).
const CUE_REACH_MARGIN: float = 1.0

## The block's config; the instance works on its own copy (D-12).
@export var config: CatchLaunchConfig

var _phase: Phase = Phase.ARMED
var _timer: float = 0.0
var _captured: PlayerController = null
## The LoaderProfile source this block's last catch asked for (CAGE or FIXED).
var _issued: LoaderProfile.Source = LoaderProfile.Source.CAGE

## Real seconds left on the two cues (0 = hidden).
var _blast_left: float = 0.0
var _puff_left: float = 0.0
var _blast: Node3D = null
var _puff: Node3D = null

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
	_blast = find_child("SteamBlast", true, false) as Node3D
	_puff = find_child("SteamPuff", true, false) as Node3D
	_hide_cues()
	EventBus.loader_released.connect(_on_loader_released)
	EventBus.launched.connect(_on_launched)


func _process(delta: float) -> void:
	var real: float = TimeFx.unscaled(delta)
	_blast_left = _step_cue(_blast, _blast_left, BLAST_TIME, real)
	_puff_left = _step_cue(_puff, _puff_left, PUFF_TIME, real)
	if _blast_left <= 0.0 and _puff_left <= 0.0:
		set_process(false)


## Counts one cue down by `real` seconds, scales it out over `length` and hides it at the end. Returns the time left.
func _step_cue(cue: Node3D, left: float, length: float, real: float) -> float:
	if cue == null or left <= 0.0:
		return 0.0
	left = maxf(left - real, 0.0)
	if left <= 0.0:
		cue.visible = false
		return 0.0
	cue.scale = Vector3.ONE * lerpf(CUE_SCALE_FROM, CUE_SCALE_TO, 1.0 - left / length)
	return left


func _show_cue(cue: Node3D) -> float:
	if cue == null:
		return 0.0
	cue.scale = Vector3.ONE * CUE_SCALE_FROM
	cue.visible = true
	set_process(true)
	return 1.0


func _hide_cues() -> void:
	_blast_left = 0.0
	_puff_left = 0.0
	for cue: Node3D in [_blast, _puff]:
		if cue != null:
			cue.visible = false
			cue.scale = Vector3.ONE
	set_process(false)


## The CAGE throw fact: shows the SteamBlast when the throw is this block's own hold (D-01 steam blast on release).
func _on_loader_released(position: Vector3, direction: Vector3, _speed: float, _steps: int) -> void:
	if not _own_throw(LoaderProfile.Source.CAGE, position, global_position):
		return
	if _blast != null and direction.is_finite() and direction.length_squared() > 0.0001:
		# The column's +Y is its length: point it against the throw, so it reads as the exhaust that pushed Rino out.
		var axis: Vector3 = -direction.normalized()
		var side: Vector3 = axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT).normalized()
		_blast.global_basis = Basis(side, axis, side.cross(axis).normalized())
	_blast_left = BLAST_TIME * _show_cue(_blast)


## The FIXED launch fact: shows the SteamBlast at the barrel mouth when the launch is this block's own hold.
func _on_launched(position: Vector3, _direction: Vector3, _speed: float) -> void:
	if not _own_throw(LoaderProfile.Source.FIXED, position, muzzle_point()):
		return
	_blast_left = BLAST_TIME * _show_cue(_blast)


## True when a release fact at `position` belongs to this block's running hold of `source` (other launches, such as boost rings and
## bounce pads, also emit `launched`).
func _own_throw(source: LoaderProfile.Source, position: Vector3, centre: Vector3) -> bool:
	if _phase != Phase.CAPTURING or _issued != source or not position.is_finite():
		return false
	return position.distance_to(centre) <= config.radius + CUE_REACH_MARGIN


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
	_hide_cues()


## The profile handed to the player for this block's catch: FREE_AIM a CAGE hold (a free 2-step Loader flight, D-60), FIXED a hold at
## the barrel mouth that launches along the barrel at fixed_speed after fixed_hold.
func profile_for(player: PlayerController) -> LoaderProfile:
	if config.profile != CatchLaunchConfig.Profile.FIXED:
		return LoaderProfile.cage()
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
	_puff_left = PUFF_TIME * _show_cue(_puff)


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
