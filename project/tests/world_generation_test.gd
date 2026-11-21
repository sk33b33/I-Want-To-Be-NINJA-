extends TestCase
## Terrain, flora and fauna generation: route stays walkable, gorge is deadly, generation is
## deterministic, vegetation never blocks the route, wildlife reacts to the player.

const TERRAIN_CFG := "res://data/biomes/verdant_canopy_terrain.tres"
const FLORA_CFG := "res://data/biomes/verdant_canopy_flora.tres"


func _make_terrain() -> BiomeTerrain:
	var t := BiomeTerrain.new()
	t.config = load(TERRAIN_CFG)
	add_node(t)
	return t


func test_route_corridor_is_flat_at_route_height() -> void:
	var t := _make_terrain()
	var cfg := t.config
	for z in [18.0, 0.0, -20.0, -45.0, -75.0, -100.0]:
		for x in [-3.0, 0.0, 3.0]:
			if absf(z - cfg.stream_z) < cfg.stream_half_width + 2.0:
				continue
			check_near(t.get_height(x, z), cfg.route_height, 0.001, "route flat at (%.0f, %.0f)" % [x, z])


func test_gorge_floor_is_below_kill_height() -> void:
	var t := _make_terrain()
	var kill := (load("res://data/player/default_movement.tres") as PlayerMovementConfig).kill_height
	for x in [-60.0, -20.0, 0.0, 20.0, 60.0]:
		check(t.get_height(x, -60.0) < kill, "gorge at x=%.0f is deadly (h=%.1f)" % [x, t.get_height(x, -60.0)])


func test_terrain_has_hills_and_border_cliffs() -> void:
	var t := _make_terrain()
	var cfg := t.config
	var near_edge := t.get_height(cfg.max_corner.x - 1.0, -20.0)
	var off_route := t.get_height(35.0, 0.0)
	check(near_edge > 20.0, "map border rises into cliffs (h=%.1f)" % near_edge)
	check(absf(off_route) > 1.0, "terrain off the route is sculpted, not flat (h=%.1f)" % off_route)


func test_collision_matches_visible_terrain() -> void:
	var t := _make_terrain()
	await physics_frames(2)
	var space := t.get_world_3d().direct_space_state
	for p in [Vector2(20, -10), Vector2(-33, 12), Vector2(5, -90), Vector2(-50, -30)]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 100, p.y), Vector3(p.x, -100, p.y))
		var hit := space.intersect_ray(q)
		check(not hit.is_empty(), "ray hits terrain at %s" % p)
		if not hit.is_empty():
			check_near((hit["position"] as Vector3).y, t.get_height_interpolated(p.x, p.y), 0.15,
					"collision height matches mesh at %s" % p)


func test_flora_is_deterministic_for_a_seed() -> void:
	var t := _make_terrain()
	var a := _make_flora(t)
	var b := _make_flora(t)
	check(a.get_tree_positions().size() > 50, "plenty of trees placed (%d)" % a.get_tree_positions().size())
	check(a.get_tree_positions() == b.get_tree_positions(), "same seed gives the same forest")
	check(a.get_child_count() == b.get_child_count(), "same number of generated nodes")


func test_flora_never_blocks_the_route() -> void:
	var t := _make_terrain()
	var f := _make_flora(t)
	for p in f.get_tree_positions():
		check(t.route_distance(p.x, p.z) >= f.config.tree_route_clearance - 0.01,
				"tree at %s keeps clear of the route" % p)


func test_flora_draw_distance_set_on_ground_cover() -> void:
	var t := _make_terrain()
	var f := _make_flora(t)
	var chunks := 0
	for c in f.get_children():
		if c is MultiMeshInstance3D and str(c.name).begins_with("Grass_"):
			chunks += 1
			check(c.visibility_range_end > 0.0, "%s culls with distance" % c.name)
	check(chunks > 4, "grass split into culled chunks (%d)" % chunks)


func test_frog_hops_away_from_player() -> void:
	var t := _make_terrain()
	var player := Node3D.new()
	add_node(player)
	player.global_position = Vector3(0, 0, 0)
	var frog := FrogCritter.new()
	frog.terrain = t
	frog.player = player
	frog.mesh = BoxMesh.new()
	add_node(frog)
	frog.global_position = Vector3(1.0, 0, 0)
	await process_frames(60)
	check(frog.global_position.distance_to(player.global_position) > 1.8,
			"frog moved away (distance %.2f)" % frog.global_position.distance_to(player.global_position))


func test_lurker_eyes_vanish_when_player_close() -> void:
	var player := Node3D.new()
	add_node(player)
	var eyes := LurkerEyes.new()
	eyes.mesh = BoxMesh.new()
	eyes.player = player
	eyes.vanish_radius = 10.0
	eyes.relocate = func() -> Vector3: return Vector3(40, 1, 40)
	add_node(eyes)
	eyes.global_position = Vector3(0, 1, -30)
	player.global_position = Vector3(0, 0, 0)
	var vanished := [false]
	eyes.vanished.connect(func() -> void: vanished[0] = true)
	await process_frames(30)
	check(not vanished[0], "eyes stay while the player is far")
	player.global_position = Vector3(0, 0, -25)
	await process_frames(90)
	check(vanished[0], "eyes vanish when the player approaches")


func _make_flora(t: BiomeTerrain) -> FloraScatter:
	var f := FloraScatter.new()
	f.config = load(FLORA_CFG)
	add_node(f)
	f.terrain_path = f.get_path_to(t)
	f.rebuild()
	return f
