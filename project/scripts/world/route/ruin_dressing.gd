class_name RuinDressing
extends Resource
## Art pass 5B: which CC0 ruin models (assets/models/cc0/ruins, ledger) dress a jungle's long route,
## and how. Data only; RouteBuilder places them. Props are visual (no collision), so they can
## never change a bot path or a jump. Written by tools/apply_ruin_dressing.gd.

## Standing / fallen ruins scattered beside the route (picked at random, heavy ones skipped per tier).
@export var scatter_models: Array[PackedScene] = []
## A pair flanks every checkpoint shrine.
@export var shrine_pillar: PackedScene
## Stands over the start of the route.
@export var gate_arch: PackedScene
## Metres between scatter spots along the waypoint lines, and the side distance range.
@export var spacing: float = 8.0
@export var side_min: float = 8.0
@export var side_max: float = 14.0
## Overall prop height range scale (models are 1 unit = 1 m as authored).
@export var scale_range: Vector2 = Vector2(0.9, 1.4)
@export var seed_value: int = 1
