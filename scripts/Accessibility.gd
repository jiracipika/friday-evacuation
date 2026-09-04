# Accessibility.gd — autoload-free helper for reading accessibility settings.
# Settings persist in user://settings.cfg alongside the Settings screen values.
# Static-only on purpose: usable from any script (modes, HUD, traps, powerups)
# without node wiring, and standalone-compilable for raw SceneTree tests.
class_name Accessibility
extends RefCounted

## Test seam: overridable so smoke tests never clobber the real player save.
static var CFG_PATH := "user://settings.cfg"

## Ladder harnesses pass --test-mode (run_ladder.sh) so a developer's real
## 0.75x save can't skew deterministic bot/smoke runs. Overridable so the
## Phase 8B round-trip test can exercise the real wiring anyway. Checks both
## arg arrays: Godot only reports args after a `--` separator as user args.
static var TEST_MODE := \
	"--test-mode" in OS.get_cmdline_args() or "--test-mode" in OS.get_cmdline_user_args()

## Setting keys (section "accessibility")
const KEY_SCREEN_SHAKE := "screen_shake"
const KEY_FLASH_EFFECTS := "flash_effects"
const KEY_REDUCED_MOTION := "reduced_motion"
const KEY_HIGH_CONTRAST := "high_contrast"
const KEY_SUBTITLES := "subtitles"
const KEY_TIME_SCALE := "time_scale"

const TIME_SCALE_OPTIONS := [0.75, 1.0, 1.25]

static func _cfg() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(CFG_PATH)
	return config

static func get_setting(key: String, default: Variant) -> Variant:
	return _cfg().get_value("accessibility", key, default)

static func set_setting(key: String, value: Variant) -> void:
	var config := _cfg()
	config.set_value("accessibility", key, value)
	config.save(CFG_PATH)

## Effective time scale: single-player only. Returns 1.0 whenever a network
## peer is active so remote peers never desync from local physics tuning.
static func get_time_scale() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		var net_node := tree.root.get_node_or_null("Network")
		if net_node and "peer" in net_node and net_node.peer:
			return 1.0
	var raw := float(get_setting(KEY_TIME_SCALE, 1.0))
	# Guard against corrupted values: snap to the nearest supported option.
	var best := 1.0
	var best_dist := absf(raw - 1.0)
	for option in TIME_SCALE_OPTIONS:
		var dist := absf(raw - option)
		if dist < best_dist:
			best_dist = dist
			best = option
	return best

static func captions_enabled() -> bool:
	# bool() over a corrupt String crashes ("Nonexistent 'bool' constructor").
	return _as_bool(get_setting(KEY_SUBTITLES, false), false)

## Phase 8B wiring: actually drive Engine.time_scale from the setting.
## The race clock and every _process(delta) in the game tick on scaled delta,
## so physics, timers, tweens, and captions all follow one knob. No-op in
## test mode so a developer's real 0.75x save can't skew ladder runs.
static func apply_time_scale() -> void:
	if TEST_MODE:
		return
	Engine.time_scale = get_time_scale()

## Restore neutral speed (mode teardown; also the network desync guard).
static func reset_time_scale() -> void:
	Engine.time_scale = 1.0

## Show a caption now, routed through whatever overlay exists.
## Call sites never need to know whether subtitles are enabled or mounted.
static func caption(text: String, duration := 1.5) -> void:
	if not captions_enabled():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group("caption_overlays"):
		if node and is_instance_valid(node) and node.has_method("show_caption"):
			node.show_caption(text, duration)
			return

static func screen_shake_enabled() -> bool:
	return _as_bool(get_setting(KEY_SCREEN_SHAKE, true), true)

static func flash_effects_enabled() -> bool:
	return _as_bool(get_setting(KEY_FLASH_EFFECTS, true), true)

static func reduced_motion_enabled() -> bool:
	return _as_bool(get_setting(KEY_REDUCED_MOTION, false), false)

static func high_contrast_enabled() -> bool:
	return _as_bool(get_setting(KEY_HIGH_CONTRAST, false), false)


## Safe bool coercion: GDScript's bool() CRASHES on String values
## ("Nonexistent 'bool' constructor") and a hand-edited or legacy cfg can
## hold "yes"/"no". Anything not literally a bool falls back to default.
static func _as_bool(value: Variant, default: bool) -> bool:
	return value if value is bool else default
