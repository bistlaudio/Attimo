---
phase: 02-movement-core-follow-camera
verified: 2026-11-06T12:00:00Z
status: human_needed
score: 5/5 roadmap success criteria verified in code and tests; 1 criterion part (144 Hz judder) and 1 provisional item (hardware latency) await human check
covered_files:
  - .planning/phases/02-movement-core-follow-camera/02-01-PLAN.md
  - .planning/phases/02-movement-core-follow-camera/02-01-SUMMARY.md
  - .planning/phases/02-movement-core-follow-camera/02-02-PLAN.md
  - .planning/phases/02-movement-core-follow-camera/02-02-SUMMARY.md
  - .planning/phases/02-movement-core-follow-camera/02-03-PLAN.md
  - .planning/phases/02-movement-core-follow-camera/02-03-SUMMARY.md
  - .planning/phases/02-movement-core-follow-camera/02-04-PLAN.md
  - .planning/phases/02-movement-core-follow-camera/02-04-SUMMARY.md
  - .planning/phases/02-movement-core-follow-camera/02-05-PLAN.md
  - .planning/phases/02-movement-core-follow-camera/02-05-SUMMARY.md
  - .planning/phases/02-movement-core-follow-camera/02-06-PLAN.md
  - .planning/phases/02-movement-core-follow-camera/02-06-SUMMARY.md
  - .planning/phases/02-movement-core-follow-camera/02-07-PLAN.md
  - .planning/phases/02-movement-core-follow-camera/02-07-SUMMARY.md
  - .planning/phases/02-movement-core-follow-camera/02-08-PLAN.md
  - .planning/phases/02-movement-core-follow-camera/02-08-SUMMARY.md
  - .planning/phases/02-movement-core-follow-camera/02-09-PLAN.md
  - .planning/phases/02-movement-core-follow-camera/02-09-SUMMARY.md
  - .planning/phases/02-movement-core-follow-camera/02-10-PLAN.md
  - .planning/phases/02-movement-core-follow-camera/02-10-SUMMARY.md
  - .planning/phases/02-movement-core-follow-camera/02-11-PLAN.md
  - .planning/phases/02-movement-core-follow-camera/02-11-SUMMARY.md
  - .planning/phases/02-movement-core-follow-camera/02-12-PLAN.md
  - .planning/phases/02-movement-core-follow-camera/02-12-SUMMARY.md
  - .planning/phases/02-movement-core-follow-camera/02-13-PLAN.md
  - .planning/phases/02-movement-core-follow-camera/02-13-SUMMARY.md
  - .planning/phases/02-movement-core-follow-camera/02-14-PLAN.md
  - .planning/phases/02-movement-core-follow-camera/02-14-SUMMARY.md
  - attimo/scenes/test/movement_gym.tscn
  - attimo/scripts/camera/camera_rig.gd
  - attimo/scripts/player/movement_config.gd
  - attimo/scripts/player/player_controller.gd
  - docs/MOVEMENT-METRICS.md
covered_digest: "v4:sha256:89525c09c2d412bd4fb56e3dac94db9bfb56a2c4116f556df394a108e4e45e77"
behavior_unverified: 0
overrides_applied: 0
re_verification: false
human_verification:
  - test: "MANDATORY 144 Hz judder check (02-14 sign-off item 7): open the movement gym on a 144 Hz display with V-Sync on, turn the camera and run through the pillar forest at 60 TPS and at 10 TPS (F6 cycles the tick rate). Record pass/fail and the display used."
    expected: "The camera follows the Mannequin without visible judder or stutter at 144 Hz, at 60 and 10 TPS."
    why_human: "Needs a real 144 Hz display. The developer only has a Mac and could not check it. The headless jitter test in test_camera_rig (0.0 % unmoved frames at 10 and 60 TPS) is only a proxy for render-rate judder."
  - test: "Re-check hardware input latency (02-14 sign-off item 8) on the dev machine: judge how immediate jump and dash feel."
    expected: "Jump and dash respond without perceptible delay (target <= 66 ms end to end, hard limit 100 ms)."
    why_human: "Signed off only provisionally ('ja an sich'). Display, compositor and USB latency are outside the software measurement (D-22). The software latency is asserted (medians 6.5 to 14.8 ms, max 20.3 ms)."
---

# Phase 2: Movement Core & Follow Camera Verification Report

**Phase Goal:** As a player, I want to run, sprint, jump, double jump and dash with a smooth camera, so that moving feels fluid and fast.
**Verified:** 2026-11-06
**Status:** human_needed
**Re-verification:** No, initial verification

## Summary

The code delivers the goal. I re-ran the full headless suite myself (`bash attimo/tests/run.sh`): `SMOKE SUMMARY: tests=24 passed=1009 failed=0`, `RUN.SH: PASSED`. A second filtered run of the camera, platform, dash and latency tests also passed (5 tests, 207 checks, 0 FAIL). All code-checkable truths of the five roadmap success criteria are backed by passing tests and by code I read. The phase cannot be marked `passed` for one reason: the mandatory 144 Hz judder check (part of success criterion 1, requirement CAM-01) was never performed, and the hardware latency feel check (FEEL-06 human part) was only provisionally accepted. Both stay human items. CAM-01 correctly remains `Pending` in REQUIREMENTS.md.

No gaps were found. No debt markers (TBD, FIXME, XXX, TODO, HACK) in `attimo/scripts`, `attimo/tools`, `attimo/tests` or `attimo/scenes/test`.

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1a | In a gym built from Prototype Bits the player steers relative to a mouse-look follow camera centered behind the character, with smooth accel/decel, and can sprint | VERIFIED | `PlayerController.input_direction()` steers through `CameraRig.steering_yaw()`; `accelerate_ground` uses accel/decel/skid rates; `Sprint` state targets `run_speed * sprint_multiplier` (10.5 m/s in METRICS). `movement_gym.tscn` is `run/main_scene` (project.godot:14); `test_movement_gym` (54 checks) asserts Prototype Bits only, one Player, one Camera3D in a sibling CameraRig, camera-relative run. Human sign-off items 1 and 6 passed. |
| 1b | Camera follows without jitter at 10 TPS | VERIFIED (proxy plus human) | `test_camera_rig` (d): 0.0 % of 216 process frames left the rig unmoved at 10 TPS and at 60 TPS; rig is top level with physics interpolation off. Human item 6 passed (no jitter at 60/120/10 TPS). |
| 1c | Camera follows without jitter at 144 Hz | UNCERTAIN (human_needed) | Not verified. Developer has no 144 Hz display (02-14 item 7). Only the headless proxy exists. See Human Verification. |
| 1d | Camera never clips through walls | VERIFIED | `test_camera_rig` (h) lens 1.73 m from pivot with a wall 2 m behind, not inside the wall; (j) orbit at 10 and 60 TPS: 0 of 289 / 287 frames with a wall between pivot and lens, 0 with the lens inside a collider. SphereShape cast on the World layer, per-frame in `camera_rig.gd`. Human item 6 passed. |
| 1e | Mouse sensitivity and invert-Y can be changed | VERIFIED | `CameraSettings` (sensitivity, invert_y, auto_follow_mode) loaded from `user://settings.cfg`, applied in `CameraRig._unhandled_input`; `test_camera_controls` (sign, scaling, invert flip, ConfigFile round-trip, clamp on tampered files) and `test_tuning_panel` (4) (set_sensitivity(2.0) reaches rig.settings, set_invert_y(true), both saved) pass. Reachable via the F2 panel. |
| 2a | Tap jump lower than hold; fall heavier than rise | VERIFIED | `AirState.apply_jump_cut()` cuts the rise on release; `PlayerController._integrate` multiplies gravity by `fall_multiplier` (1.7) when falling. METRICS: tap 0.80 m vs full 2.00 m. `test_jump` passes. |
| 2b | Jump just after leaving a ledge (coyote) or just before landing (buffer) still fires | VERIFIED | `coyote_timer` set in `_leave_floor` only on walk-off (0.10 s); `jump_buffer_timer` set in `_tick_timers` (0.12 s) and `will_land_within` keeps a late press for a landing jump. Covered by `test_jump` (passes in full run). |
| 2c | Exactly one double jump per airtime | VERIFIED | `air_jump_available` cleared in `DoubleJump.enter`, refilled only in `_land`. `test_jump` and `test_dash` assert the single air jump. |
| 3a | Dash on the ground and once in the air; air dash refills on landing | VERIFIED | `Dash` state with `can_dash()`/`start_dash(in_air)`; `air_dash_available` spent on air start, refilled in `_land`. METRICS: ground and air dash 3.98 m. `test_dash` passes. |
| 3b | A dash flows straight into a jump | VERIFIED | `Dash.physics_update`: ground dash into `LongJump`, air dash into `DoubleJump`; grace window `dash_jump_grace`. `test_long_jump` passes (small < mid < max, 10.6 to 12.5 m). |
| 3c | A dash never tunnels through walls | VERIFIED | Dash is a velocity override integrated by the single swept `move_and_slide`; `test_dash` asserts no tunnelling at 10 and 60 TPS. |
| 4a | Platforms and conveyors carry the player; momentum kept on leaving | VERIFIED | `MovingPlatform`, conveyors, `platform_carry` applied in `_leave_floor` from `_last_platform_velocity`. `test_platforms` (passes) and `test_movement_gym` play check (platforms move). Human item 5 passed. |
| 4b | Slopes and stairs never stick or launch | VERIFIED | Speed-scaled floor snap held in 0.3 to 0.5 m; METRICS floor limits: 0.10/0.15 m steps climbed, 45 degree slope walkable; `test_platforms` covers ramps and 0.15 m stairs. Human item 5 passed. |
| 5a | All movement values live-tunable in one resource | VERIFIED | One `MovementConfig` resource (`movement_default.tres`, 39 float exports) read by `PlayerController`/states; F2 `TuningPanel` has one slider per float; `test_tuning_panel` (3): set_value changes config, running player reaches 9.0 m/s without restart, shared res:// config untouched. |
| 5b | Movement-metrics table (jump height/distance, dash distance) recorded | VERIFIED | `docs/MOVEMENT-METRICS.md` exists with jump, dash, long jump, timing, floor limits, latency, grid cross-check and config snapshot; `test_movement_metrics` drift guard passes in the full run. |
| 5c | Measured input latency meets 66 ms target (hard limit 100 ms) | VERIFIED (software) | `test_latency` asserts median <= 66 ms and every sample <= 100 ms at 60 and 120 TPS; METRICS: medians 6.5 to 14.8 ms, max 20.3 ms. Hardware/display latency is a human item (provisional OK). |
| 5d | Movement signed off without any juice | VERIFIED (partial human) | No particles, glow, fog or camera effects in the gym (`test_movement_gym` composition checks; human item 10 pass). Feel sign-off items 1-6, 9, 10 passed; items 7 and 8 open (see below). |

**Score:** all code-verifiable truths verified; 1 truth (1c, 144 Hz) UNCERTAIN, routed to human verification.

### Human sign-off recorded in 02-14 (not upgraded)

| Item | Result |
|---|---|
| 1-6, 9, 10 | pass |
| 7 MANDATORY 144 Hz judder | NOT verified (no 144 Hz display) |
| 8 Latency | provisional OK, to be re-checked |

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `attimo/scripts/player/player_controller.gd` | Single move call, timers, chain, dash gating | VERIFIED | 314 lines, substantive, wired through states and tests |
| `attimo/scripts/player/movement_config.gd` | Tunable resource | VERIFIED | 132 lines, 39 float exports, used by all states and the panel |
| `attimo/scripts/player/states/*.gd` | Idle, Run, Sprint, Jump, DoubleJump, Fall, Dash, LongJump | VERIFIED | All substantive, registered in the state machine, exercised by tests |
| `attimo/scripts/camera/camera_rig.gd` | Hand-built SpringArm rig, FOV/offset stack, auto-follow, recenter | VERIFIED | 388 lines, wired in gym and test scene |
| `attimo/scripts/camera/camera_settings.gd` | Sensitivity, invert-Y, auto-follow mode persistence | VERIFIED | 89 lines, round-trip tested |
| `attimo/scripts/gym/moving_platform.gd`, `fall_reset.gd` | Platforms and respawn | VERIFIED | Present, used in gym, tested |
| `attimo/scripts/debug/{latency_probe,metrics_overlay,tuning_panel}.gd` | Latency, F4 overlay, F2 panel | VERIFIED | Present, tested |
| `attimo/scenes/test/movement_gym.tscn` | Gym, main scene | VERIFIED | Main scene in project.godot, 54 composition and play checks |
| `docs/MOVEMENT-METRICS.md` | Generated metrics table | VERIFIED | Present, drift guard passes |

### Key Link Verification

| From | To | Via | Status |
|---|---|---|---|
| PlayerController.input_direction | CameraRig.steering_yaw | `_find_rig` on the current camera | WIRED |
| States | PlayerController | write `move_velocity`/`vertical_speed` only, single `move_and_slide` in `_integrate` | WIRED |
| PlayerController | EventBus | `jumped`, `double_jumped`, `dash_started`, `landed`, `chain_stage_changed` | WIRED (test_*_fact tests and event log checks pass) |
| TuningPanel | MovementConfig / CameraRig.settings | `set_value`, `set_sensitivity`, `set_invert_y` | WIRED (test_tuning_panel) |
| project.godot | movement_gym.tscn | `run/main_scene` | WIRED |

### Data-Flow Trace (Level 4)

No rendered dynamic data in the UI sense. The overlay and panel read live values from the player and config; `test_metrics_overlay` and `test_tuning_panel` confirm real values flow (running player reaches the retuned 9.0 m/s). Status FLOWING.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full suite | `bash attimo/tests/run.sh` | tests=24 passed=1009 failed=0, RUN.SH: PASSED | PASS |
| Camera, platforms, dash, latency | `bash attimo/tests/run.sh test_camera_rig,test_camera_controls,test_platforms,test_dash.gd,test_latency` | tests=5 passed=207 failed=0 | PASS |

### Probe Execution

SKIPPED: no `scripts/*/tests/probe-*.sh` probes are declared by the phase.

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|---|---|---|---|
| MOVE-01 | Run with accel/decel, camera-relative steering | SATISFIED | `accelerate_ground`, `input_direction`; `test_ground_movement`, `test_scene_run`, `test_movement_gym` |
| MOVE-02 | Sprint | SATISFIED | `Sprint` state; METRICS 10.5 m/s; `test_ground_movement` |
| MOVE-03 | Variable jump height, heavier fall | SATISFIED | `apply_jump_cut`, `fall_multiplier`; `test_jump` |
| MOVE-04 | Coyote time and jump buffer | SATISFIED | timers in `PlayerController`; `test_jump` |
| MOVE-05 | One double jump per airtime | SATISFIED | `air_jump_available`, `DoubleJump`; `test_jump` |
| MOVE-06 | Ground dash | SATISFIED | `Dash` state; `test_dash` |
| MOVE-07 | One air dash, refill on landing, dash into jump | SATISFIED | `air_dash_available`, `LongJump`; `test_dash`, `test_long_jump` |
| MOVE-08 | Platform/conveyor momentum, slopes and steps | SATISFIED | `platform_carry`, floor snap; `test_platforms` |
| MOVE-10 | Tunable resource and metrics table | SATISFIED | `MovementConfig`, `TuningPanel`, `MOVEMENT-METRICS.md`, `test_tuning_panel`, `test_movement_metrics` |
| CAM-01 | Follow camera, centered, smooth, no jitter, no wall clipping | NEEDS HUMAN | Everything verified except the 144 Hz judder check, which was not performed. REQUIREMENTS.md correctly keeps it Pending. |
| CAM-03 | Sensitivity and invert-Y configurable | SATISFIED | `CameraSettings`, F2 panel; `test_camera_controls`, `test_tuning_panel` |
| FEEL-06 | Latency measured, target <= 66 ms, hard limit 100 ms | SATISFIED (software), hardware feel provisional | `test_latency`, METRICS latency table. Hardware re-check listed as human item. |

No orphaned requirements: every Phase 2 ID in REQUIREMENTS.md is claimed by a plan.

### Anti-Patterns Found

None. No TBD/FIXME/XXX/TODO/HACK markers in the phase's code. No stubs, no empty handlers in the reviewed files. `project.godot` and two `.import` files are rewritten by the engine when tests run; I reverted them, so the working tree is clean.

### Notes (not gaps)

- Follow-up feedback from the developer, not roadmap criteria: movement feels too heavy and should be more input-responsive; long-jump arc should be higher; double-jump logic to change; dash should move to Left Shift with sprint on another key (proposed Left Alt). These belong to a tuning follow-up round, not to this verification.
- `common/physics_interpolation=true` is set project-wide while the CameraRig opts out (verified by test_camera_rig (a)); this is intentional.

## Human Verification Required

### 1. 144 Hz judder (MANDATORY, CAM-01, success criterion 1)

**Test:** Run the movement gym on a 144 Hz display with V-Sync on. Turn the camera and run the pillar forest at 60 TPS and at 10 TPS (F6 cycles). Record pass/fail and the display.
**Expected:** No visible camera judder or stutter.
**Why human:** Needs real 144 Hz hardware, which the developer does not have. The headless jitter test is only a proxy. Until a result is recorded, CAM-01 stays open and the phase is not signed off for success criterion 1. If no 144 Hz display will ever be available, the developer can record an explicit override (accepted_by, reason) in this file's frontmatter.

### 2. Hardware input latency re-check (FEEL-06 human part)

**Test:** Judge immediacy of jump and dash on the dev machine.
**Expected:** Feels immediate, no perceptible lag.
**Why human:** Only provisionally accepted. Display, compositor and USB latency cannot be measured headless.

## Gaps Summary

No gaps. The phase goal is implemented and covered by a green 1009-check suite. The open items are two human checks, the 144 Hz judder check being mandatory by the phase's own validation contract.

---

_Verified: 2026-11-06_
_Verifier: Claude (gsd-verifier)_
