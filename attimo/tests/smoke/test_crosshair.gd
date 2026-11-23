extends RefCounted
## CAM-02 / D-15 / T-03-09: the reticle is always visible, the goggle HUD (hud_visible) follows aim_changed, it never takes
## mouse input, covers the full screen rect and draws below the debug overlays (layers 100-102). It carries a reserved
## lock state for Phase 4.

const CROSSHAIR_SCENE: String = "res://scenes/ui/crosshair.tscn"
const MAX_LAYER: int = 99


func run(tree: SceneTree, check: Callable) -> void:
	var bus: Node = tree.root.get_node("EventBus")
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

	check.call(crosshair.visible and not crosshair.hud_visible, "the reticle is always on and the goggle HUD is off after one process frame (D-01)")
	bus.aim_changed.emit(true)
	check.call(crosshair.visible and crosshair.hud_visible, "aim_changed(true) switches the goggle HUD on, the reticle stays visible")
	await tree.process_frame
	bus.aim_changed.emit(false)
	check.call(crosshair.visible and not crosshair.hud_visible, "aim_changed(false) switches the goggle HUD off, the reticle stays visible")

	var reticle: Control = crosshair.get_node("Reticle") as Control
	check.call(reticle.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the Reticle ignores the mouse (T-03-09)")
	check.call(is_equal_approx(reticle.anchor_right, 1.0) and is_equal_approx(reticle.anchor_bottom, 1.0), "the Reticle covers the full rect")
	check.call(crosshair.layer >= 1 and crosshair.layer <= MAX_LAYER, "the layer %d is below the debug overlays (100-102)" % crosshair.layer)

	check.call(not crosshair.locked, "the crosshair starts unlocked")
	crosshair.set_locked(true)
	check.call(crosshair.locked, "set_locked(true) stores the lock state")
	crosshair.set_locked(false)
	check.call(not crosshair.locked, "set_locked(false) restores it")

	# Goggle HUD (Phase 4, D-13): the reticle state, the charge arc and the module frame.
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
	crosshair.set_module_name("Fernauslöser")
	check.call(crosshair.module_name == "Fernauslöser", "set_module_name stores the name")
	bus.aim_changed.emit(true)
	await tree.process_frame
	bus.aim_changed.emit(false)
	check.call(crosshair.visible and not crosshair.hud_visible, "the goggle HUD is off again when aim ends (hud_visible false)")

	# Goggle lens overlay: hidden without aim, visible and fully open shortly after aim starts, ignores the mouse, gone again
	# after aim ends. The brass plate and the gear need no state beyond the module name.
	var lens: ColorRect = crosshair.get_node_or_null("Lens") as ColorRect
	check.call(lens != null, "the goggle lens overlay exists")
	if lens != null:
		check.call(lens.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the lens overlay ignores the mouse")
		for _i: int in 30:
			await tree.process_frame
		check.call(not lens.visible, "the lens overlay is hidden without aim")
		bus.aim_changed.emit(true)
		for _i: int in 30:
			await tree.process_frame
		check.call(lens.visible, "the lens overlay is shown while aiming")
		bus.aim_changed.emit(false)
		for _i: int in 30:
			await tree.process_frame
		check.call(not lens.visible, "the lens overlay is hidden again after aim ends")

	crosshair.free()
