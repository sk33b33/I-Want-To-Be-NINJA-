class_name TrailConfig
extends Resource
## Blade slash trail tuning (data/combat/blade_trail.tres). Per-attack width/brightness live on
## AttackDefinition (trail_width, trail_intensity) so light and heavy look different.

## How long a slice of trail stays visible (seconds).
@export var lifetime: float = 0.16
## Start drawing this long before the hit frame, keep drawing this long after the hit window.
@export var lead: float = 0.1
@export var tail: float = 0.08
## Along the blade mesh (metres from the grip): where the ribbon starts (guard) and ends (tip).
@export var base: float = 0.12
@export var tip: float = 0.66
## Opacity at the tip and at the guard (additive, so keep these low).
@export var tip_alpha: float = 0.42
@export var base_alpha: float = 0.06
## Colour for plain blades; forged elemental blades use `element_colors`.
@export var color: Color = Color(0.55, 0.75, 0.95)
@export var element_colors: Dictionary = {&"fire": Color(1.0, 0.5, 0.15), &"water": Color(0.35, 0.7, 1.0),
		&"lightning": Color(0.85, 0.88, 1.0), &"earth": Color(0.95, 0.7, 0.35), &"nature": Color(0.5, 1.0, 0.45)}
## Extra interpolated slices between frames (smooth arcs). LOW quality uses `low_subdivisions`.
@export var subdivisions: int = 3
@export var low_subdivisions: int = 1
