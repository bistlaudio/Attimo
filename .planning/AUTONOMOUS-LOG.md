# Autonomous Run Log

Run started 2026-11-24 21:30 CET on user request ("weiter bis morgen 6 Uhr im Auto-Modus mit wenig Entscheidungen, Entscheidungen dokumentieren"). Hard stop: 2026-11-25 06:00 CET.
Every decision Claude takes instead of the user is logged here with the reason. Branch: `dev`. Nothing is merged to `main` or pushed during the run.

## Ground rules for this run

- R1: Work stays on `dev`. No merge to `main`, no push. Reason: CLAUDE.md allows the merge only after verification *passed*; Phase 5 is `human_needed` (feel checks need a human), so the merge waits for the user.
- R2: Feel and look checks that need a human are never marked passed by Claude. They go into `*-HUMAN-UAT.md` files and stay `pending`.
- R3: Grey-area questions in discuss/plan steps are answered with the recommended option; each answer is logged below.
- R4: When a choice would change the game design (GAME-DESIGN.md), Claude takes the option closest to the existing design doc and logs it as "design decision, review".

## Decisions

| # | Time | Phase | Decision | Reason |
|---|------|-------|----------|--------|
| A1 | 21:00 | 05 | Plan 05-01 resumed at Task 3 on top of WIP commit 70efbf7 (user chose this) | User answer |
| A2 | 21:30 | 05 | Code-review fix scope = blocker + warnings (CR-01, WR-01..05); INFO items left open | Default `--fix` scope; INFO items are hygiene |
| A3 | 21:30 | 05 | WR-01 (time-scale delta) only fixed if the engine fact is confirmed by a probe; otherwise skipped | Do not risk movement feel (core value) on an unverified claim |
| A4 | 21:30 | 05 | Phase 5 treated as "approved with open UAT": 13 human checks stay pending in 05-HUMAN-UAT.md; work continues with Phase 05.1 | User asked for few decisions; feel checks cannot be done by Claude |
| A5 | 21:30 | 05 | Loader-door 4 m jump: kept as is for now (no bridge) | Smallest change; listed as UAT item 12 for the user |
| A6 | 22:25 | 05 | Accepted fixer result: CR-01 + WR-01..05 fixed in 7 commits (04662b3..b634d20); own full-suite run 73 tests / 3572 checks / 0 failed; MOVEMENT-METRICS.md base rows unchanged | Verified independently |
| A7 | 22:25 | 05 | WR-02 fix gets an extra human check (UAT item 14) | Fixer flagged it as needing a gym check |
| A8 | 22:25 | 05 | `phase.complete 05` run; STATE now points to 05.1. Correction: ROADMAP already showed Phase 5 as done (set by the 05-05 executor), contrary to what Claude first told the user | Consistent state before 05.1 |
| A9 | 22:25 | 05 | Local tag `phase-05-uat` (not pushed) marks the state the 14 UAT checks refer to; 05.1 will rebuild the gym | User can test Phase 5 at that tag in the morning |
| A10 | 22:25 | 05 | Pre-existing: `run.sh test_dash` alone shows `reset_to` on Nil (fixtures.gd:151), not in full runs; left as is, noted for later | Not caused by Phase 5 fixes; out of scope |
| A11 | 22:25 | 05.1 | Scope of the night: Phase 05.1 only (discuss --auto -> research/plan -> execute -> review/fix -> verify). No milestone audit/complete. Phase 6 at most discussed/planned if time remains. No new executor after 05:00 | Bounded, safe stop before 06:00 |
| A12 | 23:35 | 05.1 | Discuss run with `--auto`: 27 grey areas auto-answered (full list in `phases/05.1-kit-rework-inserted/05.1-DISCUSSION-LOG.md`). DESIGN CHANGES to review: slingshot hold starts on entering the cage and fires like the Loader (no bonus/energy); steam cannon = fixed launch; steam wall pad = plain wall pad, NozzleWall push cut; clock hand = bounded sweep (no 360); energy-cost component also used by the energy core pay-in; damage = push + `player_hit` fact only (health in Phase 6); targets fire by shot only, heavy gear disc needs full charge (replaces valve); energy core: hold E pays in, thresholds 25/50/75; force-field barrier broken only by Loader bonus discharge; attraction field: walk out free, fast escape 20/s; showroom = the gym (3 layer areas + mixed course); old puzzle rooms removed | GAME-DESIGN.md, site, deck updated (c683c51, 5a26588, b3c0e5a). Most important playtest checks: clock-hand sweep and auto-start slingshot |
| A13 | 23:35 | 05.1 | Phase 5 zones (Zone_Loader, Zone_Energy) keep their layout; only cut pieces swapped in place, so 13 of 14 Phase 5 UAT checks stay testable on HEAD; item 11 at tag `phase-05-uat` | Protect pending UAT |
| A14 | 23:35 | 05.1 | Plan step runs with research, without a separate UI-SPEC (`--skip-ui`) | Greybox looks only in Group A; no screens/menus in this phase; saves ~1 h of the night |
