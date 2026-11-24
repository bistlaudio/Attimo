extends RefCounted
## Phase 05.1 plan 03 (D-06, KIT-01, KIT-02): the Wall surface block and its looks.
##   Parity: a plain pad and its steam look give the same wall-run / wall-jump exit velocity (within 0.01 m/s) and the same facing
##           (dot > 0.999); the steam look is meshes only and adds no impulse.
##   Head clearance: during a wall run on the plain pad the head bone stays at least 0.45 m from the wall face, the facing runs along
##           the wall (facing . wall_tangent() > 0.99) and the body still tilts toward the wall (Mannequin up . wall normal < 0).
##           The clearance is a pose-only clamp in ProceduralPose; wall_run_lean_deg is unchanged (unattended decision 2).
##   Twin catch: two wall-jump pads JUMP_PAD_HEIGHT_MIN tall with TWIN_FACE_GAP_MIN between their faces; a held kick off the near pad
##           is caught by the far pad and never passes behind its back face (layout fix, wall_jump_* unchanged, unattended decision 3).
## The block class and its constants are read by reflection, so this file compiles before WallSurface exists.

const Fixtures := preload("res://tests/fixtures.gd")

const BLOCK_SCRIPT: String = "res://scripts/kit/blocks/wall_surface.gd"
const RUN_PLAIN: String = "res://scenes/kit/steampunk/wall_pad.tscn"
const RUN_STEAM: String = "res://scenes/kit/steampunk/wall_pad_steam.tscn"
const JUMP_PLAIN: String = "res://scenes/kit/steampunk/wall_jump_pad.tscn"
const JUMP_STEAM: String = "res://scenes/kit/steampunk/wall_jump_pad_steam.tscn"
const JUMP_PRESET: String = "res://resources/kit/wall_surface/wall_jump.tres"
const SHIPPED_TPS: int = 60
## Player start 1.5 m in front of the pad face (face at z = 0.25, capsule radius 0.5), as in test_wall_states.
const START_Z: float = 2.25
## Exit velocities of a plain and a steam-look pad may differ by at most this much (m/s).
const PARITY_SPEED: float = 0.01
## Facing of a plain and a steam-look pad: dot at least this.
const PARITY_FACING: float = 0.999
## D-06: the head bone keeps at least this distance (m) from the wall face during a run.
const HEAD_CLEARANCE: float = 0.45
## D-06: the facing runs along the wall.
const TANGENT_DOT: float = 0.99
## Ticks after the WallRun entry before the lean counts as settled (lean_in_time is 0.12 s at the shipped config).
const LEAN_SETTLE_TICKS: int = 12
## Feet heights of the twin kicks in m: 3.4 is the research fling reproduction (kicked at 3.37 m on the old 4 m pads, it cleared
## the far pad); 4.4 is a kick one metre higher, still reachable with a chained jump. A kick near the top of an 8 m pad would clear
## any pad by geometry alone (the kick rises about 2.1 m while it crosses the gap), so the test takes the realistic kick heights.
const KICK_HEIGHTS: Array[float] = [3.4, 4.4]


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	var constants: Dictionary = {}
	check.call(ResourceLoader.exists(BLOCK_SCRIPT), "the WallSurface block script %s exists" % BLOCK_SCRIPT)
	if ResourceLoader.exists(BLOCK_SCRIPT):
		var script: GDScript = load(BLOCK_SCRIPT) as GDScript
		check.call(String(script.get_global_name()) == "WallSurface", "wall_surface.gd declares class_name WallSurface")
		constants = script.get_script_constant_map()
	for path: String in [RUN_PLAIN, RUN_STEAM, JUMP_PLAIN, JUMP_STEAM]:
		check.call(ResourceLoader.exists(path), "the wall surface look %s exists" % path)
	if ResourceLoader.exists(RUN_PLAIN) and ResourceLoader.exists(RUN_STEAM):
		await _scenario_run_parity(tree, check)
		await _scenario_head_clearance(tree, check)
	if ResourceLoader.exists(JUMP_PLAIN) and ResourceLoader.exists(JUMP_STEAM):
		await _scenario_jump_parity(tree, check)
	var has_constants: bool = constants.has("TWIN_FACE_GAP_MIN") and constants.has("JUMP_PAD_HEIGHT_MIN")
	check.call(has_constants, "WallSurface has the layout constants TWIN_FACE_GAP_MIN and JUMP_PAD_HEIGHT_MIN")
	if has_constants and ResourceLoader.exists(JUMP_PLAIN):
		var gap: float = float(constants["TWIN_FACE_GAP_MIN"])
		var height: float = float(constants["JUMP_PAD_HEIGHT_MIN"])
		check.call(ResourceLoader.exists(JUMP_PRESET) and float((load(JUMP_PRESET) as Resource).get("height")) >= height, "the wall-jump preset is at least JUMP_PAD_HEIGHT_MIN (%.1f m) tall" % height)
		for kick_y: float in KICK_HEIGHTS:
			await _scenario_twin_catch(tree, check, gap, height, kick_y)
	Input.action_release(&"jump")
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _free(tree: SceneTree, nodes: Array) -> void:
	Input.action_release(&"jump")
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _spawn_pad(tree: SceneTree, path: String, position: Vector3) -> Node3D:
	return Fixtures.spawn_scene(tree.root, path, position)


## The panel body of a wall surface instance.
func _panel(pad: Node3D) -> StaticBody3D:
	return pad.get_node("Panel") as StaticBody3D


## Half the panel thickness (the face sits this far from the pad origin along z).
func _half_thickness(pad: Node3D) -> float:
	var shape: CollisionShape3D = pad.get_node("Panel/CollisionShape3D") as CollisionShape3D
	var box: BoxShape3D = shape.shape as BoxShape3D
	return box.size.z * 0.5 if box != null else 0.25


func _velocity(player: PlayerController) -> Vector3:
	return Vector3(player.move_velocity.x, player.vertical_speed, player.move_velocity.z)


func _facing(player: PlayerController) -> Vector3:
	var facing: Vector3 = player.visual_root.global_basis.z
	facing.y = 0.0
	return facing.normalized()


## One wall-run on the pad scene `path` and a jump off it. Returns {ok, facing (during the run), exit (first WallJump tick)}.
func _run_and_kick(tree: SceneTree, path: String) -> Dictionary:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var pad: Node3D = _spawn_pad(tree, path, Vector3.ZERO)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(-7.0, 2.0, START_Z))
	await Fixtures.wait_physics(tree, 3)
	Fixtures.set_energy(player, 40.0)
	player.launch_along(Vector3(0.6, 0.2, -0.8), 10.0, false)
	var result: Dictionary = {"ok": false, "facing": Vector3.ZERO, "exit": Vector3.ZERO}
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallRun", 20)
	if waited >= 0:
		await Fixtures.wait_physics(tree, 6)
		result["facing"] = _facing(player)
		Input.action_press(&"jump")
		var kicked: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallJump", 6)
		if kicked >= 0:
			result["ok"] = true
			result["exit"] = _velocity(player)
	await _free(tree, [floor_body, pad, player])
	return result


## Touches the wall-jump pad scene `path` in the air and kicks off. Returns {ok, facing, exit} at the first WallJump tick.
func _touch_and_kick(tree: SceneTree, path: String) -> Dictionary:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var pad: Node3D = _spawn_pad(tree, path, Vector3.ZERO)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(-2.0, 2.0, START_Z))
	await Fixtures.wait_physics(tree, 3)
	player.launch_along(Vector3(0.2, 0.2, -0.8), 6.0, false)
	var result: Dictionary = {"ok": false, "facing": Vector3.ZERO, "exit": Vector3.ZERO}
	var touched: int = await Fixtures.wait_until(tree, func() -> bool: return player.wall_contact_age == 0.0, 40)
	if touched >= 0:
		Input.action_press(&"jump")
		var kicked: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallJump", 6)
		if kicked >= 0:
			result["ok"] = true
			result["exit"] = _velocity(player)
			result["facing"] = _facing(player)
	await _free(tree, [floor_body, pad, player])
	return result


func _compare(check: Callable, label: String, plain: Dictionary, steam: Dictionary) -> void:
	check.call(bool(plain["ok"]) and bool(steam["ok"]), "%s: both the plain and the steam pad give a wall jump (%s, %s)" % [label, plain["ok"], steam["ok"]])
	if not bool(plain["ok"]) or not bool(steam["ok"]):
		return
	var exit_a: Vector3 = plain["exit"] as Vector3
	var exit_b: Vector3 = steam["exit"] as Vector3
	check.call(exit_a.distance_to(exit_b) < PARITY_SPEED, "%s: same exit velocity within 0.01 m/s (plain %s, steam %s)" % [label, exit_a, exit_b])
	var facing_dot: float = (plain["facing"] as Vector3).dot(steam["facing"] as Vector3)
	check.call(facing_dot > PARITY_FACING, "%s: same facing (dot %.5f > 0.999)" % [label, facing_dot])


func _scenario_run_parity(tree: SceneTree, check: Callable) -> void:
	var plain: Dictionary = await _run_and_kick(tree, RUN_PLAIN)
	var steam: Dictionary = await _run_and_kick(tree, RUN_STEAM)
	_compare(check, "wall-run pad", plain, steam)


func _scenario_jump_parity(tree: SceneTree, check: Callable) -> void:
	var plain: Dictionary = await _touch_and_kick(tree, JUMP_PLAIN)
	var steam: Dictionary = await _touch_and_kick(tree, JUMP_STEAM)
	_compare(check, "wall-jump pad", plain, steam)


## Every tick of a run on the plain pad after the lean settled: head clearance, facing along the wall and a lean toward the wall.
func _scenario_head_clearance(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var pad: Node3D = _spawn_pad(tree, RUN_PLAIN, Vector3.ZERO)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(-7.0, 2.0, START_Z))
	var mannequin: Node3D = player.get_node("VisualRoot/Mannequin") as Node3D
	await Fixtures.wait_physics(tree, 3)
	Fixtures.set_energy(player, 40.0)
	player.launch_along(Vector3(0.6, 0.2, -0.8), 10.0, false)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallRun", 20)
	check.call(waited >= 0, "head clearance: the run on the plain pad starts (%d)" % waited)
	if waited < 0:
		await _free(tree, [floor_body, pad, player])
		return
	await Fixtures.wait_physics(tree, LEAN_SETTLE_TICKS)
	var normal: Vector3 = player.wall_normal
	var face_point: Vector3 = pad.global_position + normal * _half_thickness(pad)
	var min_distance: float = INF
	var min_tangent: float = INF
	var max_up_dot: float = -INF
	var ticks: int = 0
	var finite: bool = true
	while player.state_machine.current.name == &"WallRun" and ticks < 120:
		var distance: float = Fixtures.head_to_wall_distance(player, face_point, normal)
		if not is_finite(distance):
			finite = false
		else:
			min_distance = minf(min_distance, distance)
		min_tangent = minf(min_tangent, _facing(player).dot(player.wall_tangent()))
		max_up_dot = maxf(max_up_dot, mannequin.global_basis.y.normalized().dot(normal))
		ticks += 1
		await tree.physics_frame
	check.call(ticks >= 20, "head clearance: at least 20 settled run ticks measured (%d)" % ticks)
	check.call(finite, "head clearance: the head bone is found on every tick")
	check.call(min_distance >= HEAD_CLEARANCE, "the head bone stays at least 0.45 m from the wall face (closest %.3f m)" % min_distance)
	check.call(min_tangent > TANGENT_DOT, "the facing runs along the wall (facing . wall_tangent() at least %.4f > 0.99)" % min_tangent)
	var pose: Node = player.get_node("ProceduralPose")
	var limit: float = float(pose.call(&"wall_run_lean_limit_deg", player.config)) if pose.has_method(&"wall_run_lean_limit_deg") else NAN
	check.call(max_up_dot < 0.0, "the body still leans toward the wall (Mannequin up . wall normal at most %.4f < 0, lean %.2f deg, wall_run_lean_deg %.1f)" % [max_up_dot, limit, player.config.wall_run_lean_deg])
	await _free(tree, [floor_body, pad, player])


## A held kick at `kick_y` off the near pad of a twin with `gap` between the faces and `height` tall pads: the far pad catches it.
func _scenario_twin_catch(tree: SceneTree, check: Callable, gap: float, height: float, kick_y: float) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var near: Node3D = _spawn_pad(tree, JUMP_PLAIN, Vector3.ZERO)
	var half: float = _half_thickness(near)
	# The far pad turns its face toward the near one (yaw 180 keeps the panel symmetric anyway).
	var far: Node3D = _spawn_pad(tree, JUMP_PLAIN, Vector3(0.0, 0.0, gap + 2.0 * half))
	far.rotation.y = PI
	var far_panel: StaticBody3D = _panel(far)
	var far_face_z: float = gap + half
	var far_back_z: float = gap + 3.0 * half
	var tall: float = (near.get_node("Panel/CollisionShape3D") as CollisionShape3D).global_position.y * 2.0
	check.call(tall >= height - 0.01, "twin at %.1f m: the wall-jump pad is at least JUMP_PAD_HEIGHT_MIN %.1f m tall (%.2f)" % [kick_y, height, tall])
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, kick_y + 0.3, half + 1.2))
	await Fixtures.wait_physics(tree, 2)
	player.launch_along(Vector3(0.0, 0.25, -1.0).normalized(), 4.0, false)
	var kicks: Array[float] = []
	var on_jumped: Callable = func(position: Vector3, _direction: Vector3) -> void: kicks.append(position.y)
	EventBus.wall_jumped.connect(on_jumped)
	var touched: int = await Fixtures.wait_until(tree, func() -> bool: return player.wall_contact_age == 0.0 and player.wall_collider == _panel(near), 40)
	check.call(touched >= 0, "twin at %.1f m: the player touches the near pad" % kick_y)
	Input.action_press(&"jump")
	var kicked: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"WallJump", 6)
	check.call(kicked >= 0, "twin at %.1f m: a held jump kicks off the near pad (kick feet at %.2f m)" % [kick_y, kicks[0] if kicks.size() > 0 else NAN])
	var caught: bool = false
	var max_z: float = player.global_position.z
	for i: int in 90:
		await tree.physics_frame
		max_z = maxf(max_z, player.global_position.z)
		if player.wall_collider == far_panel and player.wall_contact_age <= player.config.wall_contact_grace:
			caught = true
		if player.is_grounded():
			break
	EventBus.wall_jumped.disconnect(on_jumped)
	check.call(caught, "twin at %.1f m: the far pad (face %.2f m away) catches the held kick" % [kick_y, far_face_z - half])
	check.call(max_z < far_back_z, "twin at %.1f m: the player never passes behind the far pad's back face (max z %.2f, back %.2f)" % [kick_y, max_z, far_back_z])
	await _free(tree, [floor_body, near, far, player])
