extends RefCounted
## Plan 05-01 (HAND-04, D-01..D-03): the Loader. Holding `loader` brakes Rino on the ground (a skid of loader_skid_time) or hangs
## Rino in the air (gravity off), the world runs at loader_slow_factor while held, and the release discharges along the camera view:
## LoaderMath.discharge_speed(stored, min_push, bonus, max). The hold auto-discharges at loader_hold_cap of REAL time (72 ticks at
## 60 TPS, whatever Engine.time_scale is). The bonus costs one full core and is decided at the release; an empty arm gets the
## redirect cooldown. One use per airborne stretch (D-02), the air dash is never touched (D-03), the jump buffer never fires after
## the release, and Engine.time_scale is 1.0 after every exit path. Every expectation derives from player.config.

const Fixtures := preload("res://tests/fixtures.gd")
const SHIPPED_TPS: int = 60
## The skid is run in real time, so it ends within loader_skid_time plus a little slack.
const SKID_SLACK_TICKS: int = 3
## Full-hold ticks of the cap edge: 1.2 s at 60 TPS is the 72nd Loader physics update.
const CAP_TICKS: int = 72

var _bus: Node
var _floor: StaticBody3D
var _rig: CameraRig
var _player: PlayerController
var _started: Array[Dictionary] = []
var _released: Array[Dictionary] = []
var _spent: Array[Dictionary] = []
var _on_started: Callable
var _on_released: Callable
var _on_spent: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	Engine.physics_ticks_per_second = SHIPPED_TPS
	check.call(InputMap.has_action(&"loader"), "the Input Map has the loader action")
	var probe: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 1.0, 0.0))
	var has_state: bool = probe.get_node_or_null(^"StateMachine/Loader") != null
	probe.queue_free()
	await probe.tree_exited
	check.call(has_state, "player.tscn has the Loader state node")
	if not has_state or not InputMap.has_action(&"loader"):
		return
	await _scenario_ground_hold(tree, check)
	await _scenario_cap_edge(tree, check)
	await _scenario_release(tree, check)
	await _scenario_no_bonus_edge(tree, check)
	await _scenario_air_hang(tree, check)
	await _scenario_ground_throw_over_ledge(tree, check)
	await _scenario_air_dash_untouched(tree, check, true)
	await _scenario_air_dash_untouched(tree, check, false)
	await _scenario_jump_buffer(tree, check)
	await _scenario_teleport(tree, check)
	await _scenario_free(tree, check)


## Fresh recorders, a floor, a player on its own config instance, a camera rig and one full core of energy.
func _begin(tree: SceneTree, position: Vector3, pitch: float = -0.22, floor_size: Vector3 = Vector3(60.0, 1.0, 60.0)) -> PlayerController:
	_started = []
	_released = []
	_spent = []
	_on_started = func(_position: Vector3, stored_speed: float, in_air: bool) -> void: _started.append({"stored_speed": stored_speed, "in_air": in_air})
	_on_released = func(_position: Vector3, direction: Vector3, speed: float, bonus: bool) -> void:
		_released.append({
			"direction": direction,
			"speed": speed,
			"bonus": bonus,
			"velocity": Vector3(_player.move_velocity.x, _player.vertical_speed, _player.move_velocity.z),
			"cooldown": _player.loader_cooldown_timer,
			"energy": _player.arm_energy.value,
			"dash_available": _player.air_dash_available,
			"expected_direction": _player.loader_direction(),
		})
	_on_spent = func(amount: float, reason: StringName) -> void: _spent.append({"amount": amount, "reason": reason})
	_bus.connect(&"loader_started", _on_started)
	_bus.connect(&"loader_released", _on_released)
	_bus.connect(&"energy_spent", _on_spent)
	_floor = Fixtures.spawn_floor(tree.root, floor_size)
	_player = Fixtures.spawn_player(tree.root, position)
	_rig = Fixtures.spawn_camera_rig(tree.root, _player)
	_rig.pitch = pitch
	Fixtures.set_energy(_player, 25.0)
	await Fixtures.wait_physics(tree, 10)
	return _player


func _end(tree: SceneTree, check: Callable, name: String) -> void:
	for action: StringName in [&"loader", &"move_forward", &"jump", &"dash"]:
		Fixtures.send_action_event(action, false)
		Input.action_release(action)
	# The release hitstop (loader_hitstop_time of real time, plan 05-02) ends by itself within a few ticks.
	await Fixtures.wait_physics(tree, 8)
	check.call(Engine.time_scale == 1.0, "(%s) Engine.time_scale is back at 1.0 (got %.3f)" % [name, Engine.time_scale])
	Fixtures.restore_time()
	_bus.disconnect(&"loader_started", _on_started)
	_bus.disconnect(&"loader_released", _on_released)
	_bus.disconnect(&"energy_spent", _on_spent)
	_on_started = Callable()
	_on_released = Callable()
	_on_spent = Callable()
	if is_instance_valid(_rig):
		_rig.queue_free()
	if is_instance_valid(_player):
		_player.queue_free()
		await _player.tree_exited
	_floor.queue_free()
	await tree.process_frame


func _is_loader(player: PlayerController) -> bool:
	return player.state_machine.current.name == &"Loader"


func _press_loader(tree: SceneTree, player: PlayerController) -> int:
	Input.action_press(&"loader")
	return await Fixtures.wait_until(tree, func() -> bool: return _is_loader(player), 4)


## Runs forward until the player reaches run_speed.
func _run_up(tree: SceneTree, player: PlayerController) -> void:
	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - player.config.run_speed) < 0.05, 180)


# D-01 ground use: the press enters the Loader, the world slows, the run brakes within loader_skid_time, the stored velocity
# is the run velocity.
func _scenario_ground_hold(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree, Vector3(0.0, 0.0, 25.0))
	var config: MovementConfig = player.config
	await _run_up(tree, player)
	check.call(absf(player.horizontal_speed() - config.run_speed) < 0.05, "(g1) the player runs at run_speed before the press (got %.2f)" % player.horizontal_speed())
	var entered: int = await _press_loader(tree, player)
	check.call(entered >= 0, "(g1) the loader press enters the Loader state within 4 ticks (state %s)" % player.state_machine.current.name)
	check.call(Engine.time_scale == config.loader_slow_factor, "(g1) the world runs at loader_slow_factor %.2f (got %.3f)" % [config.loader_slow_factor, Engine.time_scale])
	check.call(_started.size() == 1 and _started[0]["in_air"] == false, "(g1) loader_started fired once with in_air false (%s)" % [_started])
	var state: LoaderState = player.loader_state()
	check.call(absf(state.stored_velocity.length() - config.run_speed) < 0.1, "(g2) the stored velocity is the run velocity (got %.2f)" % state.stored_velocity.length())
	await Fixtures.wait_physics(tree, ceili(config.loader_skid_time * SHIPPED_TPS) + SKID_SLACK_TICKS)
	check.call(player.horizontal_speed() < 0.05, "(g3) the run brakes to a stop within loader_skid_time (got %.3f m/s)" % player.horizontal_speed())
	check.call(player.loader_active() and player.vertical_speed == 0.0, "(g3) the hold keeps going on the floor (state %s)" % player.state_machine.current.name)
	Input.action_release(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return not _is_loader(player), 4)
	await _end(tree, check, "ground hold")


# The cap is REAL time: still Loader after 71 Loader physics updates, out on the 72nd (1.2 s at 60 TPS), at time scale 0.25.
func _scenario_cap_edge(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree, Vector3(0.0, 0.0, 0.0))
	var config: MovementConfig = player.config
	check.call(is_equal_approx(config.loader_hold_cap * SHIPPED_TPS, float(CAP_TICKS)), "(c0) loader_hold_cap %.2f s is %d ticks at %d TPS" % [config.loader_hold_cap, CAP_TICKS, SHIPPED_TPS])
	var entered: int = await _press_loader(tree, player)
	check.call(entered >= 0, "(c1) the press enters the Loader")
	var state: LoaderState = player.loader_state()
	var guard: int = 0
	while state.update_count < CAP_TICKS - 1 and guard < 400:
		await tree.physics_frame
		guard += 1
	check.call(state.update_count == CAP_TICKS - 1 and _is_loader(player), "(c2) after %d updates the player is still in the Loader (updates %d, state %s)" % [CAP_TICKS - 1, state.update_count, player.state_machine.current.name])
	check.call(Engine.time_scale == config.loader_slow_factor, "(c2) the world is still slow (got %.3f)" % Engine.time_scale)
	await tree.physics_frame
	check.call(state.update_count == CAP_TICKS and not _is_loader(player), "(c3) the %dnd update released the hold (updates %d, state %s)" % [CAP_TICKS, state.update_count, player.state_machine.current.name])
	check.call(_released.size() == 1, "(c3) loader_released fired once (got %d)" % _released.size())
	check.call(not (TimeFx.active_sources()).has(&"loader") and Engine.time_scale >= config.loader_hitstop_scale, "(c3) the Loader slow-down is released at the cap; only the release hitstop may remain (got %.3f)" % Engine.time_scale)
	await _end(tree, check, "cap edge")


# The release: along the camera view, at the LoaderMath speed with the bonus; the bonus costs exactly one core.
func _scenario_release(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree, Vector3(0.0, 0.0, 25.0))
	var config: MovementConfig = player.config
	await _run_up(tree, player)
	await _press_loader(tree, player)
	var state: LoaderState = player.loader_state()
	var stored: float = state.stored_velocity.length()
	await Fixtures.wait_physics(tree, 20)
	check.call(_is_loader(player), "(r1) still holding after 20 ticks")
	Input.action_release(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return not _released.is_empty(), 6)
	check.call(_released.size() == 1, "(r1) the release fired loader_released once (got %d)" % _released.size())
	if _released.is_empty():
		await _end(tree, check, "release")
		return
	var released: Dictionary = _released[0]
	var velocity: Vector3 = released["velocity"] as Vector3
	var expected_direction: Vector3 = released["expected_direction"] as Vector3
	var angle: float = rad_to_deg(velocity.angle_to(expected_direction))
	check.call(angle < 2.0, "(r2) the discharge points along the camera view (off by %.2f deg)" % angle)
	var expected_speed: float = LoaderMath.discharge_speed(stored, config.loader_min_push, config.loader_bonus_speed, config.loader_max_speed)
	check.call(absf(velocity.length() - expected_speed) < 0.05, "(r3) the discharge speed is LoaderMath.discharge_speed with the bonus %.2f (got %.2f)" % [expected_speed, velocity.length()])
	check.call(released["bonus"] == true and absf((released["speed"] as float) - expected_speed) < 0.05, "(r3) the fact carries bonus true and the speed (%s)" % [released])
	check.call(absf(player.arm_energy.value) < 0.0001, "(r4) the bonus took the whole core: energy %.2f" % player.arm_energy.value)
	check.call(_spent.size() == 1 and is_equal_approx(_spent[0]["amount"] as float, 25.0) and _spent[0]["reason"] == &"loader", "(r4) energy_spent(25.0, loader) fired once (%s)" % [_spent])
	check.call(not _is_loader(player) and not (TimeFx.active_sources()).has(&"loader"), "(r5) the state is left and the Loader slow-down is released (hitstop scale %.3f)" % Engine.time_scale)
	await _end(tree, check, "release")


# Below one core there is no bonus and no spend: the arm counts as empty and the redirect cooldown starts (A7, D-04 carry-over).
func _scenario_no_bonus_edge(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree, Vector3(0.0, 0.0, 25.0))
	var config: MovementConfig = player.config
	Fixtures.set_energy(player, 24.9)
	await _run_up(tree, player)
	await _press_loader(tree, player)
	var stored: float = player.loader_state().stored_velocity.length()
	await Fixtures.wait_physics(tree, 10)
	Input.action_release(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return not _released.is_empty(), 6)
	check.call(_released.size() == 1 and _released[0]["bonus"] == false, "(n1) 24.9 energy gives no bonus (%s)" % [_released])
	check.call(absf(player.arm_energy.value - 24.9) < 0.0001 and _spent.is_empty(), "(n1) the energy stays 24.9 and nothing is spent (energy %.3f)" % player.arm_energy.value)
	if _released.is_empty():
		await _end(tree, check, "no bonus")
		return
	var velocity: Vector3 = _released[0]["velocity"] as Vector3
	var expected_speed: float = LoaderMath.discharge_speed(stored, config.loader_min_push, 0.0, config.loader_max_speed)
	check.call(absf(velocity.length() - expected_speed) < 0.05, "(n2) the redirect speed is max(stored, min_push) %.2f (got %.2f)" % [expected_speed, velocity.length()])
	check.call(is_equal_approx(_released[0]["cooldown"] as float, config.loader_redirect_cooldown), "(n3) the redirect cooldown starts at %.2f (got %.3f)" % [config.loader_redirect_cooldown, _released[0]["cooldown"] as float])
	await Fixtures.wait_physics(tree, 10)
	var before: int = _started.size()
	Input.action_press(&"loader")
	await Fixtures.wait_physics(tree, 6)
	check.call(not _is_loader(player) and _started.size() == before, "(n4) a ground press inside the cooldown does not enter the Loader (state %s)" % player.state_machine.current.name)
	Input.action_release(&"loader")
	await Fixtures.wait_physics(tree, 2)
	var cooled: int = await Fixtures.wait_until(tree, func() -> bool: return player.loader_cooldown_timer <= 0.0, int(config.loader_redirect_cooldown * SHIPPED_TPS) + 30)
	check.call(cooled >= 0, "(n5) the cooldown runs out")
	var entered: int = await _press_loader(tree, player)
	check.call(entered >= 0, "(n5) after the cooldown the press enters the Loader again")
	await _end(tree, check, "no bonus")


## Drops the player from `height`, presses the Loader while it falls and returns once the Loader is entered (or fails the check).
func _air_enter(tree: SceneTree, check: Callable, player: PlayerController, name: String) -> bool:
	await Fixtures.wait_until(tree, func() -> bool: return not player.is_grounded() and player.vertical_speed < -3.0, 120)
	var entered: int = await _press_loader(tree, player)
	check.call(entered >= 0 and _started.size() == 1 and _started[0]["in_air"] == true, "(%s) the airborne press enters the Loader with in_air true (%s)" % [name, _started])
	return entered >= 0


# D-02: in the air the body hangs (gravity off) and the Loader is spent for the airborne stretch; landing or a refill gives it back.
func _scenario_air_hang(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree, Vector3(0.0, 15.0, 0.0), 0.3, Vector3(200.0, 1.0, 200.0))
	check.call(player.loader_available, "(a0) the Loader is available at spawn")
	if not await _air_enter(tree, check, player, "a1"):
		await _end(tree, check, "air hang")
		return
	check.call(not player.loader_available, "(a1) the airborne press spends the Loader use")
	var drift: float = 0.0
	for i: int in 30:
		await tree.physics_frame
		drift = maxf(drift, absf(player.vertical_speed))
	check.call(drift < 0.0001 and _is_loader(player), "(a2) the body hangs for 30 ticks (max vertical speed %.5f)" % drift)
	Input.action_release(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return not _is_loader(player), 6)
	check.call(not player.loader_available, "(a3) the use stays spent after the release")
	await Fixtures.wait_physics(tree, 2)
	var before: int = _started.size()
	Input.action_press(&"loader")
	await Fixtures.wait_physics(tree, 5)
	check.call(not _is_loader(player) and _started.size() == before and not player.is_grounded(), "(a4) a second press in the same airtime does not enter the Loader (state %s)" % player.state_machine.current.name)
	Input.action_release(&"loader")
	var landed: int = await Fixtures.wait_until(tree, func() -> bool: return player.is_grounded(), 600)
	check.call(landed >= 0 and player.loader_available, "(a5) landing gives the Loader back")
	player.loader_available = false
	player.refill_air_dash()
	check.call(player.loader_available, "(a6) refill_air_dash (boost ring, slingshot) gives the Loader back")
	await _end(tree, check, "air hang")


# D-03: the discharge leaves air_dash_available exactly as it was, and locks air control for loader_release_control_lock.
func _scenario_air_dash_untouched(tree: SceneTree, check: Callable, dash_available: bool) -> void:
	var label: String = "d3 dash %s" % ("kept" if dash_available else "spent")
	var player: PlayerController = await _begin(tree, Vector3(0.0, 15.0, 0.0), 0.3, Vector3(200.0, 1.0, 200.0))
	var config: MovementConfig = player.config
	player.air_dash_available = dash_available
	if not await _air_enter(tree, check, player, label):
		await _end(tree, check, label)
		return
	check.call(player.air_dash_available == dash_available, "(%s) entering the Loader leaves the air dash as it was" % label)
	await Fixtures.wait_physics(tree, 6)
	Input.action_release(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return not _released.is_empty(), 6)
	check.call(_released.size() == 1 and _released[0]["dash_available"] == dash_available, "(%s) the discharge leaves air_dash_available at %s (%s)" % [label, dash_available, _released])
	await tree.physics_frame
	check.call(player.air_dash_available == dash_available, "(%s) the air dash is still %s one tick later" % [label, dash_available])
	check.call(player.air_control_lock_timer > 0.0, "(%s) air control is locked right after the release (timer %.3f)" % [label, player.air_control_lock_timer])
	await Fixtures.wait_physics(tree, ceili(config.loader_release_control_lock * SHIPPED_TPS) + 2)
	check.call(player.air_control_lock_timer == 0.0 and not player.is_grounded(), "(%s) air control is back after loader_release_control_lock (timer %.3f)" % [label, player.air_control_lock_timer])
	await _end(tree, check, label)


# A jump press during the hold never fires a jump after the release (Pitfall 4: the buffer would outlive the slow motion).
func _scenario_jump_buffer(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree, Vector3(0.0, 0.0, 0.0))
	await _press_loader(tree, player)
	await Fixtures.wait_physics(tree, 3)
	await Fixtures.tap_action(tree, &"jump")
	await Fixtures.wait_physics(tree, 6)
	check.call(_is_loader(player), "(j1) the jump press does not leave the Loader")
	Input.action_release(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return not _is_loader(player), 6)
	await tree.physics_frame
	check.call(player.jump_buffer_timer == 0.0, "(j2) the jump buffer is spent on exit (got %.3f)" % player.jump_buffer_timer)
	var jumped: bool = false
	for i: int in 30:
		await tree.physics_frame
		var state_name: StringName = player.state_machine.current.name
		if state_name == &"Jump" or state_name == &"LongJump":
			jumped = true
	check.call(not jumped, "(j3) no jump fires within 30 ticks after the release")
	await _end(tree, check, "jump buffer")


# Every exit path ends the slow motion: teleport() mid-hold hands the FSM to Fall.
func _scenario_teleport(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree, Vector3(0.0, 0.0, 0.0))
	await _press_loader(tree, player)
	await Fixtures.wait_physics(tree, 4)
	check.call(Engine.time_scale == player.config.loader_slow_factor, "(t1) the hold is slow before the teleport")
	player.teleport(Vector3(0.0, 5.0, 0.0))
	check.call(player.state_machine.current.name == &"Fall", "(t2) teleport() mid-hold leaves the Loader for Fall (state %s)" % player.state_machine.current.name)
	check.call(Engine.time_scale == 1.0, "(t2) the time scale is 1.0 right after the teleport (got %.3f)" % Engine.time_scale)
	await _end(tree, check, "teleport")


# Freeing the player mid-hold must not leave the world slow.
func _scenario_free(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree, Vector3(0.0, 0.0, 0.0))
	await _press_loader(tree, player)
	await Fixtures.wait_physics(tree, 4)
	check.call(Engine.time_scale == player.config.loader_slow_factor, "(f1) the hold is slow before the player is freed")
	_rig.queue_free()
	player.queue_free()
	await player.tree_exited
	check.call(Engine.time_scale == 1.0, "(f2) freeing the player mid-hold restores the time scale (got %.3f)" % Engine.time_scale)
	await _end(tree, check, "free")


# D-02 / WR-02: a ground discharge aimed slightly down stays on the floor; when the throw carries Rino over a ledge, that airborne
# stretch already used the Loader, so a second press in the air does not enter it. Landing gives it back.
func _scenario_ground_throw_over_ledge(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree, Vector3(0.0, 0.0, -1.5), -0.22, Vector3(6.0, 1.0, 6.0))
	player.debug_loader_direction = Vector3(0.0, -0.1, -1.0)
	var entered: int = await _press_loader(tree, player)
	check.call(entered >= 0 and _started.size() == 1 and _started[0]["in_air"] == false, "(l1) a standing ground press enters the Loader (%s)" % [_started])
	await Fixtures.wait_physics(tree, 3)
	Input.action_release(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return not _released.is_empty(), 6)
	var released_velocity: Vector3 = Vector3.ZERO if _released.is_empty() else _released[0]["velocity"] as Vector3
	check.call(released_velocity.y <= 0.0, "(l1) the throw points slightly down (vertical %.2f)" % released_velocity.y)
	var left: int = await Fixtures.wait_until(tree, func() -> bool: return not player.is_grounded(), 60)
	check.call(left >= 0, "(l2) the throw carries Rino over the ledge")
	check.call(not player.loader_available, "(l2) leaving the floor with the throw spends the airborne Loader use")
	await Fixtures.wait_physics(tree, ceili(player.config.loader_redirect_cooldown * SHIPPED_TPS) + 2)
	var before: int = _started.size()
	Input.action_press(&"loader")
	await Fixtures.wait_physics(tree, 4)
	check.call(not _is_loader(player) and _started.size() == before, "(l3) a second press in the same airtime does not enter the Loader (state %s)" % player.state_machine.current.name)
	Input.action_release(&"loader")
	await _end(tree, check, "ground throw over ledge")
