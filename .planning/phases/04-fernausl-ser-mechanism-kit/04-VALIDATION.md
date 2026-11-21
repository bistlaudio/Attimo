---
phase: 4
slug: fernausl-ser-mechanism-kit
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-11-21
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Project-own headless smoke runner (`attimo/tests/run_smoke.gd`), Godot 4.7.2; each test is `extends RefCounted` with `run(tree, check)` |
| **Config file** | none (auto-discovers `res://tests/smoke/test_*.gd`); `attimo/tests/run.sh` wraps import + run + log grep |
| **Quick run command** | `bash attimo/tests/run.sh <filter>` (comma-separated substring filter) |
| **Full suite command** | `bash attimo/tests/run.sh` (prints `SMOKE SUMMARY` and `RUN.SH: PASSED`) |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash attimo/tests/run.sh <relevant filters>`
- **After every plan wave:** Run `bash attimo/tests/run.sh`
- **Before `/gsd:verify-work`:** Full suite must be green, plus a short manual play of the showcase and puzzle rooms
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

Filled by the planner per task (`<automated>` blocks in each PLAN.md). Requirement-level map:

| Requirement | Behavior | Test Type | Automated Command | Plan | File Exists | Status |
|-------------|----------|-----------|-------------------|------|-------------|--------|
| HAND-01 | Registry lists defs; dummy module needs no HandController change; each def's scene loads | unit/integration | `bash attimo/tests/run.sh hand_module` | 04-01 | ❌ W0 | ⬜ pending |
| HAND-02 | accepts_module + can_accept truth tables; modules talk only to the contract; PulseHit fields; NEAR fact on near_begin; near contact with hold via E | unit/integration | `bash attimo/tests/run.sh interactable,near_contact` | 04-01, 04-02 | ❌ W0 | ⬜ pending |
| HAND-03 | Tap < 0.4 s small, hold big, no fire without aim, cooldown, 15/25 m range, empty shot still fires, wall occludes, gym door opens | integration | `bash attimo/tests/run.sh pulse,mechanisms` | 04-01 | ❌ W0 | ⬜ pending |
| CAM-04 | Three shared stage materials only; non-interactables never use them | unit/scan | `bash attimo/tests/run.sh glow_stages` | 04-02 | ❌ W0 | ⬜ pending |
| CAM-05 | Cone selection, hysteresis (no ping-pong), invalid never valid (incl. wrong module), sticky multiplier < 1, camera unchanged | integration | `bash attimo/tests/run.sh aim_assist` | 04-02 | ❌ W0 | ⬜ pending |
| HUD | Reticle states, charge arc, module frame, hidden when not aiming | unit | `bash attimo/tests/run.sh crosshair` | 04-02 | ✅ extend | ⬜ pending |
| Arm-out / shot presentation | Shoot OneShot on pulse_fired, arm layer during near contact without strafe, F2 Hand rows | integration | `bash attimo/tests/run.sh aim_layer,aim_pose,tuning_panel,near_contact` | 04-02 | ✅ extend | ⬜ pending |
| MECH-01 | Lever + gear gate (04-01); valve, energy core, crank (04-03); lift, nozzle, conveyor, pendulum (04-04) behave per D-15..D-21 | unit/integration | `bash attimo/tests/run.sh mechanisms,triggers,moving_mechanisms,steam_nozzle,conveyor_pendulum` | 04-01, 04-03, 04-04 | ❌ W0 | ⬜ pending |
| MECH-02 | AND/OR/timer truth tables, chaining, packed-scene round trip of exported refs | unit | `bash attimo/tests/run.sh logic_nodes` | 04-03 | ❌ W0 | ⬜ pending |
| MECH-03 | Rotating carry (LYING, STANDING, TILTING) drift < 0.05 m at 60/10 TPS (go/no-go gate), lift/conveyor no launch, launch repeatability, knock-back leaves Dash | integration | `bash attimo/tests/run.sh mechanism_carry,player_launch,moving_mechanisms,steam_nozzle,conveyor_pendulum` | 04-04 | ❌ W0 | ⬜ pending |
| Rooms | Gym builds, door exists, showcase covers every type, puzzle graphs resolve, reset sweep, reachability vs MOVEMENT-METRICS, scripted solves | integration | `bash attimo/tests/run.sh movement_gym,mechanism_rooms` | 04-01, 04-03, 04-04, 04-05 | ✅ extend + ❌ W0 | ⬜ pending |
| Conventions | groups/layers docs in sync | existing | `bash attimo/tests/run.sh conventions` | 04-01 | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Each plan's first task (04-04: Task 1 for the spike test, Task 2 for the other stubs and tests) creates its tests plus typed stub scripts, so the project compiles and the tests fail on assertions (RED gate: exit code 1).

- [ ] 04-01: `attimo/tests/smoke/test_pulse.gd`, `test_hand_module.gd`, `test_interactable.gd`, `test_mechanisms.gd` (single-ref packed round trip, A1)
- [ ] 04-02: `test_aim_assist.gd`, `test_glow_stages.gd`, `test_near_contact.gd`; extend `test_crosshair.gd`
- [ ] 04-03: `test_triggers.gd`, `test_logic_nodes.gd` (Array[SignalSource] packed round trip, A1)
- [ ] 04-04: `test_mechanism_carry.gd` (rotation spike, A2/A3, go/no-go gate), `test_player_launch.gd`, `test_moving_mechanisms.gd`, `test_steam_nozzle.gd`, `test_conveyor_pendulum.gd`
- [ ] 04-05: `test_mechanism_rooms.gd`
- [ ] Extended existing tests: `test_movement_gym.gd` (04-01, 04-03, 04-04), `test_aim_layer.gd`, `test_tuning_panel.gd` (04-02), `test_conventions.gd` (unchanged, kept green)
- [ ] Fixtures in `attimo/tests/fixtures.gd` (04-01): `spawn_scene(...)`, `hold_action(tree, action, seconds)`

Each filter above was checked against the planned file names (run_smoke.gd does a substring match on `test_*.gd`).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Tap latency feel of the small pulse | HAND-03 | Feel, not measurable headless | Aim, tap LMB at a lever repeatedly; the reaction must feel instant |
| Glow and reticle readability over turquoise targets | CAM-04 | Visual judgement | Aim across the showcase; target and reticle states must read at a glance |
| Aim-assist and sticky-aim feel | CAM-05 | Feel | Sweep the crosshair across two close levers; no flicker, no camera pull |
| Nozzle and pendulum feel, carry smoothness while running on rotators | MECH-03 | Core-value feel | Ride every rotating/lift platform and conveyor, use each nozzle mode, get hit by the pendulum |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 90s (estimate ~60 s full suite, not yet measured; re-check on the first executor run)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
