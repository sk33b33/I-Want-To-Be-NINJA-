extends TestCase
## Phase 13 long routes (owner: "the path to the bosses is too small — make it longer and harder,
## for all stages"; chose ~3x, harder platforming, enemies, branching paths, more hazards).
## Data and length, the terrain under it, checkpoints catching falls, and the gate: a bot walks
## both the safe and the risky way in every jungle from the new spawn to the original route.

const SCENES := {
	&"verdant_canopy": "res://scenes/main/main.tscn",
	&"emberwild": "res://scenes/main/expedition_emberwild.tscn",
	&"moonfen": "res://scenes/main/expedition_moonfen.tscn",
	&"stormcrag": "res://scenes/main/expedition_stormcrag.tscn",
}
const ORIGINAL_LENGTH := 123.0  # Spawn (z 0) to the arena trigger (z -123) before Phase 13.


func _start(biome: StringName) -> Node:
	PlayerProfile.path = "user://test_profile_routes.json"
	return instantiate(SCENES[biome])


func _done() -> void:
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH


func test_every_route_is_about_three_times_longer_with_forks_enemies_and_hazards() -> void:
	for biome: StringName in SCENES:
		var layout := load("res://data/routes/%s.tres" % biome) as RouteLayout
		var length := layout.spawn.z + ORIGINAL_LENGTH
		check(length >= ORIGINAL_LENGTH * 2.8, "%s: %.0f m spawn to arena (%.1fx)" % [biome, length, length / ORIGINAL_LENGTH])
		var kinds := {}
		for p in layout.pieces:
			kinds[p.kind] = int(kinds.get(p.kind, 0)) + 1
		check(int(kinds.get(RoutePiece.Kind.ENEMY, 0)) >= 3, "%s: three enemy packs" % biome)
		check(int(kinds.get(RoutePiece.Kind.CHECKPOINT, 0)) >= 2, "%s: two new checkpoints" % biome)
		check(int(kinds.get(RoutePiece.Kind.CLIMB, 0)) >= 1, "%s: a climb" % biome)
		var hazards := 0
		for k in [RoutePiece.Kind.CRUMBLE, RoutePiece.Kind.SINK_STONE, RoutePiece.Kind.RAFT, RoutePiece.Kind.VENT,
				RoutePiece.Kind.LAVA, RoutePiece.Kind.BOG, RoutePiece.Kind.POISON, RoutePiece.Kind.BRAMBLE,
				RoutePiece.Kind.GUST, RoutePiece.Kind.STORM]:
			hazards += int(kinds.get(k, 0))
		check(hazards >= 8, "%s: plenty of hazards (%d)" % [biome, hazards])
		var safe: Array = layout.bot_paths["safe"]
		var risky: Array = layout.bot_paths["risky"]
		var split := false
		for w in safe:
			if absf((w as Vector4).x) > 20.0:
				split = true
		check(split and risky.size() > 0 and safe.size() > 0, "%s: a fork with two ways" % biome)


func test_terrain_carves_the_chasms_and_keeps_trees_out() -> void:
	for biome: StringName in SCENES:
		var main := _start(biome)
		await physics_frames(2)
		var terrain := main.find_children("*", "BiomeTerrain", true, false)[0] as BiomeTerrain
		check(terrain.config.pits.size() == 2, "%s: two new chasms" % biome)
		for pit in terrain.config.pits:
			# Verdant/Stormcrag: a drop to the kill height; Emberwild/Moonfen: lava/bog below route level.
			check(terrain.get_height(pit.x, pit.y) <= terrain.config.gorge_depth + 0.01 and terrain.get_height(pit.x, pit.y) < -3.0,
					"%s: chasm at (%.0f, %.0f) is carved (%.1f m)" % [biome, pit.x, pit.y, terrain.get_height(pit.x, pit.y)])
		check(absf(terrain.get_height(0, 245)) < 0.5 and absf(terrain.get_height(0, 30)) < 0.5, "%s: the route is flat ground" % biome)
		var flora := main.find_children("*", "FloraScatter", true, false)[0] as FloraScatter
		var in_pit := flora.get_tree_positions().filter(func(t: Vector3) -> bool: return terrain.is_in_pit(t.x, t.z))
		check(in_pit.is_empty(), "%s: no trees in the chasms (%d)" % [biome, in_pit.size()])
		main.free()
		_nodes.erase(main)
	_done()


func test_falling_into_the_big_chasm_returns_to_its_checkpoint() -> void:
	var main := _start(&"verdant_canopy")
	await physics_frames(5)
	var player := main.get_node("Player") as PlayerController
	player.respawn(Vector3(0, 0.3, 140))
	await physics_frames(5)
	player.respawn(Vector3(0, 0.3, 136))  # Touch the section-2 checkpoint shrine.
	await physics_frames(20)
	check(player.has_checkpoint() and player.get_checkpoint().origin.z > 130.0, "checkpoint at the chasm taken")
	player.global_position = Vector3(20, 1.0, 112)  # Over the chasm.
	await physics_frames(150)
	check(player.global_position.z > 128.0 and player.global_position.y > -1.0, "fell and came back to the checkpoint (%s)" % player.global_position.round())
	_done()


## Phase 13 gate (long routes): both ways are walkable with the real controls in every jungle.
## The bot is made immune to damage — this tests navigation (enemies still get in the way).
func test_gate_bot_walks_the_safe_and_risky_way_in_every_jungle() -> void:
	for biome: StringName in SCENES:
		for way in ["safe", "risky"]:
			var main := _start(biome)
			await physics_frames(5)
			var player := main.get_node("Player") as PlayerController
			player.combat.health.invulnerable = true
			# The bot's own dodge rolls switch `invulnerable` off again when they end; a zero damage
			# multiplier survives them (this test is about navigation, not survival).
			player.combat.health.damage_taken_multiplier = 0.0
			var falls := [0]
			player.respawned.connect(func(_at: Vector3) -> void: falls[0] += 1)
			var ok := await BotHelpers.run_long_route(self, player, way, true)
			check(ok and player.global_position.z < 12.0, "%s %s way: reached the original route (at %s)" % [biome, way, player.global_position.round()])
			check(falls[0] == 0, "%s %s way: no falls (%d)" % [biome, way, falls[0]])
			main.free()
			_nodes.erase(main)
			await physics_frames(2)
	_done()


## Regression (found by the long-route gate): the player body is created at the scene origin,
## inside the ORIGINAL spawn's checkpoint shrine, before the long route moves it to the new
## spawn — and that stale overlap lit the shrine. A fall anywhere on the new route then sent you
## to z ~ 1, skipping the whole new route (an exploit). Shrines must only take a player who is
## really standing in them.
func test_the_start_does_not_light_the_old_spawn_shrine() -> void:
	for biome: StringName in SCENES:
		var main := _start(biome)
		await physics_frames(10)
		var player := main.get_node("Player") as PlayerController
		check(player.get_checkpoint().origin.z > 200.0, "%s: the checkpoint is the new spawn (z %.0f)" % [biome, player.get_checkpoint().origin.z])
		var lit := main.find_children("*", "Checkpoint", true, false).filter(func(c: Checkpoint) -> bool: return c.is_active)
		check(lit.is_empty(), "%s: no shrine lit at the start (%s)" % [biome, lit.map(func(c: Node) -> String: return c.name)])
		main.free()
		_nodes.erase(main)
	_done()



## Regression (found by the Low benchmark): trees are never distance-culled, so their triangles
## scale with their TOTAL count. Scaling the tree count with the terrain area (x1.6) pushed the
## Verdant Canopy on Low to 257k triangles (budget 250k). Low and Medium keep the original count.
func test_low_and_medium_keep_the_original_tree_count() -> void:
	for tier in [&"low", &"medium"]:
		QualityProfile.force_tier(tier)
		var main := _start(&"verdant_canopy")
		await physics_frames(2)
		var flora := main.find_children("*", "FloraScatter", true, false)[0] as FloraScatter
		var preset := QualityProfile.current()
		var limit := int((flora.config.jungle_tree_count + flora.config.dead_tree_count) * preset.tree_density) + 1
		var n := flora.get_tree_positions().size()
		check(n <= limit, "%s: %d trees (the original-size limit is %d)" % [tier, n, limit])
		main.free()
		_nodes.erase(main)
	QualityProfile.force_tier(&"")
	_done()


## Regression (found in the owner's play log): the first chasm was only 20 m wide, so the hill
## beside it was walkable and the player ran straight down the middle between the two branches
## (x 0..3, z 209 -> 155) — skipping the whole fork (enemy pack, hazard lane, chasm). The chasm
## must run from the safe lane's edge to the map edge: the only ways on are the safe lane or the
## stepping pieces.
func test_the_first_chasm_cannot_be_walked_around() -> void:
	for biome: StringName in SCENES:
		var main := _start(biome)
		await physics_frames(2)
		var terrain := main.find_children("*", "BiomeTerrain", true, false)[0] as BiomeTerrain
		var mirror := -1.0 if biome in [&"emberwild", &"stormcrag"] else 1.0
		var open: Array = []
		for x in range(-10, 79, 2):
			if not terrain.is_in_pit(x * mirror, 184.0):
				open.append(x)
		check(open.is_empty(), "%s: no way round the first chasm (walkable at x = %s)" % [biome, open])
		check(not terrain.is_in_pit(-24.0 * mirror, 184.0), "%s: the safe lane stays clear of the chasm" % biome)
		main.free()
		_nodes.erase(main)
	_done()


## Art pass 5B: CC0 ruins dress every long route — an arch at the start, a pillar pair at each new
## shrine, scattered ruins beside (never on) the route — lighter on Low, all of it solid (but the start arch).
func test_ruins_dress_every_route_lighter_on_low_and_never_solid() -> void:
	var counts := {}
	for tier in [&"low", &"high"]:
		QualityProfile.force_tier(tier)
		for biome: StringName in SCENES:
			var main := _start(biome)
			await physics_frames(2)
			var dressing := main.find_children("RuinDressing", "Node3D", true, false)
			check(dressing.size() == 1, "%s %s: ruin dressing built" % [tier, biome])
			if dressing.size() == 1:
				var n := 0
				var arch := false
				for mmi in dressing[0].get_children():
					n += (mmi as MultiMeshInstance3D).multimesh.instance_count if mmi is MultiMeshInstance3D else 0
					arch = arch or mmi.name == "StartArch"
				counts[[tier, biome]] = n
				check(arch, "%s %s: the start arch stands" % [tier, biome])
				check(n >= 6, "%s %s: %d ruin props" % [tier, biome, n])
				var solid := dressing[0].find_children("Ruins*Solid*", "StaticBody3D", true, false)
				check(not solid.is_empty() and dressing[0].find_children("StartArch", "CollisionObject3D", true, false).is_empty(), "%s %s: ruin props are solid, the start arch stays open" % [tier, biome])
			main.free()
			_nodes.erase(main)
	for biome: StringName in SCENES:
		check(counts.get([&"low", biome], 0) < counts.get([&"high", biome], 0), "%s: Low has fewer ruins than High (%s vs %s)" % [biome, counts.get([&"low", biome]), counts.get([&"high", biome])])
	QualityProfile.force_tier(&"")
	_done()

