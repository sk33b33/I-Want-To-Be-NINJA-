class_name HealthComponent
extends Node
## Hit points for anything that can be hurt. Emits events; it never moves or animates anything.

signal damaged(info: DamageInfo)
signal changed(current: float, maximum: float)
signal died
signal revived

@export var max_health: float = 100.0
## While true, incoming damage is ignored (dodge i-frames, cutscenes, training dummies' reset).
var invulnerable: bool = false
## Armor: incoming damage is multiplied by this (0.85 = takes 15% less).
var damage_taken_multiplier: float = 1.0
var current: float = 0.0
var dead: bool = false


func _ready() -> void:
	current = max_health
	set_process(false)


## Returns true when the damage was applied.
func apply_damage(info: DamageInfo) -> bool:
	if dead or invulnerable or info.amount <= 0.0:
		return false
	info.amount *= damage_taken_multiplier
	current = maxf(current - info.amount, 0.0)
	changed.emit(current, max_health)
	damaged.emit(info)
	if current <= 0.0:
		dead = true
		died.emit()
	return true


## Poison (Venom Tanto): `dps` for `seconds`, ticking every POISON_TICK. A new dose refreshes
## the timer and keeps the stronger dps — poison never stacks.
const POISON_TICK := 0.5
var poison_dps: float = 0.0
var poison_left: float = 0.0
var _poison_tick: float = 0.0
var _poison_element: StringName = &"poison"


func poison(dps: float, seconds: float) -> void:
	if dead or dps <= 0.0 or seconds <= 0.0:
		return
	poison_dps = maxf(poison_dps if poison_left > 0.0 else 0.0, dps)
	poison_left = seconds
	set_process(true)


func _process(delta: float) -> void:
	if poison_left <= 0.0 or dead:
		poison_left = 0.0
		set_process(false)
		return
	poison_left -= delta
	_poison_tick += delta
	while _poison_tick >= POISON_TICK:
		_poison_tick -= POISON_TICK
		var info := DamageInfo.new()
		info.amount = poison_dps * POISON_TICK
		info.element = _poison_element
		info.attack_name = &"poison"
		apply_damage(info)


func heal(amount: float) -> void:
	if dead:
		return
	current = minf(current + amount, max_health)
	changed.emit(current, max_health)


## Back to full health (respawn, dummy reset).
func reset() -> void:
	current = max_health
	dead = false
	invulnerable = false
	poison_left = 0.0
	changed.emit(current, max_health)
	revived.emit()


func fraction() -> float:
	return current / max_health if max_health > 0.0 else 0.0
