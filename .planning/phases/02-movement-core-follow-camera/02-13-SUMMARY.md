---
phase: 02-movement-core-follow-camera
plan: 13
subsystem: metrics
tags: [godot, gdscript, metrics, latency, documentation, headless-tool]
status: complete

requires:
  - phase: 02-movement-core-follow-camera
    provides: "02-07 floor snap and platforms, 02-08 LatencyProbe, 02-11 chain and LongJump"
provides:
  - "tools/measure_movement.gd: one command regenerates docs/MOVEMENT-METRICS.md from the real Player (scripted per-tick inputs, headless)"
  - "docs/MOVEMENT-METRICS.md: speeds, jump/double/Jump 2/dash/long-jump numbers, timing windows, floor limits, latency at 60 and 120 TPS with accumulated input on and off, grid cross-check, config snapshot"
  - "test_movement_metrics: 71 checks, a retuned movement_default.tres without a regenerated table fails the suite"
affects: [02-14, 07-gap-sizing]

actuals:
  tokens: 21000
  tasks: 2
  commits: 2

commits: 2
plan_head_before: 5cb724c39e39ddb16d5411d8f17501171a3dddcf
plan_head_after: b33688227fce9a4621f89cae9e48ceb6a037ad83

tech-stack:
  added: []
  patterns:
    - "A SceneTree script run with -s is compiled before the autoloads exist, so it cannot name a type that touches EventBus; it loads a RefCounted worker at run time (same idea as run_smoke.gd loading the tests)"
    - "Doc plus drift guard: the generated table carries a config snapshot and a smoke test compares it with the resource"

key-files:
  created:
    - attimo/tools/measure_movement.gd
    - attimo/tools/measure_movement.gd.uid
    - attimo/tools/movement_metrics.gd
    - attimo/tools/movement_metrics.gd.uid
    - attimo/tests/smoke/test_movement_metrics.gd
    - attimo/tests/smoke/test_movement_metrics.gd.uid
    - docs/MOVEMENT-METRICS.md
  modified: []

key-decisions:
  - "The tool is split in two files: measure_movement.gd (SceneTree loader, prints MEASURE: PASSED/FAILED, quits 0/1) and movement_metrics.gd (RefCounted worker with all measurement and doc code)."
  - "Latency presses and jump/dash presses go through Fixtures.send_action_event (the input pipeline, one press per tick, deterministic by tick counts) while held directions use Input.action_press; this is the pattern the existing tests already prove."
  - "The latency run starts the player at z -100: a dash without input goes toward the facing (+Z), and ten dashes from the default start would leave the 300 m floor."

patterns-established:
  - "Measurement helpers (_jump_flight, _fly, _dash, _long_jump) record EventBus facts and follow one airtime; distances are take-off fact to landed fact"

requirements-completed: [MOVE-10, FEEL-06]

coverage:
  - id: D1
    description: "bash attimo/tests/run.sh --tool res://tools/measure_movement.gd measures every verb headless and writes docs/MOVEMENT-METRICS.md; MEASURE: PASSED, RUN.SH: PASSED"
    requirement: "MOVE-10"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh --tool res://tools/measure_movement.gd"
        status: pass
    human_judgment: false
  - id: D2
    description: "The latency of jump and dash at 60 and 120 TPS, accumulated input on and off, is recorded and asserted: all medians 6.5 to 14.8 ms (target 66 ms), all maxima at most 20.3 ms (limit 100 ms)"
    requirement: "FEEL-06"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh --tool res://tools/measure_movement.gd (latency section, tool exits 1 on a violation)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The doc has every required row and its config snapshot equals movement_default.tres"
    requirement: "MOVE-10"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_movement_metrics (71 PASS, failed=0)"
        status: pass
    human_judgment: false
  - id: D4
    description: "End-to-end hardware latency (display, compositor, USB) and whether the measured jump and dash distances fit the gym"
    requirement: "FEEL-06"
    verification: []
    human_judgment: true
    rationale: "Outside the software measurement (D-22); stays a flagged human item in the 02-14 sign-off"

duration: 15 min
completed: 2026-11-05
---

# Phase 2 Plan 13: Movement Metrics and Latency Table Summary

**A headless tool drives the real Player with per-tick inputs and regenerates docs/MOVEMENT-METRICS.md (jump height and distance, dash distance, chain and long jump, floor limits, latency at 60 and 120 TPS), and a drift guard keeps the table in sync with movement_default.tres.**

## Performance

- **Duration:** 15 min
- **Tasks:** 2
- **Files:** 7 created, 0 modified

## Accomplishments

Measured with the shipped defaults at 60 TPS (full table in docs/MOVEMENT-METRICS.md):

- Run 7.00 m/s in 0.18 s, sprint 10.50 m/s.
- Tap jump 0.80 m, full jump 2.00 m (0.67 s airtime); run jump 4.78 m, sprint jump 7.18 m. Double jump 3.96 m total (second jump adds 2.00 m), 8.52 m from a run. Jump 2 2.60 m / 5.37 m.
- Ground and air dash 3.98 m in 0.18 s, exit speed 12.00 m/s; the air dash holds altitude (0.00 m change).
- Long jumps: 10.63 / 11.73 / 12.47 m with apexes 1.0 / 1.2 / 1.4 m, take-off at the capped dash speed 22.00 m/s; in the last grace tick they take off at the stage floors (14 / 15 / 17 m/s) and reach 6.77 / 8.00 / 9.63 m.
- Floor limits: steps 0.10 and 0.15 m are climbed, 0.20 and 0.25 m block (theory 0.18 m), the 45 degree slope is walkable (plateau in 2.27 s).
- Latency: jump and dash medians 6.5 to 14.8 ms, maxima at most 20.3 ms, at 60 and 120 TPS, with accumulated input on and off. Accumulation makes no relevant difference for key presses (RESEARCH A9). All cells meet the 66 ms target and the 100 ms hard limit.
- The tool exits 1 when a latency median exceeds 66 ms or a sample 100 ms, a tap jump is not lower than a held jump, the long-jump distances are not strictly increasing, or a long-jump take-off speed exceeds long_jump_speed_cap + 0.1.

## Task Commits

1. **Task 1: measure tool and generated doc** - `6d3dcd2` (feat)
2. **Task 2: test_movement_metrics** - `b336882` (test)

## Decisions Made

See key-decisions in the frontmatter.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The tool had to be split into a loader and a worker**
- **Found during:** Task 1 (first run)
- **Issue:** A SceneTree script run with `-s` is compiled before the autoloads exist. Referencing Fixtures, PlayerController or LatencyProbe from it fails with "Identifier not found: EventBus", so a single-file tool cannot work.
- **Fix:** `tools/measure_movement.gd` stays the entry point with the contract (`_initialize`, `MEASURE: PASSED/FAILED`, exit 0/1) and loads `tools/movement_metrics.gd` (RefCounted, `run(tree)` returns the failure messages) at run time. The plan listed one tool file; the worker is an additional file.
- **Files modified:** attimo/tools/measure_movement.gd, attimo/tools/movement_metrics.gd
- **Verification:** tool prints MEASURE: PASSED, RUN.SH: PASSED; test_project_settings sweeps both scripts
- **Commit:** 6d3dcd2

**2. [Rule 1 - Bug] Latency dash samples were missing in the first run**
- **Found during:** Task 1
- **Issue:** The player started at z 140 on a floor that ends at z 150; a dash without input goes toward +Z, so after three dashes the player left the floor and only 3 to 4 of 10 dash samples came in.
- **Fix:** The latency scenario starts at z -100.
- **Commit:** 6d3dcd2

### Plan wording

The plan says inputs go "only through Input.action_press / action_release". Held directions and sprint do; jump and dash use `Fixtures.send_action_event` (the input pipeline), which the existing jump, dash and long-jump tests use so a press and release in one tick still reaches the controller as just_pressed. Still deterministic and counted in physics ticks.

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug in the new tool). **Impact:** one extra file, no scope change.

## Issues Encountered

The tool takes about 4 minutes (latency runs in real time: 4 settings x 20 presses). The doc carries the generation date, so a regeneration always changes that line.

## Known Stubs

None.

## Threat Flags

None. T-02-18: the tool writes only the fixed path `res://../docs/MOVEMENT-METRICS.md`, built from a constant. T-02-19: the config snapshot and test_movement_metrics make a stale table fail the suite.

## Next Phase Readiness

Ready for 02-14 (gym and sign-off). The doc's grid cross-check gives the gap widths per verb (run jump 4 m, sprint jump 7 m, double jump 8 m, long jumps 10 to 12 m on the 1 m grid) for the gym markings. End-to-end hardware latency stays a human item for the sign-off (D-22).

## Self-Check: PASSED

- Files: measure_movement.gd, movement_metrics.gd, test_movement_metrics.gd (each with .uid) and docs/MOVEMENT-METRICS.md present
- Commits 6d3dcd2 and b336882 are ancestors of HEAD
- `bash attimo/tests/run.sh` (full suite): tests=23 passed=956 failed=0, `RUN.SH: PASSED`; the tool run printed `MEASURE: PASSED`
- All acceptance greps of both tasks returned the required counts (71 PASS lines for test_movement_metrics)
