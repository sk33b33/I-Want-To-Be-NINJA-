class_name CombatFx
extends Node3D
## Pooled hit feedback: spark burst + floating damage number. Lives in the expedition scene in
## group "combat_fx"; Hurtboxes call spawn_hit(). Small pools keep phones happy.

@export var pool_size: int = 8
@export var spark_material: Material

var _labels: Array[Label3D] = []
var _sparks: Array[CPUParticles3D] = []
var _label_time: Array[float] = []
var _next: int = 0
var spawned: int = 0


func _ready() -> void:
	add_to_group("combat_fx")
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	quad.material = spark_material
	for i in pool_size:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.font_size = 56
		l.outline_size = 10
		l.pixel_size = 0.006
		l.visible = false
		add_child(l)
		_labels.append(l)
		_label_time.append(0.0)
		var p := CPUParticles3D.new()
		p.mesh = quad
		p.emitting = false
		p.one_shot = true
		p.amount = 14
		p.lifetime = 0.35
		p.explosiveness = 1.0
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 7.0
		p.gravity = Vector3(0, -9, 0)
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.85, 0.5, 1.0))
		ramp.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
		p.color_ramp = ramp
		add_child(p)
		_sparks.append(p)


func spawn_hit(at: Vector3, amount: float, on_player: bool) -> void:
	spawned += 1
	var i := _next
	_next = (_next + 1) % pool_size
	var l := _labels[i]
	l.text = str(int(round(amount)))
	l.modulate = Color(1.0, 0.3, 0.25) if on_player else Color(1.0, 0.92, 0.7)
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.global_position = at + Vector3(randf_range(-0.2, 0.2), 0.6, randf_range(-0.2, 0.2))
	l.visible = true
	_label_time[i] = 0.8
	var p := _sparks[i]
	p.global_position = at
	p.restart()
	p.emitting = true


## Spark burst without a number (talisman explosions and similar).
func spawn_burst(at: Vector3, _color: Color) -> void:
	var p := _sparks[_next]
	_next = (_next + 1) % pool_size
	p.global_position = at
	p.restart()
	p.emitting = true


func _process(delta: float) -> void:
	for i in pool_size:
		if _label_time[i] <= 0.0:
			continue
		_label_time[i] -= delta
		var l := _labels[i]
		l.global_position += Vector3.UP * delta * 1.2
		l.modulate.a = clampf(_label_time[i] / 0.4, 0.0, 1.0)
		if _label_time[i] <= 0.0:
			l.visible = false
