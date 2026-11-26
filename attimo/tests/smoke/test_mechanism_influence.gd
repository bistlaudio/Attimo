extends RefCounted
## D-06 audit: every mechanism that moves the player does so, measurably, and only through the PlayerController request API.
## No mover scenario is left here (the pendulum and piston wall are Timed motion SWING and STAMP with DamagePush since plan 05.1-20, covered by test_damage_push; the nozzle updraft is the Force volume block since plan 05.1-15, covered by test_force_volume; the nozzle launch and push-back modes were cut in plan 05.1-03, the lift
## in plan 05.1-06), each with a real player on real geometry.
## The rotating platform carry has its own test (test_mechanism_carry); the belt was replaced by the speed pad (test_impulse). Later plans add
## their movers to this file. The source guard keeps mechanism scripts from writing the player's velocity fields at all.

const Fixtures := preload("res://tests/fixtures.gd")

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


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	_source_guard(check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


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
	# 5 files since plan 05.1-20 deleted the old pendulum and piston wall scripts (7 before, 10 before plan 05.1-18).
	check.call(files.size() >= 4, "the guard sees the mechanism scripts (%d files)" % files.size())
	var report: Array[String] = []
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		for line: int in _offending_lines(text, write, setter, mover):
			report.append("%s:%d" % [path, line])
	# Plan 05.1-20 (D-17): the DamagePush component only asks for a knock-back, it never writes the player's motion.
	var push_text: String = FileAccess.get_file_as_string("res://scripts/kit/components/damage_push.gd")
	check.call(push_text != "" and _offending_lines(push_text, write, setter, mover).is_empty(), "damage_push.gd never writes the player's velocity fields or calls move_and_slide")
	check.call(report.is_empty(), "no mechanism script writes the player's velocity fields or calls move_and_slide (%s)" % ", ".join(report))
