---
phase: 4
slug: fernausl-ser-mechanism-kit
status: draft
nyquist_compliant: false
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

| Requirement | Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|----------|-----------|-------------------|-------------|--------|
| HAND-01 | Registry lists defs; dummy module needs no HandController change; each def's scene loads | unit/integration | `bash attimo/tests/run.sh hand_module` | ❌ W0 | ⬜ pending |
| HAND-02 | `can_accept(kind,size)` truth table; modules talk only to the contract; PulseHit carries size/point/direction/collider | unit | `bash attimo/tests/run.sh interactable` | ❌ W0 | ⬜ pending |
| HAND-03 | Tap < 0.4 s small, hold big, no fire without aim, cooldown, 15/25 m range, empty shot still fires, wall occludes | integration | `bash attimo/tests/run.sh pulse` | ❌ W0 | ⬜ pending |
| CAM-04 | Three shared stage materials only; non-interactables never use them | unit/scan | `bash attimo/tests/run.sh glow` | ❌ W0 | ⬜ pending |
| CAM-05 | Cone selection, hysteresis (no ping-pong), invalid never valid, sticky multiplier < 1, camera unchanged | integration | `bash attimo/tests/run.sh aim_assist` | ❌ W0 | ⬜ pending |
| MECH-01 | Every trigger/mechanism instantiates and behaves per D-15..D-21 | unit/integration | `bash attimo/tests/run.sh mechanism` | ❌ W0 | ⬜ pending |
| MECH-02 | AND/OR/timer truth tables, chaining, packed-scene round trip of exported refs | unit | `bash attimo/tests/run.sh logic` | ❌ W0 | ⬜ pending |
| MECH-03 | Rotating carry radial drift < 0.05 m at 60/10 TPS, no launch on start/stop, launch repeatability, knock-back leaves Dash | integration | `bash attimo/tests/run.sh platform_carry,player_launch` | ❌ W0 | ⬜ pending |
| Rooms | Gym builds, door exists, showcase covers every type, puzzle graphs resolve, one scripted pulse solve | integration | `bash attimo/tests/run.sh movement_gym,mechanism_rooms` | ❌ W0 | ⬜ pending |
| HUD | Reticle states, charge arc, hidden when not aiming | unit | `bash attimo/tests/run.sh crosshair` | ✅ extend | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `attimo/tests/smoke/test_hand_module.gd`, `test_interactable.gd`, `test_pulse.gd`, `test_aim_assist.gd`, `test_glow_stages.gd`
- [ ] `attimo/tests/smoke/test_logic_nodes.gd` (includes packed-scene export round trip, A1)
- [ ] `attimo/tests/smoke/test_mechanisms.gd`, `test_mechanism_carry.gd` (rotation spike, A2/A3), `test_player_launch.gd`
- [ ] `attimo/tests/smoke/test_mechanism_rooms.gd`
- [ ] Fixtures in `attimo/tests/fixtures.gd`: `spawn_interactable(...)`, `hold_action(tree, action, seconds)`

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

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
