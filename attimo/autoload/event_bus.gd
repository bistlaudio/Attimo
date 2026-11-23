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
## Emitted by PlayerController when the aim hold starts (true) or ends (false), once per change (CAM-02). Listeners: CameraRig, the crosshair and the animator.
signal aim_changed(active: bool)
## Emitted by PlayerController when a dash press is refused while aiming (quick 261120-dik, reduced by 261120-ef9): `reason` is &"aim"
## (the only lockout). Once per press, no dash starts and the cooldown and the air dash stay unspent. Listeners: later juice and audio.
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
