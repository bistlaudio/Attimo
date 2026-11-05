---
phase: 02-movement-core-follow-camera
plan: 03
subsystem: assets
tags: [prototype-bits, assets, collision-wrappers, slopes, stairs, asset-hygiene]
status: complete

requires:
  - phase: 01-project-foundation
    provides: Prototype Bits wrapper pattern (primitive_floor.tscn), test_asset_hygiene whitelist, run.sh originals guard
provides:
  - Primitive_Slope and Primitive_Beam copied byte-identical into attimo/assets/prototype_bits (gltf, bin, import)
  - res://scenes/proto/primitive_slope.tscn, a 45 degree wedge with one ConvexPolygonShape3D on the World layer
  - res://scenes/proto/primitive_beam.tscn, a 4 x 1 x 1 box with its top at y 1.0 (stair riser and ledge piece)
  - 31-entry asset whitelist and run.sh originals guard for both new pieces
affects: [02-07, 02-14]

actuals:
  tokens: 4200
  tasks: 2
  commits: 2
plan_head_before: 16564d97d1e8aca482f61c9a87d2af03b88b0197
plan_head_after: ce80546fb03e2a0f3120f4b2cf7b0c1c84115ca9
commits: 2

tech-stack:
  added: []
  patterns:
    - "Slope uses a six-point ConvexPolygonShape3D (no box, no trimesh), per CLAUDE.md and the Jolt ghost-edge rule"
    - "Beam reuses the generic box checks in test_proto_pieces; Slope gets its own _check_slope coroutine"

key-files:
  created:
    - attimo/assets/prototype_bits/Primitive_Slope.gltf
    - attimo/assets/prototype_bits/Primitive_Slope.bin
    - attimo/assets/prototype_bits/Primitive_Slope.gltf.import
    - attimo/assets/prototype_bits/Primitive_Beam.gltf
    - attimo/assets/prototype_bits/Primitive_Beam.bin
    - attimo/assets/prototype_bits/Primitive_Beam.gltf.import
    - attimo/scenes/proto/primitive_slope.tscn
    - attimo/scenes/proto/primitive_beam.tscn
  modified:
    - attimo/tests/run.sh
    - attimo/tests/smoke/test_asset_hygiene.gd
    - attimo/tests/smoke/test_proto_pieces.gd

key-decisions:
  - "Only Slope and Beam are copied (A37); Cube, Floor_Hole and other Prototype Bits stay in KayKit/ until a plan needs them"
  - "Gym stairs use Beam risers of at most 0.15 m sunk into the floor; no step-up code (A4)"

requirements-completed: [MOVE-08]

coverage:
  - id: D1
    description: "Slope and Beam are copied byte-identical from the tracked KayKit originals, whitelist pins exactly 31 asset files, run.sh exits 4 if either original becomes untracked"
    requirement: MOVE-08
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_asset_hygiene"
        status: pass
    human_judgment: false
  - id: D2
    description: "primitive_slope.tscn is a 45 degree wedge on the World layer: ray at x 0 hits y 2.0, at x -1 hits y 3.0, normal 45 degrees from up"
    requirement: MOVE-08
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_proto_pieces"
        status: pass
    human_judgment: false
  - id: D3
    description: "primitive_beam.tscn is a 4 x 1 x 1 box on the World layer with its top at y 1.0"
    requirement: MOVE-08
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_proto_pieces"
        status: pass
    human_judgment: false
---

# Phase 2 Plan 03: Slope and Beam Prototype Bits Summary

**Primitive_Slope and Primitive_Beam copied from the KayKit Prototype Bits pack with a convex 45 degree wedge collider and a 4 x 1 x 1 box collider, the 31-file asset whitelist and run.sh originals guard updated.**

## Performance

- **Tasks:** 2 of 2
- **Files:** 11 (8 created, 3 modified)
- **Task commits:** 89daee9, ce80546

## Accomplishments

- Copied Slope and Beam (gltf and bin, byte-identical, `cmp` clean) into `attimo/assets/prototype_bits/`; the originals stay tracked in `KayKit/`. The Godot import step generated the two `.gltf.import` files, which are committed.
- `test_asset_hygiene` whitelist extended from 25 to 31 entries, `run.sh` ORIGINALS guards both new originals (exit 4 if untracked).
- `primitive_slope.tscn`: StaticBody3D on layer 1, mask 0, one `ConvexPolygonShape3D` with the six wedge vertices. `primitive_beam.tscn`: StaticBody3D with a `BoxShape3D` of 4 x 1 x 1 centred at y 0.5.
- `test_proto_pieces` now checks the Beam through the generic box path (top 1.0) and the Slope through `_check_slope`: single convex shape with 6 points, ray at x 0 hits y 2.0, at x -1 hits y 3.0, normal exactly 45 degrees from up (walkable under the 50 degree `floor_max_angle`).

## Verification

- `bash attimo/tests/run.sh test_proto_pieces,test_asset_hygiene,test_project_settings` ended with `SMOKE SUMMARY: tests=3 passed=120 failed=0` and `RUN.SH: PASSED`.
- `bash attimo/tests/run.sh test_proto_pieces` ended `passed=98 failed=0`, `RUN.SH: PASSED`.
- All task acceptance greps passed (ConvexPolygonShape3D count 1, `size = Vector3(4, 1, 1)` count 1, `primitive_beam.tscn` and `_check_slope` present in the test).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Pre-existing, out of scope: `test_proto_pieces` prints two `ERROR: Condition "!is_inside_tree()"` engine messages for the first wrapper (`primitive_floor`), from `global_position` / `global_transform` being read while the scene root is not yet in the tree on the first call from `_initialize`. They are not test failures (every check passes) and predate this plan. Not fixed here.

## Known Stubs

None.

## Threat Flags

None.

## Next Phase Readiness

02-07 can prove the player on the Slope and on Beam risers (0.15 m climb, 0.25 m ledge block), and 02-14 can build the movement gym from both pieces.

## Self-Check: PASSED

- All 8 created files exist on disk and are tracked.
- Commits 89daee9 and ce80546 are ancestors of HEAD on branch `dev`.
