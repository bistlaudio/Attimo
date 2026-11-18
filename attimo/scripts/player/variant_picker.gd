class_name VariantPicker
extends RefCounted
## Picks presentation variants (quick 261118-qi3): a clip at random from a pool without an immediate repeat, the first
## pool whose condition holds, and random delays. Pure logic: no engine nodes and no globals, so the player animator,
## the boss and the mechanisms can share it. Every pool key remembers its own last pick.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Last pick per pool key.
var _last: Dictionary[StringName, StringName] = {}


## `rng_seed` 0 or more gives a reproducible sequence (tests); a negative seed randomizes.
func _init(rng_seed: int = -1) -> void:
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()


## A random option of `options`, never the last pick of `pool` when two or more options exist. &"" for an empty pool.
func pick(pool: StringName, options: Array[StringName]) -> StringName:
	if options.is_empty():
		return &""
	var candidates: Array[StringName] = options
	if options.size() >= 2 and _last.has(pool):
		candidates = []
		for option: StringName in options:
			if option != _last[pool]:
				candidates.append(option)
		if candidates.is_empty():
			candidates = options
	var choice: StringName = candidates[_rng.randi_range(0, candidates.size() - 1)]
	_last[pool] = choice
	return choice


## Picks through pick() from the first branch whose "when" is true. A branch is {"when": bool, "options":
## Array[StringName]}; the branches share the pool key. &"" when no branch is true.
func pick_first(pool: StringName, branches: Array[Dictionary]) -> StringName:
	for branch: Dictionary in branches:
		if bool(branch.get("when", false)):
			var options: Array[StringName] = []
			for option: Variant in branch.get("options", []):
				options.append(StringName(option))
			return pick(pool, options)
	return &""


## A random delay between the two bounds in either order. Non-finite bounds are replaced by the other bound (or 0), so
## the result is always finite.
func delay(min_s: float, max_s: float) -> float:
	var low: float = min_s if is_finite(min_s) else (max_s if is_finite(max_s) else 0.0)
	var high: float = max_s if is_finite(max_s) else low
	if low > high:
		var swap: float = low
		low = high
		high = swap
	return _rng.randf_range(low, high)
