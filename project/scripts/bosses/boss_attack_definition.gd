class_name BossAttackDefinition
extends Resource
## One boss attack's numbers (docs/GAME_DESIGN.md "Boss mechanics"). Behaviour per id lives in
## the boss script; timings, damage and selection rules live here.

@export var id: StringName
@export var display_name: String = ""
## Warning time before the attack becomes dangerous (generous for a prototype).
@export var telegraph_time: float = 1.0
@export var active_time: float = 0.4
## Punish window after the attack.
@export var recovery_time: float = 1.0
@export var damage: float = 20.0
@export var knockback: float = 6.0
## Movement speed during the active part (used by charges).
@export var move_speed: float = 0.0
## The boss picks this attack only when the player is within [min_range, max_range].
@export var min_range: float = 0.0
@export var max_range: float = 6.0
## Relative chance among the valid attacks.
@export var weight: float = 1.0
## Seconds before this attack can be used again.
@export var cooldown: float = 2.0
@export var enraged_only: bool = false
## How to avoid it (shown in docs/tests; kept with the data so it is never forgotten).
@export var counterplay: String = ""
