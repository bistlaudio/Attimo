# Phase 1: Foundation & Prototype Character - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-04
**Phase:** 1-Foundation & Prototype Character
**Areas discussed:** Asset-Import & Repo, Charakter-Aufbau & Animation, Event-Bus & Debug-Log, Konventionen & Doku

---

## Asset-Import & Repo

| Option | Description | Selected |
|--------|-------------|----------|
| Remove raw packs from tree, gitignore | Packs only local, repo stays small | |
| Keep raw packs in repo | Every clone has everything, ~205 MB | ✓ |
| Move raw packs to Git LFS | Needs LFS on every machine | |

**User's choice:** Keep raw packs in the repo as a shared reference library. Roadmap, requirements and CLAUDE.md were changed accordingly.
**Notes:** User wants everyone to have the packs as reference and to use them later when needed. Versioning: plain git, no LFS (default recommendation, explained in chat). Used assets are copied (not moved) into `attimo/assets/`.

| Option | Description | Selected |
|--------|-------------|----------|
| A: `attimo/` stays project root | KayKit next to it, not imported | ✓ |
| B: project in repo root | Needs `.gdignore` for KayKit | |

**User's choice:** A ("so wie jetzt ist gut").

---

## Charakter-Aufbau & Animation

| Option | Description | Selected |
|--------|-------------|----------|
| AnimationTree with state machine | Matches stack plan | ✓ |
| AnimationPlayer direct | Rebuild needed later | |

| Option | Description | Selected |
|--------|-------------|----------|
| Demo only, no real movement | Clips triggered by input | ✓ |
| Simple run/jump movement | Pulls Phase 2 work forward | |

| Option | Description | Selected |
|--------|-------------|----------|
| `CharacterBody3D > VisualRoot > Mannequin` | Pivot at feet | ✓ |
| Mannequin as root | No VisualRoot | |

---

## Event-Bus & Debug-Log

| Option | Description | Selected |
|--------|-------------|----------|
| Autoload with typed signals | Type-checked | ✓ |
| Generic `emit(name, payload)` | Runtime-only checks | |

| Option | Description | Selected |
|--------|-------------|----------|
| In-game overlay, key toggle | Visible in game | ✓ |
| `print()` only | Minimal | |

| Option | Description | Selected |
|--------|-------------|----------|
| Only events the demo triggers | More with later phases | ✓ |
| Broad catalogue up front | Dead signals until used | |

---

## Konventionen & Doku

| Option | Description | Selected |
|--------|-------------|----------|
| `docs/CONVENTIONS.md` | One file in repo | ✓ |
| `attimo/README.md` | Mixed with build notes | |

| Option | Description | Selected |
|--------|-------------|----------|
| Full layer list + reserve | World, Player, Interactable, Enemy, Projectile/Beam, Hazard | ✓ |
| Minimal: World, Player, Interactable | Later changes to masks | |

**Notes:** User first asked for a more detailed explanation of layers/masks in chat, then chose the full list.

| Option | Description | Selected |
|--------|-------------|----------|
| By type: `scenes/ scripts/ assets/ autoload/` | snake_case files, PascalCase nodes | ✓ |
| By feature | Scene and script together | |

---

## Claude's Discretion

- Debug log toggle key, overlay look, event payload fields
- Test scene layout
- AnimationTree state names and clip mapping
- Groups list in CONVENTIONS.md

## Deferred Ideas

- Git LFS before Phase 9
- Cleaning raw packs from git history (only if repo size becomes a problem)
