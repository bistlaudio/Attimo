---
phase: "02"
slug: "movement-core-follow-camera"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-04"
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Source of truth for the test map: `02-RESEARCH.md` § Validation Architecture.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Project smoke harness (`RefCounted` tests with `run(tree, check)`), Godot 4.7.2 headless |
| **Config file** | none — `attimo/tests/run.sh` auto-discovers `tests/smoke/test_*.gd` |
| **Quick run command** | `bash attimo/tests/run.sh <filter>` |
| **Full suite command** | `bash attimo/tests/run.sh` |
| **Estimated runtime** | ~60-80 seconds (baseline ~19 s + ~40-60 s new) |

## Sampling Rate

- **After every task commit:** `bash attimo/tests/run.sh <touched test names>`
- **After every plan wave:** `bash attimo/tests/run.sh`
- **Before `/gsd-verify-work`:** Full suite green
- **Max feedback latency:** 90 seconds

## Per-Task Verification Map

| Req | Behavior | Test Type | Automated Command | File Exists | Status |
|-----|----------|-----------|-------------------|-------------|--------|
| MOVE-01/02 | accel/decel, camera-relative input, sprint | integration | `bash attimo/tests/run.sh test_ground_movement` | ❌ W0 | ⬜ pending |
| MOVE-03/04/05 | variable jump, coyote, buffer, one double jump | integration | `bash attimo/tests/run.sh test_jump` | ❌ W0 | ⬜ pending |
| MOVE-06/07 | ground/air dash, dash→jump, no tunnelling | integration | `bash attimo/tests/run.sh test_dash` | ❌ W0 | ⬜ pending |
| MOVE-08 | platforms, conveyors, slopes, stairs | integration | `bash attimo/tests/run.sh test_platforms` | ❌ W0 | ⬜ pending |
| MOVE-10 | MovementConfig + metrics doc | unit + tool | `bash attimo/tests/run.sh test_movement_config` | ❌ W0 | ⬜ pending |
| CAM-01 | rig top-level, jitter-free at 10 TPS, wall pull-in | integration | `bash attimo/tests/run.sh test_camera_rig` | ❌ W0 | ⬜ pending |
| CAM-03 | sensitivity / invert-Y / settings round-trip | unit | `bash attimo/tests/run.sh test_camera_rig` | ❌ W0 | ⬜ pending |
| FEEL-06 | input→fact latency ≤ 100 ms (target 66 ms) | integration | `bash attimo/tests/run.sh test_latency` | ❌ W0 | ⬜ pending |

## Wave 0 Requirements

- [ ] `attimo/tests/fixtures.gd` — floor helper, `send_action_event`, `send_mouse_motion`
- [ ] New test files: `test_movement_config`, `test_ground_movement`, `test_jump`, `test_dash`, `test_platforms`, `test_camera_rig`, `test_latency`
- [ ] Rewrite Phase 1 tests that assert "body never moves": `test_scene_run`, `test_movement_facts`, `test_jump_fact`, `test_dash_fact`, `test_mannequin_animation`
- [ ] Update `test_asset_hygiene` whitelist/count, `test_input_map`, `test_conventions`, `test_proto_pieces`

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Subjective feel sign-off (no juice) | MOVE-10 | Feel is not machine-checkable | Play the movement gym |
| 144 Hz visual judder | CAM-01 | Needs real display | Run gym at 144 Hz, watch camera |
| Real hardware latency | FEEL-06 | Headless cannot see display/USB | Measure on dev machine |
| Corridor camera feel | CAM-01 | Subjective | Walk tight corridor in gym |

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90 s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
