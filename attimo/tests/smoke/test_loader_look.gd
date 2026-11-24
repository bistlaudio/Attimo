extends RefCounted
## Plan 05-02 (HAND-04, D-04 "geladen", D-29): the cues of the Loader hold. LoaderLook eases a turquoise vignette and a desaturated
## world in over the hold and out again within 0.3 s of REAL time after the release (saturation exactly back at its original value,
## adjustment off), also when it is freed mid-hold (T-05-05). The camera pulls back along the additive &"loader" source and returns,
## and auto-follow and recenter stay out of the hold. The release applies the discharge velocity first and then a short hitstop
## (TimeFx.pulse) that ends by itself. Plan 05-02 task 3 adds the pitch raise (D-29).

const Fixtures := preload("res://tests/fixtures.gd")

const LOOK_SCENE: String = "res://scenes/ui/loader_look.tscn"
const SHIPPED_TPS: int = 60
const FADE_OUT_SECONDS: float = 0.3

var _bus: Node
var _floor: StaticBody3D
var _player: PlayerController
var _rig: CameraRig
var _look: LoaderLook
var _environment: WorldEnvironment
var _released: Array[Dictionary] = []
var _on_released: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await tree.process_frame
	await _scenario_look(tree, check)
	await _scenario_free_mid_hold(tree, check)
	await _scenario_camera(tree, check)
	await _scenario_hitstop(tree, check)


func _begin(tree: SceneTree, with_look: bool = true) -> void:
	_released = []
	_on_released = func(_position: Vector3, _direction: Vector3, speed: float, bonus: bool) -> void:
		_released.append({
			"velocity": Vector3(_player.move_velocity.x, _player.vertical_speed, _player.move_velocity.z),
			"speed": speed,
			"bonus": bonus,
			"time_scale": Engine.time_scale,
		})
	_bus.connect(&"loader_released", _on_released)
	_floor = Fixtures.spawn_floor(tree.root, Vector3(60.0, 1.0, 60.0))
	_environment = WorldEnvironment.new()
	_environment.environment = Environment.new()
	tree.root.add_child(_environment)
	_player = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 0.0))
	_rig = Fixtures.spawn_camera_rig(tree.root, _player)
	_rig.pitch = 0.0
	if with_look:
		_look = (load(LOOK_SCENE) as PackedScene).instantiate() as LoaderLook
		_look.world_environment = _environment
		tree.root.add_child(_look)
	await Fixtures.wait_physics(tree, 6)
	Fixtures.set_energy(_player, 25.0)


func _end(tree: SceneTree) -> void:
	Input.action_release(&"loader")
	Fixtures.restore_time()
	_bus.disconnect(&"loader_released", _on_released)
	_on_released = Callable()
	for node: Node in [_look, _rig, _player, _environment, _floor]:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
	_look = null


func _hold(tree: SceneTree, ticks: int) -> void:
	Input.action_press(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return _player.loader_active(), 6)
	await Fixtures.wait_physics(tree, ticks)


## Waits real seconds (the world may be slow): a timer that ignores the time scale.
func _wait_real(tree: SceneTree, seconds: float) -> void:
	await tree.create_timer(seconds, true, false, true).timeout


func _scenario_look(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var vignette: ColorRect = _look.get_node("Vignette") as ColorRect
	var environment: Environment = _environment.environment
	check.call(not vignette.visible and environment.adjustment_saturation == 1.0 and not environment.adjustment_enabled, "(l1) before the hold the vignette is hidden and the world is untouched")
	await _hold(tree, 12)
	await _wait_real(tree, 0.1)
	check.call(vignette.visible, "(l2) the vignette is visible during the hold")
	check.call(environment.adjustment_enabled and environment.adjustment_saturation < 1.0, "(l2) the world desaturates during the hold (saturation %.3f)" % environment.adjustment_saturation)
	check.call(environment.adjustment_saturation >= 1.0 - _look.desaturation - 0.001, "(l2) the saturation stays above the target %.2f (got %.3f)" % [1.0 - _look.desaturation, environment.adjustment_saturation])
	var hum: PlaceholderTone = _look.get_node("Hum") as PlaceholderTone
	check.call(hum.sounding(), "(l3) the hum sounds during the hold")
	Input.action_release(&"loader")
	await _wait_real(tree, FADE_OUT_SECONDS)
	check.call(not vignette.visible, "(l4) the vignette is hidden within %.1f s of real time after the release" % FADE_OUT_SECONDS)
	check.call(environment.adjustment_saturation == 1.0 and not environment.adjustment_enabled, "(l4) the saturation is exactly 1.0 and the adjustment is off again (got %.4f, enabled %s)" % [environment.adjustment_saturation, environment.adjustment_enabled])
	check.call(not hum.sounding(), "(l5) the hum is silent after the release")
	await _end(tree)


# T-05-05: freeing LoaderLook mid-hold gives the world its colour back.
func _scenario_free_mid_hold(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var environment: Environment = _environment.environment
	await _hold(tree, 12)
	await _wait_real(tree, 0.1)
	check.call(environment.adjustment_saturation < 1.0, "(f1) the world is desaturated mid-hold")
	_look.free()
	_look = null
	check.call(environment.adjustment_saturation == 1.0 and not environment.adjustment_enabled, "(f2) freeing LoaderLook restores saturation 1.0 (got %.4f)" % environment.adjustment_saturation)
	await _end(tree)


func _scenario_camera(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false)
	var config: MovementConfig = _player.config
	var yaw_before: float = _rig.yaw
	# Make auto-follow and a recenter possible: the player faces away from the camera yaw and has not seen look input for a while.
	_rig.time_since_look = 10.0
	_player.visual_root.rotation.y = 1.2
	check.call(_rig.call(&"_offset_total") == Vector3.ZERO, "(c0) no pull-back before the hold")
	await _hold(tree, 24)
	await _wait_real(tree, 0.25)
	_rig.recenter()
	var pull: Vector3 = _rig.call(&"_offset_total") as Vector3
	check.call(pull.z > 0.0 and pull.z <= config.loader_camera_pullback + 0.001, "(c1) the camera pulls back along +z during the hold (%.3f of %.2f m)" % [pull.z, config.loader_camera_pullback])
	check.call(is_equal_approx(pull.x, 0.0) and is_equal_approx(pull.y, 0.0), "(c1) the pull-back is straight back (%s)" % pull)
	await _wait_real(tree, 0.2)
	check.call(is_equal_approx(_rig.yaw, yaw_before), "(c2) auto-follow and recenter leave the yaw alone during the hold (%.3f -> %.3f)" % [yaw_before, _rig.yaw])
	Input.action_release(&"loader")
	await _wait_real(tree, FADE_OUT_SECONDS)
	var after: Vector3 = _rig.call(&"_offset_total") as Vector3
	check.call(after == Vector3.ZERO, "(c3) the pull-back is cleared within %.1f s after the release (got %s)" % [FADE_OUT_SECONDS, after])
	await _end(tree)


func _scenario_hitstop(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false)
	var config: MovementConfig = _player.config
	_player.debug_loader_direction = Vector3(0.0, 0.6, -0.8)
	await _hold(tree, 10)
	Input.action_release(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return not _released.is_empty(), 6)
	check.call(_released.size() == 1, "(h1) the release fired once (got %d)" % _released.size())
	if _released.size() == 1:
		var expected: Vector3 = LoaderMath.discharge_velocity(Vector3(0.0, 0.6, -0.8), LoaderMath.discharge_speed(0.0, config.loader_min_push, config.loader_bonus_speed, config.loader_max_speed))
		var velocity: Vector3 = _released[0]["velocity"] as Vector3
		check.call(velocity.distance_to(expected) < 0.05, "(h2) the discharge velocity is already applied on the release tick (%s vs %s)" % [velocity, expected])
	check.call(Engine.time_scale == config.loader_hitstop_scale, "(h3) the hitstop scale %.2f holds right after the release (got %.3f)" % [config.loader_hitstop_scale, Engine.time_scale])
	await _wait_real(tree, config.loader_hitstop_time + 3.0 / SHIPPED_TPS)
	check.call(Engine.time_scale == 1.0, "(h4) the time scale is 1.0 after loader_hitstop_time + 3 ticks (got %.3f)" % Engine.time_scale)
	await _end(tree)
