class_name SecretSite
extends Node3D
## One hidden spirit shrine (Phase 13 part 3), built at load from a SecretDefinition by
## SecretSpots: a climbable pillar or a boulder nook, a floating relic, and a faint spirit beam
## that is visible from afar while the relic is still unfound. Touch the relic to find it:
## ExpeditionManager.find_secret() saves it immediately (kept even if the hunt is lost).

signal found(secret: SecretDefinition)

var secret: SecretDefinition
var secret_set: SecretSet
var relic: Area3D
var beam: Node3D
var taken: bool = false
var _relic_visual: Node3D
var _t: float = 0.0


## Build everything; `ground` is the terrain height at the site.
func build(def: SecretDefinition, set_data: SecretSet, ground: float, climb_material: Material,
		rock_material: Material, beam_material: Material, relic_material: Material, already_found: bool) -> void:
	secret = def
	secret_set = set_data
	name = "Secret_" + String(def.id)
	position = Vector3(def.position.x, ground, def.position.y)
	var relic_height := 1.0
	match def.kind:
		SecretDefinition.Kind.PILLAR:
			_build_pillar(def.height, climb_material)
			relic_height = def.height + 0.9
		SecretDefinition.Kind.NOOK:
			_build_nook(def.gap_direction, rock_material)
			relic_height = 0.9
	relic = Area3D.new()
	relic.name = "Relic"
	relic.collision_layer = 0
	relic.collision_mask = 2  # player
	relic.position = Vector3(0, relic_height, 0)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	shape.shape = sphere
	relic.add_child(shape)
	_relic_visual = MeshInstance3D.new()
	(_relic_visual as MeshInstance3D).mesh = ProceduralMeshes.spirit_relic(relic_material)
	(_relic_visual as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	relic.add_child(_relic_visual)
	add_child(relic)
	relic.body_entered.connect(_on_body_entered)
	beam = Node3D.new()
	beam.name = "SpiritBeam"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 22.0)
	quad.material = beam_material
	for k in 2:  # Two crossed planes read as a column of light.
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation.y = deg_to_rad(90.0 * k)
		mi.position.y = 11.0
		beam.add_child(mi)
	relic.add_child(beam)
	if already_found:
		_mark_found()


func _build_pillar(height: float, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = "Pillar"
	body.collision_layer = 1 | 4  # world + climbable
	body.collision_mask = 0
	# The base goes 1.5 m into the ground so a pillar on a slope never floats.
	var sink := 1.5
	var size := Vector3(1.8, height + sink, 1.8)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = (height - sink) * 0.5
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position.y = (height - sink) * 0.5
	body.add_child(mi)
	add_child(body)


func _build_nook(gap_dir: Vector2, material: Material) -> void:
	var gap := atan2(gap_dir.y, gap_dir.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(secret.id)
	var mesh := ProceduralMeshes.rock(rng, material)
	# Boulders round the ring, leaving a clear ±45° opening at `gap` (about 1.4 m between the two
	# boulders either side of it — a narrow gap a ninja fits through, tested by secrets_test).
	var count := 8
	for i in count:
		var ang := gap + deg_to_rad(45.0) + deg_to_rad(270.0) * float(i) / float(count - 1)
		var r := 3.0
		var body := StaticBody3D.new()
		body.name = "Boulder%d" % i
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		body.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(1.3, 1.5)
		var shape := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.95 * s
		shape.shape = sph
		shape.position.y = 0.5 * s
		body.add_child(shape)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.scale = Vector3(s, s * 1.25, s)
		body.add_child(mi)
		add_child(body)


func _process(delta: float) -> void:
	if _relic_visual == null:
		return
	_t += delta
	if taken:
		_relic_visual.scale = _relic_visual.scale.move_toward(Vector3.ZERO, delta * 3.0)
		return
	_relic_visual.rotation.y += delta * 0.9
	_relic_visual.position.y = sin(_t * 1.8) * 0.12


func _on_body_entered(body: Node3D) -> void:
	if taken or not body is PlayerController:
		return
	var manager := get_tree().get_first_node_in_group("expedition") as ExpeditionManager
	if manager:
		manager.find_secret(secret, secret_set)
	_mark_found()
	found.emit(secret)


## Found (now or in an earlier hunt): the relic fades, the beam goes out, the shrine stays.
func _mark_found() -> void:
	taken = true
	if beam:
		beam.visible = false
	relic.set_deferred("monitoring", false)
