extends RefCounted
## MOVE-12 (D-09): wall-run and wall-jump on pads only. A WallRun starts in the air against a pad in group wall_run_surface with at
## least wall_run_min_speed of horizontal speed, runs along the pad with scaled gravity for wall_run_time, ends at the pad's end,
## and cannot restart for wall_run_cooldown. A plain wall never starts it. Task 2 adds the WallJump scenarios to this file.

const Fixtures := preload("res://tests/fixtures.gd")

const PAD_SCENE: String = "res://scenes/mechanisms/wall_pad.tscn"
const SHIPPED_TPS: int = 60
## Player start 1.5 m in front of the pad face (face at z = 0.25, capsule radius 0.5).
const START_Z: float = 2.25


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_run_basics(tree, check)
	await _scenario_run_end_and_cooldown(tree, check)
	await _scenario_rejections(tree, check)
	await _scenario_dash_and_landing(tree, check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


## A floor, an active pad (mode 0 = WALL_RUN, 1 = WALL_JUMP) and a player in the air at (x, 2, START_Z). Returns [floor, source, pad, player].
func _setup(tree: SceneTree, mode: int, x: float) -> Array:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var pad: WallPad = (load(PAD_SCENE) as PackedScene).instantiate() as WallPad
	pad.mode = mode as WallPad.Mode
	pad.source = source
	tree.root.add_child(pad)
	source.set_active(true)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(x, 2.0, START_Z))
	await Fixtures.wait_physics(tree, 3)
	return [floor_body, source, pad, player]


func _launch_at_pad(player: PlayerController, speed: float) -> void:
	player.launch_along(Vector3(0.6, 0.2, -0.8), speed, false)


## True when the player is in state `state_name` on any tick of the next `ticks` ticks.
func _ever_in(tree: SceneTree, player: PlayerController, state_name: StringName, ticks: int) -> bool:
	for i: int in ticks:
		await tree.physics_frame
		if player.state_machine.current.name == state_name:
			return true
	return false


func _scenario_run_basics(tree: SceneTree, check: Callable) -> void:
	var started: Array[int] = [0]
	var on_started: Callable = func(_p: Vector3, _n: Vector3) -> void: started[0] += 1
	EventBus.wall_run_started.connect(on_started)
	var parts: Array = await _setup(tree, 0, -7.0)
	var pad: WallPad = parts[2] as WallPad
	var player: PlayerController = parts[3] as PlayerController
	var panel: Node = pad.get_node("Panel")
	check.call(panel.is_in_group(&"wall_run_surface") and not panel.is_in_group(&"wall_jump_surface"), "an active WALL_RUN pad puts its panel in group wall_run_surface only")
	_launch_at_pad(player, 10.0)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallRun", 20)
	check.call(waited >= 0, "a 10 m/s approach at an active wall-run pad enters WallRun within 20 ticks (%d)" % waited)
	var start_x: float = player.global_position.x
	var start_vy: float = player.vertical_speed
	check.call(player.gravity_scale == player.config.wall_run_gravity_scale, "during WallRun gravity_scale is wall_run_gravity_scale (%.2f)" % player.gravity_scale)
	await Fixtures.wait_physics(tree, 30)
	check.call(player.state_machine.current.name == &"WallRun", "still in WallRun after 0.5 s (%s)" % player.state_machine.current.name)
	check.call(absf(player.vertical_speed - start_vy) < 3.0, "vertical speed changed %.2f m/s in 0.5 s (gravity scaled, under 3)" % (player.vertical_speed - start_vy))
	waited = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name != &"WallRun", 80)
	check.call(waited >= 0 and player.state_machine.current.name == &"Fall", "WallRun hands over to Fall at wall_run_time (%s)" % player.state_machine.current.name)
	var travelled: float = player.global_position.x - start_x
	check.call(travelled >= 8.0, "the player ran %.2f m along the pad (at least 8)" % travelled)
	check.call(player.gravity_scale == 1.0, "gravity_scale is 1.0 after the exit (%.2f)" % player.gravity_scale)
	check.call(started[0] == 1, "wall_run_started fired once per run (%d)" % started[0])
	EventBus.wall_run_started.disconnect(on_started)
	await _free(tree, parts)


func _scenario_run_end_and_cooldown(tree: SceneTree, check: Callable) -> void:
	var parts: Array = await _setup(tree, 0, -1.0)
	var player: PlayerController = parts[3] as PlayerController
	_launch_at_pad(player, 10.0)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallRun", 20)
	check.call(waited >= 0, "run-end scenario: WallRun starts (%d)" % waited)
	var ticks_in_run: int = 0
	while player.state_machine.current.name == &"WallRun" and ticks_in_run < 120:
		await tree.physics_frame
		ticks_in_run += 1
	var run_time: float = float(ticks_in_run) / SHIPPED_TPS
	check.call(player.state_machine.current.name == &"Fall" and run_time < player.config.wall_run_time - 0.1, "at the pad's end the run drops to Fall after %.2f s (before wall_run_time %.2f)" % [run_time, player.config.wall_run_time])
	check.call(player.wall_run_cooldown_timer > 0.0, "the cooldown runs after the exit (%.2f s)" % player.wall_run_cooldown_timer)
	check.call(not player.can_wall_run(), "can_wall_run is false during the cooldown")
	var again: bool = await _ever_in(tree, player, &"WallRun", 15)
	check.call(not again, "the same pad is not re-entered within the cooldown")
	await _free(tree, parts)


func _scenario_rejections(tree: SceneTree, check: Callable) -> void:
	var parts: Array = await _setup(tree, 0, -7.0)
	var player: PlayerController = parts[3] as PlayerController
	_launch_at_pad(player, 4.0)
	var entered: bool = await _ever_in(tree, player, &"WallRun", 40)
	check.call(not entered, "a 4 m/s approach does not start WallRun (below wall_run_min_speed)")
	await _free(tree, parts)

	# A plain wall without the group.
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var wall: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(12.0, 4.0, 0.5), Vector3(0.0, 2.0, 0.0))
	var plain_player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(-7.0, 2.0, START_Z))
	await Fixtures.wait_physics(tree, 3)
	_launch_at_pad(plain_player, 10.0)
	var plain_entered: bool = await _ever_in(tree, plain_player, &"WallRun", 40)
	check.call(not plain_entered, "a plain wall without a pad group never starts WallRun")
	check.call(plain_player.wall_contact_age < 1.0 or plain_player.wall_collider == wall, "the plain wall was touched (bookkeeping sees it)")
	await _free(tree, [floor_body, wall, plain_player])


func _scenario_dash_and_landing(tree: SceneTree, check: Callable) -> void:
	var parts: Array = await _setup(tree, 0, -7.0)
	var player: PlayerController = parts[3] as PlayerController
	_launch_at_pad(player, 10.0)
	await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallRun", 20)
	await Fixtures.wait_physics(tree, 4)
	await Fixtures.tap_action(tree, &"dash", 3)
	var dashed: bool = player.state_machine.current.name == &"Dash" or await _ever_in(tree, player, &"Dash", 3)
	check.call(dashed, "a dash press during WallRun enters Dash (%s)" % player.state_machine.current.name)
	check.call(player.gravity_scale != player.config.wall_run_gravity_scale or player.gravity_scale == player.config.air_dash_gravity_scale, "the WallRun gravity scale is gone after leaving WallRun")
	await _free(tree, parts)

	# Landing during a run: normal gravity, no entry rise, a low start.
	var parts_b: Array = await _setup(tree, 0, -7.0)
	var low_player: PlayerController = parts_b[3] as PlayerController
	low_player.config = low_player.config.duplicate() as MovementConfig
	low_player.config.wall_run_gravity_scale = 1.0
	low_player.config.wall_run_entry_rise = 0.0
	low_player.config.wall_run_time = 3.0
	low_player.teleport(Vector3(-7.0, 1.8, START_Z))
	await Fixtures.wait_physics(tree, 2)
	low_player.launch_along(Vector3(0.6, 0.0, -0.8), 10.0, false)
	var in_run: int = await Fixtures.wait_until(tree, func() -> bool: return low_player.state_machine.current.name == &"WallRun", 20)
	check.call(in_run >= 0, "landing scenario: WallRun starts low over the floor (%d)" % in_run)
	var landed: int = await Fixtures.wait_until(tree, func() -> bool: return low_player.state_machine.current.name == &"Run" or low_player.state_machine.current.name == &"Idle", 60)
	check.call(landed >= 0 and low_player.is_grounded(), "landing during WallRun goes to Run or Idle (%s)" % low_player.state_machine.current.name)
	await _free(tree, parts_b)
