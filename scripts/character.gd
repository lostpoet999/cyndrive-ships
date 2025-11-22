extends CharacterBody2D

const CHARACTER_APPROX_SIZE: float = 100.

@export var team_id = 0
@export var spawn_position = Vector2()
@export var color = Color()
@export var starting_health = 10.

var do_motion_overwrite = false
var motion_to_set : Dictionary
func correct_motion_course(motion: Dictionary) -> void:
	motion_to_set = motion
	do_motion_overwrite = true

func _physics_process(_delta: float) -> void:
	if do_motion_overwrite:
		transform = motion_to_set["transform"]
		velocity = motion_to_set["velocity"]
		do_motion_overwrite = false

func init_clone(predecessor):
	predecessor.get_node("team").init_succesor($team)
	$skin.self_modulate = $team.color

func init_control_character():
	$team.initialize(team_id, spawn_position, color)
	$skin.self_modulate = $team.color

var accept_keyboard_inputs = false
func accepts_input(yesno):
	accept_keyboard_inputs = yesno
	$controller.stop()

func is_alive():
	return $health.is_alive

func set_highlight(yesno):
	$target_arrow.set_visible(yesno)

var zoom_value = 0.4
func _process(_delta):
	if has_node("cam"):
		var next_zoom_value = clamp($controller.top_speed / get_velocity().length() * 10., 0.25, 0.5)
		zoom_value = lerpf(zoom_value, next_zoom_value, 0.01)
		$cam.zoom.x = zoom_value
		$cam.zoom.y = zoom_value
		
	if !is_alive():
		unalive_me()

func process_input_action(action):
		$controller.process_input_action(action)
		$laser_beam.process_input_action(action)
		if has_node("move_recorder"):
			$move_recorder.process_input_action(action)
		
func accept_damage(strength):
	$health.accept_damage(strength)
	if $health.health > 3:
		explosion_shake_smooth($cam)
	else:
		explosion_shake($cam)

func respawn():
	$health.respawn()
	$controller.move_to_spawn_pos()
	set_collision_layer_value(1, true)
	set_visible(true)

func unalive_me():
	set_collision_layer_value(32, false)
	set_visible(false)
	if has_node("ai_control"):
		$ai_control.enabled = false

func _unhandled_input(inev: InputEvent) -> void:
	if(accept_keyboard_inputs):
		var action = BattleInputMap.get_action(get_viewport(), get_global_position(), inev)
		var target_assist = get_parent().get_node("target_assist")
		if target_assist.is_target_locked():
			var assisted_direction = ( \
				target_assist.get_current_target_position() \
				- get_global_position() \
			).normalized()
			action["cursor"] = assisted_direction
			
		# move camera lightly on boost  
		if action["boost"]:
			var camera_direction = $controller.intent_direction * -1
			var boost_tween = create_tween()
			boost_tween.tween_property($cam, "offset", camera_direction * CHARACTER_APPROX_SIZE * 2., 0.2)
			boost_tween.tween_property($cam, "offset", Vector2(), 0.5)
			boost_tween.chain()

		process_input_action(action)

func explosion_shake(target: Object, intensity: float = 30.0, duration: float = 0.5, frequency: int = 20):
	var tween = create_tween()
	
	# Create multiple random shakes
	for i in frequency:
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(target, "offset", shake_offset, duration / frequency)
	
	# Return to center
	tween.tween_property(target, "offset", Vector2.ZERO, duration / frequency)

func explosion_shake_smooth(target: Object, intensity: float = 30.0, duration: float = 0.5):
	var tween = create_tween()
	var steps = 10
	
	for i in steps:
		var progress = float(i) / steps
		var current_intensity = intensity * (1.0 - progress)  # Decay
		var shake_offset = Vector2(
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity)
		)
		tween.tween_property(target, "offset", shake_offset, duration / steps)
	
	tween.tween_property(target, "offset", Vector2.ZERO, 0.1)
