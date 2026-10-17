extends SceneTree
# Headless match simulation: CPU vs CPU, driving the original 200Hz timer.
# usage: godot --headless --path godot -s res://tests/sim_match.gd -- [frames] [team_a] [team_b] [seed]
func _init():
	var args := OS.get_cmdline_user_args()
	var frames := int(args[0]) if args.size() > 0 else 2000
	var cfg := {"team_a": int(args[1]) if args.size() > 1 else 4, "team_b": int(args[2]) if args.size() > 2 else 6,
		"time": 0, "rand": int(args[3]) if args.size() > 3 else 3523, "users": []}
	MatchSetup.prepare(cfg)
	var err := Football.match_start()
	print("match_start -> ", err, " camera ", Glob.camera, " time_factor ", Glob.time_factor)
	Glob.demo_match = 0		# play the full match instead of the 80s rolling demo
	var last_min := -1
	var t0 := Time.get_ticks_msec()
	for f in frames:
		for k in 10:
			NetInput.nethandler()
		if not Football.match_frame():
			print("match loop ended at frame ", f)
			break
		if f % 500 == 0:
			print("f %d line_up %d mode %d clock %d sec %.1f kickoff %d act0 %d anim0 %d x0 %.1f" % [f, Glob.line_up, Glob.match_mode, Glob.clock_running, Glob.match_time.sec, Glob.kickoff, Glob.teams[0].tm_act, Glob.teams[0].tm_anim, Glob.teams[0].tm_x])
		if Glob.match_time.min != last_min and Glob.match_time.min % 5 == 0:
			last_min = Glob.match_time.min
			print("min %d  half %d  mode %d  score %d-%d  ball (%.0f,%.0f,%.0f) poss %d  logic %d" % [Glob.match_time.min, Glob.match_half, Glob.match_mode, Glob.team_a_goals, Glob.team_b_goals, Glob.ballx, Glob.bally, Glob.ballz, Glob.ball_poss, Glob.logic_cnt])
	print("done: %d ms, logic cycles %d, score %d-%d, min %d" % [Time.get_ticks_msec() - t0, Glob.logic_cnt, Glob.team_a_goals, Glob.team_b_goals, Glob.match_time.min])
	Football.match_end()
	quit()
