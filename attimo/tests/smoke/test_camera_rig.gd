extends RefCounted
## CAM-01: the follow camera. Structure, jitter proxy at 10 and 60 TPS, the lock onto the player on jumps, long jumps
## and dashes (the vertical lock and the two lag clamps replace the Phase 2 D-15 hold band, DEV-05, quick 261118-qbt),
## the lower-third framing, the additive FOV and offset sources (D-14, D-18), the pitch clamp and wall safety. The
## jitter check is a headless proxy for the 144 Hz criterion; the real display judgment is a human item in 02-14.
## Tick rate and frame cap are restored (60 and unlimited) and actions released before nodes are freed.

const Fixtures := preload("res://tests/fixtures.gd")

const JITTER_SECONDS: float = 1.5
const MAX_STATIONARY_SHARE: float = 0.05
const LAG_TOLERANCE: float = 0.01
const FEET_HEIGHT: float = 0.05
const HEAD_HEIGHT: float = 2.2
const NDC_LIMIT: float = 0.95
const SKELETON_PATH: NodePath = ^"VisualRoot/Mannequin/Rig_Medium/Skeleton3D"
const DASH_SPEED_MIN: float = 20.0


## Records the rig lag and the framing after the rig own _process of every frame (process priority 100 runs after the
## rig at 0), so the numbers are those the player sees.
class LagProbe extends Node:
	var rig: CameraRig
	var target: Node3D
	var worst_horizontal: float = 0.0
	var worst_vertical: float = 0.0
	var ndc_min: float = INF
	var ndc_max: float = -INF
	var rig_low: float = INF
	var rig_high: float = -INF
	var frames: int = 0

	func _init() -> void:
		process_priority = 100

	func _process(_delta: float) -> void:
		var origin: Vector3 = target.get_global_transform_interpolated().origin
		var anchor: Vector3 = origin + Vector3.UP * rig.pivot_height
		worst_horizontal = maxf(worst_horizontal, Vector2(rig.global_position.x - anchor.x, rig.global_position.z - anchor.z).length())
		worst_vertical = maxf(worst_vertical, absf(rig.global_position.y - anchor.y))
		rig_low = minf(rig_low, rig.global_position.y)
		rig_high = maxf(rig_high, rig.global_position.y)
		for height: float in [FEET_HEIGHT, HEAD_HEIGHT]:
			var ndc: float = ndc_y(rig.camera, origin + Vector3.UP * height)
			ndc_min = minf(ndc_min, ndc)
			ndc_max = maxf(ndc_max, ndc)
		frames += 1

	## Vertical normalised device coordinate of a world point (-1 bottom, 1 top). INF behind the lens. Camera3D keeps
	## the height by default, so fov is the vertical field of view.
	static func ndc_y(camera: Camera3D, world_point: Vector3) -> float:
		var local: Vector3 = camera.global_transform.affine_inverse() * world_point
		if local.z >= 0.0:
			return INF
		return (local.y / -local.z) / tan(deg_to_rad(camera.fov) * 0.5)


func run(tree: SceneTree, check: Callable) -> void:
	await _scenario_structure(tree, check)
	await _scenario_channels(tree, check)
	await _scenario_pitch_clamp(tree, check)
	await _scenario_jitter(tree, check, 10)
	await _scenario_jitter(tree, check, 60)
	await _scenario_jump_height(tree, check)
	await _scenario_framing(tree, check)
	await _scenario_dash_follow(tree, check)
	await _scenario_step_landing(tree, check)
	await _scenario_ledge(tree, check)
	await _scenario_wall_pull_in(tree, check)
	await _scenario_open_space(tree, check)
	await _scenario_corridor(tree, check, 10)
	await _scenario_corridor(tree, check, 60)


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
	check.call((rig.arm_collision_mask() & PhysicsLayers.PLAYER) == 0, "(a) the arm cast mask excludes the Player layer")
	check.call((rig.arm_collision_mask() & PhysicsLayers.WORLD) != 0, "(a) the arm cast mask includes the World layer")
	check.call(rig.spring_arm.collision_mask == 0, "(a) the SpringArm3D node's own mask is 0 (the rig casts per frame, A3)")
	await _free_all(tree, nodes)


# (b) additive FOV and offset sources with centered defaults (D-14, D-18).
func _scenario_channels(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree)
	var rig: CameraRig = nodes[2] as CameraRig
	await Fixtures.wait_process(tree, 2)
	check.call(rig.spring_arm.position.is_equal_approx(rig.base_shoulder_offset), "(b) with no source the arm sits at the base shoulder offset, the debug framing (%s)" % rig.spring_arm.position)
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
	check.call(rig.spring_arm.position.is_equal_approx(rig.base_shoulder_offset + Vector3(0.7, 0.0, 0.0)), "(b) an offset source moves the arm origin by exactly its offset (%s)" % rig.spring_arm.position)
	rig.clear_offset(&"aim")
	await Fixtures.wait_process(tree, 2)
	check.call(rig.spring_arm.position.is_equal_approx(rig.base_shoulder_offset), "(b) clearing the offset returns the arm to the base shoulder offset (%s)" % rig.spring_arm.position)
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


# (e) the camera locks onto the player through a held jump and a long jump (stage 1: dash and jump on one tick from a
# run): it never lags more than max_follow_lag horizontally or max_vertical_lag vertically, head and feet stay inside the
# vertical view and the rig rises with the jump (the opposite of the old D-15 hold band, DEV-05).
func _scenario_jump_height(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, Vector3(0.0, 0.0, 25.0))
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	var probe: LagProbe = LagProbe.new()
	probe.rig = rig
	probe.target = player
	tree.root.add_child(probe)
	nodes.append(probe)
	var low: float = rig.global_position.y
	Input.action_press(&"jump")
	var left_floor: bool = false
	var apex: float = 0.0
	var end_msec: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < end_msec:
		await tree.process_frame
		apex = maxf(apex, player.global_position.y)
		if not player.is_grounded():
			left_floor = true
		elif left_floor:
			break
	Input.action_release(&"jump")
	check.call(left_floor and apex > 1.5, "(e) the player jumped about 2 m (apex %.2f)" % apex)
	check.call(probe.rig_high - low > 1.2, "(e) the rig rose %.3f m with the jump (> 1.2)" % (probe.rig_high - low))
	check.call(probe.worst_vertical <= rig.max_vertical_lag + LAG_TOLERANCE, "(e) the vertical lag during the jump was %.3f m (<= %.2f)" % [probe.worst_vertical, rig.max_vertical_lag])
	check.call(probe.worst_horizontal <= rig.max_follow_lag + LAG_TOLERANCE, "(e) the horizontal lag during the jump was %.3f m (<= %.2f)" % [probe.worst_horizontal, rig.max_follow_lag])
	check.call(probe.ndc_min >= -NDC_LIMIT and probe.ndc_max <= NDC_LIMIT, "(e) head and feet stayed inside the view during the jump (ndc %.2f .. %.2f)" % [probe.ndc_min, probe.ndc_max])
	await Fixtures.wait_until(tree, func() -> bool: return player.is_grounded(), 120)
	await Fixtures.wait_physics(tree, 20)

	# Long jump stage 1: dash and jump pressed on one tick from a run.
	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - player.config.run_speed) < 0.05, 120)
	var probe_hop: LagProbe = LagProbe.new()
	probe_hop.rig = rig
	probe_hop.target = player
	tree.root.add_child(probe_hop)
	nodes.append(probe_hop)
	low = rig.global_position.y
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"jump", true)
	Fixtures.send_action_event(&"dash", false)
	var started: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"LongJump", 12)
	var airborne: bool = false
	var ticks: int = 0
	while ticks < 240:
		await tree.physics_frame
		ticks += 1
		if not player.is_grounded():
			airborne = true
		if airborne and player.is_grounded():
			break
		if player.vertical_speed <= 0.0 and airborne:
			Fixtures.send_action_event(&"jump", false)
	Fixtures.send_action_event(&"jump", false)
	Input.action_release(&"move_forward")
	check.call(started >= 0 and airborne, "(e) the dash plus jump became a long jump (state started %d)" % started)
	check.call(probe_hop.rig_high - low > 1.0, "(e) the rig rose %.3f m with the long jump (> 1.0)" % (probe_hop.rig_high - low))
	check.call(probe_hop.worst_vertical <= rig.max_vertical_lag + LAG_TOLERANCE, "(e) the vertical lag during the long jump was %.3f m (<= %.2f)" % [probe_hop.worst_vertical, rig.max_vertical_lag])
	check.call(probe_hop.worst_horizontal <= rig.max_follow_lag + LAG_TOLERANCE, "(e) the horizontal lag during the long jump was %.3f m (<= %.2f)" % [probe_hop.worst_horizontal, rig.max_follow_lag])
	check.call(probe_hop.ndc_min >= -NDC_LIMIT and probe_hop.ndc_max <= NDC_LIMIT, "(e) head and feet stayed inside the view during the long jump (ndc %.2f .. %.2f)" % [probe_hop.ndc_min, probe_hop.ndc_max])
	await _free_all(tree, nodes)


# (k) framing at spawn with the default pitch: the shoulder sits slightly below the screen centre, the head top in the
# upper half and the feet in the lower part; the arm is at most 4 m and the pivot lies slightly above the shoulder.
func _scenario_framing(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree)
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	await Fixtures.wait_physics(tree, 10)
	await Fixtures.wait_process(tree, 3)
	var origin: Vector3 = player.global_position
	var skeleton: Skeleton3D = player.get_node(SKELETON_PATH) as Skeleton3D
	var bone: int = skeleton.find_bone("upperarm.r")
	var shoulder: float = (skeleton.global_transform * skeleton.get_bone_global_rest(bone)).origin.y - origin.y
	var shoulder_ndc: float = LagProbe.ndc_y(rig.camera, origin + Vector3.UP * shoulder)
	var head_ndc: float = LagProbe.ndc_y(rig.camera, origin + Vector3.UP * HEAD_HEIGHT)
	var feet_ndc: float = LagProbe.ndc_y(rig.camera, origin + Vector3.UP * FEET_HEIGHT)
	check.call(shoulder_ndc >= -0.45 and shoulder_ndc <= -0.02, "(k) the shoulder (y %.2f m) projects to vertical ndc %.2f (-0.45 .. -0.02)" % [shoulder, shoulder_ndc])
	check.call(head_ndc <= 0.3 and head_ndc > 0.0, "(k) the head top projects to vertical ndc %.2f (0 .. 0.3)" % head_ndc)
	check.call(feet_ndc >= -0.9 and feet_ndc < shoulder_ndc, "(k) the feet project to vertical ndc %.2f (at least -0.9)" % feet_ndc)
	check.call((head_ndc + feet_ndc) * 0.5 < 0.0, "(k) the standing character sits in the lower part of the screen (centre ndc %.2f)" % ((head_ndc + feet_ndc) * 0.5))
	check.call(rig.spring_arm.spring_length <= 5.0, "(k) the start arm is at most 5 m (%.2f)" % rig.spring_arm.spring_length)
	# Mouse-wheel zoom (2026-11-18): the chosen distance clamps to zoom_min .. zoom_max.
	rig.zoom_by(-100.0)
	check.call(is_equal_approx(rig.zoom_distance, rig.zoom_min), "(k) zooming far in clamps to zoom_min (%.2f)" % rig.zoom_distance)
	rig.zoom_by(100.0)
	check.call(is_equal_approx(rig.zoom_distance, rig.zoom_max), "(k) zooming far out clamps to zoom_max (%.2f)" % rig.zoom_distance)
	check.call(rig.pivot_height >= shoulder + 0.05 and rig.pivot_height <= shoulder + 0.4, "(k) pivot_height %.2f lies 0.05 .. 0.4 above the shoulder %.2f" % [rig.pivot_height, shoulder])
	check.call(rig.base_fov >= 76.0 and rig.base_fov <= 82.0, "(k) the field of view is a little wider than 75 (%.1f)" % rig.base_fov)
	check.call(rig.pitch_max >= 0.7, "(k) the upward pitch range is larger than before (%.2f)" % rig.pitch_max)
	await _free_all(tree, nodes)


# (l) a ground dash at dash speed never leaves the player more than max_follow_lag behind.
func _scenario_dash_follow(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, Vector3(0.0, 0.0, 25.0))
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = nodes[2] as CameraRig
	var probe: LagProbe = LagProbe.new()
	probe.rig = rig
	probe.target = player
	tree.root.add_child(probe)
	nodes.append(probe)
	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - player.config.run_speed) < 0.05, 120)
	await Fixtures.tap_action(tree, &"dash")
	var peak: float = 0.0
	var ticks: int = 0
	while player.state_machine.current.name == &"Dash" and ticks < 40:
		peak = maxf(peak, player.horizontal_speed())
		await tree.physics_frame
		ticks += 1
	await Fixtures.wait_process(tree, 3)
	Input.action_release(&"move_forward")
	check.call(peak > DASH_SPEED_MIN, "(l) the dash reached %.1f m/s (> %.0f)" % [peak, DASH_SPEED_MIN])
	check.call(probe.worst_horizontal <= rig.max_follow_lag + LAG_TOLERANCE, "(l) the horizontal lag during the dash was %.3f m (<= %.2f)" % [probe.worst_horizontal, rig.max_follow_lag])
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


## Pivot to lens distance (the arm origin sits on the pivot when no offset source is set).
func _arm_distance(rig: CameraRig) -> float:
	return rig.camera.global_position.distance_to(rig.pitch_node.global_position)


## True while the lens point is inside a World collider.
func _lens_inside_world(tree: SceneTree, rig: CameraRig) -> bool:
	var query: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	query.position = rig.camera.global_position
	query.collision_mask = PhysicsLayers.WORLD
	return not rig.get_world_3d().direct_space_state.intersect_point(query, 1).is_empty()


## True while a World collider sits on the segment from the pivot to the lens.
func _wall_between(rig: CameraRig) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(rig.pitch_node.global_position, rig.camera.global_position, PhysicsLayers.WORLD)
	return not rig.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# (h) a wall 2 m behind the player pulls the lens in (CAM-01: never clips through walls).
func _scenario_wall_pull_in(tree: SceneTree, check: Callable) -> void:
	var wall: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(10.0, 10.0, 1.0), Vector3(0.0, 5.0, 2.5))
	var nodes: Array[Node] = await _spawn(tree)
	var rig: CameraRig = nodes[2] as CameraRig
	await Fixtures.wait_physics(tree, 10)
	await Fixtures.wait_process(tree, 2)
	var distance: float = _arm_distance(rig)
	check.call(distance <= 2.0, "(h) with a wall 2 m behind, the lens is %.2f m from the pivot (<= 2.0)" % distance)
	check.call(not _lens_inside_world(tree, rig), "(h) the lens is not inside the wall")
	nodes.append(wall)
	await _free_all(tree, nodes)


# (i) in open space the lens sits at spring_length; the player capsule never pulls it in.
func _scenario_open_space(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree)
	var rig: CameraRig = nodes[2] as CameraRig
	await Fixtures.wait_physics(tree, 10)
	await Fixtures.wait_process(tree, 2)
	var distance: float = _arm_distance(rig)
	check.call(absf(distance - rig.spring_arm.spring_length) < 0.15, "(i) in open space the lens is %.3f m out, spring_length %.2f" % [distance, rig.spring_arm.spring_length])
	await _free_all(tree, nodes)


# (j) orbiting inside a 3 m corridor never puts a wall between pivot and lens, at any tick rate.
func _scenario_corridor(tree: SceneTree, check: Callable, tps: int) -> void:
	Engine.physics_ticks_per_second = tps
	Engine.max_fps = 144
	await Fixtures.wait_physics(tree, 2)
	var left_wall: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(1.0, 10.0, 40.0), Vector3(-2.0, 5.0, 0.0))
	var right_wall: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(1.0, 10.0, 40.0), Vector3(2.0, 5.0, 0.0))
	var nodes: Array[Node] = await _spawn(tree)
	var rig: CameraRig = nodes[2] as CameraRig
	await Fixtures.wait_physics(tree, maxi(5, tps / 10))
	var frames: int = 0
	var blocked: int = 0
	var inside: int = 0
	var worst: float = 0.0
	var end_msec: int = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < end_msec:
		await tree.process_frame
		frames += 1
		if _wall_between(rig):
			blocked += 1
		if _lens_inside_world(tree, rig):
			inside += 1
		worst = maxf(worst, _arm_distance(rig))
		rig.yaw += PI * tree.root.get_process_delta_time()
	check.call(frames > 20, "(j) at %d TPS enough orbit frames were sampled (%d)" % [tps, frames])
	check.call(blocked == 0, "(j) at %d TPS %d of %d frames had a wall between pivot and lens" % [tps, blocked, frames])
	check.call(inside == 0, "(j) at %d TPS %d of %d frames had the lens inside a collider" % [tps, inside, frames])
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 0
	await Fixtures.wait_physics(tree, 2)
	nodes.append(left_wall)
	nodes.append(right_wall)
	await _free_all(tree, nodes)
