# ---- ACTIONS.CPP part B: lines 3048-end (user_throw ... process_teams) ----

# #define TOO_CLOSE_TO_GOAL (prat)
static func TOO_CLOSE_TO_GOAL() -> float:
	return prat

# #define JUMP_POINT (0.1)
const JUMP_POINT = 0.1

#/******************************************************************************
#*****************************************************************************/

# void user_throw(match_player *player)
static func user_throw(player: match_player) -> void:
	var high: int = FALSE
	var x: float
	var y: float

	if um:
		# Joystick_dir...
		if bally > cntspot_y:
			# Bottom line...
			x = ux
			y = uy

			if uy > 0:
				high = TRUE
				y = -uy
			else:
				high = FALSE
		else:
			# Top line...
			x = ux
			y = uy

			if uy < 0:
				high = TRUE
				y = -uy
			else:
				high = FALSE

		player.tm_xdis = x
		player.tm_ydis = y

		if uf2:
			# Pass to nearest team-mate...
			must_pass = TRUE
			throw_cnt = 1
			if high:
				chip_pass = TRUE

			var p: int = Intell.pass_decide(player, FALSE)
			Intell.make_pass(player, p, FALSE)
			dead_ball_cnt = 0
			game_action = 0
			just_thrown = 20
			match_mode = 0
			arrow_on = FALSE
			already_there = FALSE
			stop_clock = FALSE

		if uf1:
			# Throw straight...
			var sx: float
			var sy: float
			var sz: float
			var power: float = 5 + (player.tm_pow / 16)
			ballxdis = player.tm_xdis * power
			ballydis = player.tm_ydis * power
			ballzdis = (power if high else power / 2)

			init_anim(player, MC_THROWL)
			# Point at which ball leaves hand!
			# Calculate current mcap offsets for given direction (newdx,newdy)!
			var r: Array = rotate_offs(MC_THROWL, sx, sy, sz, player.tm_xdis, player.tm_ydis)
			sx = r[0]; sy = r[1]; sz = r[2]
			ballx = player.tm_x + sx
			bally = player.tm_y + sy
			ballz = player.tm_z + sz
			Ball.ball_limbo(player.tm_player, MCC_THROWL)
			player.tm_limbo = int(1 / MC_THROWL_FS)

			ball_inair = TRUE
			BallInt.holder_lose_ball()
			dead_ball_cnt = 0
			game_action = 0
			just_thrown = 20
			match_mode = 0
			arrow_on = FALSE
			already_there = FALSE
			stop_clock = FALSE

			Ball.launch_ball(1)			# Set up spin vector.

#/******************************************************************************
#*****************************************************************************/

# void throw_action(match_player *player)
static func throw_action(player: match_player) -> void:

	# Lmen normal...
	refs[1].act = 0
	refs[2].act = 0

	if refs[0].act != 2:
		# Referee wait for kick mode...
		refs[0].act = 2
		ktaker = player.tm_player
		ref_wait = (160 - ref_strictness) * REAL_SPEED / 8
		Audio.play_fx(PS_SHORTWHISTLE, refs[0].x, refs[0].y)

	if user_controlled:
		user_throw(player)
	else:
		if player.dir_mode == 2:
			# Scan in all directions for team-mate...
			var ang_add: float
			var nx: float
			var ny: float
			var ox: float = player.go_txdis
			var oy: float = player.go_tydis

			if player.turn_dir > 0:
				ang_add = 0.1047198 		# 6 degrees (radians)
			else:
				ang_add = -0.1047198

			nx = (ox * cos(ang_add)) - (oy * sin(ang_add))
			ny = (oy * cos(ang_add)) + (ox * sin(ang_add))

			if ny > 1:
				ny = 1
				nx = 0

			if ny < -1:
				ny = -1
				nx = 0

			if (bally < cntspot_y) and (ny <= 0):
				player.turn_dir = -player.turn_dir
				ny = 0
				if nx > 0:
					nx = 1
				else:
					nx = -1

			if (bally > cntspot_y) and (ny >= 0):
				player.turn_dir = -player.turn_dir
				ny = 0
				if nx > 0:
					nx = 1
				else:
					nx = -1

			player.go_txdis = nx
			player.go_tydis = ny

			throw_cnt -= 1
			if not throw_cnt:
				# Looked around long enough must pass now.
				must_pass = TRUE
				throw_cnt = 1

			var tx: float = player.tm_xdis
			var ty: float = player.tm_ydis
			player.tm_xdis = player.go_txdis
			player.tm_ydis = player.go_tydis

			var x: float
			var y: float
			var d: float

			var p: int = Intell.pass_decide(player, FALSE)
			if p:
				player.dir_mode = 0		# Face in move dir.
				player.turn_dir = p		# store receiver.

				x = teams[p - 1].tm_x - player.tm_x
				y = teams[p - 1].tm_y - player.tm_y
				d = Maths.calc_dist(x, y)
				player.go_txdis = x / d
				player.go_tydis = y / d
				player.go_tx = teams[p - 1].tm_x
				player.go_ty = teams[p - 1].tm_y
				already_there = FALSE
				stop_clock = FALSE

			player.tm_xdis = tx
			player.tm_ydis = ty
		else:
			# Wait for thrower to rotate to pass direction...

			var ox: float = player.tm_xdis
			var oy: float = player.tm_ydis

			var dif: float = ((player.go_txdis * ox) + (player.go_tydis * oy))
			if ABS(dif) > 0.95:
				# He's facing receiver...
				Intell.make_pass(player, player.turn_dir, FALSE)
				dead_ball_cnt = 0
				game_action = 0
				just_thrown = 20
				match_mode = 0
				Ball.launch_ball(1)			# Set up spin vector.
				already_there = FALSE
				stop_clock = FALSE

#/******************************************************************************
#*****************************************************************************/

# Moves player on journey to target (x,y).

# void user_run(match_player *player)
static func user_run(player: match_player) -> void:
	var px: float = player.tm_x
	var py: float = player.tm_y

	if ((px < -(prat * 2) and ux < 0)
			or (px > pitch_len + (prat * 2) and ux > 0)):
		ux = 0
		if ABS(uy) < 0.05:
			init_stand_act(player)
		else:
			if uy > 0:
				uy = 1
			else:
				uy = -1

	if ((py < -(prat * 2) and uy < 0)
			or (py > pitch_wid + (prat * 2) and uy > 0)):
		uy = 0
		if ABS(ux) < 0.05:
			init_stand_act(player)
		else:
			if ux > 0:
				ux = 1
			else:
				ux = -1
#/*
#	if (camera==6)
#// Follow mode!
#	{
#		float x,y;
#		forward_joystick(player,x,y);
#		if (uy<0)
#			init_run_act(player,player->tm_x+x*256,player->tm_y+y*256,FALSE);
#		else
#		{
#			init_stand_act(player);
#			user_stand(player);
#		}
#	}
#	else
#*/
	init_run_act(player, player.tm_x + ux * 256, player.tm_y + uy * 256, FALSE)

	go_forward(player)
	player.go_cnt = 0

#/*****************************************************************************
#*****************************************************************************/

# Keeper (holding ball) faces out then throws or kicks ball.

# void kphold_action(match_player *player)
static func kphold_action(player: match_player) -> void:
	var p: int = player.tm_player
	game_action = -1				# Force players to keep away!

	if not player.int_cnt:
		player.dir_mode = 3

		# Added... Make keeper kick ball out if close to own goal line!
		var kickit: int = FALSE
		if ((player.tm_player == KP_A and player.tm_x < TOO_CLOSE_TO_GOAL())
				or (player.tm_player == KP_B and player.tm_x > (pitch_len - TOO_CLOSE_TO_GOAL()))):
			kickit = TRUE

		init_anim(player, MC_STANDB)

		if keep_timer:
			keep_timer -= 1

		if not Intell.opp_around(int(ballx), int(bally), player.tm_player) or not keep_timer:
			# No opposition near!
			if seed & 1 and seed & 8 and not kickit:
				# Bounce the ball...
				init_anim(player, MC_BOUNCE)
				player.int_move = I_KP_BUSY
				player.int_cnt = int(1.0 / MC_BOUNCE_FS)
			else:
				if seed & 2 and seed & 8 and not kickit:
					# Wave team-mates up-field...
					init_anim(player, MC_WAVEUP)
					player.int_move = I_KP_BUSY
					player.int_cnt = int(1.0 / MC_WAVEUP_FS)
				else:
					if seed & 4 and seed & 8 and not kickit:
						# Stand for a bit...
						player.int_move = I_KP_BUSY
						player.int_cnt = 20
					else:
						# Just run...
						if (p == KP_A) and (player.tm_xdis >= 0.95):
							init_run_act(player, player.tm_x + (prat * 15), player.tm_y, FALSE)

						if (p == KP_B) and (player.tm_xdis <= -0.95):
							init_run_act(player, player.tm_x - (prat * 15), player.tm_y, FALSE)

						if ABS(player.tm_anim) == MC_RUN:
							init_anim(player, MC_RUNWITHB)

#/******************************************************************************
#*****************************************************************************/

# void wait_action(match_player *player)
static func wait_action(player: match_player) -> void:
	if ((player.ball_state < 0 and not ball_poss)
			or (player.ball_state > 0 and player.ball_state != last_touch)):
		# Ball has changed trajectory!
		init_stand_act(player)
	else:
		player.tm_ftime -= 1
		if not player.tm_ftime:
			# No more waiting!
			player.tm_strike = -player.tm_strike
			init_strike_act(player)
		else:
			player.tm_x += player.go_txdis
			player.tm_y += player.go_tydis

#/******************************************************************************
#*****************************************************************************/

# void stop_action(match_player *player)
static func stop_action(player: match_player) -> void:
	if player.int_move == I_INTERCEPT:
		var a: float = angle_to_xy(player.go_xoff, player.go_yoff, player.tm_xdis, player.tm_ydis)

		# MAX_TURN = ((14+(float)player->tm_rate/8)*PI/180)
		if a > cos(((14 + float(player.tm_rate) / 8) * PI / 180)):
			# Facing target now...
			init_run_act(player, player.go_tx, player.go_ty, FALSE)
			go_toward_target(player)
	else:
		init_stand_act(player)

#/******************************************************************************
#*****************************************************************************/

# void init_stop_act(match_player *player,float x,float y)
static func init_stop_act(player: match_player, x: float, y: float) -> void:
	player.dir_mode = 0
	player.tm_act = STOP_ACT
	player.go_tx = x
	player.go_ty = y
	player.go_xoff = x - player.tm_x
	player.go_yoff = y - player.tm_y
	init_anim(player, MC_STAND)

#/******************************************************************************
#*****************************************************************************/

# void init_wait_act(match_player *player,float x,float y)
static func init_wait_act(player: match_player, x: float, y: float) -> void:
	player.dir_mode = 2
	player.tm_act = WAIT_ACT
	player.go_step = TRUE	# Side step if needed!
	var m: int = player.int_move
	player.int_move = 0
	var rate: float = actual_spd(player)
	player.int_move = m

	var d: float = Maths.calc_dist(x, y)
	x = x / d
	y = y / d
	var t: int = player.tm_ftime

	d = d / t		# Magnitude of displacement!
	if d > (rate + (player.tm_stime - 1)):
		init_stand_act(player)
	else:
		player.tm_strike = -player.tm_strike
		player.go_txdis = x * d
		player.go_tydis = y * d
#		player->go_tx=player->go_tx-player->tm_x+(player->go_txdis*(t+1));
#		player->go_ty=player->go_ty-player->tm_y+(player->go_tydis*(t+1));
		if d > .5:
			init_anim(player, MC_TROTA)
		else:
			init_anim(player, MC_STAND)
		player.int_cnt = player.tm_ftime + 1

		player.tm_x += player.go_txdis
		player.tm_y += player.go_tydis

#/******************************************************************************
#*****************************************************************************/

# void control_action(match_player *player)
static func control_action(player: match_player) -> void:
	if player.tm_frm >= 1:
		# end of animation...
		ballz = 0
		init_stand_act(player)
		player.tm_ftime = -2
		BallInt.hold_ball(player)
		ball_limbo_on = FALSE
	else:
		if player.tm_frm >= player.contact and ball_poss != player.tm_player and player.tm_ftime >= 0:
			# Player should have ball now but doesn't....
			init_stand_act(player)
		else:
			player.tm_x += player.go_txdis
			player.tm_y += player.go_tydis

#/******************************************************************************
#*****************************************************************************/

# void get_closest_pred(match_player *player,float &rt,float &x,float &y,float &z,float &d)
# returns [rt, x, y, z, d]
static func get_closest_pred(player: match_player, rt: float, x: float, y: float, z: float, d: float) -> Array:
	var sx: float
	var sy: float
	var sz: float
	var r: Array = rotate_offs(player.tm_anim, sx, sy, sz, player.mface_x, player.mface_y)
	sx = r[0]; sy = r[1]; sz = r[2]

	x = ball_pred_tab[int(rt)][0] - sx
	y = ball_pred_tab[int(rt)][1] - sy
	z = ball_pred_tab[int(rt)][2] - sz

	x = x - player.tm_x
	y = y - player.tm_y
	z = z - player.tm_z

	d = Maths.calc_dist(x, y)
	d = Maths.calc_dist(z, d)

	var best_rt: float = rt
	var min_d: float = d
	var best_x: float = x
	var best_y: float = y
	var best_z: float = z

	# Check one forward...
	if rt < 49:
		rt += 1
		x = ball_pred_tab[int(rt)][0] - sx
		y = ball_pred_tab[int(rt)][1] - sy
		z = ball_pred_tab[int(rt)][2] - sz

		x = x - player.tm_x
		y = y - player.tm_y
		z = z - player.tm_z

		d = Maths.calc_dist(x, y)
		d = Maths.calc_dist(z, d)

		if d < min_d:
			min_d = d
			best_rt = rt
			best_x = x
			best_y = y
			best_z = z

	# Check one back...
	if rt >= 1:
		rt -= 2
		x = ball_pred_tab[int(rt)][0] - sx
		y = ball_pred_tab[int(rt)][1] - sy
		z = ball_pred_tab[int(rt)][2] - sz

		x = x - player.tm_x
		y = y - player.tm_y
		z = z - player.tm_z

		d = Maths.calc_dist(x, y)
		d = Maths.calc_dist(z, d)

		if d < min_d:
			min_d = d
			best_rt = rt
			best_x = x
			best_y = y
			best_z = z

	d = min_d
	x = best_x
	y = best_y
	z = best_z
	rt = best_rt
	return [rt, x, y, z, d]

#/******************************************************************************
#*****************************************************************************/

# void init_control_act(match_player *player)
static func init_control_act(player: match_player) -> void:
	var x: float
	var y: float
	var z: float
	var d: float
	var rt: float

	match player.tm_strike:
		1:
			init_anim(player, MC_TRAPL)
			player.contact = MCC_TRAP
			z = save_offs[(MC_TRAPL * 3) + 2]

		2:
			init_anim(player, MC_CHEST)
			player.contact = MCC_CHEST
			z = save_offs[(MC_CHEST * 3) + 2]

		3:
			init_anim(player, MC_D_HEAD)
			player.contact = MCC_D_HEAD
			z = save_offs[(MC_D_HEAD * 3) + 2]

	# Real contact point with offset...
	var old_rt: float = player.tm_stime + player.tm_ftime
	rt = old_rt
	var r: Array = get_closest_pred(player, rt, x, y, z, d)
	rt = r[0]; x = r[1]; y = r[2]; z = r[3]; d = r[4]

	player.tm_ftime = int(player.tm_ftime + (rt - old_rt))		# Add difference in timing.

	if player.tm_ftime > 0:
		# Some free time... (lets stand and wait!)
		init_wait_act(player, x, y)
	else:
		# Need to run animation...
		player.tm_ftime = 0
		var ts: int = player.tm_strike
		Intell.reset_ideas(player)

		if player.tm_player > 11:
			interceptor_b = player.tm_player
		else:
			interceptor_a = player.tm_player

		player.tm_strike = ts
		player.tm_act = CONTROL_ACT
		player.int_move = I_RECEIVE
		player.tm_fstep = player.contact / rt
		player.tm_frm = player.tm_fstep + 0.01
		player.int_cnt = int(((1.0 - player.tm_frm) / player.tm_fstep) + 1)

		d = Maths.calc_dist(x, y)
		if d / rt > 1:
			# Ball has changed direction... (cannot meet!)
			init_stand_act(player)
		else:
			if iabs(z) > prat:
				# Ball has changed direction... (cannot meet!)
				init_stand_act(player)
			else:
				# set displacement to meet ball at contact point!
				player.go_txdis = x / rt
				player.go_tydis = y / rt

				# keep facing same direction!
				player.dir_mode = 2

			player.tm_strike = -player.tm_strike

#/******************************************************************************
#*****************************************************************************/

# void strike_action(match_player *player)
static func strike_action(player: match_player) -> void:
	if player.tm_frm + player.tm_fstep >= 1:
		# end of animation...
		player.tm_ftime = -2

		if player.tm_anim == MC_OVERHEAD:
			# On the ground must get up ( on his back )...
			player.tm_limbo = int(1 / MC_GETUP_FS)
			init_anim(player, MC_GETUP)
		else:
			if player.tm_anim == MC_DV_HEAD:
				# On the ground must get up ( on his front )...
				player.tm_limbo = int(1 / MC_GETUPF_FS)
				init_anim(player, MC_GETUPF)
			else:
				init_stand_act(player)
	else:
		if player.tm_anim == MC_J_HEAD:
			# Jumping header...
			if player.tm_frm > JUMP_POINT:
				player.tm_z += player.tm_zdis
				if player.tm_z < 0:
					player.tm_z = 0
				else:
					player.tm_zdis -= gravity

		if player.tm_frm >= player.contact:
			# Player can slow down now...
			player.go_txdis = player.go_txdis * SAVE_DECEL
			player.go_tydis = player.go_tydis * SAVE_DECEL

		player.tm_x += player.go_txdis
		player.tm_y += player.go_tydis

#/******************************************************************************
#*****************************************************************************/

# void init_first_time_act(match_player *player,int mc,float pc)
static func init_first_time_act(player: match_player, mc: int, pc: float) -> void:
	var x: float
	var y: float
	var z: float
	var d: float
	var rt: float

	init_anim(player, mc)

	player.tm_frm = 0

	# Real contact point with offset...
	var old_rt: float = player.tm_stime + player.tm_ftime
	rt = old_rt
	var r: Array = get_closest_pred(player, rt, x, y, z, d)
	rt = r[0]; x = r[1]; y = r[2]; z = r[3]; d = r[4]

	player.tm_ftime = int(player.tm_ftime + (rt - old_rt))		# Add difference in timing.

	if player.tm_ftime > 0:
		# Some free time... (lets stand and wait!)
		init_wait_act(player, x, y)
	else:
		# Need to speed up animation...
		player.tm_ftime = 0
		var ts: int = player.tm_strike
		Intell.reset_ideas(player)			# Stop interception etc.

		if player.tm_player > 11:
			interceptor_b = player.tm_player
		else:
			interceptor_a = player.tm_player

		player.tm_strike = ts
		player.tm_act = STRIKE_ACT
		player.int_move = I_RECEIVE
		player.contact = pc
		var fs: float = player.tm_fstep
		player.tm_fstep = player.contact / rt
		player.tm_frm = player.tm_fstep + 0.01
		player.int_cnt = int(((1.0 - player.tm_frm) / player.tm_fstep) + 1)

		if mc == MC_J_HEAD:
			player.tm_zdis = (gravity * ((player.int_cnt - 1) * .6) / 2)

		d = Maths.calc_dist(x, y)
		if d / rt > 2:
			# Ball has changed direction... (cannot meet!)
			init_stand_act(player)
		else:
			if iabs(z) > prat:
				# Ball has changed direction... (cannot meet!)
				init_stand_act(player)
			else:

				# set displacement to meet ball at contact point!
				player.go_txdis = x / rt
				player.go_tydis = y / rt

				# keep facing same direction!
				player.dir_mode = 2
			player.tm_strike = -player.tm_strike

#/******************************************************************************
#*****************************************************************************/

# void oinit_first_time_act(match_player *player,int mc,float pc)
static func oinit_first_time_act(player: match_player, mc: int, pc: float) -> void:
	var x: float
	var y: float
	var z: float
	var d: float

	init_anim(player, mc)

	var sx: float
	var sy: float
	var sz: float

	var r: Array = rotate_offs(mc, sx, sy, sz, player.tm_xdis, player.tm_ydis)
	sx = r[0]; sy = r[1]; sz = r[2]

	# Real contact point with offset...
	var rt: float = player.tm_stime + player.tm_ftime
	x = ball_pred_tab[int(rt)][0] - sx
	y = ball_pred_tab[int(rt)][1] - sy
	z = ball_pred_tab[int(rt)][2] - sz

	x = x - player.tm_x
	y = y - player.tm_y
	z = z - player.tm_z

	if player.tm_ftime:
		# Some free time... (lets stand and wait!)
		init_wait_act(player, x, y)
	else:
		player.tm_strike = -player.tm_strike
		var fs: float = player.tm_fstep		# Standard anim speed fstep!
		player.contact = pc
		player.tm_fstep = (pc - player.tm_frm) / (player.tm_stime + player.tm_ftime)
		player.dir_mode = 2
		Intell.reset_ideas(player)			# Stop interception etc.
		player.int_move = I_RECEIVE
		player.int_cnt = int(((pc - player.tm_frm) / player.tm_fstep) + (1 - pc / fs) + 1)
		player.tm_act = STRIKE_ACT

		# (C: inner block redeclares "float d" - same variable used here)
		d = Maths.calc_dist(x, y)
		if d / rt > 1:
			# Ball has changed direction... (cannot meet!)
			init_stand_act(player)
		else:
			if iabs(z) > prat:
				# Ball has changed direction... (cannot meet!)
				init_stand_act(player)
			else:
				# set displacement to meet ball at contact point!
				player.go_txdis = x / rt
				player.go_tydis = y / rt

#/******************************************************************************
#*****************************************************************************/

# void init_strike_act(match_player *player)
static func init_strike_act(player: match_player) -> void:
	var s: int

	match player.tm_strike:
		1, 2, 3:
			init_control_act(player)

		4:
			init_first_time_act(player, MC_OVERHEAD, MCC_OVERHEAD)
			headed_ball = FALSE

		5:
			init_first_time_act(player, MC_VOLLEYL, MCC_VOLLEY)
			headed_ball = FALSE

		6:
			init_first_time_act(player, MC_DV_HEAD, MCC_DV_HEAD)
			headed_ball = TRUE

		7:
			init_first_time_act(player, MC_J_HEAD, MCC_J_HEAD)
			headed_ball = TRUE

		8:
			init_first_time_act(player, MC_SHOOTL, MCC_SHOOT)
			headed_ball = FALSE

		9:
			init_first_time_act(player, MC_S_HEAD, MCC_S_HEAD)
			headed_ball = TRUE

		10:
			init_first_time_act(player, MC_CHIPL, MCC_CHIP)
			headed_ball = FALSE

#/******************************************************************************
#*****************************************************************************/

# Moves player on journey to target (x,y).

# void orun_action(match_player *player)
static func orun_action(player: match_player) -> void:
	if ((player.tm_comm == SAY_PASS or player.tm_comm == SAY_CROSS)
			and not player.tm_ccnt):
		# He's asking for ball!
		go_toward_target(player)
	else:
		var player_ref: int = player.tm_player

		if (ball_poss or (not ball_poss and player.int_move != I_INTERCEPT)) and (user_controlled) and (not match_mode):

			user_run(player)
		else:
			if ball_poss != player_ref:
				if sender_1_2 != player_ref:
					if (player.tm_strike > 0 and player.int_move == I_INTERCEPT
							and ((player.ball_state < 0 and not ball_poss)
							or (player.ball_state > 0 and player.ball_state != last_touch))):
						init_stand_act(player)
					else:
						player.go_cnt -= 1
						if player.go_cnt <= 0:
							player.go_cnt = 0

							if player.tm_strike > 0 and player.int_move == I_INTERCEPT:
								# Begin first touch animation...
								go_toward_target(player)
								init_strike_act(player)
							else:
								if ((player.tm_player == KP_A and not (ballx < cntspot_x and shot_pending))
										or (player.tm_player == KP_B and not (ballx > cntspot_x and shot_pending))
										or (player.tm_player != KP_A and player.tm_player != KP_B)):
									# Make sure that keeper isn't waiting to make save!
									Intell.find_zonal_target(player, player.tm_x, player.tm_y)	#players x,y for comparison.
									if (player.go_cnt) and (player.tm_act == RUN_ACT):
										go_toward_target(player)
									else:
										if player.tm_act != TURN_ACT:
											init_stand_act(player)
								else:
									# Keeper waiting to make save!
									init_stand_act(player)
						else:
							if just_scored > 0:
								someone_has_scored(player)		# Target is goal scorer!
							else:
								go_toward_target(player)
			else:
				# Running with ball!
				player.go_cnt -= 1
				if player.go_cnt <= 0:
					player.go_cnt = 0
					init_stand_act(player)
				else:
					go_toward_target(player)
					if ball_in_hands:
						if player.tm_player == KP_A:
							# Keeper A...
							if keeper_a_in_box:
								# Can only take three steps...
								keeper_steps -= 1
								if not keeper_steps:
									must_punt = TRUE
							else:
								must_punt = TRUE
						else:
							if player.tm_player == KP_B:
								# Keeper B...
								if keeper_b_in_box:
									keeper_steps -= 1
									if not keeper_steps:
										must_punt = TRUE
									# Can only take three steps...
								else:
									must_punt = TRUE


#/******************************************************************************
#*****************************************************************************/

# Moves player on journey to target (x,y).

# void run_action(match_player *player)
static func run_action(player: match_player) -> void:
	if ((player.tm_comm == SAY_PASS or player.tm_comm == SAY_CROSS)
			and not player.tm_ccnt):
		# He's asking for ball!
		go_forward(player)
	else:
		var player_ref: int = player.tm_player

		if user_controlled and game_action != -1 and not match_mode and (ball_poss or (not ball_poss and player.int_move != I_INTERCEPT)):

			user_run(player)
		else:
			if ball_poss != player_ref:
				# Doesn't have ball...
				if sender_1_2 != player_ref:
					# Not part of 1-2 move...
					if (player.tm_strike > 0 and player.int_move == I_INTERCEPT
							and ((player.ball_state < 0 and not ball_poss)
							or (player.ball_state > 0 and player.ball_state != last_touch))):

						# Can't continue first touch action! (Ball trajectory has changed!)

						init_stand_act(player)
					else:
						if (user_controlled and player.int_move == I_INTERCEPT and player.int_cnt
								and not player.tm_strike and (uf1 or uf2)):
							Intell.go_to_path(player.tm_player)		# Forced to try special move next cycle...

						if player.go_cnt and player.dir_mode != 6:
							go_forward(player)

						if (player.tm_trap and player_ref == player_on_off
								and player.go_cnt < 12):
							player.draw_me = FALSE

						player.go_cnt -= 1
						if player.go_cnt <= 0:
							# Should be at target now!
							player.go_cnt = 0

							if player.int_move == I_CELEB:
								# Celebration run finished...
								init_taunt_act(player)

							if player.tm_strike > 0 and player.int_move == I_INTERCEPT:
								# Begin first touch animation...
								if player.mface and player.dir_mode != 6:
									player.dir_mode = 6
									player.go_cnt = player.mface_time
									init_anim(player, MC_STAND)
								else:
									init_strike_act(player)
							else:
								if ((player.tm_player == KP_A and not (ballx < cntspot_x and shot_pending))
										or (player.tm_player == KP_B and not (ballx > cntspot_x and shot_pending))
										or (player.tm_player != KP_A and player.tm_player != KP_B)):
									# Make sure that keeper isn't waiting to make save!
									if just_scored:
										someone_has_scored(player)
									else:
										if player.int_move == I_OFF:
											player.tm_x = player.go_tx
											player.tm_y = player.go_ty
											init_stand_act(player)
										else:
											if player.int_cnt:
												init_stand_act(player)
											else:
												Intell.find_zonal_target(player, player.tm_x, player.tm_y)	#players x,y for comparison.
								else:
									# Keeper waiting to make save!
									init_stand_act(player)
						else:
							if just_scored > 0 and player.int_move != I_CELEB:
								someone_has_scored(player)		# Target is goal scorer!
			else:
				# Running with ball!
				if player.go_cnt:
					go_forward(player)

				player.go_cnt -= 1
				if player.go_cnt <= 0:
					player.go_cnt = 0
					init_stand_act(player)
				else:
					if ball_in_hands:
						if player.tm_player == KP_A:
							# Keeper A...
							if keeper_a_in_box:
								# Can only take three steps...
								keeper_steps -= 1
								if not keeper_steps:
									game_action = 0
									must_punt = TRUE
							else:
								game_action = 0
								must_punt = TRUE
						else:
							if player.tm_player == KP_B:
								# Keeper B...
								if keeper_b_in_box:
									keeper_steps -= 1
									if not keeper_steps:
										game_action = 0
										must_punt = TRUE
									# Can only take three steps...
								else:
									game_action = 0
									must_punt = TRUE

#/******************************************************************************
#*****************************************************************************/

# void tackle_action(match_player *player)
static func tackle_action(player: match_player) -> void:
	go_toward_target(player)
	player.go_txdis *= TACKLE_DECEL
	player.go_tydis *= TACKLE_DECEL
	var old_cnt: int = player.go_cnt		# if (!player->go_cnt--)
	player.go_cnt -= 1
	if not old_cnt:
		init_stand_act(player)

#/******************************************************************************
#*****************************************************************************/

# void save_action(match_player *player)
static func save_action(player: match_player) -> void:
	if ((player.tm_player == KP_A and keeper_a_in_box)
			or (player.tm_player == KP_B and keeper_b_in_box)):
		player.tm_x += player.go_txdis
		player.tm_y += player.go_tydis
	else:
		seconds += 1

	if player.tm_anim >= MC_AFOOTB and player.tm_anim <= MC_AJUMPC and player.tm_frm > keeper_contact:
		# Slow him down after ball contact in zone A...
		player.go_txdis = player.go_txdis * SAVE_DECEL
		player.go_tydis = player.go_tydis * SAVE_DECEL

	#/*WAIT for mcap data*/
	#/* If keeper lands on ground slow him down...*/

	var old_cnt: int = player.go_cnt		# if (!player->go_cnt--)
	player.go_cnt -= 1
	if not old_cnt:
		player.go_txdis = player.go_txdis * SAVE_DECEL
		player.go_tydis = player.go_tydis * SAVE_DECEL
		player.go_cnt = 0
		player.tm_fstep = 0
		player.tm_frm = .9999
		if (not keeper_on_grnd) or (keeper_on_grnd and player.int_cnt <= 1):
			shot_acknowledged = FALSE
			player.go_cnt = 0
			init_stand_act(player)

#/******************************************************************************
#*****************************************************************************/

# void fall_action(match_player *player)
static func fall_action(player: match_player) -> void:
	go_toward_target(player)
	player.go_txdis *= TACKLE_DECEL
	player.go_tydis *= TACKLE_DECEL
	player.go_cnt -= 1

	if player.go_cnt == 1:
		init_anim(player, MC_GETUPF)
		player.tm_fstep *= (float(player.tm_rate + 128) / 128)
		player.tm_limbo = int(1 / player.tm_fstep)
	else:
		if not player.go_cnt:
			init_stand_act(player)

#/******************************************************************************
#*****************************************************************************/

# void init_tussles()
static func init_tussles() -> void:
	tussle_ptr = 0		# tussle_ptr=&tussle_tab[0];
	tussle_tab[tussle_ptr] = 0

#/******************************************************************************
#*****************************************************************************/

# void tussle_collision(match_player *p1,match_player *p2)
static func tussle_collision(p1: match_player, p2: match_player) -> void:
	var xoff: float
	var yoff: float
	var dist: float

	xoff = (p2.tm_x) - (p1.tm_x)
	yoff = (p2.tm_y) - (p1.tm_y)

	dist = Maths.calc_dist(xoff, yoff)

	if dist < prat * 0.7:

		# Sub vectors to get force of collision!
		var ef_xd: float = ((p1.tm_pow * p1.go_txdis) - (p2.tm_pow * p2.go_txdis))
		var ef_yd: float = ((p1.tm_pow * p1.go_tydis) - (p2.tm_pow * p2.go_tydis))
		var force: int = int(ABS(ef_xd) + ABS(ef_yd))

		# Add averaged vector!
		ef_xd = (p1.go_txdis) + (p2.go_txdis)
		ef_yd = (p1.go_tydis) + (p2.go_tydis)
		var power: int = ((p1.tm_pow + (32 if p1.tm_act == STEAL_ACT else 0) + (500 if p1.tm_act == SAVE_ACT else 0))
					- (p2.tm_pow + (32 if p2.tm_act == STEAL_ACT else 0) + (500 if p2.tm_act == SAVE_ACT else 0)))

		if power + (seed / 2) - 32 < 0:
			# Player 1 is shoved!
			if p2.tm_anim == MC_RUN:
				# Player 2 can barge run!
				init_anim(p2, MC_BARGE)
				p2.tm_barge = 20

			if p2.tm_player == KP_B:
				force *= 2

			if p2.tm_act == SAVE_ACT:
				force += 128 * 16

			# Update current movement!
			if force / 16 > seed and (not (seed & 3) or p2.tm_act == SAVE_ACT):
				var d: float = Maths.calc_dist(ef_xd, ef_yd)
				p1.tm_xdis = ef_xd / d
				p1.tm_ydis = ef_yd / d
				init_fall(p1)
				if p2.tm_act == SAVE_ACT and (p2.tm_poss + 2) * 32 < (float(seed) * ref_strictness / 128):
					man_down = TRUE
					Rules.init_foul(p2.tm_player, TRUE, FALSE)	# pass no. of fouler.
				else:
					p1.tm_x += (ef_xd)
					p1.tm_y += (ef_yd)

					if (p1.tm_act == RUN_ACT) or (p1.tm_act == JUMP_ACT):
						p1.tm_x -= (p1.go_txdis)
						p1.tm_y -= (p1.go_tydis)
			else:
				p1.tm_x += (ef_xd)
				p1.tm_y += (ef_yd)

				if (p1.tm_act == RUN_ACT) or (p1.tm_act == JUMP_ACT):
					p1.tm_x -= (p1.go_txdis)
					p1.tm_y -= (p1.go_tydis)
		else:
			# Player 2 is shoved!
			if p1.tm_anim == MC_RUN:
				# Player 1 can barge run!
				init_anim(p1, MC_BARGE)
				p1.tm_barge = 20

			# Update current movement!
			if force / 16 > seed and (not (seed & 3) or p2.tm_act == SAVE_ACT):
				var d: float = Maths.calc_dist(ef_xd, ef_yd)
				p2.tm_xdis = ef_xd / d
				p2.tm_ydis = ef_yd / d
				init_fall(p2)
				if p1.tm_act == SAVE_ACT and (p1.tm_poss + 2) * 32 < (float(seed) * ref_strictness / 128):
					man_down = TRUE
					Rules.init_foul(p1.tm_player, TRUE, FALSE)	# pass no. of fouler.
			else:
				p2.tm_x += (ef_xd)
				p2.tm_y += (ef_yd)

				if (p2.tm_act == RUN_ACT) or (p2.tm_act == JUMP_ACT):
					p2.tm_x -= (p2.go_txdis)
					p2.tm_y -= (p2.go_tydis)

#/******************************************************************************
#*****************************************************************************/

# void player_tussles()
static func player_tussles() -> void:
	var p: int = 0
	var p1: int
	var p2: int
	var op: int
	var same_team: int = FALSE
	# (tussle_ptr is an index into tussle_tab[]: tussle_ptr!=&tussle_tab[p] -> tussle_ptr!=p)
	while (tussle_ptr != p) and (not same_team):
		p1 = tussle_tab[p]
		p += 1
		op = p
		same_team = TRUE
		while tussle_ptr != op:
			p2 = tussle_tab[op]
			op += 1
			if ((p1 < 12) and (p2 > 11)) or ((p1 > 11) and (p2 < 12)):
				same_team = FALSE
				tussle_collision(teams[p1 - 1], teams[p2 - 1])

#/******************************************************************************
#*****************************************************************************/

# void inline add_to_tussle_list(int pnum)
static func add_to_tussle_list(pnum: int) -> void:
	# *tussle_ptr++=pnum;
	tussle_tab[tussle_ptr] = pnum
	tussle_ptr += 1

#/******************************************************************************
#*****************************************************************************/

# void do_action()
static func do_action() -> void:
	match teams[player_num - 1].tm_act:
		STAND_ACT:
			stand_action(teams[player_num - 1])

		RUN_ACT:
			run_action(teams[player_num - 1])
#/*
#		case TURN_ACT:
#			turn_action(&teams[player_num-1]);
#			break;
#*/
		TACKLE_ACT:
			tackle_action(teams[player_num - 1])

		FALL_ACT:
			fall_action(teams[player_num - 1])

		JUMP_ACT:
			jump_action(teams[player_num - 1])

		SAVE_ACT:
			save_action(teams[player_num - 1])

		THROW_ACT:
			throw_action(teams[player_num - 1])

		KPHOLD_ACT:
			kphold_action(teams[player_num - 1])

		STEAL_ACT:
			steal_action(teams[player_num - 1])

		KICK_ACT:
			kick_action(teams[player_num - 1])

		CELEB_ACT:
			celeb_action(teams[player_num - 1])

		CONTROL_ACT:
			control_action(teams[player_num - 1])

		STRIKE_ACT:
			strike_action(teams[player_num - 1])

		WAIT_ACT:
			wait_action(teams[player_num - 1])

		PICKUP_ACT:
			pickup_action(teams[player_num - 1])

		STOP_ACT:
			stop_action(teams[player_num - 1])

#/******************************************************************************
#*****************************************************************************/

# void new_dir(match_player *player,float x,float y)
static func new_dir(player: match_player, x: float, y: float) -> void:
	var d: float = Maths.calc_dist(x, y)
	var max: float

	# get maximum turn.
	max = ((14 + float(player.tm_rate) / 8) * PI / 180)		# MAX_TURN

	# get new normalised vector.
	var nx: float = x / d
	var ny: float = y / d

	var ox: float = player.tm_xdis
	var oy: float = player.tm_ydis

	# get difference (cos a).
	var dif: float = ((nx * ox) + (ny * oy))

	if dif < cos(max):

		# Which way to turn?
		if (nx * oy) > (ny * ox):
			max = -max

		nx = (ox * cos(max)) - (oy * sin(max))
		ny = (oy * cos(max)) + (ox * sin(max))

		# Error Correction...
		d = Maths.calc_dist(nx, ny)
		nx = nx / d
		ny = ny / d

		if ny > 1:
			ny = 1
			nx = 0

		if ny < -1:
			ny = -1
			nx = 0

		if nx > 1:
			nx = 1
			ny = 0

		if nx < -1:
			nx = -1
			ny = 0

	player.tm_xdis = nx
	player.tm_ydis = ny
	player.face_dir = Intell.get_dir(player.tm_xdis, player.tm_ydis)

#/******************************************************************************
#*****************************************************************************/

# void dir_movement(match_player *player)
static func dir_movement(player: match_player) -> void:
	var x: float
	var y: float

	if user_controlled and not player.tm_act and player.tm_player == ball_poss:
		x = player.tm_xdis * 10
		y = player.tm_ydis * 10
	else:
		x = player.go_tx - player.tm_x
		y = player.go_ty - player.tm_y

	if (x != 0) or (y != 0):
		new_dir(player, x, y)

#/******************************************************************************
#*****************************************************************************/

# void dir_ball(match_player *player)
static func dir_ball(player: match_player) -> void:
	var x: float = ballx - player.tm_x
	var y: float = bally - player.tm_y
	if (x != 0) or (y != 0):
		new_dir(player, x, y)

#/******************************************************************************
#*****************************************************************************/

# void dir_new_d(match_player *player)
static func dir_new_d(player: match_player) -> void:
	new_dir(player, newdx, newdy)

#/******************************************************************************
#*****************************************************************************/

# void dir_must_face(match_player *player)
static func dir_must_face(player: match_player) -> void:
	new_dir(player, player.mface_x, player.mface_y)

#/******************************************************************************
#*****************************************************************************/

# void dir_away(match_player *player)
static func dir_away(player: match_player) -> void:
	var x: float
	var y: float = 0

	if player.tm_player < 12:
		x = 1
	else:
		x = -1

	new_dir(player, x, y)

#/******************************************************************************
#*****************************************************************************/

# void select_hlite(match_player *player,short u)
static func select_hlite(player: match_player, u: int) -> void:
	player.tm_hcol = u8(u - 1)				# Highlight colour.
	if ball_poss == player.tm_player:
		if in_cross_area:
			player.tm_htype = HLITE_CROSS
		else:
			if player.tm_srng:
				player.tm_htype = HLITE_SHOOT
			else:
				player.tm_htype = HLITE_BALL
	else:
		if player.special > 0 and player.int_move == I_INTERCEPT:
			player.tm_htype = HLITE_SPECIAL
		else:
			if player.special < 0 and player.int_move == I_INTERCEPT:
				player.tm_htype = HLITE_STAR
			else:
				player.tm_htype = HLITE_NORM

#/******************************************************************************
#*****************************************************************************/

# void user_conts(match_player *player)
static func user_conts(player: match_player) -> void:
	var u: int = player.control
	if u:
		ux = users_dir[u - 1].x
		uy = users_dir[u - 1].y
		um = users_dir[u - 1].m

		if users_dir[u - 1].f & 1:
			uf1 = TRUE
			if player.tm_player == KP_B:
				uf1 = u8(uf1 + 1)
		else:
			uf1 = FALSE

		if users_dir[u - 1].f & 2:
			uf2 = TRUE
		else:
			uf2 = FALSE

		if uf1 or uf2:
			# Any fire buttons pressed?
			if users[u - 1].chng:
				# Just been selected... wait for release of buttons...
				uf1 = FALSE
				uf2 = FALSE
		else:
			if users[u - 1].chng:
				# Buttons released...
				users[u - 1].chng = FALSE

		if FORCE_SELECT:
			# (#ifdef EURO96 / #ifndef EURO96 select the condition of the same if-statement)
			var fsel: bool = false
			if EURO96:
				fsel = bool(uf2 and uf1 and player.tm_dist > FSELECT_DIST and users[u - 1].type < 0)
			if not EURO96:
				fsel = bool(uf2 and player.tm_dist > FSELECT_DIST and users[u - 1].type < 0)
			if fsel:
				uf1 = FALSE
				uf2 = FALSE

				if (forced >> (u - 1)) & 1:
					forced -= 1 << (u - 1)
				else:
					forced += 1 << (u - 1)
			else:
				if (forced >> (u - 1)) & 1:
					forced -= 1 << (u - 1)

#/******************************************************************************
#*****************************************************************************/

# void process_dir(match_player *player)
static func process_dir(player: match_player) -> void:
	var dm: int = player.dir_mode		# switch(player->dir_mode)
	if dm == 0:
		dir_movement(player)

	elif dm == -1:
		dir_movement(player)
		player.dir_mode = 1

	elif dm == 1:
		dir_ball(player)

	elif dm == 2:
		player.face_dir = Intell.get_dir(player.tm_xdis, player.tm_ydis)

	elif dm == 3:
		dir_away(player)

	elif dm == 4:
		player.face_dir = Intell.get_dir(player.tm_xdis, player.tm_ydis)
		player.dir_mode = 0

	elif dm == 5:
		dir_new_d(player)

	elif dm == 6:
		dir_must_face(player)

#/******************************************************************************
#*****************************************************************************/

# void init_stand_anim(match_player *player)
static func init_stand_anim(player: match_player) -> void:
	player.tm_anim = MC_STAND
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_STAND_FS

#/******************************************************************************
#*****************************************************************************/

# void init_penalty_anim(match_player *player)
static func init_penalty_anim(player: match_player) -> void:
	if player.tm_anim != MC_PENALTY:
		player.tm_anim = MC_PENALTY
		player.tm_newanim = TRUE
		player.tm_frm = 0
		player.tm_fstep = MC_PENALTY_FS

#/******************************************************************************
#*****************************************************************************/

# void init_shame_anim(match_player *player)
static func init_shame_anim(player: match_player) -> void:
	player.tm_anim = MC_SHAMEW
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_SHAMEW_FS

#/******************************************************************************
#*****************************************************************************/

# void init_standb_anim(match_player *player)
static func init_standb_anim(player: match_player) -> void:
	player.tm_anim = MC_STANDB
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_STANDB_FS

#/******************************************************************************
#*****************************************************************************/

# void init_barge_anim(match_player *player)
static func init_barge_anim(player: match_player) -> void:
	# Always go from run animation to barge!

	player.tm_anim = MC_BARGE
	player.tm_fstep = MC_BARGE_FS * (actual_spd(player) / MC_RUN_SPD)
	player.tm_frm += 0.5

#/******************************************************************************
#*****************************************************************************/

# void init_run_anim(match_player *player)
static func init_run_anim(player: match_player) -> void:
	if not player.tm_barge or player.tm_anim != MC_BARGE:
		# Not barging!!!
		if user_controlled and uf2:
			player.tm_fstep = (MC_RUN_FS * (actual_spd(player) / MC_RUN_SPD)) * 1.2
		else:
			player.tm_fstep = MC_RUN_FS * (actual_spd(player) / MC_RUN_SPD)

		if ABS(int(player.tm_anim)) == MC_JOG:
			# Tween to run from jog....
			player.tm_anim = MC_RUN
			player.tm_frm += 0.4
		else:
			if ABS(int(player.tm_anim)) != MC_RUN:
				player.tm_anim = MC_RUN
				player.tm_newanim = TRUE
				player.tm_frm = 0

#/******************************************************************************
#*****************************************************************************/

# void init_jog_anim(match_player *player)
static func init_jog_anim(player: match_player) -> void:
	player.tm_fstep = MC_JOG_FS * ((actual_spd(player) / 2) / MC_JOG_SPD)

	if ABS(int(player.tm_anim)) == MC_RUN:
		# Tween to jog from run....
		player.tm_anim = MC_JOG
		player.tm_frm += 0.7
	else:
		if ABS(int(player.tm_anim)) == MC_BARGE:
			player.tm_anim = MC_JOG
		else:
			if ABS(int(player.tm_anim)) != MC_JOG:
				player.tm_anim = MC_JOG
				player.tm_newanim = TRUE
				player.tm_frm = 0

#/******************************************************************************
#*****************************************************************************/

# void init_shoot_anim(match_player *player)
static func init_shoot_anim(player: match_player) -> void:
	player.tm_fstep = MC_SHOOT_FS
	var n: float

	if ((AFEQS(player.tm_anim, MC_RUN)) or
			(AFEQS(player.tm_anim, MC_JOG))):
		if c_modf(player.tm_frm) > 0.5:
			# Left Footed Shot...
			player.tm_anim = MC_SHOOTL
			player.tm_newanim = TRUE
			player.tm_frm -= 0.5
		else:
			# Right Footed Shot...
			player.tm_anim = MC_SHOOTR
			player.tm_newanim = TRUE
	else:
		# Right Footed Shot...
		player.tm_anim = MC_SHOOTR
		player.tm_newanim = TRUE
		player.tm_frm = 0

#/******************************************************************************
#*****************************************************************************/

# void init_kick_anim(match_player *player,int a)
static func init_kick_anim(player: match_player, a: int) -> void:
	var an: int = a
	var n: float
	var t: float
	var f: float

	if AFEQS(player.tm_anim, MC_RUN):
		t = c_modf(player.tm_frm)
	else:
		if AFEQS(player.tm_anim, MC_JOG) or AFEQS(player.tm_anim, MC_BARGE):
			t = c_modf((player.tm_frm + 0.5))

	if (AFEQS(player.tm_anim, MC_JOG)) or (AFEQS(player.tm_anim, MC_RUN)) or (AFEQS(player.tm_anim, MC_BARGE)):
		match a:
			MC_PASSL, MC_CHIPL, MC_BACKHEELL:
				if t >= 0.3 and t < 0.8:
					# Right Footed...
					t = (t - 0.3)
					an -= 1
				else:
					# Left Footed...
					if t < 0.3:
						t = (t + 0.2)
					else:
						t = (t - 0.8)

				# switch(a)
				if a == MC_TOEL:
					f = 0.7
				else:
					# default:
					f = 0.8

				player.tm_anim = ABS(an)
				player.tm_newanim = TRUE
				player.tm_frm = (t * f)

			MC_SHOOTL, MC_CROSSL:
				if t >= 0.25 and t < 0.75:
					# Right Footed...
					t = (t - 0.25)
					an -= 1
				else:
					# Left Footed...
					if t < 0.25:
						t = (t + 0.25)
					else:
						t = (t - 0.75)

				match a:
					MC_SHOOTL:
						f = 0.6

					MC_CROSSL:
						f = 0.5

				player.tm_anim = ABS(an)
				player.tm_newanim = TRUE
				player.tm_frm = (t * f)
	else:
		# Right Footed...
		player.tm_anim = ABS(an)
		player.tm_newanim = TRUE
		player.tm_frm = 0

	match a:
		MC_PASSL:
			player.tm_fstep = MC_PASS_FS
		MC_CHIPL:
			player.tm_fstep = MC_CHIP_FS
		MC_BACKHEELL:
			player.tm_fstep = MC_BACKHEEL_FS
		MC_SHOOTL:
			player.tm_fstep = MC_SHOOT_FS
		MC_CROSSL:
			player.tm_fstep = MC_CROSS_FS

#/******************************************************************************
#*****************************************************************************/

# void init_kick_l_anim(match_player *player,int a)
static func init_kick_l_anim(player: match_player, a: int) -> void:
	var an: int = a
	var n: float
	var t: float

	if AFEQS(player.tm_anim, MC_RUN):
		t = c_modf(player.tm_frm)
	else:
		if AFEQS(player.tm_anim, MC_JOG):
			t = c_modf((player.tm_frm + 0.5))

	if (AFEQS(player.tm_anim, MC_JOG)) or (AFEQS(player.tm_anim, MC_RUN)):
		# Left Footed...
		if t < 0.3:
			t = (t + 0.2)
		else:
			if t > 0.8:
				t = (t - 0.8)
			else:
				t = 0

		player.tm_frm = (t * 0.8)
	else:
		player.tm_frm = 0

	player.tm_anim = ABS(an)
	player.tm_newanim = TRUE

	match an:
		MC_DIAGPASSL:
			player.tm_fstep = MC_DIAGPASS_FS
		MC_DIAGBACKL:
			player.tm_fstep = MC_DIAGBACK_FS
		MC_SIDEPASSL:
			player.tm_fstep = MC_SIDEPASS_FS

#/******************************************************************************
#*****************************************************************************/

# void init_kick_r_anim(match_player *player,int a)
static func init_kick_r_anim(player: match_player, a: int) -> void:
	var an: int = a
	var n: float
	var t: float

	if AFEQS(player.tm_anim, MC_RUN):
		t = c_modf(player.tm_frm)
	else:
		if AFEQS(player.tm_anim, MC_JOG):
			t = c_modf((player.tm_frm + 0.5))

	if (AFEQS(player.tm_anim, MC_JOG)) or (AFEQS(player.tm_anim, MC_RUN)):
		if t >= 0.3 and t < 0.8:
			# Right Footed...
			t = (t - 0.3)
		else:
			t = 0

		player.tm_frm = (t * 0.8)
	else:
		player.tm_frm = 0

	player.tm_anim = ABS(an)
	player.tm_newanim = TRUE

	match an:
		MC_DIAGPASSR:
			player.tm_fstep = MC_DIAGPASS_FS
		MC_DIAGBACKR:
			player.tm_fstep = MC_DIAGBACK_FS
		MC_SIDEPASSR:
			player.tm_fstep = MC_SIDEPASS_FS

#/******************************************************************************
#*****************************************************************************/

# void init_trap_anim(match_player *player)
static func init_trap_anim(player: match_player) -> void:
	player.tm_fstep = MC_TRAP_FS * Intell.fstep_factor(player.tm_cont)
	player.tm_frm = 0
	player.tm_newanim = TRUE
	var n: float

	if AFEQS(player.tm_anim, MC_RUN):
		if c_modf(player.tm_frm) >= 0.4 and c_modf(player.tm_frm) < 0.9:
			# Left Footed Trap...
			player.tm_anim = MC_TRAPL
		else:
			# Right Footed Trap...
			player.tm_anim = MC_TRAPR
	else:
		# Right Footed Trap...
		player.tm_anim = MC_TRAPR

#/******************************************************************************
#*****************************************************************************/

# void init_ride_anim(match_player *player)
static func init_ride_anim(player: match_player) -> void:
	var n: float
	var t: float

	if AFEQS(player.tm_anim, MC_RUN):
		t = c_modf(player.tm_frm)
	else:
		if AFEQS(player.tm_anim, MC_JOG):
			t = c_modf((player.tm_frm + 0.5))

	if (AFEQS(player.tm_anim, MC_JOG)) or (AFEQS(player.tm_anim, MC_RUN)):
		if t >= 0.35 and t < 0.85:
			# Left Footed...
			player.tm_anim = MC_RIDEL
			player.tm_newanim = TRUE
			t = (t - 0.35)
		else:
			# Right Footed...
			player.tm_anim = MC_RIDER
			player.tm_newanim = TRUE
			if t >= 0.85:
				t = t - 0.85
			else:
				t = t + 0.15
		player.tm_frm = (t * 2 / 5)
	else:
		player.tm_frm = 0
		player.tm_anim = MC_RIDEL
		player.tm_newanim = TRUE

	# Player's speed and flair determine how fast he rides tackle...
	var f: float = (player.tm_flair + player.tm_rate) / 2
	f = MC_RIDE_FS + (0.000536 * f)
	player.tm_fstep = f

#/******************************************************************************
#*****************************************************************************/

# void init_tack_anim(match_player *player)
static func init_tack_anim(player: match_player) -> void:
	player.tm_fstep = MC_S_TACKLE_FS
	player.tm_anim = MC_S_TACKLE
	player.tm_newanim = TRUE
	player.tm_frm = 0

#/******************************************************************************
#*****************************************************************************/

# void init_shdr_anim(match_player *player)
static func init_shdr_anim(player: match_player) -> void:
	if (ABS(int(player.tm_anim)) != MC_S_HEAD) and (ABS(int(player.tm_anim)) != MC_J_HEAD):
		player.tm_fstep = MC_S_HEAD_FS * Intell.fstep_factor(player.tm_flair)
		player.tm_anim = MC_S_HEAD
		player.tm_newanim = TRUE
		player.tm_frm = 0

#/******************************************************************************
#*****************************************************************************/

# void init_jhdr_anim(match_player *player)
static func init_jhdr_anim(player: match_player) -> void:
	player.tm_fstep = MC_J_HEAD_FS * Intell.fstep_factor(player.tm_flair)
	player.tm_anim = MC_J_HEAD
	player.tm_newanim = TRUE
	player.tm_frm = 0

#/******************************************************************************
#*****************************************************************************/

# void init_dhdr_anim(match_player *player)
static func init_dhdr_anim(player: match_player) -> void:
	player.tm_fstep = MC_DV_HEAD_FS * Intell.fstep_factor(player.tm_flair)
	player.tm_anim = MC_DV_HEAD
	player.tm_newanim = TRUE
	player.tm_frm = 0

#/******************************************************************************
#*****************************************************************************/

# void init_ohd_anim(match_player *player)
static func init_ohd_anim(player: match_player) -> void:
	player.tm_fstep = MC_OVERHEAD_FS * Intell.fstep_factor(player.tm_flair)
	player.tm_anim = MC_OVERHEAD
	player.tm_newanim = TRUE
	player.tm_frm = 0

#/******************************************************************************
#*****************************************************************************/

# void init_voll_anim(match_player *player)
static func init_voll_anim(player: match_player) -> void:
	player.tm_fstep = MC_VOLLEY_FS * Intell.fstep_factor(player.tm_flair)
	player.tm_anim = MC_VOLLEYL
	player.tm_newanim = TRUE
	player.tm_frm = 0

#/******************************************************************************
#*****************************************************************************/

# void init_fallr_anim(match_player *player)
static func init_fallr_anim(player: match_player) -> void:
	player.tm_fstep = MC_FALLR_FS
	player.tm_anim = MC_FALLR
	player.tm_newanim = TRUE
	player.tm_frm = 0

#/******************************************************************************
#*****************************************************************************/

# void init_chest_anim(match_player *player)
static func init_chest_anim(player: match_player) -> void:
	player.tm_fstep = MC_CHEST_FS * Intell.fstep_factor(player.tm_cont)
	player.tm_anim = MC_CHEST
	player.tm_newanim = TRUE
	player.tm_frm = 0

#/******************************************************************************
#*****************************************************************************/

# void init_dnhead_anim(match_player *player)
static func init_dnhead_anim(player: match_player) -> void:
	player.tm_fstep = MC_D_HEAD_FS * Intell.fstep_factor(player.tm_cont)
	player.tm_anim = MC_D_HEAD
	player.tm_newanim = TRUE
	player.tm_frm = 0

#/******************************************************************************
#*****************************************************************************/

# void init_getupf_anim(match_player *player)
static func init_getupf_anim(player: match_player) -> void:
	player.tm_fstep = MC_GETUPF_FS
	player.tm_anim = MC_GETUPF
	player.tm_newanim = TRUE
	player.tm_frm = 0

#/******************************************************************************
#*****************************************************************************/

# void init_getup_anim(match_player *player)
static func init_getup_anim(player: match_player) -> void:
	player.tm_fstep = MC_GETUP_FS
	player.tm_anim = MC_GETUP
	player.tm_newanim = TRUE
	player.tm_frm = 0

#/******************************************************************************
#*****************************************************************************/

# void init_save_anim(match_player *player,int an)
static func init_save_anim(player: match_player, an: int) -> void:
	player.tm_anim = ABS(an)
	player.tm_newanim = TRUE
	player.tm_frm = 0

#/******************************************************************************
#*****************************************************************************/

# void init_bounce_anim(match_player *player)
static func init_bounce_anim(player: match_player) -> void:
	player.tm_anim = MC_BOUNCE
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_BOUNCE_FS

#/******************************************************************************
#*****************************************************************************/

# void init_kout_anim(match_player *player)
static func init_kout_anim(player: match_player) -> void:
	player.tm_anim = MC_KICKOUT
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_KICKOUT_FS

#/******************************************************************************
#*****************************************************************************/

# void init_hvoll_anim(match_player *player)
static func init_hvoll_anim(player: match_player) -> void:
	player.tm_anim = MC_HALFVOLL
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_HALFVOLL_FS

#/******************************************************************************
#*****************************************************************************/

# void init_throw_anim(match_player *player)
static func init_throw_anim(player: match_player) -> void:
	player.tm_anim = MC_THROW
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_THROW_FS

#/******************************************************************************
#*****************************************************************************/

# void init_roll_anim(match_player *player)
static func init_roll_anim(player: match_player) -> void:
	player.tm_anim = MC_ROLL
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_ROLL_FS

#/******************************************************************************
#*****************************************************************************/

# void init_runb_anim(match_player *player)
static func init_runb_anim(player: match_player) -> void:
	player.tm_anim = MC_RUNWITHB
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_RUNWITHB_FS

#/******************************************************************************
#*****************************************************************************/

# void init_waveup_anim(match_player *player)
static func init_waveup_anim(player: match_player) -> void:
	player.tm_anim = MC_WAVEUP
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_WAVEUP_FS

#/******************************************************************************
#*****************************************************************************/

# void init_throwl_anim(match_player *player)
static func init_throwl_anim(player: match_player) -> void:
	player.tm_anim = MC_THROWL
	player.tm_newanim = TRUE
	player.tm_frm = 0.02
	player.tm_fstep = MC_THROWL_FS

#/******************************************************************************
#*****************************************************************************/

# void init_throws_anim(match_player *player)
static func init_throws_anim(player: match_player) -> void:
	player.tm_anim = MC_THROWS
	player.tm_newanim = TRUE
	player.tm_frm = 0.02
	player.tm_fstep = MC_THROWS_FS

#/******************************************************************************
#*****************************************************************************/

# void init_crtostb_anim(match_player *player)
static func init_crtostb_anim(player: match_player) -> void:
	player.tm_anim = MC_CRTOSTB
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_CRTOSTB_FS

#/******************************************************************************
#*****************************************************************************/

# void init_crl_anim(match_player *player)
static func init_crl_anim(player: match_player) -> void:
	player.tm_anim = MC_CROSSL
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_CROSS_FS

#/******************************************************************************
#*****************************************************************************/

# void init_crr_anim(match_player *player)
static func init_crr_anim(player: match_player) -> void:
	player.tm_anim = MC_CROSSR
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_CROSS_FS

#/******************************************************************************
#*****************************************************************************/

# void init_tostand_anim(match_player *player,int an)
static func init_tostand_anim(player: match_player, an: int) -> void:
	player.tm_anim = ABS(an)
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_STOS_FS

#/******************************************************************************
#*****************************************************************************/

# void init_tostandb_anim(match_player *player,int an)
static func init_tostandb_anim(player: match_player, an: int) -> void:
	player.tm_anim = ABS(an)
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_STOSB_FS

#/******************************************************************************
#*****************************************************************************/

# void init_socks_anim(match_player *player,int an)
static func init_socks_anim(player: match_player, an: int) -> void:
	player.tm_anim = ABS(an)
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_SOCKS_FS

#/******************************************************************************
#*****************************************************************************/

# void init_celeb_anim(match_player *player,int an)
static func init_celeb_anim(player: match_player, an: int) -> void:
	player.tm_anim = ABS(an)
	player.tm_newanim = TRUE
	player.tm_frm = 0
	match an:
		MC_CELEB:
			player.tm_fstep = MC_CELEB_FS

		MC_PUMP:
			player.tm_fstep = MC_PUMP_FS

		MC_BABY:
			player.tm_fstep = MC_BABY_FS

		MC_REEVES:
			player.tm_fstep = MC_REEVES_FS

		MC_MILLER:
			player.tm_fstep = MC_MILLER_FS

		MC_PLANE:
			player.tm_fstep = MC_PLANE_FS

		MC_FINGER:
			player.tm_fstep = MC_FINGER_FS

		MC_KNEE:
			player.tm_fstep = MC_KNEE_FS

		MC_MOON:
			player.tm_fstep = MC_MOON_FS

		MC_DUCK:
			player.tm_fstep = MC_DUCK_FS

#/******************************************************************************
#*****************************************************************************/

# void init_pickup_anim(match_player *player)
static func init_pickup_anim(player: match_player) -> void:
	player.tm_anim = MC_PICKBALL
	player.tm_newanim = TRUE
	player.tm_frm = 0
	player.tm_fstep = MC_PICKBALL_FS

#/******************************************************************************
#*****************************************************************************/

# void init_trot_anim(match_player *player)
static func init_trot_anim(player: match_player) -> void:
	var x: float = player.go_tx - player.tm_x
	var y: float = player.go_ty - player.tm_y

	var d: float = Maths.calc_dist(x, y)
	# d is effective speed!
	player.tm_fstep = actual_spd(player) * MC_TROTA_FS / 2

	x = x / d
	y = y / d

	var nx: float = (x * player.tm_xdis) + (y * player.tm_ydis)
	var ny: float = (y * player.tm_xdis) - (x * player.tm_ydis)

	if player.tm_anim < MC_TROTB or player.tm_anim > MC_TROTE:
		# Not currently in trot animation...
		player.tm_frm = 0
		player.tm_newanim = TRUE

	var gd: int = (1 + Intell.get_dir(nx, ny))
	match gd:
		8:
			player.tm_anim = MC_TROTF

		7:
			player.tm_anim = MC_TROTG

		6:
			player.tm_anim = MC_TROTH

		5:
			player.tm_anim = MC_TROTA

		4:
			player.tm_anim = MC_TROTB

		3:
			player.tm_anim = MC_TROTC

		2:
			player.tm_anim = MC_TROTD

		1:
			player.tm_anim = MC_TROTE

#/******************************************************************************
#*****************************************************************************/

# void init_anim(match_player *player,int an)
static func init_anim(player: match_player, an: int) -> void:
#/*
#	if (player->tm_act==STAND_ACT)
#	{
#// Prevent temporary jump to stand animation!
#		player->tm_anim=player->ls_anim;
#		player->tm_frm=player->ls_frm;
#	}
#*/
	if an >= MC_AFOOTB and an <= MC_CJUMPBR:
		init_save_anim(player, an)
	else:
		match an:
			MC_PASSL, MC_CHIPL, MC_SHOOTL, MC_BACKHEELL:
				init_kick_anim(player, an)

			MC_DIAGPASSL, MC_DIAGBACKL, MC_SIDEPASSL:
				init_kick_l_anim(player, an)

			MC_CROSSL:
				init_crl_anim(player)

			MC_CROSSR:
				init_crr_anim(player)

			MC_DIAGPASSR, MC_DIAGBACKR, MC_SIDEPASSR:
				init_kick_r_anim(player, an)

			MC_STOSL, MC_STOSR:
				init_tostand_anim(player, an)

			MC_STOSBL, MC_STOSBR:
				init_tostandb_anim(player, an)

			MC_CRTOSTB:
				init_crtostb_anim(player)

			MC_STAND:
				init_stand_anim(player)

			MC_PENALTY:
				if EURO96:
					init_penalty_anim(player)
				else:
					init_stand_anim(player)

			MC_SHAME:
				init_shame_anim(player)

			MC_TRAPL:
				init_trap_anim(player)

			MC_CHEST:
				init_chest_anim(player)

			MC_D_HEAD:
				init_dnhead_anim(player)

			MC_BARGE:
				init_barge_anim(player)

			MC_RUN:
				init_run_anim(player)

			MC_JOG:
				init_jog_anim(player)

			MC_TROTA:
				init_trot_anim(player)

			MC_S_TACKLE:
				init_tack_anim(player)

			MC_DV_HEAD:
				init_dhdr_anim(player)

			MC_S_HEAD:
				init_shdr_anim(player)

			MC_J_HEAD:
				init_jhdr_anim(player)

			MC_OVERHEAD:
				init_ohd_anim(player)

			MC_VOLLEYL:
				init_voll_anim(player)

			MC_FALLR:
				init_fallr_anim(player)

			MC_GETUPF:
				init_getupf_anim(player)

			MC_GETUP:
				init_getup_anim(player)

			MC_RIDEL:
				init_ride_anim(player)

			MC_SOCKSL, MC_SOCKSR:
				init_socks_anim(player, an)

			MC_CELEB, MC_KNEE, MC_DUCK, MC_MOON, MC_MILLER, MC_BABY, MC_PUMP, MC_REEVES, MC_FINGER, MC_PLANE:
				init_celeb_anim(player, an)

			MC_PICKBALL:
				init_pickup_anim(player)

			# Keeper specific anims...

			MC_STANDB:
				init_standb_anim(player)

			MC_BOUNCE:
				init_bounce_anim(player)

			MC_KICKOUT:
				init_kout_anim(player)

			MC_HALFVOLL:
				init_hvoll_anim(player)

			MC_THROW:
				init_throw_anim(player)

			MC_ROLL:
				init_roll_anim(player)

			MC_RUNWITHB:
				init_runb_anim(player)

			MC_WAVEUP:
				init_waveup_anim(player)
#/*
#			case(MC_PENALTY):
#				init_penalty_anim(player);
#				break;
#*/
			MC_THROWL:
				init_throwl_anim(player)

			MC_THROWS:
				init_throws_anim(player)

#/******************************************************************************
#*****************************************************************************/

# void process_anims(match_player *player)
static func process_anims(player: match_player) -> void:
	if not (ABS(player.tm_anim) == MC_THROWL and player.tm_frm < 0.001):
		# Initial throw-in animation is frozen...
		player.tm_frm += player.tm_fstep

	if player.tm_anim == MC_BARGE and player.tm_act == RUN_ACT:
		player.tm_barge = u8(player.tm_barge - 1)
		if not player.tm_barge:
			init_anim(player, MC_RUN)
	else:
		player.tm_barge = 0

	if player.tm_limbo:
		player.tm_limbo -= 1
		if not player.tm_limbo:
			# Finished animation...
			var a: int = ABS(player.tm_anim)
			match a:
				MC_KICKOUT, MC_HALFVOLL, MC_THROW, MC_THROWL, MC_THROWS, MC_ROLL, MC_GETUPF, MC_GETUP:
					init_stand_act(player)

#/******************************************************************************
#******************************************************************************/

# User controls player...

# void user_play(int player_num)
static func user_play(player_num: int) -> void:
	user_conts(teams[player_num - 1])

	Intell.override(teams[player_num - 1])

	Intell.player_ints(teams[player_num - 1])

	Intell.user_intelligence(teams[player_num - 1])

	if not teams[player_num - 1].tm_limbo and (ball_limbo_on <= 0 or (ball_limbo_on > 0 and ball_limbo_p != player_num)):
		Intell.player_comment(teams[player_num - 1])

		do_action()

#/******************************************************************************
#*****************************************************************************/

# Computer controls player...

# void computer_play(int player_num)
static func computer_play(player_num: int) -> void:
	# (#ifdef EURO96: the penalty-kick branch only exists when EURO96 is defined)
	if EURO96 and (setp_taker == player_num and ((player_num < 12 and not auto_users_a)
			or (player_num > 11 and not auto_users_b)) and already_there
			and (match_mode == PEN_KICK_A or match_mode == PEN_KICK_B)):
		if not allow_replay:
			Upd3D.init_replay()

		if ball_poss != setp_taker:
			BallInt.collect_ball(teams[setp_taker - 1])

		# Must be a computer penalty kick...
		if reselection:
			setp_kick_x = teams[setp_taker - 1].tm_xdis
			setp_kick_y = teams[setp_taker - 1].tm_ydis
			setp_power = 0
			setp_hgt = 0
			setp_byd = cntspot_y
			setp_bzd = 0
			reselection = FALSE
		comp_set_piece(teams[player_num - 1])
	else:
		teams[player_num - 1].tm_htype = HLITE_OFF			# Turn highlight off!

		Intell.override(teams[player_num - 1])

		Intell.player_ints(teams[player_num - 1])

		Intell.intelligence(teams[player_num - 1])

		if not teams[player_num - 1].tm_limbo and (ball_limbo_on <= 0 or (ball_limbo_on > 0 and ball_limbo_p != player_num)):
			Intell.player_comment(teams[player_num - 1])

			do_action()

#/******************************************************************************
#*****************************************************************************/

# void go_team(int p)
static func go_team(p: int) -> void:
	if (p < 12 and (team_a_on or p == KP_A)) or (p >= 12 and (team_b_on or p == KP_B)):
		player_num = p
		while player_num < p + players / 2:
			if teams[player_num - 1].guy_on:

				# For debugging purposes...
				if player_num == 10:
					player_num += 1
					player_num -= 1

				process_anims(teams[player_num - 1])

				if not teams[player_num - 1].tm_limbo and (not ball_limbo_on or (ball_limbo_on and ball_limbo_p != player_num)):
					# He is NOT bound up in animation!!!

					if not just_thrown:
						BallInt.ball_interact(teams[player_num - 1])

					if just_scored:
						user_controlled = FALSE
					else:
						user_controlled = teams[player_num - 1].control

					if user_controlled:
						# User controls player...
						user_plr = player_num

						if match_mode and match_mode != THROW_IN_A and match_mode != THROW_IN_B:
							if (user_taker == user_controlled) and (already_there):
								user_set_piece(teams[player_num - 1])
								if not ball_poss:
									teams[player_num - 1].tm_leave = -TRUE
							else:
								computer_play(player_num)
						else:
							user_play(player_num)
					else:
						computer_play(player_num)

					if teams[player_num - 1].tm_act <= TURN_ACT or teams[player_num - 1].tm_act == SAVE_ACT:
						add_to_tussle_list(teams[player_num - 1].tm_player)

					if not teams[player_num - 1].tm_limbo and (not ball_limbo_on or (ball_limbo_on and ball_limbo_p != player_num)):
						process_dir(teams[player_num - 1])
			player_num += 1

#/******************************************************************************
#*****************************************************************************/

# void select_all_hlites()
static func select_all_hlites() -> void:
	var u: int
	var i: int
	var hcol: int = 1
	for p in range(MAX_NET_USERS):
		if users[p].control != NET_CTRL and users[p].control and users[p].type:
			# Controlled by a user on this machine...
			if users[p].type > 0:
				# Fixed player...
				select_hlite(teams[users[p].type - 1], hcol)
				hcol = u8(hcol + 1)
			else:
				# Auto-user...
				if users[p].type == -1:
					# Team A...
					for ii in range(0, 11):
						i = ii
						if teams[i].control == (p + 1):
							# This user...
							select_hlite(teams[i], hcol)
							break
					hcol = u8(hcol + 1)
				else:
					# Team B...
					for ii in range(11, 22):
						i = ii
						if teams[i].control == (p + 1):
							# This user...
							select_hlite(teams[i], hcol)
							break
					hcol = u8(hcol + 1)

#/******************************************************************************
#*****************************************************************************/

# void process_teams()
static func process_teams() -> void:

	var p: int

	init_tussles()

	if frame:
		p = 1
	else:
		p = 12

	go_team(p)

	if p == 1:
		p = 12
	else:
		p = 1

	go_team(p)

	if not dead_ball_cnt and not just_scored:
		player_tussles()
