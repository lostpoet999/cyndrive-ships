extends Node2D

@export var active_movement_rotation_threshold: float = 0.05
@export var passive_movement_rotation_threshold: float = 0.15

@onready var character: BattleCharacter = get_parent()
@onready var team: Node2D = get_parent().get_node("team")
var enabled: bool = false
var intent_direction: Vector2 = Vector2()
var intent_force: Vector2 = Vector2()
var internal_force: Vector2 = Vector2()

"""
Run curve based on https://www.youtube.com/watch?v=yorTG9at90g
	--> Run curve is based on speed x time
	--> 3 phases: 
		- acceleration is based on the function x^2
		- speed is capped to: top_speed
		- deceleration: x^2
"""
@export_range(0.001, 200) var top_speed: float = 20.
@export_range(1, 100) var start_resistance: float = 10.
@export_range(1, 100) var stop_resistance: float = 5.
@export_range(10., 100.) var booster_strength: float = 100.
@export_range(0., 1.) var momentum_dampener: float = 1.


"""
From 0 to the top speed the curve the player changes speed is based on x^2 / @start_resistance.
The function provides the speed based on x
"""
func accelerate_function(x: float) -> float:
	return pow(x,2.) / start_resistance

"""
Decelerating from top speed to fullstop the curve of the player speed follows x^2 / @stop_resistance.
The function provides the speed based on x
"""	
func decelerate_function(x: float) -> float:
	return pow(max(0., x),2.) / stop_resistance

"""
Given: y(@speed) = x^2/@start_resistance; Based on that x = sqrt(y * @start_resistance)
The function provides the x value for the given y value(speed).
"""
func get_accel_x(speed: float) -> float:
	return sqrt(start_resistance * speed)
	
"""
Given: y(@speed) = x^2/@stop_resistance; Based on that x = sqrt(y * @stop_resistance)
The function provides the x value for the given y value(speed).
"""
func get_decel_x(speed: float) -> float:
	return sqrt(stop_resistance * speed)
	
"""
Accepts an inputevent and reconstructs an intent vector from it, based on the implementation in:
Input.get_vector("left", "right", "up", "down")
--> https://github.com/godotengine/godot/blob/a586e860e5fc382dec4ad9a0bec72f7c6684f020/core/input/input.cpp#L382
"""
func get_vector(event: InputEvent, p_deadzone: float = -1.) -> Vector2:
	var vector: Vector2 = Vector2( \
		event.get_action_strength("right") - event.get_action_strength("left"), \
		event.get_action_strength("down") - event.get_action_strength("up"), \
	)
	
	var deadzone: float = p_deadzone
	if deadzone < 0.:
		# If the deadzone isn't specified, get it from the average of the actions.
		deadzone = 0.25 * (
			InputMap.action_get_deadzone("left")
			+ InputMap.action_get_deadzone("right")
			+ InputMap.action_get_deadzone("up")
			+ InputMap.action_get_deadzone("down")
		);
	
	# Circular lentgh limiting and deadzone
	var length: float = vector.length()
	if(length <= deadzone):
		return Vector2()
	elif(length > 1.):
		return vector / length
	else:
		return vector * inverse_lerp(deadzone, 1. , length) / length

func start() -> void:
	enabled = true

func pause() -> void:
	enabled = false

func stop() -> void:
	enabled = false
	intent_force = Vector2()
	internal_force = Vector2()

func process_input_action(action: Dictionary) -> void:
	intent_direction += action["intent"]
	intent_direction = Vector2(sign(intent_direction.x), sign(intent_direction.y))
	if action["boost"]:
		if 0. < action["intent"].length():
			intent_direction = action["intent"]
		internal_force = intent_direction * top_speed * booster_strength

@onready var last_position = get_global_position()
func _physics_process(_delta):
	if not enabled or BattleTimeline.instance.time_flow == BattleTimeline.TimeFlow.BACKWARD:
		return
	
	var previous_intent = intent_force * momentum_dampener
	var current_intent = Vector2()
	var x

	"""Calculating speed from intent"""
	if intent_direction.x == 0:
		x = get_decel_x(abs(previous_intent.x))
		current_intent.x = decelerate_function(x - 1) * sign(previous_intent.x)
	elif 0 == previous_intent.x or sign(previous_intent.x) == sign(intent_direction.x): #trying to accelerate in this direction
		x = get_accel_x(abs(previous_intent.x))
		current_intent.x = accelerate_function(x + 1) * sign(intent_direction.x)
	else:
		x = get_decel_x(abs(previous_intent.x))
		current_intent.x = decelerate_function(x - 1) * sign(previous_intent.x)
	if intent_direction.y == 0:
		x = get_decel_x(abs(previous_intent.y))
		current_intent.y = decelerate_function(x - 1) * sign(previous_intent.y)
	elif 0 == previous_intent.y or sign(previous_intent.y) == sign(intent_direction.y): #trying to accelerate in this direction
		x = get_accel_x(abs(previous_intent.y))
		current_intent.y = accelerate_function(x + 1) * sign(intent_direction.y)
	else:
		x = get_decel_x(abs(previous_intent.y))
		current_intent.y = decelerate_function(x - 1) * sign(previous_intent.y)
	current_intent = current_intent.clamp(-Vector2(top_speed,top_speed), Vector2(top_speed,top_speed))

	"""Apply the new speed"""
	internal_force *= 0.99
	internal_force += current_intent
	intent_force = current_intent
	character.set_velocity(internal_force)

	"""Apply angle based on speed"""
	if active_movement_rotation_threshold < intent_force.length():
		character.set_rotation(intent_force.angle())
	else:
		var pos_delta = (get_global_position() - last_position)
		if passive_movement_rotation_threshold < pos_delta.length():
			character.set_global_rotation(lerp(pos_delta.angle(), get_global_rotation(), 0.2))
	last_position = get_global_position()

#region temporal corrective functions

func _set_internal_force(force: Vector2) -> void:
	internal_force = force

#endregion
