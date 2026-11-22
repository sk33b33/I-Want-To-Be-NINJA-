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


## Fights Kurogale by reading its telegraphs: roll back from sweeps, sideways off charges, strafe
## out of snare rings, back out of thorn bursts; punish openings in front of the lowered head;
## throw the Ember Talisman whenever it is ready. Returns when the boss is defeated or time runs out.
static func fight_boss(tc: TestCase, player: PlayerController, boss: Kurogale, max_frames: int = 60 * 300) -> void:
	var reacted_to := -1
	var attack_count := 0
	for frame in max_frames:
		await tc.tree.physics_frame
		if boss.state == Kurogale.State.DEFEATED:
			break
		if player.combat.state == PlayerCombat.State.DEAD:
			continue
		if player.combat.lock_target == null and boss.is_alive():
			await tap(tc, "lock_on")
		var to_boss := boss.global_position - player.global_position
		to_boss.y = 0.0
		var dist := to_boss.length()
		release_moves()
		if boss.state == Kurogale.State.TELEGRAPH:
			var a := boss.current_attack
			var left := boss.telegraph_seconds(a) - boss.state_time()
			match a.id:
				&"root_snare":
					Input.action_press("move_left")
					Input.action_press("sprint")
				&"thorn_burst":
					if dist < 6.5:
						Input.action_press("move_back")
						Input.action_press("sprint")
				_:
					if left < 0.18 and reacted_to != attack_count:
						reacted_to = attack_count
						Input.action_press("move_left" if a.id == &"charge" else "move_back")
						await tap(tc, "dodge")
			continue
		if boss.state == Kurogale.State.ATTACK:
			attack_count += 1 if boss.state_time() < 0.02 else 0
			continue
		var opening := boss.state in [Kurogale.State.RECOVER, Kurogale.State.STAGGER, Kurogale.State.STUNNED, Kurogale.State.PART_BREAK]
		if player.combat.skill_cooldown_left <= 0.0 and player.combat.state == PlayerCombat.State.READY:
			await tap(tc, "skill")
			continue
		var head_spot := boss.global_position - boss.global_basis.z * 4.6
		head_spot.y = player.global_position.y
		var to_spot := head_spot - player.global_position
		if to_spot.length() > 1.2:
			Input.action_press("move_forward")
			if dist > 8.0 and not opening:
				Input.action_press("sprint")
		if dist < 6.5 and opening and player.combat.state == PlayerCombat.State.READY:
			await tap(tc, "attack_heavy" if frame % 3 == 0 else "attack_light")
	release_moves()
