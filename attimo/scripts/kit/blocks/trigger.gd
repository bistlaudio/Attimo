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

## Height in m of the mark arc above the lintel.
const MARK_ARC_HEIGHT: float = 0.7

signal active_changed(active: bool)

## Per-instance option: a plain Trigger that is on from the start and after every reset (an always-on driver, e.g. a pendulum).
@export var start_active: bool = false
## The profile config of a visible trigger (null for logic nodes and plain drivers); the instance works on its own copy (D-12).
@export var config: TriggerConfig

var is_active: bool = false

var _volume: Area3D


func _ready() -> void:
	if config != null:
		config = own_config(config) as TriggerConfig
		if config.profile == TriggerConfig.Profile.CHARGE_GATE:
			_setup_gate()
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
	active_changed.emit(value)


## Virtual: back to the load state (start_active, off by default). Called by the reset sweep.
func reset() -> void:
	super.reset()
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
