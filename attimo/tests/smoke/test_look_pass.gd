extends RefCounted
## HAND-07 / D-07, D-07b: every mechanism and trigger scene carries a faceted GlowElement and shared brass, copper or iron
## materials. The four interactable lenses (lever, valve, crank, energy core) are GlowElements named GlowLens, the glow
## stages still switch their material_override, and nothing uses a sphere lens any more.

const DIR: String = "res://scenes/mechanisms/"
const BRASS: String = "res://resources/mechanisms/look_brass.tres"
const COPPER: String = "res://resources/mechanisms/look_copper.tres"
const IRON: String = "res://resources/mechanisms/look_iron.tres"
const ENERGY: String = "res://resources/mechanisms/glow_energy.tres"
const GLOW_TARGET: String = "res://resources/mechanisms/glow_target.tres"
const LENS_STYLES: Dictionary = {
	"lever": GlowElement.Style.DIAMOND,
	"valve": GlowElement.Style.HUB,
	"crank": GlowElement.Style.COG,
	"energy_core": GlowElement.Style.CAGE,
}


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	var looks: Array[Material] = [load(BRASS), load(COPPER), load(IRON)]
	var energy: Material = load(ENERGY)
	for path: String in [BRASS, COPPER, IRON, ENERGY]:
		check.call(ResourceLoader.exists(path), "%s exists" % path)
	var dir: DirAccess = DirAccess.open(DIR)
	var names: Array[String] = []
	for file: String in dir.get_files():
		if file.ends_with(".tscn") and file != "glow_element.tscn":
			names.append(file)
	names.sort()
	check.call(names.size() >= 26, "at least 26 mechanism and trigger scenes (%d)" % names.size())
	for file: String in names:
		var stem: String = file.get_basename()
		var packed: PackedScene = load(DIR + file) as PackedScene
		var instance: Node = packed.instantiate()
		if not (instance is Mechanism or instance is SignalSource):
			instance.free()
			continue
		tree.root.add_child(instance)
		await tree.process_frame
		var found_look: bool = false
		var elements: Array[GlowElement] = []
		for node: Node in instance.find_children("*", "MeshInstance3D", true, false):
			var mesh_node: MeshInstance3D = node as MeshInstance3D
			if looks.has(mesh_node.material_override):
				found_look = true
			if mesh_node is GlowElement:
				elements.append(mesh_node)
		check.call(found_look, "%s: a mesh carries a shared brass, copper or iron material" % stem)
		check.call(not elements.is_empty(), "%s: has a GlowElement" % stem)
		for element: GlowElement in elements:
			var faceted: bool = element.mesh != null and not (element.mesh is SphereMesh)
			var bezel: MeshInstance3D = element.get_node_or_null("Bezel") as MeshInstance3D
			check.call(faceted and bezel != null, "%s/%s: faceted core with a bezel" % [stem, element.name])
			if not LENS_STYLES.has(stem):
				check.call(element.material_override == energy, "%s/%s: the core uses glow_energy" % [stem, element.name])
		if LENS_STYLES.has(stem):
			var interactable: Interactable = instance.get_node("Interactable") as Interactable
			var lens: Node = interactable.glow_meshes[0]
			check.call(lens is GlowElement and lens.name == &"GlowLens", "%s: glow_meshes[0] is a GlowElement named GlowLens" % stem)
			if lens is GlowElement:
				check.call((lens as GlowElement).style == LENS_STYLES[stem], "%s: lens style %d" % [stem, LENS_STYLES[stem]])
		instance.queue_free()
		await tree.process_frame

	var first: Node = (load(DIR + "lever.tscn") as PackedScene).instantiate()
	var second: Node = (load(DIR + "lever.tscn") as PackedScene).instantiate()
	tree.root.add_child(first)
	tree.root.add_child(second)
	await tree.process_frame
	var lens_a: GlowElement = first.get_node("Handle/GlowLens") as GlowElement
	var lens_b: GlowElement = second.get_node("Handle/GlowLens") as GlowElement
	check.call(lens_a.mesh == lens_b.mesh, "two levers share the same core Mesh")
	check.call(lens_a.get_node("Bezel").material_override == lens_b.get_node("Bezel").material_override, "two levers share the bezel material")
	check.call(lens_a.get_node("Bezel").mesh == lens_b.get_node("Bezel").mesh, "two levers share the bezel Mesh")
	var interactable: Interactable = first.get_node("Interactable") as Interactable
	interactable.set_glow_stage(Interactable.GlowStage.TARGET)
	check.call(lens_a.material_override == load(GLOW_TARGET), "the target stage sets glow_target on the lens")
	first.queue_free()
	second.queue_free()
	await tree.process_frame
