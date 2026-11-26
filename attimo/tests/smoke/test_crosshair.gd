extends RefCounted
## CAM-02 / D-01 / D-15 / T-03-09: the reticle is always visible with one small look (no aim hold, no goggle lens overlay, no module
## plate), it never takes mouse input, covers the full screen rect and draws below the debug overlays (layers 100-102). It carries the
## Loader ring and the near prompt only: the shot ring, the lock state and the Targeting state are gone (D-45).

const Fixtures := preload("res://tests/fixtures.gd")
const CROSSHAIR_SCENE: String = "res://scenes/ui/crosshair.tscn"
const MAX_LAYER: int = 99
## Plan 05.1-05 (D-01, D-05, D-26): the kit hold sources. The cage shows a brass pressure gauge, the cannon shows nothing.
const CAGE_SCENE: String = "res://scenes/kit/steampunk/slingshot_core.tscn"
const CANNON_SCENE: String = "res://scenes/kit/steampunk/steam_cannon.tscn"
const PREVIEW_SCRIPT: String = "res://scripts/player/loader_preview.gd"
const BRASS_LOOK: String = "res://resources/mechanisms/look_brass.tres"
const CAGE_CENTRE: Vector3 = Vector3(0.0, 10.0, 0.0)


func run(tree: SceneTree, check: Callable) -> void:
	var packed: PackedScene = load(CROSSHAIR_SCENE) as PackedScene
	check.call(packed != null, "crosshair.tscn loads")
	if packed == null:
		return
	var crosshair: Crosshair = packed.instantiate() as Crosshair
	check.call(crosshair != null, "the scene root is a Crosshair")
	if crosshair == null:
		return
	tree.root.add_child(crosshair)
	await tree.process_frame

	check.call(crosshair.visible, "the reticle is always on after one process frame (D-01)")
	check.call(crosshair.idle_alpha > 0.0 and crosshair.idle_alpha < 1.0, "the reticle with no target is drawn at the idle alpha (%.2f)" % crosshair.idle_alpha)
	check.call(crosshair.get_node_or_null("Lens") == null, "there is no lens overlay")
	check.call(not crosshair.has_method(&"set_module_name"), "there is no module plate")
	for _i: int in 5:
		await tree.process_frame
	check.call(crosshair.visible, "the reticle stays on over time")

	var reticle: Control = crosshair.get_node("Reticle") as Control
	check.call(reticle.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the Reticle ignores the mouse (T-03-09)")
	check.call(is_equal_approx(reticle.anchor_right, 1.0) and is_equal_approx(reticle.anchor_bottom, 1.0), "the Reticle covers the full rect")
	check.call(crosshair.layer >= 1 and crosshair.layer <= MAX_LAYER, "the layer %d is below the debug overlays (100-102)" % crosshair.layer)

	# D-45: no shot ring, no lock state, no charge arc, no cooldown dim; the source names neither Targeting nor the full-charge fact.
	var property_names: Array[String] = []
	for property: Dictionary in crosshair.get_property_list():
		property_names.append(str(property["name"]))
	check.call(not property_names.has("shot_ring_visible") and not property_names.has("state") and not property_names.has("charge"), "the crosshair has no shot ring, state or charge property")
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/crosshair.gd")
	check.call(not source.contains("Targeting") and not source.contains("shot_fully_charged"), "crosshair.gd names neither Targeting nor shot_fully_charged")
	check.call(not crosshair.has_method(&"set_state") and not crosshair.has_method(&"set_charge") and not crosshair.has_method(&"set_cooldown_dim"), "the reticle state, charge and cooldown setters are gone")
	await tree.process_frame
	check.call(crosshair.visible, "the reticle is still on")

	crosshair.free()
	await _check_loader_ring(tree, check)
	await _check_cage_gauge(tree, check)
	await _check_cannon_quiet(tree, check)


# Plan 05-02 (D-14): while the Loader holds, a double ring turns counter-clockwise (the angle decreases), it is turquoise with a full
# core and the empty colour without one, and it never shows outside the hold.
func _check_loader_ring(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 0.0))
	var ring: Crosshair = (load(CROSSHAIR_SCENE) as PackedScene).instantiate() as Crosshair
	tree.root.add_child(ring)
	await Fixtures.wait_physics(tree, 10)
	check.call(not ring.loader_ring_visible, "the Loader ring is hidden before a hold")
	Fixtures.set_energy(player, 3)
	Input.action_press(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return player.loader_active(), 6)
	await Fixtures.wait_process(tree, 3)
	check.call(ring.loader_ring_visible, "the Loader ring is visible while the Loader holds")
	var first: float = ring.loader_ring_angle
	await Fixtures.wait_process(tree, 5)
	var second: float = ring.loader_ring_angle
	check.call(second < first, "the ring angle decreases, so it turns counter-clockwise (%.3f -> %.3f)" % [first, second])
	check.call(ring.loader_ring_speed_deg > 0.0, "the ring speed is positive; the ring turns counter-clockwise")
	check.call(ring.loader_ring_tint == ring.lock_color, "a full core draws the ring in the turquoise lock colour")
	check.call(ring.loader_ring_hold > 0.0 and ring.loader_ring_hold <= 1.0, "the inner ring fills with the hold time (%.2f)" % ring.loader_ring_hold)
	check.call(_ring_style(ring) == &"double", "(05.1-05) the arm Loader keeps the double ring style (got '%s')" % _ring_style(ring))
	Input.action_release(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return not player.loader_active(), 8)
	await Fixtures.wait_process(tree, 3)
	check.call(not ring.loader_ring_visible, "the ring is hidden again after the release")
	# Without a core the ring is grey.
	Fixtures.restore_time()
	await Fixtures.wait_physics(tree, 80)
	Fixtures.set_energy(player, 0)
	player.loader_cooldown_timer = 0.0
	player.loader_available = true
	Input.action_press(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return player.loader_active(), 12)
	await Fixtures.wait_process(tree, 3)
	check.call(ring.loader_ring_visible and ring.loader_ring_tint == ring.loader_empty_color, "an empty arm draws the ring in the empty colour (visible %s)" % ring.loader_ring_visible)
	Input.action_release(&"loader")
	await Fixtures.wait_physics(tree, 4)
	Fixtures.restore_time()
	ring.queue_free()
	player.queue_free()
	await player.tree_exited
	floor_body.queue_free()
	await tree.process_frame


## Crosshair.loader_ring_style() by reflection (plan 05.1-05), or &"" while the method does not exist.
func _ring_style(ring: Crosshair) -> StringName:
	return ring.call(&"loader_ring_style") as StringName if ring.has_method(&"loader_ring_style") else &""


## LoaderPreview.BRASS_COLOR by reflection, or an impossible colour while it does not exist.
static func brass_color() -> Color:
	var script: GDScript = load(PREVIEW_SCRIPT) as GDScript
	return script.get_script_constant_map().get("BRASS_COLOR", Color(-1.0, -1.0, -1.0, -1.0)) as Color


# Plan 05.1-05 (D-01, D-26): while the cage holds Rino the ring is a brass pressure gauge whose needle stands at the stored speed
# (stored_ratio), brass even with a full core (never the turquoise lock colour, never the grey empty-arm colour).
func _check_cage_gauge(tree: SceneTree, check: Callable) -> void:
	var brass: Color = brass_color()
	var look: StandardMaterial3D = load(BRASS_LOOK) as StandardMaterial3D
	check.call(brass.is_equal_approx(look.albedo_color), "(g0) LoaderPreview.BRASS_COLOR is the look_brass.tres albedo %s (got %s)" % [look.albedo_color, brass])
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(300.0, 1.0, 300.0))
	var cage: Node3D = Fixtures.spawn_scene(tree.root, CAGE_SCENE, CAGE_CENTRE)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 10.0, 60.0))
	var ring: Crosshair = (load(CROSSHAIR_SCENE) as PackedScene).instantiate() as Crosshair
	tree.root.add_child(ring)
	Fixtures.set_energy(player, 3)
	await Fixtures.wait_physics(tree, 3)
	player.teleport(CAGE_CENTRE + Vector3(-4.0, -1.0, 0.0))
	player.launch_along(Vector3.RIGHT, 9.0, false)
	var entered: int = await Fixtures.wait_until(tree, func() -> bool: return player.loader_active(), 40)
	await Fixtures.wait_process(tree, 3)
	check.call(entered >= 0 and ring.loader_ring_visible, "(g1) the cage hold shows the Loader ring (entered %d)" % entered)
	var state: LoaderState = player.loader_state()
	check.call(_ring_style(ring) == &"gauge", "(g1) the cage hold draws the pressure gauge style (got '%s')" % _ring_style(ring))
	var needle: Variant = ring.get(&"loader_gauge_needle")
	check.call(needle != null and state != null and state.stored_ratio() > 0.0 and absf(float(needle) - state.stored_ratio()) < 0.001, "(g2) the gauge needle stands at the stored ratio (needle %s, stored %.3f)" % [needle, state.stored_ratio() if state != null else -1.0])
	check.call(ring.loader_ring_tint.is_equal_approx(brass), "(g3) the gauge is brass with a full core (got %s)" % ring.loader_ring_tint)
	check.call(ring.loader_ring_tint != ring.lock_color and ring.loader_ring_tint != ring.loader_empty_color, "(g3) the gauge is neither turquoise nor the grey empty-arm colour")
	await Fixtures.tap_action(tree, &"loader", 1)
	await Fixtures.wait_until(tree, func() -> bool: return not player.loader_active(), 6)
	await Fixtures.wait_process(tree, 3)
	check.call(not ring.loader_ring_visible, "(g4) the gauge is hidden after the cage throw")
	Input.action_release(&"loader")
	Fixtures.restore_time()
	for node: Node in [ring, player, cage, floor_body]:
		node.queue_free()
	await tree.process_frame
	await tree.process_frame


# Plan 05.1-05 (D-05): the steam cannon's 0.2 s FIXED hold has no input, so it shows no Loader ring and no trajectory preview.
func _check_cannon_quiet(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(300.0, 1.0, 300.0))
	var cannon: Node3D = (load(CANNON_SCENE) as PackedScene).instantiate() as Node3D
	cannon.rotation.y = deg_to_rad(-90.0)
	tree.root.add_child(cannon)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 40.0))
	var ring: Crosshair = (load(CROSSHAIR_SCENE) as PackedScene).instantiate() as Crosshair
	tree.root.add_child(ring)
	var preview: Node3D = player.get_node("LoaderPreview") as Node3D
	var blast: Node3D = cannon.find_child("SteamBlast", true, false) as Node3D
	var blast_on_launch: Array[bool] = []
	var bus: Node = tree.root.get_node("EventBus")
	var on_launch: Callable = func(_p: Vector3, _d: Vector3, _s: float) -> void: blast_on_launch.append(blast != null and blast.visible)
	bus.connect(&"launched", on_launch, CONNECT_DEFERRED)
	Fixtures.set_energy(player, 3)
	await Fixtures.wait_physics(tree, 3)
	player.teleport(cannon.global_position - Vector3.RIGHT * 3.2)
	await tree.physics_frame
	var speed: float = player.config.run_speed
	player.launch_along(Vector3.RIGHT, speed, false)
	var entered: int = -1
	for i: int in 40:
		if player.loader_active():
			entered = i
			break
		player.move_velocity = Vector3.RIGHT * speed
		await tree.physics_frame
	check.call(entered >= 0, "(q1) the cannon catches Rino into a FIXED hold (entered %d)" % entered)
	# The entry push of this test emits `launched` too; only the cannon's own launch counts.
	blast_on_launch.clear()
	var frames: int = 0
	var ring_seen: bool = false
	var preview_seen: bool = false
	var guard: int = 0
	while player.loader_active() and guard < 400:
		await tree.process_frame
		guard += 1
		frames += 1
		ring_seen = ring_seen or ring.loader_ring_visible
		preview_seen = preview_seen or preview.visible
	check.call(frames > 0, "(q2) the cannon hold was sampled over %d process frames" % frames)
	check.call(not ring_seen, "(q2) the cannon hold shows no Loader ring")
	check.call(not preview_seen, "(q2) the cannon hold shows no trajectory preview")
	await tree.process_frame
	check.call(blast != null and not blast_on_launch.is_empty() and blast_on_launch[0], "(q3) the cannon's SteamBlast shows on its launch (%s)" % [blast_on_launch])
	check.call(blast_on_launch.size() == 1, "(q3) one launch fact after the catch (%d)" % blast_on_launch.size())
	await tree.create_timer(0.3, true, false, true).timeout
	check.call(blast != null and not blast.visible, "(q3) the cannon's SteamBlast is hidden again within 0.3 s")
	bus.disconnect(&"launched", on_launch)
	Fixtures.restore_time()
	for node: Node in [ring, player, cannon, floor_body]:
		node.queue_free()
	await tree.process_frame
	await tree.process_frame
