class_name CombatFx
extends Node3D
## Pooled hit feedback: spark burst + floating damage number. Lives in the expedition scene in
## group "combat_fx"; Hurtboxes call spawn_hit(). Small pools keep phones happy.
## Phase 11: particle counts follow QualityPreset.particle_scale, and dust puffs when the ninja
## lands or rolls (CombatFx listens to the player itself).

@export var pool_size: int = 8
@export var spark_material: Material

var _labels: Array[Label3D] = []
var _sparks: Array[CPUParticles3D] = []
var _label_time: Array[float] = []
var _next: int = 0
var spawned: int = 0
var dust_spawned: int = 0
var _dust: Array[CPUParticles3D] = []
var _next_dust: int = 0
const DUST_POOL := 4


func _ready() -> void:
	add_to_group("combat_fx")
	var k := QualityProfile.current().particle_scale
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
		p.amount = maxi(4, int(14 * k))
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
	_build_dust(k)
	_hook_player.call_deferred()


func _build_dust(k: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	for i in DUST_POOL:
		var d := CPUParticles3D.new()
		d.mesh = quad
		d.emitting = false
		d.one_shot = true
		d.amount = maxi(3, int(10 * k))
		d.lifetime = 0.6
		d.explosiveness = 0.9
		d.direction = Vector3.UP
		d.spread = 80.0
		d.initial_velocity_min = 0.8
		d.initial_velocity_max = 2.0
		d.gravity = Vector3(0, -1.0, 0)
		d.scale_amount_min = 0.6
		d.scale_amount_max = 1.4
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.45, 0.42, 0.38, 0.45))
		ramp.set_color(1, Color(0.35, 0.33, 0.3, 0.0))
		d.color_ramp = ramp
		add_child(d)
		_dust.append(d)


func _hook_player() -> void:
	var p := get_tree().get_first_node_in_group("player") as PlayerController
	if p == null:
		return
	p.landed.connect(func() -> void: spawn_dust(p.global_position))
	if p.combat:
		p.combat.dodge_started.connect(func(_d: Vector3) -> void: spawn_dust(p.global_position))


## Ground dust puff (landing, rolling).
func spawn_dust(at: Vector3) -> void:
	dust_spawned += 1
	var d := _dust[_next_dust]
	_next_dust = (_next_dust + 1) % _dust.size()
	d.global_position = at + Vector3.UP * 0.1
	d.restart()
	d.emitting = true


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
