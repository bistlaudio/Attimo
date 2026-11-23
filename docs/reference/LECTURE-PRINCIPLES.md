# Lecture Principles (Concept & Design II + III)

Source: lectures by Prof. Dr. Benedikt Morschheuser and Florian Enders, Game Production & Management (C&D II "Prototyping, Level Basics, Balance", 02.11.2026; C&D III "Onboarding, Game Feel, Architecture", 23.11.2026). PDFs in `docs/vorlesung/`. Free books read directly: Nystrom, *Game Programming Patterns* (web edition) and *The Level Design Book* (web).

> **Priority (user decision 2026-11-23):** the lectures are **one additional lens, not the main basis**. The main basis for every discuss, plan and execute step is always our own research into current, state-of-the-art practice (phase research, current Godot docs and engine features, proven techniques from shipped games and recent talks/papers). Use this file afterwards as a second perspective: does the plan also hold up against the lecture? Where research and lecture disagree, follow the better-supported current practice and note why.

This file turns the lectures into **checks for discuss, plan and execute**. The project skill `attimo-design-principles` points every GSD planning step here. When a new lecture or book arrives, add its principles here and update the checklist.

## 1. Planning checklist (every phase)

Answer these in the discuss/plan step; a plan that cannot answer them is not ready.

| # | Check | From |
|---|---|---|
| 1 | **Question:** which question does this phase's prototype answer? State it in one sentence. | Schell ch. 8; Fullerton ch. 7 |
| 2 | **Greatest risk first:** is the riskiest part (for the core value) built and tested first, as a throwaway if needed? | Schell ch. 8 |
| 3 | **Fidelity follows the question:** is the build only as polished as the question needs (greybox, Prototype Bits)? | Fullerton ch. 7; Virzi et al. 1996 |
| 4 | **Metrics:** are new spaces and objects built against measured numbers (MovementConfig, MOVEMENT-METRICS.md), not taste? | Totten ch. 3; LDB "Metrics" |
| 5 | **Toybox:** does the gym get a station/room for every new mechanic before it goes into a level (gym rule)? | Totten ch. 3; LDB "Pre-production" |
| 6 | **Teach, test, twist:** does every new mechanic get teach → test → twist beats, without text, one mechanic per scene, twist spaced after the test? | Totten pp. 331–334; LDB "Pacing" |
| 7 | **Don't challenge learners:** no punishment while a mechanic is new; retry starts near the mistake (respawn ≤ 1 s). | Hodent pp. 122, 153 |
| 8 | **Loop relationships:** which reinforcing or balancing relationships does the phase add or change (see section 3)? | Fullerton ch. 5; Gazaway ch. 16 |
| 9 | **Which knob:** tuning changes the element lowest in the hierarchy (section 3), found by binary search on the F2 panel. | Gazaway ch. 12–13 |
| 10 | **Feel property:** which single physical property should the mechanic sell, and do all cues point at it (no clashing effects)? | Swink pp. 6, 151–170 |
| 11 | **Readability:** does the object follow the coupling (brass free, turquoise energy, nature resistance); contrast, landmark, signal-to-noise? | Totten ch. 4–5 |
| 12 | **Architecture decision:** name the decision and the change it keeps cheap; which part is a component, which fires an event? | Nystrom; Konrad et al. 2026 |
| 13 | **Done means:** write down what "done" means before prompting; one job, one session, one test. | Kaufman et al. 2026 |
| 14 | **Docs:** GAME-DESIGN.md, the site and the presentation updated if the design changed. | project rule |

## 2. Principles by topic

### Level design (C&D II, Totten 2014, The Level Design Book)
- **Toybox for testing:** one scene as a workbench to try jumps, doors and enemy placement before a real layout. For Attimo this is the movement gym.
- **Metrics:** space is built against player numbers (jump height/distance, speed, width). Player metrics are measured from the engine; building metrics (gap widths, ledge heights) are chosen against them. Check reachability with h = v²/2g and the dash/long-jump distances. "Metrics are not magic": playtest anyway.
- **Form follows function:** the shape of a space follows what the player does there.
- **Parti sketch, then greybox:** cheap unmeasured sketches first, then a grey blockout walked with real gravity and speed, never only flown in the editor. Expect most blockouts not to survive a playtest.
- **Three space sizes:** narrow (tension), intimate (sized to metrics), prospect (open, long sightlines). For a speed game, prospect spaces show the route ahead.
- **Enter by contrast:** dark → light, busy → sparse announces an entrance without signage.
- **Landmarks:** one landmark that attracts, orients and tracks beats five decorations. Attimo: the lab, visible from far.
- **Signal-to-noise:** push everything that is not the point into the background.
- **Guidance ages:** guidance aids help early players and become noise later.
- **Pacing:** alternate intensity; start quiet; intensity is not difficulty; plan at least one set piece; build a "pile of beats" and arrange the best.

### Prototyping (C&D II, Schell 2020, Fullerton 2019)
- A prototype is a quick, disposable model you loop on; the number of test cycles predicts quality, not hours.
- Every prototype answers a stated question.
- Prototype the greatest risk first (Schell's Bubbleville: fun risk, tech risk, production risk, art risk, each with its own small prototype).
- Ideas are paper cups: cheap, replaceable.

### Balance (C&D II, Gazaway 2022, Fullerton 2019)
- Balance is agency: every option has a time, place or playstyle where it is the right call. Equal numbers are not a choice (sword vs. sword of Kapow).
- Reinforcing loops drive to an extreme; balancing loops pull back. Most games need both.
- Difficulty mechanisms: flat, dynamic (DDA), layered, cross-feeding (several ways to solve the same task).
- **Hierarchical design:** rank elements; when two conflict, change the lower one. Lecture ranking: core vision > engine > controls > camera > player character > level design constraints > enemies > individual levels. A monster too hard? Change the monster, not the player.
- **Binary search:** guess the middle of the remaining range; if the range is unknown, double or halve until it is.
- **Attribute weights:** compare options by weighted totals of what actually matters in the game.

### Onboarding (C&D III, Totten 2014, Hodent 2018)
- The opening must hold attention, show the world, teach the mechanic by doing, and give a reason to go on.
- Text fails: massed tutorial text gets wiped out (fix: spacing) and text without stakes means nothing (fix: purpose).
- One scene, one mechanic; teach → test → twist with numbered beats.
- Cognitive load: learning uses the same budget as everything else; no challenge while learning. Curse of knowledge: the developer finds it easier than it is.

### Game feel (C&D III, Swink 2008)
- Game feel = real-time control of virtual objects in a simulated space, with interactions emphasised by polish.
- Polish creates artificial cues about physical properties without changing the simulation.
- Toolkit: animation (squash and stretch), VFX (motion over texture), sound, cinematic (shake, frame pause), tactile (rumble), rules feedback.
- Design top-down (property → perception → effects), players read bottom-up. Clashing effects destroy the reading: all effects point at one property.

### Architecture (C&D III, Nystrom 2014, recent studies)
- Good architecture makes the next change feel anticipated. Understand → think → code → clean up is still the developer's job.
- "Vibe architecting": AI agents make architecture decisions that nobody reviews. More capable models produce more bloated, coupled code; code volume predicts structural degradation (Zhu et al. 2026). AI speeds up tasks but can skip comprehension (Alakmeh et al. 2026).
- **Component:** split along domain lines, composition over inheritance; keep update order explicit.
- **Observer:** one system announces, others listen (Godot signals, EventBus). Pass values, not node references that may be freed; never re-emit from inside a handler of the same signal; disconnect long-lived listeners.
- **Event Queue:** only when sending and processing must be decoupled in time.
- **State:** explicit states instead of contradicting booleans; per-state data lives in the state; separate machines for independent concerns.
- **Type Object / Prototype:** kinds of things as data (Godot Resources), variants by overriding fields of a base.
- **Grey-box modules:** you own the interface, the agent owns the implementation, a test checks the fit (Pocock 2026).
- Tips: modular scenes, Resources for data, test the build pipeline early, define "done" before prompting.
- YAGNI: add abstraction only when a second consumer exists; label throwaway prototypes and really throw them away.

## 3. Attimo applied

### Loop relationships
| Type | Relationship |
|---|---|
| Reinforcing | speed → passive charge → more speed; Moto Perpetuo raises run speed, which charges faster; opened routes lead to new sources |
| Balancing | injected moves and the Loader cost energy; cap at 100; respawn with one core; nature slows (less charge); extracting is efficient but slow and risky |

### Element hierarchy (change the lowest first)
1. Core vision (energy-momentum loop, fluid movement)
2. Engine (Godot 4.7, Jolt)
3. Controls (Input Map, KB+M)
4. Camera (CameraRig)
5. Player character (MovementConfig, energy costs, Loader)
6. Kit and level design constraints (logic blocks, metrics)
7. Enemies
8. Individual level sections

### Kit architecture review (GAME-DESIGN.md section 6.8)
The 8 blocks + 4 components + looks design **matches the lecture** (components by composition, signals as observer, `.tres` as type objects, inherited scenes as modular prefabs, a smoke test per object as the grey-box check). Guardrails to keep it that way:

1. **No flag soup inside a block.** Timed motion and force volume each serve 7–10 objects. Their variants (path / rotate / swing / stamp; directional / radial / drag / gravity) are one selected profile, not combinable booleans. If one variant needs much special code, split it into its own block.
2. **Shared Resources:** a loaded `.tres` is shared by reference. Runtime state (current charge, amplification, timers) lives on the node; never write into the config at runtime, or `duplicate()` it first.
3. **YAGNI for components:** build a component only when it has two users. The energy-cost component currently has one (attraction field escape); keep it a force-volume parameter until a second user appears.
4. **Interface first:** each block documents its interface (exported config, incoming and outgoing signals) and has a contract test; each object keeps its smoke test.
5. **Signals carry values:** EventBus facts carry ids, positions and amounts, not node references.
6. **Small and reviewed:** every plan names its architecture decision and the change it keeps cheap; keep blocks small, because code volume predicts degradation.

### Open lecture homework for Attimo
- Feel property: name the one word the Loader/momentum should sell (candidates: "charged", "weighty", "snappy").
- Opening beats: write the opening level as numbered teach/test/twist beats (Phase 6 teaching rooms, Phase 7 level).
- Architecture diagram: core loop → components and events, readable by a stranger (fits the design notebook).

## 4. Book list

**Download priority (only these are worth getting as full text):** 1. Swink, *Game Feel*; 2. Totten, *An Architectural Approach to Level Design*; 3. Hodent, *The Gamer's Brain* (optional, for the teaching rooms and the opening). Everything else is covered well enough by the lecture slides, the free books already read, or the paper abstracts.

**Source plan (status 2026-11-23):**

| Source | Who gets it | How | Used in phase |
|---|---|---|---|
| Swink, *Game Feel* (full) | done | `docs/vorlesung/books/swink-2008-game-feel.pdf` | 5, 11, 12 |
| Totten, *An Architectural Approach to Level Design*, 2nd ed. (full), ISBN 9780815361367 / eBook 9781351116299 | not available (closed 2026-11-23) | use the local preview, the lecture slides and *The Level Design Book* instead | 05.1, 7 |
| Pittman, "Math for Game Programmers: Building a Better Jump" (GDC 2016) | Claude, in the phase | fetch a written summary of the talk during phase research | 5 |
| Nesky, "50 Game Camera Mistakes" (GDC 2014) | Claude, in the phase | video: fetch a written summary or transcript during phase research | 5 |
| Nijman, "The Art of Screenshake" (2013); Jonasson & Purho, "Juice it or lose it" (2012) | Claude, in the phase | video: fetch a written summary or transcript during phase research | 11, 12 |
| Nystrom, *Game Programming Patterns*; *The Level Design Book* | done | read online, summarised in section 2 | all |

The same sources are attached to the phases in `.planning/ROADMAP.md` (phase notes, "Research sources").

**Local library (`docs/vorlesung/books/`, git-ignored), status 2026-11-23:**

| File | Content | Use |
|---|---|---|
| `swink-2008-game-feel.pdf` | full book, 377 pages | main reference for Loader, movement feel and polish (no newer edition exists) |
| `totten-2019-level-design-2e-PREVIEW.pdf` | publisher preview of the 2nd edition, 63 pages | intro only; the full book is needed for metrics, landmarks and pacing chapters (Phase 05.1 gym, Phase 7 level) |
| `hodent-2018-gamers-brain-PREVIEW.pdf` | publisher preview, 27 pages | intro only; optional, the lecture slides cover what we need |

**Gaps, filled with free classic talks instead of more books:**

| Gap | Source | Why |
|---|---|---|
| Third-person camera (incl. the Loader's free camera) | John Nesky, "50 Game Camera Mistakes", GDC 2014 (free on YouTube / GDC Vault) | the standard practical reference for third-person cameras |
| Jump arcs and air control | Kyle Pittman, "Math for Game Programmers: Building a Better Jump", GDC 2016 (free) | the standard reference for tunable jump curves |
| Juice and feedback (Phases 11-12) | Jan Willem Nijman, "The Art of Screenshake" (2013); Jonasson & Purho, "Juice it or lose it" (2012) (free) | classic, short, directly applicable |
| Optional book, only if the camera becomes a problem | Haigh-Hutchinson, M. (2009). *Real-Time Cameras.* Morgan Kaufmann, ISBN 9780123116345 | classic by the Metroid Prime camera developer |

Verified = DOI found in a registry or publisher record. "ISBN-based, unverified" = CRC Press pattern `10.1201/<eISBN>`, check before citing.

**Books**

| Source | Topic | Identifier |
|---|---|---|
| Totten, C. W. (2014). *An Architectural Approach to Level Design.* CRC Press | level design, metrics, landmarks, pacing | ISBN 9781466585416; DOI likely 10.1201/9781466585416 (unverified) |
| Fullerton, T. (2019). *Game Design Workshop* (4th ed.). CRC Press | prototyping, systems, balance | ISBN 9781138098770, eISBN 9781315104300; DOI likely 10.1201/9781315104300 (unverified) |
| Schell, J. (2020). *The Art of Game Design: A Book of Lenses* (3rd ed.). CRC Press | prototyping, risk | ISBN 9781138632059, eISBN 9781315208435; DOI likely 10.1201/9781315208435 (unverified) |
| Gazaway, D. (2022). *Introduction to Game Systems Design.* Addison-Wesley / Pearson | balance, tuning, hierarchical design (ch. 12, 13, 16, 17) | ISBN 9780137440788 (no DOI) |
| Swink, S. (2008). *Game Feel: A Game Designer's Guide to Virtual Sensation.* Morgan Kaufmann | game feel, polish | ISBN 9780123743282 (no DOI found) |
| Hodent, C. (2018). *The Gamer's Brain.* CRC Press | onboarding, cognitive load | ISBN 9781138089969 (hardback), eISBN 9781351650762 (no DOI found) |
| Shell, D. F., et al. (2010). *The Unified Learning Model.* Springer | learning, prior knowledge | DOI 10.1007/978-90-481-3215-7 (verified) |
| Nystrom, R. (2014). *Game Programming Patterns* | architecture patterns | free: gameprogrammingpatterns.com (read) |
| *The Level Design Book* | blockout, metrics, pacing | free: book.leveldesignbook.com (read) |

**Papers**

| Source | Identifier |
|---|---|
| Sweller, J. (1988). Cognitive load during problem solving: Effects on learning. *Cognitive Science* 12(2) | DOI 10.1207/s15516709cog1202_4 (verified) |
| Virzi, R. A., Sokolov, J. L., & Karis, D. (1996). Usability problem identification using both low- and high-fidelity prototypes. CHI '96 | DOI 10.1145/238386.238516 (verified) |
| Lankes, M., Wallner, G., & Kocur, M. (2025). Pathways of Desire: Enhancing Navigation and Sense of Community Through Player-Generated Desire Paths. CHI '25 | DOI 10.1145/3706598.3713191 (verified) |
| Robb, N., & Zhang, B. (2022). Performance-Based Dynamic Difficulty Adjustment and Player Experience in a 2D Digital Game. *Acta Ludologica* 5(1), 4–22 | no DOI found; actaludologica.com |
| Konrad, P. M., et al. (2026). Architecture Without Architects: How AI Coding Agents Shape Software Architecture. SAGAI @ ICSA 2026 | arXiv:2604.04990 (DOI 10.48550/arXiv.2604.04990) |
| Zhu, Y. C., Tsantalis, N., & Rigby, P. C. (2026). AI-Generated Smells: An Analysis of Code and Architecture in LLM- and Agent-Driven Development | arXiv:2605.02741 (DOI 10.48550/arXiv.2605.02741) |
| Borg, M., et al. (2026). Echoes of AI: Investigating the Downstream Effects of AI Assistants on Software Maintainability. *Empirical Software Engineering* 31(6) | DOI 10.1007/s10664-026-10889-1 (verified) |
| Alakmeh, T., et al. (2026). Grasping AI Reliance in Program Comprehension and Coding through the AIRELI Persona Taxonomy. ICPC '26 | DOI 10.1145/3794763.3794804; arXiv:2605.10702 |
| Kaufman et al. (2026, preprint) | not found; ask the lecturer for the reference |
| Pocock (2026), grey-box modules | not a paper (Matt Pocock's agent workflow material); no DOI |

Paid books go into `docs/vorlesung/books/` (git-ignored, never committed).
