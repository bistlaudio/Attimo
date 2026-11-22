class_name Pendulum
extends Mechanism
## Pendel (MECH-03, D-21): a swinging hazard that knocks the player away and deals no damage. Stub of plan 04-04 task 2, the
## body follows in task 4.

@export_range(10.0, 80.0, 1.0) var swing_deg: float = 60.0
@export_range(0.5, 8.0, 0.1) var period: float = 2.4
@export_range(1.0, 30.0, 0.5) var knock_strength: float = 10.0
@export_range(0.0, 15.0, 0.5) var knock_up: float = 4.0
@export_range(0.0, 3.0, 0.05) var rehit_cooldown: float = 0.5
