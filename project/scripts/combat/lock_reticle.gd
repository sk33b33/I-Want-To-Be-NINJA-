class_name LockReticle
extends MeshInstance3D
## Shows the lock-on reticle over the player's current lock target.

@export var combat_path: NodePath = ^"../Combat"

var _combat: PlayerCombat


func _ready() -> void:
	top_level = true
	visible = false
	_combat = get_node_or_null(combat_path) as PlayerCombat


func _process(_delta: float) -> void:
	visible = _combat != null and _combat.lock_target != null
	if visible:
		global_position = _combat.get_lock_point()
