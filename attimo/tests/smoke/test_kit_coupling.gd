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
## KitBlock.EnergyRelation values (FREE 0, COSTS 1, AMPLIFIED 2).
const RELATION_FREE: int = 0
const RELATION_COSTS: int = 1
const RELATION_AMPLIFIED: int = 2
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
	if folder == "nature":
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
