@tool
class_name ProceduralMeshes
extends RefCounted
## Builders for original, low-poly procedural flora/fauna/ruin meshes (no external assets).
## Vertex colour conventions:
##   foliage.gdshader  - rgb = colour, a = wind sway weight (0 root .. 1 tip)
##   glow_fungus       - rgb = glow colour, a = glow amount
##   creature          - r > 0.5 marks flapping wing vertices, a = emissive eyes
## Every builder takes an RNG so variants are deterministic per seed.


# ---------------------------------------------------------------- helpers

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca); st.add_vertex(a)
	st.set_color(cb); st.add_vertex(b)
	st.set_color(cc); st.add_vertex(c)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_tri(st, a, b, c, ca, cb, cc)
	_tri(st, a, c, d, ca, cc, cd)


static func _perp(dir: Vector3) -> Vector3:
	var ref := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT
	return dir.cross(ref).normalized()


## Tube along `spine` with per-point radius. `colors` per spine point.
static func _tube(st: SurfaceTool, spine: PackedVector3Array, radii: PackedFloat32Array,
		colors: PackedColorArray, sides: int, rng: RandomNumberGenerator, wobble: float = 0.0) -> void:
	var rings: Array[PackedVector3Array] = []
	for i in spine.size():
		var dir: Vector3 = (spine[mini(i + 1, spine.size() - 1)] - spine[maxi(i - 1, 0)]).normalized()
		var u := _perp(dir)
		var v := dir.cross(u).normalized()
		var ring := PackedVector3Array()
		for s in sides:
			var ang := TAU * float(s) / sides
			var r := radii[i] * (1.0 + rng.randf_range(-wobble, wobble))
			ring.append(spine[i] + (u * cos(ang) + v * sin(ang)) * r)
		rings.append(ring)
	for i in spine.size() - 1:
		for s in sides:
			var s2 := (s + 1) % sides
			_quad(st, rings[i][s], rings[i][s2], rings[i + 1][s2], rings[i + 1][s],
					colors[i], colors[i], colors[i + 1], colors[i + 1])


## Low-poly blob (lat/long sphere) with jitter. Colour picked per vertex via callback-free gradient.
static func _blob(st: SurfaceTool, center: Vector3, radius: Vector3, rng: RandomNumberGenerator,
		top: Color, bottom: Color, lat: int = 5, lon: int = 8, jitter: float = 0.15) -> void:
	var pts: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	for i in lat + 1:
		var phi := PI * float(i) / lat
		var row := PackedVector3Array()
		var crow := PackedColorArray()
		for j in lon:
			var th := TAU * float(j) / lon
			var n := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var jit := 1.0 + (rng.randf_range(-jitter, jitter) if i > 0 and i < lat else 0.0)
			row.append(center + n * radius * jit)
			crow.append(bottom.lerp(top, n.y * 0.5 + 0.5))
		pts.append(row)
		cols.append(crow)
	for i in lat:
		for j in lon:
			var j2 := (j + 1) % lon
			_quad(st, pts[i][j], pts[i][j2], pts[i + 1][j2], pts[i + 1][j],
					cols[i][j], cols[i][j2], cols[i + 1][j2], cols[i + 1][j])


static func _finish(st: SurfaceTool, mesh: ArrayMesh = null, material: Material = null) -> ArrayMesh:
	st.index()
	st.generate_normals()
	var out := st.commit(mesh)
	if material:
		out.surface_set_material(out.get_surface_count() - 1, material)
	return out


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


# ---------------------------------------------------------------- ground plants

## Clump of curved grass blades.
static func grass_clump(rng: RandomNumberGenerator, material: Material) -> ArrayMesh:
	var st := _begin()
	for b in 7:
		var base := Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
		var h := rng.randf_range(0.35, 0.85)
		var lean := Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))
		var side := _perp(Vector3.UP + lean).normalized() * rng.randf_range(0.03, 0.05)
		var dead := rng.randf() < 0.18
		var root := Color(0.02, 0.04, 0.02, 0.0)
		var tip := Color(0.14, 0.13, 0.06) if dead else Color(0.07, 0.15, 0.06)
		var prev_l := base - side
		var prev_r := base + side
		for seg in 3:
			var t := float(seg + 1) / 3.0
			var p := base + Vector3.UP * h * t + lean * t * t * h
			var w := side * (1.0 - t * 0.85)
			var c0 := root.lerp(tip, float(seg) / 3.0); c0.a = pow(float(seg) / 3.0, 1.5)
			var c1 := root.lerp(tip, t); c1.a = pow(t, 1.5)
			_quad(st, prev_l, prev_r, p + w, p - w, c0, c0, c1, c1)
			prev_l = p - w
			prev_r = p + w
	return _finish(st, null, material)


## Arching fern with saw-toothed fronds.
static func fern(rng: RandomNumberGenerator, material: Material) -> ArrayMesh:
	var st := _begin()
	var fronds := rng.randi_range(7, 10)
	var dark := Color(0.02, 0.05, 0.025, 0.0)
	var light := Color(0.06, 0.13, 0.05)
	for f in fronds:
		var ang := TAU * float(f) / fronds + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var side := dir.cross(Vector3.UP).normalized()
		var length := rng.randf_range(0.8, 1.5)
		var rise := rng.randf_range(0.4, 0.7) * length
		var prev := Vector3.ZERO
		var prev_w := 0.0
		var segs := 10
		for i in segs:
			var t := float(i + 1) / segs
			var p := dir * length * t + Vector3.UP * (sin(t * PI * 0.75) * rise)
			var w := 0.17 * sin(t * PI) * (1.0 if i % 2 == 0 else 0.55)
			var c0 := dark.lerp(light, float(i) / segs); c0.a = float(i) / segs
			var c1 := dark.lerp(light, t); c1.a = t
			_quad(st, prev - side * prev_w, prev + side * prev_w, p + side * w, p - side * w, c0, c0, c1, c1)
			prev = p
			prev_w = w
	return _finish(st, null, material)


## Large drooping "elephant ear" leaves on stems.
static func broadleaf(rng: RandomNumberGenerator, material: Material) -> ArrayMesh:
	var st := _begin()
	var leaves := rng.randi_range(4, 6)
	for l in leaves:
		var ang := TAU * float(l) / leaves + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var stem_top := dir * rng.randf_range(0.3, 0.6) + Vector3.UP * rng.randf_range(0.7, 1.5)
		var stem_c := Color(0.04, 0.08, 0.03, 0.0)
		var stem_c2 := Color(0.04, 0.08, 0.03, 0.4)
		var s := _perp(stem_top) * 0.03
		_quad(st, -s, s, stem_top + s, stem_top - s, stem_c, stem_c, stem_c2, stem_c2)
		# Leaf blade: midrib from stem_top outward and drooping, folded slightly along the rib.
		var length := rng.randf_range(0.8, 1.3)
		var width := length * 0.42
		var side := dir.cross(Vector3.UP).normalized()
		var rib := PackedVector3Array()
		var segs := 6
		for i in segs + 1:
			var t := float(i) / segs
			rib.append(stem_top + dir * length * t + Vector3.UP * (0.25 * sin(t * PI) - 0.45 * t * t) * length)
		var edge_c := Color(0.03, 0.09, 0.04, 0.6)
		var mid_c := Color(0.07, 0.16, 0.06, 0.6)
		for i in segs:
			var t0 := float(i) / segs
			var t1 := float(i + 1) / segs
			var w0 := width * sin(t0 * PI) * (1.0 - t0 * 0.3)
			var w1 := width * sin(t1 * PI) * (1.0 - t1 * 0.3)
			var fold := Vector3.DOWN * 0.08
			for sgn in [-1.0, 1.0]:
				var e0: Vector3 = rib[i] + side * w0 * sgn + fold * w0 / width
				var e1: Vector3 = rib[i + 1] + side * w1 * sgn + fold * w1 / width
				var cm := mid_c; cm.a = 0.4 + t0 * 0.6
				var ce := edge_c; ce.a = 0.4 + t1 * 0.6
				_quad(st, rib[i], rib[i + 1], e1, e0, cm, cm, ce, ce)
	return _finish(st, null, material)


## Cluster of glowing mushrooms. `glow` is the cap emission colour.
static func mushroom_cluster(rng: RandomNumberGenerator, glow: Color, material: Material) -> ArrayMesh:
	var st := _begin()
	var count := rng.randi_range(3, 7)
	for m in count:
		var base := Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))
		var h := rng.randf_range(0.12, 0.45)
		var r := h * rng.randf_range(0.5, 0.8)
		var lean := Vector3(rng.randf_range(-0.08, 0.08), 0.0, rng.randf_range(-0.08, 0.08))
		var stem := Color(0, 0, 0, 0.0)
		_tube(st, PackedVector3Array([base, base + Vector3.UP * h + lean]),
				PackedFloat32Array([r * 0.22, r * 0.16]), PackedColorArray([stem, stem]), 6, rng)
		var cap := glow; cap.a = 1.0
		var cap_dark := glow; cap_dark.a = 0.55
		_blob(st, base + Vector3.UP * h + lean, Vector3(r, r * 0.45, r), rng, cap, cap_dark, 3, 8, 0.05)
	return _finish(st, null, material)


## Mossy boulder.
static func rock(rng: RandomNumberGenerator, material: Material) -> ArrayMesh:
	var st := _begin()
	var scale := Vector3(rng.randf_range(0.8, 1.4), rng.randf_range(0.45, 0.8), rng.randf_range(0.8, 1.3))
	var top := Color(0.11, 0.18, 0.08)
	var bottom := Color(0.2, 0.2, 0.21)
	_blob(st, Vector3(0, scale.y * 0.4, 0), scale, rng, top, bottom, 5, 9, 0.22)
	return _finish(st, null, material)


# ---------------------------------------------------------------- trees

## Giant jungle tree: buttress roots, tall trunk, branches, dark canopy blobs and hanging vines.
## Returns a mesh with surfaces [bark, leaves, vines].
static func jungle_tree(rng: RandomNumberGenerator, bark: Material, leaves: Material, vines: Material) -> ArrayMesh:
	var height := rng.randf_range(15.0, 22.0)
	var r0 := rng.randf_range(0.8, 1.2)
	var bark_c := Color(0.16, 0.12, 0.09)
	var bark_moss := Color(0.09, 0.14, 0.065)
	var st := _begin()
	# Trunk.
	var spine := PackedVector3Array()
	var radii := PackedFloat32Array()
	var cols := PackedColorArray()
	var bend := Vector3(rng.randf_range(-1.5, 1.5), 0.0, rng.randf_range(-1.5, 1.5))
	for i in 9:
		var t := float(i) / 8.0
		spine.append(Vector3.UP * height * t + bend * t * t)
		radii.append(r0 * (1.0 - 0.6 * t))
		cols.append(bark_moss.lerp(bark_c, clampf(t * 3.0, 0.0, 1.0)))
	_tube(st, spine, radii, cols, 9, rng, 0.08)
	# Buttress roots (thin fins).
	var fins := rng.randi_range(4, 6)
	for f in fins:
		var ang := TAU * float(f) / fins + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(ang), 0.0, sin(ang))
		var side := out.cross(Vector3.UP) * 0.12
		var top := out * r0 * 0.7 + Vector3.UP * rng.randf_range(2.0, 3.5)
		var foot := out * rng.randf_range(2.2, 3.4) + Vector3.DOWN * 0.3
		var inner := out * r0 * 0.5 + Vector3.DOWN * 0.3
		for sgn in [-1.0, 1.0]:
			_tri(st, inner + side * sgn, top + side * sgn, foot + side * sgn, bark_moss, bark_c, bark_moss)
		_quad(st, top - side, top + side, foot + side, foot - side, bark_c, bark_c, bark_moss, bark_moss)
	# Branches.
	var canopy_points: Array[Vector3] = [spine[8] + Vector3.UP * 1.0]
	var branch_count := rng.randi_range(3, 5)
	for b in branch_count:
		var t := rng.randf_range(0.55, 0.85)
		var start := Vector3.UP * height * t + bend * t * t
		var ang := TAU * float(b) / branch_count + rng.randf_range(-0.4, 0.4)
		var length := rng.randf_range(4.0, 7.0)
		var end := start + Vector3(cos(ang), rng.randf_range(0.4, 0.8), sin(ang)) * length
		var mid := (start + end) * 0.5 + Vector3.UP * 0.8
		_tube(st, PackedVector3Array([start, mid, end]), PackedFloat32Array([r0 * 0.35, r0 * 0.22, r0 * 0.12]),
				PackedColorArray([bark_c, bark_c, bark_c]), 6, rng)
		canopy_points.append(end)
	var mesh := _finish(st, null, bark)

	# Canopy.
	var leaf_st := _begin()
	var leaf_top := Color(0.05, 0.1, 0.045, 0.12)
	var leaf_bottom := Color(0.012, 0.03, 0.018, 0.05)
	var vine_anchors: Array[Vector3] = []
	for p in canopy_points:
		for k in rng.randi_range(2, 3):
			var c := p + Vector3(rng.randf_range(-2.0, 2.0), rng.randf_range(-0.5, 1.0), rng.randf_range(-2.0, 2.0))
			var rad := rng.randf_range(2.5, 4.2)
			_blob(leaf_st, c, Vector3(rad, rad * 0.5, rad), rng, leaf_top, leaf_bottom, 4, 8, 0.25)
			for v in rng.randi_range(1, 3):
				vine_anchors.append(c + Vector3(rng.randf_range(-rad, rad) * 0.7, -rad * 0.35, rng.randf_range(-rad, rad) * 0.7))
	mesh = _finish(leaf_st, mesh, leaves)

	# Hanging vines.
	var vine_st := _begin()
	for a in vine_anchors:
		var length := rng.randf_range(3.0, 9.0)
		var side := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * 0.06
		var segs := 6
		for i in segs:
			var t0 := float(i) / segs
			var t1 := float(i + 1) / segs
			var p0 := a + Vector3.DOWN * length * t0 + side * sin(t0 * 7.0) * 3.0
			var p1 := a + Vector3.DOWN * length * t1 + side * sin(t1 * 7.0) * 3.0
			var c0 := Color(0.03, 0.06, 0.03, t0 * 0.8)
			var c1 := Color(0.03, 0.06, 0.03, t1 * 0.8)
			_quad(vine_st, p0 - side, p0 + side, p1 + side, p1 - side, c0, c0, c1, c1)
	return _finish(vine_st, mesh, vines)


## Gnarled dead tree: twisting trunk and recursive bare branches with grey hanging moss.
## Returns a mesh with surfaces [bark, moss].
static func dead_tree(rng: RandomNumberGenerator, bark: Material, moss: Material) -> ArrayMesh:
	var st := _begin()
	var moss_anchors: Array[Vector3] = []
	var height := rng.randf_range(8.0, 13.0)
	_dead_branch(st, Vector3.ZERO, Vector3.UP, height, rng.randf_range(0.45, 0.7), 0, rng, moss_anchors)
	var mesh := _finish(st, null, bark)
	var mst := _begin()
	for a in moss_anchors:
		var length := rng.randf_range(0.8, 2.5)
		var side := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * 0.12
		var c0 := Color(0.12, 0.13, 0.11, 0.0)
		var c1 := Color(0.07, 0.08, 0.07, 0.7)
		_quad(mst, a - side, a + side, a + Vector3.DOWN * length + side * 0.3, a + Vector3.DOWN * length - side * 0.3, c0, c0, c1, c1)
	return _finish(mst, mesh, moss)


static func _dead_branch(st: SurfaceTool, start: Vector3, dir: Vector3, length: float, radius: float,
		depth: int, rng: RandomNumberGenerator, moss: Array[Vector3]) -> void:
	var spine := PackedVector3Array()
	var radii := PackedFloat32Array()
	var cols := PackedColorArray()
	var p := start
	var d := dir.normalized()
	var segs := 5
	for i in segs + 1:
		var t := float(i) / segs
		spine.append(p)
		radii.append(radius * (1.0 - 0.75 * t))
		cols.append(Color(0.21, 0.2, 0.18).lerp(Color(0.12, 0.11, 0.1), t))
		d = (d + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.1, 0.2), rng.randf_range(-0.35, 0.35))).normalized()
		p += d * length / segs
	_tube(st, spine, radii, cols, 6 if depth == 0 else 4, rng, 0.1)
	if depth >= 3:
		moss.append(spine[segs])
		return
	var children := rng.randi_range(2, 3)
	for c in children:
		var idx := rng.randi_range(2, segs)
		var nd := (d + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(0.1, 0.8), rng.randf_range(-1.2, 1.2))).normalized()
		_dead_branch(st, spine[idx], nd, length * rng.randf_range(0.45, 0.65), radii[idx] * 0.7, depth + 1, rng, moss)
	if depth >= 1 and rng.randf() < 0.6:
		moss.append(spine[segs / 2])


## Fallen mossy log lying along +X.
static func log_mesh(rng: RandomNumberGenerator, material: Material) -> ArrayMesh:
	var st := _begin()
	var length := rng.randf_range(5.0, 9.0)
	var r := rng.randf_range(0.4, 0.7)
	var spine := PackedVector3Array()
	var radii := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in 6:
		var t := float(i) / 5.0
		spine.append(Vector3(length * (t - 0.5), r * 0.85 + sin(t * 3.0) * 0.1, sin(t * 2.0) * 0.3))
		radii.append(r * (1.0 - 0.25 * t))
		cols.append(Color(0.1, 0.16, 0.07) if i % 2 == 0 else Color(0.15, 0.11, 0.085))
	_tube(st, spine, radii, cols, 8, rng, 0.1)
	return _finish(st, null, material)


# ---------------------------------------------------------------- ruins

## Broken stone pillar, `height` metres, with a jagged top. Collision is a cylinder of `radius`.
static func broken_pillar(rng: RandomNumberGenerator, radius: float, height: float, material: Material) -> ArrayMesh:
	var st := _begin()
	var drums := maxi(2, int(height / 1.2))
	var c := Color(1, 1, 1)
	for d in drums:
		var y0 := height * float(d) / drums
		var y1 := height * float(d + 1) / drums
		var off := Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05))
		var r := radius * rng.randf_range(0.93, 1.0)
		_tube(st, PackedVector3Array([Vector3(0, y0, 0) + off, Vector3(0, y1 - 0.04, 0) + off]),
				PackedFloat32Array([r, r]), PackedColorArray([c, c]), 10, rng)
	# Jagged broken cap.
	var top_y := height
	var centre := Vector3(0, top_y + 0.1, 0)
	for s in 10:
		var a0 := TAU * float(s) / 10
		var a1 := TAU * float(s + 1) / 10
		var p0 := Vector3(cos(a0) * radius, top_y - 0.04 + rng.randf_range(-0.3, 0.2), sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, top_y - 0.04 + rng.randf_range(-0.3, 0.2), sin(a1) * radius)
		_tri(st, centre, p1, p0, c, c, c)
	return _finish(st, null, material)


# ---------------------------------------------------------------- fauna

## Bat: small body + two wings (wing verts tagged COLOR.r = 1 for the flap shader), glowing eyes.
static func bat(material: Material) -> ArrayMesh:
	var st := _begin()
	var body := Color(0, 0, 0, 0)
	var wing := Color(1, 0, 0, 0)
	var eye := Color(0, 0, 0, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_blob(st, Vector3.ZERO, Vector3(0.07, 0.06, 0.14), rng, body, body, 3, 6, 0.0)
	for sgn in [-1.0, 1.0]:
		var root_f := Vector3(0.05 * sgn, 0, -0.06)
		var root_b := Vector3(0.05 * sgn, 0, 0.08)
		var tip := Vector3(0.45 * sgn, 0.02, -0.02)
		var mid_b := Vector3(0.28 * sgn, 0, 0.14)
		_tri(st, root_f, tip, root_b, body, wing, body)
		_tri(st, root_b, tip, mid_b, body, wing, wing)
		_blob(st, Vector3(0.025 * sgn, 0.03, -0.13), Vector3(0.012, 0.012, 0.012), rng, eye, eye, 2, 4, 0.0)
	return _finish(st, null, material)


## Squat jungle frog with faintly glowing eyes. Faces -Z.
static func frog(material: Material) -> ArrayMesh:
	var st := _begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var body := Color(0, 0, 0, 0)
	var eye := Color(0, 0, 0, 1)
	_blob(st, Vector3(0, 0.07, 0), Vector3(0.1, 0.065, 0.13), rng, body, body, 4, 8, 0.05)
	for sgn in [-1.0, 1.0]:
		_blob(st, Vector3(0.05 * sgn, 0.13, -0.08), Vector3(0.025, 0.025, 0.025), rng, eye, eye, 3, 5, 0.0)
		_blob(st, Vector3(0.1 * sgn, 0.03, 0.06), Vector3(0.05, 0.03, 0.07), rng, body, body, 3, 5, 0.0)
	return _finish(st, null, material)


## Pair of glowing eyes (for lurkers in the dark). Eyes are 0.22 m apart, facing -Z.
static func eye_pair(material: Material) -> ArrayMesh:
	var st := _begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var eye := Color(0, 0, 0, 1)
	for sgn in [-1.0, 1.0]:
		_blob(st, Vector3(0.11 * sgn, 0, 0), Vector3(0.05, 0.028, 0.02), rng, eye, eye, 3, 6, 0.0)
	return _finish(st, null, material)


# ---------------------------------------------------------------- combat (Phase 4)

## Thornling: squat thorn-backed beast, ~0.9 m tall, facing -Z. Spines tagged COLOR.g = 1
## (they glow during the attack telegraph), eyes COLOR.a = 1.
static func thornling(material: Material) -> ArrayMesh:
	var st := _begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var body := Color(0, 0, 0, 0)
	var spine := Color(0, 1, 0, 0)
	var eye := Color(0, 0, 0, 1)
	# Body and head.
	_blob(st, Vector3(0, 0.5, 0.05), Vector3(0.42, 0.34, 0.62), rng, body, body, 5, 9, 0.1)
	_blob(st, Vector3(0, 0.52, -0.6), Vector3(0.26, 0.22, 0.3), rng, body, body, 4, 8, 0.08)
	# Tusks.
	for sgn in [-1.0, 1.0]:
		var base := Vector3(0.12 * sgn, 0.42, -0.82)
		_tri(st, base, base + Vector3(0.04 * sgn, 0.0, 0.04), base + Vector3(0.06 * sgn, 0.16, -0.12), body, body, body)
		_blob(st, Vector3(0.11 * sgn, 0.6, -0.84), Vector3(0.035, 0.03, 0.02), rng, eye, eye, 2, 5, 0.0)
	# Legs.
	for lx in [-0.26, 0.26]:
		for lz in [-0.3, 0.35]:
			_tube(st, PackedVector3Array([Vector3(lx, 0.35, lz), Vector3(lx * 1.1, 0.0, lz)]),
					PackedFloat32Array([0.09, 0.06]), PackedColorArray([body, body]), 5, rng)
	# Back spines in rows (the readable silhouette + telegraph glow).
	for i in 9:
		var z := lerpf(-0.45, 0.55, float(i) / 8.0)
		for sgn in [-1.0, 0.0, 1.0]:
			if sgn != 0.0 and i % 2 == 1:
				continue
			var base := Vector3(0.14 * sgn, 0.78 - absf(z) * 0.15, z)
			var h := rng.randf_range(0.25, 0.42) * (1.0 - absf(z) * 0.4)
			var tip := base + Vector3(0.12 * sgn, h, 0.12)
			var w := Vector3(0.05, 0, 0)
			var d := Vector3(0, 0, 0.05)
			_tri(st, base - w, base + w, tip, spine, spine, spine)
			_tri(st, base - d, base + d, tip, spine, spine, spine)
	return _finish(st, null, material)


## Training dummy: wooden post with a crossbar and a straw-bound body. Surfaces [wood].
static func training_dummy(material: Material) -> ArrayMesh:
	var st := _begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var wood := Color(0.22, 0.15, 0.09)
	var straw := Color(0.42, 0.36, 0.2)
	var rope := Color(0.12, 0.08, 0.05)
	_tube(st, PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 2.0, 0)]), PackedFloat32Array([0.1, 0.08]),
			PackedColorArray([wood, wood]), 8, rng)
	_tube(st, PackedVector3Array([Vector3(-0.55, 1.45, 0), Vector3(0.55, 1.45, 0)]), PackedFloat32Array([0.06, 0.06]),
			PackedColorArray([wood, wood]), 6, rng)
	_blob(st, Vector3(0, 1.15, 0), Vector3(0.32, 0.45, 0.25), rng, straw, straw * 0.8, 5, 8, 0.12)
	_blob(st, Vector3(0, 1.78, 0), Vector3(0.18, 0.2, 0.18), rng, straw, straw * 0.8, 4, 7, 0.1)
	for y in [0.95, 1.35]:
		_tube(st, PackedVector3Array([Vector3(-0.001, y, 0), Vector3(0.001, y + 0.06, 0)]), PackedFloat32Array([0.34, 0.34]),
				PackedColorArray([rope, rope]), 10, rng)
	return _finish(st, null, material)


## Ninja short blade (kodachi) along +Y from the grip at the origin: grip, guard, blade.
static func ninja_blade(material: Material) -> ArrayMesh:
	var st := _begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var grip := Color(0.08, 0.06, 0.07)
	var guard := Color(0.35, 0.3, 0.22)
	var steel := Color(0.75, 0.8, 0.85)
	_tube(st, PackedVector3Array([Vector3(0, -0.12, 0), Vector3(0, 0.08, 0)]), PackedFloat32Array([0.018, 0.018]),
			PackedColorArray([grip, grip]), 6, rng)
	_blob(st, Vector3(0, 0.09, 0), Vector3(0.045, 0.012, 0.045), rng, guard, guard, 2, 8, 0.0)
	# Blade: thin, slightly curved, single edge.
	var segs := 6
	var length := 0.55
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var c0 := Vector3(0, 0.1 + length * t0, sin(t0 * 1.4) * 0.04)
		var c1 := Vector3(0, 0.1 + length * t1, sin(t1 * 1.4) * 0.04)
		var w0 := 0.022 * (1.0 - t0 * 0.6)
		var w1 := 0.022 * (1.0 - t1 * 0.6) if i < segs - 1 else 0.0
		for sgn in [-1.0, 1.0]:
			var th := Vector3(0.004 * sgn, 0, 0)
			_quad(st, c0 + th, c1 + th, c1 + Vector3(0, 0, w1) + th * 0.2, c0 + Vector3(0, 0, w0) + th * 0.2,
					steel, steel, steel, steel)
	return _finish(st, null, material)
