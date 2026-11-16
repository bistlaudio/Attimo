---
phase: 03-animated-mannequin-aim-mode
plan: 05
subsystem: ui
tags: [godot, crosshair, hud, canvaslayer, movement-gym, gdscript]

requires:
  - phase: 03-animated-mannequin-aim-mode
    provides: 03-03 EventBus.aim_changed(active) and PlayerController.aiming
provides:
  - Crosshair CanvasLayer (layer 10), code-drawn dot plus thin ring, shown only while aim is held
  - Reserved Phase 4 lock state (locked, set_locked) that switches dot and ring to turquoise
  - Hidden Crosshair instance in the generated movement gym and in test_scene.tscn
  - test_crosshair (10 checks) and Crosshair entries in test_movement_gym
affects: [03-09, 04-hand-interaction]

actuals:
  tokens: 1150   # chars/4 over the added hand-written diff lines (4569 chars), gym regeneration churn excluded
  tasks: 2
  commits: 2
plan_head_before: af47391b23a4fa4e6e759e8d900a7223c684adf2
plan_head_after: f32a26252bf1c4eb43d9a1e0c7fa9e6b8739353d
commits: 2

tech-stack:
  added: []
  patterns:
    - "HUD overlay = CanvasLayer under layer 100 with a full-rect Control child (mouse_filter IGNORE) that draws through its own draw signal"
    - "Crosshair listens to EventBus.aim_changed only; gameplay never calls it"

key-files:
  created:
    - attimo/scripts/ui/crosshair.gd
    - attimo/scripts/ui/crosshair.gd.uid
    - attimo/scenes/ui/crosshair.tscn
    - attimo/tests/smoke/test_crosshair.gd
    - attimo/tests/smoke/test_crosshair.gd.uid
  modified:
    - attimo/tools/movement_gym_builder.gd
    - attimo/scenes/test/movement_gym.tscn
    - attimo/scenes/test/test_scene.tscn
    - attimo/tests/smoke/test_movement_gym.gd

key-decisions:
  - "The crosshair is a CanvasLayer root with a Reticle Control child; the Control's draw signal is wired to _draw_reticle, so no Control subclass is needed"
  - "Lock state recolours both dot and ring (one tint) so Phase 4 only has to call set_locked(true)"

requirements-completed: []

duration: about 7 min
completed: 2026-11-16
status: complete
---

# Phase 3 Plan 5: Crosshair Summary

**A code-drawn cream dot with a thin 14 px ring appears at the screen centre exactly while aim is held, ignores the mouse, sits on layer 10 below the debug overlays, carries a reserved turquoise lock state for Phase 4, and is instanced hidden in both the generated gym and the test scene.**

CAM-02 is listed in the plan frontmatter but is deliberately not marked complete: it spans the whole phase and the orchestrator marks it at phase end.

## Accomplishments

- `Crosshair` (`scripts/ui/crosshair.gd`, `scenes/ui/crosshair.tscn`): `class_name Crosshair extends CanvasLayer`, layer 10, typed exports `dot_radius` 2.0, `ring_radius` 14.0, `ring_width` 1.5, `color` cream (0.96, 0.93, 0.85, 0.9) and `lock_color` turquoise (0.25, 0.9, 0.85). Hidden in `_ready`, shown by `EventBus.aim_changed`, drawn with `draw_circle` and an antialiased 48-point `draw_arc` at the Reticle's centre.
- Reserved lock state: `locked` plus `set_locked(value)` that redraws. Nothing in this phase calls it.
- T-03-09 mitigated: `Reticle` is a full-rect Control (anchors_preset 15) with `mouse_filter = IGNORE`, the layer is below the overlays (100-102); `test_crosshair` asserts both.
- No asset: the scene has no texture, `test_asset_hygiene` still reports the 33-entry whitelist.
- `movement_gym_builder.gd` has a `CROSSHAIR` constant and instances it as "Crosshair" after HitPuffs; the gym was regenerated with the tool (`GYM: WRITTEN`). `test_scene.tscn` instances it next to the overlays. `test_movement_gym` has "Crosshair" in `CONTRACT_NODES` and in `_check_overlays` (present, a Crosshair, hidden).

## Task Commits

1. **Task 1 (tracer): aim_changed -> Crosshair dot and ring** - `3fc183a` (feat)
2. **Task 2: Crosshair in the generated gym and the test scene** - `f32a262` (feat)

Tracer gate: `test_crosshair,test_asset_hygiene` re-run end to end before expansion (22 checks passed), then expansion continued.

## Verification

- `bash attimo/tests/run.sh test_crosshair,test_movement_gym,test_scene_run,test_asset_hygiene`: 186 checks, `failed=0`, `RUN.SH: PASSED`.
- Full suite: 29 tests, 1215 checks, `failed=0`, `RUN.SH: PASSED`.
- Acceptance criteria: `class_name Crosshair` 1, `aim_changed.connect` 1, `Texture` in the scene 0, `crosshair.tscn` present once in the builder, the gym and the test scene, `"Crosshair"` 2 in `test_movement_gym.gd`, `test_crosshair` prints 10 PASS lines.

## Deviations from Plan

None - plan executed exactly as written.

One note, not a deviation: regenerating the gym rewrites the whole `movement_gym.tscn` (about 616 added and 610 removed lines) because the generator assigns fresh random resource ids on every run. The content is otherwise identical apart from the Crosshair instance. The same churn will happen on any future regeneration.

## Known Stubs

None. `set_locked()` is an intentionally reserved Phase 4 hook (D-15), covered by the test; it is not a stub that blocks this plan's goal.

## Threat Flags

None.

## Issues Encountered

None. The unrelated working-tree changes (project.godot, two .png.import files, .planning/state.json) were left untouched and unstaged.

## Next

Ready for 03-06.

## Self-Check: PASSED

- Files exist: crosshair.gd, crosshair.tscn, test_crosshair.gd, movement_gym.tscn changed.
- Commits `3fc183a` and `f32a262` are on `dev`.
