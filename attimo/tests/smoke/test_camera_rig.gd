extends RefCounted
## CAM-01: the follow camera. Structure, jitter proxy at 10 and 60 TPS, the vertical follow band (D-15), the
## additive FOV and offset sources (D-14, D-18), the pitch clamp and wall safety. The jitter check is a headless
## proxy for the 144 Hz criterion; the real display judgment is a human item in 02-14.
## Tick rate and frame cap are restored (60 and unlimited) and actions released before nodes are freed.

const Fixtures := preload("res://tests/fixtures.gd")

const JITTER_SECONDS: float = 1.5
const MAX_STATIONARY_SHARE: float = 0.05


func run(tree: SceneTree, check: Callable) -> void:
	await _scenario_structure(tree, check)
	await _scenario_channels(tree, check)
	await _scenario_pitch_clamp(tree, check)
	await _scenario_jitter(tree, check, 10)
	await _scenario_jitter(tree, check, 60)
	await _scenario_jump_height(tree, check)
	await _scenario_step_landing(tree, check)
	await _scenario_ledge(tree, check)


func _spawn(tree: SceneTree, position: Vector3 = Vector3.ZERO) -> Array[Node]:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, position)
	var rig: CameraRig = Fixtures.spawn_camera_rig(tree.root, player)
	await Fixtures.wait_physics(tree, maxi(5, int(Engine.physics_ticks_per_second / 10.0)))
	await Fixtures.wait_process(tree, 2)
	return [floor_body, player, rig]


func _free_all(tree: SceneTree, nodes: Array[Node]) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame


## Awaits process frames for `seconds` of wall clock time.
func _run_for(tree: SceneTree, seconds: float) -> void:
	var end_msec: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end_msec:
		await tree.process_frame


# (a) the rig sits beside the player, top level, interpolation off, with a sphere arm that ignores the player.
func _scenario_structure(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree)
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	check.call(rig.top_level, "(a) the rig is top level")
	check.call(rig.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "(a) the rig has physics interpolation off")
	check.call(not player.is_ancestor_of(rig) and rig.get_parent() == player.get_parent(), "(a) the rig is a sibling of the player, not in its subtree")
	check.call(rig.spring_arm.shape is SphereShape3D, "(a) the arm casts a SphereShape3D")
	check.call((rig.spring_arm.collision_mask & PhysicsLayers.PLAYER) == 0, "(a) the arm mask excludes the Player layer")
	check.call((rig.spring_arm.collision_mask & PhysicsLayers.WORLD) != 0, "(a) the arm mask includes the World layer")
	await _free_all(tree, nodes)


# (b) additive FOV and offset sources with centered defaults (D-14, D-18).
func _scenario_channels(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree)
	var rig: CameraRig = nodes[2] as CameraRig
	await Fixtures.wait_process(tree, 2)
	check.call(rig.spring_arm.position == Vector3.ZERO, "(b) with no source the arm sits at the pivot (%s)" % rig.spring_arm.position)
	check.call(is_equal_approx(rig.camera.fov, rig.base_fov), "(b) with no source fov equals base_fov (%.2f)" % rig.camera.fov)

	rig.set_fov_offset(&"aim", 5.0)
	rig.set_fov_offset(&"kick", -2.0)
	await Fixtures.wait_process(tree, 2)
	check.call(is_equal_approx(rig.camera.fov, rig.base_fov + 3.0), "(b) +5 and -2 give base_fov + 3 (%.2f)" % rig.camera.fov)
	check.call(is_equal_approx(rig.get_fov_total(), rig.base_fov + 3.0), "(b) get_fov_total reports base_fov + 3")

	rig.clear_fov_offset(&"aim")
	await Fixtures.wait_process(tree, 2)
	check.call(is_equal_approx(rig.camera.fov, rig.base_fov - 2.0), "(b) clearing +5 leaves only the -2 share (%.2f)" % rig.camera.fov)

	rig.set_fov_offset(&"kick", 500.0)
	await Fixtures.wait_process(tree, 2)
	check.call(rig.camera.fov <= 179.0 and rig.camera.fov >= 1.0, "(b) the summed fov is clamped to 1..179 (%.2f)" % rig.camera.fov)
	rig.clear_fov_offset(&"kick")

	rig.set_offset(&"aim", Vector3(0.7, 0.0, 0.0))
	await Fixtures.wait_process(tree, 2)
	check.call(rig.spring_arm.position == Vector3(0.7, 0.0, 0.0), "(b) an offset source moves the arm origin exactly (%s)" % rig.spring_arm.position)
	rig.clear_offset(&"aim")
	await Fixtures.wait_process(tree, 2)
	check.call(rig.spring_arm.position == Vector3.ZERO, "(b) clearing the offset returns the arm to the pivot (%s)" % rig.spring_arm.position)
	await _free_all(tree, nodes)


# (c) pitch stays inside [pitch_min, pitch_max] however far the mouse moves.
func _scenario_pitch_clamp(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree)
	var rig: CameraRig = nodes[2] as CameraRig
	Fixtures.send_mouse_motion(Vector2(0.0, -100000.0))
	check.call(rig.pitch == rig.pitch_max, "(c) a huge upward motion leaves pitch at pitch_max (%.3f)" % rig.pitch)
	Fixtures.send_mouse_motion(Vector2(0.0, 100000.0))
	check.call(rig.pitch == rig.pitch_min, "(c) a huge downward motion leaves pitch at pitch_min (%.3f)" % rig.pitch)
	await _free_all(tree, nodes)


# (d) jitter proxy: running at constant speed, almost no process frame leaves the rig where it was.
func _scenario_jitter(tree: SceneTree, check: Callable, tps: int) -> void:
	Engine.physics_ticks_per_second = tps
	Engine.max_fps = 144
	await Fixtures.wait_physics(tree, 2)
	var nodes: Array[Node] = await _spawn(tree, Vector3(0.0, 0.0, 40.0))
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	Input.action_press(&"move_forward")
	await _run_for(tree, 1.0)
	var run_speed: float = player.config.run_speed
	check.call(player.horizontal_speed() > run_speed - 0.5, "(d) at %d TPS the player runs at constant speed (%.2f m/s)" % [tps, player.horizontal_speed()])

	var frames: int = 0
	var stationary: int = 0
	var previous: Vector3 = rig.global_position
	var end_msec: int = Time.get_ticks_msec() + int(JITTER_SECONDS * 1000.0)
	while Time.get_ticks_msec() < end_msec:
		await tree.process_frame
		var now: Vector3 = rig.global_position
		frames += 1
		if now.is_equal_approx(previous):
			stationary += 1
		previous = now
	var share: float = float(stationary) / float(maxi(frames, 1))
	check.call(frames > 20, "(d) at %d TPS enough process frames were sampled (%d)" % [tps, frames])
	check.call(share < MAX_STATIONARY_SHARE, "(d) at %d TPS %.1f %% of %d process frames left the rig unmoved (< 5 %%)" % [tps, share * 100.0, frames])

	Input.action_release(&"move_forward")
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 0
	await Fixtures.wait_physics(tree, 2)
	await _free_all(tree, nodes)


# (e) a 2 m held jump on flat ground does not bob the camera (D-15).
func _scenario_jump_height(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree)
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	var low: float = rig.global_position.y
	var high: float = low
	Input.action_press(&"jump")
	var left_floor: bool = false
	var apex: float = 0.0
	var end_msec: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < end_msec:
		await tree.process_frame
		low = minf(low, rig.global_position.y)
		high = maxf(high, rig.global_position.y)
		apex = maxf(apex, player.global_position.y)
		if not player.is_grounded():
			left_floor = true
		elif left_floor:
			break
	Input.action_release(&"jump")
	check.call(left_floor and apex > 1.5, "(e) the player jumped about 2 m (apex %.2f)" % apex)
	check.call(high - low < 0.3, "(e) the rig height varied by %.3f m during the jump (< 0.3)" % (high - low))
	await _free_all(tree, nodes)


# (f) after landing on a 1 m step the rig settles on step top + pivot_height within 1 s.
func _scenario_step_landing(tree: SceneTree, check: Callable) -> void:
	var step: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(6.0, 1.0, 8.0), Vector3(0.0, 0.5, -8.0))
	var nodes: Array[Node] = await _spawn(tree)
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return player.global_position.z < -1.0, 180)
	Input.action_press(&"jump")
	var landed: int = await Fixtures.wait_until(tree, func() -> bool: return player.is_grounded() and player.global_position.y > 0.9, 180)
	Input.action_release(&"jump")
	Input.action_release(&"move_forward")
	check.call(landed >= 0, "(f) the player landed on the 1 m step (y %.2f)" % player.global_position.y)
	await _run_for(tree, 1.0)
	var expected: float = 1.0 + rig.pivot_height
	check.call(absf(rig.global_position.y - expected) < 0.05, "(f) the rig settled at %.3f, expected %.3f" % [rig.global_position.y, expected])
	nodes.append(step)
	await _free_all(tree, nodes)


# (g) walking off a 3 m ledge, the camera follows the fall down.
func _scenario_ledge(tree: SceneTree, check: Callable) -> void:
	var platform: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(10.0, 3.0, 10.0), Vector3(0.0, 1.5, 0.0))
	var nodes: Array[Node] = await _spawn(tree, Vector3(0.0, 3.0, 0.0))
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	var start_y: float = rig.global_position.y
	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return player.global_position.z < -5.5, 240)
	var landed: int = await Fixtures.wait_until(tree, func() -> bool: return player.is_grounded() and player.global_position.y < 0.1, 240)
	Input.action_release(&"move_forward")
	check.call(landed >= 0, "(g) the player fell to the floor (y %.2f)" % player.global_position.y)
	await _run_for(tree, 0.5)
	check.call(start_y - rig.global_position.y > 2.0, "(g) the rig dropped %.2f m by 0.5 s after landing (> 2)" % (start_y - rig.global_position.y))
	nodes.append(platform)
	await _free_all(tree, nodes)
