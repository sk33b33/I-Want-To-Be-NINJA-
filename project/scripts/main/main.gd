extends Node3D
## Phase 1 entry scene: places the player at the level's spawn point and wires touch look.

@export var player_path: NodePath = ^"Player"
@export var spawn_point_path: NodePath = ^"Level/SpawnPoint"
@export var touch_controls_path: NodePath = ^"UI/TouchControls"


func _ready() -> void:
	var player := get_node(player_path) as PlayerController
	var spawn := get_node_or_null(spawn_point_path) as Node3D
	if spawn:
		player.global_position = spawn.global_position
		player.set_safe_position(spawn.global_position)
	var rig := player.get_node(player.camera_rig_path) as CameraRig
	if spawn:
		rig.set_yaw(spawn.global_rotation.y)
	rig.snap_to_target()
	var touch := get_node_or_null(touch_controls_path) as TouchControls
	if touch:
		touch.look_dragged.connect(rig.add_touch_look)
