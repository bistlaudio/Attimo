extends RefCounted
## Phase 05.1 (KIT-01, D-10..D-12): the per-block contract tests. Every block is one script with an exported config Resource of its
## own class, its variants are one profile enum (no flag soup), it never writes the player's motion itself (only PlayerController
## request APIs, D-17), and a loaded config .tres is never written at runtime: every instance duplicates its config in _ready, so two
## instances of one preset never share a write (D-12). Scripts are loaded by path and checked by reflection, so a block added by a
## later plan only needs a new entry in BLOCKS.

## Block name -> script path, config class, config script path, required profile values, preset .tres and a scene using the preset.
const BLOCKS: Dictionary = {
	"CatchLaunch": {
		"script": "res://scripts/kit/blocks/catch_launch.gd",
		"config_class": "CatchLaunchConfig",
		"config_script": "res://scripts/kit/configs/catch_launch_config.gd",
		"profiles": ["FREE_AIM", "FIXED"],
		"preset": "res://resources/kit/catch_launch/slingshot_default.tres",
		"scene": "res://scenes/kit/steampunk/slingshot_core.tscn",
		"probe": "radius",
		# Plan 05.1-02: timer and divisor fields of the FIXED profile need a strictly positive minimum (T-05.1-06), and the steam
		# cannon preset is a FIXED profile.
		"positive": ["fixed_hold", "fixed_speed", "radius", "rearm_time"],
		"profile_presets": {"res://resources/kit/catch_launch/steam_cannon_default.tres": "FIXED"},
	},
}
## Source fragments a block script must not contain: direct writes of the player's motion (D-17).
const FORBIDDEN_WRITES: Array[String] = [".move_velocity =", ".vertical_speed =", ".move_velocity +=", ".vertical_speed +=", ".velocity ="]
const KIT_BLOCK_SCRIPT: String = "res://scripts/kit/kit_block.gd"


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	check.call(ResourceLoader.exists(KIT_BLOCK_SCRIPT), "the KitBlock base %s exists" % KIT_BLOCK_SCRIPT)
	if ResourceLoader.exists(KIT_BLOCK_SCRIPT):
		_check_kit_block(check)
	for block: String in BLOCKS:
		await _check_block(tree, check, block, BLOCKS[block] as Dictionary)


func _check_kit_block(check: Callable) -> void:
	var script: GDScript = load(KIT_BLOCK_SCRIPT) as GDScript
	check.call(String(script.get_global_name()) == "KitBlock", "kit_block.gd declares class_name KitBlock")
	var constants: Dictionary = script.get_script_constant_map()
	var layers: Dictionary = constants.get("Layer", {}) as Dictionary
	var relations: Dictionary = constants.get("EnergyRelation", {}) as Dictionary
	check.call(layers.has("STEAMPUNK") and layers.has("ENERGY") and layers.has("NATURE"), "KitBlock.Layer is STEAMPUNK, ENERGY, NATURE (%s)" % [layers])
	check.call(relations.has("FREE") and relations.has("COSTS") and relations.has("AMPLIFIED"), "KitBlock.EnergyRelation is FREE, COSTS, AMPLIFIED (%s)" % [relations])
	var exported: Array[String] = _exported(script)
	check.call(exported.has("layer") and exported.has("energy_relation"), "KitBlock exports layer and energy_relation (%s)" % [exported])
	check.call(not exported.has("source"), "KitBlock keeps no source field (switching is the Receiver component's job, D-13)")
	var methods: Array[String] = []
	for method: Dictionary in script.get_script_method_list():
		methods.append(String(method["name"]))
	check.call(methods.has("reset") and methods.has("own_config"), "KitBlock has reset() and own_config()")


## The names of a script's exported properties (script variables with the editor usage flag).
func _exported(script: GDScript) -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in script.get_script_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_EDITOR:
			names.append(String(property["name"]))
	return names


func _check_block(tree: SceneTree, check: Callable, block: String, spec: Dictionary) -> void:
	var path: String = String(spec["script"])
	check.call(ResourceLoader.exists(path), "%s: the block script %s exists" % [block, path])
	if not ResourceLoader.exists(path):
		return
	var script: GDScript = load(path) as GDScript
	check.call(String(script.get_global_name()) == block, "%s: class_name %s" % [block, block])
	var is_kit_block: bool = false
	var base: Script = script.get_base_script()
	while base != null:
		if String(base.get_global_name()) == "KitBlock":
			is_kit_block = true
		base = base.get_base_script()
	check.call(is_kit_block, "%s extends KitBlock" % block)
	var config_property: Dictionary = {}
	for property: Dictionary in script.get_script_property_list():
		if String(property["name"]) == "config":
			config_property = property
	check.call(not config_property.is_empty() and String(config_property["class_name"]) == String(spec["config_class"]) and int(config_property["usage"]) & PROPERTY_USAGE_EDITOR, "%s exports config: %s (%s)" % [block, spec["config_class"], config_property])
	var config_script: GDScript = load(String(spec["config_script"])) as GDScript
	check.call(config_script != null and String(config_script.get_global_name()) == String(spec["config_class"]), "%s: the config class %s exists" % [block, spec["config_class"]])
	if config_script != null:
		var profiles: Dictionary = config_script.get_script_constant_map().get("Profile", {}) as Dictionary
		for value: String in spec["profiles"] as Array:
			check.call(profiles.has(value), "%s: the Profile enum has %s (%s)" % [block, value, profiles])
		_check_positive(check, block, config_script, spec.get("positive", []) as Array)
		var presets: Dictionary = spec.get("profile_presets", {}) as Dictionary
		for preset_path: String in presets:
			var preset: Resource = load(preset_path) as Resource if ResourceLoader.exists(preset_path) else null
			var wanted: int = int(profiles.get(String(presets[preset_path]), -1))
			check.call(preset != null and int(preset.get("profile")) == wanted, "%s: preset %s uses profile %s" % [block, preset_path, presets[preset_path]])
	var source: String = script.source_code
	for fragment: String in FORBIDDEN_WRITES:
		check.call(not source.contains(fragment), "%s writes no player motion itself (no '%s', D-17)" % [block, fragment])
	await _check_no_shared_write(tree, check, block, spec)


## Every named config field has an @export_range whose minimum is strictly positive (no zero timer or divisor).
func _check_positive(check: Callable, block: String, config_script: GDScript, fields: Array) -> void:
	for field: Variant in fields:
		var found: bool = false
		var minimum: float = 0.0
		for property: Dictionary in config_script.get_script_property_list():
			if String(property["name"]) == String(field) and int(property["hint"]) == PROPERTY_HINT_RANGE:
				found = true
				minimum = String(property["hint_string"]).split(",")[0].to_float()
		check.call(found and minimum > 0.0, "%s: config field %s has a positive range minimum (%s, %.3f)" % [block, field, found, minimum])


## D-12: two instances of a scene that uses the preset; a runtime change on one stays on that one, the other and the file keep theirs.
func _check_no_shared_write(tree: SceneTree, check: Callable, block: String, spec: Dictionary) -> void:
	var scene_path: String = String(spec["scene"])
	var preset_path: String = String(spec["preset"])
	var probe: String = String(spec["probe"])
	check.call(ResourceLoader.exists(preset_path) and ResourceLoader.exists(scene_path), "%s: preset %s and scene %s exist" % [block, preset_path, scene_path])
	if not ResourceLoader.exists(preset_path) or not ResourceLoader.exists(scene_path):
		return
	var preset: Resource = load(preset_path) as Resource
	var original: float = float(preset.get(probe))
	var scene: PackedScene = load(scene_path) as PackedScene
	var a: Node3D = scene.instantiate() as Node3D
	var b: Node3D = scene.instantiate() as Node3D
	a.position = Vector3(0.0, -200.0, 0.0)
	b.position = Vector3(20.0, -200.0, 0.0)
	tree.root.add_child(a)
	tree.root.add_child(b)
	await tree.process_frame
	var config_a: Resource = a.get("config") as Resource
	var config_b: Resource = b.get("config") as Resource
	check.call(config_a != null and config_b != null, "%s: both instances carry a config" % block)
	if config_a != null and config_b != null:
		check.call(config_a != config_b and config_a != preset and config_b != preset, "%s: each instance owns its own config copy (D-12)" % block)
		config_a.set(probe, original + 1.0)
		check.call(is_equal_approx(float(config_b.get(probe)), original), "%s: a change on one instance leaves the other at %.2f (got %.2f)" % [block, original, float(config_b.get(probe))])
		check.call(is_equal_approx(float((load(preset_path) as Resource).get(probe)), original), "%s: the loaded preset keeps %s = %.2f" % [block, probe, original])
	a.queue_free()
	b.queue_free()
	await tree.process_frame
	await tree.process_frame
