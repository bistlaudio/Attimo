class_name MovementPuffs
extends Node3D
## Movement dust puffs (user request 2026-11-25, placeholder ahead of the Phase 11 juice catalogue): every jump (Jump 1, 2 and 3)
## and every dash-hop stage (1, 2 and 3) kicks up one cream puff at Rino's feet. All puffs share ONE colour and are never turquoise:
## turquoise is reserved for energy (ArmEnergyPresentation), movement visuals stay cream, warm white or amber (ROADMAP rule).
## Listens to the EventBus facts jumped and long_jumped only; never writes gameplay state. Each puff is a one-shot CPUParticles3D in
## world space that frees itself after its lifetime and carries the meta energy_fx (the scene tests' fx marker). A later stage throws a slightly bigger puff, the colour never changes.

## The one puff colour for every jump and dash-hop stage (warm cream).
const PUFF_COLOR: Color = Color(0.96, 0.9, 0.76, 1.0)
const PUFF_SIZE: float = 0.07
const PUFF_LIFETIME: float = 0.4
## Particles of a plain jump puff and of a stage-1 dash-hop puff; each further dash-hop stage adds STAGE_EXTRA.
const JUMP_AMOUNT: int = 12
const HOP_AMOUNT: int = 14
const STAGE_EXTRA: int = 5


func _ready() -> void:
	top_level = true
	EventBus.jumped.connect(_on_jumped)
	EventBus.long_jumped.connect(_on_long_jumped)


func _exit_tree() -> void:
	if EventBus.jumped.is_connected(_on_jumped):
		EventBus.jumped.disconnect(_on_jumped)
	if EventBus.long_jumped.is_connected(_on_long_jumped):
		EventBus.long_jumped.disconnect(_on_long_jumped)


func _on_jumped(position: Vector3) -> void:
	spawn_puff(position, JUMP_AMOUNT, 1.0)


func _on_long_jumped(position: Vector3, stage: int) -> void:
	var extra: int = maxi(stage - 1, 0)
	spawn_puff(position, HOP_AMOUNT + STAGE_EXTRA * extra, 1.0 + 0.2 * float(extra))


## Spawns one self-freeing dust puff at `at` (Rino's feet). Returns the emitter, or null for a non-finite position.
func spawn_puff(at: Vector3, amount: int, scale_factor: float) -> CPUParticles3D:
	if not at.is_finite() or not is_inside_tree():
		return null
	var emitter: CPUParticles3D = CPUParticles3D.new()
	emitter.name = &"Puff"
	emitter.set_meta(&"energy_fx", true)
	emitter.one_shot = true
	emitter.amount = maxi(amount, 1)
	emitter.lifetime = PUFF_LIFETIME
	emitter.explosiveness = 0.95
	emitter.local_coords = false
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	emitter.emission_ring_axis = Vector3.UP
	emitter.emission_ring_radius = 0.25 * scale_factor
	emitter.emission_ring_inner_radius = 0.1
	emitter.emission_ring_height = 0.05
	emitter.direction = Vector3.UP
	emitter.spread = 70.0
	emitter.initial_velocity_min = 1.0 * scale_factor
	emitter.initial_velocity_max = 2.5 * scale_factor
	emitter.gravity = Vector3(0.0, -2.0, 0.0)
	emitter.damping_min = 3.0
	emitter.damping_max = 5.0
	var shrink: Curve = Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	emitter.scale_amount_curve = shrink
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE * PUFF_SIZE * scale_factor
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = PUFF_COLOR
	box.material = material
	emitter.mesh = box
	add_child(emitter)
	emitter.global_position = at + Vector3(0.0, 0.05, 0.0)
	emitter.emitting = true
	get_tree().create_timer(PUFF_LIFETIME + 0.2, false).timeout.connect(emitter.queue_free)
	return emitter
