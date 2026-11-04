---
phase: "01"
slug: foundation-prototype-character
status: draft
nyquist_compliant: true
wave_0_complete: false
created: "2026-11-04"
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Custom headless smoke runner (one `SceneTree` script, counted asserts, `quit(failures)`); no addon |
| **Config file** | none — Wave 0 creates `attimo/tests/run_smoke.gd` + `attimo/tests/run.sh` |
| **Quick run command** | `"$GODOT" --headless --path attimo -s res://tests/run_smoke.gd` |
| **Full suite command** | `bash attimo/tests/run.sh` (import, smoke, log grep for `SCRIPT ERROR\|Parse Error\|Failed to load`, non-zero on any failure) |
| **Estimated runtime** | ~30 seconds |

`GODOT` must point at the Godot 4.7.2 binary (not installed system-wide; `~/Downloads/Godot.app` is 4.6.3).

---

## Sampling Rate

- **After every task commit:** quick run command
- **After every plan wave:** `bash attimo/tests/run.sh`
- **Before `/gsd-verify-work`:** full suite green + manual play-through
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-T1 (tracer) | 01-01 | 1 | FOUND-01, FOUND-02, FEEL-01 | T-01-01 (T-01-supply), T-01-02, T-01-03 | Engine zip SHA-512 verified before extract; run.sh exits 3 on any other `--version`; log grep catches script errors; Space -> Jump -> `jumped`, Player static (D-09) | smoke (`test_jump_fact`) | `bash attimo/tests/run.sh` | ❌ W0 (this task creates run.sh, run_smoke.gd, test_jump_fact.gd) | ⬜ pending |
| 01-01-T2 | 01-01 | 1 | FOUND-01 | T-01-01 | Version/build/hash pinned; Jolt, Forward+, interpolation, untyped-as-error; every script loads | smoke (`test_project_settings`) | `bash attimo/tests/run.sh` | ❌ W0 (created by 01-01-T1/T2) | ⬜ pending |
| 01-02-T1 | 01-02 | 2 | FOUND-05, FOUND-04 | T-01-04 (T-01-assets), T-01-05 | Byte-identical KayKit copies; builder reads/writes fixed `res://` paths only | smoke (`test_animation_library`) | `bash attimo/tests/run.sh` | ❌ (created by this task) | ⬜ pending |
| 01-02-T2 | 01-02 | 2 | FOUND-05 | T-01-05 | Mannequin wrapped, GLB unedited; clips play via local FSM signal | smoke (`test_mannequin_animation`) | `bash attimo/tests/run.sh` | ❌ (created by this task) | ⬜ pending |
| 01-03-T1 | 01-03 | 3 | FOUND-05, FEEL-01, FOUND-02 | T-01-06 | Input only via actions; Run/Fall/`landed` timer-driven, position and velocity unchanged (D-09) | smoke (`test_movement_facts`) | `bash attimo/tests/run.sh` | ❌ (created by this task) | ⬜ pending |
| 01-03-T2 | 01-03 | 3 | FOUND-05, FEEL-01 | T-01-06 | Dash in place, `dash_started` with in_air from state, no displacement (D-09) | smoke (`test_dash_fact`) | `bash attimo/tests/run.sh` | ❌ (created by this task) | ⬜ pending |
| 01-04-T1 | 01-04 | 2 | FOUND-02 | T-01-07 | 18 actions, KB+M bound, no gamepad events, no raw input polling | smoke (`test_input_map`) | `bash attimo/tests/run.sh` | ❌ (created by this task) | ⬜ pending |
| 01-04-T2 | 01-04 | 2 | FOUND-03 | T-01-08 | Layer names, PhysicsLayers and CONVENTIONS.md stay in sync | smoke (`test_conventions`) | `bash attimo/tests/run.sh` | ❌ (created by this task) | ⬜ pending |
| 01-05-T1 | 01-05 | 2 | FOUND-05, FOUND-04 | T-01-09 (T-01-assets) | Byte-identical copies; box collision matches mesh; static ray probe hits top face | smoke (`test_proto_pieces`) | `bash attimo/tests/run.sh` | ❌ (created by this task) | ⬜ pending |
| 01-05-T2 | 01-05 | 2 | FOUND-05, FOUND-04 | T-01-09 | Reference blocks on the 1 m grid, box collision only | smoke (`test_proto_pieces`) | `bash attimo/tests/run.sh` | ✅ (from 01-05-T1) | ⬜ pending |
| 01-06-T1 | 01-06 | 3 | FEEL-01 | T-01-10 | Event log not an autoload, hidden by default, auto-connects to all facts | smoke (`test_event_log`) | `bash attimo/tests/run.sh` | ❌ (created by this task) | ⬜ pending |
| 01-06-T2 | 01-06 | 3 | FEEL-01 | T-01-11 | Read-only guard: no feedback calls in gameplay, no particle nodes, bus holds signals only | smoke (`test_feedback_guard`) | `bash attimo/tests/run.sh` | ❌ (created by this task) | ⬜ pending |
| 01-07-T1 | 01-07 | 4 | FOUND-01, FOUND-05, FEEL-01 | T-01-13 | Main scene is Prototype-Bits-only, no particles/glow, Player static (D-09), facts in log | smoke (`test_scene_run`) + human-check | `bash attimo/tests/run.sh` | ❌ (created by this task) | ⬜ pending |
| 01-07-T2 | 01-07 | 4 | FOUND-04 | T-01-12 (T-01-assets) | Fixed 25-file whitelist, no KayKit dir in `attimo/`, KayKit originals tracked, no LFS | smoke + shell (`test_asset_hygiene`, run.sh repo check) | `bash attimo/tests/run.sh` | ❌ (created by this task) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `attimo/tests/run_smoke.gd` — runner that auto-discovers `tests/smoke/test_*.gd`; by phase end the 13 test files cover FOUND-01..05 and FEEL-01 (created in 01-01-T1)
- [ ] `attimo/tests/run.sh` — version gate, import, run, log grep, exit code (created in 01-01-T1; repo checks added in 01-07-T2)
- [ ] `GODOT` binary path documented in README (01-01-T2)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Mannequin visibly plays Idle/Run/Jump/Dodge in place (D-09 Option A: no movement physics), turns to face the pressed direction, F3 toggles the log, no glow/particles | FOUND-05, FEEL-01 | Visual | 01-07-T1 `<human-check>`: open `attimo/` in Godot 4.7.2, press F5, exercise inputs |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (all 14 tasks: `bash attimo/tests/run.sh`)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (01-01 creates the runner, run.sh and README)
- [x] No watch-mode flags
- [x] Feedback latency < 30s (estimated, RESEARCH A8; re-measure on the first 01-01 run, because a fresh worktree import may be slower)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
