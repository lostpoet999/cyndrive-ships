class_name BattleTimeline extends Node

static var _instance: BattleTimeline = null
static var instance: BattleTimeline:
	get: 
		return _instance

enum TimeFlow {FORWARD = 1, BACKWARD = -1}

signal round_reset
signal rewind_started
signal rewind_stopped

var time_flow : TimeFlow = TimeFlow.FORWARD
var player_timeline_start_msec: float
var player_timeline_start_usec: int
var player_rewind_amount_sec: float
var player_reverse_started_on_msec: float = 0.
var player_reverse_started_on_usec: int = 0

## Resetting sets the relative timestamp to be of the current time, and restarts the battle
func reset() -> void:
	time_flow = TimeFlow.FORWARD
	player_timeline_start_msec = Time.get_ticks_msec()
	player_timeline_start_usec = Time.get_ticks_usec()
	player_rewind_amount_sec = 0.
	player_reverse_started_on_msec = 0.
	player_reverse_started_on_usec = 0
	round_reset.emit()

func time_usec() -> int:
	if 0 < player_rewind_amount_sec:
		return player_reverse_started_on_usec - int(player_rewind_amount_sec * 1000000.)
	return Time.get_ticks_usec() - player_timeline_start_usec

func time_since_usec(past_time_usec: int) -> int:
	return time_usec() - past_time_usec

func time_msec() -> float:
	if 0 < player_rewind_amount_sec:
		return player_reverse_started_on_msec - player_rewind_amount_sec * 1000
	return Time.get_ticks_msec() - player_timeline_start_msec

func time_since_msec(past_time_msec: float) -> float:
	return time_msec() - past_time_msec

func reverse(delta: float) -> void:
	if 0. == player_reverse_started_on_msec:
		player_reverse_started_on_msec = Time.get_ticks_msec() - player_timeline_start_msec
		player_reverse_started_on_usec = Time.get_ticks_usec() - player_timeline_start_usec
		time_flow = TimeFlow.BACKWARD
		rewind_started.emit()
	player_rewind_amount_sec += delta

func finish_reverse() -> void:
	# Correct start time so records are stored with the actual relative timestamp moving forward
	# Push it forward with the double of the rewind time --> time spent while reversing AND time reversed
	player_timeline_start_msec += player_rewind_amount_sec * 2000
	player_timeline_start_usec += int(player_rewind_amount_sec * 2000000.)
	player_rewind_amount_sec = 0.
	player_reverse_started_on_msec = 0.
	player_reverse_started_on_usec = 0
	time_flow = TimeFlow.FORWARD
	rewind_stopped.emit()

func _enter_tree() -> void:
	if instance == null:
		_instance = self

func _exit_tree() -> void:
	if instance == self:
		_instance = null
		
