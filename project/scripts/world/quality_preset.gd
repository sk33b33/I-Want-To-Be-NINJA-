@tool
class_name QualityPreset
extends Resource
## One graphics preset (Phase 11). Every heavy feature reads its budget from here, so a tier is
## tuned by editing data/quality/<id>.tres — never by code. Targets: LOW = 30 fps on a mid-range
## phone, HIGH = 60 fps on a typical PC (docs/PERFORMANCE.md).

@export var id: StringName = &"high"
@export var display_name: String = "High"

@export_group("Rendering")
## 3D resolution scale (fill rate is the phone bottleneck). 1.0 = native.
@export_range(0.5, 1.0, 0.05) var render_scale: float = 1.0
@export var glow: bool = true
@export var moon_shadows: bool = true
## 1 = one cascade (cheap), 2 = two cascades.
@export_range(1, 2) var shadow_splits: int = 2
@export var shadow_distance: float = 55.0
## Small lights (shrines, lanterns, glows) fade out beyond this distance.
@export var light_fade_distance: float = 45.0

## Sky reflections (the sky radiance cubemap). Off on phones: re-baking it is heavy GPU work.
@export var sky_reflections: bool = true
## Lightning also brightens the sky shader (changing the sky re-bakes its radiance). Without it,
## lightning still flashes through the moonlight.
@export var sky_flash: bool = true

@export_group("World")
## Multiplies grass/fern/broadleaf/rock/mushroom counts.
@export_range(0.1, 1.0, 0.05) var flora_density: float = 1.0
@export_range(0.1, 1.0, 0.05) var tree_density: float = 1.0
## Multiplies flora draw distances.
@export_range(0.3, 1.0, 0.05) var draw_distance_scale: float = 1.0
## Terrain render mesh uses every Nth height sample (collision always uses all of them).
@export_range(1, 4) var terrain_mesh_step: int = 1
@export_range(0.0, 1.0, 0.05) var mist_scale: float = 1.0

@export_group("Effects")
@export_range(0.0, 1.0, 0.05) var rain_scale: float = 1.0
## Multiplies particle bursts (hit sparks, dust).
@export_range(0.0, 1.0, 0.05) var particle_scale: float = 1.0
## Extra flash lights on lightning strikes etc.
@export var effect_lights: bool = true

@export_group("Surfaces")
## Normal maps on the CC0-textured ground, rock and stone (global shader uniform
## `detail_normals`). Off on Low: the bumps cost a few texture reads per pixel.
@export var detail_normals: bool = true
## A second, larger ground-texture sample that hides tiling (global uniform `anti_tile`).
@export var anti_tile: bool = true
## Leaf-spray cards around tree canopies (alpha-tested; extra overdraw). Off on Low.
@export var leaf_cards: bool = true
