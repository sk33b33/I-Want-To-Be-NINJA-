extends SceneTree
## Phase 13 (owner: "the path to the bosses is too small — make it longer and harder, for all
## stages"; chose ~3x, harder platforming + enemies + branching paths + more hazards).
## Adds ~250 m of route BEFORE each jungle's original route (which keeps its coordinates):
##   Section 1 (z 250 -> 140): a fork — a safe-but-long path west (lantern-marked; an enemy pack
##     and a hazard lane) and a risky-but-short path east over a chasm on the jungle's hazard
##     platforms (a pickup at the far end).
##   Section 2 (z 140 -> 5): checkpoint, a 24 m chasm with two crossings (narrow beams / hazard
##     platforms), a climb up to a plateau with a hazard field and an enemy pack, a dead-end arm
##     with a reward, a drop, a final enemy pack and a checkpoint before the original route.
## Emberwild and Stormcrag are mirrored (safe path east). Writes data/routes/<biome>.tres,
## extends data/biomes/<biome>_terrain.tres (length, corridor segments, chasm pits) and adds a
## RouteBuilder node to scenes/biomes/<biome>.tscn. Run AFTER generate_visual_pass.gd.
##   godot --headless --path project -s ../tools/generate_routes.gd

const K := RoutePiece.Kind
const MAT := "res://data/materials/"

const THEMES := {
	"verdant_canopy": {"mirror": false, "stone": "stone", "climb": "climb_stone", "step": K.CRUMBLE, "step2": K.CRUMBLE, "step_y": -0.2,
		"floor": -1, "lane": K.BRAMBLE, "field": K.BRAMBLE, "pickup": "ruin_shard"},
	"emberwild": {"mirror": true, "stone": "basalt", "climb": "basalt_climb", "step": K.SINK_STONE, "step2": K.SINK_STONE, "step_y": 0.0,
		"floor": K.LAVA, "lane": K.VENT, "field": K.VENT, "pickup": "ember_crystal"},
	"moonfen": {"mirror": false, "stone": "stone", "climb": "climb_stone", "step": K.RAFT, "step2": K.RAFT, "step_y": 0.0,
		"floor": K.BOG, "lane": K.POISON, "field": K.POISON, "pickup": "spirit_moss"},
	"stormcrag": {"mirror": true, "stone": "crag_stone", "climb": "climb_stone", "step": K.BOX, "step2": K.CRUMBLE, "step_y": -0.2, "gusts": true,
		"floor": -1, "lane": K.GUST, "field": K.STORM, "pickup": "storm_glass"},
}

# Shared geometry (unmirrored: safe path west at x = -24, risky path east at x = 16).
const SPAWN_Z := 250.0
const SAFE_X := -24.0
const RISKY_X := 16.0
const PIT1 := Vector4(16, 184, 10, 18)          # Risky-path chasm: x 6..26, z 166..202.
const PIT2 := Vector4(0, 112, 80, 12)           # Full-width chasm: z 100..124.
const PLATEAU_Z := Vector2(56, 90)              # Plateau top y = 5 between these z.
const PLATEAU_H := 5.0

var _pieces: Array[RoutePiece] = []
var _mirror := 1.0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/routes"))
	for biome: String in THEMES:
		var t: Dictionary = THEMES[biome]
		_mirror = -1.0 if t["mirror"] else 1.0
		_pieces = []
		var layout := RouteLayout.new()
		layout.biome_id = StringName(biome)
		layout.spawn = Vector3(0, 0.1, SPAWN_Z)
		_section_one(t)
		_section_two(t)
		layout.pieces = _pieces
		layout.bot_paths = {"safe": _bot_path(true), "risky": _bot_path(false)}
		ResourceSaver.save(layout, "res://data/routes/%s.tres" % biome)
		_extend_terrain(biome)
		_add_builder(biome, t)
		print("route ", biome, ": ", _pieces.size(), " pieces")
	quit()


func _v(x: float, y: float, z: float) -> Vector3:
	return Vector3(x * _mirror, y, z)


func _add(kind: int, pos: Vector3, size: Vector3 = Vector3(3, 1, 3), extra: Dictionary = {}) -> RoutePiece:
	var p := RoutePiece.new()
	p.kind = kind
	p.position = pos
	p.size = size
	for k: String in extra:
		p.set(k, extra[k])
	_pieces.append(p)
	return p


## A themed hazard lane: the hazard on both sides of a 2 m lane (or across it, timed).
func _hazard_lane(kind: int, x: float, z0: float, z1: float) -> void:
	match kind:
		K.BRAMBLE, K.POISON:
			for z in range(int(z0), int(z1), -9):
				if kind == K.BRAMBLE:
					_add(K.BRAMBLE, _v(x - 3.5, 0.4, z), Vector3(5, 1, 6))
					_add(K.BRAMBLE, _v(x + 3.5, 0.4, z - 4.5), Vector3(5, 1, 6))
				else:
					_add(K.POISON, _v(x - 3.3, 0.5, z), Vector3(2.4, 1, 2.4))
					_add(K.POISON, _v(x + 3.3, 0.5, z - 4.5), Vector3(2.4, 1, 2.4))
		K.VENT:
			var i := 0
			for z in range(int(z0), int(z1), -6):
				_add(K.VENT, _v(x, 0.0, z), Vector3.ONE, {"phase": 0.55 * i})
				i += 1
		K.GUST:
			_add(K.GUST, _v(x, 2.0, (z0 + z1) * 0.5), Vector3(10, 5, absf(z0 - z1)))
		K.STORM:
			_add(K.STORM, _v(x, 3.0, (z0 + z1) * 0.5), Vector3(12, 5, absf(z0 - z1)))


## Stepping pieces across a chasm along z (from z_start down to z_end), in the jungle's style.
## Sinking stones rise and sink as a travelling WAVE (each 0.8 s behind the one before): start on
## a fresh stone and every next one is up as you reach it — watch the wave, then ride it.
## `gust`: wind over the middle stretch only (solid slabs either side to wait on for a calm).
func _steps(kind: int, t: Dictionary, x: float, z_start: float, z_end: float, spacing: float, gust: bool) -> void:
	var z := z_start
	var i := 0
	while z > z_end:
		match kind:
			K.BOX:  # Stormcrag: narrow, rain-slick stone slabs.
				_add(K.BOX, _v(x, -0.5, z), Vector3(2.2, 1.0, 3.0), {"material": "stone"})
			K.SINK_STONE:
				_add(K.SINK_STONE, _v(x, float(t["step_y"]), z), Vector3.ONE, {"phase": 100.0 - 0.8 * i})
			_:
				_add(kind, _v(x, float(t["step_y"]), z))
		z -= spacing
		i += 1
	if gust:
		# Exactly two slabs in the wind (z 175..185.5 for the risky chasm); the slab before it is
		# outside, so you can wait there for a calm and then cross in two quick jumps.
		var mid := (z_start + z_end) * 0.5 - 2.0
		_add(K.GUST, _v(x, 2.0, mid), Vector3(8, 5, 10.0), {"phase": 0.7})


func _section_one(t: Dictionary) -> void:
	# The fork: lanterns mark the safe way.
	for p in [Vector3(-4, 0, 226), Vector3(-14, 0, 214), Vector3(SAFE_X + 3, 0, 200)]:
		_add(K.LANTERN, _v(p.x, p.y, p.z))
	# Safe path (west): an enemy pack, then the jungle's hazard lane.
	_add(K.ENEMY, _v(SAFE_X, 0.0, 190), Vector3.ONE, {"count": 3})
	_hazard_lane(t["lane"], SAFE_X, 180, 160)
	if t.get("gusts", false):  # Stormcrag: lightning chases you down the windy lane too.
		_hazard_lane(K.STORM, SAFE_X, 180, 160)
	# Risky path (east): stepping pieces over a chasm (PIT1), a reward at the far side.
	if t["floor"] != -1:
		_add(t["floor"], _v(PIT1.x, -4.0, PIT1.y), Vector3(PIT1.z * 2.0, 6.0, PIT1.w * 2.0))
	_steps(t["step"], t, RISKY_X, 199.5, 165.0, 5.5, t.get("gusts", false))
	_add(K.PICKUP, _v(RISKY_X + 4, 0.0, 162), Vector3.ONE, {"item": t["pickup"]})


func _section_two(t: Dictionary) -> void:
	_add(K.CHECKPOINT, _v(0, 0.0, 136))
	# The big chasm (PIT2): narrow beams on the left, the jungle's hazard platforms on the right.
	if t["floor"] != -1:
		_add(t["floor"], _v(0, -4.0, PIT2.y), Vector3(PIT2.z * 2.0, 6.0, PIT2.w * 2.0))
	for z in [122.0, 116.0, 110.0, 104.0]:
		_add(K.BOX, _v(-6, -0.5, z), Vector3(0.9, 1.0, 4.0), {"material": "wood"})
	_steps(t["step2"], t, 6.0, 121.5, 100.0, 5.0, false)
	# Climb to the plateau (top y = 5) and its hazard field.
	var depth := PLATEAU_Z.y - PLATEAU_Z.x
	# Climbable on every side: knocked off in a fight, you can climb straight back up.
	_add(K.CLIMB, _v(0, PLATEAU_H * 0.5, (PLATEAU_Z.x + PLATEAU_Z.y) * 0.5), Vector3(26, PLATEAU_H, depth))
	_add(K.CLIMB, _v(0, PLATEAU_H * 0.5, PLATEAU_Z.y + 0.5), Vector3(26, PLATEAU_H, 1.0))
	_add(K.ENEMY, _v(-2, PLATEAU_H + 0.1, 66), Vector3.ONE, {"count": 3})
	match int(t["field"]):
		K.BRAMBLE, K.POISON:
			for c in [Vector3(4, 0, 84), Vector3(-4, 0, 78), Vector3(5, 0, 70), Vector3(-5, 0, 62)]:
				if t["field"] == K.BRAMBLE:
					_add(K.BRAMBLE, _v(c.x, PLATEAU_H + 0.4, c.z), Vector3(6, 1, 4))
				else:
					_add(K.POISON, _v(c.x, PLATEAU_H + 0.5, c.z), Vector3(2.6, 1, 2.6))
		K.VENT:
			var i := 0
			for c in [Vector3(4, 0, 84), Vector3(-4, 0, 78), Vector3(5, 0, 70), Vector3(-5, 0, 62), Vector3(0, 0, 74)]:
				_add(K.VENT, _v(c.x, PLATEAU_H, c.z), Vector3.ONE, {"phase": 0.7 * i})
				i += 1
		K.STORM:
			_add(K.STORM, _v(0, PLATEAU_H + 3.0, 72), Vector3(24, 5, depth - 2.0))
			for c in [Vector3(-7, 0, 80), Vector3(7, 0, 64)]:  # Shelters (rock roofs on posts).
				_add(K.BOX, _v(c.x, PLATEAU_H + 2.6, c.z), Vector3(3.6, 0.6, 3.0))
				_add(K.BOX, _v(c.x - 1.4, PLATEAU_H + 1.2, c.z - 1.0), Vector3(0.6, 2.4, 0.6))
				_add(K.BOX, _v(c.x + 1.4, PLATEAU_H + 1.2, c.z + 1.0), Vector3(0.6, 2.4, 0.6))
	# Dead-end arm (east) with a reward; a lantern shows the way on.
	_add(K.CLIMB, _v(18, PLATEAU_H * 0.5, 72), Vector3(10, PLATEAU_H, 6))
	_add(K.PICKUP, _v(21, PLATEAU_H, 72), Vector3.ONE, {"item": t["pickup"]})
	_add(K.LANTERN, _v(-8, PLATEAU_H, 58))
	# Final stretch: another pack, a checkpoint before the original route.
	_add(K.ENEMY, _v(0, 0.0, 36), Vector3.ONE, {"count": 2})
	_add(K.CHECKPOINT, _v(0, 0.0, 22))


## Bot paths (gate tests): Vector4(x, y, z, jump-at-this-point).
func _bot_path(safe: bool) -> Array:
	var pts: Array = []
	var add := func(x: float, z: float, jump: bool = false, y: float = 0.0) -> void:
		pts.append(Vector4(x * _mirror, y, z, 1.0 if jump else 0.0))
	add.call(0, 232)
	if safe:
		add.call(-12, 216)
		add.call(SAFE_X, 204)
		add.call(SAFE_X, 158)
	else:
		add.call(RISKY_X, 208)
		add.call(RISKY_X, 203.9, true)  # A stride before the edge: the first piece is close.
		# Keep running: take off from each piece's far edge (a running jump carries ~4.7 m,
		# landing near the middle of the next piece — like a player would cross).
		for z in [199.5, 194.0, 188.5, 183.0, 177.5, 172.0, 166.5]:
			add.call(RISKY_X, z - 0.9, true)  # The last one jumps onto the bank.
		add.call(RISKY_X, 162.0)
	add.call(0, 142)
	var x := -6.0 if safe else 6.0
	add.call(x, 126)
	if safe:
		for z in [122.0, 116.0, 110.0, 104.0]:
			add.call(x, z + 1.5)
			add.call(x, z - 1.7, true)
	else:
		add.call(x, 125.2, true)
		for z in [121.5, 116.5, 111.5, 106.5, 101.5]:
			add.call(x, z - 0.9, true)
	add.call(x, 97)
	add.call(-3, 93)
	add.call(-3, PLATEAU_Z.y - 3.0, false, PLATEAU_H)  # Walk into the wall: climb, mantle.
	add.call(-10, 82, false, PLATEAU_H)
	add.call(-10, 60, false, PLATEAU_H)
	add.call(-2, 52)
	add.call(0, 8)
	return pts


func _extend_terrain(biome: String) -> void:
	var path := "res://data/biomes/%s_terrain.tres" % biome
	var cfg := load(path) as TerrainConfig
	cfg.max_corner.y = 290.0
	var segs := PackedVector2Array([
		Vector2(0, 275), Vector2(0, 226),
		Vector2(0, 226), Vector2(SAFE_X * _mirror, 206), Vector2(SAFE_X * _mirror, 206), Vector2(SAFE_X * _mirror, 158),
		Vector2(SAFE_X * _mirror, 158), Vector2(0, 142),
		Vector2(0, 226), Vector2(RISKY_X * _mirror, 210), Vector2(RISKY_X * _mirror, 210), Vector2(RISKY_X * _mirror, 158),
		Vector2(RISKY_X * _mirror, 158), Vector2(0, 142),
		Vector2(0, 142), Vector2(0, 30)])
	# Keep the original segments that start at or below z = 30.
	var kept := PackedVector2Array()
	var old := cfg.route_points
	for i in range(0, old.size() - 1, 2):
		var a := old[i]
		var b := old[i + 1]
		if a == Vector2(0, 30) or maxf(a.y, b.y) <= 30.0:
			kept.append(a)
			kept.append(b)
	cfg.route_points = segs + kept
	cfg.pits = [Vector4(PIT1.x * _mirror, PIT1.y, PIT1.z, PIT1.w), PIT2]
	# Flat clearings for the plateau arm and the fork.
	var clearings: Array[Vector3] = []
	for c in cfg.clearings:
		if c.y < 30.0:
			clearings.append(c)
	clearings.append(Vector3(18 * _mirror, 72, 8))
	clearings.append(Vector3(0, 73, 17))  # The plateau: no trees on or through it.
	clearings.append(Vector3(0, 228, 10))
	cfg.clearings = clearings
	ResourceSaver.save(cfg, path)


## Add a RouteBuilder to the biome scene (properties after `script` — see CLAUDE.md).
func _add_builder(biome: String, t: Dictionary) -> void:
	var p := ProjectSettings.globalize_path("res://scenes/biomes/%s.tscn" % biome)
	var s := FileAccess.get_file_as_string(p)
	if s.contains("name=\"RouteBuilder\""):
		return
	var lines := s.split("\n")
	var last := 0
	for i in lines.size():
		if lines[i].begins_with("[ext_resource"):
			last = i
	var ext := [
		"[ext_resource type=\"Script\" path=\"res://scripts/world/route/route_builder.gd\" id=\"route_builder_script\"]",
		"[ext_resource type=\"Resource\" path=\"res://data/routes/%s.tres\" id=\"route_layout_%s\"]" % [biome, biome],
		"[ext_resource type=\"Material\" path=\"%s%s.tres\" id=\"route_stone_%s\"]" % [MAT, t["stone"], biome],
		"[ext_resource type=\"Material\" path=\"%s%s.tres\" id=\"route_climb_%s\"]" % [MAT, t["climb"], biome],
		"[ext_resource type=\"Material\" path=\"%sdark_wood.tres\" id=\"route_wood_%s\"]" % [MAT, biome],
	]
	var out: Array = []
	for i in lines.size():
		out.append(lines[i])
		if i == last:
			out.append_array(ext)
	var text := "\n".join(PackedStringArray(out)).strip_edges(false, true)
	text += "\n\n[node name=\"RouteBuilder\" type=\"Node3D\" parent=\".\"]\nscript = ExtResource(\"route_builder_script\")\n"
	text += "layout = ExtResource(\"route_layout_%s\")\nstone_material = ExtResource(\"route_stone_%s\")\n" % [biome, biome]
	text += "climb_material = ExtResource(\"route_climb_%s\")\nwood_material = ExtResource(\"route_wood_%s\")\n" % [biome, biome]
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()
