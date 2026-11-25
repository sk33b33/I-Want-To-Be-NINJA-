class_name FloraConfig
extends Resource
## How much vegetation, rock and ruin dressing a biome gets. Lower counts for weaker phones.

@export var seed: int = 4242
## Side length of a vegetation chunk (each chunk is culled separately).
@export var chunk_size: float = 25.0

@export_group("Ground cover")
@export var grass_count: int = 9000
@export var fern_count: int = 1800
@export var broadleaf_count: int = 700
@export var mushroom_count: int = 450
@export var rock_count: int = 350
## Distance at which small ground cover stops drawing.
@export var ground_cover_draw_distance: float = 55.0
@export var rock_draw_distance: float = 90.0
## Mushroom cap glow colours (one MultiMesh variant per colour).
@export var mushroom_glows: Array[Color] = [Color(0.15, 0.95, 0.8), Color(1.0, 0.45, 0.12), Color(0.6, 0.25, 1.0)]

@export_group("Trees")
@export var jungle_tree_count: int = 95
@export var dead_tree_count: int = 35
@export var tree_variants: int = 3
## Trees closer than this to the route get trunk collision.
@export var tree_collision_distance: float = 400.0  # Every trunk is solid (30 m left far trees walk-through).
## Keep trunks at least this far from the route centre so the path is never blocked.
@export var tree_route_clearance: float = 9.0

@export_group("Tree models (art pass; CC0 models in assets/models/cc0)")
## Imported tree models for the big jungle trees (empty = the code-built trees). Which ones are used
## depends on the quality tier (QualityPreset.tree_model_max_tris).
@export var tree_models: Array[PackedScene] = []
## One atlas for every model (bark + leaf cards) and the jungle's colour for it.
@export var tree_model_atlas: Texture2D
@export var tree_model_tint: Color = Color(1, 1, 1)
## Every model is scaled to this height (metres) before the per-tree random scale.
@export var tree_model_height: float = 17.0
## Minimum spacing between model trees (their canopies are wider than the code-built ones).
@export var tree_model_spacing: float = 8.0

@export_group("Debris and ruins")
@export var log_count: int = 12
@export var pillar_count: int = 16

@export_group("Low quality (phones) — unused since Phase 11")
## Unused since Phase 11: density/draw distance come from QualityPreset (data/quality/*.tres).
## Kept so existing biome .tres files still load.
@export var low_density_scale: float = 0.4
## Multiplier on ground-cover draw distances on the LOW tier.
@export var low_draw_distance_scale: float = 0.65
## Tree count multiplier on the LOW tier.
@export var low_tree_scale: float = 0.7

@export_group("Placement")
## Plants are denser near the route (where the player looks) and thin out with distance.
@export var near_route_density: float = 1.0
@export var far_density: float = 0.35
@export var density_falloff_start: float = 10.0
@export var density_falloff_end: float = 60.0
## Steepest slope (1 - normal.y) that ground cover may sit on.
@export var max_ground_slope: float = 0.45
