extends SceneTree
static func chk(tag: String) -> bool:
	if is_nan(Glob.ballx) or is_nan(Glob.bally):
		print("NaN after ", tag, " poss ", Glob.ball_poss, " last ", Glob.last_touch)
		return true
	for i in 22:
		var p = Glob.teams[i]
		if is_nan(p.tm_x) or is_nan(p.tm_y):
			print("player NaN after ", tag, " player ", i+1)
			return true
	return false

static func pstate(i: int) -> String:
	var p = Glob.teams[i-1]
	return "p%d act %d int %d/%d anim %d frm %.3f fstep %.4f pos(%.2f,%.2f,%.2f) dis(%.3f,%.3f) go(%.1f,%.1f) gotd(%.3f,%.3f) gocnt %d dir %d/%d/%d" % [i, p.tm_act, p.int_move, p.int_cnt, p.tm_anim, p.tm_frm, p.tm_fstep, p.tm_x, p.tm_y, p.tm_z, p.tm_xdis, p.tm_ydis, p.go_tx, p.go_ty, p.go_txdis, p.go_tydis, p.go_cnt, p.turn_dir, p.face_dir, p.dir_mode]

static func trace_teams() -> void:
	# replicate process_teams() for team B with checks around each call
	Actions.init_tussles()
	var order := [1, 12] if Glob.frame else [12, 1]
	for p in order:
		Glob.player_num = p
		while Glob.player_num < p + 11:
			var n: int = Glob.player_num
			var pl = Glob.teams[n - 1]
			if pl.guy_on:
				if n == 21: print("before   ", pstate(21))
				Actions.process_anims(pl)
				if n == 21: print("anims    ", pstate(21))
				if not pl.tm_limbo and (not Glob.ball_limbo_on or Glob.ball_limbo_p != n):
					if not Glob.just_thrown:
						BallInt.ball_interact(pl)
					if n == 21: print("interact ", pstate(21))
					Glob.user_controlled = pl.control
					if n == 21:
						pl.tm_htype = 0
						Intell.override(pl); print("override ", pstate(21))
						Intell.player_ints(pl); print("ints     ", pstate(21))
						Intell.intelligence(pl); print("intell   ", pstate(21))
						Intell.player_comment(pl)
						print("zone1 %d zone2 %d bz %d mm %d" % [Glob.ball_zone1, Glob.ball_zone2, 0, Glob.match_mode])
						var rr: Array = Intell.get_target(2, Glob.ball_zone2, Glob.zone2_x, Glob.zone2_y, 21-12, 0.0, 0.0, Glob.match_tactics2)
						print("get_target -> ", rr, " zone2xy ", Glob.zone2_x, ",", Glob.zone2_y, " tac ", Glob.match_tactics2[Glob.ball_zone2][9])
						Actions.init_run_act(pl, Glob.pitch_len - rr[0], Glob.pitch_wid - rr[1], 1); print("run      ", pstate(21))
					else:
						Actions.computer_play(n)
					if n == 21: print("compplay ", pstate(21))
					if pl.tm_act <= Glob.TURN_ACT or pl.tm_act == Glob.SAVE_ACT:
						Actions.add_to_tussle_list(pl.tm_player)
					if not pl.tm_limbo and (not Glob.ball_limbo_on or Glob.ball_limbo_p != n):
						Actions.process_dir(pl)
					if n == 21: print("dir      ", pstate(21))
			Glob.player_num += 1
	print("tussles..."); Actions.player_tussles(); print("after tussles ", pstate(21))

func _init():
	MatchSetup.prepare({"team_a": 4, "team_b": 6, "time": 0, "users": []})
	Football.match_start()
	Glob.demo_match = 0
	for f in 2000:
		for k in 10:
			NetInput.nethandler()
		# --- replicate one logic cycle with checks (old_mf path, MF==1) ---
		Football._logic_cycle()
		NetInput.get_user_inputs(); NetInput.process_user_inputs()
		Glob.writeptr = (Glob.writeptr + 1) & 511
		User.convert_inputs()
		Glob.readptr = (Glob.readptr + 1) & 511
		if Glob.line_up:
			Glob.line_up -= 1
			Football.animate_players()
			if not Glob.line_up:
				Glob.match_mode = Glob.CENTRE_A
				Rules.init_match_mode()
		else:
			Display.init_pitch_sprites()
			Glob.frame = 0 if Glob.frame else 1
			Maths.af_randomize()
			Football.process_subs()
			var steps := [["process_ball", func(): Ball.process_ball()], ["match_rules", func(): Rules.match_rules()],
				["keeper_boxes", func(): Intell.keeper_boxes()], ["player_distances", func(): BallInt.player_distances()],
				["get_nearest", func(): BallInt.get_nearest()], ["get_opp_near_ball", func(): BallInt.get_opp_near_ball(Glob.ball_poss)],
				["process_speech", func(): Intell.process_speech()], ["process_comments", func(): Intell.process_comments()],
				["process_flags", func(): Football.process_flags()], ["process_teams", func(): Actions.process_teams()],
				["new_users", func(): User.new_users()], ["select_all_hlites", func(): Actions.select_all_hlites()],
				["process_offs", func(): Rules.process_offs()]]
			for s in steps:
				if s[0] == "process_teams" and f == 349:
					trace_teams()
				s[1].call()
				if chk("f%d %s" % [f, s[0]]):
					var p = Glob.teams[max(Glob.ball_poss, 1) - 1]
					print("  holder act %d int %d anim %d frm %f fstep %f pos(%f,%f) dis(%f,%f) contact %f" % [p.tm_act, p.int_move, p.tm_anim, p.tm_frm, p.tm_fstep, p.tm_x, p.tm_y, p.tm_xdis, p.tm_ydis, p.contact])
					quit()
					return
		Football.process_state()
		Upd3D.new_update_coords()
		Upd3D.process_replay()
		Football.watch_match_time()
	print("no NaN")
	quit()
