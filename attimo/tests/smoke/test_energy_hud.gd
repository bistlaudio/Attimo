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
	await _scenario_readouts(tree, check, hud, player)
	hud.queue_free()
	player.queue_free()
	floor_body.queue_free()
	await player.tree_exited


# The complete HUD (D-13): the Moto badge, the active module name, the momentum gauge with the five marks and the charge indicator.
func _scenario_readouts(tree: SceneTree, check: Callable, hud: EnergyHud, player: PlayerController) -> void:
	var config: MovementConfig = player.config
	Fixtures.set_energy(player, 0.0)
	await tree.process_frame
	await tree.process_frame
	check.call(not hud.is_moto_shown, "(r1) no Moto badge at 0")
	Fixtures.set_energy(player, 60.0)
	await tree.process_frame
	await tree.process_frame
	check.call(hud.is_moto_shown == player.arm_energy.is_moto() and hud.is_moto_shown, "(r1) the Moto badge lights in Moto")
	Fixtures.set_energy(player, 25.0)
	await tree.process_frame
	var hand: HandController = player.get_node("HandController") as HandController
	await tree.process_frame
	check.call(hand.active_def != null and hud.module_name == hand.active_def.display_name, "(r2) the module plate shows the active module (%s)" % hud.module_name)
	player.move_velocity = Vector3(7.5, 0.0, 0.0)
	await tree.process_frame
	await tree.process_frame
	check.call(absf(hud.speed_gauge_value - player.horizontal_speed()) < 0.01, "(r3) the gauge needle is the horizontal speed (%.2f vs %.2f)" % [hud.speed_gauge_value, player.horizontal_speed()])
	var marks: Array[float] = hud.gauge_marks
	var expected: Array[float] = [config.run_speed, config.energy_passive_start_speed, config.dash_exit_speed, config.energy_passive_full_speed, config.loader_max_speed]
	var ok: bool = marks.size() == expected.size()
	for value: float in expected:
		var found: bool = false
		for mark: float in marks:
			found = found or is_equal_approx(mark, value)
		ok = ok and found
	check.call(ok, "(r4) the gauge marks are run, passive start, dash exit, passive full and loader max (got %s)" % [marks])
	check.call(not hud.charging_shown, "(r5) no charge indicator without charging")
	player.arm_energy.charging = true
	await tree.process_frame
	await tree.process_frame
	check.call(hud.charging_shown, "(r5) the charge indicator follows arm_energy.charging")
	player.arm_energy.charging = false
	check.call(hud.health_slot_rect().position.x > hud.chambers_rect().end.x, "(r6) a slot for health is left to the right of the chambers")
