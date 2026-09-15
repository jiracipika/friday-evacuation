# SubviewWrap.gd — tiny behavior shell for Main.gd's in-menu subviews.
#
# The subview wrap is a plain Control (built in code, so it has no script of
# its own); this adds the focus entry point the menu contract expects:
# grab_focus_first() focuses the first focusable control in the content list.
extends Control

func grab_focus_first() -> void:
	var list: Node = get_meta("focus_list") if has_meta("focus_list") else null
	if list == null:
		return
	for node in list.find_children("*", "Button", true, false):
		var btn := node as Button
		if btn and btn.is_visible_in_tree() and btn.focus_mode != Control.FOCUS_NONE:
			btn.grab_focus()
			return
