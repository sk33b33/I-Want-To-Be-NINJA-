class_name RouteBuilder
extends Node3D
## Builds a jungle's long-route sections (RouteLayout) when the level loads — before the shader
## warm-up, so every new visual is warmed up — and moves the spawn to the start of the new route.
## One per biome scene (tools/generate_routes.gd). Materials come from the jungle so each long
## route looks like its jungle; hazards reuse the existing hazard scenes and scripts.

const MAT := "res://data/materials/"

@export var layout: RouteLayout
@export var stone_material: Material
@export var climb_material: Material
@export var wood_material: Material
## Art pass 5B: CC0 ruin props beside the route (visual only). Null = data/routes/ruins_<biome>.tres
## when it exists (tools/apply_ruin_dressing.gd), else none.
@export var dressing: RuinDressing
## Where the player starts (moved to layout.spawn); paths relative to this node.
@export var spawn_path: NodePath = ^"../SpawnPoint"
@export var player_path: NodePath = ^"../../Player"

var built: Array[Node] = []


func _ready() -> void:
	add_to_group("route_builder")
	if layout == null:
		return
	CrashReport.note("long route: %s (%d pieces)" % [layout.biome_id, layout.pieces.size()])
	for i in layout.pieces.size():
		var n := _build(layout.pieces[i], i)
		if n:
			add_child(n)
			built.append(n)
	_dress()
	_move_spawn()


func _move_spawn() -> void:
	var spawn := get_node_or_null(spawn_path) as Node3D
	if spawn:
		spawn.position = layout.spawn
	# The player is already in the tree (its _ready runs after the level's), so it starts here and
	# records this as its first safe ground.
	var player := get_node_or_null(player_path) as Node3D
	if player:
		player.global_position = layout.spawn + Vector3.UP * 0.2


func _build(p: RoutePiece, i: int) -> Node:
	var label := "%s%d" % [RoutePiece.Kind.keys()[p.kind].capitalize().replace(" ", ""), i]
	match p.kind:
		RoutePiece.Kind.BOX:
			return _box(label, p, _material(p.material), false)
		RoutePiece.Kind.CLIMB:
			return _box(label, p, climb_material, true)
		RoutePiece.Kind.CRUMBLE:
			return _reskin(_scene("res://scenes/world/crumble_platform.tscn", label, p))
		RoutePiece.Kind.SINK_STONE:
			var s := _reskin(_scene("res://scenes/world/sinking_stone.tscn", label, p))
			s.set("phase_offset", p.phase)
			return s
		RoutePiece.Kind.RAFT:
			return _scene("res://scenes/world/sinking_raft.tscn", label, p)
		RoutePiece.Kind.VENT:
			var v := _scene("res://scenes/world/fire_vent.tscn", label, p)
			v.set("phase_offset", p.phase)
			return v
		RoutePiece.Kind.LAVA:
			return _deadly_pool(label, p, &"fire", &"lava", MAT + "lava.tres")
		RoutePiece.Kind.BOG:
			return _deadly_pool(label, p, &"water", &"deep bog", MAT + "bog_water.tres")
		RoutePiece.Kind.POISON:
			return _poison(label, p)
		RoutePiece.Kind.BRAMBLE:
			return _bramble(label, p)
		RoutePiece.Kind.GUST:
			return _gust(label, p)
		RoutePiece.Kind.STORM:
			return _storm(label, p)
		RoutePiece.Kind.ENEMY:
			return _enemies(label, p)
		RoutePiece.Kind.CHECKPOINT:
			return _scene("res://scenes/world/checkpoint.tscn", label, p)
		RoutePiece.Kind.PICKUP:
			return _scene("res://scenes/world/pickup_%s.tscn" % p.item, label, p)
		RoutePiece.Kind.LANTERN:
			return _lantern(label, p)
	return null


## Crumbling / sinking stones were made for Emberwild (basalt): use this jungle's stone. Basalt
## shaders drive the warning glow (`rune_glow`), so Emberwild keeps its own material.
func _reskin(n: Node3D) -> Node3D:
	if stone_material and Cc0Surfaces.shader_name(stone_material) != "basalt":
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = stone_material
	return n


func _material(key: String) -> Material:
	match key:
		"wood":
			return wood_material
		"climb":
			return climb_material
	return stone_material


func _box(label: String, p: RoutePiece, mat: Material, climbable: bool) -> Node3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1 | (4 if climbable else 0)
	body.collision_mask = 0
	body.position = p.position
	body.rotation.y = deg_to_rad(p.rotation_y)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = p.size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = p.size
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	return body


func _scene(path: String, label: String, p: RoutePiece) -> Node3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	n.name = label
	n.position = p.position
	n.rotation.y = deg_to_rad(p.rotation_y)
	return n


func _zone(label: String, script_path: String, p: RoutePiece, shape: Shape3D) -> Area3D:
	var z := Area3D.new()
	z.name = label
	z.set_script(load(script_path))
	z.position = p.position
	var col := CollisionShape3D.new()
	col.shape = shape
	z.add_child(col)
	return z


func _flat(label: String, size: Vector2, y: float, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = label
	var q := QuadMesh.new()
	q.size = size
	q.orientation = PlaneMesh.FACE_Y
	q.material = load(mat)
	mi.mesh = q
	mi.position.y = y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Lava / deep bog filling a pit: touching it hurts and returns you to the last checkpoint.
func _deadly_pool(label: String, p: RoutePiece, element: StringName, attack: StringName, surface: String) -> Area3D:
	var box := BoxShape3D.new()
	box.size = p.size
	var z := _zone(label, "res://scripts/world/hazards/lava_zone.gd", p, box)
	z.set("element", element)
	z.set("attack_name", attack)
	z.add_child(_flat("Surface", Vector2(p.size.x, p.size.z), p.size.y * 0.5 - 0.3, surface))
	return z


func _poison(label: String, p: RoutePiece) -> Area3D:
	var radius := p.size.x
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 1.2
	var z := _zone(label, "res://scripts/world/hazards/surface_zone.gd", p, cyl)
	z.set("speed_multiplier", 0.8)
	z.set("damage_per_tick", 4.0)
	z.set("element", &"poison")
	z.set("attack_name", &"poison")
	z.add_to_group("poison_pools")
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.04
	cm.radial_segments = 20
	cm.material = load(MAT + "poison.tres")
	mi.mesh = cm
	mi.position.y = -0.52
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	z.add_child(mi)
	var rim := _flat("Rim", Vector2(radius * 2.1, radius * 2.1), -0.48, MAT + "poison_warning.tres")
	rim.set_instance_shader_parameter("intensity", 0.25)
	z.add_child(rim)
	return z


## Thorn bramble: slows and scratches (nature damage). Dark thorns make it readable.
func _bramble(label: String, p: RoutePiece) -> Area3D:
	var box := BoxShape3D.new()
	box.size = Vector3(p.size.x, 1.4, p.size.z)
	var z := _zone(label, "res://scripts/world/hazards/surface_zone.gd", p, box)
	z.set("speed_multiplier", 0.6)
	z.set("damage_per_tick", 2.0)  # 4/s: brushing the brambles on the "safe" path stings, not kills.
	z.set("element", &"nature")
	z.set("attack_name", &"thorns")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(label)
	var thorn := CylinderMesh.new()
	thorn.top_radius = 0.0
	thorn.bottom_radius = 0.07
	thorn.height = 0.9
	thorn.radial_segments = 5
	thorn.material = wood_material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = thorn
	var n := int(p.size.x * p.size.z * 2.0)
	mm.instance_count = n
	for k in n:
		var t := Transform3D(Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(),
				rng.randf_range(0.1, 0.6)), Vector3(rng.randf_range(-0.5, 0.5) * p.size.x, -0.35, rng.randf_range(-0.5, 0.5) * p.size.z))
		mm.set_instance_transform(k, t.scaled_local(Vector3.ONE * rng.randf_range(0.7, 1.3)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Thorns"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	z.add_child(mmi)
	return z


func _gust(label: String, p: RoutePiece) -> Area3D:
	var box := BoxShape3D.new()
	box.size = p.size
	var z := _zone(label, "res://scripts/world/hazards/gust_zone.gd", p, box)
	z.set("traction", 0.35)
	z.set("phase_offset", p.phase)
	var warn := Node3D.new()
	warn.name = "Warning"
	warn.visible = false
	var strips := maxi(2, int(p.size.z / 4.5))
	for k in strips:
		var s := _flat("Strip%d" % k, Vector2(2.0, 4.0), -p.size.y * 0.5 + 0.1, MAT + "gust_warning.tres")
		s.position.z = -p.size.z * 0.5 + (float(k) + 0.5) * p.size.z / strips
		warn.add_child(s)
	z.add_child(warn)
	return z


func _storm(label: String, p: RoutePiece) -> Area3D:
	var box := BoxShape3D.new()
	box.size = p.size
	var z := _zone(label, "res://scripts/world/hazards/storm_caller.gd", p, box)
	z.set("warning_material", load(MAT + "lightning_warning.tres"))
	z.set("bolt_material", load(MAT + "bolt_flame.tres"))
	return z


func _enemies(label: String, p: RoutePiece) -> Node3D:
	var pack := Node3D.new()
	pack.name = label
	pack.position = p.position
	var scene := load("res://scenes/enemies/thornling.tscn") as PackedScene
	for k in p.count:
		var e := scene.instantiate() as Node3D
		e.name = "Thornling%d" % k
		var ang := TAU * float(k) / maxf(p.count, 1)
		e.position = Vector3(cos(ang), 0.3, sin(ang)) * (1.8 if p.count > 1 else 0.0) + Vector3.UP * 0.3
		pack.add_child(e)
	return pack


func _lantern(label: String, p: RoutePiece) -> Node3D:
	var n := Node3D.new()
	n.name = label
	n.position = p.position
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.18, 1.6, 0.18)
	pm.material = wood_material
	post.mesh = pm
	post.position.y = 0.8
	n.add_child(post)
	var flame := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.9)
	q.material = load(MAT + "spirit_flame.tres")
	flame.mesh = q
	flame.position.y = 1.85
	flame.set_script(load("res://scripts/world/instance_tint.gd"))
	flame.set("color", Color(1.0, 0.85, 0.4))
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(flame)
	return n


# ---- Ruin dressing (art pass 5B) -------------------------------------------------------------

## Bakes a ruin model into one mesh standing on y = 0, centred on x/z. Returns {} if it has no
## geometry or is above the tier's triangle cap.
func _bake_ruin(scene: PackedScene, max_tris: int) -> Dictionary:
	var root := scene.instantiate() as Node3D
	var st := SurfaceTool.new()
	var tris := 0
	var parts: Array = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := (root.global_transform.affine_inverse() * m.global_transform) if root.is_inside_tree() else _local_xf(m, root)
		parts.append([m.mesh, xf])
	root.free()
	for part in parts:
		var mesh := part[0] as Mesh
		for s in mesh.get_surface_count():
			tris += mesh.surface_get_array_len(s) / 3 if mesh.surface_get_array_index_len(s) == 0 else mesh.surface_get_array_index_len(s) / 3
	if parts.is_empty() or tris > max_tris:
		return {}
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		st.append_from(part[0] as Mesh, 0, part[1] as Transform3D)
		for s in range(1, (part[0] as Mesh).get_surface_count()):
			st.append_from(part[0] as Mesh, s, part[1] as Transform3D)
	var mesh := st.commit()
	var aabb := mesh.get_aabb()
	var low := aabb.position.y
	var centre := aabb.get_center()
	var baked := SurfaceTool.new()
	baked.begin(Mesh.PRIMITIVE_TRIANGLES)
	baked.append_from(mesh, 0, Transform3D(Basis.IDENTITY, Vector3(-centre.x, -low, -centre.z)))
	var out := baked.commit()
	out.surface_set_material(0, stone_material)
	return {"mesh": out, "tris": tris, "size": aabb.size}


func _local_xf(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _dress() -> void:
	if layout == null or stone_material == null:
		return
	if dressing == null:
		var path := "res://data/routes/ruins_%s.tres" % layout.biome_id
		if ResourceLoader.exists(path):
			dressing = load(path) as RuinDressing
	if dressing == null:
		return
	var preset := QualityProfile.current()
	var max_tris := preset.ruin_prop_max_tris
	var rng := RandomNumberGenerator.new()
	rng.seed = dressing.seed_value
	var kinds: Array[Dictionary] = []
	for sc in dressing.scatter_models:
		var b := _bake_ruin(sc, max_tris)
		if not b.is_empty():
			kinds.append(b)
	var xf: Array = []
	for k in kinds.size():
		xf.append([])
	var terrain := _find_terrain()
	# Pieces to keep clear of (their footprint plus a margin): props are visual but should never hide the route.
	var clear: Array[Rect2] = []
	for p in layout.pieces:
		var half := Vector2(p.size.x, p.size.z) * 0.5 + Vector2.ONE * 3.5
		clear.append(Rect2(Vector2(p.position.x, p.position.z) - half, half * 2.0))
	if not kinds.is_empty():
		for way: String in ["safe", "risky"]:
			var pts: Array = layout.bot_paths.get(way, [])
			for i in range(pts.size() - 1):
				var a := pts[i] as Vector4
				var b := pts[i + 1] as Vector4
				var seg := Vector2(b.x - a.x, b.z - a.z)
				var len := seg.length()
				if len < 1.0:
					continue
				var dir := seg / len
				var side := Vector2(-dir.y, dir.x)
				var d := rng.randf_range(0.0, dressing.spacing)
				while d < len:
					var roll := rng.randf()
					var sgn := -1.0 if rng.randf() < 0.5 else 1.0
					var off := rng.randf_range(dressing.side_min, dressing.side_max) * sgn
					var pos := Vector2(a.x, a.z) + dir * d + side * off
					d += dressing.spacing * rng.randf_range(0.8, 1.3)
					if roll > preset.ruin_density:
						continue
					if not _spot_ok(pos, terrain, clear):
						continue
					var k := rng.randi_range(0, kinds.size() - 1)
					var y := terrain.get_height(pos.x, pos.y) if terrain else 0.0
					var s := rng.randf_range(dressing.scale_range.x, dressing.scale_range.y)
					var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-6.0, 6.0))).scaled(Vector3.ONE * s)
					xf[k].append(Transform3D(basis, Vector3(pos.x, y - 0.15, pos.y)))
	var root := Node3D.new()
	root.name = "RuinDressing"
	add_child(root)
	for k in kinds.size():
		_add_ruin_multimesh(root, "Ruins%d" % k, kinds[k]["mesh"], xf[k])
	# Shrine pillars and the start arch.
	if dressing.shrine_pillar:
		var b := _bake_ruin(dressing.shrine_pillar, max_tris)
		if not b.is_empty():
			var pxf: Array = []
			for p in layout.pieces:
				if p.kind == RoutePiece.Kind.CHECKPOINT:
					for sgn in [-1.0, 1.0]:
						pxf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p.position + Vector3(2.6 * sgn, -0.5, 0.0)))
			_add_ruin_multimesh(root, "ShrinePillars", b["mesh"], pxf)
	if dressing.gate_arch:
		var b := _bake_ruin(dressing.gate_arch, maxi(max_tris, 3000))  # One instance: cheap even on Low.
		if not b.is_empty():
			var width := float((b["size"] as Vector3).x)
			var s := 9.0 / maxf(width, 1.0)
			var at := layout.spawn + Vector3(0, -0.1, -9.0)
			_add_ruin_multimesh(root, "StartArch", b["mesh"], [Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), at)])


func _spot_ok(pos: Vector2, terrain: BiomeTerrain, clear: Array[Rect2]) -> bool:
	if terrain:
		if terrain.is_in_pit(pos.x, pos.y, 4.0) or absf(terrain.get_height(pos.x, pos.y)) > 1.2:
			return false
	for r in clear:
		if r.has_point(pos):
			return false
	return true


func _find_terrain() -> BiomeTerrain:
	var found := owner.find_children("*", "BiomeTerrain", true, false) if owner else []
	if found.is_empty():
		found = get_tree().root.find_children("*", "BiomeTerrain", true, false)
	if found.is_empty():
		return null
	var t := found[0] as BiomeTerrain
	if not t.is_built():
		t.rebuild()
	return t


func _add_ruin_multimesh(parent: Node3D, label: String, mesh: Mesh, xforms: Array) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = label
	mmi.multimesh = mm
	parent.add_child(mmi)
