class_name PhysicsLayers
extends RefCounted
## Collision layer bitmasks (D-14). Layer N has the bitmask 1 << (N - 1).
## .tscn files store bitmasks, code uses these constants and never magic numbers.
## The full table (who sits on a layer, who masks it) lives in docs/CONVENTIONS.md.
## Layer names in project.godot [layer_names] mirror these constants; test_conventions keeps them in sync.

const WORLD: int = 1 << 0
const PLAYER: int = 1 << 1
const INTERACTABLE: int = 1 << 2
const ENEMY: int = 1 << 3
## Layer 5 is named "Projectile/Beam" in project.godot.
const PROJECTILE: int = 1 << 4
const HAZARD: int = 1 << 5
