class_name Forge
extends RefCounted
## Crafting rules (pure logic over a PlayerProfile; the UI and tests call these).
##   can_craft: owns every input in the required amount and does not own the gear yet.
##   craft:     consumes the inputs exactly once and adds the gear (does not save).
##   equip:     puts owned gear in its slot (replacing what was there).


static func missing(profile: PlayerProfile, recipe: RecipeDefinition) -> Dictionary:
	var out := {}
	for i in recipe.inputs.size():
		var item := recipe.inputs[i]
		var need := recipe.counts[i]
		var have := profile.count(item.id)
		if have < need:
			out[item.id] = need - have
	return out


static func can_craft(profile: PlayerProfile, recipe: RecipeDefinition) -> bool:
	return recipe.result != null and not profile.owns(recipe.result.id) and missing(profile, recipe).is_empty()


static func craft(profile: PlayerProfile, recipe: RecipeDefinition) -> bool:
	if not can_craft(profile, recipe):
		return false
	for i in recipe.inputs.size():
		profile.add_material(recipe.inputs[i].id, -recipe.counts[i])
	profile.gear_owned.append(String(recipe.result.id))
	return true


static func equip(profile: PlayerProfile, gear: GearDefinition) -> bool:
	if gear == null or not profile.owns(gear.id):
		return false
	profile.equipped[GearDefinition.slot_name(gear.slot)] = String(gear.id)
	return true


static func unequip(profile: PlayerProfile, slot: GearDefinition.Slot) -> void:
	profile.equipped.erase(GearDefinition.slot_name(slot))


## Gear currently equipped, resolved through the catalog.
static func equipped_gear(profile: PlayerProfile, catalog: CraftingCatalog) -> Array[GearDefinition]:
	var out: Array[GearDefinition] = []
	for slot in profile.equipped:
		var g := catalog.find_gear(StringName(profile.equipped[slot]))
		if g:
			out.append(g)
	return out
