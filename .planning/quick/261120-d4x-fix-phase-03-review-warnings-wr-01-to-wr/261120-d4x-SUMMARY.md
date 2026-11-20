---
quick_id: 261120-d4x
description: Fix phase 03 review warnings WR-01 to WR-06
status: complete
commits: 7
plan_head_before: ddf3856
plan_head_after: 67ae159dadbcd08bf03eab9191eb93c4ffd857f7
actuals:
  tasks: 6
  commits: 7
---
# Quick task 261120-d4x: Phase 3 review warnings WR-01 to WR-06

All six warnings from 03-REVIEW.md are fixed. `bash attimo/tests/run.sh` ends `RUN.SH: PASSED` (38 tests, 1839 checks, 0 failed).

## Fixes

| Finding | Commit | Change |
|---------|--------|--------|
| WR-01 | d74ce19 | `CameraRig` sets `process_priority = -100` (const `PROCESS_PRIORITY`) in `_ready`, so the animator and AnimationTree read this frame's camera. New check `(t6)` in test_aim_target: a reader ahead of the rig in tree order sees the same camera position and aim point as a priority-200 reader while the view turns. Verified it fails (0.93 m / 77 m off) with priority 0. |
| WR-02 | a7b9a14 | build_animation_library guards the missing AnimationPlayer, conformed source, mannequin scene and skeleton (push_error, quit(1)). build_mannequin_tree: a missing FALLBACK row or clip routes into the existing `TREE: FAILED (missing clip ...)` path instead of a hard lookup. `run.sh --tool` runs under `timeout`/`gtimeout` (300 s) when one exists. conform_external_clip already returned failures as strings, nothing to change. |
| WR-03 | e75b43a | `MannequinAnimator._travel_to` and the `_playback.start` call skip a null playback, `_ready` warns once. New (wr03) checks in test_mannequin_animation with the playback removed. |
| WR-04 | dbe723f, 977881e | Slider ticks apply to the rig; the file is written on `drag_ended` (or at once for a change outside a drag); `save_to` result is checked and a failure pushes a warning. New (8) checks in test_tuning_panel. |
| WR-05 | 67ae159 | Filter is now the regex `(Object|Resource|SubResource|ExtResource)\s*\(`; new cases for space, tab and double-space in test_camera_controls. |
| WR-06 | 1c359cf | test_aim_layer `_begin` duplicates the player config, so the (d3) mutation never touches the shared resource. |

## Deviations / notes

- WR-06 test_tuning_panel: already safe. `_spawn` duplicates the config before the panel binds, and scenario (3) asserts the shared resource is unchanged. No change made.
- Stale comments fixed only in touched files: slide playback scale and drop-only note in build_mannequin_tree.gd, aim fallback description in build_animation_library.gd. Not fixed: movement_config.gd ("49 sliders", "fall gravity about 55"), because that file was not touched by this task.
- The two tool scripts were run headless to confirm they still work; the regenerated rig_medium_library.res was reverted (not part of the fix), mannequin_tree.tres came out unchanged.
- run.sh was first edited with an empty-array expansion that failed under macOS bash 3.2 with `set -u`; fixed before commit.
- Not staged, per instructions: attimo/project.godot, the two .png.import files, .planning/state.json. docs/MOVEMENT-METRICS.md was not rewritten.
- The full-run log ends with the usual Godot "resources still in use at exit" notice; run.sh still passes.
