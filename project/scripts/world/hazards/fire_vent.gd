class_name FireVent
extends Node3D
## A volcanic vent on a fixed cycle: DORMANT -> WARNING (cracks glow, rumble) -> ERUPT (fire
## column; hurts and knocks back) -> DORMANT. The warning always comes first (readable hazard).

enum Phase { DORMANT, WARNING, ERUPT }

@export var dormant_time: float = 2.6
@export var warning_time: float = 1.2
@export var erupt_time: float = 0.9
## Offset into the cycle (seconds) so neighbouring vents alternate.
@export var phase_offset: float = 0.0
@export var damage: float = 20.0
@export var knockback: float = 7.0

var phase: Phase = Phase.DORMANT

var _t: float = 0.0

@onready var _hitbox: Hitbox = $Hitbox
@onready var _glow: GeometryInstance3D = $Glow
@onready var _column: Node3D = $Column


func _ready() -> void:
	add_to_group("fire_vents")
	_t = fmod(phase_offset, cycle_length())
	_column.visible = false


func cycle_length() -> float:
	return dormant_time + warning_time + erupt_time


## Seconds until the next eruption starts (0 while erupting).
func time_to_eruption() -> float:
	var t := fmod(_t, cycle_length())
	if t < dormant_time + warning_time:
		return dormant_time + warning_time - t
	return 0.0


func is_dangerous() -> bool:
	return phase == Phase.ERUPT


func _physics_process(delta: float) -> void:
	_t = fmod(_t + delta, cycle_length())
	var new_phase := Phase.DORMANT
	if _t >= dormant_time + warning_time:
		new_phase = Phase.ERUPT
	elif _t >= dormant_time:
		new_phase = Phase.WARNING
	if new_phase != phase:
		phase = new_phase
		if phase == Phase.ERUPT:
			var info := DamageInfo.new()
			info.amount = damage
			info.knockback = knockback
			info.stagger = 100.0
			info.element = &"fire"
			info.source = self
			info.attack_name = &"fire_vent"
			_hitbox.activate(info)
		else:
			_hitbox.deactivate()
	var glow := 0.1
	if phase == Phase.WARNING:
		glow = 0.3 + 0.7 * (_t - dormant_time) / warning_time
	elif phase == Phase.ERUPT:
		glow = 1.0
	_glow.set_instance_shader_parameter("intensity", glow)
	_column.visible = phase == Phase.ERUPT
	if _column.visible:
		_column.scale = Vector3(1, clampf((_t - dormant_time - warning_time) / 0.15, 0.05, 1.0), 1)
