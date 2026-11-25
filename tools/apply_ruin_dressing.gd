extends SceneTree
## Art pass 5B: writes data/routes/ruins_<biome>.tres (RuinDressing). Run after generate_routes.gd.
##   godot --headless --path project -s ../tools/apply_ruin_dressing.gd

const DIR := "res://assets/models/cc0/ruins/"
const SCATTER := ["ruinpillar_01", "pillarsegment_01", "ruinwallsegment_02", "romantypecol_01", "romanrail_01",
	"foundationruin_01", "ruinwallsegment_01", "templeruin_02", "ruinarch_01", "speakingstones_01"]
const SEEDS := {"verdant_canopy": 11, "emberwild": 23, "moonfen": 37, "stormcrag": 41}

func _initialize() -> void:
	for biome: String in SEEDS:
		var d := RuinDressing.new()
		var models: Array[PackedScene] = []
		for m: String in SCATTER:
			models.append(load(DIR + m + ".glb") as PackedScene)
		d.scatter_models = models
		d.shrine_pillar = load(DIR + "ruinpillar_01.glb") as PackedScene
		d.gate_arch = load(DIR + "ruinarch_01.glb") as PackedScene
		d.seed_value = SEEDS[biome]
		ResourceSaver.save(d, "res://data/routes/ruins_%s.tres" % biome)
		print("ruin dressing ", biome)
	quit()
