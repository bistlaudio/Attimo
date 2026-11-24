class_name Interactable
extends Node
## The HAND-02 contract component: what a hand module may trigger. It declares the accepted modules, whether it accepts
## the shot, near contact or both, and the minimum pulse size. accepts_module and can_accept are the only deciders;
## modules only call try_trigger. Add it as a child of the thing and point hit_body at its collision body.

const GLOW_IDLE_MATERIAL: StandardMaterial3D = preload("res://resources/mechanisms/glow_idle.tres")
const GLOW_SHOT_READY_MATERIAL: StandardMaterial3D = preload("res://resources/mechanisms/glow_shot_ready.tres")
const GLOW_TARGET_MATERIAL: StandardMaterial3D = preload("res://resources/mechanisms/glow_target.tres")
## Emission energy of the brightest stage before Targeting adds its pulse.
const GLOW_TARGET_ENERGY: float = 3.0

## Glow stages of the shared turquoise materials (D-11, D-28): faint always, stronger while the shot module is equipped and the arm can
## shoot (SHOT_READY, driven by EventBus.shot_ready_changed), brightest when targeted.
enum GlowStage { IDLE, SHOT_READY, TARGET }

signal triggered(hit: PulseHit)
signal near_started()
signal near_held(delta: float)
signal near_ended()

@export var accepted_modules: Array[StringName] = [&"remote_trigger"]
@export var accepts_shot: bool = true
@export var accepts_near: bool = false
@export var min_pulse: PulseHit.Size = PulseHit.Size.SMALL
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
	EventBus.shot_ready_changed.connect(_on_shot_ready_changed)
	# An Interactable that enters after the shot module was equipped starts at the stage the others already show.
	var hand: HandController = get_tree().get_first_node_in_group(&"hand_controller") as HandController
	if hand != null and hand.shot_ready:
		set_glow_stage(GlowStage.SHOT_READY)
	if hit_body != null:
		hit_body.collision_layer = PhysicsLayers.INTERACTABLE
		hit_body.collision_mask = 0
		hit_body.set_meta(&"interactable", self)


## Switches the glow meshes to the shared material of `stage` (the same resource instance on every Interactable).
func set_glow_stage(stage: int) -> void:
	glow_stage = stage
	var material: StandardMaterial3D = GLOW_IDLE_MATERIAL
	match stage:
		GlowStage.SHOT_READY:
			material = GLOW_SHOT_READY_MATERIAL
		GlowStage.TARGET:
			material = GLOW_TARGET_MATERIAL
	for mesh: MeshInstance3D in glow_meshes:
		if is_instance_valid(mesh):
			mesh.material_override = material


func _on_shot_ready_changed(ready: bool) -> void:
	if glow_stage == GlowStage.TARGET:
		return
	set_glow_stage(GlowStage.SHOT_READY if ready else GlowStage.IDLE)


func accepts_module(id: StringName) -> bool:
	return accepted_modules.has(id)


func can_accept(kind: PulseHit.Kind, size: PulseHit.Size) -> bool:
	match kind:
		PulseHit.Kind.SHOT:
			return accepts_shot and size >= min_pulse
		PulseHit.Kind.NEAR:
			return accepts_near
	return false


## Runs the hit synchronously. False when the contract rejects it.
func try_trigger(hit: PulseHit) -> bool:
	if hit == null or not can_accept(hit.kind, hit.size):
		return false
	if hit.kind == PulseHit.Kind.SHOT and not accepts_module(hit.module_id):
		return false
	triggered.emit(hit)
	EventBus.interactable_triggered.emit(get_parent(), int(hit.kind))
	return true


func near_begin() -> bool:
	if not accepts_near:
		return false
	near_started.emit()
	EventBus.interactable_triggered.emit(get_parent(), int(PulseHit.Kind.NEAR))
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
