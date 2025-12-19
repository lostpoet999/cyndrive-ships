extends Node2D

@onready var health: float = get_parent().starting_health

func value() -> float:
	return health

func set_value(new_value: float) -> void:
	health = new_value
	is_alive = 0 < health

var is_alive: bool = true
func accept_damage(strength) -> void:
	if get_parent().has_node("debug_label"):
		get_parent().get_node("debug_label").set_text(str(health))
	health -= strength
	is_alive = 0 < health

func respawn() -> void:
	is_alive = true
	health = get_parent().starting_health
