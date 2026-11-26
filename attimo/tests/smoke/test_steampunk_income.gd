extends RefCounted
## Plan 05.1-14 (KIT-03, ENRG-08, D-43, D-41): a steampunk element that carries Rino gives +1 whole step per use. The slingshot cage and
## the steam cannon grant it on the catch (KitBlock.grant_step through ArmEnergy.gain) and announce it with EventBus.income_granted(position,
## steps, source_id). The block's own cooldown (income_cooldown, real time) stops farming: a re-catch inside it gives nothing, the next
## catch after it gives +1 again. At 12 steps a catch adds nothing and does not error, and the released flight gives no further step.

const Fixtures := preload("res://tests/fixtures.gd")

const CAGE_SCENE: String = "res://scenes/kit/steampunk/slingshot_core.tscn"
const CANNON_SCENE: String = "res://scenes/kit/steampunk/steam_cannon.tscn"
const SHIPPED_TPS: int = 60
const CENTRE: Vector3 = Vector3(0.0, 10.0, 0.0)
const START_OFFSET: Vector3 = Vector3(-4.0, -1.0, 0.0)
const FAR: Vector3 = Vector3(0.0, 10.0, 60.0)
const ENTRY_SPEED: float = 9.0

var _bus: Node
var _income: Array[Dictionary] = []
var _on_income: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await tree.process_frame
	check.call(_bus.has_signal(&"income_granted"), "EventBus has the income_granted fact")
	check.call(KitBlock.EnergyRelation.keys().size() == 4 and KitBlock.EnergyRelation.keys()[3] == "GIVES", "KitBlock.EnergyRelation has GIVES as the 4th value (%s)" % [KitBlock.EnergyRelation.keys()])
	if not _bus.has_signal(&"income_granted"):
		return
	await _scenario_cage(tree, check)
	await _scenario_cannon(tree, check)
	await _scenario_full(tree, check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _begin(tree: SceneTree, scene: String, at: Vector3, yaw_deg: float) -> Array[Node]:
	_income = []
	_on_income = func(position: Vector3, steps: int, source_id: StringName) -> void: _income.append({"position": position, "steps": steps, "source": source_id})
	_bus.connect(&"income_granted", _on_income)
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(300.0, 1.0, 300.0))
	var element: Node3D = (load(scene) as PackedScene).instantiate() as Node3D
	element.position = at
	element.rotation.y = deg_to_rad(yaw_deg)
	tree.root.add_child(element)
	var player: PlayerController = Fixtures.spawn_player(tree.root, FAR)
	player.debug_loader_direction = Vector3(0.0, 0.3, -1.0)
	await Fixtures.wait_physics(tree, 3)
	return [floor_body, element, player]


func _end(tree: SceneTree, nodes: Array[Node]) -> void:
	for action: StringName in [&"loader", &"move_forward", &"jump", &"dash"]:
		Input.action_release(action)
	await Fixtures.wait_physics(tree, 8)
	Fixtures.restore_time()
	_bus.disconnect(&"income_granted", _on_income)
	_on_income = Callable()
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
	await tree.process_frame


func _is_loader(player: PlayerController) -> bool:
	return player.state_machine.current.name == &"Loader"


## One cage entry from the west at ENTRY_SPEED. Returns true when Rino was caught.
func _cage_entry(tree: SceneTree, player: PlayerController) -> bool:
	player.teleport(CENTRE + START_OFFSET)
	player.launch_along(Vector3.RIGHT, ENTRY_SPEED, false)
	# The flight is held level (vertical speed zero) so the chest point crosses the core centre (D-54).
	return await Fixtures.wait_until(tree, func() -> bool:
		if not _is_loader(player):
			player.vertical_speed = 0.0
		return _is_loader(player), 40) >= 0


## Taps the loader to throw Rino out of the cage and waits until he is out.
func _release(tree: SceneTree, player: PlayerController) -> void:
	await Fixtures.wait_physics(tree, 4)
	await Fixtures.tap_action(tree, &"loader", 1)
	await Fixtures.wait_until(tree, func() -> bool: return not _is_loader(player), 20)


func _scenario_cage(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _begin(tree, CAGE_SCENE, CENTRE, 0.0)
	var cage: Node3D = nodes[1]
	var player: PlayerController = nodes[2] as PlayerController
	var config: Resource = cage.get("config") as Resource
	check.call(config != null and "income_steps" in config and "income_cooldown" in config, "(cage) the config has income_steps and income_cooldown")
	var cooldown: float = float(config.get("income_cooldown")) if config != null and "income_cooldown" in config else 3.0
	Fixtures.set_energy(player, 3)
	var caught: bool = await _cage_entry(tree, player)
	await Fixtures.wait_physics(tree, 2)
	check.call(caught, "(cage) the first catch happens")
	check.call(player.arm_energy.value == 4, "(cage) the catch gives exactly +1 step (3 -> %d)" % player.arm_energy.value)
	check.call(_income.size() == 1, "(cage) one income_granted fact (%d)" % _income.size())
	if _income.size() == 1:
		check.call((_income[0]["position"] as Vector3).distance_to(cage.global_position) < 0.01 and _income[0]["steps"] == 1, "(cage) the fact carries the core position and 1 step (%s)" % [_income[0]])
	await _release(tree, player)
	var after_release: int = player.arm_energy.value
	await Fixtures.wait_physics(tree, 30)
	check.call(player.arm_energy.value == after_release and _income.size() == 1, "(cage) the released flight gives no further step (%d -> %d)" % [after_release, player.arm_energy.value])
	# Second catch inside the cooldown: rearm_time has passed, the income cooldown has not.
	player.teleport(FAR)
	await Fixtures.wait_physics(tree, 70)
	Fixtures.set_energy(player, 3)
	var again: bool = await _cage_entry(tree, player)
	await Fixtures.wait_physics(tree, 2)
	check.call(again, "(cage) the cage catches again after its rearm time")
	check.call(player.arm_energy.value == 3 and _income.size() == 1, "(cage) a re-catch inside the %.1f s cooldown gives nothing (energy %d, facts %d)" % [cooldown, player.arm_energy.value, _income.size()])
	await _release(tree, player)
	# After the cooldown the next catch gives +1 again.
	player.teleport(FAR)
	await Fixtures.wait_physics(tree, ceili(cooldown * SHIPPED_TPS) + 30)
	Fixtures.set_energy(player, 3)
	var third: bool = await _cage_entry(tree, player)
	await Fixtures.wait_physics(tree, 2)
	check.call(third and player.arm_energy.value == 4 and _income.size() == 2, "(cage) after the cooldown the catch gives +1 again (caught %s, energy %d, facts %d)" % [third, player.arm_energy.value, _income.size()])
	await _end(tree, nodes)


func _scenario_cannon(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _begin(tree, CANNON_SCENE, Vector3.ZERO, -90.0)
	var cannon: Node3D = nodes[1]
	var player: PlayerController = nodes[2] as PlayerController
	var config: Resource = cannon.get("config") as Resource
	var cooldown: float = float(config.get("income_cooldown")) if config != null and "income_cooldown" in config else 3.0
	Fixtures.set_energy(player, 3)
	var caught: bool = await _cannon_entry(tree, player)
	await Fixtures.wait_physics(tree, 2)
	check.call(caught, "(cannon) the first catch happens")
	check.call(player.arm_energy.value == 4 and _income.size() == 1, "(cannon) the catch gives exactly +1 step (energy %d, facts %d)" % [player.arm_energy.value, _income.size()])
	await Fixtures.wait_until(tree, func() -> bool: return not _is_loader(player), 60)
	await Fixtures.wait_physics(tree, 100)
	player.teleport(Vector3(0.0, 0.0, 40.0))
	await Fixtures.wait_physics(tree, 30)
	Fixtures.set_energy(player, 3)
	var again: bool = await _cannon_entry(tree, player)
	await Fixtures.wait_physics(tree, 2)
	check.call(again and player.arm_energy.value == 3 and _income.size() == 1, "(cannon) a re-catch inside the cooldown gives nothing (caught %s, energy %d, facts %d)" % [again, player.arm_energy.value, _income.size()])
	await Fixtures.wait_until(tree, func() -> bool: return not _is_loader(player), 60)
	player.teleport(Vector3(0.0, 0.0, 40.0))
	await Fixtures.wait_physics(tree, ceili(cooldown * SHIPPED_TPS) + 30)
	Fixtures.set_energy(player, 3)
	var third: bool = await _cannon_entry(tree, player)
	await Fixtures.wait_physics(tree, 2)
	check.call(third and player.arm_energy.value == 4 and _income.size() == 2, "(cannon) after the cooldown the catch gives +1 again (energy %d, facts %d)" % [player.arm_energy.value, _income.size()])
	await _end(tree, nodes)


## Slides into the breech along +X from 3.2 m at run speed.
func _cannon_entry(tree: SceneTree, player: PlayerController) -> bool:
	var speed: float = player.config.run_speed
	player.teleport(Vector3(-3.2, 0.0, 0.0))
	await tree.physics_frame
	player.launch_along(Vector3.RIGHT, speed, false)
	for i: int in 40:
		if _is_loader(player):
			return true
		player.move_velocity = Vector3.RIGHT * speed
		await tree.physics_frame
	return false


## At 12 steps a catch adds nothing and does not error.
func _scenario_full(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _begin(tree, CAGE_SCENE, CENTRE, 0.0)
	var player: PlayerController = nodes[2] as PlayerController
	Fixtures.set_energy(player, ArmEnergy.MAX_STEPS)
	var caught: bool = await _cage_entry(tree, player)
	await Fixtures.wait_physics(tree, 2)
	check.call(caught and player.arm_energy.value == ArmEnergy.MAX_STEPS, "(full) a catch at %d steps adds nothing (caught %s, energy %d)" % [ArmEnergy.MAX_STEPS, caught, player.arm_energy.value])
	await _end(tree, nodes)
