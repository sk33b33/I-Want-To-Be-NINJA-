class_name RouteLayout
extends Resource
## A jungle's long-route sections (Phase 13, owner: "the path is too short — make it ~3x longer
## and harder"): pieces built by RouteBuilder, the new spawn, and the bot paths the gate tests
## follow (each a list of waypoints; a waypoint with w = 1 is a take-off point: jump there).
## data/routes/<biome>.tres, written by tools/generate_routes.gd.

@export var biome_id: StringName
@export var spawn: Vector3 = Vector3(0, 0.1, 250)
@export var pieces: Array[RoutePiece] = []
## Named bot paths: "safe" (long way, enemies) and "risky" (short way, hazards), each from the
## spawn to the start of the original route (z ~ 5). Vector4(x, y, z, jump).
@export var bot_paths: Dictionary = {}
