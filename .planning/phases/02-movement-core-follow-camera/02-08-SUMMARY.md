---
phase: 02-movement-core-follow-camera
plan: 08
subsystem: debug-tooling
tags: [latency, debug-overlay, metrics, event-bus-listener]
status: complete

requires:
  - phase: 02-movement-core-follow-camera
    provides: "02-01 PlayerController, Fixtures (send_action_event, wait_until); 02-02 debug_metrics / debug_tick_rate actions and the double_jumped, long_jumped, chain_stage_changed facts; 02-04 test scene with CameraRig"
provides:
  - "LatencyProbe: input-event stamp to gameplay-fact latency samples for jump and dash, summary(kind) with count, median and max"
  - "MetricsOverlay (F4 / 9): per-airtime jump height, distance and kind, dash record, chain stage, latency summaries, F6 / 0 tick-rate cycle 60 -> 120 -> 10 -> 60"
  - "test_latency: FEEL-06 asserted at 60 and 120 TPS (median <= 66 ms, every sample <= 100 ms, every sample <= 2 ticks + 5 ms)"
  - "test_metrics_overlay: 16 checks; MetricsOverlay instanced in test_scene.tscn after the EventLog"
affects: [02-12, 02-13, 02-14]

actuals:
  tokens: 9000
  tasks: 2
  commits: 4
plan_head_before: c1c3a8e583a0e67f66507f5ceca97af61d4a6475
plan_head_after: 2039e02d2458cd4f86e72ea9fe49562f0cb16f5a
commits: 4

tech-stack:
  added: []
  patterns:
    - "Debug tooling is a pure bus listener: it connects to EventBus facts and reads the player, gameplay folders contain no measurement code"
    - "Take-off position is the last grounded position, not the first airborne one, so a per-airtime height is not short by one tick of rise"
    - "Tick-rate cycle only indexes the fixed TICK_RATES list (T-02-10)"

key-files:
  created:
    - attimo/scripts/debug/latency_probe.gd
    - attimo/scripts/debug/metrics_overlay.gd
    - attimo/scenes/debug/metrics_overlay.tscn
    - attimo/tests/smoke/test_latency.gd
    - attimo/tests/smoke/test_metrics_overlay.gd
  modified:
    - attimo/scenes/test/test_scene.tscn

key-decisions:
  - "A press with no fact within 0.5 s is treated as stale and never matches a later fact, so a jump press that cannot fire does not produce a bogus sample"
  - "Airtime height is measured from the last grounded position; kinds are 'jump', 'double', 'long N' and 'walk-off', later facts in the same airtime are appended with '+'"

requirements-completed: [FEEL-06, MOVE-10]

coverage:
  - id: D1
    description: "Jump and dash input-to-fact latency at 60 and 120 TPS: median at most 66 ms and every sample at most 100 ms, both asserted"
    requirement: FEEL-06
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_latency"
        status: pass
    human_judgment: false
  - id: D2
    description: "Hidden-by-default F4 overlay with per-airtime jump numbers, dash record, chain stage, latency summaries and the F6 tick-rate cycle"
    requirement: MOVE-10
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_metrics_overlay"
        status: pass
    human_judgment: false
  - id: D3
    description: "Readability of the overlay in the running game and the feel at 10 TPS"
    requirement: MOVE-10
    verification: []
    human_judgment: true
    rationale: "Visual readability and 10 TPS feel are judgments; folded into the 02-14 sign-off"
---

# Phase 2 Plan 08: Latency Probe and Metrics Overlay Summary

**LatencyProbe stamps jump and dash input events and measures the time to the matching bus fact (asserted at 60 and 120 TPS: median under 14 ms, max under 21 ms against the 66 ms target and 100 ms limit), and a hidden-by-default F4 MetricsOverlay shows live per-airtime jump height and distance, dash records, chain stage and latency, with an F6 tick-rate cycle, all as pure listeners outside gameplay code.**

## Performance

- **Tasks:** 2 of 2
- **Files:** 5 created (plus 3 generated `.uid` files), 1 modified
- **Commits:** 34f4b6f (RED latency), b35928f (LatencyProbe), 1b48340 (RED overlay), 2039e02 (MetricsOverlay, scene, test scene)

## Accomplishments

- `LatencyProbe` (`class_name LatencyProbe`, Node): `_input` stamps the first press of `jump` and `dash` with `Time.get_ticks_usec()`; `jumped`, `double_jumped` and `long_jumped` share one variadic handler, `dash_started` has its own. One sample per press, `summary(kind)` returns count, median and max, `clear()` empties both arrays, `last_frame_ms` records the fact-to-first-`frame_post_draw` time (stays -1.0 headless, not asserted, A25).
- `test_latency` (18 checks): per tick rate and action, five presses at different phases of the physics tick produce five samples, every sample is within 2 ticks + 5 ms, median is at most 66.0 ms and max at most 100.0 ms; a `jumped` fact without a press adds no sample. Four lines print `TARGET MET`.
- `MetricsOverlay` (`class_name MetricsOverlay`, CanvasLayer layer 101): top-right panel with the EventLog's StyleBoxFlat, `Lines` RichTextLabel, `LatencyProbe` child. Airtime records (kind, height, distance, airtime) with a 5-entry history, dash record (distance, in_air, duration), chain stage, probe summaries, tick rate and `Input.use_accumulated_input`. Label refreshes only while visible. `debug_metrics` toggles, `debug_tick_rate` moves through `TICK_RATES = [60, 120, 10]` only.
- `test_metrics_overlay` (16 checks): hidden at start and toggling, probe child, standing jump height 2.000 m (config 2.0) with 0.000 m distance and 0.667 s airtime, running jump 4.157 m, dash record on the floor with in_air false, cycle `[120, 10, 60]`, visible text contains tick rate, jump record and latency.
- `test_scene.tscn` instances `MetricsOverlay` after the EventLog.

## Measured latency (software only, headless, A24)

| Run | Count | Median | Max |
|-----|-------|--------|-----|
| 60 TPS jump | 5 | 13.30 ms | 14.05 ms |
| 60 TPS dash | 5 | 13.68 ms | 19.95 ms |
| 120 TPS jump | 5 | 5.63 ms | 6.96 ms |
| 120 TPS dash | 5 | 6.17 ms | 7.06 ms |

Figures from the full-suite run; single-test runs vary by a few ms (60 TPS jump median 12.7 ms, max 20.4 ms). All sit far below the 66 ms target and the 100 ms hard limit. The numbers exclude display, compositor and USB latency; 02-13 writes that caveat into MOVEMENT-METRICS.md and real hardware latency stays a human item in the 02-14 sign-off.

## Verification

- `bash attimo/tests/run.sh test_latency`: 18 passed, 0 failed, 4 `TARGET MET` lines.
- `bash attimo/tests/run.sh test_metrics_overlay,test_scene_run,test_feedback_guard`: `tests=3 passed=135 failed=0`.
- Plan gate `bash attimo/tests/run.sh` (full suite): `tests=19 passed=716 failed=0`, `RUN.SH: PASSED`.
- Acceptance greps: `class_name LatencyProbe` 1, `Time.get_ticks_usec` 5, `frame_post_draw` 2, `66.0` 1, `100.0` 1, `class_name MetricsOverlay` 1, `debug_tick_rate` 2, `debug_metrics` 2, `latency_probe.gd` in the overlay scene 1, `metrics_overlay.tscn` in the test scene 1. `grep -rn 'LatencyProbe\|get_ticks_usec' attimo/scripts/player attimo/scripts/core attimo/autoload` prints nothing.

## Deviations from Plan

None - plan executed exactly as written. RED was real for both tasks (missing class parse errors). One addition inside the planned test file: a check that the visible overlay text lists tick rate, jump record and latency, so the label refresh path is exercised.

## Issues Encountered

- Pre-existing, out of scope (noted in 02-03, 02-07): `test_proto_pieces` prints `!is_inside_tree()` engine messages in the full run. Not touched.
- Human check from Task 2 (press F5, F4, jump, dash, F6 three times; judge readability and 10 TPS feel) was not run; it is a visual judgment and is carried to the 02-14 sign-off.

## Known Stubs

None.

## Threat Flags

None. T-02-09 transferred as planned (debug-only folders, hidden at start, reachable only through `debug_` actions, removal owned by REL-03). T-02-10 mitigated: the tick-rate cycle indexes only `TICK_RATES`.

## Next Phase Readiness

02-09 adds the dash cooldown and displacement: the overlay's dash distance will turn non-zero then, and `test_latency` already waits `config.dash_cooldown + 0.1 s` between dashes. 02-12 (tuning panel) and 02-13 (`measure_movement`) can read `MetricsOverlay.last_jump` / `last_dash` and `LatencyProbe.summary()`.

## Self-Check: PASSED

- All five created files and the modified test scene exist on disk and are tracked.
- Commits 34f4b6f, b35928f, 1b48340, 2039e02 are ancestors of HEAD on branch `dev`.
