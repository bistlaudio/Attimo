---
phase: "02"
slug: "movement-core-follow-camera"
status: planned
nyquist_compliant: true
wave_0_complete: false
created: "2026-11-04"
updated: "2026-11-05"
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Derived from `02-RESEARCH.md` § Validation Architecture and refreshed against the 14 plans (02-01..02-14) after the plan-check revision: every row below names a test file that a plan actually creates or edits.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Project smoke harness (`RefCounted` tests with `run(tree, check)`), Godot 4.7.2 headless |
| **Config file** | none — `attimo/tests/run.sh` auto-discovers `tests/smoke/test_*.gd` |
| **Quick run command** | `bash attimo/tests/run.sh <filter>` (comma-separated substrings; use `test_jump.gd` to exclude `test_jump_fact`) |
| **Full suite command** | `bash attimo/tests/run.sh` |
| **Estimated runtime** | ~80-110 seconds at phase end (baseline ~19 s + new tests; test_camera_controls alone runs about 30 s of real-time auto-follow scenarios); filtered per-task runs ~10-40 s |

## Sampling Rate

- **After every task commit:** `bash attimo/tests/run.sh <touched test names>` (filtered; no task uses the full suite except the final plan's last task, 02-14 Task 2, which is the phase gate)
- **At plan end:** the plan's `<verification>` run. Wave 1 and the wave-2 plans other than 02-04 run named test lists; from 02-04 on, plan end runs the full suite.
- **Wave gates:** wave 1 has no shared gate: each wave-1 plan runs only the tests whose inputs it owns (02-01: `test_ground_movement,test_feedback_guard`), so no plan's gate depends on a parallel plan finishing; the first cross-plan gate is the full suite (`bash attimo/tests/run.sh`) at the end of 02-04, after all of wave 1 has landed, and every plan end from 02-04 on runs the full suite.
- **Known red interval:** between 02-01 (wave 1) and 02-04 (wave 2) the five Phase 1 tests that encode "the body never moves" (`test_scene_run`, `test_jump_fact`, `test_movement_facts`, `test_dash_fact`, `test_mannequin_animation`) fail by design (RESEARCH Pitfall 6). No other plan runs them in that interval.
- **Before `/gsd-verify-work`:** full suite green, `measure_movement.gd` run (MEASURE: PASSED) and `docs/MOVEMENT-METRICS.md` committed, gym sign-off recorded (including the mandatory 144 Hz item).
- **Max feedback latency:** 90 seconds

## Per-Task Verification Map

| Req | Behavior | Test Type | Automated Command | Plans | File Exists | Status |
|-----|----------|-----------|-------------------|-------|-------------|--------|
| MOVE-01 | accel/decel, skid, camera-relative input (bare camera and rig steering_yaw), floor snap inside 0.3-0.5 m up to dash speed, camera follow, tracer jump | integration | `bash attimo/tests/run.sh test_ground_movement` | 02-01 | ❌ W1 (02-01) | ⬜ pending |
| MOVE-01 | Phase 1 tests on real physics; F5 test scene with follow camera | integration | `bash attimo/tests/run.sh test_jump_fact,test_movement_facts,test_mannequin_animation,test_scene_run` | 02-04 | ✅ rewrite | ⬜ pending |
| MOVE-02 | hold-to-sprint ~1.5x run, own accel, release returns to run | integration | `bash attimo/tests/run.sh test_ground_movement` | 02-09 | ❌ W1 (02-01) | ⬜ pending |
| MOVE-03/04/05 | variable jump, tick-rate independent apex, coyote, buffer, one double jump | integration | `bash attimo/tests/run.sh test_jump.gd` | 02-05 | ❌ W2 (02-05) | ⬜ pending |
| MOVE-06/07 | ground/air dash, cooldown, altitude hold, combos, exit carry, dash→jump, no tunnelling at 10/60 TPS, dash down the 45° ramp grounded inside the D-13 snap band | integration | `bash attimo/tests/run.sh test_dash` | 02-04 (rename), 02-09 | ✅ renamed from test_dash_fact | ⬜ pending |
| MOVE-07 | chain Jump 1 → Jump 2 → Dash → Jump, long jump carries the dash speed bounded by long_jump_speed_cap, small < mid < max | integration | `bash attimo/tests/run.sh test_long_jump` | 02-11 | ❌ W4 (02-11) | ⬜ pending |
| MOVE-08 | Slope/Beam wrappers, 31-file whitelist, originals guarded | unit | `bash attimo/tests/run.sh test_proto_pieces,test_asset_hygiene` | 02-03 | ✅ edit | ⬜ pending |
| MOVE-08 | conveyors, moving platforms, momentum on leave, ramps and 0.15 m stairs at 60 TPS with the snap inside 0.3-0.5 m (10 TPS diagnostic, printed), 0.25 m ledge, fall reset | integration | `bash attimo/tests/run.sh test_platforms` | 02-07 | ❌ W2 (02-07) | ⬜ pending |
| MOVE-10 | one MovementConfig resource drives every number (asserted through the tracer and every movement test deriving expectations from `player.config`) | integration | `bash attimo/tests/run.sh test_ground_movement` | 02-01 | ❌ W1 (02-01) | ⬜ pending |
| MOVE-10 | live tuning panel: one slider per float, live retune, shared config never written by tests | integration | `bash attimo/tests/run.sh test_tuning_panel` | 02-12 | ❌ W4 (02-12) | ⬜ pending |
| MOVE-10 | metrics overlay (live numbers) | integration | `bash attimo/tests/run.sh test_metrics_overlay` | 02-08 | ❌ W3 (02-08) | ⬜ pending |
| MOVE-10 | generated metrics table + config-snapshot drift guard | tool + unit | `bash attimo/tests/run.sh --tool res://tools/measure_movement.gd` ; `bash attimo/tests/run.sh test_movement_metrics` | 02-13 | ❌ W5 (02-13) | ⬜ pending |
| CAM-01 | rig top-level, interpolation off, jitter proxy at 10/60 TPS (proxy only for 144 Hz), vertical band, additive FOV/offset, wall pull-in, corridor at 10/60 TPS | integration | `bash attimo/tests/run.sh test_camera_rig` | 02-06 | ❌ W2 (02-06) | ⬜ pending |
| CAM-01 | auto-follow converges under a held sideways/diagonal key (yaw change < 0.02 rad over the last second of a 3 s hold), never fights the mouse, mode auto/on/off keyed to the last input device (simulated joypad events), recenter without re-steering | integration | `bash attimo/tests/run.sh test_camera_controls` | 02-10 | ❌ W3 (02-10) | ⬜ pending |
| CAM-01 | gym composition and play smoke test | integration | `bash attimo/tests/run.sh test_movement_gym` | 02-14 | ❌ W6 (02-14) | ⬜ pending |
| CAM-03 | mouse sign, sensitivity scales, invert-Y flips, ConfigFile round-trip incl. auto_follow_mode, clamp on tampered files (unknown mode -> auto), user:// only | unit | `bash attimo/tests/run.sh test_camera_controls` | 02-10 | ❌ W3 (02-10) | ⬜ pending |
| CAM-03 | sensitivity / invert-Y / auto-follow mode changed in the panel, saved and applied | integration | `bash attimo/tests/run.sh test_tuning_panel` | 02-12 | ❌ W4 (02-12) | ⬜ pending |
| FEEL-06 | input→fact latency at 60 and 120 TPS: median ≤ 66 ms (target, asserted) and every sample ≤ 100 ms (hard limit, asserted) | integration | `bash attimo/tests/run.sh test_latency` | 02-08 | ❌ W3 (02-08) | ⬜ pending |
| FEEL-06 | latency table at 60/120 TPS with accumulation on/off; tool fails above 66 ms median or 100 ms sample | tool | `bash attimo/tests/run.sh --tool res://tools/measure_movement.gd` | 02-13 | ❌ W5 (02-13) | ⬜ pending |
| D-17 | `camera_recenter` + debug actions in the Input Map and CONVENTIONS; EventBus facts documented | unit | `bash attimo/tests/run.sh test_input_map,test_conventions` | 02-02 | ✅ edit | ⬜ pending |

There is no `test_movement_config` file: MovementConfig is exercised by every movement test (all expectations derive from `player.config`), by the tuning panel test (row count over its float exports) and by the metrics drift guard (config snapshot).

## Wave 0 Requirements

- [ ] `attimo/tests/fixtures.gd` — floor/box helpers, `spawn_camera_rig`, `send_action_event`, `send_mouse_motion`, `wait_until` (02-01: body and wait helpers in Task 1, camera and input-event helpers in Task 2)
- [ ] New test files, each created RED in its own plan before the code: `test_ground_movement` (02-01), `test_jump` (02-05), `test_camera_rig` (02-06), `test_platforms` (02-07), `test_latency`, `test_metrics_overlay` (02-08), `test_camera_controls` (02-10), `test_long_jump` (02-11), `test_tuning_panel` (02-12), `test_movement_metrics` (02-13), `test_movement_gym` (02-14)
- [ ] Rewrite Phase 1 tests that assert "body never moves" (02-04): `test_scene_run`, `test_movement_facts`, `test_jump_fact`, `test_mannequin_animation`, and `test_dash_fact` renamed to `test_dash`
- [ ] Update `test_asset_hygiene` whitelist/count and `test_proto_pieces` (02-03); `test_input_map`, `test_conventions` (02-02)

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Subjective feel sign-off (no juice) | MOVE-10, success criterion 5 | Feel is not machine-checkable | 02-14 sign-off items 1-5, 9, 10 in the movement gym |
| 144 Hz visual judder — **mandatory, not optional** | CAM-01, success criterion 1 | Needs a real 144 Hz display; `test_camera_rig`'s jitter test is only a headless proxy | 02-14 sign-off item 7: gym on a 144 Hz display, V-Sync on, camera turns and pillar-forest runs at 60 and 10 TPS; record pass/fail and the display. Without a recorded result the phase is not signed off |
| Real hardware latency | FEEL-06 | Headless cannot see display/USB/compositor latency; the software latency (≤ 66 ms target) is asserted by `test_latency` and the measure tool | 02-14 sign-off item 8: judge immediacy on the dev machine and record the D-22 caveat |
| Corridor camera feel | CAM-01 | Subjective | 02-14 sign-off item 6 (passage and pillar forest) |
| Test-scene and per-feature feel checks | MOVE-01..07, CAM-01, CAM-03 | Subjective | `<human-check>` blocks in 02-04, 02-08, 02-09, 02-10, 02-11, 02-12 (end-of-phase mode) |

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 90 s (filtered per-task runs; full suite only at plan ends from 02-04 on and in the final task)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending (execution)
