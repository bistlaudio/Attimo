# KayKit & VFX Folder Analysis

**Analyzed:** 2026-11-02 (direct inspection of `KayKit/` in the repo root)
**Confidence:** HIGH (measured from the files themselves)

## What's in `KayKit/` (~207 MB, untracked)

| Pack | Size | Content | License |
|------|------|---------|---------|
| KayKit_Character_Animations_1.1 | 42 MB | Animation libraries for `Rig_Medium` and `Rig_Large` (FBX + GLB), Mannequin_Medium/Large reference characters | CC0 |
| KayKit_Skeletons_1.1_FREE | 17 MB | 4 skeleton characters (Mage, Minion, Rogue, Warrior) on Rig_Medium, props, own animations | CC0 |
| KayKit_Dungeon_Pack_1.1_FREE | 52 MB | 211 modular dungeon pieces (gltf/fbx/obj) | CC0 |
| KayKit_Prototype_Bits_1.1_FREE | 9 MB | Prototype/greybox pieces | CC0 |
| brackeys_vfx_bundle | 72 MB | Flipbooks (cloud/smoke/explosion/fire, 8x8 sheets), 93 alpha particle textures, pre-drawn spritesheets | CC0 |
| kenny particles | 15 MB | 81 transparent particle PNGs (Kenney Particle Pack 1.1) | CC0 |

All CC0: free for the uni project, credit optional (add to CREDITS.md anyway).

## Lessons for Attimo

### 1. KayKit characters are rigid, segmented meshes on a tiny rig

- `Rig_Medium` has ~18 bones and **no finger bones**: root, hips, spine, chest, head, upperarm/lowerarm/wrist/hand (L/R), upperleg/lowerleg/foot/toes (L/R).
- Each character is split into separate meshes per body part: `ArmLeft`, `ArmRight`, `Body`, `Head`, `LegLeft`, `LegRight`, plus accessories (Hat, Cloak, Cape, Jaw, Eyes).
- Measured triangle counts: Skeleton_Mage 4,588, Skeleton_Minion 5,288, Skeleton_Rogue 5,278, Skeleton_Warrior 5,934, Mannequin_Medium 6,916, Mannequin_Large 9,148.

**Consequences:**
- This is exactly the "rigid-bind per segment" approach the stack/pitfalls research recommended to avoid deformation problems with triangulated Meshy meshes. KayKit proves it looks good in this style.
- Hero budget: KayKit Medium characters sit at **~5–7k tris**. The current Meshy placeholder (3,027) is below that; the refined hero should land around **6–9k**, which reconciles STACK (8–10k) and PITFALLS (3–6k).
- The fixed prosthetic arm fits naturally: it is just the `ArmRight` segment, rigid on upperarm/lowerarm/hand.

### 2. Animation plan: use KayKit animations on the Meshy hero

The user wants KayKit animations on the Meshy character. Two routes:

- **Route A (preferred): rig the Meshy hero onto KayKit's `Rig_Medium` skeleton in Blender.** Import Mannequin_Medium, align the Meshy mesh (chibi proportions are close), split the hero mesh into the same segments, parent rigidly to the matching bones (Cloth/leather parts get light weight painting). Same bone names → KayKit clips play directly, no retargeting.
- **Route B (fallback): Godot BoneMap retargeting** from a Meshy auto-rig to `SkeletonProfileHumanoid`, with KayKit clips also mapped to the profile. More moving parts, more failure points with chibi proportions.

Route A also sidesteps Meshy auto-rig limitations (T/A-pose requirement, walk/run only).

### 3. Clip coverage for our verbs (Rig_Medium)

| Our action | KayKit clip(s) | Gap |
|------------|----------------|-----|
| Idle | Idle_A, Idle_B | — |
| Walk / Run | Walking_A/B/C, Running_A/B | — |
| Sprint | Running_B (speed-scaled) | Maybe lean via procedural spine tilt |
| Jump | Jump_Start, Jump_Idle, Jump_Land, Jump_Full_Short/Long | — |
| Double jump | — | Needs flip/tuck: make in Blender or procedural rotation |
| Dash (ground) | Dodge_Forward/Left/Right/Backward | — |
| Air dash | — | Reuse Dodge_Forward pose held in air, or new clip |
| Aim / hand beam (Modul 1) | Ranged_1H_Aiming, Ranged_Magic_Raise, Ranged_Magic_Shoot | Upper-body layer via AnimationTree blend |
| Pull (Modul 2) | Ranged_Magic_Raise / Throw (partial) | Needs "zip" pose; new clip |
| Push / steam (Modul 2) | Ranged_Magic_Shoot, Throw | Probably fine |
| Interact / pickup | Interact, PickUp, Use_Item | — |
| Damage / death / respawn | Hit_A, Hit_B, Death_A/B, Spawn_Ground, Spawn_Air | — |
| Celebrate (boss win) | Cheering | — |

Missing clips (double jump, air dash, pull/zip, optional wall-run) are few and small; build them in Blender on Rig_Medium.

### 4. Environment art conventions to copy

- **One atlas texture, one material** for the whole dungeon pack (`dungeon_texture.png`, material `texture`). Every piece samples colour swatches from it → confirms the shared palette-atlas plan.
- 211 modular pieces; measured triangle counts: min 20 (floor tiles), **median ~250**, max 3,499 (decorated long table). Matches the STACK budgets for kit pieces (150–1.2k) and medium props (800–3k).
- Pieces are grid-modular (floors, walls, stairs, corners) → our blockout should use the same grid so kit pieces drop in.
- Prototype Bits = ready greybox pieces for the movement gym and level blockout.

### 5. VFX sources for juice

- Brackeys flipbooks: cloud/smoke 8x8 sheets → **steam** for vents, Modul 2 push, landing puffs, dash trails.
- Kenney + Brackeys particle textures (sparks, circles, stars, traces) → beam impact, pickup, hit sparks, mechanism activation.
- Turquoise tinting happens in Godot materials; keep the raw textures neutral.

### 6. Repo hygiene

- `KayKit/` sits in the repo root, untracked, ~207 MB with FBX/OBJ/GLTF duplicates.
- Plan for Phase 1: copy only the GLB/GLTF + textures actually used into `assets/third_party/kaykit/...`, keep raw packs out of git (`.gitignore`) or put binaries under Git LFS. Same for the reference PNGs (move to `docs/reference/`).

## Roadmap implications

- Phase 1 (foundation/pipeline): Route A spike — Meshy placeholder on Rig_Medium, play Idle/Run/Jump/Dodge in Godot. This replaces the generic "Meshy auto-rig vs retarget" spike.
- Movement phase: animation state machine maps directly to the clip table above; missing clips tracked as tasks.
- Look/art phase: palette atlas modeled on `dungeon_texture.png`; steampunk kit built with the same grid and tri budgets.
- Juice: VFX library is already available; juice work is mostly wiring and tuning, not texture creation.
