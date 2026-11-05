extends RefCounted
## FOUND-04 (D-01..D-05): only the whitelisted KayKit files live under res://assets, no raw pack sits inside
## the project, and the D-05 folder layout exists. The whitelist is fixed at planning time (2026-11-04); extended to 31 entries in Phase 2 plan 02-03 (Primitive_Slope, Primitive_Beam). Do not
## derive it from the disk: a new asset is a deliberate edit of this list, in the same change as the asset.
## The "raw packs stay tracked at the repo root" and "no Git LFS" checks live in tests/run.sh (they need git).

const ASSETS_DIR: String = "res://assets"

## Paths relative to res://assets/. Includes the two importer extractions of the Mannequin GLB's embedded image.
const WHITELIST: PackedStringArray = [
	"characters/mannequin/Mannequin_Medium.glb",
	"characters/mannequin/Mannequin_Medium.glb.import",
	"characters/mannequin/Mannequin_Medium_mannequin_texture.png",
	"characters/mannequin/Mannequin_Medium_mannequin_texture.png.import",
	"animations/rig_medium/Rig_Medium_General.glb",
	"animations/rig_medium/Rig_Medium_General.glb.import",
	"animations/rig_medium/Rig_Medium_MovementBasic.glb",
	"animations/rig_medium/Rig_Medium_MovementBasic.glb.import",
	"animations/rig_medium/Rig_Medium_MovementAdvanced.glb",
	"animations/rig_medium/Rig_Medium_MovementAdvanced.glb.import",
	"animations/rig_medium/rig_medium_library.res",
	"prototype_bits/prototypebits_texture.png",
	"prototype_bits/prototypebits_texture.png.import",
	"prototype_bits/Primitive_Floor.gltf",
	"prototype_bits/Primitive_Floor.gltf.import",
	"prototype_bits/Primitive_Floor.bin",
	"prototype_bits/Primitive_Wall.gltf",
	"prototype_bits/Primitive_Wall.gltf.import",
	"prototype_bits/Primitive_Wall.bin",
	"prototype_bits/Primitive_Cube_Small.gltf",
	"prototype_bits/Primitive_Cube_Small.gltf.import",
	"prototype_bits/Primitive_Cube_Small.bin",
	"prototype_bits/Primitive_Pillar.gltf",
	"prototype_bits/Primitive_Pillar.gltf.import",
	"prototype_bits/Primitive_Pillar.bin",
	"prototype_bits/Primitive_Slope.gltf",
	"prototype_bits/Primitive_Slope.gltf.import",
	"prototype_bits/Primitive_Slope.bin",
	"prototype_bits/Primitive_Beam.gltf",
	"prototype_bits/Primitive_Beam.gltf.import",
	"prototype_bits/Primitive_Beam.bin",
]

## D-05 layout plus tests and tools (A6).
const REQUIRED_DIRS: PackedStringArray = [
	"res://autoload",
	"res://scenes",
	"res://scripts",
	"res://assets",
	"res://tests",
	"res://tools",
]

const FORBIDDEN_EXTENSIONS: PackedStringArray = ["fbx", "obj"]


func run(_tree: SceneTree, check: Callable) -> void:
	check.call(WHITELIST.size() == 31, "the whitelist holds exactly 31 entries (got %d)" % WHITELIST.size())

	var found: PackedStringArray = PackedStringArray()
	_collect_files(ASSETS_DIR, found)
	var stray: int = 0
	for relative: String in found:
		if not WHITELIST.has(relative):
			stray += 1
			check.call(false, "unlisted file in res://assets: %s" % relative)
	check.call(stray == 0, "res://assets holds no file outside the whitelist (%d files found)" % found.size())
	var missing: int = 0
	for relative: String in WHITELIST:
		if not found.has(relative):
			missing += 1
			check.call(false, "whitelisted file missing from res://assets: %s" % relative)
	check.call(missing == 0, "every whitelisted file exists")

	var raw_pack_dirs: int = 0
	var forbidden_files: int = 0
	var all_files: PackedStringArray = PackedStringArray()
	var all_dirs: PackedStringArray = PackedStringArray()
	_walk_project("res://", all_files, all_dirs)
	for dir_path: String in all_dirs:
		if dir_path.get_file().to_lower().contains("kaykit"):
			raw_pack_dirs += 1
			check.call(false, "raw pack folder inside the project: %s" % dir_path)
	for file_path: String in all_files:
		if FORBIDDEN_EXTENSIONS.has(file_path.get_extension().to_lower()):
			forbidden_files += 1
			check.call(false, "raw .fbx/.obj file inside the project: %s" % file_path)
	check.call(raw_pack_dirs == 0, "no kaykit directory inside the project (%d directories scanned)" % all_dirs.size())
	check.call(forbidden_files == 0, "no .fbx or .obj file inside the project (%d files scanned)" % all_files.size())

	for dir_path: String in REQUIRED_DIRS:
		check.call(DirAccess.dir_exists_absolute(dir_path), "folder exists: %s" % dir_path)


## Collects file paths relative to ASSETS_DIR, recursively.
func _collect_files(dir_path: String, into: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		into.append(dir_path.path_join(file_name).trim_prefix(ASSETS_DIR + "/"))
	for sub: String in dir.get_directories():
		_collect_files(dir_path.path_join(sub), into)


## Walks res:// except hidden folders such as .godot.
func _walk_project(dir_path: String, files: PackedStringArray, dirs: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		files.append(dir_path.path_join(file_name))
	for sub: String in dir.get_directories():
		if sub.begins_with("."):
			continue
		var sub_path: String = dir_path.path_join(sub)
		dirs.append(sub_path)
		_walk_project(sub_path, files, dirs)
