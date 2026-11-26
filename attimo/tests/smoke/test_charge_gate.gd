extends RefCounted
## Plan 05.1-17 (KIT-02, KIT-03, KIT-04, D-21, D-47, D-18, GAME-DESIGN 6.5 / 6.9): the charge gate and its two stations. The gate is a check
## volume, not a door: it is active while the player stands inside it with at least `threshold` steps (start 6) and it never touches
## the energy (T-05.1-53). It shows the threshold as turquoise marks. Station 1: gate -> drawbridge (a HINGE Timed motion that folds down
## while its receiver is on). Station 2: gate -> 5 s invisible timer -> switched speed pad (boosts only while the timer is on).
## Scenes are reached by path and by get()/call(), so this file compiles before the classes exist (TDD RED).

const Fixtures := preload("res://tests/fixtures.gd")

const GATE_SCENE: String = "res://scenes/kit/energy/charge_gate.tscn"
const GATE_PRESET: String = "res://resources/kit/trigger/charge_gate.tres"
const BRIDGE_SCENE: String = "res://scenes/kit/steampunk/drawbridge.tscn"
const PAD_SCENE: String = "res://scenes/kit/steampunk/speed_pad_switched.tscn"
const TIMER_SCENE: String = "res://scenes/mechanisms/logic_timer.tscn"
const SHIPPED_TPS: int = 60
const THRESHOLD: int = 6
const FAR_AWAY: Vector3 = Vector3(0.0, 0.05, 40.0)
## The bridge folds within hinge_time plus this many seconds.
const FOLD_SLACK: float = 0.2
const DECK_FLAT_TOLERANCE: float = 0.1

var _saved_interval: float = 10.0


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	var all_there: bool = true
	for path: String in [GATE_SCENE, GATE_PRESET, BRIDGE_SCENE, PAD_SCENE, TIMER_SCENE]:
		var exists: bool = ResourceLoader.exists(path)
		check.call(exists, "%s exists" % path)
		all_there = all_there and exists
	if not all_there:
		return
	_scenario_look(tree, check)
	await _scenario_gate(tree, check)
	await _scenario_bridge_direct(tree, check)
	await _scenario_bridge_station(tree, check)
	await _scenario_pad_station(tree, check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _free(tree: SceneTree, nodes: Array) -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"move_back")
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


## The player on a floor with the passive step switched off (the passive tick would change the energy during a long wait).
func _player(tree: SceneTree, at: Vector3) -> PlayerController:
	var player: PlayerController = Fixtures.spawn_player(tree.root, at)
	_saved_interval = player.config.energy_passive_interval
	player.config.energy_passive_interval = 100000.0
	return player


func _restore(player: PlayerController) -> void:
	player.config.energy_passive_interval = _saved_interval


func _is_active(gate: Node) -> bool:
	return bool(gate.get("is_active"))


func _glow_count(root: Node) -> int:
	var count: int = 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var script: Script = node.get_script() as Script
		if script != null and String(script.get_global_name()) == "GlowElement" and (node as Node3D).visible:
			count += 1
	return count


func _scenario_look(tree: SceneTree, check: Callable) -> void:
	var preset: Resource = load(GATE_PRESET) as Resource
	check.call(preset != null and int(preset.get("threshold")) == THRESHOLD, "charge_gate.tres: threshold %d (F2 start value)" % THRESHOLD)
	var gate: Node3D = (load(GATE_SCENE) as PackedScene).instantiate() as Node3D
	check.call(int(gate.get("layer")) == 1 and int(gate.get("energy_relation")) == 0, "charge gate: ENERGY layer, energy relation FREE (it never costs, D-21)")
	check.call(_glow_count(gate) >= 1, "charge gate: carries a turquoise GlowElement in its authored scene")
	tree.root.add_child(gate)
	var shown: int = _glow_count(gate)
	check.call(shown == THRESHOLD, "charge gate: shows %d turquoise threshold marks (%d visible)" % [THRESHOLD, shown])
	gate.queue_free()
	# Tuning stays honest: the marks follow the threshold of the instance.
	var tuned: Node3D = (load(GATE_SCENE) as PackedScene).instantiate() as Node3D
	var tuned_config: Resource = (load(GATE_PRESET) as Resource).duplicate()
	tuned_config.set(&"threshold", 4)
	tuned.set(&"config", tuned_config)
	tree.root.add_child(tuned)
	check.call(_glow_count(tuned) == 4, "charge gate: with threshold 4 it shows 4 marks (%d)" % _glow_count(tuned))
	tuned.queue_free()


func _scenario_gate(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var gate: Node3D = (load(GATE_SCENE) as PackedScene).instantiate() as Node3D
	tree.root.add_child(gate)
	var player: PlayerController = _player(tree, Vector3(0.0, 0.05, 0.0))
	Fixtures.set_energy(player, THRESHOLD - 1)
	await Fixtures.wait_physics(tree, 10)
	check.call(not _is_active(gate), "gate: %d steps inside, below the threshold: inactive" % (THRESHOLD - 1))
	Fixtures.set_energy(player, THRESHOLD)
	await Fixtures.wait_physics(tree, 6)
	check.call(_is_active(gate), "gate: %d steps inside: active" % THRESHOLD)
	Fixtures.set_energy(player, 12)
	await Fixtures.wait_physics(tree, 6)
	check.call(_is_active(gate), "gate: 12 steps inside: still active")
	check.call(player.arm_energy.value == 12, "gate: it never consumes steps (energy %d, expected 12)" % player.arm_energy.value)
	player.global_position = FAR_AWAY
	await Fixtures.wait_physics(tree, 6)
	check.call(not _is_active(gate), "gate: leaving the volume switches it off")
	check.call(player.arm_energy.value == 12, "gate: leaving does not change the energy either (%d)" % player.arm_energy.value)
	_restore(player)
	await _free(tree, [player, gate, floor_body])


## Near floor and far floor with an 8 m gap; the bridge pivot sits on the near edge (z 0) and folds toward +z.
func _gap_world(tree: SceneTree) -> Array[Node]:
	var near: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(20.0, 1.0, 12.0), Vector3(0.0, -0.5, -6.0))
	var far: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(20.0, 1.0, 20.0), Vector3(0.0, -0.5, 18.0))
	return [near, far]


func _tip_y(bridge: Node3D) -> float:
	var deck: Node3D = bridge.call(&"body") as Node3D
	var length: float = float((bridge.get("config") as Resource).get("hand_length"))
	return (deck.global_transform * Vector3(0.0, 0.0, length)).y


func _fold_ticks(bridge: Node3D) -> int:
	var config: Resource = bridge.get("config") as Resource
	return int(ceil((float(config.get("hinge_time")) + FOLD_SLACK) * float(SHIPPED_TPS)))


func _scenario_bridge_direct(tree: SceneTree, check: Callable) -> void:
	var ground: Array[Node] = _gap_world(tree)
	var gate: Node3D = (load(GATE_SCENE) as PackedScene).instantiate() as Node3D
	gate.position = Vector3(0.0, 0.0, -4.0)
	tree.root.add_child(gate)
	var bridge: Node3D = (load(BRIDGE_SCENE) as PackedScene).instantiate() as Node3D
	var receiver: Node = bridge.get_node("Receiver")
	receiver.set(&"source", gate)
	tree.root.add_child(bridge)
	var length: float = float((bridge.get("config") as Resource).get("hand_length"))
	await Fixtures.wait_physics(tree, 5)
	check.call(_tip_y(bridge) > length * 0.9, "drawbridge: starts raised, the tip is up at %.2f m (deck %.1f m long)" % [_tip_y(bridge), length])
	var player: PlayerController = _player(tree, Vector3(0.0, 0.05, -4.0))
	Fixtures.set_energy(player, THRESHOLD)
	await Fixtures.wait_physics(tree, _fold_ticks(bridge) + 6)
	check.call(absf(_tip_y(bridge)) <= DECK_FLAT_TOLERANCE, "drawbridge: folded down within hinge_time + %.1f s (tip y %.3f)" % [FOLD_SLACK, _tip_y(bridge)])
	player.global_position = FAR_AWAY
	await Fixtures.wait_physics(tree, _fold_ticks(bridge) + 6)
	check.call(_tip_y(bridge) > length * 0.9, "drawbridge: folds up again when the gate goes inactive (tip y %.2f)" % _tip_y(bridge))
	_restore(player)
	await _free(tree, [player, bridge, gate] + ground)


func _scenario_bridge_station(tree: SceneTree, check: Callable) -> void:
	var ground: Array[Node] = _gap_world(tree)
	var gate: Node3D = (load(GATE_SCENE) as PackedScene).instantiate() as Node3D
	gate.position = Vector3(0.0, 0.0, -4.0)
	tree.root.add_child(gate)
	var timer: Node3D = (load(TIMER_SCENE) as PackedScene).instantiate() as Node3D
	timer.set(&"source", gate)
	timer.set(&"hold_time", 10.0)
	tree.root.add_child(timer)
	var bridge: Node3D = (load(BRIDGE_SCENE) as PackedScene).instantiate() as Node3D
	bridge.get_node("Receiver").set(&"source", timer)
	tree.root.add_child(bridge)
	var player: PlayerController = _player(tree, Vector3(0.0, 0.05, -4.0))
	Fixtures.set_energy(player, THRESHOLD)
	await Fixtures.wait_physics(tree, _fold_ticks(bridge) + 6)
	check.call(absf(_tip_y(bridge)) <= DECK_FLAT_TOLERANCE, "station: standing in the gate folds the bridge down (tip y %.3f)" % _tip_y(bridge))
	Input.action_press(&"move_back")
	var crossed: Callable = func() -> bool: return player.global_position.z > 12.0
	var ticks: int = await Fixtures.wait_until(tree, crossed, 60 * 8)
	Input.action_release(&"move_back")
	check.call(ticks >= 0 and player.global_position.y > -0.5, "station: the rider crosses the 8 m gap over the bridge (z %.1f, y %.2f)" % [player.global_position.z, player.global_position.y])
	check.call(player.arm_energy.value == THRESHOLD, "station: the energy is untouched by the whole station (%d)" % player.arm_energy.value)
	_restore(player)
	await _free(tree, [player, bridge, timer, gate] + ground)


## Gate -> 5 s timer -> switched speed pad: boosts only while the timer is on.
func _scenario_pad_station(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(120.0, 1.0, 120.0))
	var gate: Node3D = (load(GATE_SCENE) as PackedScene).instantiate() as Node3D
	gate.position = Vector3(30.0, 0.0, 0.0)
	tree.root.add_child(gate)
	var timer: Node3D = (load(TIMER_SCENE) as PackedScene).instantiate() as Node3D
	timer.set(&"source", gate)
	timer.set(&"hold_time", 5.0)
	tree.root.add_child(timer)
	var pad: Node3D = (load(PAD_SCENE) as PackedScene).instantiate() as Node3D
	pad.get_node("Receiver").set(&"source", timer)
	tree.root.add_child(pad)
	var add: float = float((pad.get("config") as Resource).get("add"))
	var player: PlayerController = _player(tree, Vector3(0.0, 0.05, 9.0))
	Fixtures.set_energy(player, THRESHOLD)
	await Fixtures.wait_physics(tree, 10)
	var cold: float = await _run_over_pad(tree, player)
	check.call(cold < player.config.run_speed + add - 0.8, "pad station: the switched pad does not boost while the timer is off (peak %.2f m/s)" % cold)
	# Enter the gate: the timer starts at this rising edge.
	player.global_position = Vector3(30.0, 0.05, 0.0)
	await Fixtures.wait_physics(tree, 5)
	check.call(bool(timer.get("is_active")), "pad station: the gate with %d steps starts the 5 s timer" % THRESHOLD)
	player.global_position = Vector3(0.0, 0.05, 9.0)
	await Fixtures.wait_physics(tree, 10)
	var warm: float = await _run_over_pad(tree, player)
	check.call(warm >= player.config.run_speed + add - 0.3, "pad station: while the timer is on the pad boosts (peak %.2f m/s, expected >= %.2f)" % [warm, player.config.run_speed + add - 0.3])
	var expired: Callable = func() -> bool: return not bool(timer.get("is_active"))
	var left: int = await Fixtures.wait_until(tree, expired, 60 * 8)
	check.call(left >= 0, "pad station: the timer switches off by itself after about 5 s")
	player.global_position = Vector3(0.0, 0.05, 9.0)
	await Fixtures.wait_physics(tree, 10)
	var after: float = await _run_over_pad(tree, player)
	check.call(after < player.config.run_speed + add - 0.8, "pad station: after the timer ran out the pad stops boosting (peak %.2f m/s)" % after)
	_restore(player)
	await _free(tree, [player, pad, timer, gate, floor_body])


func _run_over_pad(tree: SceneTree, player: PlayerController) -> float:
	Input.action_press(&"move_forward")
	var peak: float = 0.0
	for i: int in 100:
		await Fixtures.wait_physics(tree, 1)
		peak = maxf(peak, player.horizontal_speed())
	Input.action_release(&"move_forward")
	await Fixtures.wait_physics(tree, 5)
	return peak
