class_name HandPresentation
extends Node
## Presentation of the prosthetic hand's energy (D-07b, D-04, D-08, D-10). Reads the HandController and the EventBus,
## never drives the hand. The palm of hand.r glows (brighter while charging), flashes on every pulse and pulses while near
## contact holds; a thin streak shows the pulse from the palm to the hit point for a moment; the forearm light glows on
## near contact. Everything hangs on the Mannequin skeleton through BoneAttachment3D. No particles, no animation player.

## Turquoise of the hand energy (the same language as the glow stages, D-07b).
const ENERGY_COLOR: Color = Color(0.25, 0.9, 0.85, 1.0)
const HAND_BONE: StringName = &"hand.r"
const FOREARM_BONE: StringName = &"lowerarm.r"
const SKELETON_PATH: NodePath = ^"Rig_Medium/Skeleton3D"
const PALM_RADIUS: float = 0.06
const BASE_ENERGY: float = 0.4
const CHARGE_ENERGY: float = 2.0
const FLASH_ENERGY: float = 5.0
const FLASH_TIME: float = 0.12
const STREAK_TIME: float = 0.08
const STREAK_WIDTH: float = 0.03
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
var _streak: MeshInstance3D
var _flash: float = 0.0
var _streak_left: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	if player != null:
		_hand = player.get_node_or_null(^"HandController") as HandController
	var skeleton: Skeleton3D = null
	if mannequin != null:
		skeleton = mannequin.get_node_or_null(SKELETON_PATH) as Skeleton3D
	if skeleton == null or skeleton.find_bone(HAND_BONE) < 0:
		set_process(false)
		return
	var hand_attachment: BoneAttachment3D = _attach(skeleton, HAND_BONE)
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
	var arm_attachment: BoneAttachment3D = _attach(skeleton, forearm_name)
	_arm_light = _make_light(&"ArmLight")
	arm_attachment.add_child(_arm_light)
	var streak_material: StandardMaterial3D = StandardMaterial3D.new()
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.albedo_color = ENERGY_COLOR
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(STREAK_WIDTH, STREAK_WIDTH, 1.0)
	_streak = MeshInstance3D.new()
	_streak.name = &"Streak"
	_streak.mesh = box
	_streak.material_override = streak_material
	_streak.top_level = true
	_streak.visible = false
	hand_attachment.add_child(_streak)
	EventBus.pulse_fired.connect(_on_pulse_fired)


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
	if _streak_left > 0.0:
		_streak_left -= delta
		if _streak_left <= 0.0:
			_streak.visible = false


## Flash and streak on a fired pulse (D-04, presentation only).
func _on_pulse_fired(_origin: Vector3, point: Vector3, _size: int, _hit_valid: bool) -> void:
	_flash = FLASH_ENERGY
	if _streak == null or not point.is_finite():
		return
	var start: Vector3 = _palm.global_position
	var offset: Vector3 = point - start
	var distance: float = offset.length()
	if distance < 0.01:
		return
	var direction: Vector3 = offset / distance
	var up: Vector3 = Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	_streak.global_position = start + offset * 0.5
	_streak.look_at(point, up)
	_streak.scale = Vector3(1.0, 1.0, distance)
	_streak.visible = true
	_streak_left = STREAK_TIME


func _attach(skeleton: Skeleton3D, bone: StringName) -> BoneAttachment3D:
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = StringName("%sAttachment" % String(bone).replace(".", "_"))
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	return attachment


func _make_light(light_name: StringName) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = light_name
	light.light_color = ENERGY_COLOR
	light.omni_range = LIGHT_RANGE
	light.shadow_enabled = false
	light.light_energy = 0.0
	return light
