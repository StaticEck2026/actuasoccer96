extends SceneTree
# Visual test of the 2D overlay (scripts/game/eng3d.gd + scripts/render/hud.gd):
# starts a quick match, triggers every in-game menu/banner and the modal menus
# (options -> formation, replay, substitution) and saves screenshots.
#
# xvfb-run -a -s "-screen 0 1280x800x24" godot --path godot --rendering-driver opengl3 \
#     -s res://tests/hud_menus.gd -- --quick [outdir]
# Screenshots: <outdir>/hud_NN_name.png (default /tmp/hud_shots)

var main: Node
var frame := 0
var step := 0
var wait := 0
var outdir := "/tmp/hud_shots"
var steps: Array = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if not a.begins_with("--"):
			outdir = a
	DirAccess.make_dir_recursive_absolute(outdir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_build_steps()

func key(sc: int, ext := false, down := true) -> void:
	if ext:
		NetInput.key_handler(0xE0)
	NetInput.key_handler(sc if down else (sc | 0x80))

func tap(sc: int, ext := false) -> void:
	key(sc, ext, true)

func untap(sc: int, ext := false) -> void:
	key(sc, ext, false)

func shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var p := "%s/hud_%02d_%s.png" % [outdir, step, name]
	img.save_png(p)
	print("saved ", p, "  menu=", Eng3D.menu, " slide=", Eng3D.slide, " modal=", Eng3D.modal, " mstate=", Eng3D.mstate)

# Show a banner menu: trigger it, let it slide in (and pin it), screenshot.
func banner(name: String, trig: Callable, frames := 45) -> void:
	steps.append([1, trig, ""])
	steps.append([frames, func(): Eng3D.mcount = 100000, name])

func _build_steps() -> void:
	steps.append([60, func(): pass, "start_ref"])
	steps.append([1, func(): pass, ""])
	# goals for the score breakdowns (team A player 9 twice, a penalty, an own goal by B)
	steps.append([1, func():
		Eng3D.GOAL_SCORED(0, 8, 12)
		Eng3D.GOAL_SCORED(0, 8, 33 + 256)
		Eng3D.GOAL_SCORED(0, 13, 40 + 512)
		Eng3D.GOAL_SCORED(0, 20, 71)
		Glob.team_a_goals = 3
		Glob.team_b_goals = 1, ""])
	banner("goal", func(): Eng3D.do_goal_menu(0, 8, 12), 12)
	steps.append([30, func(): pass, "goal_full"])
	banner("booked", func(): Eng3D.do_booked_menu(1, 3))
	banner("off", func(): Eng3D.do_off_menu(0, 4))
	banner("direct", func(): Eng3D.do_direct_menu(0))
	banner("indirect", func(): Eng3D.do_indirect_menu(1))
	banner("penalty", func(): Eng3D.do_penalty_menu(0))
	banner("corner", func(): Eng3D.do_corner_menu(1))
	banner("throw", func(): Eng3D.do_throw_menu(0))
	banner("goalkick", func(): Eng3D.do_goalkick_menu(1))
	banner("kickoff", func(): Eng3D.do_kickoff_menu(0))
	banner("offside", func(): Eng3D.do_offside_menu(1))
	banner("injured", func(): Eng3D.do_injured_menu(1, 6))
	banner("owngoal", func(): Eng3D.do_owngoal_menu(1, 2, 40))
	banner("fulltime", func(): Eng3D.do_fulltime_menu(), 90)
	steps.append([1, func(): bench("fulltime"), ""])
	banner("halftime", func(): Eng3D.do_halftime_menu(), 90)
	banner("extratime", func(): Eng3D.do_extratime_menu(), 90)
	banner("penalty_shootout", func(): Eng3D.do_penalty_shootout_menu(), 90)
	banner("final_score", func(): Eng3D.do_final_score_menu(), 90)
	banner("ref", func(): Eng3D.do_ref_menu())
	banner("stats", func(): Eng3D.do_stats_menu(), 90)
	# slide out
	steps.append([1, func(): Eng3D.mcount = 0, ""])
	steps.append([10, func(): pass, "slide_out"])
	steps.append([60, func(): Glob.key_togs[0xf] = 1, "scanner"])
	steps.append([1, func(): Glob.key_togs[0xf] = 0, ""])
	# Options menu via the real path (F1 -> process_keys -> update_3d -> options())
	steps.append([2, func(): tap(0x3b), ""])
	steps.append([2, func(): untap(0x3b), ""])
	steps.append([80, func(): pass, "options"])
	steps.append([1, func(): bench("options"), ""])
	steps.append([2, func(): tap(0x50, true), ""])		# cursor down
	steps.append([2, func(): untap(0x50, true), ""])
	steps.append([10, func(): pass, "options_down"])
	# F3: formation
	steps.append([2, func(): tap(0x3d), ""])
	steps.append([2, func(): untap(0x3d), ""])
	steps.append([80, func(): pass, "formation"])
	# keypad 0 (fire) on the formation button: next formation
	steps.append([2, func(): tap(0x52), ""])
	steps.append([2, func(): untap(0x52), ""])
	steps.append([10, func(): pass, "formation_next"])
	# F3 = cancel -> back to options
	steps.append([2, func(): tap(0x3d), ""])
	steps.append([2, func(): untap(0x3d), ""])
	steps.append([80, func(): pass, "options_again"])
	# F1: replay
	steps.append([2, func(): tap(0x3b), ""])
	steps.append([2, func(): untap(0x3b), ""])
	steps.append([60, func(): pass, "replay"])
	steps.append([60, func(): pass, "replay_later"])
	# F4: done -> back to the match
	steps.append([2, func(): tap(0x3e), ""])
	steps.append([2, func(): untap(0x3e), ""])
	steps.append([60, func(): pass, "after_replay"])
	# Substitution menu (the path of process_subs(): opt_user=100)
	steps.append([1, func():
		Eng3D.sub_p_a = 0
		Glob.opt_user = 100
		Glob.opt_team = 0, ""])
	steps.append([80, func(): pass, "substitution"])
	steps.append([2, func(): tap(0x52), ""])		# fire on "OFF": next player
	steps.append([2, func(): untap(0x52), ""])
	steps.append([10, func(): pass, "substitution_next"])
	steps.append([2, func(): tap(0x01), ""])		# Esc
	steps.append([2, func(): untap(0x01), ""])
	steps.append([40, func(): pass, "after_sub"])
	# low resolution (F10: switchmode)
	steps.append([2, func(): tap(0x44), ""])
	steps.append([2, func(): untap(0x44), ""])
	banner("lo_goal", func(): Eng3D.do_goal_menu(0, 8, 12))
	banner("lo_fulltime", func(): Eng3D.do_fulltime_menu(), 90)
	banner("lo_stats", func(): Eng3D.do_stats_menu(), 90)
	steps.append([2, func(): tap(0x3b), ""])
	steps.append([2, func(): untap(0x3b), ""])
	steps.append([80, func(): pass, "lo_options"])
	steps.append([2, func(): tap(0x3e), ""])
	steps.append([2, func(): untap(0x3e), ""])
	steps.append([40, func(): Glob.key_togs[0xf] = 1, "lo_scanner"])

# Average cost of one overlay frame (render3d 2D part + upload).
func bench(name: String) -> void:
	var h = main.hud
	var t0 := Time.get_ticks_usec()
	for i in 20:
		h._begin()
		Eng3D.render3d_2d()
		h._end()
	print("bench %s: %.2f ms/frame" % [name, (Time.get_ticks_usec() - t0) / 20000.0])

func _process(delta: float) -> bool:
	frame += 1
	if step >= steps.size():
		print("done")
		return true
	wait += 1
	var s: Array = steps[step]
	if wait == 1:
		s[1].call()
	if wait >= s[0]:
		if s[2] != "":
			shot(s[2])
		step += 1
		wait = 0
	return false
