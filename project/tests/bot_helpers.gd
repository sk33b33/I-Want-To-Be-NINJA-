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
	if not await run_long_route(tc, player):
		return false
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
	if not await run_long_route(tc, player):
		return false
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
	if not await run_long_route(tc, player):
		return false
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
	if not await run_long_route(tc, player):
		return false
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
## `from`: where this leg started (the previous waypoint) — after a fight pulls the bot off the
## path it first walks back to the nearest point of the leg, like a player finding the trail again.
static func walk_toward(tc: TestCase, player: PlayerController, target: Vector3, done: Callable,
		max_frames: int = 1500, fight: bool = true, from: Vector3 = Vector3.INF) -> bool:
	var last := player.global_position
	var stuck := 0
	for i in max_frames:
		await tc.tree.physics_frame
		if done.call():
			release_moves()
			return true
		if fight and nearest_thornling(tc, player, 9.0):
			await fight_thornlings(tc, player, 9.0)  # Like a player: deal with the pack, then go on.
			if from != Vector3.INF:
				var back := Geometry3D.get_closest_point_to_segment(player.global_position, from, target)
				back.y = player.global_position.y
				await walk_toward(tc, player, back, func() -> bool:
					return Vector2(player.global_position.x - back.x, player.global_position.z - back.z).length() < 1.0, 400, false)
			last = player.global_position
			continue
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




## Phase 13 long routes: walk the new sections (RouteLayout.bot_paths, "safe" or "risky") from
## the spawn to the start of the original route. Does nothing if the player already stands on
## the original route (z < 20) or the jungle has no long route. Returns false if stuck.
static func run_long_route(tc: TestCase, player: PlayerController, path_name: String = "safe") -> bool:
	var builders := tc.tree.get_nodes_in_group("route_builder")
	if builders.is_empty() or player.global_position.z < 20.0:
		return true
	var layout := (builders[0] as RouteBuilder).layout
	var ok := await follow_path(tc, player, layout.bot_paths.get(path_name, []))
	# Hand over like at the spawn: no lock-on, camera looking down the route (the original route
	# bots steer with camera-relative "forward"; fights with lock-on turn the camera).
	if player.combat.lock_target:
		await tap(tc, "lock_on")
	var rig := player.get_node_or_null(player.camera_rig_path) as CameraRig
	if rig:
		rig.set_yaw(0.0)
		rig.snap_to_target()
	return ok


## Walk through waypoints Vector4(x, y, z, jump); at a jump point, jump and keep heading for the
## next waypoint. A waypoint counts as reached within 0.9 m horizontally and 2 m vertically.
static func follow_path(tc: TestCase, player: PlayerController, pts: Array, frames_per_leg: int = 900) -> bool:
	var respawns := [0]
	var on_respawn := func(_at: Vector3) -> void: respawns[0] += 1
	player.respawned.connect(on_respawn)
	var retries := 0
	var i := 0
	while i < pts.size():
		var seen: int = respawns[0]
		var w: Vector4 = pts[i]
		var target := Vector3(w.x, w.y, w.z)
		var reached := func() -> bool:
			var d := player.global_position - target
			return Vector2(d.x, d.z).length() < 0.9 and absf(d.y) < 2.0
		var prev := Vector3(pts[i - 1].x, pts[i - 1].y, pts[i - 1].z) if i > 0 else player.global_position
		var ok := await walk_toward(tc, player, target, reached, frames_per_leg, true, prev)
		if respawns[0] != seen and retries < 3:
			# Fell or died: like a player, pick the trail up again from the nearest waypoint.
			retries += 1
			i = _nearest_waypoint(pts, player.global_position)
			continue
		if not ok:
			push_warning("follow_path: stuck before waypoint %d %s at %s" % [i, target, player.global_position])
			player.respawned.disconnect(on_respawn)
			return false
		if w.w > 0.5 and i + 1 < pts.size():
			var nxt: Vector4 = pts[i + 1]
			await _wait_until_safe_to_jump(tc, player, Vector3(nxt.x, nxt.y, nxt.z))
			var to := Vector3(nxt.x, nxt.y, nxt.z) - player.global_position
			to.y = 0.0
			var local := player.get_camera_basis().inverse() * to.normalized()
			Input.action_press("move_right", maxf(local.x, 0.0))
			Input.action_press("move_left", maxf(-local.x, 0.0))
			Input.action_press("move_back", maxf(local.z, 0.0))
			Input.action_press("move_forward", maxf(-local.z, 0.0))
			tc.press("jump")
			await tc.physics_frames(14)
			tc.release("jump")
		i += 1
	player.respawned.disconnect(on_respawn)
	release_moves()
	return true


## Like a careful player at the edge: before jumping onto a sinking stone, wait until it has
## plenty of up-time left (the stones run as a wave, so the next ones will be up in time); before
## jumping into wind, wait for a fresh calm. Stands still while waiting (max ~10 s).
static func _wait_until_safe_to_jump(tc: TestCase, player: PlayerController, target: Vector3) -> void:
	release_moves()
	for f in 600:
		var ok := true
		for s in tc.tree.get_nodes_in_group("sinking_stones"):
			var stone := s as SinkingStone
			var d := stone.global_position - target
			if Vector2(d.x, d.z).length() < 2.5 and not (stone.is_safe() and stone.safe_time_left() > 2.0):
				ok = false
		for g in tc.tree.get_nodes_in_group("gust_zones"):
			var gust := g as GustZone
			# Only before ENTERING the wind; once in it, dash through (waiting there gets you blown off).
			if _in_zone(gust, target) and not _in_zone(gust, player.global_position) \
					and not (gust.phase == GustZone.Phase.CALM and gust.calm_time - gust.phase_time() > 2.6):
				ok = false
		if ok:
			return
		await tc.tree.physics_frame


static func _in_zone(zone: Area3D, p: Vector3) -> bool:
	for c in zone.get_children():
		var cs := c as CollisionShape3D
		if cs and cs.shape is BoxShape3D:
			var local := cs.global_transform.affine_inverse() * p
			var half := (cs.shape as BoxShape3D).size * 0.5
			if absf(local.x) <= half.x and absf(local.z) <= half.z:
				return true
	return false


static func nearest_thornling(tc: TestCase, player: PlayerController, radius: float) -> Thornling:
	var best: Thornling = null
	for n in tc.tree.get_nodes_in_group("lock_targets"):
		var t := n as Thornling
		if t and t.is_alive():
			var d := t.global_position.distance_to(player.global_position)
			if d < radius and (best == null or d < best.global_position.distance_to(player.global_position)):
				best = t
	return best


## The Phase 4 combat gate's tactics (lock on, dodge each telegraphed lunge, hit in the
## recovery) against every live Thornling within `radius`. Returns when they are all down
## (or after 40 s).
static func fight_thornlings(tc: TestCase, player: PlayerController, radius: float) -> void:
	release_moves()
	var dodge_side := 1.0
	for frame in 60 * 40:
		await tc.tree.physics_frame
		var near := nearest_thornling(tc, player, radius + 4.0)
		if near == null or player.combat.state == PlayerCombat.State.DEAD:
			break
		if player.combat.lock_target == null or not (player.combat.lock_target is Thornling) \
				or not (player.combat.lock_target as Thornling).is_alive():
			await tap(tc, "lock_on")
		var threat: Thornling = null
		for n in tc.tree.get_nodes_in_group("lock_targets"):
			var t := n as Thornling
			if t and t.is_alive() and t.state == Thornling.State.TELEGRAPH and t._t >= t.config.telegraph_time - 0.15 \
					and t.global_position.distance_to(player.global_position) < 6.0:
				threat = t
		if threat and player.combat.state == PlayerCombat.State.READY:
			dodge_side = -dodge_side
			Input.action_press("move_right" if dodge_side > 0.0 else "move_left")
			await tap(tc, "dodge")
			release_moves()
			continue
		var target := player.combat.lock_target as Thornling
		if target and target.is_alive():
			var dist := target.global_position.distance_to(player.global_position)
			var opening := target.state == Thornling.State.RECOVER or target.state == Thornling.State.STAGGER
			if dist > 2.4:
				Input.action_press("move_forward")
			else:
				Input.action_release("move_forward")
				if opening or target.state == Thornling.State.CHASE:
					await tap(tc, "attack_light")
	release_moves()
	if player.combat.lock_target:
		await tap(tc, "lock_on")  # Release the lock to walk on freely.


static func _nearest_waypoint(pts: Array, p: Vector3) -> int:
	var best := 0
	for k in pts.size():
		var w: Vector4 = pts[k]
		var bw: Vector4 = pts[best]
		if Vector2(w.x - p.x, w.z - p.z).length() < Vector2(bw.x - p.x, bw.z - p.z).length():
			best = k
	return best

