---
phase: 02-movement-core-follow-camera
verified: 2026-11-06T18:00:00Z
status: passed
overrides:
  - item: "CAM-01 success criterion 1, 144 Hz judder check"
    status: not_verified
    accepted_by: "Christian Nappo (developer)"
    accepted: 2026-11-06
    reason: "Only a Mac without a 144 Hz display is available; the headless jitter proxy passes (0.0 % unmoved frames at 10 and 60 TPS). The check stays open as a later human item and CAM-01 stays unchecked in REQUIREMENTS.md."
  - item: "FEEL-06 hardware latency (display, compositor, USB)"
    status: provisional
    accepted_by: "Christian Nappo (developer)"
    accepted: 2026-11-06
    reason: "Software latency measured at 6.5-20 ms against the 66 ms target; hardware part accepted provisionally ('ja an sich'), to be re-checked."
score: 5/5 roadmap success criteria verified in code and tests against the reworked wording (criterion 1 without its 144 Hz part, criterion 5 without hardware latency; both carried by the developer overrides above)
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
  - attimo/resources/player/movement_default.tres
  - attimo/scenes/debug/hit_puff.tscn
  - attimo/scenes/debug/hit_puffs.tscn
  - attimo/scenes/test/movement_gym.tscn
  - attimo/scripts/camera/camera_rig.gd
  - attimo/scripts/debug/hit_puffs.gd
  - attimo/scripts/player/movement_config.gd
  - attimo/scripts/player/player_controller.gd
  - attimo/scripts/player/states/air_state.gd
  - attimo/scripts/player/states/dash.gd
  - attimo/scripts/player/states/ground_state.gd
  - attimo/scripts/player/states/jump.gd
  - attimo/scripts/player/states/long_jump.gd
  - attimo/scripts/player/states/run.gd
  - docs/CONVENTIONS.md
  - docs/MOVEMENT-METRICS.md
covered_digest: "v4:sha256:2d5f67e79c37e1a48488895efeb515fba293832347ac24e7ec9d0d19a02dbc80"
behavior_unverified: 0
overrides_applied: 2
re_verification:
  previous_status: passed (stale; written against the pre-rework wording with sprint, air double jump and a 39-slider config)
  previous_score: 5/5 against the old wording
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 2: Movement Core & Follow Camera Verification Report

**Phase Goal:** As a player, I want to run, jump (Jump 1-2-3 chain), dash and dash hop with a smooth camera, so that moving feels fluid and fast.
**Verified:** 2026-11-06
**Status:** passed (two developer overrides apply, see below)
**Re-verification:** Yes, after the movement rework (quick task 261106-erl, commits bd3c75b..f4a487f plus 4a99d23). The first report (8627d72) described sprint, an air double jump and a 39-slider config that no longer exist.

## Summary

I checked the current code against the reworded ROADMAP success criteria and requirement text, not against the old report. I re-ran the full headless suite myself (`bash attimo/tests/run.sh`): `SMOKE SUMMARY: tests=25 passed=1044 failed=0`, `RUN.SH: PASSED`. The run left no engine noise in the working tree (only this report was modified).

All five reworded success criteria are backed by passing tests and by code I read in `attimo/scripts/player`, `attimo/scripts/camera` and `attimo/scripts/debug`. Two parts are not verified by me and are carried by the developer overrides in the frontmatter, which I kept unchanged: the 144 Hz judder check (CAM-01, criterion 1) and the hardware part of the latency check (FEEL-06, criterion 5). No gaps were found. No debt markers (TBD, FIXME, XXX, TODO, HACK) in `attimo/scripts`, `attimo/tools`, `attimo/tests`, `attimo/scenes/test` or `attimo/scenes/debug`.

## Goal Achievement

### Observable Truths (current ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1a | Camera-relative steering behind a mouse-look follow camera, smooth accel/decel, one tunable run speed | VERIFIED | `PlayerController.input_direction()` steers through `CameraRig.steering_yaw()`; `accelerate_ground` uses accel/decel/skid rates; `Run` targets `config.run_speed` (8.5 m/s) and is the only ground speed. `Sprint` state and `DoubleJump` state files are deleted; no `sprint`, `double_jump` or `air_jump` identifier remains in `attimo/` outside tests that assert their absence (`test_input_map`: no `sprint` action; `test_ground_movement` (g): no extra run state node). `dash` is bound to Shift in `project.godot`. `test_ground_movement` (38), `test_movement_gym` (54), `test_input_map` (113) pass. |
| 1b | Camera follows without jitter at 10 TPS | VERIFIED (proxy) | `test_camera_rig` (d): 0.0 % of 216 process frames at 10 TPS and 0.0 % of 217 at 60 TPS left the rig unmoved (limit 5 %); rig is top level with physics interpolation off. Proxy runs at run speed (see Notes). |
| 1c | Camera follows without jitter at 144 Hz | PASSED (override) | Override: Only a Mac without a 144 Hz display is available; headless proxy passes. Accepted by Christian Nappo (developer) on 2026-11-06. Stays open as a later human item; CAM-01 stays unchecked in REQUIREMENTS.md. |
| 1d | Camera never clips through walls | VERIFIED | `test_camera_rig` (h) lens 1.73 m from pivot with a wall 2 m behind, not inside the wall; (j) orbit in a 3 m corridor at 10 and 60 TPS: 0 of 289 frames with a wall between pivot and lens. SphereShape cast on the World layer in `camera_rig.gd`. Camera script unchanged by the rework (no commits on `scripts/camera` since 8627d72). |
| 1e | Mouse sensitivity and invert-Y can be changed | VERIFIED | `CameraSettings` loaded from `user://settings.cfg`; `test_camera_controls` (59 checks) and `test_tuning_panel` (24 checks, scenario 4: `set_sensitivity(2.0)` and `set_invert_y(true)` reach `rig.settings` and the saved file). |
| 2a | Tap jump lower than hold; fall heavier than rise | VERIFIED | `AirState.apply_jump_cut()` cuts the rise to `cut_speed()`; `_integrate` uses `fall_gravity() = rise_gravity * fall_multiplier` (34 * 1.3) while falling. `test_jump` (a): held apex within 0.1 of 2.00 m, tapped apex within 0.15 of 0.80 m, tap lower than hold, fall shorter than rise (ticks). |
| 2b | Jump just after a ledge (coyote) or just before landing (buffer) still fires | VERIFIED | `coyote_timer` set in `_leave_floor` only on walk-off (0.10 s); `jump_buffer_timer` 0.12 s, polled each tick. `test_jump` (c) coyote inside/outside, (d) buffered landing jump fires within 2 ticks and keeps speed, (e) buffered tap gives tap height, (h) late press fires on landing. |
| 2c | Ground jumps chain Jump 1 -> 2 -> 3 (salto, highest) inside a landing window | VERIFIED | `advance_chain_for_ground_jump()` returns 2 after Jump 1 and 3 after Jump 2 only while `combo_timer > 0`, otherwise 1; `landing_window` 0.35 s. `test_long_jump` (c1) stages [1,2,3], apexes 2.00 < 2.60 < 3.40 m; (c3) buffered press becomes Jump 2; (c4) timeout resets; (c5) standing resets; (c6) a fourth jump is Jump 1 again. Salto is physics only; its flip is Phase 3 (MOVE-09). |
| 2d | There is no air jump | VERIFIED | `AirState._airborne_jump_decision()` returns only `Jump` while coyote time is left, never an air jump; `DoubleJump` state removed. `test_jump` (f): a held press at the apex never rises again and emits no second `jumped`; (g) an air press far above the floor adds no rise; `test_dash` (6): jump -> air dash -> jump press adds no rise. |
| 3a | Dash on the ground and once in the air; air dash refills on landing | VERIFIED | `can_dash()` allows ground always, air only while `air_dash_available`; `_land` refills it. `test_dash` (5): holds altitude, second air dash in the same airtime refused, landing refills. `test_long_jump` (c7): after the salto one air dash, second refused. METRICS: ground and air dash 4.01 m. |
| 3b | A dash flows straight into a jump: a long jump whose speed stacks over three stages on clean repeats | VERIFIED | `Dash` hands a jump press to `LongJump` (also within `dash_jump_grace` 0.15 s via `GroundState`); `advance_long_jump_stage()` climbs 1 -> 2 -> 3 and restarts at 1 after stage 3. `test_long_jump` (l3): hops 1-4 take off at 14.0 / 16.0 / 18.0 / 14.0 m/s with apexes 2.00 / 2.50 / 3.00 / 2.00 m, never above 22 m/s, distances 9.10 < 11.73 < 14.40 m, hop 4 equals hop 1; (stack_misses) a miss restarts at 1; (grace) last grace tick still hops; (l2) speed is set, not carried. |
| 3c | A dash never tunnels through walls | VERIFIED | Dash is a velocity override integrated by the one swept `move_and_slide`. `test_dash` (9): a 60 m/s dash never reaches the far face of the wall, at 10 TPS and at 60 TPS (lowest z -4.450, far face -5.05). |
| 4a | Platforms and conveyors carry the player; momentum kept on leaving | VERIFIED | `platform_carry` applied in `_leave_floor` from `_last_platform_velocity`; `test_platforms` (40 checks) and the gym play check in `test_movement_gym`. |
| 4b | Slopes and stairs never stick or launch | VERIFIED | Speed-scaled floor snap held in 0.3 to 0.5 m; METRICS floor limits: 0.10 and 0.15 m steps climbed, 0.20 and 0.25 m blocked, 45 degree slope walkable; `test_platforms` covers ramps and stairs. |
| 5a | All movement values live-tunable in one resource | VERIFIED | One `MovementConfig` resource (`movement_default.tres`): 8 `@export_group`s, 34 `@export_range` float sliders (counted in source), no non-float exports. `test_tuning_panel` (2): `row_count` equals the number of float properties; (3) `set_value` changes the config and a running player reaches the retuned speed without restart, the shared res:// config stays untouched. |
| 5b | Movement-metrics table (jump height/distance, dash distance) recorded | VERIFIED | `docs/MOVEMENT-METRICS.md` holds run speed, tap/full/Jump 2/Jump 3, ground/air dash, long jump stages 1-3 plus the post-stage-3 restart, timing windows, floor limits, latency and grid cross-check, in line with the current config. `test_movement_metrics` (66) drift guard passes. |
| 5c | Measured jump and dash input latency meets 66 ms (hard limit 100 ms) | VERIFIED (software); hardware PASSED (override) | `test_latency` (18) asserts median <= 66 ms and every sample <= 100 ms for jump and dash at 60 and 120 TPS (this run: medians 6.7 to 18.9 ms, max 20.3 ms). METRICS table: medians 6.3 to 19.5 ms, max 20.98 ms. Hardware (display, compositor, USB): Override: accepted provisionally by Christian Nappo (developer) on 2026-11-06, to be re-checked. |
| 5d | Movement is signed off without any juice | VERIFIED | The gym scene has no particle node (`test_movement_gym` composition check "no particle node"). The only particles are the debug hit puffs, an explicit developer-sanctioned exception: one allowlisted scene `scenes/debug/hit_puff.tscn` spawned at runtime by `scripts/debug/hit_puffs.gd` from `chain_stage_changed` and `long_jumped` facts only. `test_feedback_guard` (12) allowlists exactly that scene, fails on any other particle node and on any gameplay script naming the puff; `test_hit_puffs` (13) covers the listener. Exception is recorded in `docs/CONVENTIONS.md`. No glow, fog, shake or FOV effect added. |

**Score:** 5/5 roadmap success criteria verified; 2 sub-parts carried by developer overrides (144 Hz, hardware latency).

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `attimo/scripts/player/player_controller.gd` | Single move call, timers, chain and stack bookkeeping, dash gating | VERIFIED | 309 lines, substantive; one `move_and_slide` in `_integrate`; wired through states and tests |
| `attimo/scripts/player/movement_config.gd` | One tunable resource, 8 groups, 34 sliders | VERIFIED | 139 lines, counted in source; per-stage helpers `jump_height_for_stage`, `long_jump_height`, `long_jump_speed` |
| `attimo/scripts/player/states/*.gd` | Idle, Run, Jump, Fall, Dash, LongJump (+ AirState, GroundState bases) | VERIFIED | Substantive, no Sprint or DoubleJump file remains |
| `attimo/scripts/camera/camera_rig.gd` | Hand-built SpringArm rig, FOV/offset stack, auto-follow, recenter | VERIFIED | 388 lines, unchanged since the first verification |
| `attimo/scripts/debug/hit_puffs.gd`, `scenes/debug/hit_puff.tscn` | Debug-only timing feedback (allowlisted exception) | VERIFIED | Fact-driven, referenced only from the gym scene, guarded by `test_feedback_guard` |
| `attimo/scenes/test/movement_gym.tscn` | Gym, main scene | VERIFIED | Instances `HitPuffs`; 54 composition and play checks pass |
| `docs/MOVEMENT-METRICS.md` | Generated metrics table | VERIFIED | In line with the current config; drift guard passes |

### Key Link Verification

| From | To | Via | Status |
|---|---|---|---|
| PlayerController.input_direction | CameraRig.steering_yaw | `_find_rig` on the current camera | WIRED |
| States | PlayerController | write `move_velocity` / `vertical_speed` only, single `move_and_slide` in `_integrate` | WIRED |
| Dash / GroundState | LongJump | jump press during the ground dash or inside `dash_jump_grace` | WIRED (test_long_jump) |
| LongJump / Jump | PlayerController chain and stack | `advance_long_jump_stage`, `advance_chain_for_ground_jump` | WIRED |
| PlayerController | EventBus | `jumped`, `long_jumped`, `dash_started`, `landed`, `chain_stage_changed` | WIRED (test_movement_facts, test_jump_fact, test_long_jump) |
| EventBus | HitPuffs | `chain_stage_changed`, `long_jumped` | WIRED (test_hit_puffs) |
| TuningPanel | MovementConfig / CameraRig.settings | `set_value`, `set_sensitivity`, `set_invert_y` | WIRED (test_tuning_panel) |
| project.godot | movement_gym.tscn | `run/main_scene` | WIRED |

### Data-Flow Trace (Level 4)

No rendered dynamic data in the UI sense. The overlay and panel read live values from the player and config; `test_metrics_overlay` and `test_tuning_panel` confirm real values flow (a running player reaches the retuned speed). Status FLOWING.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full suite | `bash attimo/tests/run.sh` | tests=25 passed=1044 failed=0, RUN.SH: PASSED | PASS |
| Per-test counts from the saved run (0 FAIL lines overall) | `grep -c "^PASS \[test_x\]"` on the saved log | camera_rig 38, camera_controls 59, latency 18, platforms 40, dash 51, jump 24, ground_movement 38, movement_gym 54, movement_metrics 66, tuning_panel 24, hit_puffs 13, feedback_guard 12, input_map 113 | PASS |

The behavior-dependent truths (chain, long-jump stack, air-dash refill, no air jump, restart after stage 3) each have a passing behavioral test, so none is left as present-but-behavior-unverified.

### Probe Execution

SKIPPED: no `scripts/*/tests/probe-*.sh` probes are declared by the phase.

### Requirements Coverage

| Requirement | Description (current wording) | Status | Evidence |
|---|---|---|---|
| MOVE-01 | Run with accel/decel, camera-relative steering | SATISFIED | `accelerate_ground`, `input_direction`; `test_ground_movement`, `test_movement_gym` |
| MOVE-02 | One tunable run speed, no separate sprint | SATISFIED | Sprint state and action removed; `run_speed` 8.5; `test_input_map`, `test_ground_movement` (g) |
| MOVE-03 | Variable jump height, heavier fall | SATISFIED | `apply_jump_cut`, `fall_multiplier` 1.3; `test_jump` (a) |
| MOVE-04 | Coyote time and jump buffer | SATISFIED | timers in `PlayerController`; `test_jump` (c), (d), (e), (h) |
| MOVE-05 | Ground chain Jump 1 -> 2 -> 3 (salto) in a landing window; no air jump | SATISFIED | `advance_chain_for_ground_jump`; `test_long_jump` (c1-c7), `test_jump` (f), (g). No glide, dive or ground-pound exists. |
| MOVE-06 | Ground dash | SATISFIED | `Dash` state; `test_dash` |
| MOVE-07 | One air dash (refills on landing); dash + jump = long jump with a 3-stage stack | SATISFIED | `air_dash_available`, `LongJump`; `test_dash` (5), `test_long_jump` (l1-l9) |
| MOVE-08 | Platform/conveyor momentum, slopes and steps | SATISFIED | `platform_carry`, floor snap; `test_platforms` |
| MOVE-10 | Tunable resource and metrics table | SATISFIED | `MovementConfig` (34 sliders), `TuningPanel`, `MOVEMENT-METRICS.md`; `test_tuning_panel`, `test_movement_metrics` |
| CAM-01 | Follow camera, centered, smooth, no jitter, no wall clipping | NOT CHECKED OFF (override) | Everything except the 144 Hz check is verified. The override keeps CAM-01 open in REQUIREMENTS.md (`[ ]`, Pending), which is consistent. |
| CAM-03 | Sensitivity and invert-Y configurable | SATISFIED | `CameraSettings`, F2 panel; `test_camera_controls`, `test_tuning_panel` |
| FEEL-06 | Latency measured, target <= 66 ms, hard limit 100 ms | SATISFIED (software); hardware PASSED (override) | `test_latency`, METRICS latency table |

No orphaned requirements: every Phase 2 ID in REQUIREMENTS.md is claimed by the phase. MOVE-09 (Phase 3) and FEEL-02 (Phase 11) are reworded to the new verbs (salto, long jump) but belong to later phases and stay Pending there.

### Anti-Patterns Found

None. No TBD/FIXME/XXX/TODO/HACK markers in the phase's code, no stubs and no empty handlers in the reviewed files. The hit puff particles are the one documented, allowlisted exception and are not a stub.

### Notes (not gaps)

- **Jitter proxy speed.** The headless jitter proxy (`test_camera_rig` (d)) runs at run speed (8.5 m/s). No test drives the camera at the dash-hop speeds of 14 to 18 m/s. The rig's horizontal follow is an exponential damping with `follow_rate` 14/s, so the steady lag grows with speed (about 0.6 m at 8.5 m/s, about 1.3 m at 18 m/s). The camera script is unchanged since the first verification and no roadmap criterion names a speed, so I do not count this as a gap. It belongs to the already planned gym playtest of the reworked feel (camera at sustained 18 m/s), which no human has done yet.
- **Fall gravity.** `fall_multiplier` is 1.3, below the 1.5 to 2x range from the original STACK guidance (Phase 2 D-04). This is a recorded user decision from the rework; criterion 2 only requires the fall to be heavier than the rise, which holds and is tested.
- **No air dash after a dash hop.** `LongJump.enter` spends the air dash and landing refills it (commit 4a99d23). Criterion 3 ("once in the air, refills on landing") still holds for normal jumps and falls; `test_long_jump` (l9) pins the new rule.
- **Open human items, not roadmap-blocking:** gym playtest of the reworked feel (light feel, hop stack balance at 14/16/18 m/s), the hold-vs-tap question and a possible dash buffer, from the quick task summary. The 144 Hz judder check and the hardware latency re-check remain open as the developer decided in the overrides.
- `common/physics_interpolation=true` is set project-wide while the CameraRig opts out (verified by `test_camera_rig` (a)); this is intentional.

## Gaps Summary

No gaps. The reworked phase goal (run, Jump 1-2-3 chain, dash, dash hop with a 3-stage stack, smooth camera) is implemented, and the reworded success criteria are covered by a green 1044-check suite. Two items stay open by the developer's explicit override: the 144 Hz judder check and the hardware latency re-check.

---

_Verified: 2026-11-06_
_Verifier: Claude (gsd-verifier)_
