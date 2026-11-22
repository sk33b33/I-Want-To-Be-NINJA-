class_name ForgePanel
extends VBoxContainer
## The dojo forge (Phase 7): every recipe with its costs (have / need), what the gear does,
## Craft and Equip buttons, and a flash when something is forged. Saves the profile on change.

signal forged(gear: GearDefinition)
signal equipped(gear: GearDefinition)

var catalog: CraftingCatalog
var profile: PlayerProfile

var _list: VBoxContainer
var _materials: Label
var _flash: Label
var _flash_t: float = 0.0
## gear id -> {"craft": Button, "equip": Button}
var buttons: Dictionary = {}


func setup(p_catalog: CraftingCatalog) -> void:
	catalog = p_catalog
	add_theme_constant_override("separation", 12)
	_materials = UiStyle.label("", 18, UiStyle.WARNING)
	add_child(_materials)
	_flash = UiStyle.label("", 26, UiStyle.SPIRIT)
	_flash.modulate.a = 0.0
	add_child(_flash)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)
	refresh()


func _process(delta: float) -> void:
	_flash_t = maxf(_flash_t - delta, 0.0)
	_flash.modulate.a = clampf(_flash_t, 0.0, 1.0)


func refresh() -> void:
	profile = PlayerProfile.load_profile()
	_materials.text = _materials_text()
	for c in _list.get_children():
		c.queue_free()
	buttons.clear()
	for recipe in catalog.recipes:
		_list.add_child(_recipe_card(recipe))


## Craft (UI and tests). Returns true when the gear was forged and saved.
func craft(recipe: RecipeDefinition) -> bool:
	profile = PlayerProfile.load_profile()
	if not Forge.craft(profile, recipe):
		return false
	profile.save()
	_flash.text = "Forged: %s!" % recipe.result.display_name
	_flash_t = 3.0
	forged.emit(recipe.result)
	refresh()
	return true


func equip(gear: GearDefinition) -> bool:
	profile = PlayerProfile.load_profile()
	if not Forge.equip(profile, gear):
		return false
	profile.save()
	_flash.text = "Equipped: %s" % gear.display_name
	_flash_t = 2.0
	equipped.emit(gear)
	refresh()
	return true


func _materials_text() -> String:
	if profile.materials.is_empty():
		return "Your materials: none"
	var parts: PackedStringArray = []
	for id in profile.materials:
		var it := catalog.find_item(StringName(id))
		parts.append("%s ×%d" % [it.display_name if it else String(id), int(profile.materials[id])])
	return "Your materials: " + ",  ".join(parts)


func _recipe_card(recipe: RecipeDefinition) -> Control:
	var gear := recipe.result
	var owned := profile.owns(gear.id)
	var is_equipped := profile.equipped_id(GearDefinition.slot_name(gear.slot)) == gear.id
	var card := UiStyle.panel(Color(0.04, 0.05, 0.055, 0.95), gear.color * Color(1, 1, 1, 0.6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(UiStyle.label("%s  ·  %s" % [gear.display_name, GearDefinition.slot_name(gear.slot)], 24, gear.color.lightened(0.2)))
	info.add_child(UiStyle.label(gear.description, 16, UiStyle.MUTED))
	info.add_child(UiStyle.label("  ".join(gear.stat_lines()), 18, UiStyle.SPIRIT))
	var costs: PackedStringArray = []
	for i in recipe.inputs.size():
		var item := recipe.inputs[i]
		costs.append("%s %d/%d" % [item.display_name, profile.count(item.id), recipe.counts[i]])
	var affordable := Forge.missing(profile, recipe).is_empty()
	info.add_child(UiStyle.label("Needs: " + ",  ".join(costs), 17, UiStyle.BONE if affordable or owned else UiStyle.DANGER))
	var actions := VBoxContainer.new()
	row.add_child(actions)
	var craft_b := UiStyle.button("Owned" if owned else "Forge", gear.color)
	craft_b.custom_minimum_size = Vector2(200, UiStyle.BUTTON_HEIGHT)
	craft_b.disabled = owned or not affordable
	craft_b.pressed.connect(craft.bind(recipe))
	actions.add_child(craft_b)
	var equip_b := UiStyle.button("Equipped" if is_equipped else "Equip", UiStyle.SPIRIT)
	equip_b.custom_minimum_size = Vector2(200, UiStyle.BUTTON_HEIGHT)
	equip_b.disabled = not owned or is_equipped
	equip_b.pressed.connect(equip.bind(gear))
	actions.add_child(equip_b)
	buttons[gear.id] = {"craft": craft_b, "equip": equip_b}
	return card
