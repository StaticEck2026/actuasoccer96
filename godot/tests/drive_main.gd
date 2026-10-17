extends SceneTree
# End-to-end test of the real driver (scripts/main.gd): starts at the selection
# menu, presses KICK OFF, then plays with random keyboard input injected through
# Godot's input system, taking screenshots; checks the match returns to the menu.
# usage: xvfb-run -a godot --path godot --rendering-driver opengl3 -s res://tests/drive_main.gd -- OUTDIR SECONDS
var main: Node
var t := 0.0
var outdir := "/tmp/drive"
var secs := 60.0
var rng := RandomNumberGenerator.new()
var held := {}
var shot_i := 0
var next_shot := 5.0
var frames := 0

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: outdir = a[0]
	if a.size() > 1: secs = float(a[1])
	DirAccess.make_dir_recursive_absolute(outdir)
	rng.seed = 12345
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _key(code: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)

func _process(delta: float) -> bool:
	t += delta
	frames += 1
	if frames == 3:
		# press the KICK OFF button of the menu
		main.menu._start()
	if main.running and frames % 6 == 0:
		var keys := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_KP_0, KEY_KP_PERIOD]
		var k: int = keys[rng.randi_range(0, keys.size() - 1)]
		if held.has(k):
			_key(k, false); held.erase(k)
		else:
			_key(k, true); held[k] = true
	if t >= next_shot:
		next_shot += 10.0
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s/drive_%02d.png" % [outdir, shot_i])
		print("shot %d t=%.1f fps~%.1f min %d score %d-%d mode %d cam %d" % [shot_i, t, Engine.get_frames_per_second(), Glob.match_time.min, Glob.team_a_goals, Glob.team_b_goals, Glob.match_mode, Glob.camera])
		shot_i += 1
	if t > secs:
		print("done frames %d logic %d min %d running %s" % [frames, Glob.logic_cnt, Glob.match_time.min, main.running])
		return true
	return false
