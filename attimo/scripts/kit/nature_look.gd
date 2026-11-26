class_name NatureLook
extends RefCounted
## Shared nature material pass (Phase 05.1, D-26): walks a nature kit object once and gives every plain mesh a shared moss green, bark
## brown, amber resin or weathered stone material by node-name keyword (the node and its ancestors up to the root, nearest name first).
## Toon diffuse, roughness 0.9. Meshes that already carry a material_override, glow or translucent materials and everything inside a
## GlowElement keep their look, as do meshes without a keyword. Mirror of MechanismLook for the NATURE layer; KitBlock calls it on ready.

const MOSS: StandardMaterial3D = preload("res://resources/kit/nature/look_moss.tres")
const BARK: StandardMaterial3D = preload("res://resources/kit/nature/look_bark.tres")
const RESIN: StandardMaterial3D = preload("res://resources/kit/nature/look_resin.tres")
const STONE: StandardMaterial3D = preload("res://resources/kit/nature/look_stone.tres")

const MOSS_KEYWORDS: Array[String] = ["moss", "grass", "leaf"]
const BARK_KEYWORDS: Array[String] = ["bark", "wood", "root", "branch"]
const RESIN_KEYWORDS: Array[String] = ["resin", "amber", "sap"]
const STONE_KEYWORDS: Array[String] = ["stone", "rock", "pebble"]


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
		for keyword: String in RESIN_KEYWORDS:
			if lowered.contains(keyword):
				return RESIN
		for keyword: String in MOSS_KEYWORDS:
			if lowered.contains(keyword):
				return MOSS
		for keyword: String in BARK_KEYWORDS:
			if lowered.contains(keyword):
				return BARK
		for keyword: String in STONE_KEYWORDS:
			if lowered.contains(keyword):
				return STONE
		node = node.get_parent()
	return null


## Glowing or translucent meshes keep their own look.
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
