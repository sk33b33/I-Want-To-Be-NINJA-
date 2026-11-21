class_name TraversalConfig
extends Resource
## Tunables for ninja traversal (Phase 2): wall climbing, ledge grab, mantle and wall jump.
## Distances are metres measured from the player's feet (the CharacterBody3D origin).

@export_group("Detection")
## Physics layer mask of all solid world geometry (ledges can be grabbed on any of it).
@export_flags_3d_physics var world_mask: int = 1
## Physics layer mask of surfaces the ninja may climb (layer 3 "climbable").
@export_flags_3d_physics var climbable_mask: int = 4
## Height of the chest probe that looks for walls.
@export var chest_height: float = 1.3
## Height of the knee probe (used to detect reaching the top of a wall).
@export var knee_height: float = 0.45
## How far ahead of the body centre walls are detected.
@export var reach: float = 0.8
## Ledges are grabbable when their top is this far above the feet...
@export var ledge_min_above_feet: float = 1.3
## ...up to this far (hands at full stretch).
@export var ledge_max_above_feet: float = 2.3
## Free height required above a ledge to pull up onto it.
@export var ledge_headroom: float = 1.7
## Only grab ledges while rising slower than this (near the jump apex or falling).
@export var ledge_grab_max_up_speed: float = 1.5
## Wall surfaces steeper than this (|normal.y| below) count as walls.
@export var wall_max_normal_y: float = 0.35
## Ledge tops flatter than this (normal.y above) count as standable.
@export var ledge_min_normal_y: float = 0.7
## Seconds after letting go before the ninja can grab again.
@export var regrab_cooldown: float = 0.35
## Body capsule radius (keeps the ninja this far from the wall).
@export var body_radius: float = 0.4

@export_group("Climbing")
@export var climb_up_speed: float = 2.6
@export var climb_down_speed: float = 3.2
@export var climb_side_speed: float = 2.2
## Small force pressing the body into the wall so it stays attached on uneven faces.
@export var wall_stick_speed: float = 1.0
## Input magnitude needed (toward a wall) to attach.
@export var attach_input_threshold: float = 0.3

@export_group("Hang and mantle")
## Feet are this far below the ledge top while hanging (hands on the edge).
@export var hang_feet_below_ledge: float = 1.95
@export var shimmy_speed: float = 1.6
## Seconds to pull up over a ledge.
@export var mantle_time: float = 0.45
## How far past the edge the ninja ends up after mantling.
@export var mantle_forward: float = 0.55

@export_group("Wall jump")
@export var wall_jump_push: float = 6.5
@export var wall_jump_up: float = 7.5
