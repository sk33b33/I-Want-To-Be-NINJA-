extends SceneTree
## Phase 13 part 3 (secrets & exploration): writes the Spirit Relic item, one SecretSet per jungle
## (data/secrets/<biome>.tres: three hidden spirit shrines with riddle hints + a Shrine Blessing)
## and the Spirit Charm (forged from relics) into the forge catalog. Positions were chosen on
## flat ground off the route, clear of hazards; secrets_test.gd checks every one is placeable
## and that the bot can reach and take each relic. Re-run any time.
##   godot --headless --path project -s ../tools/generate_secrets.gd

const SETS := {
	"verdant_canopy": [
		{"id": &"verdant_pillar_west", "name": "Moss Pillar", "kind": SecretDefinition.Kind.PILLAR, "pos": Vector2(-20, -18), "height": 5.0,
			"hint": "Before the gorge, west of the path, a mossy pillar keeps something on its head. Climb it."},
		{"id": &"verdant_nook_east", "name": "Root Hollow", "kind": SecretDefinition.Kind.NOOK, "pos": Vector2(17, -84), "gap": Vector2(-1, 0),
			"hint": "Past the gorge, east of the path, boulders huddle around a light. Find the gap."},
		{"id": &"verdant_pillar_far", "name": "Last Watch", "kind": SecretDefinition.Kind.PILLAR, "pos": Vector2(-18, -100), "height": 6.0,
			"hint": "Near the beast's clearing, a tall stone watches the west. Its top holds a gift."},
	],
	"emberwild": [
		{"id": &"ember_nook_west", "name": "Ash Circle", "kind": SecretDefinition.Kind.NOOK, "pos": Vector2(-18, -20), "gap": Vector2(1, 0),
			"hint": "Where the vents still sleep, west of the path, stones sit in a ring around an ember-cold light."},
		{"id": &"ember_pillar_east", "name": "Basalt Finger", "kind": SecretDefinition.Kind.PILLAR, "pos": Vector2(14, -24), "height": 5.0,
			"hint": "East of the heat, a basalt finger points at the sky. Climb it before the river."},
		{"id": &"ember_pillar_far", "name": "Cinder Spire", "kind": SecretDefinition.Kind.PILLAR, "pos": Vector2(-16, -88), "height": 6.0,
			"hint": "Across the lava, west of the path, a spire waits for someone who climbs."},
	],
	"moonfen": [
		{"id": &"fen_pillar_east", "name": "Reed Stone", "kind": SecretDefinition.Kind.PILLAR, "pos": Vector2(15, -8), "height": 5.0,
			"hint": "Before the mud, east of the path, a stone stands out of the reeds. Look on top."},
		{"id": &"fen_nook_west", "name": "Lantern Ring", "kind": SecretDefinition.Kind.NOOK, "pos": Vector2(-17, -86), "gap": Vector2(1, 0),
			"hint": "Beyond the bog, west of the path, a ring of stones hides a lantern-light."},
		{"id": &"fen_pillar_far", "name": "Drowned Spire", "kind": SecretDefinition.Kind.PILLAR, "pos": Vector2(15, -97), "height": 6.0,
			"hint": "Near the serpent's water, east of the path, a spire rises from the fen."},
	],
	"stormcrag": [
		{"id": &"crag_nook_west", "name": "Wind Shelter", "kind": SecretDefinition.Kind.NOOK, "pos": Vector2(-18, -10), "gap": Vector2(1, 0),
			"hint": "Below the cliff, west of the path, stones shelter something from the wind."},
		{"id": &"crag_pillar_east", "name": "Thunder Post", "kind": SecretDefinition.Kind.PILLAR, "pos": Vector2(13, -84), "height": 5.0,
			"hint": "After the ridge, east of the path, a post that lightning never hits. Climb it."},
		{"id": &"crag_pillar_far", "name": "Storm Spire", "kind": SecretDefinition.Kind.PILLAR, "pos": Vector2(-17, -104), "height": 6.0,
			"hint": "By the temple steps, west of the path, the highest stone keeps the storm's gift."},
	],
}
const BLESSING := {"verdant_canopy": "Blessing of the Canopy", "emberwild": "Blessing of the Ember",
	"moonfen": "Blessing of the Fen", "stormcrag": "Blessing of the Storm"}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/secrets"))
	var relic := ItemDefinition.new()
	relic.id = &"spirit_relic"
	relic.display_name = "Spirit Relic"
	relic.description = "A crystal from a hidden jungle shrine. It is warm, and it remembers."
	relic.color = Color(0.6, 0.95, 1.0)
	relic.rarity = 2
	ResourceSaver.save(relic, "res://data/items/spirit_relic.tres")
	relic = load("res://data/items/spirit_relic.tres")
	for biome: String in SETS:
		var set_data := SecretSet.new()
		set_data.biome_id = StringName(biome)
		set_data.blessing_name = BLESSING[biome]
		set_data.blessing_health = 10.0
		set_data.relic_item = relic
		for s: Dictionary in SETS[biome]:
			var d := SecretDefinition.new()
			d.id = s["id"]
			d.display_name = s["name"]
			d.hint = s["hint"]
			d.kind = s["kind"]
			d.position = s["pos"]
			d.height = s.get("height", 5.0)
			d.gap_direction = s.get("gap", Vector2(1, 0))
			set_data.secrets.append(d)
		ResourceSaver.save(set_data, "res://data/secrets/%s.tres" % biome)
		print("secrets ", biome, " x", set_data.secrets.size())
	# Spirit Charm: forged from relics found in at least two jungles.
	var charm := GearDefinition.new()
	charm.id = &"spirit_charm"
	charm.display_name = "Spirit Charm"
	charm.description = "Relics from the hidden shrines, bound with red thread. The talisman answers faster."
	charm.slot = GearDefinition.Slot.CHARM
	charm.color = Color(0.6, 0.95, 1.0)
	charm.skill_cooldown_reduction = 1.5
	charm.skill_damage_multiplier = 1.15
	charm.max_health_bonus = 10.0
	ResourceSaver.save(charm, "res://data/gear/spirit_charm.tres")
	var r := RecipeDefinition.new()
	r.id = &"spirit_charm"
	r.result = load("res://data/gear/spirit_charm.tres")
	r.inputs.append(relic)
	r.counts = PackedInt32Array([5])
	ResourceSaver.save(r, "res://data/crafting/recipe_spirit_charm.tres")
	var catalog := load("res://data/crafting/catalog.tres") as CraftingCatalog
	var recipe := load("res://data/crafting/recipe_spirit_charm.tres") as RecipeDefinition
	var found := false
	for i in catalog.recipes.size():
		if catalog.recipes[i].id == recipe.id:
			catalog.recipes[i] = recipe
			found = true
	if not found:
		catalog.recipes.append(recipe)
	if not catalog.items.has(relic):
		catalog.items.append(relic)
	ResourceSaver.save(catalog, "res://data/crafting/catalog.tres")
	quit()
