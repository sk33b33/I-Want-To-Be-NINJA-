class_name WeatherDefinition
extends Resource
## Phase 13 part 4: weather for an expedition (Clear / Mist / Rain / Storm), applied once at load
## and, for a mid-hunt turn, in a few steps (ConditionsDirector) — never per frame. Rain and the
## wet look scale with the quality preset (rain_scale); storms add more frequent lightning.

@export var id: StringName = &"clear"
@export var display_name: String = "Clear"
@export var fog_density: float = 1.0
@export var fog_height_density: float = 1.0
@export var fog_color: Color = Color(1, 1, 1)
## 0 = dry, 1 = full rain (RainFX drop count x the preset's rain_scale).
@export var rain: float = 0.0
## Wet, darker, shinier ground and stone (global shader uniform `wetness`, 0..1).
@export var wetness: float = 0.0
## Plant sway (global shader uniform `wind_boost`, 1 = the jungle's own wind).
@export var wind: float = 1.0
## Lightning every x..y seconds; (0, 0) = the jungle's own.
@export var lightning_interval: Vector2 = Vector2.ZERO
## Darkens the sky colours (storm clouds), 1 = unchanged.
@export var sky: float = 1.0
