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
## Plan 05.1-05 (D-01, D-05, D-26): the cage tints the vignette brass, the cannon's FIXED hold shows no look at all.
const CAGE_SCENE: String = "res://scenes/kit/steampunk/slingshot_core.tscn"
const CANNON_SCENE: String = "res://scenes/kit/steampunk/steam_cannon.tscn"
const PREVIEW_SCRIPT: String = "res://scripts/player/loader_preview.gd"
const TURQUOISE: Color = Color(0.25, 0.9, 0.85, 1.0)

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
	await _scenario_release_fade(tree, check)
	await _scenario_free_mid_hold(tree, check)
	await _scenario_camera(tree, check)
	await _scenario_hitstop(tree, check)
	await _scenario_pitch(tree, check)
	await _scenario_cage_tint(tree, check)
	await _scenario_cannon_quiet(tree, check)


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
	check.call(_vignette_tint().is_equal_approx(TURQUOISE), "(05.1-05) the arm Loader vignette stays turquoise (got %s)" % _vignette_tint())
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


# D-29: during the hold the pitch-up limit rises to loader_pitch_max_deg, after the release it eases back to pitch_max without a jump.
func _scenario_pitch(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false)
	var config: MovementConfig = _player.config
	var limit: float = deg_to_rad(config.loader_pitch_max_deg)
	_rig.pitch = _rig.pitch_max
	check.call(limit > _rig.pitch_max, "(p0) the Loader pitch limit %.0f deg is above the normal %.0f deg" % [config.loader_pitch_max_deg, rad_to_deg(_rig.pitch_max)])
	await _hold(tree, 24)
	await _wait_real(tree, 0.3)
	_rig.pitch = limit
	await tree.process_frame
	await tree.process_frame
	check.call(absf(_rig.pitch - limit) < 0.001, "(p1) the rig accepts pitch up to %.0f deg during the hold (got %.1f deg)" % [config.loader_pitch_max_deg, rad_to_deg(_rig.pitch)])
	Input.action_release(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return not _player.loader_active(), 6)
	var worst_step: float = 0.0
	var last: float = _rig.pitch
	var elapsed: float = 0.0
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 400 and _rig.pitch > _rig.pitch_max + 0.0001:
		await tree.process_frame
		worst_step = maxf(worst_step, absf(_rig.pitch - last))
		last = _rig.pitch
	elapsed = float(Time.get_ticks_msec() - start) / 1000.0
	check.call(_rig.pitch <= _rig.pitch_max + 0.0001, "(p2) the pitch eases back to pitch_max within 0.4 s (%.1f deg after %.2f s)" % [rad_to_deg(_rig.pitch), elapsed])
	check.call(rad_to_deg(worst_step) <= 10.0, "(p3) no frame moves the pitch by more than 10 deg (worst %.1f deg)" % rad_to_deg(worst_step))
	await _end(tree)


# WR-04 / D-04: a short hold's cues only fade after the release, they never jump up first ("eases, never a cut").
func _scenario_release_fade(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var material: ShaderMaterial = (_look.get_node("Vignette") as ColorRect).material as ShaderMaterial
	await _hold(tree, 4)
	await _wait_real(tree, 0.15)
	var last_held: float = -1.0
	var after_max: float = -1.0
	var released: bool = false
	for i: int in 90:
		await tree.process_frame
		var strength: float = float(material.get_shader_parameter(&"strength"))
		if _player.loader_active():
			last_held = strength
		else:
			after_max = maxf(after_max, strength)
		if i == 2 and not released:
			released = true
			Input.action_release(&"loader")
	check.call(last_held > 0.0, "(e1) the vignette is on at the end of a short hold (%.3f)" % last_held)
	check.call(after_max >= 0.0 and after_max <= last_held + 0.0001, "(e1) after the release the vignette only fades: max %.3f <= last held %.3f" % [after_max, last_held])
	await _end(tree)


## The vignette shader's tint of the current LoaderLook.
func _vignette_tint() -> Color:
	var material: ShaderMaterial = (_look.get_node("Vignette") as ColorRect).material as ShaderMaterial
	return material.get_shader_parameter(&"tint") as Color


## LoaderPreview.BRASS_COLOR by reflection, or an impossible colour while it does not exist.
func _brass() -> Color:
	var script: GDScript = load(PREVIEW_SCRIPT) as GDScript
	return script.get_script_constant_map().get("BRASS_COLOR", Color(-1.0, -1.0, -1.0, -1.0)) as Color


# Plan 05.1-05 (D-01, D-26): a cage hold keeps the "geladen" look but tints the vignette brass, even with a full core; the fade-out
# after the throw stays brass.
func _scenario_cage_tint(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var cage: Node3D = Fixtures.spawn_scene(tree.root, CAGE_SCENE, Vector3(0.0, 10.0, 0.0))
	await Fixtures.wait_physics(tree, 2)
	_player.teleport(Vector3(-4.0, 9.0, 0.0))
	_player.launch_along(Vector3.RIGHT, 9.0, false)
	var entered: int = await Fixtures.wait_until(tree, func() -> bool: return _player.loader_active(), 40)
	await _wait_real(tree, 0.1)
	var vignette: ColorRect = _look.get_node("Vignette") as ColorRect
	check.call(entered >= 0 and vignette.visible, "(k1) the cage hold shows the vignette (entered %d)" % entered)
	check.call(_vignette_tint().is_equal_approx(_brass()), "(k1) the cage vignette is brass (got %s, brass %s)" % [_vignette_tint(), _brass()])
	check.call(not _vignette_tint().is_equal_approx(TURQUOISE), "(k1) the cage vignette is not turquoise with a full core")
	await Fixtures.tap_action(tree, &"loader", 1)
	await Fixtures.wait_until(tree, func() -> bool: return not _player.loader_active(), 6)
	await tree.process_frame
	check.call(not vignette.visible or _vignette_tint().is_equal_approx(_brass()), "(k2) the fade-out after the cage throw stays brass (got %s)" % _vignette_tint())
	await _wait_real(tree, FADE_OUT_SECONDS)
	check.call(not vignette.visible, "(k2) the vignette is gone within %.1f s after the cage throw" % FADE_OUT_SECONDS)
	cage.queue_free()
	await _end(tree)


# Plan 05.1-05 (D-05): the cannon's 0.2 s FIXED hold shows no vignette, no desaturation and no hum.
func _scenario_cannon_quiet(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var cannon: Node3D = (load(CANNON_SCENE) as PackedScene).instantiate() as Node3D
	cannon.rotation.y = deg_to_rad(-90.0)
	cannon.position = Vector3(10.0, 0.0, 0.0)
	tree.root.add_child(cannon)
	await Fixtures.wait_physics(tree, 2)
	_player.teleport(cannon.global_position - Vector3.RIGHT * 3.2)
	await tree.physics_frame
	var speed: float = _player.config.run_speed
	_player.launch_along(Vector3.RIGHT, speed, false)
	var entered: int = -1
	for i: int in 40:
		if _player.loader_active():
			entered = i
			break
		_player.move_velocity = Vector3.RIGHT * speed
		await tree.physics_frame
	check.call(entered >= 0, "(n1) the cannon catches Rino into a FIXED hold (entered %d)" % entered)
	var vignette: ColorRect = _look.get_node("Vignette") as ColorRect
	var hum: PlaceholderTone = _look.get_node("Hum") as PlaceholderTone
	var environment: Environment = _environment.environment
	var frames: int = 0
	var seen: bool = false
	var guard: int = 0
	while _player.loader_active() and guard < 400:
		await tree.process_frame
		guard += 1
		frames += 1
		seen = seen or vignette.visible or hum.sounding() or environment.adjustment_enabled
	check.call(frames > 0, "(n2) the cannon hold was sampled over %d process frames" % frames)
	check.call(not seen, "(n2) the cannon hold shows no vignette, no desaturation and no hum")
	cannon.queue_free()
	await _end(tree)
