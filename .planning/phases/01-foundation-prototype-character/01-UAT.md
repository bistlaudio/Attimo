---
status: testing
phase: 01-foundation-prototype-character
source: [01-VERIFICATION.md]
started: 2026-11-04T14:40:32Z
updated: 2026-11-04T14:40:32Z
---

## Current Test

number: 1
name: Animation quality in the test scene (F5)
expected: |
  Idle_A, Running_A, Jump_Start/Jump_Idle/Jump_Land and Dodge_Forward play in place without broken poses; the Mannequin faces the pressed direction. (Review WR-03 predicts a visible Idle-to-Run pop.)
awaiting: user response

## Tests

### 1. Animation quality in the test scene (F5)
expected: Idle, Run, Jump and Dodge clips play in place without broken poses; facing follows input.
result: [pending]

### 2. F3 event log feel
expected: Log starts hidden, F3 (and the key left of 1) toggles it, newest line last, readable placement.
result: [pending]

### 3. Camera framing of the test scene
expected: Static camera frames the 20x20 floor, wall ring, 1/2/4 m blocks and the Mannequin; Prototype Bits texture renders.
result: [pending]

### 4. Collision layer names in the inspector
expected: Layers 1-6 show World, Player, Interactable, Enemy, Projectile/Beam, Hazard; 7-32 unnamed.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
