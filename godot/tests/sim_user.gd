extends SceneTree
# Headless match with a keyboard user on team A pressing random keys (arrows + fire).
func _init():
	var args := OS.get_cmdline_user_args()
	var frames := int(args[0]) if args.size() > 0 else 6000
	var seed_v := int(args[1]) if args.size() > 1 else 77
	MatchSetup.prepare({"team_a": 4, "team_b": 6, "time": 0, "rand": seed_v, "users": [{"team": 0, "control": 0}, {"team": 1, "control": 1}]})
	Football.match_start()
	print("users ", Glob.num_of_users, " types ", Glob.users[0].type, "/", Glob.users[1].type, " ctrl ", Glob.users[0].control, "/", Glob.users[1].control)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	# KEY1: arrows (extended) + keypad 0 / keypad . ; KEY2: A Z , . Q /
	var k1 := [[0x48, true], [0x50, true], [0x4b, true], [0x4d, true], [0x52, false], [0x53, false]]
	var k2 := [[0x1e, false], [0x2c, false], [0x33, false], [0x34, false], [0x10, false], [0x35, false]]
	var held := {}
	for f in frames:
		if f % 7 == 0:
			for set in [k1, k2]:
				var k = set[rng.randi_range(0, 5)]
				var key = str(k)
				if held.has(key):
					if k[1]: NetInput.key_handler(0xE0)
					NetInput.key_handler(k[0] | 0x80)
					held.erase(key)
				else:
					if k[1]: NetInput.key_handler(0xE0)
					NetInput.key_handler(k[0])
					held[key] = true
		for k in 10:
			NetInput.nethandler()
		if Eng3D.modal:
			Eng3D.modal = 0	# (no HUD here: dismiss in-game menus)
		if not Football.match_frame():
			print("ended at ", f)
			break
		if f >= 2600 and f < 2700 and f % 5 == 0:
			var k = Glob.teams[21]
			print("f%d act %d int %d/%d anim %d frm %.2f hands %d stopclk %d clockrun %d game_action %d must_punt %d steps %d inbox %d ud(%.2f,%.2f,m%d,f%d) uf %d/%d f1d %d f2d %d limbo %d" % [f, k.tm_act, k.int_move, k.int_cnt, k.tm_anim, k.tm_frm, Glob.ball_in_hands, Glob.stop_clock, Glob.clock_running, Glob.game_action, Glob.must_punt, Glob.keeper_steps, Glob.keeper_b_in_box, Glob.users_dir[1].x, Glob.users_dir[1].y, Glob.users_dir[1].m, Glob.users_dir[1].f, Glob.uf1, Glob.uf2, Glob.f1_down, Glob.f2_down, k.tm_limbo])
		if f % 1000 == 0:
			print("f %d min %d mode %d score %d-%d plr %d/%d poss %d" % [f, Glob.match_time.min, Glob.match_mode, Glob.team_a_goals, Glob.team_b_goals, Glob.users[0].plr, Glob.users[1].plr, Glob.ball_poss])
	print("done min %d score %d-%d" % [Glob.match_time.min, Glob.team_a_goals, Glob.team_b_goals])
	quit()
