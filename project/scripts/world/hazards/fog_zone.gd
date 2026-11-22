class_name FogZone
extends Area3D
## A fog bank (Moonfen): while the hunter is inside, the world fog thickens until only a few
## metres are visible; spirit lanterns along the safe path stay readable through it. The fog
## eases back out when they leave. Purely visual — the danger is what the fog hides.

@export var environment_path: NodePath
@export var fog_density_inside: float = 0.09
## Seconds to blend in/out.
@export var blend_time: float = 1.2

var _env: Environment
var _base_density: float = 0.0
var _inside: int = 0
var _amount: float = 0.0


func _ready() -> void:
	add_to_group("fog_zones")
	collision_layer = 0
	collision_mask = 2
	var we := get_node_or_null(environment_path) as WorldEnvironment
	if we and we.environment:
		_env = we.environment
		_base_density = _env.fog_density
	body_entered.connect(func(b: Node3D) -> void:
		if b is PlayerController: _inside += 1)
	body_exited.connect(func(b: Node3D) -> void:
		if b is PlayerController: _inside = maxi(_inside - 1, 0))


## 0 = clear, 1 = fully inside the bank.
func amount() -> float:
	return _amount


func _physics_process(delta: float) -> void:
	var target := 1.0 if _inside > 0 else 0.0
	_amount = move_toward(_amount, target, delta / maxf(blend_time, 0.01))
	if _env:
		_env.fog_density = lerpf(_base_density, fog_density_inside, _amount)


func _exit_tree() -> void:
	if _env:
		_env.fog_density = _base_density
