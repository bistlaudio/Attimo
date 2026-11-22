---
phase: 04-fernausl-ser-mechanism-kit
plan: 01
subsystem: hand, mechanisms
tags: [hand, pulse, interactable, mechanism, tracer, movement-gym]
requires: []
provides:
  - HandController with registry-driven modules (aim-gated charge, cooldown)
  - RemoteTrigger instant pulse with PulseHit
  - Interactable contract (HAND-02)
  - SignalSource / Mechanism bases, Lever, GearGate
  - Gym door into room 2 (tools/mechanism_rooms_builder.gd, build_into contract)
affects: [04-02, 04-03, 04-04, 04-05]
tech-stack:
  added: []
  patterns: [registry resource instead of directory scan, exported-ref wiring in generated scenes, worker builder with build_into(zone, builder)]
key-files:
  created:
    - attimo/scripts/hand/ (hand_controller, pulse_hit, hand_module, hand_module_def, module_registry, hand_context)
    - attimo/scripts/hand/modules/remote_trigger/, attimo/scripts/hand/modules/dummy/
    - attimo/resources/hand/module_registry.tres
    - attimo/scripts/mechanisms/ (interactable, signal_source, mechanism, gear_gate, triggers/lever)
    - attimo/scenes/mechanisms/lever.tscn, gear_gate.tscn
    - attimo/tools/mechanism_rooms_builder.gd
    - attimo/tests/smoke/test_pulse.gd, test_hand_module.gd, test_interactable.gd, test_mechanisms.gd
  modified:
    - attimo/autoload/event_bus.gd, attimo/scripts/camera/camera_rig.gd (aim_ray)
    - attimo/scenes/player/player.tscn, attimo/tools/movement_gym_builder.gd, attimo/scenes/test/movement_gym.tscn
    - attimo/tests/fixtures.gd, attimo/tests/smoke/test_movement_gym.gd, docs/CONVENTIONS.md
key-decisions:
  - "Lever visuals use raw Prototype Bits glTF meshes (cube, pillar) scaled down instead of the StaticBody wrappers, so no oversized WORLD collider occludes the hit body"
  - "GearGate holds the doorway open only once it started opening (progress > 0), so a closed gate does not open when the player walks up to it"
  - "Room-2 floor starts at x 43 with a 1 m beam threshold in the wall cell, closing the gap between hall floor (ends x 42) and room"
  - "Module switching (module_next/prev) only while aiming, since the wheel zooms the camera otherwise"
metrics:
  tasks: 3
  completed: 2026-11-22
---

# Phase 4 Plan 01: Fernauslöser tracer bullet Summary

Aim (RMB hold) plus LMB tap or hold fires a small or big instant pulse at the crosshair; it toggles a Lever through the Interactable contract and the wired Zahnrad-Tor rolls open in the generated movement gym as the door into a room-2 shell.

## Tasks

| Task | Commit | Result |
|------|--------|--------|
| 1 RED: stubs + four failing tests | 16bb0be | test_pulse, test_hand_module, test_interactable, test_mechanisms, fixtures hold_action/spawn_scene |
| 2 GREEN: hand framework, pulse, Interactable | 7194c53 | HandController, RemoteTrigger, dummy module, registry, seven EventBus facts, CameraRig.aim_ray |
| 3 GREEN: lever, gate, gym door | 2d3079f | SignalSource/Mechanism/Lever/GearGate, mechanism_rooms_builder, regenerated gym |

Full suite: 43 test files, 1970 checks, 0 failed (RUN.SH: PASSED).

## Deviations from Plan

**1. [Rule 1 - Bug] Doorway guard would open a closed gate on approach**
- The plan's guard ("keep target 1.0 while the doorway overlaps the player") also opens a closed gate when the player stands within 1 m of it. Fixed: the guard only applies while progress > 0.

**2. [Rule 1 - Bug] Floor gap at the door**
- Hall floor ends at x 42, plan room starts at x 44 and the wall cell is 42..43. Room floor now starts at x 43 and a beam threshold covers the wall cell.

**3. [Rule 3 - Blocking] Lever base built from raw glTF meshes**
- The primitive_cube_small wrapper has a 2 m WORLD collider that would block the pulse ray before the hit body. Used the glTF mesh scaled 0.4 plus a 0.8 m base collider, and the pillar mesh for the stick instead of the beam wrapper.

**4. [Rule 3 - Blocking] CONVENTIONS.md EventBus table**
- test_conventions requires every EventBus signal to be listed; the seven new facts were added to the doc in Task 2.

**5. Environment note**
- Godot 4.7.2 was not installed; the pinned zip was downloaded (SHA-512 verified against the README) into the session scratchpad and used via GODOT. Nothing was installed outside the scratchpad.

## Known Stubs

- Lever GlowLens uses a plain grey material; plan 04-02 switches it to the glow stages (planned).
- `build_showcase_stations` in the rooms builder is an empty extension point for plans 04-03 to 04-05 (planned).

## Threat Flags

None. T-04-01 (explicit res:// registry), T-04-02 (is_finite guards, aim_ray returns {} for non-finite hits), T-04-03 (debug_only dummy skipped in release) are implemented.

## Self-Check: PASSED

Files and commits 16bb0be, 7194c53, 2d3079f verified present.
