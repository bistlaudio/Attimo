extends RefCounted
## ENRG-02 / D-07, D-08, D-11, D-16, D-42, D-44: the Extractor drains an energy source (capsule +3 steps quickly, broken machine +5 in about 2 s) into the
## arm. It needs hand_extract_range and hand_extract_angle, never overfills the arm (the source keeps the rest), goes dark when empty
## and refills after respawn_time (0 never; reset() at once). Module keys 1 and 2 equip, the wheel skips the debug module.

const Fixtures := preload("res://tests/fixtures.gd")

const CAPSULE_SCENE: String = "res://scenes/kit/energy/energy_capsule.tscn"
const MACHINE_SCENE: String = "res://scenes/kit/energy/broken_machine.tscn"
const GLOW_ON: String = "res://resources/mechanisms/glow_energy.tres"
const GLOW_OFF: String = "res://resources/mechanisms/glow_off.tres"
const SHIPPED_TPS: int = 60
const BEAM_SETTLE_FRAMES: int = 16

var _nodes: Array[Node] = []
var _player: PlayerController
var _rig: CameraRig
var _hand: HandController
var _emptied: Array = []
var _gained: Array = []
var _bus: Node


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	_bus = tree.root.get_node("EventBus")
	await _scenario_capsule(tree, check)
	await _scenario_limits(tree, check)
	await _scenario_full_arm(tree, check)
	await _scenario_respawn(tree, check)
	await _scenario_machine(tree, check)


func _on_emptied(_position: Vector3, amount: int) -> void:
	_emptied.append(amount)


func _on_gained(amount: int, source: StringName) -> void:
	_gained.append({"amount": amount, "source": source})


func _begin(tree: SceneTree) -> void:
	_nodes.clear()
	_emptied.clear()
	_gained.clear()
	_nodes.append(Fixtures.spawn_floor(tree.root, Vector3(200.0, 1.0, 200.0)))
	_player = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	_nodes.append(_player)
	_rig = Fixtures.spawn_camera_rig(tree.root, _player)
	_nodes.append(_rig)
	_rig.pitch = 0.0
	_hand = _player.get_node("HandController") as HandController
	_bus.connect(&"energy_source_emptied", _on_emptied)
	_bus.connect(&"energy_gained", _on_gained)
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.wait_process(tree, 3)
	await Fixtures.wait_physics(tree, 3)
	await Fixtures.wait_process(tree, 3)


func _end(tree: SceneTree) -> void:
	Input.action_release(&"use_hand")
	Input.action_release(&"module_2")
	if _bus.is_connected(&"energy_source_emptied", _on_emptied):
		_bus.disconnect(&"energy_source_emptied", _on_emptied)
	if _bus.is_connected(&"energy_gained", _on_gained):
		_bus.disconnect(&"energy_gained", _on_gained)
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
	await tree.process_frame


## The point on the crosshair line whose distance from the player origin is `distance`, turned by `yaw_deg` about the camera.
func _line_point(distance: float, yaw_deg: float = 0.0) -> Vector3:
	var camera: Camera3D = _rig.camera
	var forward: Vector3 = -camera.global_basis.z.normalized()
	var start: Vector3 = CameraRig.aim_ray_start(camera.global_position, forward, _rig.global_position)
	var best: Vector3 = start
	var best_error: float = INF
	var t: float = 0.0
	while t < 80.0:
		var point: Vector3 = start + forward * t
		var error: float = absf(point.distance_to(_player.global_position) - distance)
		if error < best_error:
			best_error = error
			best = point
		t += 0.02
	return camera.global_position + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * (best - camera.global_position)


## An energy source scene whose Core marker sits at `point`.
func _place(tree: SceneTree, path: String, point: Vector3) -> EnergySource:
	var source: EnergySource = Fixtures.spawn_scene(tree.root, path, Vector3(300.0, 0.0, 300.0)) as EnergySource
	source.global_position += point - source.core.global_position
	_nodes.append(source)
	return source


func _equip_extractor(tree: SceneTree) -> void:
	await Fixtures.tap_action(tree, &"module_2", 2)
	await Fixtures.wait_physics(tree, 2)


## The ExtractorBeam mesh of the hand presentation (D-44), or null.
func _beam() -> MeshInstance3D:
	return _player.find_child("ExtractorBeam", true, false) as MeshInstance3D


## Beam length in m: the mesh height times the scale along its own y axis.
func _beam_length(beam: MeshInstance3D) -> float:
	var cylinder: CylinderMesh = beam.mesh as CylinderMesh
	if cylinder == null:
		return -1.0
	return cylinder.height * beam.global_basis.y.length()


func _palm_point() -> Vector3:
	var palm: Node3D = _player.find_child("Palm", true, false) as Node3D
	return palm.global_position if palm != null else Vector3.ZERO


func _lens(source: EnergySource) -> MeshInstance3D:
	return source.glow_meshes[0]


func _scenario_capsule(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	check.call(ResourceLoader.exists(CAPSULE_SCENE), "energy_capsule.tscn exists")
	var capsule: EnergySource = _place(tree, CAPSULE_SCENE, _line_point(2.5))
	capsule.respawn_time = 2.0
	check.call(capsule.is_in_group(&"energy_source") and capsule.is_in_group(&"mechanism"), "(1) the capsule joins the groups energy_source and mechanism")
	check.call(capsule.amount == 3 and is_equal_approx(capsule.step_interval, 0.15), "(1) the capsule holds 3 steps, one per 0.15 s")
	check.call(_lens(capsule).material_override == load(GLOW_ON), "(1) a full capsule glows with glow_energy.tres")
	Fixtures.set_energy(_player, 3)
	await _equip_extractor(tree)
	check.call(_hand.active_def.id == &"extractor", "(1) key 2 equips the Extractor")
	var before: int = _player.arm_energy.value
	check.call(_beam() != null and not _beam().visible, "(1) the ExtractorBeam exists and is hidden before the drain (D-44)")
	Input.action_press(&"use_hand")
	# Long enough for the arm to settle at its raised pose (the palm moves while the layer blends), still inside the 0.45 s drain.
	await Fixtures.wait_physics(tree, BEAM_SETTLE_FRAMES)
	await Fixtures.wait_process(tree, 3)
	var beam: MeshInstance3D = _beam()
	if beam != null:
		var error: float = absf(_beam_length(beam) - _palm_point().distance_to(capsule.target_point()))
		check.call(beam.visible and error < 0.05, "(1) the beam is visible while draining and as long as hand to source (error %.3f m)" % error)
		check.call(beam.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "(1) the beam casts no shadow")
	await Fixtures.wait_physics(tree, ceili(0.6 * SHIPPED_TPS) - BEAM_SETTLE_FRAMES)
	Input.action_release(&"use_hand")
	await Fixtures.wait_physics(tree, 3)
	await Fixtures.wait_process(tree, 3)
	check.call(beam != null and not beam.visible, "(1) the beam is hidden after the release and the empty source")
	var gained: int = _player.arm_energy.value - before
	check.call(gained == 3, "(1) holding left click 0.6 s gives +3 steps (got %d)" % gained)
	check.call(not capsule.is_available(), "(1) the capsule reports empty")
	check.call(_lens(capsule).material_override == load(GLOW_OFF), "(1) the empty capsule is dark (glow_off.tres)")
	check.call(_emptied.size() == 1, "(1) energy_source_emptied fired once (%d)" % _emptied.size())
	var total: int = 0
	var count: int = 0
	for fact: Dictionary in _gained:
		if fact["source"] == &"extractor":
			total += int(fact["amount"])
			count += 1
	check.call(count == 1 and total == 3, "(1) energy_gained(3, extractor) fired once (%d times, %d)" % [count, total])
	var mid: int = _player.arm_energy.value
	await Fixtures.hold_action(tree, &"use_hand", 0.5)
	await Fixtures.wait_physics(tree, 3)
	check.call(_player.arm_energy.value == mid, "(1) an empty capsule gives nothing more")
	await Fixtures.wait_physics(tree, 120 + 3)
	check.call(capsule.is_available(), "(1) with respawn_time 2 s the capsule is available again")
	check.call(_lens(capsule).material_override == load(GLOW_ON), "(1) the refilled capsule glows again")
	await _end(tree)


func _scenario_limits(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var far: EnergySource = _place(tree, CAPSULE_SCENE, _line_point(6.0))
	Fixtures.set_energy(_player, 3)
	await _equip_extractor(tree)
	await Fixtures.hold_action(tree, &"use_hand", 0.6)
	await Fixtures.wait_physics(tree, 3)
	check.call(_player.arm_energy.value == 3 and far.is_available(), "(2) a capsule 6 m away (range 4 m) gives nothing")
	far.queue_free()
	await Fixtures.wait_physics(tree, 4)
	var off: EnergySource = _place(tree, CAPSULE_SCENE, _line_point(2.5, 60.0))
	await Fixtures.wait_physics(tree, 3)
	await Fixtures.hold_action(tree, &"use_hand", 0.6)
	await Fixtures.wait_physics(tree, 3)
	check.call(_player.arm_energy.value == 3 and off.is_available(), "(2) a capsule 60 degrees off the crosshair gives nothing")
	check.call(_gained.is_empty(), "(2) no energy_gained fact without a drain")
	await _end(tree)


func _scenario_full_arm(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var capsule: EnergySource = _place(tree, CAPSULE_SCENE, _line_point(2.5))
	Fixtures.set_energy(_player, 11)
	await _equip_extractor(tree)
	await Fixtures.hold_action(tree, &"use_hand", 0.6)
	await Fixtures.wait_physics(tree, 3)
	check.call(_player.arm_energy.value == 12, "(3) the arm stops at 12 (got %d)" % _player.arm_energy.value)
	check.call(_beam() != null and not _beam().visible, "(3) the beam is hidden while the arm is full")
	check.call(capsule.is_available() and capsule.remaining == 2, "(3) the capsule keeps the remaining 2 steps, it is not emptied (%d)" % capsule.remaining)
	check.call(_emptied.is_empty(), "(3) no energy_source_emptied for a capsule that kept steps")
	await _end(tree)


func _scenario_respawn(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var capsule: EnergySource = _place(tree, CAPSULE_SCENE, _line_point(2.5))
	capsule.respawn_time = 0.0
	Fixtures.set_energy(_player, 0)
	await _equip_extractor(tree)
	await Fixtures.hold_action(tree, &"use_hand", 0.6)
	await Fixtures.wait_physics(tree, 3)
	check.call(not capsule.is_available(), "(4) the capsule was drained")
	await Fixtures.wait_physics(tree, 600)
	check.call(not capsule.is_available(), "(4) respawn_time 0 never refills within 10 s")
	capsule.reset()
	check.call(capsule.is_available() and _lens(capsule).material_override == load(GLOW_ON), "(4) reset() refills at once and the glow returns")
	capsule.remaining = 0
	capsule.empty = true
	check.call(capsule.take_step() == 0 and not capsule.is_available(), "(4) an empty source gives no step")
	capsule.reset()
	await _end(tree)


func _scenario_machine(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	check.call(ResourceLoader.exists(MACHINE_SCENE), "broken_machine.tscn exists")
	if not ResourceLoader.exists(MACHINE_SCENE):
		await _end(tree)
		return
	var machine: EnergySource = _place(tree, MACHINE_SCENE, _line_point(2.5))
	check.call(machine.amount == 5 and is_equal_approx(machine.step_interval, 0.4), "(5) the broken machine holds 5 steps, one per 0.4 s")
	Fixtures.set_energy(_player, 0)
	await _equip_extractor(tree)
	await Fixtures.hold_action(tree, &"use_hand", 2.2)
	await Fixtures.wait_physics(tree, 3)
	check.call(_player.arm_energy.value == 5, "(5) the machine gives +5 steps after 2 s (got %d)" % _player.arm_energy.value)
	check.call(not machine.is_available() and _lens(machine).material_override == load(GLOW_OFF), "(5) the machine goes dark")
	await _end(tree)
