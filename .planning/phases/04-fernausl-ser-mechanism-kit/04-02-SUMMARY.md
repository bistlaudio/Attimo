---
phase: 04-fernausl-ser-mechanism-kit
plan: 02
subsystem: hand, targeting, ui
tags: [targeting, aim-assist, glow, hud, near-contact, presentation]
requires: [04-01]
provides:
  - Targeting (cone snap, hysteresis, reticle state, sticky look factor)
  - Three shared glow stages on every Interactable
  - Goggle HUD in the Crosshair (rim arcs, gear reticle, charge arc, module frame)
  - Near contact with hold (interact) and HandController.arm_out
  - HandPresentation (palm glow, flash, streak, arm light)
  - F2 Hand section
affects: [04-03, 04-04, 04-05]
tech-stack:
  added: []
  patterns: [read-only presentation polling the hand_controller group, shared material instances per glow stage, sticky aim through a sensitivity multiplier instead of camera writes]
key-files:
  created:
    - attimo/scripts/hand/targeting.gd
    - attimo/scripts/hand/hand_presentation.gd
    - attimo/resources/mechanisms/glow_idle.tres, glow_aim.tres, glow_target.tres
    - attimo/tests/smoke/test_aim_assist.gd, test_glow_stages.gd, test_near_contact.gd
  modified:
    - attimo/scripts/hand/hand_controller.gd, modules/remote_trigger/remote_trigger.gd
    - attimo/scripts/mechanisms/interactable.gd, attimo/scenes/mechanisms/lever.tscn
    - attimo/scripts/ui/crosshair.gd
    - attimo/scripts/camera/camera_rig.gd (look_sensitivity_multiplier)
    - attimo/scripts/player/mannequin_animator.gd, attimo/scenes/player/player.tscn
    - attimo/scripts/debug/tuning_panel.gd
    - attimo/tests/smoke/test_crosshair.gd, test_aim_layer.gd, test_tuning_panel.gd
    - docs/CONVENTIONS.md
key-decisions:
  - "Only valid targets are held in Targeting.target; an exact crosshair hit on an invalid Interactable only sets state INVALID, so it gets no TARGET glow and no sticky aim"
  - "arm_out lives on HandController (hand presentation state), the animator reads it read-only and uses it only for the Aim layer weight and the solver target; aim edge, strafe, backward and dash node stay on player.aiming"
  - "Targeting.state is typed int because the global class State shadows the enum name in type positions"
  - "Shot assist re-casts a ray from the chest at the target point, then at the hit body centre, and falls back to the crosshair ray when line of sight fails"
metrics:
  tasks: 3
  completed: 2026-11-22
---

# Phase 4 Plan 02: Targeting, glow, goggle HUD, near contact Summary

Aiming now snaps the pulse onto glowing mechanisms: a cone assist with hysteresis and sticky look sensitivity (camera never pulled), three shared turquoise glow stages (target brightest and pulsing), a goggle HUD, and E as near contact with hold, arm-out and palm/arm glow.

## Tasks

| Task | Commit | Result |
|------|--------|--------|
| 1 RED: stubs and failing tests | f5b37e3 | Targeting/glow/Crosshair/CameraRig stubs, test_aim_assist, test_glow_stages, test_near_contact, extended test_crosshair |
| 2 GREEN: Targeting, glow stages, goggle HUD | 1be6d47 | targeting.gd, glow_*.tres, Interactable stages, Crosshair HUD, RemoteTrigger snapped shot, lever on glow_idle |
| 3 GREEN: near contact, presentation, F2 Hand | ad3e5cf | HandController near contact + arm_out, animator Shoot on pulse_fired, HandPresentation, Hand rows |

Full suite: 46 test files, 2032 checks, 0 failed (RUN.SH: PASSED).

## Deviations from Plan

**1. [Rule 3 - Blocking] Test-side fixes**
- The off-axis snap test uses 3 degrees instead of 2: at 8 m a 2 degree offset (0.28 m) still lies inside the 0.6 m hit body, so the crosshair would hit it and the snap would not be exercised.
- Levers in the new tests spawn parked far from the player (04-01's test_pulse spawns them at the origin, where the 0.8 m base pushes the player's capsule up; test_pulse still passes and was left unchanged).
- The near contact tests place the lever 1.2 m ahead instead of 1.5 m: the handle swings, so the aim point moved past hand_near_range (2.2 m) after the toggle and ended the contact (correct behaviour per the range rule).
- Tests start with `await tree.process_frame` (runner calls them before the root is in the tree).

**2. [Rule 1 - Bug] Freed target reference**
- `_set_target(null)` returned early when the previous target was a freed object, leaving a stale reference. Now it assigns the target before returning.

**3. [Rule 3 - Blocking] Typed state**
- `var state: State` in Targeting resolved to the global class `State`; the property is typed `int` and compared against `Targeting.State`.

**4. test_aim_layer h5**
- The Shoot OneShot now fires on the pulse at release, so h5 waits 2 physics frames before the process frames. Assertion intent unchanged; h2 unchanged.

## Known Stubs

None. Streak, palm and arm light positions sit on the bone origins without a tuned offset (visual tuning is for the human check in plan 04-05).

## Threat Flags

None. T-04-04 (hand_* rows are range-clamped, never saved, test asserts no hand_ key in settings.cfg) and T-04-05 (non-finite and zero-length directions give INF angle, acos input clamped) are implemented.

## Self-Check: PASSED

Files verified present; commits f5b37e3, 1be6d47, ad3e5cf exist.
