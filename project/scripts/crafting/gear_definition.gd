class_name GearDefinition
extends Resource
## A forgeable piece of gear. Stats are deliberately few and readable (docs/GAME_DESIGN.md:
## "Gear stats should be understandable (damage, defense, element, traversal utility)").

enum Slot { WEAPON, ARMOR, CHARM }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var slot: Slot = Slot.WEAPON
## Tint shown on the gear in game (blades) and in the forge UI.
@export var color: Color = Color(0.8, 0.8, 0.8)

@export_group("Stats")
## Multiplier on blade (light/heavy) damage. 1.25 = +25%.
@export var blade_damage_multiplier: float = 1.0
## Extra maximum health.
@export var max_health_bonus: float = 0.0
## Fraction of incoming damage ignored. 0.15 = takes 15% less damage.
@export var damage_reduction: float = 0.0
## Seconds taken off the Ember Talisman cooldown.
@export var skill_cooldown_reduction: float = 0.0
## Multiplier on Ember Talisman damage.
@export var skill_damage_multiplier: float = 1.0
## Changes the talisman's element (e.g. &"water" for the Mist Charm). Empty = keep fire.
@export var skill_element: StringName = &""
## Gives the blades an element (e.g. &"fire"). Empty = physical.
@export var blade_element: StringName = &""


static func slot_name(s: Slot) -> String:
	return ["Weapon", "Armor", "Charm"][s]


## Human-readable stat lines for the forge, e.g. "Blade damage +25%".
func stat_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	if blade_damage_multiplier != 1.0:
		lines.append("Blade damage %+d%%" % int(round((blade_damage_multiplier - 1.0) * 100.0)))
	if max_health_bonus != 0.0:
		lines.append("Max health %+d" % int(max_health_bonus))
	if damage_reduction != 0.0:
		lines.append("Damage taken -%d%%" % int(round(damage_reduction * 100.0)))
	if skill_cooldown_reduction != 0.0:
		lines.append("Ember Talisman cooldown -%.1fs" % skill_cooldown_reduction)
	if skill_damage_multiplier != 1.0:
		lines.append("Ember Talisman damage %+d%%" % int(round((skill_damage_multiplier - 1.0) * 100.0)))
	if skill_element != &"":
		lines.append("Talisman becomes %s" % String(skill_element).capitalize())
	if blade_element != &"":
		lines.append("Blades deal %s damage" % String(blade_element).capitalize())
	return lines
