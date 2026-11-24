---
phase: 05-energy-arm-loader
fixed_at: 2026-11-24T21:03:44Z
review_path: .planning/phases/05-energy-arm-loader/05-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 5: Code Review Fix Report

**Fixed at:** 2026-11-24T21:03:44Z
**Source review:** .planning/phases/05-energy-arm-loader/05-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6 (CR-01, WR-01..WR-05; Info findings out of scope)
- Fixed: 6
- Skipped: 0

**Verification:**
- Full suite `bash attimo/tests/run.sh` after all seven commits: RUN.SH: PASSED, 73 tests, 3572 checks passed, 0 failed. The baseline before the fixes was 3544 passed, 0 failed. The 28 new checks come from the fixes. The "5 ObjectDB instances leaked / 2 resources still in use" exit warnings appear in the baseline too.
- `bash attimo/tests/run.sh --tool res://tools/measure_movement.gd` (run after WR-05 and again after the WR-02 follow-up): MEASURE: PASSED both times. The only diff in `docs/MOVEMENT-METRICS.md` was the four wall-clock latency rows. Those rows are run-to-run noise; all of them still meet the target. Every deterministic movement row was unchanged, including the whole base jump chain, so the file was not committed.
- Each new test was checked against the code without its fix: it fails there and passes with the fix.
- Not caused by these fixes: the filtered run `run.sh test_dash` hits `SCRIPT ERROR: Nonexistent function 'reset_to' in base 'Nil'` (fixtures.gd:151 from test_dash.gd:373). It already happens at the pre-fix commit 07dcfeb, which was checked in a separate detached worktree. The full suite run does not show it.

## Fixed Issues

### CR-01: Shot energy is destroyed when the module changes during a charge

**Files modified:** `attimo/scripts/hand/modules/remote_trigger/remote_trigger.gd`, `attimo/tests/smoke/test_shot.gd`
**Commit:** 04662b3
**Applied fix:**
- `RemoteTrigger.deactivate()` now refunds the energy paid for an active charge through a new `_refund()`. `_refund()` calls `ArmEnergy.gain` and emits one `energy_gained(amount, &"shot_refund")`.
- `_fire()` now checks the projectile, the parent and the direction before it resets `_spent` and starts the cooldown, and refunds on the early return.
- New test_shot scenario (11): at 60 energy, hold for 0.4 s, switch to the extractor mid-hold, then release. It expects no shot, energy back at 60, one refund fact, and spent and gained facts that balance on the bus.

### WR-01: `TimeFx.unscaled(delta)` gives a wrong real delta on every frame the time scale changes

**Files modified:** `attimo/autoload/time_fx.gd`, `attimo/tests/smoke/test_time_fx.gd`
**Commit:** 86f1788
**Engine fact checked first:** A headless probe on Godot 4.7.2 (`--fixed-fps 60` and `--fixed-fps 30` at 60 TPS) confirmed what the reviewer could not verify:
- `Main::iteration()` reads `Engine.time_scale` once per iteration.
- A write during a physics tick leaves that frame's process delta at the old scale. One frame showed `delta=0.016667` while `Engine.time_scale` already read 0.25.
- It also leaves the second physics step of the same iteration at the old scale.
- Every physics step and the process step of one iteration share the same `Engine.get_process_frames()` value.
**Applied fix:**
- TimeFx captures the engine scale once per process frame in `_sync_frame_scale()`. It runs at the top of `_apply()` and of `unscaled()`, so the capture always happens before TimeFx, the sole writer, changes the scale.
- `unscaled()` divides by that captured per-iteration scale.
- There is no wall clock, so the Loader hold accounting stays deterministic.
- The test_time_fx check that called `unscaled()` in the same frame as the request now waits a frame. New checks: on the change frame `unscaled()` still divides by the old scale (1.0, and 0.25 when 0.05 lands); on the next frame it uses 0.25 and then 0.05.
- Effect on feel: on the Loader enter frame and the release-hitstop frame, the camera follow, LoaderLook, HUD and crosshair no longer see 4x or 5x real time. Every other frame is unchanged.

### WR-02: A ground Loader discharge can leave the floor without spending `loader_available` (D-02 bypass)

**Files modified:** `attimo/scripts/player/states/loader.gd`, `attimo/scripts/player/player_controller.gd`, `attimo/tests/smoke/test_loader.gd`
**Commits:** 9c61a43, b634d20 (follow-up)
**Status:** fixed: requires human verification (logic / design rule)
**Applied fix:**
- The release spends `loader_available` for a ground entry when the throw lifts off (`velocity.y > 0`) or when Rino is no longer grounded at the release, for example after skidding off a ledge mid-hold.
- A ground throw that stays on the floor sets a new `PlayerController.loader_ground_throw`. `_leave_floor()` spends the air use when Rino walks off with it set (`vertical_speed <= 0`). The flag is cleared on landing, on any floor exit (a jump take-off keeps the old rule), and once the speed on the floor falls back to `ground_target_speed()`.
- Follow-up b634d20: the first version cleared the flag at `run_speed` (8.5). A Moto run holds 9.52, so the flag never cleared, and any walk-off later in that run spent the air Loader. That would have been a regression in a common state. The threshold is now `ground_target_speed(Vector3.FORWARD) + 0.05`, so it covers the Moto run too.
- The reviewer's alternative, always spend and give back on landing, was rejected. A ground throw that never leaves the floor fires no landing, so a later cliff walk-off would deny an air Loader he never used.
- New test_loader scenario (l1..l3): a standing ground press on a 6 m floor, then a throw slightly down that carries Rino over the ledge. In the air, `loader_available` is false and a second press does not enter the Loader.
- New test_loader scenario (m1..m4): at 80 energy, so Moto stays on after the bonus, a ground throw is followed by a held-forward Moto run off the far end of a 40 m floor. The use stays available and an air press enters the Loader. The scenario was checked to fail with the first version.
- Human check: in the gym (Loader_Gap), confirm three cases. Ground throw, then over the ledge, then air Loader is now refused. Ground throw, then jump, then air Loader still works. Ground throw, then a run (also in Moto), then a walk-off much later, then air Loader still works.

### WR-03: `ArmEnergy.drain` emits `energy_spent` on every physics tick and floods the EventBus and the EventLog

**Files modified:** `attimo/scripts/player/arm_energy.gd`, `attimo/scripts/player/states/wall_run.gd`, `attimo/scripts/hand/modules/remote_trigger/remote_trigger.gd`, `attimo/tests/smoke/test_shot.gd`, `attimo/tests/smoke/test_energy_costs.gd`
**Commit:** 9647006
**Applied fix:**
- `ArmEnergy.drain()` is silent now.
- The new `ArmEnergy.report_spent(total, reason)` emits one `energy_spent`, so ArmEnergy stays the only emitter of the fact.
- WallRun adds up its drain and reports it in `exit()`.
- RemoteTrigger adds up the charge drain and reports it once at the release, or before the refund. A cancelled shot therefore balances on the bus: spent 10 plus the drain, gained the same total.
- New checks: a full shot hold gives exactly two `energy_spent(shot)` facts (the tap cost and the charge total). A paid wall run gives exactly one `energy_spent(wall_run)` of about 7.5.

### WR-04: The LoaderLook vignette and desaturation get stronger on an early release instead of fading out

**Files modified:** `attimo/scripts/ui/loader_look.gd`, `attimo/tests/smoke/test_loader_look.gd`
**Commit:** c327530
**Applied fix:**
- LoaderLook keeps `_last_ratio` from the last held frame and always applies `level * (0.5 + 0.5 * _last_ratio)`, so the release only fades.
- New test_loader_look scenario (e1) samples the vignette strength on every process frame across a short-hold release.
- Before the fix the strength jumped from 0.332 to 0.479. After the fix the maximum after the release equals the last held 0.332.

### WR-05: A tapped Moto Perpetuo Jump 3 is lower than a tapped normal Jump 3

**Files modified:** `attimo/scripts/player/states/air_state.gd`, `attimo/tests/smoke/test_energy.gd`
**Commit:** a30fb0a
**Status:** fixed: requires human verification (feel)
**Applied fix:**
- `apply_jump_cut()` multiplies the cut speed by `sqrt(actor.gravity_scale)` only while `gravity_scale > 1.0`. The tap apex `cut^2 * s / (2 * g * s)` is then `jump_min_height` again.
- Only the Moto Jump 3 runs above scale 1; Dash, Loader, WallRun and Capture use 0 to 0.1. The base chain numbers and the base rows in MOVEMENT-METRICS.md are therefore unchanged, which the regenerated metrics confirmed.
- New test_energy check (b4): tapped normal Jump 3 0.800 m, tapped Moto Jump 3 0.800 m. Before the fix the Moto tap was 0.552 m.
- Human check: confirm that a short tap of Jump 3 in Moto feels right with the faster rise.

---

_Fixed: 2026-11-24T21:03:44Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
