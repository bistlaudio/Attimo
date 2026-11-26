class_name LoaderProfile
extends RefCounted
## The source of a Loader hold (Phase 05.1, D-04): plain data the LoaderState reads in enter, physics_update and _discharge, so the
## arm, the slingshot cage and the steam cannon share one hold state instead of forking it. ARM is the right-click Loader (the player
## has no profile, PlayerController.loader_profile is null). CAGE is the slingshot core (Catch & launch FREE_AIM): it catches Rino into
## the hold, the throw is a free 2-step flight and spends no energy, and it gives the Loader use back. FIXED is the cannon (Catch & launch FIXED),
## declared here and implemented by plan 05.1-02. Kit blocks build a profile and hand it to PlayerController.catch_into_loader.

enum Source { ARM, CAGE, FIXED }

## Who started the hold.
var source: Source = Source.ARM
## FIXED: the point Rino is pulled to before the throw (world space).
var anchor: Vector3 = Vector3.ZERO
## FIXED: the throw direction (world space, need not be unit length).
var direction: Vector3 = Vector3.ZERO
## FIXED: the throw speed in m/s.
var speed: float = 0.0
## FIXED: the hold time in s before the throw.
var hold: float = 0.0


## A CAGE profile: the throw is a free 2-step Loader flight computed by LoaderState from the MovementConfig Loader fields (D-60).
static func cage() -> LoaderProfile:
	var profile: LoaderProfile = LoaderProfile.new()
	profile.source = Source.CAGE
	return profile


## True when every number is finite and non-negative where it is a speed or a time, and a FIXED profile has a direction (T-05.1-01).
func is_valid() -> bool:
	if not is_finite(speed) or speed < 0.0 or not is_finite(hold) or hold < 0.0:
		return false
	if not anchor.is_finite() or not direction.is_finite():
		return false
	if source == Source.FIXED and direction.length_squared() < 0.0001:
		return false
	return true
