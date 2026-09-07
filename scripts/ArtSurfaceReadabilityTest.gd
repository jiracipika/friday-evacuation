extends SceneTree
var failures: int = 0
var checks: int = 0
func _init() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
func _run() -> void:
	var floors: GDScript = load("res://scripts/FloorMaterials.gd")
	var props: GDScript = load("res://scripts/PropMaterials.gd")
	var walls: GDScript = load("res://scripts/WallMaterials.gd")
	var img: Image = floors.floor_albedo(Color(0.2, 0.2, 0.25), 0).get_image()
	var ratio: float = img.get_pixel(1, 64).get_luminance() / img.get_pixel(64, 64).get_luminance()
	check(ratio > 0.75 and ratio < 0.98, "carpet seams suggest fabric joins, not black trenches: %.3f" % ratio)
	var wood: StandardMaterial3D = props.wood_planks()
	check(wood.albedo_texture.get_image().has_mipmaps(), "wood albedo has real mip levels, not only a mip sampler")
	var normal: Image = wood.normal_texture.get_image()
	var minimum_z: float = 1.0
	for y in range(8, 248, 16):
		for x in range(4, 252, 4):
			minimum_z = minf(minimum_z, normal.get_pixel(x,y).b)
	check(minimum_z > 0.9, "wood field normals face outward, not sideways: %.3f" % minimum_z)
	check(wood.normal_scale <= 0.35, "wood relief does not turn desks into camouflage")
	# Partition weave: the highest-frequency surface in the office. Ribs
	# must read as felt at gameplay distance, not as shimmer/moiré bait.
	var partition: StandardMaterial3D = walls.make_partition(2)
	check(partition.normal_scale <= 0.5, "partition weave relief stays subtle (%.2f <= 0.5)" % partition.normal_scale)
	var pn: Image = partition.normal_texture.get_image()
	var p_min_z: float = 1.0
	for y in range(8, 248, 16):
		for x in range(4, 508, 4):
			p_min_z = minf(p_min_z, pn.get_pixel(x, y).b)
	check(p_min_z > 0.9, "partition normals face outward, not sideways: %.3f" % p_min_z)
	var p_img: Image = partition.albedo_texture.get_image()
	var p_swing: float = 0.0
	for y in range(4, 252, 4):
		for x in range(8, 504, 4):
			var l := p_img.get_pixel(x, y).get_luminance()
			p_swing = maxf(p_swing, absf(l - p_img.get_pixel(x - 1, y).get_luminance()))
	check(p_swing < 0.09, "partition weave is calm at pixel level (swing %.3f < 0.09)" % p_swing)
	# Ceiling T-bar grid: seams must read as panel joints, not trenches.
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var evac: Node = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(evac)
	await process_frame
	await process_frame
	var ceil_mat: StandardMaterial3D = evac._ceiling_material(0)
	var c_img: Image = ceil_mat.albedo_texture.get_image()
	var line_l: float = c_img.get_pixel(1, 65).get_luminance()
	var field_l: float = c_img.get_pixel(32, 65).get_luminance()
	check(line_l / field_l > 0.72, "ceiling T-bar reads as joint, not trench (ratio %.2f > 0.72)" % (line_l / field_l))
	evac.queue_free()
	await process_frame
	print("ArtSurfaceReadabilityTest: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
