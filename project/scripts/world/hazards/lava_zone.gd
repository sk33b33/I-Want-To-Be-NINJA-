class_name LavaZone
extends Area3D
## Molten lava: touching it burns (fire damage) and throws the hunter back to the last
## checkpoint (Emberwild, docs/GAME_DESIGN.md "lava gaps").

signal burned(player: PlayerController)

@export var damage: float = 25.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player := body as PlayerController
	if player == null:
		return
	var health := player.combat.health if player.combat else null
	if health and not health.dead:
		var info := DamageInfo.new()
		info.amount = damage
		info.element = &"fire"
		info.attack_name = &"lava"
		var was_invulnerable := health.invulnerable
		health.invulnerable = false  # Rolling does not make lava safe.
		health.apply_damage(info)
		health.invulnerable = was_invulnerable
		if health.dead:
			burned.emit(player)
			return
	player.respawn.call_deferred()
	burned.emit(player)
