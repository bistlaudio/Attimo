class_name HandPresentation
extends Node
## Presentation of the prosthetic hand's energy (D-07b, D-04, D-08, D-10). Reads the HandController and the EventBus,
## never drives the hand. The palm of hand.r glows at a base level and pulses while near
## contact holds; the forearm light glows on near contact. Everything hangs on the Mannequin skeleton through BoneAttachment3D. No particles, no animation player.

## Turquoise of the hand energy (the same language as the glow stages, D-07b).
const ENERGY_COLOR: Color = Color(0.25, 0.9, 0.85, 1.0)
const HAND_BONE: StringName = &"hand.r"
const FOREARM_BONE: StringName = &"lowerarm.r"
const PALM_RADIUS: float = 0.06
const BASE_ENERGY: float = 0.4
const NEAR_PULSE_HZ: float = 6.0
const NEAR_ENERGY: float = 2.0
const NEAR_SWING: float = 1.0
const LIGHT_RANGE: float = 1.2
const LIGHT_SCALE: float = 0.4
## The Extractor beam (D-44): a thin turquoise mesh cylinder from the palm to the source, no particles.
const BEAM_RADIUS: float = 0.03
const BEAM_ENERGY: float = 2.5
## Shorter than this (or not finite) the beam is hidden instead of getting a degenerate transform (T-05.1-30).
const BEAM_MIN_LENGTH: float = 0.05

@export var player: PlayerController
@export var mannequin: Node3D

var _hand: HandController
var _palm: MeshInstance3D
var _palm_material: StandardMaterial3D
var _palm_light: OmniLight3D
var _arm_light: OmniLight3D
var _beam: MeshInstance3D
var _time: float = 0.0


func _ready() -> void:
	if player != null:
		_hand = player.get_node_or_null(^"HandController") as HandController
	var skeleton: Skeleton3D = BoneAttach.skeleton_of(mannequin)
	if skeleton == null or skeleton.find_bone(HAND_BONE) < 0:
		set_process(false)
		return
	# After the animation tree and the arm solver, so the beam starts at this frame's palm.
	process_priority = 1000
	var hand_attachment: BoneAttachment3D = BoneAttach.attach(skeleton, HAND_BONE)
	_palm_material = StandardMaterial3D.new()
	_palm_material.albedo_color = ENERGY_COLOR.darkened(0.7)
	_palm_material.emission_enabled = true
	_palm_material.emission = ENERGY_COLOR
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = PALM_RADIUS
	sphere.height = PALM_RADIUS * 2.0
	_palm = MeshInstance3D.new()
	_palm.name = &"Palm"
	_palm.mesh = sphere
	_palm.material_override = _palm_material
	hand_attachment.add_child(_palm)
	_palm_light = _make_light(&"PalmLight")
	hand_attachment.add_child(_palm_light)
	var forearm_name: StringName = FOREARM_BONE
	if skeleton.find_bone(FOREARM_BONE) < 0:
		forearm_name = skeleton.get_bone_name(skeleton.get_bone_parent(skeleton.find_bone(HAND_BONE)))
	var arm_attachment: BoneAttachment3D = BoneAttach.attach(skeleton, forearm_name)
	_arm_light = _make_light(&"ArmLight")
	arm_attachment.add_child(_arm_light)
	_beam = _make_beam()
	mannequin.add_child(_beam)


func _process(delta: float) -> void:
	_time += delta
	var energy: float = BASE_ENERGY
	var near: bool = _hand != null and _hand.near_target != null
	var arm_energy: float = 0.0
	if near:
		var pulse: float = NEAR_ENERGY + NEAR_SWING * sin(_time * TAU * NEAR_PULSE_HZ)
		energy = maxf(energy, pulse)
		arm_energy = pulse
	_palm_material.emission_energy_multiplier = energy
	_palm_light.light_energy = energy * LIGHT_SCALE
	_arm_light.light_energy = arm_energy * LIGHT_SCALE
	_update_beam()


## Shows the beam from the palm to the source while the active module holds the arm out and has a point (the Extractor drain);
## the cylinder (height 1) is stretched along y to the distance. Hidden on release, when the source is empty and when the arm is full.
func _update_beam() -> void:
	var module: HandModule = _hand.active_module if _hand != null else null
	if module == null or not module.holds_arm_out():
		_beam.visible = false
		return
	var target: Vector3 = module.arm_point()
	var start: Vector3 = _palm.global_position
	var offset: Vector3 = target - start
	if not target.is_finite() or not start.is_finite() or not offset.is_finite() or offset.length() < BEAM_MIN_LENGTH:
		_beam.visible = false
		return
	var length: float = offset.length()
	var axis: Vector3 = offset / length
	var helper: Vector3 = Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x_axis: Vector3 = helper.cross(axis).normalized()
	var z_axis: Vector3 = x_axis.cross(axis)
	_beam.global_transform = Transform3D(Basis(x_axis, axis * length, z_axis), start + offset * 0.5)
	_beam.visible = true


func _make_beam() -> MeshInstance3D:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = BEAM_RADIUS
	cylinder.bottom_radius = BEAM_RADIUS
	cylinder.height = 1.0
	cylinder.radial_segments = 8
	cylinder.rings = 1
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = ENERGY_COLOR
	material.emission_enabled = true
	material.emission = ENERGY_COLOR
	material.emission_energy_multiplier = BEAM_ENERGY
	var beam: MeshInstance3D = MeshInstance3D.new()
	beam.name = &"ExtractorBeam"
	beam.mesh = cylinder
	beam.material_override = material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.top_level = true
	beam.visible = false
	return beam


func _make_light(light_name: StringName) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = light_name
	light.light_color = ENERGY_COLOR
	light.omni_range = LIGHT_RANGE
	light.shadow_enabled = false
	light.light_energy = 0.0
	return light
