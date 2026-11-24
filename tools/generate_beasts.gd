extends SceneTree
## Phase 13: the second beast of each jungle, built from data below by one shared builder.
## Writes items, boss data, boss scenes and hunts, and adds each hunt to its jungle (after the
## jungle's first beast). Run AFTER tools/generate_visual_pass.gd (which rewrites the biomes):
##   godot --headless --path project -s ../tools/generate_beasts.gd

const MAT := "res://data/materials/"


func _initialize() -> void:
	for spec in _beasts():
		_build(spec)
	print("BEASTS GENERATED")
	quit(0)


# ---------------------------------------------------------------- the four beasts

func _beasts() -> Array:
	return [
		{
			"id": "kamakiri", "name": "Kamakiri", "epithet": "the Ironbark Mantis", "biome": "verdant_canopy",
			"after": "kurogale", "element": "Nature", "weakness": "Fire", "signature": "Scythe cross, leaping strike",
			"description": "A mantis grown from ironwood bark that hunts from the ruins' shadows. Its scythes cut stone; fire cracks its shell.",
			"affinity": &"nature", "multipliers": {&"fire": 1.5, &"nature": 0.5, &"water": 0.85},
			"body": ProceduralMeshes.mantis_body, "part_mesh": ProceduralMeshes.mantis_scythes,
			"body_mat": {"body_color": Color(0.2, 0.22, 0.12), "glow_color": Color(0.8, 1.0, 0.3), "glow_energy": 4.0,
					"spine_idle": Color(0.25, 0.35, 0.1), "spine_color": Color(0.8, 1.0, 0.2), "spine_strength": 2.5},
			"part_mat": {"body_color": Color(0.3, 0.3, 0.2), "spine_idle": Color(0.45, 0.48, 0.3), "spine_color": Color(1.0, 0.9, 0.4), "spine_strength": 1.5},
			"max_health": 950.0, "poise": 120.0, "walk": 3.4, "turn": 4.5, "stalk": 4.8, "interval": 1.2,
			"lock": Vector3(0, 2.6, -1.0), "pitch": -0.5, "collision": [Vector3(2.0, 3.0, 3.6), Vector3(0, 1.5, 0.6)],
			"body_hurt": [Vector3(2.4, 3.2, 4.0), Vector3(0, 1.7, 0.5)],
			"part": {"id": &"scythes", "name": "Scythes", "health": 230.0, "hurt": [Vector3(2.6, 2.4, 2.2), Vector3(0, 2.3, -1.6)],
					"reward": ["mantis_scythe", "Mantis Scythe", "A serrated scythe of ironbark, sharper than forged steel.", Color(0.8, 0.85, 0.5), 1]},
			"victory": ["ironbark_carapace", "Ironbark Carapace", "A plate of the mantis's bark-hard shell.", Color(0.35, 0.3, 0.2), 0],
			"front": {"node": "Cross", "hit": [Vector3(5.0, 2.6, 4.0), Vector3(0, 1.3, -3.2)], "warn": [Vector2(5.5, 4.5), Vector3(0, 0.12, -3.3)]},
			"dash_radius": 2.0, "radial": 6.0, "eruption": "res://scenes/bosses/root_snare.tscn",
			"attacks": [
				{"kind": "FRONT", "id": "scythe_cross", "name": "Scythe Cross", "t": [1.0, 0.35, 1.1], "dmg": 26.0, "kb": 10.0, "range": [0.0, 5.5],
						"counter": "Both scythes rise and cross: step back out of the zone, then strike the scythes as they bury in the ground."},
				{"kind": "DASH", "id": "leaping_strike", "name": "Leaping Strike", "t": [1.0, 1.0, 1.4], "dmg": 28.0, "kb": 12.0, "range": [6.0, 26.0],
						"speed": 13.0, "homing": 0.8, "counter": "It crouches and springs along the line: roll sideways late; it stuns itself on the pillars."},
				{"kind": "ERUPTIONS", "id": "seed_burst", "name": "Seed Burst", "t": [1.3, 0.5, 1.0], "dmg": 20.0, "kb": 6.0, "range": [3.0, 26.0],
						"counter": "It flicks thorn seeds around you: get out of the green circles before they sprout."},
				{"kind": "RADIAL", "id": "whirl", "name": "Whirling Scythes", "t": [1.2, 0.5, 1.0], "dmg": 24.0, "kb": 9.0, "range": [0.0, 6.0],
						"counter": "Enraged: it spins with both scythes out — leave the ring."},
			],
		},
		{
			"id": "kasai", "name": "Kasai", "epithet": "the Cinder Salamander", "biome": "emberwild",
			"after": "ashen_oni_tortoise", "element": "Fire", "weakness": "Water", "signature": "Flame breath, belly slide",
			"description": "A salamander that swims through lava as if it were water. Its tail burns hottest — cut it and the fire goes out of it.",
			"affinity": &"fire", "multipliers": {&"water": 1.5, &"fire": 0.25, &"nature": 0.75},
			"body": ProceduralMeshes.salamander_body, "part_mesh": ProceduralMeshes.salamander_tail,
			"body_mat": {"body_color": Color(0.15, 0.08, 0.06), "glow_color": Color(1.0, 0.6, 0.1), "glow_energy": 4.0,
					"spine_idle": Color(0.6, 0.18, 0.05), "spine_color": Color(1.0, 0.45, 0.05), "spine_strength": 3.0},
			"part_mat": {"body_color": Color(0.2, 0.08, 0.05), "glow_color": Color(1.0, 0.55, 0.1), "glow_energy": 5.0,
					"spine_idle": Color(0.7, 0.25, 0.05), "spine_color": Color(1.0, 0.6, 0.1), "spine_strength": 2.5},
			"max_health": 1050.0, "poise": 140.0, "walk": 2.8, "turn": 3.5, "stalk": 5.5, "interval": 1.3,
			"lock": Vector3(0, 1.4, -2.2), "pitch": -0.25, "collision": [Vector3(2.4, 1.8, 5.4), Vector3(0, 0.9, 0.2)],
			"body_hurt": [Vector3(2.8, 2.0, 5.8), Vector3(0, 1.0, 0.2)],
			"part": {"id": &"tail", "name": "Tail", "health": 240.0, "hurt": [Vector3(1.8, 2.0, 3.6), Vector3(0, 1.0, 4.6)],
					"reward": ["cinder_tail", "Cinder Tail", "The salamander's tail tip, still smouldering.", Color(1.0, 0.5, 0.2), 1]},
			"victory": ["salamander_hide", "Salamander Hide", "Slick, heat-proof hide.", Color(0.35, 0.15, 0.1), 0],
			"front": {"node": "Breath", "hit": [Vector3(3.6, 2.4, 9.0), Vector3(0, 1.0, -6.6)], "warn": [Vector2(4.0, 9.5), Vector3(0, 0.12, -6.6)]},
			"dash_radius": 2.2, "radial": 6.5, "eruption": "res://scenes/bosses/lava_burst.tscn",
			"attacks": [
				{"kind": "FRONT", "id": "flame_breath", "name": "Flame Breath", "t": [1.2, 0.5, 1.2], "dmg": 26.0, "kb": 8.0, "range": [0.0, 9.0],
						"counter": "Its throat glows and the strip in front of it lights up: step to the side — its tail is open behind it."},
				{"kind": "DASH", "id": "belly_slide", "name": "Belly Slide", "t": [1.0, 1.2, 1.5], "dmg": 26.0, "kb": 12.0, "range": [6.0, 26.0],
						"speed": 12.0, "homing": 1.0, "counter": "It drops flat and slides at you: roll sideways late; it stuns itself on the pillars."},
				{"kind": "ERUPTIONS", "id": "magma_spit", "name": "Magma Spit", "t": [1.3, 0.5, 1.0], "dmg": 22.0, "kb": 6.0, "range": [3.0, 26.0],
						"counter": "Glowing circles open under you: step out before the magma lands."},
				{"kind": "RADIAL", "id": "cinder_ring", "name": "Cinder Ring", "t": [1.2, 0.4, 1.0], "dmg": 24.0, "kb": 9.0, "range": [0.0, 6.5],
						"counter": "Enraged: the ground around it glows; get out of the ring."},
			],
		},
		{
			"id": "gamakage", "name": "Gamakage", "epithet": "the Bog Toad", "biome": "moonfen",
			"after": "nami", "element": "Water / Poison", "weakness": "Lightning", "signature": "Tongue lash, belly flop",
			"description": "A toad as big as a hut that sleeps under the bog. Its throat sac swells with poison; storms make it croak in fear.",
			"affinity": &"water", "multipliers": {&"lightning": 1.5, &"water": 0.5, &"poison": 0.25, &"fire": 0.75},
			"body": ProceduralMeshes.toad_body, "part_mesh": ProceduralMeshes.toad_sac,
			"body_mat": {"body_color": Color(0.1, 0.14, 0.08), "glow_color": Color(1.0, 0.85, 0.2), "glow_energy": 4.0,
					"spine_idle": Color(0.35, 0.5, 0.1), "spine_color": Color(0.7, 1.0, 0.2), "spine_strength": 2.5},
			"part_mat": {"body_color": Color(0.3, 0.4, 0.1), "glow_color": Color(0.6, 1.0, 0.2), "glow_energy": 3.0,
					"spine_idle": Color(0.4, 0.6, 0.1), "spine_color": Color(0.8, 1.0, 0.3), "spine_strength": 2.0},
			"max_health": 1150.0, "poise": 160.0, "walk": 2.4, "turn": 3.0, "stalk": 5.5, "interval": 1.4,
			"lock": Vector3(0, 1.8, -1.8), "pitch": -0.3, "collision": [Vector3(3.6, 2.8, 4.4), Vector3(0, 1.4, 0.2)],
			"body_hurt": [Vector3(3.8, 3.0, 4.6), Vector3(0, 1.5, 0.2)],
			"part": {"id": &"sac", "name": "Throat sac", "health": 250.0, "hurt": [Vector3(2.4, 2.0, 1.8), Vector3(0, 1.1, -2.2)],
					"reward": ["toxin_sac", "Toxin Sac", "A swollen gland full of glowing bog venom.", Color(0.6, 1.0, 0.25), 1]},
			"victory": ["bog_toad_hide", "Bog Toad Hide", "Rubbery, damp and impossible to tear.", Color(0.2, 0.3, 0.15), 0],
			"front": {"node": "Tongue", "hit": [Vector3(2.4, 2.0, 10.0), Vector3(0, 1.0, -7.0)], "warn": [Vector2(2.8, 10.5), Vector3(0, 0.12, -7.0)]},
			"dash_radius": 2.8, "radial": 7.0, "eruption": "res://scenes/bosses/spirit_spout.tscn",
			"attacks": [
				{"kind": "FRONT", "id": "tongue_lash", "name": "Tongue Lash", "t": [1.1, 0.35, 1.2], "dmg": 24.0, "kb": 10.0, "range": [0.0, 10.0],
						"counter": "It opens its mouth and the long strip in front lights up: step sideways out of the line."},
				{"kind": "DASH", "id": "belly_flop", "name": "Belly Flop", "t": [1.2, 1.0, 1.6], "dmg": 30.0, "kb": 13.0, "range": [6.0, 26.0],
						"speed": 10.0, "homing": 0.6, "counter": "It crouches and hops at you: roll sideways late; it stuns itself on the pillars."},
				{"kind": "ERUPTIONS", "id": "venom_bubbles", "name": "Venom Bubbles", "t": [1.4, 0.5, 1.0], "dmg": 20.0, "kb": 5.0, "range": [3.0, 26.0],
						"counter": "Bubbling circles open under you: keep moving and get out before they burst."},
				{"kind": "RADIAL", "id": "croak_shock", "name": "Croak Shock", "t": [1.2, 0.4, 1.0], "dmg": 22.0, "kb": 10.0, "range": [0.0, 7.0],
						"counter": "Enraged: its sac swells and the ground around it ripples — get out of the ring."},
			],
		},
		{
			"id": "kazekiri", "name": "Kazekiri", "epithet": "the Gale Wolf", "biome": "stormcrag",
			"after": "raijins_echo", "element": "Lightning", "weakness": "Earth", "signature": "Gale claw, thunder lunge",
			"description": "A wolf that runs ahead of the storm, faster than its own thunder. Stone-charms ground its sparks; its fangs hold the lightning.",
			"affinity": &"lightning", "multipliers": {&"earth": 1.5, &"lightning": 0.25, &"water": 0.85},
			"body": ProceduralMeshes.wolf_body, "part_mesh": ProceduralMeshes.wolf_fangs,
			"body_mat": {"body_color": Color(0.12, 0.13, 0.16), "glow_color": Color(0.6, 0.85, 1.0), "glow_energy": 5.0,
					"spine_idle": Color(0.3, 0.35, 0.5), "spine_color": Color(0.7, 0.9, 1.0), "spine_strength": 3.0, "flap_amount": 0.0},
			"part_mat": {"body_color": Color(0.8, 0.85, 0.9), "glow_color": Color(0.7, 0.9, 1.0), "glow_energy": 3.0,
					"spine_idle": Color(0.7, 0.75, 0.85), "spine_color": Color(0.8, 0.95, 1.0), "spine_strength": 2.0},
			"max_health": 980.0, "poise": 120.0, "walk": 3.8, "turn": 5.0, "stalk": 4.8, "interval": 1.15,
			"lock": Vector3(0, 2.0, -1.6), "pitch": -0.45, "collision": [Vector3(1.6, 2.4, 4.2), Vector3(0, 1.2, 0.3)],
			"body_hurt": [Vector3(2.0, 2.6, 4.6), Vector3(0, 1.4, 0.2)],
			"part": {"id": &"fangs", "name": "Storm fangs", "health": 220.0, "hurt": [Vector3(2.2, 2.2, 2.0), Vector3(0, 1.8, -2.4)],
					"reward": ["gale_fang", "Gale Fang", "A fang that never stops crackling.", Color(0.75, 0.9, 1.0), 1]},
			"victory": ["gale_pelt", "Gale Pelt", "A storm-grey pelt that sheds rain.", Color(0.4, 0.45, 0.55), 0],
			"front": {"node": "Claw", "hit": [Vector3(5.0, 2.4, 3.8), Vector3(0, 1.2, -3.2)], "warn": [Vector2(5.5, 4.2), Vector3(0, 0.12, -3.3)]},
			"dash_radius": 2.0, "radial": 6.0, "eruption": "res://scenes/bosses/storm_bolt.tscn",
			"attacks": [
				{"kind": "FRONT", "id": "gale_claw", "name": "Gale Claw", "t": [1.0, 0.35, 1.1], "dmg": 24.0, "kb": 11.0, "range": [0.0, 5.5],
						"counter": "It rears and the zone in front lights up: back out, then strike the fangs as it lands."},
				{"kind": "DASH", "id": "thunder_lunge", "name": "Thunder Lunge", "t": [1.0, 1.0, 1.4], "dmg": 28.0, "kb": 13.0, "range": [6.0, 26.0],
						"speed": 15.0, "homing": 0.7, "counter": "It crouches and bolts along the line: roll sideways late; it stuns itself on the pillars."},
				{"kind": "ERUPTIONS", "id": "storm_howl", "name": "Storm Howl", "t": [1.3, 0.4, 1.0], "dmg": 22.0, "kb": 6.0, "range": [3.0, 26.0],
						"counter": "It howls and pale circles open around you: step out before the bolts fall."},
				{"kind": "RADIAL", "id": "static_burst", "name": "Static Burst", "t": [1.2, 0.4, 1.0], "dmg": 24.0, "kb": 10.0, "range": [0.0, 6.0],
						"counter": "Enraged: its mane crackles and the ground around it sparks — leave the ring."},
			],
		},
	]


# ---------------------------------------------------------------- builder

func _build(s: Dictionary) -> void:
	var id: String = s["id"]
	var body_mat := _save(_creature_mat(s["body_mat"]), MAT + "%s_body.tres" % id)
	var part_mat := _save(_creature_mat(s["part_mat"]), MAT + "%s_part.tres" % id)
	var reward := _item(s["part"]["reward"])
	var victory := _item(s["victory"])
	# Boss data.
	var el := ElementProfile.new()
	el.affinity = s["affinity"]
	el.multipliers = s["multipliers"]
	var attacks: Array[BossAttackDefinition] = []
	for a: Dictionary in s["attacks"]:
		attacks.append(_attack(a, s))
	var part := BossPartDefinition.new()
	part.id = s["part"]["id"]
	part.display_name = s["part"]["name"]
	part.break_health = s["part"]["health"]
	part.reward = reward
	part.reward_count = 1
	part.break_stagger_time = 2.3
	part.intact_node = NodePath("Visual/Part")
	part.broken_node = NodePath("Visual/PartStub")
	var def := BossDefinition.new()
	def.id = StringName(id)
	def.display_name = "%s, %s" % [s["name"], s["epithet"]]
	def.max_health = s["max_health"]
	def.poise = s["poise"]
	def.stagger_time = 1.5
	def.elements = el
	def.attacks = attacks
	def.parts = [part] as Array[BossPartDefinition]
	def.victory_rewards = [victory] as Array[ItemDefinition]
	def.walk_speed = s["walk"]
	def.turn_sharpness = s["turn"]
	def.stalk_distance = s["stalk"]
	def.attack_interval = s["interval"]
	def.head_down_pitch = s["pitch"]
	def.lock_offset = s["lock"]
	_save(def, "res://data/bosses/%s.tres" % id)
	# Scene.
	_pack(_scene(s, load("res://data/bosses/%s.tres" % id), body_mat, part_mat), "res://scenes/bosses/%s.tscn" % id)
	# Hunt, added to its jungle after the first beast.
	var h := HuntDefinition.new()
	h.id = StringName(id)
	h.beast_name = s["name"]
	h.epithet = s["epithet"]
	h.element = s["element"]
	h.weakness = s["weakness"]
	h.signature = s["signature"]
	h.description = s["description"]
	h.config = load("res://data/expedition/default_expedition.tres")
	h.boss_scene = load("res://scenes/bosses/%s.tscn" % id)
	h.requires_hunt = StringName(s["after"])
	_save(h, "res://data/hunts/%s.tres" % id)
	var biome: BiomeDefinition = load("res://data/biomes/biome_%s.tres" % s["biome"])
	var hunts: Array[HuntDefinition] = []
	for existing in biome.hunts:
		if existing.id != h.id:
			hunts.append(existing)
	hunts.append(load("res://data/hunts/%s.tres" % id))
	biome.hunts = hunts
	_save(biome, "res://data/biomes/biome_%s.tres" % s["biome"])
	var catalog: CraftingCatalog = load("res://data/crafting/catalog.tres")
	for it in [reward, victory]:
		if not catalog.items.any(func(x: ItemDefinition) -> bool: return x.id == it.id):
			catalog.items.append(it)
	_save(catalog, "res://data/crafting/catalog.tres")


func _attack(a: Dictionary, s: Dictionary) -> BossAttackDefinition:
	var b := BossAttackDefinition.new()
	b.id = StringName(a["id"])
	b.display_name = a["name"]
	b.telegraph_time = a["t"][0]
	b.active_time = a["t"][1]
	b.recovery_time = a["t"][2]
	b.damage = a["dmg"]
	b.knockback = a["kb"]
	b.min_range = a["range"][0]
	b.max_range = a["range"][1]
	b.weight = 3.0 if a["kind"] == "FRONT" else 2.0
	b.cooldown = 3.0 if a["kind"] == "FRONT" else 6.0
	b.counterplay = a["counter"]
	b.element = s["affinity"]
	match a["kind"]:
		"FRONT":
			b.kind = BossAttackDefinition.Kind.FRONT
			b.hitbox_node = NodePath("Front/%sHitbox" % s["front"]["node"])
			b.warning_node = NodePath("Front/%sWarning" % s["front"]["node"])
			b.telegraph_pitch = 0.35
			b.glow = BossAttackDefinition.Glow.BODY
			b.weakened_by_part = s["part"]["id"]
		"DASH":
			b.kind = BossAttackDefinition.Kind.DASH
			b.hitbox_node = NodePath("Front/DashHitbox")
			b.warning_node = NodePath("Front/DashWarning")
			b.move_speed = a["speed"]
			b.dash_homing = a["homing"]
			b.stuns_on_wall = true
			b.stun_time = 2.6
			b.telegraph_pitch = -0.2
			b.telegraph_wobble = 0.05
		"ERUPTIONS":
			b.kind = BossAttackDefinition.Kind.ERUPTIONS
			b.eruption_scene = load(s["eruption"])
			b.eruption_offsets = PackedVector3Array([Vector3.ZERO, Vector3(3.0, 0, 1.0), Vector3(-3.0, 0, 1.0), Vector3(0, 0, -3.0)])
			b.telegraph_pitch = 0.15
			b.glow = BossAttackDefinition.Glow.PARTS
		"RADIAL":
			b.kind = BossAttackDefinition.Kind.RADIAL
			b.enraged_only = true
			b.hitbox_node = NodePath("BurstHitbox")
			b.warning_node = NodePath("BurstWarning")
			b.telegraph_pitch = 0.2
			b.glow = BossAttackDefinition.Glow.BODY
			b.tracks_player = false
	return b


func _scene(s: Dictionary, def: BossDefinition, body_mat: Material, part_mat: Material) -> Node:
	var k := CharacterBody3D.new()
	k.name = String(s["name"])
	k.set_script(load("res://scripts/bosses/boss_controller.gd"))
	k.set("definition", def)
	var col := CollisionShape3D.new()
	col.name = "Collision"
	col.shape = _box_shape(s["collision"][0])
	col.position = s["collision"][1]
	k.add_child(col)
	var vis := Node3D.new()
	vis.name = "Visual"
	k.add_child(vis)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = (s["body"] as Callable).call(body_mat)
	vis.add_child(body)
	var part := MeshInstance3D.new()
	part.name = "Part"
	part.mesh = (s["part_mesh"] as Callable).call(part_mat, false)
	vis.add_child(part)
	var stub := MeshInstance3D.new()
	stub.name = "PartStub"
	stub.mesh = (s["part_mesh"] as Callable).call(part_mat, true)
	vis.add_child(stub)
	var ph := _area("PartHurtbox", "res://scripts/combat/hurtbox.gd", &"enemy", _box_shape(s["part"]["hurt"][0]), s["part"]["hurt"][1])
	ph.set("part_id", s["part"]["id"])
	ph.set("health_path", NodePath("../../Health"))
	vis.add_child(ph)
	var front := Node3D.new()
	front.name = "Front"
	k.add_child(front)
	var f: Dictionary = s["front"]
	front.add_child(_area("%sHitbox" % f["node"], "res://scripts/combat/hitbox.gd", &"enemy", _box_shape(f["hit"][0]), f["hit"][1]))
	front.add_child(_warning_quad("%sWarning" % f["node"], f["warn"][0], f["warn"][1], "attack_warning" if f["warn"][0].y > 7.0 else "area_warning"))
	var dash := SphereShape3D.new()
	dash.radius = s["dash_radius"]
	front.add_child(_area("DashHitbox", "res://scripts/combat/hitbox.gd", &"enemy", dash, Vector3(0, 1.2, -1.2)))
	front.add_child(_warning_quad("DashWarning", Vector2(3.0, 14.0), Vector3(0, 0.12, -8.5), "attack_warning"))
	var hc := Node.new()
	hc.name = "Health"
	hc.set_script(load("res://scripts/combat/health_component.gd"))
	k.add_child(hc)
	var bh := _area("BodyHurtbox", "res://scripts/combat/hurtbox.gd", &"enemy", _box_shape(s["body_hurt"][0]), s["body_hurt"][1])
	bh.set("health_path", NodePath("../Health"))
	k.add_child(bh)
	var ring := SphereShape3D.new()
	ring.radius = s["radial"]
	k.add_child(_area("BurstHitbox", "res://scripts/combat/hitbox.gd", &"enemy", ring, Vector3(0, 1.0, 0)))
	k.add_child(_warning_quad("BurstWarning", Vector2(s["radial"] * 2.0, s["radial"] * 2.0), Vector3(0, 0.12, 0), "area_warning"))
	return k


# ---------------------------------------------------------------- helpers (as in generate_visual_pass.gd)

func _creature_mat(params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/creature.gdshader")
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


func _item(spec: Array) -> ItemDefinition:
	var it := ItemDefinition.new()
	it.id = StringName(spec[0])
	it.display_name = spec[1]
	it.description = spec[2]
	it.color = spec[3]
	it.rarity = spec[4]
	return _save(it, "res://data/items/%s.tres" % spec[0])


func _save(res: Resource, path: String) -> Resource:
	if res is ShaderMaterial:
		Cc0Surfaces.apply(res, path.get_file().get_basename())  # Beast skin (art pass stage 4).
	if ResourceSaver.save(res, path) != OK:
		push_error("save failed " + path)
	return load(path)


func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = owner
		if child.scene_file_path == "":
			_own(child, owner)


func _pack(root: Node, path: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	if ps.pack(root) != OK:
		push_error("pack failed " + path)
	_save(ps, path)
	root.free()


func _warning_quad(node_name: String, size: Vector2, pos: Vector3, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var q := QuadMesh.new()
	q.size = size
	q.orientation = PlaneMesh.FACE_Y
	q.material = load(MAT + mat + ".tres")
	mi.mesh = q
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _area(node_name: String, script: String, team: StringName, shape: Shape3D, pos: Vector3) -> Area3D:
	var a := Area3D.new()
	a.name = node_name
	a.set_script(load(script))
	a.set("team", team)
	var c := CollisionShape3D.new()
	c.shape = shape
	c.position = pos
	a.add_child(c)
	return a


func _box_shape(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b
