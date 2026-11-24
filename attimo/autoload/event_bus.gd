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
## Emitted by the Fernausloeser module on every shot, valid or not (D-06). `size` is a PulseHit.Size, `hit_valid` is true when an
## accepting Interactable was triggered. Listeners: later juice, audio and the debug event log.
signal pulse_fired(origin: Vector3, point: Vector3, size: int, hit_valid: bool)
## Emitted by Interactable when it accepted a hit. `node` is the owner of the Interactable, `kind` a PulseHit.Kind. Listeners: juice, audio.
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
## Emitted by the Capture state on enter (slingshot core, pneumatic tube, phase 04.1). Listeners: juice, audio.
signal capture_started(position: Vector3)
## Emitted by the Capture state when it lets go. `velocity` is the exit velocity (zero after a stuck or time-out release). Listeners: juice, audio.
signal capture_released(position: Vector3, velocity: Vector3)
## Emitted by the Loader state on enter (HAND-04). `stored_speed` is the speed in m/s that was stored, `in_air` is true when the hold hangs
## in the air. Listeners: the Loader presentation (plan 05-02), juice, audio.
signal loader_started(position: Vector3, stored_speed: float, in_air: bool)
## Emitted by the Loader state on the discharge (release or the hold cap). `direction` is the unit discharge direction, `speed` the
## discharge speed in m/s, `bonus` is true when the arm paid a core for the bonus. Listeners: the Loader presentation, juice, audio.
signal loader_released(position: Vector3, direction: Vector3, speed: float, bonus: bool)
## Emitted by ArmEnergy whenever the energy value changed through a discrete spend or reset. `value` is the new energy, 0 .. 100. Listeners: the HUD.
signal energy_changed(value: float)
## Emitted by ArmEnergy when an amount was paid. `reason` names the cost (&"loader" for the Loader bonus). Listeners: the arm cores, juice, audio.
signal energy_spent(amount: float, reason: StringName)
## Emitted by an energy source at the end of a continuous gain (the charge button when it stops; capsules and machines in plan 05-04).
## `amount` is the total gained, `source` names the income. The passive charge never emits it (it would flood the log).
signal energy_gained(amount: float, source: StringName)
## Emitted by ArmEnergy.refuse when a move that does not fire (the air dash, the shot) is refused for lack of energy. `reason` names the
## move, `needed` the energy it would have cost. A base move that falls back never emits it (D-12). Listeners: the arm flicker, audio.
signal energy_refused(reason: StringName, needed: float)
## Emitted by HandController when the shot module becomes usable (true) or unusable (false), once per change and once after an equip.
## Listeners: Interactable glow (stage SHOT_READY), the HUD.
signal shot_ready_changed(ready: bool)
