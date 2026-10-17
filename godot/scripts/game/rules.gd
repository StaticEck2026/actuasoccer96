# Port of SOURCE/RULES.CPP  (assembled by tools/assemble.py - edit the files in parts/)
class_name Rules extends Glob
#******************************************************************************
#******************************************************************************
#
# Match rules and control routines...
#
#******************************************************************************
#******************************************************************************

# (#include "global.h" "defines.h" "externs.h" "data.h" "audio.h" "front.h" "eurofrnt\euro_int.h")
# extern match_data match_info;  extern team_info game_data[];  extern setup_info setup;
# int timeout;                     -> glob.gd (timeout)
# extern char old_tac_a,old_tac_b; -> glob.gd
# extern void load_new_tactics();  -> Football.load_new_tactics()

# do_*_menu() (3DENG.C on-screen overlay panels) -> Eng3D.do_*_menu(...)

# struct copy helper (C: memcpy(&a,&b,sizeof(match_player)) )
static func _copy_match_player(dst: match_player, src: match_player) -> void:
	for p in src.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			dst.set(p.name, src.get(p.name))

#******************************************************************************
#******************************************************************************

# void decide_set_kick()
static func decide_set_kick() -> void:
	support_me = FALSE
	var p: int

	match set_piece_on:
		SETP_CORNER:
			if ref_wait < 0:
				must_shoot = TRUE
			p = Intell.pass_decide(teams[setp_taker-1], TRUE)
			if p:
				Intell.make_pass(teams[setp_taker-1], p, TRUE)
			else:
				if Intell.shoot_decide(teams[setp_taker-1]):
					Intell.make_shoot(teams[setp_taker-1])
				else:
					support_me = TRUE		# No action (help).

		SETP_CENTRE:
			must_pass = TRUE
			p = centre_guy_2
			pass_type = 5
			if p:
				Intell.make_pass(teams[setp_taker-1], p, FALSE)
			else:
				support_me = TRUE		# No action (help).
			must_pass = FALSE

		SETP_IFKICK:
			if ref_wait < 0:
				must_punt = TRUE
			p = Intell.pass_decide(teams[setp_taker-1], FALSE)
			if p:
				Intell.make_pass(teams[setp_taker-1], p, FALSE)
			else:
				if Intell.punt_decide(teams[setp_taker-1]):
					Intell.make_punt(teams[setp_taker-1])
				else:
					support_me = TRUE		# No action (help).

		SETP_GKICK:
			if ref_wait < 0:
				must_punt = TRUE
			p = Intell.pass_decide(teams[setp_taker-1], FALSE)
			if p and p != KP_A and p != KP_B:
				Intell.make_pass(teams[setp_taker-1], p, FALSE)
			else:
				# C: (!seed&3) == ((!seed)&3)
				if bi(not seed) & 3:
					must_punt = TRUE
				if Intell.punt_decide(teams[setp_taker-1]):
					Intell.make_punt(teams[setp_taker-1])
				else:
					support_me = TRUE		# No action (help).

		SETP_DFKICK:
			if ref_wait < 0:
				must_shoot = TRUE
			p = Intell.pass_decide(teams[setp_taker-1], FALSE)
			if p:
				Intell.make_pass(teams[setp_taker-1], p, FALSE)
			else:
				if Intell.punt_decide(teams[setp_taker-1]):
					Intell.make_punt(teams[setp_taker-1])
				else:
					if Intell.shoot_decide(teams[setp_taker-1]):
						Intell.make_shoot(teams[setp_taker-1])
					else:
						support_me = TRUE		# No action (help).

		SETP_PENALTY:
			must_shoot = TRUE
			if Intell.shoot_decide(teams[setp_taker-1]):
				penalty_shot = TRUE
				Intell.make_shoot(teams[setp_taker-1])
			else:
				support_me = TRUE		# No action (help).

#******************************************************************************
#******************************************************************************

# char all_standing()
static func all_standing() -> int:
	var i: int = 0
	setp_wait_cnt = s16(setp_wait_cnt - 1)
	if setp_wait_cnt:
		i = 0
		while i < players:
			if (teams[i].guy_on > 0 and teams[i].tm_act != STAND_ACT and teams[i].tm_act != PICKUP_ACT
					and teams[i].dir_mode != 6 and (teams[i].tm_act != RUN_ACT or teams[i].tm_off != -2)):
				i = 100
			i += 1
	else:
		setp_wait_cnt = 1

	return (TRUE if (i <= players) else FALSE)

#******************************************************************************
#******************************************************************************

# void clear_wall()
static func clear_wall() -> void:
	for j in range(0, men_in_wall):
		teams[wguys[j].guy-1].tm_wall = 0
	men_in_wall = 0

#******************************************************************************
#******************************************************************************

# void ready_set_kick()
static func ready_set_kick() -> void:
	if set_piece_on:
		if men_in_wall and (match_mode == DF_KICK_A or match_mode == DF_KICK_B):
			clear_wall()

		arrow_on = FALSE
		match_mode = 0
		offside_now = FALSE
		dead_ball_cnt = 0
		game_action = 0
		teams[setp_taker-1].tm_leave = -TRUE	# Not allowed to touch ball after kick!
		user_taker = 0
# Referee normal mode...
		refs[0].act = 0
		set_piece_on = FALSE
		already_there = FALSE
		User.reselect()

#******************************************************************************
#******************************************************************************

# void go_set_kick(char type)
static func go_set_kick(type: int) -> void:
	var p: int
	if type:
		ready_set_kick()

		match type:
			PASS_FEET:
				must_pass = TRUE
				p = Intell.pass_decide(teams[setp_taker-1], FALSE)
				if p:
					Intell.make_pass(teams[setp_taker-1], p, FALSE)

			PASS_HEAD:
				must_pass = TRUE
				chip_pass = TRUE
				p = (Intell.pass_decide(teams[setp_taker-1], FALSE))
				if p:
					Intell.make_pass(teams[setp_taker-1], p, FALSE)

			PUNT:
				must_punt = TRUE
				if Intell.punt_decide(teams[setp_taker-1]):
					Intell.make_punt(teams[setp_taker-1])

			_:
				must_pass = TRUE

#******************************************************************************
#******************************************************************************

# void ready_ckick()
static func ready_ckick() -> void:
	arrow_on = FALSE
	match_mode = 0
	dead_ball_cnt = 0
	BallInt.collect_ball(teams[corner_taker-1])
	game_action = 0
	teams[corner_taker-1].tm_leave = -TRUE	# Not allowed to touch ball!
	user_taker = 0

#******************************************************************************
#******************************************************************************

# void go_ckick(char type)
static func go_ckick(type: int) -> void:
	if type:
		ready_ckick()
		match type:
			PASS_FEET:
				must_pass = TRUE

			PASS_HEAD:
				must_pass = TRUE

			PUNT:
				must_punt = TRUE

			_:
				must_pass = TRUE

#******************************************************************************
#******************************************************************************

# void await_set_kick()
static func await_set_kick() -> void:
	if not hold_up_play:
		if ((not player_on_off and (all_standing() and already_there)) or (support_me)):
			if not allow_replay:
				Upd3D.init_replay()

			if ball_poss != setp_taker:
				BallInt.collect_ball(teams[setp_taker-1])

			if refs[0].act == 4:
# Referee wait for kick mode...
				refs[0].act = 2
				ktaker = setp_taker
				ref_wait = (160-ref_strictness)*REAL_SPEED/8
				Audio.play_fx(PS_SHORTWHISTLE, refs[0].x, refs[0].y)
				clock_running = TRUE
				kickoff = FALSE

			if user_taker:
				if reselection:
					setp_kick_x = teams[setp_taker-1].tm_xdis
					setp_kick_y = teams[setp_taker-1].tm_ydis
					setp_power = 0
					setp_hgt = 0
					setp_byd = cntspot_y
					reselection = FALSE
					teams[setp_taker-1].dir_mode = 1
					teams[setp_taker-1].control = u8(user_taker)
					users[user_taker-1].plr = s8(setp_taker)

					if EURO96:
						if match_mode == PEN_KICK_A and user_taker2:
							teams[KP_B-1].control = u8(user_taker2)
							users[user_taker2-1].plr = KP_B
						if match_mode == PEN_KICK_B and user_taker2:
							teams[KP_A-1].control = u8(user_taker2)
							users[user_taker2-1].plr = KP_A

					User.reselect_all_users()
					arrow_on = TRUE
					arrow_guy = u8(setp_taker)
					if match_mode >= GOAL_KICK_TL and match_mode <= GOAL_KICK_BR:
						support_me = FALSE
					else:
						support_me = TRUE
			else:
				if refs[0].act == 2:
					if (not EURO96) or (match_mode != PEN_KICK_A and match_mode != PEN_KICK_B):
						decide_set_kick()
						if not support_me:
# Doesnt need support....
							ready_set_kick()
	else:
		hold_up_play -= 1

#*****************************************************************************
#*****************************************************************************

# void swap_users()
static func swap_users() -> void:

# Team A users now play Team B...

	var p: int
	for u in range(0, num_of_users):
		if users[u].type > 0:
# Fixed-player...
			if users[u].type > 11:
				users[u].type -= 11
			else:
				users[u].type += 11
		else:
# Auto-player...
			if users[u].type == -1:
				users[u].type = -2
			else:
				users[u].type = -1

		p = users[u].plr
		if p > 11:
			users[u].plr = s8(p-11)
		else:
			if p < 12 and p > 0:
				users[u].plr = s8(p+11)

	p = auto_users_a
	auto_users_a = auto_users_b
	auto_users_b = p

	# short t[10]; memcpy swap of auto_users_list_a / auto_users_list_b
	var t: Array = []
	t.resize(10)
	for k in range(0, 10):
		t[k] = auto_users_list_a[k]
	for k in range(0, 10):
		auto_users_list_a[k] = auto_users_list_b[k]
	for k in range(0, 10):
		auto_users_list_b[k] = t[k]

#*****************************************************************************
#*****************************************************************************

# void swap_teams()
static func swap_teams() -> void:
	match_half = u8(match_half + 1)

	var a: match_player = match_player.new()

	swap_users()

	for p in range(0, 11):
		_copy_match_player(a, teams[p])
		_copy_match_player(teams[p], teams[p+11])
		_copy_match_player(teams[p+11], a)

		teams[p].tm_player = p+1
		teams[p+11].tm_player = p+12

	var t: int = team_a
	team_a = team_b
	team_b = t

	var pp: int = players_off_a		# (C reuses 'short p' here)
	players_off_a = players_off_b
	players_off_b = pp

	old_tac_a = u8(-1)
	old_tac_b = u8(-1)
	Football.load_new_tactics()

#*****************************************************************************
#*****************************************************************************

# char in_tunnel()
static func in_tunnel() -> int:
	for p in range(0, players):
		if teams[p].draw_me:
			return FALSE
	return TRUE

#*****************************************************************************
#*****************************************************************************

# void await_swap()
static func await_swap() -> void:
	var go: bool = bool(in_tunnel())
	if not go:
		# !(timeout--)
		var old_timeout: int = timeout
		timeout -= 1
		go = not old_timeout
	if go:
		if match_half >= 11:
			end_game = TRUE
		else:
			swap_teams()

		camera = old_cam

		if last_centre:
# Team A had last kick off...(not including goal respots)
			last_centre = FALSE
			match_mode = CENTRE_B
			init_match_mode()
		else:
# Team B had last kick off...(not including goal respots)
			last_centre = TRUE
			match_mode = CENTRE_A
			init_match_mode()

#*****************************************************************************
#*****************************************************************************

# void remember_cam()
static func remember_cam() -> void:
	if camera != 15:
		old_cam = camera
# old_cam is already remembered if camera=15!

#*****************************************************************************
#*****************************************************************************

# void init_swap_ends()
static func init_swap_ends() -> void:
	allow_replay = FALSE
	remember_cam()
	timeout = 20*15
	clock_running = FALSE
	camera = 16
	Ball.reset_ball()
	dead_ball_cnt = 40
	for i in range(0, players):
		Actions.init_stand_act(teams[i])

#******************************************************************************
#******************************************************************************

# void await_throw()
static func await_throw() -> void:
	if already_there and not player_on_off:
		var x: float = teams[throw_in_taker-1].tm_x
		var y: float = teams[throw_in_taker-1].tm_y
		if Maths.calc_dist(incident_x-x, incident_y-y) < prat*3:
			if user_taker:
				if reselection:
					reselection = FALSE
					teams[throw_in_taker-1].dir_mode = 1
					teams[throw_in_taker-1].control = u8(user_taker)
					users[user_taker-1].plr = s8(throw_in_taker)
					User.reselect_all_users()
					arrow_on = TRUE
					arrow_guy = u8(throw_in_taker)

			if ball_in_hands:
				match_mode = 0
				ball_in_hands = TRUE
				Actions.init_throw_act(teams[throw_in_taker-1])
				BallInt.collect_ball(teams[throw_in_taker-1])
				teams[throw_in_taker-1].tm_leave = -TRUE	# Not allowed to touch ball!
			else:
				if teams[throw_in_taker-1].tm_act != PICKUP_ACT:
					Actions.init_pickup_act(teams[throw_in_taker-1])

#******************************************************************************
#******************************************************************************

# void ball_situation()
static func ball_situation() -> void:
	if match_mode:
		if match_mode == SWAP_ENDS:
# Half time or extra time.
			await_swap()
		else:
			if set_piece_on != SETP_THROW:
				await_set_kick()
			else:
				await_throw()

#******************************************************************************
#******************************************************************************

# void stop()
static func stop() -> void:
	alarm = FALSE
	mf_fixed = TRUE
	stop_min += 1000
	watch = TRUE

#******************************************************************************
#******************************************************************************

# void add_player_time()
static func add_player_time() -> void:
	for p in range(0, 22):
		teams[p].tm_time = u8(teams[p].tm_time + 1)

#******************************************************************************
#******************************************************************************

# void match_clock()
static func match_clock() -> void:
	if demo_match:
		rolling_clock -= 1

	if not match_mode and not penalty_game and not stop_clock and not just_scored:
		match_time.sec += 90.0/(time_factor*REAL_SPEED)
		if match_time.sec >= 60:
			match_time.sec -= 60
			match_time.min = u16(match_time.min + 1)
			add_player_time()

		if (alarm) and (match_time.min >= stop_min) and (match_time.sec >= stop_sec):
			stop()

#******************************************************************************
#******************************************************************************

# void kill_ball()
static func kill_ball() -> void:
	Intell.reset_all_ideas()
	BallInt.holder_lose_ball()
	Ball.stop_ball_spin()
	ballxdis = 0
	ballydis = 0
	ballzdis = 0
	ballx = incident_x
	bally = incident_y
	ballz = ball_diam/2
	dead_ball_cnt = 50

#******************************************************************************
#******************************************************************************

# void pen_to_team_a()
static func pen_to_team_a() -> void:
	away_pens_left -= 1
# Team A penalty...

	match_mode = PEN_KICK_A
	while true:
		pen_taker_a -= 1
		if not pen_taker_a:
			pen_taker_a = 10

		if teams[pen_taker_a].guy_on:
			break

# Guy hasn't been sent off!

	user_taker = User.user_taker_a(pen_taker_a+1)

	if EURO96:
		user_taker2 = User.user_keeper_b()

	penalty_taker = pen_taker_a+1

#******************************************************************************
#******************************************************************************

# void pen_to_team_b()
static func pen_to_team_b() -> void:
	home_pens_left -= 1
# Team B penalty...

	match_mode = PEN_KICK_B
	while true:
		pen_taker_b -= 1
		if pen_taker_b == 11:
			pen_taker_b = 21

		if teams[pen_taker_b].guy_on:
			break

# Guy hasn't been sent off!

	user_taker = User.user_taker_b(pen_taker_b+1)

	if EURO96:
		user_taker2 = User.user_keeper_a()

	penalty_taker = pen_taker_b+1

#******************************************************************************
#******************************************************************************

# void do_penalties()
static func do_penalties() -> void:
	if not match_mode:
# Normal play...
		if not penalty_counter:
# Next penalty...
			if penalties >= 10 and not (penalties & 1):
# If at least 5 penalties each and both taken same no...
				if team_a_goals != team_b_goals:
					penalty_game = FALSE
			else:
				if penalties < 10:
					if team_a_goals > team_b_goals:
# Home team winning...
						if away_pens_left < (team_a_goals-team_b_goals):
							penalty_game = FALSE
					else:
# Away team winning...
						if home_pens_left < (team_b_goals-team_a_goals):
							penalty_game = FALSE

			if penalty_game:
				penalties += 1
				penalty_counter = 5*REAL_SPEED
				kill_ball()
				game_action = 2		# gather outside box!
				if not penalty_team:
					penalty_team = TRUE		# Setup next for team!
					if match_half & 1:
						pen_to_team_b()
					else:
						pen_to_team_a()
				else:
					penalty_team = FALSE		# Setup next for team!
					if match_half & 1:
						pen_to_team_a()
					else:
						pen_to_team_b()
				init_match_mode()
		else:
			penalty_counter -= 1

#******************************************************************************
#******************************************************************************

# void match_rules()
static func match_rules() -> void:
	if penalty_game:
		if match_mode != PEN_KICK_A and match_mode != PEN_KICK_B and match_mode != SWAP_ENDS:
			match_mode = 0

		do_penalties()

	match_clock()
	if dead_ball_cnt:
		ball_situation()

#******************************************************************************
#******************************************************************************

# char bounds_rules()
static func bounds_rules() -> int:

	var xoff: float = 0
	var yoff: float = 0

#***********************

	if ballx < 0:
# Past Left Goal-line...
		xoff = -ballx

		if last_touch < 12:
# Corner!
			if not team_b_on:
				if bally > cntspot_y:
					return GOAL_KICK_BL
				else:
					return GOAL_KICK_TL
			else:
				if bally > cntspot_y:
					return CORNER_BL
				else:
					return CORNER_TL
		else:
# Goal Kick!
			if not team_a_on:
				if bally > cntspot_y:
					return CORNER_BL
				else:
					return CORNER_TL
			else:
				if bally > cntspot_y:
					return GOAL_KICK_BL
				else:
					return GOAL_KICK_TL

#***********************

	if ballx >= pitch_len:
# Past Right Goal-line...
		xoff = ballx-(pitch_len-1)

		if last_touch > 11:
# Corner!
			if not team_a_on:
				if bally > cntspot_y:
					return GOAL_KICK_BR
				else:
					return GOAL_KICK_TR
			else:
				if bally > cntspot_y:
					return CORNER_BR
				else:
					return CORNER_TR
		else:
# Goal Kick!
			if not team_b_on:
				if bally > cntspot_y:
					return CORNER_BR
				else:
					return CORNER_TR
			else:
				if bally > cntspot_y:
					return GOAL_KICK_BR
				else:
					return GOAL_KICK_TR

#***********************

	if bally < 0:
		yoff = -bally

	if bally >= pitch_wid:
		yoff = bally-(pitch_wid-1)

	if yoff > xoff:
# Over top side-line...

		incident_x = int(ballx)
		incident_y = (0 if (bally < 0) else pitch_wid-1)

		if last_touch < 12:

# Throw-in to team B!
			if not team_b_on:
				return THROW_IN_A
			else:
				return THROW_IN_B
		else:
			if not team_a_on:
				return THROW_IN_B
			else:
				return THROW_IN_A

	return 0

#******************************************************************************
#******************************************************************************
# INITIALISE MATCH SITUATIONS...
#******************************************************************************
#******************************************************************************

#******************************************************************************
#******************************************************************************

# void throw_taker(int p)
static func throw_taker(p: int) -> void:
# Decision is made on the closest tactical position at current ball_zone...

	var min_d: int = 1000
	var d: int

	for pn in range(p, p+10):
		if teams[pn-1].guy_on > 0:
			if pn < 12:
				d = int(Maths.calc_dist(ballx-match_tactics1[ball_zone1][pn-2][0],
							   bally-match_tactics1[ball_zone1][pn-2][1]))
			else:
				d = int(Maths.calc_dist((pitch_len-ballx)-match_tactics2[ball_zone2][pn-13][0],
							   (pitch_wid-bally)-match_tactics2[ball_zone2][pn-13][1]))

			if d < min_d:
				min_d = d
				throw_in_taker = pn

#******************************************************************************
#******************************************************************************

# int get_taker(int p)
static func get_taker(p: int) -> int:
# Decision is made on the closest tactical position at current ball_zone...

	var min_d: int = 1000
	var d: int
	var taker: int = 0		# (uninitialised in C)

	for pn in range(p, (12 if p < 12 else 23)):
		if teams[pn-1].guy_on > 0:
			if pn == KP_A:
				d = int(Maths.calc_dist(ballx-0, bally-cntspot_y))
			else:
				if pn == KP_B:
					d = int(Maths.calc_dist(pitch_len, bally-cntspot_y))
				else:
					if pn < 12:
						d = int(Maths.calc_dist(ballx-match_tactics1[ball_zone1][pn-2][0],
							   		bally-match_tactics1[ball_zone1][pn-2][1]))
					else:
						d = int(Maths.calc_dist((pitch_len-ballx)-match_tactics2[ball_zone2][pn-13][0],
							   		(pitch_wid-bally)-match_tactics2[ball_zone2][pn-13][1]))

			if d < min_d:
				min_d = d
				taker = pn
	return taker

#******************************************************************************
#******************************************************************************

# void centre_takers()
static func centre_takers() -> void:
	var p: int
	centre_guy_1 = 0
	centre_guy_2 = 0

	if match_mode == CENTRE_A:
		p = 2
		flag = TRUE
	else:
		p = 13
		flag = FALSE

	var d: int
	var min_d: int = 1000

# Decide on which two players shall take centre.

# Decision is made on the two closest tactical positions...

	for pn in range(p, p+10):
		if teams[pn-1].guy_on > 0:
			if flag:
				d = int(Maths.calc_dist(cntspot_x-match_tactics1[68][pn-2][0],
							   cntspot_y-match_tactics1[68][pn-2][1]))
			else:
				d = int(Maths.calc_dist(cntspot_x-match_tactics2[68][pn-13][0],
							   cntspot_y-match_tactics2[68][pn-13][1]))

			if d < min_d:
				min_d = d
				centre_guy_1 = pn

	min_d = 1000
	for pn in range(p, p+10):
		if teams[pn-1].guy_on > 0:
			if flag:
				d = int(Maths.calc_dist(cntspot_x-match_tactics1[68][pn-2][0],
							   cntspot_y-match_tactics1[68][pn-2][1]))
			else:
				d = int(Maths.calc_dist(cntspot_x-match_tactics2[68][pn-13][0],
							   cntspot_y-match_tactics2[68][pn-13][1]))

			if (d < min_d) and (centre_guy_1 != pn):
				min_d = d
				centre_guy_2 = pn

#******************************************************************************
#******************************************************************************

# void init_centre()
static func init_centre() -> void:
	if kickoff and next_mins:
		match_time.min = next_mins
		match_time.sec = 0
		match_mode = CENTRE_A
		last_goal = 0

	Ball.reset_ball()
	dead_ball_cnt = 40
	ballx = cntspot_x
	bally = cntspot_y
	ballz = ball_diam/2

	if match_mode == CENTRE_A:
# Team A centre.
		ball_zone1 = 68
		ball_zone2 = 69
		refs[0].goto_x = cntspot_x+5*prat
		centre_takers()
		Eng3D.do_kickoff_menu(team_a)
	else:
# Team B centre.
		ball_zone2 = 68
		ball_zone1 = 69
		refs[0].goto_x = cntspot_x-5*prat
		centre_takers()
		Eng3D.do_kickoff_menu(team_b)

	game_action = 1		# 10 Yards away!

# Referee go to spot behind incident...
	refs[0].act = 1
	refs[0].target = 0	# Ball!
	refs[0].goto_y = cntspot_y

	main_man = centre_guy_1

	user_taker = 0
#	if (centre_guy_1>11)
#		user_taker=user_taker_b(centre_guy_1);
#	else
#		user_taker=user_taker_a(centre_guy_1);

#******************************************************************************
#******************************************************************************

# void init_corner()
static func init_corner() -> void:
	Audio.PlayCommentaryMessage(SP_CORNER)

	comsetp = 40
	user_taker = 0
	dead_ball_cnt = 20
	match match_mode:
		CORNER_TL:
			ballx = prat-1
			bally = prat-1
			ballz = ball_diam/2
			ball_zone1 = 64
			ball_zone2 = 67
			last_touch = 12			# team b has possession.

			if (corn_kicker_b) and (teams[corn_kicker_b-1].guy_on > 0):
				corner_taker = corn_kicker_b
			else:
				corner_taker = get_taker(13)

			Eng3D.do_corner_menu(team_b)

		CORNER_BL:
			ballx = prat-1
			bally = pitch_wid-prat+1
			ballz = ball_diam/2
			ball_zone1 = 66
			ball_zone2 = 65
			last_touch = 12			# team b has possession.

			if (corn_kicker_b) and (teams[corn_kicker_b-1].guy_on > 0):
				corner_taker = corn_kicker_b
			else:
				corner_taker = get_taker(13)

			Eng3D.do_corner_menu(team_b)

		CORNER_TR:
			ballx = pitch_len-prat+1
			bally = prat-1
			ballz = ball_diam/2
			ball_zone1 = 65
			ball_zone2 = 66
			last_touch = 1			# team a has possession.

			if (corn_kicker_a) and (teams[corn_kicker_a-1].guy_on > 0):
				corner_taker = corn_kicker_a
			else:
				corner_taker = get_taker(2)

			Eng3D.do_corner_menu(team_a)

		CORNER_BR:
			ballx = pitch_len-prat+1
			bally = pitch_wid-prat+1
			ballz = ball_diam/2
			ball_zone1 = 67
			ball_zone2 = 64
			last_touch = 1			# team a has possession.

			if (corn_kicker_a) and (teams[corn_kicker_a-1].guy_on > 0):
				corner_taker = corn_kicker_a
			else:
				corner_taker = get_taker(2)

			Eng3D.do_corner_menu(team_a)

	incident_x = int(ballx+(-4 if (ballx < cntspot_x) else 4))
	incident_y = int(bally+(-8 if (bally < cntspot_y) else 8))
	game_action = 1		# 10 Yards away!

	if corner_taker > 11:
		user_taker = User.user_taker_b(corner_taker)
	else:
		user_taker = User.user_taker_a(corner_taker)

	main_man = corner_taker

# Referee go to spot between centre spot and ball...
	refs[0].act = 1
	refs[0].target = 0	# Ball!
	refs[0].goto_x = cntspot_x+((ballx-cntspot_x)/2)
	refs[0].goto_y = cntspot_y+((bally-cntspot_y)/2)
	last_touch = main_man
	pre_kp_touch = last_touch
	ball_in_hands = FALSE

#******************************************************************************
#******************************************************************************

# void init_gkick()
static func init_gkick() -> void:
	if fired_a_shot:
		if (ABS(bally_out-cntspot_y) > prat*7) or (ballz_out > prat*4):
# Miles away...
			Audio.PlayCommentaryMessage(PM_WIDE)
		else:
# Near miss..
			Audio.PlayCommentaryMessage(PM_CLOSE)
	else:
		Audio.PlayCommentaryMessage(SP_GOALKICK)

	dead_ball_cnt = 100
	match match_mode:
		GOAL_KICK_TL:
			ballx = (5.8*prat)
			bally = cntspot_y-(5.0*prat)
			ballz = ball_diam/2
			ball_zone1 = 11
			ball_zone2 = 20
			last_touch = 1			# team a has possession.

			if (goal_kicker_a) and (teams[goal_kicker_a-1].guy_on > 0):
				gkick_taker = goal_kicker_a
			else:
				gkick_taker = get_taker(1)

			Eng3D.do_goalkick_menu(team_a)

		GOAL_KICK_BL:
			ballx = (5.8*prat)
			bally = cntspot_y+(5.0*prat)
			ballz = ball_diam/2
			ball_zone1 = 19
			ball_zone2 = 12
			last_touch = 1			# team a has possession.

			if (goal_kicker_a) and (teams[goal_kicker_a-1].guy_on > 0):
				gkick_taker = goal_kicker_a
			else:
				gkick_taker = get_taker(1)

			Eng3D.do_goalkick_menu(team_a)

		GOAL_KICK_TR:
			ballx = pitch_len-(5.8*prat)
			bally = cntspot_y-(5.0*prat)
			ballz = ball_diam/2
			ball_zone1 = 12
			ball_zone2 = 19
			last_touch = 12			# team b has possession.

			if (goal_kicker_b) and (teams[goal_kicker_b-1].guy_on > 0):
				gkick_taker = goal_kicker_b
			else:
				gkick_taker = get_taker(12)

			Eng3D.do_goalkick_menu(team_b)

		GOAL_KICK_BR:
			ballx = pitch_len-(5.8*prat)
			bally = cntspot_y+(5.0*prat)
			ballz = ball_diam/2
			ball_zone1 = 20
			ball_zone2 = 11
			last_touch = 12			# team b has possession.

			if (goal_kicker_b) and (teams[goal_kicker_b-1].guy_on > 0):
				gkick_taker = goal_kicker_b
			else:
				gkick_taker = get_taker(12)

			Eng3D.do_goalkick_menu(team_b)

	incident_x = int(ballx)
	incident_y = int(bally)
	game_action = 1		# 10 Yards away!

	main_man = gkick_taker

# Referee go to spot between centre spot and ball...
	refs[0].act = 1
	refs[0].target = 0	# Ball!
	refs[0].goto_x = cntspot_x+((ballx-cntspot_x)/2)
	refs[0].goto_y = cntspot_y+((bally-cntspot_y)/2)
	last_touch = main_man
	pre_kp_touch = last_touch

	user_taker = 0

	if gkick_taker > 11:
		user_taker = User.user_taker_b(gkick_taker)
	else:
		user_taker = User.user_taker_a(gkick_taker)

	var ang: float = (64.0-seed)*(PI/(8*64))

	if match_mode < GOAL_KICK_TR:
# Goal_kick to team A...
		taker_x = int(ballx-(cos(ang)*4))
		taker_y = int(bally+(sin(ang)*4))
	else:
# Goal_kick to team B...
		taker_x = int(ballx+(cos(ang)*4))
		taker_y = int(bally+(sin(ang)*4))

#******************************************************************************
#******************************************************************************

# void init_throw()
static func init_throw() -> void:
	stop_clock = TRUE
	user_taker = 0
	dead_ball_cnt = 100
	if match_mode == THROW_IN_A:
		Eng3D.do_throw_menu(team_a)
		last_touch = 1		# Team A have possession...
		throw_taker(2)
		if ballx_out > (pitch_len-(prat*20)):
			Audio.PlayCommentaryMessage(SP_LONGTHROWIN)
		else:
			Audio.PlayCommentaryMessage(SP_THROWIN)

	if match_mode == THROW_IN_B:
		Eng3D.do_throw_menu(team_b)
		last_touch = 12		# Team B have possession...
		throw_taker(13)
		if ballx_out < (prat*20):
			Audio.PlayCommentaryMessage(SP_LONGTHROWIN)
		else:
			Audio.PlayCommentaryMessage(SP_THROWIN)

	teams[throw_in_taker-1].int_move = I_THROW

	ballx = incident_x
	bally = incident_y

	ballz = ball_diam/2
	game_action = 1		# 10 Yards away!

	if throw_in_taker > 11:
		user_taker = User.user_taker_b(throw_in_taker)
	else:
		user_taker = User.user_taker_a(throw_in_taker)

# Linesman go to spot behind incident...
	if bally > cntspot_y:
# Bottom linesman....
		refs[2].act = 1
		refs[2].goto_y = refs[2].y
		if refs[2].x > ballx+prat*4:
			refs[2].goto_x = ballx+prat*4
		else:
			if refs[2].x < ballx-prat*4:
				refs[2].goto_x = ballx-prat*4
			else:
				refs[2].act = 0
	else:
# Top linesman....
		refs[1].act = 1
		refs[1].goto_y = refs[1].y
		if refs[1].x > ballx+prat*4:
			refs[1].goto_x = ballx+prat*4
		else:
			if refs[1].x < ballx-prat*4:
				refs[1].goto_x = ballx-prat*4
			else:
				refs[1].act = 0
	main_man = throw_in_taker

#******************************************************************************
#******************************************************************************

# char penalty(int fouler)
static func penalty(fouler: int) -> int:
	if ballx < cntspot_x:
# Team A box...
		if (fouler < 12) and (ballx < prat*18) and (bally < cntspot_y+(prat*22)) and (bally > cntspot_y-(prat*22)):
			return TRUE
	else:
# Team B box...
		if (fouler > 11) and (ballx > pitch_len-(prat*18)) and (bally < cntspot_y+(prat*22)) and (bally > cntspot_y-(prat*22)):
			return TRUE
	return FALSE

#******************************************************************************
#******************************************************************************

# void init_offside(match_player *player)
static func init_offside(player: match_player) -> void:
	var d: float
	var x: float

	if player.tm_player > 11:
# Top linesman...
		x = defense_a-player.tm_x		# How much offside.
		d = (pitch_wid-Maths.calc_dist(player.tm_x-refs[1].x, player.tm_y-refs[1].y))/prat
	else:
# Bot linesman...
		x = player.tm_x-defense_b		# How much offside.
		d = (pitch_wid-Maths.calc_dist(player.tm_x-refs[2].x, player.tm_y-refs[2].y))/prat

	d = ref_accuracy/2+(ref_accuracy*((d*d*0.000740740)-(0.07*d)+1))
	if d < 1:
		d = 1

	if seed < d/2+x:

# The linesman sees the Offside...
		player.tm_off = TRUE
	else:
		var rel: int = (128-ref_accuracy)/4
		player.tm_off = -TRUE
		if ball_released < 0:
			ball_released += rel
			if ball_released > 0:
				ball_released = 0
		else:
			ball_released -= rel
			if ball_released < 0:
				ball_released = 0

#******************************************************************************
#******************************************************************************

# void big_yeller(int plr)
static func big_yeller(plr: int) -> void:
	card_is_out = 3*REAL_SPEED
	var t: int
	booking = TRUE

	if plr < 12:
		t = team_a
	else:
		t = team_b

	Audio.PlayCommentaryMessage(FU_YELLOWCARD)
	Eng3D.do_booked_menu(t, teams[plr-1].shirt-1)
	inc_yellow(plr)

#******************************************************************************
#******************************************************************************

# void ger_em_off(int plr)
static func ger_em_off(plr: int) -> void:
# Off
	inc_red(plr)
	card_is_out = 6*REAL_SPEED
	booking = TRUE
	if plr < 12:
		players_off_a += 1
	else:
		players_off_b += 1

	player_on_off = plr
	sub_camera = camera
	camera = 17
	Intell.reset_ideas(teams[plr-1])
	Intell.init_off_int(teams[plr-1])
	Audio.PlayCommentaryMessage(FU_REDCARD)

	var t: int
	var p: int

	if plr < 12:
		t = team_a
		var pi_a: player_info = game_data[setup.team_a if team_a == 0 else setup.team_b].players[plr-1]
		pi_a.flags = u8(pi_a.flags | 2)
	else:
		t = team_b
		var pi_b: player_info = game_data[setup.team_a if team_b == 0 else setup.team_b].players[plr-12]
		pi_b.flags = u8(pi_b.flags | 2)

	Eng3D.do_off_menu(t, teams[plr-1].shirt-1)

#	teams[plr-1].guy_on=-1;			// Waiting to be sent off!

	if corn_kicker_a == plr:
		corn_kicker_a = 0

	if corn_kicker_b == plr:
		corn_kicker_b = 0

	if goal_kicker_a == plr:
		if plr < 12:
			goal_kicker_a = KP_A
		else:
			goal_kicker_a = KP_B

	# NOTE: original bug kept - sets goal_kicker_a (not goal_kicker_b).
	if goal_kicker_b == plr:
		if plr < 12:
			goal_kicker_a = KP_A
		else:
			goal_kicker_a = KP_B

	if fkick_taker_a == plr:
		fkick_taker_a = 0

	if fkick_taker_b == plr:
		fkick_taker_b = 0

#******************************************************************************
#******************************************************************************

# void send_off_plr(int plr,float nasty)
static func send_off_plr(plr: int, nasty: float) -> void:
	if plr != KP_A and plr != KP_B and EUROmatch_info.bookings:
		if teams[plr-1].tm_book:
# He's had a yellow card...
			if nasty > seed:
				if (plr < 12 and players_off_a < 5) or (plr > 11 and players_off_b < 5):
					ger_em_off(plr)
		else:
			if nasty > seed*4:
				if (plr < 12 and players_off_a < 5) or (plr > 11 and players_off_b < 5):
					ger_em_off(plr)
			else:
				if nasty > seed:
					big_yeller(plr)

#******************************************************************************
#******************************************************************************

# void punish_foul(int fouler,char direct)
static func punish_foul(fouler: int, direct: int) -> void:
	user_taker = 0
	in_range = FALSE
	Intell.reset_all_ideas()
	BallInt.holder_lose_ball()
	Ball.stop_ball_spin()
	ballxdis = 0
	ballydis = 0
	ballzdis = 0
	ballx = incident_x
	bally = incident_y
	ballz = ball_diam/2
	dead_ball_cnt = 50
	last_touch = fouler

	var nastiness: float

	booking = 0
	nastiness = sqrt(teams[last_touch-1].tm_dist*4)*ref_strictness/6			# distance to ball. (how late was the challenge?)
	if not man_down:
		nastiness /= 3

# Shall we send him off?
	if direct:
		send_off_plr(last_touch, nastiness)

	if direct and (penalty(fouler)):
		inc_pfoul(fouler)

		if (seed & 2) and not player_on_off:
			Audio.PlayCommentaryMessage(FU_DIVE)

		Intell.init_speech(players+1, SAY_PENALTY, FALSE)
		game_action = 2		# gather outside box!
		if fouler > 11:
# Team A P.K.
			match_mode = PEN_KICK_A
			if (penalty_taker_a) and (teams[penalty_taker_a-1].guy_on > 0):
				penalty_taker = penalty_taker_a
			else:
				penalty_taker = get_taker(2)

			if not booking:
				Eng3D.do_penalty_menu(team_a)

			user_taker = User.user_taker_a(penalty_taker)
			if EURO96:
				user_taker2 = User.user_keeper_b()
		else:
# Team B P.K.
			match_mode = PEN_KICK_B
			if (penalty_taker_b) and (teams[penalty_taker_b-1].guy_on > 0):
				penalty_taker = penalty_taker_b
			else:
				penalty_taker = get_taker(13)

			if not booking:
				Eng3D.do_penalty_menu(team_b)

			user_taker = User.user_taker_b(penalty_taker)
			if EURO96:
				user_taker2 = User.user_keeper_a()
	else:
		game_action = 1		# 10 Yards away!
		if fouler > 11:
# Team A F.K.
			if not direct:
# Not on the ball..(INDIRECT)
				inc_ifoul(fouler)
				Intell.init_speech(players+1, SAY_OFFSIDE, FALSE)
				match_mode = IF_KICK_A
				fkick_taker = get_taker(2)
				if not booking:
					if offside_now:
						Eng3D.do_offside_menu(team_a)
					else:
						Eng3D.do_indirect_menu(team_a)
			else:
# On the ball..(DIRECT)
				if not player_on_off:
					if seed & 64:
						Audio.PlayCommentaryMessage(FU_BADFOUL)
					else:
						Audio.PlayCommentaryMessage(FU_FREEKICK)

				inc_dfoul(fouler)
				Intell.init_speech(players+1, SAY_FOUL, FALSE)
				match_mode = DF_KICK_A
				if (fkick_taker_a) and (teams[fkick_taker_a-1].guy_on > 0):
					fkick_taker = fkick_taker_a
				else:
					fkick_taker = get_taker(2)
			user_taker = User.user_taker_a(fkick_taker)
		else:
# Team B F.K.
			if not direct:
# Not on the ball..(INDIRECT)
				inc_ifoul(fouler)
				Intell.init_speech(players+1, SAY_OFFSIDE, FALSE)
				match_mode = IF_KICK_B
				fkick_taker = get_taker(13)
				if not booking:
					if offside_now:
						Eng3D.do_offside_menu(team_b)
					else:
						Eng3D.do_indirect_menu(team_a)	# (sic: team_a in the original)
			else:
# On the ball..(DIRECT)
				if not player_on_off:
					if seed & 64:
						Audio.PlayCommentaryMessage(FU_BADFOUL)
					else:
						Audio.PlayCommentaryMessage(FU_FREEKICK)

				inc_dfoul(fouler)
				Intell.init_speech(players+1, SAY_FOUL, FALSE)
				match_mode = DF_KICK_B
				if (fkick_taker_b) and (teams[fkick_taker_b-1].guy_on > 0):
					fkick_taker = fkick_taker_b
				else:
					fkick_taker = get_taker(13)
			user_taker = User.user_taker_b(fkick_taker)
	init_match_mode()

#******************************************************************************
#******************************************************************************

# void retake_foul()
static func retake_foul() -> void:
	punish_foul(bad_guy, direct_fk)
	play_advantage = FALSE

#******************************************************************************
#******************************************************************************

# void init_foul(int fouler,char direct,char see)
static func init_foul(fouler: int, direct: int, see: int) -> void:
	play_advantage = FALSE
	Maths.af_randomize()
	var x: float
	var y: float
	var d: float
	d = Maths.calc_dist(ballx-refs[0].x, bally-refs[0].y)/prat
	d = (ref_accuracy/d)*2*man_down

	if d > 128:
		d = 128

	if not just_scored and EUROmatch_info.freekicks and ((seed < d) or (see)):
		incident_x = int(teams[fouler-1].tm_x)
		incident_y = int(teams[fouler-1].tm_y)

		direct_fk = direct
		bad_guy = fouler

# The referee sees the foul...
		if offside_now:
# Cannot play advantage with offside rule...
			punish_foul(fouler, direct_fk)
		else:
			Maths.af_randomize()

# May play advantage...
			if fouler < 12:
# Team A commited foul...
				if (not ball_poss) and (seed > ref_strictness):
# Ball is free...play temporary advantage...
					play_advantage = TRUE
					Intell.init_speech(players+1, SAY_ADV, FALSE)
				else:
					if ball_poss < 12:
						punish_foul(fouler, direct_fk)
			else:
# Team B commited foul...
				if (not ball_poss) and (seed > ref_strictness):
# Ball is free...play temporary advantage...
					play_advantage = TRUE
					Intell.init_speech(players+1, SAY_ADV, FALSE)
				else:
					if ball_poss > 11 or not ball_poss:
						punish_foul(fouler, direct_fk)
	else:
		if (seed & 2) and not just_scored:
			Audio.PlayCommentaryMessage(FU_DIVE)


#******************************************************************************
#******************************************************************************

# extern int pen_cnt;   (glob.gd)

# void force_penalty()
static func force_penalty() -> void:
	pen_cnt = 100
	BallInt.holder_lose_ball()
	ball_poss = 12
	ballx = pitch_len-2
	bally = cntspot_y
	ballz = ball_diam/2
	init_foul(13, TRUE, TRUE)

#******************************************************************************
#******************************************************************************

# void init_fkick()
static func init_fkick() -> void:
	var x: float
	var y: float
	var d: float

	if last_touch < 12:
		x = -ballx
	else:
		x = pitch_len-ballx

	y = cntspot_y-bally
	d = Maths.calc_dist(x, y)
	taker_x = int(ballx-(x*BESIDE_BALL/d))
	taker_y = int(bally-(y*BESIDE_BALL/d))

# Referee go to spot behind incident...
	refs[0].act = 1
	refs[0].target = 0	# Ball!
	var rx: float = refs[0].x-ballx
	var ry: float = refs[0].y-bally
	var rd: float = Maths.calc_dist(rx, ry)
	refs[0].goto_x = ballx+(rx*BESIDE_BALL*16/rd)
	refs[0].goto_y = bally+(ry*BESIDE_BALL*16/rd)
	main_man = fkick_taker
	last_touch = fkick_taker
	pre_kp_touch = last_touch

#******************************************************************************
#******************************************************************************

# void find_wall_guys(int guys,float x,float y)
static func find_wall_guys(guys: int, x: float, y: float) -> void:
	var d: int
	var pn: int = 0		# (uninitialised in C)
	var min_d: int
	var wall_cnt: int
	var dist: float = prat*0.9
	var xd: float = x*dist
	var yd: float = y*dist
	var cx: float = wallx-xd
	var cy: float = wally-yd

	wall_cnt = 0

	for j in range(0, men_in_wall):
		min_d = 2000
		for i in range(guys, guys+10):
			if (not teams[i-1].tm_wall) and (teams[i-1].guy_on > 0):
				if i < 12:
					d = int(Maths.calc_dist(ballx-match_tactics1[ball_zone1][i-2][0],
								   bally-match_tactics1[ball_zone1][i-2][1]))
				else:
					d = int(Maths.calc_dist((pitch_len-ballx)-match_tactics2[ball_zone2][i-13][0],
								   (pitch_wid-bally)-match_tactics2[ball_zone2][i-13][1]))

				if d < min_d:
					min_d = d
					pn = i
		if min_d != 2000:
# found an idiot...
			teams[pn-1].tm_wall = TRUE
			wguys[j].guy = pn
			wguys[j].x = cx
			wguys[j].y = cy
			cx = cx+xd
			cy = cy+yd
			wall_cnt += 1
	men_in_wall = wall_cnt

# Get keeper position...
	var gx: float
	var gy: float
	# NOTE: with wall_cnt<2 the original reads before wguys[] (wguys[-1]/[-2]);
	# GDScript negative indices wrap to the end of the array instead.
	x = wguys[wall_cnt-2].x-incident_x		# 2nd last man in wall!
	y = wguys[wall_cnt-2].y-incident_y
	if guys > 11:
# Team B's goal...
		gx = pitch_len-prat
	else:
# Team A's goal...
		gx = 0+prat

	gx = gx-incident_x
	gy = y*gx/x

	keeper_pos_x = gx+incident_x
	keeper_pos_y = gy+incident_y

#*****************************************************************************
#*****************************************************************************

# void inc_pfoul(short p)
static func inc_pfoul(p: int) -> void:
	teams[p-1].tm_fouls = u8(teams[p-1].tm_fouls + 10)		# add giving penalty to foul list.

#*****************************************************************************
#*****************************************************************************

# void inc_dfoul(short p)
static func inc_dfoul(p: int) -> void:
	teams[p-1].tm_fouls = u8(teams[p-1].tm_fouls + 3)		# add direct F.K. to foul list.

#*****************************************************************************
#*****************************************************************************

# void inc_ifoul(short p)
static func inc_ifoul(p: int) -> void:
	teams[p-1].tm_fouls = u8(teams[p-1].tm_fouls + 1)		# add indirect F.K. to foul list.

#*****************************************************************************
#*****************************************************************************

# void inc_pass(short p)
static func inc_pass(p: int) -> void:
	teams[p-1].tm_pass = s16(teams[p-1].tm_pass + 1)		# Passes attempted.

#*****************************************************************************
#*****************************************************************************

# void inc_work(short p)
static func inc_work(p: int) -> void:
	teams[p-1].tm_work += 1		# Passes attempted.

#******************************************************************************
#******************************************************************************

# void inc_pwon(short p)
static func inc_pwon(p: int) -> void:
	teams[p-1].tm_pwon = s16(teams[p-1].tm_pwon + 1)		# Passes won.

#******************************************************************************
#******************************************************************************

# void inc_tack(short p)
static func inc_tack(p: int) -> void:
	teams[p-1].tm_tacks = s16(teams[p-1].tm_tacks + 1)		# Tackles attempted.

#******************************************************************************
#******************************************************************************

# void inc_twon(short p)
static func inc_twon(p: int) -> void:
	teams[p-1].tm_twon = s16(teams[p-1].tm_twon + 1)		# Tackles won.

#******************************************************************************
#******************************************************************************

# void inc_poss(short p)
static func inc_poss(p: int) -> void:
	teams[p-1].tm_posst = s16(teams[p-1].tm_posst + 1)		# Possession time.

#******************************************************************************
#******************************************************************************

# void inc_inj(short p,short i)
static func inc_inj(p: int, i: int) -> void:
	teams[p-1].tm_inj = u16(teams[p-1].tm_inj + i)		# Injury.

#******************************************************************************
#******************************************************************************

# void inc_yellow(short p)
static func inc_yellow(p: int) -> void:
	teams[p-1].tm_book = u8(teams[p-1].tm_book + 1)		# Yellow card.

#******************************************************************************
#******************************************************************************

# void inc_red(short p)
static func inc_red(p: int) -> void:
	teams[p-1].tm_book = u8(teams[p-1].tm_book + 5)		# Red card.

#******************************************************************************
#******************************************************************************

# void inc_shot(short p)
static func inc_shot(p: int) -> void:
	teams[p-1].tm_shots = s16(teams[p-1].tm_shots + 1)		# Shots attempted.

#******************************************************************************
#******************************************************************************

# void inc_goal(short p)
static func inc_goal(p: int) -> void:
	teams[p-1].tm_goals = u8(teams[p-1].tm_goals + 1)		# Goals scored.

#******************************************************************************
#******************************************************************************

# void inc_ogs(short p)
static func inc_ogs(p: int) -> void:
	teams[p-1].tm_ogs = u8(teams[p-1].tm_ogs + 1)		# Own goals scored.

#******************************************************************************
#******************************************************************************

# void inc_save(short p)
static func inc_save(p: int) -> void:
	teams[p-1].tm_saved = s16(teams[p-1].tm_saved + 1)		# shots saved.

#******************************************************************************
#******************************************************************************

# void inc_saves(short p)
static func inc_saves(p: int) -> void:
	teams[p-1].tm_kpsaves = s16(teams[p-1].tm_kpsaves + 1)		# Saved shot.

#******************************************************************************
#******************************************************************************

# void add_comp_pass(short plr)
static func add_comp_pass(plr: int) -> void:
	if last_touch and ((last_touch < 12 and plr < 12)
			or (last_touch > 11 and plr > 11)):
		inc_pwon(last_touch)

#******************************************************************************
#******************************************************************************

# void init_dfkick()
static func init_dfkick() -> void:
	comsetp = 40

	var taker: int
	var d: float
	var x: float
	var y: float
	var range_v: float		# C: range

	if not booking:
		if last_touch < 12:
			Eng3D.do_direct_menu(team_b)
		else:
			Eng3D.do_direct_menu(team_a)

	if last_touch < 12:
# F.K. to Team B...

		last_touch = 12		# Team B have possession...
		x = -ballx
		y = cntspot_y-bally
		d = Maths.calc_dist(x, y)
		taker_x = int(ballx-(x*BESIDE_BALL/d))
		taker_y = int(bally-(y*BESIDE_BALL/d))

# Referee go to spot behind incident...
		refs[0].act = 1
		refs[0].target = 0	# Ball!
		var rx: float = refs[0].x-ballx
		var ry: float = refs[0].y-bally
		var rd: float = Maths.calc_dist(rx, ry)
		refs[0].goto_x = ballx+(rx*BESIDE_BALL*16/rd)
		refs[0].goto_y = bally+(ry*BESIDE_BALL*16/rd)

		range_v = Maths.calc_dist(x, y)
		if range_v > (MIN_SHOOT_DIST+(float(teams[fkick_taker-1].tm_pow)*3)):
# Out of shooting range!
			men_in_wall = 0		# No wall!
			taker = -1
		else:
# In shooting range!
			in_range = TRUE
			if incident_y < cntspot_y:
# Near post is top!
				y = top_post_y-incident_y
				range_v = Maths.calc_dist(incident_x, y)
			else:
# Near post is bottom!
				y = bot_post_y-incident_y
				range_v = Maths.calc_dist(incident_x, y)

			y = y/range_v											# horiz. vector to goal!
			x = -incident_x/range_v

			men_in_wall = int(5.5-(ABS(y)*3))					# Team A make wall.
			taker = fkick_taker
			wallx = incident_x+(prat*10*x)
			wally = incident_y+(prat*10*y)					# Wall coords...
			if incident_y < cntspot_y:
				x = -x
			else:
				y = -y
			find_wall_guys(2, y, x)			# x,y reversed for right angle!
			if not player_on_off:
				Audio.PlayCommentaryMessage(FU_WALL)
	else:
# F.K. to Team A...

		last_touch = 1		# Team A have possession...
		x = pitch_len-ballx
		y = cntspot_y-bally
		d = Maths.calc_dist(x, y)
		taker_x = int(incident_x-(x*BESIDE_BALL/d))
		taker_y = int(incident_y-(y*BESIDE_BALL/d))

# Referee go to spot behind incident...
		refs[0].act = 1
		refs[0].target = 0	# Ball!
		var rx: float = refs[0].x-ballx
		var ry: float = refs[0].y-bally
		var rd: float = Maths.calc_dist(rx, ry)
		refs[0].goto_x = ballx+(rx*BESIDE_BALL*16/rd)
		refs[0].goto_y = bally+(ry*BESIDE_BALL*16/rd)

		range_v = Maths.calc_dist(x, y)
		if range_v > (MIN_SHOOT_DIST+(float(teams[fkick_taker-1].tm_pow)*3)):
# Out of shooting range!
			men_in_wall = 0		# No wall!
			taker = 0				# Anybody can take F.K.
		else:
# In shooting range!
			in_range = TRUE
			if incident_y < cntspot_y:
# Near post is top!
				y = top_post_y-incident_y
				range_v = Maths.calc_dist(pitch_len-incident_x, y)
			else:
# Near post is bottom!
				y = bot_post_y-incident_y
				range_v = Maths.calc_dist(pitch_len-incident_x, y)

			y = y/range_v				  						# horiz. vector to goal!
			x = (pitch_len-incident_x)/range_v

			men_in_wall = int(5.5-(ABS(y)*3))				# Team B make wall.
			taker = fkick_taker
			wallx = incident_x+(prat*10*x)
			wally = incident_y+(prat*10*y)				# Wall coords...
			if incident_y < cntspot_y:
				y = -y
			else:
				x = -x
			find_wall_guys(13, y, x)			# x,y reversed for right angle!
			if not player_on_off:
				Audio.PlayCommentaryMessage(FU_WALL)

	if taker < 1:
# Not close enough to take shot so nearest can take!
		var min_d: int = 1000
		var di: int		# C: int d (shadows float d)
		var p: int = (13 if taker < 0 else 2)

		for pn in range(p, p+10):
			if teams[pn-1].guy_on > 0:
				if pn < 12:
					di = int(Maths.calc_dist(ballx-match_tactics1[ball_zone1][pn-2][0],
						   		bally-match_tactics1[ball_zone1][pn-2][1]))
				else:
					di = int(Maths.calc_dist((pitch_len-ballx)-match_tactics2[ball_zone2][pn-13][0],
						   		(pitch_wid-bally)-match_tactics2[ball_zone2][pn-13][1]))

				if di < min_d:
					min_d = di
					fkick_taker = pn

	main_man = fkick_taker
	last_touch = fkick_taker
	pre_kp_touch = last_touch

#******************************************************************************
#******************************************************************************

# void init_penalty()
static func init_penalty() -> void:
	if not penalty_game:
		Audio.PlayCommentaryMessage(SP_PENALTY)

	var x: float
	var y: float
	var range_v: float

	if match_mode == PEN_KICK_A:
		ballx = pitch_len-(prat*12)
		if EURO96:
			taker_x = int(ballx-PEN_RUNUP_DIST)
		else:
			taker_x = int(ballx-8)
	else:
		ballx = (prat*12)
		if EURO96:
			taker_x = int(ballx+PEN_RUNUP_DIST)
		else:
			taker_x = int(ballx+8)

	taker_y = cntspot_y
	bally = cntspot_y
	incident_x = int(ballx)
	incident_y = int(bally)

# Referee go to spot above penalty spot...
	refs[0].act = 1
	refs[0].target = 0	# Ball!
	refs[0].goto_x = ballx
	refs[0].goto_y = cntspot_y-(prat*10)

	if (not penalty_taker) or (not teams[penalty_taker-1].guy_on):
# No particular player chosen nearest can take!
		var min_d: int = 1000
		var d: int
		var p: int = (13 if match_mode == PEN_KICK_B else 2)

		for pn in range(p, p+10):
			if pn < 12:
				d = int(Maths.calc_dist(ballx-match_tactics1[ball_zone1][pn-2][0],
						   	bally-match_tactics1[ball_zone1][pn-2][1]))
			else:
				d = int(Maths.calc_dist((pitch_len-ballx)-match_tactics2[ball_zone2][pn-13][0],
						   	(pitch_wid-bally)-match_tactics2[ball_zone2][pn-13][1]))

			if d < min_d:
				min_d = d
				penalty_taker = pn

	main_man = penalty_taker
#	if (main_man<12)
#	{
#// Team A penalty...
#		user_keeper_b();
#	}
#	else
#	{
#// Team B penalty...
#		user_keeper_a();
#	}

#******************************************************************************
#******************************************************************************

# void init_match_mode()
static func init_match_mode() -> void:
	ref_wait = (160-ref_strictness)*REAL_SPEED/8
	support_me = FALSE
	spec_kick_type = 0
	already_there = FALSE		# Taker is not in position.
	reselection = FALSE		# When do I reselect auto users.
	User.clear_all_autos()		# Clear all auto selected players.

	if match_mode:
		play_advantage = FALSE
		setp_wait_cnt = MAX_SETP_WAIT
		if ball_limbo_on:
			ball_limbo_on = FALSE
			teams[ball_limbo_p-1].tm_limbo = FALSE
		teams[KP_A-1].tm_limbo = 0
		teams[KP_B-1].tm_limbo = 0


		Intell.reset_all_ideas()
		BallInt.holder_lose_ball()
		if teams[KP_A-1].tm_act == KPHOLD_ACT:
			Actions.init_stand_act(teams[KP_A-1])

		if teams[KP_B-1].tm_act == KPHOLD_ACT:
			Actions.init_stand_act(teams[KP_B-1])

	# switch(match_mode) with fall-through cases -> if/elif chain
	var sw: int = match_mode
	if sw == 0:
# Normal Play.
		pass

	elif sw == CORNER_TL or sw == CORNER_BL or sw == CORNER_TR or sw == CORNER_BR:
# Corner.
		set_piece_on = SETP_CORNER
		can_be_offside = FALSE
		Audio.play_fx(PS_SHORTWHISTLE, refs[0].x, refs[0].y)
		init_corner()

	elif sw == CENTRE_A or sw == CENTRE_B:
# Centre.
		if sw == CENTRE_A:
			if not team_a_on:
				match_mode = CENTRE_B
		# (fall through)
		if not team_b_on:
			match_mode = CENTRE_A
		set_piece_on = SETP_CENTRE
		can_be_offside = TRUE
		Audio.play_fx(PS_SHORTWHISTLE, refs[0].x, refs[0].y)
		init_centre()

	elif sw == GOAL_KICK_TL or sw == GOAL_KICK_BL or sw == GOAL_KICK_TR or sw == GOAL_KICK_BR:
# Goal kick.
		set_piece_on = SETP_GKICK
		can_be_offside = FALSE
		Audio.play_fx(PS_SHORTWHISTLE, refs[0].x, refs[0].y)
		init_gkick()

	elif sw == THROW_IN_A or sw == THROW_IN_B:
# Throw in.
		set_piece_on = SETP_THROW
		can_be_offside = FALSE
		Audio.play_fx(PS_SHORTWHISTLE, refs[0].x, refs[0].y)
		init_throw()

	elif sw == IF_KICK_A or sw == IF_KICK_B:
# Indirect free kick.
		if sw == IF_KICK_A:
			if not team_a_on:
				match_mode = IF_KICK_B
		# (fall through)
		if not team_b_on:
			match_mode = IF_KICK_A
		can_be_offside = TRUE
		Audio.play_fx(PS_LONGWHISTLE, refs[0].x, refs[0].y)
		set_piece_on = SETP_IFKICK
		init_fkick()

	elif sw == DF_KICK_A or sw == DF_KICK_B:
# Direct free kick.
		if sw == DF_KICK_A:
			if not team_a_on:
				match_mode = DF_KICK_B
		# (fall through)
		if not team_b_on:
			match_mode = DF_KICK_A
		can_be_offside = TRUE
		Audio.play_fx(PS_LONGWHISTLE, refs[0].x, refs[0].y)
		set_piece_on = SETP_DFKICK
		init_dfkick()

	elif sw == PEN_KICK_A or sw == PEN_KICK_B:
# Penalty kick.
		if sw == PEN_KICK_A:
			if not team_a_on:
				match_mode = PEN_KICK_B
		# (fall through)
		if not team_b_on:
			match_mode = PEN_KICK_A
		can_be_offside = FALSE
		Audio.play_fx(PS_LONGWHISTLE, refs[0].x, refs[0].y)
		set_piece_on = SETP_PENALTY
		init_penalty()

	elif sw == SWAP_ENDS:
		init_swap_ends()

	setp_taker = main_man

#******************************************************************************
#******************************************************************************

# char offc_thinking()
static func offc_thinking() -> int:
	var f: int = ((129-ref_accuracy)/4)+1
	var t: int = logic_cnt/f
	var r: int = logic_cnt-(t*f)
	return bi(not r)

#******************************************************************************
#******************************************************************************

# void init_ref_stand(officials *lman)
static func init_ref_stand(lman: officials) -> void:
	if ABS(lman.anim) != MC_STAND:
		lman.anim = MC_STAND
		lman.newanim = TRUE
		lman.frm = 0
		lman.fstep = MC_STAND_FS

#******************************************************************************
#******************************************************************************

# void init_ref_run(officials *lman)
static func init_ref_run(lman: officials) -> void:
	if ABS(lman.anim) == MC_JOG:
# Tween to run from jog....
		lman.anim = MC_RUN
		lman.fstep = MC_RUN_FS
	else:
		if ABS(lman.anim) != MC_RUN:
			lman.anim = MC_RUN
			lman.newanim = TRUE
			lman.frm = 0
			lman.fstep = MC_RUN_FS

#******************************************************************************
#******************************************************************************

# void init_ref_jog(officials *lman)
static func init_ref_jog(lman: officials) -> void:
	if ABS(lman.anim) == MC_RUN:
# Tween to jog from run....
		lman.anim = MC_JOG
		lman.fstep = MC_JOG_FS
	else:
		if ABS(lman.anim) != MC_JOG:
			lman.anim = MC_JOG
			lman.newanim = TRUE
			lman.frm = 0
			lman.fstep = MC_JOG_FS

#******************************************************************************
#******************************************************************************

# void init_rtrot_anim(officials *lman)
static func init_rtrot_anim(lman: officials) -> void:
	var x: float = lman.goto_x-lman.x
	var y: float = lman.goto_y-lman.y

	var d: float = Maths.calc_dist(x, y)

	lman.fstep = MC_TROTA_FS

	x = x/d
	y = y/d

	var nx: float = (x*lman.dir_x)+(y*lman.dir_y)
	var ny: float = (y*lman.dir_x)-(x*lman.dir_y)

	if lman.anim < MC_TROTB or lman.anim > MC_TROTE:
# Not currently in trot animation...
		lman.frm = 0
		lman.newanim = TRUE

	var dir: int = 1+Intell.get_dir(nx, ny)
	match dir:
		8:
			lman.anim = MC_TROTF

		7:
			lman.anim = MC_TROTG

		6:
			lman.anim = MC_TROTH

		5:
			lman.anim = MC_TROTA

		4:
			lman.anim = MC_TROTB

		3:
			lman.anim = MC_TROTC

		2:
			lman.anim = MC_TROTD

		1:
			lman.anim = MC_TROTE

#******************************************************************************
#******************************************************************************

# void init_refs_anim(officials *lman,int an)
static func init_refs_anim(lman: officials, an: int) -> void:
	match an:
		MC_STAND:
			init_ref_stand(lman)

		MC_RUN:
			init_ref_run(lman)

		MC_JOG:
			init_ref_jog(lman)

		MC_TROTA:
			init_rtrot_anim(lman)

#******************************************************************************
#******************************************************************************

# void lman_follow(officials *lman)
static func lman_follow(lman: officials) -> void:
	if match_mode:
		init_refs_anim(lman, MC_STAND)
		lman.go = 12+(129-ref_accuracy)/4
	else:
		var x: float
		if lman.go > 0:
			lman.go -= 1
		else:
			if lman.y < cntspot_y:
# Top Linesman...
				lman.dir_x = 0
				lman.dir_y = 1

				if ballx > cntspot_x:
					x = ((ballx-defense_a)/1.25)*(pitch_wid-bally)/pitch_wid
				else:
					x = 0

				if defense_a+x-2 > lman.x:
					lman.goto_x = lman.x+2
					if lman.anim != MC_TROTG:
						init_refs_anim(lman, MC_TROTA)
					lman.x = lman.goto_x
				else:
					if defense_a+x+2 < lman.x:
						lman.goto_x = lman.x-2
						if lman.anim != MC_TROTC:
							init_refs_anim(lman, MC_TROTA)
						lman.x = lman.goto_x
					else:
						init_refs_anim(lman, MC_STAND)
						lman.go = 12+(129-ref_accuracy)/4
			else:
# Bot. Linesman...
				lman.dir_x = 0
				lman.dir_y = -1

				if ballx < cntspot_x:
					x = ((defense_b-ballx)/1.25)*bally/pitch_wid
				else:
					x = 0

				if defense_b+x-2 > lman.x:
					lman.goto_x = lman.x+2
					if lman.anim != MC_TROTC:
						init_refs_anim(lman, MC_TROTA)
					lman.x = lman.goto_x
				else:
					if defense_b+x+2 < lman.x:
						lman.goto_x = lman.x-2
						if lman.anim != MC_TROTG:
							init_refs_anim(lman, MC_TROTA)
						lman.x = lman.goto_x
					else:
						init_refs_anim(lman, MC_STAND)
						lman.go = 12+(129-ref_accuracy)/4

#******************************************************************************
#******************************************************************************

# void await_kicker(officials *offc)
static func await_kicker(offc: officials) -> void:
	init_refs_anim(refs[0], MC_STAND)

	if (not match_mode) and (teams[ktaker-1].tm_act != THROW_ACT):
		offc.act = 0
	else:
		ref_wait -= 1
		if not ref_wait and match_mode != PEN_KICK_A and match_mode != PEN_KICK_B:
# Time-up!!!
			var cond: bool
			if STOP_TIME_WASTING:
				cond = not practice
			else:
				cond = not practice and teams[ktaker-1].tm_act != THROW_ACT
			if cond:
				ref_wait = -1
# Cannot be in practice mode...
				if teams[ktaker-1].tm_act == THROW_ACT:
# Give away a throw...
					if ktaker > 11:
# Team A gets Throw In...
						match_mode = THROW_IN_A
						init_match_mode()
						Actions.init_stand_act(teams[ktaker-1])
						BallInt.holder_lose_ball()
					else:
# Team B gets Throw In...
						match_mode = THROW_IN_B
						init_match_mode()
						Actions.init_stand_act(teams[ktaker-1])
						BallInt.holder_lose_ball()
#				else
#				{
#					if ((match_mode>=CORNER_TL) && (match_mode<=CORNER_BR))
#					{
#// Give opposing team a Goal Kick...
#						match_mode+=6;
#						init_match_mode();
#						init_stand_act(&teams[setp_taker-1]);
#						holder_lose_ball();
#					}
#					else
#					{
#// Opposing Team recieves Indirect Free Kick...
#						init_foul(ktaker,FALSE,TRUE);
#						init_stand_act(&teams[setp_taker-1]);
#						holder_lose_ball();
#					}
#				}
#				init_speech(players+1,SAY_TIMEW);

#******************************************************************************
#******************************************************************************

# void goto_target(officials *offc)
static func goto_target(offc: officials) -> void:
	var tx: float
	var ty: float
	var x: float
	var y: float
	var d: float
	var bd: float
	var nx: float
	var ny: float
	var ox: float
	var oy: float
	var dif: float
	var spd: float

	tx = offc.goto_x-offc.x
	ty = offc.goto_y-offc.y

	d = Maths.calc_dist(tx, ty)
	tx = tx/d
	ty = ty/d

	offc.dir_x = tx
	offc.dir_y = ty

	if d > 2.6:
# Not there yet...
		init_refs_anim(offc, MC_JOG)
		spd = 2.6
	else:
		init_refs_anim(offc, MC_STAND)
		offc.act = 3	# Face target!
		spd = 0

	offc.x += tx*spd
	offc.y += ty*spd

#******************************************************************************
#******************************************************************************

# void at_target(officials *referee)
static func at_target(referee: officials) -> void:
# Turns player to face object (ball or player!)

	var nx: float
	var ny: float
	var x: float
	var y: float
	var bd: float
	var xd: float
	var yd: float
	var dif: float
	var max: float = (PI/12)

	if not referee.target:
# Face ball!
		x = ballx-referee.x
		y = bally-referee.y
	else:
# Face Player!
		x = teams[referee.target-1].tm_x-referee.x
		# NOTE: original bug kept - uses tm_x for the y component.
		y = teams[referee.target-1].tm_x-referee.y

	bd = Maths.calc_dist(x, y)

	x = x/bd
	y = y/bd

	xd = referee.dir_x
	yd = referee.dir_y

	dif = ((x*xd)+(y*yd))

	if dif < cos(max):
		if (x*yd) > (y*xd):
			max = -max

		nx = (xd*cos(max))-(yd*sin(max))
		ny = (yd*cos(max))+(xd*sin(max))
	else:
		nx = x
		ny = y
		referee.act = 4		# Action complete!

	bd = Maths.calc_dist(nx, ny)
	nx = nx/bd
	ny = ny/bd

	referee.dir_x = nx
	referee.dir_y = ny

#******************************************************************************
#******************************************************************************

# void follow_play(officials *referee)
static func follow_play(referee: officials) -> void:
	var tx: float
	var ty: float
	var x: float
	var y: float
	var d: float
	var bd: float
	var nx: float
	var ny: float
	var ox: float
	var oy: float
	var dif: float
	var spd: float
	if not match_mode:
		x = ballx-referee.x
		y = bally-referee.y

		bd = Maths.calc_dist(x, y)

# Face Ball...
		if bd > 0.2:
			referee.dir_x = x/bd
			referee.dir_y = y/bd

		tx = cntspot_x+((ballx-cntspot_x)*0.5)+((prat*10) if (last_touch < 12) else (prat*-10))
		ty = cntspot_y+((bally-cntspot_y)*0.5)

		tx = tx-referee.x
		ty = ty-referee.y

		d = Maths.calc_dist(tx, ty)

		if d > prat*2:

# Keep distance from ball..
			if (bd > 0.2) and (bd < prat*10) and (not dead_ball_cnt):
				tx -= x*50/bd
				ty -= y*50/bd
				d = Maths.calc_dist(tx, ty)

			if d > prat*2:
				referee.goto_x = referee.x+tx
				referee.goto_y = referee.y+ty

				tx = tx/d
				ty = ty/d

# Get angle of movement Vs facing...
				dif = ((referee.dir_x*tx)+(referee.dir_y*ty))
				if dif > 1.0:
					dif = 1

				if dif < -1.0:
					dif = -1

				init_refs_anim(refs[0], MC_TROTA)
				spd = 2.2

				referee.x += tx*spd
				referee.y += ty*spd

			else:
				init_refs_anim(refs[0], MC_STAND)
		else:
			init_refs_anim(refs[0], MC_STAND)

#******************************************************************************
#******************************************************************************

# void process_ref(officials *offc)
static func process_ref(offc: officials) -> void:
	if match_mode == SWAP_ENDS:
		init_refs_anim(refs[0], MC_STAND)
	else:

		match offc.act:
			0:				# Follow Play...
				follow_play(offc)

			1:				# Goto target..
				goto_target(offc)

			2:				# Wait for someone to kick ball..
				await_kicker(offc)

			3:				# Stand and turn...
				at_target(offc)

			4:				# Facing target now...
				at_target(offc)

#******************************************************************************
#******************************************************************************

# void process_lman(officials *offc)
static func process_lman(offc: officials) -> void:
	match offc.act:
		0:				# Follow Play...
			lman_follow(offc)

		1:				# Follow Play...
			goto_target(offc)

#******************************************************************************
#******************************************************************************

# void anim_officials(officials *offc)
static func anim_officials(offc: officials) -> void:
	offc.frm += offc.fstep

#******************************************************************************
#******************************************************************************

# void process_offs()
static func process_offs() -> void:
	process_ref(refs[0])
	process_lman(refs[1])
	process_lman(refs[2])
	anim_officials(refs[0])
	anim_officials(refs[1])
	anim_officials(refs[2])

