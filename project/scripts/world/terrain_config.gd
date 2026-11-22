class_name TerrainConfig
extends Resource
## Data for a procedurally sculpted biome terrain (heightmap + collision).
## The walkable route is a flat corridor (height `route_height`) so traversal stays predictable;
## everything outside it is hills, cliffs and a map-wide gorge.

@export_group("Extent")
## Minimum X/Z corner of the terrain in world metres.
@export var min_corner: Vector2 = Vector2(-80, -150)
## Maximum X/Z corner of the terrain in world metres.
@export var max_corner: Vector2 = Vector2(80, 35)
## Metres between heightmap vertices. 1.0 keeps cliffs sharp and stays cheap on phones.
@export var cell_size: float = 1.0
@export var seed: int = 1337

@export_group("Route corridor")
## Polyline segments (pairs of X/Z points) the corridor follows.
@export var route_points: PackedVector2Array = PackedVector2Array([
	Vector2(0, 30), Vector2(0, -50), Vector2(0, -71), Vector2(0, -130)])
## Circular flat clearings: x, z, radius (one Vector3 each).
@export var clearings: Array[Vector3] = [
	Vector3(0, 0, 11), Vector3(-9, -8, 7), Vector3(10, -16, 10), Vector3(0, -30, 9), Vector3(0, -46, 12), Vector3(0, -84, 15), Vector3(0, -120, 18), Vector3(-24, -22, 9)]
@export var route_height: float = 0.0
## Half width of the perfectly flat part of the corridor.
@export var corridor_half_width: float = 6.0
## Distance over which the corridor blends into the wild terrain.
@export var corridor_blend: float = 10.0

@export_group("Hills")
@export var hill_height: float = 5.0
@export var hill_frequency: float = 0.025
## Extra height that builds up with distance from the route (walls in the valley).
@export var valley_wall_height: float = 16.0
@export var valley_wall_distance: float = 40.0
@export var detail_height: float = 0.5
@export var detail_frequency: float = 0.18
## Height of the cliffs that ring the playable map.
@export var border_height: float = 30.0
@export var border_width: float = 14.0

@export_group("Stream")
@export var stream_z: float = -40.0
@export var stream_half_width: float = 2.5
@export var stream_depth: float = 0.7

@export_group("Gorge")
## Z range (exclusive) of the map-wide gorge the pit jumps cross. Its floor is below the kill height.
@export var gorge_start_z: float = -50.0
@export var gorge_end_z: float = -71.0
@export var gorge_depth: float = -40.0
