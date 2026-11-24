---
phase: "05"
slug: "energy-arm-loader"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-24"
---

# Phase 05 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Project-own headless smoke runner `attimo/tests/run_smoke.gd` (auto-discovers `res://tests/smoke/test_*.gd`; each test is `RefCounted` with `func run(tree, check)`) |
| **Config file** | none (`attimo/tests/run.sh` wraps version gate, repo checks, `--import`, run, log grep for `SCRIPT ERROR|Parse Error|Failed to load|Failed loading resource`) |
| **Quick run command** | `bash attimo/tests/run.sh <filter[,filter]>` (e.g. `test_loader,test_energy`) |
| **Full suite command** | `bash attimo/tests/run.sh` |
| **Gym regeneration** | `bash attimo/tests/run.sh --tool res://tools/build_movement_gym.gd` |
| **Mannequin tree regeneration** | `bash attimo/tests/run.sh --tool res://tools/build_mannequin_tree.gd` |
| **Metrics regeneration** | `bash attimo/tests/run.sh --tool res://tools/measure_movement.gd` |
| **Estimated runtime** | ~60-240 seconds (first `--import` can exceed 3 min) |
| **Godot binary** | Required for every command above (Godot 4.7.2-stable). NOT installed on the current Mac; set `GODOT=...` on the executing machine. Without it only grep/diff static guards run. |

---

## Sampling Rate

- **After every task commit:** Run `bash attimo/tests/run.sh <the task's filters>`
- **After every plan wave:** Run `bash attimo/tests/run.sh`
- **Before `/gsd-verify-work`:** Full suite green, freshly regenerated and committed `movement_gym.tscn`, `mannequin_tree.tres` and `docs/MOVEMENT-METRICS.md`, plus the human feel checklist below
- **Max feedback latency:** ~240 seconds

---

## Per-Task Verification Map

| Requirement | Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|----------|-----------|-------------------|-------------|--------|
| HAND-04 | Hold stores velocity; `Engine.time_scale` 0.25 and back to 1.0 on release, cap, teleport and free; cap counted in real ticks (72 ticks = 1.2 s) | smoke | `bash attimo/tests/run.sh test_loader` | ❌ W0 | ⬜ pending |
| HAND-04 / D-02, D-03 | Once per air phase, refilled on landing and by `refill_air_dash()`; discharge never changes `air_dash_available`; air control locked 0.15 s | smoke | `bash attimo/tests/run.sh test_loader` | ❌ W0 | ⬜ pending |
| HAND-04 | `LoaderMath.discharge_speed`: `max(stored, min_push) + bonus` capped; empty arm = no bonus + cooldown; spend only at release | unit-style smoke | `bash attimo/tests/run.sh test_loader_math` | ❌ W0 | ⬜ pending |
| HAND-04 | Trajectory preview landing point equals real flight landing (no input) within tolerance | smoke | `bash attimo/tests/run.sh test_loader_math` | ❌ W0 | ⬜ pending |
| FEEL-10 | Loader/Energy floats of `movement_default.tres` appear in `docs/MOVEMENT-METRICS.md` snapshot; Loader rows exist | smoke | `bash attimo/tests/run.sh test_movement_metrics` | extend existing | ⬜ pending |
| ENRG-01 | 0..100 clamp, 4 core fills, Moto Perpetuo at 50 with hysteresis, respawn sets exactly 25 | smoke | `bash attimo/tests/run.sh test_energy` | ❌ W0 | ⬜ pending |
| ENRG-02 / D-05..D-08 | Passive curve (below 10 m/s = 0, 10 = 3/s, 18 = 6/s), none in Loader/Capture; charge button only while still; source drain amounts and `respawn_time` | smoke | `bash attimo/tests/run.sh test_energy_income` | ❌ W0 | ⬜ pending |
| ENRG-03 | Ground dash free; air dash refused below cost with `dash_blocked` reason `&"energy"`; hop stage 2/3 cost, fallback to stage 1 without failure signal; wall run free 0.6 s then drains | smoke | `bash attimo/tests/run.sh test_energy_costs,test_dash_lockout` | ❌ W0 + rewrite | ⬜ pending |
| ENRG-04 / D-15 | No `aim` action, no `aim_changed` signal, no `aiming` property, no goggle nodes; crosshair always visible; Targeting active without a hold; no sticky multiplier | smoke (static guard) | `bash attimo/tests/run.sh test_aim_removed` | ❌ W0 | ⬜ pending |
| ENRG-05 / D-13, D-14 | HUD exists, reads `ArmEnergy`, 4 cores, Moto state, module name, speed gauge; ignores mouse; two charge rings distinct | smoke | `bash attimo/tests/run.sh test_energy_hud,test_crosshair` | ❌ W0 + edit | ⬜ pending |
| D-11 | Extractor cone drains only `energy_source` nodes in range, amounts per D-07, then dark | smoke | `bash attimo/tests/run.sh test_extractor` | ❌ W0 | ⬜ pending |
| D-17 / D-18 / D-19 | Tap = 10, hold up to 25 in ~0.8 s, below 10 refuses; projectile hits `Interactable` with `PulseHit.energy`; bends to locked target | smoke | `bash attimo/tests/run.sh test_shot` | rewrite of `test_pulse` | ⬜ pending |
| Criterion 6 / D-20 | Gym: Loader room, charge track, capsules, machine, per-move stations each with "Erwartet:" sign; no aim station | smoke | `bash attimo/tests/run.sh test_movement_gym,test_energy_gym` | edit + ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `attimo/tests/smoke/test_loader.gd`, `test_loader_math.gd`
- [ ] `attimo/tests/smoke/test_energy.gd`, `test_energy_income.gd`, `test_energy_costs.gd`, `test_energy_hud.gd`
- [ ] `attimo/tests/smoke/test_extractor.gd`, `test_aim_removed.gd`, `test_energy_gym.gd`
- [ ] `attimo/tests/fixtures.gd` helpers: `set_energy(player, value)`, time-scale guard (assert and reset `Engine.time_scale`, release `TimeFx` requests in teardown)
- [ ] Delete or rewrite every aim test from the RESEARCH removal inventory in the same task that removes the code
- [ ] Godot 4.7.2 binary available to the executor (`GODOT=...`)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Loader hold tension and release snap ("geladen"), 0.25x read, camera pull-back, hitstop | HAND-04 / D-04 | feel | Loader test room: hold RMB from run, dash and jump; release in several directions incl. up; tune on F2 |
| Two charge rings never confused | D-14 | visual | Charge a shot and a Loader back to back; both rings must read differently at a glance |
| Shot charge tell and bend noticeability | D-17 / D-19 | feel / visual | Hip-fire at targets while moving fast; full-charge flash must be obvious |
| Moto Perpetuo glow points, arm cores, HUD layout | ENRG-01 / ENRG-05 / D-09 / D-10 | visual | Charge past 50 and back; check arm, feet, back glow and HUD |
| Gym walk-through of every new station | Criterion 6 | feel / visual | Walk the Loader and energy area; each station matches its "Erwartet:" line |
| 60 TPS and 120 TPS spot check | HAND-04 | engine timing | Metrics overlay F6 cycles 60/120/10; repeat the Loader hold |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 240s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
