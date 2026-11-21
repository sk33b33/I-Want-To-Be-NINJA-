class_name BatFlock
extends MultiMeshInstance3D
## A flock of bats circling a point on wobbling orbits. One MultiMesh = one draw call;
## wing flapping happens in creature.gdshader.

var _orbits: Array[Dictionary] = []
var _time: float = 0.0


func setup(mesh: Mesh, count: int, radius_range: Vector2, speed_range: Vector2, rng: RandomNumberGenerator) -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in count:
		_orbits.append({
			"radius": rng.randf_range(radius_range.x, radius_range.y),
			"speed": rng.randf_range(speed_range.x, speed_range.y) * (1.0 if rng.randf() < 0.8 else -1.0),
			"phase": rng.randf() * TAU,
			"height": rng.randf_range(-3.0, 3.0),
			"bob": rng.randf_range(0.5, 2.0),
			"scale": rng.randf_range(0.8, 1.4),
		})
	_update(0.0)


func _process(delta: float) -> void:
	_time += delta
	_update(_time)


func _update(t: float) -> void:
	for i in _orbits.size():
		var o: Dictionary = _orbits[i]
		var r: float = o["radius"]
		var ang: float = o["phase"] + t * float(o["speed"]) / r
		var wobble := sin(t * 0.7 + float(o["phase"])) * 2.0
		var pos := Vector3(cos(ang) * (r + wobble), float(o["height"]) + sin(t * 1.3 + float(o["phase"])) * float(o["bob"]), sin(ang) * (r + wobble))
		# Face along the orbit tangent (bat mesh faces -Z).
		var dir := Vector3(-sin(ang), 0.0, cos(ang)) * signf(o["speed"])
		var basis := Basis.looking_at(dir, Vector3.UP).scaled(Vector3.ONE * float(o["scale"]))
		multimesh.set_instance_transform(i, Transform3D(basis, pos))
