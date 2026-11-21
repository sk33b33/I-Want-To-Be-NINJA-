class_name LurkerEyes
extends MeshInstance3D
## Glowing eyes watching from the dark. They track the player, blink, and fade away when the
## player comes close, then reappear somewhere else. Pure atmosphere (an ominous hint of beasts).

signal vanished

var player: Node3D
var vanish_radius: float = 13.0
## Called to pick a new hiding spot: func() -> Vector3
var relocate: Callable

var _visibility: float = 0.0
var _hidden_timer: float = 0.0
var _blink_timer: float = 2.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(global_position)
	_blink_timer = _rng.randf_range(1.0, 5.0)


func _process(delta: float) -> void:
	if _hidden_timer > 0.0:
		_hidden_timer -= delta
		if _hidden_timer <= 0.0 and relocate.is_valid():
			global_position = relocate.call()
		visible = false
		return
	visible = true
	if player == null:
		return
	var to_player := player.global_position + Vector3.UP * 1.2 - global_position
	if to_player.length() < vanish_radius:
		_visibility = maxf(_visibility - delta * 3.0, 0.0)
		if _visibility <= 0.0:
			_hidden_timer = _rng.randf_range(6.0, 15.0)
			vanished.emit()
	else:
		_visibility = minf(_visibility + delta * 0.4, 1.0)
	look_at(global_position - to_player, Vector3.UP)  # Eyes face +Z toward the player.
	_blink_timer -= delta
	var blink := 1.0
	if _blink_timer < 0.15:
		blink = 0.1
		if _blink_timer < 0.0:
			_blink_timer = _rng.randf_range(2.0, 6.0)
	scale = Vector3(1.0, blink * _visibility + 0.001, 1.0)
