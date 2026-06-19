extends Node

signal generator_activated()
signal generator_deactivated()
signal game_over_requested()
signal win_game_requested()
signal exit_unlock_ready()

var pages_collected: int = 0
const TOTAL_PAGES: int = 5

var generators_activated: int = 0
const TOTAL_GENERATORS: int = 3

var exit_door_ref: Node = null
var level_generator: Node = null
var ui_manager: Node = null
var player: Node = null

func collect_page() -> void:
	pages_collected += 1
	EventBus.log_debug("Page collected! Total: %d/%d" % [pages_collected, TOTAL_PAGES])
	_check_exit_condition()

func activate_generator() -> void:
	generators_activated += 1
	EventBus.log_debug("Generator activated! Total: %d/%d" % [generators_activated, TOTAL_GENERATORS])
	generator_activated.emit()
	_check_exit_condition()

func deactivate_generator() -> void:
	generators_activated = max(generators_activated - 1, 0)
	EventBus.log_debug("Generator deactivated! Total: %d/%d" % [generators_activated, TOTAL_GENERATORS])
	generator_deactivated.emit()

func _check_exit_condition() -> void:
	if pages_collected >= TOTAL_PAGES and generators_activated >= TOTAL_GENERATORS:
		exit_unlock_ready.emit()

func can_unlock_exit() -> bool:
	return pages_collected >= TOTAL_PAGES and generators_activated >= TOTAL_GENERATORS

func reset() -> void:
	EventBus.log_debug("GameState reset: pages=%d, generators=%d" % [pages_collected, generators_activated])
	pages_collected = 0
	generators_activated = 0
	exit_door_ref = null

func request_game_over() -> void:
	game_over_requested.emit()

func request_win_game() -> void:
	win_game_requested.emit()
