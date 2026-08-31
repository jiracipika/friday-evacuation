extends SceneTree

var scenes := [
	"res://scenes/Hauled.tscn",
	"res://scenes/ShopSeek.tscn",
	"res://scenes/PizzaColony.tscn",
]
var index := 0
var current: Node
var frames := 0

func _init() -> void:
	_test_next.call_deferred()

func _process(_delta: float) -> bool:
	frames += 1
	if frames >= 4:
		if current and is_instance_valid(current):
			current.queue_free()
		index += 1
		frames = 0
		if index >= scenes.size():
			print("=== MODE SMOKE TEST PASSED ===")
			quit(0)
		else:
			_test_next.call_deferred()
	return false

func _test_next() -> void:
	var packed = load(scenes[index])
	if not packed:
		printerr("Failed to load %s" % scenes[index])
		quit(1)
		return
	# PreMatchModal pauses the tree on mount — suppressed per instantiation.
	load("res://scripts/PreMatchModal.gd").suppress_next()
	current = packed.instantiate()
	root.add_child(current)
	print("[PASS] instantiated %s" % scenes[index])
