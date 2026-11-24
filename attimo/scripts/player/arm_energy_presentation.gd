class_name ArmEnergyPresentation
extends Node
## Presentation of the arm energy on Rino's body (D-09, D-10, D-12). Reads ArmEnergy and the EventBus, never writes gameplay state.
## Four small emissive prisms sit in a row on the forearm (BoneAttachment3D, shared helper BoneAttach): full is bright, a partial core is
## dimmed by its fill, an empty one dark. A spent core flashes briefly, a refused action flickers the cores grey, and Moto Perpetuo
## brightens the arm and lights both feet and the back (bones foot.l, foot.r and chest; a missing bone is skipped) with a short flash
## on entry and a fade on exit. Greybox: emission on meshes only. No particles, no screen effect, no camera effect.
## Colour: the cores and Moto glow points use the energy turquoise ENERGY_COLOR, the same as HandPresentation. This is a recorded
## exception to the ROADMAP rule "turquoise only for interactables and hand feedback": the glow is energy feedback of the arm's state
## (D-10), GAME-DESIGN section 6 requires anything amplified to show turquoise, and CONTEXT checklist item 11 says turquoise = energy
## everywhere; movement visuals stay cream and amber, and the Phase 9 style contract revisits the player's glow.
## Group A exception (recorded, D-10, D-12): the spent-core flash, the grey flicker and the Moto flash and fade carry information
## (what was spent, what was refused, which state is active), so they are allowed; they never flash more than three times a second
## (a refusal during a running flicker does not restart it, a flash has a cooldown). Phase 12 polishes them.
## Time: everything runs on TimeFx.unscaled(delta), so the cues keep their real-time speed during the Loader slow motion.

## Turquoise of the arm energy (the same colour as HandPresentation and the glow stages).
const ENERGY_COLOR: Color = Color(0.25, 0.9, 0.85, 1.0)
## Grey of a refused action.
const REFUSED_COLOR: Color = Color(0.55, 0.57, 0.6, 1.0)
const FOREARM_BONE: StringName = &"lowerarm.r"
const HAND_BONE: StringName = &"hand.r"
const MOTO_BONES: Array[StringName] = [&"foot.l", &"foot.r", &"chest"]
const CORE_SIZE: Vector3 = Vector3(0.04, 0.04, 0.08)
## Spacing of the cores along the forearm (bone local Y is the bone axis).
const CORE_SPACING: float = 0.06
const CORE_OFFSET: Vector3 = Vector3(0.0, 0.1, 0.05)
const POINT_RADIUS: float = 0.07
const DARK_ENERGY: float = 0.05
const BRIGHT_ENERGY: float = 2.0
const FLASH_ENERGY: float = 5.0
## Seconds of a spent-core flash and of the Moto entry flash.
const FLASH_TIME: float = 0.15
## No new spent-core flash starts within this many seconds of the last one (flash limit: 3 per second).
const FLASH_COOLDOWN: float = 0.35
## One grey flicker: a refusal shows two grey flashes of FLICKER_ON seconds at a FLICKER_PERIOD (2.5 Hz, below 3 flashes per second).
const FLICKER_TIME: float = 0.8
const FLICKER_PERIOD: float = 0.4
const FLICKER_ON: float = 0.2
const MOTO_ARM_BOOST: float = 1.6
const MOTO_POINT_ENERGY: float = 2.5
const MOTO_FADE_IN: float = 0.05
const MOTO_FADE_OUT: float = 0.3
const MOTO_BEEP_HZ: float = 660.0
const MOTO_BEEP_SECONDS: float = 0.08

@export var player: PlayerController
@export var mannequin: Node3D

## The four core prisms, index 0 is the first core to fill.
var core_nodes: Array[MeshInstance3D] = []
## The Moto glow points (foot.l, foot.r, chest; only those whose bone exists).
var moto_points: Array[MeshInstance3D] = []

var _arm: ArmEnergy
var _core_parent: Node
var _moto_parents: Array[Node] = []
var _core_materials: Array[StandardMaterial3D] = []
var _point_materials: Array[StandardMaterial3D] = []
var _prev_fill: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _core_flash: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _flash_cooldown: float = 0.0
var _flicker_left: float = 0.0
var _moto_on: bool = false
var _moto_glow: float = 0.0
var _entry_flash: float = 0.0
var _initialised: bool = false
var _tone: PlaceholderTone


func _ready() -> void:
	if player != null:
		_arm = player.get_node_or_null(^"ArmEnergy") as ArmEnergy
	EventBus.energy_refused.connect(_on_energy_refused)
	_tone = PlaceholderTone.new()
	_tone.name = &"MotoTone"
	add_child(_tone)
	var skeleton: Skeleton3D = BoneAttach.skeleton_of(mannequin)
	if skeleton == null or _arm == null:
		set_process(false)
		return
	var forearm: StringName = FOREARM_BONE
	if skeleton.find_bone(forearm) < 0 and skeleton.find_bone(HAND_BONE) >= 0:
		forearm = skeleton.get_bone_name(skeleton.get_bone_parent(skeleton.find_bone(HAND_BONE)))
	var forearm_attachment: BoneAttachment3D = BoneAttach.attach(skeleton, forearm)
	if forearm_attachment == null:
		set_process(false)
		return
	_core_parent = forearm_attachment
	for i: int in ArmEnergy.CORE_COUNT:
		var material: StandardMaterial3D = _glow_material()
		var box: BoxMesh = BoxMesh.new()
		box.size = CORE_SIZE
		var core: MeshInstance3D = MeshInstance3D.new()
		core.name = StringName("Core%d" % i)
		core.mesh = box
		core.material_override = material
		core.position = CORE_OFFSET + Vector3(0.0, float(i) * CORE_SPACING, 0.0)
		forearm_attachment.add_child(core)
		core_nodes.append(core)
		_core_materials.append(material)
	for bone: StringName in MOTO_BONES:
		var attachment: BoneAttachment3D = BoneAttach.attach(skeleton, bone)
		if attachment == null:
			continue
		var material: StandardMaterial3D = _glow_material()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = POINT_RADIUS
		sphere.height = POINT_RADIUS * 2.0
		var point: MeshInstance3D = MeshInstance3D.new()
		point.name = StringName("Moto_%s" % String(bone).replace(".", "_"))
		point.mesh = sphere
		point.material_override = material
		point.visible = false
		attachment.add_child(point)
		moto_points.append(point)
		_point_materials.append(material)
		_moto_parents.append(attachment)


func _exit_tree() -> void:
	if EventBus.energy_refused.is_connected(_on_energy_refused):
		EventBus.energy_refused.disconnect(_on_energy_refused)


func _process(delta: float) -> void:
	var dt: float = TimeFx.unscaled(delta)
	_flash_cooldown = maxf(_flash_cooldown - dt, 0.0)
	_flicker_left = maxf(_flicker_left - dt, 0.0)
	_entry_flash = maxf(_entry_flash - dt, 0.0)
	_poll_fills(dt)
	_poll_moto(dt)
	_apply()


## The node the core prisms hang under (the forearm BoneAttachment3D), or null without a skeleton.
func core_parent() -> Node:
	return _core_parent


## The BoneAttachment3D parents of the Moto glow points.
func moto_parents() -> Array[Node]:
	return _moto_parents


## Emission energy multiplier of core `index` without the flash: lerp(dark, bright, fill) times the Moto arm boost.
func core_emission(index: int) -> float:
	if index < 0 or index >= ArmEnergy.CORE_COUNT or _arm == null:
		return 0.0
	return lerpf(DARK_ENERGY, BRIGHT_ENERGY, _arm.core_fill(index)) * arm_boost()


## Seconds left of the spent flash of core `index` (0.0 when none).
func core_flash_left(index: int) -> float:
	if index < 0 or index >= _core_flash.size():
		return 0.0
	return _core_flash[index]


## The colour of the cores when not flickering.
func core_color() -> Color:
	return ENERGY_COLOR


## True while a grey flicker runs.
func flicker_active() -> bool:
	return _flicker_left > 0.0


## True during a grey phase of the flicker.
func flicker_grey() -> bool:
	if _flicker_left <= 0.0:
		return false
	return fposmod(FLICKER_TIME - _flicker_left, FLICKER_PERIOD) < FLICKER_ON


## True while the Moto glow points show (on, or still fading out).
func moto_visible() -> bool:
	return _moto_glow > 0.001


## Seconds left of the Moto entry flash.
func moto_entry_flash_left() -> float:
	return _entry_flash


## Brightness factor of the arm: 1.0 without Moto, MOTO_ARM_BOOST in full Moto, faded in between.
func arm_boost() -> float:
	return lerpf(1.0, MOTO_ARM_BOOST, _moto_glow)


## A refusal starts the grey flicker; one that arrives during a running flicker does not restart it (flash limit).
func _on_energy_refused(_reason: StringName, _needed: float) -> void:
	if _flicker_left <= 0.0:
		_flicker_left = FLICKER_TIME


## A core that was full and lost energy flashes once; the next flash waits for the cooldown (3 flashes per second at most).
func _poll_fills(dt: float) -> void:
	for i: int in core_nodes.size():
		_core_flash[i] = maxf(_core_flash[i] - dt, 0.0)
	if _arm == null:
		return
	for i: int in core_nodes.size():
		var fill: float = _arm.core_fill(i)
		if _initialised and _prev_fill[i] >= 0.999 and fill < _prev_fill[i] - 0.001 and _flash_cooldown <= 0.0:
			_core_flash[i] = FLASH_TIME
			_flash_cooldown = FLASH_COOLDOWN
		_prev_fill[i] = fill
	_initialised = true


## Moto edges from polling the arm: on at once with an entry flash and a beep, off with a fade.
func _poll_moto(dt: float) -> void:
	var moto: bool = _arm != null and _arm.is_moto()
	if moto and not _moto_on:
		_entry_flash = FLASH_TIME
		_tone.beep(MOTO_BEEP_HZ, MOTO_BEEP_SECONDS)
	_moto_on = moto
	if moto:
		_moto_glow = minf(_moto_glow + dt / MOTO_FADE_IN, 1.0)
	else:
		_moto_glow = maxf(_moto_glow - dt / MOTO_FADE_OUT, 0.0)


func _apply() -> void:
	var tint: Color = REFUSED_COLOR if flicker_grey() else ENERGY_COLOR
	for i: int in _core_materials.size():
		var material: StandardMaterial3D = _core_materials[i]
		material.emission = tint
		material.albedo_color = tint.darkened(0.7)
		var flash: float = FLASH_ENERGY * (_core_flash[i] / FLASH_TIME)
		material.emission_energy_multiplier = core_emission(i) + flash
	var visible_now: bool = moto_visible()
	var point_energy: float = MOTO_POINT_ENERGY * _moto_glow + FLASH_ENERGY * (_entry_flash / FLASH_TIME)
	for i: int in moto_points.size():
		moto_points[i].visible = visible_now
		_point_materials[i].emission_energy_multiplier = point_energy


func _glow_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = ENERGY_COLOR.darkened(0.7)
	material.emission_enabled = true
	material.emission = ENERGY_COLOR
	material.emission_energy_multiplier = DARK_ENERGY
	return material
