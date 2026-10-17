# Port of SOURCE/BALLINT.CPP  (assembled by tools/assemble.py - edit the files in parts/)
class_name BallInt extends Glob
#******************************************************************************
#******************************************************************************
#
# Ball-Player interaction routines...
#
#******************************************************************************
#******************************************************************************

# #include <stdio.h> "audio.h" "defines.h" "externs.h" "global.h" "data.h" "3deng.h"

# extern capfrm *player_p;
# extern mcap *mcaps;

# Offset of the ball point (point 23) inside a capfrm: [(23*3)+1]
const _MC_BALL_PT := (23 * 3) + 1

#******************************************************************************
#******************************************************************************

# void out_mcball_coords()
static func out_mcball_coords() -> void:
	var str1: String
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	var an: int
	var cp: int
	var frms: int
	var ball_in: int

	an = 0
	while an < 117:
		frms = mcaps[an].capfrms
		ball_in = 0

		cp = 0
		while cp < frms:
			var p: Array = player_p[mcaps[an].cappts + (cp)]
			var pi_: int = _MC_BALL_PT
			if p[pi_ + 1] < 0:
# Ball not included...
				if ball_in:
# Output last pos. of ball...
					str1 = "%d\tReleased\tfrms=%d\tcp=%d\tx=%1.3f\ty=%1.3f\tz=%1.3f\n" % [an, frms, cp, x, y, z]
					printraw(str1)
					cp = frms
			else:
				x = p[pi_]; pi_ += 1
				z = p[pi_]; pi_ += 1
				y = -p[pi_]; pi_ += 1
				if not ball_in:
# Contact...
					str1 = "%d\tcontact\tfrms=%d\tcp=%d\tx=%1.3f\ty=%1.3f\tz=%1.3f\n" % [an, frms, cp, x, y, z]
					printraw(str1)
					ball_in = 1
			cp += 1

		if not ball_in:
# Haven't came across ball yet...
			str1 = "%d\tBall not included.\n" % an
			printraw(str1)
		an += 1

#******************************************************************************
#******************************************************************************

# void get_mcball_coords(match_player *player)
static func get_mcball_coords(player: match_player) -> void:
	var an: int = s16(int(player.ls_anim))
	var cp: float = player.ls_frm
	var z: float = 0.0
	var p: Array = []
	# PORT NOTE: player_p/mcaps are the renderer's motion-capture tables; if they
	# have not been loaded the ball is treated as "not in the capture" (z<=0 branch).
	if not player_p.is_empty():
		p = player_p[mcaps[an].cappts + s16(int(cp * mcaps[an].capfrms))]
		z = p[_MC_BALL_PT + 1]
	if z > 0:
		var x: float = p[_MC_BALL_PT]
		var y: float = -p[_MC_BALL_PT + 2]
		var d: float = Maths.calc_dist(x, y)
		x = x / d
		y = y / d
		ballx = player.tm_x + d * ((x * player.tm_xdis) - (y * player.tm_ydis))
		bally = player.tm_y + d * ((y * player.tm_xdis) + (x * player.tm_ydis))
		ballz = z
	else:
		ballx = player.tm_x
		bally = player.tm_y
		ballz = ball_diam / 2

#******************************************************************************
#******************************************************************************

# void user_header(match_player *player)
static func user_header(player: match_player) -> void:
	var power: float
	if (uf1) and (not uf2) and (in_header_rng):
		if um:
# Shoot header in joystick dir.
			power = (iabs(Actions.angle_to_xy(ux, uy, ballxdis, ballydis))) \
					* player.tm_pow / 16 + (MIN_HEADER_POW / 16)

			ballxdis = ux * power
			ballydis = uy * power
			ballzdis = 1
			Ball.new_shot(player.tm_player)
			Ball.launch_ball(-1)			# Set up spin vector.
		else:
# head in dir facing.
			power = (iabs(Actions.angle_to_xy(player.tm_xdis, player.tm_ydis, ballxdis, ballydis))) \
					* player.tm_pow / 16 + (MIN_HEADER_POW / 16)

			ballxdis = player.tm_xdis * power
			ballydis = player.tm_ydis * power
			ballzdis = 1
			Ball.new_shot(player.tm_player)
			Ball.launch_ball(1)			# Set up spin vector.

	if (uf1) and (not uf2) and (not in_header_rng):
		if um:
# punt header in joystick dir.
			power = (iabs(Actions.angle_to_xy(ux, uy, ballxdis, ballydis))) \
					* player.tm_pow / 16 + (MIN_HEADER_POW / 16)
			ballxdis = ux * power
			ballydis = uy * power
			ballzdis = 4
			Ball.launch_ball(1)			# Set up spin vector.
		else:
# header vertical.
			ballxdis = ballxdis / (player.tm_cont / 16)
			ballydis = ballydis / (player.tm_cont / 16)
			ballzdis = 4 + (ball_speed / (player.tm_cont / 12))
			Ball.launch_ball(0)			# Set up spin vector.

	if (uf2) and (not uf1):
# Header pass...
		if um:
# head in joystick dir.
			var x: float
			var y: float
			x = player.tm_xdis
			y = player.tm_ydis
			player.tm_xdis = ux
			player.tm_ydis = uy						# Force joystick as orientation!

			var p: int = Intell.pass_decide(player, in_cross_area)
			Intell.make_pass(player, p, in_cross_area)

			player.tm_xdis = x
			player.tm_ydis = y						# Restore orientation!
			Ball.launch_ball(1)			# Set up spin vector.
		else:
# head in dir facing.
			heading_ball = 1
			var p: int = Intell.pass_decide(player, in_cross_area)
			Intell.make_pass(player, p, in_cross_area)
			Ball.launch_ball(1)			# Set up spin vector.

	if (not uf1) and (not uf2):
# Head down to grnd...
		if um:
# downward header in joystick dir.
			ballxdis = ux * (128 - player.tm_cont) / 16
			ballydis = uy * (128 - player.tm_cont) / 16
			ballzdis = -1
			Ball.launch_ball(-1)			# Set up spin vector.
		else:
# downward header in dir facing.

			ballxdis = player.tm_xdis * (128 - player.tm_cont) / 16
			ballydis = player.tm_ydis * (128 - player.tm_cont) / 16
			ballzdis = -1
			Ball.launch_ball(-1)			# Set up spin vector.

	holder_lose_ball()
	ball_inair = TRUE
	Ball.stop_ball_spin()

	Actions.init_anim(player, MC_S_HEAD)

#	float bd=calc_dist(ballxdis,ballydis);
#	ballx=player->tm_x+(ballxdis*(HEADER_CONTACT+1)/bd);
#	bally=player->tm_y+(ballydis*(HEADER_CONTACT+1)/bd);
#	ballz=PLAYER_HEIGHT+player->tm_z;

	action = "Header"

#******************************************************************************
#******************************************************************************

# void head_ball(match_player *player)
static func head_ball(player: match_player) -> void:
	last_touch = player.tm_player
	if last_touch != KP_A and last_touch != KP_B:
		pre_kp_touch = last_touch

	Ball.reset_shot()
	var p: int = 0
	Intell.set_pos_flags(player)

	if not player.control:
		User.reselect()

	if player.control:
		user_header(player)
	else:
		# (sic) "cannot_pick_up<12" in the keeper B test (always true when <1 is false and <12)
		if (keeper_a_in_box and player.tm_player == KP_A and (cannot_pick_up < 1 or cannot_pick_up > 11)) \
			or (keeper_b_in_box and player.tm_player == KP_B and (cannot_pick_up < 1 or cannot_pick_up < 12)):
# Attempt to catch ball...
			control_ball(player)		# attempt to bring ball under control.
			before = 100
		else:
			if not Intell.head_shoot_decide(player):
				if not Intell.head_punt_decide(player):
					heading_ball = 1
					if in_cross_area:
						p = (Intell.pass_decide(player, TRUE))
						if p:
							Intell.make_pass(player, p, TRUE)
					if not p:
# PASS!
						p = (Intell.pass_decide(player, FALSE))
						if p:
							Intell.make_pass(player, p, FALSE)
					heading_ball = FALSE

					if not p:
						if Intell.opp_around(int(ballx), int(bally), player.tm_player):
							ballxdis = -ballxdis / 2
							ballydis = -ballydis / 2
							ballxdis = ballxdis + ((((float(seed & 15)) - 7) / 16) * ball_speed)
							ballydis = ballydis + ((((float(seed & 63)) - 31) / 64) * ball_speed)
						else:
# header vertical.
							ballxdis = ballxdis / (player.tm_cont / 16)
							ballydis = ballydis / (player.tm_cont / 16)
							ballzdis = 4 + (ball_speed / (player.tm_cont / 12))
		if before != 100:
# Keeper doesn't have ball...
			holder_lose_ball()
			action = "Header"

#******************************************************************************
#******************************************************************************

# void ball_at_contact(match_player *player)
static func ball_at_contact(player: match_player) -> void:
	var cx: float = 0.0
	var cy: float = 0.0
	var cz: float = 0.0
	var r: Array = Actions.rotate_offs(player.tm_anim, cx, cy, cz, player.tm_xdis, player.tm_ydis)
	cx = r[0]; cy = r[1]; cz = r[2]
	ballx = player.tm_x + cx
	bally = player.tm_y + cy
	ballz = player.tm_z + cz

#******************************************************************************
#******************************************************************************

# void rebound_off_plr(match_player *player)
static func rebound_off_plr(player: match_player) -> void:
	penalty_shot = FALSE
	last_touch = player.tm_player
	if last_touch != KP_A and last_touch != KP_B:
		pre_kp_touch = last_touch

	can_be_offside = TRUE

	if save_block < 0:
# Keeper block save...

# How close???
		var d: float = SAVE_CONTACT - Maths.calc_dist(ballx - (player.tm_x + save_xoff), bally - (player.tm_y + save_yoff))

		var skill: float = d * player.tm_flair / (SAVE_CONTACT * 128)
		var bx: float
		var by: float

# New ball displacement...
		bx = (-(1.0 - skill) * ballxdis) + (skill * player.go_txdis)
		by = (-(1.0 - skill) * ballydis) + (skill * player.go_tydis)
		ballxdis = bx
		ballydis = by

		if ballz > SAVE_HEAD_HGT:
# Up!
			ballzdis = 3 + ballzdis * VERT_BALL_DAMP
		else:
# Damp!
			ballzdis = ballzdis * VERT_BALL_DAMP

		action = "Rebound"
		Ball.reset_shot()
	else:
		ballxdis = -ballxdis / 2
		ballydis = -ballydis / 2
		ballxdis = ballxdis + ((((float(seed & 15)) - 7) / 16) * ball_speed)
		ballydis = ballydis + ((((float(seed & 63)) - 31) / 64) * ball_speed)
		var bd: float = Maths.calc_dist(ballxdis, ballydis)
		ballx = player.tm_x + (ballxdis * (TOUCHB_BOX + 1) / bd)
		bally = player.tm_y + (ballydis * (TOUCHB_BOX + 1) / bd)
		ballzdis = ballzdis * VERT_BALL_DAMP
		action = "Rebound"
		Ball.reset_shot()

#******************************************************************************
#******************************************************************************

# void has_ball(match_player *player)
static func has_ball(player: match_player) -> void:
	# (comm_pass is an unsigned char: comm_pass>=0 is always true)
	if comm_pass >= 0 and not (seed & (32 + 16 + 8)):
		if (prev_touch > 11 and player.tm_player > 11) \
			or (prev_touch < 12 and player.tm_player < 12):
			if comm_pass_type == 1:
# Backheel...
				if comsetp:
					Audio.PlayCommentaryMessage(CP_SETPIECE)
					comsetp = 0
				else:
					Audio.PlayCommentaryMessage(CP_NICEMOVE)
			else:
				if comm_pass_type == 2:
# Cross...
					if comsetp:
						Audio.PlayCommentaryMessage(CP_SETPIECE)
						comsetp = 0
					else:
						Audio.PlayCommentaryMessage(CP_TARGET)
				else:
# Normal...
					var prx: float = teams[prev_touch - 1].tm_x
					var pry: float = teams[prev_touch - 1].tm_y
					var tx: float = player.tm_x
					var ty: float = player.tm_y
					var d: int = s16(int(Maths.calc_dist(prx - tx, pry - ty)))
					if d > LONG_PASS_DIST:
						Audio.PlayCommentaryMessage(CP_LONG)
					else:
						Audio.PlayCommentaryMessage(CP_SHORT)
#
#		else
#		{
# Not guy aimed for...
#			if ((prev_touch>11 && player->tm_player<12)
#				|| (prev_touch<12 && player->tm_player>11))
# Bad pass...
#				if (comm_pass || comm_pass_type==2)
# Long try...
#					PlayCommentaryMessage(FP_LONG);
#				else
#					if (comm_pass_type==1)
# Backheel...
#						PlayCommentaryMessage(FP_LOOSE);
#					else
#						PlayCommentaryMessage(FP_SHORT);
#		}
#
		comm_pass = u8(-1)
	else:
		if say_names and not opponents_really_close:
			var intone: int = 0
			if ball_poss < 12:
				intone = s16(int(ballx / cntspot_x))
			else:
				intone = s16(int((pitch_len - ballx) / cntspot_x))

			Audio.PlayTeamSample(Ball.real_player(ball_poss), intone)

#******************************************************************************
#******************************************************************************

# void hold_ball(match_player *player)
static func hold_ball(player: match_player) -> void:
	if not set_piece_on:
# calculate position of ball at feet!
		var bx: float
		var by: float
		bx = ballx
		by = bally

		player.tm_poss = s16(player.tm_poss + 1)
		ballxdis = player.go_txdis
		ballydis = player.go_tydis
		ballzdis = 0							# Ground ball.
		ballz = ball_diam / 2

		var x: float = player.tm_xdis
		var y: float = player.tm_ydis

		last_touch = player.tm_player
		if last_touch != KP_A and last_touch != KP_B:
			pre_kp_touch = last_touch

		if ball_in_hands:
			if player.tm_act == THROW_ACT:
# Ball above player's head!
				ballz = player.tm_z + (PLAYER_HEIGHT + 4)
				ballx = player.tm_x
				bally = player.tm_y
				ball_in_hands = TRUE
			else:
				if player.int_move != I_GET_UP or not player.int_cnt:
					if player.tm_act == SAVE_ACT:
						ballz = player.tm_z + save_zoff
						ballx = player.tm_x + save_xoff
						bally = player.tm_y + save_yoff
						player.dir_mode = 5
					else:
						ballz = player.tm_z + (PLAYER_HEIGHT / 2)
						ballx = player.tm_x + (x * IN_HANDS_DIST)
						bally = player.tm_y + (y * IN_HANDS_DIST)
						if player.tm_act != KPHOLD_ACT:
							player.dir_mode = 2
						else:
							player.dir_mode = 3
		else:
			if player.tm_poss == HAS_BALL_DELAY:
				has_ball(player)

#			inc_poss(player->tm_player);
			var n: float		# double n; (integer part of modf, unused)
			player.dir_mode = 0
			ball_inair = FALSE
			if player.tm_act == RUN_ACT:
				bx = player.tm_x + (x * (AT_FEET_DIST + (4.0 * (c_modf(player.tm_frm) - 0.5))))
				by = player.tm_y + (y * (AT_FEET_DIST + (4.0 * (c_modf(player.tm_frm) - 0.5))))
			else:
				if not dead_ball_cnt:
# If player is in a set-piece then no need to move position of ball...
					bx = player.tm_x + (x * AT_FEET_DIST)
					by = player.tm_y + (y * AT_FEET_DIST)

			if player.tm_ftime < -1:
# Just controlled ball... (so tween to held pos.)
# ftime (-2 to -10)...
				if player.tm_ftime == -2:
					get_mcball_coords(player)
				else:
					ballx += ((bx - ballx) * (-2 - player.tm_ftime) / 8)
					bally += ((by - bally) * (-2 - player.tm_ftime) / 8)
#				ballx=bx;
#				bally=by;
				player.tm_ftime -= 1
				if player.tm_ftime == -11:
					player.tm_ftime = 0
			else:
# No tweening...
				ballx = bx
				bally = by

		if ((player.tm_player == KP_A) or (player.tm_player == KP_B)) \
			and (player.tm_act == STAND_ACT) and (ball_in_hands):
			Actions.init_kphold_act(player)
	else:
		last_touch = player.tm_player
		if last_touch != KP_A and last_touch != KP_B:
			pre_kp_touch = last_touch

#******************************************************************************
#******************************************************************************

# void init_specials()
static func init_specials() -> void:
	spec_kick_type = 0
	f1_down = FALSE
	f2_down = FALSE

#******************************************************************************
#******************************************************************************

# void collect_ball(match_player *player)
static func collect_ball(player: match_player) -> void:
	Rules.add_comp_pass(player.tm_player)
	if player.tm_act == TACKLE_ACT:
		Rules.inc_twon(player.tm_player)

	if not player.tm_leave:
		Intell.reset_leaves()

#	comm_pass=-1;		//FIX
	prev_touch = last_touch
	receiver_a = FALSE
	receiver_b = FALSE
	init_specials()

	if (must_shoot) or (must_punt) or (must_pass):
		must_shoot = u8(-must_shoot)
		must_pass = u8(-must_pass)
		must_punt = u8(-must_punt)

	if (player.tm_player != KP_A) and (player.tm_player != KP_B):
		cannot_pick_up = player.tm_player

# Keeper can pick up ball...

	hold_ball(player)
	if (ball_in_hands) and (player.tm_act != SAVE_ACT):
		Intell.reset_all_ideas()
	Ball.stop_ball_spin()
	ball_poss = player.tm_player
	player.tm_poss = 1
	if (player.int_cnt) and (player.int_move == I_INTERCEPT):
		Intell.reset_ideas(player)
	action = "Collect"
	Ball.reset_shot()
	penalty_shot = FALSE

	if player.tm_act == CONTROL_ACT:
		ball_at_contact(player)

	User.reselect()

#******************************************************************************
#******************************************************************************

# void control_difficulty(match_player *player)
# Calculates difficulty factor (0 simple -> 128 impossible)!
static func control_difficulty(player: match_player) -> void:
	var x: float = ballx - ballxdis		#take ball one step back!
	var y: float = bally - ballydis
	x = x - player.tm_x				#offset to player.
	y = y - player.tm_y
	var cside: int = Intell.get_dir(x, y)		#contact side of player.
	cside = cside - player.face_dir
	if cside < 0:
		cside = cside + 8
	if cside > 4:
		cside = 8 - cside
	difficulty = cside * 16			#direction difficulty!
	var s: int = ball_speed * 2

	if player.tm_act == RUN_ACT:
		if want_pass == player.tm_player:
# He is expecting it so better chance of controlling ball!
			s += 2
		else:
			s += 4							# speed factor.

	if player.tm_act == TACKLE_ACT:
		s += 8							# speed factor.
	if (player.tm_act == SAVE_ACT) or (((player.tm_player == KP_A) or (player.tm_player == KP_B)) \
		and (ballz > PLAYER_HEIGHT / 3)):
		s -= 4							# Keeper saving!

	difficulty += (6 * s)				#add speed difficulty!

#******************************************************************************
#******************************************************************************

# void active_control(match_player *player)
static func active_control(player: match_player) -> void:
	if player.tm_ftime >= 0:
		var cx: float = 0.0
		var cy: float = 0.0
		var cz: float = 0.0
		var r: Array = Actions.rotate_offs(player.tm_anim, cx, cy, cz, player.tm_xdis, player.tm_ydis)
		cx = r[0]; cy = r[1]; cz = r[2]
		ballx = player.tm_x + cx
		bally = player.tm_y + cy
		ballz = player.tm_z + cz
		ballxdis = player.tm_xdis * (2 + (ball_speed / (player.tm_cont / 32)))
		ballydis = player.tm_ydis * (2 + (ball_speed / (player.tm_cont / 32)))
		ballzdis = 1
		last_touch = player.tm_player
		if last_touch != KP_A and last_touch != KP_B:
			pre_kp_touch = last_touch
		player.tm_ftime = -1				# Continue animation!

#******************************************************************************
#******************************************************************************

# void standard_fstep(match_player *player)
static func standard_fstep(player: match_player) -> void:
	match player.tm_anim:
		MC_D_HEAD:
			player.tm_fstep = MC_D_HEAD_FS

		MC_CHEST:
			player.tm_fstep = MC_CHEST_FS

		MC_TRAPL, MC_TRAPR:
			player.tm_fstep = MC_TRAP_FS

		MC_SHOOTL, MC_SHOOTR:
			player.tm_fstep = MC_SHOOT_FS

		MC_CHIPL, MC_CHIPR:
			player.tm_fstep = MC_CHIP_FS

		MC_VOLLEYL, MC_VOLLEYR:
			player.tm_fstep = MC_VOLLEY_FS

		MC_OVERHEAD:
			player.tm_fstep = MC_OVERHEAD_FS

		MC_DV_HEAD:
			player.tm_fstep = MC_DV_HEAD_FS

		MC_S_HEAD:
			player.tm_fstep = MC_S_HEAD_FS

		MC_J_HEAD:
			player.tm_fstep = MC_J_HEAD_FS

#******************************************************************************
#******************************************************************************

# void control_ball(match_player *player)
# Having made contact with ball,
# the player must attempt to control it!
static func control_ball(player: match_player) -> void:
	can_be_offside = TRUE

	if player.tm_act == CONTROL_ACT:
# Player has successfully controlled ball.
		if player.tm_anim == MC_U_HEAD:
# Head Control...(Bounce ball upward!)
			active_control(player)
		else:

			holder_lose_ball()
			collect_ball(player)		#bring ball to feet!
			player.dir_mode = 2
			if player.tm_anim != MC_TRAPL and player.tm_anim != MC_TRAPR:
				standard_fstep(player)		# Normal speed anim...
				Ball.ball_limbo(player.tm_player, 1 - player.tm_fstep)		# Ball is motion captured to ground!
	else:
		if player.tm_act == TACKLE_ACT:
			player.go_step = TRUE				# He has touched the ball (no foul)!
		control_difficulty(player)
		# C precedence: SAVE || KP_A || (KP_B && z>PLAYER_HEIGHT/3)
		if ((((player.tm_act != SAVE_ACT) and (player.tm_z < 1)) \
			or ((player.tm_act == SAVE_ACT) or (player.tm_player == KP_A) \
			or ((player.tm_player == KP_B) and (player.tm_z > PLAYER_HEIGHT / 3))))) \
			and (seed + player.tm_cont > difficulty):
# Assume controlled ball is at feet level.
			holder_lose_ball()
			collect_ball(player)		#bring ball to feet!
		else:
			rebound_off_plr(player)		#could not control!

#******************************************************************************
#******************************************************************************

# char control_interact(match_player *player)
static func control_interact(player: match_player) -> int:
	if player.tm_frm >= player.contact:
# Contact point exceeded...

		if player.tm_anim != MC_TRAPL and player.tm_anim != MC_TRAPR:
			player.tm_anim = u16(player.tm_anim + 1)
			player.tm_anim = u16(player.tm_anim - 1)

		var px: float = player.tm_x
		var py: float = player.tm_y
		var pz: float = player.tm_z

		var cx: float = 0.0
		var cy: float = 0.0
		var cz: float = 0.0
		var r: Array = Actions.rotate_offs(player.tm_anim, cx, cy, cz, player.tm_xdis, player.tm_ydis)
		cx = r[0]; cy = r[1]; cz = r[2]

		px += cx
		py += cy
		pz += cz

		var d: float = Maths.calc_dist(ballx - px, bally - py)
		if d > ball_speed + 2 and d > 8:
			return FALSE

		if iabs(ballz - pz) > prat / 2:
			return FALSE

# Good contact... (control ball)!
		return TRUE
	return FALSE

#******************************************************************************
#******************************************************************************

# void ball_interact(match_player *player)
static func ball_interact(player: match_player) -> void:
	var act: int = player.tm_act

	if player.tm_poss <= 0:
		player.tm_poss = 0
		if not ((act == FALL_ACT) or \
			(act == RISE_ACT) or (act == RIDE_ACT) or (dead_ball_cnt)):	#player not out of game.
			if (not ((player.int_cnt != 0) and (player.int_move == I_KICKED))) \
				and (not ball_in_hands):
				if act != SAVE_ACT:
# Normal player...
					if not just_scored and ((not ball_poss) or (ball_poss and teams[ball_poss - 1].tm_act != PICKUP_ACT)):

						if not ball_poss or (ball_poss and ball_poss < 12 and player.tm_player > 11) \
							or (ball_poss > 11 and player.tm_player < 12):
# Ball is free or the opponent has ball...

							if act == CONTROL_ACT and player.tm_ftime >= 0 and control_interact(player):
# He has successfully controlled the ball!
								control_ball(player)

							if act == STRIKE_ACT and player.tm_ftime >= 0 and control_interact(player):
# He has successfully struck the ball!
								Actions.strike_ball_off(player)

							if player.tm_act != CONTROL_ACT and player.tm_act != STRIKE_ACT:
								if not player.tm_strike and TOUCHB_BOX >= Maths.calc_dist(ballx - player.tm_x, bally - player.tm_y) \
									and ballz < PLAYER_HEIGHT and (not penalty_game or player.tm_player == KP_A or player.tm_player == KP_B):
# Contact is made...
									receiver_a = FALSE
									receiver_b = FALSE

									if not practice and (player.tm_leave > 0) and (last_touch == player.tm_player):
										Rules.init_foul(player.tm_player, FALSE, TRUE)	# Indirect F.K. for touching ball again!

									if (ballz < player.tm_z + PLAYER_HEIGHT / 2) \
										and (ballz - ballzdis < player.tm_z + PLAYER_HEIGHT / 2):
#Contact with ball at feet...
										if act <= TURN_ACT or act == TACKLE_ACT or act == STEAL_ACT:
											control_ball(player)
									else:
										if ballz < player.tm_z + PLAYER_HEIGHT - 3:
# At head and body height...
											if act <= TURN_ACT or act == TACKLE_ACT or act == STEAL_ACT:
												rebound_off_plr(player)

					if player.tm_leave < 0:
						player.tm_leave = TRUE
				else:
# Keeper save!
					if player.tm_frm > (keeper_contact - 0.00001):
# Contact with ball reached...
						if keeper_will_save > 0 or keep_dive:
# Keeper should connect with ball at contact point...
							if keep_dive or (SAVE_CONTACT > Maths.calc_dist(ballx - (player.tm_x + save_xoff), bally - (player.tm_y + save_yoff)) \
								and not ball_in_goal):
# Keeper has judged it well!
								Rules.inc_saves(player.tm_player)
								shot_saved = 25
								keeper_will_save = -1
								if save_block and not keep_dive:
									if real_shot:
										Audio.PlayCommentaryMessage(PM_BLOCK)
										Rules.inc_save(last_touch)
									save_block = -1						# Rebound properly from block!
									rebound_off_plr(player)		#could not control!
									ball_inair = TRUE
									ballz = save_zoff
									ballx = player.tm_x + player.go_txdis + save_xoff
									bally = player.tm_y + player.go_tydis + save_yoff
									save_block = 0						# Rebound properly from block!
								else:
									if real_shot:
										Audio.PlayCommentaryMessage(PM_CATCH)
										Rules.inc_save(last_touch)
									holder_lose_ball()
									ball_in_hands = TRUE
									collect_ball(player)		#bring ball to feet!
								keep_dive = FALSE
							else:
# Ball too far!!!
								keeper_will_save = 0		# Catch will change to block...
								if not save_block:
# Must become desperate block instead of catch...
									if ABS(player.tm_anim) < MC_BFOOTBL:
# Zone A save...(no right,left)
										player.tm_anim = u16(player.tm_anim - 1)
									else:
										player.tm_anim = u16(player.tm_anim - 2)

									player.go_cnt = int((1 - player.tm_frm) / player.tm_fstep)

									if not player.tm_anim:		# AFOOTB
										keeper_on_grnd = FALSE

									if keeper_on_grnd:
										player.int_cnt = s16(player.go_cnt + 2)
									else:
										player.int_cnt = s16(player.go_cnt + 2)
	else:
		if (player.contact > 0) and (player.tm_act == KICK_ACT):
# Currently awaiting contact point in animation...
# He's kicking the ball just now...

			ballx += ((player.tm_x + b_xoff) - ballx) * player.tm_frm / player.contact
			bally += ((player.tm_y + b_yoff) - bally) * player.tm_frm / player.contact
			ballz += ((player.tm_z + b_zoff) - ballz) * player.tm_frm / player.contact

		else:
			# (sic) the original tests "(act=KPHOLD_ACT)": an ASSIGNMENT, always true
			# when reached (it is the last operand of the ||).
			var held: bool = ((ballz >= player.tm_z) and (ballz < PLAYER_HEIGHT + player.tm_z)) \
				or (act == THROW_ACT) or (act == SAVE_ACT)
			if not held:
				act = KPHOLD_ACT
				held = (act != 0)
			if held:
				if player.tm_player == ball_poss:
					hold_ball(player)
				else:
					player.tm_poss = 0				# doesnt have ball any more.
			else:
				holder_lose_ball()

#******************************************************************************
#******************************************************************************

# Predicts ball coords from now till 50 turns ahead!

# void predict_ball()
static func predict_ball() -> void:
#	struct stack{
#		float x; float y; float z;
#		float xd; float yd; float zd;
#		int ba; int bs; int sw; float xys; float zs;
#		float f_xys; float f_zs; int sp_b;};
#	struct stack sp;
	var sp_x: float
	var sp_y: float
	var sp_z: float
	var sp_xd: float
	var sp_yd: float
	var sp_zd: float
	var sp_ba: int
	var sp_bs: int
	var sp_sw: int
	var sp_xys: float
	var sp_zs: float
	var sp_f_xys: float
	var sp_f_zs: float
	var sp_sp_b: int

	sp_x = ballx
	sp_y = bally
	sp_z = ballz
	sp_xd = ballxdis
	sp_yd = ballydis
	sp_zd = ballzdis
	sp_ba = ball_inair
	sp_bs = ball_still
	sp_sw = swerve
	sp_xys = ball_xyspin
	sp_zs = ball_zspin
	sp_f_xys = full_xyspin
	sp_f_zs = full_zspin
	sp_sp_b = spin_cnt

	ns_ballx = ballx
	ns_bally = bally
	ns_ballz = ballz

	# float *ptr1=&ball_pred_tab[0][0];  float *ptr2=&ns_ball_pred_tab[0][0];

	first_bounce = -1
	prediction = TRUE
	for i in range(0, 50):
# Ball with swerve!
		ball_pred_tab[i][0] = ballx
		ball_pred_tab[i][1] = bally
		ball_pred_tab[i][2] = ballz
		if first_bounce < 0 and ballz <= (ball_diam / 2) and i > 0:
			first_bounce = i

# Ball without swerve!
		ns_ball_pred_tab[i][0] = ns_ballx
		ns_ball_pred_tab[i][1] = ns_bally
		ns_ball_pred_tab[i][2] = ns_ballz

		if not ball_poss:
			Ball.ball_trajectory()
		else:
			if teams[ball_poss - 1].tm_act == TACKLE_ACT:
# Take into account deceleration of tackle action!
				ballx += ballxdis * pow(TACKLE_DECEL, i)
				bally += ballydis * pow(TACKLE_DECEL, i)
				ns_ballx += ballxdis * pow(TACKLE_DECEL, i)
				ns_bally += ballydis * pow(TACKLE_DECEL, i)
			else:
				ballx += ballxdis
				bally += ballydis
				ns_ballx += ballxdis
				ns_bally += ballydis

	spin_cnt = sp_sp_b
	full_zspin = sp_f_zs
	full_xyspin = sp_f_xys
	ball_zspin = sp_zs
	ball_xyspin = sp_xys
	swerve = sp_sw
	ball_still = sp_bs
	ball_inair = sp_ba
	ballzdis = sp_zd
	ballydis = sp_yd
	ballxdis = sp_xd
	ballz = sp_z
	bally = sp_y
	ballx = sp_x

#******************************************************************************
#******************************************************************************

# Find no. of opponents near ball holder.

# void get_opp_near_ball(int holder)
static func get_opp_near_ball(holder: int) -> void:
	opponents_near_holder = 0			# Initialise count.
	opponents_really_close = 0
	var p: int
	if holder:
		if holder > 11:						# Get opposing team.
			p = 0
		else:
			p = 11
		for i in range(p, p + 11):
			if (teams[i].guy_on > 0) and (teams[i].tm_dist <= DRIB_DANGER_AREA):
				opponents_near_holder += 1
				if teams[i].tm_dist <= MEGA_DANGER_AREA:
					opponents_really_close += 1

#******************************************************************************
#******************************************************************************

# void get_dist_pos(int pn)
static func get_dist_pos(pn: int) -> void:
	var d: float
	var lowest: float
	var guy: int = pn

	for pos in range(2, 5):
		lowest = 2000

		# (sic) i<pn+12 also scans the first player of the other team and, for
		# pn=12, reads one element past the end of teams[22] (teams[22]); that
		# out-of-bounds slot is treated as an inactive player (guy_on<=0).
		for i in range(pn, pn + 12):
			if i - 1 < teams.size() and teams[i - 1].guy_on > 0:
				d = teams[i - 1].tm_dist
				if (d < lowest) and (not teams[i - 1].tm_pos):
					guy = i
					lowest = d
		teams[guy - 1].tm_pos = pos

#******************************************************************************
#******************************************************************************

# Updates player distances.

# #define SELECTION_CIRCLE (prat*10)
static func SELECTION_CIRCLE() -> float:
	return (prat * 10)

# void player_distances()
static func player_distances() -> void:
	var px: float
	var py: float
	var ad: float = 2000
	var bd: float = 2000
	var d: float
	defense_a = cntspot_x
	defense_b = cntspot_x

	player_num = 0
	while player_num < players:
		if teams[player_num].guy_on > 0:
			px = teams[player_num].tm_x

			if player_num < 11:
				if px < defense_a and player_num:
					defense_a = int(px)

				d = Maths.calc_dist(pitch_len - teams[player_num].tm_x, cntspot_y - teams[player_num].tm_y)

				if d < (MIN_SHOOT_DIST + (float(teams[player_num].tm_pow) * 3)):
					teams[player_num].tm_srng = TRUE
				else:
					teams[player_num].tm_srng = FALSE
			else:
				if (player_num != 11) and (px > defense_b):
					defense_b = int(px)

				d = Maths.calc_dist(teams[player_num].tm_x, cntspot_y - teams[player_num].tm_y)

				if d < (MIN_SHOOT_DIST + (float(teams[player_num].tm_pow) * 3)):
					teams[player_num].tm_srng = TRUE
				else:
					teams[player_num].tm_srng = FALSE

			px -= ballx
			py = teams[player_num].tm_y - bally
			d = Maths.calc_dist(px, py)
			teams[player_num].tm_dist = d
			teams[player_num].tm_pos = 0
			if player_num >= players / 2:
				if d < bd:
					bd = d
					nearest_b = player_num + 1
			else:
				if d < ad:
					ad = d
					nearest_a = player_num + 1
			if player_num != (KP_A - 1) and player_num != (KP_B - 1):
				sel_circle[player_num] = (TRUE if d < SELECTION_CIRCLE() else FALSE)
			else:
				sel_circle[player_num] = FALSE
		player_num += 1
	teams[nearest_a - 1].tm_pos = 1
	teams[nearest_b - 1].tm_pos = 1
	get_dist_pos(1)
	get_dist_pos(12)

#******************************************************************************
#******************************************************************************

# Return closest guy to the ball (from one team) who is not busy!
# p_num = first player in team.

# int get_nearest_guy(int p_num)
static func get_nearest_guy(p_num: int) -> int:
	var near_guy: int = 0
	var closest: int = 10000
	for i in range(p_num, p_num + 11):
		if teams[i].tm_act <= TURN_ACT:				#player is not busy!
			if teams[i].tm_dist < closest:
				near_guy = i + 1						#This guy is closer!
				closest = int(teams[i].tm_dist)
	return near_guy

#******************************************************************************
#******************************************************************************

# void get_nearest()
static func get_nearest() -> void:
	if receiver_a:
		near_path_a = receiver_a
	else:
		near_path_a = Intell.get_near_path(0, TRUE)

	if receiver_b:
		near_path_b = receiver_b
	else:
		near_path_b = Intell.get_near_path(11, TRUE)

#******************************************************************************
#******************************************************************************

# void holder_lose_ball()
static func holder_lose_ball() -> void:
	if ball_poss:
		Intell.reset_ideas(teams[ball_poss - 1])
		if ball_poss < 12:
			ball_released = OFFSIDE_REL_CNT
		else:
			ball_released = -OFFSIDE_REL_CNT

		var p: int = teams[ball_poss - 1].tm_poss
		teams[ball_poss - 1].tm_posst = s16(teams[ball_poss - 1].tm_posst + p * p / 50)	# Good dribbles will adjust performance.
		teams[ball_poss - 1].tm_poss = 0
		ball_poss = 0
		in_cross_area = FALSE
		ball_in_hands = FALSE
		must_punt = FALSE
		must_pass = FALSE
		must_shoot = FALSE

