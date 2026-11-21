class_name PlayerMovementConfig
extends Resource
## Tunable locomotion values for the ninja (Phase 1: run, sprint, jump, fall recovery).
## Edit `res://data/player/default_movement.tres` to tune; do not hard-code values in the controller.

@export_group("Ground")
## Default running speed in m/s. The ninja runs by default; analog sticks scale it down.
@export var run_speed: float = 7.0
## Speed while holding the sprint action.
@export var sprint_speed: float = 11.0
## How fast the ninja reaches target speed on the ground (m/s²).
@export var ground_acceleration: float = 45.0
## How fast the ninja stops when there is no input (m/s²).
@export var ground_deceleration: float = 60.0
## How quickly the body turns to face the move direction (higher = snappier).
@export var turn_sharpness: float = 14.0

@export_group("Air")
## Steering acceleration while airborne (m/s²). No input keeps momentum.
@export var air_acceleration: float = 16.0
## Initial upward velocity of a jump (m/s).
@export var jump_velocity: float = 9.0
## Base gravity (m/s²).
@export var gravity: float = 24.0
## Extra gravity while falling, for a snappier arc.
@export var fall_gravity_multiplier: float = 1.6
## Extra gravity while rising with jump released, for variable jump height.
@export var jump_release_gravity_multiplier: float = 2.2
## Terminal fall speed (m/s).
@export var max_fall_speed: float = 40.0
## Seconds after leaving a ledge during which a jump still works.
@export var coyote_time: float = 0.12
## Seconds a jump press is remembered before landing.
@export var jump_buffer_time: float = 0.12

@export_group("Fall recovery")
## Falling below this world height respawns the ninja at the last safe ground.
@export var kill_height: float = -25.0
## Seconds of continuous grounding before a position counts as "safe".
@export var safe_ground_time: float = 0.25
## Height added to the safe position on respawn so the ninja drops onto it.
@export var respawn_height_offset: float = 0.5
