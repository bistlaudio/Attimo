class_name LoaderLook
extends CanvasLayer
## The "geladen" look of the Loader hold (D-04, HAND-04): a turquoise vignette and a desaturated world ease in over the hold and are
## gone again right after the release, plus a placeholder hum that rises in pitch with the hold. Presentation only: it polls the
## player group (read only) and writes only its own vignette and the Environment adjustment. Everything runs in REAL time
## (TimeFx.unscaled), so the slow motion of the hold does not slow the fade. Group A exception (plan 05-02 objective): these cues
## carry Loader state (the hold is active, how much is stored) at greybox quality; Phase 12 polishes them. Every cue is an export.
## Layer 6 sits below the EnergyHud (9), the Crosshair (10) and the debug overlays (100+), so nothing here covers the HUD.
## Cleanup (T-05-05): the ease-out ends with the Environment's original adjustment state restored exactly (saturation 1.0 and
## adjustment off in the gym), and _exit_tree restores it too, so a freed LoaderLook never leaves the world grey.

## Alpha of the vignette at the screen corners at a full hold.
@export_range(0.0, 1.0, 0.01) var vignette_strength: float = 0.55
## Saturation removed from the world at a full hold: the world runs at 1.0 - desaturation.
@export_range(0.0, 1.0, 0.01) var desaturation: float = 0.55
## Real seconds the cues take to fade in or out; raise it for a softer fade.
@export_range(0.02, 1.0, 0.01) var ease_time: float = 0.12
## The environment whose saturation is lowered. Empty: the first WorldEnvironment of the tree.
@export var world_environment: WorldEnvironment
## Hum pitch in Hz at the start and at the end of the hold, and its level.
@export var hum_pitch_from: float = 110.0
@export var hum_pitch_to: float = 220.0
@export var hum_volume_db: float = -18.0

## 0 .. 1, how far the cues have faded in (eased in real time).
var level: float = 0.0

var _environment: Environment
var _original_enabled: bool = false
var _original_saturation: float = 1.0
var _touched: bool = false

@onready var _vignette: ColorRect = $Vignette
@onready var _hum: PlaceholderTone = $Hum


func _ready() -> void:
	_vignette.visible = false
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var real: float = TimeFx.unscaled(delta)
	var player: PlayerController = get_tree().get_first_node_in_group(&"player") as PlayerController
	var state: LoaderState = null if player == null else player.loader_state()
	var holding: bool = player != null and state != null and player.loader_active()
	var ratio: float = state.hold_ratio() if holding else 0.0
	level = move_toward(level, 1.0 if holding else 0.0, real / maxf(ease_time, 0.001))
	if holding:
		_hum.set_hum(lerpf(hum_pitch_from, hum_pitch_to, ratio), hum_volume_db)
	else:
		_hum.stop_hum()
	_apply(level * (0.5 + 0.5 * ratio if holding else level))


## Writes the vignette and the world saturation for `amount` (0 = off); at 0 the environment is restored exactly.
func _apply(amount: float) -> void:
	if amount <= 0.0001 and level <= 0.0:
		_vignette.visible = false
		_restore()
		return
	_vignette.visible = true
	(_vignette.material as ShaderMaterial).set_shader_parameter(&"strength", vignette_strength * amount)
	var environment: Environment = _find_environment()
	if environment == null:
		return
	if not _touched:
		_touched = true
		_original_enabled = environment.adjustment_enabled
		_original_saturation = environment.adjustment_saturation
	environment.adjustment_enabled = true
	environment.adjustment_saturation = lerpf(_original_saturation, _original_saturation * (1.0 - desaturation), clampf(amount, 0.0, 1.0))


func _restore() -> void:
	if not _touched:
		return
	_touched = false
	if _environment != null:
		_environment.adjustment_saturation = _original_saturation
		_environment.adjustment_enabled = _original_enabled


func _find_environment() -> Environment:
	if _environment != null:
		return _environment
	var holder: WorldEnvironment = world_environment
	if holder == null:
		var found: Array[Node] = get_tree().root.find_children("*", "WorldEnvironment", true, false)
		holder = null if found.is_empty() else found[0] as WorldEnvironment
	_environment = null if holder == null else holder.environment
	return _environment


func _exit_tree() -> void:
	_restore()
