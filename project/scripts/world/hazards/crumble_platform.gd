class_name CrumblePlatform
extends AnimatableBody3D
## Brittle basalt: stepping on it starts a short shake, then it breaks and falls; it reforms
## after `reform_time`. Used for the optional lava-pool shortcut.

enum Phase { SOLID, SHAKING, FALLEN }

@export var shake_time: float = 0.7
@export var reform_time: float = 4.0

var phase: Phase = Phase.SOLID

var _t: float = 0.0
var _home: Vector3

@onready var _trigger: Area3D = $Trigger
@onready var _shape: CollisionShape3D = $Collision


func _ready() -> void:
	add_to_group("crumble_platforms")
	_home = position
	_trigger.collision_layer = 0
	_trigger.collision_mask = 2
	_trigger.body_entered.connect(func(b: Node3D) -> void:
		if b is PlayerController and phase == Phase.SOLID:
			phase = Phase.SHAKING
			_t = 0.0)


func _physics_process(delta: float) -> void:
	_t += delta
	match phase:
		Phase.SHAKING:
			position = _home + Vector3(sin(_t * 70.0), 0, cos(_t * 61.0)) * 0.05
			if _t >= shake_time:
				phase = Phase.FALLEN
				_t = 0.0
				_shape.set_deferred("disabled", true)
		Phase.FALLEN:
			position = _home + Vector3.DOWN * minf(_t * 6.0, 6.0)
			if _t >= reform_time:
				phase = Phase.SOLID
				position = _home
				_shape.set_deferred("disabled", false)
