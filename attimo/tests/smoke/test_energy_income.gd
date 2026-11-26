extends RefCounted
## Phase 05.1 plan 08 (ENRG-08, D-41, D-42): the timed income of the step clock. A passive +1 every energy_passive_interval (10 s),
## always: standing, running, in the Loader. The charge key R held while standing still in Idle gives +1 every energy_charge_interval
## (5 s) INSTEAD of the passive tick (one accumulator, never stacking). Speed earns nothing: a dash or a hop never adds a step.

const Fixtures := preload("res://tests/fixtures.gd")
const SHIPPED_TPS: int = 60

var _floor: StaticBody3D


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	_floor = Fixtures.spawn_floor(tree.root, Vector3(80.0, 1.0, 200.0))
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 80.0))
	await Fixtures.wait_physics(tree, 6)
	# Direct ticks with the player's own physics paused make the counts exact.
	player.set_physics_process(false)
	_scenario_passive(check, player)
	_scenario_charge_key(check, player)
	_scenario_never_stacks(check, player)
	_scenario_loader_and_full(check, player)
	player.set_physics_process(true)
	await _scenario_speed_earns_nothing(tree, check, player)
	player.queue_free()
	_floor.queue_free()
	await player.tree_exited


## `seconds` of direct ticks at 60 TPS.
func _ticks(arm: ArmEnergy, seconds: float, state_name: StringName, still: bool) -> void:
	for i: int in int(round(seconds * SHIPPED_TPS)):
		arm.tick(1.0 / SHIPPED_TPS, state_name, still)


func _scenario_passive(check: Callable, player: PlayerController) -> void:
	var arm: ArmEnergy = player.arm_energy
	var interval: float = player.config.energy_passive_interval
	check.call(is_equal_approx(interval, 10.0) and is_equal_approx(player.config.energy_charge_interval, 5.0), "(p0) the shipped intervals are 10 s and 5 s")
	var gained: Array[Dictionary] = []
	var on_gained: Callable = func(amount: int, source: StringName) -> void: gained.append({"amount": amount, "source": source})
	EventBus.energy_gained.connect(on_gained)
	arm.reset_to(0)
	_ticks(arm, interval - 0.5, &"Run", false)
	check.call(arm.value == 0, "(p1) before the interval nothing is added (got %d)" % arm.value)
	var progress: float = arm.tick_progress()
	check.call(progress > 0.9 and progress < 1.0, "(p1) tick_progress shows the climb toward the next step (got %.3f)" % progress)
	_ticks(arm, 0.6, &"Run", false)
	check.call(arm.value == 1, "(p2) one full interval gives exactly +1 (got %d)" % arm.value)
	check.call(gained.size() == 1 and gained[0]["amount"] == 1 and gained[0]["source"] == &"passive", "(p2) one energy_gained(1, passive) (got %s)" % [gained])
	_ticks(arm, interval, &"Idle", true)
	check.call(arm.value == 2, "(p3) it also ticks standing still without R (got %d)" % arm.value)
	EventBus.energy_gained.disconnect(on_gained)
	arm.reset_to(12)
	_ticks(arm, interval * 2.0, &"Run", false)
	check.call(arm.value == 12 and arm.tick_progress() == 0.0, "(p4) a full clock adds nothing and shows no progress (value %d, progress %.2f)" % [arm.value, arm.tick_progress()])


func _scenario_charge_key(check: Callable, player: PlayerController) -> void:
	var arm: ArmEnergy = player.arm_energy
	var config: MovementConfig = player.config
	var gained: Array[Dictionary] = []
	var on_gained: Callable = func(amount: int, source: StringName) -> void: gained.append({"amount": amount, "source": source})
	EventBus.energy_gained.connect(on_gained)
	arm.reset_to(0)
	Input.action_press(&"charge")
	_ticks(arm, config.energy_charge_interval + 0.1, &"Idle", true)
	check.call(arm.value == 1 and arm.charging, "(k1) R held in Idle and still gives +1 after energy_charge_interval (got %d)" % arm.value)
	check.call(gained.size() == 1 and gained[0]["source"] == &"charge", "(k1) the fact names the charge source (got %s)" % [gained])
	# Moving cancels R back to the passive interval: no more steps at the fast rate, progress is kept.
	var before: int = arm.value
	_ticks(arm, config.energy_charge_interval, &"Idle", false)
	check.call(arm.value == before and not arm.charging, "(k2) a move input stops the charge rate (got %d)" % arm.value)
	for state_name: StringName in [&"Jump", &"Dash", &"Run", &"Fall"]:
		arm.tick(1.0 / SHIPPED_TPS, state_name, true)
		check.call(not arm.charging, "(k3) R charges in no state but Idle (%s)" % state_name)
	Input.action_release(&"charge")
	EventBus.energy_gained.disconnect(on_gained)
	arm.reset_to(12)
	Input.action_press(&"charge")
	_ticks(arm, config.energy_charge_interval * 2.0, &"Idle", true)
	Input.action_release(&"charge")
	check.call(arm.value == 12, "(k4) a full arm stays at 12")


# One accumulator: R replaces the passive tick, it never adds on top inside the same 10 s.
func _scenario_never_stacks(check: Callable, player: PlayerController) -> void:
	var arm: ArmEnergy = player.arm_energy
	var config: MovementConfig = player.config
	arm.reset_to(0)
	Input.action_press(&"charge")
	_ticks(arm, config.energy_passive_interval, &"Idle", true)
	Input.action_release(&"charge")
	check.call(arm.value == 2, "(s1) 10 s of R gives exactly +2 (5 s each), not +3 with the passive tick on top (got %d)" % arm.value)


func _scenario_loader_and_full(check: Callable, player: PlayerController) -> void:
	var arm: ArmEnergy = player.arm_energy
	arm.reset_to(0)
	_ticks(arm, player.config.energy_passive_interval + 0.1, &"Loader", false)
	check.call(arm.value == 1, "(l1) the passive tick also runs during a Loader hold (D-42 always; got %d)" % arm.value)


# D-41: speed never earns a step. A dash-hop run at speed adds nothing within a few seconds (the tick interval is raised out of reach).
func _scenario_speed_earns_nothing(tree: SceneTree, check: Callable, player: PlayerController) -> void:
	var arm: ArmEnergy = player.arm_energy
	player.config = player.config.duplicate() as MovementConfig
	player.config.energy_passive_interval = 100000.0
	player.teleport(Vector3(0.0, 0.0, 90.0))
	await Fixtures.wait_physics(tree, 6)
	Fixtures.set_energy(player, 5)
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 30)
	Fixtures.send_action_event(&"dash", true)
	Fixtures.send_action_event(&"jump", true)
	await Fixtures.wait_physics(tree, 4)
	Fixtures.send_action_event(&"dash", false)
	Fixtures.send_action_event(&"jump", false)
	await Fixtures.wait_until(tree, func() -> bool: return player.is_grounded(), 120)
	var peak_speed: float = player.horizontal_speed()
	Input.action_release(&"move_forward")
	await Fixtures.wait_physics(tree, 4)
	check.call(arm.value <= 5, "(h1) a dash-hop run never adds a step; the dash and the hop only cost (value %d, speed %.1f)" % [arm.value, peak_speed])
