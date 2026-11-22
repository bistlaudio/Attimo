class_name PulseHit
extends RefCounted
## The facts of one Fernausloeser shot (D-25). Phase 6 can attach damage here without rewriting the module.

enum Size { SMALL, BIG }
enum Kind { SHOT, NEAR }

var size: Size = Size.SMALL
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
