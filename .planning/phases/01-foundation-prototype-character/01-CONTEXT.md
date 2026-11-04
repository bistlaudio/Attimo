# Phase 1: Foundation & Prototype Character - Context

**Gathered:** 2026-11-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Prove the project base and the prototype pipeline. A pinned Godot 4.7.x project (`attimo/`) runs a test scene built from KayKit Prototype Bits pieces. Input Map actions make the KayKit Mannequin_Medium (Rig_Medium) play the KayKit Idle, Run, Jump and Dodge clips. Gameplay facts are broadcast on an event bus and shown in a debug event log. Collision layers, groups and folder conventions are fixed and documented.

Out of scope: real movement tuning (Phase 2), camera (Phase 2), gamepad bindings (Phase 13), particles/juice (Phases 11-12), Meshy work, the cue catalogue (Phase 11).

</domain>

<decisions>
## Implementation Decisions

### Repo, assets and structure
- **D-01:** The Godot project root stays `attimo/` (contains `project.godot`). The repo root keeps `.planning/`, `docs/` and `KayKit/`. Godot only imports what lies under `attimo/`, so `KayKit/` is never imported. — **Reversibility:** costly — moving `project.godot` later changes every `res://` path and the repo layout.
- **D-02:** The raw packs (`KayKit/`: Character Animations, Skeletons, Dungeon Pack, Prototype Bits, Brackeys VFX, Kenney particles, ~205 MB) stay tracked in git as a shared reference library. They were committed on `dev` in `a8ece0e`. The earlier plan to gitignore them is dropped. ROADMAP.md (Phase 1 criterion 2), REQUIREMENTS.md (FOUND-04) and CLAUDE.md (Git Workflow) were updated to match.
- **D-03:** No Git LFS for now. Plain git. Revisit before Phase 9 (Meshy hero, steampunk kit, audio) if binaries grow large.
- **D-04:** Used assets are COPIED (not moved) from `KayKit/` into `attimo/assets/`. `KayKit/` stays complete as reference. Only the used Prototype Bits pieces, the Mannequin_Medium and the Rig_Medium animation library go into `assets/`.
- **D-05:** Folder layout by type inside `attimo/`: `scenes/`, `scripts/`, `assets/`, `autoload/`. Files are `snake_case`, nodes and classes are `PascalCase`.

### Character and animation
- **D-06:** Player scene `player.tscn`: `CharacterBody3D` > `VisualRoot` > Mannequin scene. `VisualRoot` has its pivot at the feet. Later phases reuse it for flip/lean (Phase 3), the final hero (Phase 9) and squash/stretch (Phase 11).
- **D-07:** The Mannequin is wrapped in its own scene around the imported GLB. The imported GLB is never edited in place.
- **D-08:** Animation runs through an `AnimationTree` with a state machine (Locomotion, Jump, Fall, Dash as in the stack plan in CLAUDE.md). Code sets parameters. The movement state machine stays the source of truth.
- **D-09:** Phase 1 is a demo, not real movement. The scaffold (`CharacterBody3D`, node-based state machine) exists, but there is no tuned walk/jump physics. Input actions trigger the clips (Idle, Run, Jump, Dodge). Tuned movement is Phase 2.

### Event bus and debug log
- **D-10:** The event bus is an autoload with typed signals (for example `signal jumped(position: Vector3)`). Gameplay code only emits. It calls no feedback directly. Juice (Phases 11-12) and audio (Phase 14) connect to these signals later.
- **D-11:** Phase 1 declares only the facts the demo triggers: `jumped`, `landed`, `dash_started`, plus a movement state change fact (for example `movement_state_changed`). More facts arrive with their own phases.
- **D-12:** The debug event log is an in-game overlay: a scrolling list of recent events with timestamps, toggled by a key (for example F3). No particles and no juice effects in the scene.

### Conventions and documentation
- **D-13:** Conventions are documented in `docs/CONVENTIONS.md`: collision layers, groups, folder and naming rules, Input Map action names. Layer names are also set in `project.godot` so the editor shows them.
- **D-14:** Collision layers (full list plus reserve): World, Player, Interactable, Enemy, Projectile/Beam, Hazard. Further layer numbers stay free and reserved. — **Reversibility:** costly — every mask in every scene and script references these numbers.
- **D-15:** Input Map uses the action names from the stack table in CLAUDE.md (`move_forward/back/left/right`, `jump`, `sprint`, `dash`, `aim`, `use_hand`, `interact`, `module_next/prev`, `pause`). KB+M is bound now. Gamepad slots are reserved but not bound. — **Reversibility:** costly — action names are referenced from code throughout.

### Project settings (carried from CLAUDE.md, not re-discussed)
- Godot 4.7.2 standard build, typed GDScript, Jolt (already set), Forward+ with D3D12 on Windows (already set), Physics Interpolation ON (still to set). The current `project.godot` has Jolt and D3D12 only: no input actions, no layers, no interpolation, no scenes yet.

### Claude's Discretion
- Exact key for the debug log toggle, overlay look and event payload fields.
- Test scene layout and size, as long as it uses only Prototype Bits pieces and has reference geometry on a 1 m grid.
- Exact AnimationTree state names and the clip-to-state mapping, using the KayKit clip names (Idle_A, Running_A/B, Jump_*, Dodge_*).
- Groups list in CONVENTIONS.md, beyond the layers above.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project planning
- `.planning/ROADMAP.md` §Phase 1 — goal, success criteria, notes (VisualRoot pivot, fact bus as the only Group A feedback hook)
- `.planning/REQUIREMENTS.md` — FOUND-01..05, FEEL-01
- `.planning/PROJECT.md` — core value and constraints
- `.claude/CLAUDE.md` — stack, input table, movement and animation plans, Git workflow (work on `dev`)

### Research
- `.planning/research/KAYKIT.md` — pack contents, Rig_Medium bone list, clip coverage table
- `.planning/research/GAME-FEEL.md` — feel research behind the feedback-hook requirement
- `.planning/research/ARCHITECTURE.md` — architecture notes
- `.planning/research/STACK.md` — stack rationale
- `.planning/research/PITFALLS.md` — known pitfalls

### Assets
- `KayKit/KayKit_Prototype_Bits_1.1_FREE/` — greybox pieces for the test scene
- `KayKit/KayKit_Character_Animations_1.1/Mannequin Character/characters/Mannequin_Medium.glb` — prototype character
- `KayKit/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/` — Rig_Medium clip libraries (MovementBasic, MovementAdvanced, General, ...)

### Project files
- `attimo/project.godot` — current engine settings

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `KayKit/` packs: Prototype Bits (geometry), Mannequin_Medium (character), Rig_Medium animation GLBs (Idle, Run, Jump, Dodge).

### Established Patterns
- None yet in `attimo/`. It holds only `project.godot`, `icon.svg`, `.editorconfig`, `.gitattributes` and `.gitignore` (ignores `.godot/`, `/android/`). Phase 1 sets the patterns.

### Integration Points
- The event bus autoload is the integration point for Phases 11, 12 and 14.
- `VisualRoot` is the integration point for Phases 3, 9 and 11.
- Input Map action names are the integration point for Phase 13.

</code_context>

<specifics>
## Specific Ideas

- The user wants the raw packs available to everyone as a reference library. They may be used later "when we get to it and something comes up".
- Work happens on `dev`. Merge to `main` only after verification.

</specifics>

<deferred>
## Deferred Ideas

- Git LFS for large binaries: revisit before Phase 9.
- Cleaning the 205 MB of raw packs out of git history: not planned. Only relevant if repo size becomes a problem.

</deferred>

---

*Phase: 1-Foundation & Prototype Character*
*Context gathered: 2026-11-04*
