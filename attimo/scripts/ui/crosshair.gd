class_name Crosshair
extends CanvasLayer
## Aim crosshair (D-15, CAM-02): a small dot with a thin ring at the screen centre, drawn in code (no image asset).
## Hidden at start, shown only while the aim button is held. It only listens to EventBus.aim_changed, gameplay never
## calls it. The ring is reserved for Phase 4: set_locked(true) switches dot and ring to the turquoise lock colour.
## Nothing in Phase 3 locks it. The Reticle child ignores the mouse, so the HUD never eats gameplay or F2 panel clicks.

## Radius of the centre dot in pixels.
@export var dot_radius: float = 2.0
## Radius of the thin ring in pixels.
@export var ring_radius: float = 14.0
## Line width of the ring in pixels.
@export var ring_width: float = 1.5
## Normal colour (cream, the UI accent colour).
@export var color: Color = Color(0.96, 0.93, 0.85, 0.9)
## Lock colour (turquoise, reserved for the Phase 4 target lock).
@export var lock_color: Color = Color(0.25, 0.9, 0.85, 1.0)

## True while the Phase 4 lock colour is shown. Reserved: nothing in this phase sets it.
var locked: bool = false

const RING_POINTS: int = 48

@onready var _reticle: Control = $Reticle


func _ready() -> void:
	visible = false
	_reticle.draw.connect(_draw_reticle)
	EventBus.aim_changed.connect(_on_aim_changed)


## Phase 4 hook: marks the ring as locked (turquoise) or unlocked.
func set_locked(value: bool) -> void:
	locked = value
	_reticle.queue_redraw()


func _on_aim_changed(active: bool) -> void:
	visible = active
	_reticle.queue_redraw()


func _draw_reticle() -> void:
	var centre: Vector2 = _reticle.size * 0.5
	var tint: Color = lock_color if locked else color
	_reticle.draw_circle(centre, dot_radius, tint)
	_reticle.draw_arc(centre, ring_radius, 0.0, TAU, RING_POINTS, tint, ring_width, true)
