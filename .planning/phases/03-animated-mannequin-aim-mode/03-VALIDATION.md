---
phase: "03"
slug: animated-mannequin-aim-mode
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-14"
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Source: 03-RESEARCH.md "Validation Architecture".

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Project smoke runner (`attimo/tests/run_smoke.gd`, auto-discovers `tests/smoke/test_*.gd`), Godot 4.7.2 headless |
| **Config file** | none; `attimo/tests/run.sh` wraps version gate, repo checks, import, run, error-grep |
| **Quick run command** | `bash attimo/tests/run.sh test_aim_mode,test_mannequin_animation,test_animation_map` |
| **Full suite command** | `bash attimo/tests/run.sh` |
| **Estimated runtime** | ~160 seconds (full), under ~30 seconds (quick) |

---

## Sampling Rate

- **After every task commit:** Run the test names the task touched via `bash attimo/tests/run.sh <names>`
- **After every plan wave:** Run `bash attimo/tests/run.sh`
- **Before `/gsd-verify-work`:** Full suite must be green, plus the human gym check
- **Max feedback latency:** 30 seconds (per task)

---

## Per-Task Verification Map

Filled at planning time (plan revision 1, 2026-11-14) from the PLAN files: one row per task, the command is the task's `<automated>` verify verbatim. 03-09 Task 3 sets the Status column from the SUMMARYs; `nyquist_compliant` is set by the verifier, not by a plan.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 03-01 | 1 | MOVE-09, criterion 4 | T-03-01 | Tree tool validates every clip name against the library before saving | integration (tracer) | `bash attimo/tests/run.sh --tool res://tools/build_mannequin_tree.gd && bash attimo/tests/run.sh test_mannequin_animation` | update existing | ⬜ pending |
| 03-01-02 | 03-01 | 1 | MOVE-09 | — | N/A | regression (path migration) | `bash attimo/tests/run.sh test_mannequin_animation,test_movement_facts,test_dash,test_scene_run,test_latency` | update existing | ⬜ pending |
| 03-01-03 | 03-01 | 1 | MOVE-09, CAM-02 | — | N/A | manual (decision checkpoint; answers and DEV-01/DEV-02 in 03-01-SUMMARY.md) | n/a: `grep -c 'Confirmed decisions (03-01 checkpoint)' .planning/phases/03-animated-mannequin-aim-mode/03-01-SUMMARY.md` returns 1 | n/a | ⬜ pending |
| 03-02-01 | 03-02 | 2 | MOVE-09 | T-03-03 | Byte-identical copy, exact-count whitelist (33) | smoke (tracer) | `bash attimo/tests/run.sh --tool res://tools/build_animation_library.gd && bash attimo/tests/run.sh test_animation_library,test_asset_hygiene` | update existing | ⬜ pending |
| 03-02-02 | 03-02 | 2 | MOVE-09 | T-03-04 | Only the four Dodge root position tracks are rewritten; strafe root yaw survives | smoke | `bash attimo/tests/run.sh --tool res://tools/build_animation_library.gd && bash attimo/tests/run.sh test_animation_library,test_asset_hygiene,test_conventions,test_mannequin_animation` | update existing | ⬜ pending |
| 03-10-01 | 03-10 | 3 | MOVE-09, criterion 4 | T-03-14 | Air-dash pose hold is presentation only; landing travels on the landing frame | integration (tracer) | `bash attimo/tests/run.sh test_animation_timing,test_mannequin_animation,test_dash,test_latency` | ❌ W0 (created here) | ⬜ pending |
| 03-10-02 | 03-10 | 3 | MOVE-09, criterion 4 | T-03-02 | Land overlay inactive within 10 ticks after a move input (no landing lock) | guard | `bash attimo/tests/run.sh test_animation_timing,test_mannequin_animation,test_movement_facts,test_dash,test_long_jump,test_latency` | ✅ (03-10-01) | ⬜ pending |
| 03-03-01 | 03-03 | 4 | CAM-02 | T-03-06 | face()/face_now() return early while aiming; release hands facing back | integration (tracer) | `bash attimo/tests/run.sh test_aim_mode,test_input_map,test_conventions,test_feedback_guard,test_event_log` | ❌ W0 (created here) | ⬜ pending |
| 03-03-02 | 03-03 | 4 | CAM-02 | T-03-05 | Aim factors have a 0.1 minimum, no zero divisor | integration | `bash attimo/tests/run.sh --tool res://tools/measure_movement.gd && bash attimo/tests/run.sh test_aim_mode,test_ground_movement,test_movement_metrics,test_tuning_panel,test_dash,test_long_jump` | ✅ (03-03-01) | ⬜ pending |
| 03-04-01 | 03-04 | 5 | CAM-02 | T-03-08 | aim_blend_time minimum 0.01, no zero divisor | integration (tracer) | `bash attimo/tests/run.sh test_aim_camera,test_camera_rig,test_camera_controls` | ❌ W0 (created here) | ⬜ pending |
| 03-04-02 | 03-04 | 5 | CAM-02 | — | N/A | integration | `bash attimo/tests/run.sh test_aim_camera,test_input_map,test_conventions,test_feedback_guard,test_event_log,test_camera_controls` | update existing | ⬜ pending |
| 03-04-03 | 03-04 | 5 | CAM-02 | T-03-07 | No "aim_" key is written to the settings file | integration | `bash attimo/tests/run.sh test_tuning_panel,test_aim_camera,test_movement_gym` | update existing | ⬜ pending |
| 03-05-01 | 03-05 | 5 | CAM-02 | T-03-09 | Crosshair ignores the mouse and draws below the debug overlays | smoke (tracer) | `bash attimo/tests/run.sh test_crosshair,test_asset_hygiene` | ❌ W0 (created here) | ⬜ pending |
| 03-05-02 | 03-05 | 5 | CAM-02 | — | N/A | smoke | `bash attimo/tests/run.sh --tool res://tools/build_movement_gym.gd && bash attimo/tests/run.sh test_movement_gym,test_scene_run,test_crosshair` | update existing | ⬜ pending |
| 03-06-01 | 03-06 | 5 | MOVE-09 | T-03-10 | Divisor minimums, non-finite angles reset the pose | integration (tracer) | `bash attimo/tests/run.sh --tool res://tools/measure_movement.gd && bash attimo/tests/run.sh test_procedural_pose,test_feedback_guard,test_movement_metrics,test_dash` | ❌ W0 (created here) | ⬜ pending |
| 03-06-02 | 03-06 | 5 | MOVE-09 | T-03-10 | Spin rate divisor clamped, every written basis finite | integration | `bash attimo/tests/run.sh test_procedural_pose,test_long_jump,test_jump,test_feedback_guard` | ✅ (03-06-01) | ⬜ pending |
| 03-06-03 | 03-06 | 5 | MOVE-09 | — | N/A | guard | `bash attimo/tests/run.sh --tool res://tools/measure_movement.gd && bash attimo/tests/run.sh test_movement_metrics,test_tuning_panel` | update existing | ⬜ pending |
| 03-07-01 | 03-07 | 6 | MOVE-09, CAM-02 | T-03-11 | Clip playback divisors have positive minimums | integration (tracer) | `bash attimo/tests/run.sh --tool res://tools/build_mannequin_tree.gd && bash attimo/tests/run.sh --tool res://tools/measure_movement.gd && bash attimo/tests/run.sh test_aim_layer,test_mannequin_animation,test_animation_timing,test_movement_metrics` | ❌ W0 (created here) | ⬜ pending |
| 03-07-02 | 03-07 | 6 | MOVE-09, CAM-02 | T-03-11 | Blend divisor clamped, non-finite scales fall back to 1.0 | integration | `bash attimo/tests/run.sh --tool res://tools/build_mannequin_tree.gd && bash attimo/tests/run.sh test_aim_layer,test_mannequin_animation,test_movement_facts,test_dash,test_animation_timing` | ✅ (03-07-01) | ⬜ pending |
| 03-07-03 | 03-07 | 6 | MOVE-09, CAM-02 | — | N/A | integration | `bash attimo/tests/run.sh --tool res://tools/build_mannequin_tree.gd && bash attimo/tests/run.sh test_aim_layer,test_dash,test_animation_timing,test_latency` | ✅ (03-07-01) | ⬜ pending |
| 03-08-01 | 03-08 | 7 | CAM-02 | T-03-12 | Non-finite quaternions are never written to a bone | integration (tracer) | `bash attimo/tests/run.sh test_aim_pose,test_aim_layer,test_mannequin_animation` | ❌ W0 (created here) | ⬜ pending |
| 03-08-02 | 03-08 | 7 | CAM-02 | T-03-12 | Opposite vectors give a finite rotation | integration | `bash attimo/tests/run.sh test_aim_pose,test_aim_layer,test_aim_mode` | ✅ (03-08-01) | ⬜ pending |
| 03-09-01 | 03-09 | 8 | MOVE-11 | T-03-13 | Read-only fixed-path doc reads; synthetic self-check proves the guard can fail | guard (tracer) | `bash attimo/tests/run.sh test_animation_map,test_conventions` | ❌ W0 (created here) | ⬜ pending |
| 03-09-02 | 03-09 | 8 | MOVE-09 (D-07 wording) | — | N/A | regression | `bash attimo/tests/run.sh test_long_jump,test_hit_puffs,test_movement_metrics` | update existing | ⬜ pending |
| 03-09-03 | 03-09 | 8 | MOVE-09, MOVE-11, CAM-02, criterion 4 | — | N/A | regression (filtered phase run; full suite is the plan-level gate) | `bash attimo/tests/run.sh test_latency,test_animation_timing,test_movement_metrics,test_animation_map` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `attimo/tests/fixtures.gd` — helpers `animation_tree(player)`, `playback(player)`, `locomotion_blend(player)`, `land_active(player)`; migrate `test_mannequin_animation`, `test_movement_facts`, `test_dash`, `test_scene_run` (03-01)
- [ ] `attimo/tests/smoke/test_aim_mode.gd` (03-03), `test_aim_camera.gd` (03-04), `test_crosshair.gd` (03-05), `test_procedural_pose.gd` (03-06), `test_aim_layer.gd` (03-07), `test_aim_pose.gd` (03-08), `test_animation_map.gd` (03-09) — new
- [ ] `test_animation_library.gd` — expected clip list, loop flags, lengths for new clips (03-02)
- [ ] `test_asset_hygiene.gd` whitelist 31 to 33, `tests/run.sh` `ORIGINALS` (03-02), `test_input_map.gd` and `test_conventions.gd` action lists (03-04)
- [ ] Same-tick animation response, landing-lock, anticipation and air-dash hold test `test_animation_timing.gd` (03-10)
- [ ] Regenerate `docs/MOVEMENT-METRICS.md` after `MovementConfig` additions (03-03, 03-06, 03-07)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Aim stance over idle, run, strafe L/R, back; strafe-right twist; pirouette and stretch composition; Dodge aim clips; run foot sliding | MOVE-09, CAM-02 | Needs rendering, headless cannot judge looks | Movement gym session at end of phase |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
