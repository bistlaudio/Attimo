# Game Feel and Juice: Science and Practice for Attimo

**Domain:** 3D third-person action-platformer, Godot 4.7.x, KayKit `Rig_Medium` rigid segmented chibi hero, prosthetic hand with ability modules (Modul 1 Fernausloeser beam, Modul 2 Pull/Push)
**Researched:** 2026-11-02
**Overall confidence:** MEDIUM (the research findings are solid; most numeric values are starting values from practice and must be tuned by playtest)
**Scope note:** Sound is deliberately last. Every cue below has an empty `sfx_id` slot that the audio phase fills later, without touching gameplay code. This file does not repeat movement numbers (coyote, buffer, gravity) or camera-jitter prevention. See FEATURES.md and PITFALLS.md for those.

Confidence tags used below: HIGH = verified this session from primary or official text; MEDIUM = verified in secondary sources, or widely documented and consistent with several sources; LOW = single blog, forum post or recollection. All numeric values in the catalogue are STARTING VALUES, not findings.

---

## 1. Position in five lines

1. Juice is not decoration on top of movement. For a platformer whose Core Value is "fluid, fast movement", perceived responsiveness is made of input latency, animation response, camera behaviour and impact feedback together (Swink). Treat it as a system with an owner, a data format and a test method.
2. The evidence says "medium to high" juice is best. No juice and extreme juice both scored worse than medium and high on play time, player experience, intrinsic motivation and performance (Kao 2020, N = 3018). So build a switchable amount, default to "high" as defined here, and never let the catalogue drift to "extreme".
3. Build the hook system first (FeelService, FeelCue data, FeelSettings with a global on/off), then layer cues per phase, then run one dedicated Feel Pass before audio. Do not leave juice for the end only, because it changes how movement and camera numbers must be tuned.
4. The KayKit clip set lacks sprint, double jump, air dash, aim stance, pull and push. Procedural body motion (squash/stretch springs, lean, VFX) is therefore not only polish. It carries part of the missing animation, and that is why it belongs in the movement phase.
5. Measure, do not argue. Every cue is toggleable per channel, the whole layer can be switched off, and a within-subject A/B protocol (Section 7) produces numbers a uni report can use.

---

## 2. Principles with sources

| # | Principle | Source | Meaning for Attimo | Confidence |
|---|-----------|--------|--------------------|------------|
| P1 | Game feel is the tactile sensation of controlling a virtual object. Foundations are real-time control and simulated space; polish and metaphor sit on top. Swink names six areas: input, response, context, polish, metaphor, rules. | Swink, *Game Feel* (2008); Game Developer feature "Game Feel: The Secret Ingredient" | Sign off raw movement and camera WITHOUT juice first (Phase 2 gate). Juice then amplifies a base that already works; it cannot rescue bad control. | HIGH (existence and structure); the three-block wording varies by secondary source |
| P2 | Input-to-response latency should stay under about 100 ms for comfortable real-time control. Secondary sources cite tiers around 50 / 100 / 240 ms. | Swink (pp. ~34-35) as cited in a Rutgers lecture deck; agent-skills page for tiers | Budget in Section 7: target <= 66 ms button-to-photon for jump, hard limit 100 ms. The first visible reaction (pose change or dust) must land on the same frame as the state change. | MEDIUM for 100 ms; LOW for 50/240 tiers (unconfirmed in the book) |
| P3 | Forgiveness is mostly invisible. Celeste uses coyote time, jump buffering, halved gravity at the jump apex when jump is held, jump corner correction, dash corner correction, lift-momentum storage after leaving a moving platform, and wider wall-jump windows. Thorson's intent: "it wants you to succeed". | Thorson Celeste thread (Mar 2020) and the "Celeste & Forgiveness" article (numeric values NOT given there) | Apply the same attitude to the hand: trigger input buffer, aim magnetism with hysteresis, momentum carry after platform exit and after pull release. Forgiveness is not juice but it is the largest single contributor to "feel". | HIGH for the list; frame values LOW (sources conflict; one third-party site says 5-6 frames coyote) |
| P4 | Derive jumps from design numbers (height, time to apex) and use separate gravity for rise and fall. Swink is cited for Mario's gravity roughly tripling after the apex. Physically exact jumps are a design choice, not a requirement. | Pittman, GDC 2016 "Math for Game Programmers: Building a Better Jump" | Already covered in PITFALLS 2. Add an "apex hang" option: gravity x 0.5 while jump is held and |vy| is small (Celeste-style). It reads as air-control feel more than as animation. | HIGH (talk exists, summary matches); exact Mario factor MEDIUM |
| P5 | Juice means abundant, proportional feedback to every player action: the same game with layers of tweens, particles, camera motion and sound feels dramatically better without a mechanic change. | Jonasson and Purho, "Juice it or lose it" (Nordic Game / GDC Europe 2012), Breakout demo | Every verb in the Section 4 table gets a cue. Added in layers and compared, not all at once. | MEDIUM-HIGH (well-known talk; not re-fetched this session) |
| P6 | Work incrementally: add one feedback element at a time (camera kick, screen shake, hit pause, muzzle flash, bigger effects, permanence of debris), judge each, keep what improves the feel. | Nijman (Vlambeer), "The Art of Screenshake" (2013) | Each cue is one data row with its own toggle. A/B per channel is possible by design (Section 7). | HIGH (talk exists, widely referenced); the exact item list is from memory |
| P7 | Screen shake should be a bounded, decaying value ("trauma", 0..1) with shake = trauma squared (or cubed), driven by smooth noise, not random per frame. | Eiserloh, GDC 2016 "Math for Game Programmers: Juicing Your Cameras With Math" | Section 6 camera code. Caution for 3D third-person: keep rotation amplitudes small and roll off by default. | HIGH (talk exists); trauma^2 and noise recalled from the talk, widely reproduced in Godot tutorials |
| P8 | Hit-stop is a micro-freeze (tens of ms up to about 150 ms) reserved for impact and reward moments. Typical tutorial values: 40-80 ms light, 100-180 ms heavy; Celeste freezes about 50 ms on dash start (from its Player.cs constants, recalled). | Godot community tutorials (forum "Hit-stop and screen shake in Godot 4", uhiyama-lab); Celeste source (recalled) | Use hit-stop only for damage, boss hit, pickup, phase change. Not for landings or normal movement, where a freeze reads as lag. | MEDIUM (tutorials verified) / LOW (Celeste constant) |
| P9 | Squash and stretch, anticipation, follow-through and overlap, slow in/slow out, exaggeration are the animation principles that read as "life". | Thomas and Johnston, *The Illusion of Life* (1981) | Rigid segmented chibi characters take whole-body squash well. Anticipation conflicts with responsiveness, so compress it to at most 2 frames or replace it with an effect. | HIGH |
| P10 | Visual embellishments are design elements that support information already conveyed elsewhere. They reliably raise visual appeal; competence effects appear only in specific circumstances. | Hicks, Gerling, Dickinson, Vanden Abeele, "Juicy Game Design", CHI PLAY 2019, pp. 185-197 | Split feedback into informational (never switched off: reticle states, cooldown ready, damage indication, interactable highlight) and embellishment (scaled by FeelSettings). Juice OFF must remain fully playable. | HIGH for bibliographic facts and abstract; details of the study unconfirmed (PDF not retrievable) |
| P11 | Amount matters. Four otherwise identical action-RPG versions (none / medium / high / extreme juiciness), N = 3018: none and extreme both gave significantly lower play time, player experience, intrinsic motivation and performance than medium and high. | Kao, "The effects of juiciness in an action RPG", Entertainment Computing 34, 2020, DOI 10.1016/j.entcom.2020.100359 | Default preset "HIGH" = catalogue values. "MEDIUM" = x0.6. "EXTREME" (x1.8) exists only for the comparison study, never as a shipped option. | HIGH for design and headline result (abstract confirmed); effect sizes not read |
| P12 | Follow-up: juice that depends on the player's success enhanced all measured motives, while uniformly amplified juice reduced them, possibly through a weaker sense of agency. | Kao et al., CHI 2024 (n = 1,699), reported by search summary | Make cues contingent on successful, player-caused events (hit confirmed, anchor attached), not on timers or idle ambience. Proportional to input, not random. | MEDIUM-LOW (secondary summary only) |
| P13 | Hierarchy and contrast: if every action is loud, nothing is. Reserve the biggest cues (long hit-stop, big trauma, slow-mo) for rare moments. | Derived from P11 plus practitioner consensus | Tier system in Section 4.1 with hard caps per tier. | MEDIUM (derived) |
| P14 | Motion safety. Strong FOV change, roll, lag and constant shake cause discomfort. | PITFALLS 5 (practitioner heuristics); Simulator Sickness Questionnaire (Kennedy 1993) for measurement | FOV kicks are impulses that return, total additive FOV change <= +12 degrees, roll off by default, "Reduce motion" setting. | MEDIUM |
| P15 | Platformer toolkits show feel as a set of adjustable parameters (acceleration, jump shape, coyote time, camera behaviour). | Mark Brown, GMTK "Platformer Toolkit" (2021) | Keep every feel number in an inspector-editable Resource and expose a live debug panel. | MEDIUM (existence confirmed; no numbers used) |
| P16 | Reference games: Mario 64 / Odyssey (speed-reactive lean, skid turns, hat/cappy-driven motion), Hollow Knight (hit freeze, recoil, flash, particles on confirmed hits, grace window around 5 frames reported), Astro Bot (momentum and weight, reactive environment). | General knowledge plus blog/review summaries | Pattern sources only. No source found with quantified values; do not cite their numbers as fact. | LOW |

**Not verified this session (state honestly in the report):** a GMTK video specifically on 3D platformer cameras was not found; no authoritative analysis of Astro Bot or Odyssey feel numbers was found; Nijman's and Jonasson/Purho's talk contents were not re-read; Hicks et al. study details (conditions, effect sizes) were not retrievable.

---

## 3. Design rules distilled for Attimo

1. **Gameplay emits facts, juice listens.** Gameplay code never calls particles, shake or tweens. It emits `landed(impact_speed)`, `dash_started(dir, in_air)` and so on. Switching juice off is then a matter of disconnecting listeners (FEEL-01, FEEL-05).
2. **Never delay control for feedback.** No jump squat before leaving the ground, no hit-stop on the player's own movement, no landing lock. Hit-stop and slow-mo may freeze the world, but buffered input stays valid through them.
3. **Reaction within one frame, full effect later.** The beam hits, the target shudders on the very next frame (FEATURES C), the bigger motion follows after the 0.1 s anticipation. Cause-to-effect clarity beats spectacle.
4. **Proportional to impact.** Landing scales with fall speed, shake with distance, FOV with speed. Continuous mapping instead of on/off keeps the world feeling physical.
5. **Colour discipline for juice.** Movement feedback (dust, steam, trails, rings) uses cream / warm white / amber. Turquoise appears only for hand and interactable feedback (resolves the turquoise rule in FEATURES/PITFALLS). Open question for Phase 1: arm-core glow on the player (see Section 9).
6. **Camera juice is additive and bounded.** One owner (CameraRig) sums all channels in fixed order and clamps.
7. **Informational feedback is never optional.** Juice OFF keeps reticle states, cooldown ready, damage indication, highlight.
8. **One time owner.** Exactly one autoload may write `Engine.time_scale`.
9. **Calibrate before audio, expect to recalibrate after.** Sound strongly changes perceived impact. Keep initial hit-stop and trauma on the conservative side of "high" and schedule a half-day retune after the audio phase.

---

## 4. Juice catalogue (starting values)

Assumptions: physics at 60 ticks/s (1 frame = 16.7 ms), hero about 1.2 m tall (PITFALLS 11), base FOV 75 degrees, run about 7 m/s, sprint about 10-11 m/s. Replace with the real movement-metrics table once it exists. "S" means spring displacement (Section 6.4). Preset scale: OFF 0, MEDIUM 0.6, HIGH 1.0 (these numbers), EXTREME 1.8 (study only).

### 4.1 Tier system (calibration anchor)

| Tier | Meaning | Examples | Trauma | Hit-stop | FOV impulse | Particle cap (live) | Body squash/stretch |
|------|---------|----------|--------|----------|-------------|---------------------|---------------------|
| T0 | Constant micro feedback | footsteps, sprint lean, idle glow | 0 | 0 | 0 | 4 | 0 to 0.05 |
| T1 | Small action | jump, small land, aim, small pickup | 0 to 0.1 | 0 | up to 2 deg | 10 | up to 0.15 |
| T2 | Medium action | dash, double jump, beam fire, mechanism, push | 0.1 to 0.3 | 0 to 0.04 s | up to 6 deg | 25 | up to 0.25 |
| T3 | Big moment | damage, boss hit, module pickup, pull impact | 0.3 to 0.6 | 0.06 to 0.2 s | up to 8 deg | 45 | up to 0.30 |
| T4 | Rare climax | death, boss phase change, boss defeated | 0.6 to 0.9 | 0.12 to 0.3 s plus optional slow-mo | up to 10 deg | 60 | up to 0.35 |

Global caps (do not exceed even with stacking): trauma 1.0, additive FOV +12 degrees, concurrent hit-stop 1 (longer wins), live juice particles about 120, same cue minimum interval 50 ms.

### 4.2 Movement

Scale rule for squash: `s` is the vertical displacement of the VisualRoot scale (y = 1 + s, xz = 1 / sqrt(1 + s), volume preserved). Positive = stretch, negative = squash.

| Action | Tier | Body / animation | Camera | VFX | Time | UI |
|--------|------|------------------|--------|-----|------|----|
| **Jump** | T1 | Launch stretch S +0.15, spring 3.5 Hz, zeta 0.45; clip `Jump_Start` blended in 0.05 s; no anticipation frames. Early release (jump cut): no extra feedback. | none (vertical damping already handles it) | Dust puff at feet: 6 particles, life 0.30 s, size 0.25 to 0.5 m, cream, `smoke` sprite | none | none |
| **Double jump** | T2 | Stretch S +0.25; procedural forward flip 360 degrees over 0.35 s on VisualRoot (no clip exists); arm cores flash 1.0 to 2.5 to 1.0 in 0.2 s | FOV impulse +2 deg in 0.1 s, return 0.3 s | Steam ring under feet: flat ring mesh 0.3 to 1.2 m in 0.25 s, alpha 0.6 to 0; 10 steam particles in a downward cone, life 0.35 s. The ring doubles as the readable "second jump spent" signal. | none | none |
| **Land** | T0 to T2 by impact | Impact scale `t = clamp((v_impact - 4) / (20 - 4), 0, 1)` (v in m/s). Squash S = -(0.06 + 0.22 t), spring 3.5 Hz, zeta 0.45. Soft (<6 m/s): clip `Jump_Land` blended 0.04 s, skippable if move input is held (no landing lock, ever). | Camera dip 0.04 + 0.08 t m, recovery 0.2 s; trauma 0.3 t^2 only above t = 0.5 | Dust ring: 3 + 11 t particles, radius 0.4 to 1.2 m; hard landing adds 4 steam wisps | none | none |
| **Run start / skid turn** | T0 to T1 | Reverse input at > 60 % of max speed: lean back 15 degrees, 0.15 s, skid dust | none | skid dust 6 particles, life 0.25 s | none | none |
| **Sprint** | T0 sustained | Forward lean 8 to 12 degrees proportional to speed (VisualRoot pitch, smoothed 0.15 s); `Running_B` speed_scale = ground_speed / clip_ref_speed (limit +/-15 %); arm core emission x1.0 to x1.6 | FOV +5 deg ramp over 0.25 s in, 0.4 s out; camera distance +0.3 m smoothed 0.4 s; no bob, no shake | 2 foot-dust particles per step; optional screen-edge speed streaks alpha 0 to 0.25 at >= 90 % sprint speed | none | speed streaks (optional) |
| **Dash (ground)** | T2 | `Dodge_Forward` retimed to dash duration (about 0.18 to 0.22 s); lean 20 degrees forward; stretch S +0.15 in 2 frames, return 0.2 s | FOV +6 deg in 0.06 s, hold for the dash, return 0.25 s; camera follow lag +0.2 m behind for 0.3 s; trauma 0 | Steam vent burst opposite to travel: 10 particles; ribbon trail from `handslot.r` and feet, life 0.2 s; ground streak decal 0.3 s | Optional dash-start freeze 0.03 s (2 frames), default OFF, A/B it (Celeste uses about 0.05 s, LOW) | Dash-ready indicator on arm cores: spent = 0.3 emission, refill = flash 0.15 s |
| **Air dash** | T2 | Same as dash plus held `Dodge_Forward` pose; stretch S +0.2; shockwave ring at origin (0.2 s) | FOV +8 deg impulse (this is the largest movement impulse) | As dash plus ring | none | Arm cores stay dim until landing, then refill flash (readability of "air dash available") |

### 4.3 Hand, aim and modules

| Action | Tier | Body / animation | Camera | VFX | Time | UI |
|--------|------|------------------|--------|-----|------|----|
| **Aim enter** | T1 | Single `aim_blend` 0 to 1 in 0.15 s (ease-out cubic); character yaw to camera yaw in 0.1 s; upper-body layer from `Ranged_Magic_Raise` / `Ranged_1H_Aiming`; arm cores 1.0 to 2.0 in 0.15 s | FOV -8 deg (75 to 67) with the blend, shoulder offset 0.6 m, aim sensitivity x0.7 | small charge ring at hand, 0.15 s | none (no slow-mo in aim) | Reticle fades in with scale 1.4 to 1.0 in 0.12 s |
| **Aim exit** | T1 | Reverse blend 0.2 s (quick in, easy out) | FOV returns with blend | none | none | Reticle fades 0.1 s |
| **Reticle states** (informational, never off) | T1 | n/a | n/a | n/a | n/a | idle: thin ring, 40 % alpha. Valid target: ring closes 1.0 to 0.7 in 0.1 s, tick marks rotate 90 degrees in 0.3 s. Locked: filled dot plus brackets pop 1.3 to 1.0. Invalid / out of range: dim plus 2 px shake 0.1 s |
| **Beam fire (Modul 1)** | T2 | Arm pump: `upperarm.r` pitch back 6 degrees in 0.05 s, return 0.15 s (SkeletonModifier3D); base clip `Ranged_Magic_Shoot` or `Use_Item` | Kick back 0.03 m (spring), trauma 0.08 | Muzzle flash at `handslot.r`: 2 frames (0.08 s). Beam: width 0.14 to 0.05 m in 0.1 s, HDR brightness 3 to 1.5, noise texture scroll 6 m/s; full length visible in the first frame; sustain 0.25 s, fade 0.1 s. Impact: 8 sparks, ring 0.3 to 0.8 m in 0.2 s. Target: shudder +/-2.5 degrees (spring 6 Hz, zeta 0.3) starting on the next frame; core emission 4 to base over 0.25 s. | none | Reticle expands 1.0 to 1.25 and back in 0.12 s; module icon cooldown sweep |
| **Pull start (Modul 2)** | T2 | Hook flight <= 0.08 s (about 250-300 m/s visual); rope with sine ripple, amplitude 0.25 m decaying over 0.25 s; body aligns to travel direction (slerp 0.1 s); stretch S +0.15 along motion; arm extended (hold last frame of `Throw`) | FOV +4 deg snap in 0.06 s, then speed-proportional up to +10 total; look-ahead 0.3 x velocity, clamp 2 m, smoothed 0.2 s; trauma 0.1 at hook impact | Hook impact: 10 sparks plus ring; amber / brass colour family to separate from the turquoise beam | optional 0.03 s attach freeze, default OFF | Anchor ring contracts onto the reticle |
| **Pull in flight** | T1 sustained | Legs trail (`Jump_Idle`-style pose); rope tension: width 0.04 to 0.02 m, brighter as it tightens | FOV follows speed; no roll | Wind streaks alpha proportional to speed; screen-edge streaks as sprint | none | none |
| **Pull release / arrival** | T2 to T3 | Stretch pop S +0.2 then spring settle; if jump pressed within the release window: extra stretch +0.1 | FOV decays over 0.4 s (not instant: the camera tells the player "you still have momentum"); trauma 0.15 only on surface impact above 12 m/s | Steam burst at hand: 12 particles; rope retracts in 0.12 s | none | cooldown sweep |
| **Push / steam (Modul 2)** | T2 | Arm thrust (first 6 frames of `Throw`), arm kick 8 degrees; if self-push: lean back 6 degrees | Kick back 0.15 m (spring), trauma 0.25, FOV +3 deg pulse 0.08 s | Steam cone: 30 to 50 particles, life 0.45 s, speed 12 to 3 m/s, half-angle 20 degrees (`wispy_smoke` flipbook); pressure ring 0.5 to 3 m in 0.2 s; dust where the cone meets floor | hit-stop 0.04 s only when a pushable is hit | Reticle pulse |
| **Mechanism activated** | T2 | Target anticipation 0.1 s shudder (+/-1.5 degrees or 0.02 m) so cause-effect is visible within a frame, then main motion with back-ease overshoot | trauma 0.1 to 0.3 attenuated with distance (full <= 8 m, zero at 30 m); only for large mechanisms (doors, bridges, big gears) | Steam puff 10 to 20; "energy pulse" travels along turquoise pipes from source to target at about 15 m/s (UV scroll plus emission); state lamp turns from turquoise (dormant) to warm steady (active) per PITFALLS 6 | none (0.03 s for a heavy clunk is optional) | If target off-screen: edge arrow 1.0 s (alternative to a cinematic camera cut, which is an anti-feature) |

### 4.4 Pickups, damage, boss, death

| Action | Tier | Body / animation | Camera | VFX | Time | UI |
|--------|------|------------------|--------|-----|------|----|
| **Small pickup** | T1 | none | none | Magnet pull from 2.5 m, fly 0.25 s accelerating; scale pop 1 to 1.3 to 0; 6 sparkles | none | Counter bump 1.0 to 1.25 spring 0.2 s |
| **Module pickup** (HAND-05) | T3 | `PickUp` clip; arm cores flash white-hot 0.3 s; part flies to `handslot.r` on a curved path in 0.35 s | FOV -5 deg punch-in 0.3 s, back over 0.6 s; trauma 0.15 (celebration, little shake) | Ring burst plus 16 sparkles, warm vignette 0.4 s | freeze: `time_scale` 0.05 for 0.20 s, or 0.2 for 0.5 s eased (A/B) | Icon pop 0 to 1.4 to 1.0 in 0.35 s (back ease), glow held 1.5 s; first-use prompt after 0.8 s; no cutscene |
| **Checkpoint activated** | T2 | none | none | Lamp ignites, ring 1 to 4 m in 0.4 s, 16 sparkles | none | tiny icon 1.0 s |
| **Damage taken** | T3 | `Hit_A` / `Hit_B`; white-hot flash 0.1 s via shared `flash` shader uniform (1 to 0); knockback 6 to 8 m/s away from source; control lock at most 0.15 s, then full air control; i-frames 1.0 s with 10 Hz blink at 50 % alpha | Trauma 0.5; FOV -4 deg punch-in 0.08 s | 8 cog / spark shards; warm vignette pulse alpha 0.35 to 0 in 0.3 s | hit-stop 0.08 s | Health pip shakes 0.3 s |
| **Boss hit (weak point)** | T3 | Boss rigid parts: displacement 0.15 m, rotate 5 degrees, spring 4 Hz, zeta 0.3; white flash 0.1 s | Trauma 0.4; kick 0.2 m toward the boss; FOV -3 deg 0.1 s | 20 sparks plus ring; core emission 4 to 0 over 0.4 s | hit-stop 0.08 s light, 0.14 s core destroyed (trauma 0.7) | Core pip pops |
| **Boss phase change / defeat** | T4 | Boss telegraph pose, then rigid-part burst | Trauma 0.8 with slow rumble | 30 debris pieces (cap 60), steam | `time_scale` 0.3 for 0.5 s eased in/out | none |
| **Death** | T4 | Skip long `Death_A`. Hide hero, burst into 8 to 12 cog pieces (mesh particles) plus 20 steam | Hit-stop 0.12 s, trauma 0.5, freeze follow for 0.4 s, FOV -6 deg | cog burst | hit-stop 0.12 s | Iris / wipe out 0.2 s, hold 0.1 s |
| **Respawn** | T2 | `Spawn_Ground` or `Spawn_Air` at checkpoint; scale pop 0.8 to 1.1 to 1.0 over 0.25 s | Camera repositioned and `reset_physics_interpolation()` called, fade-in 0.15 s, trauma 0 | steam puff 15, checkpoint lamp pulse | none | wipe in 0.2 s |

**Respawn timeline budget:** fatal event to controllable <= 1.0 s (FEATURES I says about 1 s). Control returns 0.25 s after the player is placed.

**Kill-plane fall:** no trauma, fast fade 0.15 s, same respawn path.

---

## 5. Momentum and grapple feel (Modul 2)

Evidence base for this section is thin and mostly practitioner or community material (LOW). Treat everything as a prototype hypothesis and put the pull into a dedicated test room early.

**Design choice: zip with carry-over, not pendulum swing.** The brief says "pull yourself toward a point with momentum carry-over like a grapple". A community post on a physical swing model reports it was "too busy and confused people" in playtests (LOW). A zip is readable, deterministic and easy to gate in level design. Swinging can be an optional later mode; do not build it in the slice.

| Parameter | Starting value | Reason / note |
|-----------|----------------|---------------|
| Aim target class | `anchor`, a separate Interactable type | Distinct highlight and reticle state |
| Max range | 25 m | Test: reads as "far enough to matter" |
| Aim assist (acquire / release) | 6 deg / 10 deg (beam: 4 / 7 deg) | Anchors are rare and high-stakes, so wider tolerance; keeps hysteresis from PITFALLS 6 |
| Targeting volume | SphereCast radius about 0.4 m | Avoids pixel-precision aiming |
| Hook flight | <= 0.08 s | Visible causality without feeling delayed |
| Pull start speed | first tick: at least 8 m/s toward the anchor | Response within one tick |
| Pull acceleration | 45 m/s^2 (range 40-60) | Ramp, then cap |
| Max pull speed | 20 m/s (about 1.8 x sprint) | Speed is the fun; cap keeps camera and collisions sane |
| Gravity during pull | x0.5 | Pull reads as a deliberate path |
| Arrival | distance < 1.5 m or release input | Keeps velocity |
| Carry-over | keep full velocity; horizontal speed above sprint cap decays at 6-10 m/s^2; vertical clamped to +12 m/s | The "momentum" feeling is the decay, not instant clamping |
| Post-release gravity | x0.5 for 0.25 s ("hang time") | Same idea as Celeste apex hang; eases landing on the target ledge |
| Release boost | jump pressed within 0.12 s after release adds 4 m/s along velocity plus normal jump impulse | Rewards timing; the 0.12 s window doubles as forgiveness |
| Air dash refund | pull attach refunds the air dash | Fuses movement and hand (Core Value); chain pull, dash, pull |
| Air control while carrying | 50 % of normal for 0.3 s after release, then 100 % | Prevents the player cancelling momentum by accident |
| Camera | FOV up to +10 deg with speed, look-ahead 0.3 x v (clamp 2 m), no automatic yaw | Camera never steers for the player (nausea) |

**Push (steam).** Two uses are plausible and the phase must pick one first: (a) push objects and mechanisms (low risk), (b) self-push as a blast-jump from surfaces (high feel potential, high balance risk). Starting values if (b) is chosen: aim at floor or wall within 4 m, impulse 12 m/s along the surface normal, cooldown 0.6 s, same carry-over rules as pull.

**Momentum test room (checklist):**
- Pull from standing at 5, 10, 20 m. Record time to full speed and exit speed. Target: exit speed within 10 % of the cap.
- Pull to a ledge above the player: can the player land on it from release without extra input? The result sets level gates.
- Pull then jump within window: height gain should be roughly +25 % over a normal jump (starting guess; tune).
- Pull into a wall at max speed: no tunnelling, no stuck state, kill plane present.
- Camera test at 144 Hz and 10 TPS (PITFALLS 1).
- Fresh tester: can they explain what the pull does after 2 minutes without text?

---

## 6. Godot 4.7 implementation notes

### 6.1 Architecture hooks (FEEL-01, FEEL-05)

```
Gameplay (Player, Hand, Mechanisms, Boss, Pickups)
        | emits FACTS (local signals; world facts via EventBus)
        v
   FeelService (autoload)   <-- FeelSettings (Resource, ConfigFile-persisted)
        | looks up FeelCue (Resource) by id, scales by settings, dispatches
        v
   Sinks:  BodySink -> VisualRoot springs, SkeletonModifier3D
           CameraSink -> CameraRig (trauma, FOV kick, kick offset, dip)
           VfxSink -> pooled GPUParticles3D, trail ribbons, rings
           TimeSink -> hit-stop / slow-mo (sole writer of Engine.time_scale)
           UiSink -> reticle, HUD pops, vignette, wipe
           AudioSink -> (registered in the LAST phase; reads cue.sfx_id)
```

- This adds **one autoload** (`FeelService`) beyond the four in ARCHITECTURE.md (EventBus, GameState, SaveService, DebugOverlay). Justification: it must own `Engine.time_scale`, the global juice switch and the cue registry. If a fifth autoload is unacceptable, host these in `TimeFx` plus a `FeelDirector` node in the main scene.
- Facts to define up front (names are suggestions): `jumped(is_double)`, `landed(impact_speed, surface)`, `dash_started(dir, in_air)`, `dash_ended`, `sprint_changed(on)`, `aim_changed(on)`, `beam_fired(target)`, `beam_hit(target, point)`, `pull_started(anchor)`, `pull_released(velocity)`, `push_fired(origin, dir)`, `mechanism_activated(node)`, `module_picked_up(def)`, `checkpoint_reached`, `player_damaged(amount, dir)`, `boss_hit(weak_point, heavy)`, `boss_phase_changed`, `player_died`, `player_respawned`.
- Call site shape: `Feel.play(&"land", {intensity = t, position = global_position, normal = n})`. The player state machine emits a signal; a small `PlayerFeel` node translates it into `Feel.play`. Gameplay files contain no juice code.
- **FeelCue** (Resource, one `.tres` per cue, or one big table resource): `id`, `tier`, channel blocks (body: squash S, stretch, lean, spring freq / zeta; camera: trauma, fov_kick, kick, dip; vfx: scene, amount_ratio; time: hit_stop, freeze_scale, slow_mo; ui: animation id), `sfx_id` (empty until the audio phase), `min_interval`, `informational: bool`.
- **FeelSettings** (Resource, persisted): `preset` (OFF, MEDIUM, HIGH, EXTREME), `master`, per-channel gains (`body`, `shake`, `fov`, `particles`, `time`, `ui`, later `audio`), `reduce_motion` (shake 0, roll 0, FOV kicks x0.3, hit-stop x0.5). Informational cues ignore gains. Hotkeys for comparison: F6 cycle preset, hold F8 for instant OFF.
- Catalogue as data means retuning in the inspector, run-time panel in DebugOverlay, and no code edits during playtests.

### 6.2 Camera: additive layers and trauma shake (CAM, FEEL-04)

CameraRig is the single writer of `Camera3D.fov` and offsets. It sums, in fixed order: base FOV, aim blend, sprint (speed-proportional), dash / pull impulse springs, landing dip, trauma shake. Each channel clamped; total FOV change <= +12 degrees.

```gdscript
# camera_shake.gd, child of CameraRig (not of the interpolated body)
extends Node3D
@export var noise: FastNoiseLite            # simplex/perlin, frequency 1.0
@export var max_deg := Vector3(2.5, 2.5, 0.0)   # pitch, yaw, roll (roll off by default)
@export var max_offset := Vector2(0.10, 0.10)   # Camera3D h_offset / v_offset, metres
@export var decay := 1.6                    # trauma per second (1.0 to 2.5)
@export var noise_speed := 45.0
@onready var cam: Camera3D = %Camera3D
var trauma := 0.0
var _last_us := Time.get_ticks_usec()

func add_trauma(a: float) -> void:
    trauma = minf(1.0, trauma + a)          # a already scaled by FeelSettings

func _process(_d: float) -> void:
    var now := Time.get_ticks_usec()
    var dt := minf((now - _last_us) / 1e6, 0.05)   # REAL time: unaffected by hit-stop
    _last_us = now
    trauma = maxf(0.0, trauma - decay * dt)
    var s := trauma * trauma                # Eiserloh: trauma squared
    var t := now / 1e6 * noise_speed
    rotation_degrees = Vector3(
        max_deg.x * s * noise.get_noise_2d(0.0, t),
        max_deg.y * s * noise.get_noise_2d(100.0, t),
        max_deg.z * s * noise.get_noise_2d(200.0, t))
    cam.h_offset = max_offset.x * s * noise.get_noise_2d(300.0, t)
    cam.v_offset = max_offset.y * s * noise.get_noise_2d(400.0, t)
```

- Use `Camera3D.h_offset` / `v_offset` (frustum shift) for translation shake. It cannot push the lens into a wall, which the SpringArm3D rig exists to prevent.
- `physics_interpolation_mode = OFF` on the shake node: it is visual only and driven from `_process`. Verify with the 10-TPS test.
- **If Phantom Camera is adopted:** it drives the host Camera3D transform and may own FOV. The Phase 3 spike must also test "additive FOV impulse plus noise shake without fighting the addon". Phantom Camera ships noise features in recent versions (LOW, recalled; verify against v0.11.0.4). If the layering is awkward, the SpringArm3D fallback wins because juice needs a camera with a single clear additive stack.

### 6.3 Hit-stop and slow-mo (TimeSink)

```gdscript
# time_fx.gd, the ONLY writer of Engine.time_scale
extends Node
var _end_ms := 0
var _token := 0

func hit_stop(duration: float, freeze_scale := 0.05) -> void:
    duration *= FeelSettings.time_gain
    if duration <= 0.0: return
    var end := Time.get_ticks_msec() + int(duration * 1000.0)
    if Engine.time_scale < 1.0 and end <= _end_ms: return   # never shorten an active stop
    _end_ms = end
    Engine.time_scale = freeze_scale                         # assign, never multiply
    _token += 1
    var mine := _token
    await get_tree().create_timer(duration, true, false, true).timeout   # ignore_time_scale
    if mine == _token: Engine.time_scale = 1.0

func _exit_tree() -> void: Engine.time_scale = 1.0
```

Pitfalls (verified in two Godot 4 tutorials, one of them tested on 4.7-stable in the Compatibility renderer only):
- Without the fourth `create_timer` argument (`ignore_time_scale = true`) a 0.08 s wait lasts about 1.6 s at scale 0.05.
- Never multiply `time_scale` (overlapping hits compound to 0.0025). Assign it, and let the latest or longest stop win.
- Do not set 0. Use 0.02 to 0.05. One report says the collision code dislikes `time_scale = 0` (LOW), and the tutorial author recommends against 0.
- The restore logic must live in an autoload. If it lives in an enemy that is freed, the game stays in slow motion.
- `process_mode = ALWAYS` and CanvasLayer do not exempt nodes from `time_scale`. Tweens for UI need `tween.set_ignore_time_scale(true)`; world tweens (squash) should freeze, which is correct.
- Shake decay and flashes must use real time (see 6.2), otherwise they hang during the freeze.
- `AudioStreamPlayer` ignores `time_scale` (relevant for the audio phase); shader `TIME` is affected, so pass a real-time uniform if a shader must keep animating.
- Pause menu must reset `time_scale` and restore it on resume.
- **Open question, 30-minute spike in Phase 2:** the official `Engine` docs state that `time_scale` "does not automatically adjust `physics_ticks_per_second`". My understanding (MEDIUM-LOW, unconfirmed) is that physics ticks keep their real-time cadence while the delta passed to `_physics_process` is scaled, which would keep interpolation smooth during hit-stop. No source found on `time_scale` combined with physics interpolation. Test: hit-stop at 0.05 with Physics TPS = 10 and 144 Hz; look for stutter on player, camera and moving platforms.
- Coyote and jump-buffer timers decremented in `_physics_process` with the scaled delta stretch during a freeze. That favours the player and is acceptable. Raw input events keep arriving in real time.

### 6.4 Squash and stretch on rigid segmented KayKit characters

`Rig_Medium` has about 18 bones (root, hips, spine, chest, head, upperarm / lowerarm / wrist / hand L/R, upperleg / lowerleg / foot / toes L/R, plus `handslot.l/r`) and the mannequin is split into rigid meshes (Body, Head, ArmLeft, ArmRight, LegLeft, LegRight). Each mesh is rigid to one bone, so a bone scale scales the segment around its joint without skinning artefacts. Keep bone names as `@export var` StringNames, because the final Meshy hero may differ.

Three layers, cheapest first:

1. **VisualRoot (primary).** Node3D wrapper around the whole hero, pivot at the feet. Scale = (xz, y, xz) from a spring; yaw / pitch for lean, flip and travel alignment. Robust, rig-independent, works with any clip. Set `physics_interpolation_mode = OFF` on VisualRoot and drive it from `_process`; the CharacterBody3D parent stays interpolated.
2. **Bone layer (secondary, optional).** A `SkeletonModifier3D` subclass placed under the `Skeleton3D`. In Godot 4.7 docs it runs after the `AnimationMixer`, overrides `_process_modification_with_delta(delta)` (the plain `_process_modification()` is deprecated), must not apply `influence` itself, and may be called with `delta = 0.0` during initialisation. Use it for: head squash on landing with a two-frame lag (overlap), `upperarm.r` pump on beam fire, chest breath on idle. Do NOT scale legs or `hips`: scaling `hips` also scales the legs and lifts the feet off the ground.
3. **Procedural clips for missing animations (ART-04).** Double-jump flip, air-dash pose, aim lean and pull pose can start as VisualRoot motion over existing clips (see KAYKIT.md clip table), then be replaced by Blender clips only if they fail the playtest.

Spring helper (critically useful: impulses stack without tween fighting):

```gdscript
class_name Spring extends RefCounted
var value := 0.0          # displacement from rest
var velocity := 0.0
var freq_hz := 3.5        # 3-4 Hz body, 6 Hz small shudders
var zeta := 0.45          # 0.3 bouncy, 0.45 default (about 20 % overshoot), 1.0 no overshoot
func kick(d: float) -> void: value += d
func step(dt: float) -> float:
    dt = minf(dt, 1.0 / 30.0)
    var w := TAU * freq_hz
    velocity += (-w * w * value - 2.0 * zeta * w * velocity) * dt
    value += velocity * dt
    return value
```

Usage: `spring.kick(-0.2)` on landing; each frame `var s := spring.step(delta)`; `visual_root.scale = Vector3(k, 1 + s, k)` with `k = 1.0 / sqrt(maxf(0.2, 1.0 + s))`.

Use `Tween` only for one-shot, non-interruptible UI animations (icon pop, wipe). Always keep a reference and `kill()` before creating a new tween on the same property. Use `set_trans(TRANS_BACK)` / `TRANS_ELASTIC` for pops. UI tweens call `set_ignore_time_scale(true)`.

### 6.5 Particles (GPUParticles3D)

- One-shot pools, not per-event instancing: 6 to 8 pre-instanced emitters per type (dust, steam, sparks, ring), `one_shot = true`, `explosiveness = 1.0` for bursts, `local_coords = false`. Reposition, call `restart()`, return to the pool on `finished` or a timer.
- Do not change `amount` at run time (it resets the system); scale intensity via `amount_ratio`.
- One shared material per type, `visibility_aabb` set, small quads, additive or alpha-scissor to limit overdraw (PITFALLS 13). Steam 20 to 60 particles.
- Pre-warm every cue once behind the load screen to avoid first-use shader compile hitches.
- Particles follow `time_scale`, so they freeze during hit-stop, which looks right.
- Ribbon trails: `RibbonTrailMesh` on a GPUParticles3D attached to `handslot.r` and feet are cheaper than ghost copies. Ghosts of a skinned character need duplicated skeleton plus 18 bone poses per ghost; add only if the A/B test says trails are too weak.
- Asset sources already in the repo (CC0): Kenney particle pack (circle, dirt, magic, muzzle, smoke, spark, star, trace, twirl, flare), Brackeys flipbooks (cloud, wispy_smoke, explosion_smoke 8x8). Tint in Godot materials; keep raw textures neutral.
- Anything spawned from `_physics_process` that must not interpolate: `reset_physics_interpolation()` after setting its transform.

### 6.6 Other

- Footstep-synchronised effects need animation callbacks (method-call tracks) on run clips or a foot-bone height / velocity check. Prefer the latter so it works for all clips.
- Flash effect: a shared `flash` instance uniform on the character material (HDR white mix), set by spring, no material duplication.
- Hand VFX anchor: `handslot.r` via `BoneAttachment3D`, the same socket as HandSocket in ARCHITECTURE.md.
- Interaction of juice with `Input.use_accumulated_input`: set `false` for lowest input latency, see Section 7.

---

## 7. Evaluation method for a university project

### 7.1 Latency budget (ESTIMATES by arithmetic, not measurements)

| Stage | Typical at 60 Hz display / 60 TPS | At 144 Hz / 120 TPS | Lever |
|-------|-----------------------------------|---------------------|-------|
| Input device and OS | 1 to 8 ms | same | 1000 Hz mouse |
| Wait for next physics tick | 0 to 16.7 ms (avg 8) | 0 to 8.3 ms (avg 4) | `physics_ticks_per_second = 120` (Jolt, measure CPU) |
| Interpolation delay (render is up to one tick behind the simulation) | up to 16.7 ms | up to 8.3 ms | same lever |
| Render plus present with V-Sync | 17 to 33 ms | 7 to 14 ms | V-Sync mode (Mailbox / off for tests) |
| Display processing | 5 to 15 ms | 3 to 10 ms | monitor |
| **Sum, typical** | **about 60 to 90 ms** | **about 30 to 50 ms** | |

Targets: jump button-to-photon <= 66 ms (4 frames at 60 Hz) as goal, 100 ms hard limit (P2). Decision for Phase 2: measure at 60 and at 120 TPS on the target laptop and choose; the interpolation delay is the known price of smooth rendering.

How to measure:
- **Software part:** log `Time.get_ticks_usec()` at `_input`, at the state change in `_physics_process`, and at the first frame after (`RenderingServer.frame_post_draw`). Gives input-to-frame latency in the engine, per press, into a CSV.
- **Photon part:** 240 fps phone camera filming keyboard and screen together; count frames from key press to first visible change (accuracy about 4 ms per frame). 20 presses, report median and p90.
- Settings under test: V-Sync on / off, 60 / 120 TPS, `Input.use_accumulated_input` true / false.
- Animation response rule: first visible change (pose, dust, stretch) on the same frame as the state change; anticipation <= 2 frames.

### 7.2 Juice on/off and A/B tooling

- Presets OFF / MEDIUM / HIGH / EXTREME mapped to the four Kao conditions (scale 0 / 0.6 / 1.0 / 1.8). EXTREME only exists in a "study build" flag.
- Per-channel switches (body, shake, fov, particles, time, ui) for the Nijman-style incremental method: turn channels on one at a time and compare.
- Hold-to-compare hotkey and a `--juice=<preset>` command-line flag so study sessions are reproducible.
- Every telemetry row records the active preset.
- OFF must keep all informational cues (P10), otherwise OFF measures readability instead of juice.

### 7.3 Playtest protocol (three levels)

| Level | Who | When | What |
|-------|-----|------|------|
| Daily self-test | Developer | every working day, 10 min | "Feel loop" in the gym: run, jump chain, dash, land from heights, pull course. Log one line of impressions. Always compare to the previous build's note. |
| Peer sessions | 4 to 6 players, 15 min each | after Phase 3 (movement and camera), after Phase 5 (modules), after boss | Think-aloud on the gym plus one level section. Ask: "Did the jump / dash / pull feel responsive? What felt late, heavy, floaty, jittery, too much?" Collect telemetry. |
| Controlled A/B study | 8 to 12 players (uni peers), within-subject | after the Feel Pass, before audio | Same 10-minute course played under OFF, MEDIUM, HIGH, EXTREME, order counterbalanced (Latin square), 2-minute break between. Questionnaires after each. Report medians and effect sizes; avoid p-hunting with n = 10. |

Tasks for the controlled study: (1) gym jump-gap course, (2) dash and double-jump section, (3) pull / anchor course, (4) a short boss-hit exchange (once the boss exists).

### 7.4 Instruments

| Instrument | Use | Notes |
|------------|-----|-------|
| In-game GEQ (IJsselsteijn, de Kort, Poels 2013), 14 items, 7 components (competence, sensory and imaginative immersion, flow, tension, challenge, negative affect, positive affect) | After each condition | Short enough to repeat 4 times. Report competence, flow, positive affect first. |
| PENS (Ryan, Rigby, Przybylski 2006): use the **intuitive controls** and **competence** subscales | After each condition | Directly about control feel; Kao uses PENS and IMI for the same reason. |
| IMI (Intrinsic Motivation Inventory): interest/enjoyment and perceived competence subscales | Optional | Aligns with Kao 2020 outcomes. |
| Custom 7-point items | After each condition | "The controls felt responsive", "Landing and jumping felt satisfying", "The grapple made me feel fast", "The effects were distracting" (reverse-coded), "I always knew what was interactable". |
| Simulator Sickness Questionnaire (Kennedy 1993) or the single-item Fast Motion Sickness scale | After the camera-heavy conditions | Checks FOV kicks and shake. |
| MDA (Hunicke, LeBlanc, Zubek 2004) | Framework for the written report, not a measurement tool | Separate mechanics (movement numbers), dynamics (flow, momentum chains) and aesthetics (satisfaction, "juiciness"). |

Telemetry (cheap, high value): per run, deaths per section, completion time, count of jumps saved by coyote or buffer, dash count, pull count, FPS p99 and frame-time spikes, camera collision events, juice preset. A rising share of "saved by coyote" with falling deaths supports P3.

### 7.5 Per-cue definition of done

A cue is done when: it has a data row with tier and numbers; it respects tier caps; it can be switched off per channel; it was reviewed in OFF / MEDIUM / HIGH; informational parts survive OFF; it does not delay control; it was tested at 10 TPS and 144 Hz without jitter; and its `sfx_id` slot exists (empty).

---

## 8. Roadmap implications

Map to the existing 9-phase proposal in SUMMARY.md. Requirements FEEL-01..05 already exist; suggested additions are at the end.

| Phase | Juice work to add | Gate / acceptance |
|-------|-------------------|-------------------|
| 1 Foundation | FeelService autoload skeleton, `FeelCue` and `FeelSettings` resources, fact signal list, debug panel with preset switch and hold-to-compare, telemetry CSV writer, latency-logging harness. Decide `Engine.time_scale` ownership (TimeFx). Colour rule: movement VFX cream/warm, turquoise only for hand and interactables. | FEEL-01, FEEL-05 skeleton works with one dummy cue (OFF vs HIGH visibly differs). |
| 2 Movement | Minimum viable juice: VisualRoot spring squash/stretch, jump and land dust, sprint lean and foot-sync, dash stretch and steam, skid turn. 30-minute spike: hit-stop x physics interpolation x 10 TPS. Measure latency at 60 vs 120 TPS. Missing-clip strategy for double jump / air dash as procedural motion. | Movement sign-off first WITHOUT juice (Swink gate), then with juice ON and OFF; no jitter; latency table filled. FEEL-02. |
| 3 Camera and aim | Additive CameraRig stack: aim blend, sprint FOV, dash impulse, landing dip, trauma shake with noise, reduce-motion switch. Phantom Camera spike includes layering test. | FOV total <= +12 deg; roll off by default; peer session 1 (nausea check, SSQ/FMS). FEEL-04 camera part. |
| 4 Hand framework and Modul 1 | Reticle state set, target highlight pulse, beam cue (flash, width pulse, impact), target shudder on next frame, arm pump via SkeletonModifier3D, hit-stop hook for later. | Cause-to-effect within one frame; informational cues survive OFF. FEEL-03 part. |
| 5 Mechanisms, Modul 2, progression | **Pull/push prototype with momentum test room first** (Section 5). Mechanism activation cue (anticipation, steam, pipe pulse, distance-attenuated shake). Module pickup cue (freeze, icon pop). Checkpoint and respawn cue with 1.0 s budget. Death cog burst. | Pull metrics table recorded; peer session 2; respawn <= 1.0 s. FEEL-03 complete. |
| 6 Level blockout | No new juice; use the blockout to validate that camera, trauma and FOV hold up in tight rooms. Telemetry for level pacing. | Tight-corridor shake test passes. |
| 7 Art pass | Calibrate VisualRoot pivot and bone names on the final Meshy hero (rigid segments); arm-core glow states; flash shader uniform on the final materials; steam and dust sprites finalised in the palette. | Lineup scene includes juice VFX under final lighting. |
| 8 Boss | Boss-hit, core-extinguish, phase-change and defeat cues; boss recoil via rigid-part springs; slow-mo ease; telegraph readability (juice must not hide telegraphs). | Boss cues within T3/T4 caps; peer session 3. |
| 9 **Feel and Juice Pass (new, dedicated)** | Walk the catalogue row by row, fill gaps, tune with A/B per channel, run the controlled study (Section 7.3), set shipped default preset, freeze values, strip study-only EXTREME. | Study report exists; no cue breaks the DoD in 7.5. |
| 10 **Audio (last)** | Register AudioSink, fill `sfx_id`, then re-tune hit-stop and trauma by about +/-20 % (sound changes perceived impact). Polish, performance, export follow (existing Phase 9 content). | Every catalogue row has sound; retune log written. AUDIO-01/02. |

**Why juice cannot be only a final phase.** Camera lag, FOV behaviour, squash timing and dust are part of what "responsive" means, so movement and camera numbers are tuned against the presence of juice. Hence Phase 1 hooks, Phase 2 and 3 minimum juice, Phase 4-5 per-module cues, Phase 9 dedicated pass. **Why still a dedicated pass:** consistency of tiers, parameter tuning across cues, and the controlled study need all verbs to exist.

**Cut list for juice if time slips (in order):** ghost afterimages, bone-layer secondary motion (keep VisualRoot only), pipe energy-pulse shader (keep lamp colour change), distortion rings, slow-mo on phase change (keep hit-stop), self-push blast-jump, screen-edge speed streaks, SSQ questionnaire (keep one motion-sickness item).

**Must keep:** springs on VisualRoot, land and jump dust, FOV kicks, trauma shake, hit-stop on damage / boss hit / pickup, reticle states, target reaction on the next frame, rope visual and carry-over decay for the pull, fast respawn, juice OFF switch.

**Suggested additions to REQUIREMENTS.md:**
- FEEL-06: Latency measured and recorded (<= 100 ms, goal 66 ms) for jump and dash at the chosen TPS.
- FEEL-07: "Reduce motion" option (no roll, no shake, reduced FOV kicks and hit-stop).
- FEEL-08: Juice catalogue as data (`FeelCue` resources) with tiers and caps documented.
- FEEL-09: Controlled A/B juice study (OFF / MEDIUM / HIGH / EXTREME) with GEQ and PENS subscales, results documented.
- FEEL-10: Pull momentum metrics table (speed gain, exit speed, release window) recorded and used for level gates.
- FEEL-11: Informational feedback remains with juice OFF.

**Research flags:**
- Phase 2: standard patterns plus the 30-minute time_scale / interpolation spike.
- Phase 3: spike for Phantom Camera layering (already flagged for the addon).
- Phase 5: **needs its own focused prototype** for pull and push feel (thin literature, highest risk to Core Value).
- Phase 7: check bone naming of the final hero for the SkeletonModifier3D.
- Phase 9: standard, but needs ethics-light consent wording for the study (uni requirement, unverified).

---

## 9. Pitfalls specific to juice

| Pitfall | Why it matters | Prevention |
|---------|----------------|------------|
| Juice covering for weak movement | Feedback can mask but not fix floaty control (P1) | Phase 2 gate without juice |
| Extreme juice | Worse outcomes than medium (Kao 2020) | Tier caps, default HIGH = this catalogue, EXTREME study-only |
| Uniform, unearned juice | Success-dependent juice works, amplified juice reduces agency (Kao 2024, secondary) | Contingent cues, proportional scaling |
| Hit-stop on movement | Reads as lag, breaks flow | Only for damage, boss hit, pickup, phase change |
| `time_scale` stuck below 1 | Freed node never restores | Single owner autoload, token, `_exit_tree` reset |
| Multiplying `time_scale` | Overlapping hits compound | Assign, longest wins |
| Shake on real-time vs scaled clock | Shake hangs or snaps during freeze | Real-time clock (ticks_usec) |
| Roll and large rotation shake | Motion sickness (PITFALLS 5) | Roll off, small angles, reduce-motion |
| Camera additive channels fighting | FOV and offsets overwritten by several writers | CameraRig sole writer |
| Visual nodes driven from `_process` under interpolated parent | Jitter, interpolation warnings | `physics_interpolation_mode = OFF` on VisualRoot, ShakeRoot, ghosts; 10-TPS test |
| Scaling `hips` or legs | Feet float or slide | Whole-body squash on VisualRoot, bone scale on head / arm / chest only |
| Tween stacking on the same property | Fighting, stuck scale | Springs for continuous values; kill previous tween |
| Anticipation frames before jump / dash | Adds latency | <= 2 frames or none |
| Turquoise used in movement VFX | Dilutes the interactable language | Movement VFX cream / amber; open question: player arm cores glow turquoise (same exception issue as in SUMMARY "Turquoise conflict") |
| Particle overdraw and first-use hitches | Performance on weak laptops | Pools, `amount_ratio`, pre-warm, caps |
| Retune after audio forgotten | Sound shifts perceived impact | Scheduled retune in Phase 10 |
| Study confounds | Learning effect, order effect | Counterbalance, same course, short breaks |

---

## 10. Gaps and open questions

- Exact timing constants from Celeste, Hollow Knight, Odyssey, Astro Bot: not verified. Use the catalogue as hypotheses.
- Interaction of `Engine.time_scale` with physics interpolation and physics tick cadence: no source found; spike in Phase 2.
- Phantom Camera compatibility with additive FOV / shake layers on 4.7.2: unverified.
- Whether the shipped hero keeps `Rig_Medium` bone names: Route A in KAYKIT.md says yes; keep bone names exported.
- Arm-core glow on the player vs the turquoise-for-interactables rule: needs a decision in the Phase 1 style contract (suggest: the player's cores are warm white / amber-cyan shifted, or an explicit documented exception).
- Pull-and-push literature: only community material found; no GDC-grade source on grapple feel. Phase 5 prototype must generate its own data.
- Hicks et al. effect sizes and Kao 2024 details: only abstracts and secondary summaries read.
- Ethics or consent requirement for playtests at the university: unknown.
- Jolt at 120 TPS CPU cost on the target laptop: unmeasured.

---

## Sources

Primary or official (HIGH where marked):
- Kao, D. (2020). The effects of juiciness in an action RPG. Entertainment Computing 34, 100359. DOI 10.1016/j.entcom.2020.100359. Abstract confirmed via search index (x-mol, dblp). HIGH for headline result.
- Hicks, K., Dickinson, P., Gerling, K., Vanden Abeele, V. (2019). Juicy Game Design: Understanding the Impact of Visual Embellishments on Player Experience. CHI PLAY 2019, pp. 185-197, DOI 10.1145/3311350.3347171. Abstract confirmed; full text not retrievable (403). HIGH for bibliographic data and abstract framing.
- Kao et al. (2024), CHI follow-up on success dependence and amplification (n = 1,699), spiral.imperial.ac.uk listing. MEDIUM-LOW (secondary summary).
- Godot docs, `Engine` class (time_scale note) and `SkeletonModifier3D` class (4.7 docs): docs.godotengine.org/en/stable/classes/class_engine.html, class_skeletonmodifier3d.html. HIGH.
- Eiserloh, S. GDC 2016, Math for Game Programmers: Juicing Your Cameras With Math. gdcvault.com/play/1023146. Existence HIGH; trauma and noise details recalled.
- Pittman, K. GDC 2016, Math for Game Programmers: Building a Better Jump. gdcvault.com/play/1023148. Existence HIGH; Mario gravity claim via JCCC conference blog summary, MEDIUM.
- Swink, S. (2008). Game Feel: A Game Designer's Guide to Virtual Sensation. Morgan Kaufmann. Existence HIGH; latency thresholds via lecture decks, MEDIUM-LOW.
- Swink, S. Game Feel: The Secret Ingredient. gamedeveloper.com/design/game-feel-the-secret-ingredient. MEDIUM.

Practitioner and community (MEDIUM-LOW):
- Hit-stop and screen shake in Godot 4 (autoload plus trauma camera), Godot forum, tested on 4.7-stable Compatibility renderer only: forum.godotengine.org/t/tutorial-hit-stop-and-screen-shake-in-godot-4-autoload-trauma-camera-mit/145240. MEDIUM.
- Godot Hitstop Basics (uhiyama-lab): uhiyama-lab.com/en/notes/godot/hit-feedback-hitstop/. MEDIUM (durations, pitfalls consistent with the forum tutorial).
- Celeste and Forgiveness (maddymakesgames.com/articles/celeste_and_forgiveness/): list of forgiveness mechanics, no numbers. MEDIUM for the list.
- Thorson, M., Celeste game-feel Twitter thread (March 2020), via reposts (Gigazine, GameSpot, Blizzard Watch, threadreader). MEDIUM for content, LOW for numbers.
- Jonasson, M., Purho, P. Juice it or lose it (2012), Nijman, J.W. The Art of Screenshake (2013), Thomas and Johnston, The Illusion of Life (1981): standard references, recalled, not re-fetched.
- IJsselsteijn et al. (2013) Game Experience Questionnaire; Ryan, Rigby, Przybylski (2006) PENS; Hunicke, LeBlanc, Zubek (2004) MDA; Kennedy et al. (1993) SSQ: standard instruments, recalled.
- Mark Brown, GMTK Platformer Toolkit (2021): existence confirmed via news listing.
- Community posts on grapple swing readability (itch.io, Roblox guides): LOW.
- Project files: `.planning/research/FEATURES.md`, `PITFALLS.md`, `SUMMARY.md`, `ARCHITECTURE.md`, `KAYKIT.md`, `.planning/REQUIREMENTS.md`; KayKit `Rig_Medium` clip names (read directly from the GLB headers in `KayKit/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/`: `Jump_Start/Idle/Land`, `Jump_Full_Short/Long`, `Running_A/B`, `Dodge_*`, `Hit_A/B`, `Death_A/B`, `Spawn_Air/Ground`, `PickUp`, `Interact`, `Throw`, `Use_Item`, `Cheering`; no sprint, double jump, dash-in-air, pull or push clips). HIGH.

---
*Game feel research for Attimo, 2026-11-02*
