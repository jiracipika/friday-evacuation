# PendingFixture.gd — target scene that reports ASYNC readiness: it exists
# and is node-ready for a few frames BEFORE is_loading_complete() turns
# true. Used to prove the loader waits for actual readiness instead of
# dismissing as soon as is_node_ready() would pass.
extends Node

var _frames_waited := 0
var _complete := false


func is_loading_complete() -> bool:
	return _complete


func _process(_delta: float) -> void:
	_frames_waited += 1
	if _frames_waited >= 3:
		_complete = true
