extends Node2D

@onready var character_template = preload("res://scenes/character.tscn")

var init_countdown = 2.
var living_team_members: Dictionary = {}

func _ready():
	$combatants/character.accepts_user_input(true)
	$combatants/character/controller.stop()
	living_team_members[2] = 0
	living_team_members[1] = 0
	for combatant in $combatants.get_children():
		combatant.spawn_position = combatant.get_global_position()
		$timeline.connect("round_reset", combatant.respawn)
		$timeline.connect("rewind_started", combatant.pause_control)
		$timeline.connect("rewind_stopped", combatant.resume_control)
		combatant.dead.connect(_on_battle_character_dead)
		combatant.resurrected.connect(_on_battle_character_resurrected)
		living_team_members[combatant.get_node("team").team_id] += 1

	for debris in $debris.get_children():
		$timeline.connect("round_reset", debris.respawn)
	
var debug_lines = []
func display_line(from: Vector2, to: Vector2, color: Color) -> void:
	debug_lines.push_back({"from": from, "to": to, "color": color})
	var erasure_tween = create_tween()
	erasure_tween.tween_interval(0.8)
	erasure_tween.tween_callback(func() : debug_lines.pop_front())
	erasure_tween.chain()
	queue_redraw()
	
func _draw() -> void:
	for line in debug_lines:
		draw_line(line.from, line.to, line.color, 3.0)

func restart_round() -> void:
	# Stop the fighting
	for combatant in $combatants.get_children():
		if "pause_control" in combatant:
			combatant.pause_control()

	# Create a clone of the ship
	create_new_puppet($combatants/character)
	$GUI/rewind_effects.set_visible(true)

	# Move the player to its spawn position
	var respawn_time = 1.
	var player_move_tween = create_tween()
	player_move_tween.tween_method(
		func(pos):
			$combatants/character.set_global_position(pos)
			$GUI/rewind_effects.material.set_shader_parameter("rewind_amount", -(pos - $combatants/character.spawn_position).length() / 500.),
		$combatants/character.get_global_position(),
		$combatants/character.spawn_position,
		respawn_time
	)
	player_move_tween.tween_callback(func():
		for combatant in $combatants.get_children():
			if "pause_control" in combatant:
				combatant.resume_control()
		$GUI/rewind_effects.set_visible(false)
		$timeline.reset()
		debug_lines.clear()
		queue_redraw()
		$GUI/defeat.set_visible(false)
		$GUI/victory.set_visible(false)
		$GUI/restart_round_panel.set_visible(false)
		living_team_members[1] = 0
		living_team_members[2] = 0
		for c in $combatants.get_children():
			if "is_alive" in c and c.is_alive():
				living_team_members[c.get_node("team").team_id] += 1
	)
	player_move_tween.chain()

const tap_interval_msec: int = 500
const short_reverse_hold_time_sec: float = 0.15 # How long to hold down the reverse action to start reversing time
var reverse_being_held: bool = false
var reverse_initiated: bool = false
var reverse_hold_time_sec: float = 0.
var reverse_tap_count: int = 0
var reverse_last_tap_at: int = Time.get_ticks_msec()
@onready var battle_start_timetamp_msec: int = int(Time.get_unix_time_from_system())
func _process(delta):
	var display_time: int = battle_start_timetamp_msec + int(BattleTimeline.instance.time_msec())
	$GUI/fps.set_text("%s fps" % Engine.get_frames_per_second())
	$GUI/time.set_text("0x%X//%X" % [display_time >> 16, display_time & 0xFFFF])

	# Countdown to battle start
	if 0 < init_countdown:
		init_countdown = max(init_countdown - delta, 0)
		$GUI/score.set_text("%0.3f" % init_countdown)
		if init_countdown <= 0:
			for combatant in $combatants.get_children():
				combatant.resume_control()
			$timeline.reset()
			$GUI/sensors_display.set_sonar_visibility(false)
			$GUI/sensors_display.expose_health()
		else: return

	# score, target assist area and sensor control
	$GUI/score.set_text(str(living_team_members[1], " vs ", living_team_members[2]))
	$target_assist.set_position(get_global_mouse_position())
	if $combatants/character/sonar_sensor.direct_control:
		var direction = (get_global_mouse_position() - $combatants/character.get_global_position()).normalized()
		$combatants/character/sonar_sensor.set_manual_rotation(direction.angle())

	# Handling Battle restart
	if (Time.get_ticks_msec() - reverse_last_tap_at) > tap_interval_msec:
		reverse_tap_count = 0
	if 2 <= reverse_tap_count:
		reverse_tap_count = 0
		restart_round()

	# Handling Timeline reverse
	if reverse_being_held:
		reverse_hold_time_sec += delta
		if reverse_hold_time_sec > short_reverse_hold_time_sec:
			reverse_initiated = true
			$timeline.reverse(delta)
			$GUI/rewind_effects.set_visible(true)
			$GUI/rewind_effects.material.set_shader_parameter("rewind_amount", BattleTimeline.instance.player_rewind_amount_sec)
			$GUI/defeat.set_visible(false)
			$GUI/victory.set_visible(false)
			$GUI/restart_round_panel.set_visible(false)
	if reverse_initiated:
		if not reverse_being_held:
			$timeline.finish_reverse()
			reverse_hold_time_sec = 0.
			reverse_initiated = false
			$GUI/rewind_effects.set_visible(false)

func create_new_puppet(predecessor):
	#Initialize the new clone/puppet
	var records = predecessor.get_node("temporal_recorder").stop_recording()
	var puppet = character_template.instantiate();
	var replayer = Node2D.new()
	puppet.init_clone(predecessor)
	replayer.set_script(preload("res://scripts/battle/temporal_replayer.gd"))
	replayer.name = "replayer"
	replayer.usec_records = records["actions"]
	replayer.msec_records = records["motion"]
	$timeline.connect("round_reset", puppet.respawn)
	$timeline.connect("rewind_started", puppet.pause_control)
	$timeline.connect("rewind_stopped", puppet.resume_control)
	$timeline.connect("round_reset", replayer.reset)
	$timeline.connect("round_reset", replayer.start_replay)
	replayer.reset()
	puppet.add_child(replayer, true)
	puppet.dead.connect(_on_battle_character_dead)
	puppet.resurrected.connect(_on_battle_character_resurrected)

	# set new spawn position for the predecessor
	predecessor.spawn_position = (
		$combatants/player_carrier.spawn_position
		+ (
			(predecessor.get_global_position() - $combatants/player_carrier.spawn_position).normalized()
			* $combatants/player_carrier.approx_size
		)
	)

	# Add the new puppet to battle
	$combatants.add_child(puppet)
	predecessor.get_node("temporal_recorder").start_recording()

func _unhandled_input(event: InputEvent) -> void:
	var just_pressed = event.is_pressed() and not event.is_echo()

	if event.is_action_pressed("replay") and just_pressed:
		if (Time.get_ticks_msec() - reverse_last_tap_at) < tap_interval_msec:
			reverse_tap_count += 1
		reverse_last_tap_at = Time.get_ticks_msec()
		reverse_being_held = true
		$GUI/rewind_effects.material.set_shader_parameter("rewind_amount", BattleTimeline.instance.player_rewind_amount_sec)

	if event.is_action_released("replay"):
		reverse_being_held = false
	
	if event.is_action_pressed("radar-control") and just_pressed:
		$combatants/character/sonar_sensor.direct_control = true
		$GUI/sensors_display.set_sonar_visibility(true)

	if event.is_action_released("radar-control"):
		$GUI/sensors_display.set_sonar_visibility(false)
		$combatants/character/sonar_sensor.direct_control = false

func player_defeated() -> bool:
	return (
		not $combatants/player_carrier.is_alive()
		or (
			false # TODO: Laupeerium reserves are empty
			and not $combatants/character.is_alive()
		)
	)

func are_you_winning_son() -> bool:
	return (
		not player_defeated()
		 and 0 == living_team_members[2]
	)

func _on_battle_character_dead(character: BattleCharacter) -> void:
	living_team_members[character.get_node("team").team_id] -= 1
	if player_defeated():
		$GUI/victory.set_visible(false)
		$GUI/restart_round_panel.set_visible(false)
		$GUI/defeat.set_visible(true)
	elif are_you_winning_son():
		$GUI/restart_round_panel.set_visible(false)
		$GUI/defeat.set_visible(false)
		$GUI/victory.set_visible(true)
	elif not $combatants/character.is_alive():
		$GUI/victory.set_visible(false)
		$GUI/defeat.set_visible(false)
		$GUI/restart_round_panel.set_visible(true)

func _on_battle_character_resurrected(character: BattleCharacter) -> void:
	if $combatants/character.is_alive():
		$GUI/restart_round_panel.set_visible(false)
	living_team_members[character.get_node("team").team_id] += 1
