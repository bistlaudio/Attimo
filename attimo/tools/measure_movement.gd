extends SceneTree
## Editor-time tool (MOVE-10, FEEL-06, D-21, D-22): measures every movement verb of the real Player headless and the
## input latency at 60 and 120 TPS (LatencyProbe), then writes docs/MOVEMENT-METRICS.md.
## Run: bash attimo/tests/run.sh --tool res://tools/measure_movement.gd
## Prints "MEASURE: PASSED" and exits 0, or "MEASURE: FAILED (<reason>)" and exits 1 when a latency median exceeds
## 66 ms, a sample exceeds 100 ms, a tap jump is not lower than a held jump, the long-jump stages 1-3 are not
## ordered by distance and apex, a take-off speed misses its stage row, or any long-jump speed exceeds 22 m/s.
## The work happens in tools/movement_metrics.gd, loaded at run time: this script is compiled before the autoloads
## exist, so it must not name a type that touches EventBus.

const WORKER_PATH: String = "res://tools/movement_metrics.gd"


func _initialize() -> void:
	var script: GDScript = load(WORKER_PATH) as GDScript
	if script == null or not script.can_instantiate():
		print("MEASURE: FAILED (cannot load %s)" % WORKER_PATH)
		quit(1)
		return
	var worker: RefCounted = script.new() as RefCounted
	var failures: PackedStringArray = await worker.call(&"run", self)
	if failures.is_empty():
		print("MEASURE: PASSED")
		quit(0)
	else:
		print("MEASURE: FAILED (%s)" % "; ".join(failures))
		quit(1)
