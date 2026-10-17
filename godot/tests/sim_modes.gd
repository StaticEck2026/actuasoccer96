extends SceneTree
# usage: -- <competition> <frames>   (0 friendly, 2 cup, 3 practice, 5 penalties)
func _init():
	var args := OS.get_cmdline_user_args()
	var comp := int(args[0]) if args.size() > 0 else 5
	var frames := int(args[1]) if args.size() > 1 else 6000
	var users := [] if comp != 3 else [{"team": 0, "control": 0}]
	MatchSetup.prepare({"team_a": 2, "team_b": 9, "time": 0, "rand": 4242, "competition": comp, "users": users})
	Football.match_start()
	Glob.demo_match = 0
	var last := ""
	for f in frames:
		for k in 10:
			NetInput.nethandler()
		if Eng3D.modal:
			Eng3D.modal = 0
		if not Football.match_frame():
			print("ended at ", f)
			break
		var st := "half %d mode %d score %d-%d pen_game %d pens(%d,%d) taker %d menu %d" % [Glob.match_half, Glob.match_mode, Glob.team_a_goals, Glob.team_b_goals, Glob.penalty_game, Glob.home_pens_left, Glob.away_pens_left, Glob.penalty_taker, Eng3D.menu]
		if st != last:
			print("f%d min %d %s" % [f, Glob.match_time.min, st])
			last = st
	print("done min %d score %d-%d  pens %d-%d" % [Glob.match_time.min, Glob.team_a_goals, Glob.team_b_goals, Glob.EUROmatch_info.Team_A_penalties, Glob.EUROmatch_info.Team_B_penalties])
	quit()
