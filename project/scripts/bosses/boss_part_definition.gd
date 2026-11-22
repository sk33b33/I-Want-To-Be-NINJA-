class_name BossPartDefinition
extends Resource
## A breakable boss part (docs/GAME_DESIGN.md: "Parts have independent health thresholds,
## hit zones, and reward definitions").

@export var id: StringName
@export var display_name: String = ""
## Damage the part must take (from hits on its hurtbox) before it breaks.
@export var break_health: float = 200.0
@export var reward: ItemDefinition
@export var reward_count: int = 1
## Long stagger when it breaks (a reward moment for the player).
@export var break_stagger_time: float = 2.0
