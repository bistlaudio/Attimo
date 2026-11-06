class_name HitPuffs
extends Node
## Debug-only placeholder feedback: a small puff of particles at the player's feet when a timing is hit, so the
## tester can see it. It listens to EventBus facts only and never touches gameplay code. Exception to the
## no-feedback rule, recorded in docs/CONVENTIONS.md; real juice stays Phase 3+.
##   chain_stage_changed 2 and 3: a puff for Jump 2 and the bigger one for Jump 3 (the salto). Stage 1 and the
##   reset to 0 give nothing.
##   long_jumped 1, 2, 3: one puff per dash-hop stack stage, bigger and a different colour per stage.
## A missed window emits no hit fact, so it gives no puff. Strip with the other debug scripts (REL-03).

const PUFF_SCENE: String = "res://scenes/debug/hit_puff.tscn"
## Seconds after which a puff is freed (lifetime of the scene plus a margin).
const PUFF_LIFETIME: float = 1.0

## Jump chain puffs by stage 2 and 3: [color, scale].
const CHAIN_STYLE: Dictionary = {
	2: [Color(0.4, 1.0, 0.4), 1.0],
	3: [Color(1.0, 0.3, 1.0), 1.8],
}
## Dash hop puffs by stage 1, 2 and 3: [color, scale].
const LONG_JUMP_STYLE: Dictionary = {
	1: [Color(0.3, 0.9, 1.0), 1.0],
	2: [Color(1.0, 0.9, 0.2), 1.5],
	3: [Color(1.0, 0.45, 0.1), 2.1],
}

## Number of puffs spawned so far (tests read it).
var puffs_spawned: int = 0
## Kind of the last puff: "chain" or "long".
var last_kind: String = ""
## Stage of the last puff.
var last_stage: int = 0

var _scene: PackedScene


func _ready() -> void:
	_scene = load(PUFF_SCENE) as PackedScene
	EventBus.chain_stage_changed.connect(_on_chain_stage_changed)
	EventBus.long_jumped.connect(_on_long_jumped)


func _on_chain_stage_changed(stage: int) -> void:
	if not CHAIN_STYLE.has(stage):
		return
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	_spawn("chain", stage, player.global_position, CHAIN_STYLE[stage])


func _on_long_jumped(position: Vector3, stage: int) -> void:
	if not LONG_JUMP_STYLE.has(stage):
		return
	_spawn("long", stage, position, LONG_JUMP_STYLE[stage])


func _spawn(kind: String, stage: int, position: Vector3, style: Array) -> void:
	puffs_spawned += 1
	last_kind = kind
	last_stage = stage
	if _scene == null:
		return
	var puff: CPUParticles3D = _scene.instantiate() as CPUParticles3D
	puff.color = style[0] as Color
	puff.scale = Vector3.ONE * float(style[1])
	add_child(puff)
	puff.global_position = position
	puff.emitting = true
	get_tree().create_timer(PUFF_LIFETIME).timeout.connect(puff.queue_free)
