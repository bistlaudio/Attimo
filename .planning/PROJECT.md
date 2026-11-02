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
- [ ] Zwei Hand-Module, Details in der jeweiligen Phase: Modul 1 Fernauslöser (türkiser Strahl), Modul 2 Pull/Push (zum Ankerpunkt ziehen mit Momentum, Dampfstoß zum Wegdrücken)
- [ ] Schießen mit dem Hand-Strahl auf Gegenstände und 1–2 einfache Gegnertypen (Details in der Phase)
- [ ] Juicy Feedback, wissenschaftlich fundiert (Game-Feel-Forschung), als durchgehender Schwerpunkt; Sound erst ganz am Ende
- [ ] Menüs: Titel, Pause, Einstellungen, Endbild
- [ ] Animationen nur aus dem KayKit-Kit (Rig_Medium), Movement richtet sich danach
- [ ] Steampunk-Mechanismen in der Welt (Ventile, Zahnräder, Förderbänder, Schalter), die die Hand auslöst
- [ ] Loop: Rätsel lösen → Bauteil finden → Hand bekommt neue Fähigkeit → neue Wege werden frei
- [ ] Ein polierter Level (vertikaler Slice) mit Boss am Ende; Bosse sind durch die Katastrophe böse gewordene Gegenstände
- [ ] Look: Steampunk, post-apokalyptisch, warm und hoffnungsvoll, Low-Poly; Stil-Referenz KayKit Dungeon Remastered, aber auf den eigenen Stil angepasst
- [ ] Erzählung ausschließlich über Welt und Look, keine Dialoge oder Cutscenes

### Out of Scope

- Dialoge und Cutscenes — Story läuft nur über Welt und Look
- Mehrere Level — Umfang ist ein vertikaler Slice
- Wall-Run, Kanten greifen — keine Clips im KayKit-Kit (v2)
- Volles Kampfsystem — nur Strahl-Schießen und 1–2 einfache Gegnertypen
- Controller-Optimierung im ersten Schritt — erst Maus/Tastatur, Controller später (Input trotzdem über Input-Actions angelegt)
- Festlegung aller Hand-Module vorab — werden pro Phase definiert

## Context

- Uni-Prototyp, Arbeitstitel offen.
- Art-Referenz: https://kaylousberg.com/game-assets/dungeon-remastered. Der Stil soll so sauber sein, aber an den eigenen Steampunk-Look angepasst (cremig-beige Akzente, gedämpftes Metall statt grellem Bronze, warmes Licht, Dampf, Stoff und Leder, kleine türkise Energiekerne als Leuchtakzent). Verfallene Maschinen, Rohre, Zahnräder, Natur erobert die Ruinen zurück.
- Look-Referenzen im Repo (in `docs/reference/`): `Character_Look.png` (Chibi-Proportionen, großer Kopf, graue Haare, Steampunk-Brille, Leder- und Stoffkleidung, Prothesen-Arm rechts mit grün-türkis leuchtenden Kernen, Low-Poly mit facettierten Kanten) und `World Look.png` (schwebende Steampunk-Inseln über Wolken, Ziegel und Holz, Rohre, Zahnräder als Plattformen, Dampf, grün-türkise Kristalle und Leuchtrohre, warmes Licht).
- **Asset-Pipeline:** Der Hauptcharakter wird in **Meshy** (AI-3D-Generator) erzeugt. Ein erster Charakter liegt vor (`CharMeshy.png`: 3.027 Dreiecke, 3.518 Vertices, Dreieck-Topologie). Der Charakter wird später in Meshy weiter verfeinert, bis er passt; bis dahin dient der aktuelle Stand als Platzhalter. Weitere Assets werden über das **Blender-MCP** erzeugt oder bearbeitet. Welche Assets gebraucht werden, wird gemeinsam festgelegt. Es braucht klare Regeln für Poly-Budgets (Charakter, Props, Umgebung), Rigging/Animation und den Export nach Godot.
- Asset-Bibliothek im Repo: `KayKit/` (Character Animations, Skeletons, Dungeon Pack, Prototype Bits, Brackeys VFX, Kenney Particles; alles CC0, ~207 MB). Analyse in `.planning/research/KAYKIT.md`.
- Modul-Ideen aus der Diskussion: Fernauslöser, Pull/Push (gewählt); Rücklauf-Uhrwerk, Stasis-Hemmung (verworfen bzw. v2).

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
| Prothesen-Arm bleibt optisch immer gleich | Austauschbare Arm-Meshes wären zu viel Arbeit; Module sind reine Fähigkeiten (Gameplay, VFX), der Arm interagiert wie er ist mit der Welt | — Pending |
| Charakter wird später in Meshy finalisiert | Aktuelles Modell ist Platzhalter, Feinschliff später | — Pending |
| KayKit-Animationen (Rig_Medium) auf den Meshy-Charakter | Starre Segmente wie bei KayKit, keine eigenen Animationen; Movement nur, was das Kit hergibt (inkl. Schnitte/Kombinationen) | — Pending |
| Türkis = interaktiv, zweite Akzentfarbe für Deko | Lesbarkeit von Interagierbarem; Farbe (Vorschlag Bernstein) im Stil-Vertrag Phase 1 | — Pending |
| 3–5 Lebenspunkte | Klare Fehlerkonsequenz im Bosskampf | — Pending |
| Vertical-MVP-Roadmap | Jede Phase liefert etwas Spielbares | — Pending |
| Zwei Gruppen: A Prototyp (Prototype Bits + KayKit-Mannequin, ohne Partikel/Juice) bis alle Mechaniken stimmen, dann B Produktion (Held, Assets/Welt, Juice + Politur, Controller, Audio, Release) | Mechaniken zuerst sauber, dann Look und Gefühl | — Pending |
| Keine Juice-Stufen oder -Schalter | Eine feste, kräftige Juice-Stufe; Fokus auf Polish am Ende | — Pending |
| Git: Arbeit auf `dev`, nach jeder erfolgreichen Phase Merge nach `main` + Push | `main` enthält nur fertige Phasen | — Pending |

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
*Last updated: 2026-11-02 after roadmap approval*
