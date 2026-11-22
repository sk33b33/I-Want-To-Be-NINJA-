class_name AttackDefinition
extends Resource
## One attack: which slice of which animation clip, when it hits, and what the hit does.
## Clip times are seconds into the clip (measured from the hand-speed peaks of the Mixamo clip).

@export var id: StringName
@export var clip: StringName = &"Dual_Weapon_Combo"
@export var clip_start: float = 0.0
@export var clip_end: float = 1.0
## Moment the blade connects (start of the active window).
@export var clip_hit: float = 0.5
## Playback speed (lower = heavier, slower).
@export var speed: float = 1.0
## Seconds (real time) the hitbox stays active from the hit moment.
@export var active_time: float = 0.12
@export var damage: float = 10.0
@export var stagger: float = 10.0
@export var knockback: float = 2.0
## Forward step during the windup (m/s) so attacks close small gaps.
@export var lunge_speed: float = 3.0
## How long before the clip slice ends the next combo input is accepted (and the dodge cancel).
@export var cancel_window: float = 0.25


func windup_seconds() -> float:
	return maxf(clip_hit - clip_start, 0.0) / speed


func total_seconds() -> float:
	return maxf(clip_end - clip_start, 0.01) / speed
