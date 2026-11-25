extends SceneTree
## Art pass 5A: gives each jungle's FloraConfig its imported (CC0) tree models. Run AFTER
## tools/generate_visual_pass.gd (which rewrites the flora configs).
##   godot --headless --path project -s ../tools/apply_flora_models.gd

const DIR := "res://assets/models/cc0/amazon_trees/"
const SETS := {
	"verdant_canopy": {"models": ["young_twisted", "young_thick", "young_slim", "tree_bigbark", "tree_emergent", "tree_ancient", "tree_big"],
		"atlas": "amazon_trees_atlas.png", "tint": Color(0.7, 0.76, 0.66), "height": 17.0},
}

func _initialize() -> void:
	for biome: String in SETS:
		var path := "res://data/biomes/%s_flora.tres" % biome
		var cfg := load(path) as FloraConfig
		var spec: Dictionary = SETS[biome]
		var models: Array[PackedScene] = []
		for m: String in spec["models"]:
			models.append(load(DIR + m + ".fbx") as PackedScene)
		cfg.tree_models = models
		cfg.tree_model_atlas = load(DIR + spec["atlas"]) as Texture2D
		cfg.tree_model_tint = spec["tint"]
		cfg.tree_model_height = spec["height"]
		ResourceSaver.save(cfg, path)
		print("tree models ", biome, " x", models.size())
	quit()
