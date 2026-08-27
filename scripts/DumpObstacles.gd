# DumpObstacles.gd — one-off audit: exact solid-obstacle footprints per floor.
extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var ev: Node = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(ev)
	await process_frame
	await process_frame
	for sb in _bodies(ev):
		var col: CollisionShape3D = null
		for c in sb.get_children():
			if c is CollisionShape3D:
				col = c
		if col == null or col.shape == null:
			continue
		var ext: Vector3 = Vector3.ZERO
		if col.shape is BoxShape3D:
			ext = (col.shape as BoxShape3D).size
		elif col.shape is CylinderShape3D:
			var cy := col.shape as CylinderShape3D
			ext = Vector3(cy.radius * 2.0, cy.height, cy.radius * 2.0)
		var p := sb.global_position
		var floor_idx := int(round((p.y - 0.5) / 6.0))
		print("F%d pos=(%.1f, %.1f) size=(%.1f x %.1f) %s" % [
			floor_idx, p.x, p.z, ext.x, ext.z,
			"scripted" if sb.get_script() != null else "static"])
	quit(0)

func _bodies(node: Node) -> Array[StaticBody3D]:
	var out: Array[StaticBody3D] = []
	if node is StaticBody3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_bodies(c))
	return out
