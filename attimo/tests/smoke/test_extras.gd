extends RefCounted
## MECH-05 (D-11, D-06): the three steampunk extras. The piston punch wall (Kolbenwand) knocks a player in front of it away once
## per slam after a telegraph, (the pressure-valve geyser moved to the Force volume block, plan 05.1-15, test_force_volume)
## and the paternoster carries a rider up on level decks. Each is driven by an active Trigger stub and moves the player only
## through knock_back, launch_along or the engine's platform carry. Real player, real geometry, 60 Hz.

const Fixtures := preload("res://tests/fixtures.gd")

const PISTON_SCENE: String = "res://scenes/mechanisms/piston_wall.tscn"
const PATERNOSTER_SCENE: String = "res://scenes/mechanisms/paternoster.tscn"
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
	await _scenario_paternoster(tree, check)
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


func _scenario_paternoster(tree: SceneTree, check: Callable) -> void:
	var source: Trigger = Trigger.new()
	tree.root.add_child(source)
	var lift: Paternoster = (load(PATERNOSTER_SCENE) as PackedScene).instantiate() as Paternoster
	lift.source = source
	tree.root.add_child(lift)
	await Fixtures.wait_physics(tree, 2)
	var decks: Array[AnimatableBody3D] = lift.decks()
	check.call(decks.size() == lift.deck_count, "paternoster: %d decks are built (%d)" % [lift.deck_count, decks.size()])
	var lowest: float = INF
	var in_group: bool = false
	for deck: AnimatableBody3D in decks:
		lowest = minf(lowest, deck.global_position.y - lift.global_position.y)
		in_group = in_group or deck.is_in_group(&"moving_platform") or deck.is_in_group(&"carrying_platform")
		check.call(deck.collision_layer == PhysicsLayers.WORLD and deck.sync_to_physics, "paternoster: a deck is on the World layer and syncs to physics")
	check.call(lowest >= 0.05 - 0.0001, "paternoster: the lowest deck top is %.3f m above the origin (at least 0.05)" % lowest)
	check.call(not in_group and not lift.is_in_group(&"moving_platform"), "paternoster: no deck joins a platform group of the gym")
	# A rider on deck 0 (it starts at the bottom of the up run) rises with it and never separates.
	var deck: AnimatableBody3D = decks[0]
	var rider: PlayerController = Fixtures.spawn_player(tree.root, deck.global_position + Vector3(0.0, 0.1, 0.0))
	await Fixtures.wait_physics(tree, 20)
	var start_y: float = rider.global_position.y
	source.set_active(true)
	var worst_gap: float = 0.0
	for i: int in 3 * SHIPPED_TPS:
		await Fixtures.wait_physics(tree, 1)
		worst_gap = maxf(worst_gap, rider.global_position.y - deck.global_position.y)
	var rise: float = rider.global_position.y - start_y
	check.call(rise >= 3.0, "paternoster: the rider rises %.2f m (at least 3)" % rise)
	check.call(worst_gap <= 0.15 and rider.is_grounded(), "paternoster: the rider stays on the deck (largest gap %.3f m, grounded %s)" % [worst_gap, rider.is_grounded()])
	lift.reset()
	await Fixtures.wait_physics(tree, 2)
	check.call(absf(deck.global_position.y - lift.global_position.y - 0.05) < 0.01, "paternoster: reset() restores the deck positions")
	await _free(tree, [rider, lift, source])
