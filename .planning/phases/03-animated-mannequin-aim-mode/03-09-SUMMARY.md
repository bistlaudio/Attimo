---
phase: 03-animated-mannequin-aim-mode
plan: 09
subsystem: animation-docs
tags: [animation-map, docs-guard, wording, validation, gym-check]

requires:
  - phase: 03-animated-mannequin-aim-mode
    provides: 03-01 to 03-08 and 03-10 (BlendTree root, library, aim mode, pose, aim layer, arm solver, timing guard)
provides:
  - docs/ANIMATION-MAP.md, the verb -> FSM state -> animation node -> clip map with the DEV-01/02/03 rules and the left-out verbs
  - test_animation_map (50 checks, with a synthetic self-check that proves the guard can fail)
  - CONVENTIONS facing and pose rules, ui folders, map pointer
  - D-07 pirouette wording everywhere, ROADMAP criterion 4 DEV-02 exception, Phase 1 and Phase 11 notes per DEV-01
  - CLAUDE.md and STACK.md AnimationTree layout as built
  - 03-VALIDATION.md task statuses
affects: [phase-verification]

actuals:
  tokens: 6950   # chars/4 over the added diff lines (27806 chars): map, guard, docs, validation table
  tasks: 3
  commits: 3
plan_head_before: 99b3d86515ed12c0fc6d5e12b3fe2cd04e241512
plan_head_after: 3d2a2d464a7b76722893d338caff6c7af09ef5fe
commits: 3

tech-stack:
  added: []
  patterns:
    - "Doc drift guard: read-only FileAccess on a fixed project-relative path, names collected from the scene and the generated tree text, a pure _missing() helper tested on a synthetic doc"

key-files:
  created:
    - docs/ANIMATION-MAP.md
    - attimo/tests/smoke/test_animation_map.gd
    - attimo/tests/smoke/test_animation_map.gd.uid
  modified:
    - docs/CONVENTIONS.md
    - attimo/tests/smoke/test_conventions.gd
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md
    - attimo/scripts/debug/hit_puffs.gd
    - attimo/tests/smoke/test_hit_puffs.gd
    - attimo/tests/smoke/test_long_jump.gd
    - .planning/phases/03-animated-mannequin-aim-mode/03-VALIDATION.md
    - .claude/CLAUDE.md
    - .planning/research/STACK.md

key-decisions:
  - "The documentation and wording work is complete and green; the developer's gym judgement (below) is the only open item, so the plan stays awaiting the human check"

requirements-completed: []

duration: about 30 min
completed: 2026-11-16
status: awaiting-human-check
---

# Phase 3 Plan 9: Animation map, wording sweep, stack docs and gym hand-off Summary

**Every movement verb is mapped to its FSM state and kit clip in docs/ANIMATION-MAP.md and guarded by a test that can fail; Jump 3 is called the pirouette everywhere; the DEV-01/02/03 decisions are written into CONVENTIONS and ROADMAP; the stack docs describe the BlendTree root; the full suite and the Phase 2 numbers are green. Only the developer's gym check is pending.**

MOVE-11, MOVE-09 and CAM-02 are listed in the plan frontmatter but are deliberately not marked complete in REQUIREMENTS.md, and `nyquist_compliant` stays false: the orchestrator or verifier sets both after the gym check.

## Accomplishments

- **Task 1 (tracer):** `docs/ANIMATION-MAP.md` with a verb table (idle, run, Jump 1 and 2, Jump 3, fall, landing, ground dash, air dash, long jump stages 1-2 and 3, aim stance, strafe left and right, backwards, aim dashes), a "Left out" section (wall-run MOVE-12, ledge grab MOVE-13, slide D-03, no sprint) and an "Adding a verb" rule. DEV-02 hold rule on the air-dash row, DEV-03 aim rule on the Jump 3 and long jump stage 3 rows. `test_animation_map` reads the six state nodes of `player.tscn`, the 13 distinct clip names of `mannequin_tree.tres` and the library, with a pure `_missing()` helper proven on a synthetic doc (50 PASS checks). CONVENTIONS: VisualRoot yaw is the facing, lean and pirouette on the Mannequin child (DEV-01), the pirouette aim rule (DEV-03), Phase 11 squash/stretch on the same node, `scripts/ui/` and `scenes/ui/`, pointer to the map; `test_conventions` gets the two folders and the terms `ANIMATION-MAP.md` and `ProceduralPose`.
- **Task 2:** `git grep -n -i salto` over attimo, docs, REQUIREMENTS.md and ROADMAP.md is empty. MOVE-05, MOVE-09 (with the DEV-03 aim note), FEEL-02, ROADMAP Phase 2 criterion 2, Phase 3 criterion 1 (DEV-03 note) and Phase 11 criterion 2 say pirouette. Phase 3 criterion 4 names the presentation-only air-dash pose hold (DEV-02) as the one exception to the same-frame rule. Phase 1 and Phase 11 notes put lean, pirouette and squash/stretch on the Mannequin child (DEV-01). `hit_puffs.gd`, `test_hit_puffs.gd` and `test_long_jump.gd` reworded; the scenario is now `_scenario_jump3_then_one_air_dash`; no assertion changed.
- **Task 3:** CLAUDE.md and STACK.md describe the BlendTree root (StateMachine -> TimeScale -> Land -> Aim -> output, matching `build_mannequin_tree.gd`), the BlendSpace2D locomotion, the Land OneShot overlay, the Aim Blend2 layer with `AimPoseModifier`, and the five animator parameter paths; the GSD markers are untouched. 03-VALIDATION.md: all 25 rows green, Wave 0 ticked, `wave_0_complete: true`.

## Task Commits

1. **Task 1 (tracer): animation map, drift guard, CONVENTIONS rules** - `3144bbb` (feat). Tracer gate: automated-only `<verify>` re-run end to end and passed before Task 2.
2. **Task 2: wording sweep, ROADMAP criterion 4 and notes** - `52a24a0` (docs)
3. **Task 3: stack docs and validation statuses** - `3d2a2d4` (docs)

## Verification

- Task 1: `test_animation_map,test_conventions`: 122 checks, `failed=0`; `test_animation_map` alone 50 PASS lines.
- Task 2: `test_long_jump,test_hit_puffs,test_movement_metrics`: 171 checks, `failed=0`. All Task 2 acceptance greps hold (salto 0, `Jump 3 pirouette` with DEV-03 in ROADMAP and MOVE-09, criterion 4 DEV-02 1, notes with `Mannequin child` 2, `runs on the VisualRoot` 0, new scenario name 2).
- Task 3: `test_latency,test_animation_timing,test_movement_metrics,test_animation_map`: 192 checks, `failed=0`; no `BlendSpace1D on horizontal speed` left, `AnimationNodeBlendSpace2D` and `parameters/StateMachine/playback` in both stack docs, markers 1 and 1, pending rows 0.
- Phase gate: `measure_movement` prints `MEASURE: PASSED` (latency rows all "Target met"; the regenerated `docs/MOVEMENT-METRICS.md` differs only by measurement noise and was reverted, not committed). Full suite `bash attimo/tests/run.sh`: 33 tests, 1464 checks, `failed=0`, `RUN.SH: PASSED`.

## Deviations from Plan

### Gym-check text adjusted by the orchestrator (not a code deviation)

The plan's gym text was stale in places; the list below follows the orchestrator's instructions: shoulder swap dropped (D-13 amended, Q unbound), item 5 uses the measured numbers from 03-08, and the open look items of 03-06, 03-07 and 03-08 are folded in.

### Scope additions per the orchestrator

- The wording sweep also covers `hit_puffs.gd`, `test_hit_puffs.gd` and `test_long_jump.gd` (03-06 report); these are in the plan's file list already.

No auto-fixes (Rules 1-3) were needed. The plan was not set to complete: it stays awaiting the developer's gym check.

## Known Stubs

None.

## Threat Flags

None. T-03-13 is mitigated as planned: fixed-path read-only reads, no write, and the synthetic self-check proves the guard fails on a missing entry.

## Issues Encountered

None. The unrelated working-tree changes (`attimo/project.godot`, two `*.png.import` files, `.planning/state.json`) were left unstaged.

## Gym check (pending, developer)

Open the pinned editor (`"${GODOT:-$HOME/Applications/Godot_4.7.2/Godot.app/Contents/MacOS/Godot}" --path attimo -e`), press F5 (movement gym), play 15-20 minutes, F2 open for tuning, F4 for metrics. Do not save scenes in the editor. Record each item as pass, fail or tuned (with the new value). None of this was attempted or simulated by the executor.

| # | Item | Status |
|---|------|--------|
| 1 | Animation follows every state on the same frame: idle, run, Jump 1 and 2 (no visible wind-up), fall (the fall loop starts at the apex, not when the take-off clip ends; on the slightly longer Jump 2 and Jump 3 rises the take-off pose holds to the apex without a visible freeze, A-01-2), landing (short bounce, never holds you), ground dash, held air-dash pose, long jump (ROADMAP criteria 1 and 4). | pending |
| 2 | Ground dash lean flows into the long-jump stretch without a pop (D-01, D-04); lean snapping: the dash lean reaches 20 degrees in a single tick (1200 deg/s ease), check that it reads as a snap or acceptable. The air dash stays upright (D-02) and holds its Dodge pose past the end of the dash through the fall until landing, or until `air_dash_hold_time` (0.35 s) hands over to the fall loop on a long drop (DEV-02, A-10-1: the held last frame of the non-looping clip). The hold never delays control: steering in the air, landing and the next jump or dash respond at once. If the hand-over reads wrong, tune `air_dash_hold_time` in F2 and record the value. | pending |
| 3 | Jump 3 and long jump stage 3: one clean pirouette that ends before touchdown, no flip (D-05, D-07). Judge the pirouette direction (`pirouette_clockwise`) and the corkscrew versus tilted-top composition for stage 3 (`spin_about_body_axis`). With aim held at takeoff Jump 3 and stage 3 do not spin; pressing aim or air-dashing mid-spin finishes the turn cleanly in about 0.1 s, no snap (DEV-03; tune `pirouette_finish_time` in F2 if abrupt). While aiming, the dash and stretch lean read at `aim_lean_scale` 0.5 (03-01 item 3). | pending |
| 4 | Hold right mouse: crosshair (dot plus ring) appears, FOV tightens and the camera moves over the fixed right shoulder in about 0.18 s; release restores everything (D-13 as amended, D-14, D-15). Q stays unbound, there is no shoulder swap. | pending |
| 5 | Aim stance reads well over idle, run, strafe left, strafe right, backwards; the right arm points at the crosshair at high and low pitch (D-11). Measured (03-08, `max_twist_deg` 70): idle 47 degrees of torso twist, run 54, strafe left 10, backwards 52; strafe right sits at the 70 degree clamp plus about 44 degrees of upper-arm rotation on top; at low pitch (pitch_min) the twist is about 65 degrees, at pitch_max about 64. The arm error is 0.000 degrees in every case, so the judgement is only whether the torso and the arm read well (A-08-1). Also check the left arm and the head: they are not corrected and turn with the torso twist. If strafe right looks broken, note which fallback to try: raise `spine_share` (0.4), lower `max_twist_deg` (the arm then carries more), arms-only filter, or reduce the strafe blend in aim. | pending |
| 6 | Aim dashes play Dodge_Left, Dodge_Right and Dodge_Backward and keep facing the crosshair (D-12, A-07-1); otherwise note the fallback `return &"Dash"` in `dash_node_for` (Dodge_Forward for every direction). | pending |
| 7 | Foot sliding on the run (Running_A at about 1.9x) and the backwards walk is acceptable. The whole state machine plays at the run scale in Locomotion, so aim strafe and back run at about 1.42x at aim speed (6.4 m/s): judge whether strafe and back need their own reference speeds. Diagonal back-left and back-right legs look coherent (A-07-3: the 1.067 s back cycle mixes with the 0.8 s strafe cycle under CYCLIC_MUTABLE sync; research Open Question 5). | pending |
| 8 | Movement feel and the F4 latency numbers are unchanged from Phase 2 (criterion 4). Headless numbers from this run: jump 60 TPS median about 13 ms, dash 60 TPS median about 17-19 ms, all verdicts "Target met". | pending |

## Next

Developer runs the gym check and records the results per item. After that the orchestrator marks MOVE-09, CAM-02 and MOVE-11 complete and runs the phase verification (it sets `nyquist_compliant`).

## Self-Check: PASSED

- Files exist: docs/ANIMATION-MAP.md, attimo/tests/smoke/test_animation_map.gd (+ .uid), updated CONVENTIONS, stack docs and VALIDATION.
- Commits `3144bbb`, `52a24a0` and `3d2a2d4` are on `dev`.
