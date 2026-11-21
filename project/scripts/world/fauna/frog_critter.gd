class_name FrogCritter
extends MeshInstance3D
## A small frog that sits, breathes, and hops away from the player in short arcs.

var terrain: BiomeTerrain
var player: Node3D
var flee_radius: float = 4.0
var hop_distance: float = 1.6
var hop_time: float = 0.45

var _hop_from: Vector3
var _hop_to: Vector3
var _hop_t: float = -1.0
var _breath: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(global_position)
	_breath = _rng.randf() * TAU


func _process(delta: float) -> void:
	_breath += delta * 3.0
	if _hop_t >= 0.0:
		_hop_t += delta / hop_time
		var t := minf(_hop_t, 1.0)
		var p := _hop_from.lerp(_hop_to, t)
		p.y += sin(t * PI) * 0.5
		global_position = p
		scale = Vector3(0.9, 1.2, 0.9) if t < 0.8 else Vector3.ONE
		if _hop_t >= 1.0:
			_hop_t = -1.0
		return
	scale = Vector3(1.0, 1.0 + sin(_breath) * 0.06, 1.0)
	if player and player.global_position.distance_to(global_position) < flee_radius:
		_start_hop()
	elif _rng.randf() < delta * 0.05:
		_start_hop()  # Occasional idle hop.


func _start_hop() -> void:
	var away := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
	if player:
		away += (global_position - player.global_position) * Vector3(1, 0, 1)
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var target := global_position + away * hop_distance * _rng.randf_range(0.7, 1.3)
	if terrain:
		if terrain.is_in_gorge(target.z, 1.0):
			target = global_position - away * hop_distance
		target.y = terrain.get_height_interpolated(target.x, target.z)
	_hop_from = global_position
	_hop_to = target
	_hop_t = 0.0
	look_at(Vector3(target.x, global_position.y, target.z), Vector3.UP)
