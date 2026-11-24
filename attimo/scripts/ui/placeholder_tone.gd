class_name PlaceholderTone
extends AudioStreamPlayer
## A generator sine tone for placeholder audio: a hum that can rise in pitch and short beeps for tells. PLACEHOLDER ONLY: real
## audio is Phase 14. It is shared by the Loader hum (plan 05-02), the Moto Perpetuo tell (05-03) and the full-charge tell (05-04).
## It needs no audio files. On a driver without a playback (the headless dummy driver) every call is a silent no-op, and the node
## stops playing as soon as nothing sounds.

const MIX_RATE: float = 22050.0
const BUFFER_SECONDS: float = 0.1
## Linear amplitude of the sine at 0 dB.
const AMPLITUDE: float = 0.5

var _humming: bool = false
var _hum_pitch: float = 110.0
var _hum_db: float = -18.0
var _beep_pitch: float = 440.0
var _beep_left: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = BUFFER_SECONDS
	stream = generator


## True while a hum or a beep is sounding.
func sounding() -> bool:
	return _humming or _beep_left > 0.0


## Starts or retunes the hum: `pitch_hz` is the sine frequency, `volume_db` its level. Non-finite values are ignored.
func set_hum(pitch_hz: float, volume_db: float) -> void:
	if not is_finite(pitch_hz) or not is_finite(volume_db) or pitch_hz <= 0.0:
		return
	_hum_pitch = pitch_hz
	_hum_db = volume_db
	_humming = true
	_ensure_playing()


func stop_hum() -> void:
	_humming = false


## A short tell: a sine of `pitch_hz` for `seconds` (at the hum level).
func beep(pitch_hz: float, seconds: float) -> void:
	if not is_finite(pitch_hz) or not is_finite(seconds) or pitch_hz <= 0.0 or seconds <= 0.0:
		return
	_beep_pitch = pitch_hz
	_beep_left = seconds
	_ensure_playing()


func _ensure_playing() -> void:
	if is_inside_tree() and not playing:
		play()


func _process(delta: float) -> void:
	if not playing:
		return
	if not sounding():
		stop()
		return
	var playback: AudioStreamGeneratorPlayback = get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var pitch: float = _hum_pitch if _humming else _beep_pitch
	var level: float = AMPLITUDE * db_to_linear(_hum_db)
	var frames: int = playback.get_frames_available()
	var step: float = TAU * pitch / MIX_RATE
	for _i: int in frames:
		playback.push_frame(Vector2.ONE * (sin(_phase) * level))
		_phase = fmod(_phase + step, TAU)
	if not _humming:
		_beep_left = maxf(_beep_left - TimeFx.unscaled(delta), 0.0)
