extends RefCounted
## MECH-03 / D-18 / D-22: the Timed motion deck (clock hand) sits on WORLD and never joins the gym group moving_platform. The old
## rotating platform's lever reversal went with the always-on Timed motion block (plan 05.1-04, D-07); its carry is
## test_mechanism_carry, its floor clearance and take-off test_timed_motion. The Hub-Plattform (lift) and its travel and rider
## scenarios were cut in plan 05.1-06 (D-09, KIT-04).

const HAND_SCENE: String = "res://scenes/kit/steampunk/clock_hand_platform.tscn"
const SHIPPED_TPS: int = 60


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_layers(tree, check)


func _spawn(path: String, check: Callable) -> Node3D:
	if not ResourceLoader.exists(path):
		check.call(false, "scene %s exists" % path)
		return null
	return (load(path) as PackedScene).instantiate() as Node3D


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _scenario_layers(tree: SceneTree, check: Callable) -> void:
	var rotating: TimedMotion = _spawn(HAND_SCENE, check) as TimedMotion
	if rotating == null:
		return
	rotating.position = Vector3(0.0, -50.0, 0.0)
	tree.root.add_child(rotating)
	var body: AnimatableBody3D = rotating.body()
	check.call(body.collision_layer == PhysicsLayers.WORLD and not body.is_in_group(&"moving_platform"), "the Timed motion deck body is on WORLD and not in group moving_platform")
	await _free(tree, [rotating])
