# Phase 5: Energy Arm & Loader - Pattern Map

**Mapped:** 2026-11-24
**Files analyzed:** 24 new/modified groups
**Analogs found:** 22 / 24
**All analog paths verified git-tracked** (`git ls-files` on player_controller.gd, hand_presentation.gd, puzzle_rooms_builder.gd, fixtures.gd; all other paths live in tracked `attimo/scripts|autoload|tests|tools|scenes`; no `.gsd/capabilities` mirrors involved). Paths below are relative to `/Users/janwinter/Desktop/UNI/Games/Attimo/attimo/`.

Project rules that apply to every file: typed GDScript only (`untyped_declaration=2` makes any untyped declaration a parse error, also in `tools/` and `tests/`), one `.gd.uid` sidecar per script, signals carry values, runtime state not in shared `.tres`, gym content only via builders. Generated artefacts (`movement_gym.tscn`, `mannequin_tree.tres`, `docs/MOVEMENT-METRICS.md`) are regenerated, never hand-edited, and need a Godot 4.7.2 binary that is not installed on this machine.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match |
|---|---|---|---|---|
| `autoload/time_fx.gd` (new autoload) | service | event-driven | `autoload/event_bus.gd` (registration) + RESEARCH TimeFx sketch | partial |
| `autoload/event_bus.gd` (modify) | utility (fact bus) | pub-sub | itself (signal + doc-comment style) | exact |
| `scripts/player/arm_energy.gd` (new, `ArmEnergy`) | service (component) | CRUD + transform | `scripts/hand/hand_presentation.gd` (component under Player, `@export player`) | role-match |
| `scripts/player/loader_math.gd` (new, `LoaderMath`) | utility | transform | `scripts/hand/pulse_hit.gd` (RefCounted, class_name) + `PlayerController._integrate` | role-match |
| `scripts/player/states/loader.gd` (new) | state | request-response (hold/release) | `scripts/player/states/capture.gd` | exact (with D-03 correction) |
| `scenes/player/player.tscn` (modify: Loader node, ArmEnergy node) | config | n/a | `Capture` node block, `player.tscn:68-70` | exact |
| `scripts/player/player_controller.gd` (modify) | controller | request-response | itself: `dash_locked_reason`, `can_dash`, `_block_dash`, `refill_air_dash`, `lock_air_control` | exact |
| `scripts/player/movement_config.gd` (modify, Energy/Moto/Loader groups) | config | n/a | itself (`@export_group` + doc comment + `@export_range`) | exact |
| `scripts/player/states/{dash,long_jump,wall_run,jump}.gd` (energy checks) | state | request-response | `states/dash.gd` header + `start_dash` | exact |
| `scripts/player/arm_energy_presentation.gd` (new) | component (presentation) | event-driven | `scripts/hand/hand_presentation.gd` | exact |
| `scripts/hand/modules/extractor/{extractor.gd,.tscn,_def.tres}` + registry line | module | streaming (hold drain) | `scripts/hand/modules/remote_trigger/*` | exact |
| `scripts/hand/modules/remote_trigger/remote_trigger.gd` (rewrite as shot) | module | request-response | itself (snapped-hit logic kept) | exact |
| `scripts/hand/shot_projectile.gd` + `scenes/hand/shot_projectile.tscn` (new) | model/entity | streaming (stepped per tick) | `remote_trigger.gd` (ray + PulseHit build) | role-match |
| `scripts/hand/{hand_controller,targeting,pulse_hit,hand_module}.gd` (modify) | controller | event-driven | themselves | exact |
| `scripts/mechanisms/energy_source.gd` + `scenes/mechanisms/{energy_capsule,broken_machine}.tscn` (new) | mechanism | CRUD (drain) | `scripts/mechanisms/boost_ring.gd` (rearm timer) + `slingshot_core.gd` (Phase enum) | role-match |
| `scripts/mechanisms/interactable.gd` (modify, GlowStage.AIM reuse) | component | event-driven | itself | exact |
| `scripts/camera/camera_rig.gd` (modify: real-time delta, loader source, aim removal) | component | event-driven | itself (additive `set_offset`/`set_fov_offset`) | exact |
| `scripts/ui/energy_hud.gd` + `scenes/ui/energy_hud.tscn` (new) | component (UI) | polling | `scripts/ui/crosshair.gd` + `scenes/ui/crosshair.tscn` | exact |
| `scripts/ui/crosshair.gd` (modify: two rings) | component (UI) | polling | itself (`_arc`, `_draw_ring`, charge arc) | exact |
| `scripts/ui/loader_vignette.gdshader` + loader preview (new) | utility / presentation | transform | `scripts/ui/goggle_lens.gdshader` (procedural radial, no screen texture) | role-match |
| `scripts/debug/tuning_panel.gd` (modify) | component | request-response | itself (auto rows from `MovementConfig`) | exact |
| `tools/energy_area_builder.gd` (new) | tool | batch | `tools/puzzle_rooms_builder.gd` (`build_into(zone, builder)`) | exact |
| `tests/smoke/test_{loader,loader_math,energy,energy_income,energy_costs,energy_hud,extractor,aim_removed,energy_gym}.gd` (new) | test | request-response | `tests/smoke/test_dash_lockout.gd` + `tests/fixtures.gd` | exact |
| Input Map in `project.godot` (aim -> loader, charge, module_1/2), `docs/CONVENTIONS.md` | config | n/a | existing `[input]` block; `test_input_map`/`test_conventions` enforce names | exact |

## Pattern Assignments

### `scripts/player/states/loader.gd` (state, hold/release)

**Analog:** `scripts/player/states/capture.gd` (93 lines). Same lifecycle: owns the whole body, gravity off, `exit()` restores gravity, release goes to `Fall`.

**Header doc + state skeleton** (capture.gd:1-9, 30-44): file starts with `extends State`, a `##` paragraph describing contract (who requests it, what it owns, how it ends, what `exit()` restores), then named consts with `##` comments.
```gdscript
func enter(_previous: StringName) -> void:
	...
	actor.gravity_scale = 0.0
	actor.move_velocity = Vector3.ZERO
	actor.vertical_speed = 0.0
	EventBus.capture_started.emit(actor.global_position)

func exit() -> void:
	actor.gravity_scale = 1.0
```
Loader additions: `exit()` also `TimeFx.release(&"loader")` (every exit path incl. `teleport()`), `actor.consume_jump()` in enter and exit (RESEARCH Pitfall 4). State returns `&""` to stay, `&"Fall"` to leave (capture.gd:46-72).

**Release pattern** (capture.gd:84-93), copy with ONE deletion:
```gdscript
actor.move_velocity = Vector3(exit_velocity.x, 0.0, exit_velocity.z)
actor.vertical_speed = clampf(exit_velocity.y, -config.terminal_speed, config.terminal_speed)
actor.air_speed_cap = maxf(config.run_speed, actor.horizontal_speed())
actor.lock_air_control(EXIT_CONTROL_LOCK)
actor.refill_air_dash()        # <-- DO NOT COPY: violates D-03
EventBus.capture_released.emit(actor.global_position, exit_velocity)
return &"Fall"
```
Use `config.loader_release_control_lock` instead of a const. Clamp speed with `config.loader_max_speed`; guard non-finite (T-04.1-06 pattern: `MAX_EXIT_SPEED`, `limit_length`).

**Do not copy** `_set_velocity_toward` (divides by `delta`, unsafe at 0.25x/hitstop). Hold clock uses `TimeFx.unscaled(delta)` and tick accounting, not `Time.get_ticks_msec()`.

**State registration:** add node in `scenes/player/player.tscn` next to
```
[node name="Capture" type="Node" parent="StateMachine"]
script = ExtResource("20_capture")
```
(player.tscn:68-70). Also add `Loader` to `STATE_TO_ANIM` in `mannequin_animator.gd` (l.62-72) and `docs/ANIMATION-MAP.md` (`test_animation_map` enforces).

**Press check** in `GroundState`/`AirState.physics_update`: model on `dash_press_starts_dash()` (player_controller.gd:~280):
```gdscript
func dash_press_starts_dash() -> bool:
	if not Input.is_action_just_pressed(&"dash"):
		return false
	var reason: StringName = dash_locked_reason()
	if reason != &"":
		_block_dash(reason)
		return false
	return can_dash()
```
Loader gets an analogous `loader_press_starts_loader()` using `loader_available` (set false on air entry, refilled in `_land()` and inside `refill_air_dash()`).

---

### `scripts/player/player_controller.gd` (modify, controller)

**Analog:** itself. Anchors (verified lines): `var gravity_scale` l.16, `var air_dash_available` l.28, `horizontal_speed()` l.118, `teleport` l.206, `consume_jump` l.244, `dash_locked_reason` l.257, `can_dash` l.265, `_block_dash` l.286, `start_dash` l.297, `refill_air_dash` l.347, `lock_air_control` l.355, `capture_along` l.436, `advance_long_jump_stage` l.502, `_tick_timers` l.531, `_land` l.662.

**Energy refusal reuses the existing lockout channel** (replace aim reason with energy):
```gdscript
func dash_locked_reason() -> StringName:
	if aiming:                     # remove with aim mode
		return DASH_LOCK_AIM
	return &""
```
becomes `&"energy"` when not grounded, `air_dash_available`, cooldown elapsed and `not arm_energy.can_afford(config.air_dash_cost)`. `_block_dash` (emits `EventBus.dash_blocked` once per physics frame, starts twitch) is reused unchanged. Spend in `start_dash` after `air_dash_available = false`.

**Request API with finite guard** (`lock_air_control`, l.355-358): `if not is_finite(seconds) or seconds < 0.0: return`. Copy this guard style for any new request API (energy, loader direction).

Remove aim: `aiming`, `DASH_LOCK_AIM`, aim branch of `ground_target_speed`, `_tick_aim`/`_apply_aim_facing` (see RESEARCH removal inventory).

---

### `scripts/player/movement_config.gd` (modify, config)

**Analog:** itself. New groups `Energy`, `Moto Perpetuo`, `Loader`; delete group `Aim` (l.93-97) and `aim_lean_scale`.
```gdscript
@export_group("Floor and platforms")
## Lower bound of the speed-scaled floor snap length in m (D-13 band, A35); raise it for a stickier floor.
@export_range(0.3, 0.5, 0.01) var snap_min: float = 0.3
```
Convention: `##` doc comment states unit + "raise it for ..." effect, strictly positive minimum for any divisor (T-02-02), range note for hard limits (long_jump_speed_3: 22 m/s tunnelling envelope; start `loader_max_speed` at 22, RESEARCH Pitfall 8). Update the class header count ("Twelve groups, 67 live sliders"). Starting values: RESEARCH "Loader and Energy starting values" table. `test_movement_metrics` fails until `docs/MOVEMENT-METRICS.md` is regenerated (needs Godot) and `tools/movement_metrics.gd` `ROW_LABELS` gets Loader rows.

---

### `scripts/player/arm_energy.gd` (component, single owner)

**Analog:** `scripts/hand/hand_presentation.gd` for composition (a `Node` under Player with `@export var player: PlayerController`, `_ready` null-safe lookups), and `capture.gd` for the "all-or-nothing, clamp, guard" style.

```gdscript
class_name HandPresentation
extends Node
@export var player: PlayerController
func _ready() -> void:
	if player != null:
		_hand = player.get_node_or_null(^"HandController") as HandController
```
Interface: RESEARCH Pattern 1 (`can_afford`, `try_spend`, `drain`, `gain`, `reset_to_checkpoint`, `core_fill`, `is_moto` with hysteresis ~2.5). Value clamped 0..100. Emit EventBus facts: discrete changes always, passive charge only when integer part changes (EventLog connects to every EventBus signal). Passive charge in `_physics_process` from `player.horizontal_speed()`; skip in `Loader` and `Capture` states. Add as child node in `player.tscn` and call from `PlayerController._tick_timers`.

---

### `scripts/player/loader_math.gd` (utility, pure)

**Analog:** `scripts/hand/pulse_hit.gd` for header style (`class_name X`, `extends RefCounted`, `##` description) with only static funcs; physics integration must mirror `PlayerController._integrate` (gravity chosen once per tick, `rise_gravity` while `vertical_speed >= 0`, `fall_gravity()` below, half-step gravity, terminal clamp). Reject non-finite input. Shared by release and preview; slingshot may adopt later (GAME-DESIGN 6.8).

---

### `autoload/time_fx.gd` (autoload) and `autoload/event_bus.gd` (modify)

**Registration analog** (`project.godot:18-20`):
```
[autoload]

EventBus="*res://autoload/event_bus.gd"
```
Add `TimeFx="*res://autoload/time_fx.gd"`, no `class_name` (code body: RESEARCH "TimeFx" example; sole writer of `Engine.time_scale`, `_exit_tree` restores 1.0).

**EventBus signal style** (event_bus.gd:5-40): header comment "Gameplay FACTS only. No state, no logic."; each signal has a `##` line naming emitter, value meaning and listeners:
```gdscript
## Emitted by PlayerController.refill_air_dash (boost ring, plan 04.1-03) when the air dash was given back. Listeners: juice, audio, the HUD.
signal dash_refilled(position: Vector3)
```
Add: `energy_changed`, `energy_spent`, `energy_gained`, `energy_refused`, `moto_changed`, `loader_started`, `loader_released`, `shot_hit`. Remove `aim_changed` (l.13-14); update `dash_blocked` doc (reason `&"energy"`). Every new signal must appear in backticks in `docs/CONVENTIONS.md` (`test_conventions`). Remove all `aim_changed.connect` users first (interactable.gd:40, camera_rig.gd:206, crosshair.gd `_ready`) or `_ready` errors.

---

### `scripts/player/arm_energy_presentation.gd` (component, bone attachments)

**Analog:** `scripts/hand/hand_presentation.gd` (141 lines). Copy: ENERGY_COLOR const, `SKELETON_PATH = ^"Rig_Medium/Skeleton3D"`, null-skeleton/bone guard that disables processing, `_attach`, emissive-material prisms, `_process` driven by polled state, EventBus-connected flashes.
```gdscript
const ENERGY_COLOR: Color = Color(0.25, 0.9, 0.85, 1.0)
const SKELETON_PATH: NodePath = ^"Rig_Medium/Skeleton3D"
if skeleton == null or skeleton.find_bone(HAND_BONE) < 0:
	set_process(false)
	return
```
```gdscript
func _attach(skeleton: Skeleton3D, bone: StringName) -> BoneAttachment3D:
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = StringName("%sAttachment" % String(bone).replace(".", "_"))
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	return attachment
```
Material: `StandardMaterial3D` with `albedo_color = ENERGY_COLOR.darkened(0.7)`, `emission_enabled`, `emission = ENERGY_COLOR`, animate `emission_energy_multiplier` per frame (hand_presentation.gd:50-53, 98+). Bones for Moto: `foot.l`, `foot.r`, `chest` (Assumption A10): skip missing bones as HandPresentation does. No particles (gym test). Prefer sharing `_attach` rather than copying a third time (extract to a small static helper if touching hand_presentation anyway). `pulse_fired` flash hook (l.~84): the projectile fires later, so also listen to new `shot_hit` (RESEARCH Pitfall 16).

---

### `scripts/hand/modules/extractor/` (module, hold drain) and rewrite of `remote_trigger.gd`

**Analog:** `scripts/hand/modules/remote_trigger/` (folder with `.gd`, `.tscn`, `_def.tres`).

Scene (remote_trigger.tscn):
```
[gd_scene format=3]
[ext_resource type="Script" path="res://scripts/hand/modules/remote_trigger/remote_trigger.gd" id="1_script"]
[node name="RemoteTrigger" type="Node"]
script = ExtResource("1_script")
```
Def (remote_trigger_def.tres): `HandModuleDef` script with `id = &"remote_trigger"`, `display_name`, `scene = ExtResource(...)`, `debug_only = false`. Registry: add one entry to the `ModuleRegistry.modules` array resource (`module_registry.gd`; order = wheel order; skip `debug_only` defs in `cycle()`, RESEARCH Pitfall 6).

Module base (hand_module.gd): `ctx: HandContext`, `activate(context)`, `deactivate()`, `wants_charge()`, `on_use_released(big)`. Extractor needs a hold callback (new virtual such as `on_use_held(delta)`/`on_use_pressed`); add it to `HandModule` with an empty default so existing modules keep compiling.

Guard style (remote_trigger.gd:16-19) to copy:
```gdscript
if ctx == null or ctx.player == null or ctx.controller == null:
	return
var controller: HandController = ctx.controller
var player: PlayerController = ctx.player
```
Hit build (remote_trigger.gd:44-58): `PulseHit.new()`, set `size/kind/module_id/origin/point/direction/collider/distance`, `Interactable.from_collider(collider)`, check `target.can_accept(kind, size) and target.accepts_module(id)`, `target.try_trigger(pulse)`, emit `EventBus.pulse_fired`. The new projectile does this at impact. Keep `_snapped_hit` (l.63-85) logic for aim assist (stronger snap, D-19) but feed the result to projectile bending instead of an instant hit; add `energy: float` to `PulseHit`, derive `size = BIG` iff `energy >= big_energy_threshold` so `Interactable.min_pulse`, `valve.tscn` and 12 tests keep working.

---

### `scripts/hand/shot_projectile.gd` (entity, stepped swept ray)

**Analog (role-match):** `remote_trigger.gd` ray query:
```gdscript
var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(chest, chest + forward * (controller.hand_big_range + RAY_MARGIN), mask)
query.collide_with_areas = false
hit = player.get_world_3d().direct_space_state.intersect_ray(query)
```
with `mask = PhysicsLayers.WORLD | PhysicsLayers.INTERACTABLE` (`scripts/core/physics_layers.gd`). Step `intersect_ray(prev, next)` each `_physics_process`, cap live projectiles (~4), reject non-finite, free at max range. No rigid body.

---

### `scripts/mechanisms/energy_source.gd` + capsule/machine scenes (mechanism)

**Analog:** `scripts/mechanisms/boost_ring.gd` (extends `Mechanism`, `@export_range` tunables, armed/rearm timer, `_physics_process(delta)`, `super._ready()`), and `slingshot_core.gd` for the `enum Phase { ARMED, CAPTURING, COOLDOWN }` plus `@onready` child lookups and a trigger-area setup:
```gdscript
var _armed: bool = true
var _rearm_timer: float = 0.0
func _physics_process(delta: float) -> void:
	_rearm_timer = maxf(_rearm_timer - delta, 0.0)
	if _rearm_timer <= 0.0:
		_armed = true
```
Map to `respawn_time` (0 = never, D-08). Join group `energy_source` in `_ready`; the Extractor cone queries that group on the physics tick only. The mechanism never writes `ArmEnergy.value`; the Extractor calls `ArmEnergy.gain` (D-06 request-API rule). Scenes must live in `scenes/mechanisms/` (gym sanction prefix, `test_movement_gym`); look at `scenes/mechanisms/boost_ring.tscn` or `energy_core.tscn` for node layout and `MechanismLook` usage.

---

### `scripts/ui/energy_hud.gd` + `scenes/ui/energy_hud.tscn` (UI, polling)

**Analog:** `scripts/ui/crosshair.gd` (`class_name Crosshair`, `extends CanvasLayer`, Control `_draw`, `_process(delta)` polling the `hand_controller` group, never drives). Reuse its drawing helpers' conventions: `_u = clampf(size.y / maxf(ui_reference_height, 1.0), 0.75, 3.0)` UI scale, `outline_color` + tint double-draw for `draw_arc`:
```gdscript
_reticle.draw_arc(centre, radius, start, end, RING_POINTS, outline_color, width + OUTLINE_EXTRA, true)
_reticle.draw_arc(centre, radius, start, end, RING_POINTS, tint, width, true)
```
Layers: Crosshair is layer 10, debug 100-102 (event_log 100, metrics_overlay 101, tuning_panel 102); put HUD at layer 9 and the vignette at 5-8 (Pitfall 13). Mouse filter ignore. HUD animation uses `TimeFx.unscaled(delta)`.

---

### `scripts/ui/crosshair.gd` (modify)

**Analog:** itself. Keep `_draw_ring` (notched ring, dot, VALID_BIG outer ring, INVALID cross) and the existing charge arc (l.~266-268):
```gdscript
if charge > 0.0:
	var charge_radius: float = (ring_radius + gear_gap + gear_tooth_length + CHARGE_RING_GAP) * _u
	_arc(centre, charge_radius, -PI * 0.5, -PI * 0.5 + TAU * charge, lock_color, ring_width * _u)
```
This becomes the shot ring (notched, clockwise). Add a Loader double ring turning counter-clockwise via the same `_arc`/`_line` helpers (D-14). Delete `hud_visible` branch, `_draw_module_plate`, goggle lens, `goggle_lens.gdshader` + `.uid`. Reticle always drawn (the old `hud_visible=false` idle branch becomes the base look).

---

### `scripts/ui/loader_vignette.gdshader` (presentation)

**Analog:** `scripts/ui/goggle_lens.gdshader` (procedural radial on a CanvasLayer `ColorRect`, no `hint_screen_texture`). Replace by turquoise vignette; desaturation via `Environment.adjustment_enabled` + `adjustment_saturation` on the gym WorldEnvironment (RESEARCH Don't-Hand-Roll). Read the analog file when implementing (not excerpted here).

---

### `scripts/camera/camera_rig.gd` (modify)

**Analog:** itself: keep the additive `set_offset`/`set_fov_offset` source API and `aim_target_point`/`aim_ray`/`aim_direction_from`; add a `&"loader"` additive source for the pull-back; `_process` damping must use `TimeFx.unscaled(delta)`; raise `pitch_max` (0.75 rad, l.71) up to ~75 degrees while Loader is held and ease back (D-29); remove wheel zoom l.249-250 (D-26), aim group l.103-121, `_on_aim_changed` + connect l.206, `look_sensitivity_multiplier` l.36/235.

---

### `tools/energy_area_builder.gd` (tool, batch)

**Analog:** `tools/puzzle_rooms_builder.gd` (327 lines): worker with `build_into(zone: Node3D, builder: RefCounted)`; all builder-script helpers are called through the parent builder with `builder.call(&"_group"|&"_instance"|&"_label"|&"_yaw", ...)`:
```gdscript
func build_into(zone: Node3D, builder: RefCounted) -> void:
	var puzzle: Node3D = builder.call(&"_group", zone, "Zone_PuzzleRooms") as Node3D
	...
	builder.call(&"_label", puzzle, "Label_Entry", "Rätselräume", Vector3(ENTRY_X, 5.0, DOOR_Z))
```
Room helper (l.~70-75) sets `x_range` meta and a `Label_Name`. Every station needs a `Label3D` sign with an "Erwartet:" line (`test_movement_gym` requires >= 40 labels) and its own `FallReset` zone. New zones `Zone_Loader` and `Zone_Energy`; call from `tools/mechanism_rooms_builder.gd` / gym builder like the puzzle builder is called. Sign rewrite for hip fire: `mechanism_rooms_builder.gd:358` label "Fernauslöser: RMB halten, LMB tippen". Capsule next to every shot station (D-18/D-24). Regenerate with `bash tests/run.sh --tool res://tools/build_movement_gym.gd` (needs Godot).

---

### Tests (`tests/smoke/test_*.gd`)

**Analog:** `tests/smoke/test_dash_lockout.gd` + `tests/fixtures.gd`.
```gdscript
extends RefCounted
const Fixtures := preload("res://tests/fixtures.gd")
const SHIPPED_TPS: int = 60
var _bus: Node
func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_takeoff(tree, check)
```
Pattern: `_begin` (connect EventBus recorders via `_bus.connect(&"dash_blocked", callable)`, `Fixtures.spawn_floor`, `Fixtures.spawn_player`, duplicate `player.config` for private numbers, `await Fixtures.wait_physics(tree, 10)`); `_end` (release/`send_action_event(action, false)` for all used actions, disconnect recorders, `queue_free` player and floor, `await player.tree_exited`). Helpers: `spawn_floor/box/player/camera_rig`, `wait_physics`, `wait_until`, `tap_action`, `hold_action`, `send_action_event`. Expectations derive from `player.config`, never literals. Every Loader test ends with `check.call(Engine.time_scale == 1.0, ...)`. Add fixtures `set_energy(player, value)` and a time-scale guard. Aim tests to delete/rewrite: see RESEARCH removal inventory (`test_aim_mode`, `test_aim_camera`, `test_aim_pose` deleted; `test_aim_assist`, `test_aim_layer`, `test_aim_target`, `test_dash_lockout` rewritten, `_end` in test_dash_lockout still releases `&"aim"` and must change to `&"loader"`). Run: `bash tests/run.sh test_loader,test_energy` (needs Godot).

## Shared Patterns

### Single-owner energy + request APIs
**Source:** `scripts/player/player_controller.gd` request APIs (`lock_air_control`, `refill_air_dash`, `capture_along`). **Apply to:** ArmEnergy, Loader, Extractor, energy sources. Mechanisms influence the player only through PlayerController request APIs, with `is_finite()` guards; one writer per piece of state (ArmEnergy.value, Engine.time_scale via TimeFx).

### State cleanup in exit()
**Source:** `states/capture.gd:42-43`, `states/dash.gd` header ("gravity_scale is restored in exit()"). **Apply to:** Loader, any state that changes `gravity_scale`, Moto Jump 3 (`Jump.exit()` restores gravity_scale).

### Facts on the EventBus, values only
**Source:** `autoload/event_bus.gd`. **Apply to:** all energy/Loader/shot facts. Never node references for energy facts; quantise high-frequency emits.

### Presentation reads, never drives
**Source:** `hand_presentation.gd`, `crosshair.gd`. **Apply to:** arm cores, Moto glow, HUD, rings, preview. Real-time delta via `TimeFx.unscaled(delta)` while Loader holds.

### Tunables in MovementConfig groups
**Source:** `movement_config.gd`. **Apply to:** all Loader/energy/Moto numbers; hand tunables (`hand_shot_*`, `hand_extract_*`) as floats on `HandController` auto-appear in the F2 "Hand" section (`tuning_panel.gd`).

### Generated artefacts and snapshot guards
`test_movement_metrics` (config snapshot in `docs/MOVEMENT-METRICS.md`), `test_conventions` (action and signal names in `docs/CONVENTIONS.md`), `test_animation_map` (state/clip whitelist in `docs/ANIMATION-MAP.md`), `test_movement_gym` (sanctioned scene prefixes, no particles, >= 40 labels). Plan doc edits in the same task as the code, and mark regeneration steps as "needs Godot on the user's machine".

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `autoload/time_fx.gd` | service | event-driven | Only autoload today is EventBus (facts, no logic); use the RESEARCH TimeFx example plus the `[autoload]` registration line |
| Loader trajectory preview (`MultiMeshInstance3D`, `loader_preview.gd`) | presentation | transform | No existing MultiMesh or dashed-path code; use RESEARCH sketch + `LoaderMath.trajectory`; `hit_puffs.gd` (`scripts/debug/`) is the nearest runtime-spawned-mesh example if needed |

## Metadata

**Analog search scope:** `attimo/autoload`, `scripts/{player,hand,mechanisms,ui,camera,core,debug,gym}`, `scenes/{player,mechanisms}`, `tools`, `tests`.
**Files read for excerpts:** capture.gd (full), remote_trigger.gd (full), hand_presentation.gd (full), module_registry/hand_module/hand_module_def/pulse_hit/remote_trigger def+tscn, event_bus.gd header, boost_ring.gd and slingshot_core.gd heads, dash.gd head, player_controller.gd (dash/lockout/refill region), crosshair.gd (reticle draw region), puzzle_rooms_builder.gd head, test_dash_lockout.gd head, fixtures.gd, movement_config.gd heads.
**Not read (planner/executor to open on demand):** `goggle_lens.gdshader`, `tuning_panel.gd`, `camera_rig.gd` body, `energy_core.tscn`, `mechanism_rooms_builder.gd`, `states/{long_jump,wall_run,jump}.gd` (insertion points are listed in RESEARCH "Energy checks at the existing choke points").
**Pattern extraction date:** 2026-11-24
