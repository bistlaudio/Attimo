class_name KitBlock
extends Node3D
## Base of every mechanism-kit block (Phase 05.1, KIT-01, D-10, D-16). A block is one script with one config Resource of its own
## class (a .tres preset per object) and a look as an inherited scene under scenes/kit/{steampunk,energy,nature}. `layer` and
## `energy_relation` are plain data the coupling test (test_kit_coupling) reads: turquoise glow means energy, nature is free.
## The block joins the groups `mechanism` (FallReset.reset sweep) and `kit_block`, and gets the shared steampunk material pass for the
## STEAMPUNK and ENERGY layers. Both hooks run on NOTIFICATION_READY, which reaches this base class even when a subclass overrides
## _ready without calling super. A block has no signal source of its own: switching is the Receiver component's job (D-13).
## Kit blocks touch the player only through PlayerController request APIs (D-17).

enum Layer { STEAMPUNK, ENERGY, NATURE }
enum EnergyRelation { FREE, COSTS, AMPLIFIED }

## Which world layer the object belongs to (its look scene lives in the folder of the same name).
@export var layer: Layer = Layer.STEAMPUNK
## How the object relates to the arm energy: free, costs energy, or amplified by it (COSTS and AMPLIFIED need a GlowElement).
@export var energy_relation: EnergyRelation = EnergyRelation.FREE


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		add_to_group(&"mechanism")
		add_to_group(&"kit_block")
		if layer == Layer.STEAMPUNK or layer == Layer.ENERGY:
			MechanismLook.apply(self)


## Virtual: back to the load state (FallReset sweep). Subclasses reset their runtime state here.
func reset() -> void:
	pass


## The block's own copy of a shared config (D-12): a loaded .tres is never written at runtime, so every instance works on a
## duplicate. Returns null for a null config.
func own_config(shared: Resource) -> Resource:
	if shared == null:
		return null
	return shared.duplicate()
