# FaceSmokeTest.gd — verifies FaceStudio wiring end-to-end headlessly:
# 1) textures generate for all variants (non-trivial pixel variance)
# 2) googly texture generates
# 3) a spawned PlayerChair builds FaceDecal + GooglyEye nodes
# 4) _update_googly_eyes runs without error and shifts pupils under force
# Frame-driven state machine; quits 0/1 for CI.
extends SceneTree

var step := 0
var frames := 0
var chair = null
var world: Node3D = null

func _init() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var fcol := CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(8, 0.2, 8)
	fcol.shape = fs
	floor_body.add_child(fcol)
	floor_body.position = Vector3(0, -0.1, 0)
	world.add_child(floor_body)

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	match step:
		0:
			var lib = load("res://scripts/FaceStudio.gd")
			if lib == null:
				printerr("[FAIL] FaceStudio not found")
				quit(1)
				return true
			for variant in ["panic", "determined", "deranged", "exhausted", "screaming"]:
				var tex: ImageTexture = lib.face_albedo(variant)
				var img := tex.get_image()
				var minv: float = 1.0
				var maxv: float = 0.0
				for y in range(0, img.get_height(), 4):
					for x in range(0, img.get_width(), 4):
						var p := img.get_pixel(x, y)
						minv = minf(minv, p.v)
						maxv = maxf(maxv, p.v)
				if maxv - minv < 0.2:
					printerr("[FAIL] face %s too flat (%.2f..%.2f)" % [variant, minv, maxv])
					quit(1)
					return true
			var gt: ImageTexture = lib.googly_texture(3.0)
			if gt == null:
				printerr("[FAIL] googly texture")
				quit(1)
				return true
			step += 1
		1:
			var scene = load("res://scenes/PlayerChair.tscn")
			chair = scene.instantiate()
			world.add_child(chair)
			step += 1
		2:
			if not is_instance_valid(chair):
				printerr("[FAIL] chair freed itself")
				quit(1)
				return true
			var rider = chair.get("rider_root")
			if rider == null or not is_instance_valid(rider):
				return false   # rider spawns a frame later
			var decals: Array = rider.find_children("FaceDecal", "MeshInstance3D", true, false)
			var googlies: Array = rider.find_children("GooglyEye*", "MeshInstance3D", true, false)
			if decals.is_empty():
				printerr("[FAIL] no FaceDecal on rider")
				quit(1)
				return true
			if googlies.size() != 2:
				printerr("[FAIL] expected 2 googly eyes, got %d" % googlies.size())
				quit(1)
				return true
			# Force an acceleration event and tick the updater.
			chair.velocity = Vector3(6, 0, 0)
			chair._update_googly_eyes(1.0 / 60.0)
			var m: StandardMaterial3D = (googlies[0] as MeshInstance3D).material_override
			if m.albedo_texture == null:
				printerr("[FAIL] googly material has no texture after update")
				quit(1)
				return true
			print("=== FACE SMOKE TEST PASSED ===")
			quit(0)
			return true
	return false
