extends RefCounted
## Plan 05-05 (FEEL-10, ENRG-02, ENRG-03, D-22..D-24): Zone_Energy, the energy test area west of the Loader room. Static contract (zone,
## doorway, stations, signs, fall reset), the walk route hall -> Loader room -> doorway -> Zone_Energy (rays plus a live walk), the live
## capsule check (no charge track: movement no longer charges the arm, D-41), drain plates, the injected-move stations, capsules next to the former shot stations (kept until 05.1-13), and the sign wording.

const Fixtures := preload("res://tests/fixtures.gd")

const GYM_SCENE: String = "res://scenes/test/movement_gym.tscn"
const X_EAST: float = -115.0
const X_WEST: float = -239.0
const FLOOR_TOLERANCE: float = 0.1
## Stations of Zone_Energy (every one a direct child with a sign and an "Erwartet:" line).
const STATIONS: Array[String] = [
	"Energy_Capsule", "Energy_BoostLine", "Energy_Machine", "Energy_ChargeSpot", "Energy_Drain",
	"Energy_AirDash", "Energy_DashHop", "Energy_WallRun", "Shot_TapVsFull", "Shot_Moving",
]
## Injected-move stations: a drain plate (the base version) and a capsule (the injected version) next to each.
const INJECTED: Array[String] = ["Energy_AirDash", "Energy_DashHop", "Energy_WallRun"]
## The former shot stations of Zone_Energy (the shot is gone, D-45; 05.1-13 swaps them for Loader-field obstacles).
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
		await _live_capsule(tree, check)
		_check_capsules_near_shots(check)
		_check_signs(check)
		await _live_drain(tree, check)
		await _live_air_dash(tree, check, 0)
		await _live_air_dash(tree, check, 5)
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


## The world x extent (min, max) of the first box shape of a fall reset.
func _reset_x_extent(area: FallReset) -> Vector2:
	var shape: BoxShape3D = (area.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	return Vector2(area.global_position.x - shape.size.x * 0.5, area.global_position.x + shape.size.x * 0.5)


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
	var plates: int = 0
	for node: Node in _gym.find_children("*", "Area3D", true, false):
		if node is EnergyDrainPlate:
			plates += 1
	check.call(plates >= 4, "Zone_Energy has a lone drain plate and one per injected-move station (got %d)" % plates)
	for tag: String in INJECTED:
		var station: Node3D = _zone.get_node_or_null(tag) as Node3D
		if station == null:
			continue
		var marker: Marker3D = station.get_node_or_null("Start") as Marker3D
		check.call(marker != null, "%s has a Start marker" % tag)
		check.call(_nearest_plate(station) != null, "%s has a drain plate" % tag)
		if marker != null:
			var capsule: EnergySource = _nearest_capsule(marker.global_position)
			check.call(capsule != null and capsule.respawn_time > 0.0 and capsule.global_position.distance_to(marker.global_position) <= CAPSULE_REACH, "%s has a respawning capsule within %.0f m of its start" % [tag, CAPSULE_REACH])
	for tag: String in SHOT_STATIONS:
		var station: Node3D = _zone.get_node_or_null(tag) as Node3D
		if station == null:
			continue
		var marker: Marker3D = station.get_node_or_null("Start") as Marker3D
		check.call(marker != null, "%s has a Start marker" % tag)
		if marker != null:
			var capsule: EnergySource = _nearest_capsule(marker.global_position)
			check.call(capsule != null and capsule.respawn_time > 0.0 and capsule.global_position.distance_to(marker.global_position) <= CAPSULE_REACH, "%s has a respawning capsule within %.0f m" % [tag, CAPSULE_REACH])


func _nearest_plate(station: Node3D) -> EnergyDrainPlate:
	var marker: Marker3D = station.get_node_or_null("Start") as Marker3D
	if marker == null:
		return null
	var best: EnergyDrainPlate = null
	var best_distance: float = CAPSULE_REACH
	for node: Node in _gym.find_children("*", "Area3D", true, false):
		var plate: EnergyDrainPlate = node as EnergyDrainPlate
		if plate != null and plate.global_position.distance_to(marker.global_position) <= best_distance:
			best = plate
			best_distance = plate.global_position.distance_to(marker.global_position)
	return best


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
	_rig.pitch = 0.0
	_rig.rotation.y = _rig.yaw


## Live walk: from inside the Loader room, only holding forward, through the doorway into Zone_Energy.
func _live_walk(tree: SceneTree, check: Callable) -> void:
	_player.call(&"respawn", Vector3(-109.0, 0.0, 0.0))
	Fixtures.set_energy(_player, 3)
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
	check.call(_player.arm_energy.value == 3, "plain walking leaves the arm at 3 steps (got %d)" % _player.arm_energy.value)


## Capsule: hold the Extractor at the capsule next to the entry, the arm fills; the capsule is full again after its respawn time.
func _live_capsule(tree: SceneTree, check: Callable) -> void:
	var station: Node3D = _zone.get_node("Energy_Capsule") as Node3D
	var stand: Marker3D = station.get_node("Start") as Marker3D
	var capsule: EnergySource = _nearest_capsule(stand.global_position)
	check.call(capsule != null, "the capsule station has an EnergySource")
	if capsule == null:
		return
	_player.call(&"respawn", stand.global_position)
	Fixtures.set_energy(_player, 3)
	await Fixtures.wait_physics(tree, 20)
	_face_west()
	await Fixtures.wait_physics(tree, 20)
	await Fixtures.tap_action(tree, &"module_2", 2)
	await Fixtures.wait_physics(tree, 2)
	await Fixtures.hold_action(tree, &"use_hand", 0.6)
	await Fixtures.wait_physics(tree, 3)
	check.call(_player.arm_energy.value == 6, "draining the capsule with the Extractor gives +3 steps (got %d)" % _player.arm_energy.value)
	check.call(not capsule.is_available(), "the drained capsule is empty")
	await Fixtures.wait_physics(tree, ceili(capsule.respawn_time * Engine.physics_ticks_per_second) + 10)
	check.call(capsule.is_available(), "the capsule refills after its respawn time %.1f s" % capsule.respawn_time)
	_release_inputs()


## Every shot station has a respawning capsule within reach: the Loader room's gap and super jump, and (above) the Zone_Energy shot
## stations. (The Phase 4 puzzle rooms were removed in plan 05.1-02, D-29; the old Auslöser stations of the mechanism rooms went with
## the rooms in plan 05.1-06, and target stations in the kit layer areas carry their own capsule, kit_area_shell.gd capsule_beside.)
func _check_capsules_near_shots(check: Callable) -> void:
	var loader: Node3D = _gym.get_node("Zone_Loader") as Node3D
	for tag: String in ["Loader_Gap", "Loader_SuperJump"]:
		var launch: Marker3D = loader.get_node("%s/Launch" % tag) as Marker3D
		var capsule: EnergySource = _nearest_capsule(launch.global_position)
		check.call(capsule != null and capsule.respawn_time > 0.0 and capsule.global_position.distance_to(launch.global_position) <= CAPSULE_REACH, "%s has a respawning capsule within %.0f m" % [tag, CAPSULE_REACH])


## D-20: no sign names the aiming mode or the old pulse sizes by hold time; no sign names the shot (D-45).
func _check_signs(check: Callable) -> void:
	var stale: PackedStringArray = PackedStringArray()
	var labels: int = 0
	for node: Node in _gym.find_children("*", "Label3D", true, false):
		var text: String = (node as Label3D).text
		labels += 1
		for word: String in STALE_WORDS:
			if text.contains(word):
				stale.append("%s: %s" % [node.name, text])
	check.call(stale.is_empty(), "no sign names aiming or the old pulse sizes (%s)" % [stale])
	var shot: Label3D = _zone.get_node("Shot_TapVsFull/Label_Shot_TapVsFull") as Label3D
	check.call(not shot.text.contains("Schuss") and not shot.text.contains("tippen"), "D-45: the former shot station sign names no shot (%s)" % shot.text)
	var expects: int = 0
	for node: Node in _gym.find_children("Label_*_Expect", "Label3D", true, false):
		if (node as Label3D).text.begins_with("Erwartet:"):
			expects += 1
	# 47 since plan 05.1-02 removed the pneumatic tube station (48 before); 46 since plan 05.1-03 cut the nozzle wall and jump
	# stations and added the steam-look wall-run pad; 45 after plan 05.1-04. 22 since plan 05.1-06 (21 after 05.1-08 removed Energy_Track) replaced the old mechanism rooms
	# (30 lines) by the kit layer areas (7 steampunk stations so far; later plans add a station per object): Zone_Energy 11,
	# Zone_Loader 4, Zone_KitSteampunk 7.
	check.call(expects >= 21, "the gym has at least 21 'Erwartet:' lines (got %d)" % expects)
	check.call(labels >= 40, "at least 40 labels (%d)" % labels)


## Stepping on a drain plate empties the arm (through the owner's request API).
func _live_drain(tree: SceneTree, check: Callable) -> void:
	var plate: Node3D = _zone.get_node("Energy_Drain/Plate") as Node3D
	_player.call(&"respawn", plate.global_position + Vector3(0.0, 0.0, 4.0))
	Fixtures.set_energy(_player, 8)
	await Fixtures.wait_physics(tree, 20)
	check.call(_player.arm_energy.value == 8, "the arm holds 8 before the plate")
	_player.call(&"respawn", plate.global_position)
	Fixtures.set_energy(_player, 8)
	await Fixtures.wait_physics(tree, 10)
	check.call(_player.arm_energy.value == 0, "stepping on the drain plate sets the arm to 0 (got %d)" % _player.arm_energy.value)


## At the air dash pit an empty arm is refused the air dash and falls into the pit; with energy the dash carries over the gap.
func _live_air_dash(tree: SceneTree, check: Callable, energy: int) -> void:
	var station: Node3D = _zone.get_node("Energy_AirDash") as Node3D
	var start: Vector3 = (station.get_node("Start") as Marker3D).global_position
	var edge_x: float = float(station.get_meta(&"platform_edge_x"))
	var far_x: float = float(station.get_meta(&"far_edge_x"))
	_player.call(&"respawn", start)
	Fixtures.set_energy(_player, energy)
	await Fixtures.wait_physics(tree, 20)
	_face_west()
	var saw_dash: bool = false
	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return _player.global_position.x <= edge_x - 0.3, 120)
	Input.action_press(&"jump")
	await Fixtures.wait_physics(tree, 2)
	Input.action_release(&"jump")
	await Fixtures.wait_physics(tree, 6)
	Input.action_press(&"dash")
	for i: int in 6:
		await tree.physics_frame
		saw_dash = saw_dash or _player.state_machine.current.name == &"Dash"
	Input.action_release(&"dash")
	var landed: int = await Fixtures.wait_until(tree, func() -> bool: return _player.is_on_floor() and _player.global_position.x < far_x + 4.0, 150)
	await Fixtures.wait_physics(tree, 20)
	Input.action_release(&"move_forward")
	if energy <= 0:
		check.call(not saw_dash, "with an empty arm the air dash press is refused (no Dash state)")
		check.call(_player.global_position.x > far_x or _player.global_position.y < -1.0 or landed < 0, "with an empty arm the pit is not crossed (x %.2f)" % _player.global_position.x)
	else:
		check.call(saw_dash, "with energy the air dash press starts the Dash state")
		check.call(landed >= 0 and _player.global_position.x < far_x, "with energy the air dash crosses the pit (x %.2f, far edge %.2f)" % [_player.global_position.x, far_x])
	_release_inputs()


func _release_inputs() -> void:
	for action: StringName in [&"move_forward", &"dash", &"jump", &"use_hand", &"module_1", &"module_2", &"loader"]:
		Input.action_release(action)
