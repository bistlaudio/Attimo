extends RefCounted
## Plan 05-03 (ENRG-05, D-13): the energy HUD is a CanvasLayer 9 (below the crosshair 10 and the debug overlays), its Control ignores
## the mouse, and its chambers mirror ArmEnergy.core_fill after one frame. It only reads.

const Fixtures := preload("res://tests/fixtures.gd")
const HUD_SCENE: String = "res://scenes/ui/energy_hud.tscn"


func run(tree: SceneTree, check: Callable) -> void:
	var packed: PackedScene = load(HUD_SCENE) as PackedScene
	check.call(packed != null, "energy_hud.tscn loads")
	if packed == null:
		return
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	var hud: EnergyHud = packed.instantiate() as EnergyHud
	check.call(hud != null, "the scene root is an EnergyHud")
	if hud == null:
		return
	tree.root.add_child(hud)
	await Fixtures.wait_physics(tree, 4)
	await tree.process_frame
	check.call(hud.layer == 9, "the HUD is on layer 9 (got %d)" % hud.layer)
	var panel: Control = hud.get_node("Panel") as Control
	check.call(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the HUD Control ignores the mouse")
	for energy: float in [0.0, 37.5, 100.0]:
		Fixtures.set_energy(player, energy)
		await tree.process_frame
		await tree.process_frame
		var ok: bool = true
		for i: int in 4:
			ok = ok and is_equal_approx(hud.chamber_fill(i), player.arm_energy.core_fill(i))
		check.call(ok, "(c1) the chambers equal core_fill at %.1f (got %.2f %.2f %.2f %.2f)" % [energy, hud.chamber_fill(0), hud.chamber_fill(1), hud.chamber_fill(2), hud.chamber_fill(3)])
	hud.queue_free()
	player.queue_free()
	floor_body.queue_free()
	await player.tree_exited
