class_name BattleCharacter extends CharacterBody2D

signal health_changed(percentage: float)
signal dead(BattleCharacter)
signal resurrected(BattleCharacter)

@export var approx_size: float = 100.
@export var team_id: int = 0
@export var spawn_position: Vector2 = Vector2()
@export var central_ship: bool = false
@export var color: Color = Color.from_rgba8(0,0,0,0)
@export var skin_layers: Array[BattleShipSkin] = []
@export var starting_health: float = 10.
@export var target_assist_shape: CollisionShape2D
@export var temporal_correction_distance_threshold: float = approx_size / 2.
@export_range(0., 200.) var mass: float = 10.

var target_assist_original_size: float = 150.
func _ready() -> void:
	$team.initialize(team_id, spawn_position, color)
	$skin.init_skin(skin_layers, $team.color)

	if has_node("ai_control"):
		$ai_control.enabled = true
	if target_assist_shape:
		target_assist_original_size = target_assist_shape.shape.radius

var debug_color: Color = Color.from_hsv(randf() * 6., 1., 1., 1.)
func correct_temporal_state(snapshot: Dictionary, over_time_msec: float) -> void:
	# DEBUG LINES FOR MOTION CORRECTION
	get_parent().get_parent().display_line(transform.get_origin(), snapshot["transform"].get_origin(), debug_color)
	# DEBUG LINES FOR MOTION CORRECTION

	if "health" in snapshot:
		was_alive = $health.is_alive
		$health.set_value(snapshot["health"])
		if not was_alive and $health.is_alive:
			resurrect_me()
			was_alive = $health.is_alive

	if "energy" in snapshot and has_node("energy_systems"):
		get_node("energy_systems").temporal_correction(snapshot["energy"])

	var correction_length = (snapshot["transform"].get_origin() - get_transform().get_origin()).length()
	var tween_length = max(0., over_time_msec) / 1000.;
	if "internal_force" in snapshot:
		create_tween().tween_property($controller, "internal_force", snapshot["internal_force"], tween_length)
	if "velocity" in snapshot:
		create_tween().tween_property(self, "velocity", snapshot["velocity"], tween_length)

	# Add an afterimage of the character, and erase it shortafter
	if temporal_correction_distance_threshold < correction_length:
		create_tween().tween_property(self, "transform", snapshot["transform"], tween_length)
		var clone = $skin.duplicate()
		clone.set_skins_material(preload("res://resources/implode_effect.tres").duplicate())
		clone.set_transform($skin.get_transform())
		clone.set_global_position(get_global_position())
		clone.set_global_rotation(get_global_rotation())
		if "replace_skin" in clone: clone.replace_skin = false
		get_parent().add_child(clone)
		var tween = create_tween()
		tween.tween_method(
			func(value): clone.set_burn_percentage(value),
			0.0, 1.0, 0.5
		)
		tween.finished.connect(func(): clone.queue_free())


func init_clone(predecessor: BattleCharacter) -> void:
	ship_explosion = null
	team_id = predecessor.team_id
	skin_layers = predecessor.skin_layers # set skin from predecessor(_ready will construct the skin)

func is_alive() -> bool:
	return self.has_node("health") and $health.is_alive

func in_battle() -> bool:
	return is_alive() and (not has_node("replayer") or $replayer.is_within_current_time())

func set_highlight(yesno: bool) -> void:
	$target_arrow.set_visible(yesno)

func get_mass() -> float:
	return mass

func apply_impulse(impulse: Vector2) -> void:
	$controller.internal_force += impulse

# Keeping track of the body the character is in contact with
var body_in_contact: Object = null
var contact_time: float = 0.
func _physics_process(delta: float) -> void:
	if control_enabled == true:
		var collision = move_and_collide(get_velocity() * delta)
		if collision != null and collision.get_collider().has_method("get_mass"):
			if body_in_contact == collision.get_collider():
				contact_time += delta
			else:
				contact_time = 0.
			body_in_contact = collision.get_collider()
			var mass_ratio = get_mass() / body_in_contact.get_mass()
			body_in_contact.apply_impulse($controller.internal_force * delta * mass_ratio * 0.9)
		else:
			contact_time = 0.

@onready var was_alive = is_alive()
@onready var was_in_battle = in_battle()
var ship_explosion : ShipExplosion
var explosion_template = preload("res://scenes/effects/explosion-firey.tscn")
var zoom_value = 0.4
func _process(_delta):
	# Play thruster sound when ship is being steered
	if (
		0. < $controller.intent_direction.length() and in_battle()
		and not has_node("ai_control") and not has_node("replayer")
		and not $thruster_sound.playing
	):
		$thruster_sound.play(randf())
	elif 0. == $controller.intent_direction.length() and $thruster_sound.playing: 
		var stop_fnc = create_tween()
		stop_fnc.tween_interval(0.5)
		stop_fnc.tween_callback(func() : $thruster_sound.stop())
		stop_fnc.chain()
	
	# Handle dynamic zoom for camera
	if has_node("cam"):
		var next_zoom_value = clamp($controller.top_speed / get_velocity().length() * 10., 0.25, 0.5)
		zoom_value = lerpf(zoom_value, next_zoom_value, 0.01)
		$cam.zoom.x = zoom_value
		$cam.zoom.y = zoom_value
		if target_assist_shape:
			target_assist_shape.shape.radius = target_assist_original_size * (0.5 / zoom_value)

	# Sync state for being alive and in battle 
	if is_alive() != was_alive:
		was_in_battle = in_battle()

	# Handle when player timeline gets different from characters timeline
	if not in_battle() and was_in_battle:
		create_tween().tween_method(func(value): $skin.set_burn_percentage(value), 0.0, 1.0, 0.5)
		was_in_battle = false
	elif in_battle() and not was_in_battle:
		create_tween().tween_method(func(value): $skin.set_burn_percentage(value), 1.0, 0.0, 0.5)
		was_in_battle = true

	# Handle explosion when ship is destroyed
	if !is_alive():
		unalive_me()
		if was_alive:
			#erase a previous explosion if there was any
			if ship_explosion == null:
				ship_explosion = explosion_template.instantiate().duplicate()
				get_tree().get_root().add_child(ship_explosion)
			ship_explosion.reinit()
			ship_explosion.set_global_position(get_global_position())
			was_alive = false
			was_in_battle = false
			explosion_shake(100., 0.8)
			$explosion_sound.play()
			dead.emit(self)

	# Erase explosion if alive
	if is_alive() and ship_explosion != null:
		ship_explosion.queue_free()
		ship_explosion = null

func accept_damage(strength):
	$health.accept_damage(strength)
	health_changed.emit($health.health / starting_health)
	if $health.health > 3:
		explosion_shake_smooth()
	else:
		explosion_shake()

func move_to_spawn_position():
	set_global_position(spawn_position)

func respawn():
	move_to_spawn_position()
	set_velocity(Vector2())
	set_collision_layer_value(1, true)
	set_visible(true)
	$health.respawn()
	was_alive = true
	$controller.stop()
	resume_control()
	if has_node("temporal_recorder"):
		$temporal_recorder.start_recording()
	if has_node("replayer"):
		$replayer.reset()

func unalive_me():
	set_collision_layer_value(1, false)
	set_visible(false)
	if has_node("ai_control"):
		$ai_control.enabled = false
		
func resurrect_me():
	set_collision_layer_value(1, true)
	set_visible(true)
	if has_node("ai_control"):
		$ai_control.enabled = true
	resurrected.emit(self)

var accepts_inputs = false
var control_enabled = false
func accepts_user_input(yesno):
	accepts_inputs = yesno

func pause_control() -> void:
	control_enabled = false
	$controller.stop()
	if has_node("ai_control"):
		$ai_control.stop()

func resume_control() -> void:
	control_enabled = true
	$controller.start()
	if has_node("ai_control"):
		$ai_control.resume()

func _unhandled_input(inev: InputEvent) -> void:
	if not accepts_inputs:
		return;
	var action = BattleInputMap.get_action(get_viewport(), inev)
	if(control_enabled):
		if (has_node("energy_systems")):	
			action["boost"] = action["boost"] and $energy_systems.has_boost_energy()
			if not $energy_systems.has_laser_energy() and "pewpew" in action:
				action.erase("pewpew")
		
		if "pewpew" in action and $"../../target_assist".is_target_locked():
			action["pewpew"] = $"../../target_assist".get_current_target_position()
			action["pewpew_target"] =  $"../../target_assist".get_current_target()
			
		# move camera lightly on boost  
		if action["boost"]:
			$booster_fx.visible = true
			$thruster_fx.visible = false
			$booster_sound.play()
			await $booster_sound.finished.connect(func():
				$booster_fx.visible = false
				$thruster_fx.visible = true
			)
			var camera_direction = $controller.intent_direction * -1
			var boost_tween = create_tween()
			boost_tween.tween_property($cam, "offset", camera_direction * approx_size * 2., 0.1)
			boost_tween.tween_property($cam, "offset", Vector2(), 0.5)
			boost_tween.chain()
	process_input_action(action)

func process_input_action(action: Dictionary) -> void:
	# For targets representing past versions ( e.g. player previous round ), positions may mismatch slightly
	# because of the inaccuracies in the replay system and floating point inaccuracies of the physics system
	# Should the target be slightly off, but still around the actual laser position, the position is corrected
	# so past versions of the players can hit their targets more accurately
	if (
		"pewpew_target" in action
		and (action["pewpew_target"].get_global_position() - action["pewpew"]).length() < action["pewpew_target"].approx_size * 3
	):
		action["pewpew"] = action["pewpew_target"].get_global_position()

	$controller.process_input_action(action)
	$laser_beam.process_input_action(action)
	if has_node("temporal_recorder"):
		$temporal_recorder.process_input_action(action)
	if has_node("energy_systems"):
		$energy_systems.process_input_action(action)

func explosion_shake(intensity: float = 30.0, duration: float = 0.5, frequency: int = 20) -> void:
	if not has_node("cam"):
		return
	var tween = create_tween()

	# Create multiple random shakes
	for i in frequency:
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property($cam, "offset", shake_offset, duration / frequency)

	# Return to center
	tween.tween_property($cam, "offset", Vector2.ZERO, duration / frequency)

func explosion_shake_smooth(intensity: float = 30.0, duration: float = 0.5) -> void:
	if not has_node("cam"):
		return
	var tween = create_tween()
	var steps = 10
	
	for i in steps:
		var progress = float(i) / steps
		var current_intensity = intensity * (1.0 - progress)  # Decay
		var shake_offset = Vector2(
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity)
		)
		tween.tween_property($cam, "offset", shake_offset, duration / steps)
	
	tween.tween_property($cam, "offset", Vector2.ZERO, 0.1)
