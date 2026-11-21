# Phase 4: Fernauslöser & Mechanism Kit - Research

**Researched:** 2026-11-21
**Domain:** Godot 4.7.2 gameplay architecture (hand module framework, instant-hit targeting, aim assist, editor-wired mechanisms, moving platforms under Jolt)
**Confidence:** MEDIUM-HIGH (codebase facts verified by reading the code; the Godot-engine behaviours for rotating platforms and typed node-array exports are ASSUMED and must be proven by the first spike; no Godot binary exists on this machine, so nothing could be run)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
D-01..D-30 in `.planning/phases/04-fernausl-ser-mechanism-kit/04-CONTEXT.md` are locked and authoritative. Summary of the ones that drive implementation (the planner must read the full file):
- D-01 pulse not beam (tap = small, hold >= 0.4 s = big; D-05 threshold tunable); D-02 fire only while aiming (RMB hold + LMB); D-03 small ~15 m / big ~25 m, each Interactable declares the pulse size it needs; D-04 instant hit by raycast, visible streak is presentation only, target reacts next frame; D-06 a shot at nothing still fires; D-07 cooldown ~0.25 s, no HUD element; D-07b palm glows brighter while charging, flash on fire (emissive spot or small light, no particles).
- D-08/D-09/D-10 near contact with `interact` (E), arm out + palm pulse, Interactables declare shot / near / both; near contact can be held (crank).
- D-11..D-14 always-faint turquoise glow, stronger while aiming, brightest+pulsing on target, minimal goggle HUD (rim arcs, gear-notch reticle, charge arc, module frame), aim assist = snap + sticky slowdown with hysteresis, camera never pulled.
- D-15 four triggers (Hebel, Handrad-Ventil, Energiekern, Uhrwerk-Kurbel); D-16 six mechanisms (Zahnrad-Tor, Dreh-Plattform, Hub-Plattform, Förderband, Dampfdüse with 4 modes, Pendel); D-17..D-22 toggle / per-instance behaviour / gate never crushes / nozzle sets velocity along its axis and keeps sideways momentum / pendulum knock-back, no damage / moving parts carry without slide, jitter or launch.
- D-23 AND, OR, timer are invisible logic nodes wired in the editor; D-24/D-25 Pattern 4 framework + dummy module, pulse hit data carries size, hit point, direction, collider.
- D-26..D-29 extend the existing gym with a door, room 2 = showcase, then several puzzle rooms, all from Prototype Bits on the 1 m grid.
- D-30 plan count stays in the `standard` band (3-5 plans); group related work.

### Claude's Discretion
Number/layout of puzzle rooms (about 3); all tunable numbers; near-contact range and whether it works while aiming; arm-out pose; pulse streak shape (no particles); dummy module behaviour; optional "stays on" per lever/valve.

### Deferred Ideas (OUT OF SCOPE)
Full goggle look (vignette, tint): Phase 11. Hand particles: Phase 12. Pulse vs enemies/damage: Phase 6. Module icon in HUD frame: Phase 5. Pendulum damage: Phase 6. Pressure plate, extending bridge, swing bridge: not picked.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HAND-01 | Module framework: def resource + behaviour scene, one folder + one registry entry | `HandModuleDef` + `HandModule` + `ModuleRegistry.tres` with preloaded scene refs; no DirAccess scan (Pattern 1) |
| HAND-02 | Interactables declare accepted modules/inputs; modules only talk to the contract | `Interactable` component with `accepts_shot`, `accepts_near`, `min_pulse`; modules call `target.try_trigger(hit)` only |
| HAND-03 | Fernauslöser pulse (small/big) triggers mechanisms at range | `RemoteTrigger` module, instant ray via a new `CameraRig.aim_ray()`, range from player origin, charge state machine |
| CAM-04 | Interactables glow; the targeted one is clearly highlighted | Shared stage materials (no per-instance duplication), global pulse driver, reticle state |
| CAM-05 | Aim assist snaps to nearest valid interactable, with hysteresis | Angle-cone selection over the `interactable` group + LOS ray + hysteresis; sticky sensitivity as a rig multiplier (camera never moved) |
| MECH-01 | Reusable mechanism components | 4 triggers + 6 mechanisms on a common `SignalSource` / `Mechanism` contract |
| MECH-02 | Signal wiring incl. AND, OR, timer | `LogicAnd`, `LogicOr`, `LogicTimer` nodes with exported source refs |
| MECH-03 | Moving mechanisms carry the player correctly | AnimatableBody3D + speed ramps; conveyor via `constant_linear_velocity`; rotating platforms need analytic chord-carry in `PlayerController` (known Godot/Jolt pitfall) |
</phase_requirements>

## Summary

The code base is well prepared. `CameraRig` already owns the crosshair ray (`aim_target_point()`, `aim_direction_from()`, `crosshair_ray_mask`, `aim_sensitivity_factor` applied in `_unhandled_input`), `Crosshair.set_locked()` is reserved, `PhysicsLayers.INTERACTABLE` and the `interactable` group are reserved and documented, `EventBus` is the fact bus, the `MovingPlatform` + conveyor carry is already covered by `test_platforms.gd`, and `MannequinAnimator`/`AimPoseModifier` already point the right arm at a world point. Phase 4 is therefore mostly new scripts layered on these seams, plus two small core edits (`CameraRig` gets a generic ray and a sensitivity multiplier, `PlayerController` gets a launch/push entry point and platform rotation carry).

Two genuine risks. (1) Rotating platforms: Godot's built-in platform velocity carries translation but a CharacterBody3D standing off-centre on a rotating AnimatableBody3D drifts outward (forum reports on 4.6 with Jolt; no verified fix found). Plan an explicit, tested carry in `PlayerController` rather than trusting `get_platform_velocity()`. (2) The nozzle and pendulum must change `move_velocity`/`vertical_speed` (the only things the FSM integrates) from outside the FSM; the clean seam is a pair of methods on `PlayerController` that write those fields and, when grounded, force the `Fall` state. The grounded states and `AirState` already behave correctly with a rising `Fall`.

**Primary recommendation:** Build in 4 plans per D-30: (1) core seams + hand framework + Fernauslöser + targeting + HUD + glow; (2) triggers + logic + Interactable-driven mechanisms (static: gate, valve/lever visuals); (3) moving mechanisms + player launch/carry entry points + spike tests; (4) showcase room + puzzle rooms in the gym builder + integration tests. Do the rotating-platform spike first inside plan 3 (or plan 1's Wave 0) because it can force a `PlayerController` change.

## Architectural Responsibility Map

(Single-process Godot game; "tiers" are the project's layers.)

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Input -> charge/fire intent | Player-side `HandController` (child of Player) | `PlayerController` (`aiming`) | Reads `aim`/`use_hand`/`interact` in the physics tick, same pattern as `_tick_aim` |
| Targeting (ray, assist, hysteresis) | `Targeting` node under HandController | `CameraRig` (ray, sensitivity multiplier) | Rig owns the camera/ray; targeting owns selection state |
| Interactable contract | World object component (`Interactable`) | `interactable` group + INTERACTABLE layer | World never knows module classes (Pattern 5) |
| Mechanism state + logic | Mechanism scenes + logic nodes | editor-wired exported refs | Local signals, not EventBus (ARCHITECTURE Pattern 6) |
| Moving-part carry | `AnimatableBody3D`/`StaticBody3D` mechanisms | `PlayerController` carry code | Platform moves in `_physics_process`; player integrates its velocity |
| Player launch/knock-back | `PlayerController` public methods | movement FSM (reads result only) | Hand/mechanisms never touch the FSM (D-20, D-21, Pattern 4 "narrow API") |
| Facts for juice | `EventBus` | Phase 11/12 listeners | FEEL-01 |
| Goggle HUD + glow stages | `Crosshair` CanvasLayer + shared materials | `Targeting` signals | Presentation listens, never drives gameplay |
| Room content | `tools/` builder scripts -> `movement_gym.tscn` | — | The gym is generated (build_movement_gym.gd), not hand-edited |

## Standard Stack

No new addons or packages. Everything is built-in Godot 4.7.2 + typed GDScript. [VERIFIED: attimo/project.godot, .claude/CLAUDE.md]

| Piece | Built-in used | Why |
|-------|---------------|-----|
| Raycast | `PhysicsDirectSpaceState3D.intersect_ray` (already used in `CameraRig.aim_target_point`) | Instant hit, no node needed |
| Moving platforms | `AnimatableBody3D` + `sync_to_physics` (existing `MovingPlatform`) | Engine reports platform velocity to CharacterBody3D |
| Conveyor | `StaticBody3D.constant_linear_velocity` (existing, tested) | Already proven in `test_platforms` |
| Proximity/volumes | `Area3D` (gate overlap, nozzle volume, pendulum hit, near contact) | Standard |
| Glow | `StandardMaterial3D` emission, shared `.tres` | No duplication |
| Registry | custom `Resource` with `Array[HandModuleDef]` | Export-safe |

**Packages:** none installed -> Package Legitimacy Audit not applicable. **Package legitimacy / slopcheck:** not run (no external packages). [VERIFIED: phase scope]

## Architecture Patterns

### System Architecture Diagram

```
Input (aim hold, use_hand, interact)
   |
   v
PlayerController._physics_process
   |-- _tick_aim() -> EventBus.aim_changed          (existing)
   |-- state_machine.physics_update()               (existing, source of truth for movement)
   |-- _integrate()                                 (existing single move_and_slide)
   '-- HandController._physics_process (sibling node, runs after Player? see Pitfall 7)
          |
          |-- Targeting.update(): camera ray (WORLD|INTERACTABLE) + assist cone over group "interactable"
          |        -> current_target (Interactable|null), valid flag, needs_big flag
          |        -> CameraRig.look_slowdown (sticky), Crosshair.set_state(...)
          |        -> glow stage change (Interactable.set_focus)
          |-- charge timer (use_hand held while aiming) -> small/big on release
          '-- active HandModule.on_use_released(PulseHit)
                  |
                  v
          RemoteTrigger.fire(size)
             instant ray from camera/crosshair (or assist target point), range from player origin
             -> PulseHit{size, point, direction, collider, interactable}
             -> EventBus.pulse_fired(...)  (presentation: streak, palm flash)
             -> if interactable and accepts(shot, size): interactable.try_trigger(hit)
                         |
                         v  signal triggered(hit)
              Trigger (Hebel/Ventil/Kern/Kurbel)  --active_changed(bool)-->
                   LogicAnd/Or/Timer --active_changed(bool)--> Mechanism.set_signal(bool)
                         |
                         v
   Mechanism._physics_process: moves AnimatableBody3D / sets conveyor velocity /
   Area3D nozzle or pendulum -> PlayerController.launch_along()/push()  (public, narrow)
```

### Recommended Project Structure
```
attimo/scripts/hand/
  hand_controller.gd        # input, charge, cooldown, module routing, arm_out flag
  hand_module.gd            # class_name HandModule extends Node  (interface)
  hand_module_def.gd        # class_name HandModuleDef extends Resource
  module_registry.gd        # class_name ModuleRegistry extends Resource (Array[HandModuleDef])
  hand_context.gd           # class_name HandContext extends RefCounted (player, rig, socket, targeting)
  pulse_hit.gd              # class_name PulseHit extends RefCounted (D-25 data)
  targeting.gd              # target selection + hysteresis + sticky
attimo/scripts/hand/modules/remote_trigger/remote_trigger.gd (+ remote_trigger.tscn, remote_trigger_def.tres)
attimo/scripts/hand/modules/dummy/dummy_module.gd (+ .tscn, .tres)   # proves "one folder + one registry line"
attimo/resources/hand/module_registry.tres
attimo/scripts/mechanisms/
  interactable.gd           # component (Node), class_name Interactable
  signal_source.gd          # base: is_active, active_changed(bool)
  logic_and.gd logic_or.gd logic_timer.gd
  triggers/ lever.gd valve.gd energy_core.gd crank.gd
  mechanism.gd              # base: set_signal(bool), mode enum (RUN_WHILE_ON / REVERSE_ON_SIGNAL)
  gear_gate.gd rotating_platform.gd lift_platform.gd conveyor.gd steam_nozzle.gd pendulum.gd
attimo/scenes/mechanisms/*.tscn   # one scene per component (greybox)
attimo/resources/mechanisms/glow_*.tres   # shared materials
attimo/scenes/ui/goggle_hud.tscn  # extends/replaces crosshair.tscn content
attimo/tools/mechanism_rooms_builder.gd   # called from movement_gym_builder.gd (file is already 2.7k lines of .tscn)
attimo/tests/smoke/test_*.gd
```
Note: CONTEXT says the module folder is `hand/modules/<name>/` (ARCHITECTURE layout). The repo uses `scripts/` and `scenes/` roots, so keep a self-contained folder `scripts/hand/modules/<name>/` holding script, scene and def together (that is what makes "one folder" true). [VERIFIED: directory listing]

### Pattern 1: Module registry (one folder + one registry entry)
**What:** `module_registry.tres` is a `ModuleRegistry` resource whose `modules: Array[HandModuleDef]` lists defs; each `HandModuleDef` has `scene: PackedScene`. The `.tres` stores `ext_resource` references, so the export includes the module scenes without any `DirAccess` scan (scan inside a PCK needs `.remap` handling; ARCHITECTURE.md Pattern 4 already says the explicit registry is safer). Adding a module = create folder with script+scene+def, add one line (one `ext_resource` + array entry) to the registry. [CITED: .planning/research/ARCHITECTURE.md Pattern 4]
**HandController** instantiates the active module scene lazily, calls only the base interface: `activate(ctx)`, `deactivate()`, `on_use_pressed()`, `on_use_released(charged: bool)`, `on_near_pressed/held/released()`. Module never references Player or other modules; it gets a `HandContext` (player for the narrow `launch_along/push` API, rig, socket, targeting result).
**Test seam:** instantiate a module scene with a fake `HandContext` and a stub Interactable (no player needed).
```gdscript
class_name HandModuleDef
extends Resource
@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export var small_range: float = 15.0
@export var big_range: float = 25.0
@export var cooldown: float = 0.25
```
Dummy module (D-24): e.g. prints/emits `used` and records a counter; the smoke test registers it via the registry (second entry, `enabled_in_game=false` or just not default-equipped) and asserts HandController can equip it by id without any HandController edit.

### Pattern 2: Interactable component (contract)
**What:** `class_name Interactable extends Node`, child of the mechanism root. Exports: `accepts_shot: bool`, `accepts_near: bool`, `min_pulse: PulseHit.Size` (SMALL/BIG), `hit_body: CollisionObject3D` (the body/area on INTERACTABLE layer), `aim_point: Node3D` (optional marker for the assist), `glow_meshes: Array[MeshInstance3D]`. In `_ready`: `add_to_group(&"interactable")`, `hit_body.collision_layer = INTERACTABLE`, `hit_body.set_meta(&"interactable", self)`. Signals: `triggered(hit: PulseHit)`, `near_started()`, `near_held(delta)`, `near_ended()`, `focus_changed(stage)`. Method `can_accept(kind, size) -> bool` is the single place D-03/D-09 are decided, also used by Targeting to set the reticle to valid/needs-big/invalid.
**Collider -> Interactable:** meta on the hit collider (O(1), no tree walk). [ASSUMED: meta approach is a design choice, not an engine fact]
**Layering:** interactable hit bodies sit on INTERACTABLE only and the player masks WORLD only, so a lever never blocks the player. Mechanisms that are solid (gate, platforms) stay on WORLD and are not directly targeted; targets are triggers.

### Pattern 3: Instant-hit pulse and targeting
- Add `CameraRig.aim_ray(mask: int, length: float) -> Dictionary` (reuses `aim_ray_start`, so geometry between lens and character is never hit). Do NOT just widen `crosshair_ray_mask` silently: it also feeds `AimPoseModifier`; widening it to WORLD|INTERACTABLE is acceptable (arm then points at the lever), but the generic method keeps range/mask explicit per shot. [VERIFIED: camera_rig.gd lines 311-331]
- Ray mask = `WORLD | INTERACTABLE | ENEMY` later; first hit decides, so a wall in front of a lever blocks the shot (World occludes). [VERIFIED: physics_layers.gd, CONVENTIONS layer table]
- Range is measured from the player origin to the hit point (not from the camera, which sits ~3.6-4.5 m behind): `hit_distance = player.global_position.distance_to(point)`. A hit beyond `small_range` for a small pulse = invalid target, reticle dimmed, the shot still fires (D-06).
- Assist target (D-14): when the assist has a target, the pulse aims at `target.aim_point` and the hit is that Interactable exactly.
- Fire on release: a tap must be distinguished from a hold, so the small pulse fires on LMB release (latency = hold time, typically 60-150 ms). Optional mitigation if it feels laggy: fire the small pulse on press when the active target does not need the big one... that conflicts with D-05 (a tap = small, hold = big), so keep fire-on-release and tune. [ASSUMED: latency acceptable; flag for human playtest]
- Poll `Input.is_action_just_pressed/released(&"use_hand")` in the physics tick (same pattern as `PlayerController._tick_timers`, catches presses between ticks). [VERIFIED: player_controller.gd:307]
- "Target reacts next frame": trigger synchronously at fire; mechanisms respond in their next `_physics_process`.
- Hit data: `PulseHit` RefCounted {size, origin, point, direction, collider, interactable} (D-25). Emit `EventBus.pulse_fired(origin, point, size, hit_valid)` and `EventBus.interactable_triggered(node, source_kind)`, `EventBus.mechanism_changed(node, active)` (typed primitives/nodes, no state).

### Pattern 4: Aim assist with hysteresis and sticky sensitivity (CAM-05, D-14)
- Candidates: iterate `get_tree().get_nodes_in_group(&"interactable")` (tens of nodes at most) per physics tick; compute angle between camera forward and direction camera->`aim_point`; filter: `can_accept(kind,size)`-agnostic for display (invalid ones still glow but never snap), within `assist_angle` (start ~3.5 deg), within `big_range`, line of sight (one World-mask ray from `aim_ray_start` to the point). The exact ray hit counts as angle 0 and wins.
- Hysteresis: keep the current target while its angle <= `assist_angle * 1.6` and LOS holds; switch to another only if that candidate's angle < current angle - `switch_margin` (~1 deg) for the rest to avoid flicker. Add a small drop delay (~0.1 s) before releasing a target.
- Sticky: `CameraRig` gets `look_sensitivity_multiplier` (float, eased, default 1.0) multiplied into `scale` in `_unhandled_input` (line 223). Targeting writes e.g. 0.6 while a valid target is held, eased in/out. The camera is never rotated by assist. [VERIFIED: camera_rig.gd:223]
- Debug draw is deferred (A39); use the F2 panel for numbers instead.
- Gamepad (Phase 13) can reuse the same module.

### Pattern 5: Shared-material glow stages (CAM-04, D-11, D-12)
No per-instance material duplication: create shared resources `glow_idle.tres` (low emission), `glow_aim.tres` (stronger), `glow_target.tres` (brightest). Each interactable has a glow-only mesh (lens/core/handle). Stage switching swaps `material_override` on that mesh among the shared resources (assigning a shared resource is free). Pulsing is done by one global `GlowDriver` (node in the HUD scene or a static helper updated from `Targeting`) that animates `emission_energy_multiplier` on the shared `glow_target` (only one target at a time, so sharing is safe) and slowly on `glow_idle`/`glow_aim` (everything pulses together, fine). Aim stage: all interactables switch idle->aim on `aim_changed`. Rule "nothing non-interactable glows turquoise": keep the turquoise colour only in these three materials and add a smoke test that scans the gym for the colour/material usage. [ASSUMED: StandardMaterial3D `emission_enabled` + `emission_energy_multiplier` API; standard, verify in 4.7 class ref]
Check the gym `WorldEnvironment` has glow enabled (grep found a WorldEnvironment node but glow settings were not verified); with Group A "no juice" a bloom-less emissive is acceptable.

### Pattern 6: Signal graph (MECH-02, D-23)
- `SignalSource` (Node, `class_name`): `var is_active: bool`, `signal active_changed(active: bool)`, `set_active(v)` emits only on change. Triggers extend it; logic nodes extend it too, so logic can chain (AND of an OR etc.).
- `LogicAnd`/`LogicOr`: `@export var sources: Array[SignalSource]`; connect to each `active_changed` in `_ready`, recompute. `LogicTimer`: `@export var source`, `@export var hold_time`; rising edge starts timer, output true until it elapses (retriggerable flag).
- `Mechanism`: `@export var source: SignalSource`; in `_ready` connects `source.active_changed` to `set_signal` and applies the current state once (so a source that is already active at load works). Per-instance behaviour enum (D-18): `RUN_WHILE_ON`, `REVERSE_ON_SIGNAL`; lift uses `A_B`.
- The gym is generated by a builder script and packed with `PackedScene.pack`. Exported node references (`NodePath`s stored by the engine) survive packing as long as every node has an `owner`; signal connections need `CONNECT_PERSIST`. Prefer exported refs set in the builder over `connect(...)` in the builder. The existing builder already has `_adopt`/`_owner_children` helpers for owner handling. [VERIFIED: movement_gym_builder.gd function list]
- Typed node-array exports (`Array[SignalSource]` of a custom `class_name` Node) are expected to work in 4.x but this is [ASSUMED]; Wave 0 spike: build a tiny packed scene in a headless test, reload it, assert the array is populated. Fallback: `Array[NodePath]` resolved with `get_node` in `_ready`.
- Local signals only; EventBus gets `mechanism_changed` as a fact for juice. (ARCHITECTURE Pattern 6: emitter and listener in one scene -> local signal.) [CITED: .planning/research/ARCHITECTURE.md]
- Reset path (PITFALLS: every puzzle needs a reset path): mechanisms expose `reset()`; the existing `FallReset` already respawns the player; add a per-room reset that calls `reset()` on all `SignalSource`/`Mechanism` nodes in the room group (cheap, prevents soft locks, e.g. an energy core or pulse-only gate state). [CITED: .planning/research/PITFALLS.md line 171]

### Pattern 7: Player entry points for launch/knock-back (D-20, D-21)
The FSM only integrates `move_velocity` (horizontal), `vertical_speed`, `gravity_scale`, and `_integrate` does the one `move_and_slide`. [VERIFIED: player_controller.gd] Add to `PlayerController`:
```gdscript
## One-shot: sets the velocity along `direction` to `speed`, keeps the component of the current velocity perpendicular to it (D-20).
func launch_along(direction: Vector3, speed: float) -> void:
	var dir: Vector3 = direction.normalized()
	var v: Vector3 = Vector3(move_velocity.x, vertical_speed, move_velocity.z)
	var side: Vector3 = v - dir * v.dot(dir)
	v = side + dir * speed
	move_velocity = Vector3(v.x, 0.0, v.z)
	vertical_speed = v.y
	coyote_timer = 0.0
	air_speed_cap = maxf(config.run_speed, horizontal_speed())
	if state_machine.current.name != &"Fall":
		state_machine.transition_to(&"Fall")
	EventBus.launched.emit(global_position, dir, speed)

## Continuous (updraft/steam wall): moves velocity toward a target along an axis, per tick, from the nozzle's physics tick.
func push_toward(direction: Vector3, target_speed: float, accel: float, delta: float) -> void: ...

## Knock-back impulse (D-21): adds to velocity; also interrupts a Dash (the Dash state overwrites move_velocity every tick).
func knock_back(impulse: Vector3) -> void: ...
```
Why this works with the existing FSM (verified by reading): a rising `Fall` is legal (Fall has no apex check, `AirState` lands only when `is_grounded() and vertical_speed <= 0`; `Jump`'s `apply_jump_cut` is not called in Fall, so the launch is not cut). Upward velocity disables floor snap in `move_and_slide`, so the body leaves the floor, `_leave_floor` runs with `vertical_speed > 0` (no coyote), and adds platform velocity. `Dash.physics_update` writes `move_velocity` every tick, so a knock-back or launch during a dash must transition out of Dash (via `transition_to(&"Fall")`, which calls `Dash.exit()` and restores `gravity_scale`). LongJump: same, transition out. `air_dash_available` is untouched (D-20: dash stays available); `dash_cooldown_timer` untouched. Pendulum on the ground: give a small upward component (about 3-5 m/s) so the body enters Fall and uses air decel; otherwise `ground_decel` eats the horizontal knock-back in a few ticks. [VERIFIED: ground_state.gd, air_state.gd, fall.gd, dash.gd, player_controller.gd; the numbers are ASSUMED tuning]
Also add `Fixtures`-level smoke tests: launch from ground, launch in air, launch during dash, sideways momentum preserved, vertical exactly `speed` along an up axis (height repeatability, D-20 "reliable height and distance").
Nozzle repeat-trigger guard: a one-shot launch from an `Area3D` must not fire every tick while the player overlaps; use a per-nozzle re-arm (player leaves the volume or `launch_cooldown` ~0.25 s).

### Pattern 8: Moving mechanisms and player carry (MECH-03, D-22)
**Facts (verified in repo):** `PlayerController` sets `platform_on_leave = DO_NOTHING`, reads `get_platform_velocity()` while on floor into `_last_platform_velocity`, and on leaving adds its horizontal part times `config.platform_carry`. Linear, vertical and circular `MovingPlatform` motion and a `StaticBody3D.constant_linear_velocity` conveyor are already tested at 60 TPS and the walk-off case is covered. [VERIFIED: player_controller.gd:375-409, test_platforms.gd]
- **Lift (Hub) platform:** `AnimatableBody3D`, `sync_to_physics = true`, moved only in `_physics_process`, `global_position = A.lerp(B, t)`, with `t` advanced by `move_toward` at a speed capped (for decelerating/stopping) so the platform velocity never steps instantly from v to 0 while carrying (instant stops are fine for the player since only horizontal velocity carries on leaving, but vertical shear while the player stands is visible; use a short ease, ~0.15 s). Descending faster than fall speed is covered by the speed-scaled floor snap. Keep descent speed below about `config.snap_max / delta` per tick; verify with a test at 60 and 10 TPS (the existing DIAGNOSTIC_TPS pattern).
- **Conveyor:** keep `constant_linear_velocity` on a `StaticBody3D` (proven). Toggling/reverse: assign `constant_linear_velocity` from code with a short ease (move_toward) to avoid a launch when the signal flips. The player jump-off keeps the conveyor velocity as momentum through `platform_carry` (already tested in `_scenario_conveyor_jump`).
- **Rotating platform (the pitfall):** a CharacterBody3D standing off-centre on a rotating AnimatableBody3D is carried along the tangent but drifts outward from the centre because the carry is a straight velocity while the contact point travels on a circle; reported on Godot 4.6 with Jolt, no verified engine fix found. [CITED: https://forum.godotengine.org/t/rotating-characterbody3d-on-rotating-platform-how/136346 ; https://forum.godotengine.org/t/how-to-make-characterbody3d-stay-stable-on-rotating-and-moving-platforms/86573 ; both forum reports, MEDIUM-LOW]
  **Recommendation (prescriptive):** Do not rely on `get_platform_velocity()` for rotating bodies. Give rotating platforms a method `carry_velocity_at(world_point: Vector3, delta: float) -> Vector3` that returns the chord velocity `((R(omega*delta) * (p - pivot)) + pivot - p) / delta + linear_velocity` (exact displacement of that point over one tick, no tangent drift), and put the platform in a group `&"carrying_platform"`. `PlayerController._post_move/_integrate` finds the floor collider (loop `get_slide_collision_count()` for a collision with `get_floor_normal`-compatible normal, or keep the collider from the last grounded tick), and if it is a `carrying_platform` adds `carry_velocity_at(global_position, delta)` to `velocity` just before `move_and_slide` and suppresses the engine's own platform velocity for it (otherwise it is applied twice). Simplest suppression: rotating platforms set `sync_to_physics = false` and are moved with a script-set transform but excluded from `get_platform_velocity()` via a `platform_floor_layers` split, OR (safer, ASSUMED) leave the engine behaviour and subtract the engine's `get_platform_velocity()` before adding the chord velocity. Which of these works under Jolt must be decided by the spike below. Also yaw: rotate `VisualRoot` by `omega_y * delta` is optional polish; the camera does not rotate with the platform.
  **Spike (plan 3, task 1, headless, no human needed):** spawn the player at radius 3 m on a rotating AnimatableBody3D at 1 rad/s (standing axis Y, then a tilting axis X at low angle), run 3 s at 60 TPS and at 10 TPS, assert radial distance from the axis stays within 0.05 m and the player stays grounded. Run it first without the custom carry to document the drift, then with it. This is the single test that settles MECH-03.
  Keep rotating platform speed moderate (the spec examples: gear 0.8-1.2 rad/s, clock hand 0.5-0.8 rad/s) so a missed carry is not catastrophic; tilting platform tilt limited to the `floor_max_angle` (~50 deg per `MovementConfig`) minus a margin so the player never slides off by physics rather than by design.
- **Gate (Zahnrad-Tor):** `AnimatableBody3D` sliding on a rail, ~0.3 s. D-19: never closes on the player: an `Area3D` over the doorway (mask PLAYER); while it overlaps, the closing is paused (state "waiting"). Same for the lift when descending onto the player is not needed (lift is carried, not crushed) but a ceiling above lifts needs level design care.
- **Pendulum:** `AnimatableBody3D` driven by a sine angle in `_physics_process` (so the engine reports velocity) plus an `Area3D` hit zone (layer HAZARD, mask PLAYER) calling `player.knock_back(tangent_direction * strength + up)`; gate with a re-hit cooldown (~0.5 s). Swing direction = sign of the current angular velocity tangent, projected flat.
- All mechanisms move strictly in `_physics_process`; mechanism scenes keep `physics_interpolation_mode` inherited (project interpolation on), so no manual `reset_physics_interpolation` except on teleports/resets (call it in `reset()` after setting the transform). [VERIFIED: project.godot common/physics_interpolation=true; CITED: PITFALLS.md]

### Pattern 9: Arm-out and hand presentation (D-07b, D-08)
- `MannequinAnimator` drives `parameters/Aim/blend_amount` from aim; extend it to read a `PlayerController.arm_out: bool` set by `HandController` (true during near contact, true for ~0.25 s after a shot, true while aiming) so the upper-body layer and `AimPoseModifier` raise the right arm. Near contact does not pin facing (aim does that in `_tick_aim`); `aim_target` for the modifier is the interactable's `aim_point` during near contact. [ASSUMED: the animator accepts a second driver without disturbing the aim blend; verify in the spike by reading `mannequin_animator.gd` — not read in this research]
- Palm glow: a small emissive mesh + `OmniLight3D` (no shadow, low range) on a `BoneAttachment3D` for `hand.r` under `VisualRoot/Mannequin/Rig_Medium/Skeleton3D`. Energy from `HandController.charge_ratio` plus flash on `pulse_fired`. No particles (Group A). [VERIFIED: skeleton path `Rig_Medium/Skeleton3D` from mannequin_animator.gd:46, bone name `hand.r` from aim_pose_modifier.gd:18]
- Pulse streak: one `MeshInstance3D` (stretched thin `BoxMesh`/`CylinderMesh`, unshaded turquoise) positioned between hand and hit point for ~0.08 s via a Tween or timer; owned by a presentation node listening to `EventBus.pulse_fired`.

### Pattern 10: Goggle HUD (D-13)
Extend `Crosshair` (CanvasLayer + `Reticle` Control drawn in code, existing): states `NONE`, `VALID`, `VALID_BIG` (outer ring), `INVALID` (dim + diagonal stroke), `charge` 0..1 (arc via `draw_arc`), rim arcs at the screen edges with rivets drawn in `_draw`, module frame bottom centre (a small drawn rectangle + label of `def.display_name`). Keep drawing code-only (no image assets) like today. Reticle needs a dark outline: draw each primitive twice (dark wider first, white on top). `set_locked(bool)` stays for compatibility (`VALID` = locked). Keep `mouse_filter = IGNORE` and the layer below 100 (existing test constraints). [VERIFIED: crosshair.gd, test_crosshair.gd]
Redraw only on state change (`queue_redraw`), not per frame, except while charging.

### Anti-Patterns to Avoid
- Putting trigger logic in `HandController` per module id (breaks HAND-01/02). Modules call the contract only.
- Setting `velocity` or calling `move_and_slide` from a mechanism. Only `launch_along/push_toward/knock_back` on the player.
- Duplicating a `StandardMaterial3D` per interactable for glow (use the three shared stages).
- Moving a platform in `_process` (jitter with physics interpolation; carry reads wrong velocity).
- Letting the pulse/aim ray hit the player's own collider (player layer is not in the mask, fine) or hit an INTERACTABLE body behind a wall (World occlusion: first hit wins).
- A discrete angle check without hysteresis (flicker). Pulling the camera toward the target (violates D-14).
- Per-frame `get_nodes_in_group` allocations inside `_process`; do it in the physics tick at tick rate, cache the array when the group is unchanged is premature at this scale.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Instant raycast | custom bullet/projectile simulation | `intersect_ray` (existing in CameraRig) | D-04 says instant hit |
| Platform velocity | custom position-diff tracking for linear platforms | `AnimatableBody3D` + `sync_to_physics` + engine platform velocity (existing) | Already tested; only rotation needs custom carry |
| Conveyor | custom push logic | `constant_linear_velocity` | Tested in test_platforms |
| State machine for mechanisms | a new FSM framework | a `bool` + enum + `move_toward` ramps | 2-state mechanisms; the project rule is own simple code |
| Module discovery | `DirAccess` folder scan | explicit `ModuleRegistry.tres` | PCK `.remap` safety (ARCHITECTURE Pattern 4) |
| Tween-based glow per object | per-instance animation players | one shared-material driver | cost and consistency |
| HUD | image assets for reticle/rim | code-drawn `Control._draw` (existing Crosshair approach) | Group A, no assets |

**Key insight:** every hard piece (ray, carry, conveyor, HUD drawing, event bus, test harness) already exists in the repo. The new work is contracts and glue; the only new physics risk is rotation carry.

## Runtime State Inventory

Not a rename/refactor/migration phase: omitted. (The wording changes in CONTEXT, "beam" -> "pulse" in REQUIREMENTS.md, ROADMAP.md, SHOOT-01, plus MECH-01 and the Phase 4 success criteria, are document edits, no runtime state.)

## Common Pitfalls

### Pitfall 1: Rotating platform drift (MECH-03)
**What goes wrong:** player slides outward / off the platform. **Why:** carry is a straight-line velocity applied to a circular path (known Godot+Jolt report). **Avoid:** chord-velocity carry + the headless spike with a radial-drift assertion at 60 and 10 TPS. **Warning signs:** player distance from the axis grows during a rotation test.

### Pitfall 2: Double carry
**What goes wrong:** adding custom carry on top of the engine's platform velocity doubles the speed. **Avoid:** the spike decides which to suppress; assert the player's speed relative to the platform is ~0 in the test.

### Pitfall 3: Instant start/stop launches the player
**What goes wrong:** toggling a conveyor/lift/rotator from 0 to full speed in one tick shoves the player or lets them keep a jolt of momentum via `platform_carry`. **Avoid:** ease every moving mechanism's speed with `move_toward` (about 0.15-0.3 s); jump-off momentum then is what the platform actually had.

### Pitfall 4: Dash overwrites launch/knock-back
`Dash` writes `move_velocity` every tick and `LongJump` sets its own speed. Launch/knock-back must transition the FSM out (`transition_to(&"Fall")`), never just write velocity. Test it during a dash.

### Pitfall 5: Ground deceleration eats the knock-back
`accelerate_ground` decelerates at `ground_decel`. Pendulum knock-back on the ground needs an upward component so the state becomes `Fall`; or the test shows the player barely moves.

### Pitfall 6: Nozzle fires every tick
An `Area3D` with `body_entered` fires once, but polling `get_overlapping_bodies` every tick re-launches. Use a re-arm (leave volume or ~0.25 s) for jump/cannon modes; updraft/wall are continuous by design (`push_toward`).

### Pitfall 7: Tick order between HandController, Player and CameraRig
`CameraRig` runs at `process_priority = -100` in `_process`; the player and hand run in `_physics_process`. Targeting reads the camera transform in the physics tick: the camera transform is from the last rendered frame, which is the same data the crosshair shows, so it is consistent with what the player sees. Do the targeting update in `_physics_process` (fire decisions) and only presentation (reticle state) in `_process`. At 10 TPS (diagnostic) a fire may use a slightly stale camera; acceptable, covered by existing 10 TPS convention only as a diagnostic. [VERIFIED: camera_rig.gd:182, player_controller.gd:65]

### Pitfall 8: Assist LOS and the ray disagree
Assist says target, the shot ray hits a wall corner. Fire along the assist target's `aim_point` with the same LOS test used for selection; if LOS fails at fire time, fall back to the plain crosshair ray.

### Pitfall 9: Static typing warnings are errors
`untyped_declaration` is a warning-as-error and applies to tools and tests too. Every `for`, lambda parameter and local needs a type. [VERIFIED: project.godot, CONVENTIONS.md]

### Pitfall 10: Godot exits 0 on script errors
The harness greps the log for `SCRIPT ERROR|Parse Error|Failed to load|Failed loading resource`; new scripts that fail to parse show up there, not in the exit code. [VERIFIED: tests/run.sh]

### Pitfall 11: Generated gym vs hand edits
`movement_gym.tscn` is generated by `tools/build_movement_gym.gd`. Re-running the generator overwrites hand edits and the tool output "Re-running reproduces the same file". Build the new rooms in the builder (a new `mechanism_rooms_builder.gd` called from `build()`), not in the editor, or the D-26 door and rooms vanish on regeneration. The generated tscn is already 2,716 lines and will roughly double; that is expected. [VERIFIED: build_movement_gym.gd header]

### Pitfall 12: Group/layer docs must stay in sync
`test_conventions` checks `project.godot` layer names, `PhysicsLayers` and docs/CONVENTIONS.md. Phase 4 needs no new layer (INTERACTABLE exists) but moves the `interactable` group row from "reserved" to used, plus any new group (`carrying_platform`, `mechanism`) in the same commit. [VERIFIED: CONVENTIONS.md lines 60-95, test_conventions.gd exists]

## Code Examples

### Charge/fire timing (HandController sketch)
```gdscript
# Source: pattern derived from PlayerController._tick_timers / _tick_aim (project code)
func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not player.aiming:
		_cancel_charge()
		return
	if Input.is_action_just_pressed(&"use_hand") and _cooldown <= 0.0:
		_charging = true
		_charge_time = 0.0
	if _charging:
		_charge_time += delta
		charge_ratio = clampf(_charge_time / charge_threshold, 0.0, 1.0)
		if Input.is_action_just_released(&"use_hand"):
			var big: bool = _charge_time >= charge_threshold
			_charging = false
			_cooldown = cooldown
			module.on_use_released(big)
```
(Decision for the planner: releasing RMB mid-charge cancels the charge, no shot, since LMB without aim does nothing, D-02.)

### Rig additions
```gdscript
# CameraRig: generic ray, reuses the existing start rule so geometry behind the character never blocks.
func aim_ray(mask: int, length: float) -> Dictionary:
	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z.normalized()
	var query := PhysicsRayQueryParameters3D.create(aim_ray_start(origin, forward, global_position), origin + forward * length, mask)
	return get_world_3d().direct_space_state.intersect_ray(query)

## Multiplies the look sensitivity (sticky aim). 1.0 = off; written by Targeting, eased by the writer.
var look_sensitivity_multiplier: float = 1.0
# in _unhandled_input: var scale: float = base_sensitivity * settings.sensitivity * lerpf(...) * look_sensitivity_multiplier
```
(Mask value uses `PhysicsLayers.WORLD | PhysicsLayers.INTERACTABLE`.)

### Chord carry for a rotating platform
```gdscript
# Source: derived (geometry); correctness under Jolt is verified by the spike, not assumed.
func carry_velocity_at(point: Vector3, delta: float) -> Vector3:
	var pivot: Vector3 = global_position
	var offset: Vector3 = point - pivot
	var rotated: Vector3 = Basis(axis_world, angular_speed * delta) * offset
	return (rotated - offset) / delta
```

### Smoke test skeleton (existing harness)
```gdscript
extends RefCounted
const Fixtures := preload("res://tests/fixtures.gd")
func run(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 10)
	# ... exercise, then check.call(cond, "message")
```
[VERIFIED: tests/fixtures.gd, tests/run_smoke.gd, tests/smoke/test_platforms.gd]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| GodotPhysics platform carry | Jolt default, `sync_to_physics` kinematic bodies report velocity | Godot 4.4-4.6 | Linear carry works (tested here); rotation carry still has reports of drift |
| Folder scan for plugins | explicit registry resource | n/a | Export safe |
| Per-object shader params for pulsing | shared material + one driver | n/a | no instance cost |

**Deprecated/outdated:** nothing relevant; Phantom Camera dropped (D-18 Phase 2), Debug Draw 3D deferred (A39).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Typed `Array[SignalSource]` (custom Node class) exports survive packing/reload | Pattern 6 | Rooms' wiring breaks; fall back to `Array[NodePath]` (low cost) |
| A2 | Under Jolt a rotating AnimatableBody3D drifts the player outward with engine carry and the chord-velocity fix removes it | Pattern 8 | MECH-03 fails for rotators; spike decides, fallback is to make rotators only carry via parenting-free "velocity add" or restrict to slow, centred rotators |
| A3 | Engine `get_platform_velocity()` must be suppressed/subtracted when custom carry is added to avoid doubling | Pattern 8 | Doubled speed on rotators; caught by the spike assertion |
| A4 | Fire-on-release latency for the small pulse (tap) is acceptable | Pattern 3 | Pulse feels laggy; tune tap/charge threshold or accept fire-on-press when no big pulse is needed |
| A5 | MannequinAnimator can take `arm_out` as a second driver of the Aim layer without regressions | Pattern 9 | Animator edit takes longer; fallback is a separate small OneShot like the Phase 5 plan |
| A6 | Meta on the hit collider is enough to map collider -> Interactable | Pattern 2 | None significant |
| A7 | Numbers: assist angle ~3.5 deg, hysteresis x1.6, sticky 0.6, knock-back up component 3-5 m/s, 0.15-0.3 s ease | multiple | Tuning only, exposed in F2 |
| A8 | StandardMaterial3D emission API names (`emission_enabled`, `emission_energy_multiplier`) unchanged in 4.7 | Pattern 5 | trivial; check in class ref when implementing |
| A9 | The gym `WorldEnvironment` glow is on/off (not verified) | Pattern 5 | glow reads weaker; visual only |

## Open Questions

1. **Does near contact work while aiming?** (Claude's discretion.) Recommendation: yes, `interact` is independent of `aim`; near range ~2.2 m from the player; when both a shot target and a near target exist, E always means near.
2. **Which input toggles module in aim?** `module_next/prev` are defined (mouse wheel stays free while aiming per CameraRig comment); with one module the indicator is static. Recommendation: wire the actions but do nothing visible beyond the dummy module in a debug-only test (the dummy proves HAND-01).
3. **"Dash and further jumps stay available" after a nozzle (D-20).** There is no air jump (MOVE-05); read as: air dash and landing jump chain intact. Recommendation: do not reset `air_dash_available` on launch (it is not spent by a launch), leave coyote 0.
4. **Reset/soft-lock policy.** Per-room reset via a `reset()` sweep plus `FallReset` (existing); confirm with the developer whether an in-world reset lever is wanted (out of scope here).
5. **Rotating platform axis variants.** Standing (clock hand) and tilting are the hardest for carry; the spike covers them; if the tilting case fails, restrict tilt to small angles per instance.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Godot 4.7.2 binary | all tests, spikes, builder | not on this machine (`$HOME/Applications/Godot_4.7.2/Godot.app/...` missing; no other Godot found) | expected `4.7.2.stable.official.ed1daf0bf` | none for research; executor machine must provide it (`GODOT` env var or the default path in run.sh) |
| bash, git | run.sh | yes | — | — |
| Network/web docs | research | yes | — | — |

**Missing dependencies with no fallback:** the Godot binary on the planning machine; the executor/developer machine presumably has it (previous phases ran the harness). All Phase 4 claims about engine behaviour that could not be run here are therefore tagged ASSUMED and routed to spike tests.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Project-own headless smoke runner (`attimo/tests/run_smoke.gd`), Godot 4.7.2; each test is `extends RefCounted` with `run(tree, check)` |
| Config file | none (auto-discovers `res://tests/smoke/test_*.gd`); `attimo/tests/run.sh` wraps import + run + log grep |
| Quick run command | `bash attimo/tests/run.sh <filter>` (comma-separated substring filter, e.g. `interactable,targeting,pulse`) |
| Full suite command | `bash attimo/tests/run.sh` (prints `SMOKE SUMMARY` and `RUN.SH: PASSED`) |
| Builder tools | `bash attimo/tests/run.sh --tool res://tools/build_movement_gym.gd` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HAND-01 | Registry lists defs; equipping the dummy module by id needs no HandController change; each def's scene loads | unit/integration | `bash attimo/tests/run.sh hand_module` | Wave 0 (`test_hand_module.gd`) |
| HAND-02 | `can_accept(kind,size)` truth table; modules call only the contract (stub Interactable receives `triggered` with a PulseHit carrying size/point/direction/collider) | unit | `bash attimo/tests/run.sh interactable` | Wave 0 |
| HAND-03 | Tap < 0.4 s -> small, hold >= 0.4 -> big, no fire without aim, cooldown 0.25 s, range 15/25 m measured from the player, shot at nothing still emits `pulse_fired`, wall occludes a lever | integration (simulated `Input.action_press/release`) | `bash attimo/tests/run.sh pulse` | Wave 0 |
| CAM-04 | Idle/aim/target stage materials: interactables use only the three shared resources; no unshared material instance count growth; non-interactables never reference them | unit/scan | `bash attimo/tests/run.sh glow` | Wave 0 |
| CAM-05 | Assist: target inside cone selected; outside cone not; hysteresis (target held at 1.3x angle, no ping-pong between two close candidates over N ticks); invalid (needs big, small pulse) never snaps/valid=false; `look_sensitivity_multiplier` < 1 on target, camera yaw/pitch unchanged by assist | integration | `bash attimo/tests/run.sh aim_assist` | Wave 0 |
| MECH-01 | Every trigger and mechanism scene instantiates, has a contract-satisfying API, toggles per D-15/D-17, crank wind ratio, energy core timeout, gate rolls 0.3 s and does not close with the player overlapping | unit/integration | `bash attimo/tests/run.sh mechanism` | Wave 0 |
| MECH-02 | AND/OR/timer truth tables; chained logic; state applied at load; packed-and-reloaded scene keeps the exported source refs (settles A1) | unit + packed-scene round trip | `bash attimo/tests/run.sh logic` | Wave 0 |
| MECH-03 | Linear lift, conveyor (existing), rotating platform carry with radial drift < 0.05 m at 60 and 10 TPS (standing axis, lying axis, tilt), no launch on start/stop (peak player speed bounded), `launch_along` height repeatability, sideways momentum kept, knock-back during Dash leaves Dash | integration | `bash attimo/tests/run.sh platform_carry,player_launch` (extend `test_platforms.gd` or new `test_mechanism_carry.gd`) | Wave 0 |
| Rooms (D-26..D-29) | Gym still builds; door exists; every trigger/mechanism type appears in the showcase; each puzzle room's source graph resolves (all exported refs non-null) and every mechanism type is covered by the union of rooms; a scripted solve of at least one pulse puzzle | integration | `bash attimo/tests/run.sh movement_gym,mechanism_rooms` | extend `test_movement_gym.gd` + Wave 0 |
| Conventions | docs/CONVENTIONS.md groups/layers in sync | existing | `bash attimo/tests/run.sh conventions` | exists |
| HUD | reticle states, charge arc, mouse_filter IGNORE, layer < 100, hidden when not aiming | unit | `bash attimo/tests/run.sh crosshair` (extend) | exists; extend |
| Feel (not automatable) | tap latency, glow readability over turquoise, assist feel, nozzle feel, carry smoothness while running on rotators | manual-only (human-verify at end of phase, config `human_verify_mode: end-of-phase`) | — | — |

### Sampling Rate
- **Per task commit:** `bash attimo/tests/run.sh <relevant filters>`
- **Per wave merge:** `bash attimo/tests/run.sh` (full)
- **Phase gate:** full suite green before `/gsd:verify-work`, plus a short manual play of the showcase and puzzle rooms.

### Wave 0 Gaps
- [ ] `tests/smoke/test_hand_module.gd`, `test_interactable.gd`, `test_pulse.gd`, `test_aim_assist.gd`, `test_glow_stages.gd`
- [ ] `tests/smoke/test_logic_nodes.gd` (includes the packed-scene export round trip, A1)
- [ ] `tests/smoke/test_mechanisms.gd`, `test_mechanism_carry.gd` (rotation spike, A2/A3), `test_player_launch.gd`
- [ ] `tests/smoke/test_mechanism_rooms.gd`
- [ ] Fixtures: helpers `spawn_interactable(...)`, `hold_action(tree, action, seconds)` in `tests/fixtures.gd`
- [ ] Framework install: none (existing runner)

## Security Domain

`security_enforcement` is enabled (ASVS level 1). This is an offline single-player game prototype with no network, accounts or untrusted input beyond local files.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | minimal | exported ranges (`@export_range`), clamp tunables from the F2 panel; module registry only loads project `res://` resources |
| V6 Cryptography | no | — |
| V12 Files/Resources | minimal | no user-supplied `.tres`/scene loading; the F2 panel never writes res:// (existing T-02-16 rule); do not persist hand tunables to `user://settings.cfg` (mirrors T-03-07) |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Loading arbitrary resources from user:// as modules | Tampering | registry is a `res://` resource; no dynamic path loading |
| Debug/tuning panel active in release | Elevation | existing: tuning panel is debug-only (REL-03); new tunables go through it only |
| Division by zero / non-finite values (delta, vectors) in carry and launch math | DoS (crash/NaN physics) | guard `delta > 0`, `is_finite()` checks on launch/carry results (the rig already checks `is_finite` for the aim point) |

## Sources

### Primary (HIGH confidence, read in this session)
- `attimo/scripts/player/player_controller.gd`, `states/*.gd`, `core/state_machine.gd`, `camera/camera_rig.gd`, `ui/crosshair.gd`, `gym/moving_platform.gd`, `core/physics_layers.gd`, `autoload/event_bus.gd`, `debug/tuning_panel.gd`, `tools/build_movement_gym.gd`, `tools/movement_gym_builder.gd`
- `attimo/tests/run.sh`, `run_smoke.gd`, `fixtures.gd`, `smoke/test_platforms.gd`, `smoke/test_crosshair.gd`
- `docs/CONVENTIONS.md`, `attimo/project.godot`, `.planning/research/ARCHITECTURE.md` (Patterns 4, 5, 6), `.planning/research/PITFALLS.md`, `.planning/phases/04-.../04-CONTEXT.md`, `.claude/CLAUDE.md`

### Secondary (MEDIUM-LOW confidence)
- Godot forum, rotating CharacterBody3D platform drift on 4.6 with Jolt: https://forum.godotengine.org/t/rotating-characterbody3d-on-rotating-platform-how/136346
- Godot forum, stability on rotating and moving platforms: https://forum.godotengine.org/t/how-to-make-characterbody3d-stay-stable-on-rotating-and-moving-platforms/86573
- Godot forum, platform velocity setup (`platform_floor_layers`, `platform_on_leave`): https://forum.godotengine.org/t/not-inhereting-platform-velocity/37759

### Tertiary
- Training knowledge for StandardMaterial3D emission properties, typed Node-array exports (tagged ASSUMED). Context7/ctx7 was not used (no engine-API doubt was resolvable without a running engine; the key engine-behaviour claims are routed to executable spikes instead).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH (no new dependencies; everything in the repo)
- Architecture (framework, contract, targeting, signals): MEDIUM-HIGH (follows the project's own ARCHITECTURE.md; code seams verified)
- Moving platforms / rotation carry: LOW-MEDIUM (forum-reported pitfall, solution untested, spike prescribed)
- Pitfalls: MEDIUM-HIGH (most derived from reading the actual FSM/controller code)

**Research date:** 2026-11-21
**Valid until:** 30 days (stable engine pin 4.7.2)

## Project Constraints (from CLAUDE.md)

- Godot 4.7.2-stable (standard, not .NET), GDScript typed everywhere (`untyped_declaration` is an error), Jolt physics, Forward+; physics interpolation on; camera in `_process` on the top-level `CameraRig`, physics in `_physics_process`.
- Own `CharacterBody3D` controller; the movement FSM is the source of truth and the hand must not take over movement state; one `move_and_slide` per tick.
- Group A rule: greybox from Prototype Bits, no particles and no juice VFX in this phase; feedback that carries information (glow, reticle, streak, palm glow) is allowed.
- Input actions only via the Input Map (`aim`, `use_hand`, `interact`, `module_next/prev` already exist); no hard-coded keys.
- Hand module system: the arm mesh never changes; modules are pure ability components (PROJECT.md).
- Raw KayKit packs stay at repo root; only used assets are copied into `attimo/assets/` (copy Door_A/B, Pillar etc. only when used; run.sh repo checks require originals stay tracked).
- Git: all work on `dev`; the user writes German, answers German, planning docs English. GSD workflow: work enters through GSD commands.
- D-30: 3-5 plans for this phase, grouped by area.
