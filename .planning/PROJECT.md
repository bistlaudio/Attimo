# Attimo (Arbeitstitel offen)

## What This Is

Ein 3D-Third-Person-Platformer als Uni-Prototyp (vertikaler Slice). Die Hauptfigur ist schuld an der Apokalypse, weil in ihrem Labor etwas schiefgegangen ist, und will zurück ins Labor. Dafür muss sie durch die zerstörte, überwachsene Welt. Zentrales Werkzeug ist die Prothesen-Hand, die steampunkige Mechanismen auslöst und durch gefundene Bauteile (Module) erweitert wird.

## Core Value

Flüssiges, schnelles Bewegungsgefühl: Laufen, Sprint, Sprung und Dash müssen sich smooth anfühlen, und die Hand muss sich damit nahtlos verbinden. Wenn alles andere wackelt, muss das funktionieren.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Third-Person-Basis-Movement: Laufen, Sprint, Sprung, Dash, evtl. Wall-Run, mit Fokus auf flüssiges, schnelles Gefühl (Coyote-Time, Jump-Buffering, weiche Beschleunigung)
- [ ] Over-the-Shoulder-Kamera; Taste halten = Zielmodus mit Fadenkreuz
- [ ] Interagierbares leuchtet türkis (Energiekerne), leichte Zielhilfe
- [ ] Hand-Modul-System als Rahmen: Module lassen sich leicht hinzufügen und tauschen; jedes Modul hat klare Eingabe, klaren Effekt und eine Level-Situation, in der es gebraucht wird
- [ ] Konkrete Hand-Module, in der jeweiligen Phase festgelegt (erstes Modul: Mechanismen aus der Ferne auslösen, Zielen mit türkisem Strahl, sofern in der Phase bestätigt)
- [ ] Steampunk-Mechanismen in der Welt (Ventile, Zahnräder, Förderbänder, Schalter), die die Hand auslöst
- [ ] Loop: Rätsel lösen → Bauteil finden → Hand bekommt neue Fähigkeit → neue Wege werden frei
- [ ] Ein polierter Level (vertikaler Slice) mit Boss am Ende; Bosse sind durch die Katastrophe böse gewordene Gegenstände
- [ ] Look: Steampunk, post-apokalyptisch, warm und hoffnungsvoll, Low-Poly; Stil-Referenz KayKit Dungeon Remastered, aber auf den eigenen Stil angepasst
- [ ] Erzählung ausschließlich über Welt und Look, keine Dialoge oder Cutscenes

### Out of Scope

- Dialoge und Cutscenes — Story läuft nur über Welt und Look
- Mehrere Level — Umfang ist ein vertikaler Slice
- Controller-Optimierung im ersten Schritt — erst Maus/Tastatur, Controller später (Input trotzdem über Input-Actions angelegt)
- Festlegung aller Hand-Module vorab — werden pro Phase definiert

## Context

- Uni-Prototyp, Arbeitstitel offen.
- Art-Referenz: https://kaylousberg.com/game-assets/dungeon-remastered. Der Stil soll so sauber sein, aber an den eigenen Steampunk-Look angepasst (cremig-beige Akzente, gedämpftes Metall statt grellem Bronze, warmes Licht, Dampf, Stoff und Leder, kleine türkise Energiekerne als Leuchtakzent). Verfallene Maschinen, Rohre, Zahnräder, Natur erobert die Ruinen zurück.
- Der Nutzer erwähnte Assets "schon im Repo". Beim Start war das Repo leer (nur `.git`, keine Commits). Pfad der Assets ist zu klären.
- Modul-Ideen, die besprochen wurden und noch offen sind: Rücklauf-Uhrwerk (Zeit zurückspulen), Stasis-Hemmung (bewegte Teile einfrieren), Dampfstoß-Kolben (Boost/Druckwelle), Magnet-Greifhaken.

## Constraints

- **Engine**: Godot 4 — Szenen und Skripte sind textbasiert und lassen sich direkt bearbeiten und versionieren
- **Input**: Maus/Tastatur zuerst, Controller später, daher Input-Actions von Anfang an
- **Umfang**: Vertikaler Slice (ein Level, ein Boss, Uni-Prototyp)
- **Assets**: Low-Poly im KayKit-Stil, importierbar als glTF

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Godot 4 als Engine | Textbasierte Dateien, gute Zusammenarbeit mit Claude, glTF-Import, geeignet für Uni-Prototyp | — Pending |
| Vertikaler Slice statt mehrere Level | Politur und Spielgefühl wichtiger als Umfang | — Pending |
| Maus/Tastatur zuerst, Controller später | Schneller spielbar, Controller-Tuning ist eigener Aufwand | — Pending |
| Hand-Module pro Phase definieren | Nutzer will erst die Basics bauen und Module später festlegen | — Pending |
| Erzählung nur über Welt und Look | Kein Aufwand für Dialoge und Cutscenes | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-11-02 after initialization*
