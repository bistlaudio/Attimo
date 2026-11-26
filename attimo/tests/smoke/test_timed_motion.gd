extends RefCounted
## Plan 05.1-04 (KIT-01, KIT-02, D-07, D-09, D-11): the Timed motion block, profiles SWEEP (clock-hand platform) and TILT (tilting
## platform), both always on. Research reproduction 3 (D-07): with the hand pivot at the old RAISED 1.0 the swept deck dips under the
## floor top, the CharacterBody3D floor snap / floor detection then lands the rider on the static floor tile, _find_floor_carrier()
## stops returning the deck, the reference-frame carry is lost and the rider ends up to 3.4 m off the deck. The fix is the station
## geometry guard: the pivot stands at TimedMotion.min_pivot_height, so the lowest deck point over a full sweep stays above the floor
## top plus FLOOR_CLEARANCE. Checked here with a real floor and a tip rider on every tick (the deck is the floor collider, the static
## floor never is, the feet stay within 0.2 m of the deck top), with a positive control at the old pivot 1.0 that must meet the floor.
## Bug 2: a jump off a rising deck keeps the deck's vertical chord (within 0.1 m/s), a jump off a static floor and off an
## engine-carried paternoster cabin is unchanged (within 0.01 m/s, no double count). Samples are read by a priority-50 probe: after
## the player (0) moved and before the deck (100) moves, so the rider and the deck pose of one tick are read together.
## Block, config and statics are reached by path, call() and constant maps, so this file compiles before the classes exist (TDD RED).

const Fixtures := preload("res://tests/fixtures.gd")

const BLOCK_SCRIPT: String = "res://scripts/kit/blocks/timed_motion.gd"
const CONFIG_SCRIPT: String = "res://scripts/kit/configs/timed_motion_config.gd"
const HAND_SCENE: String = "res://scenes/kit/steampunk/clock_hand_platform.tscn"
const TILT_SCENE: String = "res://scenes/kit/steampunk/tilting_platform.tscn"
const HAND_PRESET: String = "res://resources/kit/timed_motion/clock_hand.tres"
const TILT_PRESET: String = "res://resources/kit/timed_motion/tilting_platform.tres"
const BRIDGE_SCENE: String = "res://scenes/kit/steampunk/drawbridge.tscn"
const BRIDGE_PRESET: String = "res://resources/kit/timed_motion/drawbridge.tres"
const PATERNOSTER_SCENE: String = "res://scenes/mechanisms/paternoster.tscn"
const SHIPPED_TPS: int = 60
## Ticks to let the rider land and the always-on ramp start before sampling.
const SETTLE_TICKS: int = 30
## At least one full sweep of both profiles (hand period about 230 ticks, tilt about 200 at the shipped values).
const SWEEP_TICKS: int = 600
const MAX_DECK_OFFSET: float = 0.2
const DECK_TAKEOFF_TOLERANCE: float = 0.1
const STATIC_TAKEOFF_TOLERANCE: float = 0.01
## The old station height of the rotating platform (research reproduction 3), used as the positive control.
const OLD_RAISED: float = 1.0
const HAND_RIDER: float = 7.0
const TILT_RIDER: float = 3.5
## The take-off rider stands 4 m out on the hand, so the deck chord (up to 4 m/s) stays under the take-off clamp.
const TAKEOFF_RIDER: float = 4.0
const RISING_CHORD: float = 1.5
## PlayerController.MAX_DECK_TAKEOFF_SPEED when the constant is missing (RED).
const FALLBACK_TAKEOFF_CLAMP: float = 6.0


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	var all_there: bool = true
	for path: String in [BLOCK_SCRIPT, CONFIG_SCRIPT, HAND_SCENE, TILT_SCENE, HAND_PRESET, TILT_PRESET]:
		var exists: bool = ResourceLoader.exists(path)
		check.call(exists, "%s exists" % path)
		all_there = all_there and exists
	if not all_there:
		return
	var script: GDScript = load(BLOCK_SCRIPT) as GDScript
	check.call(String(script.get_global_name()) == "TimedMotion", "timed_motion.gd declares class_name TimedMotion")
	_geometry_guard(check, script)
	await _always_on(tree, check)
	var hand_pivot: float = float(script.call(&"min_pivot_height", load(HAND_PRESET), 0.0))
	var tilt_pivot: float = float(script.call(&"min_pivot_height", load(TILT_PRESET), 0.0))
	await _rider(tree, check, HAND_SCENE, HAND_PRESET, HAND_RIDER, hand_pivot, true, "clock hand")
	await _rider(tree, check, TILT_SCENE, TILT_PRESET, TILT_RIDER, tilt_pivot, true, "tilt plate")
	await _rider(tree, check, HAND_SCENE, HAND_PRESET, HAND_RIDER, OLD_RAISED, false, "clock hand")
	await _rider(tree, check, TILT_SCENE, TILT_PRESET, TILT_RIDER, OLD_RAISED, false, "tilt plate")
	var static_speed: float = await _static_takeoff(tree, check)
	await _deck_takeoff(tree, check, hand_pivot, static_speed)
	await _paternoster_takeoff(tree, check, static_speed)
	await _hinge(tree, check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


## The swept deck's reach from the pivot for a config, independent of the block: hand length (SWEEP) or half the plate (TILT).
func _reach(config: Resource) -> float:
	var profiles: Dictionary = (load(CONFIG_SCRIPT) as GDScript).get_script_constant_map().get("Profile", {}) as Dictionary
	if int(config.get("profile")) == int(profiles.get("SWEEP", -1)):
		return float(config.get("hand_length"))
	return float(config.get("plate_size")) * 0.5


func _limit_deg(config: Resource) -> float:
	var profiles: Dictionary = (load(CONFIG_SCRIPT) as GDScript).get_script_constant_map().get("Profile", {}) as Dictionary
	if int(config.get("profile")) == int(profiles.get("SWEEP", -1)):
		return float(config.get("sweep_limit_deg"))
	return float(config.get("tilt_limit_deg"))


func _geometry_guard(check: Callable, script: GDScript) -> void:
	var clearance: float = float(script.get_script_constant_map().get("FLOOR_CLEARANCE", NAN))
	check.call(clearance > 0.0, "TimedMotion.FLOOR_CLEARANCE is positive (%.2f)" % clearance)
	var profiles: Dictionary = (load(CONFIG_SCRIPT) as GDScript).get_script_constant_map().get("Profile", {}) as Dictionary
	var timings: Dictionary = (load(CONFIG_SCRIPT) as GDScript).get_script_constant_map().get("Timing", {}) as Dictionary
	check.call(profiles.has("SWEEP") and profiles.has("TILT"), "TimedMotionConfig.Profile has SWEEP and TILT (%s)" % [profiles])
	check.call(timings.has("ALWAYS_ON") and timings.has("SWITCHED"), "TimedMotionConfig.Timing has ALWAYS_ON and SWITCHED (%s)" % [timings])
	for preset_path: String in [HAND_PRESET, TILT_PRESET]:
		var config: Resource = load(preset_path) as Resource
		check.call(int(config.get("timing")) == int(timings.get("ALWAYS_ON", -1)), "%s is ALWAYS_ON (D-07)" % preset_path)
		var pivot: float = 5.0
		var lowest: float = float(script.call(&"lowest_deck_y", config, pivot))
		check.call(lowest < pivot, "%s: lowest_deck_y %.3f lies under the pivot %.1f" % [preset_path, lowest, pivot])
		var needed: float = clearance + _reach(config) * sin(deg_to_rad(_limit_deg(config))) + float(config.get("plate_thickness"))
		var station: float = float(script.call(&"min_pivot_height", config, 0.0))
		check.call(station >= needed - 0.0001, "%s: min_pivot_height %.3f >= floor + clearance + reach * sin(limit) + thickness = %.3f" % [preset_path, station, needed])
		var at_station: float = float(script.call(&"lowest_deck_y", config, station))
		check.call(at_station >= clearance - 0.0001, "%s: at min_pivot_height the lowest deck point is %.3f m above the floor top (>= %.2f)" % [preset_path, at_station, clearance])
	var hand: Resource = load(HAND_PRESET) as Resource
	var tilt: Resource = load(TILT_PRESET) as Resource
	check.call(int(hand.get("profile")) == int(profiles.get("SWEEP", -1)), "clock_hand.tres is the SWEEP profile")
	check.call(int(tilt.get("profile")) == int(profiles.get("TILT", -1)), "tilting_platform.tres is the TILT profile")
	# D-09: the tuned values are folded unchanged.
	check.call(is_equal_approx(float(hand.get("angular_speed")), 1.0) and is_equal_approx(float(hand.get("ramp_time")), 0.3), "the folded angular_speed 1.0 and ramp_time 0.3 are unchanged")
	check.call(is_equal_approx(float(hand.get("sweep_limit_deg")), 35.0) and is_equal_approx(float(tilt.get("tilt_limit_deg")), 30.0), "the folded sweep limit 35 and tilt limit 30 are unchanged")
	check.call(is_equal_approx(float(hand.get("hand_length")), 8.0) and is_equal_approx(float(tilt.get("plate_size")), 8.0), "the folded deck sizes (hand 8 m, plate 8 m) are unchanged")


func _spawn_block(tree: SceneTree, scene_path: String, preset_path: String, at: Vector3) -> Node3D:
	var block: Node3D = (load(scene_path) as PackedScene).instantiate() as Node3D
	# Never write the cached preset: the block gets its own copy before it enters the tree.
	block.set(&"config", (load(preset_path) as Resource).duplicate())
	block.position = at
	tree.root.add_child(block)
	return block


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


## D-07: no receiver, no lever, the deck moves on its own right after spawn.
func _always_on(tree: SceneTree, check: Callable) -> void:
	for scene_path: String in [HAND_SCENE, TILT_SCENE]:
		var preset: String = HAND_PRESET if scene_path == HAND_SCENE else TILT_PRESET
		var block: Node3D = _spawn_block(tree, scene_path, preset, Vector3(0.0, -100.0, 0.0))
		await Fixtures.wait_physics(tree, 1)
		var start: float = float(block.call(&"current_angle"))
		await Fixtures.wait_physics(tree, 30)
		var now: float = float(block.call(&"current_angle"))
		check.call(absf(now - start) > 0.01, "%s: always on, the deck turns within 30 ticks with no receiver (%.3f -> %.3f rad)" % [scene_path.get_file(), start, now])
		var deck: Node = block.call(&"body") as Node
		check.call(deck is AnimatableBody3D and deck.is_in_group(&"carrying_platform") and not (deck as AnimatableBody3D).sync_to_physics, "%s: the deck is an AnimatableBody3D in carrying_platform, sync_to_physics off" % scene_path.get_file())
		check.call(block.process_physics_priority == 100, "%s: the block ticks after the player (priority %d)" % [scene_path.get_file(), block.process_physics_priority])
		await _free(tree, [block])


## A rider `distance` m out on the deck over a real floor (top y 0), the pivot at `pivot_y`. `clean`: the fixed station height, every
## tick must stand on the deck; otherwise the positive control at the old height must meet the static floor at least once.
func _rider(tree: SceneTree, check: Callable, scene_path: String, preset_path: String, distance: float, pivot_y: float, clean: bool, label: String) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var block: Node3D = _spawn_block(tree, scene_path, preset_path, Vector3(0.0, pivot_y, 0.0))
	var deck: CollisionObject3D = block.call(&"body") as CollisionObject3D
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, pivot_y + 0.05, distance))
	var stats: Dictionary = {"tick": 0, "sampled": 0, "deck_missing": 0, "floor_hits": 0, "worst": 0.0, "peak": 0.0}
	var sample: Callable = func() -> void:
		stats["tick"] = int(stats["tick"]) + 1
		if int(stats["tick"]) <= SETTLE_TICKS:
			return
		stats["sampled"] = int(stats["sampled"]) + 1
		var on_deck: bool = false
		var on_static: bool = false
		for index: int in player.get_slide_collision_count():
			var hit: KinematicCollision3D = player.get_slide_collision(index)
			var collider: Object = hit.get_collider()
			if collider == floor_body:
				on_static = true
			elif collider == deck and hit.get_normal().y > 0.5:
				on_deck = true
		if not (on_deck and player.is_on_floor()):
			stats["deck_missing"] = int(stats["deck_missing"]) + 1
		if on_static:
			stats["floor_hits"] = int(stats["floor_hits"]) + 1
		stats["worst"] = maxf(float(stats["worst"]), absf(Fixtures.deck_offset(player, deck)))
		stats["peak"] = maxf(float(stats["peak"]), absf(float(block.call(&"current_angle"))))
	var probe: Node = Fixtures.spawn_physics_probe(tree.root, 50, sample)
	await Fixtures.wait_physics(tree, SETTLE_TICKS + SWEEP_TICKS)
	var label_full: String = "%s, rider %.1f m, pivot %.2f" % [label, distance, pivot_y]
	if clean:
		check.call(float(stats["peak"]) > 0.3, "%s: the deck really swept (peak %.2f rad)" % [label_full, float(stats["peak"])])
		check.call(int(stats["deck_missing"]) == 0, "%s: the deck is the rider's floor collider on every tick (missing on %d of %d)" % [label_full, int(stats["deck_missing"]), int(stats["sampled"])])
		check.call(int(stats["floor_hits"]) == 0, "%s: the static floor body is never touched (%d ticks)" % [label_full, int(stats["floor_hits"])])
		check.call(float(stats["worst"]) <= MAX_DECK_OFFSET, "%s: worst feet offset from the deck top %.3f m (<= %.1f)" % [label_full, float(stats["worst"]), MAX_DECK_OFFSET])
	else:
		check.call(int(stats["floor_hits"]) > 0, "positive control, %s: the deck dips under the floor and the rider meets the static floor (%d ticks, worst offset %.2f m)" % [label_full, int(stats["floor_hits"]), float(stats["worst"])])
	await _free(tree, [probe, player, block, floor_body])


## Presses jump and returns {speed, chord} from the take-off tick (first tick off the floor after a grounded one), sampled by the
## probe. `carrier` (may be null) gives the deck chord under the feet on the last grounded tick. Empty on a timeout.
func _jump(tree: SceneTree, player: PlayerController, carrier: Node3D) -> Dictionary:
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var state: Dictionary = {"armed": false, "grounded": true, "chord": Vector3.ZERO, "result": {}}
	var sample: Callable = func() -> void:
		var grounded: bool = player.is_on_floor()
		if grounded and carrier != null:
			state["chord"] = carrier.call(&"carry_velocity_at", player.global_position, dt) as Vector3
		if bool(state["armed"]) and bool(state["grounded"]) and not grounded and (state["result"] as Dictionary).is_empty():
			state["result"] = {"speed": player.vertical_speed, "chord": state["chord"]}
		state["grounded"] = grounded
	var probe: Node = Fixtures.spawn_physics_probe(tree.root, 50, sample)
	await Fixtures.wait_physics(tree, 1)
	state["armed"] = true
	Input.action_press(&"jump")
	var took_off: Callable = func() -> bool: return not (state["result"] as Dictionary).is_empty()
	await Fixtures.wait_until(tree, took_off, 30)
	Input.action_release(&"jump")
	await _free(tree, [probe])
	return state["result"] as Dictionary


func _static_takeoff(tree: SceneTree, check: Callable) -> float:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.05, 0.0))
	await Fixtures.wait_physics(tree, 20)
	var result: Dictionary = await _jump(tree, player, null)
	check.call(not result.is_empty(), "static floor: the jump takes off")
	var speed: float = float(result.get("speed", NAN))
	check.call(speed > 1.0, "static floor: take-off vertical speed %.4f m/s (the shipped jump, read in this run)" % speed)
	await _free(tree, [player, floor_body])
	return speed


## A jump off the clock hand while the deck point under the feet rises: the take-off keeps the deck's vertical chord.
func _deck_takeoff(tree: SceneTree, check: Callable, pivot_y: float, static_speed: float) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var block: Node3D = _spawn_block(tree, HAND_SCENE, HAND_PRESET, Vector3(0.0, pivot_y, 0.0))
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, pivot_y + 0.05, TAKEOFF_RIDER))
	await Fixtures.wait_physics(tree, SETTLE_TICKS)
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var is_rising: Callable = func() -> bool:
		return player.is_on_floor() and (block.call(&"carry_velocity_at", player.global_position, dt) as Vector3).y > RISING_CHORD
	var rising: int = await Fixtures.wait_until(tree, is_rising, 400)
	check.call(rising >= 0, "clock hand: the deck point under the rider rises faster than %.1f m/s at some tick" % RISING_CHORD)
	var result: Dictionary = await _jump(tree, player, block)
	check.call(not result.is_empty(), "clock hand: the jump takes off the rising deck")
	if not result.is_empty():
		var clamp_speed: float = float(player.get_script().get_script_constant_map().get("MAX_DECK_TAKEOFF_SPEED", FALLBACK_TAKEOFF_CLAMP))
		var chord_y: float = (result["chord"] as Vector3).y
		var expected: float = static_speed + clampf(chord_y, -clamp_speed, clamp_speed)
		var speed: float = float(result["speed"])
		check.call(chord_y > 1.0, "clock hand: the deck rose at take-off (chord y %.3f m/s)" % chord_y)
		check.call(absf(speed - expected) <= DECK_TAKEOFF_TOLERANCE, "clock hand: take-off vertical speed %.3f = static %.3f + deck chord %.3f (expected %.3f, tolerance %.2f)" % [speed, static_speed, chord_y, expected, DECK_TAKEOFF_TOLERANCE])
	await _free(tree, [player, block, floor_body])


## A jump off a rising paternoster cabin (engine-carried, sync_to_physics): no double count, the take-off equals the static jump.
func _paternoster_takeoff(tree: SceneTree, check: Callable, static_speed: float) -> void:
	var source: Trigger = Trigger.new()
	tree.root.add_child(source)
	var lift: Paternoster = (load(PATERNOSTER_SCENE) as PackedScene).instantiate() as Paternoster
	lift.source = source
	tree.root.add_child(lift)
	await Fixtures.wait_physics(tree, 2)
	var deck: AnimatableBody3D = lift.decks()[0]
	var player: PlayerController = Fixtures.spawn_player(tree.root, deck.global_position + Vector3(0.0, 0.1, 0.0))
	await Fixtures.wait_physics(tree, 20)
	source.set_active(true)
	await Fixtures.wait_physics(tree, 40)
	var before: float = deck.global_position.y
	await Fixtures.wait_physics(tree, 2)
	check.call(deck.global_position.y > before + 0.01 and player.is_on_floor(), "paternoster: the rider stands on a rising cabin (%.3f -> %.3f)" % [before, deck.global_position.y])
	var result: Dictionary = await _jump(tree, player, null)
	check.call(not result.is_empty(), "paternoster: the jump takes off the cabin")
	var speed: float = float(result.get("speed", NAN))
	check.call(absf(speed - static_speed) <= STATIC_TAKEOFF_TOLERANCE, "paternoster: take-off vertical speed %.4f equals the static jump %.4f (no double count, tolerance %.2f)" % [speed, static_speed, STATIC_TAKEOFF_TOLERANCE])
	await _free(tree, [player, lift, source])


## Plan 05.1-17 (D-18, GAME-DESIGN 6.5): the HINGE profile, the drawbridge. It folds from raised (hinge_angle_deg) to flat while its child
## Receiver is on, with the same carry contract as the sweep: AnimatableBody3D in carrying_platform, priority 100, carry_velocity_at.
func _hinge(tree: SceneTree, check: Callable) -> void:
	var exists: bool = ResourceLoader.exists(BRIDGE_SCENE) and ResourceLoader.exists(BRIDGE_PRESET)
	check.call(exists, "the drawbridge scene and preset exist")
	if not exists:
		return
	var profiles: Dictionary = (load(CONFIG_SCRIPT) as GDScript).get_script_constant_map().get("Profile", {}) as Dictionary
	check.call(profiles.has("HINGE"), "TimedMotionConfig.Profile has HINGE (%s)" % [profiles])
	var preset: Resource = load(BRIDGE_PRESET) as Resource
	check.call(int(preset.get("profile")) == int(profiles.get("HINGE", -1)), "drawbridge.tres is the HINGE profile")
	check.call(int(preset.get("timing")) == 1, "drawbridge.tres is SWITCHED")
	var driver: Node3D = Fixtures.spawn_signal_driver(tree.root, false)
	var bridge: Node3D = (load(BRIDGE_SCENE) as PackedScene).instantiate() as Node3D
	bridge.get_node("Receiver").set(&"source", driver)
	tree.root.add_child(bridge)
	var length: float = float(preset.get("hand_length"))
	var hinge_time: float = float(preset.get("hinge_time"))
	var deck: Node3D = bridge.call(&"body") as Node3D
	await Fixtures.wait_physics(tree, 5)
	var raised_tip: float = (deck.global_transform * Vector3(0.0, 0.0, length)).y
	check.call(raised_tip > length * 0.9, "hinge: raised at rest, deck tip y %.2f (deck %.1f m)" % [raised_tip, length])
	check.call(deck is AnimatableBody3D and deck.is_in_group(&"carrying_platform") and not (deck as AnimatableBody3D).sync_to_physics, "hinge: the deck is an AnimatableBody3D in carrying_platform, sync_to_physics off")
	check.call(bridge.process_physics_priority == 100, "hinge: the block ticks after the player (priority %d)" % bridge.process_physics_priority)
	driver.call(&"set_active", true)
	await Fixtures.wait_physics(tree, int(hinge_time * 0.5 * float(SHIPPED_TPS)))
	var dt: float = 1.0 / float(SHIPPED_TPS)
	var mid: Vector3 = bridge.call(&"carry_velocity_at", deck.global_transform * Vector3(0.0, 0.0, length), dt) as Vector3
	check.call(mid.y < -0.5, "hinge: mid-fold the deck tip moves down, chord y %.2f m/s" % mid.y)
	await Fixtures.wait_physics(tree, int(ceil((hinge_time + 0.2) * float(SHIPPED_TPS))))
	var tip: float = (deck.global_transform * Vector3(0.0, 0.0, length)).y
	check.call(absf(tip) < 0.1, "hinge: lowered flat within hinge_time + 0.2 s (tip y %.3f)" % tip)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.05, 4.0))
	var stats: Dictionary = {"tick": 0, "missing": 0, "worst": 0.0}
	var sample: Callable = func() -> void:
		stats["tick"] = int(stats["tick"]) + 1
		if int(stats["tick"]) <= 20:
			return
		var on_deck: bool = false
		for index: int in player.get_slide_collision_count():
			var hit: KinematicCollision3D = player.get_slide_collision(index)
			if hit.get_collider() == deck and hit.get_normal().y > 0.5:
				on_deck = true
		if not (on_deck and player.is_on_floor()):
			stats["missing"] = int(stats["missing"]) + 1
		stats["worst"] = maxf(float(stats["worst"]), absf(Fixtures.deck_offset(player, deck as CollisionObject3D)))
	var probe: Node = Fixtures.spawn_physics_probe(tree.root, 50, sample)
	await Fixtures.wait_physics(tree, 80)
	check.call(int(stats["missing"]) == 0 and float(stats["worst"]) <= MAX_DECK_OFFSET, "hinge: a rider stands on the lowered deck on every tick, floor snap works (missing %d, worst offset %.3f m)" % [int(stats["missing"]), float(stats["worst"])])
	await _free(tree, [probe, player, bridge, driver])
