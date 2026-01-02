class_name WeaponSlot extends Node

signal weapon_changed(slot: int)

const MAX_SLOTS = 4
var current_slot: int = 1  # 1-indexed to match keys

var weapons = {
	1: { "name": "laser_beam", "energy_cost": 1 },
	2: { "name": "chain_lightning", "energy_cost": 3 },
	3: null,
	4: null,
}

func select_slot(slot: int) -> void:
	if slot < 1 or slot > MAX_SLOTS:
		return
	if weapons[slot] == null:
		return  # Weapon not unlocked
	if current_slot == slot:
		return  # Already selected
	current_slot = slot
	weapon_changed.emit(slot)

func get_weapon_name() -> String:
	return weapons[current_slot]["name"] if weapons[current_slot] else ""

func get_energy_cost() -> int:
	return weapons[current_slot]["energy_cost"] if weapons[current_slot] else 1

func is_laser() -> bool:
	return current_slot == 1

func is_chain_lightning() -> bool:
	return current_slot == 2
