class_name TimeOfDay
extends Resource
## Phase 13 part 4: a time of day, layered on the jungle's JungleMood ONCE at expedition load
## (never per frame). Colours multiply the mood's; the sun's height and direction are absolute.
## Every time of day must stay readable (the owner found the jungles too dark): night is
## moonlit blue, not darker overall (exposure compensates).

@export var id: StringName = &"day"
@export var display_name: String = "Day"
## Sun/moon height above the horizon (degrees; < 0 = keep the jungle's own) and turn from the
## jungle's own sun direction.
@export var sun_elevation: float = -1.0
@export var sun_turn: float = 0.0
@export var sun_color: Color = Color(1, 1, 1)
@export var sun_energy: float = 1.0
@export var ambient_color: Color = Color(1, 1, 1)
@export var ambient_energy: float = 1.0
@export var exposure: float = 1.0
@export var fog_color: Color = Color(1, 1, 1)
@export_group("Sky")
## Multiply the sky shader's colours (sky_gloom: zenith, horizon, glow_tint).
@export var sky_zenith: Color = Color(1, 1, 1)
@export var sky_horizon: Color = Color(1, 1, 1)
@export var sky_glow: Color = Color(1, 1, 1)
