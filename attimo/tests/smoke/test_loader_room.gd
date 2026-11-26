extends RefCounted
## Plan 05-02 (HAND-04, D-21): Zone_Loader, the Loader test room behind the hall's west door. The gap and ledge sizes are computed from
## MovementConfig through LoaderMath at build time, so this test recomputes them from the CURRENT config and fails until the gym is
## regenerated after a retune (T-05-07). Live: a discharge with a full core clears the gap and reaches the ledge, an empty arm falls
## into the pit and is respawned with one core.

const Fixtures := preload("res://tests/fixtures.gd")

const GYM_SCENE: String = "res://scenes/test/movement_gym.tscn"
const STATIONS: Array[String] = ["Loader_Redirect", "Loader_Air", "Loader_Gap", "Loader_SuperJump"]
const MARGIN: float = 0.5
const LANE_X_FROM: int = -44
const LANE_X_TO: int = -114
const FLOOR_TOLERANCE: float = 0.1
const RESPAWN_TOLERANCE: float = 1.5

var _gym: Node
var _player: PlayerController


func run(tree: SceneTree, check: Callable) -> void:
	var packed: PackedScene = load(GYM_SCENE) as PackedScene
	check.call(packed != null, "the movement gym loads")
	if packed == null:
		return
	_gym = packed.instantiate()
	tree.root.add_child(_gym)
	await Fixtures.wait_physics(tree, 20)
	var zone: Node3D = _gym.get_node_or_null("Zone_Loader") as Node3D
	check.call(zone != null, "the gym has Zone_Loader")
	_player = _gym.get_node("Player") as PlayerController
	if zone != null and _player != null:
		var config: MovementConfig = _player.config
		_check_door_and_lane(zone, check)
		_check_stations(zone, check)
		_check_gap_numbers(zone, config, check)
		_check_ledge_numbers(zone, config, check)
		await _live_gap(tree, zone, check, true)
		await _live_gap(tree, zone, check, false)
		await _live_ledge(tree, zone, check, true)
		await _live_ledge(tree, zone, check, false)
	_release_inputs()
	Fixtures.restore_time()
	_gym.queue_free()
	await _gym.tree_exited


func _check_door_and_lane(zone: Node3D, check: Callable) -> void:
	var hall: Node = _gym.get_node("Hall")
	check.call(hall.get_node_or_null("WallWest_0") == null, "the hall west wall has the door cell open (no WallWest_0)")
	check.call(hall.get_node_or_null("WallWest_1") != null, "the rest of the west wall stands")
	check.call(zone.get_node_or_null("LoaderWallWest_1") != null and zone.get_node_or_null("LoaderWallWest_0") == null, "the room's west wall is built per cell and cell 0 is the open doorway into Zone_Energy (05-05)")
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var bad_floor: PackedInt32Array = PackedInt32Array()
	var blocked: PackedInt32Array = PackedInt32Array()
	for x: int in range(LANE_X_FROM, LANE_X_TO - 1, -1):
		var down: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 2.0, 0.0), Vector3(x, -2.0, 0.0), PhysicsLayers.WORLD))
		if down.is_empty() or absf((down["position"] as Vector3).y) > FLOOR_TOLERANCE:
			bad_floor.append(x)
		# The west wall (x -115) is the lane's end, so the horizontal ray stops one metre before it.
		var ahead: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 1.0, 0.0), Vector3(maxf(x - 1.0, -114.4), 1.0, 0.0), PhysicsLayers.WORLD))
		if not ahead.is_empty():
			blocked.append(x)
	check.call(bad_floor.is_empty(), "the walk lane z 0 is plain floor at y 0 from x %d to %d (bad: %s)" % [LANE_X_FROM, LANE_X_TO, bad_floor])
	check.call(blocked.is_empty(), "nothing blocks the lane at 1 m height (blocked at: %s)" % [blocked])
	var door_landing: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-40.0, 2.0, 0.0), Vector3(-40.0, -2.0, 0.0), PhysicsLayers.WORLD))
	var threshold: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-42.5, 2.0, 0.0), Vector3(-42.5, -2.0, 0.0), PhysicsLayers.WORLD))
	check.call(not door_landing.is_empty() and not threshold.is_empty(), "the door cell has floor from the landing tile to the room")
	check.call(zone.get_node_or_null("FallResetLoader") != null and zone.get_node_or_null("Respawn_Loader") != null, "FallResetLoader and its respawn marker exist")


func _check_stations(zone: Node3D, check: Callable) -> void:
	for tag: String in STATIONS:
		var station: Node3D = zone.get_node_or_null(tag) as Node3D
		check.call(station != null, "station %s is a direct child of Zone_Loader" % tag)
		if station == null:
			continue
		var sign_label: Label3D = station.get_node_or_null("Label_%s" % tag) as Label3D
		var expect: Label3D = station.get_node_or_null("Label_%s_Expect" % tag) as Label3D
		check.call(sign_label != null and sign_label.text != "", "%s has a sign" % tag)
		check.call(expect != null and expect.text.begins_with("Erwartet:"), "%s has an 'Erwartet:' line" % tag)
		check.call(station.get_node_or_null("Launch") != null, "%s has a Launch marker" % tag)


func _check_gap_numbers(zone: Node3D, config: MovementConfig, check: Callable) -> void:
	var gap: Node3D = zone.get_node("Loader_Gap") as Node3D
	var width: float = float(gap.get_meta(&"gap_width"))
	var direction: Vector3 = gap.get_meta(&"launch_direction") as Vector3
	var base_speed: float = LoaderMath.legacy_speed(0.0, config.loader_min_push, 0.0, config.loader_max_speed)
	var bonus_speed: float = LoaderMath.legacy_speed(0.0, config.loader_min_push, config.loader_bonus_speed, config.loader_max_speed)
	var base_reach: float = LoaderMath.flat_reach(LoaderMath.discharge_velocity(direction, base_speed), config)
	var bonus_reach: float = LoaderMath.flat_reach(LoaderMath.discharge_velocity(direction, bonus_speed), config)
	check.call(absf(float(gap.get_meta(&"base_reach")) - base_reach) < 0.05 and absf(float(gap.get_meta(&"bonus_reach")) - bonus_reach) < 0.05, "the gym's stored reaches match the current config (rebuild the gym after a retune): %.2f/%.2f vs %.2f/%.2f" % [float(gap.get_meta(&"base_reach")), float(gap.get_meta(&"bonus_reach")), base_reach, bonus_reach])
	check.call(base_reach + MARGIN <= width and width <= bonus_reach - MARGIN, "the gap %.1f m is at least %.1f m wider than the base reach %.2f and %.1f m narrower than the bonus reach %.2f" % [width, MARGIN, base_reach, MARGIN, bonus_reach])


func _check_ledge_numbers(zone: Node3D, config: MovementConfig, check: Callable) -> void:
	var station: Node3D = zone.get_node("Loader_SuperJump") as Node3D
	var height: float = float(station.get_meta(&"ledge_height"))
	var apex_min: float = LoaderMath.apex_height(config.loader_min_push, config)
	var apex_bonus: float = LoaderMath.apex_height(minf(config.loader_min_push + config.loader_bonus_speed, config.loader_max_speed), config)
	check.call(apex_min + MARGIN <= height and height <= apex_bonus - MARGIN, "the ledge %.1f m is above the base apex %.2f and below the bonus apex %.2f (margin %.1f m)" % [height, apex_min, apex_bonus, MARGIN])
	check.call(height > config.jump_3_height + MARGIN, "a plain Jump 3 (%.1f m) cannot reach the ledge %.1f m" % [config.jump_3_height, height])


## Puts the player on the station's Launch marker with `energy` and fires a discharge along `direction` after a 10 tick hold.
func _fire(tree: SceneTree, station: Node3D, direction: Vector3, energy: int) -> void:
	var marker: Marker3D = station.get_node("Launch") as Marker3D
	_player.call(&"respawn", marker.global_position)
	Fixtures.set_energy(_player, energy)
	_player.debug_loader_direction = direction
	await Fixtures.wait_until(tree, func() -> bool: return _player.is_on_floor(), 60)
	await Fixtures.wait_physics(tree, 3)
	Input.action_press(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return _player.loader_active(), 6)
	await Fixtures.wait_physics(tree, 10)
	Input.action_release(&"loader")


func _release_inputs() -> void:
	Input.action_release(&"loader")
	if _player != null:
		_player.debug_loader_direction = Vector3.ZERO


## Plan 05.1-11: the gap and the ledge were sized for the ballistic bonus discharge; 05.1-12 re-derives them from the straight reach.
## Until then "with a core" is a full 3-step Loader and "without a core" is an empty clock (the press is refused, D-48): the player
## never leaves the platform.
func _live_gap(tree: SceneTree, zone: Node3D, check: Callable, with_core: bool) -> void:
	var gap: Node3D = zone.get_node("Loader_Gap") as Node3D
	var far_edge: float = float(gap.get_meta(&"far_edge_x"))
	var label: String = "gap with a core" if with_core else "gap without a core"
	await _fire(tree, gap, gap.get_meta(&"launch_direction") as Vector3, 3 if with_core else 0)
	if with_core:
		await Fixtures.wait_until(tree, func() -> bool: return _player.is_on_floor() and _player.global_position.x < far_edge, 240)
		var pos: Vector3 = _player.global_position
		check.call(pos.x < far_edge and absf(pos.y) < 0.3, "(%s) the player stands on the far island (x %.2f, far edge %.2f, y %.2f)" % [label, pos.x, far_edge, pos.y])
		check.call(Engine.time_scale == 1.0, "(%s) Engine.time_scale is 1.0" % label)
	else:
		await Fixtures.wait_physics(tree, 120)
		var marker: Marker3D = gap.get_node("Launch") as Marker3D
		check.call(_player.global_position.distance_to(marker.global_position) < 1.0 and _player.global_position.x > far_edge, "(%s) the refused press leaves the player on the near platform (at %s)" % [label, _player.global_position])
		check.call(Engine.time_scale == 1.0, "(%s) Engine.time_scale is 1.0" % label)
	_release_inputs()
	Fixtures.restore_time()


func _live_ledge(tree: SceneTree, zone: Node3D, check: Callable, with_core: bool) -> void:
	var station: Node3D = zone.get_node("Loader_SuperJump") as Node3D
	var height: float = float(station.get_meta(&"ledge_height"))
	var label: String = "ledge with a core" if with_core else "ledge without a core"
	await _fire(tree, station, station.get_meta(&"launch_direction") as Vector3, 3 if with_core else 0)
	var peak: float = 0.0
	for i: int in 180:
		await tree.physics_frame
		peak = maxf(peak, _player.global_position.y)
	if with_core:
		check.call(peak > height, "(%s) the straight 3-step discharge rises above the ledge (peak %.1f, ledge %.1f)" % [label, peak, height])
	else:
		check.call(peak < 0.5, "(%s) an empty clock does not lift the player (peak %.1f)" % [label, peak])
	_release_inputs()
	Fixtures.restore_time()
