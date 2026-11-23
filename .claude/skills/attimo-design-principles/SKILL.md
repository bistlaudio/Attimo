---
name: attimo-design-principles
description: Lecture-based design, level, balance, onboarding, game-feel and architecture checks for Attimo. Load before discussing, planning, executing or verifying any phase, and whenever designing mechanics, levels, the mechanism kit or code structure.
---

# Attimo design principles

0. **Research first:** the main basis is always our own up-to-date research into current best practice (current Godot docs and features, proven techniques, recent talks and papers). The lecture principles are a second lens applied afterwards; where they disagree, follow the better-supported current practice and say why.
1. Read `docs/GAME-DESIGN.md` (what the game is) and `docs/reference/LECTURE-PRINCIPLES.md` (the lecture lens).
2. **Discuss / plan:** answer the planning checklist in section 1 of LECTURE-PRINCIPLES.md inside the phase CONTEXT or PLAN (a short table is enough). Flag every item that the plan cannot answer.
3. **Mechanism kit and code:** follow the kit architecture guardrails in section 3 (no flag soup in blocks, runtime state not in shared `.tres`, components only with two users, interface + contract test per block, signals carry values).
4. **Tuning:** change the lowest element in the hierarchy first; find values by binary search on the F2 panel; record the knob and the reason.
5. **New mechanics:** gym station first (gym rule), teach → test → twist without text, no challenge while learning.
6. **Phase end:** if the design changed, update `docs/GAME-DESIGN.md` (change log), `docs/game-design.html` (site) and `docs/attimo-presentation.html` (deck).
7. If a lecture principle does not fit Attimo, say so and why (lecture homework item 6), instead of forcing it.
