extends SceneTree
# Checks that the selection screen starts a match from real input events:
# mode "enter" sends an Enter key press, mode "click" clicks the KICK OFF button.
# usage: xvfb-run -a godot --path godot --rendering-driver opengl3 -s res://tests/menu_start.gd -- enter|click
var main: Node
var f := 0
var mode := "enter"
func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: mode = a[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _process(d):
	f += 1
	if f == 10:
		if mode == "enter":
			var e := InputEventKey.new()
			e.keycode = KEY_ENTER; e.physical_keycode = KEY_ENTER; e.pressed = true
			Input.parse_input_event(e)
			var r := InputEventKey.new()
			r.keycode = KEY_ENTER; r.physical_keycode = KEY_ENTER; r.pressed = false
			Input.parse_input_event(r)
		else:
			var b: Button = main.menu.go
			var p: Vector2 = b.get_global_rect().get_center()
			for pressed in [true, false]:
				var m := InputEventMouseButton.new()
				m.button_index = MOUSE_BUTTON_LEFT; m.pressed = pressed; m.position = p; m.global_position = p
				Input.parse_input_event(m)
	if f == 200:
		root.get_viewport().get_texture().get_image().save_png("/tmp/menu_start_%s.png" % mode)
		print("RESULT mode=%s running=%s logic=%d" % [mode, main.running, Glob.logic_cnt])
		return true
	return false
