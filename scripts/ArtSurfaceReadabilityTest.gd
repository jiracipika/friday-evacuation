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
	print("ArtSurfaceReadabilityTest: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
