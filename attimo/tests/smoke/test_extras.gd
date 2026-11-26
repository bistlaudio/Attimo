extends RefCounted
## MECH-05 (D-11, D-06): the three steampunk extras. The piston punch wall (Kolbenwand) knocks a player in front of it away once
## per slam after a telegraph, (the pressure-valve geyser moved to the Force volume block, plan 05.1-15, test_force_volume)
## (the paternoster is a Timed motion PATH profile since plan 05.1-19, test_timed_motion). Each is driven by an active Trigger stub and moves the player only
## through knock_back, launch_along or the engine's platform carry. Real player, real geometry, 60 Hz.

const Fixtures := preload("res://tests/fixtures.gd")

const PISTON_SCENE: String = "res://scenes/mechanisms/piston_wall.tscn"
const SHIPPED_TPS: int = 60

var _knocks: int = 0
var _knock_along: Array[float] = []
var _knock_probe: PlayerController = null
var _knock_dir: Vector3 = Vector3.ZERO
var _launches: int = 0


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	EventBus.knocked_back.connect(_on_knocked)
	EventBus.launched.connect(_on_launched)
	await _scenario_piston(tree, check)
	EventBus.knocked_back.disconnect(_on_knocked)
	EventBus.launched.disconnect(_on_launched)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _on_knocked(_position: Vector3, _impulse: Vector3) -> void:
	_knocks += 1
	if _knock_probe != null:
		_knock_along.append(Vector3(_knock_probe.move_velocity.x, 0.0, _knock_probe.move_velocity.z).dot(_knock_dir))


func _on_launched(_position: Vector3, _direction: Vector3, _speed: float) -> void:
	_launches += 1


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _on_source() -> Trigger:
	var source: Trigger = Trigger.new()
	source.start_active = true
	return source


func _scenario_piston(tree: SceneTree, check: Callable) -> void:
	var source: Trigger = _on_source()
	tree.root.add_child(source)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var piston: PistonWall = (load(PISTON_SCENE) as PackedScene).instantiate() as PistonWall
	piston.source = source
	piston.interval = 0.5
	piston.telegraph_time = 0.3
	piston.retract_time = 0.5
	tree.root.add_child(piston)
	var hit: Area3D = piston.get_node("Head/Hit") as Area3D
	check.call(hit.collision_layer == PhysicsLayers.HAZARD and hit.collision_mask == PhysicsLayers.PLAYER, "piston: the hit area is on the Hazard layer and masks the Player")
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, -2.0))
	await Fixtures.wait_physics(tree, 5)
	_knocks = 0
	_knock_along.clear()
	_knock_probe = player
	_knock_dir = Vector3(0.0, 0.0, -1.0)
	var seen: Array[int] = []
	var slam_after_telegraph: bool = true
	var slams: int = 0
	for i: int in 6 * SHIPPED_TPS:
		await Fixtures.wait_physics(tree, 1)
		if seen.is_empty() or seen[seen.size() - 1] != int(piston.phase):
			seen.append(int(piston.phase))
			if piston.phase == PistonWall.Phase.SLAM:
				slams += 1
				if seen.size() < 2 or seen[seen.size() - 2] != int(PistonWall.Phase.TELEGRAPH):
					slam_after_telegraph = false
		if slams >= 1 and piston.phase == PistonWall.Phase.IDLE:
			break
	_knock_probe = null
	check.call(slams >= 1 and slam_after_telegraph, "piston: every slam is preceded by the telegraph phase (%d slams)" % slams)
	check.call(_knocks == 1, "piston: exactly one knock for the slam (%d)" % _knocks)
	check.call(_knock_along.size() > 0 and _knock_along[0] > 6.0, "piston: the speed along the push direction right after the knock is %.2f m/s (above 6)" % (_knock_along[0] if _knock_along.size() > 0 else 0.0))
	# Source off: the cycle stops and the head is retracted.
	source.set_active(false)
	await Fixtures.wait_physics(tree, SHIPPED_TPS)
	var slams_off: int = 0
	for i: int in 3 * SHIPPED_TPS:
		await Fixtures.wait_physics(tree, 1)
		if piston.phase == PistonWall.Phase.SLAM:
			slams_off += 1
	check.call(slams_off == 0 and piston.phase == PistonWall.Phase.IDLE, "piston: with the source off the cycle stops (%d slam ticks, phase %d)" % [slams_off, piston.phase])
	piston.reset()
	check.call(piston.phase == PistonWall.Phase.IDLE, "piston: reset() returns to IDLE")
	await _free(tree, [piston, player, floor_body, source])
