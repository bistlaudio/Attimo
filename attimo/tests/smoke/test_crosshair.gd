extends RefCounted
## CAM-02 / D-15 / T-03-09: the crosshair is hidden at start, shown exactly while aim_changed(true) holds, never takes
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

	check.call(not crosshair.visible, "the crosshair is hidden after one process frame")
	bus.aim_changed.emit(true)
	check.call(crosshair.visible, "aim_changed(true) shows the crosshair")
	await tree.process_frame
	bus.aim_changed.emit(false)
	check.call(not crosshair.visible, "aim_changed(false) hides the crosshair")

	var reticle: Control = crosshair.get_node("Reticle") as Control
	check.call(reticle.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the Reticle ignores the mouse (T-03-09)")
	check.call(is_equal_approx(reticle.anchor_right, 1.0) and is_equal_approx(reticle.anchor_bottom, 1.0), "the Reticle covers the full rect")
	check.call(crosshair.layer >= 1 and crosshair.layer <= MAX_LAYER, "the layer %d is below the debug overlays (100-102)" % crosshair.layer)

	check.call(not crosshair.locked, "the crosshair starts unlocked")
	crosshair.set_locked(true)
	check.call(crosshair.locked, "set_locked(true) stores the lock state")
	crosshair.set_locked(false)
	check.call(not crosshair.locked, "set_locked(false) restores it")

	crosshair.free()
