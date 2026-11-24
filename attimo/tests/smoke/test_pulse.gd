extends RefCounted
## HAND-03 / D-01..D-07, D-15, D-16: use_hand (tap or hold) fires the Fernausloeser pulse at the crosshair from the hip, no aim hold.
## End to end: pulse -> Lever -> Zahnrad-Tor. Every scenario builds its own world, releases every action and frees it.

const Fixtures := preload("res://tests/fixtures.gd")

const LEVER_SCENE: String = "res://scenes/mechanisms/lever.tscn"
const GATE_SCENE: String = "res://scenes/mechanisms/gear_gate.tscn"
const SHIPPED_TPS: int = 60
## Hold time above the 0.4 s charge threshold.
const BIG_HOLD_SECONDS: float = 0.5

var _nodes: Array[Node] = []
var _player: PlayerController
var _rig: CameraRig
var _events: Array = []
var _bus: Node


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	if not ResourceLoader.exists(LEVER_SCENE) or not ResourceLoader.exists(GATE_SCENE):
		check.call(false, "lever.tscn and gear_gate.tscn exist")
		return
	_bus = tree.root.get_node("EventBus")
	await _scenario_end_to_end(tree, check)
	await _scenario_big_pulse(tree, check)
	await _scenario_cooldown(tree, check)
	await _scenario_range(tree, check)
	await _scenario_occlusion(tree, check)
	await _scenario_empty_sky(tree, check)


func _on_pulse(origin: Vector3, point: Vector3, size: int, valid: bool) -> void:
	_events.append({"origin": origin, "point": point, "size": size, "valid": valid})


## Floor, player, camera rig, and a short settle.
func _begin(tree: SceneTree) -> void:
	_events.clear()
	_nodes.clear()
	_nodes.append(Fixtures.spawn_floor(tree.root, Vector3(200.0, 1.0, 200.0)))
	_player = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	_nodes.append(_player)
	_rig = Fixtures.spawn_camera_rig(tree.root, _player)
	_nodes.append(_rig)
	_rig.pitch = 0.0
	_bus.connect(&"pulse_fired", _on_pulse)
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.wait_process(tree, 3)
	await Fixtures.wait_physics(tree, 3)
	await Fixtures.wait_process(tree, 3)


func _end(tree: SceneTree, extra: Array[Node] = []) -> void:
	Input.action_release(&"use_hand")
	if _bus.is_connected(&"pulse_fired", _on_pulse):
		_bus.disconnect(&"pulse_fired", _on_pulse)
	for node: Node in extra:
		if is_instance_valid(node):
			node.queue_free()
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
	await tree.process_frame


## The point on the crosshair line whose distance from the player origin is `distance`.
func _line_point(distance: float) -> Vector3:
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
	return best


## A lever whose hit body sits on the crosshair line `distance` from the player. A gate listens to it.
func _place_lever(tree: SceneTree, distance: float) -> Lever:
	var lever: Lever = Fixtures.spawn_scene(tree.root, LEVER_SCENE, Vector3.ZERO) as Lever
	var interactable: Interactable = lever.get_node("Interactable") as Interactable
	var offset: Vector3 = interactable.hit_body.global_position - lever.global_position
	lever.global_position = _line_point(distance) - offset
	_nodes.append(lever)
	return lever


func _place_gate(tree: SceneTree, lever: Lever) -> GearGate:
	var scene: PackedScene = load(GATE_SCENE) as PackedScene
	var gate: GearGate = scene.instantiate() as GearGate
	gate.source = lever
	gate.position = Vector3(30.0, 0.0, 30.0)
	tree.root.add_child(gate)
	_nodes.append(gate)
	return gate


func _scenario_end_to_end(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var lever: Lever = _place_lever(tree, 8.0)
	var gate: GearGate = _place_gate(tree, lever)
	await Fixtures.wait_physics(tree, 3)
	check.call(not lever.is_active and not gate.is_open(), "the lever starts off and the gate closed")
	await Fixtures.tap_action(tree, &"use_hand", 2)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return lever.is_active, 2)
	check.call(waited >= 0, "a small tap at the lever 8 m away toggles it within 2 ticks of the release (waited %d)" % waited)
	check.call(_events.size() == 1, "exactly one pulse_fired (got %d)" % _events.size())
	if _events.size() == 1:
		check.call(int(_events[0]["size"]) == int(PulseHit.Size.SMALL) and bool(_events[0]["valid"]), "the pulse is small and valid")
	waited = await Fixtures.wait_until(tree, func() -> bool: return gate.is_open(), 30)
	check.call(waited >= 0, "the Zahnrad-Tor is open within 0.5 s (waited %d)" % waited)
	await _end(tree)


func _scenario_big_pulse(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var lever: Lever = _place_lever(tree, 8.0)
	await Fixtures.wait_physics(tree, 2)
	await Fixtures.hold_action(tree, &"use_hand", BIG_HOLD_SECONDS)
	await Fixtures.wait_physics(tree, 3)
	check.call(_events.size() == 1, "holding use_hand 0.5 s fires once, on release (got %d)" % _events.size())
	if _events.size() == 1:
		check.call(int(_events[0]["size"]) == int(PulseHit.Size.BIG), "holding past the threshold fires a big pulse")
	check.call(lever.is_active, "the big pulse toggled the lever")
	await _end(tree)


func _scenario_cooldown(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var lever: Lever = _place_lever(tree, 8.0)
	await Fixtures.tap_action(tree, &"use_hand", 2)
	await Fixtures.wait_physics(tree, 4)
	await Fixtures.tap_action(tree, &"use_hand", 2)
	await Fixtures.wait_physics(tree, 3)
	check.call(_events.size() == 1, "two taps 0.1 s apart fire once (cooldown 0.25 s, got %d)" % _events.size())
	check.call(lever.is_active, "the first shot toggled the lever once")
	await _end(tree)


func _scenario_range(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var lever: Lever = _place_lever(tree, 18.0)
	await Fixtures.wait_physics(tree, 2)
	await Fixtures.tap_action(tree, &"use_hand", 2)
	await Fixtures.wait_physics(tree, 4)
	check.call(_events.size() == 1 and not bool(_events[0]["valid"]), "a small tap at 18 m fires but is not valid (range 15 m)")
	check.call(not lever.is_active, "the lever 18 m away ignores a small pulse")
	await Fixtures.wait_physics(tree, 20)
	await Fixtures.hold_action(tree, &"use_hand", BIG_HOLD_SECONDS)
	await Fixtures.wait_physics(tree, 3)
	check.call(lever.is_active, "a big pulse reaches the lever 18 m away (range 25 m)")
	await _end(tree)


func _scenario_occlusion(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var lever: Lever = _place_lever(tree, 8.0)
	var wall: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(3.0, 3.0, 3.0), _line_point(4.0))
	_nodes.append(wall)
	await Fixtures.wait_physics(tree, 3)
	await Fixtures.tap_action(tree, &"use_hand", 2)
	await Fixtures.wait_physics(tree, 4)
	check.call(not lever.is_active, "a World wall in front of the lever blocks the shot")
	check.call(_events.size() == 1 and not bool(_events[0]["valid"]), "the blocked shot still fires with hit_valid false")
	await _end(tree)


func _scenario_empty_sky(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	await Fixtures.tap_action(tree, &"use_hand", 2)
	await Fixtures.wait_physics(tree, 4)
	check.call(_events.size() == 1 and not bool(_events[0]["valid"]), "a shot into empty space fires with hit_valid false")
	await _end(tree)
