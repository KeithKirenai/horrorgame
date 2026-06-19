extends Node

signal notification_requested(text: String)
signal debug_log_requested(message: String)
signal generator_interaction_held()

func request_notification(text: String) -> void:
	notification_requested.emit(text)

func log_debug(message: String) -> void:
	debug_log_requested.emit(message)

func notify_generator_interaction_held() -> void:
	generator_interaction_held.emit()
