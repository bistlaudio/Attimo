extends RefCounted
## Energy and movement feedback (user request 2026-11-25): EnergyFx hangs three turquoise emitters on the forearm only (spend burst,
## charge inflow) and drives them from ArmEnergy.value; MovementPuffs throws one cream puff per jump and dash-hop stage,
## never turquoise. Every emitter carries the meta energy_fx.

const Fixtures := preload("res://tests/fixtures.gd")


func run(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 6)
	await tree.process_frame
	var fx: EnergyFx = player.get_node_or_null(^"EnergyFx") as EnergyFx
	var presentation: ArmEnergyPresentation = player.get_node_or_null(^"ArmEnergyPresentation") as ArmEnergyPresentation
	check.call(fx != null and presentation != null, "the Player has EnergyFx and ArmEnergyPresentation")
	if fx == null or presentation == null:
		return
	var emitters: Array[CPUParticles3D] = [fx.burst_particles, fx.charge_particles]
	for emitter: CPUParticles3D in emitters:
		check.call(emitter != null and emitter.get_parent() == presentation.core_parent(), "(e1) every energy emitter hangs on the forearm")
		if emitter != null:
			check.call(emitter.has_meta(EnergyFx.FX_META), "(e1) %s carries the energy_fx meta" % emitter.name)
	# Discrete spend: a big drop bursts.
	Fixtures.set_energy(player, 9)
	await tree.process_frame
	await tree.process_frame
	Fixtures.set_energy(player, 6)
	await tree.process_frame
	await tree.process_frame
	check.call(fx.burst_particles.emitting, "(e2) a spend of 3 steps bursts the spend sparks")
	# Income: a gained step runs the inflow.
	player.arm_energy.gain(1, &"charge")
	await tree.process_frame
	await tree.process_frame
	check.call(fx.charge_fx_active() and fx.charge_particles.emitting, "(e4) a gained step runs the charge inflow")
	# Movement puff: cream, never turquoise, tagged.
	var puffs: MovementPuffs = player.get_node_or_null(^"MovementPuffs") as MovementPuffs
	check.call(puffs != null, "(p1) the Player has MovementPuffs")
	if puffs != null:
		EventBus.jumped.emit(player.global_position)
		EventBus.long_jumped.emit(player.global_position, 3)
		await tree.process_frame
		var found: int = 0
		for child: Node in puffs.get_children():
			var emitter: CPUParticles3D = child as CPUParticles3D
			if emitter == null:
				continue
			found += 1
			var color: Color = ((emitter.mesh as BoxMesh).material as StandardMaterial3D).albedo_color
			check.call(color.is_equal_approx(MovementPuffs.PUFF_COLOR), "(p2) every puff has the one cream colour")
			check.call(not color.is_equal_approx(ArmEnergyPresentation.ENERGY_COLOR), "(p2) a puff is never turquoise")
			check.call(emitter.has_meta(&"energy_fx"), "(p2) a puff carries the fx meta")
		check.call(found == 2, "(p3) one jump and one dash-hop stage give two puffs (got %d)" % found)
	player.queue_free()
	floor_body.queue_free()
	await player.tree_exited
