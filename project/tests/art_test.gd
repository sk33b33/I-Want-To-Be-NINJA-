extends TestCase
## Art pass (stage 1, ground & rocks): CC0 detail textures on every terrain/stone/basalt
## material, and the phone (Low) preset skips the normal maps and the anti-tiling sample.


func _done() -> void:
	QualityProfile.force_tier(&"")


func test_every_surface_material_has_its_cc0_textures() -> void:
	var count := 0
	for f in DirAccess.get_files_at("res://data/materials/"):
		if not f.ends_with(".tres"):
			continue
		var mat := load("res://data/materials/" + f) as ShaderMaterial
		var shader := Cc0Surfaces.shader_name(mat)
		if not Cc0Surfaces.BY_SHADER.has(shader):
			continue
		count += 1
		var slots: Dictionary = Cc0Surfaces.BY_MATERIAL.get(f.get_basename(), Cc0Surfaces.BY_SHADER[shader])
		for slot: String in slots:
			var tex := mat.get_shader_parameter(slot + "_tex") as Texture2D
			var nrm := mat.get_shader_parameter(slot + "_nrm") as Texture2D
			check(tex != null and tex.resource_path.contains(slots[slot]), "%s: %s texture is %s" % [f, slot, slots[slot]])
			check(nrm != null and nrm.resource_path.ends_with("_normal.jpg"), "%s: %s normal map" % [f, slot])
	check(count >= 10, "found the surface materials (%d)" % count)


func test_cc0_textures_are_compressed_with_mipmaps() -> void:
	for f in DirAccess.get_files_at("res://assets/textures/cc0/"):
		if not f.ends_with(".import"):
			continue
		var cfg := ConfigFile.new()
		cfg.load("res://assets/textures/cc0/" + f)
		check(int(cfg.get_value("params", "compress/mode")) == 2, "%s: VRAM compressed" % f)
		check(bool(cfg.get_value("params", "mipmaps/generate")), "%s: mipmaps (the shader reads the 1x1 mip)" % f)
		if f.contains("_normal"):
			check(int(cfg.get_value("params", "compress/normal_map")) == 1, "%s: imported as a normal map" % f)


func test_phones_skip_normal_maps_and_anti_tiling() -> void:
	var low := load("res://data/quality/low.tres") as QualityPreset
	var high := load("res://data/quality/high.tres") as QualityPreset
	check(not low.detail_normals and not low.anti_tile, "Low: no normal maps, no anti-tiling sample")
	check(high.detail_normals and high.anti_tile, "High: both on")
	QualityProfile.apply_surface_detail(low)
	check(QualityProfile.surface_detail.get(&"detail_normals") == false, "Low sets the global off")
	QualityProfile.apply_surface_detail(high)
	check(QualityProfile.surface_detail.get(&"detail_normals") == true, "High sets it on")
	_done()


func test_the_expedition_applies_the_preset_detail() -> void:
	QualityProfile.force_tier(&"low")
	QualityProfile.surface_detail = {}
	PlayerProfile.path = "user://test_profile_art.json"
	instantiate("res://scenes/main/main.tscn")
	await process_frames(3)
	check(QualityProfile.surface_detail.get(&"anti_tile") == false, "a Low expedition turns anti-tiling off")
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH
	_done()


## Stage 2 (trees & plants): leaf cards on Medium/High only, the same tree either way, and every
## jungle's canopy material carries the leaf-spray detail and broadleaf veins.
func _jungle_tree_surfaces(cards: bool) -> Array:
	var leaf := load("res://data/materials/foliage_leaf.tres") as Material
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var card_mat: Material = Cc0Surfaces.leaf_cards_for(leaf) if cards else null
	var mesh := ProceduralMeshes.jungle_tree(rng, load("res://data/materials/bark_vertex.tres"), leaf,
			load("res://data/materials/foliage_vine.tres"), card_mat)
	var out := []
	for i in mesh.get_surface_count():
		out.append([Cc0Surfaces.shader_name(mesh.surface_get_material(i)), mesh.surface_get_array_len(i)])
	out.append(rng.randi())  # The tree's random stream must end in the same place.
	return out


func test_leaf_cards_only_add_a_surface_and_never_change_the_tree() -> void:
	var plain := _jungle_tree_surfaces(false)
	var carded := _jungle_tree_surfaces(true)
	check(carded.size() == plain.size() + 1, "cards add exactly one surface (%d vs %d)" % [carded.size(), plain.size()])
	var shaders: Array = carded.slice(0, carded.size() - 1).map(func(s: Array) -> String: return s[0])
	check(shaders.has("leaf_card"), "the extra surface is leaf cards")
	check(carded[-1] == plain[-1], "the tree's random stream is unchanged by cards (vines and later trees match)")


func test_low_has_no_leaf_cards_high_does() -> void:
	check(not (load("res://data/quality/low.tres") as QualityPreset).leaf_cards, "Low: no leaf cards")
	check((load("res://data/quality/high.tres") as QualityPreset).leaf_cards, "High: leaf cards")
	for tier in [&"low", &"high"]:
		QualityProfile.force_tier(tier)
		PlayerProfile.path = "user://test_profile_art.json"
		var main := instantiate("res://scenes/main/main.tscn")
		await process_frames(2)
		var found := false
		for mmi in main.find_children("*", "MultiMeshInstance3D", true, false):
			var mesh := (mmi as MultiMeshInstance3D).multimesh.mesh
			for i in mesh.get_surface_count():
				if Cc0Surfaces.shader_name(mesh.surface_get_material(i)) == "leaf_card":
					found = true
		check(found == (tier == &"high"), "%s: leaf cards present = %s" % [tier, found])
		main.free()
		_nodes.erase(main)
		PlayerProfile.path = PlayerProfile.DEFAULT_PATH
	_done()


func test_every_jungle_canopy_has_leaf_detail_and_veins() -> void:
	for f: String in Cc0Surfaces.LEAF_FOLIAGE:
		var m := load("res://data/materials/%s.tres" % f) as ShaderMaterial
		check(m.get_shader_parameter("leaf_detail") != null and float(m.get_shader_parameter("detail_amount")) > 0.0, "%s: leaf-spray detail" % f)
		check(float(m.get_shader_parameter("veins")) > 0.0, "%s: broadleaf veins" % f)


## Stage 3 (lighting & mood): every jungle loads with its JungleMood applied (sun, fog, grade),
## the split-tone grade is off on Low, and the brightness slider scales the mood's exposure.
## (A first version set `mood` before the script in the scene file, so it was silently dropped.)
func test_every_jungle_applies_its_mood() -> void:
	var scenes := {"verdant_canopy": "res://scenes/main/main.tscn", "emberwild": "res://scenes/main/expedition_emberwild.tscn",
		"moonfen": "res://scenes/main/expedition_moonfen.tscn", "stormcrag": "res://scenes/main/expedition_stormcrag.tscn"}
	PlayerProfile.path = "user://test_profile_art.json"
	for tier in [&"high", &"low"]:
		QualityProfile.force_tier(tier)
		for id: String in scenes:
			var mood := load("res://data/mood/%s.tres" % id) as JungleMood
			var main := instantiate(scenes[id])
			await process_frames(2)
			var sun := main.get_node("Level/Moonlight") as DirectionalLight3D
			var env := (main.get_node("Level/WorldEnvironment") as WorldEnvironment).environment
			check(sun.light_color.is_equal_approx(mood.sun_color), "%s: sun colour from its mood" % id)
			check(is_equal_approx(env.fog_density, mood.fog_density) and env.fog_light_color.is_equal_approx(mood.fog_color), "%s: fog from its mood" % id)
			check(is_equal_approx(env.adjustment_saturation, mood.saturation), "%s: saturation from its mood" % id)
			check((env.adjustment_color_correction != null) == (tier == &"high"), "%s %s: split-tone grade only off Low" % [id, tier])
			check(is_equal_approx(env.tonemap_exposure, mood.exposure * GameSettings.brightness), "%s: brightness scales the mood's exposure" % id)
			main.free()
			_nodes.erase(main)
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH
	_done()


## Stage 4 (beasts): every beast has a skin, markings and rim light; small fauna keep the plain
## look; beast meshes are the smooth rebuild (and within a sane budget); flora stays coarse.
func test_every_beast_has_skin_markings_and_rim() -> void:
	for f: String in Cc0Surfaces.BEASTS:
		var m := load("res://data/materials/%s.tres" % f) as ShaderMaterial
		check(m.get_shader_parameter("skin_tex") != null and float(m.get_shader_parameter("skin_strength")) > 0.0, "%s: skin texture" % f)
		check(float(m.get_shader_parameter("rim_strength")) > 0.0, "%s: rim light" % f)
		if f.ends_with("_body"):
			check(float(m.get_shader_parameter("marking_amount")) > 0.0, "%s: glowing markings" % f)
	var bat := load("res://data/materials/bat.tres") as ShaderMaterial
	var strength: Variant = bat.get_shader_parameter("skin_strength")
	check(strength == null or float(strength) == 0.0, "small fauna keep their plain look")


func test_beast_meshes_are_smooth_and_flora_is_not() -> void:
	check(ProceduralMeshes.smooth_level == 1, "smooth mode is off at runtime (flora/fauna stay cheap)")
	for id: String in ["kurogale", "ashen_oni_tortoise", "nami", "raijins_echo", "kamakiri", "kasai", "gamakage", "kazekiri"]:
		var b := (load("res://scenes/bosses/%s.tscn" % id) as PackedScene).instantiate()
		var tris := (b.get_node("Visual/Body") as MeshInstance3D).mesh.get_faces().size() / 3
		check(tris >= 1200 and tris <= 6000, "%s body is the smooth rebuild (%d triangles, budget 6000)" % [id, tris])
		b.free()
