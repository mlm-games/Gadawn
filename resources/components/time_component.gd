class_name TimeComponent
extends EventComponent

@export var start_time_sec: float = 0.0
@export var duration_sec: float = 1.0

func get_end_time() -> float:
	return start_time_sec + duration_sec

func shift_time(delta: float):
	start_time_sec += delta

func is_in_range(start: float, end: float) -> bool:
	return start_time_sec >= start and start_time_sec <= end
