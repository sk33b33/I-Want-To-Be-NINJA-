class_name StormCaller
extends Area3D
## An exposed stretch of mountain under the storm (Stormcrag): while the hunter is inside and not
## under a shelter, lightning picks the spot they stand on every `interval` seconds — a ring
## warns for `telegraph` seconds, then the bolt falls. Keep moving or duck under an overhang.
## Dodge i-frames work (HealthComponent.invulnerable).

signal struck(at: Vector3, hit: bool)

@export var interval: float = 2.6
@export var telegraph: float = 1.2
@export var radius: float = 1.8
@export var damage: float = 18.0
@export var warning_material: Material
@export var bolt_material: Material

var _player: PlayerController
var _t: float = 0.0
## Pending strikes: [{pos, t, ring, bolt}]
var _strikes: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("storm_callers")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(b: Node3D) -> void:
		if b is PlayerController:
			_player = b
			_t = interval * 0.5)  # First strike comes a little sooner.
	body_exited.connect(func(b: Node3D) -> void:
		if b == _player: _player = null)


## True while the player stands under any StormShelter.
static func is_sheltered(p: PlayerController) -> bool:
	for s in p.get_tree().get_nodes_in_group("storm_shelters"):
		if (s as Area3D).overlaps_body(p):
			return true
	return false


func pending_strikes() -> int:
	return _strikes.size()


func _physics_process(delta: float) -> void:
	if _player and is_instance_valid(_player) and not StormCaller.is_sheltered(_player):
		_t += delta
		if _t >= interval:
			_t = 0.0
			_call_strike(_player.global_position)
	for i in range(_strikes.size() - 1, -1, -1):
		var s := _strikes[i]
		s["t"] = float(s["t"]) + delta
		var t: float = s["t"]
		var ring := s["ring"] as MeshInstance3D
		if t < telegraph:
			ring.set_instance_shader_parameter("intensity", t / telegraph)
			continue
		if not s["fired"]:
			s["fired"] = true
			_fire(s)
		if t > telegraph + 0.25:
			(s["root"] as Node3D).queue_free()
			_strikes.remove_at(i)


func _call_strike(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Strike"
	add_child(root)
	root.global_position = at
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.1, radius * 2.1)
	q.orientation = PlaneMesh.FACE_Y
	q.material = warning_material
	ring.mesh = q
	ring.position.y = 0.08
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var bolt := MeshInstance3D.new()
	var b := QuadMesh.new()
	b.size = Vector2(0.9, 14.0)
	b.center_offset = Vector3(0, 7.0, 0)
	b.material = bolt_material
	bolt.mesh = b
	bolt.visible = false
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bolt)
	bolt.set_instance_shader_parameter("flame_color", Color(0.7, 0.85, 1.0))
	_strikes.append({"root": root, "ring": ring, "bolt": bolt, "t": 0.0, "fired": false, "pos": at})


func _fire(s: Dictionary) -> void:
	var at: Vector3 = s["pos"]
	(s["bolt"] as Node3D).visible = true
	(s["ring"] as Node3D).visible = false
	if QualityProfile.current().effect_lights:
		var flash := OmniLight3D.new()
		flash.light_color = Color(0.75, 0.85, 1.0)
		flash.light_energy = 6.0
		flash.omni_range = 9.0
		flash.position.y = 2.0
		(s["root"] as Node3D).add_child(flash)
	var hit := false
	if _player and is_instance_valid(_player) and _player.combat and _player.combat.health:
		var d := _player.global_position - at
		d.y = 0.0
		if d.length() <= radius and not StormCaller.is_sheltered(_player):
			var info := DamageInfo.new()
			info.amount = damage
			info.element = &"lightning"
			info.attack_name = &"lightning_strike"
			hit = _player.combat.health.apply_damage(info)
			_player.shake_camera(0.4)
	struck.emit(at, hit)
