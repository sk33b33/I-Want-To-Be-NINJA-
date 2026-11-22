class_name SinkingRaft
extends AnimatableBody3D
## A floating reed raft on the deep bog (Moonfen). It holds you up, but it sinks while you stand
## on it and goes under after `hold_time` — keep moving. It floats back up once you step off.
## Different from Emberwild's timed stones: here YOUR weight is the clock.

@export var hold_time: float = 1.6
@export var sink_depth: float = 2.2
## Speed it floats back up (fraction of the full sink per second).
@export var rise_rate: float = 0.5

var _top: Vector3
var _sink: float = 0.0  # 0 = floating, 1 = fully under.
var _riders: int = 0

@onready var _mesh: GeometryInstance3D = get_node_or_null("Mesh") as GeometryInstance3D


func _ready() -> void:
	add_to_group("sinking_rafts")
	_top = position
	var trig := get_node_or_null("Trigger") as Area3D
	if trig:
		trig.collision_layer = 0
		trig.collision_mask = 2
		trig.body_entered.connect(func(b: Node3D) -> void:
			if b is PlayerController: _riders += 1)
		trig.body_exited.connect(func(b: Node3D) -> void:
			if b is PlayerController: _riders = maxi(_riders - 1, 0))


func is_ridden() -> bool:
	return _riders > 0


## 0 = floating at the surface, 1 = fully under.
func sink_amount() -> float:
	return _sink


func _physics_process(delta: float) -> void:
	if _riders > 0:
		_sink = minf(_sink + delta / hold_time, 1.0)
	else:
		_sink = maxf(_sink - delta * rise_rate, 0.0)
	# Sinks slowly at first, then quickly: the last moment is the warning.
	var depth := sink_depth * (_sink * _sink if _sink < 0.75 else _sink)
	position = _top + Vector3.DOWN * depth
	if _mesh:
		_mesh.set_instance_shader_parameter("rune_glow", _sink)
