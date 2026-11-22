class_name ModuleRegistry
extends Resource
## Explicit list of hand modules (T-04-01: no directory scan, res:// resources only).

@export var modules: Array[HandModuleDef] = []


## The def with `id`, or null.
func find(id: StringName) -> HandModuleDef:
	for def: HandModuleDef in modules:
		if def != null and def.id == id:
			return def
	return null


## All ids in registry order.
func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for def: HandModuleDef in modules:
		if def != null:
			result.append(def.id)
	return result
