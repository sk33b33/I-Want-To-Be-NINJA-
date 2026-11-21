class_name FaunaConfig
extends Resource
## Ambient wildlife for a biome. Purely atmospheric in Phase 1 (no combat interaction).

@export var seed: int = 99

@export_group("Bats")
## Each entry: x, height above ground, z of a flock centre.
@export var bat_flocks: Array[Vector3] = [Vector3(0, 14, -60), Vector3(-30, 18, -20), Vector3(25, 16, -90)]
@export var bats_per_flock: int = 14
@export var bat_orbit_radius: Vector2 = Vector2(6, 16)
@export var bat_speed: Vector2 = Vector2(4, 8)

@export_group("Frogs")
@export var frog_count: int = 18
## Frogs hop away when the player comes this close.
@export var frog_flee_radius: float = 4.0
@export var frog_hop_distance: float = 1.6
@export var frog_hop_time: float = 0.45

@export_group("Lurker eyes")
@export var lurker_count: int = 10
## Eyes sit this far from the route, in the dark between trees.
@export var lurker_distance: Vector2 = Vector2(14, 30)
## Eyes vanish (and reappear elsewhere later) when the player gets this close.
@export var lurker_vanish_radius: float = 13.0
@export var lurker_glow: Color = Color(1.0, 0.25, 0.08)

@export_group("Fireflies")
@export var firefly_swarms: int = 14
@export var fireflies_per_swarm: int = 22
@export var firefly_color: Color = Color(0.75, 1.0, 0.35)
