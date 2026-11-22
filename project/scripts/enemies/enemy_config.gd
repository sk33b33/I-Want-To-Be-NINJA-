class_name EnemyConfig
extends Resource
## Tuning for a small jungle beast with one telegraphed lunge (the Thornling, Phase 4).
## Generous telegraph timings by design (docs/GAME_DESIGN.md "Boss mechanics": readable tells).

@export var display_name: String = "Thornling"
@export var max_health: float = 60.0
## Poise: accumulated stagger damage that interrupts the beast (resets after a stagger).
@export var poise: float = 25.0

@export_group("Movement")
@export var move_speed: float = 3.2
@export var turn_sharpness: float = 8.0
## Notices the player within this range...
@export var aggro_range: float = 12.0
## ...and gives up (returns home, heals) beyond this distance from home.
@export var leash_range: float = 22.0
@export var wander_radius: float = 4.0

@export_group("Lunge attack")
## Starts the telegraph when the player is this close.
@export var attack_range: float = 3.6
## Rear-up + red spines + ground warning before the lunge (seconds).
@export var telegraph_time: float = 0.85
## The lunge direction locks this long before the lunge starts (so a late dodge works).
@export var aim_lock_time: float = 0.3
@export var lunge_speed: float = 10.0
@export var lunge_time: float = 0.35
@export var damage: float = 18.0
@export var knockback: float = 7.0
## Vulnerable pause after the lunge (the punish window).
@export var recover_time: float = 1.1
@export var stagger_time: float = 0.6

@export_group("Feedback")
## Knockback taken when staggered (m/s).
@export var stagger_knockback: float = 5.0
@export var death_fade_time: float = 1.2
