extends RefCounted
## Plan 05-05 (FEEL-10, ENRG-02, ENRG-03, D-22..D-24): Zone_Energy, the energy test area west of the Loader room. Static contract (zone,
## doorway, stations, signs, fall reset), the walk route hall -> Loader room -> doorway -> Zone_Energy (rays plus a live walk), live charge
## track and capsule checks, drain plates, the injected-move stations, capsules next to every shot, and the hip-fire sign wording.

const Fixtures := preload("res://tests/fixtures.gd")

const GYM_SCENE: String = "res://scenes/test/movement_gym.tscn"
const X_EAST: float = -115.0
const X_WEST: float = -239.0
const TRACK_MIN_LENGTH: float = 100.0
const FLOOR_TOLERANCE: float = 0.1
## Stations of Zone_Energy (every one a direct child with a sign and an "Erwartet:" line).
const STATIONS: Array[String] = ["Energy_Track", "Energy_Capsule"]
## Injected-move stations: a drain plate (the base version) and a capsule (the injected version) next to each.
const INJECTED: Array[String] = ["Energy_AirDash", "Energy_DashHop", "Energy_WallRun"]
## Shot stations of Zone_Energy.
const SHOT_STATIONS: Array[String] = ["Shot_TapVsFull", "Shot_Moving"]
const CAPSULE_REACH: float = 8.0
## Words no sign may contain (D-20): the aiming mode and the old big/small pulse by hold time.
const STALE_WORDS: Array[String] = ["RMB", "Rechtsklick halten und", "Zielen", "großer Puls", "Großer Puls", "kleiner Puls"]

var _gym: Node
var _zone: Node3D
var _player: PlayerController
var _rig: CameraRig


func run(tree: SceneTree, check: Callable) -> void:
	var packed: PackedScene = load(GYM_SCENE) as PackedScene
	check.call(packed != null, "the movement gym loads")
	if packed == null:
		return
	_gym = packed.instantiate()
	tree.root.add_child(_gym)
	await Fixtures.wait_physics(tree, 20)
	_zone = _gym.get_node_or_null("Zone_Energy") as Node3D
	check.call(_zone != null, "the gym has Zone_Energy")
	_player = _gym.get_node("Player") as PlayerController
	_rig = _gym.get_node("CameraRig") as CameraRig
	if _zone != null and _player != null and _rig != null:
		_check_contract(check)
		_check_stations(check)
		_check_route(check)
		await _live_walk(tree, check)
		await _live_track(tree, check)
		await _live_capsule(tree, check)
	_release_inputs()
	Fixtures.restore_time()
	_gym.queue_free()
	await _gym.tree_exited


# --- static contract ------------------------------------------------------------------------------------------


func _check_contract(check: Callable) -> void:
	var range: Vector2 = _zone.get_meta(&"x_range", Vector2.ZERO) as Vector2
	check.call(is_equal_approx(range.x, X_WEST) and is_equal_approx(range.y, X_EAST), "Zone_Energy stores x_range (%.0f, %.0f) (got %s)" % [X_WEST, X_EAST, range])
	var loader: Node3D = _gym.get_node("Zone_Loader") as Node3D
	check.call(loader.get_node_or_null("LoaderWallWest_0") == null and loader.get_node_or_null("LoaderWallWest_1") != null, "the Loader room's west wall leaves the z -2..2 cell open (no LoaderWallWest_0, the rest stands)")
	var reset: FallReset = _zone.get_node_or_null("FallResetEnergy") as FallReset
	var loader_reset: FallReset = loader.get_node_or_null("FallResetLoader") as FallReset
	check.call(reset != null and loader_reset != null, "FallResetEnergy and FallResetLoader exist")
	if reset != null and loader_reset != null:
		var own: Vector2 = _reset_x_extent(reset)
		var other: Vector2 = _reset_x_extent(loader_reset)
		check.call(own.y <= X_EAST + 0.01 and own.x >= X_WEST - 0.01, "FallResetEnergy covers only x %.0f..%.0f (got %.2f..%.2f)" % [X_WEST, X_EAST, own.x, own.y])
		check.call(own.y <= other.x + 0.01 or own.x >= other.y - 0.01, "FallResetEnergy and FallResetLoader do not overlap (energy %s, loader %s)" % [own, other])
		check.call(reset.respawn != null and reset.respawn.global_position.x < X_EAST and reset.respawn.global_position.x > X_WEST, "FallResetEnergy respawns at a marker inside the zone")
		check.call(reset.camera_rig != null, "FallResetEnergy snaps the camera rig")
	var track: Node3D = _zone.get_node_or_null("Energy_Track") as Node3D
	if track != null:
		check.call(float(track.get_meta(&"length", 0.0)) >= TRACK_MIN_LENGTH, "the charge track is at least %.0f m long (got %.1f)" % [TRACK_MIN_LENGTH, float(track.get_meta(&"length", 0.0))])
		_check_track_floor(track, check)


## The world x extent (min, max) of the first box shape of a fall reset.
func _reset_x_extent(area: FallReset) -> Vector2:
	var shape: BoxShape3D = (area.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	return Vector2(area.global_position.x - shape.size.x * 0.5, area.global_position.x + shape.size.x * 0.5)


## One straight walkable strip: floor at y 0 every metre along z 0 over the whole track.
func _check_track_floor(track: Node3D, check: Callable) -> void:
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var x_from: float = float(track.get_meta(&"x_from"))
	var x_to: float = float(track.get_meta(&"x_to"))
	var bad: PackedFloat32Array = PackedFloat32Array()
	var x: float = x_from
	while x >= x_to:
		var down: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 2.0, 0.0), Vector3(x, -2.0, 0.0), PhysicsLayers.WORLD))
		if down.is_empty() or absf((down["position"] as Vector3).y) > FLOOR_TOLERANCE:
			bad.append(x)
		x -= 1.0
	check.call(bad.is_empty(), "the track floor is solid at y 0 from x %.0f to %.0f (bad: %s)" % [x_from, x_to, bad])


func _check_stations(check: Callable) -> void:
	for tag: String in STATIONS:
		var station: Node3D = _zone.get_node_or_null(tag) as Node3D
		check.call(station != null, "station %s is a direct child of Zone_Energy" % tag)
		if station == null:
			continue
		var sign_label: Label3D = station.get_node_or_null("Label_%s" % tag) as Label3D
		var expect: Label3D = station.get_node_or_null("Label_%s_Expect" % tag) as Label3D
		check.call(sign_label != null and sign_label.text != "", "%s has a sign" % tag)
		check.call(expect != null and expect.text.begins_with("Erwartet:"), "%s has an 'Erwartet:' line" % tag)


func _nearest_capsule(point: Vector3) -> EnergySource:
	var best: EnergySource = null
	var best_distance: float = INF
	for node: Node in _gym.find_children("*", "Node3D", true, false):
		var source: EnergySource = node as EnergySource
		if source != null and source.global_position.distance_to(point) < best_distance:
			best = source
			best_distance = source.global_position.distance_to(point)
	return best


# --- route ----------------------------------------------------------------------------------------------------


## Static rays in the generated gym: no hole, wall or step on the walk lane from the Loader room through the doorway into Zone_Energy.
func _check_route(check: Callable) -> void:
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var bad_floor: PackedStringArray = PackedStringArray()
	for z: float in [-1.5, 0.0, 1.5]:
		for x: int in range(-44, -126, -1):
			var down: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 2.0, z), Vector3(x, -2.0, z), PhysicsLayers.WORLD))
			if down.is_empty() or absf((down["position"] as Vector3).y) > FLOOR_TOLERANCE:
				bad_floor.append("%d/%.1f" % [x, z])
	check.call(bad_floor.is_empty(), "the lane z -1.5, 0, 1.5 is floor at y 0 from x -44 to -125 (bad: %s)" % [bad_floor])
	var ahead: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-44.0, 1.0, 0.0), Vector3(-125.0, 1.0, 0.0), PhysicsLayers.WORLD))
	check.call(ahead.is_empty(), "nothing blocks the lane at 1 m height from x -44 to -125 (hit at %s)" % [ahead.get("position", Vector3.ZERO)])


func _face_west() -> void:
	_rig.yaw = PI * 0.5
	_rig.rotation.y = _rig.yaw


## Live walk: from inside the Loader room, only holding forward, through the doorway into Zone_Energy.
func _live_walk(tree: SceneTree, check: Callable) -> void:
	_player.call(&"respawn", Vector3(-109.0, 0.0, 0.0))
	Fixtures.set_energy(_player, 25.0)
	await Fixtures.wait_physics(tree, 20)
	_face_west()
	var lowest: float = INF
	Input.action_press(&"move_forward")
	var ticks: int = ceili(2.5 * Engine.physics_ticks_per_second)
	for i: int in ticks:
		await tree.physics_frame
		lowest = minf(lowest, _player.global_position.y)
	Input.action_release(&"move_forward")
	var pos: Vector3 = _player.global_position
	check.call(pos.x < -121.0, "walking west from the Loader room ends past x -121 (x %.2f)" % pos.x)
	check.call(_player.is_grounded() and lowest > -0.5, "the walk never fell (lowest y %.2f)" % lowest)
	check.call(is_equal_approx(_player.arm_energy.value, 25.0), "plain walking leaves the arm at 25 (got %.2f)" % _player.arm_energy.value)


## Charge track: a dash-hop chain raises the arm, plain running does not.
func _live_track(tree: SceneTree, check: Callable) -> void:
	var track: Node3D = _zone.get_node("Energy_Track") as Node3D
	var start: Vector3 = Vector3(float(track.get_meta(&"x_from")), 0.0, 0.0)
	# Plain running at run_speed (below the passive start speed) for 3 s.
	_player.call(&"respawn", start)
	Fixtures.set_energy(_player, 25.0)
	await Fixtures.wait_physics(tree, 20)
	_face_west()
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, ceili(3.0 * Engine.physics_ticks_per_second))
	Input.action_release(&"move_forward")
	check.call(absf(_player.arm_energy.value - 25.0) < 0.01, "plain running along the track leaves the arm at 25 (got %.3f)" % _player.arm_energy.value)
	# A dash-hop chain from an empty arm (every hop is the free stage 1) for 3 s.
	_player.call(&"respawn", start)
	Fixtures.set_energy(_player, 0.0)
	await Fixtures.wait_physics(tree, 20)
	_face_west()
	Input.action_press(&"move_forward")
	var ticks: int = ceili(3.0 * Engine.physics_ticks_per_second)
	for i: int in ticks:
		if _player.is_grounded():
			Input.action_press(&"dash")
			Input.action_press(&"jump")
			await tree.physics_frame
			Input.action_release(&"dash")
			Input.action_release(&"jump")
		else:
			await tree.physics_frame
	Input.action_release(&"move_forward")
	check.call(_player.arm_energy.value > 1.0, "a dash-hop chain along the track charges the arm (got %.2f)" % _player.arm_energy.value)
	_release_inputs()


## Capsule: hold the Extractor at the capsule next to the entry, the arm fills; the capsule is full again after its respawn time.
func _live_capsule(tree: SceneTree, check: Callable) -> void:
	var station: Node3D = _zone.get_node("Energy_Capsule") as Node3D
	var stand: Marker3D = station.get_node("Start") as Marker3D
	var capsule: EnergySource = _nearest_capsule(stand.global_position)
	check.call(capsule != null, "the capsule station has an EnergySource")
	if capsule == null:
		return
	_player.call(&"respawn", stand.global_position)
	Fixtures.set_energy(_player, 25.0)
	await Fixtures.wait_physics(tree, 20)
	_face_west()
	await Fixtures.wait_physics(tree, 20)
	await Fixtures.tap_action(tree, &"module_2", 2)
	await Fixtures.wait_physics(tree, 2)
	await Fixtures.hold_action(tree, &"use_hand", 0.6)
	await Fixtures.wait_physics(tree, 3)
	check.call(_player.arm_energy.value >= 60.0, "draining the capsule with the Extractor gives at least 60 (got %.2f)" % _player.arm_energy.value)
	check.call(not capsule.is_available(), "the drained capsule is empty")
	await Fixtures.wait_physics(tree, ceili(capsule.respawn_time * Engine.physics_ticks_per_second) + 10)
	check.call(capsule.is_available(), "the capsule refills after its respawn time %.1f s" % capsule.respawn_time)
	_release_inputs()


func _release_inputs() -> void:
	for action: StringName in [&"move_forward", &"dash", &"jump", &"use_hand", &"module_2", &"loader"]:
		Input.action_release(action)
