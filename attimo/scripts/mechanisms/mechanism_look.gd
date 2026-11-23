class_name MechanismLook
extends RefCounted
## Shared steampunk material pass (D-07b): walks a mechanism scene once and gives every plain metal mesh a shared brass,
## copper or iron material by node-name keyword (the node and its ancestors up to the root, nearest name first). Meshes
## that already carry a material_override, glow or translucent surface materials and everything inside a GlowElement are
## left alone, as are meshes without a keyword.

const IRON: StandardMaterial3D = preload("res://resources/mechanisms/look_iron.tres")
const BRASS: StandardMaterial3D = preload("res://resources/mechanisms/look_brass.tres")
const COPPER: StandardMaterial3D = preload("res://resources/mechanisms/look_copper.tres")

const IRON_KEYWORDS: Array[String] = ["base", "post", "frame", "plate", "deck", "head", "belt", "housing", "pillar"]
const BRASS_KEYWORDS: Array[String] = ["handle", "wheel", "rim", "spoke", "arm", "cap", "bob", "gauge", "ring", "slat", "axle", "dial"]
const COPPER_KEYWORDS: Array[String] = ["pipe", "column", "needle", "chain", "piston", "tube", "vent", "rod", "spring"]


static func apply(root: Node) -> void:
	_walk(root, root)


static func _walk(node: Node, root: Node) -> void:
	for child: Node in node.get_children():
		if child is GlowElement:
			continue
		var instance: MeshInstance3D = child as MeshInstance3D
		if instance != null and instance.material_override == null and not _is_effect(instance):
			var material: StandardMaterial3D = material_for(instance, root)
			if material != null:
				instance.material_override = material
		_walk(child, root)


## The shared material for a mesh by name keyword, or null.
static func material_for(instance: Node, root: Node) -> StandardMaterial3D:
	var node: Node = instance
	while node != null and node != root:
		var lowered: String = String(node.name).to_lower()
		for keyword: String in IRON_KEYWORDS:
			if lowered.contains(keyword):
				return IRON
		for keyword: String in BRASS_KEYWORDS:
			if lowered.contains(keyword):
				return BRASS
		for keyword: String in COPPER_KEYWORDS:
			if lowered.contains(keyword):
				return COPPER
		node = node.get_parent()
	return null


## Glowing or translucent meshes (energy cores, steam, telegraph strips) keep their own look.
static func _is_effect(instance: MeshInstance3D) -> bool:
	var candidates: Array[Material] = []
	if instance.mesh != null and instance.mesh.get_surface_count() > 0:
		candidates.append(instance.get_surface_override_material(0))
		candidates.append(instance.mesh.surface_get_material(0))
	for candidate: Material in candidates:
		if candidate == null:
			continue
		var standard: StandardMaterial3D = candidate as StandardMaterial3D
		if standard == null or standard.emission_enabled or standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return true
	return false
