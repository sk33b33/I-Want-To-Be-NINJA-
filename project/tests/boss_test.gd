extends TestCase
## Phase 5: Kurogale — elements, telegraphed attacks + counterplay, antler part break (once),
## enrage, victory rewards recorded once, and the gate bot that defeats it.

const TEST_PROFILE := "user://test_profile_phase5.json"


func _setup_profile() -> void:
	PlayerProfile.path = TEST_PROFILE
	if FileAccess.file_exists(TEST_PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE))


## Flat arena with a ring of pillars (like the real one), the boss in the middle facing +Z.
func _arena(player_at: Vector3 = Vector3(0, 0.05, 8)) -> Array:
	make_floor(Vector3(80, 1, 80))
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.3
		var pillar := make_floor(Vector3(1.6, 8, 1.6), Vector3(cos(a) * 15.0, 4, sin(a) * 15.0))
		pillar.name = "Pillar%d" % i
	var boss := instantiate("res://scenes/bosses/kurogale.tscn") as Kurogale
	boss.ai_seed = 99
	boss.global_position = Vector3(0, 0.1, 0)
	boss.rotation.y = PI
	boss.arena_center = Vector3.ZERO
	var p := make_player(player_at)
	p.set_checkpoint(Transform3D(Basis.IDENTITY, player_at))
	return [boss, p]


func _hit(target: Hurtbox, amount: float, element: StringName = &"", stagger: float = 0.0) -> void:
	var info := DamageInfo.new()
	info.amount = amount
	info.element = element
	info.stagger = stagger
	target.receive(info)


func _tap(action: String) -> void:
	press(action)
	await physics_frames(2)
	release(action)


# ---------------------------------------------------------------- data + elements

func test_boss_data_is_complete_and_every_attack_telegraphs() -> void:
	var def := load("res://data/bosses/kurogale.tres") as BossDefinition
	check(def.elements.affinity == &"nature", "Nature affinity")
	check(def.elements.is_weak_to(&"fire"), "weak to fire")
	check_near(def.elements.multiplier(&"earth"), 0.5, 0.001, "resists earth")
	check_near(def.elements.multiplier(&""), 1.0, 0.001, "physical is neutral")
	check(def.attacks.size() == 4, "four attacks")
	for a in def.attacks:
		check(a.telegraph_time >= 0.8, "%s telegraphs at least 0.8 s" % a.id)
		check(a.recovery_time >= 0.8, "%s has a punish window" % a.id)
		check(a.counterplay != "", "%s documents its counterplay" % a.id)
	check(def.get_part(&"antler") != null and def.get_part(&"antler").reward != null, "antler part has a reward")


func test_fire_deals_bonus_damage() -> void:
	var nodes := _arena()
	var boss: Kurogale = nodes[0]
	await physics_frames(3)
	var body := boss.get_node("BodyHurtbox") as Hurtbox
	var h := boss.get_health()
	_hit(body, 20.0)
	check_near(h.max_health - h.current, 20.0, 0.01, "physical: 20")
	_hit(body, 20.0, &"fire")
	check_near(h.max_health - h.current, 50.0, 0.01, "fire: 20 x 1.5 = 30 more")


func test_one_swing_touching_body_and_antlers_counts_once() -> void:
	var nodes := _arena()
	var boss: Kurogale = nodes[0]
	await physics_frames(3)
	var hb := Hitbox.new()
	hb.team = &"player"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 10, 10)
	col.shape = box
	hb.add_child(col)
	add_node(hb)
	hb.global_position = Vector3(0, 3, -1)
	await physics_frames(3)
	var info := DamageInfo.new()
	info.amount = 10.0
	hb.activate(info)
	await physics_frames(3)
	check_near(boss.get_health().max_health - boss.get_health().current, 10.0, 0.01, "health hit once, not twice")
	check_near(float(boss.part_damage.get(&"antler", 0.0)), 10.0, 0.01, "the hit landed on the antlers")


# ---------------------------------------------------------------- behaviour

func test_dormant_until_awakened_then_intro_then_stalks() -> void:
	var nodes := _arena()
	var boss: Kurogale = nodes[0]
	await physics_frames(30)
	check(boss.state == Kurogale.State.DORMANT, "sleeps until the arena event")
	boss.awaken()
	check(boss.state == Kurogale.State.INTRO, "roars")
	await physics_frames(int(boss.definition.intro_time * 60.0) + 5)
	check(boss.state != Kurogale.State.DORMANT and boss.state != Kurogale.State.INTRO, "fight on")


func _measure_attack(attack_id: StringName, player_at: Vector3) -> Dictionary:
	var nodes := _arena(player_at)
	var boss: Kurogale = nodes[0]
	var p: PlayerController = nodes[1]
	await physics_frames(10)
	boss.awaken()
	await physics_frames(int(boss.definition.intro_time * 60.0) + 2)
	boss.debug_force_attack(attack_id)
	# Expected warning comes from the data, not from the boss (so a broken boss cannot vouch for itself).
	var tele := boss.definition.get_attack(attack_id).telegraph_time
	var start := p.combat.health.current
	var first_damage_at := -1.0
	var t := 0.0
	for i in int((tele + 2.0) * 60.0):
		await tree.physics_frame
		t += 1.0 / 60.0
		if first_damage_at < 0.0 and p.combat.health.current < start:
			first_damage_at = t
	return {"telegraph": tele, "hit_at": first_damage_at, "boss": boss, "player": p}


func test_antler_sweep_warns_then_hits_a_player_in_front() -> void:
	var r := await _measure_attack(&"antler_sweep", Vector3(0, 0.05, 3.2))
	check(r["hit_at"] > 0.0, "sweep connected")
	check(r["hit_at"] >= r["telegraph"] - 0.02, "no damage before the warning ends (%.2f / %.2f)" % [r["hit_at"], r["telegraph"]])


func test_charge_warns_then_hits_and_stuns_on_a_pillar() -> void:
	var r := await _measure_attack(&"charge", Vector3(0, 0.05, 9))
	check(r["hit_at"] >= r["telegraph"] - 0.02, "no damage before the warning ends (%.2f / %.2f)" % [r["hit_at"], r["telegraph"]])
	check(r["hit_at"] > 0.0, "charge connected")


func test_root_snare_warns_then_erupts_under_the_player() -> void:
	var r := await _measure_attack(&"root_snare", Vector3(0, 0.05, 10))
	check(r["hit_at"] > 0.0, "roots erupted under a player who stood still")
	check(r["hit_at"] >= r["telegraph"] - 0.02, "no damage before the rings finish warning (%.2f / %.2f)" % [r["hit_at"], r["telegraph"]])


func test_stepping_out_of_the_snare_rings_avoids_damage() -> void:
	var nodes := _arena(Vector3(0, 0.05, 10))
	var boss: Kurogale = nodes[0]
	var p: PlayerController = nodes[1]
	await physics_frames(10)
	boss.awaken()
	await physics_frames(int(boss.definition.intro_time * 60.0) + 2)
	boss.debug_force_attack(&"root_snare")
	press("move_right")  # Camera yaw 0: world +X, away from the rings (offsets are at +x/+z and -x/-z).
	press("sprint")
	await physics_frames(int(boss.telegraph_seconds(boss.definition.get_attack(&"root_snare")) * 60.0) + 40)
	release("move_right")
	release("sprint")
	check_near(p.combat.health.current, 100.0, 0.01, "escaped the snare")


func test_charge_into_a_pillar_stuns_the_boss() -> void:
	var nodes := _arena(Vector3(0, 0.05, 9))
	var boss: Kurogale = nodes[0]
	var p: PlayerController = nodes[1]
	# Line the player up in front of a pillar, then roll away at the last moment.
	var pillar_dir := Vector3(cos(0.3), 0, sin(0.3))
	p.global_position = pillar_dir * 9.0 + Vector3.UP * 0.05
	await physics_frames(10)
	boss.awaken()
	await physics_frames(int(boss.definition.intro_time * 60.0) + 2)
	boss.debug_force_attack(&"charge")
	await physics_frames(int(boss.telegraph_seconds(boss.definition.get_attack(&"charge")) * 60.0) - 6)
	p.global_position += Vector3(0, 0, -3.5)  # Side-step off the line (instant, to isolate the stun).
	var stunned := [false]
	for i in 90:
		await tree.physics_frame
		stunned[0] = stunned[0] or boss.state == Kurogale.State.STUNNED
	check(stunned[0], "slammed into the pillar and was stunned")


func test_antlers_break_once_and_reward_once() -> void:
	var nodes := _arena()
	var boss: Kurogale = nodes[0]
	await physics_frames(3)
	boss.awaken()
	var broken := [0]
	boss.part_broken.connect(func(_p: BossPartDefinition) -> void: broken[0] += 1)
	var antler := boss.get_node("Visual/AntlerHurtbox") as Hurtbox
	for i in 10:
		_hit(antler, 30.0)
	check(boss.is_part_broken(&"antler"), "antlers broken after 220 damage")
	check(broken[0] == 1, "part_broken emitted exactly once (got %d)" % broken[0])
	check(not (boss.get_node("Visual/Antlers") as Node3D).visible, "antlers gone")
	check((boss.get_node("Visual/AntlerStubs") as Node3D).visible, "stubs shown")
	check(boss.state == Kurogale.State.PART_BREAK, "big stagger on break")
	for i in 5:
		_hit(antler, 30.0)
	check(broken[0] == 1, "further hits never break or reward again")


func test_enrages_once_at_half_health_and_unlocks_thorn_burst() -> void:
	var nodes := _arena()
	var boss: Kurogale = nodes[0]
	await physics_frames(3)
	var count := [0]
	boss.enraged.connect(func() -> void: count[0] += 1)
	var body := boss.get_node("BodyHurtbox") as Hurtbox
	var sweep := boss.definition.get_attack(&"antler_sweep")
	var normal_tele := boss.telegraph_seconds(sweep)
	_hit(body, boss.definition.max_health * 0.55)
	check(boss.is_enraged and count[0] == 1, "enraged at half health")
	_hit(body, 10.0)
	check(count[0] == 1, "enrages only once")
	check(boss.telegraph_seconds(sweep) < normal_tele, "faster telegraphs when enraged")
	var r := await _measure_attack_on(boss, nodes[1], &"thorn_burst")
	var expected := boss.definition.get_attack(&"thorn_burst").telegraph_time * boss.definition.enrage_tempo
	check(r >= expected - 0.02, "thorn burst still warns first (%.2f / %.2f)" % [r, expected])


func _measure_attack_on(boss: Kurogale, p: PlayerController, id: StringName) -> float:
	p.global_position = boss.global_position + Vector3(0, 0.05, 3.0)
	await physics_frames(5)
	boss.debug_force_attack(id)
	var start := p.combat.health.current
	var t := 0.0
	for i in 240:
		await tree.physics_frame
		t += 1.0 / 60.0
		if p.combat.health.current < start:
			return t
	return -1.0


func test_boss_waits_and_keeps_its_wounds_when_the_player_dies() -> void:
	var nodes := _arena()
	var boss: Kurogale = nodes[0]
	var p: PlayerController = nodes[1]
	p.set_checkpoint(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 40)))  # "Gate shrine" outside the arena.
	await physics_frames(5)
	boss.awaken()
	_hit(boss.get_node("BodyHurtbox") as Hurtbox, 200.0)
	var info := DamageInfo.new()
	info.amount = 999.0
	p.combat.health.apply_damage(info)
	await physics_frames(int(p.combat.config.respawn_delay * 60.0) + 120)
	check(p.combat.state == PlayerCombat.State.READY, "player respawned")
	check(p.global_position.z > 30.0, "back at the shrine")
	check_near(boss.get_health().current, boss.definition.max_health - 200.0, 0.01, "boss keeps its damage")
	check(boss.global_position.distance_to(boss.arena_center) < 3.0, "boss waits at the arena centre")


# ---------------------------------------------------------------- expedition integration

func test_victory_records_rewards_once_and_shows_results() -> void:
	_setup_profile()
	var main := instantiate("res://scenes/main/main.tscn")
	var m := main.get_node("Expedition") as ExpeditionManager
	var boss := main.get_node("Level/Boss") as Kurogale
	var results := main.get_node("UI/ExpeditionResults") as ExpeditionResults
	var ended := [{}]
	m.expedition_ended.connect(func(r: Dictionary) -> void: ended[0] = r)
	await physics_frames(10)
	var player := main.get_node("Player") as PlayerController
	player.global_position = Vector3(0, 0.5, -104)
	await physics_frames(10)
	check(m.arena_entered and boss.state != Kurogale.State.DORMANT, "arena entry woke the boss")
	var antler := boss.get_node("Visual/AntlerHurtbox") as Hurtbox
	for i in 8:
		_hit(antler, 30.0)
	_hit(antler, 30.0)  # Extra hits after the break.
	check(int(m.run_rewards.get(&"thornback_antler", 0)) == 1, "antler reward granted once")
	_hit(boss.get_node("BodyHurtbox") as Hurtbox, 5000.0)
	await physics_frames(5)
	check(boss.state == Kurogale.State.DEFEATED, "defeated")
	_hit(boss.get_node("BodyHurtbox") as Hurtbox, 5000.0)  # Hitting the corpse changes nothing.
	await physics_frames(int(boss.definition.death_time * 60.0) + 30)
	check(ended[0].get("outcome") == "victory", "victory outcome")
	check(results.visible, "results shown")
	var profile := PlayerProfile.load_profile()
	check(profile.count(&"thornback_antler") == 1, "antler saved once (got %d)" % profile.count(&"thornback_antler"))
	check(profile.count(&"kurogale_hide") == 1, "hide saved once (got %d)" % profile.count(&"kurogale_hide"))
	check(int(profile.hunts_completed.get("kurogale", 0)) == 1, "hunt recorded")
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH


func test_hunt_board_shows_earned_materials() -> void:
	_setup_profile()
	var p := PlayerProfile.new()
	p.add_material(&"thornback_antler", 2)
	p.save()
	var board := instantiate("res://scenes/ui/hunt_board.tscn") as HuntBoard
	await process_frames(2)
	check(board.materials_label.text.contains("Thornback Antler ×2"), "board lists materials (%s)" % board.materials_label.text)
	PlayerProfile.path = PlayerProfile.DEFAULT_PATH


func test_ember_talisman_flies_to_the_target_and_burns() -> void:
	var nodes := _arena(Vector3(0, 0.05, 9))
	var boss: Kurogale = nodes[0]
	var p: PlayerController = nodes[1]
	await physics_frames(10)
	await _tap("lock_on")
	await physics_frames(2)
	check(p.combat.lock_target == boss, "locked on the boss")
	await _tap("skill")
	await physics_frames(70)
	var lost := boss.get_health().max_health - boss.get_health().current
	check_near(lost, 18.0 * 1.5, 0.01, "talisman hit for fire damage (lost %.1f)" % lost)
	check(p.combat.skill_cooldown_left > 0.0, "skill on cooldown")
	await _tap("skill")
	await physics_frames(70)
	check_near(boss.get_health().max_health - boss.get_health().current, lost, 0.01, "no second throw during cooldown")


# ---------------------------------------------------------------- gate

## Phase 5 gate: a bot reads the telegraphs (roll away from sweeps, sideways off charges, out of
## snare rings and burst range), punishes openings (heads-down antler hits, talisman on
## cooldown) and defeats Kurogale, breaking its antlers.
func test_gate_bot_defeats_kurogale_and_breaks_antlers() -> void:
	var nodes := _arena(Vector3(0, 0.05, 8))
	var boss: Kurogale = nodes[0]
	var p: PlayerController = nodes[1]
	var deaths := [0]
	p.combat.player_died.connect(func() -> void: deaths[0] += 1)
	await physics_frames(10)
	boss.awaken()
	var reacted_to := -1
	var attack_count := 0
	for frame in 60 * 300:
		await tree.physics_frame
		if boss.state == Kurogale.State.DEFEATED:
			break
		if p.combat.state == PlayerCombat.State.DEAD:
			continue
		if p.combat.lock_target == null:
			await _tap("lock_on")
		var to_boss := boss.global_position - p.global_position
		to_boss.y = 0.0
		var dist := to_boss.length()
		for m in ["move_forward", "move_back", "move_left", "move_right", "sprint"]:
			Input.action_release(m)
		if boss.state == Kurogale.State.TELEGRAPH:
			var a := boss.current_attack
			var left := boss.telegraph_seconds(a) - boss.state_time()
			match a.id:
				&"root_snare":
					Input.action_press("move_left")  # Strafe around the boss, out of the rings.
					Input.action_press("sprint")
				&"thorn_burst":
					if dist < 6.5:
						Input.action_press("move_back")
						Input.action_press("sprint")
				_:
					if left < 0.18 and reacted_to != attack_count:
						reacted_to = attack_count
						Input.action_press("move_left" if a.id == &"charge" else "move_back")
						await _tap("dodge")
			continue
		if boss.state == Kurogale.State.ATTACK:
			attack_count += 1 if boss.state_time() < 0.02 else 0
			continue
		var opening := boss.state in [Kurogale.State.RECOVER, Kurogale.State.STAGGER, Kurogale.State.STUNNED, Kurogale.State.PART_BREAK]
		if p.combat.skill_cooldown_left <= 0.0 and p.combat.state == PlayerCombat.State.READY:
			await _tap("skill")
			continue
		# Aim for the antlers: stand in front of the lowered head.
		var head_spot := boss.global_position - boss.global_basis.z * 4.6
		head_spot.y = p.global_position.y
		var to_spot := head_spot - p.global_position
		if to_spot.length() > 1.2 and not opening:
			Input.action_press("move_forward")
			if dist > 8.0:
				Input.action_press("sprint")
		elif to_spot.length() > 1.2 and opening and p.combat.state == PlayerCombat.State.READY:
			Input.action_press("move_forward")
		if dist < 6.5 and opening and p.combat.state == PlayerCombat.State.READY:
			await _tap("attack_heavy" if frame % 3 == 0 else "attack_light")
	for m in ["move_forward", "move_back", "move_left", "move_right", "sprint"]:
		Input.action_release(m)
	print("        gate bot: boss hp %.0f, antler dmg %.0f, player deaths %d" % [
			boss.get_health().current, float(boss.part_damage.get(&"antler", 0.0)), deaths[0]])
	check(boss.state == Kurogale.State.DEFEATED, "Kurogale defeated (hp left %.0f)" % boss.get_health().current)
	check(boss.is_part_broken(&"antler"), "antlers broken during the fight")
