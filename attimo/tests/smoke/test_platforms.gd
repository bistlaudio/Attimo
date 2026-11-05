extends RefCounted
## MOVE-08 / D-13: conveyors and moving platforms carry the player and their velocity survives leaving
## them; the fall reset returns the player to its marker. Every body is built in code.
## Tests never mutate the shared MovementConfig: a scenario with other numbers duplicates it first.
## Actions are held with Input.action_press and always released before nodes are freed.

const Fixtures := preload("res://tests/fixtures.gd")

const PLATFORM_SCENE: String = "res://scenes/proto/moving_platform.tscn"
const SLOPE_SCENE: String = "res://scenes/proto/primitive_slope.tscn"
const BEAM_SCENE: String = "res://scenes/proto/primitive_beam.tscn"
const SHIPPED_TPS: int = 60
## Diagnostic rate (debug_tick_rate camera toggle), never shipped (A22).
const DIAGNOSTIC_TPS: int = 10
const SNAP_TOLERANCE: float = 1e-4
## The ramp and stair runs use this speed (D-13).
const RAMP_RUN_SPEED: float = 10.5


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_conveyor_carry(tree, check)
	await _scenario_conveyor_jump(tree, check)
	await _scenario_linear_platform(tree, check)
	await _scenario_platform_walk_off(tree, check)
	await _scenario_vertical_platform(tree, check)
	await _scenario_circle_platform(tree, check)
	await _scenario_fall_reset(tree, check)
	await _scenario_ramp(tree, check, SHIPPED_TPS)
	await _scenario_ramp(tree, check, DIAGNOSTIC_TPS)
	await _scenario_stairs(tree, check)
	await _scenario_ledge(tree, check)
	Engine.physics_ticks_per_second = 60  # the shipped rate, always restored


func _free_all(tree: SceneTree, nodes: Array[Node]) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame


## A MovingPlatform instance whose top face sits at `top`. The scene's box is 1 m tall, top at y 1.
func _spawn_platform(tree: SceneTree, top: Vector3, mode: MovingPlatform.Mode, travel: Vector3, speed: float, radius: float = 4.0) -> MovingPlatform:
	var scene: PackedScene = load(PLATFORM_SCENE) as PackedScene
	var platform: MovingPlatform = scene.instantiate() as MovingPlatform
	platform.mode = mode
	platform.travel = travel
	platform.speed = speed
	platform.radius = radius
	platform.position = top - Vector3(0.0, 1.0, 0.0)
	tree.root.add_child(platform)
	return platform


# Conveyor 3 m/s: an idle player is carried 3.0 +/- 0.3 m in 1 s and stays grounded.
func _scenario_conveyor_carry(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(200, 1, 60))
	floor_body.constant_linear_velocity = Vector3(3.0, 0.0, 0.0)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(-40.0, 0.0, 0.0))
	await Fixtures.wait_physics(tree, 10)
	var start_x: float = player.global_position.x
	var grounded_ticks: int = 0
	for i: int in SHIPPED_TPS:
		await Fixtures.wait_physics(tree, 1)
		if player.is_grounded():
			grounded_ticks += 1
	var carried: float = player.global_position.x - start_x
	check.call(absf(carried - 3.0) <= 0.3, "conveyor 3 m/s carries an idle player %.2f m in 1 s (3.0 +/- 0.3)" % carried)
	check.call(grounded_ticks == SHIPPED_TPS, "the player stays grounded on the conveyor (%d of %d ticks)" % [grounded_ticks, SHIPPED_TPS])
	check.call(player.horizontal_speed() < 0.01, "an idle player has no own horizontal velocity on a conveyor (%.3f)" % player.horizontal_speed())
	await _free_all(tree, [floor_body, player])


# Jumping off the conveyor keeps its velocity as momentum (D-13, Pitfall 3).
func _scenario_conveyor_jump(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(200, 1, 60))
	floor_body.constant_linear_velocity = Vector3(3.0, 0.0, 0.0)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(-40.0, 0.0, 0.0))
	await Fixtures.wait_physics(tree, 10)

	Input.action_press(&"jump")
	var left_floor: int = await Fixtures.wait_until(tree, func() -> bool: return not player.is_grounded(), 20)
	var launch_speed: float = player.move_velocity.x
	check.call(left_floor >= 0 and absf(launch_speed - 3.0) <= 0.15, "jumping off the conveyor keeps 3.0 +/- 0.15 m/s of horizontal momentum (%.3f)" % launch_speed)
	var x_before: float = player.global_position.x
	await Fixtures.wait_physics(tree, 12)
	check.call(player.global_position.x - x_before > 0.3 and not player.is_grounded(), "the player keeps drifting +X in the air (%.2f m in 12 ticks)" % (player.global_position.x - x_before))
	Input.action_release(&"jump")
	await _free_all(tree, [floor_body, player])


# LINEAR platform at 3 m/s: no drift over 1 s, a jump leaves with the platform's x speed.
func _scenario_linear_platform(tree: SceneTree, check: Callable) -> void:
	var platform: MovingPlatform = _spawn_platform(tree, Vector3(0.0, 0.0, 0.0), MovingPlatform.Mode.LINEAR, Vector3(12.0, 0.0, 0.0), 3.0)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 0.0))
	await Fixtures.wait_physics(tree, 12)
	check.call(platform.is_in_group(&"moving_platform"), "the platform joins group 'moving_platform'")
	var offset_start: float = player.global_position.x - platform.global_position.x
	var x_start: float = player.global_position.x
	await Fixtures.wait_physics(tree, SHIPPED_TPS)
	var offset_end: float = player.global_position.x - platform.global_position.x
	check.call(player.global_position.x - x_start > 2.5, "the platform really moved the player (%.2f m in 1 s)" % (player.global_position.x - x_start))
	check.call(absf(offset_end - offset_start) < 0.1, "the offset to a 3 m/s platform changes by %.3f m over 1 s (< 0.1)" % absf(offset_end - offset_start))

	Input.action_press(&"jump")
	var left_floor: int = await Fixtures.wait_until(tree, func() -> bool: return not player.is_grounded(), 20)
	var launch_speed: float = player.move_velocity.x
	check.call(left_floor >= 0 and absf(launch_speed - 3.0) <= 0.2, "a jump from the platform leaves with x speed 3.0 +/- 0.2 (%.3f)" % launch_speed)
	Input.action_release(&"jump")
	await _free_all(tree, [platform, player])


# Walking off the platform's front edge while holding input adds the platform velocity to the run.
func _scenario_platform_walk_off(tree: SceneTree, check: Callable) -> void:
	var platform: MovingPlatform = _spawn_platform(tree, Vector3(0.0, 0.0, 0.0), MovingPlatform.Mode.LINEAR, Vector3(12.0, 0.0, 0.0), 3.0)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(-1.5, 0.0, 0.0))
	await Fixtures.wait_physics(tree, 8)
	var config: MovementConfig = player.config

	Input.action_press(&"move_right")
	var left_floor: int = await Fixtures.wait_until(tree, func() -> bool: return not player.is_grounded(), 90)
	var leave_speed: float = player.move_velocity.x
	var expected: float = config.run_speed + 3.0 * config.platform_carry
	check.call(left_floor >= 0 and leave_speed >= expected - 0.3, "walking off at run speed keeps the platform speed: %.2f m/s >= %.2f" % [leave_speed, expected - 0.3])
	Input.action_release(&"move_right")
	await _free_all(tree, [platform, player])


# Vertical platform (2 m/s, 4 m): the feet stay within 0.1 m of the top on every tick through the top reversal.
func _scenario_vertical_platform(tree: SceneTree, check: Callable) -> void:
	var platform: MovingPlatform = _spawn_platform(tree, Vector3(0.0, 0.0, 0.0), MovingPlatform.Mode.LINEAR, Vector3(0.0, 4.0, 0.0), 2.0)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 0.0))
	await Fixtures.wait_physics(tree, 6)
	var worst: float = 0.0
	var max_top: float = 0.0
	var ticks: int = int(2.8 * SHIPPED_TPS)
	for i: int in ticks:
		await Fixtures.wait_physics(tree, 1)
		var top: float = platform.global_position.y + 1.0
		max_top = maxf(max_top, top)
		worst = maxf(worst, absf(player.global_position.y - top))
	check.call(max_top > 3.9, "the vertical platform reached its top and reversed (top %.2f)" % max_top)
	check.call(worst < 0.1, "the feet stay within 0.1 m of the vertical platform top through the reversal (worst %.3f)" % worst)
	await _free_all(tree, [platform, player])


# Circular platform (radius 4, 3 m/s): grounded on >= 95 % of ticks over 2 s, offset changes < 0.2 m.
func _scenario_circle_platform(tree: SceneTree, check: Callable) -> void:
	var platform: MovingPlatform = _spawn_platform(tree, Vector3(0.0, 0.0, 0.0), MovingPlatform.Mode.CIRCLE, Vector3.ZERO, 3.0, 4.0)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 0.0))
	await Fixtures.wait_physics(tree, 8)
	var offset_start: Vector3 = player.global_position - platform.global_position
	var platform_start: Vector3 = platform.global_position
	var grounded_ticks: int = 0
	var ticks: int = 2 * SHIPPED_TPS
	var worst_drift: float = 0.0
	for i: int in ticks:
		await Fixtures.wait_physics(tree, 1)
		if player.is_grounded():
			grounded_ticks += 1
		worst_drift = maxf(worst_drift, ((player.global_position - platform.global_position) - offset_start).length())
	check.call(platform.global_position.distance_to(platform_start) > 3.0, "the circular platform moved (%.2f m from its start)" % platform.global_position.distance_to(platform_start))
	check.call(float(grounded_ticks) >= 0.95 * float(ticks), "grounded on the circular platform on %d of %d ticks (>= 95 percent)" % [grounded_ticks, ticks])
	check.call(worst_drift < 0.2, "the offset to the circular platform changes by at most %.3f m (< 0.2)" % worst_drift)
	await _free_all(tree, [platform, player])


# FallReset below a hole: the player falls in and is back at the respawn marker with zero velocity.
func _scenario_fall_reset(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(10, 1, 10))
	var marker: Marker3D = Marker3D.new()
	marker.position = Vector3(0.0, 0.0, 0.0)
	tree.root.add_child(marker)

	var reset: FallReset = FallReset.new()
	var volume: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40.0, 2.0, 40.0)
	volume.shape = box
	reset.add_child(volume)
	reset.position = Vector3(30.0, -10.0, 0.0)
	reset.respawn = marker
	tree.root.add_child(reset)

	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(30.0, 5.0, 0.0))
	var rig: CameraRig = Fixtures.spawn_camera_rig(tree.root, player)
	reset.camera_rig = rig
	check.call(reset.collision_layer == PhysicsLayers.HAZARD and reset.collision_mask == PhysicsLayers.PLAYER, "FallReset sits on Hazard and masks Player")

	var fell_below: int = await Fixtures.wait_until(tree, func() -> bool: return player.global_position.y < -5.0, 120)
	check.call(fell_below >= 0, "the player teleported above a hole falls in")
	var back: int = await Fixtures.wait_until(tree, func() -> bool:
		return player.global_position.distance_to(marker.global_position) < 0.1 and player.move_velocity == Vector3.ZERO and absf(player.vertical_speed) < 0.001 and player.is_grounded(), 120)
	check.call(back >= 0, "the player is back at the respawn marker within 120 ticks (waited %d, at %s)" % [back, player.global_position])
	check.call(player.move_velocity == Vector3.ZERO and absf(player.vertical_speed) < 0.001, "move_velocity and vertical_speed are zero after the reset")
	await Fixtures.wait_process(tree, 3)
	var pivot: Vector3 = player.get_global_transform_interpolated().origin
	check.call(rig.global_position.distance_to(pivot) < 10.0, "the camera rig was snapped to the respawn (%.2f m from the player)" % rig.global_position.distance_to(pivot))
	await _free_all(tree, [floor_body, marker, reset, rig, player])


## Height of the surface straight below the player (World mask), or -INF without one.
func _surface_below(player: PlayerController) -> float:
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var from: Vector3 = player.global_position + Vector3.UP * 0.5
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0, PhysicsLayers.WORLD)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return -INF
	return (hit["position"] as Vector3).y


## Holds `action` until `done` is true or `max_ticks` pass; samples the run every tick. Returns
## {reached, ticks, airborne, max_height (above the surface below), max_gap (while airborne),
##  max_y, band_ok, grounded_samples}.
func _drive(tree: SceneTree, player: PlayerController, action: StringName, done: Callable, max_ticks: int) -> Dictionary:
	var stats: Dictionary = {"reached": false, "ticks": 0, "airborne": 0, "max_height": 0.0, "max_gap": 0.0, "max_y": player.global_position.y, "band_ok": true, "grounded_samples": 0}
	Input.action_press(action)
	while stats["ticks"] < max_ticks:
		await Fixtures.wait_physics(tree, 1)
		stats["ticks"] += 1
		var surface: float = _surface_below(player)
		var height: float = player.global_position.y - surface if surface > -INF else 0.0
		stats["max_height"] = maxf(stats["max_height"], height)
		stats["max_y"] = maxf(stats["max_y"], player.global_position.y)
		if player.is_grounded():
			stats["grounded_samples"] += 1
			var snap: float = player.floor_snap_length
			if snap < 0.3 - SNAP_TOLERANCE or snap > 0.5 + SNAP_TOLERANCE:
				stats["band_ok"] = false
		else:
			stats["airborne"] += 1
			stats["max_gap"] = maxf(stats["max_gap"], height)
		if done.call():
			stats["reached"] = true
			break
	Input.action_release(action)
	return stats


## Floor, the 45 degree Slope at the origin (rising toward -X, 4 m high) and a plateau (top y 4) behind it.
func _build_ramp(tree: SceneTree) -> Array[Node]:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(80, 1, 40))
	var slope: StaticBody3D = (load(SLOPE_SCENE) as PackedScene).instantiate() as StaticBody3D
	tree.root.add_child(slope)
	var plateau: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(8, 4, 4), Vector3(-6.0, 2.0, 0.0))
	return [floor_body, slope, plateau]


# 45 degree ramp up and down at 10.5 m/s. At 60 TPS: no airborne tick, no launch, snap inside D-13's band.
# At 10 TPS (A22) only "no launch" and "reaches the far surface" are asserted; airborne counts are printed.
func _scenario_ramp(tree: SceneTree, check: Callable, tps: int) -> void:
	Engine.physics_ticks_per_second = tps
	var label: String = "%d TPS" % tps
	var shipped: bool = tps == SHIPPED_TPS
	var path_length: float = 6.0 + sqrt(32.0) + 1.0
	var budget: int = int(ceil((path_length / RAMP_RUN_SPEED + 0.5) * float(tps)))

	# Up: from the floor at x 8 toward -X onto the plateau.
	var nodes: Array[Node] = _build_ramp(tree)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(8.0, 0.0, 0.0))
	player.config = player.config.duplicate() as MovementConfig
	player.config.run_speed = RAMP_RUN_SPEED
	await Fixtures.wait_physics(tree, 5)
	nodes.append(player)
	var up: Dictionary = await _drive(tree, player, &"move_left", func() -> bool: return player.global_position.x < -3.0 and player.global_position.y > 3.9, budget)
	print("DIAG [test_platforms] %s ramp up: reached=%s ticks=%d airborne=%d max_gap=%.3f max_height=%.3f max_y=%.3f" % [label, up["reached"], up["ticks"], up["airborne"], up["max_gap"], up["max_height"], up["max_y"]])
	check.call(up["reached"], "%s ramp up: the plateau is reached within %d ticks (%d used)" % [label, budget, up["ticks"]])
	if shipped:
		check.call(up["airborne"] == 0, "%s ramp up: 0 airborne ticks (got %d)" % [label, up["airborne"]])
		check.call(up["max_height"] <= 0.3, "%s ramp up: never more than 0.3 m above the surface (%.3f)" % [label, up["max_height"]])
		check.call(up["band_ok"] and up["grounded_samples"] > 20, "%s ramp up: floor_snap_length inside [0.3, 0.5] on every grounded tick (%d samples)" % [label, up["grounded_samples"]])
	else:
		check.call(up["max_y"] <= 4.0 + 0.3, "%s ramp up: no launch, never above the highest surface + 0.3 m (max y %.3f)" % [label, up["max_y"]])
		check.call(up["band_ok"], "%s ramp up: the snap band was not widened" % label)

	# Down: from the plateau toward +X onto the floor beyond the ramp.
	player.teleport(Vector3(-8.0, 4.0, 0.0))
	await Fixtures.wait_physics(tree, 5)
	var down: Dictionary = await _drive(tree, player, &"move_right", func() -> bool: return player.global_position.x > 4.0 and player.global_position.y < 0.1, budget)
	print("DIAG [test_platforms] %s ramp down: reached=%s ticks=%d airborne=%d max_gap=%.3f max_height=%.3f max_y=%.3f" % [label, down["reached"], down["ticks"], down["airborne"], down["max_gap"], down["max_height"], down["max_y"]])
	check.call(down["reached"], "%s ramp down: the floor beyond the ramp is reached within %d ticks (%d used)" % [label, budget, down["ticks"]])
	if shipped:
		check.call(down["airborne"] == 0, "%s ramp down: 0 airborne ticks (got %d)" % [label, down["airborne"]])
		check.call(down["band_ok"] and down["grounded_samples"] > 20, "%s ramp down: floor_snap_length inside [0.3, 0.5] on every grounded tick (%d samples)" % [label, down["grounded_samples"]])
	else:
		check.call(down["max_y"] <= 4.0 + 0.3, "%s ramp down: no launch, never above the highest surface + 0.3 m (max y %.3f)" % [label, down["max_y"]])
		check.call(down["band_ok"], "%s ramp down: the snap band was not widened" % label)

	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _free_all(tree, nodes)


## A Primitive_Beam riser with its top at `top_y`, sunk into the floor, turned so its 4 m length runs along Z
## and its 1 m depth along X, centred at `x`.
func _spawn_riser(tree: SceneTree, x: float, top_y: float) -> StaticBody3D:
	var beam: StaticBody3D = (load(BEAM_SCENE) as PackedScene).instantiate() as StaticBody3D
	beam.rotation.y = PI / 2.0
	beam.position = Vector3(x, top_y - 1.0, 0.0)
	tree.root.add_child(beam)
	return beam


# Six 0.15 m risers climbed at run speed without a jump, descended with 0 airborne ticks (A4).
func _scenario_stairs(tree: SceneTree, check: Callable) -> void:
	var bus: Node = tree.root.get_node("EventBus")
	var jumped: Array[int] = [0]
	var on_jumped: Callable = func(_position: Vector3) -> void: jumped[0] += 1
	bus.connect(&"jumped", on_jumped)

	var nodes: Array[Node] = [Fixtures.spawn_floor(tree.root, Vector3(80, 1, 40))]
	for n: int in range(1, 7):
		nodes.append(_spawn_riser(tree, 10.0 - float(n), 0.15 * float(n)))
	nodes.append(Fixtures.spawn_box(tree.root, Vector3(8, 0.9, 4), Vector3(-0.5, 0.45, 0.0)))
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(14.0, 0.0, 0.0))
	player.config = player.config.duplicate() as MovementConfig
	player.config.run_speed = RAMP_RUN_SPEED
	await Fixtures.wait_physics(tree, 5)
	nodes.append(player)

	var up: Dictionary = await _drive(tree, player, &"move_left", func() -> bool: return player.global_position.x < 0.0 and player.is_grounded(), 4 * SHIPPED_TPS)
	await Fixtures.wait_physics(tree, 3)
	check.call(up["reached"] and absf(player.global_position.y - 0.9) <= 0.05, "stairs up: the landing is reached at y 0.90 +/- 0.05 (y=%.3f)" % player.global_position.y)
	check.call(jumped[0] == 0, "stairs up: no jumped fact, the risers are climbed by running (%d)" % jumped[0])
	print("DIAG [test_platforms] stairs up: ticks=%d airborne=%d max_gap=%.3f" % [up["ticks"], up["airborne"], up["max_gap"]])

	player.teleport(Vector3(-3.0, 0.9, 0.0))
	await Fixtures.wait_physics(tree, 5)
	var down: Dictionary = await _drive(tree, player, &"move_right", func() -> bool: return player.global_position.x > 12.0 and player.global_position.y < 0.05, 4 * SHIPPED_TPS)
	check.call(down["reached"], "stairs down: the floor beyond the stairs is reached (%d ticks)" % down["ticks"])
	check.call(down["airborne"] == 0, "stairs down: 0 airborne ticks at 60 TPS (got %d)" % down["airborne"])
	check.call(jumped[0] == 0, "stairs down: still no jumped fact")

	bus.disconnect(&"jumped", on_jumped)
	await _free_all(tree, nodes)


# A 0.25 m ledge blocks the player: taller ledges need a jump (the 0.18 m limit is documented).
func _scenario_ledge(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = [Fixtures.spawn_floor(tree.root, Vector3(80, 1, 40))]
	nodes.append(_spawn_riser(tree, 0.0, 0.25))
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(6.0, 0.0, 0.0))
	player.config = player.config.duplicate() as MovementConfig
	player.config.run_speed = RAMP_RUN_SPEED
	await Fixtures.wait_physics(tree, 5)
	nodes.append(player)

	Input.action_press(&"move_left")
	await Fixtures.wait_physics(tree, SHIPPED_TPS)
	Input.action_release(&"move_left")
	check.call(player.global_position.y < 0.05, "a 0.25 m ledge blocks the run: the player stays below y 0.05 (y=%.3f)" % player.global_position.y)
	check.call(player.global_position.x > 0.9, "the player is held in front of the ledge (x=%.3f)" % player.global_position.x)
	await _free_all(tree, nodes)
