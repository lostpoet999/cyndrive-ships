extends Node2D

@export var runs_per_second: float = 5.
@export var max_distance_from_target: float = 10.
@export var laser_aim: float = 1.5
@export var laser_haste: float = 3.615
@export var difficuilty_laser_frequency_sec: float = 1.8
@export var attack_range: float = 2000.
@export var goldfish_memory_sec: float = 1.
@export var stuck_sec_threshold = 3.
@export var stuck_motion_threshold = 30.

@onready var character: BattleCharacter = get_parent()
var position_moving_avg: Vector2 = get_global_position()
var target_moving_avg: Vector2 = Vector2()
var time_until_script_execution = 1. / runs_per_second
var chosen_target: CharacterBody2D
var enabled: bool = true
var time_since_laser: float = 0.
var distance_to_target: float = 0.
var time_until_target_drop: float = goldfish_memory_sec

var permanently_disabled: bool = false
func set_disabled(yesno: bool) -> void:
	permanently_disabled = yesno

func stop() -> void:
	enabled = false
	chosen_target = null
	time_since_laser = 0.

func resume() -> void:
	enabled = true

func _physics_process(delta: float) -> void:
	time_until_script_execution -= delta
	time_since_laser += delta

	# Feature flag to disable all AI for testing
	if FeatureFlags.is_enabled("disable_ai"):
		return

	if permanently_disabled or not enabled or time_until_script_execution >= 0:
		return

	time_until_script_execution = 1. / runs_per_second
	var action = Dictionary()
	action["intent"] = Vector2()

	var combatants = character.get_parent()
	var to_target : Vector2 = character.spawn_position - get_global_position()

	# target not visible
	var space_state = get_world_2d().direct_space_state
	if chosen_target != null:
		to_target = ( chosen_target.get_global_position() - character.get_global_position() )
		distance_to_target = to_target.length()
		to_target = to_target.normalized()
		var target_range_raycast_result = space_state.intersect_ray(PhysicsRayQueryParameters2D.create(
			character.get_global_position(), character.get_global_position() + to_target * attack_range
		))
		if not target_range_raycast_result.has("collider") or chosen_target != target_range_raycast_result.collider:
			time_until_target_drop -= delta
		if time_until_target_drop <= 0.:
			chosen_target = null

	# chosen target is not alive
	if chosen_target != null and ("is_alive" not in chosen_target or not chosen_target.is_alive()):
		chosen_target = null

	# decide potential new target
	var tries = 0
	var raycast_result
	var random_target = combatants.get_children().pick_random()
	while tries < 5 and ("in_battle" not in random_target or !random_target.in_battle()):
		random_target = combatants.get_children().pick_random()
		tries += 1
	if random_target != null and random_target.has_node("team") and random_target.get_node("team").is_enemy(character.get_node("team")):
		var vector_to_target = random_target.global_position - character.global_position
		var candidate_distance = vector_to_target.length()
		if (chosen_target == null or candidate_distance < distance_to_target or candidate_distance < attack_range):
			raycast_result = space_state.intersect_ray(PhysicsRayQueryParameters2D.create(
				character.get_global_position(),
				character.get_global_position() + vector_to_target.normalized() * attack_range
			))
			if raycast_result.has("collider") and random_target == raycast_result.collider:
				chosen_target = random_target
				distance_to_target = vector_to_target.length()
				time_until_target_drop = goldfish_memory_sec
				target_moving_avg = random_target.get_global_position()
			else: # In case the random target is not in line of sight, do not cache the raycast results
				raycast_result = null

	# Go to spawn position if no target
	var target_is_alive = false
	if chosen_target != null and "in_battle" in chosen_target and chosen_target.in_battle():
		target_is_alive = true
		to_target = chosen_target.get_global_position() - character.get_global_position()
		distance_to_target = to_target.length()
	else: 
		to_target = ( character.spawn_position - character.get_global_position() )
		distance_to_target = to_target.length()

	# Determine the speed to advance towards the target
	var ideal_speed = lerp(
		character.get_node("controller").top_speed, 0.,
		max_distance_from_target / distance_to_target
	)

	# See if there's anything in the way to the target
	var target_acquired = false
	var ray_to_target = (target_moving_avg - character.get_global_position())
	if chosen_target != null:
		target_moving_avg = lerp(target_moving_avg, chosen_target.get_global_position(), laser_aim + max(0.05, 0.6 - time_since_laser) * laser_haste)
		if raycast_result == null:
			raycast_result = space_state.intersect_ray(PhysicsRayQueryParameters2D.create(
				character.get_global_position(),
				character.get_global_position() + ray_to_target
			))
		target_acquired = (
			( # Collsiion detected at gunpoint, and the target is an enemy
				"collider" in raycast_result and raycast_result.collider.has_node("team")
				and raycast_result.collider.get_node("team").is_enemy(character.get_node("team"))
			) or ( # Becuase the Carriers might have more complex geometry, the raycasts don't work on them FOR SOME REASON >:C
				null != chosen_target and chosen_target.is_in_group("complex_collision_shapes")
				# Workaround: the chosen target is a carrier and the gunpoint points within its radius
				and (character.get_global_position() + ray_to_target - chosen_target.get_global_position()).length() <= chosen_target.approx_size
				and ( # and Either there's no raycast result, or it's further away than the actual target
					not "collider" in raycast_result
					or distance_to_target <= (raycast_result.collider.get_global_position() - character.get_global_position()).length()
				)
			)
		)

	action["intent"] = Vector2(sign(to_target.x), sign(to_target.y)) * ideal_speed
	if target_acquired and target_is_alive and time_since_laser > difficuilty_laser_frequency_sec:
		action["pewpew"] = chosen_target.get_global_position()
		action["pewpew_target"] = chosen_target

	if "pewpew" in action:
		time_since_laser = 0

	# Detect if the ship is stuck, and apply boost to break free
	position_moving_avg = lerp(get_global_position(), position_moving_avg, 0.5)
	if ( # The ship is in one place, and has a long term contact, set intent to "unstuck"
		(get_global_position() - position_moving_avg).length() < stuck_motion_threshold
		and null != get_parent().body_in_contact and get_parent().contact_time > stuck_sec_threshold
	):
		action["boost"] = true
		action["intent"] = (character.get_global_position() - get_parent().body_in_contact.get_global_position()).normalized()
	character.process_input_action(action)
