extends Node2D

signal boosting(is_boosting: bool)

@onready var character: BattleCharacter = get_parent()
@onready var team: Node2D = get_parent().get_node("team")
var enabled: bool = false
var intent_direction: Vector2 = Vector2()
var internal_force: Vector2 = Vector2()

@export_range(0.001, 200) var top_speed: float = 20.
@export_range(0.1, 10.) var booster_strength: float = 2.

func start() -> void:
	enabled = true

func pause() -> void:
	enabled = false

func stop() -> void:
	enabled = false
	internal_force = Vector2()
	last_intent = Vector2()

var last_intent: Vector2 = Vector2()
var is_boosting: bool = false
@export var angle_response: float = 0.5
@export var speed_response: float = 0.45
@export var floatiness = 0.1
func process_input_action(action: Dictionary) -> void:
	if "intent" in action:
		if 0. == action["intent"].length():
			intent_direction *= floatiness
		elif 0 == intent_direction.length():
			intent_direction = action["intent"]
		else:
			var new_angle = lerp_angle(intent_direction.angle(), action["intent"].angle(), angle_response)
			intent_direction = Vector2(cos(new_angle), sin(new_angle))
			last_intent = intent_direction
	var was_boosting = is_boosting
	is_boosting = (
		(is_boosting and (not "boost_released" in action or not action["boost_released"]))
		or ("boost_initiated" in action and action["boost_initiated"])
	)
	if was_boosting != is_boosting: boosting.emit(is_boosting)

@onready var last_position = get_global_position()
func _physics_process(_delta: float) -> void:
	internal_force = lerp(internal_force, intent_direction, speed_response)
	if intent_direction.length() < 0.15:
		intent_direction = Vector2()
	if not enabled or BattleTimeline.instance.time_flow == BattleTimeline.TimeFlow.BACKWARD:
		return
	character.set_rotation(internal_force.angle())
	character.set_velocity(
		internal_force * character.approx_size * top_speed
		* (booster_strength if is_boosting else 1.0)
	)
	last_position = get_global_position()

#region temporal corrective functions

func _set_internal_force(force: Vector2) -> void:
	internal_force = force

#endregion
