extends RefCounted
## D-06 audit: every mechanism that moves the player does so, measurably, and only through the PlayerController request API.
## One scenario per existing mover (lift, nozzle JUMP, UPDRAFT and WALL, pendulum), each with a real player on real geometry.
## The rotating platform carry has its own test (test_mechanism_carry); the belt carry is test_conveyor_pendulum. Later plans add
## their movers to this file. The source guard keeps mechanism scripts from writing the player's velocity fields at all.

const Fixtures := preload("res://tests/fixtures.gd")

const LIFT_SCENE: String = "res://scenes/mechanisms/lift_platform.tscn"
const NOZZLE_SCENE: String = "res://scenes/mechanisms/steam_nozzle.tscn"
const PENDULUM_SCENE: String = "res://scenes/mechanisms/pendulum.tscn"
const MECHANISM_DIR: String = "res://scripts/mechanisms"
const SHIPPED_TPS: int = 60

## A member access that writes one of the player's motion, timer, capture or wall fields: a dot, the field name as a whole word, an
## optional component (.x/.y/.z), an optional operator character and an equals sign that is not part of ==.
## constant_linear_velocity does not match (the dot must precede the name).
const WRITE_PATTERN: String = "\\.\\s*(move_velocity|vertical_speed|velocity|gravity_scale|air_dash_available|dash_cooldown_timer|air_speed_cap|coyote_timer|jump_buffer_timer|air_control_lock_timer|capture_\\w+|wall_\\w+)\\b(\\.[xyz])?\\s*[-+*/]?=(?!=)"
## A player reference (player, _captured, body) whose position or transform is written, or any FSM transition call (WR-07).
const MOVE_PATTERN: String = "(\\b(player|_captured|body)\\s*\\.\\s*(global_)?(position|transform)\\b(\\.[a-z]+)?\\s*[-+*/]?=(?!=))|transition_to\\("
## The same fields written through set / set_deferred with the name as a string.
const SET_PATTERN: String = "\\.\\s*set(_deferred)?\\(\\s*[&]?[\"'](move_velocity|vertical_speed|velocity|gravity_scale|air_dash_available|dash_cooldown_timer|air_speed_cap|coyote_timer|jump_buffer_timer|air_control_lock_timer|capture_\\w+|wall_\\w+)[\"']"

var _knock_speeds: Array[float] = []
var _knocked_player: PlayerController = null


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	EventBus.knocked_back.connect(_on_knocked)
	await _scenario_lift(tree, check)
	await _scenario_nozzle_jump(tree, check)
	await _scenario_nozzle_updraft(tree, check)
	await _scenario_nozzle_wall(tree, check)
	await _scenario_pendulum(tree, check)
	EventBus.knocked_back.disconnect(_on_knocked)
	_source_guard(check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _on_knocked(_position: Vector3, _impulse: Vector3) -> void:
	if _knocked_player != null:
		_knock_speeds.append(_knocked_player.horizontal_speed())


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _spawn(path: String, check: Callable) -> Node3D:
	if not ResourceLoader.exists(path):
		check.call(false, "scene %s exists" % path)
		return null
	return (load(path) as PackedScene).instantiate() as Node3D


func _nozzle(check: Callable, mode: SteamNozzle.Mode, source: SignalSource) -> SteamNozzle:
	var nozzle: SteamNozzle = _spawn(NOZZLE_SCENE, check) as SteamNozzle
	if nozzle != null:
		nozzle.mode = mode
		nozzle.source = source
	return nozzle


# Lift: a rider is carried up at least 3 m.
func _scenario_lift(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	var lift: LiftPlatform = _spawn(LIFT_SCENE, check) as LiftPlatform
	if lift == null:
		await _free(tree, [source])
		return
	lift.source = source
	tree.root.add_child(lift)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 20)
	var start_y: float = player.global_position.y
	source.set_active(true)
	await Fixtures.wait_physics(tree, 4 * SHIPPED_TPS)
	var rise: float = player.global_position.y - start_y
	check.call(rise >= 3.0, "lift: the rider rises %.2f m (at least 3)" % rise)
	await _free(tree, [lift, player, source])


# Nozzle JUMP: the launch lifts the player above 2 m.
func _scenario_nozzle_jump(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	source.set_active(true)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var nozzle: SteamNozzle = _nozzle(check, SteamNozzle.Mode.JUMP, source)
	if nozzle == null:
		await _free(tree, [source, floor_body])
		return
	tree.root.add_child(nozzle)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	var apex: float = 0.0
	for i: int in 90:
		await Fixtures.wait_physics(tree, 1)
		apex = maxf(apex, player.global_position.y)
	check.call(apex > 2.0, "nozzle JUMP: the apex is %.2f m (above 2)" % apex)
	await _free(tree, [nozzle, player, floor_body, source])


# Nozzle UPDRAFT: the column holds the player up, a rise of at least 1.5 m.
func _scenario_nozzle_updraft(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	source.set_active(true)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var nozzle: SteamNozzle = _nozzle(check, SteamNozzle.Mode.UPDRAFT, source)
	if nozzle == null:
		await _free(tree, [source, floor_body])
		return
	tree.root.add_child(nozzle)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	var peak: float = 0.0
	for i: int in 60:
		await Fixtures.wait_physics(tree, 1)
		peak = maxf(peak, player.global_position.y)
	check.call(peak >= 1.5, "nozzle UPDRAFT: the player rises %.2f m (at least 1.5)" % peak)
	await _free(tree, [nozzle, player, floor_body, source])


# Nozzle WALL: the player is pushed at least 1 m along the nozzle direction (+X for a yaw of -90 degrees).
func _scenario_nozzle_wall(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	source.set_active(true)
	var nozzle: SteamNozzle = _nozzle(check, SteamNozzle.Mode.WALL, source)
	if nozzle == null:
		await _free(tree, [source])
		return
	nozzle.rotation.y = -PI * 0.5
	tree.root.add_child(nozzle)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 1.5, 0.0))
	var start_x: float = player.global_position.x
	await Fixtures.wait_physics(tree, 20)
	var pushed: float = player.global_position.x - start_x
	check.call(pushed >= 1.0, "nozzle WALL: the player is pushed %.2f m along the nozzle direction (at least 1)" % pushed)
	await _free(tree, [nozzle, player, source])


# Pendulum: at the first knock the horizontal speed is above 3 m/s.
func _scenario_pendulum(tree: SceneTree, check: Callable) -> void:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	source.set_active(true)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var pendulum: Pendulum = _spawn(PENDULUM_SCENE, check) as Pendulum
	if pendulum == null:
		await _free(tree, [source, floor_body])
		return
	pendulum.source = source
	tree.root.add_child(pendulum)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(2.5, 0.0, 0.0))
	_knock_speeds.clear()
	_knocked_player = player
	await Fixtures.wait_until(tree, func() -> bool: return _knock_speeds.size() >= 1, 2 * SHIPPED_TPS)
	_knocked_player = null
	var speed: float = _knock_speeds[0] if _knock_speeds.size() > 0 else 0.0
	check.call(speed > 3.0, "pendulum: the first knock gives %.2f m/s horizontal (above 3)" % speed)
	await _free(tree, [pendulum, player, floor_body, source])


## Lists the .gd files under `path`, recursing into sub folders.
func _script_files(path: String) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return found
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			found.append("%s/%s" % [path, file_name])
	for sub: String in dir.get_directories():
		found.append_array(_script_files("%s/%s" % [path, sub]))
	return found


## The 1-based line numbers of `source` that write a player motion field or call move_and_slide, comments excluded.
func _offending_lines(source: String, write: RegEx, setter: RegEx, mover: RegEx) -> Array[int]:
	var hits: Array[int] = []
	var lines: PackedStringArray = source.split("\n")
	for index: int in lines.size():
		var code: String = lines[index]
		var comment_at: int = code.find("#")
		if comment_at >= 0:
			code = code.substr(0, comment_at)
		if code.strip_edges() == "":
			continue
		if write.search(code) != null or setter.search(code) != null or mover.search(code) != null or code.contains("move_and_slide("):
			hits.append(index + 1)
	return hits


# D-06 source guard: no mechanism script writes the player's velocity fields or moves a body itself.
func _source_guard(check: Callable) -> void:
	var write: RegEx = RegEx.new()
	var setter: RegEx = RegEx.new()
	var mover: RegEx = RegEx.new()
	check.call(write.compile(WRITE_PATTERN) == OK and setter.compile(SET_PATTERN) == OK and mover.compile(MOVE_PATTERN) == OK, "the source guard patterns compile")
	var synthetic: String = "player.move_velocity = Vector3.ZERO\nplayer.vertical_speed += 1.0\nbody.set(\"velocity\", v)\nx.move_and_slide()\nplayer.move_velocity.y = 5.0\nplayer.move_velocity.x += 1.0\nplayer.coyote_timer = 0.0\n_captured.wall_run_cooldown_timer = 1.0\nplayer.global_position = p\nplayer.state_machine.transition_to(&\"Fall\")\n"
	var clean: String = "# player.velocity = 1\nif player.move_velocity == v:\n\tbelt.constant_linear_velocity = v\n\tplayer.push_toward(d, 1.0, 1.0) # not player.velocity = 2\n_head.global_position = p\n_mesh.position = p\nif player.move_velocity.y == 0.0:\n"
	check.call(_offending_lines(synthetic, write, setter, mover).size() == 10, "the guard flags writes (also per component), timer, capture and wall fields, set(), position writes, FSM transitions and move_and_slide in a synthetic offending string")
	check.call(_offending_lines(clean, write, setter, mover).is_empty(), "the guard ignores comments, comparisons, constant_linear_velocity, request calls and a mechanism's own node positions")
	var files: Array[String] = _script_files(MECHANISM_DIR)
	check.call(files.size() >= 10, "the guard sees the mechanism scripts (%d files)" % files.size())
	var report: Array[String] = []
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		for line: int in _offending_lines(text, write, setter, mover):
			report.append("%s:%d" % [path, line])
	check.call(report.is_empty(), "no mechanism script writes the player's velocity fields or calls move_and_slide (%s)" % ", ".join(report))
