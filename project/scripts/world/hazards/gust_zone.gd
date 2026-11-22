class_name GustZone
extends SurfaceZone
## Mountain wind (Stormcrag, Phase 10): calm -> WARNING (chevrons on the ground sweep the way the
## wind will blow) -> GUST (pushes everything in the zone sideways) -> calm. With `alternate`,
## each gust blows the other way. The push goes through SurfaceZone.current, so PlayerController
## handles it like a stream current (on the ground and in the air).

enum Phase { CALM, WARNING, GUST }

@export var calm_time: float = 3.4
@export var warning_time: float = 1.0
@export var gust_time: float = 1.4
## Push during a gust, m/s.
@export var strength: float = 7.0
## Direction of the first gust (flat).
@export var direction: Vector3 = Vector3.RIGHT
@export var alternate: bool = true
@export var phase_offset: float = 0.0

var phase: Phase = Phase.CALM

var _cycle_t: float = 0.0
var _gust_index: int = 0

## Optional "Warning" node whose GeometryInstance3D children are ground chevron strips.
@onready var _warning: Node3D = get_node_or_null("Warning") as Node3D


func _ready() -> void:
	super._ready()
	add_to_group("gust_zones")
	_cycle_t = fmod(phase_offset, cycle_length())
	_apply()


func cycle_length() -> float:
	return calm_time + warning_time + gust_time


## Seconds since the current phase began.
func phase_time() -> float:
	if _cycle_t < calm_time:
		return _cycle_t
	if _cycle_t < calm_time + warning_time:
		return _cycle_t - calm_time
	return _cycle_t - calm_time - warning_time


## Direction of the next (or current) gust.
func gust_direction() -> Vector3:
	var d := Vector3(direction.x, 0.0, direction.z).normalized()
	return -d if alternate and _gust_index % 2 == 1 else d


func _physics_process(delta: float) -> void:
	_cycle_t += delta
	if _cycle_t >= cycle_length():
		_cycle_t = fmod(_cycle_t, cycle_length())
		_gust_index += 1
	_apply()
	super._physics_process(delta)


func _apply() -> void:
	if _cycle_t < calm_time:
		phase = Phase.CALM
	elif _cycle_t < calm_time + warning_time:
		phase = Phase.WARNING
	else:
		phase = Phase.GUST
	current = gust_direction() * strength if phase == Phase.GUST else Vector3.ZERO
	if _warning:
		_warning.visible = phase != Phase.CALM
		var k := 1.0 if phase == Phase.GUST else clampf(phase_time() / warning_time, 0.0, 1.0)
		var d := gust_direction()
		for strip in _warning.get_children():
			var g := strip as GeometryInstance3D
			if g:
				g.set_instance_shader_parameter("intensity", k)
				# A strip's chevrons sweep along its local -Z: face it down-wind.
				g.rotation.y = atan2(-d.x, -d.z)
