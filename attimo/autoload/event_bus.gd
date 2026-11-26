extends Node
## Gameplay FACTS only. No state, no logic.
## Gameplay code emits; juice, audio and debug tooling connect (D-10, D-11).

signal jumped(position: Vector3)
signal landed(position: Vector3, impact_speed: float)
signal dash_started(position: Vector3, direction: Vector3, in_air: bool)
signal movement_state_changed(from_state: StringName, to_state: StringName)
## Emitted by the LongJump state on enter. `stage` is the long-jump stage: 1 first dash hop, 2, 3 top of the stack.
signal long_jumped(position: Vector3, stage: int)
## Emitted by PlayerController when the ground-jump chain stage changes: 1..3 for Jump 1, 2, 3 (the pirouette jump), 0 on reset.
signal chain_stage_changed(stage: int)
## Emitted by PlayerController when a dash press is refused: `reason` is the StringName lockout reason (&"energy" for an air dash the
## arm cannot pay, D-12; there is no other lockout). Once per press, no dash starts and the cooldown and the air dash stay
## unspent. Listeners: later juice and audio.
signal dash_blocked(position: Vector3, reason: StringName)
## Emitted by Interactable when a near contact began. `node` is the owner of the Interactable, `kind` is Interactable.KIND_NEAR. Listeners: juice, audio.
signal interactable_triggered(node: Node, kind: int)
## Emitted by Mechanism when its signal changed. `active` is the new signal state. Listeners: juice, audio, the debug event log.
signal mechanism_changed(node: Node, active: bool)
## Emitted by HandController after a module was equipped. Listeners: the HUD (plan 04-02).
signal hand_module_changed(id: StringName)
## Emitted by the near-contact hand (plan 04-02) when contact with a target starts (true) or ends (false). `point` is the contact point.
signal near_contact_changed(active: bool, point: Vector3)
## Emitted by launching mechanisms (plan 04-04) when they throw the player. Listeners: juice, audio.
signal launched(position: Vector3, direction: Vector3, speed: float)
## Emitted by hazards and mechanisms that push the player back (plan 04-04). Listeners: juice, audio.
signal knocked_back(position: Vector3, impulse: Vector3)
## Emitted by PlayerController.refill_air_dash (boost ring, plan 04.1-03) when the air dash was given back. Listeners: juice, audio, the HUD.
signal dash_refilled(position: Vector3)
## Emitted by PlayerController.boost_along (boost ring, bounce pad) with the speed along `direction` after the boost. Listeners: juice, audio.
signal boosted(position: Vector3, direction: Vector3, speed: float)
## Emitted by the WallRun state on enter (MOVE-12, phase 04.1). `normal` is the flat wall normal. Listeners: juice, audio.
signal wall_run_started(position: Vector3, normal: Vector3)
## Emitted by the WallRun state on exit, whatever the reason. Listeners: juice, audio.
signal wall_run_ended(position: Vector3)
## Emitted by the WallJump state on enter; `direction` is the flat kick direction away from the wall. Listeners: juice, audio.
signal wall_jumped(position: Vector3, direction: Vector3)
## Emitted by the Loader state on enter (HAND-04). `stored_speed` is the speed in m/s that was stored, `in_air` is true when the hold hangs
## in the air. Listeners: the Loader presentation (plan 05-02), juice, audio.
signal loader_started(position: Vector3, stored_speed: float, in_air: bool)
## Emitted by the Loader state on the discharge (release or the hold cap). `direction` is the unit discharge direction, `speed` the
## discharge speed in m/s, `bonus` is true when the arm paid a core for the bonus. Listeners: the Loader presentation, juice, audio.
signal loader_released(position: Vector3, direction: Vector3, speed: float, bonus: bool)
## Emitted by ArmEnergy whenever the energy value changed through a spend, a gain or a reset. `value` is the new energy in whole steps, 0 .. 12. Listeners: the HUD.
signal energy_changed(value: int)
## Emitted by ArmEnergy when `amount` whole steps were paid. `reason` names the cost (&"dash", &"air_dash", &"dash_hop", &"wall_run", &"wall_jump", &"loader"). Listeners: the arm cores, juice, audio.
signal energy_spent(amount: int, reason: StringName)
## Emitted when whole steps were earned: by ArmEnergy.tick for each timed step (`source` &"passive" or &"charge") and by the Extractor
## at the end of a run (`amount` is the total of steps, `source` &"extractor").
signal energy_gained(amount: int, source: StringName)
## Emitted by an EnergySource (capsule, broken machine) when its last energy was taken. `position` is where it stands, `amount` the steps it held.
## Listeners: juice, audio, the debug event log.
signal energy_source_emptied(position: Vector3, amount: int)
## Emitted by ArmEnergy.refuse when a move that does not fire (the dash, the air dash, the wall-run start, the wall jump) is refused for lack of
## energy. `reason` names the move, `needed` the steps it would have cost. A base move that falls back never emits it (D-12). Listeners: the arm flicker, audio.
signal energy_refused(reason: StringName, needed: int)
## Emitted by ArmEnergy when Moto Perpetuo turns on (true) or off (false), only on a flip (the off edge has a hysteresis margin). Listeners:
## the arm and body glow, the HUD, juice, audio.
signal moto_changed(active: bool)
