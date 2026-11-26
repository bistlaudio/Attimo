extends RefCounted
## Plan 05-03 (ENRG-05, D-13): the energy HUD is a CanvasLayer 9 (below the crosshair 10 and the debug overlays), its Control ignores
## the mouse. Plan 05.1-09 (D-35, D-39): the clock face rests the hour hand on whole steps, shows the second hand below 12, and an
## energy_refused shakes and flashes it red for a short time. It only reads.

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
	await _scenario_clock(tree, check, hud, player)
	await _scenario_readouts(tree, check, hud, player)
	hud.queue_free()
	player.queue_free()
	floor_body.queue_free()
	await player.tree_exited


# The complete HUD (D-13): the Moto badge, the active module name, the momentum gauge with the three marks and the charge indicator.
func _scenario_readouts(tree: SceneTree, check: Callable, hud: EnergyHud, player: PlayerController) -> void:
	var config: MovementConfig = player.config
	Fixtures.set_energy(player, 0)
	await tree.process_frame
	await tree.process_frame
	check.call(not hud.is_moto_shown, "(r1) no Moto badge at 0")
	Fixtures.set_energy(player, 8)
	await tree.process_frame
	await tree.process_frame
	check.call(hud.is_moto_shown == player.arm_energy.is_moto() and hud.is_moto_shown, "(r1) the Moto badge lights in Moto")
	Fixtures.set_energy(player, 3)
	await tree.process_frame
	var hand: HandController = player.get_node("HandController") as HandController
	await tree.process_frame
	check.call(hand.active_def != null and hud.module_name == hand.active_def.display_name, "(r2) the module plate shows the active module (%s)" % hud.module_name)
	player.set_physics_process(false)
	player.move_velocity = Vector3(7.5, 0.0, 0.0)
	await tree.process_frame
	await tree.process_frame
	check.call(absf(hud.speed_gauge_value - player.horizontal_speed()) < 0.01, "(r3) the gauge needle is the horizontal speed (%.2f vs %.2f)" % [hud.speed_gauge_value, player.horizontal_speed()])
	var marks: Array[float] = hud.gauge_marks
	var expected: Array[float] = [config.run_speed, config.dash_exit_speed, config.loader_max_speed]
	var ok: bool = marks.size() == expected.size()
	for value: float in expected:
		var found: bool = false
		for mark: float in marks:
			found = found or is_equal_approx(mark, value)
		ok = ok and found
	check.call(ok, "(r4) the gauge marks are run, dash exit and loader max (got %s)" % [marks])
	check.call(not hud.charging_shown, "(r5) no charge indicator without charging")
	player.arm_energy.charging = true
	await tree.process_frame
	await tree.process_frame
	check.call(hud.charging_shown, "(r5) the charge indicator follows arm_energy.charging")
	player.arm_energy.charging = false
	player.set_physics_process(true)
	check.call(hud.health_slot_rect().position.x > hud.clock_rect().end.x, "(r6) a slot for health is left to the right of the clock")


## Real seconds: the HUD animates on TimeFx.unscaled, so the test waits on a real timer.
func _real_wait(tree: SceneTree, seconds: float) -> void:
	await tree.create_timer(seconds, true, false, true).timeout
	await tree.process_frame


# The clock face (D-35) and the refusal cue (D-39).
func _scenario_clock(tree: SceneTree, check: Callable, hud: EnergyHud, player: PlayerController) -> void:
	check.call(not hud.has_method(&"chambers_rect"), "(c0) the chambers are gone")
	var angles_ok: bool = true
	for steps: int in 13:
		angles_ok = angles_ok and is_equal_approx(hud.hand_angle_for(steps), -PI * 0.5 + TAU * float(steps) / 12.0)
	check.call(angles_ok, "(c1) hand_angle_for(steps) is -PI/2 + TAU * steps / 12 for 0..12")
	for energy: int in [0, 4, 12]:
		Fixtures.set_energy(player, energy)
		await _real_wait(tree, 0.3)
		check.call(is_equal_approx(hud.displayed_angle(), hud.hand_angle_for(energy)) and hud.hand_at_rest(), "(c2) the hand rests on step %d within 0.3 s (angle %.3f)" % [energy, hud.displayed_angle()])
	check.call(not hud.second_hand_visible(), "(c3) the second hand is hidden at 12")
	Fixtures.set_energy(player, 5)
	await _real_wait(tree, 0.3)
	check.call(hud.second_hand_visible(), "(c3) the second hand shows below 12")
	check.call(absf(hud.second_hand_angle() - (-PI * 0.5 + TAU * player.arm_energy.tick_progress())) < TAU * 0.02, "(c3) the second hand follows tick_progress (within a frame of progress)")
	Fixtures.set_energy(player, 8)
	await _real_wait(tree, 0.3)
	Fixtures.set_energy(player, 5)
	await tree.process_frame
	await tree.process_frame
	check.call(not hud.hand_at_rest() or is_equal_approx(hud.displayed_angle(), hud.hand_angle_for(5)), "(c4) a spend animates the hand")
	await _real_wait(tree, 0.3)
	check.call(is_equal_approx(hud.displayed_angle(), hud.hand_angle_for(5)), "(c4) the hand settles on the new whole step (%.3f)" % hud.displayed_angle())
	check.call(hud.refusal_time_left() == 0.0 and hud.shake_offset() == Vector2.ZERO, "(c5) no cue at rest")
	EventBus.energy_refused.emit(&"dash", 1)
	var shaken: bool = false
	for i: int in 6:
		await tree.process_frame
		shaken = shaken or hud.shake_offset() != Vector2.ZERO
	check.call(hud.refusal_time_left() > 0.0, "(c5) a refusal starts the cue (left %.2f)" % hud.refusal_time_left())
	check.call(shaken, "(c5) the clock shakes (a non-zero offset)")
	check.call(hud.current_fill_color().r > hud.fill_color.r, "(c5) the fill colour is lerped toward red")
	await _real_wait(tree, 0.5)
	check.call(hud.refusal_time_left() == 0.0 and hud.shake_offset() == Vector2.ZERO and hud.current_fill_color().is_equal_approx(hud.fill_color), "(c5) the cue is back at rest within 0.5 s")
