extends SceneTree
# Renders a match through the real renderer and saves screenshots.
# usage (needs a display, e.g. xvfb-run):
#   godot --path godot --rendering-driver opengl3 -s res://tests/screenshot.gd -- [outdir] [frames...]
# Frames are logic frames (10 timer ticks each).  Screenshot names: <outdir>/shot_<frame>_cam<c>.png
# A frame spec "F:C" forces Glob.camera = C from frame F on.

var main: Node
var frame := 0
var shots := []          # [frame, camera or -1]
var outdir := "/tmp/shots"
var t_render := 0.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		outdir = args[0]
	DirAccess.make_dir_recursive_absolute(outdir)
	for i in range(1, args.size()):
		var a: String = args[i]
		if ":" in a:
			shots.append([int(a.split(":")[0]), int(a.split(":")[1])])
		else:
			shots.append([int(a), -1])
	if shots.is_empty():
		shots = [[5, -1], [60, -1], [200, -1], [400, -1]]
	main = load("res://scripts/main.gd").new()
	root.add_child(main)

var started := false

func _start() -> void:
	var users := [] if OS.get_environment("SHOT_USER") == "" else [{"team": 0, "control": 0}]
	main.start_match({"team_a": 4, "team_b": 6, "time": 0, "users": users})
	main.running = false      # we drive the frames ourselves
	if OS.get_environment("SHOT_LORES") != "":
		Eng3D.switchmode()            # F10: 640x400 <-> 320x200
	if OS.get_environment("SHOT_SIZE") != "":
		Glob.setup.screen_size = int(OS.get_environment("SHOT_SIZE"))
		Eng3D._set_main_buff_size()   # -/= screen size
	if OS.get_environment("HIDE_STANDS") != "":
		main.view.debug_hide_stands = true
	Glob.demo_match = 0
	started = true

func _process(delta: float) -> bool:
	if not started:
		_start()
		return false
	if main.view == null:
		push_error("no view")
		return true
	for s in shots:
		if s[0] == frame and s[1] >= 0:
			Glob.camera = s[1]
	for k in 10:
		NetInput.nethandler()
	if not Football.match_frame():
		return true
	var t0 := Time.get_ticks_usec()
	main.view.update_view()
	t_render += (Time.get_ticks_usec() - t0) / 1000.0
	main.hud.update_hud()
	for s in shots:
		if s[0] == frame - 2:     # give the renderer two frames
			var img := root.get_viewport().get_texture().get_image()
			var fn := "%s/shot_%04d_cam%d.png" % [outdir, s[0], Glob.camera]
			img.save_png(fn)
			print("saved ", fn, "  avg update_view ms: %.2f" % (t_render / max(frame, 1)))
	frame += 1
	var last: int = 0
	for s in shots:
		last = max(last, s[0])
	return frame > last + 3
