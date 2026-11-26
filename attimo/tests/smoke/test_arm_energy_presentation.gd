extends RefCounted
## Plan 05-03 (D-09, D-10, D-12): the arm cores and the Moto glow. Four greybox core prisms on the forearm show the fill (full bright,
## partial dimmed by fill, empty dark); a spent core flashes briefly; a refused action flickers the arm grey at most 3 flashes per
## second; Moto Perpetuo lights both feet and the back with an entry flash and a fade on exit. The glow is energy turquoise (the colour of
## HandPresentation), emission only: no particle node, nothing on a CanvasLayer.

const Fixtures := preload("res://tests/fixtures.gd")
const ENERGY_COLOR: Color = Color(0.25, 0.9, 0.85, 1.0)
const MAX_FLASH_TIME: float = 0.2
const MAX_FLASHES_PER_SECOND: int = 3


func run(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 6)
	await tree.process_frame
	var presentation: ArmEnergyPresentation = player.get_node_or_null(^"ArmEnergyPresentation") as ArmEnergyPresentation
	check.call(presentation != null, "the Player has an ArmEnergyPresentation node")
	if presentation == null:
		return
	await _scenario_cores(tree, check, player, presentation)
	await _scenario_flash(tree, check, player, presentation)
	await _scenario_flicker(tree, check, player, presentation)
	await _scenario_moto(tree, check, player, presentation)
	_scenario_hygiene(check, presentation)
	player.queue_free()
	floor_body.queue_free()
	await player.tree_exited


func _scenario_cores(tree: SceneTree, check: Callable, player: PlayerController, presentation: ArmEnergyPresentation) -> void:
	var attachment: Node = presentation.core_parent()
	check.call(attachment is BoneAttachment3D, "(c1) the cores hang under a BoneAttachment3D (got %s)" % attachment)
	check.call(presentation.core_nodes.size() == 4, "(c1) there are 4 core prisms (got %d)" % presentation.core_nodes.size())
	for core: MeshInstance3D in presentation.core_nodes:
		check.call(core.get_parent() == attachment, "(c1) core %s sits under the forearm attachment" % core.name)
	Fixtures.set_energy(player, 7)
	await tree.process_frame
	await tree.process_frame
	var e0: float = presentation.core_emission(0)
	var e1: float = presentation.core_emission(1)
	var e2: float = presentation.core_emission(2)
	var e3: float = presentation.core_emission(3)
	check.call(is_equal_approx(e0, e1) and e1 > e2 and e2 > e3, "(c2) at 7 steps the cores read full, full, a third, dark (%.2f %.2f %.2f %.2f)" % [e0, e1, e2, e3])
	var third: float = e3 + (e0 - e3) / 3.0
	check.call(absf(e2 - third) <= 0.1 * absf(e0 - e3) + 0.001, "(c2) the third-full core sits a third between dark and full (%.3f vs %.3f)" % [e2, third])
	check.call(presentation.core_color().is_equal_approx(ENERGY_COLOR) and presentation.ENERGY_COLOR.is_equal_approx(ENERGY_COLOR), "(c3) the cores glow in the energy turquoise like HandPresentation")


func _scenario_flash(tree: SceneTree, check: Callable, player: PlayerController, presentation: ArmEnergyPresentation) -> void:
	Fixtures.set_energy(player, 7)
	await tree.create_timer(0.35).timeout
	player.arm_energy.try_spend(3, &"test")
	await tree.process_frame
	await tree.process_frame
	var flashing: float = presentation.core_flash_left(1)
	check.call(flashing > 0.0 and flashing <= MAX_FLASH_TIME, "(f1) the spent core reports a flash of at most %.2f s (got %.3f)" % [MAX_FLASH_TIME, flashing])
	await tree.create_timer(0.35).timeout
	check.call(presentation.core_flash_left(1) == 0.0, "(f2) the flash is over after 0.35 s")


func _scenario_flicker(tree: SceneTree, check: Callable, player: PlayerController, presentation: ArmEnergyPresentation) -> void:
	Fixtures.set_energy(player, 0)
	await tree.create_timer(0.3).timeout
	for i: int in 10:
		player.arm_energy.refuse(&"air_dash", 1)
	await tree.process_frame
	check.call(presentation.flicker_active(), "(g1) a refusal starts the grey flicker")
	var onsets: int = 0
	var was_grey: bool = false
	var elapsed: float = 0.0
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms < 1000:
		await tree.process_frame
		var grey: bool = presentation.flicker_grey()
		if grey and not was_grey:
			onsets += 1
		was_grey = grey
	elapsed = float(Time.get_ticks_msec() - start_ms) / 1000.0
	check.call(onsets <= MAX_FLASHES_PER_SECOND, "(g2) at most %d grey flashes in %.2f s even after 10 refusals (got %d)" % [MAX_FLASHES_PER_SECOND, elapsed, onsets])
	check.call(not presentation.flicker_active(), "(g3) the flicker ends by itself after its duration")


func _scenario_moto(tree: SceneTree, check: Callable, player: PlayerController, presentation: ArmEnergyPresentation) -> void:
	Fixtures.set_energy(player, 0)
	await tree.create_timer(0.5).timeout
	check.call(not presentation.moto_visible(), "(m0) the Moto glow is hidden without Moto")
	check.call(presentation.moto_points.size() <= 3, "(m1) at most three glow points (feet and back)")
	Fixtures.set_energy(player, 8)
	await tree.process_frame
	await tree.process_frame
	check.call(presentation.moto_visible(), "(m2) Moto on makes the glow points visible")
	check.call(presentation.moto_entry_flash_left() > 0.0 and presentation.moto_entry_flash_left() <= MAX_FLASH_TIME, "(m2) with an entry flash of at most %.2f s (got %.3f)" % [MAX_FLASH_TIME, presentation.moto_entry_flash_left()])
	for point: MeshInstance3D in presentation.moto_points:
		var material: StandardMaterial3D = point.material_override as StandardMaterial3D
		check.call(material != null and material.emission.is_equal_approx(ENERGY_COLOR), "(m3) glow point %s is energy turquoise" % point.name)
	var arm_boost: float = presentation.arm_boost()
	check.call(arm_boost > 1.0, "(m4) the arm is brighter in Moto (x%.2f)" % arm_boost)
	Fixtures.set_energy(player, 0)
	await tree.create_timer(0.5).timeout
	check.call(not presentation.moto_visible(), "(m5) the glow points are invisible within 0.5 s of leaving Moto")
	check.call(is_equal_approx(presentation.arm_boost(), 1.0), "(m5) the arm is back to normal")


func _scenario_hygiene(check: Callable, presentation: ArmEnergyPresentation) -> void:
	var particles: int = 0
	var layers: int = 0
	var stack: Array[Node] = [presentation]
	var attachments: Array[Node] = [presentation.core_parent()]
	attachments.append_array(presentation.moto_parents())
	stack.append_array(attachments)
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if (node is GPUParticles3D or node is CPUParticles3D) and not node.has_meta(&"energy_fx"):
			particles += 1
		if node is CanvasLayer or node is CanvasItem:
			layers += 1
		stack.append_array(node.get_children())
	check.call(particles == 0, "(h1) the presentation has no particle node of its own (the tagged EnergyFx sparks are separate)")
	check.call(layers == 0, "(h2) nothing of the presentation is a CanvasLayer or a screen effect")
