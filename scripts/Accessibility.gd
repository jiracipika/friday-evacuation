# Accessibility.gd — autoload-free helper for reading accessibility settings.
# Settings persist in user://settings.cfg alongside the Settings screen values.
# Static-only on purpose: usable from any script (modes, HUD, traps, powerups)
# without node wiring, and standalone-compilable for raw SceneTree tests.
class_name Accessibility
extends RefCounted

## Test seam: overridable so smoke tests never clobber the real player save.
static var CFG_PATH := "user://settings.cfg"

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
	return bool(get_setting(KEY_SUBTITLES, false))

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
	return bool(get_setting(KEY_SCREEN_SHAKE, true))

static func flash_effects_enabled() -> bool:
	return bool(get_setting(KEY_FLASH_EFFECTS, true))

static func reduced_motion_enabled() -> bool:
	return bool(get_setting(KEY_REDUCED_MOTION, false))

static func high_contrast_enabled() -> bool:
	return bool(get_setting(KEY_HIGH_CONTRAST, false))
