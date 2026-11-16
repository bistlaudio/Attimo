# Phase 3: Animated Mannequin & Aim Mode - Context

**Gathered:** 2026-11-12
**Status:** Ready for planning
**Amended:** 2026-11-15 (DEV-03, approved by the developer; see "Amendments" at the end of Decisions)

<domain>
## Phase Boundary

The Mannequin (KayKit Mannequin_Medium on Rig_Medium) animates with every movement state that exists after the Phase 2 movement rework, using only kit clips, cuts, blends, playback speed and procedural rotation/scale on `VisualRoot` (MOVE-09, MOVE-11). Holding the aim button blends into an aim mode with crosshair, tighter FOV and a right-shoulder camera offset (CAM-02); in aim mode the Mannequin faces the crosshair and moves with strafe/backwards kit clips.

Movement states to present (current code, `attimo/scripts/player/states/`): Idle, Run, Jump (ground chain stages 1-3), LongJump (dash hop, stack stages 1-3), Fall, Dash (ground and air). There is no sprint, no air double jump, no wall-run and no ledge grab.

Out of scope: interactable highlight and aim assist (Phase 4), shooting and arm firing look (Phases 4/6), any juice, particles or camera kick (Phases 11-12), gamepad (Phase 13), a slide verb (not wanted), final hero and its fingers/prosthesis (Phase 9).

</domain>

<decisions>
## Implementation Decisions

### Ground dash and long jump (dash hop)
- **D-01:** The ground dash plays `Dodge_Forward` plus a procedural forward lean of the body (code rotation on `VisualRoot`, pitch toward the dash direction). The lean must blend cleanly into the long jump when the player jumps out of the dash, because that hand-over is the key look.
- **D-02:** The air dash stays as it is now: `Dodge_Forward` held as a pose in the air, no extra lean. The lean applies to the ground dash only.
- **D-03:** No slide. The user does not want a slide verb or a slide pose; the dash lean flowing into the jump covers it. (A slide would also have no kit clip, MOVE-11.)
- **D-04:** The long jump (dash hop) plays `Jump_Start` with a held forward stretch lean in flight (superman style), then `Jump_Land` on touchdown. The lean continues from the dash lean (D-01).
- **D-05:** The long jump at **stack stage 3** (maximum speed) additionally plays the Jump 3 pirouette (D-07). Stages 1 and 2 only use the stretch lean.
  - **AMENDED by DEV-03 (2026-11-15, approved by the developer):** the stage-3 pirouette follows the aim exception of DEV-03: it does not start when aim is held at takeoff, and an aim press or an air dash mid-spin finishes it cleanly within about 0.1 s (`pirouette_finish_time`). See "Amendments".

### Jump chain and landing
- **D-06:** Jump 1 and Jump 2 use `Jump_Start` -> `Jump_Idle` -> `Jump_Land` (the current mapping).
- **D-07:** **Jump 3 (the old "salto") becomes a pirouette:** one 360 degree rotation around the vertical axis (code rotation on `VisualRoot`), normal jump pose otherwise. The rotation takes the flight time of the jump and ends shortly before landing so `Jump_Land` starts clean. No flip, no double rotation. Reason: the user finds a flip too playful for a steampunk character. The planner updates the "salto/flip" wording in REQUIREMENTS.md (MOVE-05, MOVE-09, FEEL-02) and ROADMAP.md Phase 3 criterion 1 accordingly. — **Reversibility:** reversible — the rotation is one code parameter on `VisualRoot`.
  - **AMENDED by DEV-03 (2026-11-15, approved by the developer):** D-07 had no aim exception; it now has one. The pirouette is suppressed when aim is held at takeoff, and if aim or an air dash is pressed mid-spin, the spin finishes cleanly within about 0.1 s (`pirouette_finish_time`) instead of snapping. See "Amendments". (The node that carries the rotation is fixed by DEV-01: the `Mannequin` child of `VisualRoot`.)
- **D-08:** Landing is a blend without lock: `Jump_Land` plays as a short blend and is overridden at once by run or idle when the player moves. No landing lock and no anticipation longer than 2 frames (ROADMAP criterion 4); the Phase 2 latency numbers must still hold.

### Aim mode: behavior
- **D-09:** The aim button is **hold** (CAM-02). While held, the Mannequin always faces the crosshair/camera direction (no smoothing delay), and moves with `Running_Strafe_Left`/`Running_Strafe_Right` and `Walking_Backwards` blended by movement direction relative to the camera.
- **D-10:** In aim mode the player may run, jump and dash. Aim does not block movement. Run speed in aim may be reduced slightly (tunable value in `MovementConfig`, Claude picks the start factor).
- **D-11:** The aim upper-body pose is `Ranged_1H_Aiming` (arm bent, pistol-like), layered on the upper body via bone filter while the legs keep the locomotion clips. The user viewed `Ranged_Magic_Raise` (raises the arm up) and `Ranged_Magic_Shoot` (a cast) and rejected them; `1H_Aiming` is the only one of the three where the arm points forward. A procedural fine adjustment rotates the aiming arm so it points at the crosshair at any camera pitch. The Mannequin has **no finger bones**, so the hand shape cannot change; only arm, wrist and torso animate.
- **D-12:** Dash in aim mode: the figure keeps facing the crosshair, so the dash uses the directional kit clips `Dodge_Left`, `Dodge_Right`, `Dodge_Backward` (and `Dodge_Forward`) chosen by dash direction relative to facing. Outside aim mode the dash keeps D-10 of Phase 2 (turn, then `Dodge_Forward`). The planner may adjust this if the clips look wrong in the gym; flag it in the plan. — **Reversibility:** reversible — a clip choice per direction.

### Aim mode: camera and crosshair
- **D-13:** The aim camera sits over the **right shoulder** (the prosthesis is the right arm), fixed, **no shoulder swap**. AMENDED by the developer at the 03-01 checkpoint (2026-11-16): no swap action is added, Q stays unbound, aim-lock is out of scope.
- **D-14:** FOV becomes slightly tighter in aim (about 10 to 15 degrees) with a fast blend (about 0.15 to 0.2 s). Both are tunable in the F2 panel. The blend uses the additive FOV/offset sources of `CameraRig` (Phase 2 D-18), so Phase 11 camera kick still stacks on top.
- **D-15:** The crosshair is a small dot with a thin ring. The ring is reserved for Phase 4 states (it glows turquoise when a target is locked). It is shown only while aiming. Mouse sensitivity in aim follows the CAM-03 settings; a separate aim sensitivity factor is Claude's discretion.

### Claude's Discretion
- Pirouette direction (clockwise or in the movement direction), exact timing curve, and the pitch angles of the dash lean and the stretch lean.
- Run clip speed scaling against ground speed (`Running_A` playback speed, idle variant), blend times between states (the current state machine uses 0.1 s cross-fades), and foot sliding tolerance.
- Aim run-speed factor, aim sensitivity factor, exact FOV and offset values, crosshair size and colours.
- New input action name for the shoulder swap and the exact bone filter for the upper-body layer.
- Whether `Dodge_Left/Right/Backward` is enough for aim-mode dash (D-12) or needs a fallback.

### Amendments (approved by the developer)

Recorded after the discuss session, during plan revision. Each entry is a genuine developer answer, not a planner default. Plans cite them by ID; 03-01-PLAN.md "Developer Decisions" holds the full text the executor copies into 03-01-SUMMARY.md.

- **DEV-03 (2026-11-15, approved by the developer, option B): pirouette exception in aim mode.** An explicit, recorded amendment of D-05 and D-07, which had no aim exception. A pirouette (Jump 3, or long jump stage 3) does not start when aim is held at takeoff. If aim is pressed, or an air dash starts, while a pirouette is running, the remaining spin finishes cleanly within about 0.1 s (`pirouette_finish_time`, a tunable) instead of snapping or being cut off. Implemented and tested by 03-06; documented by 03-09 (docs/ANIMATION-MAP.md, docs/CONVENTIONS.md, MOVE-09, ROADMAP Phase 3 criterion 1). The lean scale while aiming is not part of DEV-03; it stays a checkpoint default (03-01 item 3).
- **DEV-01 (2026-11-14, confirmed by the developer):** lean and pirouette are written on the `Mannequin` child under `VisualRoot`, not on `VisualRoot` itself, because VisualRoot's yaw is the facing that `PlayerController.face()`, `Dash`, `LongJump` and `CameraRig.recenter()` read. Amends the letter of D-01, D-07 and the Integration Points note below ("code rotation on `VisualRoot`"); the intent (one code rotation in the visual hierarchy) is kept. Phase 11 squash/stretch uses the same Mannequin transform.
- **DEV-02 (2026-11-14, confirmed by the developer):** the air dash holds its Dodge pose past the Dash state's exit, through Fall, until landing or `air_dash_hold_time`; presentation only, it never delays control. Refines D-02 ("held as a pose in the air") and is the one documented exception to the same-frame rule of ROADMAP Phase 3 criterion 4.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project planning
- `.planning/ROADMAP.md` §Phase 3 - goal, success criteria 1-4 (note "Jump 3 salto flip" wording to change per D-07)
- `.planning/REQUIREMENTS.md` - MOVE-05, MOVE-09, MOVE-11, CAM-02, FEEL-02
- `.planning/PROJECT.md` - core value, constraints
- `.claude/CLAUDE.md` - input table (aim, dash), animation section (AnimationTree layout: Locomotion BlendSpace, upper-body layer with bone filter), camera section
- `.planning/phases/02-movement-core-follow-camera/02-CONTEXT.md` - D-10 dash direction, D-14/D-18 camera and additive FOV/offset sources. Note: its sprint and air-double-jump decisions were replaced by the movement rework (see MOVE-02, MOVE-05).
- `.planning/phases/01-foundation-prototype-character/01-CONTEXT.md` - D-06 VisualRoot, D-08 AnimationTree, event bus facts

### Research and assets
- `.planning/research/KAYKIT.md` §3 - clip coverage per verb on Rig_Medium
- `docs/CONVENTIONS.md` - action names, layers (add the shoulder swap action)
- `docs/MOVEMENT-METRICS.md` - latency and movement numbers that must still hold
- Kit animation files (outside the Godot project, source for the library build): `KayKit/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_CombatRanged.glb` (`Ranged_1H_Aiming`), `Rig_Medium_MovementAdvanced.glb` (`Dodge_*`, `Running_Strafe_*`, `Walking_Backwards`), `Rig_Medium_MovementBasic.glb` (`Jump_*`, `Running_A`)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `attimo/scripts/player/mannequin_animator.gd`: today maps `StateMachine.state_changed` to `AnimationTree` travel (Idle/Run -> Locomotion, Jump/LongJump -> Jump, Fall, Dash) and plays `Land` when a jump ends in Idle. It does not yet separate Jump 1/2/3, long jump stages, ground vs air dash, or aim.
- `attimo/scenes/player/mannequin_state_machine.tres`, `attimo/tools/build_mannequin_state_machine.gd`: AnimationTree state machine (Locomotion BlendSpace1D idle/run, Jump_Start, Jump_Idle, Jump_Land, Dodge_Forward, 0.1 s transitions) is generated by a tool script.
- `attimo/assets/animations/rig_medium/rig_medium_library.res`, `attimo/tools/build_animation_library.gd`: the library currently holds only 6 clips (Idle_A, Running_A, Jump_Start, Jump_Idle, Jump_Land, Dodge_Forward). It must be extended with `Ranged_1H_Aiming`, `Running_Strafe_Left/Right`, `Walking_Backwards`, `Dodge_Left/Right/Backward`. The CombatRanged and MovementAdvanced files must be copied into `attimo/assets/animations/rig_medium/` (only used assets are copied; the whitelist guard applies).
- `attimo/scripts/player/states/jump.gd` (stage via `advance_chain_for_ground_jump()`), `long_jump.gd` (stage via `advance_long_jump_stage()`), `dash.gd` (`in_air`, `direction`): expose the stage and dash type the animator needs. `EventBus` facts: `jumped`, `long_jumped(position, stage)`, `dash_started(position, direction, in_air)`, `landed`.
- `attimo/scripts/camera/camera_rig.gd` with additive FOV/offset sources, `camera_settings.gd`, `attimo/scenes/debug/tuning_panel.tscn` (F2 panel) for the aim values.

### Established Patterns
- Animation shows state; the local `state_changed` signal drives the AnimationTree. Gameplay does not call feedback functions (D-10/D-11 of Phase 1). Animation must switch on the same frame as the state.
- Typed GDScript, node-based FSM, physics interpolation on, camera in `_process`.

### Integration Points
- `VisualRoot` carries procedural lean/pirouette rotation (Phase 3) and later squash/stretch (Phase 11). **Amended by DEV-01:** both go on the `Mannequin` child of `VisualRoot`; VisualRoot's yaw stays the facing (see "Amendments").
- Aim mode touches `PlayerController` (facing, speed factor), `CameraRig` (additive FOV/offset), the Input Map (aim exists; add shoulder swap) and a new crosshair UI in the HUD layer.

</code_context>

<specifics>
## Specific Ideas

- Look reference: a steampunk character, so movement reads controlled and mechanical rather than playful (no flips). The pirouette instead of the salto is the first expression of this.
- A throwaway clip viewer was built in the session scratchpad to compare clips. It is not part of the repo; the planner can ask for a rebuild if needed.

</specifics>

<deferred>
## Deferred Ideas

- Slide on the ground: considered and dropped (D-03). Revisit only as its own verb with a clip composition (MOVE-11).
- Second aim pose (`Ranged_2H_Aiming`, `Ranged_Bow_Aiming_Idle`) were shown but not chosen; reconsider if the 1H pose reads badly in aim mode.
- Pirouette variants (double rotation, half flip, dive) were shown and not chosen.

</deferred>

---

*Phase: 3-Animated Mannequin & Aim Mode*
*Context gathered: 2026-11-12*
*Amended: 2026-11-15 (DEV-03 approved by the developer; DEV-01 and DEV-02 of 2026-11-14 cross-referenced)*
