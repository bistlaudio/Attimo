---
phase: 05-energy-arm-loader
plan: 03
subsystem: player-energy
tags: [energy, moto-perpetuo, hud, costs, tracer, presentation]
requires: [05-01, 05-02]
provides:
  - Full ArmEnergy (drain, gain, refuse, core_fill, passive_rate, tick, is_moto, charging), quantised energy_changed
  - Energy costs at the controller choke points (air dash, dash hop stage 2 and 3, wall run drain) with silent base fallbacks
  - Moto Perpetuo with hysteresis (run speed bonus, buffed Jump 3) and the charge button (R)
  - ArmEnergyPresentation (four forearm cores, Moto glow points, flash and flicker) and the complete EnergyHud
  - BoneAttach shared helper, EventBus energy_gained, energy_refused, moto_changed
affects: [05-04, 05-05]
tech-stack:
  added: []
  patterns: [single energy owner with a separate refuse path, polled read-only presentation on TimeFx.unscaled, state-owned gravity_scale restored in exit()]
key-files:
  created:
    - attimo/scripts/player/arm_energy_presentation.gd
    - attimo/scripts/ui/energy_hud.gd
    - attimo/scenes/ui/energy_hud.tscn
    - attimo/scripts/core/bone_attach.gd
    - attimo/tests/smoke/test_energy.gd
    - attimo/tests/smoke/test_energy_income.gd
    - attimo/tests/smoke/test_energy_costs.gd
    - attimo/tests/smoke/test_energy_hud.gd
    - attimo/tests/smoke/test_arm_energy_presentation.gd
  modified:
    - attimo/scripts/player/arm_energy.gd
    - attimo/scripts/player/player_controller.gd
    - attimo/scripts/player/movement_config.gd
    - attimo/scripts/player/states/wall_run.gd
    - attimo/scripts/player/states/jump.gd
    - attimo/scripts/hand/hand_presentation.gd
    - attimo/scenes/player/player.tscn
    - attimo/autoload/event_bus.gd
    - attimo/project.godot
    - attimo/tools/movement_gym_builder.gd
    - attimo/tools/movement_metrics.gd
    - attimo/scenes/test/movement_gym.tscn
    - docs/MOVEMENT-METRICS.md
    - docs/CONVENTIONS.md
key-decisions:
  - "Energy fixtures for tests and the measure tool are 40, not 100: enough for several injected moves but below the Moto threshold (50), so base run speed and Jump 3 keep being measured unbuffed"
  - "energy_changed is quantised: once per whole-number change or discrete spend/reset, at most once per physics frame; a second change in the same frame is sent by the next tick"
  - "Moto is polled by the presentation instead of listening to moto_changed, so a Moto that is already on at spawn also shows"
  - "The grey refusal flicker is two grey flashes (0.2 s on, 0.2 s off, 2.5 Hz) per refusal; a refusal during a running flicker does not restart it"
duration: "single session"
completed: 2026-11-24
---

# Phase 5 Plan 03: Energy economy, Moto Perpetuo and the energy HUD Summary

The arm is now a real battery: horizontal speed from 10 m/s charges it passively (3 to 6 per second), the R button charges it standing still, an air dash costs 10 (refused with the blocked-dash cue below that), dash hop stages 2 and 3 cost 15 each (silently stage 1 without it), and a wall run drains 15 per second after a free 0.6 s. From 50 energy Moto Perpetuo turns on (off below 47.5): 12 percent faster ground run, Jump 3 rises to 5 m, the forearm cores brighten and feet and back glow. Four forearm cores and the HUD (chambers, Moto badge, module plate, momentum gauge) show it.

## Commits

- b3718a4 feat(05-03): tracer: passive charge, HUD chambers, air dash cost and refusal (Task 1)
- 0ae13fd test(05-03): failing tests for hop and wall run costs, Moto Perpetuo and the charge button (Task 2 RED)
- 71c4f07 feat(05-03): hop and wall run costs with silent fallback, Moto Perpetuo, charge button (Task 2 GREEN)
- c08671e test(05-03): failing tests for the arm cores, Moto glow and the full energy HUD (Task 3 RED)
- e9c5818 feat(05-03): arm cores, Moto glow points and the complete energy HUD (Task 3 GREEN)

## What was built

- **ArmEnergy** is the only writer of the value (`_write`), every API ignores non-finite input and clamps 0..100. `try_spend` (all or nothing), `drain` (partial), `gain`, `refuse` (the only refusal path), `core_fill`, `passive_rate`, `tick` (passive curve plus the charge button), `is_moto` (hysteresis), `charging`.
- **Costs** at the existing choke points: `dash_locked_reason()` returns `&"energy"`, `_block_dash` adds `energy_refused`, `start_dash` pays in the air, `advance_long_jump_stage` pays stage 2 and 3 and falls back to stage 1 with no fact, `WallRun` drains after the free window and ends into Fall when dry.
- **Moto**: `ground_target_speed` times (1 + moto_run_bonus), `Jump.enter` sets the buffed Jump 3 (v0 from apex height and scaled gravity), new `Jump.exit()` restores `gravity_scale`.
- **MovementConfig**: group Energy (passive start/full speed, rate min/max, air dash cost, hop cost, wall run free time and cost, charge rate) and group Moto Perpetuo (threshold, exit margin, run bonus, jump height, jump gravity scale). All rows are in the metrics config snapshot.
- **Presentation**: `ArmEnergyPresentation` (greybox cores on the forearm attachment, spent flash, grey flicker, Moto glow points on foot.l, foot.r and chest, entry flash plus a PlaceholderTone beep, exit fade) and `EnergyHud` (CanvasLayer 9).

## Deviations from Plan

**1. [Process] Task 1 has no separate RED commit.** The tracer's tests and implementation went in one commit (b3718a4). Tasks 2 and 3 have a `test(05-03)` RED commit (run to fail first) followed by the `feat` commit.

**2. [Rule 1 - Bug] Fixtures use 40 energy, not 100.** With Moto the plan's `energy = 100` fixture would put every measurement in Moto (run speed 9.52, buffed Jump 3). The air-dash, hop and wall-run scenarios in test_dash, test_long_jump, test_wall_states and the measure tool's `_begin` set 40 (after the first physics frames, because `arm_energy` is an `@onready`). The base rows in MOVEMENT-METRICS.md are unchanged (only the new config rows and latency noise differ).

**3. [Rule 1 - Bug] Wall run at energy 0 does not end at exactly the free window.** The pad speed (10 m/s) equals `energy_passive_start_speed`, so the passive charge (3 per second) keeps feeding the drain for a few ticks. The test asserts the run ends into Fall after the free window plus a few ticks, well before `wall_run_time`, with no refusal fact; it does not assert "free time + 2 ticks". Passive charge was kept active during the wall run (only Loader and Capture pause it, per the plan).

**4. [Rule 1 - Bug] "A live dash-hop run from 25 ends above 25" is not true any more.** The stage 2 hop costs 15. The test starts at 5 so every hop is the free stage 1 and the passive charge shows.

**5. [Rule 1 - Bug] energy_changed quantisation gained a pending flag.** A second change in the same physics frame sets `_pending_emit` and the next tick sends it, so discrete spends are never lost while the once-per-tick rule holds.

**6. HUD detail beyond the plan text.** `health_slot_rect()`, `chambers_rect()` were added as read API so a test can assert the reserved health slot. Core placement offsets on the forearm bone are guesses (see human checks).

GAME-DESIGN.md was not edited: the Moto numbers and the charge button were already in section 3; the phase-end design check stays with the orchestrator.

## Verification

- Full suite `bash attimo/tests/run.sh`: tests=71, passed=3322 checks, failed=0, `RUN.SH: PASSED`.
- `--tool measure_movement.gd`: `MEASURE: PASSED`; `--tool build_movement_gym.gd`: `GYM: WRITTEN` (EnergyHud instanced once).
- Acceptance greps: `^signal energy_refused` 1, `func core_fill` 1, `return &"energy"` 1, `name="EnergyHud"` 1 in the gym, `energy_passive_start_speed` in MOVEMENT-METRICS.md, `^charge={` 1, `^signal moto_changed` 1, `func is_moto` 1, `try_spend(config.long_jump_cost` 1, `func exit` in jump.gd 1, `node name="ArmEnergyPresentation"` 1, `class_name ArmEnergyPresentation` 1, particle node references 0.
- Pre-existing log noise (not from this plan): `LogicTimer has no source` warnings, "2 resources still in use at exit".

## Human checks (not performed, deferred to the phase UAT)

1. In the gym: charge past 50 and back below 47.5; the four forearm cores read full, partial and empty at a glance (core offsets on the `lowerarm.r` bone are untested guesses and may sit inside the mesh).
2. Moto Perpetuo lights both feet and the back with a short flash on entry and fades on leaving; the arm brightens.
3. A refused air dash (below 10 energy) twitches and flickers the cores grey; a refused dash hop or a dry wall run shows nothing.
4. The HUD top left reads chambers, Moto badge, module name and the speed gauge without covering the crosshair; nothing flashes faster than three times a second; the turquoise-on-body exception (recorded in CONVENTIONS) feels right.
5. Feel: whether 3 to 6 per second passive charge and the 15 cost hop make players chase dashes (checklist item 1), and whether Moto run 9.52 m/s staying under the 10 m/s charge start is acceptable (flagged for playtest).

## Known Stubs

None. The Moto tone is a PlaceholderTone beep by design (real audio is Phase 14); capsules and machines (the rest of ENRG-02) arrive in 05-04.

## Threat Flags

None. T-05-08 (value written only by ArmEnergy, non-finite and over/underflow tests), T-05-09 (energy_changed quantised, emit-count test), T-05-10 (guarded span, zero-span test) are mitigated.

## Self-Check: PASSED
