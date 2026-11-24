extends RefCounted
## CAM-02 / D-01 / D-15 / T-03-09: the reticle is always visible with one small look (no aim hold, no goggle lens overlay, no module
## plate), it never takes mouse input, covers the full screen rect and draws below the debug overlays (layers 100-102). It carries the
## lock state, the Targeting state and the shot charge.

const Fixtures := preload("res://tests/fixtures.gd")
const CROSSHAIR_SCENE: String = "res://scenes/ui/crosshair.tscn"
const MAX_LAYER: int = 99


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

	check.call(not crosshair.locked, "the crosshair starts unlocked")
	crosshair.set_locked(true)
	check.call(crosshair.locked, "set_locked(true) stores the lock state")
	crosshair.set_locked(false)
	check.call(not crosshair.locked, "set_locked(false) restores it")

	# The reticle state, the charge arc and the cooldown dim (Phase 4, D-13).
	crosshair.set_state(Targeting.State.VALID)
	check.call(crosshair.state == Targeting.State.VALID and crosshair.locked, "set_state(VALID) switches to the lock colour and keeps locked true")
	crosshair.set_state(Targeting.State.VALID_BIG)
	check.call(crosshair.state == Targeting.State.VALID_BIG, "set_state(VALID_BIG) changes the state")
	crosshair.set_state(Targeting.State.INVALID)
	check.call(crosshair.state == Targeting.State.INVALID and not crosshair.locked, "set_state(INVALID) changes the state and unlocks")
	crosshair.set_state(Targeting.State.NONE)
	check.call(crosshair.state == Targeting.State.NONE and not crosshair.locked, "set_state(NONE) is the white reticle")
	crosshair.set_charge(0.5)
	check.call(is_equal_approx(crosshair.charge, 0.5), "set_charge(0.5) stores the charge ratio")
	crosshair.set_charge(2.0)
	check.call(is_equal_approx(crosshair.charge, 1.0), "set_charge clamps to 1.0")
	crosshair.set_charge(0.0)
	crosshair.set_cooldown_dim(true)
	crosshair.set_cooldown_dim(false)
	await tree.process_frame
	check.call(crosshair.visible, "the reticle is still on after every state change")

	crosshair.free()
	await _check_loader_ring(tree, check)


# Plan 05-02 (D-14): while the Loader holds, a double ring turns counter-clockwise (the angle decreases), it is turquoise with a full
# core and the empty colour without one, and it never shows outside the hold.
func _check_loader_ring(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 0.0))
	var ring: Crosshair = (load(CROSSHAIR_SCENE) as PackedScene).instantiate() as Crosshair
	tree.root.add_child(ring)
	await Fixtures.wait_physics(tree, 10)
	check.call(not ring.loader_ring_visible, "the Loader ring is hidden before a hold")
	Fixtures.set_energy(player, 25.0)
	Input.action_press(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return player.loader_active(), 6)
	await Fixtures.wait_process(tree, 3)
	check.call(ring.loader_ring_visible, "the Loader ring is visible while the Loader holds")
	var first: float = ring.loader_ring_angle
	await Fixtures.wait_process(tree, 5)
	var second: float = ring.loader_ring_angle
	check.call(second < first, "the ring angle decreases, so it turns counter-clockwise (%.3f -> %.3f)" % [first, second])
	check.call(ring.loader_ring_speed_deg > 0.0, "the ring speed is positive; the shot arc stays clockwise (start at the top, angle increases)")
	check.call(ring.loader_ring_tint == ring.lock_color, "a full core draws the ring in the turquoise lock colour")
	check.call(ring.loader_ring_hold > 0.0 and ring.loader_ring_hold <= 1.0, "the inner ring fills with the hold time (%.2f)" % ring.loader_ring_hold)
	Input.action_release(&"loader")
	await Fixtures.wait_until(tree, func() -> bool: return not player.loader_active(), 8)
	await Fixtures.wait_process(tree, 3)
	check.call(not ring.loader_ring_visible, "the ring is hidden again after the release")
	# Without a core the ring is grey.
	Fixtures.restore_time()
	await Fixtures.wait_physics(tree, 80)
	Fixtures.set_energy(player, 0.0)
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
