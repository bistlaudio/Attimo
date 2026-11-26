extends RefCounted
## Phase 05.1 (KIT-01, D-16): the coupling walk over every kit object scene under res://scenes/kit/{steampunk,energy,nature}
## (recursive, .tscn only). Each root is a KitBlock whose exported layer matches its folder. An object that costs or is amplified by
## energy, and every ENERGY object, carries a GlowElement (turquoise means energy). NATURE objects are free (energy_relation FREE),
## are never a CatchLaunch or Impulse root and carry no Amplification or EnergyCost component. STEAMPUNK objects carry no EnergyCost
## (D-16 exclusion rules). Every component class found is used by at least two object scenes (two-user rule). KIT_OBJECTS maps every
## object scene to the smoke test that covers it, and that test file exists. Class checks go by global class name (the script and
## its base scripts), so classes added by later plans need no edit here and a missing class never breaks compilation.

const KIT_ROOT: String = "res://scenes/kit"
## Folder name -> KitBlock.Layer value (STEAMPUNK 0, ENERGY 1, NATURE 2).
const LAYER_FOLDERS: Dictionary = {"steampunk": 0, "energy": 1, "nature": 2}
const LAYER_ENERGY: int = 1
const LAYER_NATURE: int = 2
## KitBlock.EnergyRelation values (FREE 0, COSTS 1, AMPLIFIED 2, GIVES 3; plan 05.1-14 D-43 appended GIVES).
const RELATION_FREE: int = 0
const RELATION_COSTS: int = 1
const RELATION_AMPLIFIED: int = 2
const RELATION_GIVES: int = 3
## The attachable component classes the two-user rule applies to (D-13 component list).
const COMPONENT_CLASSES: Array[String] = ["Receiver", "DamagePush", "Amplification", "EnergyCost"]
## Every kit object scene and the smoke test that covers it (one station and one test per object, KIT-04).
const KIT_OBJECTS: Dictionary = {
	"res://scenes/kit/steampunk/slingshot_core.tscn": "res://tests/smoke/test_slingshot_loader.gd",
	"res://scenes/kit/steampunk/steam_cannon.tscn": "res://tests/smoke/test_steam_cannon.gd",
	"res://scenes/kit/steampunk/wall_pad.tscn": "res://tests/smoke/test_wall_surface.gd",
	"res://scenes/kit/steampunk/wall_pad_steam.tscn": "res://tests/smoke/test_wall_surface.gd",
	"res://scenes/kit/steampunk/wall_jump_pad.tscn": "res://tests/smoke/test_wall_surface.gd",
	"res://scenes/kit/steampunk/wall_jump_pad_steam.tscn": "res://tests/smoke/test_wall_surface.gd",
	"res://scenes/kit/steampunk/clock_hand_platform.tscn": "res://tests/smoke/test_timed_motion.gd",
	"res://scenes/kit/steampunk/tilting_platform.tscn": "res://tests/smoke/test_timed_motion.gd",
	"res://scenes/kit/steampunk/paternoster.tscn": "res://tests/smoke/test_timed_motion.gd",
	"res://scenes/kit/steampunk/rail_cart.tscn": "res://tests/smoke/test_timed_motion.gd",
	"res://scenes/kit/steampunk/piston_steps.tscn": "res://tests/smoke/test_timed_motion.gd",
	"res://scenes/kit/steampunk/pendulum.tscn": "res://tests/smoke/test_damage_push.gd",
	"res://scenes/kit/steampunk/piston_wall.tscn": "res://tests/smoke/test_damage_push.gd",
	"res://scenes/kit/steampunk/steam_hammer.tscn": "res://tests/smoke/test_damage_push.gd",
	"res://scenes/kit/energy/energy_capsule.tscn": "res://tests/smoke/test_extractor.gd",
	"res://scenes/kit/energy/broken_machine.tscn": "res://tests/smoke/test_extractor.gd",
	"res://scenes/kit/energy/loader_field.tscn": "res://tests/smoke/test_loader_field.gd",
	"res://scenes/kit/steampunk/updraft.tscn": "res://tests/smoke/test_force_volume.gd",
	"res://scenes/kit/steampunk/geyser.tscn": "res://tests/smoke/test_force_volume.gd",
	"res://scenes/kit/steampunk/steam_stream.tscn": "res://tests/smoke/test_force_volume.gd",
	"res://scenes/kit/nature/leaf_storm.tscn": "res://tests/smoke/test_force_volume.gd",
	"res://scenes/kit/nature/resin_pool.tscn": "res://tests/smoke/test_force_volume.gd",
	"res://scenes/kit/steampunk/boost_ring.tscn": "res://tests/smoke/test_impulse.gd",
	"res://scenes/kit/steampunk/speed_pad.tscn": "res://tests/smoke/test_impulse.gd",
	"res://scenes/kit/steampunk/bounce_pad.tscn": "res://tests/smoke/test_impulse.gd",
	"res://scenes/kit/energy/bounce_pad_core.tscn": "res://tests/smoke/test_amplification.gd",
	"res://scenes/kit/energy/gravity_zone.tscn": "res://tests/smoke/test_amplification.gd",
	"res://scenes/kit/energy/charge_gate.tscn": "res://tests/smoke/test_charge_gate.gd",
	"res://scenes/kit/steampunk/drawbridge.tscn": "res://tests/smoke/test_charge_gate.gd",
	"res://scenes/kit/steampunk/speed_pad_switched.tscn": "res://tests/smoke/test_charge_gate.gd",
	"res://scenes/kit/energy/energy_core.tscn": "res://tests/smoke/test_energy_core.gd",
	"res://scenes/kit/energy/attraction_field.tscn": "res://tests/smoke/test_attraction_field.gd",
}


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	var scenes: Array[String] = []
	for folder: String in LAYER_FOLDERS:
		_collect("%s/%s" % [KIT_ROOT, folder], scenes)
	scenes.sort()
	check.call(not scenes.is_empty(), "at least one kit object scene under %s/{steampunk,energy,nature} (%d)" % [KIT_ROOT, scenes.size()])
	for path: String in KIT_OBJECTS:
		check.call(scenes.has(path), "the registered kit object %s exists" % path)
	var component_users: Dictionary = {}
	for path: String in scenes:
		_check_scene(path, check, component_users)
	for component: String in component_users:
		var users: int = (component_users[component] as Array).size()
		check.call(users >= 2, "component %s is used by at least two object scenes (%d: %s)" % [component, users, component_users[component]])
	# Guardrail 3 (plan 05.1-16): Amplification has exactly its two users, the bounce pad with core and the gravity zone.
	var amp_users: Array = component_users.get("Amplification", []) as Array
	check.call(amp_users.size() == 2 and amp_users.has("energy/bounce_pad_core.tscn") and amp_users.has("energy/gravity_zone.tscn"), "Amplification is found in exactly 2 scenes: bounce_pad_core and gravity_zone (%s)" % [amp_users])


	# Plan 05.1-17 (D-13): the Receiver component has exactly its two users, the drawbridge and the switched speed pad.
	var receiver_users: Array = component_users.get("Receiver", []) as Array
	check.call(receiver_users.size() == 2 and receiver_users.has("steampunk/drawbridge.tscn") and receiver_users.has("steampunk/speed_pad_switched.tscn"), "Receiver is found in exactly 2 scenes: drawbridge and speed_pad_switched (%s)" % [receiver_users])

	# Plan 05.1-18 (D-14): the EnergyCost component has exactly its two users, the energy core (pay-in) and the attraction field (fast escape).
	var cost_users: Array = component_users.get("EnergyCost", []) as Array
	check.call(cost_users.size() == 2 and cost_users.has("energy/energy_core.tscn") and cost_users.has("energy/attraction_field.tscn"), "EnergyCost is found in exactly 2 scenes: energy_core and attraction_field (%s)" % [cost_users])

	# Plan 05.1-20 (D-14, D-15): DamagePush has its three users so far, the pendulum, the piston wall and the steam hammer (05.1-21 adds more).
	var push_users: Array = component_users.get("DamagePush", []) as Array
	check.call(push_users.size() >= 2 and push_users.has("steampunk/pendulum.tscn") and push_users.has("steampunk/piston_wall.tscn") and push_users.has("steampunk/steam_hammer.tscn"), "DamagePush is found in at least the pendulum, piston wall and steam hammer scenes (%s)" % [push_users])


func _collect(dir_path: String, into: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for file: String in dir.get_files():
		if file.ends_with(".tscn"):
			into.append("%s/%s" % [dir_path, file])
	for sub: String in dir.get_directories():
		_collect("%s/%s" % [dir_path, sub], into)


## The global class names of a node's script and its base scripts (nearest first). Empty without a script.
func _class_chain(node: Node) -> Array[String]:
	var chain: Array[String] = []
	var script: Script = node.get_script() as Script
	while script != null:
		var global_name: String = String(script.get_global_name())
		if global_name != "":
			chain.append(global_name)
		script = script.get_base_script()
	return chain


## The class names of every descendant (scripts and their bases, plus the native class), deduplicated.
func _descendant_classes(root: Node) -> Dictionary:
	var found: Dictionary = {}
	for node: Node in root.find_children("*", "", true, false):
		for name: String in _class_chain(node):
			found[name] = true
		found[node.get_class()] = true
	return found


func _check_scene(path: String, check: Callable, component_users: Dictionary) -> void:
	var stem: String = path.trim_prefix(KIT_ROOT + "/")
	var folder: String = stem.get_slice("/", 0)
	check.call(KIT_OBJECTS.has(path), "%s has a KIT_OBJECTS entry" % stem)
	if KIT_OBJECTS.has(path):
		check.call(FileAccess.file_exists(String(KIT_OBJECTS[path])), "%s: its test %s exists" % [stem, KIT_OBJECTS[path]])
	var packed: PackedScene = load(path) as PackedScene
	check.call(packed != null, "%s loads as a PackedScene" % stem)
	if packed == null:
		return
	# Not added to the tree: _ready never runs, exports and the node tree are read as authored.
	var root: Node = packed.instantiate()
	var chain: Array[String] = _class_chain(root)
	check.call(chain.has("KitBlock"), "%s: the root is a KitBlock (%s)" % [stem, chain])
	if not chain.has("KitBlock"):
		root.free()
		return
	var layer: int = int(root.get("layer"))
	var relation: int = int(root.get("energy_relation"))
	var classes: Dictionary = _descendant_classes(root)
	check.call(layer == int(LAYER_FOLDERS[folder]), "%s: layer %d matches the folder %s" % [stem, layer, folder])
	if relation == RELATION_COSTS or relation == RELATION_AMPLIFIED or layer == LAYER_ENERGY:
		check.call(classes.has("GlowElement"), "%s: an energy object (relation %d, layer %d) carries a GlowElement" % [stem, relation, layer])
	# D-43 (05.1-14): GIVES is the 4th relation; every GIVES object carries the turquoise accent, a FREE steampunk object has none.
	check.call(KitBlock.EnergyRelation.keys().size() == 4 and KitBlock.EnergyRelation.keys()[3] == "GIVES", "KitBlock.EnergyRelation has GIVES as the 4th value")
	if relation == RELATION_GIVES:
		check.call(classes.has("GlowElement"), "%s: a GIVES object carries a turquoise GlowElement accent" % stem)
	if folder == "steampunk" and relation == RELATION_FREE:
		check.call(not classes.has("GlowElement"), "%s: a FREE steampunk object has no GlowElement" % stem)
	# Plan 05.1-15 (D-43, D-61): the steam force volumes give a step per use (GIVES + accent); the nature ones are FREE.
	if path.ends_with("/updraft.tscn") or path.ends_with("/geyser.tscn") or path.ends_with("/steam_stream.tscn"):
		check.call(relation == RELATION_GIVES and classes.has("GlowElement"), "%s: a steam force volume is GIVES with an accent (relation %d)" % [stem, relation])
	if path.ends_with("/leaf_storm.tscn") or path.ends_with("/resin_pool.tscn"):
		check.call(layer == LAYER_NATURE and relation == RELATION_FREE, "%s: nature force volume is NATURE and FREE (layer %d, relation %d)" % [stem, layer, relation])
	# Plan 05.1-16 (D-43, D-24): the free boosters give a step per use (GIVES + accent); the amplified energy objects are AMPLIFIED with a
	# turquoise core and carry the Amplification component (its two users, checked again by the two-user rule below).
	if path.ends_with("/boost_ring.tscn") or path.ends_with("/speed_pad.tscn") or path.ends_with("/bounce_pad.tscn"):
		check.call(layer == 0 and relation == RELATION_GIVES and classes.has("GlowElement") and not classes.has("Amplification"), "%s: a free booster is STEAMPUNK GIVES with an accent and no Amplification (relation %d)" % [stem, relation])
		check.call(chain.has("Impulse"), "%s: the root is an Impulse (%s)" % [stem, chain])
	if path.ends_with("/bounce_pad_core.tscn") or path.ends_with("/gravity_zone.tscn"):
		check.call(layer == LAYER_ENERGY and relation == RELATION_AMPLIFIED and classes.has("GlowElement") and classes.has("Amplification"), "%s: an amplified energy object is ENERGY AMPLIFIED with a GlowElement core and an Amplification (relation %d)" % [stem, relation])
	# Plan 05.1-17 (D-21, D-47): the charge gate is an ENERGY Trigger that never costs (FREE) and shows turquoise marks; the drawbridge is
	# a FREE steampunk Timed motion with a Receiver; the switched speed pad is a GIVES Impulse with an accent and a Receiver.
	if path.ends_with("/charge_gate.tscn"):
		check.call(layer == LAYER_ENERGY and relation == RELATION_FREE and classes.has("GlowElement") and not classes.has("Receiver"), "%s: the charge gate is ENERGY FREE with GlowElement marks and no Receiver (relation %d)" % [stem, relation])
		check.call(chain.has("Trigger"), "%s: the root is a Trigger (%s)" % [stem, chain])
	if path.ends_with("/drawbridge.tscn"):
		check.call(layer == 0 and relation == RELATION_FREE and classes.has("Receiver") and chain.has("TimedMotion"), "%s: the drawbridge is a FREE steampunk TimedMotion with a Receiver (relation %d, %s)" % [stem, relation, chain])
	# Plan 05.1-19 (D-11, D-26): the paternoster, rail cart and piston steps are FREE steampunk Timed motion blocks with no Receiver and no glow.
	if path.ends_with("/paternoster.tscn") or path.ends_with("/rail_cart.tscn") or path.ends_with("/piston_steps.tscn"):
		check.call(layer == 0 and relation == RELATION_FREE and chain.has("TimedMotion") and not classes.has("GlowElement") and not classes.has("Receiver"), "%s: an always-on platform is a FREE steampunk TimedMotion with no GlowElement or Receiver (relation %d, %s)" % [stem, relation, chain])
	if path.ends_with("/speed_pad_switched.tscn"):
		check.call(layer == 0 and relation == RELATION_GIVES and classes.has("Receiver") and classes.has("GlowElement") and chain.has("Impulse"), "%s: the switched speed pad is a steampunk GIVES Impulse with an accent and a Receiver (relation %d, %s)" % [stem, relation, chain])
	# Plan 05.1-18 (D-14, D-16): the energy core and the attraction field are ENERGY objects that COST steps and carry a turquoise GlowElement and
	# an EnergyCost; the core is a Trigger, the field a ForceVolume.
	if path.ends_with("/energy_core.tscn") or path.ends_with("/attraction_field.tscn"):
		check.call(layer == LAYER_ENERGY and relation == RELATION_COSTS and classes.has("GlowElement") and classes.has("EnergyCost"), "%s: a paid energy object is ENERGY COSTS with a GlowElement and an EnergyCost (relation %d)" % [stem, relation])
	if path.ends_with("/energy_core.tscn"):
		check.call(chain.has("Trigger"), "%s: the energy core root is a Trigger (%s)" % [stem, chain])
	if path.ends_with("/attraction_field.tscn"):
		check.call(chain.has("ForceVolume"), "%s: the attraction field root is a ForceVolume (%s)" % [stem, chain])
	if path.ends_with("/slingshot_core.tscn") or path.ends_with("/steam_cannon.tscn"):
		check.call(relation == RELATION_GIVES, "%s: the catch element is GIVES (relation %d)" % [stem, relation])
	if folder == "nature":
		check.call(relation != RELATION_GIVES, "%s: a nature object never GIVES" % stem)
		check.call(relation == RELATION_FREE, "%s: a nature object is free (relation %d)" % [stem, relation])
		check.call(not chain.has("CatchLaunch") and not chain.has("Impulse"), "%s: a nature object is no CatchLaunch or Impulse (%s)" % [stem, chain])
		check.call(not classes.has("Amplification") and not classes.has("EnergyCost"), "%s: a nature object has no Amplification or EnergyCost" % stem)
	if folder == "steampunk":
		check.call(not classes.has("EnergyCost"), "%s: a steampunk object has no EnergyCost" % stem)
	for component: String in COMPONENT_CLASSES:
		if classes.has(component):
			if not component_users.has(component):
				component_users[component] = []
			(component_users[component] as Array).append(stem)
	root.free()
