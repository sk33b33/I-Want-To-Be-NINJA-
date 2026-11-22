class_name Checkpoint
extends Area3D
## A stone shrine whose spirit flame lights up when the ninja passes. Falls respawn the player
## at the most recently activated checkpoint (docs/PHASES.md Phase 2). Facing = node -Z.

signal activated(checkpoint: Checkpoint)

@export var flame_path: NodePath = ^"Flame"
@export var light_path: NodePath = ^"FlameLight"
@export var dormant_color: Color = Color(0.6, 0.12, 0.05)
@export var active_color: Color = Color(0.3, 1.0, 0.9)
@export var dormant_energy: float = 0.4
@export var active_energy: float = 2.2

var is_active: bool = false

var _flame: GeometryInstance3D
var _light: OmniLight3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	monitoring = true
	_flame = get_node_or_null(flame_path) as GeometryInstance3D
	_light = get_node_or_null(light_path) as OmniLight3D
	body_entered.connect(_on_body_entered)
	_apply_visual()


## Respawn transform: slightly in front of the shrine, facing along the route.
func get_respawn_transform() -> Transform3D:
	return Transform3D(global_basis.orthonormalized(), global_position)


func activate(player: PlayerController) -> void:
	player.set_checkpoint(get_respawn_transform())
	if not is_active:
		is_active = true
		# First light of a shrine restores the hunter (a "supply" on the route).
		if player.combat and player.combat.health and not player.combat.health.dead:
			player.combat.health.heal(player.combat.health.max_health)
		_apply_visual()
		activated.emit(self)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		activate(body as PlayerController)


func _apply_visual() -> void:
	var c := active_color if is_active else dormant_color
	if _flame:
		_flame.set_instance_shader_parameter("flame_color", c)
	if _light:
		_light.light_color = c
		_light.light_energy = active_energy if is_active else dormant_energy
