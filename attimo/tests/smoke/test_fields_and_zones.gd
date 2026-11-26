extends RefCounted
## MECH-04 K (D-06): the gravity request API (the zone is a Force volume now). The repulsor was cut and the attractor became the attraction field, the Force volume RADIAL profile (plan 05.1-18, test_attraction_field); the wind tunnel became the steam stream force volume (plan 05.1-15, test_force_volume).

const Fixtures := preload("res://tests/fixtures.gd")

const SHIPPED_TPS: int = 60


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_gravity_requests(tree, check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


## The player-side gravity request contract (T-04.1-01): bad and out-of-range requests, cleared after the move. The gravity zone
## itself became the Force volume GRAVITY profile (plan 05.1-16, test_amplification).
func _scenario_gravity_requests(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 20)
	player.request_gravity_scale(NAN)
	player.request_gravity_scale(INF)
	check.call(player._zone_gravity_scale == 1.0, "a non-finite gravity request changes nothing")
	player.request_gravity_scale(0.0)
	check.call(is_equal_approx(player._zone_gravity_scale, 0.05), "a request below 0.05 is clamped to 0.05 (%.3f)" % player._zone_gravity_scale)
	await Fixtures.wait_physics(tree, 2)
	check.call(player._zone_gravity_scale == 1.0, "the request is cleared after the move, no restore step needed")
	player.request_gravity_scale(5.0)
	check.call(player._zone_gravity_scale == 1.0, "a request above 1.0 is clamped to 1.0")
	await _free(tree, [player, floor_body])
