extends RefCounted
## MECH-03 / D-22 spike and go/no-go gate: a rider on a Dreh-Plattform (LYING gear, STANDING clock hand, TILTING plate)
## must keep its place on the platform at 60 TPS and at the 10 TPS diagnostic rate. Drift is the change of the distance to
## the pivot (the rider's radius). The engine-only numbers (custom carry off) are printed for the record (A2), not asserted.

const Fixtures := preload("res://tests/fixtures.gd")

const PLATFORM_SCENE: String = "res://scenes/mechanisms/rotating_platform.tscn"
const SHIPPED_TPS: int = 60
## Diagnostic rate (debug_tick_rate camera toggle), never shipped (A22).
const DIAGNOSTIC_TPS: int = 10
const RUN_SECONDS: float = 3.0
const MAX_DRIFT: float = 0.05
const MAX_RELATIVE_SPEED: float = 0.3
const MIN_GROUNDED_RATIO: float = 0.95


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	for tps: int in [SHIPPED_TPS, DIAGNOSTIC_TPS]:
		Engine.physics_ticks_per_second = tps
		await _scenario(tree, check, RotatingPlatform.AxisMode.LYING, Vector3(3.0, 0.0, 0.0), 1.0, tps, false)
		await _scenario(tree, check, RotatingPlatform.AxisMode.STANDING, Vector3(0.0, 0.0, 3.0), 0.6, tps, false)
		await _scenario(tree, check, RotatingPlatform.AxisMode.TILTING, Vector3(0.0, 0.0, 2.0), 0.5, tps, false)
		await _scenario(tree, check, RotatingPlatform.AxisMode.LYING, Vector3(3.0, 0.0, 0.0), 1.0, tps, true)
		await _scenario(tree, check, RotatingPlatform.AxisMode.STANDING, Vector3(0.0, 0.0, 3.0), 0.6, tps, true)
		await _scenario(tree, check, RotatingPlatform.AxisMode.TILTING, Vector3(0.0, 0.0, 2.0), 0.5, tps, true)
	Engine.physics_ticks_per_second = SHIPPED_TPS  # the shipped rate, always restored


func _mode_name(mode: RotatingPlatform.AxisMode) -> String:
	return ["LYING", "STANDING", "TILTING"][mode]


func _scenario(tree: SceneTree, check: Callable, mode: RotatingPlatform.AxisMode, rider: Vector3, speed: float, tps: int, engine_only: bool) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	var platform: RotatingPlatform = (load(PLATFORM_SCENE) as PackedScene).instantiate() as RotatingPlatform
	platform.axis_mode = mode
	platform.angular_speed = speed
	platform.source = source
	tree.root.add_child(platform)
	var player: PlayerController = Fixtures.spawn_player(tree.root, rider)
	player.debug_disable_custom_carry = engine_only
	await Fixtures.wait_physics(tree, maxi(tps / 3, 4))
	var body: AnimatableBody3D = platform.body()
	var pivot: Vector3 = platform.pivot_position()
	var radius0: float = (player.global_position - pivot).length()
	var local0: Vector3 = body.global_transform.affine_inverse() * player.global_position
	var previous_local: Vector3 = local0
	var dt: float = 1.0 / float(tps)
	source.set_active(true)
	var ticks: int = int(RUN_SECONDS * float(tps))
	var grounded: int = 0
	var worst_drift: float = 0.0
	var worst_relative: float = 0.0
	var peak_angle: float = 0.0
	var ramp_ticks: int = ceili(platform.ramp_time * float(tps)) + 2
	for i: int in ticks:
		await Fixtures.wait_physics(tree, 1)
		if player.is_grounded():
			grounded += 1
		worst_drift = maxf(worst_drift, absf((player.global_position - pivot).length() - radius0))
		var local_now: Vector3 = body.global_transform.affine_inverse() * player.global_position
		# The rider trails the platform pose by one tick, so the start ramp (the lag changes fast) is left out.
		if i >= ramp_ticks:
			worst_relative = maxf(worst_relative, (local_now - previous_local).length() / dt)
		previous_local = local_now
		peak_angle = maxf(peak_angle, absf(platform.current_angle()))
	var ratio: float = float(grounded) / float(ticks)
	var label: String = "%s at %d TPS" % [_mode_name(mode), tps]
	if engine_only:
		check.call(true, "SPIKE engine-only carry, %s: drift %.4f m, grounded %.0f %%, relative speed %.3f m/s" % [label, worst_drift, ratio * 100.0, worst_relative])
	else:
		check.call(peak_angle > 0.3, "%s: the platform really turned (peak angle %.2f rad)" % [label, peak_angle])
		check.call(worst_drift < MAX_DRIFT, "%s: rider radius drift %.4f m (< %.2f)" % [label, worst_drift, MAX_DRIFT])
		check.call(ratio >= MIN_GROUNDED_RATIO, "%s: grounded on %.0f %% of ticks (>= 95)" % [label, ratio * 100.0])
		check.call(worst_relative < MAX_RELATIVE_SPEED, "%s: speed relative to the platform %.3f m/s (< %.1f, no double carry)" % [label, worst_relative, MAX_RELATIVE_SPEED])
	Input.action_release(&"move_forward")
	for node: Node in [player, platform, source]:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
	await tree.process_frame
