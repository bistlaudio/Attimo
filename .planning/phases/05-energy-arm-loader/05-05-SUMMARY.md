---
phase: 05-energy-arm-loader
plan: 05
subsystem: gym-energy-area
tags: [gym, energy-area, metrics, docs, tracer, drain-plate]
requires: [05-01, 05-02, 05-03, 05-04]
provides:
  - Zone_Energy (x -115..-239, z -26..26) with the open doorway from the Loader room, charge track, capsule, machine, charge spot, boost line, drain plate, air dash, dash hop, wall run and shot stations
  - EnergyDrainPlate (gym-only Area3D, empties the arm through ArmEnergy.reset_to) and energy_drain_plate.tscn
  - Respawning capsules next to every Auslöser shot station, every puzzle room entry and the Loader gap and super jump
  - Hip-fire sign wording (no aim hold, no old pulse sizes)
  - FEEL-10 energy rows in docs/MOVEMENT-METRICS.md, test-guarded
  - GAME-DESIGN.md, site, deck, ROADMAP and REQUIREMENTS updated to the built Phase 5
affects: [05.1, 06, 07]
tech-stack:
  added: []
  patterns: [gym worker with station groups, sizes from config and HandController defaults, drain plate beside a capsule for base versus injected try]
key-files:
  created:
    - attimo/tools/energy_area_builder.gd
    - attimo/scripts/gym/energy_drain_plate.gd
    - attimo/scenes/mechanisms/energy_drain_plate.tscn
    - attimo/tests/smoke/test_energy_gym.gd
  modified:
    - attimo/tools/loader_room_builder.gd
    - attimo/tools/movement_gym_builder.gd
    - attimo/tools/mechanism_rooms_builder.gd
    - attimo/tools/puzzle_rooms_builder.gd
    - attimo/tools/movement_metrics.gd
    - attimo/scenes/test/movement_gym.tscn
    - attimo/tests/smoke/test_loader_room.gd
    - attimo/tests/smoke/test_movement_gym.gd
    - attimo/tests/smoke/test_mechanism_rooms.gd
    - attimo/tests/smoke/test_movement_metrics.gd
    - docs/MOVEMENT-METRICS.md
    - docs/GAME-DESIGN.md
    - docs/game-design.html
    - docs/attimo-presentation.html
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md
key-decisions:
  - "Zone_Energy uses z -26..26 like the Loader room (tiles centred on 4 j), not the plan's -24..24"
  - "FallResetLoader now ends on the shared wall line x -115 (it reached x -116) so the two fall resets never overlap"
  - "The dash-hop chain test starts from an empty arm so every hop is the free stage 1; stage 2 would cost 15 and hide the charge"
duration: "single session"
completed: 2026-11-24
---

# Phase 5 Plan 05: Energy area, capsules at every shot, energy metrics and docs Summary

The gym now shows the whole energy core: from the Loader room the player runs through an open doorway over floor into Zone_Energy (114 m charge track, capsule, broken machine, charge spot, boost line, one station per injected move with a drain plate and a capsule side by side, and two shot stations), every shot puzzle has a respawning capsule within 8 m, signs speak of tapping and charging, FEEL-10 has measured energy rows, and the design docs match the build.

## Commits

- b233ddc test(05-05): failing Zone_Energy contract, route and live charge-track and capsule checks (RED)
- 0de6811 feat(05-05): Zone_Energy tracer: doorway from the Loader room, charge track and capsule station (Task 1)
- 870cc4e feat(05-05): energy and shot stations, drain plates, capsules next to every shot, hip-fire signs (Task 2)
- b59f02d feat(05-05): FEEL-10 energy rows in the movement metrics, measured from the real player (Task 3, metrics)
- bcfee40 docs(05-05): design docs, roadmap and requirements match the built Phase 5 (Task 3, docs)

## What was built

- **Zone_Energy** (`tools/energy_area_builder.gd`): floor flush from the Loader room's west wall line, walls north, south and west only, `FallResetEnergy` (x -115..-239 only, respawn `Respawn_Energy` with one core through `PlayerController.respawn`), `x_range` meta (-239, -115). The Loader room's `LoaderWallWest_0` cell is no longer built, so the z -2..2 lane is plain floor from the Loader room through the doorway.
- **Stations** (each a direct child with a sign and an "Erwartet:" line): Energy_Track (114 m, a mark every 10 m), Energy_Capsule, Energy_Machine (8 s respawn), Energy_ChargeSpot, Energy_Drain, Energy_BoostLine (7 always-on rings every 16 m), Energy_AirDash (8 m pit, between a run jump and run jump plus air dash), Energy_DashHop (marks at the cumulative stage 1-3 reach computed from the config), Energy_WallRun (12 m pad over a pit), Shot_TapVsFull (lever at tap range + 5 m, valve needing a full charge, gear gate), Shot_Moving. Sign numbers (air dash cost, hop cost, wall run window, tap and full range) are read from the config and the HandController defaults.
- **EnergyDrainPlate**: Hazard layer, Player mask, `reset_to(0)` deferred; its mesh is a 0.02 m slab with no body, so it is not a step.
- **Capsules next to shots**: `Capsule_<tag>` beside Valve, EnergyCore, LogicAnd, LogicOr and LogicTimer (6 s), a `Capsule` per puzzle room with room meta `capsule`, `Capsule_Gap` and `Capsule_SuperJump` in the Loader room (5 s).
- **Signs**: Valve reads "Handrad-Ventil (voll geladener Schuss)", EnergyCore "Ein Schuss lädt den Kern"; no label contains RMB, Zielen or the old pulse sizes.
- **Metrics**: `_measure_energy()` measures passive charge at exactly 10, 14 and 18 m/s (3.0, 4.5, 6.0 per second), the charge button (5.0/s), capsule (+40 in 0.50 s) and machine (+60 in 2.00 s), the cost rows from config and HandController, Moto Perpetuo run speed (9.52 m/s) and Jump 3 apex (5.00 m); invariants fail the tool when a row drifts from its config.

## Deviations from Plan

**1. [Rule 3 - Blocking] z range -26..26 instead of -24..24.** Tiles are centred on 4 j, so edges fall at +-22 or +-26; the zone copies the Loader room (z +-26, walls at +-26.5), as 05-02 did.

**2. [Rule 1 - Bug] FallResetLoader reached x -116.** It was `X_EAST - X_WEST + 2` wide; it now ends at x -115 so the overlap test with `FallResetEnergy` holds. The hall edge side is unchanged.

**3. [Rule 3 - Blocking] test_loader_room asserted `LoaderWallWest_0` exists.** The file is not in the Task 1 list; the assertion now expects the cell open (and `LoaderWallWest_1` standing).

**4. No separate threshold beam.** The Loader floor ends at x -115 and the energy floor starts at x -115, so the doorway needs no extra tile.

**5. Dash-hop chain test starts at energy 0, not 25.** Stage 2 costs 15 and a 3 s chain from 25 nets below 25, so an empty arm (every hop the free stage 1) is the clean "chain raises the arm" test; plain running is still checked from 25 and ends at exactly 25. The test presses dash and jump for two physics frames (one frame did not start the long jump).

**6. One capsule per Loader station instead of one capsule in total.** The gap launch and the super jump marker are 40 m apart, so `Capsule_Gap` and `Capsule_SuperJump` each stand within 8 m of their marker.

**7. Capsule-near-shot test scope.** It checks the Auslöser stations that need a shot (from the `stations` meta), each puzzle room's `Respawn` marker and the Zone_Energy shot stations, not every `accepts_shot` Interactable (that would sweep in every mover lever of all seven rooms).

**8. [Process] Task 2 and Task 3 have no separate RED commits.** Only Task 1 got a `test(...)` RED commit; Task 2 tests and code were committed together, the Task 3 row labels and metrics code too. Plan 05-04 took the same deviation.

**9. test_showcase_layout and test_movement_gym count thresholds unchanged.** They still pass (33 stations stay in the `stations` meta, Label3D count stays above 40); only CONTRACT_NODES gained `Zone_Energy`. The 48 "Erwartet:" lines are asserted in test_energy_gym.

## Verification

- Full suite `bash attimo/tests/run.sh`: tests=73, passed=3544 checks, failed=0, `RUN.SH: PASSED`.
- `--tool build_movement_gym.gd`: `GYM: WRITTEN`; `--tool measure_movement.gd`: `MEASURE: PASSED` (docs/MOVEMENT-METRICS.md regenerated and committed, gym regenerated and committed, `git status` clean apart from the docs commit).
- Acceptance greps: `Zone_Energy` 502 occurrences in the gym, `energy_capsule.tscn` 1, `broken_machine.tscn` 1, `energy_drain_plate.tscn` 1, `Erwartet:` 48 (39 at the start of this plan), `großer Puls` 0, `| Passive charge 18 m/s |` and `| Moto Perpetuo Jump 3 |` once each, `Phase 5 executed` in GAME-DESIGN.md, `placeholder drain via hold-interact` 0 in ROADMAP.md, EXTR-01 note present.
- Pre-existing noise (not from this plan): `LogicTimer has no source` warning in test_look_pass and test_logic_nodes.

## Human checks (not performed, deferred to the phase UAT)

1. Walk the whole west wing from the hall: Loader room, doorway, Zone_Energy. Each station does what its "Erwartet:" line says, the empty try (drain plate) and the charged try (capsule) of every injected move are one step apart, a capsule is always within reach of a shot puzzle, no sign talks about aiming.
2. Re-check the Phase 04.1 UAT items for the changed Auslöser stations (Valve, EnergyCore, the logic stations) and the three puzzle rooms (capsules added, signs reworded); 04.1 UAT is still partial.
3. Phase-end walkthrough at 60 and 120 TPS (ROADMAP criterion 6), then read GAME-DESIGN.md, the site and the deck once and confirm they describe the game as it plays.
4. The gap course still needs a 4 m jump from the hall floor to island 4 to reach the Loader door (05-02 note): confirm that is acceptable or add a bridge.
5. The station placements (air dash pit 8 m, wall-run pad pit, tap-vs-full lever distance) are sized from metrics but untested by feel; adjust by hand-play.

### Tuning log

| Knob | Old -> New | Reason | Binary-search step |
|------|------------|--------|--------------------|
| (none) | - | No F2 session happened in this automated run | - |

## Known Stubs

None. The deck and site content edits are text only.

## Threat Flags

None. T-05-15 (the drain plate is gym-only, documented in its class header, uses `reset_to` deferred), T-05-16 (gym and metrics regenerated with the tools, drift guarded by the gym contract tests and the metrics snapshot test) and T-05-17 (no new external script or font URL in the HTML) are mitigated.

## Self-Check: PASSED
