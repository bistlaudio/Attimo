class_name HandPresentation
extends Node
## Presentation of the prosthetic hand's energy (D-07b, D-04, D-08, D-10). Reads the HandController and the EventBus,
## never drives the hand. The palm of hand.r glows (brighter while charging), flashes on every shot (the shot itself is a flying ball, never a beam, D-17) and pulses while near
## contact holds; the forearm light glows on near contact. Everything hangs on the Mannequin skeleton through BoneAttachment3D. No particles, no animation player.

## Turquoise of the hand energy (the same language as the glow stages, D-07b).
const ENERGY_COLOR: Color = Color(0.25, 0.9, 0.85, 1.0)
const HAND_BONE: StringName = &"hand.r"
const FOREARM_BONE: StringName = &"lowerarm.r"
const PALM_RADIUS: float = 0.06
const BASE_ENERGY: float = 0.4
const CHARGE_ENERGY: float = 2.0
const FLASH_ENERGY: float = 5.0
const FLASH_TIME: float = 0.12
const NEAR_PULSE_HZ: float = 6.0
const NEAR_ENERGY: float = 2.0
const NEAR_SWING: float = 1.0
const LIGHT_RANGE: float = 1.2
const LIGHT_SCALE: float = 0.4

@export var player: PlayerController
@export var mannequin: Node3D

var _hand: HandController
var _palm: MeshInstance3D
var _palm_material: StandardMaterial3D
var _palm_light: OmniLight3D
var _arm_light: OmniLight3D
var _flash: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	if player != null:
		_hand = player.get_node_or_null(^"HandController") as HandController
	var skeleton: Skeleton3D = BoneAttach.skeleton_of(mannequin)
	if skeleton == null or skeleton.find_bone(HAND_BONE) < 0:
		set_process(false)
		return
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
	EventBus.shot_fired.connect(_on_shot_fired)


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - FLASH_ENERGY * delta / FLASH_TIME, 0.0)
	var energy: float = BASE_ENERGY
	var near: bool = _hand != null and _hand.near_target != null
	if _hand != null and _hand.charging:
		energy += CHARGE_ENERGY * _hand.charge_ratio
	energy += _flash
	var arm_energy: float = 0.0
	if near:
		var pulse: float = NEAR_ENERGY + NEAR_SWING * sin(_time * TAU * NEAR_PULSE_HZ)
		energy = maxf(energy, pulse)
		arm_energy = pulse
	_palm_material.emission_energy_multiplier = energy
	_palm_light.light_energy = energy * LIGHT_SCALE
	_arm_light.light_energy = arm_energy * LIGHT_SCALE


## Palm flash on a fired shot (D-04, presentation only).
func _on_shot_fired(_origin: Vector3, _direction: Vector3, _energy: float) -> void:
	_flash = FLASH_ENERGY


func _make_light(light_name: StringName) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = light_name
	light.light_color = ENERGY_COLOR
	light.omni_range = LIGHT_RANGE
	light.shadow_enabled = false
	light.light_energy = 0.0
	return light
