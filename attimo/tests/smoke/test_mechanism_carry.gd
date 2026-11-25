extends RefCounted
## MECH-03 / D-22 spike and go/no-go gate, ported to the Timed motion block in plan 05.1-04: a rider on the clock hand (SWEEP) and the
## tilt plate (TILT) must keep its place on the deck at 60 TPS and at the 10 TPS diagnostic rate, now over a real floor (top y 0)
## with the pivot at TimedMotion.min_pivot_height (D-07). Both are always on (no source). Drift is the change of the distance to the
## pivot (the rider's radius). The engine-only numbers (custom carry off) are printed for the record (A2), not asserted. The LYING gear
## was cut (KIT-04).

const Fixtures := preload("res://tests/fixtures.gd")

const HAND_SCENE: String = "res://scenes/kit/steampunk/clock_hand_platform.tscn"
const HAND_PRESET: String = "res://resources/kit/timed_motion/clock_hand.tres"
const TILT_SCENE: String = "res://scenes/kit/steampunk/tilting_platform.tscn"
const TILT_PRESET: String = "res://resources/kit/timed_motion/tilting_platform.tres"
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
		await _scenario(tree, check, HAND_SCENE, HAND_PRESET, "SWEEP", Vector3(0.0, 0.0, 3.0), 0.6, tps, false)
		await _scenario(tree, check, TILT_SCENE, TILT_PRESET, "TILT", Vector3(0.0, 0.0, 2.0), 0.5, tps, false)
		await _scenario(tree, check, HAND_SCENE, HAND_PRESET, "SWEEP", Vector3(0.0, 0.0, 3.0), 0.6, tps, true)
		await _scenario(tree, check, TILT_SCENE, TILT_PRESET, "TILT", Vector3(0.0, 0.0, 2.0), 0.5, tps, true)
	Engine.physics_ticks_per_second = SHIPPED_TPS  # the shipped rate, always restored


func _scenario(tree: SceneTree, check: Callable, scene_path: String, preset_path: String, mode: String, rider: Vector3, speed: float, tps: int, engine_only: bool) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var config: TimedMotionConfig = (load(preset_path) as TimedMotionConfig).duplicate() as TimedMotionConfig
	config.angular_speed = speed
	var pivot_y: float = TimedMotion.min_pivot_height(config, 0.0)
	var platform: TimedMotion = (load(scene_path) as PackedScene).instantiate() as TimedMotion
	platform.config = config
	platform.position = Vector3(0.0, pivot_y, 0.0)
	tree.root.add_child(platform)
	var player: PlayerController = Fixtures.spawn_player(tree.root, platform.position + rider)
	player.debug_disable_custom_carry = engine_only
	await Fixtures.wait_physics(tree, maxi(tps / 3, 4))
	var body: AnimatableBody3D = platform.body()
	var pivot: Vector3 = platform.pivot_position()
	var radius0: float = (player.global_position - pivot).length()
	var local0: Vector3 = body.global_transform.affine_inverse() * player.global_position
	var previous_local: Vector3 = local0
	var dt: float = 1.0 / float(tps)
	var ticks: int = int(RUN_SECONDS * float(tps))
	var grounded: int = 0
	var worst_drift: float = 0.0
	var worst_relative: float = 0.0
	var peak_angle: float = 0.0
	var ramp_ticks: int = ceili(platform.config.ramp_time * float(tps)) + 2
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
	var label: String = "%s at %d TPS" % [mode, tps]
	if engine_only:
		check.call(true, "SPIKE engine-only carry, %s: drift %.4f m, grounded %.0f %%, relative speed %.3f m/s" % [label, worst_drift, ratio * 100.0, worst_relative])
	else:
		check.call(peak_angle > 0.3, "%s: the platform really turned (peak angle %.2f rad)" % [label, peak_angle])
		check.call(worst_drift < MAX_DRIFT, "%s: rider radius drift %.4f m (< %.2f)" % [label, worst_drift, MAX_DRIFT])
		check.call(ratio >= MIN_GROUNDED_RATIO, "%s: grounded on %.0f %% of ticks (>= 95)" % [label, ratio * 100.0])
		check.call(worst_relative < MAX_RELATIVE_SPEED, "%s: speed relative to the platform %.3f m/s (< %.1f, no double carry)" % [label, worst_relative, MAX_RELATIVE_SPEED])
	Input.action_release(&"move_forward")
	for node: Node in [player, platform, floor_body]:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
	await tree.process_frame
