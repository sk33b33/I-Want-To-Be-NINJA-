class_name RoutePiece
extends Resource
## One piece of a long route (Phase 13): built at load by RouteBuilder from its jungle's
## RouteLayout. Positions are world space (the ground of the route is y = 0).

enum Kind {
	BOX,         ## Solid stone/wood block (platform, beam, wall). `material`: stone/wood/climb/hazard.
	CLIMB,       ## Climbable wall (world + climbable layers, climb material).
	CRUMBLE,     ## CrumblePlatform scene: shakes, falls, re-forms.
	SINK_STONE,  ## SinkingStone scene: sinks on a rhythm (`phase`).
	RAFT,        ## SinkingRaft scene: sinks under your weight.
	VENT,        ## FireVent scene: warns, then erupts (`phase`).
	LAVA,        ## LavaZone (`size`) + molten surface: burns and returns you to a checkpoint.
	BOG,         ## LavaZone with element water + bog surface (deep water).
	POISON,      ## Poison pool (SurfaceZone: slow + poison damage), `size.x` = radius.
	BRAMBLE,     ## Thorn bramble (SurfaceZone: slow + nature damage), `size` = box.
	GUST,        ## GustZone (`size`), alternating sideways gusts with chevron warnings.
	STORM,       ## StormCaller (`size`): lightning that targets where you stand.
	ENEMY,       ## `count` Thornlings around `position`.
	CHECKPOINT,  ## Checkpoint shrine (falls and deaths come back here).
	PICKUP,      ## A gatherable (`item`: pickup scene id, e.g. "ruin_shard").
	LANTERN,     ## A glowing marker post (shows the way at forks).
}

@export var kind: Kind = Kind.BOX
@export var position: Vector3 = Vector3.ZERO
@export var size: Vector3 = Vector3(3, 1, 3)
@export var rotation_y: float = 0.0
## BOX: "stone", "wood" or "climb" (the jungle's materials, see RouteBuilder).
@export var material: String = "stone"
## Timing offset for rhythmic hazards (vents, sinking stones, gusts).
@export var phase: float = 0.0
@export var count: int = 1
@export var item: String = ""
