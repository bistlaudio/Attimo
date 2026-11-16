class_name ProceduralPose
extends Node
## Code-driven body motion the animation kit has no clip for (MOVE-09): the forward lean of a ground dash (D-01) and,
## later in this file, the long-jump stretch and the Jump 3 pirouette. It is presentation only: it reads the FSM and the
## player, writes nothing back and never delays any input.
##
## The pose is written on the Mannequin child of VisualRoot, not on VisualRoot itself (DEV-01, confirmed by the
## developer on 2026-11-14). PlayerController.face(), Dash, LongJump and CameraRig.recenter() read VisualRoot's yaw as
## the facing, so a lean or a spin there would corrupt them. The Mannequin transform is a rotation about the pivot
## p = (0, pose_pivot_height, 0), so the body tilts about its hips and not about its feet. It is written in
## _physics_process only (the Player is interpolated, so a write in _process would jitter or be ignored).
## Easing is hand-written with move_toward.

@export var player: PlayerController
@export var mannequin: Node3D
## True: the spin turns about the tilted body axis (a corkscrew). False: the tilted body spins about the vertical axis
## (a tilted top). Judged in the gym check (research A4).
@export var spin_about_body_axis: bool = true
## True: the pirouette turns clockwise seen from above (Claude's discretion, D-07).
@export var pirouette_clockwise: bool = true

## Current forward lean in radians, 0 upright. Read-only for others.
var lean_angle: float = 0.0
## Axis of the lean in VisualRoot space (unit length).
var lean_axis: Vector3 = Vector3.RIGHT
## Current spin angle in radians, 0 to TAU. Read-only for others.
var spin_angle: float = 0.0
## True while a pirouette runs. Read-only for others.
var spinning: bool = false

var _machine: StateMachine
var _written_identity: bool = true


func _ready() -> void:
	# The Player's own state_machine reference is set after its children are ready, so find the node.
	_machine = player.get_node(^"StateMachine") as StateMachine


## Eases the lean toward the target of the current state and writes the Mannequin transform.
func _physics_process(delta: float) -> void:
	var config: MovementConfig = player.config
	var target: float = deg_to_rad(_lean_target_deg(config))
	if player.aiming:
		target *= config.aim_lean_scale
	var full: float = deg_to_rad(config.stretch_lean_deg)
	var time: float = config.lean_in_time if target > lean_angle else config.lean_out_time
	lean_angle = move_toward(lean_angle, target, full / time * delta)
	_update_axis()
	if not is_finite(lean_angle) or not is_finite(spin_angle):
		lean_angle = 0.0
		spin_angle = 0.0
		spinning = false
	_write(config)


## Lean target in degrees for the current state: a ground dash leans, everything else is upright.
func _lean_target_deg(config: MovementConfig) -> float:
	if _machine.current.name == &"Dash" and not _dash_in_air():
		return config.dash_lean_deg
	return 0.0


## True while the running Dash started in the air.
func _dash_in_air() -> bool:
	return bool(_machine.current.get(&"in_air"))


## Keeps lean_axis on up x travel direction, expressed in VisualRoot space. With no direction the last axis is kept
## while the lean eases out, and the facing is used once upright.
func _update_axis() -> void:
	var direction: Vector3 = Vector3.ZERO
	if _machine.current.name == &"Dash":
		direction = _machine.current.get(&"direction") as Vector3
	else:
		direction = Vector3(player.move_velocity.x, 0.0, player.move_velocity.z)
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		if lean_angle != 0.0:
			return
		direction = player.visual_root.global_basis.z
		direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var world_axis: Vector3 = Vector3.UP.cross(direction.normalized())
	var local_axis: Vector3 = player.visual_root.global_basis.orthonormalized().inverse() * world_axis
	if local_axis.length_squared() > 0.0001:
		lean_axis = local_axis.normalized()


## Writes the Mannequin transform: exactly identity when upright, otherwise a rotation about the pivot point.
func _write(config: MovementConfig) -> void:
	if lean_angle == 0.0 and not spinning:
		if not _written_identity:
			mannequin.transform = Transform3D.IDENTITY
			_written_identity = true
		return
	var pose: Basis = Basis(lean_axis, lean_angle)
	var pivot: Vector3 = Vector3(0.0, config.pose_pivot_height, 0.0)
	mannequin.transform = Transform3D(pose, pivot - pose * pivot)
	_written_identity = false
