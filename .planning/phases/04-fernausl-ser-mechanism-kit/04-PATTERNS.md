# Phase 4: Fernauslöser & Mechanism Kit - Pattern Map

**Mapped:** 2026-11-21
**Files analyzed:** 38 new, 9 modified (grouped into 22 pattern assignments)
**Analogs found:** 20 / 22 groups (2 have no analog: registry resource, packed-scene export round trip)

All paths are relative to `/Users/dominik/Documents/GitHub/Attimo/attimo/` unless noted. Typed GDScript everywhere (`untyped_declaration` is a warning-as-error, also in tools and tests).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `scripts/hand/hand_controller.gd` (new) | controller | event-driven (input poll in physics tick) | `scripts/player/player_controller.gd` `_tick_timers` / `_tick_aim` | role-match |
| `scripts/hand/targeting.gd` (new) | service | request-response (per tick query) | `scripts/camera/camera_rig.gd` `aim_target_point` | role-match |
| `scripts/hand/hand_module.gd`, `hand_module_def.gd`, `hand_context.gd`, `pulse_hit.gd` (new) | model / interface | request-response | `scripts/player/movement_config.gd` (Resource), `scripts/core/state.gd` (base class) | role-match |
| `scripts/hand/module_registry.gd` + `resources/hand/module_registry.tres` (new) | model (Resource) | CRUD (static data) | `scripts/camera/camera_settings.gd` (Resource) | partial |
| `scripts/hand/modules/remote_trigger/*` and `modules/dummy/*` (new) | service | request-response | `scripts/core/state.gd` + `scripts/player/states/dash.gd` | partial |
| `scripts/mechanisms/interactable.gd` (new) | component | event-driven | `scripts/gym/fall_reset.gd` (small node with layer setup in `_ready`) | role-match |
| `scripts/mechanisms/signal_source.gd`, `logic_and/or/timer.gd` (new) | component | pub-sub (local signals) | `scripts/gym/fall_reset.gd` (exported ref + signal wiring) | partial |
| `scripts/mechanisms/triggers/{lever,valve,energy_core,crank}.gd` (new) | component | event-driven | `scripts/gym/fall_reset.gd` | partial |
| `scripts/mechanisms/mechanism.gd` + `lift_platform.gd`, `rotating_platform.gd`, `gear_gate.gd` (new) | component | event-driven + physics tick | `scripts/gym/moving_platform.gd` | exact |
| `scripts/mechanisms/conveyor.gd` (new) | component | physics tick | `tests/smoke/test_platforms.gd` conveyor (`constant_linear_velocity`) | role-match |
| `scripts/mechanisms/steam_nozzle.gd`, `pendulum.gd` (new) | component | event-driven (Area3D to player) | `scripts/gym/fall_reset.gd` (Area3D masks PLAYER, `body_entered`) | role-match |
| `scenes/mechanisms/*.tscn` (new) | scene | n/a | `scenes/proto/moving_platform.tscn` | exact |
| `scripts/player/player_controller.gd` (modify: `launch_along`, `push_toward`, `knock_back`, `arm_out`, rotation carry) | controller | request-response | itself (`_leave_floor`, `teleport`, `start_dash`) | exact |
| `scripts/camera/camera_rig.gd` (modify: `aim_ray`, `look_sensitivity_multiplier`) | service | request-response | itself (`aim_target_point`, line 223) | exact |
| `scripts/ui/crosshair.gd` + `scenes/ui/crosshair.tscn` (modify to goggle HUD) | component (UI) | event-driven | itself | exact |
| `autoload/event_bus.gd` (modify: new facts) | config / bus | pub-sub | itself | exact |
| `scripts/debug/tuning_panel.gd` (modify: hand tunables) | component | CRUD | itself (`_build_aim_rows`) | exact |
| `scripts/player/mannequin_animator.gd`, `aim_pose_modifier.gd` (modify: `arm_out`, palm glow) | component | event-driven | `aim_pose_modifier.gd` (`set_aim_point`) | exact |
| `tools/mechanism_rooms_builder.gd` + edit `tools/movement_gym_builder.gd` (new/modify) | utility (generator) | batch / file-I/O | `tools/movement_gym_builder.gd` | exact |
| `resources/mechanisms/glow_{idle,aim,target}.tres` (new) | config | static | none | none |
| `docs/CONVENTIONS.md` (modify: groups) | doc | n/a | itself lines 60-95 | exact |
| `tests/smoke/test_*.gd` (new, 9 files) + `tests/fixtures.gd` (modify) | test | request-response | `tests/smoke/test_platforms.gd`, `test_crosshair.gd` | exact |

## Pattern Assignments

### `scripts/mechanisms/mechanism.gd`, `lift_platform.gd`, `rotating_platform.gd`, `gear_gate.gd` (component, physics tick)

**Analog:** `scripts/gym/moving_platform.gd` (whole file, 40 lines) and `scenes/proto/moving_platform.tscn`.

**Class header + physics-tick-only motion** (lines 1-39):
```gdscript
class_name MovingPlatform
extends AnimatableBody3D
@export var mode: Mode = Mode.LINEAR
@export_range(0.1, 20.0, 0.1) var speed: float = 3.0
var _start: Vector3 = Vector3.ZERO

func _ready() -> void:
	sync_to_physics = true
	add_to_group(&"moving_platform")
	_start = global_position

func _physics_process(delta: float) -> void:
	_elapsed += delta
	global_position = _start + travel / length * pingpong(_elapsed * speed, length)
```
Copy: `sync_to_physics = true` in `_ready`, group registration, `_start` captured in `_ready`, all motion only in `_physics_process`, `@export_range` on tunables. Replace `_elapsed`/`pingpong` with `move_toward` ramps toward a signal-driven target (research Pitfall 3, ease 0.15-0.3 s). Lift: `global_position = A.lerp(B, t)`, `t = move_toward(t, 1.0 if on else 0.0, speed*delta/len)`. Rotating: new `carrying_platform` group plus `carry_velocity_at(point, delta)` (research "Chord carry" snippet).

**Scene file pattern** (`scenes/proto/moving_platform.tscn`): `AnimatableBody3D` root, `collision_layer = 1` (WORLD), `collision_mask = 0`, `sync_to_physics = true`, `BoxShape3D` sub_resource, mesh as `instance=ExtResource(Primitive_*.gltf)`. Copy for every mechanism scene. Solid parts stay on WORLD; only trigger hit bodies go on INTERACTABLE.

**Gate "never closes on the player" and pendulum/nozzle volumes:** use the Area3D pattern from `scripts/gym/fall_reset.gd` below.

---

### `scripts/mechanisms/steam_nozzle.gd`, `pendulum.gd`, hit zones in `gear_gate.gd` (component, Area3D to player)

**Analog:** `scripts/gym/fall_reset.gd` (whole file).

```gdscript
class_name FallReset
extends Area3D
@export var respawn: Node3D
@export var camera_rig: CameraRig

func _ready() -> void:
	collision_layer = PhysicsLayers.HAZARD
	collision_mask = PhysicsLayers.PLAYER
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	var player: PlayerController = body as PlayerController
	if player == null or respawn == null:
		return
	player.call_deferred(&"teleport", respawn.global_position)
```
Copy: layers set from `PhysicsLayers` constants in `_ready` (never magic numbers), mask PLAYER, cast `body as PlayerController` and null-check, **deferred** call into the player (never inside the physics flush, T-02-08). Nozzle/pendulum call `player.call_deferred(&"launch_along", dir, speed)` / `knock_back`. Add the per-nozzle re-arm (~0.25 s) from research Pitfall 6. Test for layers like `test_platforms.gd` line 189: `check.call(reset.collision_layer == PhysicsLayers.HAZARD and reset.collision_mask == PhysicsLayers.PLAYER, ...)`.

---

### `scripts/player/player_controller.gd` (modify: launch/knock-back/carry entry points)

**Analog:** itself. Insert new public methods next to `start_dash` (line 249) and `teleport` (line 161); insert carry logic in `_integrate` (lines 358-372) / `_post_move` (375-393) / `_leave_floor` (403-408).

**State the FSM integrates** (lines 12-14, 358-372):
```gdscript
var move_velocity: Vector3 = Vector3.ZERO
var vertical_speed: float = 0.0
...
velocity = Vector3(move_velocity.x, vertical_speed, move_velocity.z)
...
move_and_slide()
vertical_speed = maxf(vertical_speed - g * delta * 0.5, -config.terminal_speed)
_post_move()
```
**Platform carry already present** (lines 389-391, 403-408):
```gdscript
if on_floor:
	vertical_speed = 0.0
	_last_platform_velocity = get_platform_velocity()
...
func _leave_floor() -> void:
	if vertical_speed <= 0.0:
		coyote_timer = config.coyote_time
	move_velocity.x += _last_platform_velocity.x * config.platform_carry
	move_velocity.z += _last_platform_velocity.z * config.platform_carry
```
Rotation carry (D-22) hooks here: read the floor collider in `_post_move`, and if it is in group `carrying_platform`, add `carry_velocity_at(global_position, delta)` to `velocity` before `move_and_slide`, and decide suppress vs subtract of the engine `get_platform_velocity()` from the spike result (research A2/A3). Keep exactly one `move_and_slide` per tick.

**State transitions used by `launch_along`/`knock_back`:** `state_machine.transition_to(&"Fall")` (calls `Dash.exit()`, restores `gravity_scale`; Dash overwrites `move_velocity` every tick, see `scripts/player/states/dash.gd` header). `scripts/player/states/fall.gd` is a 3-line `extends AirState`, so a rising Fall is legal. Emit a new `EventBus.launched` fact from the method, like `start_dash`/`_land` emit theirs (`EventBus.landed.emit(global_position, impact_speed)` line 400). Guard non-finite input with `is_finite()` (security row, same as `CameraRig` aim point).

**Public-API doc style:** `##` doc comment above each method, no inline `#` banners.

---

### `scripts/camera/camera_rig.gd` (modify: `aim_ray`, `look_sensitivity_multiplier`)

**Analog:** itself, `aim_target_point` lines 314-331 and `_unhandled_input` line 223.

```gdscript
static func aim_ray_start(origin: Vector3, forward: Vector3, pivot: Vector3) -> Vector3:
	return origin + forward * maxf((pivot - origin).dot(forward), 0.0)

func aim_target_point() -> Vector3:
	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z.normalized()
	...
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(aim_ray_start(origin, forward, global_position), end, crosshair_ray_mask)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (hit["position"] as Vector3).is_finite():
```
Copy this body for `aim_ray(mask, length) -> Dictionary` (reuse `aim_ray_start`, check `is_inside_tree()`, check `is_finite()`). Sticky aim: add a plain var (not `aim_*` prefixed, so the F2 aim rows stay at four per the CONVENTIONS note line 185) and multiply into line 223: `var scale: float = base_sensitivity * settings.sensitivity * lerpf(1.0, aim_sensitivity_factor, aim_weight)`. The camera is never rotated by assist. Widening `crosshair_ray_mask` (`@export_flags_3d_physics`, line 117, default `PhysicsLayers.WORLD`) to `WORLD | INTERACTABLE` is allowed (feeds `AimPoseModifier`).

---

### `scripts/ui/crosshair.gd` + `scenes/ui/crosshair.tscn` (modify to goggle HUD)

**Analog:** itself (48 lines).

```gdscript
@export var lock_color: Color = Color(0.25, 0.9, 0.85, 1.0)
const RING_POINTS: int = 48
@onready var _reticle: Control = $Reticle

func _ready() -> void:
	visible = false
	_reticle.draw.connect(_draw_reticle)
	EventBus.aim_changed.connect(_on_aim_changed)

func set_locked(value: bool) -> void:
	locked = value
	_reticle.queue_redraw()

func _draw_reticle() -> void:
	var centre: Vector2 = _reticle.size * 0.5
	var tint: Color = lock_color if locked else color
	_reticle.draw_circle(centre, dot_radius, tint)
	_reticle.draw_arc(centre, ring_radius, 0.0, TAU, RING_POINTS, tint, ring_width, true)
```
Extend with a state enum (NONE/VALID/VALID_BIG/INVALID), `charge` 0..1 (second `draw_arc`), rim arcs, module frame; keep `set_locked` (VALID maps to locked). Draw each primitive twice (dark wider first). Redraw only via `queue_redraw` on state change. Hard constraints from `tests/smoke/test_crosshair.gd`: root is `Crosshair`, hidden at start, `Reticle` has `mouse_filter == MOUSE_FILTER_IGNORE`, full-rect anchors, `layer` in 1..99, `locked` field and `set_locked` still work. Extend that test file for the new states.

---

### `autoload/event_bus.gd` (modify)

**Analog:** itself. Facts only, typed signals, one `##` doc line above each with listeners:
```gdscript
signal dash_started(position: Vector3, direction: Vector3, in_air: bool)
## Emitted by PlayerController when the aim hold starts (true) or ends (false), once per change (CAM-02). Listeners: ...
signal aim_changed(active: bool)
```
Add `pulse_fired(origin, point, size, hit_valid)`, `interactable_triggered(node, source_kind)`, `mechanism_changed(node, active)`, `launched(position, direction, speed)`. No state, no logic. Tests connect via `tree.root.get_node("EventBus")` and `bus.connect(&"name", callable)` (test_platforms lines 307-310).

---

### `scripts/hand/hand_controller.gd` (controller, event-driven input poll)

**Analog:** `scripts/player/player_controller.gd` `_tick_timers` (300-308) and `_tick_aim` (331-337).

```gdscript
func _tick_timers(delta: float) -> void:
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	...
	if Input.is_action_just_pressed(&"jump"):
		jump_buffer_timer = config.jump_buffer_time

func _tick_aim() -> void:
	var held: bool = Input.is_action_pressed(&"aim")
	if held != aiming:
		aiming = held
		EventBus.aim_changed.emit(aiming)
```
Copy: poll `Input.is_action_just_pressed/released(&"use_hand")` in `_physics_process`, timers via `maxf(x - delta, 0.0)`, read `player.aiming` rather than re-reading `aim`, emit a fact on change. Use the research "Charge/fire timing" sketch as the body. Find the player via the parent, find the rig via `PlayerController.camera_rig()` (line 172), exactly as `MannequinAnimator` does. The hand never writes movement state (FSM is source of truth).

---

### `scripts/hand/hand_module_def.gd`, `module_registry.gd`, `pulse_hit.gd` (Resource / RefCounted data)

**Analog:** `scripts/player/movement_config.gd` and `scripts/camera/camera_settings.gd` (Resources with `@export` / `@export_range` tunables; the F2 panel reads `get_property_list()` for `PROPERTY_HINT_RANGE`). Use `class_name X extends Resource`, `@export_range` on floats so the panel can bind them. No analog for a Resource holding `Array[HandModuleDef]` with `PackedScene` refs; use research Pattern 1 (explicit `.tres`, no `DirAccess`). Base class pattern for `HandModule`: `scripts/core/state.gd` (a Node base with virtual `enter/exit/physics_update` that subclasses override; modules get `activate(ctx)`, `deactivate()`, `on_use_released(big)`).

---

### `scripts/mechanisms/interactable.gd`, `signal_source.gd`, logic nodes, triggers (component, pub-sub)

**Analog:** `scripts/gym/fall_reset.gd` for style (class_name + exported refs + `_ready` sets layers from `PhysicsLayers`). The contract itself (group `&"interactable"`, `set_meta`, `active_changed` signal) has no existing analog; follow research Patterns 2 and 6. Group usage precedent: `add_to_group(&"moving_platform")` in `moving_platform.gd` line 24; `docs/CONVENTIONS.md` lines 72 and 92 mark layer INTERACTABLE and group `interactable` as "reserved, Phase 4" (update to used in the same commit; `test_conventions` checks sync).

---

### `tools/mechanism_rooms_builder.gd` and edit to `tools/movement_gym_builder.gd` (generator)

**Analog:** `tools/movement_gym_builder.gd` (`extends RefCounted`, called from `tools/build_movement_gym.gd`). The gym is generated, so rooms must be built in the builder (research Pitfall 11).

**Build entry** (lines 48-83): zones are added in `build()`:
```gdscript
_build_moving_platforms(_group(_root, "Zone_MovingPlatforms"))
_build_conveyors(_group(_root, "Zone_Conveyors"))
_build_camera_tests(_group(_root, "Zone_CameraTests"))
_build_hall(hall)
```
Add `_build_mechanism_rooms(_group(_root, "Zone_MechanismRooms"))` here (plus the D-26 door).

**Helpers to reuse** (lines 95-135, 152-157): `_adopt(parent, node, name, position, basis)` sets `owner = _root` (required for packing and exported NodePath refs), `_instance(parent, path, name, pos, basis)`, `_instance_node`, `_owner_children(node)` (use after adding code-built subtrees), `_yaw(deg)`, `_floor_tile`, `_wall`, `_label`, `_box_shape`. Constants block pattern (lines 15-30): `const X: String = "res://scenes/..."` per scene. Instance internals stay unowned so the scene keeps the instance reference. Set exported refs with `node.set("source", other)` as done for the rig target (line 58: `rig.set("target", player)`), never `connect(...)` (needs `CONNECT_PERSIST`). Use `_label` Label3D markings for station names. Coordinates on the 1 m grid, 2/4 m modules. The existing class stays under ~2.7k lines of output; a second RefCounted worker keeps files manageable.

---

### `tests/smoke/test_*.gd` (new) and `tests/fixtures.gd` (modify)

**Analog:** `tests/smoke/test_platforms.gd` (integration with physics) and `tests/smoke/test_crosshair.gd` (scene/unit).

**Skeleton** (test_platforms lines 1-34, 36-41):
```gdscript
extends RefCounted
const Fixtures := preload("res://tests/fixtures.gd")
const SHIPPED_TPS: int = 60
const DIAGNOSTIC_TPS: int = 10

func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_x(tree, check)
	Engine.physics_ticks_per_second = 60  # the shipped rate, always restored

func _free_all(tree: SceneTree, nodes: Array[Node]) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
```
**Scenario pattern:** `Fixtures.spawn_floor(tree.root, size)`, `Fixtures.spawn_player(tree.root, pos)`, `await Fixtures.wait_physics(tree, n)`, `check.call(cond, "message with %.2f" % value)`, always `await _free_all(...)` at the end. Hold input with `Input.action_press(&"x")` and always release before freeing. Rotating-platform spike: copy `_scenario_circle_platform` (lines 149-166: track `worst_drift`, grounded tick ratio) and run at `SHIPPED_TPS` and `DIAGNOSTIC_TPS` like `_scenario_ramp` (lines 253-292, resets `Engine.physics_ticks_per_second`). Spawn a mechanism the way `_spawn_platform` does (load PackedScene, set exports, set position, `tree.root.add_child`). Layer checks: copy line 189. Config copies: `player.config = player.config.duplicate() as MovementConfig` (never mutate the shared config). EventBus assertions: `bus.connect(&"jumped", on_jumped)` with an `Array[int]` counter and disconnect afterwards (lines 307-335).
**Fixtures additions** (follow the `static func` style of `tests/fixtures.gd`): `spawn_interactable(...)`, `hold_action(tree, action, seconds)` using `Input.action_press` plus `wait_physics`; for pulse input use `send_action_event` (line 69) when the pipeline matters, `tap_action` (line 116) otherwise.
**Test files:** `test_hand_module.gd`, `test_interactable.gd`, `test_pulse.gd`, `test_aim_assist.gd`, `test_glow_stages.gd`, `test_logic_nodes.gd`, `test_mechanisms.gd`, `test_mechanism_carry.gd`, `test_player_launch.gd`, `test_mechanism_rooms.gd`; extend `test_crosshair.gd`, `test_movement_gym.gd`, `test_conventions.gd`. Run: `bash attimo/tests/run.sh <filter>`.

---

### `scripts/debug/tuning_panel.gd` (modify: hand tunables)

**Analog:** itself, `_build_aim_rows` (lines ~250-260): a generated section from a node's `get_property_list()` filtered by float + `PROPERTY_USAGE_EDITOR` + `PROPERTY_HINT_RANGE` + a name prefix, then `_add_row(obj, property, hint_string, container, sliders, labels)`. Add a "Hand" section the same way (e.g. prefix `hand_` on `HandController` or the def resource exports). Rules: the panel never saves these to `user://settings.cfg` (T-03-07 mirror) and never writes res:// outside the editor (T-02-16). Keep the existing four `aim_` rows unchanged.

---

### `scripts/player/mannequin_animator.gd`, `aim_pose_modifier.gd` (modify: arm-out, palm glow)

**Analog:** `scripts/player/aim_pose_modifier.gd` `set_aim_point(world)` (finite guard, `_aim_point`, `_has_aim_point`), bone names `BONE_HAND = &"hand.r"`. The animator feeds `aim_target_point()` to it; reuse for near contact by feeding the interactable `aim_point`. Skeleton path `Rig_Medium/Skeleton3D` under `VisualRoot/Mannequin` (mannequin_animator.gd:46). Palm glow = emissive mesh plus `OmniLight3D` (no shadow) on a `BoneAttachment3D` for `hand.r`. `mannequin_animator.gd` (547 lines) was not read in this mapping: the planner must read the Aim-layer driver code (`parameters/Aim/blend_amount`) before editing (research A5).

## Shared Patterns

### Physics layers from constants, never magic numbers
**Source:** `scripts/core/physics_layers.gd` (WORLD 1<<0, PLAYER 1<<1, INTERACTABLE 1<<2, ENEMY 1<<3, PROJECTILE 1<<4, HAZARD 1<<5). **Apply to:** every new Area3D/body script and every test. `.tscn` files store bitmasks (WORLD solid bodies = `collision_layer = 1`). INTERACTABLE exists already; no new layer.

### EventBus for facts, local signals for wiring
**Source:** `autoload/event_bus.gd`. **Apply to:** hand, mechanisms, player launch. Cross-system facts go on the bus; trigger-to-mechanism wiring uses local signals (`active_changed`). Gameplay emits, presentation (streak, palm flash, HUD) listens.

### Narrow player API, deferred calls
**Source:** `scripts/gym/fall_reset.gd` `player.call_deferred(...)`. **Apply to:** nozzle, pendulum, any Area3D reacting to the player. Mechanisms never set `velocity` or call `move_and_slide`.

### Doc comments and typing
**Source:** all existing scripts: `##` doc comment above every `class_name`, export, and public method; `StringName` literals `&"..."`; typed `for x: Type in ...`; typed lambdas. No `#` banner comments inside code.

### Physics-tick-only motion and interpolation
**Source:** `scripts/gym/moving_platform.gd`. **Apply to:** all moving mechanisms (never `_process`; `reset()` must call `reset_physics_interpolation()` after teleporting a transform).

### Input via Input Map actions
**Source:** `player_controller.gd` `Input.is_action_pressed(&"aim")`. **Apply to:** hand (`aim`, `use_hand`, `interact`); no hard-coded keys. Poll in `_physics_process`.

### Conventions sync
**Source:** `docs/CONVENTIONS.md` lines 60-95 plus `tests/smoke/test_conventions.gd`. **Apply to:** any new group (`carrying_platform`, `mechanism`) and the `interactable` group row, updated in the same commit.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `scripts/hand/module_registry.gd` + `.tres` | model | static data | No Resource-holding-PackedScene registry exists; use research Pattern 1 |
| `resources/mechanisms/glow_idle/aim/target.tres` | config | static | No shared emissive materials exist yet; research Pattern 5 (three shared `StandardMaterial3D`, one global pulse driver) |
| Packed-scene export round trip test (A1, `test_logic_nodes.gd`) | test | file-I/O | No existing test packs and reloads a scene; build per research Pattern 6 (`PackedScene.pack`, owner set, reload, assert `Array[SignalSource]` populated, fallback `Array[NodePath]`) |
| Hand/mechanism contract (`Interactable`, `SignalSource`) | component | pub-sub | Only style analogs exist (`FallReset`, `MovingPlatform`); contract design is in research Patterns 2 and 6 |

## Metadata

**Analog search scope:** `attimo/scripts/**`, `attimo/scenes/**`, `attimo/tools/**`, `attimo/tests/**`, `attimo/autoload/`, `docs/CONVENTIONS.md`.
**Files read:** crosshair.gd, moving_platform.gd (+ .tscn), event_bus.gd, physics_layers.gd, fall_reset.gd, player_controller.gd (lines 296-409), camera_rig.gd (215-339), movement_gym_builder.gd (44-168), tuning_panel.gd (1-60, 200-260), aim_pose_modifier.gd (1-50), dash.gd (1-50), fall.gd, fixtures.gd, test_platforms.gd, test_crosshair.gd. Not read: mannequin_animator.gd body, ground_state.gd, air_state.gd (research already verified them).
**Pattern extraction date:** 2026-11-21
