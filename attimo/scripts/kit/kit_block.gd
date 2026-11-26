class_name KitBlock
extends Node3D
## Base of every mechanism-kit block (Phase 05.1, KIT-01, D-10, D-16). A block is one script with one config Resource of its own
## class (a .tres preset per object) and a look as an inherited scene under scenes/kit/{steampunk,energy,nature}. `layer` and
## `energy_relation` are plain data the coupling test (test_kit_coupling) reads: turquoise glow means energy, nature is free.
## The block joins the groups `mechanism` (FallReset.reset sweep) and `kit_block`, and gets the shared steampunk material pass for the
## STEAMPUNK and ENERGY layers and the nature look pass (moss, bark, resin, stone) for NATURE. Both hooks run on NOTIFICATION_READY, which reaches this base class even when a subclass overrides
## _ready without calling super. A block has no signal source of its own: switching is the Receiver component's job (D-13).
## Kit blocks touch the player only through PlayerController request APIs (D-17).

enum Layer { STEAMPUNK, ENERGY, NATURE }
enum EnergyRelation { FREE, COSTS, AMPLIFIED, GIVES }

## Which world layer the object belongs to (its look scene lives in the folder of the same name).
@export var layer: Layer = Layer.STEAMPUNK
## How the object relates to the arm energy: free, costs energy, amplified by it, or gives a step per use (D-43). COSTS, AMPLIFIED and
## GIVES need a GlowElement (GIVES a small turquoise accent). New values are appended, serialized scenes keep their ints.
@export var energy_relation: EnergyRelation = EnergyRelation.FREE


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		add_to_group(&"mechanism")
		add_to_group(&"kit_block")
		if layer == Layer.STEAMPUNK or layer == Layer.ENERGY:
			MechanismLook.apply(self)
		elif layer == Layer.NATURE:
			NatureLook.apply(self)
		set_physics_process_internal(true)
	elif what == NOTIFICATION_INTERNAL_PHYSICS_PROCESS and _income_left > 0.0:
		# Real time, so the slow world of a Loader hold does not stretch the cooldown (D-12, T-05.1-42).
		_income_left = maxf(_income_left - TimeFx.unscaled(get_physics_process_delta_time()), 0.0)


## Real seconds until this block may give a step again (0 = ready). Counted on the node, never on the shared config.
var _income_left: float = 0.0


## Steampunk income (D-43, ENRG-08): gives `steps` whole steps to the player's arm once per `cooldown` (real seconds, per block).
## Returns false inside the cooldown, with no player, or for zero steps; true when the use counted (the arm clamps at 12 itself, a full arm
## still counts as a use). Writes the value through the ArmEnergy API only and announces EventBus.income_granted for the spark.
func grant_step(player: PlayerController, steps: int, cooldown: float, source_id: StringName) -> bool:
	if player == null or not is_instance_valid(player) or steps <= 0 or _income_left > 0.0:
		return false
	_income_left = maxf(cooldown, 0.0)
	player.arm_energy.gain(steps, &"steampunk")
	EventBus.income_granted.emit(global_position, steps, source_id)
	return true


## Virtual: back to the load state (FallReset sweep). Subclasses reset their runtime state here.
func reset() -> void:
	_income_left = 0.0


## The block's own copy of a shared config (D-12): a loaded .tres is never written at runtime, so every instance works on a
## duplicate. Returns null for a null config.
func own_config(shared: Resource) -> Resource:
	if shared == null:
		return null
	return shared.duplicate()
