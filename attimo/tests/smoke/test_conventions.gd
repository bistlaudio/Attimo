extends RefCounted
## FOUND-03 guard: collision layer names, PhysicsLayers constants, the Player's layer/mask and
## docs/CONVENTIONS.md stay in sync with project.godot.

const Fixtures := preload("res://tests/fixtures.gd")

const LAYER_NAMES: Array[String] = ["World", "Player", "Interactable", "Enemy", "Projectile/Beam", "Hazard"]
const ACTIONS: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right",
	"look_left", "look_right", "look_up", "look_down",
	"jump", "sprint", "dash", "aim", "use_hand", "interact",
	"module_next", "module_prev", "pause", "debug_event_log",
]
const FOLDERS: Array[String] = ["autoload/", "scenes/", "scripts/", "assets/", "tests/", "tools/"]
## Fixed read-only path, relative to the project root (attimo/).
const DOC_RELATIVE_PATH: String = "../docs/CONVENTIONS.md"


func run(tree: SceneTree, check: Callable) -> void:
	_check_layer_names(check)
	_check_constants(check)
	await _check_player_layers(tree, check)
	_check_doc(check)


func _check_layer_names(check: Callable) -> void:
	for i: int in LAYER_NAMES.size():
		var layer: int = i + 1
		var actual: String = str(ProjectSettings.get_setting("layer_names/3d_physics/layer_%d" % layer, ""))
		check.call(actual == LAYER_NAMES[i], "3d_physics layer %d is named %s (got '%s')" % [layer, LAYER_NAMES[i], actual])
	var unnamed: bool = true
	for layer: int in range(7, 33):
		var name_7_32: String = str(ProjectSettings.get_setting("layer_names/3d_physics/layer_%d" % layer, ""))
		if name_7_32 != "":
			unnamed = false
			check.call(false, "layer %d must stay unnamed and reserved (got '%s')" % [layer, name_7_32])
	check.call(unnamed, "3d_physics layers 7-32 are unnamed")


func _check_constants(check: Callable) -> void:
	check.call(PhysicsLayers.WORLD == 1, "PhysicsLayers.WORLD == 1")
	check.call(PhysicsLayers.PLAYER == 2, "PhysicsLayers.PLAYER == 2")
	check.call(PhysicsLayers.INTERACTABLE == 4, "PhysicsLayers.INTERACTABLE == 4")
	check.call(PhysicsLayers.ENEMY == 8, "PhysicsLayers.ENEMY == 8")
	check.call(PhysicsLayers.PROJECTILE == 16, "PhysicsLayers.PROJECTILE == 16")
	check.call(PhysicsLayers.HAZARD == 32, "PhysicsLayers.HAZARD == 32")


func _check_player_layers(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	check.call(player.collision_layer == PhysicsLayers.PLAYER, "Player sits on the Player layer (got %d)" % player.collision_layer)
	check.call(player.collision_mask == PhysicsLayers.WORLD, "Player masks the World layer (got %d)" % player.collision_mask)
	check.call(player.is_in_group(&"player"), "Player is in group 'player'")
	player.queue_free()
	await tree.process_frame


func _check_doc(check: Callable) -> void:
	var doc_path: String = ProjectSettings.globalize_path("res://").path_join(DOC_RELATIVE_PATH).simplify_path()
	check.call(FileAccess.file_exists(doc_path), "docs/CONVENTIONS.md exists (%s)" % doc_path)
	var doc: String = FileAccess.get_file_as_string(doc_path)
	check.call(doc.length() > 0, "docs/CONVENTIONS.md is readable and not empty")
	for layer_name: String in LAYER_NAMES:
		check.call(doc.contains(layer_name), "doc mentions layer %s" % layer_name)
	for action: String in ACTIONS:
		check.call(doc.contains(action), "doc mentions action %s" % action)
	check.call(doc.to_lower().contains("reserved"), "doc uses the word 'reserved' (gamepad slots, layers 7-32)")
	check.call(doc.contains("player"), "doc mentions group 'player'")
	for folder: String in FOLDERS:
		check.call(doc.contains(folder), "doc mentions folder %s" % folder)
