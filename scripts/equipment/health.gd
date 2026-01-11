extends Node2D

@onready var character: BattleCharacter = get_parent()
@onready var health: float = character.starting_health


func value() -> float:
	return health

func set_value(new_value: float) -> void:
	health = new_value
	is_alive = 0 < health

var is_alive: bool = true
func accept_damage(strength: float) -> void:
	health -= max(0., strength)
	is_alive = 0 < health

func accept_healing(strength: float) -> void:
	health = min(health + max(0., strength), character.max_health)

func respawn() -> void:
	is_alive = true
	health = get_parent().starting_health
