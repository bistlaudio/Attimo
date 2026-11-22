---
phase: 04-fernausl-ser-mechanism-kit
plan: 03
subsystem: mechanisms
tags: [mechanism, triggers, logic, showcase]
requires: [04-01, 04-02]
provides:
  - Valve (Handrad-Ventil, big pulse only, heavy toggle)
  - EnergyCore (Energiekern, self-timed, pip ring as visible timer)
  - Crank (Uhrwerk-Kurbel, near-hold wind-up with dial)
  - LogicAnd, LogicOr, LogicTimer (invisible logic nodes)
  - Six showcase stations in room 2 of the gym
affects: [04-04, 04-05]
tech-stack:
  added: []
  patterns: [typed Array[SignalSource] export wired by node.set with a typed array, near_held flag consumed in _physics_process so winding and decay never double count]
key-files:
  created:
    - attimo/scripts/mechanisms/triggers/valve.gd, energy_core.gd, crank.gd
    - attimo/scripts/mechanisms/logic_and.gd, logic_or.gd, logic_timer.gd
    - attimo/scenes/mechanisms/valve.tscn, energy_core.tscn, crank.tscn
    - attimo/scenes/mechanisms/logic_and.tscn, logic_or.tscn, logic_timer.tscn
    - attimo/tests/smoke/test_triggers.gd, test_logic_nodes.gd
  modified:
    - attimo/tools/mechanism_rooms_builder.gd
    - attimo/scenes/test/movement_gym.tscn
    - attimo/tests/smoke/test_movement_gym.gd
key-decisions:
  - "Array[SignalSource] exports survive PackedScene.pack when the array is typed at the set site (A1 confirmed); no NodePath fallback needed"
  - "Valve wheel turns forward by half a revolution per toggle (accumulated), it never rewinds"
  - "Crank decay and winding are exclusive per tick through a flag set by near_held"
  - "A LogicTimer whose source is already active at _ready counts that as a rising edge"
  - "Energy core pips use their own emissive material, not the shared glow stages, so the glow stage guard stays strict"
metrics:
  tasks: 3
  completed: 2026-11-23
---

# Phase 4 Plan 03: Triggers and logic nodes Summary

The trigger set is complete (lever, valve, energy core, crank) and AND, OR and Timer logic nodes chain invisibly; room 2 of the gym shows one station per trigger and logic node, each driving a Zahnrad-Tor.

## Tasks

| Task | Commit | Result |
|------|--------|--------|
| 1 RED: stubs and failing tests | 29e9026 | Six stub classes, test_triggers, test_logic_nodes |
| 2 GREEN: triggers and logic nodes | 8bea725 | Three trigger scenes and scripts, three logic scenes and scripts |
| 3 Showcase stations | 528aa81 | Builder stations, regenerated gym, extended test_movement_gym |

Full suite green after the final fix (see Self-Check).

## Station layout (room 2)

North row z -12: Valve x 48, EnergyCore x 58 on a 4 m pillar, Crank x 68. South row z 12: AND x 48, OR x 58, Timer (4 s) x 68. Each gate stands 4 m towards the room centre. Free slots for 04-04: (73, 0, -12), (73, 0, 12) and the centre area x 52..64, z -4..4.

## Deviations from Plan

**1. [Rule 1 - Bug] Scene parent paths**
- Nested nodes in the generated tscn files (Needle bar, timer pips) used short parent names; fixed to full paths (`Dial/Needle`, `Lantern/TimerRing`).

**2. [Rule 1 - Bug] test_movement_gym picked the last GearGate**
- The existing door check took the last GearGate child of the zone; with station gates it picked a wrong one. It now reads the node `ZahnradTor`.

**3. [Rule 1 - Bug] Glow guard**
- The timer pips first reused glow_idle.tres without being Interactable glow meshes, which `test_glow_stages` (6) rejects. They now use their own emissive sub-resource material.

## Known Stubs

None. Greybox shapes only; visual polish and tuning (core_duration 6 s, wind_ratio, wheel speed) are for the human check in 04-05.

## Threat Flags

None. T-04-07 (null entries skipped with one warning, empty AND stays off, Timer without source stays off) and T-04-08 (set_active emits on change only, builder test asserts every source is wired) are implemented and tested.

## Self-Check: PASSED

Created files and commits 29e9026, 8bea725 verified present.
