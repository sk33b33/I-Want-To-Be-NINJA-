extends TestCase
## Phase 4 combat: health/hitboxes, light combo, heavy, dodge i-frames, hurt, death + respawn,
## lock-on, the Thornling's telegraphed lunge, and the gate (repeatable loop, no softlock).


func _arena() -> PlayerController:
	make_floor(Vector3(80, 1, 80))
	var p := make_player(Vector3(0, 0.05, 0))
	p.set_checkpoint(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)))
	return p


func _dummy(at: Vector3) -> TrainingDummy:
	var d := instantiate("res://scenes/enemies/training_dummy.tscn") as TrainingDummy
	d.global_position = at
	return d


func _thornling(at: Vector3) -> Thornling:
	var t := instantiate("res://scenes/enemies/thornling.tscn") as Thornling
	t.global_position = at
	t.home = at
	return t


func _tap(action: String) -> void:
	press(action)
	await physics_frames(2)
	release(action)


# ---------------------------------------------------------------- building blocks

func test_health_component_damage_invulnerability_and_death() -> void:
	var h := HealthComponent.new()
	h.max_health = 30.0
	add_node(h)
	var died := [0]
	h.died.connect(func() -> void: died[0] += 1)
	var hit := DamageInfo.new()
	hit.amount = 12.0
	check(h.apply_damage(hit), "damage applies")
	check_near(h.current, 18.0, 0.001, "health reduced")
	h.invulnerable = true
	check(not h.apply_damage(hit), "ignored while invulnerable")
	h.invulnerable = false
	h.apply_damage(hit)
	h.apply_damage(hit)
	check(h.dead and died[0] == 1, "dies exactly once")
	check(not h.apply_damage(hit), "no damage after death")
	h.reset()
	check(not h.dead and h.current == 30.0, "reset revives at full health")


func test_hitbox_hits_each_enemy_once_and_never_its_own_team() -> void:
	var p := _arena()
	var d := _dummy(Vector3(0, 0, -1.2))
	await physics_frames(5)
	var hb := p.combat.hitbox
	var info := DamageInfo.new()
	info.amount = 5.0
	info.source = p
	p.face_direction(Vector3.FORWARD)
	await physics_frames(2)
	hb.activate(info)
	await physics_frames(10)
	hb.deactivate()
	check(d.hits == 1, "dummy hit once per activation (hits=%d)" % d.hits)
	check_near(p.combat.health.current, p.combat.health.max_health, 0.001, "player's own hitbox never hurts the player")


# ---------------------------------------------------------------- player attacks

func test_light_combo_chains_three_hits() -> void:
	var p := _arena()
	var d := _dummy(Vector3(0, 0, -1.6))
	var indices: Array[int] = []
	p.combat.attack_started.connect(func(_a: AttackDefinition, i: int) -> void: indices.append(i))
	await physics_frames(10)
	for i in 3:
		await _tap("attack_light")
		await physics_frames(22)
	await physics_frames(60)
	check(indices == [0, 1, 2], "combo chained light 1 -> 2 -> 3 (got %s)" % [indices])
	check(d.hits == 3, "three hits landed (hits=%d)" % d.hits)
	check_near(d.total_damage, 10.0 + 11.0 + 17.0, 0.01, "combo damage adds up")
	check(p.combat.state == PlayerCombat.State.READY, "back to ready after the combo")


func test_heavy_attack_hits_hard() -> void:
	var p := _arena()
	var d := _dummy(Vector3(0, 0, -1.6))
	await physics_frames(10)
	await _tap("attack_heavy")
	await physics_frames(90)
	check(d.hits == 1, "heavy hit once (hits=%d)" % d.hits)
	check_near(d.total_damage, 32.0, 0.01, "heavy damage")


func test_attack_without_input_buffer_spam_returns_to_ready() -> void:
	var p := _arena()
	await physics_frames(10)
	await _tap("attack_light")
	await physics_frames(5)
	check(p.combat.state == PlayerCombat.State.ATTACK, "attacking")
	await physics_frames(90)
	check(p.combat.state == PlayerCombat.State.READY, "single attack ends cleanly")


# ---------------------------------------------------------------- defence

func _enemy_hit(p: PlayerController, amount: float) -> Hitbox:
	var hb := Hitbox.new()
	hb.team = &"enemy"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 3)
	col.shape = box
	hb.add_child(col)
	add_node(hb)
	hb.global_position = p.global_position + Vector3.UP
	return hb


func test_dodge_iframes_avoid_damage() -> void:
	var p := _arena()
	await physics_frames(10)
	press("move_right")
	await _tap("dodge")
	await physics_frames(4)
	release("move_right")
	check(p.combat.state == PlayerCombat.State.DODGE, "dodging")
	check(p.combat.is_invulnerable(), "invulnerable mid-roll")
	var hb := _enemy_hit(p, 20.0)
	var info := DamageInfo.new()
	info.amount = 20.0
	await physics_frames(2)
	hb.activate(info)
	await physics_frames(3)
	hb.deactivate()
	check_near(p.combat.health.current, 100.0, 0.001, "no damage during i-frames")
	await physics_frames(40)
	check(p.combat.state == PlayerCombat.State.READY, "roll ends")
	check(p.global_position.x > 2.0, "rolled sideways (x=%.2f)" % p.global_position.x)
	hb.global_position = p.global_position + Vector3.UP
	await physics_frames(2)
	hb.activate(info)
	await physics_frames(3)
	check_near(p.combat.health.current, 80.0, 0.001, "hit lands after the roll")


func test_keyboard_shift_tap_dodges_but_hold_sprints() -> void:
	var p := _arena()
	await physics_frames(10)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SHIFT
	key.pressed = true
	Input.parse_input_event(key)
	await physics_frames(3)
	var up := InputEventKey.new()
	up.physical_keycode = KEY_SHIFT
	up.pressed = false
	Input.parse_input_event(up)
	await physics_frames(3)
	check(p.combat.state == PlayerCombat.State.DODGE, "quick Shift tap rolls")
	await physics_frames(40)
	Input.parse_input_event(key)
	await physics_frames(30)
	Input.parse_input_event(up)
	await physics_frames(3)
	check(p.combat.state == PlayerCombat.State.READY, "holding Shift (sprint) does not roll")


func test_getting_hit_causes_brief_hitstun_then_recovers() -> void:
	var p := _arena()
	await physics_frames(10)
	var hb := _enemy_hit(p, 15.0)
	var info := DamageInfo.new()
	info.amount = 15.0
	info.knockback = 6.0
	info.source = hb
	await physics_frames(2)
	hb.global_position = p.global_position + Vector3(0, 1, -1)
	hb.activate(info)
	await physics_frames(3)
	check(p.combat.state == PlayerCombat.State.HURT, "hit-stun")
	check_near(p.combat.health.current, 85.0, 0.001, "took damage")
	await physics_frames(40)
	check(p.combat.state == PlayerCombat.State.READY, "recovers control")
	check(p.global_position.z > 0.3, "knocked back away from the hit (z=%.2f)" % p.global_position.z)


func test_death_respawns_at_checkpoint_with_full_health() -> void:
	var p := _arena()
	p.set_checkpoint(Transform3D(Basis.IDENTITY, Vector3(5, 0.05, 5)))
	await physics_frames(10)
	var died := [0]
	p.combat.player_died.connect(func() -> void: died[0] += 1)
	var info := DamageInfo.new()
	info.amount = 500.0
	p.combat.health.apply_damage(info)
	await physics_frames(5)
	check(died[0] == 1 and p.combat.state == PlayerCombat.State.DEAD, "dead")
	await _tap("attack_light")
	await physics_frames(5)
	check(p.combat.state == PlayerCombat.State.DEAD, "no attacking while dead")
	await physics_frames(int(p.combat.config.respawn_delay * 60.0) + 20)
	check(p.combat.state == PlayerCombat.State.READY, "back in action")
	check_near(p.combat.health.current, p.combat.health.max_health, 0.001, "full health")
	check(Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(5, 5)) < 1.0, "at the checkpoint")


# ---------------------------------------------------------------- lock-on

func test_lock_on_targets_enemy_in_front_and_turns_camera() -> void:
	var p := _arena()
	var behind := _dummy(Vector3(0, 0, 6))
	var front := _dummy(Vector3(8, 0, -8))
	var rig := p.get_node("CameraRig") as CameraRig
	await physics_frames(10)
	await _tap("lock_on")
	await physics_frames(2)
	check(p.combat.lock_target == front, "locks the target ahead, not the one behind (%s)" % p.combat.lock_target)
	await process_frames(90)
	var fwd := -rig.get_yaw_basis().z
	var to := (front.global_position - p.global_position)
	to.y = 0.0
	check(fwd.dot(to.normalized()) > 0.9, "camera turned toward the target (dot=%.2f)" % fwd.dot(to.normalized()))
	await _tap("lock_on")
	await physics_frames(2)
	check(p.combat.lock_target == null, "second press releases")
	behind.queue_free()


func test_lock_releases_when_target_dies() -> void:
	var p := _arena()
	var t := _thornling(Vector3(0, 0.2, -6))
	t.config = t.config.duplicate()
	t.config.aggro_range = 0.0  # Stay passive.
	await physics_frames(10)
	await _tap("lock_on")
	await physics_frames(2)
	check(p.combat.lock_target == t, "locked on the Thornling")
	var info := DamageInfo.new()
	info.amount = 999.0
	t.get_health().apply_damage(info)
	await physics_frames(3)
	check(p.combat.lock_target == null, "lock released on death")


# ---------------------------------------------------------------- Thornling

func test_thornling_telegraphs_then_lunge_hurts_a_player_who_stands_still() -> void:
	var p := _arena()
	var t := _thornling(Vector3(0, 0.2, -7))
	var seen := {}
	var glowed := [false]
	t.state_changed.connect(func(s: Thornling.State) -> void: seen[s] = true)
	t.telegraph_started.connect(func(_d: Vector3) -> void: glowed[0] = true)
	for i in 300:
		await tree.physics_frame
		if p.combat.health.current < 100.0:
			break
	check(seen.has(Thornling.State.CHASE), "chased the player")
	check(glowed[0] and seen.has(Thornling.State.TELEGRAPH), "telegraphed before attacking")
	check(seen.has(Thornling.State.LUNGE), "lunged")
	check_near(p.combat.health.current, 100.0 - t.config.damage, 0.01, "lunge hit for its damage")


func test_well_timed_dodge_avoids_thornling_lunge() -> void:
	var p := _arena()
	var t := _thornling(Vector3(0, 0.2, -7))
	var dodged := [false]
	for i in 400:
		await tree.physics_frame
		if not dodged[0] and t.state == Thornling.State.TELEGRAPH and t._t >= t.config.telegraph_time - 0.12:
			dodged[0] = true
			press("move_right")
			await _tap("dodge")
		if dodged[0] and t.state == Thornling.State.RECOVER:
			break
	release("move_right")
	check(dodged[0], "saw the telegraph and rolled")
	check_near(p.combat.health.current, 100.0, 0.001, "lunge evaded")


func test_heavy_hit_staggers_thornling_out_of_its_telegraph() -> void:
	var p := _arena()
	var t := _thornling(Vector3(0, 0.2, -3.4))
	for i in 200:
		await tree.physics_frame
		if t.state == Thornling.State.TELEGRAPH:
			break
	check(t.state == Thornling.State.TELEGRAPH, "telegraphing")
	p.face_direction(t.global_position - p.global_position)
	await _tap("attack_heavy")
	var staggered := [false]
	for i in 60:
		await tree.physics_frame
		staggered[0] = staggered[0] or t.state == Thornling.State.STAGGER
	check(staggered[0], "heavy hit broke its poise and interrupted the attack")


# ---------------------------------------------------------------- gate

## Phase 4 gate, part 1: a bot uses the whole kit (lock-on, dodge on the tell, punish in the
## recovery) to beat two Thornlings without dying.
func test_gate_bot_defeats_two_thornlings_without_dying() -> void:
	var p := _arena()
	var a := _thornling(Vector3(-2, 0.2, -8))
	var b := _thornling(Vector3(3, 0.2, -10))
	var died := [0]
	p.combat.player_died.connect(func() -> void: died[0] += 1)
	var dodge_side := 1.0
	for frame in 60 * 60:
		await tree.physics_frame
		var alive: Array[Thornling] = []
		for t in [a, b]:
			if is_instance_valid(t) and t.is_alive():
				alive.append(t)
		if alive.is_empty():
			break
		if p.combat.lock_target == null:
			await _tap("lock_on")
		var threat: Thornling = null
		for t in alive:
			if t.state == Thornling.State.TELEGRAPH and t._t >= t.config.telegraph_time - 0.15 \
					and t.global_position.distance_to(p.global_position) < 6.0:
				threat = t
		if threat and p.combat.state == PlayerCombat.State.READY:
			dodge_side = -dodge_side
			Input.action_press("move_right" if dodge_side > 0.0 else "move_left")
			await _tap("dodge")
			Input.action_release("move_right")
			Input.action_release("move_left")
			continue
		var target := p.combat.lock_target as Thornling
		if target and target.is_alive():
			var dist := target.global_position.distance_to(p.global_position)
			var opening := target.state == Thornling.State.RECOVER or target.state == Thornling.State.STAGGER
			if dist > 2.4:
				Input.action_press("move_forward")
			else:
				Input.action_release("move_forward")
				if opening or target.state == Thornling.State.CHASE:
					await _tap("attack_light")
	Input.action_release("move_forward")
	var remaining := 0
	for t in [a, b]:
		if is_instance_valid(t) and t.is_alive():
			remaining += 1
	check(remaining == 0, "both Thornlings defeated (%d left)" % remaining)
	check(died[0] == 0, "the bot never died")


## Phase 4 gate, part 2: 15 s of random button mashing next to a dummy and a Thornling never
## leaves the player stuck: once input stops, control always comes back.
func test_gate_random_input_never_softlocks() -> void:
	var p := _arena()
	_dummy(Vector3(1.5, 0, -2))
	var t := _thornling(Vector3(-3, 0.2, -5))
	t.config = t.config.duplicate()
	t.config.damage = 1.0  # Keep the player alive so we test control, not death.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var actions := ["attack_light", "attack_heavy", "dodge", "jump", "lock_on", "sprint"]
	var moves := ["move_forward", "move_back", "move_left", "move_right"]
	for frame in 60 * 15:
		await tree.physics_frame
		if frame % 6 == 0:
			var act: String = actions[rng.randi_range(0, actions.size() - 1)]
			press(act)
			release.call_deferred(act)
		if frame % 20 == 0:
			for m in moves:
				Input.action_release(m)
			Input.action_press(moves[rng.randi_range(0, moves.size() - 1)])
	for m in moves:
		Input.action_release(m)
	await physics_frames(int(3.0 * 60.0))
	check(p.combat.state == PlayerCombat.State.READY, "combat back to READY (state %d)" % p.combat.state)
	check(p.traversal.state == TraversalComponent.State.NONE, "not stuck in traversal")
	check(p.is_on_floor(), "standing on the ground")
	check(is_finite(p.global_position.x) and is_finite(p.global_position.z), "position is sane")
	await _tap("attack_light")
	await physics_frames(3)
	check(p.combat.state == PlayerCombat.State.ATTACK, "still responds to input")
