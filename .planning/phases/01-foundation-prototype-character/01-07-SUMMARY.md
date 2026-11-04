---
phase: 01-foundation-prototype-character
plan: 07
subsystem: test-scene
tags: [godot, test-scene, greybox, asset-hygiene, phase-gate]

requires:
  - phase: 01-03
    provides: "Player states (Idle, Run, Jump, Fall, Dash) and MannequinAnimator"
  - phase: 01-05
    provides: "Prototype Bits wrapper scenes (floor, wall, cube_small, pillar)"
  - phase: 01-06
    provides: "EventLog overlay scene"
provides:
  - "res://scenes/test/test_scene.tscn: the Prototype Bits test scene, set as run/main_scene (F5)"
  - "test_scene_run: composition, wall placement and simulated play-through guards on the real scene"
  - "test_asset_hygiene: fixed 25-file asset whitelist, no raw pack inside the project, D-05 folder layout"
  - "run.sh repository checks (exit 4): KayKit packs and copied originals stay tracked, no Git LFS"
affects: [phase-02-movement, phase-15-release-strip]

actuals:
  tokens: 9500
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Hand-written format=3 scene generated once from a throwaway script kept out of the repo"
    - "Fixed-at-planning-time whitelist guard: a new asset is a deliberate edit of the list in the same change"
    - "Repo-state checks (git ls-files) live in run.sh because the Godot runtime cannot query git"

key-files:
  created:
    - attimo/scenes/test/test_scene.tscn
    - attimo/tests/smoke/test_scene_run.gd
    - attimo/tests/smoke/test_asset_hygiene.gd
  modified:
    - attimo/project.godot
    - attimo/tests/run.sh

key-decisions:
  - "run.sh exit code 4 is reserved for repository-check failures; the checks are skipped for --tool runs"
  - "Wall overlap test shrinks each wall AABB by 1 cm before intersecting, so touching edges do not count as overlap"

requirements-completed: [FOUND-01, FOUND-04, FOUND-05, FEEL-01]

coverage:
  - id: D1
    description: "run/main_scene opens the Prototype Bits test scene with floor, wall ring, 1/2/4 m blocks, Player, EventLog, one static camera, one sun, plain sky"
    requirement: "FOUND-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_scene_run"
        status: pass
    human_judgment: false
  - id: D2
    description: "Only Prototype Bits wrappers and the Mannequin provide meshes; every StaticBody3D is on World; no particle nodes; glow, fog, volumetric fog, SDFGI off"
    requirement: "FOUND-05"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_scene_run"
        status: pass
    human_judgment: false
  - id: D3
    description: "Actions drive the Mannequin in place: move_forward gives Locomotion blend 1.0, jump ends with landed, dash reaches the Dash node within 3 frames; the four facts reach the event log; the Player never moves (D-09)"
    requirement: "FEEL-01"
    verification:
      - kind: integration
        ref: "bash attimo/tests/run.sh test_scene_run"
        status: pass
    human_judgment: false
  - id: D4
    description: "assets/ holds exactly the 25 whitelisted files, no kaykit directory or .fbx/.obj inside the project, D-05 folders exist"
    requirement: "FOUND-04"
    verification:
      - kind: unit
        ref: "bash attimo/tests/run.sh test_asset_hygiene (plus a mutation probe with Primitive_Cube.gltf that failed as required)"
        status: pass
    human_judgment: false
  - id: D5
    description: "run.sh fails when the KayKit packs or copied originals are untracked, or an LFS filter is declared"
    requirement: "FOUND-04"
    verification:
      - kind: other
        ref: "two mutation probes (LFS line in attimo/.gitattributes; renamed original path) each exited 4 with a RUN.SH: FAILED line"
        status: pass
    human_judgment: false
  - id: D6
    description: "Visual quality of the play-through: clips look right in place, facing follows the pressed direction, event log readable, nothing glows or particles, camera static"
    requirement: "FOUND-01"
    verification: []
    human_judgment: true
    rationale: "Clip playback, facing and overlay readability are visual judgments; see Human verification needed"

duration: 20min
completed: 2026-11-04
status: complete
commits: 2
plan_head_before: d4a16156209f60436a2dc29b09921ba7f8ae8e00
plan_head_after: f30b96e1883f11e3a576c9a1e5c984bea865ad88
---

# Phase 1 Plan 07: Prototype Bits Test Scene and Asset-Hygiene Guard Summary

**F5 now opens a static Prototype Bits test scene (20x20 m floor, 20-wall ring with open corners, 1/2/4 m reference blocks, Player with Mannequin, event log, fixed camera, sun, plain sky), proven headless with simulated input, and a permanent guard enforces the 25-file asset whitelist plus tracked KayKit originals and no Git LFS.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-11-04
- **Tasks:** 2
- **Files:** 3 created (plus `.gd.uid` sidecars), 2 modified

## Accomplishments

- `test_scene.tscn` is a hand-written format=3 scene with path-only ext_resources, produced by a throwaway generator in the session scratchpad (not committed). 25 Floor tiles at y -1 (top at y 0), 20 walls at y 0 just outside the floor (north/south rows unrotated, east/west columns rotated 90 degrees about Y, corners open), `Step_1m` (Floor wrapper at 0,0,-6), `Block_2m` (Cube_Small at 5,0,-5), `Pillar_4m` (Pillar at -5.5,0,-5.5), Player at (0,0,4), EventLog, `Camera` at (0,9,16) pitched -30 degrees, `Sun` with shadows, and a `ProceduralSkyMaterial` sky with sky ambient. No particles, no extra lights, no scripts besides the instanced ones.
- `project.godot` gained only `run/main_scene="res://scenes/test/test_scene.tscn"`.
- `test_scene_run` (104 checks) asserts the main scene setting, exactly one PlayerController with layer Player and mask World, every StaticBody3D on World, all 54 meshes under a `res://scenes/proto/` wrapper or the Mannequin scene, no particle node, Environment with glow/fog/volumetric fog/SDFGI off, one current script-free Camera3D, one DirectionalLight3D, a hidden EventLog, 20 walls with bottom at y 0 and no overlapping pairs. It then drives actions: move_forward gives Locomotion with blend 1.0, jump ends with `landed` (54 frames), dash reaches the Dash node and records one `dash_started`; the Player stays at (0,0,4) with zero velocity; the log contains jumped, landed, dash_started and movement_state_changed.
- `test_asset_hygiene` (11 checks) holds the verbatim 25-path `WHITELIST` (including the two pre-declared Mannequin texture extractions), fails per stray file and per missing entry, scans all of `res://` (skipping hidden folders) for `*kaykit*` directories and `.fbx`/`.obj` files, and checks the D-05 folders plus `tests` and `tools`.
- `run.sh` runs repository checks after the version gate and before import: at least one tracked file under `KayKit/`, `git ls-files --error-unmatch` for the nine copied originals (paths quoted for spaces), and no `filter=lfs` in `attimo/.gitattributes` or a root `.gitattributes`. Failures print `RUN.SH: FAILED (repo check: ...)` and exit 4.
- Full suite: `SMOKE SUMMARY: tests=13 passed=464 failed=0`, `RUN.SH: PASSED`, no `FAIL [` lines, a PASS line for each of the 13 phase test files.

## Task Commits

1. **Task 1: Test scene, main scene setting and play-through test** - `4fd2ade` (feat)
2. **Task 2: Asset-hygiene guard and run.sh repository checks** - `f30b96e` (test)

## Mutation Probes (all restored, working tree clean afterwards)

- Copied `Primitive_Cube.gltf` into `attimo/assets/prototype_bits/`: `FAIL [test_asset_hygiene] unlisted file in res://assets: prototype_bits/Primitive_Cube.gltf` (and its generated `.import`), exit non-zero. Both files removed.
- Appended an LFS filter line to `attimo/.gitattributes`: `RUN.SH: FAILED (repo check: Git LFS filter declared ...)`, exit 4. File restored.
- Renamed the Primitive_Wall original path inside run.sh: `RUN.SH: FAILED (repo check: original is not tracked ...)`, exit 4. Script restored byte-identical.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Worktree HEAD lacked the wave base commit**
- **Found during:** startup
- **Issue:** `git merge-base --is-ancestor d4a1615 HEAD` failed (HEAD was at `703e4c0`)
- **Fix:** tree was clean, so `git reset --hard d4a1615` in my own worktree branch as instructed
- **Files modified:** none

**2. [Rule 1 - Bug] Removed a vacuous check from my own test**
- **Found during:** Task 1 review
- **Issue:** a draft line `check.call(true, ...)` for the mesh-ancestor rule always passed
- **Fix:** replaced by a counted `unsanctioned == 0` check that fails per offending mesh
- **Files modified:** `attimo/tests/smoke/test_scene_run.gd`
- **Commit:** `4fd2ade` (before the commit)

**3. [Rule 1 - Bug] Avoided a SIGPIPE under `set -e -o pipefail` in run.sh**
- **Found during:** Task 2 drafting
- **Issue:** `git ls-files KayKit | head -n 1` over 2314 files can kill git with SIGPIPE and abort the script
- **Fix:** the tracked-file check counts lines with `wc -l` instead
- **Files modified:** `attimo/tests/run.sh`
- **Commit:** `f30b96e`

**Plan interpretation:** the removed `: "$REPO_ROOT"` no-op line in run.sh was only there to silence an unused variable; `REPO_ROOT` is now used. The header comment lists exit code 4.

**Total deviations:** 3 minor, no scope change.

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None. T-01-12 is mitigated by the exact whitelist, the no-kaykit/no-fbx/obj scan and the run.sh tracking checks, and the mutation probes prove they bite. T-01-13 accepted as planned: the log is hidden by default and bound to `debug_event_log`.

## Human verification needed

The end-of-phase play-through (cannot be judged headless). Open the project with the pinned editor (`"$HOME/Applications/Godot_4.7.2/Godot.app/Contents/MacOS/Godot" --path attimo -e`), press F5 and play for about one minute without saving scenes. Expect, all in place with the Mannequin never leaving its spawn point (D-09 Option A):

1. The Mannequin stands on the floor tiles and idles (Idle_A loops).
2. Holding W/A/S/D plays Running_A in place and the Mannequin turns to face the pressed direction (W = away from the camera); releasing returns to Idle_A.
3. Space plays Jump_Start, Jump_Idle, Jump_Land in place.
4. Q or Left Ctrl plays Dodge_Forward in place, also during a jump. A forward slide of about 0.25 m that snaps back is the known root-bone shift for Phase 3.
5. F3 (or the key left of 1) shows and hides the event log with timestamped jumped / landed / dash_started / movement_state_changed lines.
6. The floor, the wall ring with open corners, the 1 m step, the 2 m block and the 4 m pillar are visible as a static backdrop; the camera frames the Mannequin and the backdrop sensibly (A14 values are a first guess).
7. Nothing glows, no particles, the camera never moves.
8. A CollisionObject3D's layer grid in the inspector shows World / Player / Interactable / Enemy / Projectile/Beam / Hazard.

Afterwards `git status --porcelain` should be clean or the changes reviewed.

## Next Phase Readiness

Phase 1 content is complete: the full 13-file suite is green and the visible outcome exists. Phase 2 replaces the static camera (A14) with the follow camera, adds velocity/gravity in `PlayerController`, and the wall ring and blocks already carry World-layer box collision for it. Keep the asset whitelist in `test_asset_hygiene.gd` in sync whenever a new KayKit file is copied into `attimo/assets/`.

## Self-Check: PASSED

- Created files exist: `test_scene.tscn`, `test_scene_run.gd`, `test_asset_hygiene.gd` (and `.uid` sidecars).
- Commits `4fd2ade` and `f30b96e` are ancestors of HEAD.
