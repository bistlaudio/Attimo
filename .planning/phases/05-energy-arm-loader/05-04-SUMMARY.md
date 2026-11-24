---
phase: 05-energy-arm-loader
plan: 04
subsystem: hand-modules
tags: [extractor, energy-source, shot, projectile, aim-assist, crosshair]
requires: [05-01, 05-02, 05-03]
provides:
  - EnergySource block, energy_capsule.tscn (+40 in 0.5 s) and broken_machine.tscn (+60 in 2 s)
  - Extractor hand module (hold, cone and range, gain into the arm)
  - HandModule callbacks (pressed, held, released, charge_ratio, holds_arm_out, arm_point, uses_targeting), keys 1 and 2, cycle_ids
  - ShotProjectile and the shot module (tap 10, hold to 25, refusal below 10, bend, range by charge, cap 4)
  - PulseHit.energy and size_for_energy, EventBus shot_fired, shot_fully_charged, energy_source_emptied
  - Energy-gated glow (SHOT_READY and TARGET), stronger assist defaults, notched clockwise shot ring with a full-charge flash
affects: [05-05]
tech-stack:
  added: []
  patterns: [swept-ray projectile without a physics body, module callbacks routed by the controller, size derived from an energy payload]
key-files:
  created:
    - attimo/scripts/mechanisms/energy_source.gd
    - attimo/scenes/mechanisms/energy_capsule.tscn
    - attimo/scenes/mechanisms/broken_machine.tscn
    - attimo/scripts/hand/modules/extractor/extractor.gd
    - attimo/scripts/hand/modules/extractor/extractor.tscn
    - attimo/scripts/hand/modules/extractor/extractor_def.tres
    - attimo/scripts/hand/shot_projectile.gd
    - attimo/scenes/hand/shot_projectile.tscn
    - attimo/tests/smoke/test_extractor.gd
    - attimo/tests/smoke/test_shot.gd (renamed from test_pulse.gd)
  modified:
    - attimo/scripts/hand/hand_controller.gd
    - attimo/scripts/hand/hand_module.gd
    - attimo/scripts/hand/modules/remote_trigger/remote_trigger.gd
    - attimo/scripts/hand/modules/dummy/dummy_module.gd
    - attimo/scripts/hand/pulse_hit.gd
    - attimo/scripts/hand/targeting.gd
    - attimo/scripts/hand/hand_presentation.gd
    - attimo/scripts/ui/crosshair.gd
    - attimo/scripts/player/mannequin_animator.gd
    - attimo/resources/hand/module_registry.tres
    - attimo/autoload/event_bus.gd
    - attimo/project.godot
    - docs/CONVENTIONS.md
    - docs/ANIMATION-MAP.md
key-decisions:
  - "The bend replaces the old snapped ray: the projectile starts along the crosshair and turns toward the locked target's target_point at hand_shot_turn_rate, so _snapped_hit was removed from the shot module"
  - "pulse_fired now fires at projectile impact or expiry; the Shoot animation, the arm-out timer and arm_out_point follow shot_fired (the launch) instead"
  - "The debug dummy module keeps uses_targeting() true so a lever it does not accept still reads INVALID; only the Extractor drops the assist"
  - "shot_ready is false at the HandController _ready (the player ArmEnergy @onready is not set yet) and settles on the first physics tick"
duration: "single session"
completed: 2026-11-24
---

# Phase 5 Plan 04: Extractor, the energy-priced shot and readable hip fire Summary

Left click now has two modules on the wheel and keys 1 and 2. The Extractor drains glowing capsules (+40 in 0.5 s) and broken machines (+60 in 2 s) into the arm; the shot is a visible flying ball that costs 10 as a tap and up to 25 as a charge, bends into a locked target, carries its energy as the PulseHit payload and opens heavy mechanisms only at a full charge.

## Commits

- f53ff43 feat(05-04): tracer: Extractor module, energy source capsule, module keys and HandModule hold callbacks (Task 1)
- 8116772 feat(05-04): the shot as an energy-priced flying projectile with hybrid charge and energy payload (Task 2)
- c999165 feat(05-04): stronger snap with bend, energy-gated glow, notched clockwise shot ring, broken machine (Task 3)

## What was built

- **EnergySource** (kit block with interface doc): `amount`, `duration`, `respawn_time` (0 never), `glow_meshes`, `core`; `extract(delta, limit)`, `is_available()`, `target_point()`, `reset()`; groups `energy_source` and `mechanism` (so FallReset resets it); never touches the player or ArmEnergy.
- **Extractor**: holds on the available source with the smallest angle inside `hand_extract_angle` (35) and `hand_extract_range` (4 m), takes `min(rate*delta, left, room)` and calls `ArmEnergy.gain`; a full arm leaves the rest in the source; one `energy_gained(total, &"extractor")` per drain run.
- **HandModule contract change**: `wants_charge` and `on_use_released(big)` are gone. The controller routes pressed (not during the cooldown), held (every tick), released; `cycle_ids()` skips debug-only defs; `start_cooldown()`; `Targeting.release()` while the module does not use the assist.
- **Shot** (`RemoteTrigger`, id kept): the press pays 10 or refuses (`energy_refused(&"shot", 10)`); after `hand_shot_tap_time` the hold drains 15 over 0.8 s, `shot_fully_charged` once, a dry arm keeps what was spent; the release spawns a `ShotProjectile` (range 15 to 25 by charge, 40 m/s, bend 540 deg/s).
- **ShotProjectile**: no body, one swept ray per tick on World and Interactable, non-finite input frees it, cap of 4 live (the oldest goes), `PulseHit.energy` and `size_for_energy` (BIG from 25), triggers through the unchanged Interactable contract, one `pulse_fired` at impact or expiry.
- **Readability**: assist defaults 7 deg, hold factor 1.8, drop delay 0.15 s; `shot_ready` needs the shot module and `can_afford(hand_shot_cost_min)`; TARGET only under that condition (else IDLE with the lock still reported, `Targeting.refresh_glow` on a flip); the crosshair shows one notched ring turning clockwise filled by the charge with a 0.15 s flash on full charge (`shot_ring_style` vs `loader_ring_style`); palm flash and an 880 Hz placeholder beep on the full charge; the beam streak is deleted.

## Deviations from Plan

**1. [Process] Task 1 and Task 2 tests landed in the same commit as their code, not as separate RED commits.** Tasks 2 and 3 were run for failures along the way, but the plan marked them `tdd` and no separate `test(...)` commits exist.

**2. [Rule 1 - Bug] The old snap tests assumed an instant ray.** test_aim_assist (2) waited 3 ticks for the lever to toggle; with a flying shot it waits up to 60 ticks. The "6 degrees off is not a target" assertion became "6 degrees locks, 16 degrees does not" with the new 7 degree default.

**3. [Rule 1 - Bug] The dummy module lost the reticle INVALID state.** Gating `Targeting` on `uses_targeting()` made the dummy read NONE; `DummyModule.uses_targeting()` returns true so test_aim_assist scenario 1 and the debug behaviour are kept.

**4. [Rule 3 - Blocking] MannequinAnimator and HandPresentation listened to `pulse_fired`.** They now listen to `shot_fired` (the launch), otherwise the Shoot animation, palm flash and arm-out would fire at impact. docs/ANIMATION-MAP.md and CONVENTIONS.md updated.

**5. The "speed 18 m/s" bend test is a teleported player**, not a real dash hop: the test moves the player 0.3 m per tick sideways while the tap shot flies. It proves the bend, not the dash feel.

**6. The shot test for the lever 4 degrees off sets `hand_assist_angle = 7.0` explicitly** in test_shot (10) because Task 2 was committed before the Task 3 default change; the value now equals the default.

GAME-DESIGN.md was not edited: the Extractor, the shot costs and the full-charge tell are already described in sections 5 and the change log; the phase-end design check stays with the orchestrator.

## Verification

- Full suite `bash attimo/tests/run.sh`: tests=72, passed=3432 checks, failed=0, `RUN.SH: PASSED`.
- Acceptance greps: `extractor_def.tres` in the registry 1, `^module_1={` 1, `func wants_charge` 0, `class_name EnergySource` 1, `var energy: float` in pulse_hit 1, `class_name ShotProjectile` 1, test_shot exists and test_pulse is gone, `^signal shot_fired(` 1, `^signal shot_fully_charged(` 1, `_streak` in hand_presentation 0, `can_afford(hand_shot_cost_min)` 1, `shot_fully_charged` in crosshair 2, `hand_assist_angle` default 7.0.

## Human checks (not performed, deferred to the phase UAT)

1. In the gym: tap and hold-fire at levers and the valve from the hip; the shot is a visible flying ball (never a beam), grows while charging, the full-charge moment (ring flash, palm flash, beep) is unmistakable, an empty arm only flickers grey.
2. Charge a shot and then a Loader back to back: the notched clockwise shot ring and the double counter-clockwise Loader ring never read the same, also with colour ignored.
3. Hip-fire at a lever while dash-hopping past it: the snap is clearly noticeable and the ball bends in; the target only brightens when the arm can pay.
4. Extractor feel: drain a capsule and a broken machine, the arm points at the source, the dark and respawn look, no more than 3 flashes per second (D-17 exception recorded in the plan).
5. Core numbers (7 degrees, 540 deg/s turn rate, 40 m/s, 4 m extract range) are F2 starting values to tune by feel.

## Known Stubs

None. There are no capsules or machines placed in the gym yet (plan 05-05 builds the stations); the beep is a PlaceholderTone by design.

## Threat Flags

None. T-05-11 (cap 4, range expiry, tests), T-05-12 (non-finite rejection, swept ray, 120 m/s cap), T-05-13 (cycle_ids skips debug-only), T-05-14 (EnergySource never touches the arm, modules use gain, try_spend, drain, refuse) are mitigated.

## Self-Check: PASSED
