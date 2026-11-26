class_name Interactable
extends Node
## The HAND-02 contract component: what near contact (E) may trigger (D-45, D-46: the shot is gone, so there is no shot stage and no
## pulse payload). accepts_near is the only decider; the HandController calls near_begin / near_hold / near_end. Add it as a child of
## the thing and point hit_body at its collision body.

const GLOW_IDLE_MATERIAL: StandardMaterial3D = preload("res://resources/mechanisms/glow_idle.tres")
const GLOW_TARGET_MATERIAL: StandardMaterial3D = preload("res://resources/mechanisms/glow_target.tres")
## Emission energy of the brightest stage.
const GLOW_TARGET_ENERGY: float = 3.0

## The kind value interactable_triggered carries for a near contact (kept from the removed shot kinds).
const KIND_NEAR: int = 1

## Glow stages of the shared turquoise materials (D-11): faint always, brightest when marked.
enum GlowStage { IDLE, TARGET }

signal near_started()
signal near_held(delta: float)
signal near_ended()

## True when near contact (hold E beside it) may use this Interactable.
@export var accepts_near: bool = false
## The body the hand rays hit. It is moved onto the Interactable layer with mask 0 in _ready.
@export var hit_body: CollisionObject3D
## Where the crosshair and the glow aim at; the hit body position when unset.
@export var aim_point: Node3D
## Meshes whose material the glow stages switch.
@export var glow_meshes: Array[MeshInstance3D] = []


## The current glow stage (read-only for others).
var glow_stage: int = GlowStage.IDLE


func _ready() -> void:
	add_to_group(&"interactable")
	set_glow_stage(GlowStage.IDLE)
	if hit_body != null:
		hit_body.collision_layer = PhysicsLayers.INTERACTABLE
		hit_body.collision_mask = 0
		hit_body.set_meta(&"interactable", self)


## Switches the glow meshes to the shared material of `stage` (the same resource instance on every Interactable).
func set_glow_stage(stage: int) -> void:
	glow_stage = stage
	var material: StandardMaterial3D = GLOW_IDLE_MATERIAL
	match stage:
		GlowStage.TARGET:
			material = GLOW_TARGET_MATERIAL
	for mesh: MeshInstance3D in glow_meshes:
		if is_instance_valid(mesh):
			mesh.material_override = material


func near_begin() -> bool:
	if not accepts_near:
		return false
	near_started.emit()
	EventBus.interactable_triggered.emit(get_parent(), KIND_NEAR)
	return true


func near_hold(delta: float) -> void:
	near_held.emit(delta)


func near_end() -> void:
	near_ended.emit()


func target_point() -> Vector3:
	if aim_point != null:
		return aim_point.global_position
	if hit_body != null:
		return hit_body.global_position
	return Vector3.ZERO


## The Interactable that owns `collider` (set as meta by the hit body), or null.
static func from_collider(collider: Object) -> Interactable:
	if collider == null or not collider.has_meta(&"interactable"):
		return null
	return collider.get_meta(&"interactable") as Interactable
