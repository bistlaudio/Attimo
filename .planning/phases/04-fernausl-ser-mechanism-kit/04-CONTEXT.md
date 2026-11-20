# Phase 4: Fernauslöser & Mechanism Kit - Context

**Gathered:** 2026-11-20
**Status:** Ready for planning

<domain>
## Phase Boundary

The first hand module, the Fernauslöser, plus the framework around it and a mechanism kit to use it on:

- The module framework (HAND-01, HAND-02): a module is a definition resource plus a behaviour scene, added with one folder and one registry entry. A dummy test module proves it. The arm mesh never changes.
- The Fernauslöser itself (HAND-03): a **pulse shot**, not a beam (D-01), plus a **near interaction** with the hand (D-08).
- Interactable glow, target highlight, aim assist and a minimal "goggle" HUD while aiming (CAM-04, CAM-05).
- A mechanism kit of 4 triggers and 6 signal-driven mechanisms, wired in the editor with AND, OR and timer logic (MECH-01, MECH-02). Moving parts carry the player cleanly (MECH-03).
- A second gym room (showcase) followed by several puzzle rooms that together cover every mechanism (D-27 to D-29).

Everything is greybox built from KayKit Prototype Bits (Group A rule). No particles and no juice VFX in this phase.

**Wording changes the planner must carry into REQUIREMENTS.md and ROADMAP.md:** HAND-03 and Phase 4 success criterion 2 say "beam". The developer chose a pulse shot (D-01), so "beam" becomes "pulse". MECH-01 lists "switches, valves, gears, conveyor belts and doors". It becomes the kit in D-15 and D-16. Phase 4 criterion 3 ("a sandbox puzzle room") becomes "a showcase room plus puzzle rooms" (D-27). SHOOT-01 in Phase 6 ("the hand beam can also shoot") should say "pulse" as well.

</domain>

<decisions>
## Implementation Decisions

### Fernauslöser: the pulse shot
- **D-01:** No beam. The Fernauslöser fires a **pulse**. A short tap fires a **small pulse**. A short hold charges a **big pulse**. The developer said explicitly: "nie Strahl" (never a beam). — **Reversibility:** reversible — presentation and input timing only.
- **D-02:** Fire only **while aiming**: hold RMB (`aim`), then LMB (`use_hand`) fires. LMB without aim does nothing.
- **D-03:** The big pulse is needed for **heavy mechanisms**. Each Interactable declares whether the small pulse is enough or the big one is needed (part of the HAND-02 accept contract). The big pulse also **reaches further**: small about 15 m, big about 25 m, both tunable (D-13).
- **D-04:** The pulse is an **instant hit** (raycast from the camera or crosshair, or the aim-assist target, D-12). The visible pulse is presentation only, a short turquoise flash or streak from the hand to the hit point. The target reacts on the next frame (ROADMAP Phase 4 criterion 2).
- **D-05:** Charge threshold about **0.4 s**. Releasing before 0.4 s fires a small pulse. Once 0.4 s has passed the shot is charged (the charge arc fills, D-11), and releasing fires the big pulse. No auto-fire. The player may run and jump while charging (aim rules from Phase 3 D-10 apply). The threshold is tunable in the F2 panel.
- **D-06:** A shot into empty space or at an invalid target **still fires**. It travels to max range or the first hit and changes nothing. An invalid target (wrong pulse size, not accepted, out of range) already shows the invalid reticle state beforehand and stays unchanged. In this phase the only feedback for a hit is the target's own reaction.
- **D-07:** Cooldown between shots about **0.25 s**, tunable. It has no HUD element of its own (the developer rejected a cooldown needle). The reticle may dim briefly during the cooldown.
- **D-07b:** **Hand energy language:** the palm of the prosthetic hand glows. It gets brighter while charging and gives a short **flash** on firing ("Energie soll gezeigt werden"). This is an emissive spot or small light at the hand bone, not a particle effect.

### Near interaction (hand contact)
- **D-08:** A second way to use the hand: when the player is **close** to an Interactable that accepts near contact, pressing **`interact` (E)** makes the figure stretch the arm out (same arm-out direction as the shot). The **arm glows and the palm pulses and glows**, an "Iron Man repulsor" vibe. The target reacts. The developer approved this for Phase 4. Particles for it come in Phase 12. The Mannequin has no finger bones, so the hand shape stays the same; only arm, wrist and the glow animate.
- **D-09:** Interactables declare whether they accept the **shot**, **near contact**, or both, alongside the small/big pulse requirement (D-03). This is the HAND-02 contract.
- **D-10:** Near contact can be **held**. Holding E on the Uhrwerk-Kurbel winds it up (D-19), with the palm pulsing for as long as it is held.

### Glow, highlight and the goggle HUD
- **D-11:** Interactables **always glow faintly** turquoise (the visual vocabulary: turquoise means "the hand can affect this"). While aiming the glow gets **stronger**, the "goggles" idea. The targeted one is the brightest and pulses slightly. Nothing that is not interactable may glow turquoise. The faint glow outside aim is allowed under the Group A rule (feedback that carries information).
- **D-12:** **Target look = variant A, but more minimal, thinner and more steampunk:** a brighter, slightly pulsing glow on the target plus the reticle state. No outline shader and no marker above the target (variants B and C were shown and rejected; screenshots are in the discussion log).
- **D-13:** **Goggle HUD, visible only while aiming, very minimal, thin white lines:**
  1. Goggle rim: thin arcs at the left and right screen edges with small rivets.
  2. Reticle: a thin ring with four small gear notches and a centre dot. White with no target, turquoise on a valid target. A second thin outer ring means "needs the big pulse". Invalid or out of range: dimmed, with a diagonal stroke.
  3. Charge arc: an arc around the ring fills while the big pulse charges.
  4. Module indicator: a small frame at the bottom centre. In Phase 4 it shows the active module (the Fernauslöser); the real module icon comes in Phase 5.
  Rejected: range scale, cooldown needle. The reticle needs a dark outline or shadow so it stays readable over turquoise targets. Extends `Crosshair` (`set_locked` is already reserved for this, Phase 3 D-15).
- **D-14:** **Aim assist = snap plus slight slowdown.** A valid Interactable within a few degrees of the crosshair becomes the target (reticle turquoise), and the pulse hits it exactly. With hysteresis, so it does not flicker between neighbours (CAM-05). Mouse sensitivity drops slightly while the crosshair is over a target ("sticky aim"). The camera is **never pulled** toward a target. Angle, hysteresis and slowdown factor are tunable.

### Mechanism kit: triggers (what the hand affects)
- **D-15:** Four trigger types, all glowing turquoise:

| Trigger | How it is used | Behaviour |
|---|---|---|
| Hebel (lever) | small pulse or near contact | toggles on/off on each hit |
| Handrad-Ventil (hand-wheel valve) | big pulse | toggles on/off on each hit (a "heavy switch"); the wheel visibly turns |
| Energiekern (energy core in a lantern) | pulse at range | charges and glows for X seconds, then switches off by itself (a visible built-in timer) |
| Uhrwerk-Kurbel (clockwork crank) | near only, hold E | winds up while held (up to about 1.5 s gives up to about 10 s), then ticks down and switches off |

  The "Signalglocke" idea (a bell high up, reachable only by shot) is a level-design placement of a lever or energy core, not its own component.

### Mechanism kit: the 6 signal-driven mechanisms
- **D-16:** Six mechanisms. Several of the developer's 15 picks were merged as variants of one component:

| # | Mechanism | Covers the developer's picks | Notes |
|---|---|---|---|
| 1 | Zahnrad-Tor (gear gate) | 11 | Round gate in a gear frame, rolls aside |
| 2 | Dreh-Plattform (rotating platform) | 7 gear platform, 20 clock-hand platform, 17 tilting platform | Axis set per instance: lying (gear), standing (clock hand), tilting |
| 3 | Hub-Plattform (lift platform) | 8 piston column, 14 chain platform | Moves between point A and B; piston or chain look |
| 4 | Förderband (conveyor) | 10 | Pushes the player or objects in one direction |
| 5 | Dampfdüse (steam nozzle) | 12 jump nozzle, 18 updraft, 19 steam cannon, 13 steam wall | Modes: jump, updraft, cannon, wall (pushes back) |
| 6 | Pendel (pendulum) | 15 | Timing hazard that knocks the player away |

  Not chosen: 4 pressure plate, 9 extending bridge, 16 swing bridge (these two can still be built as a horizontal lift platform or a standing-axis rotating platform). The shapes are greybox stand-ins built from Prototype Bits primitives; the gate may use the kit's Door pieces. The steampunk models come in Phase 10.
- **D-17:** Lever and valve: **toggle** on each hit. Timed puzzles use the energy core, the crank or a timer node.
- **D-18:** Moving mechanisms (rotating platform, lift platform, conveyor, nozzle, pendulum): **behaviour set per instance** in the editor: either "signal on = runs, off = stops" or "always runs, the signal reverses the direction". Lift platform: signal on = at point B, off = back at A.
- **D-19:** Zahnrad-Tor: **signal on = open, off = closed.** It rolls aside quickly (about 0.3 s). With an energy core or a timer in front of it, it becomes a timed gate. It never closes on the player (it waits or stays open while the player overlaps it).
- **D-20:** Dampfdüse and player momentum: the nozzle **sets the velocity along its own direction** (reliable height and distance every time) and **keeps the player's sideways momentum**. Dash and further jumps stay available afterwards (Phase 2 rules). This must sit cleanly with the Phase 2 movement code. It is a core-value touch point.
- **D-21:** Pendulum: on contact it gives the player a **strong knock-back** in its swing direction and may throw them off a platform. No damage until Phase 6 (health, PROG-03).
- **D-22:** All moving parts that carry the player (rotating platform, lift platform, conveyor) carry them **without sliding, jitter or launching** (MECH-03, ROADMAP criterion 4). Build on the existing platform carry in `PlayerController`.

### Logic wiring
- **D-23:** AND, OR and timer are invisible logic nodes wired by signals in the editor (MECH-02). They do not count among the 6 mechanisms.

### Module framework
- **D-24:** The framework follows `.planning/research/ARCHITECTURE.md` Pattern 4 (`HandModuleDef` resource + `HandModule` behaviour scene + registry; adding a module = one folder + one registry line). A dummy test module proves criterion 5. The arm mesh never changes.
- **D-25:** The pulse hit carries enough data for Phase 6 to attach damage without rewriting the module: pulse size (small/big), hit point, direction, and the hit collider. Enemies and props in Phase 6 become more targets of the same pulse.

### Gym rooms
- **D-26:** The **existing gym** (`attimo/scenes/test/movement_gym.tscn`, the main scene) is extended with a **door** into the new area. Everything stays in one scene and one walk, with no level loading.
- **D-27:** **Room 2 = showcase:** every trigger and every mechanism (and every Dampfdüse mode and rotating-platform axis) stands on its own station, wired to a trigger, so it can be tried and tuned.
- **D-28:** After the showcase come **several puzzle rooms** that together **cover all mechanisms** and the AND, OR and timer logic, as well as near contact and the big pulse. At least one of them is solved with the pulse (ROADMAP criterion 3).
- **D-29:** Built from Prototype Bits, on the 1 m grid with 2 m / 4 m modules (same reference geometry as the movement gym).

### Planning size
- **D-30:** Keep the plan count inside the GSD granularity band (project granularity is `standard`: 3-5 plans per phase). Do not split work into many small plans; group related work (for example all triggers + logic in one plan, all moving mechanisms in one). Phases 2 and 3 ended with 14 and 10 plans; the developer wants fewer. This applies to every phase from now on, not only Phase 4.

### Claude's Discretion
- Number and layout of the puzzle rooms (about 3 is a reasonable start), as long as together they cover every mechanism and logic node.
- Exact numbers: assist angle and hysteresis, slowdown factor, pulse flash duration, glow intensities per stage, door/gate speed, nozzle forces per mode, pendulum knock-back, crank wind-up ratio, energy-core duration (all tunable, exposed in the F2 panel where it fits).
- Exact range at which near contact is offered, and whether near contact also works while aiming.
- Arm-out pose for the shot and near contact (reuse the Phase 3 aim pose `Ranged_1H_Aiming` + `AimPoseModifier` where it fits; Phase 5 ART-04 builds the dedicated hand poses).
- Visual shape of the pulse streak (a short line or mesh flash; no particles).
- Dummy test module behaviour (anything trivial that proves the folder + registry path).
- Whether the toggle-on-hit lever and valve also offer a "stays on" option per instance.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and requirements
- `.planning/ROADMAP.md` §Phase 4 — goal, success criteria, notes (wording updates listed under Phase Boundary above)
- `.planning/REQUIREMENTS.md` — HAND-01, HAND-02, HAND-03, CAM-04, CAM-05, MECH-01, MECH-02, MECH-03; SHOOT-01 (Phase 6 wording)
- `.planning/PROJECT.md` — the arm always looks the same; modules are pure abilities

### Architecture and design research
- `.planning/research/ARCHITECTURE.md` — HandController, HandModule/HandModuleDef (Pattern 4), Targeting, Interactable contract, folder layout `hand/modules/<name>/`
- `.planning/research/FEATURES.md` §C, §D, §E — interactable glow rules, aim assist sketch, module framework, mechanism base class + signal graph, checkpoint/reset notes
- `.planning/research/GAME-FEEL.md` — feel targets that the nozzle and moving platforms must not break
- `.planning/research/PITFALLS.md` — moving platform and physics pitfalls

### Prior phase decisions
- `.planning/phases/03-animated-mannequin-aim-mode/03-CONTEXT.md` — aim mode (D-09 to D-15), crosshair reserved lock state, no dash while aiming (D-12 amended)
- `.planning/phases/02-movement-core-follow-camera/02-CONTEXT.md` — movement rules, camera rig additive sources (D-18)
- `docs/CONVENTIONS.md`, `docs/ANIMATION-MAP.md`, `docs/MOVEMENT-METRICS.md` — project conventions, clip map, movement metrics

### Look
- `docs/reference/World Look.png` — steampunk floating-island reference the mechanism list was picked against (turquoise energy cores, gears, pistons, chains, steam)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `attimo/scripts/ui/crosshair.gd` + `attimo/scenes/ui/crosshair.tscn`: code-drawn dot + ring, shown on `EventBus.aim_changed`, `set_locked()` and `lock_color` reserved for Phase 4. Extend it into the goggle HUD (D-13).
- `attimo/scripts/gym/moving_platform.gd` + `attimo/scenes/proto/moving_platform.tscn`: `AnimatableBody3D` with `sync_to_physics`. Starting point for the lift and rotating platforms.
- `attimo/scripts/player/aim_pose_modifier.gd`: points the right arm at the crosshair. Reuse for the arm-out on shot and near contact.
- `attimo/autoload/event_bus.gd`: global fact bus (FEEL-01). New facts (pulse fired, interactable triggered, mechanism changed) go here so Phase 11/12 juice needs no gameplay edits.
- `attimo/scripts/debug/tuning_panel.gd` (F2): expose the new tunables here.
- `attimo/scripts/core/physics_layers.gd`: add an Interactable layer here.
- Prototype Bits in `attimo/assets/prototype_bits/`. More pieces (Door_A/B, Primitive_Doorway, Pillar, Stairs, Cube, target pieces) are in `KayKit/KayKit_Prototype_Bits_1.1_FREE/` and are copied in only when used (CLAUDE.md asset rule).

### Established Patterns
- Typed GDScript everywhere (`untyped_declaration` is a warning-as-error).
- Movement FSM is the source of truth; `MannequinAnimator` reads it. The hand must not take over movement state.
- Gameplay emits facts on `EventBus`; presentation listens (FEEL-01).
- Input actions already defined: `aim` (RMB), `use_hand` (LMB), `interact` (E), `module_next`/`module_prev`.

### Integration Points
- `PlayerController` already handles platform carry by hand (`platform_on_leave = DO_NOTHING`, `_last_platform_velocity`, `_leave_floor`). Rotating and lift platforms and the conveyor must work with it (D-22). The Dampfdüse (D-20) and pendulum knock-back (D-21) need a clean velocity-override/impulse entry point on the player.
- `CameraRig` additive sources: the aim-assist slowdown changes the mouse sensitivity, not the camera position.
- `movement_gym.tscn` is the main scene; the new door and rooms attach to it (D-26).

</code_context>

<specifics>
## Specific Ideas

- "Kurzer Tap ein kleiner Puls-Schuss, und wenn ich kurz halte, größerer Schuss. Nie Strahl."
- Aim is like putting the **goggles** on: the world highlight gets stronger and the minimal HUD appears. The character has goggles in `Character_Look.png`.
- HUD style: "sehr minimalistisches HUD, nur weiße Striche, vielleicht Goggles-Umrandung an den Seiten."
- Near contact: "der Arm leuchtet und die Handfläche pulsiert und leuchtet, Iron-Man-Vibe."
- Hand energy: "Blitz, Energie soll gezeigt werden."
- Mockups shown during discussion: target looks A/B/C and the goggle HUD (scratchpad screenshots, see DISCUSSION-LOG).

</specifics>

<deferred>
## Deferred Ideas

- **Full goggle look on aim** (vignette, edge tint, a "goggles down" moment): Phase 11 (Movement & Camera Juice). Phase 4 only has the glow stages and the minimal HUD lines.
- **Particles for the hand** (palm sparks, repulsor particles on near contact, pulse impact): Phase 12 (Hand & Combat Juice).
- **Pulse vs. enemies and props** (damage, small vs. big pulse damage): Phase 6. The hit data is prepared by D-25.
- **Module icon in the HUD frame**: Phase 5 (module pickup).
- **Pendulum damage**: Phase 6 (health).
- Mechanism ideas not picked: pressure plate (4), extending bridge (9), swing bridge (16).

</deferred>

---

*Phase: 04-fernausl-ser-mechanism-kit*
*Context gathered: 2026-11-20*
