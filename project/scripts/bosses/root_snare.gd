class_name RootSnare
extends Node3D
## One Root Snare circle: a green glowing ring warns for the telegraph time, then thorned roots
## erupt and hurt anyone still inside. Spawned by Kurogale; frees itself afterwards.

var owner_boss: Node3D

var _telegraph: float = 1.0
var _active: float = 0.4
var _t: float = 0.0
var _phase: int = 0  # 0 warning, 1 erupting, 2 fading
var _info: DamageInfo

@onready var _ring: GeometryInstance3D = $Ring
@onready var _roots: Node3D = $Roots
@onready var _hitbox: Hitbox = $Hitbox


func _ready() -> void:
	add_to_group("root_snares")
	_roots.scale = Vector3(1, 0.01, 1)
	_roots.visible = false


func setup(boss: Node3D, telegraph: float, active: float, damage: float, knockback: float) -> void:
	owner_boss = boss
	_telegraph = telegraph
	_active = active
	_info = DamageInfo.new()
	_info.amount = damage
	_info.knockback = knockback
	_info.stagger = 100.0
	_info.element = &"nature"
	_info.source = self
	_info.attack_name = &"root_snare"


func is_warning() -> bool:
	return _phase == 0


func _physics_process(delta: float) -> void:
	_t += delta
	match _phase:
		0:
			_ring.set_instance_shader_parameter("intensity", clampf(_t / _telegraph, 0.2, 1.0))
			if _t >= _telegraph:
				_phase = 1
				_t = 0.0
				_roots.visible = true
				_hitbox.activate(_info)
		1:
			_roots.scale = Vector3(1, clampf(_t / 0.12, 0.01, 1.0), 1)
			if _t >= _active:
				_hitbox.deactivate()
				_phase = 2
				_t = 0.0
		2:
			_ring.visible = false
			_roots.scale = Vector3(1, maxf(1.0 - _t / 0.6, 0.01), 1)
			if _t >= 0.6:
				queue_free()
