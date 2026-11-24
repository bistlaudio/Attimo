# Phase 5: Energy Arm & Loader - Context

**Gathered:** 2026-11-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Rino's arm becomes a battery for momentum: 0-100 energy in 4 cores of 25, Moto Perpetuo from 50, income without enemies (passive speed charge, energy capsules and broken machines, charge button), energy costs for injected moves, the right-click **Loader** (freeze, store, aim and discharge momentum in slow motion), and the removal of aim mode. Requirements: HAND-04, FEEL-10, ENRG-01, ENRG-02, ENRG-03, ENRG-04, plus **ENRG-05 (energy HUD), pulled forward from Phase 6** by this discussion.

Also pulled forward by this discussion (both on the existing Phase 4 hand module framework, see D-11 and D-17):
- the **Extractor** module, limited to energy capsules and broken machines (enemies and shards stay in Phase 6);
- the **charged shot**: the Fernauslöser pulse becomes a flying projectile that costs energy (damage on enemies stays in Phase 6).

Not in this phase: enemies, health, shards, damage, module pickup and teaching rooms (HAND-05, HAND-06), hand poses (ART-04), the kit rework and the new target objects (Phase 05.1).

</domain>

<decisions>
## Implementation Decisions

### Loader rules and feel (HAND-04, highest risk: prototype first)
- **D-01 Ground use:** pressing the Loader on the ground brakes Rino hard (a short skid of about 0.1 s), then Rino stands still while the momentum is stored. The discharge may point anywhere in the view direction, including up (a super jump out of a run). In the air Rino hangs as in GAME-DESIGN.md section 4.
- **D-02 Once per air phase:** one Loader use per airborne stretch, refilled on landing (like the air dash). Boosters and the slingshot core may refill it (planner decides which, consistent with how they refill the air dash). The empty-arm redirect cooldown therefore matters mainly on the ground.
- **D-03 Independent from the air dash:** a Loader discharge neither refills nor spends the air dash; whatever state the air dash was in stays. After the release, air control is locked for about 0.15 s (same idea as `Capture.EXIT_CONTROL_LOCK`), then normal air control returns.
- **D-04 Feel property = "geladen" (a loaded spring).** Every cue points at it (Swink): while holding, tension builds (charge ring fills, a rising hum placeholder, the camera pulls back very slightly); the release is sharp, with a short hitstop. No clashing effects (no heavy camera shake, no "weighty cannon" cues). This answers the open lecture homework item "feel property".
- Carried from GAME-DESIGN.md section 4 (not re-asked): about 0.25x slow motion, hold capped at about 1.2 s real time then auto-discharge, free camera, discharge at `max(stored speed, minimum push) + bonus` capped; bonus costs 25 (one core); empty arm = redirect only with cooldown and a grey ring; desaturation plus turquoise vignette while holding; dashed trajectory preview.

### Energy income (ENRG-02)
- **D-05 Passive charge from about 10 m/s** (just above run speed 8.5 and Moto Perpetuo run ~9.5). Plain running never charges; every technique does (dash, dash hop, boosters, Loader discharge). The rate scales with speed, about +3/s at 10 m/s up to about +6/s at about 18 m/s. Tunable on F2. Note: this deliberately lowers the design-doc threshold of ~12 m/s, so that a normal dash (exit 12 m/s) charges clearly.
- **D-06 Charge button:** a new input action `charge` on **R**. Works only while standing still and held; moving, jumping or dashing cancels it. About +5/s, emergency fallback only.
- **D-07 Capsules and broken machines are drained with left click (hold) through the Extractor module** (D-11), not with E. Capsule about +40 over about 0.5 s; broken machine larger and slower (start: about +60 over about 2 s). Afterwards dark and empty.
- **D-08 Refill:** each source has a `respawn_time` parameter (0 = never). The gym uses a timed respawn for fast testing; the level (Phase 7) uses 0.

### Making energy visible (ENRG-01, ENRG-05)
- **D-09 On the arm:** four greybox cores (small glowing prisms) on the Mannequin forearm via `BoneAttachment3D` (same approach as `HandPresentation`). Full core = bright, partially filled = dimmed by fill, empty = dark. The real arm comes with the Rino model later.
- **D-10 Moto Perpetuo look:** the arm glows brighter, **both feet glow** and **a point on the back glows**, all as greybox glow points on bone attachments. Entering and leaving gets a short flash or fade (a sound placeholder is fine). No screen effect, so it never clashes with the Loader vignette.
- **D-12 Spend and lack feedback:** the core that is spent flashes briefly, then dims. A refused action (air dash with empty arm, shot under 10) makes the arm flicker grey, plus the existing `dash_blocked` style feedback. Falling back to a base version (dash hop stage 2 -> stage 1, wall run ending after the free window) gets **no** failure signal ("no failed moment" rule).
- **D-13 Energy HUD now (ENRG-05 moves from Phase 6 to Phase 5), top left:** 4 core chambers with partial fill, the Moto Perpetuo state, the active hand module (Extractor / shot), and a **momentum readout** (current speed, e.g. a gauge arc with marks at the passive-charge threshold and other useful speeds). Health is added next to it in Phase 6; the layout leaves room. Style follows the current reticle tuning (steel rim and plate, turquoise energy). — **Reversibility:** reversible — HUD layout only; the planner updates REQUIREMENTS.md and ROADMAP.md for the ENRG-05 move.
- **D-14 Two charge rings at the crosshair, told apart at a glance:** the Loader hold shows a ring at the crosshair that turns and fills, like the shot charge ring, but visibly different (for example the shot is a notched ring turning clockwise, the Loader a double ring filled by momentum turning the other way). Exact look is Claude's discretion as long as the two never read the same.

### Aim mode removed, what left click does (ENRG-04)
- **D-15 Aim mode is removed:** goggle HUD, zoom/FOV, shoulder offset, aim pose layer, aim strafe facing, and pull/push leftovers go. The small crosshair stays always visible.
- **D-16 Mouse wheel (and 1/2) switches between two hand modules:** Extractor (D-11) and the shot (the Fernauslöser, D-17). Both fire from the hip at the always-visible crosshair; no aim button is needed any more.
- **D-11 Extractor module now, capsules and machines only:** a real hand module (one folder + one registry entry, Phase 4 framework), left-click hold, a cone in front of the hand that drains energy sources. Phase 6 adds enemies and shards to the same module; the code is kept, not thrown away.
- **D-17 The shot is a flying projectile, never a beam** (user: "kein Strahl, Schuss wie Mega Man oder Samus"). This replaces Phase 4 D-04 (instant raycast hit with a cosmetic streak). Charge model = **hybrid**: tap fires a small shot for **10**; holding drains energy continuously while the projectile grows, up to a total of **25** in about 0.8 s, with one clearly readable **full-charge** tell (flash plus sound, Samus style). Releasing earlier fires a proportional shot. If energy runs out while charging, the charge stops at that level. More charge = more range and enough force for heavy mechanisms now, and more damage from Phase 6 (the hit payload carries the energy spent). — **Reversibility:** costly — `PulseHit`, the pulse size contract of `Interactable` (small/big, Phase 4 D-03/D-09), targeting and the gym puzzles all change with it.
- **D-18 Shot under 10 energy does not fire:** grey arm flicker (D-12). Near contact with E stays free, so levers and the crank stay solvable. Every gym puzzle room that needs a shot gets an energy capsule with respawn next to it.
- **D-19 Aim assist:** snap and hysteresis stay and become **stronger and noticeable**: a valid target near the crosshair locks (ring turquoise) and the projectile clearly bends to it, so targets can be hit while moving fast. The mouse slowdown ("sticky aim") is removed.

### Movement gym rework (ROADMAP criterion 6, gym rule)
- **D-20 Remove:** aim-mode stations and pull/push leftovers; signs and "Erwartet:" lines that mention aiming are rewritten for hip fire.
- **D-21 Loader test room** (built first, with the Loader prototype): open space to freeze and redirect on the ground and in the air, gaps and heights that need a Loader discharge with bonus vs. a plain redirect, measured against the FEEL-10 metrics.
- **D-22 Energy area:** a charge track (long straight plus booster/dash-hop line to see passive charge above ~10 m/s), energy capsules and one broken machine with timed respawn (Extractor station), a charge-button spot, and one station per injected move (air dash, dash hop stages 2-3, wall run past the free window) showing the base version with an empty arm and the injected version with energy.
- **D-23 Shot stations:** tap vs. full charge (range and heavy mechanism), plus a target to hit while moving fast (stronger snap, D-19).
- **D-24 Existing puzzle rooms stay solvable without aim:** every station or puzzle that needs a shot gets a capsule with respawn next to it (D-18); mechanisms that needed the big pulse accept the charged shot.
- **D-25 Readout:** the energy HUD (D-13) is the readout for all stations; the F2 panel holds the energy and Loader tunables.
- All gym content stays builder-generated (`attimo/tools/mechanism_rooms_builder.gd` and the gym builders), never hand-edited; every new station gets a smoke test and an "Erwartet:" sign.

### Plan-phase follow-up (2026-11-24, answers to RESEARCH open questions)
- **D-26 Mouse wheel = module switch only:** camera wheel zoom (`camera_rig.gd`) is removed; the wheel and 1/2 switch hand modules (D-16). Camera distance stays fixed / F2-tunable.
- **D-27 Aim layer kept dormant for the arm:** the `Aim` Blend2 layer and `AimPoseModifier` stay, driven by an `arm_out` signal (shot, near contact E, Loader) instead of the `aim` hold, until the Phase 6 hand poses replace them. Aim strafe locomotion points and aim dashes (`DashLeft/Right/Back`) may go with aim strafe facing.
- **D-28 `Interactable.GlowStage.AIM` is reused as "shot ready":** a target brightens when it is under the crosshair lock and the arm can afford a shot (>= 10). Rename is the planner's call.
- **D-29 Loader pitch:** while the Loader is held, the camera pitch-up limit rises to about 75 degrees (F2-tunable) so near-vertical super jumps are possible; after release it eases back to the normal `pitch_max`.
- Researcher defaults accepted without asking: the Loader bonus needs a full core (25), otherwise the arm counts as empty; `base_shoulder_offset` (debug over-the-shoulder offset) stays untouched; the Loader room and energy area are new gym zones built by a builder tool.

### Carried forward (not re-asked)
- Energy numbers and the governing rule from GAME-DESIGN.md sections 2-3: air dash 10 (does not fire when empty), dash hop stages 2/3 cost 15 each (stage 1 free), wall run free for about 0.6 s then 15/s, jumping off always free, respawn with exactly 25, Moto Perpetuo +10-15 % run speed and buffed Jump 3.
- Phase 4 D-30 / memory: stay in the GSD band, 3-5 plans.
- Gym rule: the phase ends with the movement gym reworked (ROADMAP criterion 6).

### Claude's Discretion
- How the Loader is built (extend the existing `Capture` state or a new `Loader` state sharing code with it; GAME-DESIGN.md 6.8 says catch & launch "shares code with the Loader").
- Loader minimum push, bonus, cap, cooldown, the empty-arm cooldown length, camera pull-back amount, hitstop length; all F2 tunables recorded in the FEEL-10 metrics table.
- Slow motion technique (`Engine.time_scale` vs. local time scaling) as long as input, camera and the 1.2 s cap run in real time.
- Whether the Loader can be cancelled while holding, and what damage/obstacles do during the hold.
- Extractor cone size and range, whether Rino may move while extracting, machine amounts.
- Exact momentum gauge marks, HUD sizes and colours, glow point sizes.
- Projectile speed, size curve and bend strength; assist angle and hysteresis.

</decisions>

<lecture_checklist>
## Lecture Checklist (docs/reference/LECTURE-PRINCIPLES.md section 1)

| # | Check | Answer for Phase 5 |
|---|---|---|
| 1 | Question | Does stopping, storing and redirecting momentum with the Loader, paid by an arm that refills from speed, make the movement feel more fluid and more expressive instead of interrupting it? |
| 2 | Greatest risk first | The Loader feel (hold, slow motion, free camera, release). First plan builds and tunes it in a Loader test room before the energy economy is layered on. |
| 3 | Fidelity | Greybox: glow prisms on bone attachments, primitive capsules and machines, placeholder sounds. HUD functional, not final art. |
| 4 | Metrics | Loader metrics table (FEEL-10) and energy rates go into MOVEMENT-METRICS.md; gym stations measured against MovementConfig. |
| 5 | Toybox | Loader test room plus an energy area in the gym: charge track, capsules, injected-move stations with energy readout (criterion 6). |
| 6 | Teach, test, twist | Gym only in this phase; the teaching rooms come in Phase 6. Flag: the Loader has no teach/test/twist beats yet. |
| 7 | Don't challenge learners | Respawn with one core, capsules with respawn in the gym, base moves always free. |
| 8 | Loop relationships | Reinforcing: speed -> passive charge -> injected moves / Loader bonus -> more speed. Balancing: costs, cap 100, respawn at 25. Note: with the 10 m/s threshold, Moto Perpetuo's faster run (~9.5) no longer charges by itself; the reinforcing link runs through techniques. Flag for playtest. |
| 9 | Which knob | Player-character level (MovementConfig, energy config) only; no kit or level changes to compensate. |
| 10 | Feel property | "Geladen" (loaded spring), D-04. |
| 11 | Readability | Turquoise = energy everywhere; two distinct crosshair rings (D-14); grey flicker = lack; full-charge tell (D-17). |
| 12 | Architecture | Energy lives in one owner (an arm energy component on the player) with spend/try_spend/gain APIs; EventBus facts carry amounts (energy_changed(value), energy_spent(amount, reason)). Keeps adding new costs cheap. Modules stay one folder + registry line. |
| 13 | Done means | ROADMAP Phase 5 criteria 1-6 plus D-13 HUD, D-11 Extractor on capsules, D-17 charged projectile shot. |
| 14 | Docs | GAME-DESIGN.md, game-design.html and attimo-presentation.html updated in this session (shot charge model, Extractor in Phase 5, HUD, Moto look, passive threshold). |

</lecture_checklist>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Design
- `docs/GAME-DESIGN.md` sections 1-5 — core loop, governing rule, resource, Loader, modules (source of truth; updated with this discussion)
- `.planning/notes/2026-11-23-energy-momentum-core-mechanic.md` — origin of the energy-momentum design
- `docs/reference/LECTURE-PRINCIPLES.md` — planning checklist, loop relationships, element hierarchy, architecture guardrails

### Requirements and roadmap
- `.planning/ROADMAP.md` Phase 5 — goal, success criteria 1-6, research sources (Swink, Nesky, Pittman)
- `.planning/REQUIREMENTS.md` — HAND-04, FEEL-10, ENRG-01..05

### Prior phase decisions that change here
- `.planning/phases/04-fernausl-ser-mechanism-kit/04-CONTEXT.md` — D-02 (fire only while aiming: replaced by D-16), D-03/D-05 (small/big pulse: replaced by D-17), D-04 (instant hit: replaced by projectile), D-13 (goggle HUD: removed), D-14 (sticky aim slowdown: removed by D-19), D-24/D-25 (module framework and hit payload: reused)
- `.planning/phases/03-animated-mannequin-aim-mode/03-CONTEXT.md` — aim mode decisions D-09..D-15 and DEV-03 (removed with aim mode)
- `.planning/phases/04.1-mechanism-kit-extension-hud-polish/04.1-CONTEXT.md` — D-01 always-visible crosshair, D-02 E prompt, D-10 slingshot (Capture state)

### Research sources (named in ROADMAP)
- `docs/vorlesung/books/swink-2008-game-feel.pdf` (local, git-ignored) — Loader feel
- Nesky, "50 Game Camera Mistakes" (GDC 2014) — Loader free camera
- Pittman, "Building a Better Jump" (GDC 2016) — buffed Moto Perpetuo Jump 3

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `attimo/scripts/player/states/capture.gd`: freezes the body (gravity off), holds, releases with a clamped exit velocity, 0.15 s air-control lock, stuck guard. Closest base for the Loader hold and release.
- `attimo/scripts/mechanisms/slingshot_core.gd`: the steampunk counterpart that must later feel exactly like the Loader (shared code per GAME-DESIGN 6.8).
- `attimo/scripts/hand/`: module framework (`HandModuleDef`, `HandModule`, `module_registry.gd`, `hand_controller.gd`), `targeting.gd` (aim assist snap/hysteresis), `pulse_hit.gd` (hit payload), `hand_presentation.gd` (bone attachments on `hand.r` and the forearm, palm glow).
- `attimo/scripts/ui/crosshair.gd`: always-visible crosshair plus aim-only goggle HUD and charge arc; the charge arc becomes the shot ring, a second Loader ring is added, the goggle parts go.
- `attimo/scripts/player/movement_config.gd`: `dash_exit_speed` 12, `run_speed` 8.5, long jump stages, wall run values; energy tunables can live here or in a sibling config.
- `attimo/scripts/debug/tuning_panel.gd` (F2) and `metrics_overlay.gd`: tuning and readouts.
- `attimo/scripts/gym/fall_reset.gd`: respawn path, where the reset to 25 energy hooks in.

### Established Patterns
- Movement FSM is the source of truth; mechanisms influence the player only through PlayerController request APIs (04.1 D-06).
- EventBus facts carry values (`autoload/event_bus.gd`); new energy facts follow that.
- Gym rooms are generated by builders (`attimo/tools/mechanism_rooms_builder.gd`), never hand-edited; every station has a smoke test and an "Erwartet:" sign.
- Smoke tests in `attimo/tests/smoke/`; aim tests (`test_aim_*.gd`) must be removed or rewritten with aim mode.

### Integration Points
- `PlayerController` (air dash availability, long jump stage, wall run timer) gets energy checks for the injected moves.
- `MannequinAnimator` aim layer and `AimPoseModifier` are removed or disabled.
- `CameraRig` additive FOV/offset sources: aim offset removed; Loader pull-back uses the same additive path.
- Input Map: `aim` action becomes the Loader (RMB), new `charge` (R), `module_next/prev` (wheel, 1/2).

</code_context>

<specifics>
## Specific Ideas

- Shot like Mega Man / Samus charge shot: a growing projectile with a full-charge flash and sound, never a beam.
- Targets that must be hit while moving fast should be plate-like **gear discs** (Zahnräder) with a noticeable snap assist (target look belongs to Phase 05.1, see deferred).
- Moto Perpetuo: arm, both feet and a point on the back glow.
- HUD top left with a momentum readout next to the cores.

</specifics>

<deferred>
## Deferred Ideas

- **Target look as gear discs** (plate-like, gear-shaped, turquoise core) — Phase 05.1 Kit Rework, where targets replace levers. The stronger snap (D-19) is built now.
- **Health next to the energy HUD** — Phase 6.
- **Shot damage on enemies, shards, Extractor on enemies** — Phase 6 (payload already carries the energy spent).

</deferred>

---

*Phase: 05-energy-arm-loader*
*Context gathered: 2026-11-24*
