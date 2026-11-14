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

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-XX-XX | TBD | TBD | MOVE-09 | — | N/A | integration | `bash attimo/tests/run.sh test_mannequin_animation,test_procedural_pose` | partly (W0) | ⬜ pending |
| 03-XX-XX | TBD | TBD | MOVE-09 | — | N/A | smoke | `bash attimo/tests/run.sh test_animation_library` | update existing | ⬜ pending |
| 03-XX-XX | TBD | TBD | MOVE-11 | — | N/A | guard | `bash attimo/tests/run.sh test_animation_map` | ❌ W0 | ⬜ pending |
| 03-XX-XX | TBD | TBD | CAM-02 | — | N/A | integration | `bash attimo/tests/run.sh test_aim_mode,test_aim_pose` | ❌ W0 | ⬜ pending |
| 03-XX-XX | TBD | TBD | Criterion 4 | — | N/A | regression | `bash attimo/tests/run.sh test_latency` | ✅ | ⬜ pending |
| 03-XX-XX | TBD | TBD | Repo hygiene | — | N/A | guard | `bash attimo/tests/run.sh test_asset_hygiene,test_input_map,test_conventions,test_feedback_guard,test_movement_metrics` | update existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `attimo/tests/fixtures.gd` — helpers `animation_tree(player)`, `playback(player)`, `locomotion_blend(player)`; migrate `test_mannequin_animation`, `test_movement_facts`, `test_dash`, `test_scene_run`
- [ ] `attimo/tests/smoke/test_aim_mode.gd`, `test_aim_pose.gd`, `test_procedural_pose.gd`, `test_animation_map.gd` — new
- [ ] `test_animation_library.gd` — expected clip list, loop flags, lengths for new clips
- [ ] `test_asset_hygiene.gd` whitelist 31 to 33, `tests/run.sh` `ORIGINALS`, `test_input_map.gd` and `test_conventions.gd` action lists
- [ ] Same-tick animation response test (state change observable after one physics frame plus one process frame)
- [ ] Regenerate `docs/MOVEMENT-METRICS.md` after `MovementConfig` additions

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
