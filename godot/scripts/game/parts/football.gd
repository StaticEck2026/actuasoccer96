#******************************************************************************
#******************************************************************************
#
# Actua Soccer.    1.9.94
#
#	Programmed by Andy Findlay.
#
#******************************************************************************
#******************************************************************************
#
# Godot port notes:
#  * match() is split into match_start() (everything before the main loop),
#    match_frame() (one pass of the "while (in_game && !net_quit)" loop) and
#    match_end() (everything after the loop). The Godot driver (scripts/main.gd)
#    calls match_frame() once per rendered frame after advancing the 200Hz timer
#    `count` the way the DOS timer interrupt (NETWORK.C nethandler) did.
#  * Blocking loops (pause, "Quit Game Y or N") cannot block in Godot; they are
#    kept as state the driver polls (see process_keys()).
#  * Network state saving/check-summing (EURO96 process_state) is not ported
#    except for the logic counter it advances.

const COUNTRIES := 44

# int pen_cnt=100;  (FOOTBALL.CPP file scope - already in Glob: pen_cnt)
# int coo=0; char gkey=0; int otick;   (already in Glob)

#******************************************************************************
#******************************************************************************

# void checksum()
static func checksum() -> void:
	# NETWORK: XOR checksum of the net-synchronised variables between var_start
	# and var_end (used to detect network desynchronisation). Not ported.
	Upd3D.add_message("0", WHITE, TRUE)

#******************************************************************************
#******************************************************************************

# void make_mtable(int t1,int t2)
static func make_mtable(t1: int, t2: int) -> void:
	var d: float
	var min_d: float
	var x: float
	var y: float
	var gx: float
	var p: int

	for j in range(t2, t2 + 10):
		teams[j - 1].tm_mark = FALSE

	if t2 < 12:
		# Team A goals...
		gx = 0
	else:
		# Team B goals...
		gx = pitch_len

	var a: int = t1
	while a > t1 - 10:
		# Can't mark guy on ball...
		if (a != main_man) and (teams[a - 1].guy_on > 0):
			x = teams[a - 1].tm_x
			y = teams[a - 1].tm_y
			p = 0

			if Maths.calc_dist(gx - x, cntspot_y - y) < MUST_MARK_DIST:
				# Close enough to be a threat!!!
				min_d = 5000
				for i in range(t2, t2 + 10):
					if (teams[i - 1].guy_on > 0) and (not teams[i - 1].tm_wall) and (not teams[i - 1].tm_mark):
						if i < 12:
							d = Maths.calc_dist(x - match_tactics1[ball_zone1][i - 2][0],
									y - match_tactics1[ball_zone1][i - 2][1])
						else:
							d = Maths.calc_dist((pitch_len - x) - match_tactics2[ball_zone2][i - 13][0],
									(pitch_wid - y) - match_tactics2[ball_zone2][i - 13][1])
						if d < min_d:
							min_d = d
							p = i

			if p:
				d = Maths.calc_dist(gx - x, cntspot_y - y)

				# How tightly they mark depends on discipline...
				x += (prat * (gx - x) * ((192 - teams[p - 1].tm_disc) / 64) / d)
				y += (prat * (cntspot_y - y) * ((192 - teams[p - 1].tm_disc) / 64) / d)

				teams[p - 1].tm_mark = a

				if p > 11:
					p -= 11
				man2man[p - 2][0] = int(x)
				man2man[p - 2][1] = int(y)
		a -= 1

#******************************************************************************
#******************************************************************************

# void player_stamina()
static func player_stamina() -> void:
	var ir: int
	var p: int
	if match_time.min != old_min:
		old_min = match_time.min

		for i in range(22):
			if not match_info.GameType:
				var rank: int
				if (i < 11 and not (match_half & 1)) or (i > 10 and (match_half & 1)):
					rank = game_data[setup.team_a].ranking
				else:
					rank = game_data[setup.team_b].ranking

				ir = s16(int(50 + (1.4 * (COUNTRIES - rank - 1))))		# 50 - 110
			else:
				if (i < 11 and not (match_half & 1)) or (i > 10 and (match_half & 1)):
					# Team A...
					if not (match_half & 1):
						p = i
					else:
						p = i - 11
					ir = game_data[setup.team_a].players[p].pace + 28
				else:
					# Team B...
					if match_half & 1:
						p = i
					else:
						p = i - 11
					ir = game_data[setup.team_b].players[p].pace + 28

			var st: int = teams[i].tm_stam
			var f: float = (sin((PI * teams[i].tm_time / 120) - (PI / 2)) + 1) / 2
			var t: float = f * (129 - st) / 140 * ir
			teams[i].tm_rate = u8(int(ir - t))
#			if ((i==1 && !(match_half&1)) || (i==12 && (match_half&1)))
#				deb_x=teams[i].tm_rate;
#			else
#				if (i==1 || i==12)
#					deb_y=teams[i].tm_rate;

#******************************************************************************
#******************************************************************************

# Process Various control flags on each logic cycle...

# void process_flags()
static func process_flags() -> void:
	if EURO96:
		player_stamina()

	# Text message counter...
	if message_cnt:
		new_text -= 1
		if not new_text:
			message_cnt -= 1
			if message_cnt:
				new_text = MESSAGE_TIME
				current_mess += 1
				if current_mess == MAX_MESSAGES:
					current_mess = 0

	# Used for offside rule...
	if ball_released:
		if ball_released > 0:
			ball_released -= 1
		else:
			ball_released += 1

	if play_advantage:
		# Referee has seen an indiscretion but is waiting to see who collects ball...
		if ball_poss:
			# Some-one has collected ball!!!
			if (ball_poss < 12 and bad_guy > 11) or (ball_poss > 11 and bad_guy < 12):
				# Favoured team has it!
				play_advantage = FALSE
			else:
				# Fouling team has it! (no advantage gained!)
				Rules.retake_foul()

	if just_thrown:
		if last_touch == throw_in_taker:
			just_thrown -= 1
		else:
			just_thrown = FALSE

	match match_mode:
		IF_KICK_B, DF_KICK_B, CORNER_TL, CORNER_BL:
			man2man_a = TRUE
			man2man_b = FALSE

		IF_KICK_A, DF_KICK_A, CORNER_TR, CORNER_BR:
			man2man_b = TRUE
			man2man_a = FALSE

		_:
			man2man_a = FALSE
			man2man_b = FALSE

	if man2man_b:
		# Team B marking table...
		make_mtable(11, 13)
	else:
		if man2man_a:
			# Team A marking table...
			make_mtable(22, 2)

#******************************************************************************
#******************************************************************************

# void init_line_up()
static func init_line_up() -> void:
	line_up = LINE_UP_DELAY + 40

#******************************************************************************
#******************************************************************************

# short convert_control(char c)
static func convert_control(c: int) -> int:
	match c:
		0:
			return KEY1_CTRL
		1:
			return KEY2_CTRL
		2:
			return JOY1_CTRL
		3:
			return JOY2_CTRL
		4:
			return MOUSE_CTRL
		5:
			return LOGPAD_CTRL
	return 0

#******************************************************************************
#******************************************************************************

# short conv_conts_back(char c)
static func conv_conts_back(c: int) -> int:
	match c:
		JOY1_CTRL:
			return 2
		JOY2_CTRL:
			return 3
		KEY1_CTRL:
			return 0
		KEY2_CTRL:
			return 1
		MOUSE_CTRL:
			return 4
		LOGPAD_CTRL:
			return 5
	return 0

#******************************************************************************
#******************************************************************************

# void init_rand()
static func init_rand() -> void:
	# Get it from front-end...
	c_srand(EUROmatch_info.rand)

#******************************************************************************
#******************************************************************************

# void get_performance()
static func get_performance() -> void:
	var p: int
	var max_p1: int
	var max_p2: int
	var min_p1: int
	var min_p2: int
	var min_p: int
	var sp: int
	var spa: int = 0
	var spb: int = 0

	var clock_v: float = 45.0 / time_factor

	for i in range(22):
		p = 0
		if teams[i].tm_time >= 15:
			if not i or i == (KP_B - 1):
				# Keeper performance...
				p = s16(int(p + PER_KPSAVES * clock_v * teams[i].tm_kpsaves))
				p = s16(int(p + PER_GOALSIN * clock_v * (team_a_goals if i < 11 else team_b_goals)))

			p = s16(int(p + PER_BOOKINGS * clock_v * teams[i].tm_book))
			p = s16(int(p + PER_FOULS * clock_v * teams[i].tm_fouls))
			p = s16(int(p + PER_GOALS * clock_v * teams[i].tm_goals))
			p = s16(int(p + PER_OGS * clock_v * teams[i].tm_ogs))
			p = s16(int(p + PER_POSS * clock_v * teams[i].tm_posst))
			p = s16(int(p + PER_WORK * clock_v * teams[i].tm_work))

			if teams[i].tm_tacks:
				p = s16(int(p + PER_TACKS * teams[i].tm_twon / (teams[i].tm_tacks + 10 / clock_v)))

			if teams[i].tm_shots:
				p = s16(int(p + PER_SHOTS * teams[i].tm_saved / (teams[i].tm_shots + 10 / clock_v)))

			if teams[i].tm_pass:
				p = s16(int(p + PER_PASSES * teams[i].tm_pwon / (teams[i].tm_pass + 10 / clock_v)))
		else:
			# Not been on field long enough...
			p = -2000

		performance[i] = p

	max_p1 = -1000
	max_p2 = -1000
	min_p1 = 1000
	min_p2 = 1000

	for i in range(22):
		p = performance[i]
		if i > 10:
			if p > max_p1:
				max_p1 = p
				spa = i + 1

			if p < min_p1:
				min_p1 = p

		if i < 11:
			if p > max_p2:
				max_p2 = p
				spb = i + 1

			if p < min_p2:
				min_p2 = p

	if max_p1 > max_p2:
		sp = max_p1
		man_of_match = spa
	else:
		sp = max_p2
		man_of_match = spb

	if min_p1 < min_p2:
		min_p = min_p1
	else:
		min_p = min_p2

	sp -= min_p

	# Performance is a percentage of star players...
	for i in range(22):
		p = performance[i]
		if sp:
			performance[i] = s16(int(100.0 * (p - min_p) / sp))
		else:
			# (C: float division by zero -> INF/NaN converted to short; all players equal)
			performance[i] = 0

#******************************************************************************
#******************************************************************************

# Initialise zero vars...

# void initialise_vars()
static func initialise_vars() -> void:
	var i: int

	for k in range(5):
		burst_timer[k] = 0

	for k in range(22):
		sel_circle[k] = 0

	if EURO96:
		# NETWORK: state_checksum=0; state_ptr=&state1; checksum_ptr=(short *)state_ptr;
		state_checksum = 0
	escape_pending = 0
	man_of_match = 0
	xinfo = 0
	message_cnt = 0
	current_mess = 0
	new_text = 0
	not_ahead = FALSE
	kick_off = TRUE
	forced = 0
	keep_timer = 0
	player_on_off = FALSE
	player_being_subbed = FALSE
	Eng3D.sub_pending = FALSE
	booking = FALSE

	stop_clock = FALSE
	card_is_out = 0
	anykey = FALSE
	demo_match = FALSE
	rolling_clock = 0

	keep_dive = FALSE
	hold_up_play = 0
	cross_on = FALSE
	wall_is_up = FALSE

	comsetp = 0

	init_rand()

	# Timing Vars...

	updates = 0
	old_count = 0

	crowd_mood_a = 0
	crowd_mood_b = 0

	possession = 0
	poss_held = 0

	for k in range(11):
		strike[k].t = 0
		strike[k].free = 0
		strike[k].ptype = 0
		strike[k].pplr = 0
		strike[k].gt = 0
		strike[k].x = 0
		strike[k].y = 0
		strike[k].atime = 0
		strike[k].stop = 0

	first_time_it = FALSE
	auto_select = FALSE

	seconds = 0

	arrow_on = 0

	logic_cnt = 0

	ball_move = FALSE

	first_bounce = 0
	swerve = 0
	spin_cnt = 0
	spin_ball = 0
	prediction = FALSE
	set_xyspin = 0
	set_zspin = 0

	ball_horz_ang = 0
	ball_vert_ang = 0
	max_sw_factor = 0
	swerve_factor = 0
	rebound_ball = 0
	headed_ball = 0
	say_names = TRUE
	fired_a_shot = 0
	comm_pass = 0
	comm_pass_type = 0

	keeper_spd = 0
	keeper_down = FALSE
	save_direction = FALSE
	keeper_will_save = FALSE
	keeper_on_grnd = FALSE
	keeper_contact = 0
	ball_in_goal = FALSE
	ball_in_hands = FALSE
	game_action = FALSE
	throw_cnt = 0
	team_a_goals = 0
	team_b_goals = 0
	last_goal = 0
	scorer_running = FALSE
	just_scored = 0
	just_thrown = 0
	goal_scorer = 0
	pass_type = 0
	kick_type = 0
	receiver = 0
	cross_now = 0
	must_face = FALSE
	must_face_time = 0
	must_face_x = 0
	must_face_y = 0
	must_shoot = FALSE
	chip_pass = FALSE
	must_pass = FALSE
	must_punt = FALSE

	keeper_a_in_box = 0
	keeper_b_in_box = 0
	keeper_steps = 0
	save_block = 0
	save_xoff = 0
	save_yoff = 0
	save_zoff = 0
	shot_speed = 0
	scr_x = 0
	scr_y = 0
	ball_speed = 0
	ball_int_speed = 0
	interceptor_a = 0
	interceptor_b = 0
	in_cross_area = 0
	close_in_number = 0
	shooter = 0
	ball_inair = 1
	super_shot = 0
	opponents_near_holder = 0
	opponents_really_close = 0
	# (sic) "int ball_poss=0;" in the original declares a LOCAL variable, so the
	# global ball_poss is NOT reset here.
	var _local_ball_poss: int = 0
	sender_1_2 = 0
	ball_still = 0
	last_touch = 0
	want_pass = 0
	before = 0
	support_me = 0
	pre_kp_touch = 0
	prev_touch = 0

	ball_limbo_p = 0
	ball_limbo_on = FALSE
	ball_limbo_c = 0

	ball_released = 0
	cannot_pick_up = 0
	last_user_a = 0
	last_user_b = 0
	last_plr_a = 0
	last_plr_b = 0
	players_off_a = 0
	players_off_b = 0

	want_pass_stat = 0
	ball_zone1 = 0
	ball_zone2 = 0
	ball_out_of_play = 0

	receiver_a = 0
	receiver_b = 0

	ready_centre = 0
	shot_attempt = 0

	force_select = 0
	heading_ball = 0
	flag = 0

	rep_camera = 0
	sub_camera = 0
	allow_replay = 0

	replay_pos = 0
	old_rep_pos = 0
	replay_cnt = 0

	pitch_sprs = 0

	fixed_net_user = 0

	for k in range(10):
		auto_users_list_a[k] = 0
		auto_users_list_b[k] = 0
	auto_users_a = 0
	auto_users_b = 0

	play_ball_a = 0
	play_ball_b = 0

	new_select = 0
	auto_intercept = 0
	closest = 0

	f1_down = 0
	f2_down = 0

	spec_kick_type = 0
	setp_hgt = 0
	setp_power = 0
	setp_kick_x = 0
	setp_kick_y = 0
	setp_bxd = 0
	setp_byd = 0
	setp_bzd = 0

	user_taker = 0
	user_controlled = 0
	user_plr = 0
	after_touch_on = FALSE
	drive_shot = 0

	wallx = 0
	wally = 0
	men_in_wall = 0

	for k in range(5):
		wguys[k].guy = 0
		wguys[k].x = 0
		wguys[k].y = 0

	keeper_pos_x = 0
	keeper_pos_y = 0

	centre_guy_1 = 0
	centre_guy_2 = 0

	in_range = 0
	in_header_rng = 0
	in_shot_rng = 0
	taker_x = 0
	taker_y = 0

	bad_guy = 0
	direct_fk = FALSE

	play_advantage = 0

	set_piece_on = 0

	shot_acknowledged = FALSE
	shot_pending = FALSE
	real_shot = FALSE
	shot_missed = 0
	shot_saved = 0

	for k in range(10):
		opp_dir_tab[k][0] = 0
		opp_dir_tab[k][1] = 0
		opp_dir_tab[k][2] = 0

	offside_now = 0

	for k in range(tussle_tab.size()):
		tussle_tab[k] = 0

	ball_travel = 0
	select_cnt = 10
	in_game = 1
	analogue = 1

	ballxdis = 12.0
	ballydis = 2.0
	ballzdis = 10.0
	ballx = cntspot_x
	bally = cntspot_y
	ballz = ball_diam / 2
	prev_ballx = 0.0 * 16
	prev_bally = 30.0 * 16
	prev_ballz = ball_diam / 2
	ns_ballx = 0.0
	ns_bally = 0.0
	ns_ballz = ball_diam / 2
	ball_zspin = 0
	ball_xyspin = 0
	full_zspin = 0
	full_xyspin = 0
	shoot_x = 0
	shoot_y = 0

	nearest_a = 0
	nearest_b = 0
	old_ltouch = -1
	old_ball_poss = -1
	use_ball_limit = 0
	near_path_a = 0
	near_path_b = 0
	zone1_x = 0
	zone2_x = 0
	zone1_y = 0
	zone2_y = 0
	incident_x = 0
	incident_y = 0
	difficulty = 0
	match_mode = 0
	dead_ball_cnt = 0
	defense_a = 0
	defense_b = 0
	poss_mode = 0

	for k in range(50):
		ball_pred_tab[k][0] = ballx
		ball_pred_tab[k][1] = bally
		ball_pred_tab[k][2] = ballz
		ns_ball_pred_tab[k][0] = ballx
		ns_ball_pred_tab[k][1] = bally
		ns_ball_pred_tab[k][2] = ballz

	delay_cnt = 40
	play_nums_on = 0
	frame = FALSE
	frames = 0
	frms_per_sec = 0
	last_second = 0

	old_clock = 0

#******************************************************************************
#******************************************************************************

# void init_user_controls()
static func init_user_controls() -> void:
	if FRONT_END:
		num_of_users = 0

	var home_plrs: int = EUROmatch_info.TeamA_users
	var away_plrs: int = EUROmatch_info.TeamB_users

#	short home_plrs=game_data[setup.team_a].player_control;
#	short away_plrs=game_data[setup.team_b].player_control;

	var plrs: int = 0
	var c: int

	var pnum: int = 0

	var i: int = 1
	while i < 16:
		pnum += 1
		if home_plrs & i:
			# User...
			plrs += 1
			c = convert_control(EUROmatch_info.CntrlTypes[pnum - 1])
			User.add_team_user(-1, c)

		if away_plrs & i:
			# User...
			plrs += 1
			c = convert_control(EUROmatch_info.CntrlTypes[pnum - 1])
			User.add_team_user(-2, c)
		i <<= 1

#******************************************************************************
#******************************************************************************

# void svgacpy2(...), void display_endscr(), void display_screen()
# VESA bank-switched screen copies for the COVERDISK/ECTS builds; not part of
# the match build and not ported.

#******************************************************************************
#******************************************************************************

const _TAC_FILES := {
	F_4_3_3: "tac_433.tac", F_5_3_2: "tac_532.tac", F_6_3_1: "tac_631.tac", F_4_2_4: "tac_424.tac",
	F_5_1_4: "tac_514.tac", F_4_0_6: "tac_406.tac", F_3_1_6: "tac_316.tac", F_4_1_5: "tac_415.tac",
	F_5_2_3: "tac_523.tac", F_4_4_2: "tac_442.tac",
}

# fread(match_tacticsN,sizeof(int),((32*2)+6)*10*2,fp1);
static func _read_tactics(tac: int, dest: Array) -> void:
	var fn: String = "res://data/tactics/" + _TAC_FILES.get(tac, "tac_433.tac")
	var f := FileAccess.open(fn, FileAccess.READ)
	if f == null:
		push_error("Can't open tactics file " + fn)
		return
	for z in range((32 * 2) + 6):
		for p in range(10):
			for c in range(2):
				dest[z][p][c] = s32(f.get_32())
	f.close()

# void load_new_tactics()
static func load_new_tactics() -> void:
	if tactics_a != old_tac_a:
		# Load Match tactics...
		# Team A tactics...
		if not (match_half & 1):
			_read_tactics(tactics_a, match_tactics1)
		else:
			_read_tactics(tactics_a, match_tactics2)

	if tactics_b != old_tac_b:
		# Load Match tactics...
		# Team B tactics...
		if not (match_half & 1):
			_read_tactics(tactics_b, match_tactics2)
		else:
			_read_tactics(tactics_b, match_tactics1)
	old_tac_a = tactics_a
	old_tac_b = tactics_b

#******************************************************************************
#******************************************************************************

# void init_match()
static func init_match() -> void:
	Eng3D.sub_pending = 0

	key_togs[0x0a] = EUROmatch_info.vidi

	# Initialise Penalty Shoot-out...
	penalties = 0
	home_pens_left = 5
	away_pens_left = 5
	penalty_game = FALSE
	penalty_team = FALSE
	penalty_counter = 0
	pen_taker_a = 11
	pen_taker_b = 22

	first_update = TRUE

	Ball.reset_ball()

	opt_user = 0
	subbing_now = FALSE

	if setup.M8:
		replay_seconds = 15
	else:
		replay_seconds = 0

	if replay_seconds:
		# replay_tab=(plyrdat *)mallocx(replay_seconds*ncb*20*sizeof(plyrdat));
		# (allocated by Upd3D.init_replay() in the port)
		pass

	auto_intercept = TRUE
	end_game = FALSE
	allow_replay = FALSE
	match_time.min = 0
	match_time.sec = 0
	next_mins = 0

	just_scored = 0
	set_piece_on = 0
	team_a_goals = 0
	team_b_goals = 0

	if not network_on:
		init_user_controls()

	need_result = bi(match_info.CompetitionType == 2)
	clock_running = FALSE
	team_a = 0
	team_b = 1
	match_half = 0
	last_centre = 0
	init_line_up()

	# Ects show demo (head to head)...
	if ECTS:
		pass	# read_config_file(); display_screen();

	#*** Setup Tactics ***
	tactics_a = EUROmatch_info.tac_1
	tactics_b = EUROmatch_info.tac_2
	old_tac_a = 255		# Force new tactical load!  (char: -1 -> 255)
	old_tac_b = 255
	load_new_tactics()

	ref_accuracy = EUROmatch_info.referee_vision
	ref_strictness = EUROmatch_info.referee_discipline

#******************************************************************************
#******************************************************************************

# void init_player_stats(short p)
static func init_player_stats(p: int) -> void:
	p -= 1
	var ps: int

	if (not (match_half & 1) and p < 11) or ((match_half & 1) and p > 10):
		# Team A...
		if not (match_half & 1):
			ps = p
		else:
			ps = p - 11

		if match_info.GameType:
			# Simulation Mode!!!
			var pl = game_data[setup.team_a].players[ps]
			teams[p].tm_rate = u8(pl.pace + 28)
			teams[p].tm_pow = u8(pl.power + 28)
			teams[p].tm_cont = u8(pl.control + 28)
			teams[p].tm_flair = u8(pl.flair + 28)
			teams[p].tm_vis = u8(pl.vision + 28)
			teams[p].tm_ac = u8(pl.accuracy + 28)
			teams[p].tm_stam = u8(pl.stamina + 28)
			teams[p].tm_disc = u8(pl.discipline + 28)
		else:
			# Arcade Mode!!!
			var rank: int = game_data[setup.team_a].ranking
			var avg: int = s16(int(50 + (1.4 * (COUNTRIES - rank - 1))))  # 50 - 110

			teams[p].tm_rate = u8(30 + (avg / 2))
			teams[p].tm_pow = u8(avg)
			teams[p].tm_cont = u8(avg)
			teams[p].tm_flair = u8(avg)
			teams[p].tm_vis = u8(avg)
			teams[p].tm_ac = u8(avg)
			teams[p].tm_stam = u8(avg)
			teams[p].tm_disc = u8(avg)
	else:
		# Team B...
		if match_half & 1:
			ps = p
		else:
			ps = p - 11

		if match_info.GameType:
			# Simulation Mode!!!
			var pl = game_data[setup.team_b].players[ps]
			teams[p].tm_rate = u8(pl.pace + 28)
			teams[p].tm_pow = u8(pl.power + 28)
			teams[p].tm_cont = u8(pl.control + 28)
			teams[p].tm_flair = u8(pl.flair + 28)
			teams[p].tm_vis = u8(pl.vision + 28)
			teams[p].tm_ac = u8(pl.accuracy + 28)
			teams[p].tm_stam = u8(pl.stamina + 28)
			teams[p].tm_disc = u8(pl.discipline + 28)
		else:
			# Arcade Mode!!!
			var rank: int = game_data[setup.team_b].ranking
			var avg: int = s16(int(50 + (1.4 * (COUNTRIES - rank - 1))))  # 50 - 110

			teams[p].tm_rate = u8(30 + (avg / 2))
			teams[p].tm_pow = u8(avg)
			teams[p].tm_cont = u8(avg)
			teams[p].tm_flair = u8(avg)
			teams[p].tm_vis = u8(avg)
			teams[p].tm_ac = u8(avg)
			teams[p].tm_stam = u8(avg)
			teams[p].tm_disc = u8(avg)

#******************************************************************************
#******************************************************************************

# void process_subs()
static func process_subs() -> void:
	if player_being_subbed:
		# Player has been selected and should come off!
		if not teams[player_being_subbed - 1].guy_on:
			# He's off the park... (Bring on new guy!)
			init_player_stats(player_being_subbed)
			teams[player_being_subbed - 1].shirt = player_coming_on
			teams[player_being_subbed - 1].tm_trap = FALSE
			teams[player_being_subbed - 1].int_move = FALSE
			teams[player_being_subbed - 1].int_cnt = FALSE
			Intell.reset_ideas(teams[player_being_subbed - 1])
			player_being_subbed = FALSE
			teams[player_on_off - 1].guy_on = TRUE
			player_on_off = -player_on_off			# Coming on!
			Intell.init_off_int(teams[(-player_on_off) - 1])
	else:
		if not player_on_off and Eng3D.sub_pending and (match_mode >= CORNER_TL and match_mode <= DF_KICK_B) \
				and not kickoff:
			opt_user = 100		# Substitute instead of options...

			# Some-one is trying to make a substitution...(Who?)
			if Eng3D.sub_pending & 1:
				opt_team = 0
			else:
				opt_team = 1

#******************************************************************************
#******************************************************************************

# void save_state(save_data *save_it) / void restore_state(save_data *save_it)
# void checksum_state() / void reset_state(char buff)
# NETWORK: complete snapshots of the match state, saved every STATE_INTERVAL
# seconds and check-summed so that networked machines could detect and repair
# desynchronisation. Not ported (networking is not part of this port).

# void process_state()
static func process_state() -> void:
	# checksum_state(): ... logic_cnt++;
	logic_cnt += 1

	if not (logic_cnt % (REAL_SPEED * STATE_INTERVAL)):
		# Time for a save...
		# NETWORK: swap state buffers and save_state(state_ptr);
		pass

#******************************************************************************
#******************************************************************************

# void variable_wind()
static func variable_wind() -> void:
	# Variable speed and direction around initial settings...

	# Do dir.
	if wind_d_trend > 0:
		# Wind current dir gets further from initial setting...
		wind_d_trend -= 1
		if wind_var_ang < 0:
			wind_var_ang -= (MAX_WIND_CHANGE * seed / 128)
		else:
			wind_var_ang += (MAX_WIND_CHANGE * seed / 128)

		wind_x = (init_wind_x * cos(wind_var_ang)) - (init_wind_y * sin(wind_var_ang))
		wind_y = (init_wind_y * cos(wind_var_ang)) + (init_wind_x * sin(wind_var_ang))
	else:
		if wind_d_trend < 0:
			# Wind current dir returns to initial setting...
			wind_d_trend += 1
			if wind_var_ang < 0:
				wind_var_ang += (MAX_WIND_CHANGE * seed / 128)
			else:
				wind_var_ang -= (MAX_WIND_CHANGE * seed / 128)

			wind_x = (init_wind_x * cos(wind_var_ang)) - (init_wind_y * sin(wind_var_ang))
			wind_y = (init_wind_y * cos(wind_var_ang)) + (init_wind_x * sin(wind_var_ang))
		else:
			# New trend...
			if ABS(wind_var_ang * 128 / PI) < seed:
				wind_d_trend = WIND_BLUSTERINESS
			else:
				wind_d_trend = -WIND_BLUSTERINESS

	Maths.af_randomize()

	# Do speed.
	if wind_s_trend > 0:
		# Increment difference in speed...
		wind_s_trend -= 1
		if (wind_speed - init_wind_speed) < 0:
			wind_speed -= (MAX_WIND_S_CHANGE * seed / 128)
			if wind_speed < 0:
				wind_speed = 0
		else:
			wind_speed += (MAX_WIND_S_CHANGE * seed / 128)
			if wind_speed > 128:
				wind_speed = 128
	else:
		if wind_s_trend < 0:
			# Decrement difference in speed...
			wind_s_trend += 1
			if (wind_speed - init_wind_speed) < 0:
				wind_speed += (MAX_WIND_S_CHANGE * seed / 128)
				if wind_speed > 128:
					wind_speed = 128
			else:
				wind_speed -= (MAX_WIND_S_CHANGE * seed / 128)
				if wind_speed < 0:
					wind_speed = 0
		else:
			# New trend...
			if ABS(wind_speed - init_wind_speed) < (seed / 2):
				wind_s_trend = WIND_GUSTINESS
			else:
				wind_s_trend = -WIND_GUSTINESS

#******************************************************************************
#******************************************************************************

# void do_logic()
static func do_logic() -> void:
	Display.init_pitch_sprites()

	if SAVE_GAME:
		pass	# save_game()/restore_game() on w/z keys (not in this build)

	if not COVERDISK:
		if debug and key_togs[0x30]:		# b
			# Move ball around with mouse.
			ballx = mouse_x * 5 - 160
			bally = mouse_y * 5 - 160

	# Normal logic mode.
#	if (!match_mode)
#	{
#		if (!--pen_cnt)
#			force_penalty();
#	}
	frame = 0 if frame else 1
	Maths.af_randomize()

	if not on_3d:
		pass	# ReportMouse();

	process_subs()

	if wind_on < 0:
		variable_wind()		# Get current wind parameters...

	Ball.process_ball()

	Rules.match_rules()
	Intell.keeper_boxes()
	BallInt.player_distances()
	BallInt.get_nearest()		# near_path_a, near_path_b
	BallInt.get_opp_near_ball(ball_poss)

	Intell.process_speech()
	Intell.process_comments()
	process_flags()
	Actions.process_teams()
	User.new_users()
	Actions.select_all_hlites()
	Rules.process_offs()

	if not match_mode and comsetp:
		comsetp -= 1

#******************************************************************************
#******************************************************************************

# void stop_mf_time()
static func stop_mf_time() -> void:
#	int cl=clock();
#	int c=cl/CLOCKS_PER_SEC;
#	last_second=c;
#	old_clock=cl;
	oldcnt = count - 1

#******************************************************************************
#******************************************************************************

# void pause_game()
# Original: do{}while(paused); stop_mf_time();
# In Godot the driver keeps the match frozen while `paused` is set and calls
# stop_mf_time() when it is released.
static func pause_game() -> void:
	pass

#******************************************************************************
#******************************************************************************

# void init_joy1()
static func init_joy1() -> void:
	calibrated_1 = FALSE
	joy1_min_x = 20000
	joy1_max_x = 0
	joy1_min_y = 20000
	joy1_max_y = 0

# void init_joy2()
static func init_joy2() -> void:
	calibrated_2 = FALSE
	joy2_min_x = 20000
	joy2_max_x = 0
	joy2_min_y = 20000
	joy2_max_y = 0

# void init_joys()
static func init_joys() -> void:
	init_joy1()
	init_joy2()

#******************************************************************************
#******************************************************************************

# void process_keys()
static func process_keys() -> void:
	if not demo_match or debug:
		# while(escape_pending>0) { ... }  -- polled once per frame by the driver
		# (the match is frozen while escape_pending>0, see match_frame()).
		if escape_pending > 0:
			if keys[0x15]:	# Y
				Upd3D.add_message("Leaving Match!", RED, TRUE)
				escape_pending = -1

			if keys[0x31]:	# N
				Upd3D.add_message(" ", WHITE, TRUE)
				escape_pending = FALSE
				stop_mf_time()
			return

		if paused:
			pause_game()

		if keys[0x3b] and keys[0x1d] and joystick1_on:
			# Ctrl F1...
			calibrated_1 = FALSE
			init_joy1()
			Upd3D.add_message("Auto Calibrating Port 1", WHITE, TRUE)

		if keys[0x3c] and keys[0x1d] and joystick2_on:
			# Ctrl F2...
			calibrated_2 = FALSE
			init_joy2()
			Upd3D.add_message("Auto Calibrating Port 2", WHITE, TRUE)

		if NO_AUTO_SEL:
			if keys[0x43]:			# f9
				if key_togs[0x43]:
					Upd3D.add_message("Manual Switching", WHITE, TRUE)
				else:
					Upd3D.add_message("Automatic Switching", WHITE, TRUE)

		if not COVERDISK:
			if debug:
				if keys[0x11] and ball_poss and not match_mode:
					var b: int = ball_poss
					BallInt.holder_lose_ball()
					Rules.init_foul((13 if b < 12 else 2), TRUE, TRUE)	# pass no. of fouler.

				if keys[0x0f]:
					User.delete_net_user(2)

#				if (keys[0x14])		// t
#					if (key_togs[0x14])
#						tweening=TRUE;
#					else
#						tweening=FALSE;
				if keys[0x14]:		# t
					# do; while(keys[0x14]);  (wait for key release)
					keys[0x14] = 0
					xinfo += 1
					if xinfo > 8:
						xinfo = 0
#				if (keys[0x0f])		// TAB
#				{
#					delete_net_user(2);
#					while(keys[0x14]);
#				}
				if keys[0x21]:		# f
					# Fixed speed...
					mf_fixed = TRUE
					mf_scale = 1

				if keys[0x22]:		# g
					# Variable speed...
					mf_fixed = FALSE

				if keys[0x4a]:		# +
					# Game Faster...
					if game_speed > 0:
						game_speed -= 1

				if keys[0x4e]:		# -
					# Game Slower...
					game_speed += 1

		if not network_on and not player_on_off and not line_up and match_mode != SWAP_ENDS:
			if SUPPORT_LP:
				if keys[0x3b] or (users_dir[0].f & 8 and users_dir[0].f & 4 and not (users_dir[0].f & 48)):		# LS + RS
					if num_of_users >= 1:
						# User player 1 options...
						opt_user = 1
					else:
						# No user players...
						opt_user = -1

				if (keys[0x3c] or (users_dir[1].f & 8 and users_dir[1].f & 4) and not (users_dir[0].f & 48)) and num_of_users >= 2:
					opt_user = 2

				if (keys[0x3d] or (users_dir[2].f & 8 and users_dir[2].f & 4) and not (users_dir[0].f & 48)) and num_of_users >= 3:
					opt_user = 3

				if (keys[0x3e] or (users_dir[3].f & 8 and users_dir[3].f & 4) and not (users_dir[0].f & 48)) and num_of_users >= 4:
					opt_user = 4
			else:
				if keys[0x3b] and not keys[0x1d]:				# F1
					if num_of_users >= 1:
						# User player 1 options...
						opt_user = 1
					else:
						# No user players...
						opt_user = -1

				if keys[0x3c] and not keys[0x1d] and num_of_users >= 2:	# F2
					# User player 2 options...
					opt_user = 2

				if keys[0x3d] and not keys[0x1d] and num_of_users >= 3:	# F3
					# User player 3 options...
					opt_user = 3

				if keys[0x3e] and not keys[0x1d] and num_of_users >= 4:	# F4
					# User player 4 options...
					opt_user = 4

			if opt_user:
				# (opt_user is -1 when there are no users: C indexes users[-2] - the
				#  word before the array; treated as "no team" here.)
				if opt_user < 1:
					opt_team = team_a
				elif users[opt_user - 1].type == -1:
					opt_team = team_a
				else:
					if users[opt_user - 1].type == -2:
						opt_team = team_b
					else:
						if users[opt_user - 1].type < 12:
							opt_team = team_a
						else:
							opt_team = team_b
	else:
		if anykey:
			end_game = TRUE

#******************************************************************************
#******************************************************************************

# void animate_players()
static func animate_players() -> void:
	for i in range(players):
		teams[i].tm_frm += teams[i].tm_fstep

	for i in range(3):
		refs[i].frm += refs[i].fstep

#******************************************************************************
#******************************************************************************

# void update_2d()  -- 2D overhead debug display (on_3d==FALSE); not ported.

#******************************************************************************
#******************************************************************************

# void reset_possession()
static func reset_possession() -> void:
	poss_held = 0
	possession = 0

#******************************************************************************
#******************************************************************************

# void accumulate_possession()
static func accumulate_possession() -> void:
	if ball_poss > 11:
		# Team b. currently has possession...
		poss_held += (0.0001 + (ABS(poss_held) / 30))
		if poss_held > 0.5:
			poss_held = 0.5
	else:
		if ball_poss:
			# Team a. currently has possession...
			poss_held -= (0.0001 + (ABS(poss_held) / 30))
			if poss_held < -0.5:
				poss_held = -0.5

	if not ball_poss:
		# Ball is free...(tend slowly towards 0)
		poss_held += (-poss_held / 60)

	possession += poss_held
	if possession > 1:
		possession = 1
	if possession < -1:
		possession = -1

#******************************************************************************
#******************************************************************************

# Crowd mood helpers for the midfield / near goal tests used in several cases.
static func _crowd_mid() -> bool:
	return (ballx > (cntspot_x - prat * 16)) and (ballx < (cntspot_x + prat * 16))

# void process_crowd_noise()
static func process_crowd_noise() -> void:
	if shot_missed:
		if shot_missed < 0:
			# Missed by a long way...
			shot_missed += 1
			if last_touch < 12:
				# team A shot...
				crowd_mood_a = CN_BOO
				crowd_mood_b = CN_LAUGH
			else:
				# team B shot...
				crowd_mood_a = CN_LAUGH
				crowd_mood_b = CN_BOO
		else:
			# Near missed...
			shot_missed -= 1
			if last_touch < 12:
				# team A shot...
				crowd_mood_a = CN_MISS
				crowd_mood_b = CN_PENSIVE
			else:
				# team B shot...
				crowd_mood_a = CN_PENSIVE
				crowd_mood_b = CN_MISS
	else:
		if shot_saved:
			# Shot stopped...
			shot_saved -= 1
			if last_touch < 12:
				# team A save...
				crowd_mood_a = CN_SAVE
				crowd_mood_b = CN_MISS
			else:
				# team B save...
				crowd_mood_a = CN_MISS
				crowd_mood_b = CN_SAVE
		else:
			if card_is_out:
				card_is_out -= 1
				crowd_mood_a = CN_FOWL
				crowd_mood_b = CN_FOWL
			else:
				if match_half > 10:
					# End of Game...
					crowd_mood_a = CN_EXCITED
					crowd_mood_b = CN_EXCITED
				else:
					_crowd_switch()

# The switch(match_mode) of process_crowd_noise(). DF_KICK_B and DF_KICK_A fall
# through into the corner cases when men_in_wall is set (C switch fall-through).
static func _crowd_switch() -> void:
	var mm: int = match_mode
	if mm == NORMAL_PLAY:
		if shot_pending and shot_acknowledged:
			# Keeper is reacting to incoming ball...
			if ballx < prat * 40 and ballxdis < 0 and last_touch > 11:
				# Ball coming left (from team B)...
				crowd_mood_a = CN_PENSIVE
				crowd_mood_b = CN_EXCITED
			if ballx > (pitch_len - (prat * 40)) and ballxdis > 0 and last_touch < 12:
				# Ball coming right (from team A)...
				crowd_mood_a = CN_EXCITED
				crowd_mood_b = CN_PENSIVE
		else:
			accumulate_possession()

			if ball_in_hands and (ball_poss == KP_A or ball_poss == KP_B):
				# Keepers ball...(calm)
				crowd_mood_a = CN_NORMAL
				crowd_mood_b = CN_NORMAL
			else:
				if _crowd_mid():
					# In mid-field...
					crowd_mood_a = CN_NORMAL
					crowd_mood_b = CN_NORMAL
				else:
					if ballx <= (cntspot_x - prat * 16):
						# Near Goal A...
						if possession > 0.5:
							# Team B has good possession...
							crowd_mood_a = CN_PENSIVE
							crowd_mood_b = CN_EXCITED
						else:
							if possession < -0.5:
								# Defending team A has it under control...
								crowd_mood_a = CN_NORMAL
								crowd_mood_b = CN_NORMAL
							else:
								# No one team has it under control...
								crowd_mood_a = CN_NORMAL
								crowd_mood_b = CN_ENCOURAGING
					else:
						# Near Goal B...
						if possession < -0.5:
							# Team A has good possession...
							crowd_mood_a = CN_EXCITED
							crowd_mood_b = CN_PENSIVE
						else:
							if possession > 0.5:
								# Defending team B has it under control...
								crowd_mood_a = CN_NORMAL
								crowd_mood_b = CN_NORMAL
							else:
								# No one team has it under control...
								crowd_mood_a = CN_ENCOURAGING
								crowd_mood_b = CN_NORMAL

			if just_scored:
				# someone has scored a goal...
				if ballx < cntspot_x:
					# Team A. goal...
					if goal_scorer > 11:
						# Team B scores good goal!
						crowd_mood_a = CN_PENSIVE
						crowd_mood_b = CN_CELEBRATE
					else:
						# Team A scores own goal!
						crowd_mood_a = CN_BOO
						crowd_mood_b = CN_CELEBRATE
				else:
					# Team B. goal...
					if goal_scorer < 12:
						# Team A scores good goal!
						crowd_mood_a = CN_CELEBRATE
						crowd_mood_b = CN_PENSIVE
					else:
						# Team B scores own goal!
						crowd_mood_a = CN_CELEBRATE
						crowd_mood_b = CN_BOO
		return

	if mm == DF_KICK_B:
		if not men_in_wall:			# Not in shooting range!
			if _crowd_mid():
				# In mid-field...
				crowd_mood_a = CN_NORMAL
				crowd_mood_b = CN_NORMAL
			else:
				if ballx <= (cntspot_x - prat * 16):
					# Near Goal A...
					crowd_mood_a = CN_PENSIVE
					crowd_mood_b = CN_ENCOURAGING
				else:
					# Near Own Goal B...
					crowd_mood_a = CN_NORMAL
					crowd_mood_b = CN_NORMAL
			return
		mm = CORNER_TL		# falls through...

	if mm == CORNER_TL or mm == CORNER_BL:
		crowd_mood_a = CN_PENSIVE
		crowd_mood_b = CN_EXCITED
		return

	if mm == DF_KICK_A:
		if not men_in_wall:			# Not in shooting range!
			if _crowd_mid():
				# In mid-field...
				crowd_mood_a = CN_NORMAL
				crowd_mood_b = CN_NORMAL
			else:
				if ballx >= (cntspot_x + prat * 16):
					# Near Goal B...
					crowd_mood_a = CN_ENCOURAGING
					crowd_mood_b = CN_PENSIVE
				else:
					# Near Own Goal A...
					crowd_mood_a = CN_NORMAL
					crowd_mood_b = CN_NORMAL
			return
		mm = CORNER_TR		# falls through...

	if mm == CORNER_TR or mm == CORNER_BR:
		crowd_mood_a = CN_EXCITED
		crowd_mood_b = CN_PENSIVE
		return

	if mm == GOAL_KICK_TL or mm == GOAL_KICK_TR or mm == GOAL_KICK_BL or mm == GOAL_KICK_BR:
		crowd_mood_a = CN_NORMAL
		crowd_mood_b = CN_NORMAL
		reset_possession()
		return

	if mm == IF_KICK_A or mm == THROW_IN_A:
		if _crowd_mid():
			# In mid-field...
			crowd_mood_a = CN_NORMAL
			crowd_mood_b = CN_NORMAL
		else:
			if ballx >= (cntspot_x + prat * 16):
				# Near Goal B...
				crowd_mood_a = CN_ENCOURAGING
				crowd_mood_b = CN_PENSIVE
			else:
				# Near Own Goal A...
				crowd_mood_a = CN_NORMAL
				crowd_mood_b = CN_NORMAL
		return

	if mm == IF_KICK_B or mm == THROW_IN_B:
		if _crowd_mid():
			# In mid-field...
			crowd_mood_a = CN_NORMAL
			crowd_mood_b = CN_NORMAL
		else:
			if ballx <= (cntspot_x - prat * 16):
				# Near Goal A...
				crowd_mood_a = CN_PENSIVE
				crowd_mood_b = CN_ENCOURAGING
			else:
				# Near Own Goal B...
				crowd_mood_a = CN_NORMAL
				crowd_mood_b = CN_NORMAL
		return

	if mm == PEN_KICK_A or mm == PEN_KICK_B or mm == SWAP_ENDS:
		crowd_mood_a = CN_EXCITED
		crowd_mood_b = CN_EXCITED
		return

	if mm == CENTRE_A or mm == CENTRE_B:
		reset_possession()
		if kickoff:
			crowd_mood_a = CN_EXCITED
			crowd_mood_b = CN_EXCITED
		else:
			crowd_mood_a = CN_NORMAL
			crowd_mood_b = CN_NORMAL
		return

#******************************************************************************
#******************************************************************************

# char nothing_happening()
static func nothing_happening() -> int:
	if not match_mode and not just_scored:
		# In Play...
		Audio.play_fx(PS_FULLTIMEWHISTLE, refs[0].x, refs[0].y)

		if shot_pending or dead_ball_cnt or game_action:
			return FALSE			# Crucial moment!
		else:
			return TRUE
	else:
		if match_mode <= CORNER_BR or match_mode >= PEN_KICK_A:
			return FALSE			# Crucial moment!
		else:
			if (match_mode == DF_KICK_B or match_mode == DF_KICK_A) and men_in_wall:
				return FALSE			# Crucial moment!
			else:
				return TRUE

#******************************************************************************
#******************************************************************************

# The "#ifdef EURO96 get_performance(); xinfo=9; if (man_of_match) camera=18; #endif" block.
static func _end_game_performance() -> void:
	if EURO96:
		get_performance()
		xinfo = 9
		if man_of_match:
			camera = 18

# void watch_match_time()
static func watch_match_time() -> void:
	if golden_goal == 2 and not just_scored:
		# End of sudden death...
		if match_half < 11:
			# Start leaving field!
			Audio.play_fx(PS_FULLTIMEWHISTLE, refs[0].x, refs[0].y)
			last_goal = 0
			match_mode = SWAP_ENDS
			Rules.init_match_mode()
			Eng3D.do_full_time_anim(0)
			Eng3D.do_fulltime_menu()
			match_half = 11			# End game!
			Audio.PlayCommentaryMessage(TI_FULLTIME)
			next_mins = 0
			_end_game_performance()
	else:
		if match_info.CompetitionType == PENALTIES:
			# Practice penalties...
			if not penalty_game:
				if team_a_goals != team_b_goals:
					# Someone has won shoot-out...
					if match_half < 11:
						# Initialise end of penalty shoot-out...
						last_goal = 0
						match_mode = SWAP_ENDS
						Rules.init_match_mode()
						Eng3D.do_full_time_anim(0)
						EUROmatch_info.Team_A_penalties = team_a_goals
						EUROmatch_info.Team_B_penalties = team_b_goals
						Eng3D.do_final_score_menu()
						match_half = 11			# End game!
						Audio.PlayCommentaryMessage(TI_FULLTIME)
						next_mins = 0
						_end_game_performance()
				else:
					# Initialise penalty shoot-out...
					EUROmatch_info.penalties = TRUE
					penalty_game = TRUE
					team_a_goals = 0
					team_b_goals = 0
					EUROmatch_info.Team_A_penalties = team_a_goals
					EUROmatch_info.Team_B_penalties = team_b_goals
					Eng3D.do_penalty_shootout_menu()
					next_mins = 0
		else:
			if match_time.min >= (45 + injury_time) and not match_half and nothing_happening():
				# End of first half! (It's a game of two halves...)
				if DEMO:
					last_goal = 0
					match_mode = SWAP_ENDS
					Rules.init_match_mode()
					Audio.play_fx(PS_FULLTIMEWHISTLE, refs[0].x, refs[0].y)
					Eng3D.do_full_time_anim(0)
					Eng3D.do_fulltime_menu()
					Audio.PlayCommentaryMessage(TI_FULLTIME)
					match_half = 11			# End game!
					next_mins = 0
				else:
					match_mode = SWAP_ENDS
					last_goal = 0
					Rules.init_match_mode()
					Audio.play_fx(PS_HALFTIMEWHISTLE, refs[0].x, refs[0].y)
					Eng3D.do_half_time_anim(0)
					Eng3D.do_halftime_menu()
					Audio.PlayCommentaryMessage(TI_HALFTIME)
					kickoff = TRUE
					next_mins = 45

					if practice:
						match_half = 12
			else:
				if match_time.min >= (90 + injury_time) and match_half == 1 and nothing_happening():
					# End of full time! (Not half mate...)
					last_goal = 0
					match_mode = SWAP_ENDS
					Rules.init_match_mode()
					Audio.play_fx(PS_FULLTIMEWHISTLE, refs[0].x, refs[0].y)

					if need_result and team_a_goals == team_b_goals:
						Eng3D.do_extra_time_anim(0)
						Eng3D.do_extratime_menu()
						EUROmatch_info.extra = TRUE
						kickoff = TRUE
						next_mins = 90
					else:
						Eng3D.do_full_time_anim(0)
						Eng3D.do_fulltime_menu()
						Audio.PlayCommentaryMessage(TI_FULLTIME)
						match_half = 11			# End game!
						next_mins = 0
						_end_game_performance()
				else:
					if need_result and match_time.min >= (90 + 15 + injury_time) \
							and match_half == 2 and nothing_happening():
						# End of first half of extra time! (It's a game with more halves...)
						last_goal = 0
						match_mode = SWAP_ENDS
						Rules.init_match_mode()
						Eng3D.do_half_time_anim(0)
						Eng3D.do_halftime_menu()
						Audio.play_fx(PS_HALFTIMEWHISTLE, refs[0].x, refs[0].y)
						kickoff = TRUE
						next_mins = 105
					else:
						if not penalty_game and need_result and match_time.min >= (90 + 30 + injury_time) \
								and match_half == 3 and nothing_happening():
							# End of full extra time!
							Audio.play_fx(PS_FULLTIMEWHISTLE, refs[0].x, refs[0].y)
							if need_result and team_a_goals == team_b_goals:
								EUROmatch_info.penalties = TRUE
								penalty_game = TRUE
								team_a_goals = 0
								team_b_goals = 0
								EUROmatch_info.Team_A_penalties = team_a_goals
								EUROmatch_info.Team_B_penalties = team_b_goals
								Eng3D.do_penalty_shootout_menu()
								next_mins = 0
							else:
								last_goal = 0
								match_mode = SWAP_ENDS
								Rules.init_match_mode()
								Eng3D.do_full_time_anim(0)
								if EUROmatch_info.penalties:
									EUROmatch_info.Team_A_penalties = team_a_goals
									EUROmatch_info.Team_B_penalties = team_b_goals
									Eng3D.do_final_score_menu()
								else:
									Eng3D.do_fulltime_menu()
								match_half = 11			# End game!
								Audio.PlayCommentaryMessage(TI_FULLTIME)
								next_mins = 0
								_end_game_performance()

#******************************************************************************
#******************************************************************************

# void setup_alarm()
static func setup_alarm() -> void:
	mf_fixed = FALSE
	alarm = FALSE					# Debug alarm on/off.
	watch = TRUE
	stop_min = 45
	stop_sec = 1						# Debug alarm stop.

#******************************************************************************
#******************************************************************************

# void init_wind()
static func init_wind() -> void:
	# Wind stuff...
	if EUROmatch_info.wind:
		init_wind_x = 1
		init_wind_y = 0
		wind_x = init_wind_x
		wind_y = init_wind_y
		init_wind_speed = EUROmatch_info.wind * 30   # (30,60,90)
		wind_speed = init_wind_speed
		wind_var_ang = 0
		wind_d_trend = 0
		wind_s_trend = 0

		Maths.af_randomize()
		if not (seed & 3):
			wind_on = -TRUE		# Variable wind!
		else:
			wind_on = TRUE

		wind_on = TRUE
	else:
		wind_on = FALSE

#******************************************************************************
#******************************************************************************

# Get your grubby mits off these routines Andy!

# void NetUserInit()
static func NetUserInit() -> void:
	if network_on:
		# NETWORK: network users are added here (add_team_user/add_fixed_user with
		# NET_CTRL for remote machines). Not ported.
		pass

# void TimerInit()
static func TimerInit() -> void:
	ftick = 0
	otick = 0
	tick = 0
	old_count = count
#	if (!old_mf) { get_user_inputs(); process_user_inputs(); writeptr++; }
	# while(tick==otick);   (wait for the first timer tick - the driver starts the
	# clock right after this call)

#******************************************************************************
#******************************************************************************

# void reset_front()
static func reset_front() -> void:
	for i in range(cam_array.size()):
		if camera == cam_array[i]:
			EUROmatch_info.camera = i
			match_info.camera_toggle = i
			break

#******************************************************************************
#******************************************************************************
#
# int match(int argc, char **argv)
#
#******************************************************************************

static var match_err: int = FALSE

# Part 1 of match(): initialisation up to the main loop.
static func match_start() -> int:
	match_err = FALSE

	initialise_vars()

	if NET_GAME:
		pass	# Pseudo net initialisation (not normally used) NetTest();

	if network_on:
		old_mf = FALSE
	else:
		old_mf = TRUE

	offside_on = EUROmatch_info.offside

	if match_info.CompetitionType == PRACTICE:
		offside_on = FALSE

	# Set up default camera...
	camera = cam_array[EUROmatch_info.camera]
	var cd: float = set_camera_dist
	var ch: float = set_camera_height
	Upd3D.change_cam(camera)
	set_camera_dist = cd
	set_camera_height = ch

	# Set up audio...
	audio_version = u8(EUROmatch_info.audio)
	# Vidi screen setup...
	vidi_wall_on = u8(EUROmatch_info.vidi)		# Vidi toggle!

	# Debugging alarm...
	setup_alarm()

	if not FRONT_END:
		time_factor = 4
#		debug=TRUE;											// Allows return keyboard to dos.
	else:
		say_names = TRUE
		if network_on:
			time_factor = time_table[net_half]		# Real minutes duration.
		else:
			time_factor = time_table[EUROmatch_info.time]	# Real minutes duration.

		debug = FALSE										# Allows return keyboard to dos.

	if ECTS:
		time_factor = 4
#	debug=TRUE;
#	time_factor=10;

	init_wind()

	gravity = 0.60

	on_3d = TRUE
	digital_joy1 = FALSE
	digital_joy2 = FALSE
	close_in_number = 2
	goal_kicker_a = 1
	goal_kicker_b = 12

	fkick_taker_a = 0
	fkick_taker_b = 0

	corn_kicker_a = 0
	corn_kicker_b = 0

#	_setvideomode(_MRES256COLOR);

	Actions.init_officials()

	init_match()

	if not on_3d:
		pass	# 2D editor display (not ported)
	else:
		if Upd3D.init_3d() < 0:
			# ERR_3D:
			net_error = -1
			match_err += 256
			return match_err

	if audio_version:
		Audio.InitMatchAudio(rand_seed)
		if not Audio.LoadPitchSamples():
			if not Audio.LoadTeamSamples(setup.team_a, HOME_TEAM):
				if not Audio.LoadTeamSamples(setup.team_b, AWAY_TEAM):
					if match_info.CompetitionType != PRACTICE:
						Audio.LoadCommentarySamples()

					Audio.StartCrowd(HOME_TEAM)
					Audio.StartCrowd(AWAY_TEAM)

	# Pseudo net user initialisation (not normally used)
	NetUserInit()
	users_left = num_of_users

	# Wait for everyone to get here, set timer & machine factor...
	readptr = 0
	writeptr = 0
	# NETWORK: Network_Play_Ready();

	Eng3D.setscreen()
	if audio_version:
		Audio.PlayWelcomeMessage()

	# Various timing initialisations for network (DO NOT MOVE)
	TimerInit()
	mf_scale = 0.5
	omf_scale = 0.5
	MF = 1
	old_clock = 0
	oldcnt = count

	# No Dos. keyboard chain!
	return_doskey = FALSE

	# Main program loop...

#	penalty_game=TRUE;

	Eng3D.do_ref_menu()

	if FRONT_END:
		if not num_of_users:
			# No Players... Rolling match...
			anykey = FALSE
			rolling_clock = 80 * REAL_SPEED
			demo_match = TRUE

	return 0

# One logic cycle of the main loop (shared by both timing branches).
static func _logic_cycle() -> void:
	process_crowd_noise()
	if audio_version:
		process_crowd_noise()
		Audio.UpdateCrowd(crowd_mood_a, team_a)
		Audio.UpdateCrowd(crowd_mood_b, team_b)
		Audio.UpdateCommentary()

# Part 2 of match(): one pass of "while (in_game && !net_quit)".
# Returns FALSE when the loop must end.
static func match_frame() -> int:
	if not (in_game and not net_quit):
		return FALSE

	# "Quit Game Y or N" / pause: the original blocked inside process_keys().
	if escape_pending > 0 or paused:
		process_keys()
		if paused:
			return TRUE
		if escape_pending < 0:
			# Quit Match...
			net_error = -1
			return FALSE
		return TRUE

	#**********************************************

	if not old_mf:		# New logical loop
		var ttick: int = tick
		var tftick: int = ftick
		var twriteptr: int = writeptr

		if (mf_fixed) or (not on_3d) or (not watch and alarm):
			tick = otick + 1
			ttick = tick
			ftick = 0
			tftick = 0
			mf_scale = 0
			omf_scale = 0

		mf_scale = float(tftick) / TIMER_SPEED
		MF = (ttick + mf_scale) - (otick + omf_scale)
		omf_scale = mf_scale
		log_factor = MF						# Passed to 3d (Logic cycles/update)

		var i: int = readptr
		while i != twriteptr:
			_logic_cycle()

			wptr = writeptr
			rptr = readptr

			User.convert_inputs()
			readptr += 1
			readptr &= 511
			if not line_up:
				do_logic()
			else:
				line_up -= 1
				animate_players()
				if not line_up:
					match_mode = CENTRE_A
					Rules.init_match_mode()
			if EURO96:
				process_state()
			else:
				logic_cnt += 1

			Upd3D.new_update_coords()
			Upd3D.process_replay()
			watch_match_time()
			i = (i + 1) & 511
		otick = ttick
	else:
		if (mf_fixed) or (not on_3d) or (not watch and alarm):
			MF = 1

		mf_scale += MF
		log_factor = MF				# Passed to 3d(Logic cycles/update)

		var i: float = mf_scale
		while i > 1:
			_logic_cycle()

			NetInput.get_user_inputs()
			NetInput.process_user_inputs()
			writeptr += 1
			writeptr &= 511
			User.convert_inputs()
			readptr += 1
			readptr &= 511
			if not line_up:
				do_logic()
			else:
				line_up -= 1
				animate_players()
				if not line_up:
					match_mode = CENTRE_A
					Rules.init_match_mode()

			if EURO96:
				process_state()
			else:
				logic_cnt += 1
			Upd3D.new_update_coords()
			Upd3D.process_replay()
			watch_match_time()
			mf_scale = mf_scale - 1
			i = i - 1

	#**********************************************

	if not (not watch and alarm):
		Upd3D.realtime_coords()
		Upd3D.process_pitch_sprs()

		if keys[0x01] and not escape_pending:		# (Esc.)
			escape_pending = TRUE
			Upd3D.add_message("Quit Game Y or N", RED, TRUE)

		if on_3d:
			Upd3D.update_3d()
		# else: update_2d();

		if on_3d:
			if old_mf:
				Display.frame_count()
			else:
				updates += 1

			process_keys()

	if demo_match and rolling_clock <= 0:
		end_game = TRUE

	if escape_pending < 0:
		# Quit Match...
		net_error = -1
		return FALSE

	if end_game:
		return FALSE
	return TRUE

# Part 3 of match(): after the main loop.
static func match_end() -> int:
	# Remove network (if appropriate)
	# NETWORK: Quit_Network_Play();

	if audio_version:
		Audio.StopAudio()

	Eng3D.end3d()		# Goodbye Laurent's crappy heap of runny donkey shit code...

	if COVERDISK:
		pass	# display_endscr();

	# Inform front end on times...
	if end_game:
		# Played Full Match!!!
		EUROmatch_info.return_mins = -1
	else:
		# Escaped from match!!!
		EUROmatch_info.return_mins = match_time.min

	if audio_version:
		Audio.FreeCommentarySamples()
		Audio.FreeTeamSamples(AWAY_TEAM)
		Audio.FreeTeamSamples(HOME_TEAM)
		Audio.FreePitchSamples()

	# Give back front end enviroment stuff...
	reset_front()

	# Give Dos. keyboard chain!
	return_doskey = TRUE

	return FALSE		# No errors...
