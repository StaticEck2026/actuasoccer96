extends SceneTree
func _init():
	MatchSetup.prepare({"team_a": 4, "team_b": 6, "time": 0, "users": []})
	Football.match_start()
	Glob.demo_match = 0
	for f in 700:
		for k in 10:
			NetInput.nethandler()
		Football.match_frame()
		if f >= 310 and (f % 4 == 0 or f > 365 and f < 375):
			var pt = Glob.penalty_taker
			var s := ""
			if pt > 0:
				var p = Glob.teams[pt-1]
				s = "taker %d act %d int %d/%d pos(%.0f,%.0f) go(%.0f,%.0f) anim %d frm %.2f" % [pt, p.tm_act, p.int_move, p.int_cnt, p.tm_x, p.tm_y, p.go_tx, p.go_ty, p.tm_anim, p.tm_frm]
			print("f%d mode %d ball(%.0f,%.0f,%.0f) d(%.1f,%.1f) poss %d last %d bad %d %s" % [f, Glob.match_mode, Glob.ballx, Glob.bally, Glob.ballz, Glob.ballxdis, Glob.ballydis, Glob.ball_poss, Glob.last_touch, Glob.bad_guy, s])
	quit()
