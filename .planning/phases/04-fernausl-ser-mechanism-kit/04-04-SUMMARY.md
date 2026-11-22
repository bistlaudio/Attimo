---
phase: 04-fernausl-ser-mechanism-kit
plan: 04
subsystem: mechanisms
tags: [mechanism, moving-platform, carry, launch, knock-back, showcase]
requires: [04-01, 04-03]
provides:
  - RotatingPlatform (Dreh-Plattform, LYING / STANDING / TILTING) with reference-frame rider carry
  - LiftPlatform (Hub-Plattform, PISTON / CHAIN look)
  - Conveyor (Foerderband, RUN_WHILE_ON / REVERSE_ON_SIGNAL, eased)
  - SteamNozzle (Dampfduese, JUMP / UPDRAFT / CANNON / WALL)
  - Pendulum (Pendel, knock-back hazard without damage)
  - PlayerController.launch_along, push_toward, knock_back
  - 12 moving showcase stations in room 2 (room 2 now x 43..115)
affects: [04-05]
tech-stack:
  added: []
  patterns:
    - rider carried by reference frame (re-placed at the same local point every tick, engine platform carry switched off for the move)
    - platform ticks after the player (process_physics_priority 100)
    - one call rule: one-shot impulses via call_deferred, continuous pushes recorded as requests and consumed in the player's own tick
key-files:
  created:
    - attimo/scripts/mechanisms/rotating_platform.gd, lift_platform.gd, conveyor.gd, steam_nozzle.gd, pendulum.gd
    - attimo/scenes/mechanisms/rotating_platform.tscn, lift_platform.tscn, conveyor.tscn, steam_nozzle.tscn, pendulum.tscn
    - attimo/tests/smoke/test_mechanism_carry.gd, test_player_launch.gd, test_moving_mechanisms.gd, test_steam_nozzle.gd, test_conveyor_pendulum.gd
  modified:
    - attimo/scripts/player/player_controller.gd
    - attimo/tools/mechanism_rooms_builder.gd
    - attimo/scenes/test/movement_gym.tscn
    - attimo/tests/smoke/test_movement_gym.gd
key-decisions:
  - "Rotation carry ships as a third approach, not the plan's primary or fallback: reference-frame attach (see Spike)"
  - "Moving mechanism platforms tick after the player (process_physics_priority 100); the rider's carry depends on it"
  - "Steam updraft_accel and wall_accel default to 60 (the plan's 30 cannot beat rise gravity 34)"
  - "Room 2 grows to x 43..115; the 12 moving stations need the room, the puzzle rooms of 04-05 start behind x 115"
  - "Raised stations (Dreh-Plattform, Hub-Plattform, Pendel walkway) stand at y 1.0 so the moving body does not overlap the floor tiles"
metrics:
  tasks: 4
  completed: 2026-11-23
---

# Phase 4 Plan 04: Moving mechanisms Summary

The player can ride a gear, a clock hand, a tilting plate, a lift and a conveyor without sliding or being launched. Steam nozzles throw or push the player and a pendulum knocks them away. Room 2 has a lever-driven station for every moving mechanism, axis, look, behaviour and nozzle mode.

## Tasks

| Task | Commit | Result |
|------|--------|--------|
| 1 Rotation-carry spike (go/no-go gate) | feddd74 | RotatingPlatform, PlayerController carry, test_mechanism_carry; gate passed |
| 2 Entry points and failing tests | cd5e3a9 | launch_along, push_toward, knock_back; stubs; test_player_launch green, mechanism tests red |
| 3 Hub-Plattform and Dampfduese | 62ea660 | LiftPlatform and SteamNozzle, their tests green |
| 4 Foerderband, Pendel, showcase | a6750f1 and the builder commit | Conveyor and Pendulum, stations, regenerated gym |

## Rotation-carry spike (A2, A3)

Rider radius drift (worst change of the distance to the pivot, 3 s, includes the 0.3 s start ramp). Gate: below 0.05 m, grounded on at least 95 percent of ticks, relative speed below 0.3 m/s.

| Approach | LYING 60 | STAND 60 | TILT 60 | LYING 10 | STAND 10 | TILT 10 |
|----------|----------|----------|---------|----------|----------|---------|
| Engine only (custom carry off) | 0.0706 | 0.0371 | 0.0201 | 0.4408 | 0.2628 | 0.0390 |
| Plan primary: chord minus engine velocity, sync_to_physics true, platform ticks before player | 0.0000 | 0.2465 | 0.2039 | 0.0000 | 1.4054 | 1.3211 |
| Plan fallback: sync_to_physics false | identical to primary | | | | | |
| Primary, platform ticking after the player, previous-tick chord | 0.0001 | 0.0606 | 0.0158 | 0.0017 | 0.1806 | 0.0381 |
| **Shipped: reference-frame attach** | **0.0000** | **0.0379** | **0.0232** | **0.0000** | **0.0290** | **0.0111** |

All three axes were grounded on 100 percent of ticks. Relative speed to the platform (after the start ramp) was at most 0.237 m/s (STANDING at 10 TPS), 0.134 m/s at 60 TPS.

Findings:
- Godot with Jolt reports the same platform velocity for an AnimatableBody3D with sync_to_physics true and false, so the plan's fallback is the same measurement as the primary.
- The Jolt body trails the node pose by exactly one tick. A velocity based carry (engine tangent or chord) double counts the surface motion along its normal on tilted plates: the rider hovers up to the snap length and the vertical snap then shifts it along the slope (drift 0.25 to 1.4 m). Pure rotation about the vertical (LYING) has no normal motion and was fine with both.
- Setting `platform_floor_layers = 0` really switches the engine carry off for a move, which the shipped approach relies on.

Shipped approach: in `_integrate`, before the velocity is composed, `PlayerController._attach_to_carrier` puts the rider at the same local point of the carrying_platform body it stood on at the end of the last tick (`_carry_local`), with `platform_floor_layers = 0` for that move so the engine adds nothing. The own movement of the tick happens on top. The platform must tick after the player (RotatingPlatform sets `process_physics_priority = 100`), so its body pose is the world the player's move sees. `carry_velocity_at(point, delta)` (chord of the last tick) is only the take-off momentum (`_last_platform_velocity`). Guarded by `MAX_CARRY_SHIFT` (2 m) and finite checks. Still exactly one `move_and_slide()`.

## Call rule and player API

- `launch_along` (JUMP and CANNON, `call_deferred`): sets the velocity along the direction to the exact speed, keeps sideways momentum, leaves Dash/LongJump/Jump for Fall, leaves air dash charge and cooldown alone, emits `launched`. Apex repeats to 3 digits.
- `push_toward` (UPDRAFT and WALL, called directly each tick): only records a request; `_apply_push_requests` consumes it in the player's own `_physics_process` after `_tick_aim`.
- `knock_back` (Pendel, `call_deferred`): adds the impulse (caller supplies the up part), enters Fall, emits `knocked_back`.
- No mechanism script writes player velocity or calls `move_and_slide` (grep gate returns 0).

## Showcase layout (room 2 is now x 43..115)

Old part: nozzles JUMP (58, 0), UPDRAFT (68, 0), CANNON (74, -12), WALL (74, 12), each with a lever 2.5 to 3 m beside it. Extension, north row z -12: Dreh-Plattform LYING x 80, STANDING x 90, TILTING x 100, Pendel bridge x 110 (two beams, 1 m high, the bob swings over the deck). Centre row z 0: Hub-Plattform PISTON x 80, CHAIN x 90. South row z 12: Foerderband RUN_WHILE_ON x 84 and REVERSE_ON_SIGNAL x 102, both along +X, 16 m long. Raised stations stand at y 1.0 (jump onto them). Free: (100, 0) and (110, 0) in the centre row. Stations are at least 6 m apart. Puzzle rooms (04-05) have to start behind x 115.

## Deviations from Plan

**1. [Rule 1 - Bug] Rotation carry approach changed after measuring**
- **Found during:** Task 1 spike
- **Issue:** both the plan's primary and fallback fail the gate on STANDING and TILTING (drift 0.2 to 1.4 m), see table.
- **Fix:** reference-frame attach plus platform-after-player priority (see Spike). The `carrying_platform` contract and `carry_velocity_at` stay.
- **Files modified:** player_controller.gd, rotating_platform.gd
- **Commit:** feddd74

**2. [Rule 1 - Bug] updraft_accel default 60 instead of 30**
- **Issue:** rise gravity is 34 m/s^2, a push of 30 m/s^2 can never lift the player.
- **Fix:** updraft_accel and wall_accel default to 60.

**3. [Rule 3 - Blocking] Room 2 enlarged**
- **Issue:** the 6 existing stations left no room for 12 more, with 8 m plates and 16 m belts.
- **Fix:** ROOM_X_MAX 75 to 115 and the station plan above.

**4. [Rule 1 - Bug] Lift tests at 10 TPS allow one tick of lag**
- **Issue:** the engine carries the rider with the previous step's velocity, so at 10 TPS it trails the lift by speed * dt = 0.2 m and shows 0.59 m/s right after the stop.
- **Fix:** the 0.1 m and 0.5 m/s limits get one tick of travel (speed * dt) added; at 60 TPS the numbers are 0.033 m and 0.114 m/s. The 10 TPS rate is diagnostic only (A22).

**5. Plan wording**
- Piston and chain looks use plain meshes (cylinder and thin boxes), not the proto pillar and beam scenes, because those wrappers carry collision shapes that would ride with the lift body.
- The pendulum with the signal off finishes its swing and stops at the bottom (test added).
- The conveyor slats scroll with the belt so the motion is readable.

## Known Stubs

None. All shapes are greybox; tuning (nozzle speeds, pendulum timing, plate sizes) is for the human feel check in 04-05.

## Threat Flags

None. T-04-09 (non-finite vectors and speeds ignored in launch_along, push_toward, knock_back; carry shift guard; vertical_speed clamped to terminal_speed) and T-04-10 (call rule above, grep gate, one `move_and_slide`) are implemented and tested.

## Self-Check: PASSED

Commits feddd74, cd5e3a9, 62ea660, a6750f1 verified present; created scripts, scenes and tests exist; full suite green (53 tests, 2188 checks, 0 failed).
