class_name GearLoadout
extends RefCounted
## Applies equipped gear to the player at the start of an expedition.


static func apply(player: PlayerController, gear: Array[GearDefinition]) -> void:
	var combat := player.combat if player.combat else player.get_node_or_null("Combat") as PlayerCombat
	if combat == null:
		return
	var blade := 1.0
	var health_bonus := 0.0
	var reduction := 0.0
	var cd := 0.0
	var skill := 1.0
	var tint := Color(0, 0, 0, 0)
	var skill_element := &""
	var blade_element := &""
	for g in gear:
		blade *= g.blade_damage_multiplier
		health_bonus += g.max_health_bonus
		reduction = 1.0 - (1.0 - reduction) * (1.0 - g.damage_reduction)
		cd += g.skill_cooldown_reduction
		skill *= g.skill_damage_multiplier
		if g.slot == GearDefinition.Slot.WEAPON:
			tint = g.color
		if g.skill_element != &"":
			skill_element = g.skill_element
		if g.blade_element != &"":
			blade_element = g.blade_element
	combat.blade_damage_multiplier = blade
	combat.skill_damage_multiplier = skill
	combat.skill_cooldown_reduction = cd
	combat.skill_element_override = skill_element
	combat.blade_element = blade_element
	combat.health.max_health = combat.config.max_health + health_bonus
	combat.health.damage_taken_multiplier = 1.0 - clampf(reduction, 0.0, 0.9)
	combat.health.reset()
	var mount := player.get_node_or_null("WeaponMount") as WeaponMount
	if mount and tint.a > 0.0:
		mount.set_tint(tint)
	combat.equipped_gear = gear
