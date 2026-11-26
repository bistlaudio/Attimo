extends RefCounted
## Plan 05.1-21 (KIT-01, KIT-02, KIT-04, D-09, D-11, D-14, D-15, D-26, D-27): the nature layer on the Reaction to load block. Six objects on
## five appended profiles (CRUMBLE, SINK, TIP, DROP, BITE): crumbling platform (the old numbers), collapse (a 6 segment strip), sinking
## debris, tipping trunk, falling debris and snap bloom. Nature never helps: no step is ever paid to the arm. Falling debris and snap bloom
## push through DamagePush and announce one EventBus.player_hit per contact. Real player, real geometry, 60 Hz. The block and its config are
## reached by path, get() and call(), so this file compiles before the new profiles exist (TDD RED).

const Fixtures := preload("res://tests/fixtures.gd")

const CONFIG_SCRIPT: String = "res://scripts/kit/configs/reaction_to_load_config.gd"
const PLATFORM_SCENE: String = "res://scenes/kit/nature/crumbling_platform.tscn"
const COLLAPSE_SCENE: String = "res://scenes/kit/nature/collapse.tscn"
const SINK_SCENE: String = "res://scenes/kit/nature/sinking_debris.tscn"
const TRUNK_SCENE: String = "res://scenes/kit/nature/tipping_trunk.tscn"
const DEBRIS_SCENE: String = "res://scenes/kit/nature/falling_debris.tscn"
const BLOOM_SCENE: String = "res://scenes/kit/nature/snap_bloom.tscn"
const SCENES: Array[String] = [PLATFORM_SCENE, COLLAPSE_SCENE, SINK_SCENE, TRUNK_SCENE, DEBRIS_SCENE, BLOOM_SCENE]
const PRESET_DIR: String = "res://resources/kit/reaction_to_load/"
const PRESET_PROFILES: Dictionary = {
	"crumbling_platform": "CRUMBLE",
	"collapse": "CRUMBLE",
	"sinking_debris": "SINK",
	"tipping_trunk": "TIP",
	"falling_debris": "DROP",
	"snap_bloom": "BITE",
}
const SHIPPED_TPS: int = 60
## The tuned numbers of the old crumbling platform (D-09): shake 0.6 s, fall 0.5 s, respawn 3.0 s.
const OLD_SHAKE: float = 0.6
const OLD_FALL: float = 0.5
const OLD_RESPAWN: float = 3.0
## CrumblePhase ints of the block: IDLE 0, ARMED 1, SHAKE 2, FALL 3, GONE 4.
const PHASE_IDLE: int = 0
const PHASE_SHAKE: int = 2
const PHASE_GONE: int = 4
const DECK_Y: float = 5.0

var _hits: Array[Dictionary] = []
var _sources: Array[StringName] = []


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	var all_there: bool = ResourceLoader.exists(CONFIG_SCRIPT)
	for path: String in SCENES:
		check.call(ResourceLoader.exists(path), "the nature scene %s exists" % path)
		all_there = all_there and ResourceLoader.exists(path)
	_check_profiles(check)
	_check_presets(check)
	if not all_there:
		return
	EventBus.player_hit.connect(_on_hit)
	EventBus.energy_gained.connect(_on_gained)
	await _scenario_crumble(tree, check)
	await _scenario_collapse(tree, check)
	await _scenario_sink(tree, check)
	await _scenario_tip(tree, check)
	await _scenario_drop(tree, check)
	await _scenario_bite(tree, check)
	EventBus.player_hit.disconnect(_on_hit)
	EventBus.energy_gained.disconnect(_on_gained)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _on_hit(amount: int, position: Vector3, source_id: StringName) -> void:
	_hits.append({"amount": amount, "position": position, "source": source_id})


func _on_gained(_amount: int, source: StringName) -> void:
	_sources.append(source)


func _check_profiles(check: Callable) -> void:
	var script: GDScript = load(CONFIG_SCRIPT) as GDScript
	if script == null:
		check.call(false, "the Reaction to load config script loads")
		return
	var config: Resource = script.new() as Resource
	var names: Array = []
	for prop: Dictionary in config.get_property_list():
		if String(prop["name"]) == "profile":
			names = String(prop["hint_string"]).split(",")
	var keys: Array[String] = []
	for entry: Variant in names:
		keys.append(String(entry).get_slice(":", 0))
	check.call(keys == ["LOADER_FIELD", "CRUMBLE", "SINK", "TIP", "DROP", "BITE"], "Profile is { LOADER_FIELD, CRUMBLE, SINK, TIP, DROP, BITE }, new values appended (%s)" % [keys])


func _check_presets(check: Callable) -> void:
	for preset: String in PRESET_PROFILES:
		var path: String = "%s%s.tres" % [PRESET_DIR, preset]
		check.call(ResourceLoader.exists(path), "preset %s exists" % path)
		if not ResourceLoader.exists(path):
			continue
		var config: Resource = load(path) as Resource
		var value: int = int(config.get("profile"))
		var script: GDScript = config.get_script() as GDScript
		var keys: Array = []
		for constant: Variant in script.get_script_constant_map().get("Profile", {}).keys():
			keys.append(constant)
		check.call(keys.size() == 6 and String(keys[value]) == String(PRESET_PROFILES[preset]), "%s is the %s profile" % [preset, PRESET_PROFILES[preset]])


func _cfg(block: Node, field: String) -> Variant:
	return (block.get("config") as Resource).get(field)


func _free(tree: SceneTree, nodes: Array) -> void:
	for action: StringName in [&"move_forward"]:
		Input.action_release(action)
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _shape_of(block: Node, index: int) -> CollisionShape3D:
	var decks: Array = block.call("decks") as Array
	return (decks[index] as Node).get_node("CollisionShape3D") as CollisionShape3D


func _energy_clean() -> bool:
	for source: StringName in _sources:
		if source != &"passive":
			return false
	return true


func _scenario_crumble(tree: SceneTree, check: Callable) -> void:
	_sources.clear()
	var block: Node3D = Fixtures.spawn_scene(tree.root, PLATFORM_SCENE, Vector3(0.0, DECK_Y, 0.0))
	await Fixtures.wait_physics(tree, 5)
	var shape: CollisionShape3D = _shape_of(block, 0)
	var delay: float = float(_cfg(block, "delay"))
	var fall_time: float = float(_cfg(block, "fall_time"))
	var respawn: float = float(_cfg(block, "respawn_time"))
	check.call(is_equal_approx(delay, OLD_SHAKE) and is_equal_approx(fall_time, OLD_FALL) and is_equal_approx(respawn, OLD_RESPAWN), "crumbling platform keeps the old numbers 0.6 / 0.5 / 3.0 (%.2f %.2f %.2f)" % [delay, fall_time, respawn])
	check.call(int(block.call("crumble_phase", 0)) == PHASE_IDLE and not shape.disabled, "crumble: IDLE with collision on at the start")
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, DECK_Y + 0.5, 0.0))
	Fixtures.set_energy(player, 6)
	await Fixtures.wait_until(tree, func() -> bool: return int(block.call("crumble_phase", 0)) != PHASE_IDLE, 60)
	check.call(int(block.call("crumble_phase", 0)) == PHASE_SHAKE, "crumble: standing on it starts the delay (SHAKE)")
	await Fixtures.wait_physics(tree, 6)
	check.call(not shape.disabled and player.global_position.y > DECK_Y, "crumble: it still carries during the delay (y %.2f)" % player.global_position.y)
	await Fixtures.wait_physics(tree, ceili((delay + fall_time) * SHIPPED_TPS) + 8)
	check.call(shape.disabled and player.global_position.y < DECK_Y - 1.0, "crumble: after delay and fall the collision is gone and the player falls (y %.2f)" % player.global_position.y)
	check.call(int(block.call("crumble_phase", 0)) == PHASE_GONE, "crumble: the platform is gone")
	player.global_position = Vector3(30.0, 0.0, 0.0)
	await Fixtures.wait_physics(tree, ceili(respawn * SHIPPED_TPS) + 20)
	check.call(not shape.disabled and int(block.call("crumble_phase", 0)) == PHASE_IDLE, "crumble: after the respawn time with an empty footprint it is back")
	check.call(_energy_clean(), "crumble: no step was paid to the arm (%s)" % [_sources])
	await _free(tree, [player, block])


func _scenario_collapse(tree: SceneTree, check: Callable) -> void:
	var block: Node3D = Fixtures.spawn_scene(tree.root, COLLAPSE_SCENE, Vector3(0.0, DECK_Y, 0.0))
	var count: int = int(_cfg(block, "segments"))
	check.call(count == 6, "collapse: the strip has 6 segments (%d)" % count)
	var end_ledge: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(6.0, 1.0, 6.0), Vector3(0.0, DECK_Y - 0.5, -2.0 * count - 3.0))
	await Fixtures.wait_physics(tree, 5)
	var seg_delay: float = float(_cfg(block, "segment_delay")) + float(_cfg(block, "delay"))
	var fall_time: float = float(_cfg(block, "fall_time"))
	check.call((block.call("decks") as Array).size() == count, "collapse: one deck per segment")
	# A runner reaches the end ledge.
	var runner: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, DECK_Y + 0.4, 0.8))
	await Fixtures.wait_physics(tree, 20)
	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return runner.global_position.z < -2.0 * count - 1.0, 400)
	check.call(runner.global_position.y > DECK_Y - 0.5 and runner.global_position.z < -2.0 * count, "collapse: a runner reaches the far end (%s)" % [runner.global_position])
	Input.action_release(&"move_forward")
	var first_gone: bool = _shape_of(block, 0).disabled or int(block.call("crumble_phase", 0)) != PHASE_IDLE
	check.call(first_gone, "collapse: the segment the runner passed breaks behind him")
	await _free(tree, [runner, block, end_ledge])
	# A standing player falls with his segment.
	var block2: Node3D = Fixtures.spawn_scene(tree.root, COLLAPSE_SCENE, Vector3(0.0, DECK_Y, 0.0))
	await Fixtures.wait_physics(tree, 5)
	var stander: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, DECK_Y + 0.4, 0.0))
	await Fixtures.wait_physics(tree, ceili((seg_delay + fall_time) * SHIPPED_TPS) + 40)
	check.call(stander.global_position.y < DECK_Y - 1.0, "collapse: a standing player falls (y %.2f)" % stander.global_position.y)
	check.call(_energy_clean(), "collapse: no step was paid to the arm")
	await _free(tree, [stander, block2])


func _scenario_sink(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(60.0, 1.0, 60.0), Vector3(0.0, DECK_Y - 4.0, 0.0))
	var block: Node3D = Fixtures.spawn_scene(tree.root, SINK_SCENE, Vector3(0.0, DECK_Y, 0.0))
	await Fixtures.wait_physics(tree, 5)
	var depth: float = float(_cfg(block, "sink_depth"))
	var speed: float = float(_cfg(block, "sink_speed"))
	var rise: float = float(_cfg(block, "rise_speed"))
	var deck: Node3D = (block.call("decks") as Array)[0] as Node3D
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, DECK_Y + 0.4, 0.0))
	await Fixtures.wait_physics(tree, 30)
	var one_second_at: float = deck.position.y
	await Fixtures.wait_physics(tree, 30)
	check.call(one_second_at < -0.1 and deck.position.y < one_second_at, "sink: the deck sinks under the rider (y %.2f then %.2f)" % [one_second_at, deck.position.y])
	check.call(absf((deck.position.y - one_second_at) + speed) < 0.2, "sink: it sinks at sink_speed %.2f m/s (%.2f m in 1 s)" % [speed, one_second_at - deck.position.y])
	await Fixtures.wait_physics(tree, ceili(depth / speed * SHIPPED_TPS) + 30)
	check.call(absf(deck.position.y + depth) < 0.06, "sink: it stops at sink_depth %.2f (%.2f)" % [depth, deck.position.y])
	check.call(player.global_position.y > DECK_Y - depth - 0.2 and player.is_on_floor(), "sink: the rider stays carried on the deck (y %.2f)" % player.global_position.y)
	player.global_position = Vector3(20.0, DECK_Y - 3.0, 0.0)
	await Fixtures.wait_physics(tree, ceili(depth / rise * SHIPPED_TPS) + 30)
	check.call(absf(deck.position.y) < 0.06, "sink: it rises again when the rider leaves (%.2f)" % deck.position.y)
	check.call(_energy_clean(), "sink: no step was paid to the arm")
	await _free(tree, [player, block, floor_body])


func _scenario_tip(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(60.0, 1.0, 60.0), Vector3(0.0, DECK_Y - 4.0, 0.0))
	var block: Node3D = Fixtures.spawn_scene(tree.root, TRUNK_SCENE, Vector3(0.0, DECK_Y, 0.0))
	await Fixtures.wait_physics(tree, 5)
	var angle: float = deg_to_rad(float(_cfg(block, "tip_angle_deg")))
	var tip_time: float = float(_cfg(block, "tip_time"))
	var return_time: float = float(_cfg(block, "return_time"))
	var deck: Node3D = (block.call("decks") as Array)[0] as Node3D
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, DECK_Y + 0.4, 2.0))
	await Fixtures.wait_physics(tree, ceili((tip_time + 0.4) * SHIPPED_TPS))
	var tilt: float = absf(deck.rotation.x)
	check.call(absf(tilt - angle) < deg_to_rad(2.0), "tip: landing on an end tips the trunk by tip_angle_deg (%.1f deg)" % rad_to_deg(tilt))
	check.call(rad_to_deg(tilt) < player.config.floor_max_angle_deg - 5.0, "tip: the deck angle stays below the floor max angle")
	check.call(player.is_on_floor() and player.global_position.y > DECK_Y - 2.0, "tip: the rider is not thrown (y %.2f, on floor %s)" % [player.global_position.y, player.is_on_floor()])
	player.global_position = Vector3(20.0, DECK_Y - 3.0, 0.0)
	await Fixtures.wait_physics(tree, ceili((return_time + 0.3) * SHIPPED_TPS))
	check.call(absf(deck.rotation.x) < deg_to_rad(1.0), "tip: it returns after return_time (%.1f deg)" % rad_to_deg(deck.rotation.x))
	check.call(_energy_clean(), "tip: no step was paid to the arm")
	await _free(tree, [player, block, floor_body])


func _scenario_drop(tree: SceneTree, check: Callable) -> void:
	_hits.clear()
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(60.0, 1.0, 60.0))
	var block: Node3D = Fixtures.spawn_scene(tree.root, DEBRIS_SCENE, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 5)
	var radius: float = float(_cfg(block, "trigger_radius"))
	var height: float = float(_cfg(block, "drop_height"))
	var respawn: float = float(_cfg(block, "respawn_time"))
	var debris: Node3D = block.get_node("Debris") as Node3D
	check.call(absf(debris.position.y - height) < 0.05, "drop: the debris hangs at drop_height %.1f (%.2f)" % [height, debris.position.y])
	var far: PlayerController = Fixtures.spawn_player(tree.root, Vector3(radius + 5.0, 0.0, 0.0))
	Fixtures.set_energy(far, 6)
	await Fixtures.wait_physics(tree, 60)
	check.call(absf(debris.position.y - height) < 0.05 and _hits.is_empty(), "drop: nothing falls while the player is outside trigger_radius")
	far.global_position = Vector3(radius * 0.4, 0.0, 0.0)
	await Fixtures.wait_until(tree, func() -> bool: return debris.position.y < height - 0.5, 90)
	check.call(debris.position.y < height - 0.5, "drop: entering trigger_radius drops the debris")
	await Fixtures.wait_physics(tree, 120)
	check.call(_hits.size() == 1 and int(_hits[0]["amount"]) >= 0, "drop: a hit announces exactly one player_hit (%d)" % _hits.size())
	check.call(_hits.size() == 0 or _hits[0]["source"] == StringName(block.name), "drop: the fact carries the block name as source")
	far.global_position = Vector3(radius + 6.0, 0.0, 0.0)
	await Fixtures.wait_physics(tree, ceili((respawn + 0.5) * SHIPPED_TPS))
	check.call(absf(debris.position.y - height) < 0.05, "drop: the debris respawns at drop_height (%.2f)" % debris.position.y)
	check.call(_energy_clean(), "drop: no step was paid to the arm")
	await _free(tree, [far, block, floor_body])


func _scenario_bite(tree: SceneTree, check: Callable) -> void:
	_hits.clear()
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(60.0, 1.0, 60.0))
	var block: Node3D = Fixtures.spawn_scene(tree.root, BLOOM_SCENE, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 5)
	var radius: float = float(_cfg(block, "trigger_radius"))
	var windup: float = float(_cfg(block, "windup"))
	var cooldown: float = float(_cfg(block, "cooldown"))
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(radius + 5.0, 0.0, 0.0))
	Fixtures.set_energy(player, 6)
	await Fixtures.wait_physics(tree, 30)
	check.call(_hits.is_empty(), "bite: it sleeps while the player is outside trigger_radius")
	player.global_position = Vector3(0.0, 0.0, 0.8)
	player.move_velocity = Vector3.ZERO
	await Fixtures.wait_physics(tree, ceili(windup * SHIPPED_TPS * 0.5))
	check.call(_hits.is_empty(), "bite: nothing happens during the windup")
	await Fixtures.wait_physics(tree, ceili((windup * 0.5 + 0.4) * SHIPPED_TPS))
	check.call(_hits.size() == 1, "bite: after the windup the bite pushes and emits one player_hit (%d)" % _hits.size())
	# The player stays in reach: the cooldown holds the next bite back.
	for tick: int in ceili(cooldown * 0.6 * SHIPPED_TPS):
		player.global_position = Vector3(0.0, 0.0, 0.8)
		player.move_velocity = Vector3.ZERO
		await Fixtures.wait_physics(tree, 1)
	check.call(_hits.size() == 1, "bite: the cooldown prevents a second bite at once (%d)" % _hits.size())
	check.call(_energy_clean(), "bite: no step was paid to the arm")
	await _free(tree, [player, block, floor_body])
