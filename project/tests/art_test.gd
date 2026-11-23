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
