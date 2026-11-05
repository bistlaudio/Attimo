# Phase 2: Movement Core & Follow Camera - Research

**Researched:** 2026-11-04
**Domain:** Godot 4.7.2 third-person platformer movement (`CharacterBody3D` on Jolt), hand-built follow camera under physics interpolation, headless-testable feel measurement
**Confidence:** MEDIUM-HIGH (engine behaviour verified by probes on the pinned 4.7.2 binary; all feel numbers are starting values that the gym tunes)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Run and sprint feel**
- **D-01:** Ground acceleration is orientated on Super Mario (3D): fast but perceptible build-up, noticeable turn-around/skid on direction reversal, some weight. Not instant, not floaty. All values tunable in the movement resource; Claude picks the start values and the exact curve shape.
- **D-02:** Air control is high: near-full direction control in the air, forgiving for jumps.
- **D-03:** Sprint is hold-to-sprint (`sprint` action held, release = run). Sprint speed is about 1.5x run speed with its own acceleration curve.

**Jump chain (ground) and long jump**
- **D-04:** Jump height is variable in every jump: tap = short, hold = high (velocity cut on release). Chain stages only set the maximum height. Fall gravity is heavier than rise (multiplier 1.5-2x), with terminal velocity clamp.
- **D-05:** Ground chain is original, not Mario's 1-2-3: Jump 1 -> land -> Jump 2 (higher, within a landing window) -> Dash -> Jump = **maximum long jump** (high and fast, forward). Fewer chain stages give a weaker long jump (a dash-jump without a chain is still a long jump, just smaller). Landing window, stage heights and long-jump arc are tunable values.
- **D-06:** A jump pressed during or right after a plain ground dash (no chain) is already a **small long jump**: a flatter, farther arc with the dash speed carried (not a flat copy of the normal jump). Each chain stage before the dash (D-05) makes it bigger, up to the maximum long jump. Jump cancels the dash. This replaces the earlier "normal jump with dash speed" idea.
- **D-07:** The chain resets when the landing window is missed or the player stands still. Landing resets double jump and air dash.

**Air options**
- **D-08:** One air double jump per airtime (MOVE-05 unchanged), one air dash per airtime. They may be combined in any order: jump -> air dash, double jump -> air dash, air dash -> double jump. Each is available once until landing. Exact ordering edge cases are Claude's discretion; keep the rule "each used at most once per airtime".
- **D-09:** Coyote time about 0.1 s and jump buffer about 0.1-0.15 s (CLAUDE.md values). A jump pressed just before landing counts as a buffered jump and keeps horizontal speed (no ground deceleration frame).

**Dash**
- **D-10:** Dash direction is the input direction (camera-relative); without input it goes in the current facing direction. The figure turns instantly toward the dash direction first, then dashes "forward" (the kit only has `Dodge_Forward`). Re-evaluate in Phase 3 for aim mode.
- **D-11:** Dash is a fixed distance (short speed override, about 0.15-0.2 s) after which part of the speed carries into run/sprint. Air control is kept on exit. Short cooldown about 0.3-0.5 s. A dash never tunnels through walls (swept/shape-cast safe).
- **D-12:** Air dash is once per airtime, refilled on landing.

**Platforms**
- **D-13:** Moving platforms and conveyors carry the player, and the player keeps the platform velocity as momentum when leaving it or jumping off (Mario-like). Slopes and stairs never make the player stick or launch (`floor_snap_length` about 0.3-0.5, `floor_max_angle` about 50 degrees, `floor_stop_on_slope`).

**Camera**
- **D-14:** Camera framing outside aim mode is **centered behind the character**, like Odyssey/BotW/Kirby. Shoulder offset arrives only in aim mode (Phase 3). CAM-01's "over-the-shoulder" wording changes to third-person follow; the planner updates REQUIREMENTS.md/ROADMAP.md accordingly. - **Reversibility:** reversible - offset is a rig parameter.
- **D-15:** Follow uses light damping, with vertical follow smoothed so jumps do not cause bobbing (the camera catches up on landing). No fixed hard lock.
- **D-16:** Auto-follow as in Odyssey: after about 1 s without look input, while moving, the camera rotates gently behind the movement direction; sideways running pulls it along. It must never fight mouse input (it stays off while the mouse is moving) and must also work for a controller later.
- **D-17:** New input action `camera_recenter` (default: middle mouse, R3 later) snaps the camera quickly behind the character. Added to the Input Map and `docs/CONVENTIONS.md`. - **Reversibility:** costly - action names are referenced from code (D-15 of Phase 1).
- **D-18:** Camera tech: **hand-built rig, Phantom Camera is dropped.** Rig = `CameraRig (yaw) > Pitch > SpringArm3D > Camera3D`. No Phantom Camera spike. The rig must support additive contributions to FOV and offset (for Phase 3 aim blending and Phase 11 shake/FOV kick). Camera moves in `_process`, physics in `_physics_process`, jitter-free at 10 TPS and 144 Hz, never clips through walls. The planner updates the CLAUDE.md stack table (Phantom Camera row, addon list) and the STATE.md blocker. - **Reversibility:** costly - Phases 3 and 11 build on the rig's interface.
- **D-19:** Mouse sensitivity and invert-Y are configurable (CAM-03); defaults are Claude's discretion.

**Movement gym and measurement**
- **D-20:** The gym is one hall with zones: measurement strip on the 1 m grid, ramps and stairs, gaps of increasing width, moving platforms (straight, circular, up/down), conveyors, narrow passages and walls for camera tests. Built only from Prototype Bits (no new assets).
- **D-21:** Metrics are measured automatically by a debug overlay (max jump height/distance, dash distance, live) toggled by a key. Results are written into `docs/MOVEMENT-METRICS.md`. Gym markings allow a manual cross-check. Include long-jump and chain values.
- **D-22:** Latency is measured in software: time from input event to velocity/state change, at 60 and 120 TPS. Target <= 66 ms, hard limit 100 ms. Screen and mouse latency are outside the measurement; noted as a caveat in the doc.
- **D-23:** All movement values live in one tunable `Resource` (live-editable, MOVE-10). No juice in this phase.

### Claude's Discretion
- Start values and curve shapes for acceleration, skid, gravity, jump heights, chain window, long-jump arc, dash speed/duration, air-order edge cases.
- Default mouse sensitivity, pitch limits, camera distance/FOV, damping constants, auto-follow timing details.
- Key for the metrics overlay and the debug camera/gym toggles.

### Deferred Ideas (OUT OF SCOPE)
- **Prosthetic down-glide/blast:** a downward glide or burst from the prosthesis while it is "charged". Undecided; decide later (links to Hand modules, Phase 5 push/steam, and a possible charge mechanic). Not in Phase 2.
- Landing-based Odyssey triple jump and the tempo-stage idea (speed grows with well-timed actions): not taken. Revisit only if the gym sign-off shows the feel lacks it.
- Dive/ground-pound and gliding as air verbs: raised as options, not chosen; would need a clip composition (MOVE-11).

Out of scope for the phase (CONTEXT domain): full animation state mapping and aim mode (Phase 3), interactable highlighting and Fernausloeser (Phase 4), any juice/VFX (Phases 11-12), gamepad bindings (Phase 13), wall-run and ledge grab (v2).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MOVE-01 | Run with accel/decel curves, camera-relative steering | Pattern 1 (own velocity), Pattern 2 (camera-relative input), start values table, Pitfall 2 |
| MOVE-02 | Sprint | Sprint state / multiplier 1.5x (D-03), own accel; start values |
| MOVE-03 | Variable jump height, heavier fall | Pattern 3 (design-number jump, half-step gravity, velocity cut) - tick-rate independence verified |
| MOVE-04 | Coyote time and jump buffer | Pattern 3 timers; Pitfall 9 (buffer + release), jump press polling verified at 10 TPS |
| MOVE-05 | Double jump once per airtime | Pattern 4 (air-option flags, rule set) |
| MOVE-06 | Ground dash | Pattern 5 (timed state, velocity + move_and_slide; tunnelling verified blocked at 10 and 60 TPS) |
| MOVE-07 | One air dash, dash can flow into a jump | Pattern 4/5, chain + small/max long jump (D-05/D-06) |
| MOVE-08 | Platform/conveyor momentum, slopes and steps | Pattern 6 (platforms), verified conveyor/platform behaviour, snap and step-limit measurements |
| MOVE-10 | Movement values in a tunable resource + metrics table | Pattern 1 `MovementConfig`, `tools/measure_movement.gd`, `docs/MOVEMENT-METRICS.md` |
| CAM-01 | Smooth, jitter-free, non-clipping follow camera with mouse look | Pattern 7 (interpolated rig), SpringArm3D internals, automated jitter proxy |
| CAM-03 | Sensitivity and invert-Y configurable | `CameraSettings` + `ConfigFile` (Pattern 7), Security Domain |
| FEEL-06 | Input-to-response latency measured (<= 66 ms target, 100 ms hard) | Pattern 8 (`LatencyProbe` listening to existing facts), test via `InputEventAction` |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

Source: `/Users/bistl/GIT/Attimo/.claude/CLAUDE.md`. These carry the same authority as locked decisions.

- Engine: **Godot 4.7.2-stable, standard build (not .NET)**, typed GDScript everywhere (`var speed: float`, `-> void`), Jolt physics, Forward+.
- Own `CharacterBody3D` + `PlayerController`; **no** `RigidBody3D`, **no** addon controller. Hand-rolled node-based FSM, no state-machine addon.
- Physics interpolation ON; camera moves in `_process`, physics in `_physics_process`.
- Movement guide values: `motion_mode = GROUNDED`, `floor_snap_length` ~0.3-0.5, `floor_max_angle` ~50 degrees, `floor_stop_on_slope = true`; separate ground/air acceleration via `move_toward`/exponential smoothing; coyote ~0.1 s, jump buffer ~0.1-0.15 s, variable jump (cut on release), fall multiplier 1.5-2x, terminal velocity clamp; dash = short velocity override with cooldown, preserves air control on exit.
- Collision: primitive/convex shapes for platforms, **not** trimesh of the visual mesh.
- Input: all player input through Input Map actions (KB+M now, gamepad later).
- Camera row of the stack table says Phantom Camera first with SpringArm3D fallback: **superseded by D-18** (planner edits CLAUDE.md, see Plan-level doc edits below).
- Git: phase work on `dev`; raw `KayKit/` stays at repo root outside `attimo/`; only used assets are copied into `attimo/assets/`.
- Docs in English, user communication in German.
- GSD workflow enforcement: file edits only through a GSD command.

Additional repo guards that constrain implementation (read this session):
- `attimo/tests/smoke/test_feedback_guard.gd` scans `res://scripts/core`, `res://scripts/player`, `res://autoload` (comments included) for the tokens `AudioStreamPlayer`, `GPUParticles`, `CPUParticles`, `create_tween`, `Tween`, `Engine.time_scale`, `shake`. Gameplay scripts there must avoid those words, even in comments. [VERIFIED: attimo/tests/smoke/test_feedback_guard.gd:6,15-24]
- `attimo/tests/smoke/test_asset_hygiene.gd` pins `res://assets` to a whitelist of exactly 25 entries (`check.call(WHITELIST.size() == 25, ...)`). Copying new Prototype Bits is a deliberate edit of that list and its count in the same change. [VERIFIED: attimo/tests/smoke/test_asset_hygiene.gd:11-39,61]
- `debug/gdscript/warnings/untyped_declaration=2` turns every untyped declaration (including in `tools/` and `tests/`) into a parse error. [VERIFIED: attimo/project.godot:24]

## Summary

Phase 2 is almost entirely built-in Godot: a `CharacterBody3D` that owns its velocity, a thin node FSM extended from Phase 1, one `MovementConfig` Resource, and a hand-built `CameraRig`. **No external packages are needed** (Phantom Camera is dropped by D-18; Debug Draw 3D is optional and not needed for the overlay). The research risk is not in "which library" but in six engine-behaviour questions. I answered them with probes on the pinned 4.7.2 binary (Jolt, interpolation on):

1. Jolt `move_and_slide` is swept: a 60 m/s dash into a 0.1 m wall was blocked at both 10 and 60 TPS. No custom tunnel guard is required, only "dash = velocity + `move_and_slide` every tick".
2. `get_platform_velocity()` reports `constant_linear_velocity` for conveyors on both `StaticBody3D` and `AnimatableBody3D` under Jolt, and a `sync_to_physics` `AnimatableBody3D` carries the player exactly. Conveyors therefore need no script.
3. `SpringArm3D` runs its cast in `NOTIFICATION_INTERNAL_PHYSICS_PROCESS` and writes its child's transform at the physics rate. At 10 TPS the collision pull-in lags up to 100 ms. This is the one real risk in D-18 and needs an explicit 10-TPS corridor acceptance test with a defined fallback.
4. A camera rig in `_process` reading `target.get_global_transform_interpolated()` has 0% stationary frames at 10 TPS; reading `global_position` has 93%. This is also an automated, headless-runnable jitter test.
5. Semi-implicit gravity makes jump height tick-rate dependent (apex 1.500 m at 10 TPS vs 2.000 m analytic); half-step (Verlet) gravity gives the analytic apex at 10/30/60/120 TPS. Needed because FEEL-06 and the jitter test run at 10/60/120 TPS.
6. Capsule (r = 0.5) auto-climbs a 0.15 m riser but not 0.20 m at `floor_max_angle` 50 degrees; `floor_snap_length` 0.1 launches off a 45 degree ramp at sprint speed (32 airborne ticks), 0.4 does not at 60 TPS.

**Primary recommendation:** Build `PlayerController` around its own `move_velocity` (Vector3, horizontal) and `vertical_speed` (float) with half-step gravity and exactly one `move_and_slide()`; never copy the returned `velocity` back wholesale. Drive the camera from a top-level, interpolation-OFF `CameraRig` in `_process` reading the interpolated player transform. Keep every number in `MovementConfig` and generate `docs/MOVEMENT-METRICS.md` from a headless `tools/measure_movement.gd` run.

## Architectural Responsibility Map

This is a single-process game, so the "tiers" are the engine's execution contexts, not web tiers.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Velocity, gravity, `move_and_slide`, floor/platform bookkeeping | Physics tick (`PlayerController._physics_process`) | - | One kinematic move per tick (CONVENTIONS rule); interpolation needs all body motion on the tick |
| Movement decisions (jump, dash, double jump, chain) | FSM states (physics tick) | Controller timers (coyote, buffer, chain window, dash cooldown) | States write intent; controller owns integration |
| Mouse look (yaw/pitch accumulation) | Input event (`_unhandled_input`) | Render frame (`_process`) | Raw relative motion, no delta, no smoothing |
| Camera follow, damping, auto-follow, FOV/offset sum | Render frame (`CameraRig._process`) | Physics tick (SpringArm cast, see Pitfall 1) | Camera must update at display rate and read the *interpolated* target |
| Camera wall collision | SpringArm3D (physics-rate cast) | Own `cast_motion` in `_process` (fallback) | SpringArm only updates on the tick |
| Camera-relative input direction | Physics tick (reads camera yaw) | - | Input -> world direction must be sampled where velocity is set |
| Moving platforms / conveyors | Physics tick (`AnimatableBody3D` `sync_to_physics`, `constant_linear_velocity`) | - | Platform velocity is read via `get_platform_velocity()` after the move |
| Tuning values | `MovementConfig` Resource (res://) | Remote inspector / debug panel | One shared instance, live-editable |
| Camera settings persistence | `ConfigFile` at `user://` | Settings menu (Phase 7) | Avoid loading user-writable `.tres` (script injection) |
| Metrics + latency measurement | Debug tooling (listens to EventBus; headless tool) | - | Probes only listen; gameplay code gains no measurement calls |
| Gameplay facts for juice/audio | EventBus (emit only) | - | FEEL-01 guard |

## Standard Stack

### Core (all built-in, no installs)

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Godot 4.7.2-stable (standard) | 4.7.2 | Engine | Pinned by CLAUDE.md and `tests/run.sh` version gate [VERIFIED: attimo/tests/run.sh:13] |
| `CharacterBody3D`, `GROUNDED` motion mode | built-in | Player body | Locked by CLAUDE.md |
| Jolt Physics | bundled | 3D physics | `3d/physics_engine="Jolt Physics"` [VERIFIED: attimo/project.godot:128] |
| `SpringArm3D` + `Camera3D` | built-in | Camera collision + lens | Locked by D-18 |
| `AnimatableBody3D` (`sync_to_physics`) | built-in | Moving platforms | Verified to carry the player (probe) |
| `StaticBody3D.constant_linear_velocity` | built-in | Conveyors | Verified `get_platform_velocity()` = (3,0,0) on Jolt (probe) |
| `Resource` + `@export_group`/`@export_range` | built-in | `MovementConfig`, live tuning | MOVE-10 / D-23 |
| `ConfigFile` | built-in | Camera settings persistence | Safe vs `.tres` loading from `user://` |

### Supporting

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| Existing smoke harness (`attimo/tests/run.sh`, `run_smoke.gd`, `fixtures.gd`) | All automated checks | Every new test file under `tests/smoke/test_*.gd` |
| `tools/*.gd` headless scripts (`run.sh --tool`) | Metrics generation, gym generation | `tools/measure_movement.gd`, `tools/build_movement_gym.gd` |
| Debug Draw 3D 1.7.3 (CLAUDE.md addon list) | Visual raycast/vector debugging | **Not required for Phase 2.** Skip; keeps the phase free of third-party code |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `SpringArm3D` collision | Own `PhysicsDirectSpaceState3D.cast_motion` with a `SphereShape3D` in `_process` | Same node layout/interface; updates every frame and allows "snap in, ease out". Use if the 10-TPS corridor test fails (Pitfall 1). [ASSUMED: direct-space query from `_process` is permitted with default threading settings] |
| `PLATFORM_ON_LEAVE_ADD_VELOCITY` (engine default) | `DO_NOTHING` + manual carry | Manual carry survives the own-velocity pattern and is tunable (`platform_carry`). Engine default double-adds if you also carry manually |
| Polling `Input.is_action_just_pressed` for jump/dash | Event-stamped press times in `_input` | Polling is verified safe at 10 TPS; stamping is only needed for the latency probe |

**Installation:** none. No package manager step.

**Version verification:** `~/Applications/Godot_4.7.2/Godot.app/Contents/MacOS/Godot --version` prints `4.7.2.stable.official.ed1daf0bf` [VERIFIED: run this session].

## Package Legitimacy Audit

No external packages are installed in this phase (Phantom Camera is dropped by D-18; Debug Draw 3D and gdUnit4 are not adopted for Phase 2). The `package-legitimacy` gate is therefore not applicable.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| (none) | - | - | - | - | - | - |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
   OS input events
        |
        v
  Godot Input singleton ---- action state (polled in physics tick: jump/dash/sprint/move_*)
        |                \
        |                 \--> LatencyProbe._input (debug only): stamps usec for jump/dash press
        v
  CameraRig._unhandled_input  (mouse relative -> yaw/pitch, no delta; look-activity timer reset)
        |
        |  yaw (latest value)                              PHYSICS TICK (60 TPS default)
        v                                                 --------------------------------
  PlayerController._physics_process(delta)
     1. tick timers: coyote, jump buffer, chain window, dash cooldown, dash/air flags
     2. input_direction()  <-- camera yaw (Basis yaw-only) x Input.get_vector(move_*)
     3. StateMachine.physics_update  -> state writes move_velocity (Vector3 xz) / vertical_speed,
                                         may return next state name
     4. integrate: half-step gravity -> compose velocity -> dynamic floor_snap -> move_and_slide()
                   -> half-step gravity -> read floor/platform/wall/ceiling results
     5. post-move bookkeeping: landed (emit EventBus.landed), refill air options, coyote,
                               platform carry on leave, ceiling/wall velocity fix-up
        |
        +--> EventBus facts (jumped, landed, dash_started, movement_state_changed, + new facts)
        |         |--> EventLog (F3), LatencyProbe (compare stamp vs fact time), MetricsProbe
        |
        v
  Physics interpolation (engine) -> interpolated Player transform
        |
        v                                                 RENDER FRAME (display rate, 144 Hz)
  CameraRig._process(delta)     [top_level, physics_interpolation_mode = OFF]
     target = Player.get_global_transform_interpolated().origin + pivot_height
     horizontal follow (light damping) + vertical follow (smoothed, catches up on landing)
     auto-follow yaw (idle look > ~1 s, moving, lateral component only)  /  camera_recenter snap
     sum additive FOV + offset channels -> Camera3D.fov, SpringArm3D.position
        |
        v
  SpringArm3D (physics-rate cast, SphereShape3D, mask = World) -> Camera3D
```

### Recommended Project Structure

```
attimo/
├── scripts/
│   ├── core/                      # state.gd, state_machine.gd (existing), physics_layers.gd
│   ├── player/
│   │   ├── player_controller.gd   # velocity ownership + the single move_and_slide
│   │   ├── movement_config.gd     # class_name MovementConfig (Resource)
│   │   └── states/                # idle, run, sprint, jump, fall, dash (+ ground_state.gd / air_state.gd helpers)
│   ├── camera/
│   │   ├── camera_rig.gd          # class_name CameraRig
│   │   └── camera_settings.gd     # sensitivity + invert_y, ConfigFile load/save
│   ├── debug/                     # event_log.gd (existing), metrics_overlay.gd, latency_probe.gd, tuning_panel.gd
│   └── gym/                       # moving_platform.gd, fall_reset.gd (gym-only helpers; Phase 4 builds the real mechanisms)
├── resources/player/movement_default.tres   # the one shared MovementConfig instance
├── scenes/
│   ├── camera/camera_rig.tscn
│   ├── proto/                     # + Slope, Beam, ... wrappers (convex collision for slopes)
│   └── test/movement_gym.tscn     # generated by tools/build_movement_gym.gd
└── tools/
    ├── build_movement_gym.gd
    └── measure_movement.gd        # writes docs/MOVEMENT-METRICS.md
```

`scripts/camera/` and `scripts/gym/` are new folders: add them to the CONVENTIONS folder table. `scripts/camera/` is not scanned by the feedback guard (Phase 11 will need to extend that scan deliberately).

### Pattern 1: Own the velocity; one `move_and_slide()` (MOVE-01, MOVE-10)

**What:** `PlayerController` keeps `move_velocity: Vector3` (horizontal, x/z) and `vertical_speed: float`. Each tick it composes `velocity`, calls `move_and_slide()` once, then reads results. It never assigns the returned `velocity` back as the new state, except the horizontal part after a wall hit.
**Why:** Verified on 4.7.2/Jolt: with own horizontal velocity, a 10.5 m/s run up a 45 degree, 4 m ramp ends on the plateau with 0 airborne ticks at 60 TPS (max y 4.00) and 0 at 10 TPS (max y 4.23). Slope-projected returned velocity carries an upward component that launches at the ramp top; that is the classic "launch" bug (PITFALLS 3). [VERIFIED: probe2 ramp, this session]
**Rules the controller must implement itself because it owns velocity:**
- `if is_on_ceiling() and vertical_speed > 0.0: vertical_speed = 0.0`
- `if is_on_wall(): remove the move_velocity component along get_wall_normal()` (or copy the returned horizontal velocity only on a wall tick)
- on floor: `vertical_speed = 0.0` after capturing the impact speed
- `MovementConfig` is `@export`ed on the controller; all states read `actor.config`.

```gdscript
# Source: pattern verified by probes in this session (probe2/probe3); MovementConfig fields are start values [ASSUMED]
class_name MovementConfig
extends Resource
## The one tunable resource (MOVE-10). Edit live in the Remote inspector or the tuning panel.

@export_group("Ground")
@export_range(1.0, 20.0, 0.1) var run_speed: float = 7.0
@export_range(1.0, 3.0, 0.05) var sprint_multiplier: float = 1.5
@export_range(5.0, 200.0, 1.0) var ground_accel: float = 40.0
@export_range(5.0, 200.0, 1.0) var sprint_accel: float = 25.0
@export_range(5.0, 200.0, 1.0) var ground_decel: float = 55.0
@export_range(5.0, 300.0, 1.0) var turn_decel: float = 90.0   ## braking when input opposes velocity (the skid)

@export_group("Air")
@export_range(5.0, 200.0, 1.0) var air_accel: float = 35.0
@export_range(0.0, 1.0, 0.01) var air_drag: float = 0.0

@export_group("Jump")
@export_range(0.5, 6.0, 0.05) var jump_height: float = 2.5        ## full-hold height of the reference jump
@export_range(0.15, 1.0, 0.01) var jump_apex_time: float = 0.42   ## seconds to apex of the reference jump
@export_range(0.1, 3.0, 0.05) var jump_min_height: float = 0.8    ## tap height (velocity cut target)
@export_range(1.0, 3.0, 0.05) var fall_multiplier: float = 1.7
@export_range(5.0, 80.0, 1.0) var terminal_speed: float = 40.0
@export_range(0.0, 0.3, 0.01) var coyote_time: float = 0.1
@export_range(0.0, 0.3, 0.01) var jump_buffer_time: float = 0.12

@export_group("Floor")
@export_range(0.05, 1.5, 0.01) var snap_min: float = 0.3
@export_range(0.1, 2.0, 0.05) var snap_max: float = 1.2
@export_range(30.0, 60.0, 1.0) var floor_max_angle_deg: float = 50.0


## Derived, so editing height/time live updates the physics.
func gravity() -> float:
	return 2.0 * jump_height / (jump_apex_time * jump_apex_time)

func jump_speed(height: float) -> float:
	return sqrt(2.0 * gravity() * height)
```

### Pattern 2: Camera-relative input (MOVE-01)

`input_direction()` becomes: `Input.get_vector(...)` (existing action names `move_left/move_right/move_forward/move_back`) rotated by the camera's **yaw only**. Take the basis from `get_viewport().get_camera_3d()` (decoupled from the rig; falls back to world axes when no camera exists, which keeps tests camera-free): flatten `-cam.global_basis.z` onto XZ, normalize, build right as `Vector3.UP.cross(...)` negated appropriately, and combine. Keep the analog magnitude (`get_vector` returns a clamped Vector2; the controller scales target speed by its length so a controller works in Phase 13).

### Pattern 3: Jump from design numbers, half-step gravity, buffer/coyote (MOVE-03/04)

- Gravity and speeds from design numbers: `g = 2H / T^2`, `v0 = 2H / T` (reference jump H = 2.5 m, T = 0.42 s gives g = 28.34 m/s^2, v0 = 11.9 m/s). Other jump heights use the same `g`: `v0 = sqrt(2 g h)`.
- **Half-step gravity** inside the single move: `vy += g*dt*0.5; move_and_slide(); vy += g*dt*0.5` (Verlet). Verified apex for v0 = 10, g = 25: semi-implicit 1.500 / 1.833 / 1.917 / 1.958 m at 10 / 30 / 60 / 120 TPS vs half-step 2.000 at all four (analytic 2.000). Sampled apex error is bounded by `g*dt^2/8` (0.031 m at 10 TPS). [VERIFIED: probe2 _verlet]
- Fall gravity = `g * fall_multiplier` when `vertical_speed < 0`; clamp to `-terminal_speed`.
- Variable height: on `jump` release while `vertical_speed > cut_speed` set `vertical_speed = cut_speed` with `cut_speed = sqrt(2 g jump_min_height)`. This makes a tap reach about `jump_min_height` and a hold reach the stage height; chain stages only change the maximum (D-04).
- Timers decrement by `delta` in the controller, before the states run (so coyote/buffer are available to every state). Polling is enough: `is_action_just_pressed` caught a press+release that happened between two ticks at 10 TPS in the probe (`just_pressed=true pressed=false`). [VERIFIED: probe1 _tap, emulated with `parse_input_event` + `flush_buffered_events`]

### Pattern 4: Air-option rules (MOVE-05, MOVE-07, D-08)

Controller flags `air_jump_available: bool`, `air_dash_available: bool`, refilled in the post-move landing step (D-07). Recommended rules (Claude's discretion per CONTEXT):
- A jump press while grounded or inside coyote time = ground jump (consumes coyote, starts/advances the chain).
- A jump press while airborne **and past coyote** = the double jump, if `air_jump_available`. This includes walking off a ledge and never having jumped (the unused first jump is not banked beyond coyote).
- Air dash and double jump are independent flags: jump -> air dash -> double jump, double jump -> air dash, etc. all allowed, each at most once.
- Double jump sets `vertical_speed` (not additive) to `jump_speed(double_jump_height)` and keeps horizontal momentum; a held-button cut applies as in any jump.
- A buffered jump that fires on landing keeps `move_velocity` untouched (D-09: no deceleration frame). If the button was already released when the buffered jump fires, apply the cut immediately (tap height).

### Pattern 5: Dash and chain / long jump (MOVE-06/07, D-05/D-06/D-10/D-11)

- Dash is a timed state: `dash_speed * dash_time` is the distance (start 22 m/s x 0.18 s = 3.96 m). Each tick it sets `move_velocity = dir * dash_speed`; ground dash keeps floor snap; air dash sets `vertical_speed` to 0 (gravity scale tunable, start 0). Direction: input direction else `visual_root` facing; snap the facing first (existing `Dash.enter` already does this).
- Exit: `move_velocity = dir * lerp(run_speed, dash_speed, dash_carry)` clamped to a configurable `dash_exit_cap` so dash -> jump cannot produce an unbounded super-jump (PITFALLS 4). Cooldown starts on dash start (0.3-0.5 s, start 0.4).
- Tunnelling: not a concern with `move_and_slide`. Verified: speed 60 m/s into a 0.1 m wall at 10 TPS (6 m/tick) and at 60 TPS: final x = 9.45 (wall at 10), blocked in both. [VERIFIED: probe2 _tunnel] The walls in the gym are the Primitive_Wall piece (collision box 4 x 4 x 1) [VERIFIED: attimo/scenes/proto/primitive_wall.tscn `size = Vector3(4, 4, 1)`].
- Chain (controller state, not an FSM state): `chain_stage: int` 0..2 and `chain_timer`. A ground jump started inside the window advances the stage (cap 2); landing starts/refreshes the window (`chain_window`, start 0.35 s); window expiry or standing still (grounded, speed under threshold) resets to 0 (D-07). A **ground dash** inside the window keeps the stage and refreshes it. A jump during the dash or within `dash_jump_grace` (start 0.15 s) after it is a long jump of size `chain_stage` (0 = small, 2 = max): jump height, horizontal speed and arc come from three tunable rows (see start values). Jump cancels the dash.
- Interpretation of D-05 to confirm (Open Question 1): "Jump 1 -> land -> Jump 2 -> Dash -> Jump" is implemented as ground jump, ground jump, **ground** dash, jump (each step within the window). An air dash between jumps is a separate air option and does not carry a chain stage into a long jump.

### Pattern 6: Moving platforms, conveyors, slopes, stairs (MOVE-08, D-13)

- Platforms: `AnimatableBody3D` with `sync_to_physics = true`, moved only in `_physics_process`, collision layer World (1). Straight / circular / up-down are one script with a path mode and speed (`scripts/gym/moving_platform.gd`); join group `moving_platform` (remove "reserved" in CONVENTIONS).
- Conveyors: `StaticBody3D` with `constant_linear_velocity`. No script needed. [VERIFIED: probe1 _conveyor_static/_conveyor_animatable: player x = 1.45 after 30 ticks, `get_platform_velocity()` = (3.0, 0.0, 0.0) for both body types]
- Carry on leave: set `platform_on_leave = PLATFORM_ON_LEAVE_DO_NOTHING` and carry manually: after each grounded move store `get_platform_velocity()`; on the tick that goes from on-floor to off-floor (jump or walk-off) add `last_platform_velocity` (x/z, scaled by a tunable `platform_carry`, start 1.0) to `move_velocity`. Verified that `DO_NOTHING` adds nothing on leave while the default adds the platform's x-velocity (3.0) to `velocity`, which an own-velocity controller would overwrite. [VERIFIED: probe2 _leave_platform]. Whether to also add an upward platform velocity is untested: leave vertical out (docs: `ADD_UPWARD_VELOCITY` exists for lifts) and make it a tunable only if the gym shows eaten jump height on descending lifts. [CITED: docs.godotengine.org/en/stable/classes/class_characterbody3d.html]
- Slope snap: `floor_snap_length` must scale with speed. Measured on a 4 m 45 degree descent at 10.5 m/s: snap 0.1 -> 32 airborne ticks at 60 TPS; snap 0.4 -> 0 at 60 TPS; at 10 TPS (1.05 m/tick) snap 0.4 still gave 4-5 airborne ticks. [VERIFIED: probe3 _down]. Use `snap = clamp(horizontal_speed * delta * tan(floor_max_angle) + 0.1, snap_min, snap_max)` while grounded; the engine already skips snapping while the body moves upward [CITED: CharacterBody3D docs `floor_snap_length`], so jumps are not glued down.
- Stairs: `Primitive_Beam` (4 x 1 x 1) risers. Measured at 6 m/s, r = 0.5, `floor_max_angle` 50 degrees: climbs 0.10 and 0.15 m steps, blocked at 0.20 m and above (`h < r(1 - cos(angle))` = 0.178 m predicted). Descending ten 0.15 m steps at 10.5 m/s with snap 0.4: 0 airborne ticks at 60 TPS, 2 at 10 TPS. [VERIFIED: probe1 _steps, probe3 _stairs_down]. Gym stairs use 0.15 m risers; add a "ledge ladder" of 0.25/0.35/0.5 m blocks to document that taller ledges need a jump. Note a lower `floor_max_angle` (45 degrees = default) predicts only 0.146 m, so 0.15 m risers would fail; keep 50 degrees. [ASSUMED for the 45-degree figure: derived, not probed]
- Slopes available in the pack: `Primitive_Slope` is a 4 x 4 x 4 wedge (vertices (-2,0,-2) (-2,0,2) (-2,4,-2) (-2,4,2) (2,0,-2) (2,0,2): 45 degrees, rising toward -X) [VERIFIED: parsed `KayKit/KayKit_Prototype_Bits_1.1_FREE/.../Primitive_Slope.gltf`]. 45 degrees is under the 50 degree walk limit. For shallower ramps rotate a `Primitive_Floor` slab (e.g. 20 degrees). Slope wrappers need a `ConvexPolygonShape3D` (the wedge's six points), not a box.

### Pattern 7: Hand-built `CameraRig` (CAM-01, CAM-03, D-14..D-19)

- Node layout (D-18): `CameraRig (Node3D, yaw) > Pitch (Node3D) > SpringArm3D > Camera3D`, **a sibling of the Player, not a child**. `top_level = true`, `physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF` on the rig root (children inherit it recursively). [CITED: docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html]
- `_process(delta)`: `var anchor: Vector3 = target.get_global_transform_interpolated().origin + Vector3.UP * pivot_height`; horizontal part follows with exponential damping `1.0 - exp(-follow_rate * delta)` (light); the vertical part follows with a slower rate so jumps do not bob and the camera catches up on landing (D-15). Use delta-based exponentials everywhere (no per-frame `lerp(x, y, 0.1)`).
- Mouse look in `_unhandled_input` while `Input.mouse_mode == Input.MOUSE_MODE_CAPTURED`: `yaw -= event.relative.x * k`, `pitch -= event.relative.y * k` (k = `BASE_RAD_PER_PIXEL * sensitivity`, no delta, no smoothing), `pitch` clamped (start -1.2 rad .. +0.6 rad, negative = camera above looking down), invert-Y flips the pitch sign. Sign check by rotation math: rotation about X by `a` maps local +Z to (0, -sin a, cos a), so a negative pitch lifts the camera. [ASSUMED: derived by hand, confirm in the camera test]
- Auto-follow (D-16): keep `time_since_look`; any mouse motion (|relative| > 0) or future stick deflection resets it via one `notify_look_activity()` entry point. When `time_since_look > auto_follow_delay` (start 1.0 s) and horizontal speed > threshold: `lateral = move_dir.dot(rig_right)`; `yaw -= lateral * auto_follow_rate * delta`. Straight-ahead running gives lateral 0 (no rotation), sideways running pulls it along, and it can never fight the mouse because the timer gates it.
- Recenter (D-17): `camera_recenter` pressed -> ease `yaw` to the player's facing/velocity yaw over about 0.15 s, using an angle-aware move (`lerp_angle`).
- Additive contributions (D-18): `set_fov_offset(source: StringName, degrees: float)` and `set_offset(source: StringName, offset: Vector3)` store per-source values in `Dictionary[StringName, ...]`; `_process` sums them in a fixed order into `Camera3D.fov` and `SpringArm3D.position` (so the cast origin, hence collision, includes the offset). Phase 3 (aim blend) and Phase 11 (kick/shake) only register sources. No tween or "shake" word in code under the guarded folders.
- Wall collision: `SpringArm3D` with `shape = SphereShape3D` (radius about 0.25), `margin` about 0.1, `collision_mask = PhysicsLayers.WORLD` (so the player capsule on layer 2 is never hit), `spring_length` about 5. [CITED: SpringArm3D docs for margin/shape/collision_mask]
- **SpringArm3D internals (read from source, tag 4.7.2-stable):** it enables `set_physics_process_internal(true)`, runs `process_spring()` in `NOTIFICATION_INTERNAL_PHYSICS_PROCESS`, casts from `get_global_transform()` and writes every child with `child->set_global_transform(child_transform)`. It has no interpolation handling. [VERIFIED: raw.githubusercontent.com/godotengine/godot/4.7.2-stable/scene/3d/physics/spring_arm_3d.cpp:43-60,138-205]. Consequence: the child's *local* offset is set once per tick, so yaw/pitch/follow done in `_process` still move the camera every frame (the local offset is rotated by its parent), but the **collision pull-in length updates only on ticks** and uses the arm pose at tick time. At 60 TPS this is a 16 ms lag; at 10 TPS it is 100 ms and may let the lens clip briefly during a fast turn. See Pitfall 1 and Open Question 3.
- CAM-03 storage: `CameraSettings` (plain `RefCounted`/static helpers) with `sensitivity` (multiplier, default 1.0, range 0.1-3.0 [ASSUMED]) and `invert_y` (default false), persisted with `ConfigFile` to `user://settings.cfg` section `[camera]`, values clamped on load. A tiny debug panel (or `[`/`]` keys) edits them in the gym; Phase 7's menu reuses the same class.
- Mouse capture: set `MOUSE_MODE_CAPTURED` in `_ready` (guard `DisplayServer.get_name() != "headless"`), release on `pause` (Esc) and on `NOTIFICATION_APPLICATION_FOCUS_OUT`, recapture on click. Proper pause is Phase 7.

### Pattern 8: Measurement without touching gameplay code (MOVE-10, FEEL-06, D-21/D-22)

- **`MetricsProbe` (debug overlay, toggled by a new `debug_metrics` action, e.g. F4)** listens to `EventBus.jumped/landed/dash_started` and samples the player's position each physics tick; per airtime it records max height above take-off, horizontal distance take-off to landing, and for dashes start-to-end displacement. Follows the `EventLog` pattern (CanvasLayer scene + script under `scripts/debug/`).
- **`tools/measure_movement.gd`** (run with `bash attimo/tests/run.sh --tool res://tools/measure_movement.gd`): spawns a flat arena and a player, scripts inputs with `Input.action_press`/`release` counted in physics ticks (deterministic, no wall clock), measures the same table for run/sprint jump, tap jump, double jump, chain stages 0-2 long jumps, ground and air dash, and **writes `docs/MOVEMENT-METRICS.md`**. This makes the table reproducible instead of hand-copied. Gym markings stay as the manual cross-check (D-21).
- **`LatencyProbe` (debug)**: `_input` stamps `Time.get_ticks_usec()` on `jump`/`dash` presses (`event.is_action_pressed`); connects to `EventBus.jumped` / `dash_started` and logs `fact_time - stamp`; also connects `RenderingServer.frame_post_draw` once to log the first frame after the state change. Signal exists in 4.7.2. [VERIFIED: probe5 `frame_post_draw: true`]. Gameplay code is untouched because the facts already exist. Caveat to document (D-22): Godot stamps events when it dispatches them, not at the OS/hardware; screen and mouse latency are outside the number.
- Test hook: `Input.action_press()` does **not** produce an `InputEvent` for `_input`; tests that exercise the probe must send `InputEventAction` through `Input.parse_input_event()`. [VERIFIED: probe1 used `parse_input_event`; `_input` visibility is [ASSUMED] from the API contract]
- Expected software latency: input waits for the next physics tick, so mean about half a tick and worst about one tick plus a frame: roughly 8 / 17 ms at 60 TPS and 4 / 8 ms at 120 TPS, far inside 66 ms. [ASSUMED: arithmetic, to be measured]. `Input.use_accumulated_input` defaults to true (docs: events are merged and "emitted when the frame is done rendering"); set `false` in the gym to test whether it lowers measured latency. [VERIFIED default: probe5; CITED docs]

### Anti-Patterns to Avoid

- **Camera as a child of the player or driven from `_physics_process` with plain `global_position`:** stair-steps at 10 TPS (93% stationary frames measured).
- **Teleporting / tweening the player for a dash:** bypasses the swept move. Dash is velocity + `move_and_slide`.
- **A second `move_and_slide()` call** (e.g. in Dash state): violates the CONVENTIONS rule "exactly one `move_and_slide()` call, in `PlayerController._physics_process`, and states only set velocity" [VERIFIED: docs/CONVENTIONS.md "Player scene" section].
- **Storing the returned `velocity` as state:** slope launch / floor stick.
- **Processing mouse look by `delta`:** raw relative motion is already per-event; scaling by delta makes sensitivity frame-rate dependent.
- **Putting measurement calls in gameplay scripts:** probes listen to the bus.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tunnel protection for dash | Custom raycast sweep before moving | `move_and_slide()` (Jolt swept shape cast) | Verified blocked at 60 m/s, 10 and 60 TPS |
| Conveyor carry | Area3D + manual push scripts | `constant_linear_velocity` on a `StaticBody3D` | `get_platform_velocity()` already reports it (verified) |
| Moving-platform carry | Parenting the player to the platform or manual offset | `AnimatableBody3D` `sync_to_physics` + `move_and_slide` | Engine carries the body; verified x matches |
| Camera collision shape cast | Custom ray logic (first) | `SpringArm3D` with `SphereShape3D` | Locked by D-18; own cast only if the 10-TPS test fails |
| Frame-rate independent smoothing | `lerp(a, b, 0.1)` per frame | `1.0 - exp(-rate * delta)` | Per-frame lerp changes with FPS |
| Interpolated target position | Own previous/current transform blending | `Node3D.get_global_transform_interpolated()` | Exists in 4.7.2; verified smooth at 10 TPS |
| Settings file format | Loading a `.tres` from `user://` | `ConfigFile` | A user-writable `.tres` can embed a script |
| Tuning UI | A full custom editor | Remote scene inspector on the shared `MovementConfig`, optional small panel generated from `get_property_list()` | The game window is separate from the editor, so remote edits work while playing |
| State machine addon | LimboAI / State Charts | Phase 1 `StateMachine` + `State` | Locked by CLAUDE.md |
| Stair step-up | Custom step-up raycasts | Gym risers <= 0.15 m (capsule climbs them) | Explicit step-up is out of scope; document the limit instead |

**Key insight:** every "hard" requirement in this phase (no tunnelling, platform carry, conveyors, camera interpolation) is already solved by the engine primitives; the work is wiring them in the right order and proving it with numbers.

## Runtime State Inventory

Not a rename/refactor phase. Greenfield additions plus edits to Phase 1 scaffolding. Nothing stored outside git carries a renamed string. The only persistent runtime state introduced is `user://settings.cfg` (camera sensitivity/invert-Y), created at first run. Build artifacts: the `.godot/` import cache regenerates via `run.sh --import`.

## Common Pitfalls

### Pitfall 1: SpringArm3D collision lags at low tick rates
**What goes wrong:** At 10 TPS the camera's wall pull-in updates every 100 ms and is computed from the arm pose at tick time; the lens can briefly poke through a wall during a fast turn, and the arm length visibly steps.
**Why it happens:** `process_spring()` is `NOTIFICATION_INTERNAL_PHYSICS_PROCESS` only (source above).
**How to avoid:** Keep SpringArm3D (D-18). Add an acceptance test: rig in a tight corridor (gym "narrow passage"), orbit at 10 TPS, assert `get_hit_length()` never exceeds the free distance by more than a small tolerance after a tick, and eyeball it at 10 TPS. If it fails, replace the arm's logic inside `CameraRig` with a `cast_motion` (SphereShape3D) in `_process` with "instant in, eased out" lengthening; the rig interface (yaw, pitch, fov/offset channels) does not change.
**Warning signs:** camera pops through corners only at low TPS; arm length changes in steps.

### Pitfall 2: Returned `velocity` as state
**What goes wrong:** Launching at ramp tops, sticking to floors, losing speed on slopes.
**How to avoid:** Pattern 1. Verified the own-velocity version stays grounded over a 45 degree ramp top at sprint speed.

### Pitfall 3: Platform momentum overwritten
**What goes wrong:** With the engine default `ADD_VELOCITY`, the engine adds platform velocity to `velocity` on the leaving tick; a controller that rebuilds `velocity` from `move_velocity` each tick discards it, so the carry is lost or doubled.
**How to avoid:** `DO_NOTHING` + manual carry (Pattern 6). Test: stand on a 3 m/s conveyor, jump, assert horizontal speed about 3 m/s after leaving.

### Pitfall 4: Tick-rate dependent jump height
**What goes wrong:** Semi-implicit gravity lowers the jump at low TPS (apex 1.5 m vs 2.0 m at 10 TPS). The 10 TPS jitter test and the 60/120 TPS latency test then run on different physics.
**How to avoid:** Half-step gravity; unit test asserting apex within `g*dt^2/8 + epsilon` at 10/60/120 TPS.

### Pitfall 5: Floor snap too short at sprint speed, or too long
**What goes wrong:** Airborne flicker running down slopes (snap 0.1: 32 airborne ticks); or the player gluing to floors when walking off ledges if snap is huge.
**How to avoid:** Speed-scaled snap clamped to `[snap_min, snap_max]`; coyote timer must not start from snap re-attachment; `is_on_floor()` flicker is a debug-overlay line.

### Pitfall 6: Existing Phase 1 tests encode "the body never moves"
**What goes wrong:** `test_scene_run` (player position equals spawn, velocity zero, exactly one scriptless `Camera3D`, 20-wall ring, `application/run/main_scene == test_scene`), `test_movement_facts` ("Fall emits landed after a timer", player never moves), `test_jump_fact`, `test_dash_fact` and `test_mannequin_animation` will fail once movement is real. [VERIFIED: attimo/tests/smoke/test_scene_run.gd (reads: ring of 20 walls, `cameras[0].get_script() == null`, spawn check, `player velocity is zero`)]
**How to avoid:** Plan these edits explicitly: decide whether the gym replaces `test_scene.tscn` or becomes a new main scene; rewrite those five tests to the new behaviour (timer-driven fall removed, real floor needed, `Fixtures` gains a floor helper). The baseline is green: 13 files, 464 checks, about 19 s (`bash attimo/tests/run.sh`, run this session).

### Pitfall 7: Animator mapping silently falls back
**What goes wrong:** `MannequinAnimator.STATE_TO_ANIM.get(to_state, &"Locomotion")` maps any unknown new state (Sprint, DoubleJump, AirDash, LongJump) to Locomotion; the airborne check `from_state == &"Jump" or from_state == &"Fall"` misses new airborne states, so landing plays the wrong clip. [VERIFIED: attimo/scripts/player/mannequin_animator.gd:8-15,31-36]. Also the AnimationTree has no `Jump -> Jump` transition (double jump while in Jump will not replay) [VERIFIED: attimo/scenes/player/mannequin_state_machine.tres transitions list].
**How to avoid:** Phase 2 adds explicit minimal entries (Sprint -> Locomotion with blend 1.0, DoubleJump/LongJump -> Jump, AirDash -> Dash) and extends the airborne set; the proper mapping/flip/lean stays Phase 3. Keep a single `AIRBORNE_STATES` constant.

### Pitfall 8: Prototype Bits wrappers and the asset whitelist
**What goes wrong:** Only 4 pieces are copied into `attimo/assets/prototype_bits/`; the gym needs Slope (and optionally Beam, Cube, Floor_Hole). Adding files without updating `WHITELIST` and its `== 25` count fails `test_asset_hygiene`; slope wrappers with a box collider are wrong; `test_proto_pieces` only covers the original four boxes. [VERIFIED: attimo/tests/smoke/test_asset_hygiene.gd:11-39,61; test_proto_pieces.gd WRAPPERS]
**How to avoid:** Copy (never move) from `KayKit/KayKit_Prototype_Bits_1.1_FREE/KayKit_Prototype_Bits_1.1_FREE/Assets/gltf/` and add `.gltf`, `.gltf.import`, `.bin` per piece to the whitelist and change the count in the same commit.

### Pitfall 9: Buffered jump released before landing; coyote vs double jump
**What goes wrong:** A press buffered, released, then fired on landing becomes a full-height jump; or coyote leaves a "free" extra jump.
**How to avoid:** Check `Input.is_action_pressed(&"jump")` at fire time and apply the cut immediately if released; consume coyote and the buffer on every ground jump; rules in Pattern 4.

### Pitfall 10: Tests that need `_input`
**What goes wrong:** `Fixtures.tap_action` uses `Input.action_press`, which never reaches `_input`/`_unhandled_input`; camera and latency tests see nothing.
**How to avoid:** Add `Fixtures` helpers that send `InputEventAction` / `InputEventMouseMotion` through `Input.parse_input_event` (after `flush_buffered_events` if needed).

### Pitfall 11: Teleports (gym reset) leave an interpolation streak
**How to avoid:** A gym fall-reset sets `global_position`, zeroes velocities and calls `reset_physics_interpolation()` in that order. [CITED: using_physics_interpolation docs]

### Pitfall 12: Dash into jump exploit and facing
**How to avoid:** Clamp exit speed (`dash_exit_cap`); long-jump speed comes from tunable rows, not from stacking `dash_speed`.

## Code Examples

### Existing values this phase builds on (read this session)

```
# attimo/project.godot (Input Map + layers + physics)
move_back / move_forward / move_left / move_right / jump / sprint / dash / aim / use_hand / interact / pause
look_down={ "deadzone": 0.2, "events": [] }          # look_left, look_right, look_up likewise: no events
3d_physics/layer_1="World"   3d_physics/layer_2="Player"
3d/physics_engine="Jolt Physics"
common/physics_interpolation=true

# attimo/autoload/event_bus.gd
signal jumped(position: Vector3)
signal landed(position: Vector3, impact_speed: float)
signal dash_started(position: Vector3, direction: Vector3, in_air: bool)
signal movement_state_changed(from_state: StringName, to_state: StringName)

# attimo/scenes/player/player.tscn
radius = 0.5
height = 2.0
collision_layer = 2
collision_mask = 1
```
[VERIFIED: attimo/project.godot:28-115,119-129; attimo/autoload/event_bus.gd:5-8; attimo/scenes/player/player.tscn]. `Mannequin_Medium` is about 2.2 m tall and the doc says the capsule "is a valid body shape only in Phase 1; Phase 2 retunes it" [VERIFIED: docs/CONVENTIONS.md "Player scene"].

### Controller integration tick (Pattern 1/3/6)

```gdscript
# Source: assembled from probe-verified behaviour (probe2/probe3); structure is a recommendation
func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	state_machine.physics_update(delta)   # states write move_velocity / vertical_speed, may request a transition
	_integrate(delta)


func _integrate(delta: float) -> void:
	var g: float = config.gravity() * (config.fall_multiplier if vertical_speed < 0.0 else 1.0)
	vertical_speed = maxf(vertical_speed - g * delta * 0.5, -config.terminal_speed)
	velocity = Vector3(move_velocity.x, vertical_speed, move_velocity.z)
	var speed_h: float = Vector2(move_velocity.x, move_velocity.z).length()
	floor_snap_length = clampf(speed_h * delta * tan(deg_to_rad(config.floor_max_angle_deg)) + 0.1, config.snap_min, config.snap_max)
	move_and_slide()
	vertical_speed = maxf(vertical_speed - g * delta * 0.5, -config.terminal_speed)
	_post_move()


func _post_move() -> void:
	var on_floor: bool = is_on_floor()
	if is_on_ceiling() and vertical_speed > 0.0:
		vertical_speed = 0.0
	if is_on_wall():
		var n: Vector3 = get_wall_normal()
		var into: float = move_velocity.dot(n)
		if into < 0.0:
			move_velocity -= n * into
	if on_floor and not _was_on_floor:
		var impact: float = maxf(-vertical_speed, 0.0)
		_land(impact)                     # refill air options, start chain window, EventBus.landed.emit(global_position, impact)
	if _was_on_floor and not on_floor:
		_leave_floor()                    # coyote timer, add platform carry to move_velocity (platform_on_leave = DO_NOTHING)
	if on_floor:
		vertical_speed = 0.0
		_last_platform_velocity = get_platform_velocity()
	_was_on_floor = on_floor
```

### Interpolated camera follow + automated jitter proxy (Pattern 7)

```gdscript
# CameraRig: top_level, interpolation OFF, runs in _process
func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

func _process(delta: float) -> void:
	var anchor: Vector3 = target.get_global_transform_interpolated().origin + Vector3.UP * pivot_height
	var k: float = 1.0 - exp(-follow_rate * delta)
	global_position.x = lerpf(global_position.x, anchor.x, k)
	global_position.z = lerpf(global_position.z, anchor.z, k)
	global_position.y = lerpf(global_position.y, anchor.y, 1.0 - exp(-vertical_follow_rate * delta))
```

```gdscript
# Smoke test sketch: stair-step ratio at 10 TPS. Probe result: interpolated rig 0 of 272 frames stationary,
# plain global_position rig 253 of 272 (93%).
Engine.physics_ticks_per_second = 10
# ...move the player at constant velocity, sample rig.global_position every process frame for ~1.5 s...
# assert stationary_frames / frames < 0.05, then restore Engine.physics_ticks_per_second = 60
```
[VERIFIED: probe4, this session]. Camera-vs-wall check at 10 TPS goes in the same file (Pitfall 1).

### Latency probe core (Pattern 8)

```gdscript
# scripts/debug/latency_probe.gd - listens only; gameplay stays untouched
var _stamp_usec: int = 0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"jump") or event.is_action_pressed(&"dash"):
		_stamp_usec = Time.get_ticks_usec()

func _on_jumped(_position: Vector3) -> void:
	_log("jump", (Time.get_ticks_usec() - _stamp_usec) / 1000.0)
```

## Start Values (all `[ASSUMED]`, tuned in the gym; stored in `MovementConfig`)

Hero is about 2.2 m tall with a 0.5 m radius capsule; grid pieces are 4 m / 1 m. Predicted from the formulas above (computed this session, landing at take-off height, `fall_multiplier` 1.7, g = 28.34 m/s^2 from H = 2.5 m, T = 0.42 s):

| Item | Start value | Predicted result |
|------|-------------|------------------|
| Run speed / sprint multiplier | 7.0 m/s / 1.5 (10.5 m/s) | - |
| Ground accel / sprint accel / decel / turn decel | 40 / 25 / 55 / 90 m/s^2 | run reached in about 0.18 s, sprint about 0.42 s |
| Air accel | 35 m/s^2 (D-02 near-full control) | - |
| Jump 1 height | 2.0 m (stage rows: 2.0 / 2.6 for chain stage 1) | v0 10.65, airtime 0.66 s, distance 4.65 m run / 6.97 m sprint |
| Jump 2 (chain) height | 2.6 m | airtime 0.76 s, 7.95 m at sprint |
| Tap jump (min) | 0.8 m, cut speed 6.73 m/s | airtime 0.42 s, 2.94 m at run |
| Double jump | 2.0 m, vy set (not additive) | 6.97 m at sprint |
| Coyote / buffer / chain window / dash-jump grace | 0.10 s / 0.12 s / 0.35 s / 0.15 s | - |
| Dash | 22 m/s x 0.18 s = 3.96 m, cooldown 0.4 s, exit carry 0.5, air gravity scale 0 | per tick travel 0.37 m at 60 TPS, 2.2 m at 10 TPS (safe, swept) |
| Long jump small / mid / max | height 1.0 / 1.2 / 1.4 m; speed 14 / 15 / 17 m/s | 6.6 / 7.7 / 9.4 m |
| Terminal speed | 40 m/s | - |
| Camera | distance 5 m, pivot height 1.6 m, FOV 75, follow rate 14, vertical follow rate 6, pitch -1.2 .. +0.6 rad, auto-follow delay 1.0 s, rate about 1.4 rad/s at full lateral, recenter 0.15 s, sensitivity base 0.0022 rad/px x multiplier 1.0 | - |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phantom Camera (CLAUDE.md stack) | Hand-built `CameraRig` | D-18, 2026-11-04 | Planner edits CLAUDE.md camera row + addon table, the STATE.md Phase 2 blocker, ROADMAP Phase 2 notes ("Spike Phantom Camera ..."), and REQUIREMENTS CAM-01 wording |
| Camera as child + `_physics_process` follow | Top-level rig, `_process`, `get_global_transform_interpolated()` | Godot 4.4 interpolation docs | 0% stationary frames at 10 TPS (verified) |
| Semi-implicit Euler jump | Half-step (Verlet) gravity | this phase | Tick-rate independent apex |

**Deprecated/outdated:** The CAM-01 wording "over-the-shoulder" (D-14: centered third-person follow; shoulder offset only in aim mode, Phase 3). Phantom Camera in the CLAUDE.md addon list.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | All start values (speeds, accel, jump/dash/long-jump numbers, camera constants) | Start Values | Low: they are tuning inputs; the gym replaces them |
| A2 | `PhysicsDirectSpaceState3D.cast_motion` may be called from `_process` with default threading settings | Alternatives, Pitfall 1 fallback | Medium: fallback camera collision would need to move to the tick; confirm in the first camera plan |
| A3 | Pitch sign convention (negative pitch = camera above) and mouse sign mapping | Pattern 7 | Low: camera test asserts it |
| A4 | 45 degree `floor_max_angle` predicts only 0.146 m auto-step | Pattern 6 | Low: derived formula; 50 degrees is probed |
| A5 | Software latency about 8 ms mean / 17 ms worst at 60 TPS | Pattern 8 | Low: measured by the probe |
| A6 | Rule that an unused first jump past coyote becomes the double jump | Pattern 4 | Medium: affects feel/MOVE-05 test wording; confirm in discuss/plan |
| A7 | D-05 chain interpretation: ground jump, ground jump, ground dash, jump | Pattern 5 | Medium: see Open Question 1 |
| A8 | Platform upward velocity on leave is not needed | Pattern 6 | Low: tunable if lifts eat jumps |
| A9 | `Input.use_accumulated_input = false` lowers key-press latency | Pattern 8 | Low: measured, optional |
| A10 | Sensitivity multiplier range 0.1-3.0 and base 0.0022 rad/px | Pattern 7 | Low: UX-03 sets final range |
| A11 | Direct-space-state / `_input` visibility of `InputEventAction` in `_input` for tests | Pattern 8 | Low |

## Open Questions (RESOLVED)

All six questions are resolved by the Phase 2 plans; each resolution is a flagged plan assumption (A1-A6) that the developer can veto at review or at the gym sign-off.

1. **D-05 chain: is the "Dash" in "Jump 1 -> Jump 2 -> Dash -> Jump" a ground dash or an air dash?**
   - What we know: D-06 says a jump during/right after a plain *ground* dash is a small long jump; D-08 treats the air dash as a separate air option.
   - What's unclear: whether the dash in the chain happens after landing from Jump 2 (ground) or in the air.
   - Recommendation: implement as ground dash inside the landing window (Pattern 5), record three long-jump rows in the metrics doc, and let the gym sign-off decide. Cheap to change (it is a config/state-flag question).
   - RESOLVED: ground dash inside the landing window; an air dash between jumps is a separate air option and never carries a chain stage into a long jump (plan 02-11, assumption A1).
2. **Capsule size vs the 2.2 m Mannequin.** CONVENTIONS says Phase 2 retunes the capsule; the step-height result depends on radius. Recommendation: keep radius 0.5, test height 2.0 vs 2.2 in the gym; if radius changes, redo the step table.
   - RESOLVED: the capsule stays radius 0.5 m, height 2.0 m for Phase 2; the gym sign-off re-checks it against the Mannequin in the low-ceiling passage, and a change becomes a follow-up that redoes the step table (plans 02-01, 02-02, 02-14, assumption A2).
3. **Does SpringArm3D's physics-rate pull-in pass the 10-TPS corridor test?** Recommendation: build it as specified, run the test, and keep the `cast_motion`-in-`_process` fallback ready (same rig interface).
   - RESOLVED: SpringArm3D is built and tested in the 10-TPS and 60-TPS corridor; if it fails, the rig switches to a per-frame shape cast in `_process` with the SpringArm3D's own mask set to 0, without changing the node layout or public API (plan 02-06, assumption A3).
4. **Stairs policy.** Recommendation: risers <= 0.15 m, no explicit step-up code; document the 0.18 m limit in `docs/MOVEMENT-METRICS.md`. If the user wants taller auto-steps, that is a new task, not part of this phase.
   - RESOLVED: gym risers are at most 0.15 m with no step-up code; the 0.18 m theoretical limit and the 0.25 m "needs a jump" ledge are documented in CONVENTIONS and MOVEMENT-METRICS (plans 02-02, 02-07, 02-13, assumption A4).
5. **Dash key.** CONVENTIONS keeps both Q and Left Ctrl ("decide in tuning"). Recommendation: keep both until the gym sign-off.
   - RESOLVED: both Q and Left Ctrl stay bound; the developer names the preferred key at the gym sign-off and a change is a follow-up (plans 02-02, 02-09, 02-14, assumption A5).
6. **Unused first jump past coyote time (Assumptions Log A6: "confirm in discuss/plan").** Does walking off a ledge and pressing jump after coyote time give a ground jump, the double jump, or nothing?
   - RESOLVED: it uses the one air jump (it becomes the double jump); the first jump is not banked beyond coyote time (plan 02-05, assumption A6, pinned by test_jump).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Godot 4.7.2 standard | everything | yes | 4.7.2.stable.official.ed1daf0bf (matches `run.sh` gate) | none needed |
| `bash attimo/tests/run.sh` | validation | yes | baseline green: 13 test files, 464 checks, about 19 s | - |
| Headless display (`DisplayServer` = headless) | automated tests | yes | confirmed in probe5 | - |
| python3 | optional helpers (not required by the game) | yes | /opt/homebrew/bin/python3 | - |
| 144 Hz display | manual CAM-01 check | unknown | - | Automated proxy (stair-step ratio at uncapped FPS) + human checkpoint at end-of-phase |
| Gamepad | controller later | n/a | Phase 13 | - |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** 144 Hz monitor (use automated proxy, human verify when available).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Project smoke harness (`RefCounted` tests with `run(tree, check)`), engine 4.7.2 headless [VERIFIED: attimo/tests/run_smoke.gd] |
| Config file | none - `attimo/tests/run.sh`, auto-discovers `tests/smoke/test_*.gd` |
| Quick run command | `bash attimo/tests/run.sh <filter>` (comma-separated substrings) |
| Full suite command | `bash attimo/tests/run.sh` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MOVE-01 | accel/decel reach run speed in expected time; reversal brakes harder; input is camera-relative (rotate camera yaw, direction follows) | integration | `bash attimo/tests/run.sh test_ground_movement` | Wave 0 |
| MOVE-02 | sprint speed ~1.5x run, release returns to run | integration | same file | Wave 0 |
| MOVE-03 | tap apex < hold apex; fall time < rise time; apex tick-rate independent (10/60/120 TPS) | integration | `bash attimo/tests/run.sh test_jump` | Wave 0 |
| MOVE-04 | coyote jump after ledge; buffered jump fires on landing keeping horizontal speed | integration | same | Wave 0 |
| MOVE-05 | exactly one air jump per airtime; refilled on landing | integration | same | Wave 0 |
| MOVE-06 | ground dash distance within tolerance of speed x time; cooldown blocks re-dash | integration | `bash attimo/tests/run.sh test_dash` | Wave 0 |
| MOVE-07 | one air dash; refill on landing; dash -> jump is a long jump with farther distance than a plain jump; chain stages order small < mid < max; no tunnelling into a wall at 10 and 60 TPS | integration | same | Wave 0 |
| MOVE-08 | conveyor/platform carry, momentum on leave, ramp and 0.15 m stairs without airborne ticks | integration | `bash attimo/tests/run.sh test_platforms` | Wave 0 |
| MOVE-10 | `MovementConfig` loads, derived gravity/speeds match formulas, metrics doc generated | unit + tool | `bash attimo/tests/run.sh test_movement_config` ; `bash attimo/tests/run.sh --tool res://tools/measure_movement.gd` | Wave 0 |
| CAM-01 | rig is top-level, not under the player, interpolation OFF; stair-step ratio < 5% at 10 TPS and uncapped fps; wall pull-in (`get_hit_length()` < spring length near a wall); pitch clamp | integration | `bash attimo/tests/run.sh test_camera_rig` | Wave 0 |
| CAM-03 | mouse motion sign, sensitivity scales, invert-Y flips, settings round-trip through `ConfigFile` and clamp bad values | unit | same | Wave 0 |
| FEEL-06 | `InputEventAction` jump/dash -> fact latency <= 100 ms hard at 60 and 120 TPS (record vs 66 ms target) | integration | `bash attimo/tests/run.sh test_latency` | Wave 0 |
| D-17 | `camera_recenter` exists, bound to middle mouse, in CONVENTIONS | unit | `bash attimo/tests/run.sh test_input_map,test_conventions` | edit existing |

Existing tests that must be updated in the same plans: `test_scene_run`, `test_movement_facts`, `test_jump_fact`, `test_dash_fact`, `test_mannequin_animation`, `test_input_map` (add `camera_recenter`, new debug actions), `test_conventions`, `test_asset_hygiene` (whitelist + count), `test_proto_pieces` (new wrappers). `Fixtures` gains a floor helper and `parse_input_event` helpers.

Manual-only (justified): subjective feel sign-off in the gym ("without juice"), visual 144 Hz judder check, real hardware latency, corridor camera feel.

### Sampling Rate
- **Per task commit:** `bash attimo/tests/run.sh <touched test names>`
- **Per wave merge:** `bash attimo/tests/run.sh`
- **Phase gate:** full suite green, `measure_movement.gd` run and `docs/MOVEMENT-METRICS.md` committed, gym play-through (human), before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `attimo/tests/fixtures.gd` - floor helper, `send_action_event`, `send_mouse_motion`
- [ ] new test files listed above (`test_movement_config`, `test_ground_movement`, `test_jump`, `test_dash`, `test_platforms`, `test_camera_rig`, `test_latency`)
- [ ] Existing Phase 1 tests rewritten (Pitfall 6)
- [ ] Time budget: each real-time jump scenario takes about 1-1.5 s; budget roughly 40-60 s extra for the suite (current full run about 19 s)

## Security Domain

Offline single-player game; no network, accounts or secrets. `security_enforcement` is enabled (ASVS level 1), so the relevant surface is small.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | - |
| V3 Session Management | no | - |
| V4 Access Control | no | - |
| V5 Input Validation | yes (local files) | Clamp every value read from `user://settings.cfg` (`clampf`, type-check `get_value` results); never trust the file |
| V6 Cryptography | no | - |
| V12 Files and Resources | yes | Persist with `ConfigFile` (data only); do **not** `load()` a `.tres`/`.res` from `user://` (a Resource can embed a script) |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Tampered `user://` settings file (out-of-range sensitivity -> NaN/inf camera) | Tampering / DoS | Clamp to valid ranges, fall back to defaults on parse error |
| Resource-with-script loaded from a user-writable path | Elevation of Privilege | Use `ConfigFile`; keep `MovementConfig` only under `res://` |
| Debug tooling shipping in release | Information disclosure | Debug scenes/actions under `scripts/debug/`, stripped in REL-03 (Phase 15); keep the `debug_` action prefix |

## Plan-level doc edits the planner must include

- `CLAUDE.md`: camera row (Phantom Camera -> hand-built `CameraRig`, SpringArm3D), addon table (drop Phantom Camera; Debug Draw 3D optional), installation comments.
- `.planning/STATE.md`: remove/replace the "[Phase 2]: Spike needed: Phantom Camera ..." blocker.
- `.planning/ROADMAP.md` Phase 2: success criterion 1 wording ("over-the-shoulder" -> third-person follow), Notes ("Spike Phantom Camera ..." removed; "additive FOV/offset" stays).
- `.planning/REQUIREMENTS.md` CAM-01: wording per D-14.
- `docs/CONVENTIONS.md`: `camera_recenter` row, new debug actions, folders `scripts/camera/`, `scripts/gym/`, `resources/`, group `moving_platform` no longer reserved, new facts in the event-bus table, capsule retune note, platform/camera rules.
- `attimo/project.godot`: `camera_recenter` (middle mouse, button index 3) and the debug actions (metrics overlay, TPS cycle, gym reset) with the `debug_` prefix.
- New EventBus facts (emit-only, add new signals rather than changing `jumped`): `double_jumped`, `long_jumped(position, stage)`, `chain_stage_changed(stage)` as needed; update the CONVENTIONS table.

## Sources

### Primary (HIGH confidence)
- Probes run on the pinned engine (4.7.2, Jolt, interpolation on), this session, scripts in the session scratchpad: conveyor and platform carry, step height, tunnelling, ramp up/down, leave-platform modes, gravity integrators, interpolated vs plain camera follow, tap-between-ticks, API existence.
- Godot 4.7.2-stable source `scene/3d/physics/spring_arm_3d.cpp` (raw.githubusercontent.com/godotengine/godot/4.7.2-stable/...) - physics-rate cast, child transform write.
- Repository files read: `attimo/project.godot`, `attimo/scripts/player/*`, `attimo/scripts/core/*`, `attimo/autoload/event_bus.gd`, `attimo/scenes/player/player.tscn`, `attimo/scenes/proto/*`, `attimo/tests/*`, `docs/CONVENTIONS.md`, `.planning/research/PITFALLS.md`, `GAME-FEEL.md`, `KayKit_Prototype_Bits` glTF accessors.

### Secondary (MEDIUM confidence)
- https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html - camera section, `physics_interpolation_mode`, `get_global_transform_interpolated()`, top-level camera.
- https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html - tick-only motion, `reset_physics_interpolation()` order.
- https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html - `platform_on_leave` modes, `floor_snap_length` skipped while moving upward, `get_platform_velocity()`.
- https://docs.godotengine.org/en/stable/classes/class_springarm3d.html - margin, shape, collision_mask, `add_excluded_object`.
- https://docs.godotengine.org/en/stable/classes/class_input.html - `use_accumulated_input`, `is_action_just_pressed` physics-tick wording, `MOUSE_MODE_CAPTURED` / `relative`.
- https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html - ghost collision handling (does not cover CharacterBody3D specifics).

### Tertiary (LOW confidence)
- Feel numbers adapted from the project's own `.planning/research/GAME-FEEL.md` / `PITFALLS.md` (practitioner heuristics); all tagged [ASSUMED] above.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all built-in, locked by CLAUDE.md/CONTEXT, no packages.
- Architecture: HIGH for engine behaviour (probed), MEDIUM for SpringArm3D at low TPS until the corridor test runs.
- Pitfalls: HIGH - most are reproduced numerically; Phase 1 test conflicts read directly from the repo.
- Feel values: LOW-MEDIUM - starting points only, by design.

**Research date:** 2026-11-04
**Valid until:** 2026-12-04 (engine pinned at 4.7.2; behaviour will not drift unless the engine version changes)
