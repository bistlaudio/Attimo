extends RefCounted
## Mechanism rooms after plan 05.1-02 (D-29): the Phase 4 puzzle rooms were removed with their builder script (all three
## depended on cut triggers and on the nozzle cannon); their AND / OR / timer ideas return as target-based stations in plan 05.1-14.
## The test proves the rooms are gone, room 2's east wall is closed (no doorway cell left), the SteamCannon station is a Catch &
## launch block with the FIXED profile whose node carries no pitch (the barrel pitch lives in the config, fault A of RESEARCH), and
## the signs are written for hip fire.

const Fixtures := preload("res://tests/fixtures.gd")

const GYM_SCENE: String = "res://scenes/test/movement_gym.tscn"
## Room 2 spans z -32..32 in 4 m wall cells: 16 east wall segments with no gap.
const EAST_WALL_CELLS: int = 16


func run(tree: SceneTree, check: Callable) -> void:
	var packed: PackedScene = load(GYM_SCENE) as PackedScene
	check.call(packed != null, "the movement gym loads")
	if packed == null:
		return
	var gym: Node = packed.instantiate()
	tree.root.add_child(gym)
	await Fixtures.wait_physics(tree, 30)
	_check_hip_fire_signs(gym, check)
	_check_puzzle_rooms_removed(gym, check)
	_check_steam_cannon(gym, check)
	gym.queue_free()
	await gym.tree_exited


## D-20: the signs are written for hip fire. The Fernausloeser sign says LMB tap only, and no sign names the removed aim hold.
func _check_hip_fire_signs(gym: Node, check: Callable) -> void:
	var tracer: Label3D = gym.find_child("Label_Tracer", true, false) as Label3D
	check.call(tracer != null and tracer.text == "Fernauslöser: LMB tippen", "the Fernausloeser sign reads 'Fernauslöser: LMB tippen' (got %s)" % [tracer.text if tracer != null else "none"])
	var stale: Array[String] = []
	for node: Node in gym.find_children("*", "Label3D", true, false):
		var text: String = (node as Label3D).text
		if text.contains("RMB halten") or text.to_lower().contains("aim halten"):
			stale.append(text)
	check.call(stale.is_empty(), "no gym sign names the removed aim hold (%s)" % [stale])


## D-29: no puzzle room node is left and the east wall of room 2 is a plain wall (every cell present).
func _check_puzzle_rooms_removed(gym: Node, check: Callable) -> void:
	check.call(gym.get_node_or_null("Zone_MechanismRooms/Zone_PuzzleRooms") == null, "Zone_PuzzleRooms is gone")
	check.call(gym.find_children("PuzzleRoom_*", "", true, false).is_empty(), "no PuzzleRoom_* node is left")
	var zone: Node = gym.get_node_or_null("Zone_MechanismRooms")
	check.call(zone != null, "Zone_MechanismRooms exists")
	if zone == null:
		return
	var cells: int = 0
	for index: int in EAST_WALL_CELLS:
		if zone.get_node_or_null("Room2WallEast_%d" % index) != null:
			cells += 1
	check.call(cells == EAST_WALL_CELLS, "room 2's east wall is closed (%d of %d cells)" % [cells, EAST_WALL_CELLS])


## The SteamCannon station: a CatchLaunch with a FIXED config, yaw only (no pitch on the node, so the trigger stays upright).
func _check_steam_cannon(gym: Node, check: Callable) -> void:
	var cannon: Node3D = gym.get_node_or_null("Zone_MechanismRooms/SteamCannon") as Node3D
	check.call(cannon is CatchLaunch, "the SteamCannon station is a CatchLaunch block")
	if not cannon is CatchLaunch:
		return
	var block: CatchLaunch = cannon as CatchLaunch
	check.call(block.config != null and block.config.profile == CatchLaunchConfig.Profile.FIXED, "the SteamCannon uses the FIXED profile")
	var up: Vector3 = block.global_basis.y.normalized()
	check.call(up.dot(Vector3.UP) > 0.999, "the SteamCannon node is not pitched (up %s)" % up)
	var direction: Vector3 = block.barrel_direction()
	check.call(direction.y > 0.6 and direction.x > 0.6, "the SteamCannon barrel points up and east, along +X (%s)" % direction)
