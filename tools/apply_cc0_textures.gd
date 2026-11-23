extends SceneTree
## Give every existing terrain/stone/basalt material its CC0 textures (Cc0Surfaces) without
## regenerating scenes. tools/generate_visual_pass.gd does the same on a full re-run.
##   godot --headless --path project -s ../tools/apply_cc0_textures.gd

func _initialize() -> void:
	var dir := "res://data/materials/"
	var count := 0
	for f: String in Cc0Surfaces.PAINTED:  # Flat/vertex-colour materials become `painted`.
		ResourceSaver.save(Cc0Surfaces.make_painted(f), dir + f + ".tres")
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".tres"):
			continue
		var mat := load(dir + f) as Material
		if mat and Cc0Surfaces.apply(mat, f.get_basename()):
			ResourceSaver.save(mat, dir + f)
			count += 1
			print("textured ", f)
	print("%d materials textured" % count)
	quit()
