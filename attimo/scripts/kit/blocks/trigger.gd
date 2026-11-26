class_name Trigger
extends KitBlock
## Trigger block (Phase 05.1, KIT-01, D-13, D-21, D-47): the kit emitter, the atomic rename of the old SignalSource. A boolean signal that
## receivers and old mechanisms listen to: they connect to active_changed and never ask who the source is. The invisible AND / OR / timer
## logic nodes extend it (scripts/kit/logic/), as do the energy core (plan 05.1-18 reworks it into a Trigger profile) and a plain
## `Trigger.new()` used as a signal driver in tests. `config` is null for those; a profile object (TriggerConfig, preset per object) sets
## the behaviour of a visible trigger.
##
## Profile CHARGE_GATE (D-21, D-47): a check volume, not a door. It is active while the player stands inside it with at least
## `threshold` steps on the clock. It only READS the arm energy: it never spends, never refills (T-05.1-53). The threshold shows as
## `threshold` turquoise marks (GlowElement children of the Marks node, laid out like clock ticks along the lintel).
## set_active emits only on a change, so a wiring loop cannot recurse (T-05.1-51).
##
## Profile ENERGY_CORE (D-20 amended, D-37, D-39, D-47): a pay-in. Holding E near it (a child Interactable that accepts near contact) pays whole
## steps through the child EnergyCost component (start 1 step per 0.4 s); `paid` persists on the node and `level` counts the config thresholds
## reached (3 / 6 / 9 give 1 / 2 / 3). `is_active` is `level >= 1`; LogicThreshold nodes turn the level into switch signals. At 0 steps the pay-in is
## refused once per hold (EnergyCost). The core never gives steps back; reset() empties it.

## Glow materials of a ring mark that is reached / not yet reached (energy core).
const RING_ON: StandardMaterial3D = preload("res://resources/mechanisms/glow_energy.tres")
const RING_OFF: StandardMaterial3D = preload("res://resources/kit/trigger/core_ring_off.tres")
## Height in m of the mark arc above the lintel.
const MARK_ARC_HEIGHT: float = 0.7

signal active_changed(active: bool)
## Fired when `level` changes. A plain trigger has level 1 while it is active and 0 otherwise; an energy core counts its reached thresholds.
signal level_changed(level: int)

## Per-instance option: a plain Trigger that is on from the start and after every reset (an always-on driver, e.g. a pendulum).
@export var start_active: bool = false
## The profile config of a visible trigger (null for logic nodes and plain drivers); the instance works on its own copy (D-12).
@export var config: TriggerConfig

var is_active: bool = false
## ENERGY_CORE: steps paid in so far (persists until reset()).
var paid: int = 0
## Switch level: 0 .. 3 for an energy core (reached thresholds), 0 or 1 (active) for every other trigger.
var level: int = 0

var _volume: Area3D
var _cost: EnergyCost


func _ready() -> void:
	if config != null:
		config = own_config(config) as TriggerConfig
		if config.profile == TriggerConfig.Profile.CHARGE_GATE:
			_setup_gate()
		elif config.profile == TriggerConfig.Profile.ENERGY_CORE:
			_setup_core()
	if start_active:
		set_active(true)


func _physics_process(_delta: float) -> void:
	if _volume == null or config == null or config.profile != TriggerConfig.Profile.CHARGE_GATE:
		return
	set_active(_gate_open())


## Sets the signal. Emits active_changed only when the value changed.
func set_active(value: bool) -> void:
	if value == is_active:
		return
	is_active = value
	if not _is_core():
		_publish_level(1 if value else 0)
	active_changed.emit(value)


## Virtual: back to the load state (start_active, off by default). Called by the reset sweep.
func reset() -> void:
	super.reset()
	paid = 0
	if _cost != null:
		_cost.end_episode()
	if _is_core():
		_publish_level(0)
		_light_rings()
	set_active(start_active)


## CHARGE_GATE: true while the player is inside the volume with at least `threshold` steps. Reads the energy, never writes it.
func _gate_open() -> bool:
	for body: Node3D in _volume.get_overlapping_bodies():
		var player: PlayerController = body as PlayerController
		if player != null and player.arm_energy != null and player.arm_energy.value >= config.threshold:
			return true
	return false


func _setup_gate() -> void:
	_volume = get_node_or_null(^"Volume") as Area3D
	if _volume != null:
		_volume.collision_layer = 0
		_volume.collision_mask = PhysicsLayers.PLAYER
		var box: BoxShape3D = BoxShape3D.new()
		box.size = config.size
		var shape_node: CollisionShape3D = _volume.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
		if shape_node != null:
			shape_node.shape = box
			shape_node.position = Vector3(0.0, config.size.y * 0.5, 0.0)
	_layout_marks()


## Exactly `threshold` marks on the Marks node, spread like clock ticks over an arc above the lintel. The authored marks are kept (and
## copied when more are needed), so the scene always carries its turquoise element even before it runs.
func _layout_marks() -> void:
	var marks: Node3D = get_node_or_null(^"Marks") as Node3D
	if marks == null:
		return
	var elements: Array[Node3D] = []
	for child: Node in marks.get_children():
		if child is GlowElement:
			elements.append(child as Node3D)
	if elements.is_empty():
		return
	var wanted: int = maxi(config.threshold, 1)
	while elements.size() > wanted:
		var extra: Node3D = elements.pop_back()
		marks.remove_child(extra)
		extra.queue_free()
	while elements.size() < wanted:
		var copy: Node3D = elements[0].duplicate() as Node3D
		marks.add_child(copy)
		elements.append(copy)
	var half_width: float = maxf(config.size.x * 0.5 - 0.4, 0.2)
	for index: int in elements.size():
		var angle: float = PI * (1.0 - (float(index) + 0.5) / float(elements.size()))
		elements[index].position = Vector3(cos(angle) * half_width, sin(angle) * MARK_ARC_HEIGHT, 0.0)
		elements[index].visible = true


func _is_core() -> bool:
	return config != null and config.profile == TriggerConfig.Profile.ENERGY_CORE


func _publish_level(new_level: int) -> void:
	if new_level == level:
		return
	level = new_level
	level_changed.emit(level)


## ENERGY_CORE: wires the near contact of the child Interactable to the pay-in. The Interactable and the EnergyCost are authored in the scene.
func _setup_core() -> void:
	_cost = get_node_or_null(^"EnergyCost") as EnergyCost
	var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable
	if _cost == null or interactable == null:
		push_warning("Energy core %s needs an Interactable and an EnergyCost child" % get_path())
		return
	interactable.near_held.connect(_on_near_held)
	_cost.paid.connect(_on_paid)
	interactable.near_ended.connect(_cost.end_episode)
	_light_rings()


## One payment tick of a hold of E. Stops taking steps at the last threshold, so no step is wasted.
func _on_near_held(delta: float) -> void:
	if _cost == null or config.thresholds.is_empty() or paid >= _top_threshold():
		return
	var player: PlayerController = get_tree().get_first_node_in_group(&"player") as PlayerController
	if player != null:
		_cost.tick(player, delta, &"core")


## One payment went through: counts the step and recomputes the level.
func _on_paid(steps: int) -> void:
	paid += steps
	var reached: int = 0
	for threshold: int in config.thresholds:
		if paid >= threshold:
			reached += 1
	_publish_level(reached)
	set_active(reached >= 1)
	_light_rings()


func _top_threshold() -> int:
	var top: int = 0
	for threshold: int in config.thresholds:
		top = maxi(top, threshold)
	return top


## The ring marks (GlowElements of the Rings node) light up one per reached level; the unreached ones show a dim own material (not the shared Interactable stage glow, which test_glow_stages reserves for Interactable lenses).
func _light_rings() -> void:
	var rings: Node = get_node_or_null(^"Rings")
	if rings == null:
		return
	var index: int = 0
	for child: Node in rings.get_children():
		var mark: GlowElement = child as GlowElement
		if mark == null:
			continue
		mark.material_override = RING_ON if index < level else RING_OFF
		index += 1
