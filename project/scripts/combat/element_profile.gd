class_name ElementProfile
extends Resource
## How much damage each element deals to this creature (docs/CONTENT_MATRIX.md element matrix).
## Per-creature on purpose: bosses can have their own exceptions instead of a universal rule.

@export var affinity: StringName = &""
## Element -> damage multiplier, e.g. {&"fire": 1.5, &"earth": 0.5}. Missing = 1.0 (physical too).
@export var multipliers: Dictionary = {}


func multiplier(element: StringName) -> float:
	if element == &"":
		return 1.0
	return float(multipliers.get(element, 1.0))


func is_weak_to(element: StringName) -> bool:
	return multiplier(element) > 1.0
