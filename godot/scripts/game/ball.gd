# Port of SOURCE/BALL.CPP  (assembled by tools/assemble.py - edit the files in parts/)
class_name Ball extends Glob
#******************************************************************************
#******************************************************************************
#
# Ball movement routines...
#
#******************************************************************************
#******************************************************************************

# #include "global.h" "defines.h" "externs.h" "audio.h" "front.h" "data.h" "eurofrnt\euro_int.h"
# extern match_data match_info;
# extern setup_info setup;
# extern stad_info stadlist[];

#******************************************************************************
#******************************************************************************

#******************************************************************************
#******************************************************************************

# float get_angle(float x,float y,float d)
static func get_angle(x: float, y: float, d: float) -> float:
	var a: float = (acos(x / d)) * 180 / PI
	if y < 0:
		a = 360 - a
	return a

#******************************************************************************
#******************************************************************************

# void get_xydis_from_ang(float a,float d)
static func get_xydis_from_ang(a: float, d: float) -> void:
	ballxdis = (float(d) * cos(a * PI / 180))
	ballydis = -(float(d) * sin(a * PI / 180))

#******************************************************************************
#******************************************************************************

# float get_s_angle(float z,float d)
static func get_s_angle(z: float, d: float) -> float:
	var a: float = (asin(z / d)) * 180 / PI
	return a

#******************************************************************************
#******************************************************************************

# void get_zdis_from_ang(float a,float d)
static func get_zdis_from_ang(a: float, d: float) -> void:
	ballzdis = (float(d) * sin(a * PI / 180))

#******************************************************************************
#******************************************************************************

# void stop_ball_spin()
static func stop_ball_spin() -> void:
	swerve = 0; full_zspin = 0; full_xyspin = 0
	ball_zspin = 0; ball_xyspin = 0
	max_sw_factor = 0
	swerve_factor = 0
	rebound_ball = FALSE
	headed_ball = FALSE

#******************************************************************************
#******************************************************************************

# void swerve_xyz()
static func swerve_xyz() -> void:
	var x: float
	var y: float
	var z: float
	var d: float
	var dz: float
	var dn: float
	d = Maths.calc_dist(ballxdis, ballydis)
	x = ballxdis / d
	y = ballydis / d
	dz = Maths.calc_dist(ballzdis, d)
	z = ballzdis / dz
	dn = d / dz

	ballxdis = d * ((x * cos(ball_xyspin)) - (y * sin(ball_xyspin)))
	ballydis = d * ((y * cos(ball_xyspin)) + (x * sin(ball_xyspin)))
	ballzdis = d * ((z * cos(ball_zspin)) + (dn * sin(ball_zspin)))

#******************************************************************************
#******************************************************************************

# void inc_swerve()
static func inc_swerve() -> void:
	spin_cnt += 1
	ball_zspin = -(full_zspin * (SW_HOLD_FACTOR / (SW_HOLD_FACTOR + spin_cnt)))

	if swerve < 0:
		ball_xyspin = -(full_xyspin * (SW_HOLD_FACTOR / (SW_HOLD_FACTOR + spin_cnt)))
	else:
		ball_xyspin = (full_xyspin * (SW_HOLD_FACTOR / (SW_HOLD_FACTOR + spin_cnt)))

#******************************************************************************
#******************************************************************************

# void get_aftert_spin()
static func get_aftert_spin() -> void:
	spin_cnt += 1
	var xys: float
	var zs: float
	var x: float
	var y: float
	var z: float
	var d: float
	var dz: float
	var dn: float
	d = Maths.calc_dist(ballxdis, ballydis)
	x = ballxdis / d
	y = ballydis / d
	dz = Maths.calc_dist(ballzdis, d)
	z = ballzdis / dz
	dn = d / dz

	var u: int = u8(after_touch_on - 1)

	if SUPPORT_LP:	# #ifdef SUPPORT_LP
		if users[u].control == LOGPAD_CTRL:
			if not prediction:
				xys = 1

			xys = 0
			if (users_dir[u].f & 4) and not (users_dir[u].f & 8):
				xys = 1

			if (users_dir[u].f & 8) and not (users_dir[u].f & 4):
				xys = -1
		else:
			xys = ((users_dir[u].x * shoot_y) - (users_dir[u].y * shoot_x))
	else:			# #else
		xys = ((users_dir[u].x * shoot_y) - (users_dir[u].y * shoot_x))
	# #endif

	zs = ((users_dir[u].x * shoot_x) + (users_dir[u].y * shoot_y))

	ball_xyspin = -(xys * full_xyspin * (SW_HOLD_FACTOR / (SW_HOLD_FACTOR + spin_cnt)))
	ball_zspin = -(zs * full_zspin * (SW_HOLD_FACTOR / (SW_HOLD_FACTOR + spin_cnt)))
#	ball_zspin=0.05;
	ballxdis = d * ((x * cos(ball_xyspin)) - (y * sin(ball_xyspin)))
	ballydis = d * ((y * cos(ball_xyspin)) + (x * sin(ball_xyspin)))
	ballzdis = dz * ((z * cos(ball_zspin)) + (dn * sin(ball_zspin)))

	zs = 0

#******************************************************************************
#******************************************************************************

# void add_spin_fx()
static func add_spin_fx() -> void:
#	if (!prediction)
	if true:
		if swerve != 0:
			var d: float = Maths.calc_dist(ballxdis, ballydis)
			if d < 1:
# Ball is hardly travelling (swerve OFF)

				stop_ball_spin()
			else:
				inc_swerve()
				swerve_xyz()
		else:
			if after_touch_on:
				get_aftert_spin()

		if shot_pending:
			swerve_factor = ABS(ball_xyspin)
			if swerve_factor > max_sw_factor:
				max_sw_factor = swerve_factor

#******************************************************************************
#******************************************************************************

# void move_ball()
static func move_ball() -> void:
	ballx += ballxdis
	bally += ballydis

	if prediction:
		ns_ballx = ballx
		ns_bally = bally
		ns_ballz = ballz

	if ball_inair:

		ballz += ballzdis

		if ballz < ball_diam / 2:
			ballz = ball_diam / 2
			ballzdis = -ballzdis
			ballzdis -= bounce_dis
# Landing friction...
			ballxdis = ballxdis - (0.1 * ballxdis)
			ballydis = ballydis - (0.1 * ballydis)

			if ballzdis < 0:
				ballzdis = 0
				ball_inair = 0
			else:
				if not prediction:
					if ABS(ballzdis) > 7:
						Audio.play_fx(PS_HARDBOUNCE, ballx, bally)
					else:
						Audio.play_fx(PS_SOFTBOUNCE, ballx, bally)

		if ball_inair:
			add_spin_fx()
			if not prediction:
				ball_horz_ang += ball_xyspin * 40

				var x: float
				var y: float
				var d: float
				d = ((cos(ball_horz_ang) * launch_x) + (sin(ball_horz_ang) * launch_y))

				if d > 1.0:
					d = 1

				if d < -1.0:
					d = -1

				ball_vert_ang += d * (-ball_zspin * 40)

				ball_vert_ang += IN_AIR_SPIN * launch_type

#******************************************************************************
#******************************************************************************

# void grav_ball()
static func grav_ball() -> void:
	if ball_inair:
		ballzdis -= gravity

#******************************************************************************
#******************************************************************************

# void ball_friction()
static func ball_friction() -> void:
	var friction_factor: float

	if ball_inair:
		friction_factor = AIR_FRICTION
	else:
		friction_factor = GRND_FRICTION

	if wind_on:
# Wind Fx...
		var wf: float = wind_speed / (800 - (ballz * 2))
		if wf > MAX_WIND:
			wf = MAX_WIND

		ballxdis += wind_x * wf
		ballydis += wind_y * wf

	ballxdis = (friction_factor * ballxdis)
	ballydis = (friction_factor * ballydis)

	if not ball_inair:
		if (ballxdis > -0.25) and (ballxdis < 0.25):
			ballxdis = 0

		if (ballydis > -0.25) and (ballydis < 0.25):
			ballydis = 0

#******************************************************************************
#******************************************************************************

# void roll_ball()
static func roll_ball() -> void:
	if (not prediction) and (not ball_inair):
# Roll ball...
		var x: float = ballxdis
		var y: float = ballydis
		var d: float = Maths.calc_dist(x, y)
		x = x / d
		y = y / d

		ball_horz_ang = acos(x)
		if y < 0:
			ball_horz_ang = (PI * 2) - ball_horz_ang

		ball_vert_ang += d / ball_diam

#******************************************************************************
#******************************************************************************

# void ball_trajectory()
static func ball_trajectory() -> void:
	if not ball_poss:
		if game_action == -1:
			game_action = 0
		move_ball()
		grav_ball()
		ball_friction()

	if ballxdis or ballydis:
		ball_still = 0
		if (not ball_in_hands) or (not ball_poss):
			roll_ball()
	else:
		ball_still = 1

#******************************************************************************
#******************************************************************************

# void get_ball_zone()
static func get_ball_zone() -> void:
	if (not ball_out_of_play) and ((not match_mode) or (match_mode > GOAL_KICK_BR)):
		if ball_in_hands:
			if ball_poss == KP_A:
# Pretend Goal kick for A...
				ball_zone1 = 11
				ball_zone2 = 20
			else:
				if ball_poss == KP_B:
# Pretend Goal kick for B...
					ball_zone1 = 19
					ball_zone2 = 12
		else:
			var bx1: int = int(ballx)
			var bx2: int = int(ballx)
			var by1: int = int(bally)
			var by2: int = int(bally)
			bx1 = int((bx1 + (zone_wid / 2)) / (zone_wid))
			zone1_x = int(bx1 * zone_wid)
			bx2 = 7 - bx1
			zone2_x = int(bx2 * zone_wid)
			by1 = int((by1 + (zone_hgt / 2)) / (zone_hgt))
			zone1_y = int(by1 * zone_hgt)
			by2 = 3 - by1
			zone2_y = int(by2 * zone_hgt)
			if by2 >= 0:
				ball_zone1 = (by1 * 8) + bx1
				ball_zone2 = (by2 * 8) + bx2

#******************************************************************************
#******************************************************************************

# void launch_ball(int p)
static func launch_ball(p: int) -> void:
	var d: float = Maths.calc_dist(ballxdis, ballydis)
	if d > 0.2:
		launch_x = ballxdis / d
		launch_y = ballydis / d
		ball_horz_ang = acos(launch_x)
		if launch_y < 0:
			ball_horz_ang = (PI * 2) - ball_horz_ang
		launch_type = p

#******************************************************************************
#******************************************************************************

# void reset_shot()
static func reset_shot() -> void:
	real_shot = FALSE
	shot_acknowledged = FALSE
	shot_pending = FALSE
	after_touch_on = FALSE
	swerve = FALSE

#******************************************************************************
#******************************************************************************

# void new_shot(int p)
static func new_shot(p: int) -> void:
	if men_in_wall > 1:
		wall_is_up = TRUE
	else:
		wall_is_up = FALSE

	var r: float
	shot_acknowledged = FALSE
	must_shoot = FALSE
	shooter = p
	if ballx > cntspot_x or (ballx <= cntspot_x and ballxdis > ABS(ballydis)):
# Keeper B to see it...
		r = teams[KP_B - 1].tm_dist
		shot_pending = -1 - ((128 - teams[KP_B - 1].tm_vis) / 10)

		if r < LONG_RANGE and shot_pending < -1:
			shot_pending = int((((r * 1.4) / LONG_RANGE) * (shot_pending + 1)) - 1)

		if penalty_shot and teams[KP_B - 1].control:
			shot_pending = -1
	else:
# Keeper A to see it...
		if ballx <= cntspot_x or (ballx > cntspot_x and ballxdis < ABS(ballydis)):
			r = teams[KP_A - 1].tm_dist
			shot_pending = -1 - ((128 - teams[KP_A - 1].tm_vis) / 10)

			if r < LONG_RANGE and shot_pending < -1:
				shot_pending = int((((r * 1.4) / LONG_RANGE) * (shot_pending + 1)) - 1)

			if penalty_shot and teams[KP_A - 1].control:
				shot_pending = -1

#******************************************************************************
#******************************************************************************

# void reset_ball()
static func reset_ball() -> void:
	BallInt.holder_lose_ball()
	ballz = ball_diam / 2; ballxdis = 0; ballydis = 0; ballzdis = 0
	ball_zspin = 0; ball_xyspin = 0
	ball_inair = 0; ball_still = 1; super_shot = 0
	ball_in_goal = FALSE
	last_touch = 0
	shot_attempt = 0
	stop_ball_spin()
	Intell.reset_all_ideas()
	reset_shot()
	use_ball_limit = FALSE

#******************************************************************************
#******************************************************************************

# void respot_ball()
static func respot_ball() -> void:
	if shot_pending and match_mode >= GOAL_KICK_TL and match_mode <= GOAL_KICK_BR:
		fired_a_shot = TRUE
	else:
		fired_a_shot = FALSE

	reset_ball()

	if not penalty_game:
		if last_goal == 1:
			match_mode = CENTRE_B
			last_goal = 0

		if last_goal == 2:
			match_mode = CENTRE_A
			last_goal = 0

		if match_mode:
			Rules.init_match_mode()

#******************************************************************************
#******************************************************************************

# void shot_passed()
static func shot_passed() -> void:
	var d: float
	if ballx < 0:
# Left goal...
		d = Maths.calc_dist(ballx, bally - cntspot_y)
		if d > prat * 8:
			shot_missed = -25		# Laughable attempt!
		else:
			if ballz > prat * 5:
				shot_missed = -25		# Laughable attempt!
			else:
				shot_missed = 25		# good attempt!
	else:
		if ballx > pitch_len:
# Right goal...
			d = Maths.calc_dist(ballx - pitch_len, bally - cntspot_y)
			if d > prat * 8:
				shot_missed = -15		# Laughable attempt!
			else:
				if ballz > prat * 5:
					shot_missed = -15		# Laughable attempt!
				else:
					shot_missed = 15		# good attempt!

#******************************************************************************
#******************************************************************************

# void stadium_bounds()
static func stadium_bounds() -> void:
	if ballx > (pitch_len + stadlist[setup.stadium].st_l):
		ballx = (pitch_len + stadlist[setup.stadium].st_l)
		ballxdis = -ballxdis
	else:
		if ballx < -stadlist[setup.stadium].st_l:
			ballx = -stadlist[setup.stadium].st_l
			ballxdis = -ballxdis
		else:
			if bally > (pitch_wid + stadlist[setup.stadium].st_w):
				bally = (pitch_wid + stadlist[setup.stadium].st_w)
				ballydis = -ballydis
			else:
				if bally < -stadlist[setup.stadium].st_w:
					bally = -stadlist[setup.stadium].st_w
					ballydis = -ballydis

#******************************************************************************
#******************************************************************************

# void pitch_bounds()
static func pitch_bounds() -> void:
	if (ballx < 0) or (ballx >= pitch_len) or (bally < 0) or (bally >= pitch_wid):
		if (not ((ball_poss) and (teams[ball_poss - 1].tm_act == THROW_ACT))) \
			and (just_thrown == FALSE):
# Not taking throw in...
			if play_advantage:
				Rules.retake_foul()
			else:
				use_ball_limit = TRUE
				ballx_out = ballx
				bally_out = bally
				ballz_out = ballz

				if shot_pending:
					shot_passed()			# For crowd noise...
				ball_out_of_play = 25
				match_mode = u8(Rules.bounds_rules())

#******************************************************************************
#******************************************************************************

# void rebound_post()
static func rebound_post() -> void:
# Ball strikes post and rebounds off maintaining zdis...
	shot_passed()			# For crowd noise...

	var x: float
	var y: float
	var d: float
	var ang: float

	d = Maths.calc_dist(ballxdis, ballydis)
	x = ballxdis / d
	y = ballydis / d

# Get angle to come off ( favours 180 degrees )...

	ang = float(seed)
	Maths.af_randomize()
	ang += float(seed)
	Maths.af_randomize()			# Favour 128...

	ang = ang * PI / 128

	ballxdis = ((x * cos(ang)) - (y * sin(ang))) * d * REBOUND_FACTOR
	ballydis = ((y * cos(ang)) + (x * sin(ang))) * d * REBOUND_FACTOR

	rebound_ball = TRUE

	if shot_pending:
		Audio.PlayCommentaryMessage(PM_POST)

#******************************************************************************
#******************************************************************************

# void rebound_bar()
static func rebound_bar() -> void:
# Ball strikes cross-bar and rebounds off maintaining x,ydis...
	shot_passed()			# For crowd noise...

	var z: float
	var d: float
	var ndxy: float
	var dxy: float
	var ang: float

	dxy = Maths.calc_dist(ballxdis, ballydis)
	d = Maths.calc_dist(dxy, ballzdis)
	z = ballzdis / d

# Get angle to come off ( favours 180 degrees )...

	ang = float(seed)
	Maths.af_randomize()
	ang += float(seed)
	Maths.af_randomize()			# Favour 128...

	ang = ang * PI / 128

	ballzdis = ((z * cos(ang)) - (dxy / d * sin(ang))) * d * REBOUND_FACTOR
	ndxy = ABS(((dxy / d * cos(ang)) + (z * sin(ang))) * d * REBOUND_FACTOR)

	ballxdis = -ballxdis * (ndxy / dxy)
	ballydis = ballydis * (ndxy / dxy)

	rebound_ball = TRUE

	if shot_pending:
		Audio.PlayCommentaryMessage(PM_CROSSBAR)

#******************************************************************************
#******************************************************************************

# void own_goal()
static func own_goal() -> void:
	goal_scorer = last_touch

	Rules.inc_ogs(goal_scorer)

	if penalty_game:
		just_scored = PEN_SCORE_WAIT
	else:
		just_scored = SCORE_WAIT

	reset_shot()
	BallInt.holder_lose_ball()
	ball_out_of_play = 25
	Eng3D.do_goal_anim(0)
	shamed_player = goal_scorer

#******************************************************************************
#******************************************************************************

# void good_goal()
static func good_goal() -> void:
	Rules.inc_goal(goal_scorer)

	if penalty_game:
		just_scored = PEN_SCORE_WAIT
	else:
		just_scored = SCORE_WAIT

	reset_shot()
	BallInt.holder_lose_ball()
	ball_out_of_play = 25
	Eng3D.do_goal_anim(0)
	shamed_player = 0

#******************************************************************************
#******************************************************************************

# void hit_goal_post()
static func hit_goal_post() -> void:
	rebound_post()
	if ballx > cntspot_x:
		ballx = pitch_len - 1
	else:
		ballx = 1
	reset_shot()

#******************************************************************************
#******************************************************************************

# void hit_cross_bar()
static func hit_cross_bar() -> void:
	rebound_bar()
	if ballx > cntspot_x:
		ballx = pitch_len - 1
	else:
		ballx = 1
	reset_shot()

#******************************************************************************
#******************************************************************************

# void hit_high_side_net()
static func hit_high_side_net() -> void:
	if swerve != 0:
		stop_ball_spin()
	ballzdis = ballzdis / 2
	ballxdis = ballxdis / 2
	ballydis = -ballydis / 2
	bally = top_post_y

#******************************************************************************
#******************************************************************************

# void hit_low_side_net()
static func hit_low_side_net() -> void:
	if swerve != 0:
		stop_ball_spin()
	ballzdis = ballzdis / 2
	ballxdis = ballxdis / 2
	ballydis = -ballydis / 2
	bally = bot_post_y

#******************************************************************************
#******************************************************************************

# void hit_top_net()
static func hit_top_net() -> void:
	if swerve != 0:
		stop_ball_spin()
	ballz = goal_height + 1
	ballzdis = 0

	if ballxdis < 0:
		ballxdis -= 2
	else:
		ballxdis += 2

	ballxdis = ballxdis / 2
	ballydis = ballydis / 2

#******************************************************************************
#******************************************************************************

# void hit_inside_back_net()
static func hit_inside_back_net() -> void:
	if swerve != 0:
		stop_ball_spin()
	ballzdis = ballzdis / 2
	ballxdis = -ballxdis / 2
	ballydis = ballydis / 2
	ballx = 1 - goal_depth

#******************************************************************************
#******************************************************************************

# void hit_inside_back_net_r()
static func hit_inside_back_net_r() -> void:
	if swerve != 0:
		stop_ball_spin()
	ballzdis = ballzdis / 2
	ballxdis = -ballxdis / 2
	ballydis = ballydis / 2
	ballx = pitch_len + goal_depth - 1

#******************************************************************************
#******************************************************************************

# void hit_inside_top_net()
static func hit_inside_top_net() -> void:
	if swerve != 0:
		stop_ball_spin()
	ballz = goal_height - 1
	ballzdis = 0

	ballxdis = ballxdis / 2
	ballydis = ballydis / 2

#******************************************************************************
#******************************************************************************

# void hit_inside_high_side()
static func hit_inside_high_side() -> void:
	if swerve != 0:
		stop_ball_spin()
	ballzdis = ballzdis / 2
	ballxdis = ballxdis / 2
	ballydis = -ballydis / 2
	bally = top_post_y + 1

#******************************************************************************
#******************************************************************************

# void hit_inside_low_side()
static func hit_inside_low_side() -> void:
	if swerve != 0:
		stop_ball_spin()
	ballzdis = ballzdis / 2
	ballxdis = ballxdis / 2
	ballydis = -ballydis / 2
	bally = bot_post_y - 1

#******************************************************************************
#******************************************************************************

# short real_player(short p)
static func real_player(p: int) -> int:
	if match_half & 1:
# swapped...
		p = (p - 11 if p > 11 else p + 11)
	return p

#******************************************************************************
#******************************************************************************

# short standard_player(short p)
static func standard_player(p: int) -> int:
	if p > 11:
		p -= 11
	return p

#******************************************************************************
#******************************************************************************

# short country(char t)
static func country(t: int) -> int:
	var p: int
	if t:
		p = setup.team_b
	else:
		p = setup.team_a

	return p

#******************************************************************************
#******************************************************************************

# void go_right_goal()
static func go_right_goal() -> void:
	if golden_goal and (match_half > 1 and match_half < 4):
# Sudden death... Golden goal has been scored! (End of match)
		golden_goal = 2

	if not ball_out_of_play:
		ball_in_goal = TRUE
		last_goal = 1

		if match_mode == NORMAL_PLAY:
			if match_half & 1:
				team_b_goals += 1
			else:
				team_a_goals += 1

			if penalty_game:
				EUROmatch_info.Team_B_penalties = u8(EUROmatch_info.Team_B_penalties + 1)

			if last_touch > 11:
# Deflection, own goal or keeper's poss...
				if last_touch == KP_B:
# Keeper bad save...
					Audio.PlayCommentaryMessage(GL_KEEPER)
					goal_scorer = pre_kp_touch
					if goal_scorer < 12:
# Opposition scored...
						Eng3D.do_goal_menu(team_a, standard_player(goal_scorer) - 1, match_time.min)
						if not penalty_game:
							pass
							Eng3D.GOAL_SCORED(0,real_player(goal_scorer)-1,match_time.min+(256 if penalty_shot else 0))
						good_goal()
					else:
# Own goal...
						Eng3D.do_owngoal_menu(team_b, standard_player(goal_scorer) - 1, match_time.min)
						if not penalty_game:
							pass
							Eng3D.GOAL_SCORED(0,real_player(goal_scorer)-1,match_time.min+512+(256 if penalty_shot else 0))
						own_goal()
				else:
					Audio.PlayCommentaryMessage(GL_DEFLECT)
					Eng3D.do_owngoal_menu(team_b, standard_player(last_touch) - 1, match_time.min)
					if not penalty_game:
						pass
						Eng3D.GOAL_SCORED(0,real_player(last_touch)-1,match_time.min+512+(256 if penalty_shot else 0))
					own_goal()
			else:
				if headed_ball:
					Audio.PlayCommentaryMessage(GL_HEADER)
				else:
					if rebound_ball:
						Audio.PlayCommentaryMessage(GL_POST)
					else:
						if max_sw_factor > GOOD_SWERVE:
							if wall_is_up:
								Audio.PlayCommentaryMessage(GL_CURVEWALL)
							else:
								Audio.PlayCommentaryMessage(GL_CURVE)
						else:
							if shot_speed > 18:
								Audio.PlayCommentaryMessage(GL_HARDKICK)
							else:
								Audio.PlayCommentaryMessage(GL_GENERIC)

				Eng3D.do_goal_menu(team_a, standard_player(last_touch) - 1, match_time.min)
				if not penalty_game:
					pass
					Eng3D.GOAL_SCORED(0,real_player(last_touch)-1,match_time.min+(256 if penalty_shot else 0))

				goal_scorer = last_touch
				good_goal()
		Audio.PauseCommentary()

#******************************************************************************
#******************************************************************************

# void go_left_goal()
static func go_left_goal() -> void:
	if golden_goal and (match_half > 1 and match_half < 4):
# Sudden death... Golden goal has been scored! (End of match)
		golden_goal = 2

	if not ball_out_of_play:
		ball_in_goal = TRUE
		last_goal = 2

		if match_mode == NORMAL_PLAY:
			if match_half & 1:
				team_a_goals += 1
			else:
				team_b_goals += 1

			if penalty_game:
				EUROmatch_info.Team_A_penalties = u8(EUROmatch_info.Team_A_penalties + 1)

			if last_touch < 12:
# Deflection, own goal or keeper's poss...
				if last_touch == KP_A:
# Keeper bad save...
					Audio.PlayCommentaryMessage(GL_KEEPER)
					goal_scorer = pre_kp_touch
					if goal_scorer > 11:
# Opposition scored...
						Eng3D.do_goal_menu(team_b, standard_player(goal_scorer) - 1, match_time.min)
						if not penalty_game:
							pass
							Eng3D.GOAL_SCORED(0,real_player(goal_scorer)-1,match_time.min+(256 if penalty_shot else 0))
						good_goal()
					else:
# Own goal...
						Eng3D.do_owngoal_menu(team_a, standard_player(goal_scorer) - 1, match_time.min)
						if not penalty_game:
							pass
							Eng3D.GOAL_SCORED(0,real_player(goal_scorer)-1,match_time.min+512+(256 if penalty_shot else 0))
						own_goal()
				else:
					Audio.PlayCommentaryMessage(GL_DEFLECT)
					Eng3D.do_owngoal_menu(team_a, standard_player(last_touch) - 1, match_time.min)
					if not penalty_game:
						pass
						Eng3D.GOAL_SCORED(0,real_player(last_touch)-1,match_time.min+512+(256 if penalty_shot else 0))
					own_goal()
			else:
				if headed_ball:
					Audio.PlayCommentaryMessage(GL_HEADER)
				else:
					if rebound_ball:
						Audio.PlayCommentaryMessage(GL_POST)
					else:
						if max_sw_factor > GOOD_SWERVE:
							Audio.PlayCommentaryMessage(GL_CURVE)
						else:
							if shot_speed > 16:
								Audio.PlayCommentaryMessage(GL_HARDKICK)
							else:
								Audio.PlayCommentaryMessage(GL_GENERIC)

				Eng3D.do_goal_menu(team_b, standard_player(last_touch) - 1, match_time.min)
				if not penalty_game:
					pass
					Eng3D.GOAL_SCORED(0,real_player(last_touch)-1,match_time.min+(256 if penalty_shot else 0))

				goal_scorer = last_touch
				good_goal()
		Audio.PauseCommentary()

#******************************************************************************
#******************************************************************************

# void outside_of_net(float f,float y,float z)
static func outside_of_net(f: float, y: float, z: float) -> void:
	var dx: float = ballx - prev_ballx
	var dy: float = bally - prev_bally
	var dz: float = ballz - prev_ballz
	var x: float

	if (ballx < 0 and prev_ballx >= 0) or (ballx > pitch_len and prev_ballx <= pitch_len):
		if (z >= goal_height) and (z < goal_height + post_width) \
			and (y > top_post_y - post_width) and (y < bot_post_y + post_width):
# Hit cross Bar...
			hit_cross_bar()
		else:
			if (z < goal_height) and (y > top_post_y - post_width) \
				and (y <= top_post_y):
# Hit Top post...
				hit_goal_post()
			else:
				if (z < goal_height) and (y < bot_post_y + post_width) \
					and (y >= bot_post_y):
# Hit Bot post...
					hit_goal_post()
				else:
# Try top-side netting...
					f = (top_post_y - prev_bally) / dy
					z = prev_ballz + (f * dz)
					x = prev_ballx + (f * dx)

					if ((x > -goal_depth and x < 0) \
						or (x < pitch_len + goal_depth and x > pitch_len)) \
						and (z < goal_height):
# Hit high side netting...
						hit_high_side_net()
					else:
# Try low-side netting...
						f = (bot_post_y - prev_bally) / dy
						z = prev_ballz + (f * dz)
						x = prev_ballx + (f * dx)

						if ((x > -goal_depth and x < 0) \
							or (x < pitch_len + goal_depth and x > pitch_len)) \
							and (z < goal_height):
# Hit low side netting...
							hit_low_side_net()
	else:
		if (ballz < goal_height) and (prev_ballz >= goal_height):
# Falling... check top net...
			f = (goal_height - prev_ballz) / dz
			y = prev_bally + (f * dy)
			x = prev_ballx + (f * dx)

			if ((x > -goal_depth and x < 0) \
				or (x < pitch_len + goal_depth and x > pitch_len)) \
				and (y > top_post_y) and (y < bot_post_y):
# On top of net...
				hit_top_net()
			else:
# Try top-side netting...
				f = (top_post_y - prev_bally) / dy
				z = prev_ballz + (f * dz)
				x = prev_ballx + (f * dx)

				if ((x > -goal_depth and x < 0) \
					or (x < pitch_len + goal_depth and x > pitch_len)) \
					and (z < goal_height):
# Hit high side netting...
					hit_high_side_net()
				else:
# Try low-side netting...
					f = (bot_post_y - prev_bally) / dy
					z = prev_ballz + (f * dz)
					x = prev_ballx + (f * dx)

					if ((x > -goal_depth and x < 0) \
						or (x < pitch_len + goal_depth and x > pitch_len)) \
						and (z < goal_height):
# Hit low side netting...
						hit_low_side_net()

#******************************************************************************
#******************************************************************************

# void is_it_a_goal()
static func is_it_a_goal() -> void:
	var dx: float = ballx - prev_ballx
	var dy: float = bally - prev_bally
	var dz: float = ballz - prev_ballz
	var f: float
	var x: float
	var y: float
	var z: float

	if not ball_in_goal:
# Not inside goal-net...
		if ballx < 0:
# Crossed Left goal-line...
			f = prev_ballx / dx
			y = prev_bally - (f * dy)
			z = prev_ballz - (f * dz)

			if prev_ballx >= 0:
# Just crossed goal-line...

				if (z < goal_height) and (y > top_post_y) and (y < bot_post_y):
# Its a goal!!!!
					go_left_goal()
				else:
					outside_of_net(f, y, z)
			else:
				outside_of_net(f, y, z)
		else:
# Behind Left goal-line...
			if ballx > pitch_len:
				f = (pitch_len - prev_ballx) / dx
				y = prev_bally + (f * dy)
				z = prev_ballz + (f * dz)

				if prev_ballx < pitch_len:
					if (z < goal_height) and (y > top_post_y) and (y < bot_post_y):
# Its a goal!!!!
						go_right_goal()
					else:
						outside_of_net(f, y, z)
				else:
					outside_of_net(f, y, z)
	else:
# Inside goal-net...
		if ballx < 0:
# Inside left goal...
			if ballx < -goal_depth:
				hit_inside_back_net()
			if bally < top_post_y:
				hit_inside_high_side()
			if bally > bot_post_y:
				hit_inside_low_side()
			if ballz > goal_height:
				hit_inside_top_net()
		else:
# Inside right goal...
			if ballx > pitch_len + goal_depth:
				hit_inside_back_net_r()
			if bally < top_post_y:
				hit_inside_high_side()
			if bally > bot_post_y:
				hit_inside_low_side()
			if ballz > goal_height:
				hit_inside_top_net()


#******************************************************************************
#******************************************************************************

# void ball_collision()
static func ball_collision() -> void:
	is_it_a_goal()

	prev_ballx = ballx
	prev_bally = bally
	prev_ballz = ballz

#******************************************************************************
#******************************************************************************

# void oball_collision()
static func oball_collision() -> void:
	if ballx < cntspot_x:

# Left side
		if not ball_in_goal:

# Not in goal
			if ballx < 0:
# Behind posts
				if prev_ballx >= -goal_depth:
					if (prev_ballz < goal_height) or (ballz < goal_height):
						if bally < cntspot_y:
# High side
							if (bally > top_post_y) or (prev_bally > top_post_y):
								if (ballz - ballzdis) >= goal_height:
									hit_top_net()
								if (bally - ballydis) <= top_post_y:
									if (ballx - ballxdis > post_width) \
										and (ABS(ballxdis) > ABS(ballydis)):
										hit_goal_post()
									else:
										hit_high_side_net()
								else:
									go_left_goal()
						else:
# Low side
							if bally < bot_post_y:
								if (ballz - ballzdis) >= goal_height:
									hit_top_net()
								if (bally - ballydis) >= cntspot_y + (4 * prat):
									if (ballx - ballxdis > post_width) \
										and (ABS(ballxdis) > ABS(ballydis)):
										hit_goal_post()
									else:
										hit_low_side_net()
								else:
									go_left_goal()
			else:
				if ballx <= post_width:
# On goal line
					if (bally > top_post_y - post_width) \
						and (bally <= top_post_y) \
						and (ballz <= goal_height):
						hit_goal_post()

					if (bally < bot_post_y + post_width) \
						and (bally >= bot_post_y) \
						and (ballz <= goal_height):
						hit_goal_post()

					if (bally > top_post_y - post_width) \
						and (bally < bot_post_y + post_width) \
						and (ballz >= goal_height) \
						and (ballz < goal_height + post_width):
						hit_cross_bar()
		else:
# Inside Left goal
			if ballx < -goal_depth:
				hit_inside_back_net()
			if bally < top_post_y:
				hit_inside_high_side()
			if bally > bot_post_y:
				hit_inside_low_side()
			if ballz > goal_height:
				hit_inside_top_net()
	else:
# Right side
		if not ball_in_goal:

# Not in goal
			if ballx > pitch_len:
# Behind posts
				if ballx <= pitch_len + goal_depth:
					if ballz < goal_height:
						if bally < cntspot_y:
# High side
							if bally > top_post_y:
								if (ballz - ballzdis) >= goal_height:
									hit_top_net()
								if (bally - ballydis) <= top_post_y:
									if (ballx - ballxdis < pitch_len - post_width) \
										and (ABS(ballxdis) > ABS(ballydis)):
										hit_goal_post()
									else:
										hit_high_side_net()
								else:
									go_right_goal()
						else:
# Low side
							if bally < bot_post_y:
								if (ballz - ballzdis) >= goal_height:
									hit_top_net()
								if (bally - ballydis) >= cntspot_y + (4 * prat):
									if (ballx - ballxdis < pitch_len - post_width) \
										and (ABS(ballxdis) > ABS(ballydis)):
										hit_goal_post()
									else:
										hit_low_side_net()
								else:
									go_right_goal()
			else:
				if ballx >= pitch_len - post_width:
# On goal line
					if (bally > top_post_y - post_width) \
						and (bally <= top_post_y) \
						and (ballz <= goal_height):
						hit_goal_post()

					if (bally < bot_post_y + post_width) \
						and (bally >= bot_post_y) \
						and (ballz <= goal_height):
						hit_goal_post()

					if (bally > top_post_y - post_width) \
						and (bally < bot_post_y + post_width) \
						and (ballz >= goal_height) \
						and (ballz < goal_height + post_width):
						hit_cross_bar()
		else:
# Inside Right goal
			if ballx > pitch_len + goal_depth:
				hit_inside_back_net_r()
			if bally < top_post_y:
				hit_inside_high_side()
			if bally > bot_post_y:
				hit_inside_low_side()
			if ballz > goal_height:
				hit_inside_top_net()

#******************************************************************************
#******************************************************************************

# void get_ball_speed()
static func get_ball_speed() -> void:
	var tot: float = ABS(ballxdis) + ABS(ballydis) + ABS(ballzdis)
	ball_speed = int(sqrt(tot))		# ball_speed is an int (CHP/fistp in the object code)

#******************************************************************************
#******************************************************************************

# void ball_limbo(int p,float c)
static func ball_limbo(p: int, c: float) -> void:
	ball_limbo_c = ABS(c)
	ball_limbo_p = p
	ball_limbo_on = TRUE

#******************************************************************************
#******************************************************************************

# void ball_possession()
static func ball_possession() -> void:

# Calculate possession for audio...
	if not just_scored and not match_mode and last_touch != KP_A and last_touch != KP_B:
		good_poss = s16(int(good_poss + (ballx / 20 if last_touch < 12 else -(pitch_len - ballx) / 20)))

	if ABS(good_poss) > MAX_GOOD_POSS:
		if audio_version:
			Audio.PlayPossessionSample((team_b if good_poss < 0 else team_a))

		good_poss = 0

#******************************************************************************
#******************************************************************************

# void process_ball()
static func process_ball() -> void:
	ball_possession()

	if ball_limbo_on > 0:

# Ball is bound to a player's animation and should not be processed
# until the contact point of animation is exceeded...

		if teams[ball_limbo_p - 1].tm_frm + teams[ball_limbo_p - 1].tm_fstep > ball_limbo_c:
# Contact exceeded...
			ball_limbo_on = FALSE
			if teams[ball_limbo_p - 1].tm_anim == MC_KICKOUT:
				Audio.play_fx(PS_HARDKICK, ballx, bally)

	if (not ball_limbo_on) and (not ball_poss or (ball_poss and teams[ball_poss - 1].contact < 0)):
		prediction = FALSE

		if shot_acknowledged:
			shot_acknowledged = u8(shot_acknowledged - 1)				# Counter for re-acknowledgement.

#	if ((shot_pending) && (shooter==last_touch))
		if shot_pending:
			shot_pending += 1
			if not shot_pending:
				shot_pending = 1
		else:
			shot_pending = 0
			real_shot = 0

		get_ball_speed()
		if ball_out_of_play:
			ball_trajectory()
			ball_collision()
			if just_scored:
				just_scored -= 1
				if not just_scored:
					Audio.ResumeCommentary()
					Audio.PlayScoreSample(team_a_goals, team_b_goals)
			else:
				ball_out_of_play -= 1
				if not ball_out_of_play and match_mode != SWAP_ENDS:
					respot_ball()
					get_ball_zone()
					BallInt.predict_ball()
			stadium_bounds()
		else:
			ball_trajectory()
			ball_collision()
			if not just_scored and match_mode != SWAP_ENDS and match_half <= 10:
				pitch_bounds()
				get_ball_zone()
				BallInt.predict_ball()

