class_name Amplification
extends Node
## Amplification component (Phase 05.1, KIT-01, D-14, D-24): lets an energy object get stronger with the arm steps. It only READS the
## player's steps and never writes them (no spend, no gain): the object is amplified, not paid for. A child of a block; the block asks
## `factor(player)` when it acts. Exactly two users: the bounce pad with core (bounce speed times the factor) and the gravity zone (the
## gravity scale divided by the factor).

## How much a full arm (12 steps) adds to the factor: the factor is 1 + gain at 12 steps and 1.0 at 0 steps. Raise it for a stronger
## object; 0 turns the amplification off.
@export_range(0.0, 3.0, 0.05) var gain: float = 0.5


## 1.0 at 0 steps up to 1 + gain at ArmEnergy.MAX_STEPS. 1.0 without a player or arm. Always at least 1.0.
func factor(player: PlayerController) -> float:
	if player == null or not is_instance_valid(player) or player.arm_energy == null or not is_finite(gain):
		return 1.0
	return 1.0 + maxf(gain, 0.0) * float(player.arm_energy.value) / float(ArmEnergy.MAX_STEPS)
