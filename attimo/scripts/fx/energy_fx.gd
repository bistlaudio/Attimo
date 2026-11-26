class_name EnergyFx
extends Node
## Energy feedback (user request 2026-11-25, placeholder ahead of the Phase 12 juice and Phase 14 audio). Lives in scripts/fx, outside
## the gameplay folders the feedback guard watches: it only reads ArmEnergy and the EventBus and never writes gameplay state.
## - Spending energy sprays turquoise sparks from the forearm cores ONLY: a burst for every spend (every cost is a whole step, D-34:
##   dash, air dash, wall run, wall jump, Loader bonus). The dash hop shows no burst: its stages show the cream MovementPuffs instead,
##   because movement visuals are never turquoise.
## - Gaining energy draws lighter turquoise sparks from a shell around the arm into the cores.
## - Placeholder audio: a short beep per spend, a soft charge hum whose pitch rises with the fill.
## Detection: ArmEnergy.value is polled every frame, so every spender and every income is covered without new facts. The emitters hang
## on ArmEnergyPresentation.core_parent() (the forearm BoneAttachment3D) and carry the meta FX_META, so scene tests can tell them apart.

const ENERGY_COLOR: Color = ArmEnergyPresentation.ENERGY_COLOR
## Meta set on every emitter of this node.
const FX_META: StringName = &"energy_fx"
## A drop of at least this many steps in one frame counts as a spend (burst); every spend is a whole step.
const BURST_MIN_DROP: int = 1
## Seconds the charge inflow and hum keep running after the last gain.
const FX_LINGER: float = 0.15
## Spend reasons that show no turquoise burst (their move shows a movement puff).
const NO_BURST_REASONS: Array[StringName] = [&"dash_hop"]
## Milliseconds after such a spend fact during which a burst is suppressed (the poll sees the drop a frame later).
const NO_BURST_WINDOW_MS: int = 120
const SPEND_BEEP_COOLDOWN: float = 0.08
const SPEND_BEEP_HZ: float = 520.0
const SPEND_BEEP_SECONDS: float = 0.07
## Charge hum pitch: CHARGE_HUM_BASE_HZ at an empty arm, rising by CHARGE_HUM_SPAN_HZ to a full arm.
const CHARGE_HUM_BASE_HZ: float = 220.0
const CHARGE_HUM_SPAN_HZ: float = 220.0
const CHARGE_HUM_DB: float = -26.0
const PARTICLE_SIZE: float = 0.03
## Where on the forearm the sparks start (bone space, the middle of the core row).
const EMIT_OFFSET: Vector3 = Vector3(0.0, 0.19, 0.05)
## Steampunk income spark (D-43): a small brass gear flies from the element to the arm core in this many real seconds, then frees itself.
const SPARK_TIME: float = 0.35
const SPARK_RADIUS: float = 0.12
const SPARK_THICKNESS: float = 0.05
const SPARK_BRASS: StandardMaterial3D = preload("res://resources/mechanisms/look_brass.tres")

@export var player: PlayerController
@export var presentation: ArmEnergyPresentation

var burst_particles: CPUParticles3D
var charge_particles: CPUParticles3D

## Pitch and length of the soft tick that plays on an income step (placeholder audio).
const TICK_BEEP_HZ: float = 880.0
const TICK_BEEP_SECONDS: float = 0.03

var _arm: ArmEnergy
var _spend_tone: PlaceholderTone
var _charge_tone: PlaceholderTone
var _prev_value: int = -1
var _charge_left: float = 0.0
var _spend_beep_cooldown: float = 0.0
var _no_burst_until_ms: int = 0


func _ready() -> void:
	if player != null:
		_arm = player.get_node_or_null(^"ArmEnergy") as ArmEnergy
	EventBus.energy_spent.connect(_on_energy_spent)
	EventBus.income_granted.connect(_on_income_granted)
	_spend_tone = PlaceholderTone.new()
	_spend_tone.name = &"SpendTone"
	add_child(_spend_tone)
	_charge_tone = PlaceholderTone.new()
	_charge_tone.name = &"ChargeTone"
	add_child(_charge_tone)
	# The presentation builds the forearm attachment in its own _ready; attach once the whole Player is ready.
	_attach_emitters.call_deferred()


func _exit_tree() -> void:
	if EventBus.energy_spent.is_connected(_on_energy_spent):
		EventBus.energy_spent.disconnect(_on_energy_spent)
	if EventBus.income_granted.is_connected(_on_income_granted):
		EventBus.income_granted.disconnect(_on_income_granted)


## True while the charge inflow runs (a gain in the last FX_LINGER seconds).
func charge_fx_active() -> bool:
	return _charge_left > 0.0


func _attach_emitters() -> void:
	var parent: Node = presentation.core_parent() if presentation != null else null
	if parent == null:
		return
	burst_particles = _make_particles(&"SpendBurst", 28, 0.45, 0.9, 2.5)
	burst_particles.one_shot = true
	charge_particles = _make_charge_particles()
	for emitter: CPUParticles3D in [burst_particles, charge_particles]:
		emitter.position = EMIT_OFFSET
		parent.add_child(emitter)


func _process(delta: float) -> void:
	var dt: float = TimeFx.unscaled(delta)
	_spend_beep_cooldown = maxf(_spend_beep_cooldown - dt, 0.0)
	_charge_left = maxf(_charge_left - dt, 0.0)
	if _arm == null:
		return
	var now: int = _arm.value
	if _prev_value >= 0:
		var change: int = now - _prev_value
		if change <= -BURST_MIN_DROP:
			if burst_particles != null and Time.get_ticks_msec() >= _no_burst_until_ms:
				burst_particles.restart()
			if _spend_beep_cooldown <= 0.0:
				_spend_tone.beep(SPEND_BEEP_HZ, SPEND_BEEP_SECONDS)
				_spend_beep_cooldown = SPEND_BEEP_COOLDOWN
		elif change > 0:
			_charge_left = FX_LINGER
			# One soft tick per income step (the clock hand ticks forward, D-35), not per frame.
			_spend_tone.beep(TICK_BEEP_HZ, TICK_BEEP_SECONDS)
	_prev_value = now
	if charge_particles != null:
		charge_particles.emitting = _charge_left > 0.0
	if _charge_left > 0.0:
		_charge_tone.set_hum(CHARGE_HUM_BASE_HZ + CHARGE_HUM_SPAN_HZ * clampf(float(now) / float(ArmEnergy.MAX_STEPS), 0.0, 1.0), CHARGE_HUM_DB)
	else:
		_charge_tone.stop_hum()


## A spend whose move shows its own movement puff (the dash hop) suppresses the next turquoise burst; the beep still plays.
func _on_energy_spent(_amount: int, reason: StringName) -> void:
	if reason in NO_BURST_REASONS:
		_no_burst_until_ms = Time.get_ticks_msec() + NO_BURST_WINDOW_MS


## A steampunk element gave steps: a brass gear (greybox mesh, no particles) flies from the element to the arm core and frees itself
## (T-05.1-44). The tween runs in real time, so the slow world of a Loader hold does not stretch it.
func _on_income_granted(position: Vector3, _steps: int, _source_id: StringName) -> void:
	var target_parent: Node3D = presentation.core_parent() as Node3D if presentation != null else null
	if target_parent == null or not is_inside_tree():
		return
	var gear: MeshInstance3D = MeshInstance3D.new()
	gear.name = &"IncomeSpark"
	gear.set_meta(FX_META, true)
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = SPARK_RADIUS
	cylinder.bottom_radius = SPARK_RADIUS
	cylinder.height = SPARK_THICKNESS
	cylinder.radial_segments = 8
	gear.mesh = cylinder
	gear.material_override = SPARK_BRASS
	gear.top_level = true
	add_child(gear)
	gear.global_position = position
	var tween: Tween = gear.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_method(func(t: float) -> void:
		if is_instance_valid(gear) and is_instance_valid(target_parent):
			gear.global_position = position.lerp(target_parent.to_global(EMIT_OFFSET), t)
			gear.rotation.z = t * TAU * 2.0, 0.0, 1.0, SPARK_TIME)
	tween.tween_callback(gear.queue_free)


## The charge emitter: sparks appear on a shell around the arm and are pulled inward (negative radial acceleration) in the arm's own
## space, so they flow into the cores and follow the arm. A lighter turquoise than the spend sparks, so income and spending read apart.
func _make_charge_particles() -> CPUParticles3D:
	var emitter: CPUParticles3D = _make_particles(&"ChargeInflow", 18, 0.4, 0.0, 0.0)
	emitter.local_coords = true
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	emitter.emission_sphere_radius = 0.45
	emitter.gravity = Vector3.ZERO
	emitter.damping_min = 0.0
	emitter.damping_max = 0.0
	emitter.radial_accel_min = -9.0
	emitter.radial_accel_max = -6.0
	var grow: Curve = Curve.new()
	grow.add_point(Vector2(0.0, 0.3))
	grow.add_point(Vector2(0.7, 1.0))
	grow.add_point(Vector2(1.0, 0.0))
	emitter.scale_amount_curve = grow
	var material: StandardMaterial3D = (emitter.mesh as BoxMesh).material as StandardMaterial3D
	material.albedo_color = ENERGY_COLOR.lightened(0.45)
	material.emission = ENERGY_COLOR.lightened(0.45)
	return emitter


## A turquoise spark emitter: small unshaded glowing boxes thrown outward in world space, shrinking over their lifetime.
func _make_particles(node_name: StringName, amount: int, lifetime: float, explosiveness: float, speed: float) -> CPUParticles3D:
	var emitter: CPUParticles3D = CPUParticles3D.new()
	emitter.name = node_name
	emitter.set_meta(FX_META, true)
	emitter.emitting = false
	emitter.amount = amount
	emitter.lifetime = lifetime
	emitter.explosiveness = explosiveness
	emitter.local_coords = false
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 0.06
	emitter.direction = Vector3.UP
	emitter.spread = 180.0
	emitter.initial_velocity_min = speed * 0.5
	emitter.initial_velocity_max = speed
	emitter.gravity = Vector3(0.0, -1.5, 0.0)
	emitter.damping_min = 2.0
	emitter.damping_max = 4.0
	var shrink: Curve = Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	emitter.scale_amount_curve = shrink
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE * PARTICLE_SIZE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = ENERGY_COLOR
	material.emission_enabled = true
	material.emission = ENERGY_COLOR
	material.emission_energy_multiplier = 3.0
	box.material = material
	emitter.mesh = box
	return emitter
