---
phase: 01-foundation-prototype-character
plan: 05
subsystem: greybox
tags: [godot, greybox, kaykit-prototype-bits, collision, smoke-test]

requires:
  - phase: 01-foundation-prototype-character
    provides: "tests/run.sh harness, run_smoke.gd runner (plan 01-01)"
provides:
  - "Four Prototype Bits wrapper scenes (floor, wall, cube_small, pillar): StaticBody3D, World layer 1, mask 0, one BoxShape3D each"
  - "Copied KayKit glTF/bin pieces and shared texture under attimo/assets/prototype_bits/ (byte-identical to originals)"
  - "test_proto_pieces smoke test: box-vs-mesh extents, bottom-centre origin, 1 m grid, static ray probe of each top face"
affects: [01-07, phase-02-movement]

actuals:
  tokens: 6500
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Wrapper scene per greybox piece: StaticBody3D > CollisionShape3D(BoxShape3D at h/2) + glTF instance named Mesh"
    - "Collision verified against the transform-aware merged MeshInstance3D AABB plus a static intersect_ray, not by eye"

key-files:
  created:
    - attimo/assets/prototype_bits/Primitive_Floor.gltf
    - attimo/assets/prototype_bits/Primitive_Floor.bin
    - attimo/assets/prototype_bits/Primitive_Wall.gltf
    - attimo/assets/prototype_bits/Primitive_Wall.bin
    - attimo/assets/prototype_bits/Primitive_Cube_Small.gltf
    - attimo/assets/prototype_bits/Primitive_Cube_Small.bin
    - attimo/assets/prototype_bits/Primitive_Pillar.gltf
    - attimo/assets/prototype_bits/Primitive_Pillar.bin
    - attimo/assets/prototype_bits/prototypebits_texture.png
    - attimo/scenes/proto/primitive_floor.tscn
    - attimo/scenes/proto/primitive_wall.tscn
    - attimo/scenes/proto/primitive_cube_small.tscn
    - attimo/scenes/proto/primitive_pillar.tscn
    - attimo/tests/smoke/test_proto_pieces.gd
  modified: []

key-decisions:
  - "Wrappers store World as the literal bitmask 1 (plan 01-07 asserts it against PhysicsLayers), as flagged in the plan"
  - "Test uses a const Dictionary path -> expected top height so later pieces are one line each"

patterns-established:
  - "Pattern: box primitives only for greybox collision, never trimesh (Jolt ghost edges)"

requirements-completed: [FOUND-05, FOUND-04]

coverage:
  - id: D1
    description: "Each wrapper is a StaticBody3D on layer 1 / mask 0 with exactly one BoxShape3D whose AABB equals the mesh AABB within 1 cm"
    requirement: "FOUND-05"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_proto_pieces"
        status: pass
    human_judgment: false
  - id: D2
    description: "A downward static ray hits each wrapper's top face at 1 m (floor), 2 m (cube_small), 4 m (wall, pillar); extents are whole metres with origin at bottom centre"
    requirement: "FOUND-05"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_proto_pieces"
        status: pass
    human_judgment: false
  - id: D3
    description: "Only the four pieces and the shared texture are copied; files are byte-identical to the tracked KayKit originals, which stay in place"
    requirement: "FOUND-04"
    verification:
      - kind: other
        ref: "cmp of all 9 files against KayKit/.../Assets/gltf originals exits 0; git ls-files --error-unmatch on originals exits 0"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-11-04
status: complete
plan_head_before: d6c3e7b7103eb0277dbbd98c3775339ad6b5fd10
plan_head_after: e068c37b7bf0bae7536aae0d312d29b277625cd2
---

# Phase 1 Plan 05: Prototype Bits Greybox Wrappers Summary

**Four KayKit Prototype Bits pieces (Floor 4x1x4, Wall 4x4x1, Cube_Small 2x2x2, Pillar 1x4x1) wrapped as World-layer StaticBody3D scenes with one matching BoxShape3D each, verified by a smoke test that compares shape to mesh extents and ray-probes every top face.**

## Performance

- **Duration:** ~8 min
- **Completed:** 2026-11-04
- **Tasks:** 2
- **Files created:** 14 (plus `.gltf.import` / `.png.import` / `.gd.uid` sidecars)

## Accomplishments

- Copied (cp, never mv) only the four pieces plus `prototypebits_texture.png` into `attimo/assets/prototype_bits/`; all 9 files are byte-identical to the tracked originals, which remain under `KayKit/`.
- Four hand-written format=3 wrapper scenes with path-only ext_resources: root StaticBody3D (layer 1, mask 0), CollisionShape3D with BoxShape3D centred at h/2, glTF instance named `Mesh`. No trimesh, no import-time physics.
- `test_proto_pieces` (17 assertions per wrapper, 68 in total) checks per wrapper: loads, root type, layer/mask, exactly one CollisionShape3D holding a BoxShape3D, box AABB equals the merged transform-aware mesh AABB within 0.01 m, mesh min y = 0 and horizontal centre at origin, whole-metre extents, and a static `intersect_ray` from y=10 to y=-10 that hits the wrapper itself at the expected top height. Nothing moves (D-09).
- The test was proven to bite: shrinking the wall box to height 3 produced three FAIL lines (box min, box size, top face at 3.5 vs 4.0); the file was restored before the commit.
- Full suite: `SMOKE SUMMARY: tests=3 passed=88 failed=0`, `RUN.SH: PASSED`.

## Task Commits

1. **Task 1: Floor and wall wrappers + ray-probe test** - `f27e702` (feat)
2. **Task 2: Cube_Small and Pillar reference blocks** - `e068c37` (feat)

## Deviations from Plan

None - plan executed exactly as written.

Process notes (not code deviations):
- The worktree branch was at `703e4c0`, not a descendant of `d6c3e7b`; it was reset to `d6c3e7b` as the orchestrator instructed before any work.
- The `GODOT` env var was not needed: `run.sh` falls back to the pinned `$HOME/Applications/Godot_4.7.2` binary, which exists.

**Total deviations:** 0. **Impact:** none.

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None. T-01-09 mitigated: files come only from the tracked CC0 `KayKit/` pack and `cmp` proves byte identity.

## Issues Encountered

None.

## Next Phase Readiness

Plan 01-07 can instance `res://scenes/proto/primitive_{floor,wall,cube_small,pillar}.tscn` directly. Origins are at the bottom centre, so floor tiles placed at y = -1 give a walkable top at y = 0. Phase 2 can add Stairs/Slope collision (MOVE-08) following the same wrapper pattern.

## Self-Check: PASSED

- All 14 created files exist; commits `f27e702` and `e068c37` are ancestors of HEAD.
