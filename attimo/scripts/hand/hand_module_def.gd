class_name HandModuleDef
extends Resource
## One registry entry: id, display name and the module scene. A module is one folder plus one registry entry (D-24).

@export var id: StringName = &""
@export var display_name: String = ""
@export var scene: PackedScene
## Debug-only defs are skipped in release builds (T-04-03).
@export var debug_only: bool = false
