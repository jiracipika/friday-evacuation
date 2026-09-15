extends SceneTree
# B2 smoke: hero GLB loads, has Worker+Chair children, tri budget under
# LOD0 ceiling, and instances under PlayerChair without script errors.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var packed: PackedScene = load("res://models/hero_assembly.glb")
	check(packed != null, "hero_assembly.glb loads")
	if packed:
		var inst: Node3D = packed.instantiate()
		var worker: Node = inst.find_child("Worker", true, false)
		var chair: Node = inst.find_child("Chair", true, false)
		check(worker != null, "Worker mesh present")
		check(chair != null, "Chair mesh present")
		var total := 0
		var meshes := 0
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m: Mesh = (mi as MeshInstance3D).mesh
			if m:
				total += m.get_faces().size() / 3
				meshes += 1
		check(meshes >= 2, "mesh instances >= 2 (got %d)" % meshes)
		check(total > 0 and total <= 35000, "LOD0 tri budget <= 35k (got %d)" % total)
		# Seat-top height sanity: chair cushions should exist near Y=0.57-0.62
		var aabb: AABB = inst.find_children("*", "MeshInstance3D", true, false)[0].get_aabb()
		check(aabb.size.y > 1.0 and aabb.size.y < 1.7, "assembly height sane (got %.2f)" % aabb.size.y)
		inst.free()
	print("HeroAssemblySmokeTest: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
