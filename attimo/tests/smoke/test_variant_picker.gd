extends RefCounted
## Quick 261118-qi3: VariantPicker (res://scripts/player/variant_picker.gd) picks clips at random without an immediate
## repeat per pool, picks from the first true condition branch and rolls finite delays. Pure logic, no scene.
##   P1 a 2-option pool never repeats and returns both
##   P2 a 4-option pool never repeats, returns all four, each 60..140 times in 400 picks
##   P3 a 1-option pool always returns it, an empty pool returns &""
##   P4 the same seed gives the same sequence; pools are keyed independently
##   P5 pick_first respects branch order and returns &"" when no branch is true
##   P6 delay() stays within its bounds, handles swapped bounds and non-finite input

const PICKER_PATH: String = "res://scripts/player/variant_picker.gd"
const SEED: int = 4711
const HIT_POOL: Array[StringName] = [&"Hit_A", &"Hit_B", &"UAL_Hit_Chest", &"UAL_Hit_Head"]


func run(_tree: SceneTree, check: Callable) -> void:
	var script: GDScript = load(PICKER_PATH) as GDScript
	check.call(script != null, "VariantPicker script exists at %s" % PICKER_PATH)
	if script == null:
		return
	_p1(script, check)
	_p2(script, check)
	_p3(script, check)
	_p4(script, check)
	_p5(script, check)
	_p6(script, check)


func _p1(script: GDScript, check: Callable) -> void:
	var picker: RefCounted = script.new(SEED)
	var options: Array[StringName] = [&"Idle_B", &"UAL_Idle_Loop"]
	var previous: StringName = &""
	var repeats: int = 0
	var seen: Dictionary[StringName, int] = {}
	for i: int in 200:
		var pick: StringName = picker.pick(&"idle", options)
		if pick == previous:
			repeats += 1
		previous = pick
		seen[pick] = int(seen.get(pick, 0)) + 1
	check.call(repeats == 0, "P1 a 2-option pool never returns the same clip twice in a row (%d repeats)" % repeats)
	check.call(seen.size() == 2 and seen.has(&"Idle_B") and seen.has(&"UAL_Idle_Loop"), "P1 both options are returned (%s)" % seen)


func _p2(script: GDScript, check: Callable) -> void:
	var picker: RefCounted = script.new(SEED)
	var previous: StringName = &""
	var repeats: int = 0
	var seen: Dictionary[StringName, int] = {}
	for i: int in 400:
		var pick: StringName = picker.pick(&"hit", HIT_POOL)
		if pick == previous:
			repeats += 1
		previous = pick
		seen[pick] = int(seen.get(pick, 0)) + 1
	check.call(repeats == 0, "P2 a 4-option pool never repeats immediately (%d repeats)" % repeats)
	check.call(seen.size() == 4, "P2 all four options are returned (%s)" % seen)
	for option: StringName in HIT_POOL:
		var count: int = int(seen.get(option, 0))
		check.call(count >= 60 and count <= 140, "P2 %s is picked between 60 and 140 times (got %d)" % [option, count])


func _p3(script: GDScript, check: Callable) -> void:
	var picker: RefCounted = script.new(SEED)
	var single: Array[StringName] = [&"Interact"]
	var all_same: bool = true
	for i: int in 10:
		if picker.pick(&"single", single) != &"Interact":
			all_same = false
	check.call(all_same, "P3 a 1-option pool always returns that option")
	var empty: Array[StringName] = []
	check.call(picker.pick(&"empty", empty) == &"", "P3 an empty pool returns &\"\"")


func _p4(script: GDScript, check: Callable) -> void:
	var a: RefCounted = script.new(SEED)
	var b: RefCounted = script.new(SEED)
	var same: bool = true
	for i: int in 50:
		if a.pick(&"hit", HIT_POOL) != b.pick(&"hit", HIT_POOL):
			same = false
	check.call(same, "P4 two pickers with the same seed produce identical sequences")
	# Pool A's last pick must not be excluded from pool B.
	var picker: RefCounted = script.new(SEED)
	var options: Array[StringName] = [&"X", &"Y"]
	var first_a: StringName = picker.pick(&"pool_a", options)
	var b_hits_a_value: bool = false
	for i: int in 40:
		var other: RefCounted = script.new(SEED + i)
		var pick_a: StringName = other.pick(&"pool_a", options)
		var pick_b: StringName = other.pick(&"pool_b", options)
		if pick_b == pick_a:
			b_hits_a_value = true
	check.call(first_a != &"", "P4 pool A returns a pick")
	check.call(b_hits_a_value, "P4 pools are keyed independently (pool B can return pool A's last pick)")


func _p5(script: GDScript, check: Callable) -> void:
	var picker: RefCounted = script.new(SEED)
	var first: Array[Dictionary] = [
		{"when": false, "options": [&"roll"] as Array[StringName]},
		{"when": true, "options": [&"hard"] as Array[StringName]},
		{"when": true, "options": [&"soft"] as Array[StringName]},
	]
	check.call(picker.pick_first(&"land", first) == &"hard", "P5 pick_first returns from the first true branch")
	var order: Array[Dictionary] = [
		{"when": true, "options": [&"roll"] as Array[StringName]},
		{"when": true, "options": [&"hard"] as Array[StringName]},
	]
	check.call(picker.pick_first(&"land", order) == &"roll", "P5 pick_first respects the branch order")
	var none: Array[Dictionary] = [{"when": false, "options": [&"roll"] as Array[StringName]}]
	check.call(picker.pick_first(&"land", none) == &"", "P5 pick_first returns &\"\" when no branch is true")


func _p6(script: GDScript, check: Callable) -> void:
	var picker: RefCounted = script.new(SEED)
	var inside: bool = true
	var swapped_inside: bool = true
	for i: int in 200:
		var value: float = picker.delay(5.0, 8.0)
		if value < 5.0 or value > 8.0:
			inside = false
		var swapped: float = picker.delay(8.0, 5.0)
		if swapped < 5.0 or swapped > 8.0:
			swapped_inside = false
	check.call(inside, "P6 delay(5, 8) stays within [5, 8] over 200 draws")
	check.call(swapped_inside, "P6 delay(8, 5) (swapped bounds) stays within [5, 8]")
	check.call(is_finite(picker.delay(NAN, 8.0)) and is_finite(picker.delay(5.0, INF)) and is_finite(picker.delay(-INF, NAN)), "P6 non-finite bounds return a finite value")
