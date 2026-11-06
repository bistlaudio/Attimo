extends RefCounted
## Debug hit puffs: the HitPuffs listener spawns a puff on chain_stage_changed 2 and 3, none on 1 and 0, and one per
## long_jumped stage 1, 2, 3. It reacts to EventBus facts only; the facts are emitted by hand here.

const Fixtures := preload("res://tests/fixtures.gd")
const LISTENER_SCENE: String = "res://scenes/debug/hit_puffs.tscn"


func run(tree: SceneTree, check: Callable) -> void:
	var bus: Node = tree.root.get_node("EventBus")
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(3.0, 0.0, 0.0))
	var listener: HitPuffs = (load(LISTENER_SCENE) as PackedScene).instantiate() as HitPuffs
	tree.root.add_child(listener)
	await Fixtures.wait_physics(tree, 3)

	bus.emit_signal(&"chain_stage_changed", 1)
	bus.emit_signal(&"chain_stage_changed", 0)
	check.call(listener.puffs_spawned == 0 and listener.get_child_count() == 0, "(1) chain stage 1 and the reset 0 spawn no puff (spawned %d)" % listener.puffs_spawned)

	bus.emit_signal(&"chain_stage_changed", 2)
	check.call(listener.puffs_spawned == 1 and listener.last_kind == "chain" and listener.last_stage == 2, "(2) chain stage 2 spawns one puff (spawned %d)" % listener.puffs_spawned)
	check.call(listener.get_child_count() == 1, "(2) and the puff is a child of the listener (%d)" % listener.get_child_count())
	var small: CPUParticles3D = listener.get_child(0) as CPUParticles3D
	check.call(small != null and small.emitting and small.one_shot, "(2) it is a one-shot CPUParticles3D that emits")
	check.call(small != null and small.global_position.distance_to(player.global_position) < 0.01, "(2) at the player's feet")

	bus.emit_signal(&"chain_stage_changed", 3)
	check.call(listener.puffs_spawned == 2 and listener.last_stage == 3, "(3) chain stage 3 spawns a second puff (spawned %d)" % listener.puffs_spawned)
	var big: CPUParticles3D = listener.get_child(1) as CPUParticles3D
	check.call(big != null and small != null and big.scale.x > small.scale.x, "(3) the salto puff is bigger than the Jump 2 puff")

	var before: int = listener.puffs_spawned
	var sizes: Array[float] = []
	var colors: Array[Color] = []
	for stage: int in [1, 2, 3]:
		bus.emit_signal(&"long_jumped", Vector3(0.0, 0.0, -stage), stage)
		check.call(listener.puffs_spawned == before + stage and listener.last_kind == "long" and listener.last_stage == stage, "(4) long_jumped stage %d spawns exactly one puff (spawned %d)" % [stage, listener.puffs_spawned])
		var puff: CPUParticles3D = listener.get_child(listener.get_child_count() - 1) as CPUParticles3D
		sizes.append(puff.scale.x)
		colors.append(puff.color)
	check.call(sizes[0] < sizes[1] and sizes[1] < sizes[2], "(4) the long jump puffs grow with the stage (%s)" % [sizes])
	check.call(colors[0] != colors[1] and colors[1] != colors[2] and colors[0] != colors[2], "(4) and differ in colour per stage")

	var after: int = listener.puffs_spawned
	bus.emit_signal(&"long_jumped", Vector3.ZERO, 0)
	bus.emit_signal(&"chain_stage_changed", 4)
	check.call(listener.puffs_spawned == after, "(5) unknown stages spawn nothing")

	listener.queue_free()
	player.queue_free()
	floor_body.queue_free()
	await tree.process_frame
