extends RefCounted
## Plan 05-03 (ENRG-02, D-05, D-06): the passive charge uses horizontal speed only (0 below 10 m/s, 3/s at 10, 4.5/s at 14, 6/s from
## 18), pauses in the Loader state and never charges at plain run speed. A live dash-hop run fills the arm.

const Fixtures := preload("res://tests/fixtures.gd")
const SHIPPED_TPS: int = 60
const TOLERANCE: float = 0.05

var _floor: StaticBody3D


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	_floor = Fixtures.spawn_floor(tree.root, Vector3(80.0, 1.0, 200.0))
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 80.0))
	await Fixtures.wait_physics(tree, 6)
	_scenario_curve(check, player)
	_scenario_paused_states(check, player)
	_scenario_run_speed(check, player)
	await _scenario_vertical_ignored(tree, check)
	await _scenario_hop_run(tree, check, player)
	await _scenario_charge_button(tree, check, player)
	player.queue_free()
	_floor.queue_free()
	await player.tree_exited


func _scenario_curve(check: Callable, player: PlayerController) -> void:
	var arm: ArmEnergy = player.arm_energy
	var expected: Dictionary = {9.99: 0.0, 10.0: 3.0, 14.0: 4.5, 18.0: 6.0, 30.0: 6.0}
	for speed: float in expected:
		arm.reset_to(0.0)
		for i: int in SHIPPED_TPS:
			arm.tick(1.0 / SHIPPED_TPS, speed, &"Run", false)
		check.call(absf(arm.value - float(expected[speed])) < TOLERANCE, "(p1) one second at %.2f m/s gains %.2f (got %.3f)" % [speed, float(expected[speed]), arm.value])
	var config: MovementConfig = player.config
	check.call(arm.passive_rate(config.run_speed, config) == 0.0, "(p2) plain running at run_speed %.1f gives no passive charge" % config.run_speed)
	# T-05-10: a full speed tuned onto the start speed must not divide by zero.
	var squeezed: MovementConfig = config.duplicate() as MovementConfig
	squeezed.energy_passive_full_speed = squeezed.energy_passive_start_speed
	var rate: float = arm.passive_rate(squeezed.energy_passive_start_speed + 1.0, squeezed)
	check.call(is_finite(rate) and rate == squeezed.energy_passive_rate_max, "(p3) a zero span stays finite and gives the top rate (got %s)" % rate)


func _scenario_paused_states(check: Callable, player: PlayerController) -> void:
	var arm: ArmEnergy = player.arm_energy
	for state_name: StringName in [&"Loader"]:
		arm.reset_to(0.0)
		for i: int in SHIPPED_TPS:
			arm.tick(1.0 / SHIPPED_TPS, 20.0, state_name, false)
		check.call(arm.value == 0.0, "(s1) no passive charge in %s (got %.3f)" % [state_name, arm.value])


func _scenario_run_speed(check: Callable, player: PlayerController) -> void:
	var arm: ArmEnergy = player.arm_energy
	arm.reset_to(0.0)
	for i: int in SHIPPED_TPS * 5:
		arm.tick(1.0 / SHIPPED_TPS, player.config.run_speed, &"Run", false)
	check.call(arm.value == 0.0, "(s2) five seconds at run speed charge nothing (got %.3f)" % arm.value)


# A falling player with 40 m/s vertical speed and no horizontal speed charges nothing (Pitfall 10).
func _scenario_vertical_ignored(tree: SceneTree, check: Callable) -> void:
	var falling: PlayerController = Fixtures.spawn_player(tree.root, Vector3(20.0, 400.0, 80.0))
	await Fixtures.wait_physics(tree, 4)
	Fixtures.set_energy(falling, 0.0)
	falling.vertical_speed = -40.0
	await Fixtures.wait_physics(tree, 30)
	check.call(falling.arm_energy.value == 0.0 and falling.horizontal_speed() < 0.01, "(v1) falling at high vertical speed charges nothing (value %.3f, vertical %.1f)" % [falling.arm_energy.value, falling.vertical_speed])
	falling.queue_free()
	await falling.tree_exited


# A live run with dash hops (dash speed above 10 m/s) ends above where it started. It starts below the stage 2 cost, so every hop is
# the free stage 1 and the passive charge shows without a hop paying for itself.
func _scenario_hop_run(tree: SceneTree, check: Callable, player: PlayerController) -> void:
	var arm: ArmEnergy = player.arm_energy
	player.teleport(Vector3(0.0, 0.0, 90.0))
	await Fixtures.wait_physics(tree, 6)
	arm.reset_to(5.0)
	var before: float = arm.value
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 30)
	for hop: int in 2:
		Fixtures.send_action_event(&"dash", true)
		Fixtures.send_action_event(&"jump", true)
		await Fixtures.wait_physics(tree, 4)
		Fixtures.send_action_event(&"dash", false)
		Fixtures.send_action_event(&"jump", false)
		await Fixtures.wait_until(tree, func() -> bool: return player.is_grounded(), 120)
	var gained: float = arm.value - before
	Input.action_release(&"move_forward")
	await Fixtures.wait_physics(tree, 4)
	check.call(gained > 0.0, "(h1) a dash-hop run charges the arm (%.2f gained from %.1f)" % [gained, before])


# The charge button (D-06): R held in Idle with no move input adds energy_charge_rate per second; anything else stops it at once.
func _scenario_charge_button(tree: SceneTree, check: Callable, player: PlayerController) -> void:
	var arm: ArmEnergy = player.arm_energy
	var config: MovementConfig = player.config
	player.teleport(Vector3(0.0, 0.0, 0.0))
	await Fixtures.wait_physics(tree, 6)
	# Direct ticks with the player's own physics paused make the count exact.
	player.set_physics_process(false)
	var gained: Array[Dictionary] = []
	var on_gained: Callable = func(amount: float, source: StringName) -> void: gained.append({"amount": amount, "source": source})
	EventBus.energy_gained.connect(on_gained)
	arm.reset_to(0.0)
	Input.action_press(&"charge")
	for i: int in SHIPPED_TPS:
		arm.tick(1.0 / SHIPPED_TPS, 0.0, &"Idle", true)
	check.call(absf(arm.value - config.energy_charge_rate) < TOLERANCE and arm.charging, "(k1) 60 ticks of charge in Idle add energy_charge_rate %.1f (got %.3f)" % [config.energy_charge_rate, arm.value])
	var before: float = arm.value
	arm.tick(1.0 / SHIPPED_TPS, 0.0, &"Idle", false)
	check.call(arm.value == before and not arm.charging, "(k2) a move input stops the charge on that tick")
	check.call(gained.size() == 1 and gained[0]["source"] == &"charge" and absf(float(gained[0]["amount"]) - config.energy_charge_rate) < TOLERANCE, "(k2) one energy_gained(total, charge) fact when it stops (got %s)" % [gained])
	for state_name: StringName in [&"Jump", &"Dash", &"Run", &"Fall"]:
		arm.tick(1.0 / SHIPPED_TPS, 0.0, state_name, true)
		check.call(arm.value == before and not arm.charging, "(k3) no charge in %s" % state_name)
	Input.action_release(&"charge")
	arm.tick(1.0 / SHIPPED_TPS, 0.0, &"Idle", true)
	check.call(arm.value == before and not arm.charging, "(k4) a released button does not charge")
	arm.reset_to(100.0)
	Input.action_press(&"charge")
	arm.tick(1.0 / SHIPPED_TPS, 0.0, &"Idle", true)
	check.call(arm.value == 100.0, "(k5) a full arm stays at 100")
	Input.action_release(&"charge")
	EventBus.energy_gained.disconnect(on_gained)
	player.set_physics_process(true)
	# Live: standing in the real Idle state the held button charges.
	arm.reset_to(0.0)
	Input.action_press(&"charge")
	await Fixtures.wait_physics(tree, 30)
	check.call(arm.value > 1.0 and arm.charging, "(k6) holding charge in the real Idle state charges the arm (%.2f)" % arm.value)
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 3)
	check.call(not arm.charging, "(k6) walking stops the charge")
	Input.action_release(&"move_forward")
	Input.action_release(&"charge")
