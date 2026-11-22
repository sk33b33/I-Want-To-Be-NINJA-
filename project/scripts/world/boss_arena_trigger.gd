class_name BossArenaTrigger
extends Area3D
## Fires `player_entered` once when the player crosses into the boss arena (the
## BossArenaEntered event in docs/GAME_DESIGN.md). Spans the whole arena entrance.

signal player_entered

var triggered: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if triggered or not body is PlayerController:
		return
	triggered = true
	player_entered.emit()
