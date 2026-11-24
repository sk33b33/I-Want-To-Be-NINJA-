extends SceneTree
## Phase 13 part 2 ("more weapons"): four weapon types forged from the second beasts' parts.
## Writes data/weapons/<type>.tres (WeaponType), data/gear/<gear>.tres, data/crafting/recipe_<gear>.tres
## and adds the recipes to data/crafting/catalog.tres (once). Re-run any time; tune the data files.
##   godot --headless --path project -s ../tools/generate_weapons.gd

const WEAPONS := [
	{"type": {"id": &"kama", "display_name": "Twin Kama", "blade_mesh": &"kama_blade",
			"play_style": "Hooked sickles that tear at horns, tails and crests: breaks beast parts far sooner.",
			"speed_multiplier": 1.0, "damage_multiplier": 0.95, "stagger_multiplier": 1.0, "reach": 1.1,
			"part_damage_multiplier": 1.6, "trail_base": 0.32, "trail_tip": 0.62},
		"gear": {"id": &"mantis_kama", "display_name": "Mantis Kama", "color": Color(0.7, 1.0, 0.5),
			"description": "Kamakiri's scythe, ground into a pair of sickles.", "blade_damage_multiplier": 1.5, "blade_element": &"nature"},
		"inputs": [["mantis_scythe", 1], ["ironbark_carapace", 1], ["ruin_shard", 2]]},
	{"type": {"id": &"claws", "display_name": "Claws", "blade_mesh": &"claw_blade",
			"play_style": "Fast, close and relentless: many light hits, little stagger.",
			"speed_multiplier": 1.35, "damage_multiplier": 0.72, "stagger_multiplier": 0.7, "reach": 0.8,
			"trail_width_multiplier": 0.7, "trail_base": 0.2, "trail_tip": 0.42},
		"gear": {"id": &"cinder_claws", "display_name": "Cinder Claws", "color": Color(1.0, 0.55, 0.25),
			"description": "Kasai's smouldering tail spines, set as claws over each fist.", "blade_damage_multiplier": 1.5, "blade_element": &"fire"},
		"inputs": [["cinder_tail", 1], ["salamander_hide", 1], ["ember_crystal", 2]]},
	{"type": {"id": &"tanto", "display_name": "Venom Tanto", "blade_mesh": &"venom_tanto",
			"play_style": "Quick short daggers that poison: the beast keeps bleeding while you dodge.",
			"speed_multiplier": 1.15, "damage_multiplier": 0.78, "stagger_multiplier": 0.85, "reach": 0.85,
			"poison_dps": 6.0, "poison_seconds": 5.0, "trail_base": 0.12, "trail_tip": 0.44},
		"gear": {"id": &"venom_tanto", "display_name": "Venom Tanto", "color": Color(0.55, 1.0, 0.4),
			"description": "Edges coated from Gamakage's toxin sac.", "blade_damage_multiplier": 1.5, "blade_element": &"poison"},
		"inputs": [["toxin_sac", 1], ["bog_toad_hide", 1], ["spirit_moss", 2]]},
	{"type": {"id": &"greatblade", "display_name": "Greatblades", "blade_mesh": &"gale_greatblade",
			"play_style": "Slow, long and heavy: big hits and big stagger — swing into openings.",
			"speed_multiplier": 0.78, "damage_multiplier": 1.4, "stagger_multiplier": 1.7, "reach": 1.35,
			"trail_width_multiplier": 1.5, "trail_base": 0.15, "trail_tip": 1.0},
		"gear": {"id": &"gale_greatblades", "display_name": "Gale Greatblades", "color": Color(0.6, 0.8, 1.0),
			"description": "Kazekiri's storm fangs, forged long and broad.", "blade_damage_multiplier": 1.5, "blade_element": &"lightning"},
		"inputs": [["gale_fang", 1], ["gale_pelt", 1], ["storm_glass", 2]]},
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/weapons"))
	var catalog := load("res://data/crafting/catalog.tres") as CraftingCatalog
	for w: Dictionary in WEAPONS:
		var t := WeaponType.new()
		for k: String in w["type"]:
			t.set(k, w["type"][k])
		var type_path := "res://data/weapons/%s.tres" % t.id
		ResourceSaver.save(t, type_path)
		var g := GearDefinition.new()
		g.slot = GearDefinition.Slot.WEAPON
		for k: String in w["gear"]:
			g.set(k, w["gear"][k])
		g.weapon_type = load(type_path)
		var gear_path := "res://data/gear/%s.tres" % g.id
		ResourceSaver.save(g, gear_path)
		var r := RecipeDefinition.new()
		r.id = g.id
		r.result = load(gear_path)
		var counts := PackedInt32Array()
		for inp: Array in w["inputs"]:
			r.inputs.append(load("res://data/items/%s.tres" % inp[0]))
			counts.append(inp[1])
		r.counts = counts
		var recipe_path := "res://data/crafting/recipe_%s.tres" % g.id
		ResourceSaver.save(r, recipe_path)
		var recipe := load(recipe_path) as RecipeDefinition
		var found := false
		for i in catalog.recipes.size():
			if catalog.recipes[i].id == recipe.id:
				catalog.recipes[i] = recipe
				found = true
		if not found:
			catalog.recipes.append(recipe)
		print("weapon ", g.id, " (", t.display_name, ")")
	ResourceSaver.save(catalog, "res://data/crafting/catalog.tres")
	quit()
