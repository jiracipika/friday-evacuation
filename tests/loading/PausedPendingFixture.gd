# PausedPendingFixture.gd — target scene with PROCESS_MODE_ALWAYS and a
# deliberately paused tree at swap time. Counts frames via its ALWAYS
# processing and reports is_loading_complete() only after several real
# frames, proving the loader keeps polling readiness while paused and
# never dismisses merely because tree.paused is true.
extends Node

var _frames_waited := 0
var _complete := false


func is_loading_complete() -> bool:
	return _complete


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_frames_waited += 1
	if _frames_waited >= 5:
		_complete = true
