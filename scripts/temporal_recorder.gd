"""
## The temporal recorder stores data of the given @target within the battle on a given BattleTimeline
"""
extends Node2D

var stored_actions : Dictionary # key is in usec
var stored_motion : Dictionary # key is in msec

@export var triggers_per_second: int = 4
@onready var target : BattleCharacter = get_parent()

func _process(_delta: float) -> void:
	if BattleTimeline.instance.time_flow == BattleTimeline.TimeFlow.BACKWARD:
		# update stored actions
		while not stored_actions.is_empty() and stored_actions.keys().back() > BattleTimeline.instance.time_usec():
			stored_actions.erase(stored_actions.keys().back())

		# update stored motion
		var last_popped
		while not stored_motion.is_empty() and stored_motion.keys().back() > BattleTimeline.instance.time_msec():
			last_popped = { stored_motion.keys().back() : stored_motion[stored_motion.keys().back()]}
			stored_motion.erase(stored_motion.keys().back())
		if not stored_motion.is_empty() or last_popped != null:
			var corrective_motion
			var time_to_motion
			if stored_motion.is_empty() and last_popped != null:
				corrective_motion = last_popped[last_popped.keys()[0]]
				time_to_motion = abs(BattleTimeline.instance.time_since_msec(last_popped.keys()[0]))
			if not stored_motion.is_empty() and last_popped == null:
				corrective_motion = stored_motion[stored_motion.keys().back()]
				time_to_motion = abs(BattleTimeline.instance.time_since_msec(stored_motion.keys().back()))
			if not stored_motion.is_empty() and last_popped != null:
				# The current reverse corrected time point is expected to be between the last popped key and the last stored key
				# --> In this case the earlier motion is selected with the corresponding time to interpolate to it
				corrective_motion = stored_motion[stored_motion.keys().back()]
				time_to_motion = abs(BattleTimeline.instance.time_since_msec(stored_motion.keys().back()))
			target.correct_motion_course(corrective_motion, time_to_motion)

var last_triggered = 0. 
var recording = false
func start_recording():
	if !recording:
		recording = true
	stored_actions = Dictionary()
	stored_motion = Dictionary()
	last_triggered = 0. # Set to 0 to record first frame!

func stop_recording() -> Dictionary:
	var recorded_actions = stored_actions
	var recorded_motion = stored_motion
	stored_actions = Dictionary()
	stored_motion = Dictionary()
	recording = false
	return { "actions" : recorded_actions, "motion" :  recorded_motion }

func process_input_action(action) -> void:
	if BattleTimeline.instance.time_flow == BattleTimeline.TimeFlow.BACKWARD:
		return
	stored_actions[BattleTimeline.instance.time_usec()] = action

func _physics_process(_delta: float) -> void:
	if not recording or BattleTimeline.instance.time_flow == BattleTimeline.TimeFlow.BACKWARD \
		or abs(BattleTimeline.instance.time_since_msec(last_triggered)) <  (1000. / triggers_per_second):
			return
	last_triggered = BattleTimeline.instance.time_msec()
	var current_motion = {"transform": target.get_transform(), "velocity": target.get_velocity()}
	if target.has_node("controller"):
		current_motion["intent_force"] = target.get_node("controller").intent_force
		current_motion["internal_force"] = target.get_node("controller").internal_force
	stored_motion[last_triggered] = current_motion
