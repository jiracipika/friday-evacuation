# SabotageTrap.gd — Water puddle / banana peel that stuns players
extends Area3D

@export var stun_duration: float = 1.5
@export var lifetime: float = 12.0

var age: float = 0.0
var trap_type: String = "water"  # "water", "banana", "stapler", "spill"
var triggered := false
var owner_id: int = 0  # instance id of the player who placed this trap
var forced_type: String = ""  # set before add_child to skip random selection
var world_spawned: bool = false  # true = deterministic arena trap, not player-dropped

## Colorblind shape cues (Phase 8B): every trap gets a name label + floating
## glyph billboard so the type never rides on color alone (banana and spill
## are BOTH yellow). Mirrors PowerUpVisual's icon sprite, which ships
## unconditionally — distinct silhouettes help every player read traps.
const TYPE_NAMES := {
	"water": "WATER",
	"banana": "BANANA PEEL",
	"stapler": "STAPLES",
	"spill": "SLIPPERY SPILL",
}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Randomly assign type unless a forced type was requested (spill item)
	if forced_type != "":
		trap_type = forced_type
	else:
		var types = ["water", "banana", "stapler"]
		trap_type = types.pick_random()
	_apply_visual()

## Test/creator seam: pin the trap type before the node enters the tree.
func _set_forced_type(kind: String) -> void:
	forced_type = kind
	if trap_type != kind and not is_inside_tree():
		trap_type = kind
		_apply_visual()

## Phase 5: report this player-dropped trap to other peers (no-op offline).
func report_drop() -> void:
	if world_spawned or not is_inside_tree():
		return
	var network = get_node_or_null("/root/Network")
	if network and network.has_method("report_trap_drop"):
		var sender_id := owner_id
		network.report_trap_drop(global_position, trap_type, forced_type != "")

func _apply_visual() -> void:
	var mat = StandardMaterial3D.new()
	match trap_type:
		"water":
			mat.albedo_color = Color(0.3, 0.6, 1.0, 0.7)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"banana":
			mat.albedo_color = Color(1.0, 0.9, 0.2)
		"stapler":
			mat.albedo_color = Color(0.8, 0.8, 0.85)
		"spill":
			mat.albedo_color = Color(0.95, 0.85, 0.1, 0.75)
			mat.emission_enabled = true
			mat.emission = Color(0.8, 0.65, 0.05)
			mat.emission_energy_multiplier = 0.5
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_:
			mat.albedo_color = Color(1, 0, 1)
	
	var mesh_node = get_node_or_null("Mesh")
	if mesh_node:
		mesh_node.material_override = mat
	# Spill item drops a wide puddle (roadmap: 3x3 stun zone)
	if trap_type == "spill":
		if mesh_node:
			mesh_node.scale = Vector3(1.6, 1.0, 1.6)
		var col_node = get_node_or_null("CollisionShape3D")
		if col_node:
			# Swap in a bigger shape rather than scaling the node (physics-safe)
			var wide := CylinderShape3D.new()
			wide.radius = 1.6
			wide.height = 0.2
			col_node.shape = wide
	_build_shape_cue()

## Shape cue: name label + silhouette billboard above the trap. Both ship
## unconditionally (colorblind support = legible for everyone); the label
## names the hazard, the glyph gives a glance-distance SHAPE distinct from
## every other trap type. Idempotent — _apply_visual may run twice.
func _build_shape_cue() -> void:
	for old in get_children():
		if old is Label3D or old is Sprite3D:
			old.queue_free()
	# Name label (close range read).
	var label := Label3D.new()
	label.text = String(TYPE_NAMES.get(trap_type, trap_type.to_upper()))
	label.font_size = 32
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 1, 1, 0.92)
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.no_depth_test = true
	label.position = Vector3(0, 0.75, 0)
	add_child(label)
	# Glyph billboard (glance-distance shape read).
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var accent := Color(0.95, 0.95, 1.0)
	match trap_type:
		"water":
			accent = Color(0.5, 0.75, 1.0)
		"banana":
			accent = Color(1.0, 0.9, 0.2)
		"stapler":
			accent = Color(0.85, 0.88, 0.95)
		"spill":
			accent = Color(1.0, 0.85, 0.15)
	for y in 32:
		for x in 32:
			var col := Color(0.06, 0.07, 0.10, 0.0)
			if _trap_glyph_contains(x, y):
				col = Color(accent.r, accent.g, accent.b, 0.96)
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	var sprite := Sprite3D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.025  # ~0.8m sign — traps read at close range
	sprite.no_depth_test = true
	sprite.render_priority = 10
	sprite.position = Vector3(0, 1.15, 0)
	add_child(sprite)

## Silhouette masks per trap type (32x32 glyph space). Distinct SHAPES:
## water = wavy lines, banana = curved peel arc, stapler = U staple,
## spill = droplet (matches PowerUpVisual's SPILL droplet glyph).
func _trap_glyph_contains(x: int, y: int) -> bool:
	match trap_type:
		"water":
			# Three wavy horizontal lines.
			for line_y in [10, 16, 22]:
				if y >= line_y and y <= line_y + 2 and x >= 5 and x <= 26:
					var wave := int(2.0 * sin(float(x) * 0.55 + float(line_y)))
					if y == line_y + 1 or absi((y - line_y) - wave) <= 1:
						return true
			return false
		"banana":
			# Curved peel: crescent arc with tip nubs.
			var bx := float(x) - 16.0
			var by := float(y) - 20.0
			var r := sqrt(bx * bx + by * by)
			if r >= 9.0 and r <= 12.5 and by < 2.0:
				return true
			return (y >= 8 and y <= 11) and (x <= 8 or x >= 23)
		"stapler":
			# U-shaped staple with legs.
			if y >= 12 and y <= 15 and x >= 8 and x <= 23:
				return true
			return (x >= 8 and x <= 11 or x >= 20 and x <= 23) and y >= 12 and y <= 22
		"spill":
			# Droplet (same family as PowerUp SPILL glyph).
			var dx := float(x) - 16.0
			var dy := float(y) - 18.0
			if dy > 0.0 and (dx * dx) / 64.0 + (dy * dy) / 100.0 <= 1.0:
				return true
			# Teardrop tip.
			return y >= 4 and y <= 9 and absi(x - 16) <= (y - 4) / 2 + 1
		_:
			return false

func _on_body_entered(body: Node3D) -> void:
	if triggered or not body.is_in_group("players"):
		return
	triggered = true
	if body.has_method("stun"):
		body.stun(stun_duration)
		var stats = get_node_or_null("/root/StatsManager")
		if stats and int(owner_id) != int(body.get_instance_id()):
			stats.record_trap_landed()
		var fx = load("res://scripts/ImpactFX.gd")
		if fx:
			var burst_color = Color("70b7ff") if trap_type == "water" else (Color("ffcf55") if trap_type in ["banana", "spill"] else Color("dce6ff"))
			fx.burst(get_parent(), global_position + Vector3.UP * 0.2, burst_color, 24)
		var audio = get_node_or_null("/root/AudioManager")
		if audio:
			audio.play_sfx("trap", 1.3)
		var a11y = load("res://scripts/Accessibility.gd")
		if a11y:
			a11y.caption("TRAP HIT: " + trap_type.to_upper(), 1.2)
		print("[TRAP] %s hit %s trap!" % [body.player_display_name if "player_display_name" in body else "Player", trap_type])
		queue_free()

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
