class_name PulseHit
extends RefCounted
## The facts of one Fernausloeser shot (D-25). Phase 6 can attach damage here without rewriting the module.

## Float dust allowed when a charge is compared with the big threshold.
const SIZE_EPSILON: float = 0.001

enum Size { SMALL, BIG }
enum Kind { SHOT, NEAR }

var size: Size = Size.SMALL
## Energy spent on this shot (D-17). Phase 6 turns it into damage. Hand-built hits leave it at 0; their size is set directly.
var energy: float = 0.0
var kind: Kind = Kind.SHOT
var module_id: StringName = &""
## Where the pulse left the player (chest point).
var origin: Vector3 = Vector3.ZERO
## The hit point, or the ray end when nothing was hit.
var point: Vector3 = Vector3.ZERO
## Unit direction from origin to point.
var direction: Vector3 = Vector3.FORWARD
var collider: Object = null
## Metres from the player origin to the point.
var distance: float = 0.0


## The size a shot of `energy` has: BIG exactly from `big_threshold` up (the full charge), else SMALL (D-24).
static func size_for_energy(shot_energy: float, big_threshold: float) -> Size:
	return Size.BIG if shot_energy >= big_threshold - SIZE_EPSILON else Size.SMALL
