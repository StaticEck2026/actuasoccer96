#******************************************************************************
#******************************************************************************
#
# Player action routines...
#
#******************************************************************************
#*****************************************************************************/
# (part A: SOURCE/ACTIONS.CPP lines 1-3047)
# #include "ball.dta"  -> save_offs[] lives in glob.gd
# extern short get_there_time(int p_num,float x,float y);  -> Intell.get_there_time

# #define ROTATE_ANG (0.16)   (inside #ifdef SUPPORT_LP)
const ROTATE_ANG = 0.16
# #define ROT_SPEED (0.05)
const ROT_SPEED = 0.05

# void draw_tracker(...): static float fract=0;
static var draw_tracker__fract: float = 0.0

#******************************************************************************
#*****************************************************************************/

# Converts Statistical speed to actual game speed (takes possession of ball into account!)...

# float full_spd(match_player *p)
static func full_spd(p: match_player) -> float:
	var a: float

	if p.int_move == I_CELEB:
		a = MC_CELEB_SPD
	else:
		a = (float(pitch_len)) / ((18.0 - ((float(p.tm_rate) / 64) * 4)) * 20)

	return (a)

#******************************************************************************
#*****************************************************************************/

# Converts Statistical speed to actual game speed (takes possession of ball into account!)...

# float actual_spd(match_player *p)
static func actual_spd(p: match_player) -> float:
	var a: float

	if p.int_move == I_CELEB:
		a = MC_CELEB_SPD
	else:
		if p.int_move == I_INTERCEPT and p.int_cnt:
			# Chasing Ball (must run)...
			a = (float(pitch_len)) / ((18.0 - ((float(p.tm_rate) / 64) * 4)) * 20)
		else:
			if p.go_step:
				# Side stepping...
				a = (float(pitch_len)) / ((24.0 - ((float(p.tm_rate) / 64) * 4)) * 20)
			else:
				if ball_poss == p.tm_player:
					# Avg runs pitch length in 14 secs.
					# Top run in 10 secs.
					if ball_in_hands and (p.tm_player == KP_A or p.tm_player == KP_B):
						# Keeper with ball in his hands...(slow)
						a = (float(pitch_len)) / ((28.0 - ((float(p.tm_rate) / 64) * 4)) * 20)
					else:
						a = (float(pitch_len)) / ((20.0 - ((float(p.tm_rate) / 64) * 4)) * 20)
				else:
					# Avg runs pitch length in 16 secs.
					# Top run in 12 secs.
					if user_controlled and burst_timer[user_controlled - 1] > 0:
						a = (float(pitch_len)) / (((18.0 - float(burst_timer[user_controlled - 1]) / 5) - ((float(p.tm_rate) / 64) * 4)) * 20)
					else:
						a = (float(pitch_len)) / ((18.0 - ((float(p.tm_rate) / 64) * 4)) * 20)

	return (a)

#******************************************************************************
#*****************************************************************************/

# void init_officials()
static func init_officials() -> void:
	refs[0].x = cntspot_x
	refs[1].x = cntspot_x
	refs[2].x = cntspot_x
	refs[0].goto_x = cntspot_x
	refs[1].goto_x = cntspot_x
	refs[2].goto_x = cntspot_x

	refs[0].y = cntspot_y
	refs[0].goto_y = cntspot_y
	refs[1].y = -(prat * 2)
	refs[1].goto_y = -(prat * 2)
	refs[2].y = pitch_wid + (prat * 2)
	refs[2].goto_y = pitch_wid + (prat * 2)
	refs[0].z = 0
	refs[1].z = 0
	refs[2].z = 0
	refs[0].dir_x = 0
	refs[1].dir_x = 0
	refs[2].dir_x = 0
	refs[0].dir_y = 1
	refs[1].dir_y = 1
	refs[2].dir_y = -1
	refs[0].anim = MC_PLEAD
	refs[1].anim = MC_STAND
	refs[2].anim = MC_STAND
	refs[0].fstep = MC_PLEAD_FS
	refs[1].fstep = MC_STAND_FS
	refs[2].fstep = MC_STAND_FS
	refs[0].frm = 0.6
	refs[1].frm = 0
	refs[2].frm = 0
	refs[0].act = 0
	refs[1].act = 0
	refs[2].act = 0

	refs[0].target = 0
	refs[1].target = 0
	refs[2].target = 0

	refs[0].go = 0
	refs[1].go = 0
	refs[2].go = 0

	refs[0].newanim = TRUE
	refs[1].newanim = TRUE
	refs[2].newanim = TRUE

#******************************************************************************
#*****************************************************************************/

# void check_practice()
static func check_practice() -> void:
	if match_info.CompetitionType == PRACTICE:
		practice = 1
	else:
		practice = 0

	# (practice is an unsigned char: case(-1) can never match - kept as in C)
	match practice:
		0:
			team_a_on = TRUE
			team_b_on = TRUE

		1:
			team_a_on = TRUE
			team_b_on = FALSE

		-1:
			team_a_on = FALSE
			team_b_on = TRUE

#******************************************************************************
#*****************************************************************************/

# void init_team()
static func init_team() -> void:
	var i: int

	check_practice()

	for i1 in range(1, 23):
		i = i1
		Football.init_player_stats(i)
		if i == 2:
			teams[i - 1].tm_rate = 120
			teams[i - 1].tm_pow = 120
			teams[i - 1].tm_cont = 120
			teams[i - 1].tm_flair = 120
			teams[i - 1].tm_vis = 120
			teams[i - 1].tm_ac = 120
			teams[i - 1].tm_stam = 120
			teams[i - 1].tm_disc = 120

	for i2 in range(0, players / 2):
		i = i2
		if team_a_on:
			teams[i].tm_player = i + 1
			teams[i].tm_x = cntspot_x - prat * 2
			teams[i].tm_y = (cntspot_y + 10 * 24) - (i * 24)
			teams[i].tm_z = 0

			teams[i].tm_xdis = 1
			teams[i].tm_ydis = 0
			teams[i].tm_zdis = 0

			teams[i].mface = 0
			teams[i].tm_dist = 50
			teams[i].tm_pos = 1
			teams[i].tm_limbo = 0

			teams[i].guy_on = TRUE

			teams[i].control = 0
			teams[i].tm_srng = 0
			teams[i].tm_off = 0
			teams[i].tm_stopped = 0
			teams[i].tm_trap = 0
			teams[i].special = 0
			teams[i].tm_strike = 0
			teams[i].tm_stime = 0
			teams[i].tm_ftime = 0
			teams[i].ball_state = 0
			teams[i].tm_fpass_type = 0
			teams[i].tm_fpass_to = 0
			teams[i].draw_me = TRUE

			teams[i].shirt = i + 1

			teams[i].tm_book = 0
			teams[i].tm_fouls = 0
			teams[i].tm_tacks = 0
			teams[i].tm_twon = 0
			teams[i].tm_shots = 0
			teams[i].tm_saved = 0
			teams[i].tm_goals = 0
			teams[i].tm_pass = 0
			teams[i].tm_pwon = 0
			teams[i].tm_inj = 0
			teams[i].tm_posst = 0
			teams[i].tm_work = 0
			teams[i].tm_kpsaves = 0
			teams[i].tm_ogs = 0
			teams[i].tm_time = 0

			teams[i].turn_dir = 0
			teams[i].face_dir = 0
			teams[i].dir_mode = 0
			teams[i].tm_frm = 0
			teams[i].tm_fstep = MC_STAND_FS			# For intitialisation purposes.
			teams[i].tm_anim = MC_STAND
			teams[i].tm_hcol = 0
			teams[i].tm_htype = 0
			teams[i].tm_mcspd = float(teams[i].tm_flair + teams[i].tm_rate) / 128
			teams[i].ls_anim = 0
			teams[i].ls_frm = 0
			teams[i].contact = -1
			teams[i].tm_newanim = 1
			teams[i].tm_barge = 0

			teams[i].tm_act = 0
			teams[i].tm_poss = 0
			teams[i].tm_wall = 0
			teams[i].tm_leave = 0
			teams[i].tm_mark = 0
			teams[i].go_dist = 0
			teams[i].go_cnt = 0
			teams[i].go_txdis = 0
			teams[i].go_tydis = 0
			teams[i].go_tx = teams[i].tm_x
			teams[i].go_ty = teams[i].tm_y
			teams[i].go_xoff = 0
			teams[i].go_yoff = 0
			teams[i].tm_jump = PLAYER_HEIGHT + 6 + (teams[i].tm_pow / 10)
			teams[i].go_stop = 0
			teams[i].go_step = 0
			teams[i].tm_notme = 0

			teams[i].int_move = 0
			teams[i].int_cnt = 0
			teams[i].mess_num = 0
			teams[i].mess_cnt = 0
			teams[i].tm_comm = 0
			teams[i].tm_ccnt = 0
		else:
			teams[i].guy_on = FALSE
	for i3 in range(11, players):
		i = i3
		if team_b_on or i == 11:
#		if (team_b_on)

			teams[i].tm_player = i + 1
			teams[i].tm_x = cntspot_x + prat * 2
			teams[i].tm_y = (cntspot_y + 10 * 24) - ((i - 11) * 24)
			teams[i].tm_z = 0

			teams[i].tm_xdis = -1
			teams[i].tm_ydis = 0
			teams[i].tm_zdis = 0

			teams[i].mface = 0
			teams[i].tm_dist = 50
			teams[i].tm_pos = 1
			teams[i].tm_limbo = 0

			teams[i].guy_on = TRUE

			teams[i].control = 0
			teams[i].tm_srng = 0
			teams[i].tm_off = 0
			teams[i].tm_stopped = 0
			teams[i].tm_trap = 0
			teams[i].special = 0
			teams[i].tm_strike = 0
			teams[i].tm_stime = 0
			teams[i].tm_ftime = 0
			teams[i].ball_state = 0
			teams[i].tm_fpass_type = 0
			teams[i].tm_fpass_to = 0
			teams[i].draw_me = TRUE

			teams[i].shirt = i - 10

			teams[i].tm_book = 0
			teams[i].tm_fouls = 0
			teams[i].tm_tacks = 0
			teams[i].tm_twon = 0
			teams[i].tm_shots = 0
			teams[i].tm_saved = 0
			teams[i].tm_goals = 0
			teams[i].tm_pass = 0
			teams[i].tm_pwon = 0
			teams[i].tm_inj = 0
			teams[i].tm_posst = 0

			teams[i].turn_dir = 0
			teams[i].face_dir = 0
			teams[i].dir_mode = 0
			teams[i].tm_frm = 0
			teams[i].tm_fstep = MC_STAND_FS			# For intitialisation purposes.
			teams[i].tm_anim = MC_STAND
			teams[i].tm_hcol = 0
			teams[i].tm_htype = 0
			teams[i].tm_mcspd = float(teams[i].tm_flair + teams[i].tm_rate) / 128
			teams[i].ls_anim = 0
			teams[i].ls_frm = 0
			teams[i].contact = -1
			teams[i].tm_newanim = 1
			teams[i].tm_barge = 0

			teams[i].tm_act = 0
			teams[i].tm_poss = 0
			teams[i].tm_wall = 0
			teams[i].tm_leave = 0
			teams[i].tm_mark = 0
			teams[i].go_dist = 0
			teams[i].go_cnt = 0
			teams[i].go_txdis = 0
			teams[i].go_tydis = 0
			teams[i].go_tx = teams[i].tm_x
			teams[i].go_ty = teams[i].tm_y
			teams[i].go_xoff = 0
			teams[i].go_yoff = 0
			teams[i].tm_jump = PLAYER_HEIGHT + 6 + (teams[i].tm_pow / 10)
			teams[i].go_stop = 0
			teams[i].go_step = 0
			teams[i].tm_notme = 0

			teams[i].int_move = 0
			teams[i].int_cnt = 0
			teams[i].mess_num = 0
			teams[i].mess_cnt = 0
			teams[i].tm_comm = 0
			teams[i].tm_ccnt = 0

		else:
			teams[i].guy_on = FALSE
	Intell.reset_all_ideas()
	interceptor_a = 0
	interceptor_b = 0

#******************************************************************************
#*****************************************************************************/

# void taker_pass_f(float xp,float yp)
static func taker_pass_f(xp: float, yp: float) -> void:
	var t: int
	var dif: float
	var x: float
	var y: float
	var d: float
	var nx: float
	var ny: float

	t = (10 if setp_taker < 12 else 21)	# team-mates!
	pass_type = 0

	for i in range(t, t - 11, -1):
		if setp_taker != i + 1:
			# Not man on ball!
			if (teams[i].tm_act <= TURN_ACT) and (teams[i].guy_on > 0):
				# Not Busy!
				x = teams[i].tm_x - ballx
				y = teams[i].tm_y - bally
				d = Maths.calc_dist(x, y)

				dif = ((x * xp) + (y * yp)) / d
				if dif > FACING_ANGLE:
					pass_type = Intell.in_kicking_range(teams[setp_taker - 1], x, y)

				if pass_type:
					Intell.make_pass(teams[setp_taker - 1], i + 1, FALSE)
					Rules.ready_set_kick()
					break

	if not pass_type:
		setp_kick_x = xp
		setp_kick_y = yp
		must_pass = 10
		nx = (xp * teams[setp_taker - 1].tm_xdis) + (yp * teams[setp_taker - 1].tm_ydis)
		ny = (yp * teams[setp_taker - 1].tm_xdis) - (xp * teams[setp_taker - 1].tm_ydis)
		pass_type = (1 + Intell.get_dir(nx, ny))
		Intell.make_pass(teams[setp_taker - 1], 0, FALSE)
		Rules.ready_set_kick()

#******************************************************************************
#*****************************************************************************/

# void taker_pass_h(float xp,float yp)
static func taker_pass_h(xp: float, yp: float) -> void:
	chip_pass = TRUE
	var t: int
	var dif: float
	var x: float
	var y: float
	var d: float
	var nx: float
	var ny: float

	t = (10 if setp_taker < 12 else 21)	# team-mates!
	pass_type = 0

	for i in range(t, t - 11, -1):
		if setp_taker != i + 1:
			# Not man on ball!
			if (teams[i].tm_act <= TURN_ACT) and (teams[i].guy_on > 0):
				# Not Busy!
				x = teams[i].tm_x - ballx
				y = teams[i].tm_y - bally
				d = Maths.calc_dist(x, y)

				dif = ((x * xp) + (y * yp)) / d
				if dif > FACING_ANGLE:
					pass_type = Intell.in_kicking_range(teams[setp_taker - 1], x, y)
					if pass_type != 5 and pass_type != -1:
						pass_type = 0
					else:
						pass_type = -1

				if pass_type:
					Intell.make_pass(teams[setp_taker - 1], i + 1, FALSE)
					Rules.ready_set_kick()
					break
	if not pass_type:
		setp_kick_x = teams[setp_taker - 1].tm_xdis
		setp_kick_y = teams[setp_taker - 1].tm_ydis
		must_pass = TRUE
		pass_type = -1
		Intell.make_pass(teams[setp_taker - 1], 0, FALSE)
		Rules.ready_set_kick()

#******************************************************************************
#*****************************************************************************/

# void taker_tee_up(float x,float y)
static func taker_tee_up(x: float, y: float) -> void:
	taker_pass_f(x, y)
	must_shoot = TRUE
	must_punt = TRUE

#******************************************************************************
#*****************************************************************************/

# void taker_kick(float x,float y)
static func taker_kick(x: float, y: float) -> void:
	if teams[setp_taker - 1].tm_srng:
		# In shooting range...
		if spec_kick_type == SPACT_DRIVE:
			drive_shot = TRUE

		pass_type = -1
		Intell.make_shoot(teams[setp_taker - 1])
		Rules.ready_set_kick()
	else:
		Intell.make_punt(teams[setp_taker - 1])
		Rules.ready_set_kick()

#******************************************************************************
#*****************************************************************************/

# void taker_chip(float x,float y)
static func taker_chip(x: float, y: float) -> void:
	setp_kick_x = teams[setp_taker - 1].tm_xdis
	setp_kick_y = teams[setp_taker - 1].tm_ydis
	chip_pass = TRUE
	must_pass = TRUE
	pass_type = -1
	Intell.make_pass(teams[setp_taker - 1], 0, FALSE)
	Rules.ready_set_kick()

#******************************************************************************
#*****************************************************************************/

# void taker_grnd(float x,float y)
static func taker_grnd(x: float, y: float) -> void:
	setp_kick_x = teams[setp_taker - 1].tm_xdis
	setp_kick_y = teams[setp_taker - 1].tm_ydis
	chip_pass = FALSE
	must_pass = TRUE
	pass_type = 5
	Intell.make_pass(teams[setp_taker - 1], 0, FALSE)
	Rules.ready_set_kick()

#******************************************************************************
#*****************************************************************************/

# #ifdef SUPPORT_LP  (not compiled: SUPPORT_LP is false; the function is kept so that
#                    the `if SUPPORT_LP:` call sites resolve)

# #define ROTATE_ANG (0.16)   -> const at the top of this part

# void rotate_lp(match_player *player)
static func rotate_lp(player: match_player) -> void:
	var ox: float = player.tm_xdis
	var oy: float = player.tm_ydis

	var rot: float = 0

	var fire: int = users_dir[user_controlled - 1].f

	if not (fire & LP_L and fire & LP_R):
		# Not both shoulder buttons...
		if fire & LP_L:
			rot = -ROTATE_ANG

		if fire & LP_R:
			rot = ROTATE_ANG

		player.tm_xdis = (ox * cos(rot)) - (oy * sin(rot))
		player.tm_ydis = (oy * cos(rot)) + (ox * sin(rot))
		player.tm_x = ballx - (player.tm_xdis * 8)
		player.tm_y = bally - (player.tm_ydis * 8)
# #endif

#******************************************************************************
#*****************************************************************************/

# void rotate_around_ball(match_player *player)
static func rotate_around_ball(player: match_player) -> void:
	if um:
		var x: float = ballx - (ux * 8)
		var y: float = bally - (uy * 8)
		player.tm_x = x
		player.tm_y = y
		player.tm_xdis = ux
		player.tm_ydis = uy

#******************************************************************************
#*****************************************************************************/

# void taker_nkick()
static func taker_nkick() -> void:
	newk_shot = TRUE
	teams[setp_taker - 1].tm_xdis = setp_kick_x
	teams[setp_taker - 1].tm_ydis = setp_kick_y
	pass_type = -1
	Intell.make_shoot(teams[setp_taker - 1])
	Rules.ready_set_kick()

#******************************************************************************
#*****************************************************************************/

# void draw_tracker(short mp,float x,float y)
static func draw_tracker(mp: int, x: float, y: float) -> void:
	# static float fract=0;  -> draw_tracker__fract
	var bspeed: float = Intell.get_power()
	ballxdis = x * bspeed
	ballydis = y * bspeed
	ballzdis = Intell.get_traj()
	ball_inair = TRUE
	ball_poss = FALSE

	BallInt.predict_ball()
	ballxdis = 0
	ballydis = 0
	ballzdis = 0
	ball_inair = FALSE
	ball_poss = setp_taker

	var xp: float
	var yp: float
	var zp: float

	# Draw tracker...
	var i: int = 0
	while (i < first_bounce or i < mp):
		# Marker...
		xp = ball_pred_tab[i][0]
		yp = ball_pred_tab[i][1]
		zp = ball_pred_tab[i][2]
		xp = xp + (draw_tracker__fract * (ball_pred_tab[i + 1][0] - xp))
		yp = yp + (draw_tracker__fract * (ball_pred_tab[i + 1][1] - yp))
		zp = zp + (draw_tracker__fract * (ball_pred_tab[i + 1][2] - zp))

		# Dot...
		Display.add_pitch_sprite(int(xp), int(yp), int(zp), 0)

		# Shadow...
		Display.add_pitch_sprite(int(xp), int(yp), 0, 1)
		i += 1

	draw_tracker__fract += 0.2
	if draw_tracker__fract >= 1:
		draw_tracker__fract = 0

#******************************************************************************
#*****************************************************************************/

# void init_runup_act(match_player *player)
static func init_runup_act(player: match_player) -> void:
	init_run_act(player, ballx, bally, TRUE)
	player.int_move = I_RUNUP
	player.int_cnt = player.go_cnt
	if player.int_cnt > 0:
		player.int_cnt -= 1

#******************************************************************************
#*****************************************************************************/

# void user_runup(match_player *player)
static func user_runup(player: match_player) -> void:
	var c: int = player.int_cnt
	player.int_cnt -= 1
	if not c:
		# End of runup...
		spec_kick_type = SPACT_NEWK
		taker_nkick()
	else:
		go_forward(player)

#******************************************************************************
#*****************************************************************************/

# #define ROT_SPEED (0.05)   -> const at the top of this part

# void new_user_spec_kick(match_player *player)
static func new_user_spec_kick(player: match_player) -> void:
	if player.int_move == I_RUNUP:
		user_runup(player)
	else:
		var x: float = setp_kick_x
		var y: float = setp_kick_y

		# Player's maximum power of shot...
		var max_pow: int = (player.tm_pow / 6) + 8

		var xd: float
		var yd: int

		# Read unvectored user controls...
		if users_dir[user_controlled - 1].f & 8:
			xd = -ROT_SPEED * ((max_pow) / (setp_power + 6))
		else:
			if users_dir[user_controlled - 1].f & 4:
				xd = ROT_SPEED * ((max_pow) / (setp_power + 6))
			else:
				xd = 0

		if users_dir[user_controlled - 1].f & 32:
			yd = 1
		else:
			if users_dir[user_controlled - 1].f & 16:
				yd = -1
			else:
				yd = 0

		if not uf2:
			# Not trying pass...

			# Rotate player based on (left,right action)...
			setp_kick_x = (x * cos(xd)) - (y * sin(xd))
			setp_kick_y = (y * cos(xd)) + (x * sin(xd))
			var d: float = Maths.calc_dist(setp_kick_x, setp_kick_y)
			setp_kick_x = setp_kick_x / d
			setp_kick_y = setp_kick_y / d

			# Adjust run-up based on (up,down action)...
			setp_power += yd
			if setp_power < 0:
				setp_power = 0
			else:
				if setp_power > max_pow:
					setp_power = max_pow

		# Where should he be...
		setp_x = ballx - (setp_kick_x * (setp_power + 2) * 2)
		setp_y = bally - (setp_kick_y * (setp_power + 2) * 2)

		init_run_act(player, setp_x, setp_y, TRUE)
		if player.tm_act == RUN_ACT:
			go_forward(player)
		else:
			player.tm_x = setp_x
			player.tm_y = setp_y
			player.tm_xdis = setp_kick_x
			player.tm_ydis = setp_kick_y

		if uf1:
			# Shoot button held...
			setp_hgt += 1
			if setp_hgt > 30:
				setp_hgt -= 1
		else:
			if setp_hgt:
				# Shoot button has been released...
				init_runup_act(player)

			if uf2:
				if setp_power or Maths.calc_dist(player.tm_x - setp_x, player.tm_y - setp_y) > 1:
					setp_power = 0
				else:
					# At ball... Ready to pass...
					if not f2_down:
						f2_down = 1
			else:
				if f2_down:
					# uf2 released...
					if um:
						# (uf2 + d)...
						if uf1:
							spec_kick_type = SPACT_TEE_UP	# Tee up for shot or punt!
						else:
							spec_kick_type = SPACT_DPASS	# Disguised Pass!
					else:
						spec_kick_type = SPACT_FPASS	# Pass to feet!

		if not f2_down and setp_power:
			draw_tracker(max_pow / 2, setp_kick_x, setp_kick_y)

		match spec_kick_type:
			SPACT_FPASS:
				taker_pass_f(player.tm_xdis, player.tm_ydis)

			SPACT_HPASS:
				taker_pass_h(player.tm_xdis, player.tm_ydis)

			SPACT_TEE_UP:
				taker_tee_up(users_dir[user_controlled - 1].x, users_dir[user_controlled - 1].y)

			SPACT_DPASS:
				taker_pass_f(users_dir[user_controlled - 1].x, users_dir[user_controlled - 1].y)

			SPACT_GRND:
				taker_grnd(player.tm_xdis, player.tm_ydis)

			SPACT_CHIP:
				taker_chip(player.tm_xdis, player.tm_ydis)

			SPACT_DRIVE:
				taker_kick(player.tm_xdis, player.tm_ydis)

			SPACT_KICK:
				taker_kick(player.tm_xdis, player.tm_ydis)

			SPACT_NEWK:
				taker_nkick()

#******************************************************************************
#*****************************************************************************/

# void user_pen_kick(match_player *player,char user_guy)
static func user_pen_kick(player: match_player, user_guy: int) -> void:
	var ydif: float
	var racc: float

	if player.int_move == I_RUNUP:
		user_runup(player)
	else:
		if player.tm_player < 12:
			setp_bxd = pitch_len
		else:
			setp_bxd = 0

		var x: float
		var y: float
		var d: float
		var acc: float = (128.0 - player.tm_ac) / 4
		var skill: float = (160.0 - player.tm_flair) / 16
		setp_power = (player.tm_pow / 8) + 10

		if f2_down < 0:
			setp_byd -= skill
			if setp_byd < (top_post_y - acc):
				f2_down = 1
		else:
			setp_byd += skill
			if setp_byd > (bot_post_y + acc):
				f2_down = -1

		# Derive vector from point on goal-line...
		x = setp_bxd - ballx
		y = setp_byd - bally
		d = Maths.calc_dist(x, y)
		setp_kick_x = x / d
		setp_kick_y = y / d

		if not user_guy:
			# Computer intelligence...
			if not f1_down:
				# Not started kick yet...
				Maths.af_randomize()
				if seed > (92 + ((128 - player.tm_flair) / 8)):
					# Decides to kick...
					Maths.af_randomize()
					if seed > (player.tm_flair / 2):
						# Aim low... (not very spectacular)
						setp_bzd = 4
					else:
						# Aim High... (Spectacular attempt)
						setp_bzd = 16

					if f2_down < 0:
						# Targeter moving upward...
						ydif = setp_byd - (top_post_y + (ball_diam * 2) + skill)
					else:
						# Targeter moving downward...
						ydif = (bot_post_y - (ball_diam * 2) - skill) - setp_byd

					if ABS((ydif / skill) - setp_bzd) < 1:
						uf1 = TRUE
						Maths.af_randomize()
						setp_bzd += ((acc - (acc * seed / 64))) / 2
						if setp_bzd < 1:
							setp_bzd = 1
			else:
				if f1_down > (setp_bzd - 1):
					uf1 = FALSE
				else:
					uf1 = TRUE

		# Under user control...
		if uf1:
			f1_down += 1
			if (f1_down) > 30:
				f1_down = 30
			setp_hgt = f1_down
		else:
			if f1_down:
				init_runup_act(player)
				penalty_shot = TRUE
		draw_tracker(int(setp_power / 2), setp_kick_x, setp_kick_y)

#******************************************************************************
#*****************************************************************************/

# void user_spec_kick(match_player *player)
static func user_spec_kick(player: match_player) -> void:
	setp_taker = player.tm_player
	if uf1 and uf2:
		# Both buttons held...
		if um and not f1_down and not f2_down:
			# Both pressed together...(take F1!)
			spec_kick_type = SPACT_DRIVE		# Driving shot or punt!
	else:
		if f2_down and f1_down:
			# Both buttons held...
			if not uf1:
				# Both buttons were held but f1 released...
				if um:
					# Direction selected...
					spec_kick_type = SPACT_TEE_UP	# Tee up for shot or punt!
				else:
					# No Direction...
					spec_kick_type = SPACT_CHIP		# Power Chip into air!
			else:
				if not uf2:
					# Both buttons were held but f2 released...
					if um:
						# Direction selected...
						spec_kick_type = SPACT_DPASS	# Disguised pass!
					else:
						# No Direction...
						spec_kick_type = SPACT_HPASS	# Pass to head!
		else:
			if f1_down:
				# F1 held down only...
				if not uf1:
					# F1 now released...
					if um:
						# Direction selected...
						spec_kick_type = SPACT_TEE_UP	# Tee up for shot or punt!
					else:
						# No Direction...
						spec_kick_type = SPACT_DRIVE	# Driving shot or punt(no swerve)!
			else:
				if f2_down:
					# F2 held down only...
					if not uf2:
						# F2 now released...
						if um:
							# Direction selected...
							spec_kick_type = SPACT_DPASS	# Disguised Pass!
						else:
							# No Direction...
							spec_kick_type = SPACT_GRND		# Power kick along ground!
				else:
					# No buttons held...
					if uf1 and um:
						# F1 pressed initialy with dir...
						spec_kick_type = SPACT_KICK		# Shoot or punt!
					else:
						if uf2 and um:
							# F2 pressed initialy with dir...
							spec_kick_type = SPACT_FPASS	# Pass to feet!

	if not um:
		if uf2:
			if not f2_down and f1_down:
				f2_down = 1

			f2_down += 1
			if f2_down > 30:
				f2_down = 30

		if uf1:
			if not f1_down and f2_down:
				f2_down = 1

			f1_down += 1
			if f1_down > 30:
				f1_down = 30

		if f1_down:
			setp_power = f1_down
		else:
			setp_power = f2_down

		setp_bxd = (player.tm_xdis * (setp_power + 4) * (128 + teams[ball_poss - 1].tm_pow)) * 0.5 / 256
		setp_byd = (player.tm_ydis * (setp_power + 4) * (128 + teams[ball_poss - 1].tm_pow)) * 0.5 / 256
		setp_bzd = (setp_power / 4) + 4

		if SUPPORT_LP:
			if not uf1 and not uf2 and not f1_down and not f2_down and set_piece_on:
				rotate_lp(player)

	else:
		if not uf1 and not uf2 and not f1_down and not f2_down and set_piece_on:
			rotate_around_ball(player)

	match spec_kick_type:
		SPACT_FPASS:
			taker_pass_f(player.tm_xdis, player.tm_ydis)

		SPACT_HPASS:
			taker_pass_h(player.tm_xdis, player.tm_ydis)

		SPACT_TEE_UP:
			taker_tee_up(users_dir[user_controlled - 1].x, users_dir[user_controlled - 1].y)

		SPACT_DPASS:
			taker_pass_f(users_dir[user_controlled - 1].x, users_dir[user_controlled - 1].y)

		SPACT_GRND:
			taker_grnd(player.tm_xdis, player.tm_ydis)

		SPACT_CHIP:
			taker_chip(player.tm_xdis, player.tm_ydis)

		SPACT_DRIVE:
			taker_kick(player.tm_xdis, player.tm_ydis)

		SPACT_KICK:
			taker_kick(player.tm_xdis, player.tm_ydis)

#******************************************************************************
#*****************************************************************************/

# void user_limited_kick(match_player *player)
static func user_limited_kick(player: match_player) -> void:
	# Limited for penalty...

	setp_taker = player.tm_player

	if um:
		# Directional...
		if uf1:
			spec_kick_type = SPACT_KICK			# Shoot!
	else:
		if uf1:
			spec_kick_type = SPACT_DRIVE		# Driving shot!

	setp_power = (player.tm_pow / 6) + 8
	setp_bxd = (player.tm_xdis * (setp_power + 4) * (128 + teams[ball_poss - 1].tm_pow)) * 0.5 / 256
	setp_byd = (player.tm_ydis * (setp_power + 4) * (128 + teams[ball_poss - 1].tm_pow)) * 0.5 / 256
	setp_bzd = (setp_power / 4) + 4

	if not uf1 and not f1_down and set_piece_on:
		rotate_around_ball(player)

	match spec_kick_type:
		SPACT_DRIVE:
			penalty_shot = TRUE
			taker_kick(player.tm_xdis, player.tm_ydis)

		SPACT_KICK:
			penalty_shot = TRUE
			taker_kick(player.tm_xdis, player.tm_ydis)

#******************************************************************************
#*****************************************************************************/

# void comp_set_piece(match_player *player)
static func comp_set_piece(player: match_player) -> void:
	if refs[0].act == 2:
		user_pen_kick(player, FALSE)

#******************************************************************************
#*****************************************************************************/

# void user_set_piece(match_player *player)
static func user_set_piece(player: match_player) -> void:
	user_conts(teams[player_num - 1])

	if STOP_TIME_WASTING:
		if ref_wait < 0:
			# Force strike on ball (Time-up)...
			uf1 = TRUE
			uf2 = TRUE
			um = TRUE
			ux = player.tm_xdis
			uy = player.tm_ydis

	if ref_wait:

		match match_mode:
			IF_KICK_A, IF_KICK_B, DF_KICK_A, DF_KICK_B, CORNER_TL, CORNER_BL, CORNER_TR, CORNER_BR, GOAL_KICK_TL, GOAL_KICK_BL, GOAL_KICK_TR, GOAL_KICK_BR, CENTRE_A, CENTRE_B:

				if not EURO96:
					user_spec_kick(player)
				else:
					new_user_spec_kick(player)

			PEN_KICK_A, PEN_KICK_B:
				if EURO96:
					user_pen_kick(player, TRUE)
				else:
					user_limited_kick(player)

#******************************************************************************
#*****************************************************************************/

# void init_throw_act(match_player *player)
static func init_throw_act(player: match_player) -> void:
	last_touch = player.tm_player
	player.tm_anim = MC_THROWL
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_THROWL_FS

	player.dir_mode = 2
	player.go_txdis = 0
	player.go_tydis = 0
	player.tm_act = THROW_ACT
	player.tm_xdis = 0
	if player.tm_player < 12:
		player.turn_dir = 1
	else:
		player.turn_dir = -1

	if bally < cntspot_y:
		player.tm_ydis = 1
	else:
		player.tm_ydis = -1
	throw_cnt = 90

	support_me = TRUE

#******************************************************************************
#*****************************************************************************/

# void init_get_up(match_player *player,float fs)
static func init_get_up(player: match_player, fs: float) -> void:
	player.int_cnt = int(1 + (1.0 / fs))
	player.int_move = I_GET_UP
	player.dir_mode = 2			# Don't turn!

#******************************************************************************
#*****************************************************************************/

# void init_pickup_act(match_player *player)
static func init_pickup_act(player: match_player) -> void:
	Intell.reset_ideas(player)
	player.tm_act = PICKUP_ACT
	init_anim(player, MC_PICKBALL)
	player.int_move = I_GET_UP			# Look like he is busy!
	player.int_cnt = int(1 / MC_PICKBALL_FS)

#******************************************************************************
#*****************************************************************************/

# void pickup_action(match_player *player)
static func pickup_action(player: match_player) -> void:
	if not player.int_cnt:
		# end of animation...
		if player.tm_anim == MC_PICKBALL:
			init_anim(player, MC_STANDB)
			ball_in_hands = TRUE
			if player.tm_player == KP_A or player.tm_player == KP_B:
				player.dir_mode = 2
				init_kphold_act(player)

#******************************************************************************
#*****************************************************************************/

# void init_taunt_act(match_player *player)
static func init_taunt_act(player: match_player) -> void:
	# Stationary taunt...

	player.tm_act = CELEB_ACT
	player.go_txdis = 0
	player.go_tydis = 0
	player.dir_mode = 2

	if player.tm_player == goal_scorer:
		scorer_running = FALSE
		# Choose Taunt...
		Maths.af_randomize()
		if seed & 2:
			# Knee slide...
			init_anim(player, MC_KNEE)
			player.go_txdis = player.tm_xdis * 3
			player.go_tydis = player.tm_ydis * 3
			player.go_cnt = int(1 / MC_KNEE_FS)
		else:
			# Taunt...
			Maths.af_randomize()
			var r: int = 0
			if user_scorer:
				# User selects celebration...
				# (C: `while(...);` has an EMPTY body and r is never changed: if the bit is set
				#  this never terminates. Compiled exactly like this in the original object code.)
				while ((users_dir[user_scorer - 1].f) >> 2) & (1 << r):
					pass
				r -= 1
			else:
				# Computer is random...
				r = Maths.rand_range(4)

			match Maths.rand_range(4):
				0:
					init_anim(player, MC_REEVES)

				1:
					init_anim(player, MC_BABY)

				2:
					init_anim(player, MC_PUMP)

				3:
					init_anim(player, MC_MILLER)
	else:
		# Do whatever goal scorer is doing...
		if teams[goal_scorer - 1].tm_anim == MC_KNEE or teams[goal_scorer - 1].tm_anim == MC_DUCK:
			init_anim(player, MC_KNEE)
			player.go_txdis = player.tm_xdis * 3
			player.go_tydis = player.tm_ydis * 3
			player.go_cnt = int(1 / MC_KNEE_FS)
		else:
			if teams[goal_scorer - 1].tm_anim >= MC_KNEE and teams[goal_scorer - 1].tm_anim <= MC_REEVES:
				init_anim(player, teams[goal_scorer - 1].tm_anim)
				if player.tm_anim == MC_MOON:
					player.go_txdis = -player.tm_xdis
					player.go_tydis = -player.tm_ydis
			else:
				init_anim(player, MC_CELEB)

#******************************************************************************
#*****************************************************************************/

# void init_run_celeb(match_player *player,float tx,float ty)
static func init_run_celeb(player: match_player, tx: float, ty: float) -> void:
	# Moving celebration...
	player.int_move = I_CELEB
	init_run_act(player, tx, ty, TRUE)
	if player.tm_act != RUN_ACT:
		init_taunt_act(player)
	else:
		Maths.af_randomize()
		if player.tm_player == goal_scorer:
			scorer_running = TRUE
			match seed & 1:
				0:
					init_anim(player, MC_FINGER)

				1:
					init_anim(player, MC_PLANE)
		else:
			init_anim(player, MC_FINGER)

		player.int_cnt = player.go_cnt + 1

#******************************************************************************
#*****************************************************************************/

# void init_stationary_celeb(match_player *player)
static func init_stationary_celeb(player: match_player) -> void:
	# Stationary celebration...
	player.tm_act = CELEB_ACT
	player.go_txdis = player.tm_xdis
	player.go_tydis = player.tm_ydis
	player.go_txdis = 0
	player.go_tydis = 0
	player.dir_mode = 2

#******************************************************************************
#*****************************************************************************/

# #define CELEB_RUN_DIST (13*prat)
static func CELEB_RUN_DIST() -> float:
	return (13 * prat)

# void init_celeb_act(match_player *player)
static func init_celeb_act(player: match_player) -> void:
	Intell.reset_ideas(player)			# Stop interception etc.

	var celeb: int = seed & 1

	if not EURO96:
		init_anim(player, MC_CELEB)

	if player.tm_anim == MC_CELEB:
		init_stationary_celeb(player)
	else:
		if (player.tm_player == goal_scorer or
			 (player.tm_player != goal_scorer and teams[goal_scorer - 1].tm_act == RUN_ACT)):
			if player.tm_player != goal_scorer:
				# Run towards goal scorer...
				var x: float = teams[goal_scorer - 1].tm_x
				var y: float = teams[goal_scorer - 1].tm_y
				Maths.af_randomize()
				x += (seed - 64) / 2
				Maths.af_randomize()
				y += (seed - 64) / 2
				init_run_celeb(player, x, y)
			else:
				var a: float = 0.0
				var b: float = 0.0
				var x: float = player.tm_x
				var y: float = player.tm_y
				Maths.af_randomize()
				var rv: Array = Maths.random_vector(a, b)
				a = rv[0]
				b = rv[1]
				x += (a * CELEB_RUN_DIST())
				y += (b * CELEB_RUN_DIST())

				if x < 0:
					if x < -CELEB_RUN_DIST():
						init_anim(player, MC_CELEB)
					else:
						x = player.tm_x + (player.tm_x - x)

				if x > pitch_len:
					if x > (CELEB_RUN_DIST() + pitch_len):
						init_anim(player, MC_CELEB)
					else:
						x = player.tm_x + (player.tm_x - x)

				if y < 0:
					if y < -CELEB_RUN_DIST():
						init_anim(player, MC_CELEB)
					else:
						y = player.tm_y + (player.tm_y - y)

				if y > pitch_wid:
					if y > (CELEB_RUN_DIST() + pitch_wid):
						init_anim(player, MC_CELEB)
					else:
						y = player.tm_y + (player.tm_y - y)

				if player.tm_anim == MC_CELEB:
					init_taunt_act(player)
				else:
					init_run_celeb(player, x, y)
		else:
			# Goal scorer will be doing his party piece! (follow suit)...
			init_taunt_act(player)

#******************************************************************************
#*****************************************************************************/

# void celeb_action(match_player *player)
static func celeb_action(player: match_player) -> void:
	player.tm_x += player.go_txdis
	player.tm_y += player.go_tydis

	if player.tm_anim == MC_KNEE:
		player.go_txdis *= 0.94
		player.go_tydis *= 0.94

		player.go_cnt -= 1
		if (player.go_cnt) < 1:
			# Do the Duck!!!
			init_anim(player, MC_DUCK)
			player.go_txdis = player.tm_xdis * MC_DUCK_SPD
			player.go_tydis = player.tm_ydis * MC_DUCK_SPD

	if not just_scored:
		init_stand_act(player)

#******************************************************************************
#*****************************************************************************/

# void init_stand_act(match_player *player)
static func init_stand_act(player: match_player) -> void:
	player.contact = -1
	var ac: int = player.tm_act
	if ac == SAVE_ACT:
		keep_dive = FALSE
	Intell.reset_ideas(player)			# Stop interception etc.
	player.ls_anim = ABS(player.tm_anim)	# last anim stored!
	player.ls_frm = player.tm_frm - player.tm_fstep

	player.tm_act = STAND_ACT
	player.go_txdis = player.tm_xdis
	player.go_tydis = player.tm_ydis
	player.go_txdis = 0
	player.go_tydis = 0
	player.dir_mode = 1

	if player.tm_player == KP_A or player.tm_player == KP_B:
		if keeper_down and ac == SAVE_ACT:
			# This keeper is on ground...
			if ball_in_hands and ball_poss == player.tm_player:
				# Guy has ball in hands...
				if keeper_down < 0:
					# Keeper lying left...
					init_anim(player, MC_STOSBL)
					player.tm_fstep *= (keeper_spd * 2)
					init_kphold_act(player)
					init_get_up(player, player.tm_fstep)
				else:
					if keeper_down == 1:
						# Keeper lying right...
						init_anim(player, MC_STOSBR)
						player.tm_fstep *= (keeper_spd * 2)
						init_kphold_act(player)
						init_get_up(player, player.tm_fstep)
					else:
						# Keeper forward crouched...
						init_anim(player, MC_CRTOSTB)
						player.tm_fstep *= (keeper_spd * 2)
						init_kphold_act(player)
						init_get_up(player, player.tm_fstep)
			else:
				# Doesn't have ball...
				if keeper_down < 0:
					# Keeper lying left...
					init_anim(player, MC_STOSL)
					player.tm_fstep *= (keeper_spd * 2)
					init_get_up(player, player.tm_fstep)
				else:
					# Keeper lying right...
					init_anim(player, MC_STOSR)
					player.tm_fstep *= (keeper_spd * 2)
					init_get_up(player, player.tm_fstep)

			keeper_down = 0
		else:
			# Keeper standing up...
			if ball_in_hands and ball_poss == player.tm_player:
				# Has ball...
				init_anim(player, MC_STANDB)
				init_kphold_act(player)
			else:
				# Doesn't have ball...
				if match_mode == PEN_KICK_A or match_mode == PEN_KICK_B:
					init_anim(player, MC_PENALTY)
				else:
					init_anim(player, MC_STAND)
	else:
		init_anim(player, MC_STAND)

#******************************************************************************
#*****************************************************************************/

# void init_steal_act(match_player *player)
static func init_steal_act(player: match_player) -> void:
	player.tm_act = STEAL_ACT
	player.go_txdis = player.tm_xdis
	player.go_tydis = player.tm_ydis
	player.dir_mode = 1
	init_anim(player, MC_PASSL)
	Intell.reset_ideas(player)			# Stop interception etc.

#******************************************************************************
#*****************************************************************************/

# void init_kphold_act(match_player *player)
static func init_kphold_act(player: match_player) -> void:
	keep_timer = 6 * REAL_SPEED

	player.tm_act = KPHOLD_ACT

	player.dir_mode = 3

	Intell.reset_ideas(player)			# Stop interception etc.
	keeper_steps = int(1.0 / MC_RUNWITHB_FS)

#******************************************************************************
#*****************************************************************************/

# float angle_to_target(match_player *player)
static func angle_to_target(player: match_player) -> float:
	var x: float = player.go_xoff
	var y: float = player.go_yoff

	var d: float = Maths.calc_dist(x, y)

	# get new normalised vector.
	var nx: float = x / d
	var ny: float = y / d

	var ox: float = player.tm_xdis
	var oy: float = player.tm_ydis

	# get difference (cos a).
	var dif: float = ((nx * ox) + (ny * oy))

	if dif > 1.0:
		dif = 1

	if dif < -1.0:
		dif = -1

	return (dif)

#******************************************************************************
#*****************************************************************************/

# float angle_to_xy(float a,float b,float x,float y)
static func angle_to_xy(a: float, b: float, x: float, y: float) -> float:
	var d: float = Maths.calc_dist(a, b)

	# get new normalised vector.
	var nx: float = a / d
	var ny: float = b / d

	d = Maths.calc_dist(x, y)

	var ox: float = x / d
	var oy: float = y / d

	# get difference (cos a).
	var dif: float = ((nx * ox) + (ny * oy))

	if dif > 1.0:
		dif = 1

	if dif < -1.0:
		dif = -1

	return (dif)

#******************************************************************************
#*****************************************************************************/

# void init_stand_anims(match_player *player)
static func init_stand_anims(player: match_player) -> void:
	var p: int = player.tm_player
	if p == KP_A or p == KP_B:
		# Goal-keeper...
		if ball_in_hands and ball_poss == p:
			# In keeper's hands...
			init_anim(player, MC_STANDB)
		else:
			init_anim(player, MC_STAND)
	else:
		init_anim(player, MC_STAND)

#******************************************************************************
#*****************************************************************************/

# void init_trot_anims(match_player *player)
static func init_trot_anims(player: match_player) -> void:
	init_anim(player, MC_TROTA)

#******************************************************************************
#*****************************************************************************/

# void init_run_anims(match_player *player)
static func init_run_anims(player: match_player) -> void:
	var p: int = player.tm_player

	if p == KP_A or p == KP_B:
		# Goal-keeper...
		if ball_in_hands and ball_poss == p:
			# In keeper's hands...
			init_anim(player, MC_RUNWITHB)
		else:
			init_anim(player, MC_RUN)

	else:
		init_anim(player, MC_RUN)

#******************************************************************************
#*****************************************************************************/

# void init_run_act(match_player *player,float tx,float ty,char s)
static func init_run_act(player: match_player, tx: float, ty: float, s: int) -> void:
	player.mface = FALSE

	# Setup target coords...
	player.go_tx = tx
	player.go_ty = ty

	# Setup target offset...
	var x: float = tx - player.tm_x
	var y: float = ty - player.tm_y
	player.go_xoff = x
	player.go_yoff = y

	var d: float = Maths.calc_dist(x, y)		# How far is target!

	if d < IM_THERE_DIST:
		# He is there already...
		player.tm_x = tx
		player.tm_y = ty
		init_stand_act(player)
	else:
		# Got to travel...

		# Angle facing towards target...
		var a: float = angle_to_xy(x, y, player.tm_xdis, player.tm_ydis)

		# MAX_TURN = ((14+(float)player->tm_rate/8)*PI/180)
		if a >= cos(((14.0 + float(player.tm_rate) / 8.0) * PI / 180.0)):
			# He is facing target??? (no need to side step!)
			player.go_step = FALSE
			if s:
				s = 2

		# Now! Should he be side-stepping???
		if s and ((player.go_step and d < STEP_RANGE * 2) or (not player.go_step and d < STEP_RANGE)):
			# Jog now!
			player.go_stop = FALSE
			player.go_step = TRUE
			player.go_cnt = int(d / actual_spd(player) + 1)
			player.go_txdis = x / player.go_cnt
			player.go_tydis = y / player.go_cnt
			init_trot_anims(player)
			if s == TRUE:
				player.dir_mode = 1		# Face ball.
			else:
				player.dir_mode = 0		# Face target.
		else:
			# Run now!
			player.go_step = FALSE
			player.go_cnt = Intell.get_there_time(player.tm_player, tx, ty)
			if player.go_cnt >= 2000:
				init_stand_act(player)
			else:
				player.go_cnt -= must_face_time

			player.mface_x = x_face
			player.mface_y = y_face		# Direction he will be facing at target point!

			if must_face:
				# Must get to a target and then face in a certain dir...
				player.mface = TRUE
				player.mface_time = must_face_time

			if stop_and_face:
				# Quickest way to get to target is to stop and turn then run straight...

				player.go_stop = TRUE

				var tt: int = int(ABS(acos(a) / ((14.0 + float(player.tm_rate) / 8.0) * PI / 180.0)))		# time to turn!

				# Displacement vectors after turning...
				player.go_txdis = x / (player.go_cnt - tt)
				player.go_tydis = y / (player.go_cnt - tt)
				init_stand_anims(player)
			else:
				player.go_stop = FALSE

				# Displacement points to target... (not current though!)
				player.go_txdis = x / player.go_cnt
				player.go_tydis = y / player.go_cnt
				init_run_anims(player)

			player.dir_mode = 0		# Face target.

			if user_controlled and uf2:
				# Run Fast (user only!)...
				player.go_txdis = player.go_txdis * 1.2
				player.go_tydis = player.go_tydis * 1.2
		player.tm_act = RUN_ACT




#/*
#// How long to get there...
#	player->go_cnt=get_there_time(player->tm_player,tx,ty);
#
#// Face target coords mode...
#	player->dir_mode=0;
#
#	if ((ABS(x)<=.1) && (ABS(y)<=.1))
#	{
#		if ((user_controlled) && (ball_poss==player->tm_player))
#			init_stand_act(player);
#		else
#			init_stand_act(player);
#	}
#	else
#	{
#		if (player->tm_player==3)
#			player->tm_player=3;
#
#		if (!shall_i_turn(player,x,y,s))		// Turn if need be (maybe step)!
#		{
#			float dist=calc_dist(x,y);
#			player->go_dist=(int)dist;
#			if (!player->go_step)
#			{
#// Player not trotting...
#				if ((!ball_in_hands) && ((player->int_move==I_INTERCEPT) || (user_controlled) ||
#					((dist>MUST_RUN_DIST) && (ABS(player->tm_anim)==MC_RUN)) ||
#					((dist>(MUST_RUN_DIST*2)) && (ABS(player->tm_anim)!=MC_RUN)) ||
#					(player->tm_player==ball_poss && !ball_in_hands) ||
#					(plr_facing(x,y,player))))
#				{
#					player->go_cnt=((dist)/actual_spd(player));				//No. of steps till target.
#					init_anim(player,MC_RUN);
#				}
#				else
#				{
#					if ((player->tm_player==KP_A) || (player->tm_player==KP_B))
#					{
#						if (ball_in_hands && ball_poss==player->tm_player)
#						{
#// kickout run up...
#							player->go_cnt=((dist)/(actual_spd(player)/4));				//No. of steps till target.
#							init_anim(player,MC_RUNWITHB);
#						}
#						else
#						{
#							player->go_cnt=((dist)/(actual_spd(player)/2));				//No. of steps till target.
#							init_anim(player,MC_JOG);
#						}
#					}
#					else
#					{
#						player->go_cnt=dist/(actual_spd(player)/2);				//half speed.
#						init_anim(player,MC_JOG);
#					}
#				}
#			}
#			else
#			{
#// Trot away...
#				player->go_cnt=dist/(actual_spd(player));				//half speed.
#				init_anim(player,MC_TROTA);
#				player->dir_mode=1;		// Face ball.
#			}
#
#			player->go_cnt++;
#			player->go_txdis=x/player->go_cnt;
#			player->go_tydis=y/player->go_cnt;
#			player->tm_act=RUN_ACT;
#
#			if (user_controlled && uf2)
#			{
#// Run Fast (user only!)...
#				player->go_txdis=player->go_txdis*1.2;
#				player->go_tydis=player->go_tydis*1.2;
#			}
#		}
#	}
#}
#*/


#******************************************************************************
#*****************************************************************************/

# void init_fall(match_player *player)
static func init_fall(player: match_player) -> void:
	Intell.reset_ideas(player)
	if ball_poss == player.tm_player:
		BallInt.holder_lose_ball()

#	get_face_xy(player->face_dir,x,y);

	player.go_txdis = (player.tm_xdis * FALL_RATE)
	player.go_tydis = (player.tm_ydis * FALL_RATE)
	player.go_tx = player.tm_x + (player.go_txdis * 100)
	player.go_ty = player.tm_y + (player.go_tydis * 100)
	player.tm_z = 0
	player.go_cnt = int((1 / MC_FALLR_FS) - 1)
	player.tm_act = FALL_ACT
	player.dir_mode = 0
	init_anim(player, MC_FALLR)
	action = "Fall"

#******************************************************************************
#*****************************************************************************/

# void init_jump_act(match_player *player,char dir,char ride)   (EXTERNS.H: char ride=FALSE)
static func init_jump_act(player: match_player, dir: int, ride: int = FALSE) -> void:
	var t: float

	Intell.reset_ideas(player)

	if dir:
		if ride:
			# Ride tackle... set zdis to length of animation...
			player.dir_mode = 0
			player.tm_act = JUMP_ACT
			action = "Jump"
			init_anim(player, MC_RIDEL)
			player.tm_zdis = (((1.0 - player.tm_frm) / player.tm_fstep) - 2) * gravity / 2
		else:
			# Jump as high as poss...
			player.tm_zdis = 1.0 + float(player.tm_pow) / 32
			player.dir_mode = 0
			player.tm_act = JUMP_ACT
			action = "Jump"
			t = ((player.tm_zdis / gravity) * 2) + 1
			init_anim(player, MC_J_HEAD)
			player.tm_fstep = float(1) / t
	else:
		if player.tm_zdis != 0:
			player.dir_mode = 1
			player.tm_act = JUMP_ACT
			action = "Header"
			player.go_txdis = 0
			player.go_tydis = 0
			t = ((player.tm_zdis / gravity) * 2) + 1
			init_anim(player, MC_J_HEAD)
			player.tm_fstep = float(1) / t

#******************************************************************************
#*****************************************************************************/

# void jump_action(match_player *player)
static func jump_action(player: match_player) -> void:
	player.tm_z += player.tm_zdis
	player.tm_zdis -= gravity
	go_toward_target(player)
	if player.tm_z <= 0:
		player.tm_z = 0
		player.tm_zdis = 0

		init_stand_act(player)

#******************************************************************************
#*****************************************************************************/

# void user_init_tackle(match_player *player)
static func user_init_tackle(player: match_player) -> void:
	if um:
#		if (camera!=6)
		# Flat mode!
		init_tackle_act(player, player.tm_x + (ux * 256), player.tm_y + (uy * 256))
		#/*
		#		else
		#
		#// Follow mode!
		#		{
		#			if (player->tm_act==RUN_ACT)
		#				init_tackle_act(player,player->tm_x+(player->tm_xdis*256)
		#											 ,player->tm_y+(player->tm_ydis*256));
		#			else
		#			{
		#				float x,y;
		#				forward_joystick(player,x,y);
		#				init_tackle_act(player,player->tm_x+(x*256),player->tm_y+(y*256));
		#			}
		#		}
		#*/
	else:
		var x: float
		var y: float
#		get_face_xy(player->face_dir,x,y);
		x = player.tm_xdis
		y = player.tm_ydis
		init_tackle_act(player, player.tm_x + (x * 256), player.tm_y + (y * 256))

#******************************************************************************
#*****************************************************************************/

# void init_tackle_act(match_player *player,float tx,float ty)
static func init_tackle_act(player: match_player, tx: float, ty: float) -> void:
	var x: float
	var y: float
	var d: float
	x = tx - player.tm_x
	y = ty - player.tm_y

	d = Maths.calc_dist(x, y)
	player.go_tx = player.tm_x + (x / d * 30 * prat)
	player.go_ty = player.tm_y + (y / d * 30 * prat)

	x = tx - player.tm_x
	y = ty - player.tm_y

	player.go_xoff = x
	player.go_yoff = y

	var a: float = angle_to_xy(x, y, player.tm_xdis, player.tm_ydis)

	# MAX_TURN = ((14+(float)player->tm_rate/8)*PI/180)
	if a >= cos(((14.0 + float(player.tm_rate) / 8.0) * PI / 180.0)):
		Rules.inc_tack(player.tm_player)
		d = Maths.calc_dist(x, y)		# (C: `float d=...` - inner block redeclares d)
		player.go_cnt = (TACKLE_TURNS)	# no. of steps till target.
		player.go_txdis = ((x) * ((player.tm_rate + player.tm_pow + 32) / 20) / d)
		player.go_tydis = ((y) * ((player.tm_rate + player.tm_pow + 32) / 20) / d)
		player.tm_act = TACKLE_ACT
		action = "Tackle"
		player.dir_mode = 0
		init_anim(player, MC_S_TACKLE)
		player.go_cnt = int(1 / MC_S_TACKLE_FS)	# no. of steps till target.
		Audio.play_fx(PS_SLIDING, player.tm_x, player.tm_y)

#******************************************************************************
#*****************************************************************************/

# void rotate_offs(int an,float &x,float &y,float &z,float nx,float ny)
#   -> returns [x, y, z]
static func rotate_offs(an: int, x: float, y: float, z: float, nx: float, ny: float) -> Array:
	var d: float = Maths.calc_dist(nx, ny)
	nx = nx / d
	ny = ny / d

	# Calculate contact offsets with rotation in direction of facing...
	x = save_offs[((an - MC_AFOOTB) * 3)]	 	# x
	y = -save_offs[((an - MC_AFOOTB) * 3) + 1]	# y
	z = save_offs[((an - MC_AFOOTB) * 3) + 2]	# z

	# Normal of offset...
	var dof: float = Maths.calc_dist(x, y)
	if dof > 1:

		# Is there any offset present???
		x = x / dof
		y = y / dof

		# get angle of rotation.
		var nsx: float = (x * nx) - (y * ny)
		var nsy: float = (y * nx) + (x * ny)
		x = nsx * dof
		y = nsy * dof
	else:
		x = 0
		y = 0
		z = 0
	return [x, y, z]

#******************************************************************************
#*****************************************************************************/

# void init_save_act(match_player *player,int tx,int ty,int tz,int an,int zone,int bp,int cont)
static func init_save_act(player: match_player, tx: int, ty: int, tz: int, an: int, zone: int, bp: int, cont: int) -> void:
	var nx: float
	var ny: float
	var acc: float
	var cacc: float
	var sacc: float

	if not user_controlled and penalty_shot:
		# Penalty shot... (computer keeper can sometimes dive in wrong direction!)
		Maths.af_randomize()
		if seed > (32 + ((player.tm_flair + player.tm_vis) / 3)):
			ty = int(player.tm_y - (ty - player.tm_y))

	keeper_down = 0

	# Accuracy of 64 gives range of (20 to -20 degrees)...
	acc = (float((Maths.rand_range(128 - player.tm_ac)) * (1 if seed & 1 else -1))) / 183
#	acc=0;
	cacc = cos(acc)
	sacc = sin(acc)

	Maths.af_randomize()

	var x: float = tx - player.tm_x
	var y: float = ty - player.tm_y

	# Horz. vector to target...
	var d: float = Maths.calc_dist(x, y)
	x = x / d
	y = y / d

	# Add inaccuracy based on stats...
	nx = (x * cacc) - (y * sacc)
	ny = (y * cacc) + (x * sacc)

	newdx = ny
	newdy = nx

	if (an > MC_AJUMPC) and (an <= MC_CJUMPBR):
		# Is he going left or right???
		if (nx * (player.tm_y - bally)) > (ny * (player.tm_x - ballx)):
			newdy = -newdy
			an += 1
		else:
			newdx = -newdx

	# Face Ball...
	newdx = ballx - player.tm_x
	newdy = bally - player.tm_y
	var nd: float = Maths.calc_dist(newdx, newdy)
	newdx = newdx / nd
	newdy = newdy / nd

	if an == MC_AFOOTC:
		keeper_down = 2

	if (an >= MC_BFOOTCL and an <= MC_BBODYCR) or (an >= MC_CFOOTBL and an <= MC_CBODYCR):
		# Keeper will hit ground...
		if an & 1:
			# Going right...
			keeper_down = 1
		else:
			keeper_down = -1

	# Calculate current mcap offsets for given direction (newdx,newdy)!
	var sx: float = 0.0
	var sy: float = 0.0
	var sz: float = 0.0
	var ro: Array = rotate_offs(an, sx, sy, sz, newdx, newdy)
	sx = ro[0]
	sy = ro[1]
	sz = ro[2]
#	rotate_offs(an,sx,sy,sz,player->tm_xdis,player->tm_ydis);
	save_xoff = sx
	save_yoff = sy
	save_zoff = sz

	# Get horz. distance offset from target point to centre of body,
	# based on motion capture animation...
	#/*WAIT for mcap data...*/
	x = (nx * d) - save_xoff
	y = (ny * d) - save_yoff

	Intell.reset_ideas(player)

	player.tm_act = SAVE_ACT
	player.go_cnt = int(1 / player.tm_fstep)
	if keeper_on_grnd:
		# Stay down for a bit after save...
		if save_block:
			player.int_cnt = int(4 + ((128 - player.tm_rate) / 12) + 1 / player.tm_fstep)		# Time to get up!
		else:
			player.int_cnt = int(18 + 1 / player.tm_fstep)		# Time to get up!
	else:
		player.int_cnt = int(2 + 1 / player.tm_fstep)

	player.int_move = I_SAVE_WAIT
	action = "Save"
	init_anim(player, an)

	player.dir_mode = 5
#	player->dir_mode=2;

	player.go_tx = player.tm_x + x
	player.go_ty = player.tm_y + y
	player.go_xoff = x
	player.go_yoff = y

	if keeper_will_save:
		player.go_txdis = x / bp
		player.go_tydis = y / bp
	else:
		player.go_txdis = x / cont
		player.go_tydis = y / cont

	d = Maths.calc_dist(player.go_txdis, player.go_tydis)
	if d > (actual_spd(player)):
		player.go_txdis = player.go_txdis * actual_spd(player) / d
		player.go_tydis = player.go_tydis * actual_spd(player) / d

	player.tm_zdis = 0

#******************************************************************************
#*****************************************************************************/

# void go_toward_target(match_player *player)
static func go_toward_target(player: match_player) -> void:
	player.tm_x += (player.go_txdis)
	player.tm_y += (player.go_tydis)

#******************************************************************************
#*****************************************************************************/

# void go_forward(match_player *player)
static func go_forward(player: match_player) -> void:
	var rate: float = actual_spd(player)

	if player.go_step:
		# Player is trotting facing ball...
		player.tm_x += (player.go_txdis)
		player.tm_y += (player.go_tydis)
		Rules.inc_work(player.tm_player)
	else:
		# Player is aiming to run straight at target...

		if player.go_stop:
			# Player must wait until he faces target before moving on...

			var a: float = angle_to_xy(player.go_txdis, player.go_tydis, player.tm_xdis, player.tm_ydis)

			# MAX_TURN = ((14+(float)player->tm_rate/8)*PI/180)
			if a >= cos(((14.0 + float(player.tm_rate) / 8.0) * PI / 180.0)):
				# Now facing target... (can move forward!)
				player.go_stop = FALSE
				player.tm_x += (player.go_txdis)
				player.tm_y += (player.go_tydis)
				Rules.inc_work(player.tm_player)
				init_run_anims(player)
			else:
				# Stand on the spot...
				pass
		else:
			# Run forward in present dir at turn speed...

			var a: float = angle_to_xy(player.go_tx - player.tm_x, player.go_ty - player.tm_y, player.tm_xdis, player.tm_ydis)
			var turn_spd: float = (1.0 + a) / 2
			player.go_txdis = player.tm_xdis * turn_spd * rate
			player.go_tydis = player.tm_ydis * turn_spd * rate

			player.tm_x += (player.go_txdis)
			player.tm_y += (player.go_tydis)
			Rules.inc_work(player.tm_player)

#******************************************************************************
#*****************************************************************************/

# void scorer_go(match_player *player)
static func scorer_go(player: match_player) -> void:
	init_celeb_act(player)

#/*
#	float xoff=cntspot_x-player->tm_x;
#	float yoff=cntspot_y-player->tm_y;
#	xoff+=64-seed;
#	af_randomize();
#	yoff+=64-seed;
#	float step=(calc_dist(xoff,yoff)/actual_spd(player));
#	player->go_txdis=xoff/step;
#	player->go_tydis=yoff/step;
#	init_jump_act(player,TRUE);
#}
#*/

#******************************************************************************
#*****************************************************************************/

# void player_shame(match_player *player)
static func player_shame(player: match_player) -> void:
	init_anim(player, MC_SHAME)
	init_get_up(player, MC_SHAME_FS)

#******************************************************************************
#*****************************************************************************/

# void go_to_scorer(match_player *player)
static func go_to_scorer(player: match_player) -> void:
	var gs: int = goal_scorer
	if player.tm_act < TURN_ACT:
		var x: float = teams[gs - 1].tm_x
		var y: float = teams[gs - 1].tm_y
		var d: float = Maths.calc_dist(x - player.tm_x, y - player.tm_y)
		var dp: int = ((player.tm_player - 11) if player.tm_player > 11 else (player.tm_player))
		dp = dp * 6
		if d < 8 + dp:
			init_celeb_act(player)
		else:
			init_run_act(player, x, y, TRUE)
			if true:
				if player.tm_act == RUN_ACT:
					go_forward(player)
					player.go_cnt = 0

#******************************************************************************
#*****************************************************************************/

# void someone_has_scored(match_player *player)
static func someone_has_scored(player: match_player) -> void:
	if player.int_move != I_CELEB and (goal_scorer == player.tm_player or (player.tm_player != KP_A and player.tm_player != KP_B)):

		if last_goal == 1:
			# Goal for team A...
			if goal_scorer < 12:
				# Celebrate...
				if goal_scorer == player.tm_player:
					# He scored!
					scorer_go(player)
				else:
					if player.tm_player < 12:
						# His team-mate
						go_to_scorer(player)
					else:
						init_stand_act(player)
			else:
				# Own goal( Shame!	)
				if goal_scorer == player.tm_player:
					# He scored!
					player_shame(player)
				else:
					init_stand_act(player)
		else:
			# Goal for team B...
			if goal_scorer > 11:
				# Celebrate...
				if goal_scorer == player.tm_player:
					# He scored!
					scorer_go(player)
				else:
					if player.tm_player > 11:
						# His team-mate
						go_to_scorer(player)
					else:
						init_stand_act(player)
			else:
				# Own goal( Shame!	)
				if goal_scorer == player.tm_player:
					# He scored!
					player_shame(player)
				else:
					init_stand_act(player)
	else:
		if player.int_move != I_CELEB:
			init_stand_act(player)

#******************************************************************************
#*****************************************************************************/

# void dont_run_off(match_player *player)
static func dont_run_off(player: match_player) -> void:
	if ((ballx < 16) or (ballx > pitch_len - 16) or
		 (bally < 16) or (bally > pitch_wid - 16)):
		init_stand_act(player)

#******************************************************************************
#*****************************************************************************/

# void user_stand(match_player *player)
static func user_stand(player: match_player) -> void:

#	if (camera!=6)
	# Flat mode!
	if not f1_down and not f2_down:
		# Not doing special...
		if game_action == -1:
			# Should take up zonal position...
			Intell.find_zonal_target(player, player.tm_x, player.tm_y)	# players x,y for comparison.
		else:
			init_run_act(player, player.tm_x + ux * 256, player.tm_y + uy * 256, FALSE)
	#/*
	#	else
	#
	#// Follow mode!
	#	{
	#		float x,y;
	#		forward_joystick(player,x,y);
	#		if (uy<0)
	#			if (!match_mode && game_action==1)
	#// Should take up zonal position...
	#				find_zonal_target(player,player->tm_x,player->tm_y);	//players x,y for comparison.
	#			else
	#				init_run_act(player,player->tm_x+x*256,player->tm_y+y*256,FALSE);
	#		else
	#		{
	#			player->go_txdis=x;
	#			player->go_tydis=y;
	#		}
	#	}
	#*/
	player.go_cnt = 1

#******************************************************************************
#*****************************************************************************/

#/*
#void check_for_header(match_player *player)
#{
#	if ((ball_inair) && (!ball_poss))
#//		&& (player->int_move==I_INTERCEPT) && (player->int_cnt))
#	{
#
#		int meet=200;
#		prev_d=5000;
#		for (int i=0; i<24; i++)
#		{
#			x=ball_pred_tab[i][0];
#			y=ball_pred_tab[i][1];
#			z=ball_pred_tab[i][2];
#
#			d=calc_dist(x-player->tm_x,y-player->tm_y);
#
#// Volley???
#			if (ballx>
#
#			if (ballz>
#			if (d<min_d)
#			{
#				min_d=d;
#				meet=i;
#			}
#			else
#				i=21;			// end loop (not getting closer to ball)
#
#			prev_d=d;
#		}
#		if (meet!=200)
#		{
#// Ball has a closest point...
#			x=ball_pred_tab[meet][0];
#			y=ball_pred_tab[meet][1];
#			z=ball_pred_tab[meet][2];
#
#
#
#			z=z-PLAYER_HEIGHT+5;
#
#//			float	zd=sqrt(z)-(gravity*gravity);			// Take-off speed for given max height!
#
#			float zd=sqrt(2*z*gravity)-(gravity*gravity);					// Max. Height
#			int jt=gravity+zd/gravity;			// Time to reach max height.
#
#			jt=meet-jt;
#			
#			if (jt>=0)
#			{
#				reset_ideas(player);
#				player->int_cnt=jt;
#				player->int_move=I_HEADER;	// Wait for header.
#				player->tm_zdis=zd;
#			}
#		}
#	}
#}
#*/

#******************************************************************************
#*****************************************************************************/

# void kick_strike(match_player *player)
static func kick_strike(player: match_player) -> void:
	if player.tm_srng:
		# In Shooting Range!
		Intell.shoot_ball(player)
	else:
		Intell.punt_ball(player)

#******************************************************************************
#*****************************************************************************/

# void overhead_strike(match_player *player)
static func overhead_strike(player: match_player) -> void:
	player.tm_xdis = -player.tm_xdis
	player.tm_ydis = -player.tm_ydis		# Facing backwards...

	var p: int = player.tm_pow
	player.tm_pow = u8(p * 2 / 3)			# 2 3rds power of kick!

	if player.tm_srng:
		# In Shooting Range!
		Intell.shoot_ball(player)
	else:
		Intell.punt_ball(player)

	player.tm_xdis = -player.tm_xdis
	player.tm_ydis = -player.tm_ydis
	player.tm_pow = u8(p)

#******************************************************************************
#*****************************************************************************/

# void chip_strike(match_player *player)
static func chip_strike(player: match_player) -> void:
	pass_type = player.tm_fpass_type
	receiver = player.tm_fpass_to
	Intell.pass_ball(receiver, FALSE)

#******************************************************************************
#*****************************************************************************/

# void head_strike(match_player *player)
static func head_strike(player: match_player) -> void:
	heading_ball = TRUE
	if player.tm_fpass_type:
		pass_type = player.tm_fpass_type
		receiver = player.tm_fpass_to
		Intell.pass_ball(receiver, FALSE)
	else:
		var p: int = player.tm_pow
		player.tm_pow = u8(p / 2)			# Half power of kick!

		if player.tm_srng:
			# In Shooting Range!
			if user_controlled:
				if uf1:		# Head down!
					heading_ball = 3
			else:
				if seed < player.tm_ac:
					heading_ball = 3

			Intell.shoot_ball(player)
		else:
			Intell.punt_ball(player)

		player.tm_pow = u8(p)
	heading_ball = FALSE

#******************************************************************************
#*****************************************************************************/

# void dvhead_strike(match_player *player)
static func dvhead_strike(player: match_player) -> void:
	var p: int = player.tm_pow
	player.tm_pow = u8(p / 2)			# Half power of kick!
	heading_ball = 2

	var ps: int = s16(Intell.pass_decide(player, FALSE))
	if ps and pass_type >= 3:
		Intell.pass_ball(ps, FALSE)
	else:
		if player.tm_srng:
			# In Shooting Range!
			Intell.shoot_ball(player)
		else:
			Intell.punt_ball(player)
	player.tm_pow = u8(p)
	heading_ball = FALSE

#******************************************************************************
#*****************************************************************************/

# void strike_ball_off(match_player *player)
static func strike_ball_off(player: match_player) -> void:
	Rules.add_comp_pass(player.tm_player)
	player.tm_ftime = -1
	last_touch = player.tm_player
	if last_touch != KP_A and last_touch != KP_B:
		pre_kp_touch = last_touch

	ball_poss = player.tm_player
	var a: int = player.tm_anim
	match a:
		MC_OVERHEAD:
			overhead_strike(player)

		MC_DV_HEAD:
			dvhead_strike(player)

		MC_J_HEAD, MC_S_HEAD:
			head_strike(player)

		MC_CHIPL, MC_CHIPR:
			chip_strike(player)

		MC_SHOOTL, MC_SHOOTR, MC_VOLLEYL, MC_VOLLEYR:
			kick_strike(player)

	BallInt.standard_fstep(player)

#******************************************************************************
#*****************************************************************************/

# void fire_ball_off()
static func fire_ball_off() -> void:
	Ball.reset_shot()
	if kick_type == KT_PUNT:
		# Punt...
		Intell.punt_ball(teams[ball_poss - 1])
	else:
		if kick_type == KT_SHOOT:
			# Shoot...
			Intell.shoot_ball(teams[ball_poss - 1])
		else:
			Intell.pass_ball(receiver, cross_now)
			cross_now = FALSE
			chip_pass = FALSE
			action = "Pass"

	var sp: float
	var fx: int

	sp = Maths.calc_dist(ballxdis, ballydis)
	sp = Maths.calc_dist(sp, ballzdis)

	if sp < 10:
		fx = PS_SOFTKICK
	else:
		if sp < 14:
			fx = PS_MEDKICK
		else:
			fx = PS_HARDKICK

	Audio.play_fx(fx, ballx, bally)

#	process_ball();

#******************************************************************************
#*****************************************************************************/

# void init_kick_act(match_player *player,int mc,float pc)
static func init_kick_act(player: match_player, mc: int, pc: float) -> void:
	init_anim(player, mc)
	player.tm_fstep = player.tm_fstep * player.tm_mcspd
	player.contact = pc
	if not set_piece_on:
		player.dir_mode = 0
	else:
		player.dir_mode = 2

	Intell.reset_ideas(player)			# Stop interception etc.
	player.int_move = I_KICKED
	player.int_cnt = int(((1.0 - player.tm_frm) / player.tm_fstep) + 1)
	var ro: Array = rotate_offs(ABS(player.tm_anim), b_xoff, b_yoff, b_zoff, teams[ball_poss - 1].tm_xdis, teams[ball_poss - 1].tm_ydis)
	b_xoff = ro[0]
	b_yoff = ro[1]
	b_zoff = ro[2]
	player.go_txdis = MC_PASS_DIST * player.tm_fstep * player.tm_xdis
	player.go_tydis = MC_PASS_DIST * player.tm_fstep * player.tm_ydis
	player.go_tx = player.tm_x + player.tm_xdis * 100
	player.go_ty = player.tm_y + player.tm_ydis * 100
	player.tm_act = KICK_ACT

#******************************************************************************
#*****************************************************************************/

# void kick_action(match_player *player)
static func kick_action(player: match_player) -> void:
	if player.tm_frm + player.tm_fstep >= 1:
		# Finished kick animation...

		init_stand_act(player)
		player.contact = -1

	if player.tm_frm >= player.contact and ball_poss == player.tm_player:
		# Contacted ball (release it)...
		fire_ball_off()

	if ball_poss != player.tm_player and player.tm_frm < player.contact:
		# Ball stolen before kick!
		init_stand_act(player)
		player.contact = -1
	else:
		go_toward_target(player)

#******************************************************************************
#*****************************************************************************/

# void steal_action(match_player *player)
static func steal_action(player: match_player) -> void:
	if player.tm_frm < 1.0:
		if ((player.tm_frm > 0.4) and (player.tm_frm < 0.6)
			and (ballz < 1) and (ball_poss != player.tm_player)):
			# Foot out frames...
			# Get foot coords...
			var x: float = player.tm_x + (player.tm_xdis * prat)
			var y: float = player.tm_y + (player.tm_ydis * prat)
			x = ballx - x
			y = bally - y
			var d: float = Maths.calc_dist(x, y)
			if d <= STEAL_FOOT_DIST:
				BallInt.holder_lose_ball()
				BallInt.collect_ball(player)
	else:
		init_stand_act(player)

#******************************************************************************
#*****************************************************************************/

# void stand_action(match_player *player)
static func stand_action(player: match_player) -> void:
	if player.tm_strike > 0 and player.int_move == I_INTERCEPT:
		# Waiting for first touch...
		player.go_cnt -= 1
		if player.go_cnt <= 0:
			# Begin first touch animation...
			init_strike_act(player)
	else:
		if ABS(player.tm_anim) == MC_SOCKSL or ABS(player.tm_anim) == MC_SOCKSR:
			# Pulling his socks up just now...
			if player.tm_frm > 0.99:
				init_anim(player, MC_STAND)

		player.ls_anim = ABS(player.tm_anim)		# Do not use last anim!
		player.ls_frm = player.tm_frm		# Do not use last anim!

		if ((user_controlled) and (not match_mode)
			 and (not ((player.tm_player == KP_A or player.tm_player == KP_B)
			 and ABS(player.tm_anim) >= MC_STOSL and ABS(player.tm_anim) <= MC_STOSBR))):
			user_stand(player)
		else:
			if ABS(player.tm_anim) >= MC_STOSL and ABS(player.tm_anim) <= MC_STOSBR:
				# Keeper getting up!
				if not player.int_cnt:
					if ball_in_hands:
						init_anim(player, MC_STANDB)
					else:
						init_anim(player, MC_STAND)
			else:
				if just_scored > 0:
					someone_has_scored(player)
				else:
#				if (player->int_move!=I_HEADER)
#					check_for_header(player);
#				else
					if player.int_move == I_HEADER:
						if player.int_cnt <= 1:
							player.int_cnt = -1
							init_jump_act(player, FALSE)	# Jump straight up!
					else:
						if ((player.tm_player == KP_A and not (ballx < cntspot_x and shot_pending))
							or (player.tm_player == KP_B and not (ballx > cntspot_x and shot_pending))
							or (player.tm_player != KP_A and player.tm_player != KP_B)):
							# Make sure that keeper isn't waiting to make save!
							if (player.tm_act == STAND_ACT) and (not player.tm_stopped):
								Intell.find_zonal_target(player, player.tm_x, player.tm_y)	# players x,y for comparison.

		if ABS(player.tm_anim) == MC_STAND and player.tm_dist > (prat * 50):
			# Standing far away from ball...
			if ((ball_poss > 11 and player.tm_player > 11) or (ball_poss
				and ball_poss < 12 and player.tm_player < 12)):
				# Team-mate has ball (safe!)...
				if seed < SOCKS_PROB:
					if seed & 1:
						init_anim(player, MC_SOCKSL)
					else:
						init_anim(player, MC_SOCKSR)
					# Busy now...
					init_get_up(player, MC_SOCKS_FS)
