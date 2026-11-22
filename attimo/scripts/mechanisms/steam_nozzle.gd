class_name SteamNozzle
extends Mechanism
## Dampfduese (MECH-03, D-16, D-20): throws or pushes the player along a fixed direction. Stub of plan 04-04 task 2, the
## behaviour follows in task 3.

enum Mode { JUMP, UPDRAFT, CANNON, WALL }

@export var mode: Mode = Mode.JUMP
@export_range(1.0, 30.0, 0.5) var launch_speed: float = 14.0
@export_range(1.0, 20.0, 0.5) var updraft_speed: float = 6.0
@export_range(1.0, 120.0, 1.0) var updraft_accel: float = 60.0
@export_range(1.0, 20.0, 0.5) var wall_speed: float = 8.0
@export_range(1.0, 120.0, 1.0) var wall_accel: float = 60.0
@export_range(0.0, 2.0, 0.05) var launch_cooldown: float = 0.25
