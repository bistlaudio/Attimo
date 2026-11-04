---
phase: "01"
slug: foundation-prototype-character
status: draft
nyquist_compliant: false
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
| 01-xx-xx | TBD | TBD | FOUND-01 | T-01-supply | Engine pinned, version checked | smoke | `bash attimo/tests/run.sh` | ❌ W0 | ⬜ pending |
| 01-xx-xx | TBD | TBD | FOUND-02 | — | Actions exist, no joypad events, no raw key polling | smoke | `bash attimo/tests/run.sh` | ❌ W0 | ⬜ pending |
| 01-xx-xx | TBD | TBD | FOUND-03 | — | Layer names + CONVENTIONS.md match | smoke | `bash attimo/tests/run.sh` | ❌ W0 | ⬜ pending |
| 01-xx-xx | TBD | TBD | FOUND-04 | T-01-assets | `attimo/` has no KayKit dir, assets whitelisted | smoke + shell | `bash attimo/tests/run.sh` | ❌ W0 | ⬜ pending |
| 01-xx-xx | TBD | TBD | FOUND-05 | — | Scene runs, simulated inputs reach Locomotion/Jump/Dash | smoke | `bash attimo/tests/run.sh` | ❌ W0 | ⬜ pending |
| 01-xx-xx | TBD | TBD | FEEL-01 | — | jumped/landed/dash_started on EventBus + log; no feedback calls in gameplay | smoke | `bash attimo/tests/run.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `attimo/tests/run_smoke.gd` — covers FOUND-01..05, FEEL-01
- [ ] `attimo/tests/run.sh` — import, run, log grep, exit code
- [ ] `GODOT` binary path documented (README)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Mannequin visibly plays Idle/Run/Jump/Dodge, faces move direction, F3 toggles log, no glow/particles | FOUND-05, FEEL-01 | Visual | Open `attimo/` in Godot 4.7.2, press F5, exercise inputs |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
