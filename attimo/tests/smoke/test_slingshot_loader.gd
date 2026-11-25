extends RefCounted
## Plan 05.1-01 (KIT-03, D-01..D-03, D-17): the slingshot core is a Catch & launch block (FREE_AIM) that puts Rino into the Loader
## state with a CAGE source, so it plays exactly like the Loader. Entering the brass cage catches and hangs Rino, the world runs at
## loader_slow_factor, and the hold ends on the release of a held or later pressed loader button (a same-tick tap fires at once) or at
## loader_hold_cap of real time with no input (never on tick 1). The throw goes along the view at
## LoaderMath.discharge_speed(stored, loader_min_push, 0, loader_max_speed): no bonus, no energy spent or gained, no redirect cooldown,
## loader_available true, the air dash untouched, air control locked. A player in an arm Loader hold is not caught, and the cage does
## not catch again before rearm_time has passed and the player has left the radius. Every expectation derives from player.config.
## The LoaderProfile source is read through the script's constant map and LoaderState.source() through call(), so this file compiles
## before the classes exist (TDD RED of plan 05.1-01).

const Fixtures := preload("res://tests/fixtures.gd")

const KIT_SCENE: String = "res://scenes/kit/steampunk/slingshot_core.tscn"
const PROFILE_SCRIPT: String = "res://scripts/player/loader_profile.gd"
const SHIPPED_TPS: int = 60
## Full-hold ticks of the cap edge: 1.2 s at 60 TPS is the 72nd Loader physics update.
const CAP_TICKS: int = 72
const CENTRE: Vector3 = Vector3(0.0, 10.0, 0.0)
## Where the fly-in starts: 4 m west of the cage, chest level with its centre.
const START_OFFSET: Vector3 = Vector3(-4.0, -1.0, 0.0)
const ENTRY_SPEED: float = 9.0
## The deterministic throw direction (debug_loader_direction), slightly up and to the north.
const THROW_DIRECTION: Vector3 = Vector3(0.0, 0.3, -1.0)
const FAR: Vector3 = Vector3(0.0, 10.0, 60.0)
## Plan 05.1-05: the steam cues and the brass preview.
const PREVIEW_SCRIPT: String = "res://scripts/player/loader_preview.gd"
const BLAST_HIDE_SECONDS: float = 0.3

var _bus: Node
var _floor: StaticBody3D
var _cage: Node3D
var _player: PlayerController
var _released: Array[Dictionary] = []
var _spent: Array[Dictionary] = []
var _on_released: Callable
var _on_spent: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await tree.process_frame
	check.call(ResourceLoader.exists(KIT_SCENE), "the brass cage scene %s exists" % KIT_SCENE)
	check.call(_cage_source() >= 0, "LoaderProfile.Source has a CAGE value (%s)" % PROFILE_SCRIPT)
	if not ResourceLoader.exists(KIT_SCENE) or _cage_source() < 0:
		return
	await _scenario_held_release(tree, check, true)
	await _scenario_cap(tree, check, false)
	await _scenario_press_later(tree, check, true)
	await _scenario_tap(tree, check, false)
	await _scenario_arm_hold_not_caught(tree, check)
	await _scenario_rearm(tree, check)
	await _scenario_presentation(tree, check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


## LoaderProfile.Source.CAGE read from the script's constants, or -1 while the class does not exist.
func _cage_source() -> int:
	return _profile_source("CAGE")


## A LoaderProfile.Source value by name, or -1 while the class does not exist.
func _profile_source(key: String) -> int:
	if not ResourceLoader.exists(PROFILE_SCRIPT):
		return -1
	var script: GDScript = load(PROFILE_SCRIPT) as GDScript
	if script == null:
		return -1
	var sources: Dictionary = script.get_script_constant_map().get("Source", {}) as Dictionary
	return int(sources.get(key, -1))


## LoaderState.source() of the player, or -1 when the state has no such method.
func _source_of(player: PlayerController) -> int:
	var state: LoaderState = player.loader_state()
	if state == null or not state.has_method(&"source"):
		return -1
	return int(state.call(&"source"))


func _is_loader(player: PlayerController) -> bool:
	return player.state_machine.current.name == &"Loader"


## Fresh recorders, a floor far below, the cage at CENTRE and a player parked far away on one full core of energy.
func _begin(tree: SceneTree) -> PlayerController:
	_released = []
	_spent = []
	_on_released = func(_position: Vector3, direction: Vector3, speed: float, bonus: bool) -> void:
		_released.append({
			"direction": direction,
			"speed": speed,
			"bonus": bonus,
			"velocity": Vector3(_player.move_velocity.x, _player.vertical_speed, _player.move_velocity.z),
			"energy": _player.arm_energy.value,
			"cooldown": _player.loader_cooldown_timer,
			"dash_available": _player.air_dash_available,
			"update_count": _player.loader_state().update_count,
		})
	_on_spent = func(amount: float, reason: StringName) -> void: _spent.append({"amount": amount, "reason": reason})
	_bus.connect(&"loader_released", _on_released)
	_bus.connect(&"energy_spent", _on_spent)
	_floor = Fixtures.spawn_floor(tree.root, Vector3(300.0, 1.0, 300.0))
	_cage = Fixtures.spawn_scene(tree.root, KIT_SCENE, CENTRE)
	_player = Fixtures.spawn_player(tree.root, FAR)
	_player.debug_loader_direction = THROW_DIRECTION
	Fixtures.set_energy(_player, 25.0)
	await Fixtures.wait_physics(tree, 3)
	return _player


func _end(tree: SceneTree, check: Callable, name: String) -> void:
	for action: StringName in [&"loader", &"move_forward", &"jump", &"dash"]:
		Input.action_release(action)
	await Fixtures.wait_physics(tree, 8)
	check.call(Engine.time_scale == 1.0, "(%s) Engine.time_scale is back at 1.0 (got %.3f)" % [name, Engine.time_scale])
	Fixtures.restore_time()
	_bus.disconnect(&"loader_released", _on_released)
	_bus.disconnect(&"energy_spent", _on_spent)
	_on_released = Callable()
	_on_spent = Callable()
	if is_instance_valid(_player):
		_player.queue_free()
		await _player.tree_exited
	if is_instance_valid(_cage):
		_cage.queue_free()
	_floor.queue_free()
	await tree.process_frame
	await tree.process_frame


## Puts the player west of the cage and launches it into the cage at ENTRY_SPEED. Returns the ticks until the Loader state, or -1.
func _fly_in(tree: SceneTree, player: PlayerController, dash_available: bool) -> int:
	player.teleport(CENTRE + START_OFFSET)
	player.air_dash_available = dash_available
	player.launch_along(Vector3.RIGHT, ENTRY_SPEED, false)
	return await Fixtures.wait_until(tree, func() -> bool: return _is_loader(player), 40)


## The catch checks every scenario shares: Loader with source CAGE, the world at loader_slow_factor, the body hangs.
func _check_catch(tree: SceneTree, check: Callable, player: PlayerController, entered: int, name: String) -> bool:
	var config: MovementConfig = player.config
	check.call(entered >= 0, "(%s) flying into the cage at %.0f m/s enters the Loader (state %s)" % [name, ENTRY_SPEED, player.state_machine.current.name])
	if entered < 0:
		return false
	check.call(_source_of(player) == _cage_source(), "(%s) the Loader source is CAGE (got %d)" % [name, _source_of(player)])
	check.call(absf(Engine.time_scale - config.loader_slow_factor) < 0.001, "(%s) the world runs at loader_slow_factor %.2f (got %.3f)" % [name, config.loader_slow_factor, Engine.time_scale])
	await tree.physics_frame
	check.call(_is_loader(player) and absf(player.vertical_speed) < 0.0001 and player.move_velocity.length() < 0.0001, "(%s) the cage freezes the momentum (v %.3f, %.3f)" % [name, player.vertical_speed, player.move_velocity.length()])
	return true


## The discharge checks every scenario shares (D-03).
func _check_discharge(check: Callable, player: PlayerController, stored: float, dash_available: bool, name: String) -> void:
	var config: MovementConfig = player.config
	check.call(_released.size() == 1, "(%s) loader_released fired once (got %d)" % [name, _released.size()])
	if _released.is_empty():
		return
	var released: Dictionary = _released[0]
	var velocity: Vector3 = released["velocity"] as Vector3
	var expected: float = LoaderMath.discharge_speed(stored, config.loader_min_push, 0.0, config.loader_max_speed)
	check.call(absf(velocity.length() - expected) < 0.01, "(%s) the throw speed is LoaderMath.discharge_speed without bonus %.2f (got %.2f)" % [name, expected, velocity.length()])
	var angle: float = rad_to_deg(velocity.angle_to(THROW_DIRECTION.normalized()))
	check.call(angle < 1.0, "(%s) the throw goes along the view (off by %.2f deg)" % [name, angle])
	check.call(released["bonus"] == false, "(%s) the cage adds no bonus" % name)
	check.call(absf((released["energy"] as float) - 25.0) < 0.0001 and _spent.is_empty(), "(%s) no energy is spent or gained (energy %.3f, spent %s)" % [name, released["energy"] as float, _spent])
	check.call(is_zero_approx(released["cooldown"] as float), "(%s) loader_cooldown_timer stays 0 (got %.3f)" % [name, released["cooldown"] as float])
	check.call(player.loader_available, "(%s) the cage gives the Loader use back (loader_available true)" % name)
	check.call(released["dash_available"] == dash_available and player.air_dash_available == dash_available, "(%s) air_dash_available stays %s" % [name, dash_available])
	check.call(player.air_control_lock_timer > 0.0, "(%s) air control is locked after the throw (timer %.3f)" % [name, player.air_control_lock_timer])
	check.call(player.get(&"loader_profile") == null, "(%s) the profile is cleared on exit, the next arm press is ARM" % name)


# D-02: RMB held on entry -> its release fires. RMB is pressed while the airborne use is spent, so it cannot start an arm Loader.
func _scenario_held_release(tree: SceneTree, check: Callable, dash_available: bool) -> void:
	var player: PlayerController = await _begin(tree)
	player.loader_available = false
	player.teleport(CENTRE + START_OFFSET)
	Input.action_press(&"loader")
	await Fixtures.wait_physics(tree, 2)
	check.call(not _is_loader(player), "(held) a held RMB with the use spent does not start an arm Loader")
	var entered: int = await _fly_in(tree, player, dash_available)
	if not await _check_catch(tree, check, player, entered, "held"):
		await _end(tree, check, "held")
		return
	var stored: float = player.loader_state().stored_velocity.length()
	check.call(stored > ENTRY_SPEED - 1.0, "(held) the stored velocity is the entry velocity (%.2f)" % stored)
	await Fixtures.wait_physics(tree, 10)
	check.call(_is_loader(player) and _released.is_empty(), "(held) still holding after 10 ticks while RMB is held")
	Input.action_release(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return not _released.is_empty(), 4)
	_check_discharge(check, player, stored, dash_available, "held")
	await _end(tree, check, "held")


# D-02: no input -> the hold auto-launches at loader_hold_cap of real time, still holding on update 71, out on update 72.
func _scenario_cap(tree: SceneTree, check: Callable, dash_available: bool) -> void:
	var player: PlayerController = await _begin(tree)
	var entered: int = await _fly_in(tree, player, dash_available)
	var state: LoaderState = player.loader_state()
	var stored: float = state.stored_velocity.length()
	if not await _check_catch(tree, check, player, entered, "cap"):
		await _end(tree, check, "cap")
		return
	check.call(_released.is_empty(), "(cap) no input does not fire on the first tick")
	var guard: int = 0
	while state.update_count < CAP_TICKS - 1 and guard < 400:
		await tree.physics_frame
		guard += 1
	check.call(state.update_count == CAP_TICKS - 1 and _is_loader(player), "(cap) after %d updates the cage still holds (updates %d, state %s)" % [CAP_TICKS - 1, state.update_count, player.state_machine.current.name])
	await tree.physics_frame
	check.call(not _is_loader(player) and _released.size() == 1 and int(_released[0]["update_count"]) == CAP_TICKS, "(cap) the %dnd update fires the auto launch (%s)" % [CAP_TICKS, _released])
	_check_discharge(check, player, stored, dash_available, "cap")
	await _end(tree, check, "cap")


# D-02: RMB not held -> a press after 5 updates continues the hold, the release after 12 updates fires on the next update.
func _scenario_press_later(tree: SceneTree, check: Callable, dash_available: bool) -> void:
	var player: PlayerController = await _begin(tree)
	var entered: int = await _fly_in(tree, player, dash_available)
	var state: LoaderState = player.loader_state()
	var stored: float = state.stored_velocity.length()
	if not await _check_catch(tree, check, player, entered, "press"):
		await _end(tree, check, "press")
		return
	while state.update_count < 5 and _is_loader(player):
		await tree.physics_frame
	Input.action_press(&"loader")
	while state.update_count < 12 and _is_loader(player):
		await tree.physics_frame
	check.call(_is_loader(player) and _released.is_empty(), "(press) the press continues the hold (updates %d)" % state.update_count)
	Input.action_release(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return not _released.is_empty(), 4)
	check.call(_released.size() == 1 and int(_released[0]["update_count"]) == 13, "(press) the release after update 12 fires on update 13 (%s)" % [_released])
	_check_discharge(check, player, stored, dash_available, "press")
	await _end(tree, check, "press")


# D-02: a press and release on the same tick (a tap) fires at once.
func _scenario_tap(tree: SceneTree, check: Callable, dash_available: bool) -> void:
	var player: PlayerController = await _begin(tree)
	var entered: int = await _fly_in(tree, player, dash_available)
	var state: LoaderState = player.loader_state()
	var stored: float = state.stored_velocity.length()
	if not await _check_catch(tree, check, player, entered, "tap"):
		await _end(tree, check, "tap")
		return
	while state.update_count < 5 and _is_loader(player):
		await tree.physics_frame
	Input.action_press(&"loader")
	Input.action_release(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return not _released.is_empty(), 4)
	# The tap is injected inside a physics frame (after physics_frame, before the player's update): is_action_pressed changes at once,
	# just_pressed / just_released only on the next frame, so the harness sees the tap on update 7. Real input events arrive between
	# frames and are seen on the next update. Either way it fires right away, long before the cap.
	var fired: int = int(_released[0]["update_count"]) if not _released.is_empty() else -1
	check.call(_released.size() == 1 and fired >= 6 and fired <= 7, "(tap) a same-tick tap after update 5 fires at once (update %d, %s)" % [fired, _released])
	_check_discharge(check, player, stored, dash_available, "tap")
	await _end(tree, check, "tap")


# T-05.1-04: a player already in an arm Loader hold is not caught again; the hold stays ARM.
func _scenario_arm_hold_not_caught(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var arm: int = _profile_source("ARM")
	player.teleport(CENTRE + Vector3(0.0, 0.0, 12.0))
	await Fixtures.wait_until(tree, func() -> bool: return not player.is_grounded() and player.vertical_speed < -1.0, 60)
	Input.action_press(&"loader")
	var entered: int = await Fixtures.wait_until(tree, func() -> bool: return _is_loader(player), 4)
	check.call(entered >= 0 and _source_of(player) == arm, "(arm) the airborne press starts an ARM Loader (source %d)" % _source_of(player))
	_cage.global_position = player.global_position + Vector3.UP
	await Fixtures.wait_physics(tree, 6)
	check.call(_is_loader(player) and _source_of(player) == arm and player.get(&"loader_profile") == null, "(arm) the cage around an arm hold does not catch it (source %d)" % _source_of(player))
	Input.action_release(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return not _released.is_empty(), 4)
	check.call(_released.size() == 1 and _released[0]["bonus"] == true, "(arm) the arm release keeps its own rules (bonus paid, %s)" % [_released])
	await _end(tree, check, "arm")


# T-05.1-04: after a throw the cage stays disarmed for rearm_time and while the player is inside; then it catches again.
func _scenario_rearm(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var entered: int = await _fly_in(tree, player, true)
	if not await _check_catch(tree, check, player, entered, "rearm"):
		await _end(tree, check, "rearm")
		return
	await Fixtures.tap_action(tree, &"loader", 1)
	await Fixtures.wait_until(tree, func() -> bool: return not _is_loader(player), 4)
	check.call(not _is_loader(player), "(rearm) the tap throws the player out")
	await Fixtures.wait_physics(tree, 3)
	player.teleport(CENTRE + START_OFFSET)
	player.launch_along(Vector3.RIGHT, ENTRY_SPEED, false)
	var again: bool = false
	for i: int in 30:
		await tree.physics_frame
		if _is_loader(player):
			again = true
	check.call(not again, "(rearm) no second catch within rearm_time after the throw")
	player.teleport(FAR)
	var config: Resource = _cage.get("config") as Resource
	var rearm: float = float(config.get("rearm_time")) if config != null else 1.0
	await Fixtures.wait_physics(tree, ceili(rearm * SHIPPED_TPS) + 10)
	var caught: int = await _fly_in(tree, player, true)
	check.call(caught >= 0, "(rearm) after rearm_time outside the radius the cage catches again (%d)" % caught)
	await _end(tree, check, "rearm")


## LoaderPreview.BRASS_COLOR by reflection, or an impossible colour while it does not exist.
func _brass() -> Color:
	var script: GDScript = load(PREVIEW_SCRIPT) as GDScript
	return script.get_script_constant_map().get("BRASS_COLOR", Color(-1.0, -1.0, -1.0, -1.0)) as Color


# Plan 05.1-05 (D-01, D-26, ROADMAP criterion 3): the cage reads steampunk at every cue. The catch shows the SteamPuff mesh; the hold
# draws ONE brass arc (no turquoise bonus arc even with a full core); the throw shows the SteamBlast column on the release tick, gone
# again within 0.3 s of real time. Both cue meshes are hidden before the catch.
func _scenario_presentation(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = await _begin(tree)
	var puff: Node3D = _cage.find_child("SteamPuff", true, false) as Node3D
	var blast: Node3D = _cage.find_child("SteamBlast", true, false) as Node3D
	check.call(puff != null and blast != null, "(cues) the cage scene has a SteamPuff and a SteamBlast mesh")
	if puff == null or blast == null:
		await _end(tree, check, "cues")
		return
	check.call(not puff.visible and not blast.visible, "(cues) both cue meshes are hidden before the catch")
	var blast_on_release: Array[bool] = []
	var on_release_deferred: Callable = func(_p: Vector3, _d: Vector3, _s: float, _b: bool) -> void: blast_on_release.append(blast.visible)
	_bus.connect(&"loader_released", on_release_deferred, CONNECT_DEFERRED)
	var entered: int = await _fly_in(tree, player, true)
	if not await _check_catch(tree, check, player, entered, "cues"):
		_bus.disconnect(&"loader_released", on_release_deferred)
		await _end(tree, check, "cues")
		return
	check.call(puff.visible, "(cues) the catch shows the SteamPuff")
	await Fixtures.wait_process(tree, 3)
	var preview: LoaderPreview = player.get_node("LoaderPreview") as LoaderPreview
	check.call(preview.visible, "(cues) the trajectory preview shows during the cage hold")
	var arcs: Variant = preview.get(&"arcs_drawn")
	check.call(arcs != null and int(arcs) == 1, "(cues) the cage preview draws one arc, no bonus arc with a full core (got %s)" % arcs)
	var brass: Color = _brass()
	var tints: Array = preview.get(&"arc_tints") as Array if preview.get(&"arc_tints") != null else []
	check.call(tints.size() == 1 and (tints[0] as Color).is_equal_approx(brass), "(cues) the cage arc is brass (tints %s, %d dashes)" % [tints, preview.multimesh.visible_instance_count])
	check.call(not tints.has(LoaderPreview.BONUS_COLOR), "(cues) no arc is turquoise")
	await Fixtures.tap_action(tree, &"loader", 1)
	await Fixtures.wait_until(tree, func() -> bool: return not _released.is_empty(), 4)
	await tree.process_frame
	check.call(blast_on_release.size() == 1 and blast_on_release[0], "(cues) the SteamBlast shows on the release tick (%s)" % [blast_on_release])
	await tree.create_timer(BLAST_HIDE_SECONDS, true, false, true).timeout
	check.call(not blast.visible, "(cues) the SteamBlast is hidden again within %.1f s of real time" % BLAST_HIDE_SECONDS)
	check.call(not puff.visible, "(cues) the SteamPuff is hidden again")
	_bus.disconnect(&"loader_released", on_release_deferred)
	await _end(tree, check, "cues")
