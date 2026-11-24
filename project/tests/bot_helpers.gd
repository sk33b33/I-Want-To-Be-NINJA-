class_name BotHelpers
extends RefCounted
## Scripted "players" shared by the gate tests. They only press input actions (like a human with
## perfect timing), so they exercise the real controls, traversal, combat and boss telegraphs.


static func tap(tc: TestCase, action: String) -> void:
	tc.press(action)
	await tc.physics_frames(2)
	tc.release(action)


static func release_moves() -> void:
	for m in ["move_forward", "move_back", "move_left", "move_right", "sprint"]:
		Input.action_release(m)


## Runs the Verdant Canopy route from spawn until z < stop_z: holds forward, steers to the centre
## line, jumps at the rampart and each gorge gap; climbing/ledge grabs happen automatically.
## Returns true when stop_z was reached.
static func run_route(tc: TestCase, player: PlayerController, stop_z: float, max_frames: int = 2600) -> bool:
	var jump_at: Array[float] = [-43.0, -49.0, -55.0, -61.5, -68.0]
	var next_jump := 0
	tc.press("move_forward")
	for i in max_frames:
		await tc.tree.physics_frame
		var z := player.global_position.z
		var target_x := 1.5 if z < -57.0 and z > -64.0 else 0.0
		var steer := clampf((target_x - player.global_position.x) * 0.8, -1.0, 1.0)
		Input.action_press("move_right", maxf(steer, 0.0))
		Input.action_press("move_left", maxf(-steer, 0.0))
		if next_jump < jump_at.size() and z < jump_at[next_jump] and player.is_on_floor():
			tc.press("jump")
			await tc.physics_frames(12)
			tc.release("jump")
			next_jump += 1
		if z < stop_z:
			release_moves()
			return true
	release_moves()
	return false


## Fights any BossController by reading its telegraphs by attack kind: roll back from FRONT
## attacks, sideways off DASHes, strafe out of ERUPTIONS, back out of RADIAL blasts; punish
## openings in front of the lowered head;
## throw the Ember Talisman whenever it is ready. Returns when the boss is defeated or time runs out.
static func fight_boss(tc: TestCase, player: PlayerController, boss: BossController, max_frames: int = 60 * 300) -> void:
	var reacted_to := -1
	var attack_count := 0
	for frame in max_frames:
		await tc.tree.physics_frame
		if boss.state == BossController.State.DEFEATED:
			break
		if player.combat.state == PlayerCombat.State.DEAD:
			continue
		if player.combat.lock_target == null and boss.is_alive():
			await tap(tc, "lock_on")
		var to_boss := boss.global_position - player.global_position
		to_boss.y = 0.0
		var dist := to_boss.length()
		release_moves()
		if boss.state == BossController.State.TELEGRAPH:
			var a := boss.current_attack
			var left := boss.telegraph_seconds(a) - boss.state_time()
			match a.kind:
				BossAttackDefinition.Kind.ERUPTIONS:
					Input.action_press("move_left")  # Strafe around the boss, out of the circles.
					Input.action_press("sprint")
				BossAttackDefinition.Kind.RADIAL:
					if dist < 7.5:
						Input.action_press("move_back")
						Input.action_press("sprint")
				_:
					if left < 0.18 and reacted_to != attack_count:
						reacted_to = attack_count
						Input.action_press("move_left" if a.kind == BossAttackDefinition.Kind.DASH else "move_back")
						await tap(tc, "dodge")
			continue
		if boss.state == BossController.State.ATTACK:
			attack_count += 1 if boss.state_time() < 0.02 else 0
			continue
		var opening := boss.state in [BossController.State.RECOVER, BossController.State.STAGGER, BossController.State.STUNNED, BossController.State.PART_BREAK]
		if player.combat.skill_cooldown_left <= 0.0 and player.combat.state == PlayerCombat.State.READY:
			await tap(tc, "skill")
			continue
		var head_spot := boss.global_position - boss.global_basis.z * (absf(boss.definition.lock_offset.z) + 2.8)
		head_spot.y = player.global_position.y
		var to_spot := head_spot - player.global_position
		if to_spot.length() > 1.2:
			Input.action_press("move_forward")
			if dist > 8.0 and not opening:
				Input.action_press("sprint")
		if dist < 6.5 and opening and player.combat.state == PlayerCombat.State.READY:
			await tap(tc, "attack_heavy" if frame % 3 == 0 else "attack_light")
	release_moves()


## Steer toward world x while holding forward (camera yaw 0: forward = -Z).
static func _steer(player: PlayerController, target_x: float) -> void:
	var steer := clampf((target_x - player.global_position.x) * 0.8, -1.0, 1.0)
	Input.action_press("move_right", maxf(steer, 0.0))
	Input.action_press("move_left", maxf(-steer, 0.0))


## Walk forward (and steer) until z < stop_z. Returns false on timeout.
static func _walk_to_z(tc: TestCase, player: PlayerController, stop_z: float, target_x: float, max_frames: int = 900) -> bool:
	tc.press("move_forward")
	for i in max_frames:
		await tc.tree.physics_frame
		_steer(player, target_x)
		if player.global_position.z < stop_z:
			return true
	return false


## Emberwild route: waits for the vent wave and runs behind it, takes the cool lane past the heat
## zone, waits for the sinking stones to rise, then crosses the lava river and climbs the far bank.
static func run_route_emberwild(tc: TestCase, player: PlayerController, level: Node, stop_z: float) -> bool:
	var vents: Array = []
	for i in 4:
		vents.append(level.get_node("Hazards/FireVent%d" % i))
	var stones: Array = []
	for i in 4:
		stones.append(level.get_node("Hazards/SinkingStone%d" % i))
	# 1) Up to the vent field entrance, wait until the first vent has just finished erupting.
	if not await _walk_to_z(tc, player, -5.0, 0.0):
		return false
	release_moves()
	var v0 := vents[0] as FireVent
	for i in 600:
		await tc.tree.physics_frame
		if v0.phase == FireVent.Phase.DORMANT and v0.time_to_eruption() > v0.cycle_length() - v0.erupt_time - 0.9:
			break
	tc.press("sprint")
	if not await _walk_to_z(tc, player, -28.0, 0.0):
		return false
	tc.release("sprint")
	# 2) Cool lane on the right past the heat zone.
	if not await _walk_to_z(tc, player, -38.5, 4.8):
		return false
	if not await _walk_to_z(tc, player, -48.6, 0.0):
		return false
	release_moves()
	# 3) Wait for the stones to rise, then run and jump stone to stone.
	var s0 := stones[0] as SinkingStone
	for i in 900:
		await tc.tree.physics_frame
		if s0.is_safe() and s0.safe_time_left() > s0.up_time - 0.25:
			break
	var jump_at: Array[float] = [-49.3, -54.6, -59.1, -63.6, -68.1]
	var next_jump := 0
	tc.press("move_forward")
	for i in 1500:
		await tc.tree.physics_frame
		_steer(player, 0.0)
		var z := player.global_position.z
		if next_jump < jump_at.size() and z < jump_at[next_jump] and player.is_on_floor():
			tc.press("jump")
			await tc.physics_frames(12)
			tc.release("jump")
			next_jump += 1
		if z < stop_z:
			release_moves()
			return true
	release_moves()
	return false


## Moonfen route: wades straight through the mud (no jumping there), crosses the stream against
## its current, follows the spirit lanterns through the fog (away from the hidden poison), then
## keeps moving raft to raft across the deep bog — rafts sink under you, so it never waits — and
## climbs the root wall of the far bank.
static func run_route_moonfen(tc: TestCase, player: PlayerController, stop_z: float) -> bool:
	if not await _walk_to_z(tc, player, -24.0, -0.5, 1200):  # Mud flats (slow).
		return false
	if not await _walk_to_z(tc, player, -37.0, 0.0):  # Stream; steering fights the drift.
		return false
	if not await _walk_to_z(tc, player, -48.6, 1.6):  # Fog bank, lantern side.
		return false
	var jump_at: Array[float] = [-49.3, -54.6, -59.1, -63.6, -68.1]
	var next_jump := 0
	tc.press("move_forward")
	for i in 1500:
		await tc.tree.physics_frame
		_steer(player, 0.0)
		var z := player.global_position.z
		if next_jump < jump_at.size() and z < jump_at[next_jump] and player.is_on_floor():
			tc.press("jump")
			await tc.physics_frames(12)
			tc.release("jump")
			next_jump += 1
		if z < stop_z:
			release_moves()
			return true
	release_moves()
	return false


## Stormcrag route: jumps onto the cliff and climbs to the storm plateau, keeps running across it
## (lightning lands where you WERE), drops off the far edge, waits at the gale ridge until a gust
## has just blown past, then sprints the slick ridge in the calm.
static func run_route_stormcrag(tc: TestCase, player: PlayerController, level: Node, stop_z: float) -> bool:
	if not await _walk_to_z(tc, player, -7.9, 0.0):
		return false
	tc.press("jump")
	await tc.physics_frames(12)
	tc.release("jump")
	if not await _walk_to_z(tc, player, -47.5, 0.0, 1500):  # Climb, plateau, drop.
		return false
	release_moves()
	var gust := level.get_node("Hazards/GaleGust") as GustZone
	var waited := false
	for i in 900:
		await tc.tree.physics_frame
		if gust.phase == GustZone.Phase.CALM and gust.phase_time() < 0.1:
			waited = true
			break
	if not waited:
		return false
	tc.press("sprint")
	if not await _walk_to_z(tc, player, -73.0, 0.0, 400):
		return false
	tc.release("sprint")
	var ok := await _walk_to_z(tc, player, stop_z, 0.0)
	release_moves()
	return ok


## Phase 13: hold the move keys towards a world point (camera-relative, like a stick), jumping
## when stuck; walking into a climbable wall starts a climb and the climb tops out automatically.
## Stops when `done` returns true. Returns done's last value.
static func walk_toward(tc: TestCase, player: PlayerController, target: Vector3, done: Callable,
		max_frames: int = 1500) -> bool:
	var last := player.global_position
	var stuck := 0
	for i in max_frames:
		await tc.tree.physics_frame
		if done.call():
			release_moves()
			return true
		var d := target - player.global_position
		d.y = 0.0
		if d.length() < 0.05:
			continue
		var local := player.get_camera_basis().inverse() * d.normalized()
		Input.action_press("move_right", maxf(local.x, 0.0))
		Input.action_press("move_left", maxf(-local.x, 0.0))
		Input.action_press("move_back", maxf(local.z, 0.0))
		Input.action_press("move_forward", maxf(-local.z, 0.0))
		if i % 30 == 29:
			var moved := player.global_position.distance_to(last)
			last = player.global_position
			var climbing := player.traversal and player.traversal.state != TraversalComponent.State.NONE
			stuck = stuck + 1 if moved < 0.3 and not climbing else 0
			if stuck >= 2 and player.is_on_floor():
				tc.press("jump")
				await tc.physics_frames(8)
				tc.release("jump")
				stuck = 0
	release_moves()
	return bool(done.call())

