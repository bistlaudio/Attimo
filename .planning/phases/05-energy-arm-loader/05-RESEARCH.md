# Phase 5: Energy Arm & Loader - Research

**Researched:** 2026-11-24
**Domain:** Godot 4.7.2 GDScript third-person platformer: slow-motion hold state, single-owner energy resource, projectile shot, hand-module framework, aim-mode removal, HUD, headless smoke tests
**Confidence:** HIGH for engine behaviour and existing-code facts (read from source this session), MEDIUM for feel numbers and UI/VFX techniques (starting values for the F2 panel, not verified by play)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Loader rules and feel (HAND-04, highest risk: prototype first)**
- **D-01 Ground use:** pressing the Loader on the ground brakes Rino hard (a short skid of about 0.1 s), then Rino stands still while the momentum is stored. The discharge may point anywhere in the view direction, including up (a super jump out of a run). In the air Rino hangs as in GAME-DESIGN.md section 4.
- **D-02 Once per air phase:** one Loader use per airborne stretch, refilled on landing (like the air dash). Boosters and the slingshot core may refill it (planner decides which, consistent with how they refill the air dash). The empty-arm redirect cooldown therefore matters mainly on the ground.
- **D-03 Independent from the air dash:** a Loader discharge neither refills nor spends the air dash; whatever state the air dash was in stays. After the release, air control is locked for about 0.15 s (same idea as `Capture.EXIT_CONTROL_LOCK`), then normal air control returns.
- **D-04 Feel property = "geladen" (a loaded spring).** Every cue points at it (Swink): while holding, tension builds (charge ring fills, a rising hum placeholder, the camera pulls back very slightly); the release is sharp, with a short hitstop. No clashing effects (no heavy camera shake, no "weighty cannon" cues). This answers the open lecture homework item "feel property".
- Carried from GAME-DESIGN.md section 4 (not re-asked): about 0.25x slow motion, hold capped at about 1.2 s real time then auto-discharge, free camera, discharge at `max(stored speed, minimum push) + bonus` capped; bonus costs 25 (one core); empty arm = redirect only with cooldown and a grey ring; desaturation plus turquoise vignette while holding; dashed trajectory preview.

**Energy income (ENRG-02)**
- **D-05 Passive charge from about 10 m/s** (just above run speed 8.5 and Moto Perpetuo run ~9.5). Plain running never charges; every technique does (dash, dash hop, boosters, Loader discharge). The rate scales with speed, about +3/s at 10 m/s up to about +6/s at about 18 m/s. Tunable on F2. Note: this deliberately lowers the design-doc threshold of ~12 m/s, so that a normal dash (exit 12 m/s) charges clearly.
- **D-06 Charge button:** a new input action `charge` on **R**. Works only while standing still and held; moving, jumping or dashing cancels it. About +5/s, emergency fallback only.
- **D-07 Capsules and broken machines are drained with left click (hold) through the Extractor module** (D-11), not with E. Capsule about +40 over about 0.5 s; broken machine larger and slower (start: about +60 over about 2 s). Afterwards dark and empty.
- **D-08 Refill:** each source has a `respawn_time` parameter (0 = never). The gym uses a timed respawn for fast testing; the level (Phase 7) uses 0.

**Making energy visible (ENRG-01, ENRG-05)**
- **D-09 On the arm:** four greybox cores (small glowing prisms) on the Mannequin forearm via `BoneAttachment3D` (same approach as `HandPresentation`). Full core = bright, partially filled = dimmed by fill, empty = dark. The real arm comes with the Rino model later.
- **D-10 Moto Perpetuo look:** the arm glows brighter, **both feet glow** and **a point on the back glows**, all as greybox glow points on bone attachments. Entering and leaving gets a short flash or fade (a sound placeholder is fine). No screen effect, so it never clashes with the Loader vignette.
- **D-12 Spend and lack feedback:** the core that is spent flashes briefly, then dims. A refused action (air dash with empty arm, shot under 10) makes the arm flicker grey, plus the existing `dash_blocked` style feedback. Falling back to a base version (dash hop stage 2 -> stage 1, wall run ending after the free window) gets **no** failure signal ("no failed moment" rule).
- **D-13 Energy HUD now (ENRG-05 moves from Phase 6 to Phase 5), top left:** 4 core chambers with partial fill, the Moto Perpetuo state, the active hand module (Extractor / shot), and a **momentum readout** (current speed, e.g. a gauge arc with marks at the passive-charge threshold and other useful speeds). Health is added next to it in Phase 6; the layout leaves room. Style follows the current reticle tuning (steel rim and plate, turquoise energy). Reversibility: reversible, HUD layout only; the planner updates REQUIREMENTS.md and ROADMAP.md for the ENRG-05 move.
- **D-14 Two charge rings at the crosshair, told apart at a glance:** the Loader hold shows a ring at the crosshair that turns and fills, like the shot charge ring, but visibly different (for example the shot is a notched ring turning clockwise, the Loader a double ring filled by momentum turning the other way). Exact look is Claude's discretion as long as the two never read the same.

**Aim mode removed, what left click does (ENRG-04)**
- **D-15 Aim mode is removed:** goggle HUD, zoom/FOV, shoulder offset, aim pose layer, aim strafe facing, and pull/push leftovers go. The small crosshair stays always visible.
- **D-16 Mouse wheel (and 1/2) switches between two hand modules:** Extractor (D-11) and the shot (the Fernausloeser, D-17). Both fire from the hip at the always-visible crosshair; no aim button is needed any more.
- **D-11 Extractor module now, capsules and machines only:** a real hand module (one folder + one registry entry, Phase 4 framework), left-click hold, a cone in front of the hand that drains energy sources. Phase 6 adds enemies and shards to the same module; the code is kept, not thrown away.
- **D-17 The shot is a flying projectile, never a beam** (user: "kein Strahl, Schuss wie Mega Man oder Samus"). This replaces Phase 4 D-04 (instant raycast hit with a cosmetic streak). Charge model = **hybrid**: tap fires a small shot for **10**; holding drains energy continuously while the projectile grows, up to a total of **25** in about 0.8 s, with one clearly readable **full-charge** tell (flash plus sound, Samus style). Releasing earlier fires a proportional shot. If energy runs out while charging, the charge stops at that level. More charge = more range and enough force for heavy mechanisms now, and more damage from Phase 6 (the hit payload carries the energy spent). Reversibility: costly, `PulseHit`, the pulse size contract of `Interactable` (small/big, Phase 4 D-03/D-09), targeting and the gym puzzles all change with it.
- **D-18 Shot under 10 energy does not fire:** grey arm flicker (D-12). Near contact with E stays free, so levers and the crank stay solvable. Every gym puzzle room that needs a shot gets an energy capsule with respawn next to it.
- **D-19 Aim assist:** snap and hysteresis stay and become **stronger and noticeable**: a valid target near the crosshair locks (ring turquoise) and the projectile clearly bends to it, so targets can be hit while moving fast. The mouse slowdown ("sticky aim") is removed.

**Movement gym rework (ROADMAP criterion 6, gym rule)**
- **D-20 Remove:** aim-mode stations and pull/push leftovers; signs and "Erwartet:" lines that mention aiming are rewritten for hip fire.
- **D-21 Loader test room** (built first, with the Loader prototype): open space to freeze and redirect on the ground and in the air, gaps and heights that need a Loader discharge with bonus vs. a plain redirect, measured against the FEEL-10 metrics.
- **D-22 Energy area:** a charge track (long straight plus booster/dash-hop line to see passive charge above ~10 m/s), energy capsules and one broken machine with timed respawn (Extractor station), a charge-button spot, and one station per injected move (air dash, dash hop stages 2-3, wall run past the free window) showing the base version with an empty arm and the injected version with energy.
- **D-23 Shot stations:** tap vs. full charge (range and heavy mechanism), plus a target to hit while moving fast (stronger snap, D-19).
- **D-24 Existing puzzle rooms stay solvable without aim:** every station or puzzle that needs a shot gets a capsule with respawn next to it (D-18); mechanisms that needed the big pulse accept the charged shot.
- **D-25 Readout:** the energy HUD (D-13) is the readout for all stations; the F2 panel holds the energy and Loader tunables.
- All gym content stays builder-generated (`attimo/tools/mechanism_rooms_builder.gd` and the gym builders), never hand-edited; every new station gets a smoke test and an "Erwartet:" sign.

**Carried forward (not re-asked)**
- Energy numbers and the governing rule from GAME-DESIGN.md sections 2-3: air dash 10 (does not fire when empty), dash hop stages 2/3 cost 15 each (stage 1 free), wall run free for about 0.6 s then 15/s, jumping off always free, respawn with exactly 25, Moto Perpetuo +10-15 % run speed and buffed Jump 3.
- Phase 4 D-30 / memory: stay in the GSD band, 3-5 plans.
- Gym rule: the phase ends with the movement gym reworked (ROADMAP criterion 6).

### Claude's Discretion
- How the Loader is built (extend the existing `Capture` state or a new `Loader` state sharing code with it; GAME-DESIGN.md 6.8 says catch & launch "shares code with the Loader").
- Loader minimum push, bonus, cap, cooldown, the empty-arm redirect cooldown length, camera pull-back amount, hitstop length; all F2 tunables recorded in the FEEL-10 metrics table.
- Slow motion technique (`Engine.time_scale` vs. local time scaling) as long as input, camera and the 1.2 s cap run in real time.
- Whether the Loader can be cancelled while holding, and what damage/obstacles do during the hold.
- Extractor cone size and range, whether Rino may move while extracting, machine amounts.
- Exact momentum gauge marks, HUD sizes and colours, glow point sizes.
- Projectile speed, size curve and bend strength; assist angle and hysteresis.

### Deferred Ideas (OUT OF SCOPE)
- **Target look as gear discs** (plate-like, gear-shaped, turquoise core) - Phase 05.1 Kit Rework, where targets replace levers. The stronger snap (D-19) is built now.
- **Health next to the energy HUD** - Phase 6.
- **Shot damage on enemies, shards, Extractor on enemies** - Phase 6 (payload already carries the energy spent).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HAND-04 | Right-click Loader: hold freezes and stores momentum in slow motion with a free camera, charge ring and trajectory preview; release discharges in the view direction (bonus costs one core, empty arm only redirects). Replaces aim mode and Pull/Push | `Engine.time_scale` keeps real 60 Hz physics cadence with scaled delta (verified in engine source); new `Loader` FSM state + `TimeFx` single time owner; `LoaderMath` pure functions for discharge speed and the ballistic preview; CameraRig real-time delta fix; MultiMesh dashed preview |
| FEEL-10 | Loader metrics table (minimum push, bonus, cap, hold time, slow-motion factor, energy rates) documented and tuned | New `MovementConfig` groups are auto-enforced by `test_movement_metrics` snapshot; extend `tools/movement_metrics.gd` with Loader rows; starting values table below |
| ENRG-01 | Arm stores 0-100 energy in 4 cores of 25, readable on the arm; Moto Perpetuo from 50; respawn with one core | `ArmEnergy` component (single owner), `respawn()` on PlayerController, arm-core BoneAttachment3D prisms (pattern in `hand_presentation.gd`), Moto buffs hook points listed |
| ENRG-02 | Income without enemies: passive charge above ~10 m/s, capsules and broken machines, slow charge button | `ArmEnergy._physics_process` passive curve, new `charge` action, `EnergySource` node + Extractor cone drain |
| ENRG-03 | Base moves free, injected versions cost energy; base version fires automatically, air dash does not | Exact integration points: `can_dash`/`start_dash`, `advance_long_jump_stage`, `WallRun` free window; reuse of `dash_blocked` reason `&"energy"` |
| ENRG-04 | Aim mode removed (goggle HUD, zoom, shoulder offset, aim pose, pull/push); crosshair and target aim assist stay | Complete aim dependency inventory with files and lines, hidden dependencies (`AimPoseModifier.rotation_between` used by a tool, wheel zoom vs module switch) |
| ENRG-05 | Energy HUD top left (core chambers, Moto state, active module, momentum readout) | Control `_draw` HUD in a new CanvasLayer, polled from `ArmEnergy`, real-time delta, layer ordering |
</phase_requirements>

## Summary

The phase is large but well-bounded by existing seams. The riskiest piece, slow motion, is fully resolved by reading the engine source: in Godot 4.7.2 `Engine.time_scale` does **not** slow the physics tick rate. Physics still ticks `physics_ticks_per_second` times per real second, but `_physics_process(delta)`, the physics server step and `move_and_slide` receive `delta * time_scale`. `_process(delta)` is scaled the same way. That means: input is still polled every 16.7 ms real, physics interpolation keeps working, the hold cap must be counted with an *unscaled* delta (`delta / Engine.time_scale`), and everything that must run in real time (CameraRig, HUD rings, hitstop restore) has to un-scale its delta explicitly. This closes the open question left in `.planning/research/GAME-FEEL.md` section 6.3.

The existing code is a good base. The movement FSM is the source of truth and mechanisms only talk to `PlayerController` request APIs; the energy checks slot into exactly five existing choke points (`can_dash`/`start_dash`, `advance_long_jump_stage`, `WallRun.physics_update`, `ground_target_speed`, `Jump.enter`). The existing `dash_blocked(position, reason)` fact and `dash_locked_reason()` lockout infrastructure can be re-purposed from reason `&"aim"` to `&"energy"` instead of being thrown away. `Capture` is the closest model for the Loader but must not be copied blindly: its `_release` calls `refill_air_dash()`, which D-03 forbids for the Loader.

The expensive part is not the Loader, it is the **aim-mode removal and the shot rework**: about 45 files mention aim, six smoke tests are aim-specific, six more have aim scenarios, `AimPoseModifier` has a hidden user (`tools/clip_retargeter.gd`), the mouse wheel is bound twice (camera zoom and module switch), `Interactable`/`Targeting` glow stages are tied to `aim_changed`, and the generated artefacts (`mannequin_tree.tres`, `movement_gym.tscn`, `MOVEMENT-METRICS.md`) can only be regenerated with a Godot binary that is **not installed on this machine**. Plans must separate "edit sources" from "regenerate and run" and mark the second as needing the user's engine.

**Primary recommendation:** Build the Loader first as a new `Loader` FSM state (not an extension of `Capture`), with `TimeFx` (autoload, sole writer of `Engine.time_scale`), `LoaderMath` (pure static functions, headless-testable) and a real-time CameraRig; put all new tunables into new `MovementConfig` groups (Energy, Moto Perpetuo, Loader) so the F2 panel and the `test_movement_metrics` snapshot enforce FEEL-10 for free; keep `PulseHit.Size` as a classification *derived from* a new `energy` payload so the 12 test files and the valve/crank scenes keep their small/big contract; remove aim mode in the same first plan because RMB cannot serve both.

## Project Constraints (from CLAUDE.md)

- Godot **4.7.2-stable** standard build, GDScript only, **typed everywhere** (`debug/gdscript/warnings/untyped_declaration=2` makes any untyped declaration a parse error, including `tools/` and `tests/`). [VERIFIED: attimo/project.godot `[debug]` `gdscript/warnings/untyped_declaration=2`]
- Jolt Physics, Forward+, physics interpolation on. [VERIFIED: attimo/project.godot `3d/physics_engine="Jolt Physics"`, `common/physics_interpolation=true`]
- Own `CharacterBody3D` controller and hand-rolled node FSM, hand-built `CameraRig` (D-18). No addons adopted (Debug Draw 3D deferred, gdUnit4 optional). Do not add addons for this phase.
- Input Map actions from day one, keyboard+mouse first, no gamepad events bound (test_input_map enforces).
- Low-poly/greybox: Group A uses only Prototype Bits and primitives; no particles, no juice in the gym (test_movement_gym enforces "no particle node").
- All phase work on the `dev` branch; after verification merge into `main`. Planning docs in English, user communication in German.
- Project skill `attimo-design-principles`: research first, lecture principles second lens, answer the LECTURE-PRINCIPLES section 1 checklist, respect section 3 kit guardrails (signals carry values, runtime state not in shared `.tres`, interface plus contract test), update `docs/GAME-DESIGN.md` + `docs/game-design.html` + `docs/attimo-presentation.html` at phase end if the design changed.
- GSD workflow enforcement: all edits go through a GSD command.

## Architectural Responsibility Map

The "tiers" of this project are not web tiers; they are the Godot execution domains.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Energy value, spend/gain rules, Moto threshold | Simulation (physics tick, `ArmEnergy` node under Player) | Config (`MovementConfig`) | Gameplay truth; checked inside FSM states on the physics tick so results are deterministic and testable |
| Loader hold/discharge | Simulation (new `Loader` state in the FSM) | `TimeFx` autoload (time scale) | FSM is the source of truth; states own `move_velocity`/`vertical_speed` |
| Slow motion | Engine (`Engine.time_scale` via one autoload) | Presentation (real-time exceptions) | One writer, restore on exit; consumers un-scale their own delta |
| Trajectory preview, rings, vignette | Presentation (`_process`, MultiMesh, CanvasLayer) | Simulation (`LoaderMath`) | Visual only; shares one pure function with the real discharge so preview == result |
| Shot projectile | Simulation (own Node3D stepped in `_physics_process`, swept ray) | Presentation (mesh scale/flash) | Hits must be deterministic and go through `Interactable.try_trigger` |
| Extractor drain | Simulation (cone query over group `energy_source`) | Presentation (palm glow) | Energy changes are gameplay facts |
| Energy HUD (cores, Moto, module, speed gauge) | UI (CanvasLayer + Control `_draw`) | Simulation (polled read-only) | Same pattern as `Crosshair` (polls `hand_controller` group, never drives) |
| Arm cores, Moto glow points | Presentation (BoneAttachment3D prisms) | EventBus facts | Same pattern as `HandPresentation` |
| Aim assist and target lock | Simulation (`Targeting`, physics tick) | UI (reticle colour) | Existing; becomes always-on, loses sticky slowdown |
| Gym stations, Loader room | Tools (builder scripts generate the `.tscn`) | Tests (one smoke test per station) | Gym is generated and never hand-edited |
| Metrics doc (FEEL-10) | Tools (`measure_movement.gd`) | Tests (`test_movement_metrics` snapshot) | Generated from the real Player headless |

## Standard Stack

### Core (all built into Godot 4.7.2; no new packages)

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| `Engine.time_scale` | 4.7.2 | World slow motion during the Loader hold | The only engine-wide time lever; physics cadence stays real-time, delta is scaled [VERIFIED: godotengine/godot 4.7.2-stable main/main.cpp:5001 `physics_process(physics_step * time_scale)`] |
| `CharacterBody3D` + FSM state | existing | Loader hold/discharge as a state | Project convention: FSM owns velocity |
| `Resource` (`MovementConfig` groups) | existing | All tunables, F2 rows auto-generated | `tuning_panel.gd` builds one slider per float with range hint |
| `Node` component (`ArmEnergy`) | new | Single energy owner | Matches `HandController`/`HandPresentation` composition under Player |
| `MultiMeshInstance3D` | 4.7.2 | Dashed trajectory preview (fixed instance count, width controllable) | Standard instancing; avoids 1 px `PRIMITIVE_LINES` and a custom ribbon shader [ASSUMED: technique choice] |
| `Control._draw` + `draw_arc` | 4.7.2 | HUD, charge rings | Already how `crosshair.gd` draws its reticle |
| `BoneAttachment3D` | 4.7.2 | Arm cores, feet/back glow points | Already used in `hand_presentation.gd` |
| `Environment.adjustment_saturation` | 4.7.2 | World desaturation while holding | Property exists [VERIFIED: godotengine/godot 4.7.2-stable scene/resources/environment.cpp:1064 `set_adjustment_saturation`] |
| `PhysicsDirectSpaceState3D.intersect_ray` | 4.7.2 | Swept hit test of the projectile and preview truncation | Same call the module already uses |

### Supporting

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `SceneTree.create_timer(t, true, false, true)` | Real-time timer (4th arg `ignore_time_scale`) | Hitstop restore, UI timeouts during slow motion [VERIFIED: scene_tree.cpp:1768 `create_timer(double p_delay_sec, bool p_process_always, bool p_process_in_physics, bool p_ignore_time_scale)`] |
| `Tween.set_ignore_time_scale(true)` | HUD/vignette tweens that must not slow down | HUD flashes during the hold [VERIFIED: tween.cpp:264 `Tween::set_ignore_time_scale`] |
| `Timer.ignore_time_scale` | Node timers that ignore scale | If a Timer node is used [VERIFIED: timer.cpp:54-58] |
| `AudioServer.playback_speed_scale` | Pitch/speed of audio under slow motion | Only when audio lands (Phase 14); `Engine.time_scale` does not touch audio [CITED: Engine.xml time_scale doc, 4.7.2] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Global `Engine.time_scale` | Per-node local time (scale only the player's delta) | Nothing else would slow (platforms, mechanisms, projectiles); the design says "slow motion" of the world; `Engine.time_scale` is also what the lecture/GAME-FEEL research assumes. Use global scale plus explicit un-scaling for the few real-time consumers |
| `TimeFx` autoload | `SlowMotion` component on the player | A component dies with the player (test teardown, respawn) and can leak the scale; GAME-FEEL rule 8 says exactly one writer. Autoload is ~30 lines. See Assumption A2 |
| Extend `Capture` | New `Loader` state + shared helper | `Capture` is path-driven (points, hold at last point, exit velocity from the mechanism) and calls `refill_air_dash()` on release (violates D-03). A separate state with shared pure helpers is cleaner; the slingshot can adopt the helper in Phase 05.1 |
| `RigidBody3D` projectile | Custom `Node3D` + swept ray | Rigid bodies tunnel at 40 m/s, need layer setup and fight the Interactable contract; a stepped node with `intersect_ray(prev, next)` is deterministic |
| Separate `EnergyConfig`/`LoaderConfig` resources | New `MovementConfig` groups | A sibling resource needs new panel code and a second snapshot test; MovementConfig groups are auto-listed in F2 and `test_movement_metrics` fails until the metrics doc is regenerated (a useful FEEL-10 guard) |

**Installation:** none. No packages, no addons. Engine pin stays 4.7.2.

**Version verification:** engine behaviour was verified against the `4.7.2-stable` tag sources (not only master). The pinned version string is `4.7.2.stable.official.ed1daf0bf` [VERIFIED: attimo/tests/run.sh `EXPECTED_VERSION`].

## Package Legitimacy Audit

No external packages are installed by this phase (built-in engine features only; the optional addons Debug Draw 3D and gdUnit4 from CLAUDE.md stay un-adopted). Nothing to run through `package-legitimacy`.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| none | - | - | - | - | - | - |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
 INPUT (RMB loader, LMB use_hand, R charge, wheel/1/2 module, Shift dash, Space jump)
   |
   v
 PlayerController._physics_process(delta)            delta = (1/60) * Engine.time_scale
   |-- _tick_timers -> (new) ArmEnergy tick (passive charge from horizontal_speed(), charge button, Moto flag)
   |-- StateMachine.physics_update
   |      Idle/Run/Jump/Fall/LongJump/WallJump  --press loader (once per air phase)-->  LOADER
   |      Dash (air: can_dash asks ArmEnergy 10) / LongJump (stage>=2 asks 15) / WallRun (after free 0.6 s drains 15/s)
   |      LOADER: enter -> store velocity, TimeFx.request(&"loader", 0.25), gravity_scale 0 (air) or skid (ground)
   |              hold (unscaled clock <= 1.2 s) -> release or cap -> LoaderMath.discharge -> Fall
   |              exit() ALWAYS TimeFx.release(&"loader"), gravity_scale = 1
   |-- _integrate (one move_and_slide)
   v
 EventBus facts (values only): energy_changed, energy_spent, energy_gained, energy_refused, moto_changed,
                               loader_started, loader_released, dash_blocked(reason &"energy")
   |
   +--> HandPresentation / ArmEnergyPresentation (BoneAttachment3D prisms, flicker, Moto glow)  [_process, real delta]
   +--> EnergyHud (CanvasLayer, Control _draw; polls ArmEnergy + player speed)                  [_process, real delta]
   +--> Crosshair (ring: shot = notched CW, loader = double CCW) + LoaderPreview (MultiMesh)    [_process, real delta]
   +--> CameraRig (_process, real delta; additive source &"loader": pull-back)  ---> mouse look stays event driven

 HandController (_physics_process, always on, no aim gate)
   |-- Targeting (always on; snap + hysteresis; no sticky)
   |-- module: remote_trigger (shot) --> ShotProjectile (swept ray, bend toward locked target) --> Interactable.try_trigger(PulseHit{energy})
   |-- module: extractor  --cone over group energy_source--> EnergySource.extract(delta) --> ArmEnergy.gain
   v
 TimeFx (autoload): sole writer of Engine.time_scale; lowest request wins; _exit_tree restores 1.0
```

### Recommended Project Structure

```
attimo/
  autoload/time_fx.gd                       # NEW sole writer of Engine.time_scale (autoload name TimeFx; no class_name)
  scripts/player/arm_energy.gd              # NEW class ArmEnergy (component under Player)
  scripts/player/loader_math.gd             # NEW class LoaderMath (static pure functions)
  scripts/player/states/loader.gd           # NEW FSM state
  scripts/player/arm_energy_presentation.gd # NEW cores, Moto glow points, flicker (BoneAttachment3D)
  scripts/hand/modules/extractor/           # NEW extractor.gd + .tscn + _def.tres (+ one registry line)
  scripts/hand/shot_projectile.gd           # NEW class ShotProjectile (+ scenes/hand/shot_projectile.tscn)
  scripts/mechanisms/energy_source.gd       # NEW energy source block (group energy_source + mechanism)
  scenes/mechanisms/energy_capsule.tscn     # NEW (must live under scenes/mechanisms/: gym sanction prefix)
  scenes/mechanisms/broken_machine.tscn     # NEW
  scripts/ui/energy_hud.gd + scenes/ui/energy_hud.tscn   # NEW CanvasLayer HUD
  scripts/ui/loader_vignette.gdshader       # NEW (replaces goggle_lens.gdshader, no screen-texture read)
  tools/energy_area_builder.gd              # NEW worker (pattern of puzzle_rooms_builder.build_into(zone, builder))
  tests/smoke/test_*.gd                     # see Validation Architecture
```

### Pattern 1: Energy as one owner with spend/gain APIs (checklist item 12)

**What:** `ArmEnergy` is the only code that writes `value`. States and modules call `can_afford`, `try_spend`, `drain`, `gain`; it emits EventBus facts that carry numbers, never node references.
**When to use:** every cost (air dash 10, hop 15, wall run 15/s, Loader bonus 25, shot 10..25) and every income.
**Interface (recommended):**
```gdscript
class_name ArmEnergy
extends Node
const CORE_SIZE: float = 25.0
const MAX_ENERGY: float = 100.0
var value: float = 25.0                       # start and respawn value (one core)
func can_afford(amount: float) -> bool: ...
func try_spend(amount: float, reason: StringName) -> bool: ...   # all-or-nothing, emits energy_spent or energy_refused
func drain(amount: float, reason: StringName) -> float: ...      # partial (wall run per tick, shot charge), returns what was taken
func gain(amount: float, source: StringName) -> float: ...       # clamps to 100, returns what was added
func reset_to_checkpoint() -> void: ...                          # value = 25.0
func core_fill(index: int) -> float: ...                         # 0..1 for core 0..3
func is_moto() -> bool: ...                                      # with hysteresis, see Pitfall 11
```
**EventBus facts to add (values only):** `energy_changed(value: float)`, `energy_spent(amount: float, reason: StringName)`, `energy_gained(amount: float, source: StringName)`, `energy_refused(reason: StringName, needed: float)`, `moto_changed(active: bool)`, `loader_started(position: Vector3, stored_speed: float, in_air: bool)`, `loader_released(position: Vector3, direction: Vector3, speed: float, bonus: bool)`. Passive charge changes `value` every tick: emit `energy_changed` only when the integer part changes (or on any discrete gain/spend); the HUD polls `value` for smooth fill (same polling pattern as `crosshair.gd`). `EventLog` auto-connects to every EventBus signal, so six 60 Hz emits would flood it.

### Pattern 2: Loader as a state with one-place cleanup

**What:** `Loader` extends `State`. `enter` stores velocity and calls `TimeFx.request`; `exit` always calls `TimeFx.release` and restores `gravity_scale`. Every exit path (release, cap, `teleport()` -> `_enter_fall()`, damage later) goes through `exit()`, which `StateMachine.transition_to` guarantees. [VERIFIED: attimo/scripts/core/state_machine.gd `transition_to` calls `current.exit()` before `current = _states[next]`]
**Integration points (verified in `player_controller.gd`):** the press check must exist in `GroundState.physics_update`, `AirState.physics_update` (and optionally `WallRun`), modelled on `dash_press_starts_dash()`; availability flag `loader_available` beside `air_dash_available`, refilled in `_land()` and inside `refill_air_dash()` (covers boost ring and the slingshot's `Capture._release`, D-02) but the Loader itself must never call `refill_air_dash()` (D-03).

### Pattern 3: Pure helper shared by preview and release (checklist items 4, 12)

`LoaderMath` (static, `RefCounted`, no node access) holds `discharge_speed(stored, min_push, bonus, cap)`, `step_ballistic(position, velocity, config, dt)` (identical to `PlayerController._integrate`: gravity chosen once per tick, `rise_gravity` while `vertical_speed >= 0`, `fall_gravity()` below, half-step gravity around the move, terminal clamp) and `trajectory(...)`. The preview calls it every frame; the release uses the same `discharge_speed`; a test compares the preview landing point with a real flight (no input). This is also the code the slingshot can adopt later (GAME-DESIGN 6.8 "shares code with the Loader").

### Pattern 4: Real-time exceptions

`delta` in `_process` and `_physics_process` is `step * time_scale`. A one-line helper `TimeFx.unscaled(delta)` = `delta / maxf(Engine.time_scale, 0.01)` is used by: the Loader hold clock and skid, `CameraRig._process` (damping, zoom, pull-back easing), HUD/ring animation, vignette fade, preview. Do **not** use `Time.get_ticks_msec()` for the hold clock; tick-based accounting keeps headless tests deterministic.

### Pattern 5: Shot as a stepped projectile with a derived pulse size

`ShotProjectile` (Node3D, no physics body) moves `speed * delta` per physics tick; each tick `intersect_ray(prev, next, WORLD | INTERACTABLE | ENEMY, collide_with_areas=false)`; on hit it builds a `PulseHit` (adds `energy: float`; `size = BIG` iff `energy >= big_energy_threshold`) and calls `Interactable.from_collider(...).try_trigger(pulse)` exactly as `remote_trigger.gd` does today. Bend: if `Targeting` holds a valid target, rotate the velocity direction toward `target.target_point()` by at most `hand_shot_turn_rate` deg/s (rate is the tunable "bend strength"). Range: `lerp(hand_small_range, hand_big_range, charge_ratio)`; free at max range or on hit. Keeping `PulseHit.Size` as a classification preserves `Interactable.min_pulse`, `valve.tscn` (`min_pulse = 1`), `Targeting.State.VALID_BIG` and 12 test files; the payload `energy` is what Phase 6 turns into damage.

### Anti-Patterns to Avoid

- **Copying `Capture._release` into the Loader:** it calls `actor.refill_air_dash()` [VERIFIED: attimo/scripts/player/states/capture.gd:91 `actor.refill_air_dash()`], which breaks D-03.
- **Several writers of `Engine.time_scale`** (hitstop, Loader, later juice): always assign through `TimeFx`, never multiply.
- **Dividing by `delta` in new code** (as `Capture._set_velocity_toward` does): at 0.25x and 60 Hz, delta is 1/240 s; fine, but at hitstop 0.05 it is 1/1200 s. Avoid or guard.
- **Hand-editing `movement_gym.tscn`, `mannequin_tree.tres`, `MOVEMENT-METRICS.md`:** all generated.
- **Putting Loader/energy state into the shared `MovementConfig` resource at runtime** (guardrail 2). Runtime state lives on `ArmEnergy`/`Loader`.
- **Writing energy from a mechanism node directly:** sources call `ArmEnergy.gain` through the Extractor module, or a request API, never `value =`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Slow motion | Custom per-node clock | `Engine.time_scale` via `TimeFx` | Platforms, mechanisms, projectiles and animation slow for free; physics cadence stays real-time |
| Real-time timers during slow motion | Counting `_process` delta | `create_timer(..., ignore_time_scale=true)`, `Tween.set_ignore_time_scale(true)`, or `TimeFx.unscaled(delta)` | Native, one argument |
| World desaturation | Full-screen screen-texture shader | `Environment.adjustment_enabled` + `adjustment_saturation` on the gym's WorldEnvironment | No screen-texture read, HUD (CanvasLayer) stays coloured |
| Vignette | Post-process pass | CanvasLayer `ColorRect` with a procedural radial shader (pattern of the old `goggle_lens.gdshader`) | Cheap, no `hint_screen_texture` |
| Dashed trajectory | `ImmediateMesh` ribbon + dash shader | `MultiMeshInstance3D`, fixed `instance_count`, set `visible_instance_count` | Width and look controllable, no custom geometry |
| Pulse hit contract | New hit interface | Existing `PulseHit` + `Interactable.try_trigger` | 12 tests and all mechanisms already use it |
| Module plumbing | New input router | `HandModuleDef` + `ModuleRegistry` (one folder + one registry line) | Phase 4 framework, `test_hand_module` guards it |
| F2 sliders | New panel code | `MovementConfig` `@export_range` floats (auto rows) and `hand_*` floats on `HandController` (auto "Hand" section) | `tuning_panel.gd` already generates both |
| Event spam filter | Debounce class | Quantised `energy_changed` emit | `EventLog` connects to every EventBus signal |
| Respawn reset | Per-system reset hooks | One `PlayerController.respawn(pos)` = `teleport` + `ArmEnergy.reset_to_checkpoint()` | `teleport()` is also a test utility; keep it pure |

**Key insight:** every hard problem here (slow motion, UI arcs, instancing, sliders, hit contract, module registry) already has an engine feature or a project seam. The new code is three small classes (`TimeFx`, `ArmEnergy`, `LoaderMath`), one state, one projectile, one module, one source block and the HUD.

## Runtime State Inventory

(Aim-mode removal and the action rename `aim` -> `loader` make this a removal/rename phase.)

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `user://settings.cfg` holds camera sensitivity, invert-Y, auto-follow only; `test_tuning_panel` asserts no `aim_` key is ever written [VERIFIED: tests/smoke/test_tuning_panel.gd `aim_keys == 0`] | None. No migration. New tunables live in `res://resources/player/movement_default.tres` |
| Live service config | None (offline single-player, no services) | None |
| OS-registered state | None | None |
| Secrets/env vars | None (`GODOT` env var only for the test script) | None |
| Build artifacts | `attimo/scenes/player/mannequin_tree.tres` (generated by `tools/build_mannequin_tree.gd`, contains AimMachine, Shoot, directional dashes), `attimo/scenes/test/movement_gym.tscn` (generated, 9664 lines), `docs/MOVEMENT-METRICS.md` (generated, snapshot-tested), `.gd.uid` sidecars of deleted scripts, `.godot/` import cache, the Input Map in `project.godot` (`aim=` block) | Regenerate the three generated files with the pinned engine; delete `.uid` sidecars with their scripts; rename the Input Map entry |

**Nothing found in category:** Stored data (none to migrate), Live service config, OS-registered state, Secrets/env vars: verified by reading `camera_settings.gd` callers via the test and by the project having no network or OS integration.

## Aim-Mode Removal Inventory (ENRG-04)

Grep of `aim` over `.gd/.tscn/.tres/.godot/.gdshader` in `attimo/` lists these files (source of truth for the removal task; `aim_target_point()` and the crosshair ray are **kept**, they are how the shot and assist read the crosshair):

| File | What to do |
|------|------------|
| `attimo/project.godot` | `[input]` `aim=` (RMB, `button_index` 2) becomes `loader`; add `charge` (R), `module_1`/`module_2` keys (A3). `test_input_map` and `test_conventions` list the action names and `docs/CONVENTIONS.md` must name each action and each EventBus signal in backticks |
| `autoload/event_bus.gd:13-14` | Remove `signal aim_changed(active: bool)`; keep `dash_blocked` (reason becomes `&"energy"`), `pulse_fired` (keep; used by presentation) |
| `scripts/player/player_controller.gd` | Remove `aiming` (l.40-42), `DASH_LOCK_AIM` (l.47), the aim branch of `ground_target_speed` (l.145-155, becomes `run_speed * moto factor`), the `aiming` guards in `face`/`face_now` (l.188-200), `_tick_aim`/`_apply_aim_facing` (l.562-588) and the call at l.106; `dash_locked_reason` (l.254-261) now returns `&"energy"` for an unaffordable air dash |
| `scripts/player/states/dash.gd` | `slide = SLIDE_PRESENTATION and not in_air and not actor.aiming` loses the aim term; header comment |
| `scripts/player/states/run.gd`, `capture.gd` | Comments only |
| `scripts/player/procedural_pose.gd` | Aim lean scale, "no pirouette while aiming" gate (DEV-03), aim-press pirouette finish (l.77-93, 187) |
| `scripts/player/movement_config.gd` | Remove group "Aim" (`aim_speed_factor`, `aim_back_speed_factor`, l.93-97), `aim_lean_scale` (l.130-131), `aim_layer_blend_time` only if the arm layer is removed (see Open Question 2) |
| `scripts/player/mannequin_animator.gd` | Remove `_update_aim_edge`, aim branch of `_locomotion_target` and `dash_node_for`, aim strafe, `P_AIM_PLAYBACK`/`AimMachine` use, `IDLE_CANCEL_ACTIONS` entry `&"aim"` (l.44); add `Loader` to `STATE_TO_ANIM` (l.62-72) |
| `scripts/player/aim_pose_modifier.gd` + `scenes/player/mannequin.tscn` node `AimPoseModifier` | See Open Question 2. **Hidden dependency:** `tools/clip_retargeter.gd:333` and `:410` call `AimPoseModifier.rotation_between`; move that static function to a utility before deleting the class |
| `tools/build_mannequin_tree.gd`, `scenes/player/mannequin_tree.tres` | Rebuild the tree without AimMachine/Shoot/aim strafe/DashLeft/Right/Back (needs Godot); `docs/ANIMATION-MAP.md` is whitelist-tested against the tree and the library |
| `scripts/camera/camera_rig.gd` | Remove the "Aim" export group (l.103-121), `aim_weight`, `_aim_target`, `_update_aim`, `_update_snap`, `_on_aim_changed` + connect (l.206), `look_sensitivity_multiplier` (l.36, used at l.235), `_aim_target <= 0.0` guards (l.242, 249, 486, 553). **Wheel zoom (l.249-250) conflicts with D-16** (Open Question 1). Keep `aim_target_point`, `aim_ray`, `aim_direction_from`, `aim_ray_start`, the additive `set_offset`/`set_fov_offset` API |
| `scripts/hand/hand_controller.gd` | Remove the aim gate (l.134-137) and `debug_fire_without_aim` (l.36-37), `hand_sticky_*`, `arm_out` aiming term; HandController becomes input-edge router (below) |
| `scripts/hand/targeting.gd` | `update()` no longer returns early when not aiming (l.51-60 pattern), remove `_ease_sensitivity`/sticky; stronger snap defaults |
| `scripts/hand/modules/remote_trigger/remote_trigger.gd`, `hand_module.gd` | Rewritten as the projectile shot; `wants_charge()`/`on_use_released(big)` replaced (Pattern below) |
| `scripts/mechanisms/interactable.gd` | `GlowStage.AIM`, `GLOW_AIM_MATERIAL`, `_on_aim_changed` (l.14, 40, 61-64): drop or re-purpose (Open Question 4). `resources/mechanisms/glow_aim.tres` goes with it |
| `scripts/ui/crosshair.gd`, `scenes/ui/crosshair.tscn`, `scripts/ui/goggle_lens.gdshader` | Remove goggle lens, module plate, jolt, `hud_visible`; keep dot/ring and `NearPrompt`; add shot and Loader rings |
| `scripts/debug/tuning_panel.gd` | Remove the "Aim camera" section (`aim_*` rows) |
| `scenes/mechanisms/lever.tscn`, `crank.tscn`, `valve.tscn`, `energy_core.tscn` | `AimPoint` Marker3D / `aim_point` export is the **target point** of an Interactable, not aim mode: keep the name (rename is churn) |
| `tools/mechanism_rooms_builder.gd:358` | Label `"Fernauslöser: RMB halten, LMB tippen"` must be rewritten for hip fire (D-20); `puzzle_rooms_builder.gd` signs likewise |
| `docs/ANIMATION-MAP.md`, `docs/CONVENTIONS.md`, `.claude/CLAUDE.md` (input table) | Update action list, EventBus signal list, state list (`Loader`) |
| Tests deleted: `test_aim_mode`, `test_aim_camera`, `test_aim_pose`; rewritten: `test_aim_assist` (hip fire), `test_aim_layer` (new arm layer or delete), `test_aim_target` (keep the crosshair-ray parts), `test_dash_lockout` (energy reason) | |
| Tests with aim scenarios to edit: `test_clip_variants` (I3, aim clamp), `test_procedural_pose` (aim gate/lean/press finish), `test_crosshair`, `test_near_prompt`, `test_hand_module`, `test_pulse`, `test_glow_stages`, `test_tuning_panel`, `test_camera_rig`, `test_camera_controls`, `test_input_map`, `test_conventions`, `test_mechanism_rooms`, `test_near_contact`, `test_scene_run`, `test_animation_library/map/timing`, `test_dash` | Grep each for `aim` |

## Common Pitfalls

### Pitfall 1: Slow motion leaks after the Loader ends
**What goes wrong:** the game stays at 0.25x after a respawn, a freed player, a failed test or an exception.
**Why it happens:** `Engine.time_scale` is process-global; the Loader state is freed with the player. GAME-FEEL research: "if it lives in an enemy that is freed, the game stays in slow motion."
**How to avoid:** `TimeFx` autoload is the only writer; `Loader.exit()` releases; `TimeFx._exit_tree()` and test cleanup restore 1.0; every Loader smoke test ends with `check(Engine.time_scale == 1.0)`.
**Warning signs:** later tests run slower or `test_*` timings drift after a Loader test.

### Pitfall 2: Reading `delta` as real time
**What goes wrong:** the 1.2 s cap lasts 4.8 s, camera damping and HUD rings crawl, hitstop never ends.
**Why it happens:** `_process` and `_physics_process` deltas are scaled [VERIFIED: engine main.cpp:5062 `process(process_step * time_scale)`, :5001 `physics_process(physics_step * time_scale)`; Engine.xml: "affects ... all other simulations that make use of delta time (such as Node._process and Node._physics_process)"].
**How to avoid:** `TimeFx.unscaled(delta)` in the Loader, `CameraRig._process`, HUD, preview; real-time timers via the `ignore_time_scale` arguments.

### Pitfall 3: Assuming slow motion lowers the tick rate
**What goes wrong:** designing around 15 Hz input polling or adding interpolation hacks.
**Why it happens:** older guidance and the Engine docs note ("does not automatically adjust physics_ticks_per_second") invite the wrong inference.
**How to avoid:** the source shows ticks are generated from real time (`advance.physics_steps`) and only the delta is scaled; `Input.is_action_just_pressed` in physics is therefore still polled every real tick; physics interpolation (project setting on) is unaffected.

### Pitfall 4: Jump buffer and coyote stretch during the hold
**What goes wrong:** a Space press during the hold fires a jump right after the discharge (buffer 0.12 s of game time lasts 0.48 s real at 0.25x).
**How to avoid:** `consume_jump()` in `Loader.enter` and `exit`; dash presses are not buffered (`dash_press_starts_dash` reads `just_pressed` only).

### Pitfall 5: The mouse wheel is bound twice
**What goes wrong:** the wheel cycles hand modules and zooms the camera (`camera_rig.gd:249-250`).
**How to avoid:** decide in plan 1 (Open Question 1). Recommended: remove wheel zoom, keep `zoom_distance` as an export.

### Pitfall 6: `debug_only` dummy module appears in the wheel cycle
`HandController.available_ids()` includes debug-only defs in debug builds, so with registry [remote_trigger, extractor, dummy] the wheel cycles three modules in the gym. Skip `debug_only` defs in `cycle()` (keep them equip-by-id for tests).

### Pitfall 7: Generated artefacts and snapshot tests
`test_movement_metrics` fails if any `MovementConfig` float is missing from `docs/MOVEMENT-METRICS.md` ("Config snapshot" rows `| `field` | %.3f |`); `test_conventions` fails if `docs/CONVENTIONS.md` omits an EventBus signal or action; `test_animation_map` fails if a new FSM state (`Loader`) or clip is not in `docs/ANIMATION-MAP.md`. Plan the doc edits in the same task as the code, and the regeneration (`--tool res://tools/measure_movement.gd`) as a "needs Godot" step.

### Pitfall 8: Speed cap and tunnelling envelope
`long_jump_speed_3` range note: "22 m/s is the speed the camera and tunnelling tests cover, do not raise it without re-running them" [VERIFIED: movement_config.gd:68]. Capsule radius 0.5 m: at 60 TPS a body moves 0.37 m/tick at 22 m/s and 0.5 m/tick at 30 m/s. Start `loader_max_speed` at 22 (export range up to 24) and re-run `test_camera_*`/tunnelling checks before raising.

### Pitfall 9: Moto Perpetuo flicker at the 50 boundary
Passive charge (+3..6/s) and spends oscillate around 50; entry/exit flashes would spam. Use hysteresis (enter at >= 50, leave below 50 minus a small margin) or a minimum on-time; emit `moto_changed` only on flips. [ASSUMED: margin value]

### Pitfall 10: Passive charge exploits
Total speed would charge during terminal-velocity falls (40 m/s). Use **horizontal** speed (`player.horizontal_speed()`), exclude `Loader` and `Capture` states (slingshot is free and "no energy bonus"), and note moving platforms/conveyors move the body outside `move_velocity` so they do not charge. [ASSUMED: design call, flag for playtest]

### Pitfall 11: Energy on a 0..25 partial for the Loader bonus
Bonus costs 25. With 0 < energy < 25 the arm cannot pay; treat it as "empty" (grey ring, no spend, no bonus) and decide the spend **at release**, not at press, so the energy changing during a 1.2 s hold cannot desync the ring from the result. [ASSUMED: threshold rule, Open Question 3]

### Pitfall 12: Preview must not promise air control
After the release `air_control_lock_timer` blocks steering for 0.15 s, then `accelerate_air` pulls toward `air_speed_cap` along the input. The preview is the **no-input ballistic arc**; label it so and cap its length (about 1.5 s of flight or first hit).

### Pitfall 13: HUD or vignette drawn under the CanvasLayer order
`Crosshair` is layer 10, debug overlays 100-102 [VERIFIED: scenes/ui/crosshair.tscn `layer = 10`; event_log 100, metrics_overlay 101, tuning_panel 102]. Put the HUD at layer 9 or 10 (below debug) and the vignette below the HUD (layer 5-8), so the vignette never tints the HUD and F2 stays on top.

### Pitfall 14: Gym test sanctions
`test_movement_gym` requires every mesh to sit under `scenes/proto/`, `scenes/mechanisms/` or the Mannequin scene, every `StaticBody3D` on World (or Interactable under mechanisms), no particle node, no glow/fog, at least 40 `Label3D` [VERIFIED: tests/smoke/test_movement_gym.gd `check.call(particles == 0 ...)`, `_has_sanctioned_ancestor`, `check.call(labels >= 40 ...)`]. Capsule and machine scenes go under `scenes/mechanisms/`; the projectile mesh is created at runtime (not present at check time).

### Pitfall 15: `Interactable` glow stage still listens to `aim_changed`
Removing the signal without touching `interactable.gd:40` is a runtime error on `_ready` (`EventBus.aim_changed.connect`). Same for `camera_rig.gd:206` and `crosshair.gd` `_ready`.

### Pitfall 16: HandPresentation keeps dead hooks
`HandPresentation` streak and flash listen to `pulse_fired` (instant ray). The projectile fires later: emit `pulse_fired` at launch (presentation flash) and a new fact (`shot_hit`) at impact, or flash will be wrong.

## Code Examples

### TimeFx (sole writer of `Engine.time_scale`)
```gdscript
# autoload/time_fx.gd  (autoload name TimeFx, no class_name)
extends Node
const MIN_SCALE: float = 0.05
var _requests: Dictionary[StringName, float] = {}

func request(source: StringName, scale: float) -> void:
	_requests[source] = clampf(scale, MIN_SCALE, 1.0)
	_apply()

func release(source: StringName) -> void:
	if _requests.erase(source):
		_apply()

## Seconds of REAL time that a scaled `delta` represents.
func unscaled(delta: float) -> float:
	return delta / maxf(Engine.time_scale, 0.01)

func _apply() -> void:
	var lowest: float = 1.0
	for scale: float in _requests.values():
		lowest = minf(lowest, scale)
	Engine.time_scale = lowest

func _exit_tree() -> void:
	Engine.time_scale = 1.0
```
Source basis: Engine.xml (`time_scale` note: keep above 0.0) and GAME-FEEL.md 6.3 (assign, never multiply). Register in `project.godot` `[autoload]` next to `EventBus="*res://autoload/event_bus.gd"`.

### Loader hold clock and release (essentials)
```gdscript
# scripts/player/states/loader.gd  (extends State)
var _hold_real: float = 0.0
var _stored: Vector3 = Vector3.ZERO
var _grounded_entry: bool = false

func enter(_previous: StringName) -> void:
	var config: MovementConfig = actor.config
	_stored = Vector3(actor.move_velocity.x, actor.vertical_speed, actor.move_velocity.z)
	_grounded_entry = actor.is_grounded()
	_hold_real = 0.0
	actor.consume_jump()                        # Pitfall 4
	if not _grounded_entry:
		actor.loader_available = false          # once per air phase (D-02)
		actor.gravity_scale = 0.0
		actor.move_velocity = Vector3.ZERO
		actor.vertical_speed = 0.0
	TimeFx.request(&"loader", config.loader_slow_factor)
	EventBus.loader_started.emit(actor.global_position, _stored.length(), not _grounded_entry)

func exit() -> void:
	actor.gravity_scale = 1.0
	TimeFx.release(&"loader")                   # every exit path, incl. teleport() -> Fall

func physics_update(delta: float) -> StringName:
	var real: float = TimeFx.unscaled(delta)
	_hold_real += real
	if _grounded_entry:
		var flat: float = Vector2(_stored.x, _stored.z).length()
		var skid_rate: float = flat / maxf(actor.config.loader_skid_time, 0.01)
		actor.move_velocity = actor.move_velocity.move_toward(Vector3.ZERO, skid_rate * real)
	if not Input.is_action_pressed(&"loader") or _hold_real >= actor.config.loader_hold_cap:
		return _discharge()
	return &""
# _discharge(): direction = actor.loader_direction() (camera forward, one function for preview and release);
# bonus = arm_energy.try_spend(config.loader_bonus_cost, &"loader") decided HERE; speed = LoaderMath.discharge_speed(...);
# write move_velocity/vertical_speed, air_speed_cap = maxf(run_speed, horizontal_speed()), lock_air_control(0.15),
# emit loader_released, return &"Fall". Do NOT call refill_air_dash() (D-03).
```
Pattern basis: `capture.gd` (hold, `lock_air_control`, `air_speed_cap`) with the D-03 correction.

### Energy checks at the existing choke points (verified signatures)
```gdscript
# player_controller.gd: can_dash() (l.265-270) gains the cost in the air, dash_locked_reason() (l.254-261) the refusal:
func dash_locked_reason() -> StringName:
	if not is_grounded() and air_dash_available and dash_cooldown_timer <= 0.0 and not arm_energy.can_afford(config.air_dash_cost):
		return &"energy"
	return &""
# start_dash(direction, in_air) (l.297-301): in the air call arm_energy.try_spend(config.air_dash_cost, &"air_dash") after air_dash_available = false.
# advance_long_jump_stage() (l.502-507): after computing `stage`, if stage >= 2 and not arm_energy.try_spend(config.long_jump_cost, &"dash_hop"):
#     stage = 1   # base version, no failure signal (D-12)
# WallRun.physics_update: after config.wall_run_free_time, drain config.wall_run_cost_per_second * delta; if drain < wanted -> return &"Fall".
# ground_target_speed(): return config.run_speed * (1.0 + config.moto_run_bonus) while arm_energy.is_moto()
```
Quoted anchors: `func dash_locked_reason() -> StringName:`, `var air_dash_available: bool = true`, `func advance_long_jump_stage() -> int:` (player_controller.gd). A refused press re-uses `_block_dash(reason)` which emits `EventBus.dash_blocked(global_position, reason)` and starts the twitch.

### Buffed Moto Jump 3 (Pittman: solve jump from height and time)
```
v0 = 2h / t        g = 2h / t^2          (apex height h, time to apex t)
base Jump 3:  h = 4.0, rise_gravity 34.0 -> v0 = sqrt(2*34*4.0) = 16.5 m/s, t = 0.49 s
buffed:       h = 5.0, t = 0.45 s        -> v0 = 22.2 m/s, g = 49.4 (gravity_scale 1.45)
```
Implementation: `Jump.enter` sets `actor.gravity_scale = config.moto_jump_gravity_scale` and `vertical_speed = sqrt(2 * rise_gravity * scale * height)` when `stage == 3 and is_moto`; `Jump.exit()` restores `gravity_scale = 1.0` (Jump hands to Fall at the apex, so the fall keeps normal gravity). Same save/restore rule as `Dash`/`WallRun` [VERIFIED: player_controller.gd l.14-16 `## Scales gravity for this tick. A state may lower it (air dash) and must restore it in exit()`]. Numbers are starting values (A5).

### Dashed preview with MultiMesh (sketch)
```gdscript
# loader_preview.gd: _process (real delta), only while Loader state is active
var points: PackedVector3Array = LoaderMath.trajectory(origin, velocity, config, 0.05, MAX_POINTS, space_state, WORLD_MASK)
for i: int in dash_count:
	var t: Transform3D = Transform3D(Basis.looking_at(points[i + 1] - points[i], Vector3.UP), points[i].lerp(points[i + 1], 0.5))
	multimesh.set_instance_transform(i, t)
multimesh.visible_instance_count = dash_count
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phase 4 shot: instant raycast + cosmetic streak, size by hold 0.4 s | Flying projectile, energy-priced hybrid charge | This phase (D-17) | `remote_trigger.gd` rewritten; `pulse_fired` fires at launch |
| Aim hold = camera FOV/offset/goggle HUD/aim pose | Always-on crosshair, Loader on RMB | This phase | See removal inventory |
| `Input.is_action_just_pressed` returned true only while still pressed in older 4.x | 4.7.2 default returns true for a press-release in the same frame (`legacy_just_pressed_behavior` default false) | 4.x line | Mouse-wheel module switch via `just_pressed` is safe [VERIFIED: core/input/input.cpp:435-441 and `GLOBAL_DEF("input_devices/compatibility/legacy_just_pressed_behavior", false)` at :2364] |

**Deprecated/outdated:** Phase 4 D-02 (fire only while aiming), D-03/D-05 (small/big by hold time), D-04 (instant hit), D-13 (goggle HUD), D-14 (sticky aim); Phase 3 aim decisions D-09..D-15 and DEV-03.

## Lecture Checklist (LECTURE-PRINCIPLES section 1) - items research can inform

| # | Finding |
|---|---------|
| 2 Greatest risk first | The risk is Loader feel **and** slow-motion plumbing. Both are in plan 1. Because RMB is the aim button, the minimal aim cut-over (remove `aim` action, `_tick_aim`, aiming flags) belongs in plan 1 too |
| 3 Fidelity | Greybox: MultiMesh dashes, prisms, `draw_arc` rings, procedural vignette shader; no particles (gym test) |
| 4 Metrics | New MovementConfig groups are guarded by `test_movement_metrics`; add Loader rows to `tools/movement_metrics.gd` and to `ROW_LABELS` |
| 8 Loop relationships | Moto run (9.5 m/s) is below the 10 m/s passive threshold (D-05): the reinforcing loop runs through techniques only. Confirmed by `run_speed 8.5` x 1.10..1.15 = 9.35..9.78 m/s. Flag for playtest, not a research blocker |
| 9 Which knob | Tune player-character level only: `MovementConfig` Loader/Energy groups, not kit or level |
| 10 Feel property | "Geladen": rising tension = ring fill + pull-back + hum; sharp release. Swink's principle (polish creates cues about one physical property, clashing effects destroy the reading) is the lens; the local PDF `docs/vorlesung/books/swink-2008-game-feel.pdf` is **not present on this machine**, so no page-level quotes were taken (LOW for Swink specifics, principle itself is in LECTURE-PRINCIPLES section 2) |
| 11 Readability | Two rings never confused: shot = notched ring, clockwise, fills with charge; Loader = double ring, counter-clockwise, fills with stored speed / `loader_max_speed`. Grey = empty arm. Turquoise = energy only |
| 12 Architecture | Decision: one energy owner + pure `LoaderMath` + one time owner. Keeps cheap: new costs (one `try_spend` line), the slingshot sharing the hold code, Phase 11 hitstop through the same `TimeFx` |
| 13 Done means | The seven requirement IDs plus D-11, D-13, D-17 verified through the smoke tests in Validation Architecture and the human checklist |

**Camera lens (Nesky, secondary summary only):** a written summary of "50 Game Camera Mistakes" gives: orbit around the avatar and never pivot in place (item 3), "intent wins" when the camera fights the player (item 6), ease camera moves along smooth curves (item 14), tie distance and FOV to pitch together (item 16) [CITED: matellion.blogspot.com/2016/08/50-common-game-camera-mistakes-and-how.html, a third-party summary; the talk itself was not watched]. Applied: the existing orbit rig is already correct for a free camera; the Loader pull-back is a small eased additive offset, never a cut, never a shake; player mouse input is never overridden. **Jump lens (Pittman):** design jumps from apex height and time-to-apex (`v0 = 2h/t`, `g = 2h/t^2`) and use different gravity up and down [CITED: traversingvirtual.blogspot.com/2024/07/designing-platformer-player-controls.html summary of the GDC 2016 talk; slides not retrieved].

## Loader and Energy starting values (FEEL-10 table seed; all F2 tunable)

| Field (MovementConfig) | Start | Basis |
|------|-------|-------|
| `loader_slow_factor` | 0.25 | CONTEXT D-04 carried (about 0.25x) |
| `loader_slow_in_time` (real s, ease of time scale) | 0.06 | [ASSUMED] sharper than a cut, softer than a jolt |
| `loader_hold_cap` (real s) | 1.2 | CONTEXT carried |
| `loader_skid_time` (ground, real s) | 0.1 | D-01 |
| `loader_min_push` | 12.0 m/s | [ASSUMED] above run 8.5, below dash hop stage 1 (14) so redirect is not free speed |
| `loader_bonus_speed` (additive) | +8.0 m/s | [ASSUMED] |
| `loader_bonus_cost` | 25 | CONTEXT carried |
| `loader_max_speed` | 22.0 m/s (range to 24) | Pitfall 8 |
| `loader_redirect_cooldown` (empty arm) | 1.0 s | [ASSUMED] |
| `loader_release_control_lock` | 0.15 s | D-03 (mirror `Capture.EXIT_CONTROL_LOCK`) |
| `loader_hitstop_time` (real s) / scale | 0.05 s / 0.05 | [ASSUMED] world freeze via `TimeFx`, player velocity applied on the release tick (no input delay) |
| `loader_camera_pullback` | 0.35 m | [ASSUMED] "very slightly" (D-04) |
| `energy_passive_start_speed` | 10.0 m/s | D-05 |
| `energy_passive_rate_min` / `_max`, `energy_passive_full_speed` | 3.0 / 6.0 per s, 18.0 m/s | D-05 |
| `energy_charge_rate` (button R) | 5.0 /s | D-06 |
| `air_dash_cost`, `long_jump_cost` (stage 2, 3), `wall_run_free_time`, `wall_run_cost_per_second` | 10, 15, 0.6 s, 15 /s | GAME-DESIGN section 3 |
| `moto_threshold`, `moto_run_bonus`, `moto_jump_height`, `moto_jump_gravity_scale` | 50, 0.12, 5.0 m, 1.45 | GAME-DESIGN (+10-15 %); jump numbers [ASSUMED] |
| `hand_shot_cost_min`, `hand_shot_cost_max`, `hand_shot_charge_time`, `hand_shot_tap_time` | 10, 25, 0.8 s, 0.12 s | D-17; tap time [ASSUMED] |
| `hand_shot_speed`, `hand_shot_turn_rate` | 40 m/s, 540 deg/s | [ASSUMED] |
| Extractor `hand_extract_range`, `hand_extract_angle` | 4.0 m, 35 deg half-angle | [ASSUMED] |
| Capsule / machine | +40 in 0.5 s / +60 in 2.0 s, `respawn_time` per instance | D-07, D-08 |

The camera's `pitch_max 0.75 rad` (about 43 degrees, [VERIFIED: camera_rig.gd:71] `@export var pitch_max: float = 0.75`) caps how steeply the view can point up, so a super jump is limited to about 43 degrees unless the pitch limit is raised during the hold (open tuning item).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Rename Input action `aim` -> `loader` (keep `aim` removed so stale references fail loudly) | Removal inventory | CONTEXT says "`aim` action becomes the Loader"; if the user wants the name kept, tests/docs differ only in a constant |
| A2 | `TimeFx` as a second autoload (GAME-FEEL rule 8) instead of a player component | Standard Stack | Adds an `[autoload]` entry; alternative is a node under the gym root |
| A3 | New actions `module_1`/`module_2` on keys 1 and 2 (D-16 "1/2"); digits 8/9/0 are already debug alternates, no clash | Inventory | Naming/binding churn only |
| A4 | Hit-stop is a world `TimeFx` pulse (0.05 at 0.05 s), player velocity applied on the release tick | Starting values | If it reads as latency, make it player-local or 0 |
| A5 | All numbers in "starting values" except those marked CONTEXT/GAME-DESIGN | Starting values | They are F2 tunables by definition; planner must not treat them as locked |
| A6 | Passive charge uses horizontal speed and excludes Loader and Capture states | Pitfall 10 | Design call; changes how charge tracks feel |
| A7 | Loader bonus needs a full 25; below that the arm counts as empty | Pitfall 11 | Alternative: spend what is there with a smaller bonus |
| A8 | Discharge direction = camera forward (not parallax-corrected crosshair point) | Pattern 2 | Preview and result stay consistent either way, but feel differs near walls |
| A9 | Moto hysteresis margin about 2.5 energy | Pitfall 9 | Flicker if absent, slight lag if too large |
| A10 | `foot.l`, `foot.r`, `chest` exist on the Mannequin skeleton for the Moto glow points (seen as `&"foot.l"`, `&"foot.r"`, `&"chest"` in tests/tools; back point attaches to `chest` or `spine`) | Presentation | If a bone is absent the attachment helper must skip it (as `HandPresentation` does for `hand.r`) |
| A11 | MultiMesh dashes are visually acceptable as the "dashed preview" | Pattern | Cosmetic; swap for ImmediateMesh later |
| A12 | The Swink PDF is absent on this machine, so no Swink page citations were made | Lecture | None for correctness |

## Open Questions (RESOLVED)

All seven questions were resolved on 2026-11-24 during plan-phase; see 05-CONTEXT.md "Plan-phase follow-up" (D-26..D-29) and the accepted researcher defaults.

1. **Camera wheel zoom vs module switch (D-16).**
   - Known: `camera_rig.gd:249-250` zooms on the wheel outside aim; `module_next/prev` are bound to wheel down/up.
   - Unclear: which gets the wheel.
   - Recommendation: drop wheel zoom (fixed `zoom_distance`, exports stay on the F2 panel); the 1/2 keys are the alternative for modules. Needs user confirmation because it removes a feature added 2026-11-18.
   - **RESOLVED:** D-26, wheel zoom dropped; wheel and 1/2 switch modules.
2. **What replaces the Aim animation layer for near contact and the shot arm?**
   - Known: `arm_out` (near contact, shot flash, aiming) raises the Aim layer and the `AimPoseModifier` solver today; hand poses (ART-04) are Phase 6; CONTEXT says "removed or disabled".
   - Unclear: whether near-contact/shot arm presentation may regress until Phase 6.
   - Recommendation: remove aim hold, aim strafe, aim dashes and `player.aiming`, but **keep** the upper-body layer and solver driven only by `HandController.arm_out` (disabled path stays dormant) so E and the shot still show an arm. Deleting `aim_pose_modifier.gd` outright needs the `rotation_between` relocation (tools).
   - **RESOLVED:** D-27, layer and solver kept dormant, driven by `arm_out`.
3. **Bonus below one core.** Recommendation A7 (needs a full core). Confirm. **RESOLVED:** accepted default, the bonus needs a full core (25).
4. **`Interactable.GlowStage.AIM`.** With no aim, the stage has no trigger. Recommendation: reuse it as "shot module equipped and arm can afford 10" (a useful energy readability cue) or delete it with `glow_aim.tres`. **RESOLVED:** D-28, reused as "shot ready".
5. **`base_shoulder_offset (0.6, 0.35, 0)`** is a DEBUG permanent over-the-shoulder offset [VERIFIED: camera_rig.gd:111], not the aim offset. D-15 removes the *aim* shoulder offset; CLAUDE.md says framing is centred. Recommendation: leave it as is this phase, decide in the gym check. **RESOLVED:** accepted default, left untouched.
6. **Where in the gym do the Loader room and the energy area go?** Hall is x -42..42, z -50..34; room 2 is x 43..219; puzzle rooms behind x 219 (shifted). Recommendation: new zones `Zone_Loader` (open, with its own `FallReset`) and `Zone_Energy`, built by `tools/energy_area_builder.gd`, appended after the puzzle rooms or south of the hall; the planner picks coordinates with the existing grid helpers. **RESOLVED:** accepted default, new builder-generated gym zones (Zone_Loader, Zone_Energy).
7. **Loader pitch range during the hold** (camera `pitch_max` about 43 degrees). Tuning decision for the room. **RESOLVED:** D-29, pitch-up limit about 75 degrees while holding.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Godot 4.7.2 (macOS) at `$HOME/Applications/Godot_4.7.2/Godot.app/Contents/MacOS/Godot` | `bash attimo/tests/run.sh`, every tool run, all smoke tests | no | directory does not exist on this machine | `GODOT=<path>` override on the user's machine; a Windows exe `Godot_v4.7.2-stable_win64.exe` exists under `~/Downloads/Godot_v4/` but cannot run on Darwin |
| `godot` / `godot4` on PATH | convenience | no | not found | none |
| git | commits, `run.sh` repo checks | yes | n/a | n/a |
| bash, curl | tests / research | yes | n/a | n/a |
| Swink PDF (`docs/vorlesung/books/swink-2008-game-feel.pdf`) | feel research | no (git-ignored, not on this machine) | n/a | LECTURE-PRINCIPLES section 2 summary |

**Missing dependencies with no fallback:** a pinned Godot binary for executing any validation. The executor must run on the user's machine (or the user runs the commands). Commands that **require Godot**: `bash attimo/tests/run.sh [filter]` (all smoke tests), `bash attimo/tests/run.sh --tool res://tools/build_movement_gym.gd`, `--tool res://tools/build_mannequin_tree.gd`, `--tool res://tools/measure_movement.gd`, any editor feel session in the gym.
**Commands that work without Godot:** `grep`/`git diff` static guards (removed symbols, action names, EventBus signal names in docs), reading generated text artefacts.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Custom headless smoke runner `attimo/tests/run_smoke.gd`: each test is `RefCounted` with `func run(tree: SceneTree, check: Callable) -> void` (may await), auto-discovered in `res://tests/smoke/test_*.gd` |
| Config file | none; engine settings in `attimo/project.godot` |
| Quick run command | `bash attimo/tests/run.sh test_loader,test_energy` (comma-separated filename substrings) |
| Full suite command | `bash attimo/tests/run.sh` (about 70 existing smoke tests; greps logs for `SCRIPT ERROR|Parse Error|Failed to load|Failed loading resource`) |
| Helpers | `tests/fixtures.gd`: `spawn_floor`, `spawn_player`, `spawn_camera_rig`, `wait_physics`, `wait_until`, `hold_action`, `tap_action`, `send_action_event` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HAND-04 | Hold stores velocity, `Engine.time_scale` becomes 0.25 and returns to 1.0 on release, cap, teleport and free; cap counted in real ticks (72 ticks = 1.2 s) | smoke | `bash attimo/tests/run.sh test_loader` | no, Wave 0 |
| HAND-04 | Once per air phase, refilled on landing and by `refill_air_dash()`; discharge never changes `air_dash_available` (D-03); air control locked 0.15 s | smoke | same | no |
| HAND-04 | `LoaderMath.discharge_speed` table: `max(stored, min_push) + bonus` capped; empty arm = no bonus + cooldown; spend only at release | unit-style smoke | `bash attimo/tests/run.sh test_loader_math` | no |
| HAND-04 | Preview landing point equals real flight landing (no input) within tolerance | smoke | `test_loader_math` | no |
| FEEL-10 | `movement_default.tres` Loader/Energy floats appear in `docs/MOVEMENT-METRICS.md` snapshot and Loader rows exist | smoke (existing, extend `ROW_LABELS`) | `bash attimo/tests/run.sh test_movement_metrics` | yes (edit) |
| ENRG-01 | 0..100 clamp, 4 core fills (`core_fill`), Moto at 50 with hysteresis, respawn sets exactly 25 via `respawn()` | smoke | `bash attimo/tests/run.sh test_energy` | no |
| ENRG-02 | Passive curve (9.9 m/s = 0, 10 = 3/s, 18 = 6/s), no passive in Loader/Capture, charge button only while still, source drain amounts and `respawn_time` | smoke | `test_energy_income` | no |
| ENRG-03 | Ground dash free; air dash does not fire at < 10 and emits `dash_blocked` reason `&"energy"`; hop stage 2/3 cost 15, stage falls back to 1 with no failure fact; wall run free 0.6 s then drains and ends at 0 | smoke | `test_energy_costs` (+ rewrite `test_dash_lockout`) | no / edit |
| ENRG-04 | No `aim` action, no `aim_changed` signal, no `aiming` property, no goggle nodes; crosshair always visible; Targeting active without a hold; no sticky multiplier | smoke (static-ish guard) | `test_aim_removed` | no |
| ENRG-05 | HUD node exists, polls `ArmEnergy`, shows 4 cores, Moto state, module name, speed gauge; ignores the mouse; layer below debug overlays | smoke | `test_energy_hud` | no |
| D-11 | Extractor cone drains only `energy_source` nodes in range, amounts per D-07, empty then dark | smoke | `test_extractor` | no |
| D-17/D-19 | Tap = 10, hold up to 25 in about 0.8 s, `< 10` refuses, projectile hits `Interactable` with `PulseHit.energy`, bends to a locked target | smoke | `test_shot` (rewrite of `test_pulse`) | edit |
| Criterion 6 | Gym has Loader room, charge track, capsules, machine, per-move stations, each with an "Erwartet:" sign and a smoke check; no aim station | smoke | `bash attimo/tests/run.sh test_movement_gym,test_energy_gym` | edit/new |

### Sampling Rate
- **Per task commit:** the filtered smoke tests of the touched area (`bash attimo/tests/run.sh test_loader,test_energy`).
- **Per wave merge:** full `bash attimo/tests/run.sh`.
- **Phase gate:** full suite green plus the human feel checklist below before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `tests/smoke/test_loader.gd`, `test_loader_math.gd`, `test_energy.gd`, `test_energy_income.gd`, `test_energy_costs.gd`, `test_energy_hud.gd`, `test_extractor.gd`, `test_aim_removed.gd`, `test_energy_gym.gd`
- [ ] `Fixtures` helpers: `set_energy(player, value)`, `time_scale_guard` (assert and reset `Engine.time_scale` and release `TimeFx` requests in teardown)
- [ ] Delete/rewrite the aim tests listed in the removal inventory in the same task that removes the code, or the suite goes red
- [ ] Decide the Godot binary path for the executor (`GODOT=...`); no framework install needed

### Human-only items (cannot be verified headless; record in the phase verification checklist)
Loader hold tension and release snap, whether 0.25x reads as "geladen", camera pull-back amount, ring readability (two rings never confused), vignette and desaturation taste, hitstop feel, shot charge tell and bend noticeability, Moto glow points, HUD layout, gym walk-through of every new station. Run at 60 TPS and spot-check at 120 (the metrics overlay F6 cycles 60/120/10).

## Security Domain

`security_enforcement` is on (ASVS level 1, block on high). This is an offline single-player prototype: no authentication, sessions, network, secrets or untrusted file parsing beyond the existing `user://settings.cfg`.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a |
| V3 Session Management | no | n/a |
| V4 Access Control | no | n/a |
| V5 Input Validation | yes | Finite checks on every value that reaches the controller (existing pattern `is_finite()` in `launch_along`, `boost_along`, `capture_along`); clamp F2 inputs by `@export_range`; clamp `value` of `ArmEnergy` to 0..100; clamp projectile direction and speed |
| V6 Cryptography | no | n/a |
| V12 Files | minor | The Save button only writes `res://` in the editor; camera settings only `user://` (existing `CameraSettings.save_to` refuses `..`); new code writes nothing to disk |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| NaN/Inf from a mechanism, projectile or slider propagating into `CharacterBody3D` (hang or crash) | Tampering / DoS | `is_finite()` guards at every request API; `LoaderMath` and `ShotProjectile` reject non-finite input |
| Time scale left at 0.25 after an error (soft DoS of the session) | DoS | Single writer `TimeFx`, restore in `exit()`/`_exit_tree`, minimum scale 0.05 |
| Unbounded per-frame loops (trajectory steps, projectile count, group scans) | DoS | Fixed `MAX_POINTS`, cap live projectiles (e.g. 4), group queries only on the physics tick |
| Debug-only modules reachable in release | Elevation | Existing `debug_only` flag (`T-04-03`); keep the dummy out of the wheel cycle |

## Sources

### Primary (HIGH confidence)
- Godot engine source at tag `4.7.2-stable` (fetched this session): `main/main.cpp` (`Main::iteration`, lines 4936-5073: `physics_process(physics_step * time_scale)`, `process(process_step * time_scale)`, `PhysicsServer3D::step(physics_step * time_scale)`), `core/input/input.cpp` (just_pressed), `scene/main/timer.cpp`, `scene/main/scene_tree.cpp` (`create_timer`), `scene/animation/tween.cpp`, `scene/resources/environment.cpp`, `scene/3d/physics/character_body_3d.cpp` (delta from `get_physics_process_delta_time`), `doc/classes/Engine.xml`, `doc/classes/AudioServer.xml`. Master `main/main.cpp` shows the same logic.
- Project code read this session (paths and line ranges cited inline): `attimo/scripts/player/player_controller.gd`, `states/*.gd`, `core/state_machine.gd`, `scripts/camera/camera_rig.gd`, `scripts/hand/*`, `scripts/ui/crosshair.gd`, `scripts/mechanisms/interactable.gd`, `autoload/event_bus.gd`, `movement_config.gd`, `mannequin_animator.gd`, `debug/tuning_panel.gd`, `tests/run.sh`, `run_smoke.gd`, `fixtures.gd`, `tests/smoke/test_movement_metrics.gd`, `test_movement_gym.gd`, `test_conventions.gd`, `project.godot`.
- `docs/GAME-DESIGN.md`, `docs/reference/LECTURE-PRINCIPLES.md`, `.planning/research/GAME-FEEL.md` (6.3 hit-stop and time-scale pitfalls), `.planning/phases/05-energy-arm-loader/05-CONTEXT.md`.

### Secondary (MEDIUM confidence)
- Pittman, "Building a Better Jump" (GDC 2016): third-party summary at traversingvirtual.blogspot.com (apex-height/time formulation, asymmetric gravity). Talk and slides not retrieved.
- Nesky, "50 Game Camera Mistakes" (GDC 2014): third-party list at matellion.blogspot.com (items 3, 6, 14, 16). Talk not watched.

### Tertiary (LOW confidence)
- Swink, *Game Feel*: only via LECTURE-PRINCIPLES (PDF not available on this machine).
- All starting values marked [ASSUMED].

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - built-in engine features, behaviour verified in the 4.7.2 source.
- Architecture: HIGH for integration points (read in the code), MEDIUM for UI/VFX techniques (MultiMesh, procedural vignette, `adjustment_saturation`).
- Pitfalls: HIGH for time-scale and aim-removal findings (source-verified), MEDIUM for design-call pitfalls (passive charge, hysteresis).
- Numbers: LOW-MEDIUM by design; they are starting values for the F2 panel.

**Research date:** 2026-11-24
**Valid until:** 2026-12-24 (engine pinned at 4.7.2; code facts valid until the next merge touching the listed files)
