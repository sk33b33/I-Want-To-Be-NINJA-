extends TestCase
## Draw / sheathe blades (owner request, with the Draw_Sword / Sheath_Sword clips): the button,
## the blades moving between the hands and the hip sheath on the clip's timing, attacking from
## sheathed, moving and rolling during a swap, and the input on every device.


func _player() -> PlayerController:
	make_floor()
	return make_player(Vector3(0, 0.05, 0))


func _anim(p: PlayerController) -> AnimationPlayer:
	return p.get_node("Visual/NinjaModel/AnimationPlayer") as AnimationPlayer


func test_model_has_the_sword_clips() -> void:
	var p := _player()
	await physics_frames(2)
	for clip in ["Draw_Sword", "Sheath_Sword"]:
		check(_anim(p).has_animation(clip), "%s imported" % clip)


func test_button_sheathes_then_draws_with_the_clips() -> void:
	var p := _player()
	var mount := p.get_node("WeaponMount") as WeaponMount
	await physics_frames(50)
	check(p.combat.sword_drawn and not mount.sheathed, "expeditions start with blades in hand")
	BotHelpers.tap(self, "draw_sword")
	await physics_frames(6)
	check(_anim(p).current_animation == &"Sheath_Sword", "standing still plays Sheath_Sword (got %s)" % _anim(p).current_animation)
	check(p.combat.sword_drawn, "blades still in hand before the hand reaches the hip")
	await physics_frames(int(p.combat.config.sheathe_time * 60.0) + 5)
	check(not p.combat.sword_drawn and mount.sheathed, "sheathed")
	check(mount.sheathed_blades[0].visible and not mount.blades[0].visible, "blades shown at the hip, not in the hands")
	BotHelpers.tap(self, "draw_sword")
	await physics_frames(6)
	check(_anim(p).current_animation == &"Draw_Sword", "Draw_Sword plays (got %s)" % _anim(p).current_animation)
	check(p.combat.sword_drawn and mount.blades[0].visible, "blades in hand almost at once when drawing")
	await physics_frames(int(p.combat.config.draw_time * 60.0) + 5)
	check(not p.combat.is_swapping(), "draw finished")


func test_attacking_while_sheathed_draws_then_attacks() -> void:
	var p := _player()
	await physics_frames(50)
	BotHelpers.tap(self, "draw_sword")
	await physics_frames(int(p.combat.config.sheathe_time * 60.0) + 10)
	check(not p.combat.sword_drawn, "sheathed")
	BotHelpers.tap(self, "attack_light")
	var attacked := false
	for i in int((p.combat.config.draw_time + 0.5) * 60.0):
		await tree.physics_frame
		if p.combat.state == PlayerCombat.State.ATTACK:
			attacked = true
			break
	check(attacked and p.combat.sword_drawn, "one press drew the blades and attacked")


func test_attack_during_an_early_sheathe_cancels_it() -> void:
	var p := _player()
	await physics_frames(50)
	BotHelpers.tap(self, "draw_sword")
	await physics_frames(10)  # Hand not at the hip yet.
	BotHelpers.tap(self, "attack_light")
	await physics_frames(4)
	check(p.combat.state == PlayerCombat.State.ATTACK and p.combat.sword_drawn and not p.combat.is_swapping(), "attack wins, blades stay out")


func test_moving_during_a_sheathe_keeps_running_and_still_sheathes() -> void:
	var p := _player()
	await physics_frames(50)
	BotHelpers.tap(self, "draw_sword")
	press("move_forward")
	await physics_frames(40)
	check(p.global_position.z < -1.5, "kept moving (z=%.2f)" % p.global_position.z)
	check(_anim(p).current_animation == &"Run", "legs run instead of the standing clip (got %s)" % _anim(p).current_animation)
	await physics_frames(int(p.combat.config.sheathe_time * 60.0))
	release("move_forward")
	check(not p.combat.sword_drawn, "sheathed on the move")


func test_a_roll_finishes_the_swap_at_once() -> void:
	var p := _player()
	await physics_frames(50)
	BotHelpers.tap(self, "draw_sword")
	await physics_frames(5)
	BotHelpers.tap(self, "dodge")
	await physics_frames(4)
	check(p.combat.state == PlayerCombat.State.DODGE, "rolling")
	check(not p.combat.sword_drawn and not p.combat.is_swapping(), "sheathe completed by the roll")


func test_draw_button_on_keyboard_gamepad_and_touch() -> void:
	var r := InputEventKey.new()
	r.physical_keycode = KEY_R
	check(InputMap.event_is_action(r, &"draw_sword"), "R draws / sheathes")
	var dpad := InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_UP
	check(InputMap.event_is_action(dpad, &"draw_sword"), "D-pad up draws / sheathes")
	check(InputRemap.ACTIONS.has(&"draw_sword"), "remappable")
	var tc := TouchControls.new()
	add_node(tc)
	var found := false
	for b: Dictionary in tc.get("_buttons"):
		found = found or b["action"] == "draw_sword"
	check(found, "touch BLADE button")


func test_sheathed_blades_sit_at_the_left_hip_pointing_back() -> void:
	var p := _player()
	await physics_frames(20)
	p.face_direction(Vector3.FORWARD)  # Facing -Z: left is -X, back is +Z.
	await physics_frames(5)
	var mount := p.get_node("WeaponMount") as WeaponMount
	for b in mount.sheathed_blades:
		var g := b.global_transform
		var rel := g.origin - p.global_position
		check(rel.x < -0.1, "on the left side (x=%.2f)" % rel.x)
		check(rel.y > 0.6 and rel.y < 1.2, "at hip height (y=%.2f)" % rel.y)
		check(g.basis.y.normalized().z > 0.5 and g.basis.y.normalized().y < 0.0, "tip points back and down (%s)" % g.basis.y.normalized())
