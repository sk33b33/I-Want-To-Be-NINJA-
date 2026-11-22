class_name SinkingStone
extends AnimatableBody3D
## A basalt stepping stone in the lava river on a fixed cycle:
## UP -> WARNING (glows red and shakes) -> SINKING -> SUNK -> RISING -> UP.
## Standing on it while it sinks drops you into the lava. Time the jumps.

enum Phase { UP, WARNING, SINKING, SUNK, RISING }

@export var up_time: float = 3.0
@export var warning_time: float = 1.0
@export var move_time: float = 0.6
@export var sunk_time: float = 1.6
@export var sink_depth: float = 2.6
@export var phase_offset: float = 0.0

var phase: Phase = Phase.UP

var _t: float = 0.0
var _top: Vector3

@onready var _mesh: GeometryInstance3D = $Mesh


func _ready() -> void:
	add_to_group("sinking_stones")
	_top = position
	_t = fmod(phase_offset, cycle_length())


func cycle_length() -> float:
	return up_time + warning_time + move_time * 2.0 + sunk_time


## True while it is safe to land and stand (up, not yet warning).
func is_safe() -> bool:
	return phase == Phase.UP


## Seconds of safety left (0 when not safe).
func safe_time_left() -> float:
	return up_time - fmod(_t, cycle_length()) if phase == Phase.UP else 0.0


func _physics_process(delta: float) -> void:
	_t = fmod(_t + delta, cycle_length())
	var a := up_time
	var b := a + warning_time
	var c := b + move_time
	var d := c + sunk_time
	var depth := 0.0
	var shake := Vector3.ZERO
	var glow := 0.0
	if _t < a:
		phase = Phase.UP
	elif _t < b:
		phase = Phase.WARNING
		glow = (_t - a) / warning_time
		shake = Vector3(sin(_t * 60.0), 0, cos(_t * 53.0)) * 0.04
	elif _t < c:
		phase = Phase.SINKING
		depth = smoothstep(0.0, 1.0, (_t - b) / move_time)
		glow = 1.0
	elif _t < d:
		phase = Phase.SUNK
		depth = 1.0
	else:
		phase = Phase.RISING
		depth = 1.0 - smoothstep(0.0, 1.0, (_t - d) / move_time)
	position = _top + Vector3.DOWN * sink_depth * depth + shake
	_mesh.set_instance_shader_parameter("rune_glow", glow)
