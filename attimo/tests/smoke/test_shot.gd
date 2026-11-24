extends RefCounted
## HAND-03 / D-01..D-07, D-15, D-17, D-18, D-24: use_hand fires the shot from the hip as a flying, energy-priced projectile (never a beam).
## A tap costs 10, holding past the tap time drains up to 25 (Samus-style charge), below 10 the shot is refused. The PulseHit carries the
## energy spent and a size derived from it (BIG from 25), range grows with the charge, at most 4 projectiles live. End to end: shot -> Lever -> Gate.
## Every scenario builds its own world, releases every action and frees it.

const Fixtures := preload("res://tests/fixtures.gd")

const LEVER_SCENE: String = "res://scenes/mechanisms/lever.tscn"
const VALVE_SCENE: String = "res://scenes/mechanisms/valve.tscn"
const GATE_SCENE: String = "res://scenes/mechanisms/gear_gate.tscn"
const SHIPPED_TPS: int = 60

var _nodes: Array[Node] = []
var _player: PlayerController
var _rig: CameraRig
var _hand: HandController
var _pulses: Array = []
var _fired: Array = []
var _refused: Array = []
var _spent: float = 0.0
var _spent_facts: int = 0
var _full: int = 0
var _hits: Array = []
var _bus: Node


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	if not ResourceLoader.exists(LEVER_SCENE) or not ResourceLoader.exists(GATE_SCENE) or not ResourceLoader.exists(VALVE_SCENE):
		check.call(false, "lever, valve and gear_gate scenes exist")
		return
	_bus = tree.root.get_node("EventBus")
	check.call(PulseHit.size_for_energy(24.9, 25.0) == PulseHit.Size.SMALL, "(0) size_for_energy(24.9, 25.0) is SMALL")
	check.call(PulseHit.size_for_energy(25.0, 25.0) == PulseHit.Size.BIG, "(0) size_for_energy(25.0, 25.0) is BIG")
	check.call(PulseHit.size_for_energy(10.0, 25.0) == PulseHit.Size.SMALL, "(0) a tap is SMALL")
	await _scenario_tap(tree, check)
	await _scenario_refuse(tree, check)
	await _scenario_hold(tree, check)
	await _scenario_dry(tree, check)
	await _scenario_cooldown(tree, check)
	await _scenario_range(tree, check)
	await _scenario_cap(tree, check)
	await _scenario_occlusion(tree, check)
	await _scenario_empty_sky(tree, check)
	await _scenario_bend(tree, check)
	await _scenario_switch_refund(tree, check)


func _on_pulse(origin: Vector3, point: Vector3, size: int, valid: bool) -> void:
	_pulses.append({"origin": origin, "point": point, "size": size, "valid": valid})


func _on_fired(_origin: Vector3, _direction: Vector3, energy: float) -> void:
	_fired.append(energy)


func _on_refused(reason: StringName, needed: float) -> void:
	_refused.append({"reason": reason, "needed": needed})


func _on_spent(amount: float, reason: StringName) -> void:
	if reason == &"shot":
		_spent += amount
		_spent_facts += 1


func _on_full(_position: Vector3) -> void:
	_full += 1


func _on_hit(hit: PulseHit) -> void:
	_hits.append({"energy": hit.energy, "size": int(hit.size)})


## Floor, player, camera rig, and a short settle.
func _begin(tree: SceneTree) -> void:
	_pulses.clear()
	_fired.clear()
	_refused.clear()
	_hits.clear()
	_spent = 0.0
	_spent_facts = 0
	_full = 0
	_nodes.clear()
	_nodes.append(Fixtures.spawn_floor(tree.root, Vector3(200.0, 1.0, 200.0)))
	_player = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	_nodes.append(_player)
	_rig = Fixtures.spawn_camera_rig(tree.root, _player)
	_nodes.append(_rig)
	_rig.pitch = 0.0
	_hand = _player.get_node("HandController") as HandController
	_bus.connect(&"pulse_fired", _on_pulse)
	_bus.connect(&"shot_fired", _on_fired)
	_bus.connect(&"energy_refused", _on_refused)
	_bus.connect(&"energy_spent", _on_spent)
	_bus.connect(&"shot_fully_charged", _on_full)
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.wait_process(tree, 3)
	await Fixtures.wait_physics(tree, 3)
	await Fixtures.wait_process(tree, 3)


func _end(tree: SceneTree) -> void:
	Input.action_release(&"use_hand")
	Input.action_release(&"interact")
	for pair: Array in [[&"pulse_fired", _on_pulse], [&"shot_fired", _on_fired], [&"energy_refused", _on_refused], [&"energy_spent", _on_spent], [&"shot_fully_charged", _on_full]]:
		if _bus.is_connected(pair[0], pair[1]):
			_bus.disconnect(pair[0], pair[1])
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	for node: Node in tree.get_nodes_in_group(&"shot_projectile"):
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


## A mechanism scene whose hit body sits on the crosshair line `distance` from the player.
func _place(tree: SceneTree, path: String, distance: float) -> Node3D:
	var node: Node3D = Fixtures.spawn_scene(tree.root, path, Vector3.ZERO)
	var interactable: Interactable = node.get_node("Interactable") as Interactable
	var offset: Vector3 = interactable.hit_body.global_position - node.global_position
	node.global_position = _line_point(distance) - offset
	interactable.triggered.connect(_on_hit)
	_nodes.append(node)
	return node


func _place_gate(tree: SceneTree, lever: Lever) -> GearGate:
	var gate: GearGate = (load(GATE_SCENE) as PackedScene).instantiate() as GearGate
	gate.source = lever
	gate.position = Vector3(30.0, 0.0, 30.0)
	tree.root.add_child(gate)
	_nodes.append(gate)
	return gate


func _projectiles(tree: SceneTree) -> int:
	var count: int = 0
	for node: Node in tree.get_nodes_in_group(&"shot_projectile"):
		if not node.is_queued_for_deletion():
			count += 1
	return count


func _scenario_tap(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var lever: Lever = _place(tree, LEVER_SCENE, 8.0) as Lever
	var gate: GearGate = _place_gate(tree, lever)
	await Fixtures.wait_physics(tree, 3)
	Fixtures.set_energy(_player, 10.0)
	check.call(not lever.is_active and not gate.is_open(), "(1) the lever starts off and the gate closed")
	await Fixtures.tap_action(tree, &"use_hand", 2)
	await Fixtures.wait_physics(tree, 1)
	check.call(_fired.size() == 1 and is_equal_approx(_fired[0], 10.0), "(1) a tap at exactly 10.0 energy fires one shot_fired of 10.0 (got %s)" % str(_fired))
	check.call(_projectiles(tree) == 1, "(1) one ShotProjectile is flying (%d)" % _projectiles(tree))
	check.call(is_zero_approx(_player.arm_energy.value), "(1) the tap leaves 0.0 (got %.3f)" % _player.arm_energy.value)
	check.call(not lever.is_active, "(1) the shot is a flying ball: the lever does not toggle on the release tick")
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return lever.is_active, 60)
	check.call(waited >= 0, "(1) the shot reaches the lever 8 m away and toggles it (waited %d)" % waited)
	check.call(_pulses.size() == 1 and int(_pulses[0]["size"]) == int(PulseHit.Size.SMALL) and bool(_pulses[0]["valid"]), "(1) pulse_fired at impact: SMALL and valid (%s)" % str(_pulses))
	check.call(_hits.size() == 1 and is_equal_approx(float(_hits[0]["energy"]), 10.0), "(1) PulseHit.energy is the energy spent (%s)" % str(_hits))
	waited = await Fixtures.wait_until(tree, func() -> bool: return gate.is_open(), 40)
	check.call(waited >= 0, "(1) the Zahnrad-Tor opens (waited %d)" % waited)
	await Fixtures.wait_physics(tree, 3)
	check.call(_projectiles(tree) == 0, "(1) the projectile freed itself at the hit")
	await _end(tree)


func _scenario_refuse(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var lever: Lever = _place(tree, LEVER_SCENE, 8.0) as Lever
	await Fixtures.wait_physics(tree, 3)
	Fixtures.set_energy(_player, 9.99)
	await Fixtures.tap_action(tree, &"use_hand", 2)
	await Fixtures.wait_physics(tree, 3)
	check.call(_projectiles(tree) == 0 and _fired.is_empty(), "(2) at 9.99 energy nothing spawns")
	check.call(_refused.size() == 1 and _refused[0]["reason"] == &"shot" and is_equal_approx(float(_refused[0]["needed"]), 10.0), "(2) energy_refused(shot, 10.0) fired once (%s)" % str(_refused))
	check.call(is_equal_approx(_player.arm_energy.value, 9.99), "(2) the energy stays 9.99 (got %.3f)" % _player.arm_energy.value)
	await Fixtures.wait_physics(tree, 30)
	check.call(not lever.is_active, "(2) the lever did not toggle")
	await _end(tree)
	# Near contact stays free at any energy (D-18).
	await _begin(tree)
	var near: Lever = Fixtures.spawn_scene(tree.root, LEVER_SCENE, Vector3(0.0, 0.0, 1.2)) as Lever
	_nodes.append(near)
	Fixtures.set_energy(_player, 0.0)
	await Fixtures.wait_physics(tree, 4)
	await Fixtures.tap_action(tree, &"interact", 4)
	await Fixtures.wait_physics(tree, 2)
	check.call(near.is_active, "(2) near contact with E toggles a lever at energy 0 (D-18)")
	await _end(tree)


func _scenario_hold(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var valve: Node3D = _place(tree, VALVE_SCENE, 8.0)
	await Fixtures.wait_physics(tree, 3)
	Fixtures.set_energy(_player, 100.0)
	await Fixtures.hold_action(tree, &"use_hand", 1.0)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return not _pulses.is_empty(), 60)
	check.call(waited >= 0 and _fired.size() == 1, "(3) holding fires once, on release")
	check.call(absf(_spent - 25.0) <= 0.2, "(3) a full hold spends 25 in total (got %.2f)" % _spent)
	check.call(_spent_facts == 2, "(3) the hold reports two energy_spent(shot) facts, the tap cost and the charge total, never one per tick (got %d)" % _spent_facts)
	check.call(_full == 1, "(3) shot_fully_charged fired exactly once (%d)" % _full)
	check.call(_hits.size() == 1 and absf(float(_hits[0]["energy"]) - 25.0) <= 0.2 and int(_hits[0]["size"]) == int(PulseHit.Size.BIG), "(3) the payload is 25 energy and BIG (%s)" % str(_hits))
	check.call(bool(valve.get("is_active")), "(3) the valve (min pulse BIG) turns with a full charge")
	await _end(tree)

	await _begin(tree)
	valve = _place(tree, VALVE_SCENE, 8.0)
	await Fixtures.wait_physics(tree, 3)
	Fixtures.set_energy(_player, 100.0)
	await Fixtures.hold_action(tree, &"use_hand", 0.4)
	await Fixtures.wait_until(tree, func() -> bool: return not _pulses.is_empty(), 60)
	check.call(_spent > 10.5 and _spent < 24.0, "(3) a hold of 0.4 s spends between 10 and 25 (got %.2f)" % _spent)
	check.call(_full == 0, "(3) a partial hold sends no full-charge tell")
	check.call(not bool(valve.get("is_active")) and _pulses.size() == 1 and not bool(_pulses[0]["valid"]), "(3) the valve rejects a partial shot (SMALL)")
	await _end(tree)


func _scenario_dry(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	Fixtures.set_energy(_player, 18.0)
	await Fixtures.hold_action(tree, &"use_hand", 1.0)
	await Fixtures.wait_physics(tree, 3)
	check.call(absf(_spent - 18.0) <= 0.2, "(4) a dry charge keeps what was spent: total 18 (got %.2f)" % _spent)
	check.call(_player.arm_energy.value < 0.2, "(4) the arm is empty (%.3f)" % _player.arm_energy.value)
	check.call(_full == 0 and _fired.size() == 1, "(4) it still fires once and never tells a full charge")
	await _end(tree)


func _scenario_cooldown(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	Fixtures.set_energy(_player, 100.0)
	await Fixtures.tap_action(tree, &"use_hand", 2)
	await Fixtures.wait_physics(tree, 4)
	await Fixtures.tap_action(tree, &"use_hand", 2)
	await Fixtures.wait_physics(tree, 3)
	check.call(_fired.size() == 1, "(5) two taps 0.1 s apart fire once (cooldown 0.25 s, got %d)" % _fired.size())
	check.call(is_equal_approx(_player.arm_energy.value, 90.0), "(5) the ignored second tap cost nothing (%.2f)" % _player.arm_energy.value)
	await _end(tree)


func _scenario_range(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var lever: Lever = _place(tree, LEVER_SCENE, 18.0) as Lever
	await Fixtures.wait_physics(tree, 2)
	Fixtures.set_energy(_player, 100.0)
	await Fixtures.tap_action(tree, &"use_hand", 2)
	await Fixtures.wait_until(tree, func() -> bool: return not _pulses.is_empty(), 90)
	check.call(_pulses.size() == 1 and not bool(_pulses[0]["valid"]), "(6) a tap at 18 m expires without a valid hit (range 15 m)")
	if _pulses.size() == 1:
		var travelled: float = (_pulses[0]["point"] as Vector3).distance_to(_pulses[0]["origin"] as Vector3)
		check.call(absf(travelled - _hand.hand_small_range) <= 0.5, "(6) the tap shot ends at the small range (%.2f m)" % travelled)
	check.call(not lever.is_active, "(6) the lever 18 m away ignores a tap")
	await Fixtures.wait_physics(tree, 20)
	_pulses.clear()
	await Fixtures.hold_action(tree, &"use_hand", 1.2)
	await Fixtures.wait_until(tree, func() -> bool: return not _pulses.is_empty(), 90)
	check.call(lever.is_active, "(6) a full shot reaches the lever 18 m away (range 25 m)")
	await _end(tree)
	# A full shot into empty space ends at the big range.
	await _begin(tree)
	Fixtures.set_energy(_player, 100.0)
	await Fixtures.hold_action(tree, &"use_hand", 1.2)
	await Fixtures.wait_until(tree, func() -> bool: return not _pulses.is_empty(), 120)
	check.call(_pulses.size() == 1 and not bool(_pulses[0]["valid"]), "(6) a full shot into the sky expires")
	if _pulses.size() == 1:
		var far: float = (_pulses[0]["point"] as Vector3).distance_to(_pulses[0]["origin"] as Vector3)
		check.call(absf(far - _hand.hand_big_range) <= 0.5, "(6) the full shot ends at the big range (%.2f m)" % far)
	await _end(tree)


func _scenario_cap(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var scene: PackedScene = load("res://scenes/hand/shot_projectile.tscn") as PackedScene
	for i: int in 6:
		var projectile: ShotProjectile = scene.instantiate() as ShotProjectile
		tree.root.add_child(projectile)
		projectile.setup(Vector3(0.0, 40.0 + float(i), 0.0), Vector3.UP, 10.0, 1.0, 500.0, null, 0.0, &"remote_trigger", 25.0, null)
	await Fixtures.wait_physics(tree, 2)
	check.call(_projectiles(tree) <= ShotProjectile.MAX_LIVE, "(7) six spawned projectiles leave at most %d alive (%d)" % [ShotProjectile.MAX_LIVE, _projectiles(tree)])
	for node: Node in tree.get_nodes_in_group(&"shot_projectile"):
		node.queue_free()
	await Fixtures.wait_physics(tree, 2)
	var bad: ShotProjectile = scene.instantiate() as ShotProjectile
	tree.root.add_child(bad)
	bad.setup(Vector3.ZERO, Vector3(NAN, 0.0, 1.0), 10.0, 40.0, 15.0, null, 0.0, &"remote_trigger", 25.0, null)
	await Fixtures.wait_physics(tree, 2)
	check.call(_projectiles(tree) == 0, "(7) a non-finite direction leaves no projectile")
	await _end(tree)


func _scenario_occlusion(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var lever: Lever = _place(tree, LEVER_SCENE, 8.0) as Lever
	_nodes.append(Fixtures.spawn_box(tree.root, Vector3(3.0, 3.0, 3.0), _line_point(4.0)))
	await Fixtures.wait_physics(tree, 3)
	Fixtures.set_energy(_player, 50.0)
	await Fixtures.tap_action(tree, &"use_hand", 2)
	await Fixtures.wait_until(tree, func() -> bool: return not _pulses.is_empty(), 60)
	check.call(not lever.is_active, "(8) a World wall in front of the lever blocks the shot")
	check.call(_pulses.size() == 1 and not bool(_pulses[0]["valid"]), "(8) the blocked shot ends with hit_valid false")
	await _end(tree)


func _scenario_empty_sky(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	Fixtures.set_energy(_player, 50.0)
	await Fixtures.tap_action(tree, &"use_hand", 2)
	await Fixtures.wait_until(tree, func() -> bool: return not _pulses.is_empty(), 90)
	check.call(_pulses.size() == 1 and not bool(_pulses[0]["valid"]), "(9) a shot into empty space ends with hit_valid false")
	await _end(tree)


## A lever 3 degrees off the crosshair is hit by the bending shot although the straight line misses it.
func _scenario_bend(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	_hand.hand_assist_angle = 7.0
	var lever: Lever = _place(tree, LEVER_SCENE, 10.0) as Lever
	var interactable: Interactable = lever.get_node("Interactable") as Interactable
	interactable.aim_point = null
	var camera: Camera3D = _rig.camera
	var here: Vector3 = interactable.hit_body.global_position
	lever.global_position += camera.global_position + Basis(Vector3.UP, deg_to_rad(4.0)) * (here - camera.global_position) - here
	await Fixtures.wait_physics(tree, 8)
	check.call(_hand.targeting.target == interactable, "(10) the lever 4 degrees off is the locked target")
	Fixtures.set_energy(_player, 50.0)
	await Fixtures.tap_action(tree, &"use_hand", 2)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return lever.is_active, 60)
	check.call(waited >= 0, "(10) the shot bends into the locked target (waited %d)" % waited)
	await _end(tree)


## CR-01: a module switch mid-charge fires no shot and gives every paid unit back (one energy_gained(shot_refund) fact).
func _scenario_switch_refund(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var refunds: Array = []
	var on_gained: Callable = func(amount: float, source: StringName) -> void:
		if source == &"shot_refund":
			refunds.append(amount)
	_bus.connect(&"energy_gained", on_gained)
	Fixtures.set_energy(_player, 60.0)
	Input.action_press(&"use_hand")
	await Fixtures.wait_physics(tree, ceili(0.4 * SHIPPED_TPS))
	var paid: float = 60.0 - _player.arm_energy.value
	check.call(paid > 10.5, "(11) the charge has paid more than the tap cost before the switch (%.2f)" % paid)
	check.call(_hand.equip(&"extractor"), "(11) the switch to the extractor succeeds mid-charge")
	Input.action_release(&"use_hand")
	await Fixtures.wait_physics(tree, 6)
	check.call(_fired.is_empty() and _projectiles(tree) == 0, "(11) the switch fires no shot (%d fired)" % _fired.size())
	check.call(absf(_player.arm_energy.value - 60.0) < 0.01, "(11) the paid energy is refunded: back at 60.0 (got %.3f)" % _player.arm_energy.value)
	check.call(refunds.size() == 1 and absf(float(refunds[0]) - paid) < 0.01, "(11) one energy_gained(%.2f, shot_refund) fact (got %s)" % [paid, str(refunds)])
	check.call(absf(_spent - paid) < 0.01 and _spent_facts == 2, "(11) the bus balances: energy_spent(shot) totals %.2f in two facts (got %.2f in %d)" % [paid, _spent, _spent_facts])
	_bus.disconnect(&"energy_gained", on_gained)
	await _end(tree)
