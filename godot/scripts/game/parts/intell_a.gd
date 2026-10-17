#******************************************************************************
#******************************************************************************

# Player intelligence and decision making routines...

#******************************************************************************
#*****************************************************************************/

# #include "global.h" "defines.h" "externs.h" "data.h" "audio.h" "front.h" "eurofrnt\euro_int.h"
# extern match_data match_info; extern team_info game_data[]; extern float save_offs[];
# extern setup_info setup; extern stad_info stadlist[]; extern void reselect_a(); extern void reselect_b();

#******************************************************************************
#*****************************************************************************/

#  Intelligence Flags and Variables...

# char cross_on=FALSE;	(declared in glob.gd)

# #define DIVE_POINT 3
const DIVE_POINT = 3
# #define DIVE_FEET_DIST (prat*4)
static func DIVE_FEET_DIST() -> float:
	return (prat*4)

#******************************************************************************
#*****************************************************************************/

# short get_there_time(int p_num,float x,float y)
static func get_there_time(p_num: int, x: float, y: float) -> int:
	stop_and_face = FALSE

	must_face_time = 0
	var t1: int = 0
	var t2: int = 0
	var mft1: int = 0
	var mft2: int = 0
	var t: int = 0
	var mft: int = 0
	var d: float
	var rate: float = Actions.full_spd(teams[p_num-1])  # Running speed!
	var px: float
	var py: float
	px = teams[p_num-1].tm_x
	py = teams[p_num-1].tm_y
	x = x-px
	y = y-py		# Offset.

	var sx: float = x
	var sy: float = y

	var xd: float = teams[p_num-1].tm_xdis
	var yd: float = teams[p_num-1].tm_ydis  # Current facing dir.

	var max: float = ((14.0+float(teams[p_num-1].tm_rate)/8.0)*PI/180.0)	# MAX_TURN2
	var old_max: float = max
	var cmax: float = cos(max)
	var ox: float
	var oy: float
	var a: float
	var turn_spd: float
	var last_a: float

# Player must have ball slightly

	if teams[p_num-1].tm_act <= TURN_ACT:
# Can i turn on the spot?
		a = Actions.angle_to_xy(x, y, xd, yd)
		t1 = int(ABS(acos(a)/max))		# time to turn!

# Time to go straight to point...
		d = Maths.calc_dist(x, y)
		t1 = int(t1+d/rate+1)

		if must_face:
# User forced to face in a particular direction (after getting to target)...
			a = Actions.angle_to_xy(must_face_x, must_face_y, x/d, y/d)
			mft1 = int(ABS(acos(a)/max)+1)		# time to turn!
	else:
		t1 = 2000

	a = Actions.angle_to_xy(x, y, xd, yd)
	last_a = a

	d = Maths.calc_dist(x, y)

# Time to get to target point...
	var i: int = 0
	while i < 50:

# Init run...
		if d < IM_THERE_DIST:
			break
		else:
			t2 += 1

# Go forward...
		turn_spd = (1.0+a)/2

		x -= xd*rate*turn_spd		# Move on...
		y -= yd*rate*turn_spd

# Turn...

		d = Maths.calc_dist(x, y)

		ox = xd
		oy = yd

		max = old_max

		if a < cmax:
# Need to turn...

			if (x*oy/d) > (y*ox/d):
				max = -max

			xd = (ox*cos(max))-(oy*sin(max))
			yd = (oy*cos(max))+(ox*sin(max))
		else:
# Final turn...
#			xd=x/d;
#			yd=y/d;
			t2 = int(t2+d/rate)
			if d-((t2-1)*rate) > .1:
				t2 += 1
			break

		last_a = a
		a = Actions.angle_to_xy(x, y, xd, yd)

		if last_a > a:
# Getting further forget it!
			t2 = 2000
			break		# (exit)
		i += 1

	if i > 50:
		t = 2000		# Could not find intersection!

	if must_face:
# User forced to face in a particular direction (after getting to target)...
		a = Actions.angle_to_xy(must_face_x, must_face_y, xd, yd)
		mft2 = int(ABS(acos(a)/max)+1)		# time to turn!

	if (t1+mft1) < (t2+mft2):
# Rotate and run...
		t = t1+mft1
		mft = mft1
		d = Maths.calc_dist(sx, sy)
		x_face = sx/d		# New dir...
		y_face = sy/d
		stop_and_face = TRUE
	else:
# Turn and run...
		t = t2+mft2
		mft = mft2
		x_face = x/d		# New dir...
		y_face = y/d

	if must_face:
		x_face = must_face_x
		y_face = must_face_y
		must_face_time = s16(mft)

	return s16(t)

#******************************************************************************
#*****************************************************************************/

# short get_facing_opp_dir(match_player *player)
static func get_facing_opp_dir(player: match_player) -> int:

#
#Output: 1 = Side On.
#		 -1 = Behind.
#		  0 = Face On.
#

	var d: int = get_dir(ballx-player.tm_x, bally-player.tm_y)
# Direction to ball!

	var opp: int = teams[ball_poss-1].face_dir
	if opp == d:
		return -1

	d = d-opp

	if d < 0:
		d += 8

	if (d == 1) or (d == 7):
		return -1

	if (d == 2) or (d == 6):
		return 1
	else:
		return 0

#******************************************************************************
#*****************************************************************************/

# char thinking(match_player *player)
static func thinking(player: match_player) -> int:
	var f: int = (130-player.tm_flair)/2
	var t: int = logic_cnt/f
	var r: int = logic_cnt-(t*f)
	return bi(not r)

#******************************************************************************
#*****************************************************************************/

# char plr_facing(float x,float y,match_player *player)
static func plr_facing(x: float, y: float, player: match_player) -> int:
	var xd: float = player.tm_xdis
	var yd: float = player.tm_ydis
	var d: float = Maths.calc_dist(x, y)
	var a: float = ((x*xd)+(y*yd))/d
	if a > FACING_ANGLE:			# 5 degrees!
		return TRUE
	else:
		return FALSE

#******************************************************************************
#*****************************************************************************/

# char plr_facing_goal(float x,float y,match_player *player)
static func plr_facing_goal(x: float, y: float, player: match_player) -> int:

# Is the player facing between the goal posts of goal(x,y)?

	var xd: float = player.tm_xdis
	var yd: float = player.tm_ydis

	if (x > 0 and xd < 0) or (x < 0 and xd > 0):
		return FALSE

	var yt: float
	if user_controlled:
		yt = (top_post_y-prat*6)-player.tm_y
	else:
		yt = top_post_y-player.tm_y

	var d: float = Maths.calc_dist(x, yt)
	var xt: float = x/d
	yt = yt/d

	var yb: float
	if user_controlled:
		yb = (bot_post_y+prat*6)-player.tm_y
	else:
		yb = bot_post_y-player.tm_y

	d = Maths.calc_dist(x, yb)
	var xb: float = x/d
	yb = yb/d

	var dir: int = 0

	if (xt*yd) > (yt*xd):
		dir = TRUE

	if (xb*yd) > (yb*xd):
		if dir:
			return FALSE
		else:
			return TRUE
	else:
		if dir:
			return TRUE
		else:
			return FALSE
	return FALSE

#******************************************************************************
#*****************************************************************************/

# void run_back(match_player *player)
static func run_back(player: match_player) -> void:
	player.tm_off = -2
	if player.tm_player < 12:
# Team A...
		Actions.init_run_act(player, defense_b-(prat*3), player.tm_y, TRUE)
	else:
# Team B...
		Actions.init_run_act(player, defense_a+(prat*3), player.tm_y, TRUE)

#******************************************************************************
#*****************************************************************************/

# void keeper_boxes()
static func keeper_boxes() -> void:
	if ((teams[KP_A-1].tm_x > (prat*16)) or (teams[KP_A-1].tm_y > (cntspot_y+(19*prat))) \
		or (teams[KP_A-1].tm_y < (cntspot_y-(19*prat))) or (teams[KP_A-1].tm_x < 0)):

		keeper_a_in_box = FALSE
	else:
		keeper_a_in_box = TRUE

	if ((teams[KP_B-1].tm_x < pitch_len-(prat*16)) or (teams[KP_B-1].tm_y > (cntspot_y+(19*prat))) \
		or (teams[KP_B-1].tm_y < (cntspot_y-(19*prat))) or (teams[KP_B-1].tm_x > pitch_len)):

		keeper_b_in_box = FALSE
	else:
		keeper_b_in_box = TRUE

#******************************************************************************
#*****************************************************************************/

# void reset_ideas(match_player *player)
static func reset_ideas(player: match_player) -> void:
	player.tm_strike = FALSE
	player.special = FALSE
	player.tm_z = 0

	if player.int_move != I_OFF:
		if (player.int_move == I_INTERCEPT) and (player.tm_act == RUN_ACT):
			player.go_cnt = 1			# Stop running!

		if player.int_move == I_RUN_ON:
			want_pass = 0
			player.int_move = 0
			player.int_cnt = 0

		if player.int_cnt:
			if player.tm_player == interceptor_a:
				interceptor_a = 0

			if player.tm_player == interceptor_b:
				interceptor_b = 0

			player.int_move = 0
			player.int_cnt = 0

#******************************************************************************
#*****************************************************************************/

# void reset_all_ideas()
static func reset_all_ideas() -> void:
	for i in range(0, players):
		reset_ideas(teams[i])
		teams[i].tm_leave = FALSE
	keep_dive = FALSE

#******************************************************************************
#*****************************************************************************/

# void reset_leaves()
static func reset_leaves() -> void:
	for i in range(0, players):
		teams[i].tm_leave = FALSE

#******************************************************************************
#*****************************************************************************/

# void save_in_zone_a(match_player *player,float x,float y,float z,int bp,char forced)
static func save_in_zone_a(player: match_player, x: float, y: float, z: float, bp: int, forced: int) -> void:
	var factor: float
	keeper_on_grnd = FALSE
	keeper_will_save = TRUE
	var zone: int = 1
	if z < SAVE_FEET_HGT:
# Feet level...
		if bp <= SAVE_AFOOTB_TIME/keeper_spd and not keep_dive:
			keeper_contact = MCC_AFOOTB

			factor = 1.0/(float(bp)/(SAVE_AFOOTB_TIME/keeper_spd))
			if factor > max_kp_margin and not forced:
# Ball is too fast!
				factor = max_kp_margin
				keeper_will_save = FALSE
				player.tm_fstep = MC_AFOOTB_FS*factor*keeper_spd
			else:
				player.tm_fstep = keeper_contact/bp

			if player.tm_fstep >= 1:
				player.tm_fstep = 1

			save_block = TRUE
			Actions.init_save_act(player, int(x), int(y), int(z), MC_AFOOTB, zone, bp, int(SAVE_AFOOTB_TIME/keeper_spd))
		else:
			if bp <= SAVE_AFOOTC_TIME/keeper_spd or keep_dive:
				keeper_contact = MCC_AFOOTC

				factor = 1.0/(float(bp)/(SAVE_AFOOTC_TIME/keeper_spd))
				if factor > max_kp_margin and not forced:
# Ball is too fast!
					factor = max_kp_margin
					keeper_will_save = FALSE
					player.tm_fstep = MC_AFOOTC_FS*factor*keeper_spd
				else:
					player.tm_fstep = keeper_contact/bp

				if player.tm_fstep >= 1:
					player.tm_fstep = 1

				save_block = FALSE
				keeper_on_grnd = TRUE
				Actions.init_save_act(player, int(x), int(y), int(z), MC_AFOOTC, zone, bp, int(SAVE_AFOOTC_TIME/keeper_spd))
			else:
# Move to best position...
				shot_acknowledged = 1
	else:
		if z < SAVE_CHEST_HGT:
# Chest level...
			if bp <= SAVE_ABODYB_TIME/keeper_spd and not keep_dive:
				keeper_contact = MCC_ABODYB

				factor = 1.0/(float(bp)/(SAVE_ABODYB_TIME/keeper_spd))
				if factor > max_kp_margin and not forced:
# Ball is too fast!
					factor = max_kp_margin
					keeper_will_save = FALSE
					player.tm_fstep = MC_ABODYB_FS*factor*keeper_spd
				else:
					player.tm_fstep = keeper_contact/bp

				if player.tm_fstep >= 1:
					player.tm_fstep = 1

				save_block = TRUE
				Actions.init_save_act(player, int(x), int(y), int(z), MC_ABODYB, zone, bp, int(SAVE_ABODYB_TIME/keeper_spd))
			else:
				if bp <= SAVE_ABODYC_TIME/keeper_spd or keep_dive:
					keeper_contact = MCC_ABODYC

					factor = 1.0/(float(bp)/(SAVE_ABODYC_TIME/keeper_spd))
					if factor > max_kp_margin and not forced:
# Ball is too fast!
						factor = max_kp_margin
						keeper_will_save = FALSE
						player.tm_fstep = MC_ABODYC_FS*factor*keeper_spd
					else:
						player.tm_fstep = keeper_contact/bp

					if player.tm_fstep >= 1:
						player.tm_fstep = 1

					save_block = FALSE
					Actions.init_save_act(player, int(x), int(y), int(z), MC_ABODYC, zone, bp, int(SAVE_ABODYC_TIME/keeper_spd))
				else:
# Move to best position...
					shot_acknowledged = 1
		else:
			if z < SAVE_HEAD_HGT:
# Head level...
				if bp <= SAVE_AHEADB_TIME/keeper_spd and not keep_dive:
					keeper_contact = MCC_AHEADB

					factor = 1.0/(float(bp)/(SAVE_AHEADB_TIME/keeper_spd))
					if factor > max_kp_margin and not forced:
# Ball is too fast!
						factor = max_kp_margin
						keeper_will_save = FALSE
						player.tm_fstep = MC_AHEADB_FS*factor*keeper_spd
					else:
						player.tm_fstep = keeper_contact/bp

					if player.tm_fstep >= 1:
						player.tm_fstep = 1

					save_block = TRUE
					Actions.init_save_act(player, int(x), int(y), int(z), MC_AHEADB, zone, bp, int(SAVE_AHEADB_TIME/keeper_spd))
				else:
					if bp <= SAVE_AHEADC_TIME/keeper_spd or keep_dive:
						keeper_contact = MCC_AHEADC

						factor = 1.0/(float(bp)/(SAVE_AHEADC_TIME/keeper_spd))
						if factor > max_kp_margin and not forced:
# Ball is too fast!
							factor = max_kp_margin
							keeper_will_save = FALSE
							player.tm_fstep = MC_AHEADC_FS*factor*keeper_spd
						else:
							player.tm_fstep = keeper_contact/bp

						if player.tm_fstep >= 1:
							player.tm_fstep = 1

						save_block = FALSE
						Actions.init_save_act(player, int(x), int(y), int(z), MC_AHEADC, zone, bp, int(SAVE_AHEADC_TIME/keeper_spd))
					else:
# Move to best position...
						shot_acknowledged = 1
			else:
				if z < SAVE_JUMP_HGT:
# Above head level...
					if bp <= SAVE_AJUMPB_TIME/keeper_spd and not keep_dive:
						keeper_contact = MCC_AJUMPB

						factor = 1.0/(float(bp)/(SAVE_AJUMPB_TIME/keeper_spd))
						if factor > max_kp_margin and not forced:
# Ball is too fast!
							factor = max_kp_margin
							keeper_will_save = FALSE
							player.tm_fstep = MC_AJUMPB_FS*factor*keeper_spd
						else:
							player.tm_fstep = keeper_contact/bp

						if player.tm_fstep >= 1:
							player.tm_fstep = 1

						save_block = TRUE
						Actions.init_save_act(player, int(x), int(y), int(z), MC_AJUMPB, zone, bp, int(SAVE_AJUMPB_TIME/keeper_spd))
					else:
						if bp <= SAVE_AJUMPC_TIME/keeper_spd or keep_dive:
							keeper_contact = MCC_AJUMPC

							factor = 1.0/(float(bp)/(SAVE_AJUMPC_TIME/keeper_spd))
							if factor > max_kp_margin and not forced:
# Ball is too fast!
								factor = max_kp_margin
								keeper_will_save = FALSE
								player.tm_fstep = MC_AJUMPC_FS*factor*keeper_spd
							else:
								player.tm_fstep = keeper_contact/bp

							if player.tm_fstep >= 1:
								player.tm_fstep = 1

							save_block = FALSE
							Actions.init_save_act(player, int(x), int(y), int(z), MC_AJUMPC, zone, bp, int(SAVE_AJUMPC_TIME/keeper_spd))
						else:
# Move to best position...
							shot_acknowledged = 1

#******************************************************************************
#*****************************************************************************/

# void save_in_zone_b(match_player *player,float x,float y,float z,int bp,char forced)
static func save_in_zone_b(player: match_player, x: float, y: float, z: float, bp: int, forced: int) -> void:
	var factor: float
	keeper_on_grnd = FALSE
	keeper_will_save = TRUE
	var zone: int = 2
	if z < SAVE_FEET_HGT:
# Feet level...
		if bp <= SAVE_BFOOTB_TIME/keeper_spd and not keep_dive:
			keeper_contact = MCC_BFOOTB

			factor = 1.0/(float(bp)/(SAVE_BFOOTB_TIME/keeper_spd))
			if factor > max_kp_margin and not forced:
# Ball is too fast!
				factor = max_kp_margin
				keeper_will_save = FALSE
				player.tm_fstep = MC_BFOOTB_FS*factor*keeper_spd
			else:
				player.tm_fstep = keeper_contact/bp

			if player.tm_fstep >= 1:
				player.tm_fstep = 1

			save_block = TRUE
			Actions.init_save_act(player, int(x), int(y), int(z), MC_BFOOTBL, zone, bp, int(SAVE_BFOOTB_TIME/keeper_spd))
		else:
			if bp <= SAVE_BFOOTC_TIME/keeper_spd or keep_dive:
				keeper_contact = MCC_BFOOTC

				factor = 1.0/(float(bp)/(SAVE_BFOOTC_TIME/keeper_spd))
				if factor > max_kp_margin and not forced:
# Ball is too fast!
					factor = max_kp_margin
					keeper_will_save = FALSE
					player.tm_fstep = MC_BFOOTC_FS*factor*keeper_spd
				else:
					player.tm_fstep = keeper_contact/bp

				if player.tm_fstep >= 1:
					player.tm_fstep = 1

				save_block = FALSE
				keeper_on_grnd = TRUE
				Actions.init_save_act(player, int(x), int(y), int(z), MC_BFOOTCL, zone, bp, int(SAVE_BFOOTC_TIME/keeper_spd))
			else:
# Move to best position...
				shot_acknowledged = 1
	else:
		if z < SAVE_CHEST_HGT:
# Chest level...
			if bp <= SAVE_BBODYB_TIME/keeper_spd and not keep_dive:
				keeper_contact = MCC_BBODYB
				factor = 1.0/(float(bp)/(SAVE_BBODYB_TIME/keeper_spd))
				if factor > max_kp_margin and not forced:
# Ball is too fast!
					factor = max_kp_margin
					keeper_will_save = FALSE
					player.tm_fstep = MC_BBODYB_FS*factor*keeper_spd
				else:
					player.tm_fstep = keeper_contact/bp

				if player.tm_fstep >= 1:
					player.tm_fstep = 1

				save_block = TRUE
				keeper_on_grnd = TRUE
				Actions.init_save_act(player, int(x), int(y), int(z), MC_BBODYBL, zone, bp, int(SAVE_BBODYB_TIME/keeper_spd))
			else:
				if bp <= SAVE_BBODYC_TIME/keeper_spd or keep_dive:
					keeper_contact = MCC_BBODYC
					factor = 1.0/(float(bp)/(SAVE_BBODYC_TIME/keeper_spd))
					if factor > max_kp_margin and not forced:
# Ball is too fast!
						factor = max_kp_margin
						keeper_will_save = FALSE
						player.tm_fstep = MC_BBODYC_FS*factor*keeper_spd
					else:
						player.tm_fstep = keeper_contact/bp

					if player.tm_fstep >= 1:
						player.tm_fstep = 1

					save_block = FALSE
					keeper_on_grnd = TRUE
					Actions.init_save_act(player, int(x), int(y), int(z), MC_BBODYCL, zone, bp, int(SAVE_BBODYC_TIME/keeper_spd))
				else:
# Move to best position...
					shot_acknowledged = 1
		else:
			if z < SAVE_HEAD_HGT:
# Head level...
				if bp <= SAVE_BHEADB_TIME/keeper_spd and not keep_dive:
					keeper_contact = MCC_BHEADB
					factor = 1.0/(float(bp)/(SAVE_BHEADB_TIME/keeper_spd))
					if factor > max_kp_margin and not forced:
# Ball is too fast!
						factor = max_kp_margin
						keeper_will_save = FALSE
						player.tm_fstep = MC_BHEADB_FS*factor*keeper_spd
					else:
						player.tm_fstep = keeper_contact/bp

					if player.tm_fstep >= 1:
						player.tm_fstep = 1

					save_block = TRUE
					Actions.init_save_act(player, int(x), int(y), int(z), MC_BHEADBL, zone, bp, int(SAVE_BHEADB_TIME/keeper_spd))
				else:
					if bp <= SAVE_BHEADC_TIME/keeper_spd or keep_dive:
						keeper_contact = MCC_BHEADC
						factor = 1.0/(float(bp)/(SAVE_BHEADC_TIME/keeper_spd))
						if factor > max_kp_margin and not forced:
# Ball is too fast!
							factor = max_kp_margin
							keeper_will_save = FALSE
							player.tm_fstep = MC_BHEADC_FS*factor*keeper_spd
						else:
							player.tm_fstep = keeper_contact/bp

						if player.tm_fstep >= 1:
							player.tm_fstep = 1

						save_block = FALSE
						Actions.init_save_act(player, int(x), int(y), int(z), MC_BHEADCL, zone, bp, int(SAVE_BHEADC_TIME/keeper_spd))
					else:
# Move to best position...
						shot_acknowledged = 1
			else:
				if z < SAVE_JUMP_HGT:
# Above head level...
					if bp <= SAVE_BJUMPB_TIME/keeper_spd and not keep_dive:
						keeper_contact = MCC_BJUMPB
						factor = 1.0/(float(bp)/(SAVE_BJUMPB_TIME/keeper_spd))
						if factor > max_kp_margin and not forced:
# Ball is too fast!
							factor = max_kp_margin
							keeper_will_save = FALSE
							player.tm_fstep = MC_BJUMPB_FS*factor*keeper_spd
						else:
							player.tm_fstep = keeper_contact/bp

						if player.tm_fstep >= 1:
							player.tm_fstep = 1

						save_block = TRUE
						Actions.init_save_act(player, int(x), int(y), int(z), MC_BJUMPBL, zone, bp, int(SAVE_BJUMPB_TIME/keeper_spd))
					else:
# Move to best position...
						shot_acknowledged = 1

#******************************************************************************
#*****************************************************************************/

# void save_in_zone_c(match_player *player,float x,float y,float z,int bp,char forced)
static func save_in_zone_c(player: match_player, x: float, y: float, z: float, bp: int, forced: int) -> void:
	var factor: float
	keeper_will_save = TRUE
	keeper_on_grnd = FALSE
	var zone: int = 3
	if z < SAVE_FEET_HGT:
# Feet level...
		if bp <= SAVE_CFOOTB_TIME/keeper_spd and not keep_dive:
			keeper_contact = MCC_CFOOTB
			factor = 1.0/(float(bp)/(SAVE_CFOOTB_TIME/keeper_spd))
			if factor > max_kp_margin and not forced:
# Ball is too fast!
				factor = max_kp_margin
				keeper_will_save = FALSE
				player.tm_fstep = MC_CFOOTB_FS*factor*keeper_spd
			else:
				player.tm_fstep = keeper_contact/bp

			if player.tm_fstep >= 1:
				player.tm_fstep = 1

			save_block = TRUE
			keeper_on_grnd = TRUE
			Actions.init_save_act(player, int(x), int(y), int(z), MC_CFOOTBL, zone, bp, int(SAVE_CFOOTB_TIME/keeper_spd))
		else:
			if bp <= SAVE_CFOOTC_TIME/keeper_spd or keep_dive:
				keeper_contact = MCC_CFOOTC
				factor = 1.0/(float(bp)/(SAVE_CFOOTC_TIME/keeper_spd))
				if factor > max_kp_margin and not forced:
# Ball is too fast!
					factor = max_kp_margin
					keeper_will_save = FALSE
					player.tm_fstep = MC_CFOOTC_FS*factor*keeper_spd
				else:
					player.tm_fstep = keeper_contact/bp

				if player.tm_fstep >= 1:
					player.tm_fstep = 1

				save_block = FALSE
				keeper_on_grnd = TRUE
				Actions.init_save_act(player, int(x), int(y), int(z), MC_CFOOTCL, zone, bp, int(SAVE_CFOOTC_TIME/keeper_spd))
			else:
# Move to best position...
				shot_acknowledged = 1
	else:
		if z < SAVE_CHEST_HGT:
# Chest level...
			if bp <= SAVE_CBODYB_TIME/keeper_spd and not keep_dive:
				keeper_contact = MCC_CBODYB
				factor = 1.0/(float(bp)/(SAVE_CBODYB_TIME/keeper_spd))
				if factor > max_kp_margin and not forced:
# Ball is too fast!
					factor = max_kp_margin
					keeper_will_save = FALSE
					player.tm_fstep = MC_CBODYB_FS*factor*keeper_spd
				else:
					player.tm_fstep = keeper_contact/bp

				if player.tm_fstep >= 1:
					player.tm_fstep = 1

				save_block = TRUE
				keeper_on_grnd = TRUE
				Actions.init_save_act(player, int(x), int(y), int(z), MC_CBODYBL, zone, bp, int(SAVE_CBODYB_TIME/keeper_spd))
			else:
				if bp <= SAVE_CBODYC_TIME/keeper_spd or keep_dive:
					keeper_contact = MCC_CBODYC
					factor = 1.0/(float(bp)/(SAVE_CBODYC_TIME/keeper_spd))
					if factor > max_kp_margin and not forced:
# Ball is too fast!
						factor = max_kp_margin
						keeper_will_save = FALSE
						player.tm_fstep = MC_CBODYC_FS*factor*keeper_spd
					else:
						player.tm_fstep = keeper_contact/bp

					if player.tm_fstep >= 1:
						player.tm_fstep = 1

					save_block = FALSE
					keeper_on_grnd = TRUE
					Actions.init_save_act(player, int(x), int(y), int(z), MC_CBODYCL, zone, bp, int(SAVE_CBODYC_TIME/keeper_spd))
				else:
# Move to best position...
					shot_acknowledged = 1
		else:
			if z < SAVE_HEAD_HGT:
# Head level...
				if bp <= SAVE_CHEADB_TIME/keeper_spd and not keep_dive:
					keeper_contact = MCC_CHEADB
					factor = 1.0/(float(bp)/(SAVE_CHEADB_TIME/keeper_spd))
					if factor > max_kp_margin and not forced:
# Ball is too fast!
						factor = max_kp_margin
						keeper_will_save = FALSE
						player.tm_fstep = MC_CHEADB_FS*factor*keeper_spd
					else:
						player.tm_fstep = keeper_contact/bp

					if player.tm_fstep >= 1:
						player.tm_fstep = 1

					save_block = TRUE
					Actions.init_save_act(player, int(x), int(y), int(z), MC_CHEADBL, zone, bp, int(SAVE_CHEADB_TIME/keeper_spd))
				else:
# Move to best position...
					shot_acknowledged = 1
			else:
				if z < SAVE_JUMP_HGT:
# Above head level...
					if bp <= SAVE_CJUMPB_TIME/keeper_spd or keep_dive:
						keeper_contact = MCC_CJUMPB
						factor = 1.0/(float(bp)/(SAVE_CJUMPB_TIME/keeper_spd))
						if factor > max_kp_margin and not forced:
# Ball is too fast!
							factor = max_kp_margin
							keeper_will_save = FALSE
							player.tm_fstep = MC_CJUMPB_FS*factor*keeper_spd
						else:
							player.tm_fstep = keeper_contact/bp

						if player.tm_fstep >= 1:
							player.tm_fstep = 1

						save_block = TRUE
						Actions.init_save_act(player, int(x), int(y), int(z), MC_CJUMPBL, zone, bp, int(SAVE_CJUMPB_TIME/keeper_spd))
					else:
# Move to best position...
						shot_acknowledged = 1

#******************************************************************************
#*****************************************************************************/

# Send keeper to point between centre of goal and ball!
# Point ratio between goal and ball varies with distance to ball.
# i.e. If opponent is close then point will be further from goal.

# void close_angle(match_player *player,float d,float &x,float &y)   -> returns [x, y]
static func close_angle(player: match_player, d: float, x: float, y: float) -> Array:
	var gx: float
	var gd: float
	var cd: float

	cd = CLOSE_ANG_DIST+(prat*player.tm_vis)/8

	if player.tm_player < 12:
# Keeper A...
		gx = 0
	else:
# Keeper B...
		gx = pitch_len

	gd = prat+(d*((cd-d)/cd))	#	How far target point is along line.
	x = gx+((ballx-gx)*gd/d)
	y = cntspot_y+((bally-cntspot_y)*gd/d)
	return [x, y]

#******************************************************************************
#*****************************************************************************/

# char target_towards_ball(float tx,float ty,float px,float py)
static func target_towards_ball(tx: float, ty: float, px: float, py: float) -> int:
# Get distance of target to present ball pos.
	var d: float = Maths.calc_dist(tx-ballx, ty-bally)

	if d <= Maths.calc_dist(px-ballx, py-bally):
		return TRUE		# Player is further from ball than target!

	return FALSE

#******************************************************************************
#*****************************************************************************/

# void init_user_save(match_player *player)
static func init_user_save(player: match_player) -> void:
	var t: int = 0
	var dist: float = prat*1.4
	keeper_will_save = FALSE
	save_block = TRUE
	reset_ideas(player)

	if save_direction:
# Direction selected...
		if save_direction > 0:
# Raw Left...
			if match_mode == PEN_KICK_A:
# Dive Right and Up-field...
				Actions.init_anim(player, MC_CBODYBR)
				t = int(SAVE_BBODYB_TIME/keeper_spd)
				dist = -dist
			else:
# Dive Right and Down-field...
				Actions.init_anim(player, MC_CBODYBR)
				t = int(SAVE_BBODYB_TIME/keeper_spd)
		else:
# Raw Right...
			if match_mode == PEN_KICK_A:
# Dive Left and Down-field...
				Actions.init_anim(player, MC_CBODYBL)
				t = int(SAVE_BBODYB_TIME/keeper_spd)
			else:
# Dive Left and Up-field...
				Actions.init_anim(player, MC_CBODYBL)
				t = int(SAVE_BBODYB_TIME/keeper_spd)
				dist = -dist
	else:
		Actions.init_anim(player, MC_ABODYB)
		t = int(SAVE_ABODYB_TIME/keeper_spd)
		dist = 0

	player.go_tx = player.tm_x
	player.go_ty = player.tm_y+dist
	player.go_txdis = 0
	player.go_tydis = dist/t
	player.go_cnt = int(1/player.tm_fstep)
	player.dir_mode = 5
	player.tm_zdis = 0
	if keeper_on_grnd:
# Stay down for a bit after save...
		if save_block:
			player.int_cnt = s16(int(4+((128-player.tm_rate)/12)+1/player.tm_fstep))		# Time to get up!
		else:
			player.int_cnt = s16(int(18+1/player.tm_fstep))		# Time to get up!
	else:
		player.int_cnt = s16(int(2+1/player.tm_fstep))

	player.int_move = I_SAVE_WAIT
	action = "Save"
	player.tm_act = SAVE_ACT
	newdx = player.tm_xdis
	newdy = player.tm_ydis

#******************************************************************************
#*****************************************************************************/

# #define DIVE_POINT 3			(declared at the top of this part)
# #define DIVE_FEET_DIST (prat*4)	(declared at the top of this part: DIVE_FEET_DIST())

# Someone has shot...
# Send keeper to intersection with ball path.
# If he cannot meet ball then best try!

# void go_to_save_path(match_player *player,char forced=FALSE)
static func go_to_save_path(player: match_player, forced: int = FALSE) -> void:
	keeper_spd = (float(player.tm_flair+player.tm_rate)/128)*(2 if forced else 1)

# Calculate next frame distance to the ball...
	var d: float = Maths.calc_dist(player.tm_x-(ballx+ballxdis), player.tm_y-(bally+ballydis))

	if not forced:
		if d < player.tm_dist:
# Ball is getting closer...
			if player.tm_player == KP_A:
# Keeper A
				if ballx < cntspot_x:
					shot_acknowledged = u8(1+((128-player.tm_vis)/8))
			else:
# Keeper B
				if ballx > cntspot_x:
					shot_acknowledged = u8(1+((128-player.tm_vis)/8))

	if shot_acknowledged or forced:
		var flag: int
		var vision: int = ((128-player.tm_vis)/2)

# Is shot on Target?
#	if (ABS(ballxdis)>0)
		if true:
			var kp_xoff: float
			var x: float = 0.0
			var y: float = 0.0
			var z: float = 0.0
			var ox: float
			var oy: float
			var oz: float
			var xc: float
			var yc: float
			var zc: float
			var xf: float
			var yf: float
			var zf: float
			var xns: float
			var yns: float
			var zns: float
			var bp: int
			var ob: int
			var min_d: float = 2000
			# (C: inner block "float d,t,fd;" shadows the outer d -> renamed d2)
			var d2: float = 0.0
			var t: float
			var fd: float
			var px: float = player.tm_x
			var py: float = player.tm_y
			var rate: float = Actions.actual_spd(player)	# Dive is 2 x rate.
			flag = FALSE
			var in_area: int = FALSE

			bp = 1
			ob = 1
			ox = ballx
			oy = bally
			oz = ballz
			xc = ballx
			yc = bally
			zc = ballz

			if not keep_dive:
				var see_swerve: float

				see_swerve = (64.0+(player.tm_vis/2))/128

				var i: int = 1
				while i < 50:
# Coords without swerve...
					xns = ns_ball_pred_tab[i][0]
					yns = ns_ball_pred_tab[i][1]
					zns = ns_ball_pred_tab[i][2]

# Coords with swerve...
					x = ball_pred_tab[i][0]
					y = ball_pred_tab[i][1]
					z = ball_pred_tab[i][2]

# Coords seeing some swerve...
					x = xns+((x-xns)*see_swerve)
					y = yns+((y-yns)*see_swerve)
					z = zns+((z-zns)*see_swerve)

					in_area = FALSE

					if y > top_post_y and y < bot_post_y:
						kp_xoff = 4
					else:
						kp_xoff = 0
# Try and stop keeper saving and carrying ball behind line...

					if x > cntspot_x:
# Team B goal-line...
						if x >= pitch_len-kp_xoff:
							i = 60
							if ABS(y-cntspot_y) > ((prat*4.5)+(128-player.tm_flair)/4):
# Too wide!
									flag = FALSE			# Don't bother saving!

					if x <= cntspot_x:
# Team A goal-line...
						if x < 0+kp_xoff:
							i = 60
							if ABS(y-cntspot_y) > ((prat*4.5)+(128-player.tm_flair)/4):
# Too wide!
								flag = FALSE			# Don't bother saving!

					if i != 60:
						if player.tm_player < 12:
							if (x < prat*18 and y > cntspot_y-(21*prat)
								and (y < cntspot_y+(21*prat))):
								in_area = TRUE
						else:
							if (x > pitch_len-(prat*18) and y > cntspot_y-(21*prat)
								and (y < cntspot_y+(21*prat))):
								in_area = TRUE

						if in_area:
							d2 = Maths.calc_dist(x-px, y-py)
#				  			if (d<min_d && z<SAVE_JUMP_HGT+prat && target_towards_ball(x,y,px,py))
							if d2 < min_d and z < SAVE_JUMP_HGT+prat/2:
# Store closest ball!
								ox = xc
								oy = yc
								oz = zc
								ob = bp
								min_d = d2
								bp = i
								xc = x
								yc = y
								zc = z
								flag = TRUE
							else:
# Getting further away...
								if d2-min_d > prat:
# Definately not getting any closer...
									i = 60			# Quit.
					i += 1

			else:
				flag = TRUE
				xc = ball_pred_tab[DIVE_POINT][0]
				yc = ball_pred_tab[DIVE_POINT][1]
				zc = ball_pred_tab[DIVE_POINT][2]
				d2 = Maths.calc_dist(xc-px, yc-py)
				x = (xc-px)/d2
				y = (yc-py)/d2
				if keep_dive:
					xc += x*prat
					yc += y*prat
				ox = xc
				oy = yc
				oz = zc
				ob = DIVE_POINT
				bp = DIVE_POINT

			if flag:
# Shot is in area...
				x = ox+((xc-ox)/2)		# Between closest and one before...
				y = oy+((yc-oy)/2)
				z = oz+((zc-oz)/2)

				if forced:			# Forced to dive at attackers feet...
					fd = Maths.calc_dist(x-px, y-py)
					xf = (x-px)/fd
					yf = (y-py)/fd
					x += xf*3
					y += yf*3		# Dive beyond point of contact...

#				bp=ob;

# Nearest ball coord.

				d2 = Maths.calc_dist(x-px, y-py)		# Distance to keeper...

				var st: int = player.go_step
				player.go_step = TRUE
				t = d2/Actions.actual_spd(player)	# Time to step there...
				player.go_step = st

				max_kp_margin = 1.5+(1.8*time_factor/90)

#*************************************************************/
#*************************************************************/
# #ifdef EURO96
				if EURO96 and (penalty_shot and user_controlled):
					if users_dir[user_controlled-1].f & 8:
						save_direction = -1
					if users_dir[user_controlled-1].f & 4:
						save_direction = 1

					var good_choice: int = FALSE
# User decides which way to dive...
					if t < 1 and not save_direction:
# Straight on...(good choice!)
						good_choice = TRUE
					else:
						if save_direction:
# User has chosen a direction...
							if save_direction < 0:
# Left selected...
								if ((x < cntspot_x and player.tm_y > (y+(SAVE_ZONE_A/2)))
									or (x > cntspot_x and player.tm_y < (y-(SAVE_ZONE_A/2)))):
									good_choice = TRUE
							else:
# Right selected...
								if ((x < cntspot_x and player.tm_y < (y-(SAVE_ZONE_A/2)))
									or (x > cntspot_x and player.tm_y > (y+(SAVE_ZONE_A/2)))):
									good_choice = TRUE
						else:
							if d2 <= SAVE_ZONE_A:
								good_choice = TRUE

					if good_choice:
# Let computer save...
						if t < 1:
							save_in_zone_a(player, x, y, z, bp, forced)
						else:
							if d2 <= SAVE_ZONE_A:
								save_in_zone_a(player, x, y, z, bp, forced)
							else:
								if d2 <= SAVE_ZONE_B:
									save_in_zone_b(player, x, y, z, bp, forced)
								else:
									if d2 <= (SAVE_ZONE_C+prat*2):
										save_in_zone_c(player, x, y, z, bp, forced)
									else:
										keep_dive = FALSE
					else:
# Save in the direction of user's choice...
						init_user_save(player)
				else:
# #endif
#*************************************************************/
#*************************************************************/
					if t < 1:
#************************************/
# Already in preferred position... //
#************************************/

						save_in_zone_a(player, x, y, z, bp, forced)
					else:

						if t < bp-SAVE_AHEADC_TIME:
#************************************************************/
# Can get body behind it and still have time to animate... //
#************************************************************/
							reset_ideas(player)
							player.go_step = TRUE
							if player.tm_player < 12:
								Actions.init_run_act(player, x-prat, y, TRUE)			#ball meet point
							else:
								Actions.init_run_act(player, x+prat, y, TRUE)			#ball meet point
						else:
							if d2 <= SAVE_ZONE_A:
								save_in_zone_a(player, x, y, z, bp, forced)
							else:
								if d2 <= SAVE_ZONE_B:
									save_in_zone_b(player, x, y, z, bp, forced)
								else:
									if d2 <= (SAVE_ZONE_C+prat*2):
										save_in_zone_c(player, x, y, z, bp, forced)
									else:
										keep_dive = FALSE

#******************************************************************************
#*****************************************************************************/

# void fake_ball_poss(int p,float x,float y,float z)
static func fake_ball_poss(p: int, x: float, y: float, z: float) -> void:
	save_ball_poss = ball_poss
	save_ballx = ballx
	save_bally = bally
	save_ballz = ballz
	ballx = x
	bally = y
	ballz = z
	ball_poss = p

#******************************************************************************
#*****************************************************************************/

# void restore_ball_poss()
static func restore_ball_poss() -> void:
	ball_poss = save_ball_poss
	ballx = save_ballx
	bally = save_bally
	ballz = save_ballz

#******************************************************************************
#*****************************************************************************/

# char kick_straight()
static func kick_straight() -> int:
	if pass_type == -1 or (pass_type >= 4 and pass_type <= 6):
		return TRUE
	else:
		return FALSE

#******************************************************************************
#*****************************************************************************/

# char first_time_strike(int p,float x,float y,float z,float px,float py)
static func first_time_strike(p: int, x: float, y: float, z: float, px: float, py: float) -> int:
	var d: float
	var obx: float = ballx
	var oby: float = bally

	var sr: int = teams[p-1].tm_srng
	if p < 12:
		d = Maths.calc_dist(pitch_len-x, cntspot_y-y)
	else:
		d = Maths.calc_dist(x, cntspot_y-y)

	if d < (MIN_SHOOT_DIST+(float(teams[p-1].tm_pow)*3)):
		teams[p-1].tm_srng = TRUE
	else:
		teams[p-1].tm_srng = FALSE

	var xpd: float = teams[p-1].tm_xdis
	var ypd: float = teams[p-1].tm_ydis
	teams[p-1].tm_xdis = x_face
	teams[p-1].tm_ydis = y_face
	ballx = teams[p-1].tm_x
	bally = teams[p-1].tm_y

	pass_type = FALSE
	receiver = FALSE
	var allow: int = 0
	var gx: float
	var gy: float

	if p < 12:
		gx = pitch_len
	else:
		gx = 0

	gy = cntspot_y
	gx -= x
	gy -= y
	d = Maths.calc_dist(gx, gy)

	fake_ball_poss(p, x, y, z)

	if auto_select:
		if ball_int_speed > 6:
# Ball is moving so he can trap...
			allow = 128		# Can control it...

		if shoot_decide(teams[p-1]):
			pass_type = 0
			allow += 3					# Kick or volley!
			if d < MIN_HEADER_RNG+(prat*teams[p-1].tm_pow/8):
# In head range also!
				allow += 8+16			# Standing or Jumping header!
				if kick_straight():
# Target is forward!
					allow += 4			# Diving header!
		else:
			teams[p-1].tm_xdis = -teams[p-1].tm_xdis
			teams[p-1].tm_ydis = -teams[p-1].tm_ydis		# Reverse face!

			if shoot_decide(teams[p-1]):
				pass_type = 0
				allow += 32				# Overhead!
			else:
				if punt_decide(teams[p-1]):	# Overhead punt???
					pass_type = 0
					allow += 32				# Overhead!
				else:
					teams[p-1].tm_xdis = -teams[p-1].tm_xdis
					teams[p-1].tm_ydis = -teams[p-1].tm_ydis		# Reverse face!
					if punt_decide(teams[p-1]):
						pass_type = 0
						allow += 1+2+4+8+16						# Kick or volley or any header!
					else:
						receiver = pass_decide(teams[p-1], FALSE)
						if receiver:
							if pass_type == -1:
# Chip pass!
								allow += 64+8+16		# Chip, S-head, J-head!
							else:
								if kick_straight():
									allow += 8+16		# S-head, J-head!
	else:
		allow = 0

	restore_ball_poss()

	teams[p-1].tm_srng = sr			# Restore range flag!
	teams[p-1].tm_xdis = xpd
	teams[p-1].tm_ydis = ypd
	ballx = obx
	bally = oby

	return u8(allow)

#******************************************************************************
#*****************************************************************************/

# char user_pass_check(int p,float x,float y,float z,float px,float py)
static func user_pass_check(p: int, x: float, y: float, z: float, px: float, py: float) -> int:
	var d: float
	var obx: float = ballx
	var oby: float = bally

	var sr: int = teams[p-1].tm_srng
	if p < 12:
		d = Maths.calc_dist(pitch_len-x, cntspot_y-y)
	else:
		d = Maths.calc_dist(x, cntspot_y-y)

	if d < (MIN_SHOOT_DIST+(float(teams[p-1].tm_pow)*3)):
		teams[p-1].tm_srng = TRUE
	else:
		teams[p-1].tm_srng = FALSE

	var xpd: float = teams[p-1].tm_xdis
	var ypd: float = teams[p-1].tm_ydis
	teams[p-1].tm_xdis = x_face
	teams[p-1].tm_ydis = y_face
	ballx = teams[p-1].tm_x
	bally = teams[p-1].tm_y

	pass_type = FALSE
	receiver = FALSE
	var allow: int = 0
	var gx: float
	var gy: float

	if p < 12:
		gx = pitch_len
	else:
		gx = 0

	gy = cntspot_y
	gx -= x
	gy -= y
	d = Maths.calc_dist(gx, gy)

	fake_ball_poss(p, x, y, z)

	receiver = pass_decide(teams[p-1], FALSE)
	if receiver:
		if pass_type == -1:
# Chip pass!
			allow += 64+8+16		# Chip, S-head, J-head!
		else:
			if kick_straight():
				allow += 8+16		# S-head, J-head!
	else:
		allow = 0

	restore_ball_poss()

	teams[p-1].tm_srng = sr			# Restore range flag!
	teams[p-1].tm_xdis = xpd
	teams[p-1].tm_ydis = ypd
	ballx = obx
	bally = oby

	return u8(allow)


#******************************************************************************
#*****************************************************************************/

# void decide_strike(match_player *p,short t,char c,char s)
static func decide_strike(p: match_player, t: int, c: int, s: int) -> void:
	var x: float = ball_pred_tab[t][0]
	var y: float = ball_pred_tab[t][1]
	var z: float = ball_pred_tab[t][1]

	p.int_cnt = t						# Flair factor.
	Actions.init_run_act(p, x, y, TRUE)
	p.tm_strike = TRUE

#******************************************************************************
#*****************************************************************************/

# void strike_and_control(match_player *player,intercept_data *s,short action)
static func strike_and_control(player: match_player, s: intercept_data, action: int) -> void:
	player.tm_stime = s.atime+1

#	player->int_cnt=player->tm_stime+alarm+free+1;	// Make sure he seems busy for the duration!

	var x: float = s.x
	var y: float = s.y

	match action:
		7, 9, 10:
			# if (player->tm_fpass_type=s->ptype)  (assignment inside the test)
			player.tm_fpass_type = s.ptype
			if player.tm_fpass_type:
# Equate pass type and test!
				player.tm_fpass_to = s.pplr

	var gt: int = get_there_time(player.tm_player, x, y)

	player.tm_ftime = s.free
	player.tm_strike = action
	Actions.init_run_act(player, x, y, FALSE)

	player.int_cnt = s16(int(player.go_cnt+player.tm_ftime+player.tm_stime))
	if must_face:
		player.int_cnt = s16(player.int_cnt+player.mface_time)

	if user_controlled:
		player.special = -TRUE		# Special action decided!
#
#		if (player->go_cnt>1)
#		{
#			player->go_cnt=1;
#			player->int_cnt=1;
#		}
#

#******************************************************************************
#*****************************************************************************/

# void cancel_int(int p)
static func cancel_int(p: int) -> void:
# should never get here!
	Actions.init_stand_act(teams[p-1])

#******************************************************************************
#*****************************************************************************/

# void intercept(int p)
static func intercept(p: int) -> void:
	action = "Intercept"

	reset_ideas(teams[p-1])

	if p < 12:
		interceptor_a = p
	else:
		interceptor_b = p

# His intention is to intercept ball.
# Therefore his flair determines no. of turns before rethink!

	var ff: int = 33-(teams[p-1].tm_flair/4)
	teams[p-1].int_move = I_INTERCEPT		# Intercept ball!
	teams[p-1].int_cnt = ff					# Intercept ball!

	var x: float
	var y: float

	if special_move:
		teams[p-1].special = TRUE
	else:
		teams[p-1].special = FALSE

	if true:
		for i in range(10, -1, -1):
			if strike[i].t:
				if i > 0:
					if user_controlled:
# uf1 = strike, uf2 = control!
						if uf1 and i > 4:
							strike_and_control(teams[p-1], strike[i], i)
							break
						else:
							if uf2 and i <= 4 and i:
								strike_and_control(teams[p-1], strike[i], i)
								break
					else:
						strike_and_control(teams[p-1], strike[i], i)
						break
				else:
# Run onto ball...
					if strike[0].stop:
						Actions.init_stop_act(teams[p-1], strike[0].x, strike[0].y)
					else:
						Actions.init_run_act(teams[p-1], strike[0].x, strike[0].y, FALSE)

					teams[p-1].go_cnt += 1
					break

#******************************************************************************
#*****************************************************************************/

# float fstep_factor(short c)
static func fstep_factor(c: int) -> float:
# Returns a range of 0.6(c=0) to 1.6(c=128)
	var f: float = 0.6+(float(c)/128)
	return f

#******************************************************************************
#*****************************************************************************/

# #ifdef EURO96
# Euro 96 has first time pass implemented...

# char can_i_intercept(int p_num,float x,float y,float z,float px,float py,short i)
static func can_i_intercept(p_num: int, x: float, y: float, z: float, px: float, py: float, i: int) -> int:
	if z >= teams[p_num-1].tm_jump:
		return FALSE

	var cx: float = 0.0
	var cy: float = 0.0
	var cz: float = 0.0
	var cx2: float = 0.0
	var cy2: float = 0.0
	var ang: float
	var rate: float = Actions.full_spd(teams[p_num-1])
	var d: float = Maths.calc_dist(x-px, y-py)
	var can_strike: int = 0
	var do_it: int = FALSE
	var stand: int
	var strike_option: int = FALSE
	var trap_option: int = FALSE
	var pass_option: int = FALSE

	var ff: int = 1+teams[p_num-1].tm_flair/16		# Reaction times.

	var gt: int = get_there_time(p_num, x, y)
	var t: int
	var r: Array

	if gt <= i:
# He can get to ball in time...

		if ball_poss:
# Opponent has ball... (No control or strike!)
#***** RUN ONTO BALL *****/
			t = i-gt
			if t > 0 and t < strike[0].free and (teams[p_num-1].control or t < ff):
				strike[0].t = i
				strike[0].free = t
				strike[0].x = x
				strike[0].y = y
				strike[0].stop = stop_and_face
				do_it = TRUE
		else:
			if user_controlled:
				can_strike = 128+32+16+8+4+2+1
				pass_type = 0
				strike_option = uf1 & bi(not uf2)
				trap_option = uf2 & bi(not uf1)
				pass_option = uf1 & uf2
				if pass_option:
					can_strike = user_pass_check(p_num, x, y, z, px, py)
			else:
				can_strike = first_time_strike(p_num, x, y, z, px, py)

#***** RUN ONTO BALL *****/

			if z < PLAYER_HEIGHT/3:
# Feet level...
				ang = Actions.angle_to_xy(x-px, y-py, teams[p_num-1].tm_xdis, teams[p_num-1].tm_ydis)
				if ang > 0 or user_controlled:
# Target is in front of player...
					t = i-gt
					if t >= 0 and t < strike[0].free and (teams[p_num-1].control or t < ff):
						strike[0].t = i
						strike[0].free = t
						strike[0].x = x
						strike[0].y = y
						strike[0].stop = stop_and_face
						do_it = TRUE

#			if (plr_facing(x-px,y-py,&teams[p_num-1]) && target_towards_ball(x,y,px,py)
#			if ((target_towards_ball(x,y,px,py) || stop_and_face) &&
#			if (
#				 teams[p_num-1].tm_act<=TURN_ACT)

			if ((p_num != KP_A and p_num != KP_B)
				or (p_num == KP_A and cannot_pick_up < 12) or (p_num == KP_B and cannot_pick_up > 11)):
# Keeper cannot pick ball up...

# Player must be running or standing...

				if teams[p_num-1].tm_trap >= 0:
# Must control ball or may hit it first time...

#***** TRAP AND CONTROL *****/

					if can_strike & 128:
						if z < PLAYER_HEIGHT/2:
# Feet level...
							r = Actions.rotate_offs(MC_TRAPL, cx, cy, cz, x_face, y_face); cx = r[0]; cy = r[1]; cz = r[2]
							r = Actions.rotate_offs(MC_TRAPR, cx2, cy2, cz, x_face, y_face); cx2 = r[0]; cy2 = r[1]; cz = r[2]
							cx = (cx+cx2)/2
							cy = (cy+cy2)/2
							gt = get_there_time(p_num, x-cx, y-cy)
							t = int(i-(gt+ft_ttm))
							if t >= 0 and t < strike[1].free and (teams[p_num-1].control or t < ff):
# He has time to animate...
# Best so far!
								special_move = TRUE
								if trap_option or not user_controlled:
									strike[1].t = i
									strike[1].free = t
									strike[1].atime = ft_ttm
									strike[1].gt = gt
									strike[1].x = x-cx
									strike[1].y = y-cy
									strike[1].stop = stop_and_face
									do_it = TRUE
						else:
							if z < (PLAYER_HEIGHT-2):
# Chest level...
								r = Actions.rotate_offs(MC_CHEST, cx, cy, cz, x_face, y_face); cx = r[0]; cy = r[1]; cz = r[2]
								gt = get_there_time(p_num, x-cx, y-cy)
								t = int(i-(gt+ft_ctm))
								if t >= 0 and t < strike[2].free and (teams[p_num-1].control or t < ff):
# He has time to animate...
# Best so far!
									special_move = TRUE
									if trap_option or not user_controlled:
										strike[2].t = i
										strike[2].free = t
										strike[2].atime = ft_ctm
										strike[2].gt = gt
										strike[2].x = x-cx
										strike[2].y = y-cy
										strike[2].stop = stop_and_face
										do_it = TRUE
							else:
								if z < (PLAYER_HEIGHT+4):
# Head level...
									r = Actions.rotate_offs(MC_D_HEAD, cx, cy, cz, x_face, y_face); cx = r[0]; cy = r[1]; cz = r[2]
									gt = get_there_time(p_num, x-cx, y-cy)
									t = int(i-(gt+ft_utm))
									if t >= 0 and t < strike[3].free and (teams[p_num-1].control or t < ff):
# He has time to animate...
# Best so far!
										special_move = TRUE
										if trap_option or not user_controlled:
											strike[3].t = i
											strike[3].free = t
											strike[3].atime = ft_utm
											strike[3].gt = gt
											strike[3].x = x-cx
											strike[3].y = y-cy
											strike[3].stop = stop_and_face
											do_it = TRUE

				if teams[p_num-1].tm_trap <= 0:

# May hit it first time...

#***** FIRST TIME STRIKE *****/

					if z < PLAYER_HEIGHT/4:
						if can_strike & 1:
# Feet level...
							r = Actions.rotate_offs(MC_SHOOTL, cx, cy, cz, x_face, y_face); cx = r[0]; cy = r[1]; cz = r[2]
							r = Actions.rotate_offs(MC_SHOOTR, cx2, cy2, cz, x_face, y_face); cx2 = r[0]; cy2 = r[1]; cz = r[2]
							cx = (cx+cx2)/2
							cy = (cy+cy2)/2
							gt = get_there_time(p_num, x-cx, y-cy)
							t = int(i-(gt+ft_ktm))
							if t >= 0 and t < strike[8].free and (teams[p_num-1].control or t < ff):
# He has time to animate...
# Best so far!
								special_move = TRUE
								if strike_option or not user_controlled:
									strike[8].t = i
									strike[8].free = t
									strike[8].atime = ft_ktm
									strike[8].gt = gt
									strike[8].x = x-cx
									strike[8].y = y-cy
									strike[8].stop = stop_and_face
									do_it = TRUE

						if can_strike & 64:
# Feet level...
							r = Actions.rotate_offs(MC_CHIPL, cx, cy, cz, x_face, y_face); cx = r[0]; cy = r[1]; cz = r[2]
							r = Actions.rotate_offs(MC_CHIPR, cx2, cy2, cz, x_face, y_face); cx2 = r[0]; cy2 = r[1]; cz = r[2]
							cx = (cx+cx2)/2
							cy = (cy+cy2)/2
							gt = get_there_time(p_num, x-cx, y-cy)
							t = int(i-(gt+ft_ctm))
							if t >= 0 and t < strike[10].free and (teams[p_num-1].control or t < ff):
# He has time to animate...
# Best so far!
								special_move = TRUE
								if strike_option or not user_controlled:
									strike[10].t = i
									strike[10].free = t
									strike[10].ptype = pass_type
									strike[10].pplr = receiver
									strike[10].atime = ft_ctm
									strike[10].gt = gt
									strike[10].x = x-cx
									strike[10].y = y-cy
									strike[10].stop = stop_and_face
									do_it = TRUE
					else:
						if z < PLAYER_HEIGHT*.5:
# volley level...
							if can_strike & 2:
								r = Actions.rotate_offs(MC_VOLLEYL, cx, cy, cz, x_face, y_face); cx = r[0]; cy = r[1]; cz = r[2]
								gt = get_there_time(p_num, x-cx, y-cy)
								t = int(i-(gt+ft_vtm))
								if t >= 0 and t < strike[5].free and (teams[p_num-1].control or t < ff):
# He has time to animate...
# Best so far!
									special_move = TRUE
									if strike_option or not user_controlled:
										strike[5].t = i
										strike[5].free = t
										strike[5].atime = ft_vtm
										strike[5].gt = gt
										strike[5].x = x-cx
										strike[5].y = y-cy
										strike[5].stop = stop_and_face
										do_it = TRUE
						else:
							if z < PLAYER_HEIGHT*.67:
								if can_strike & 4:
									r = Actions.rotate_offs(MC_DV_HEAD, cx, cy, cz, x_face, y_face); cx = r[0]; cy = r[1]; cz = r[2]
									gt = get_there_time(p_num, x-cx, y-cy)
									t = int(i-(gt+ft_dtm))
									if t >= 0 and t < strike[6].free and (teams[p_num-1].control or t < ff):
# He has time to animate...
# Best so far!
										special_move = TRUE
										if strike_option or not user_controlled:
											strike[6].t = i
											strike[6].free = t
											strike[6].atime = ft_dtm
											strike[6].gt = gt
											strike[6].x = x-cx
											strike[6].y = y-cy
											strike[6].stop = stop_and_face
											do_it = TRUE
							else:
								if z < PLAYER_HEIGHT+2:
# head level...
									if can_strike & 32:
										r = Actions.rotate_offs(MC_OVERHEAD, cx, cy, cz, x_face, y_face); cx = r[0]; cy = r[1]; cz = r[2]
										gt = get_there_time(p_num, x-cx, y-cy)
										t = int(i-(gt+ft_otm))
										if t >= 0 and t < strike[4].free and (teams[p_num-1].control or t < ff):
# He has time to animate...
# Best so far!
											special_move = TRUE
											if strike_option or not user_controlled:
												strike[4].t = i
												strike[4].free = t
												strike[4].atime = ft_otm
												strike[4].gt = gt
												strike[4].x = x-cx
												strike[4].y = y-cy
												strike[4].stop = stop_and_face
												do_it = TRUE

									if can_strike & 8:
# He has time...
										r = Actions.rotate_offs(MC_S_HEAD, cx, cy, cz, x_face, y_face); cx = r[0]; cy = r[1]; cz = r[2]
										gt = get_there_time(p_num, x-cx, y-cy)
										t = int(i-(gt+ft_stm))
										if t >= 0 and t < strike[9].free and (teams[p_num-1].control or t < ff):
# He has time to animate...
# Best so far!
											special_move = TRUE
											if strike_option or not user_controlled:
												strike[9].t = i
												strike[9].free = t
												strike[9].ptype = pass_type
												strike[9].pplr = receiver
												strike[9].atime = ft_stm
												strike[9].gt = gt
												strike[9].x = x-cx
												strike[9].y = y-cy
												strike[9].stop = stop_and_face
												do_it = TRUE
								else:
									if z < teams[p_num-1].tm_jump:
# Jump level...
										if can_strike & 16:
# He has time...
											r = Actions.rotate_offs(MC_J_HEAD, cx, cy, cz, x_face, y_face); cx = r[0]; cy = r[1]; cz = r[2]
											gt = get_there_time(p_num, x-cx, y-cy)
											t = int(i-(gt+ft_jtm))
											if ABS(cz+prat-z) < 8 and t >= 0 and t < strike[7].free and (teams[p_num-1].control or t < ff):
# He has time to animate...
# Best so far!
												special_move = TRUE
												if strike_option or not user_controlled:
													strike[7].t = i
													strike[7].free = t
													strike[7].ptype = pass_type
													strike[7].pplr = receiver
													strike[7].atime = ft_jtm
													strike[7].gt = gt
													strike[7].x = x-cx
													strike[7].y = y-cy
													strike[7].stop = stop_and_face
													do_it = TRUE
	return do_it
# #else
# (The non-EURO96 variant of can_i_intercept -- "No first-time passing..." -- INTELL.CPP
#  lines 2253-2651 is compiled out because EURO96 is defined; it is not ported.)
# #endif

#*******************************************************************************
#*****************************************************************************/

# void clear_strike()
static func clear_strike() -> void:
# Clear first time animation array...
	for i in range(0, 11):
		strike[i].t = 0			# Init start time.
		strike[i].free = 1000	# Init wait time.
		strike[i].ptype = 0
		strike[i].pplr = 0

#*******************************************************************************
#*****************************************************************************/

# void decide_on_face(match_player *p)
static func decide_on_face(p: match_player) -> void:
	var gx: float
	var gy: float
	var x: float
	var y: float
	var d: float
	if p.tm_player < 12:
# Team A...
		gx = 0		# His goal...
	else:
		gx = pitch_len		# His goal...

	gy = cntspot_y

	gx = gx-p.tm_x
	gy = gy-p.tm_y

	d = Maths.calc_dist(gx, gy)
	if d < prat*30:
# In Defense...

		if p.tm_player < 12:
			must_face_x = 1
		else:
			must_face_x = -1

		must_face = TRUE
	else:
# Not in defense...
		if p.tm_player < 12:
			gx = pitch_len
		else:
			gx = 0

		gx = gx-p.tm_x

		d = Maths.calc_dist(gx, gy)
		if d < (MIN_SHOOT_DIST+(float(p.tm_pow)*3)):
# In Shooting Range...
			must_face_x = gx/d
			must_face_y = gy/d
			must_face = TRUE

#*******************************************************************************
#*****************************************************************************/

# char go_to_path(int p_num)
# Send player(p_num) to intersection with ball path.
# If he cannot meet ball then best try!
static func go_to_path(p_num: int) -> int:
	var spd_up: float
	special_move = FALSE

	teams[p_num-1].tm_fpass_type = 0
	teams[p_num-1].tm_fpass_to = 0

	var x: float
	var y: float
	var z: float
	var px: float = teams[p_num-1].tm_x
	var py: float = teams[p_num-1].tm_y
	var i: int
	var do_it: int = FALSE

	first_time_it = TRUE

	clear_strike()

#** Capture Timings ***/
# Release Ball

	if user_controlled:
# Allow user to animate faster for responsiveness...
		spd_up = 1.3
	else:
		spd_up = 1

# Kick time...
	ft_ktm = MCC_SHOOT/(MC_SHOOT_FS*spd_up*fstep_factor(teams[p_num-1].tm_flair))

# Volley time...
	ft_vtm = MCC_VOLLEY/(MC_VOLLEY_FS*spd_up*fstep_factor(teams[p_num-1].tm_flair))

# Diving time...
	ft_dtm = MCC_DV_HEAD/(MC_DV_HEAD_FS*spd_up*fstep_factor(teams[p_num-1].tm_flair))

# Overhead time...
	ft_otm = MCC_OVERHEAD/(MC_OVERHEAD_FS*spd_up*fstep_factor(teams[p_num-1].tm_flair))

# Standing time...
	ft_stm = MCC_S_HEAD/(MC_S_HEAD_FS*spd_up*fstep_factor(teams[p_num-1].tm_flair))

# Jumping time...
	ft_jtm = MCC_J_HEAD/(MC_J_HEAD_FS*spd_up*fstep_factor(teams[p_num-1].tm_flair))
#		ft_jtm=MCC_J_HEAD/MC_J_HEAD_FS;

# Keep Ball

# Trapping time...
	ft_ttm = MCC_TRAP/(MC_TRAP_FS*spd_up*fstep_factor(teams[p_num-1].tm_cont))

# Chesting time...
	ft_ctm = MCC_CHEST/(MC_CHEST_FS*spd_up*fstep_factor(teams[p_num-1].tm_cont))

# Up head time...
	ft_utm = MCC_D_HEAD/(MC_D_HEAD_FS*spd_up*fstep_factor(teams[p_num-1].tm_cont))

	must_face = FALSE

	auto_select = FALSE

	if user_controlled:
		if um and (uf1 or uf2):
# User.. Directional control...
			must_face = TRUE		# Forced to face in a particular dir...
			must_face_x = ux
			must_face_y = uy
		else:
			if uf1 or uf2:
# User.. No directional control...
				decide_on_face(teams[p_num-1])
	else:
		if ((p_num < 12 and not auto_users_a) or p_num == KP_A
			or (p_num > 11 and not auto_users_b) or p_num == KP_B):
# Computer player will try to face goal or away from defense...
			auto_select = TRUE

			if p_num == receiver_a or p_num == receiver_b:
				decide_on_face(teams[p_num-1])
		else:
# Should be a user...
			auto_select = FALSE		# Don't allow computer to select a move!

	i = 1
	while i < 50:
		x = ball_pred_tab[i][0]
		y = ball_pred_tab[i][1]
		z = ball_pred_tab[i][2]

		ball_int_speed = int(ABS(x-ball_pred_tab[i-1][0]) \
						  +ABS(y-ball_pred_tab[i-1][1]) \
						  +(ABS(z-ball_pred_tab[i-1][2])*2))

		if (x < 0) or (x >= pitch_len) or (y < 0) or (y >= pitch_wid):
# Ball out of bounds
			x = ball_pred_tab[i-1][0]
			y = ball_pred_tab[i-1][1]
			i = 60
		else:
			do_it = u8(do_it+can_i_intercept(p_num, x, y, z, px, py, i))
		i += 2

	if do_it:
#
#		if ((p_num<12 && auto_users_a && !teams[p_num-1].control)
#			|| (p_num>11 && auto_users_b && !teams[p_num-1].control))
#		{
#			reselect();
#			user_conts(&teams[p_num-1]);
#			user_controlled=teams[p_num-1].control;
#		}
#
		intercept(p_num)

		if ball_poss:
			teams[p_num-1].ball_state = -ball_poss
		else:
			teams[p_num-1].ball_state = last_touch

	must_face = FALSE
	first_time_it = FALSE
	return do_it

#******************************************************************************
#*****************************************************************************/

# void ogo_to_path(int p_num,char header_only)
# Send player(p_num) to intersection with ball path.
# If he cannot meet ball then best try!
static func ogo_to_path(p_num: int, header_only: int) -> void:
	var x: float = 0.0
	var y: float = 0.0
	var z: float
	var d: float
	var px: float = teams[p_num-1].tm_x
	var py: float = teams[p_num-1].tm_y
	var rate: float = Actions.actual_spd(teams[p_num-1])
	action = "Intercept"

	reset_ideas(teams[p_num-1])

	if p_num < 12:
		interceptor_a = p_num
	else:
		interceptor_b = p_num

# His intention is to intercept ball.
# Therefore his flair determines no. of turns before rethink!

	var ff: int = 33-(teams[p_num-1].tm_flair/4)
	teams[p_num-1].int_move = I_INTERCEPT		# Intercept ball!
	teams[p_num-1].int_cnt = ff						# Flair factor.

	var feet_hit: int = FALSE
	var body_hit: int = FALSE
	var head_hit: int = FALSE

	var feet_x: float = 0.0
	var feet_y: float = 0.0
	var body_x: float = 0.0
	var body_y: float = 0.0
	var head_x: float = 0.0
	var head_y: float = 0.0

	var i: int = 1
	while i < 50:
		x = ball_pred_tab[i][0]
		y = ball_pred_tab[i][1]
		z = ball_pred_tab[i][2]

		if (x < 0) or (x >= pitch_len) or (y < 0) or (y >= pitch_wid):
# Ball out of bounds
			x = ball_pred_tab[i-1][0]
			y = ball_pred_tab[i-1][1]
			i = 60
		else:
			if z < PLAYER_HEIGHT/2:
				d = Maths.calc_dist(x-px, y-py)
				d = int((float(d))/rate)					#How many steps?

				if d <= i:
# He can get there in time!
# At feet...
					feet_x = x
					feet_y = y
					feet_hit = TRUE
					i = 60
			else:
				if (z <= PLAYER_HEIGHT-4) and (not body_hit):
					d = Maths.calc_dist(x-px, y-py)
					d = int((float(d))/rate)					#How many steps?

					if d <= i:
# He can get there in time!
# On body...
						body_x = x
						body_y = y
						body_hit = TRUE

#					init_run_act(&teams[p_num-1],x,y,TRUE);				//Go to path point!
#					i=60;												// End For Loop!
				else:
					if (z > PLAYER_HEIGHT-4) and (z <= teams[p_num-1].tm_jump) and (not head_hit):
						d = Maths.calc_dist(x-px, y-py)
						d = int((float(d))/rate)					#How many steps?

						if d+(sqrt(z-PLAYER_HEIGHT+5)/gravity) <= i:
# He can get there in time!
# On head...
							head_x = x
							head_y = y
							head_hit = TRUE

#						init_run_act(&teams[p_num-1],x,y,TRUE);				//Go to path point!
#						i=60;
		i += 1

	if (not feet_hit) and (not head_hit) and (not body_hit):
# He cant intersect!
		Actions.init_run_act(teams[p_num-1], x, y, TRUE)			# run toward last.
	else:
		if header_only:
			if head_hit:
				Actions.init_run_act(teams[p_num-1], head_x, head_y, TRUE)	#Go to path point!
		else:
			if feet_hit:
				Actions.init_run_act(teams[p_num-1], feet_x, feet_y, TRUE)	#pitch line point
			else:
				if head_hit:
					Actions.init_run_act(teams[p_num-1], head_x, head_y, TRUE)	#Go to path point!
				else:
					if body_hit:
						Actions.init_run_act(teams[p_num-1], body_x, body_y, TRUE)	#Go to path point!

#******************************************************************************
#*****************************************************************************/

# void get_tack_path(match_player *player)
# Find players intersection with ball path.
# When tackling!
static func get_tack_path(player: match_player) -> void:
	if teams[ball_poss-1].tm_poss > 4:
# Opponent has ball for a bit...

		flag = FALSE
		var x: float
		var y: float
		var z: float
		var d: float
		var s: float
		var px: float = player.tm_x
		var py: float = player.tm_y
		var rate: float = player.tm_rate+player.tm_pow
		var last_diff: float = 2000

		if (((ball_poss) and (teams[ball_poss-1].tm_act == STAND_ACT))
			or ((not ball_poss) and (ball_still))):

# Ball is not moving!
			if plr_facing(ballx, bally, player):
				Actions.init_tackle_act(player, ballx, bally)				#Go to path point!
			else:
				go_to_path(player.tm_player)
		else:

			var i: int = 1
			while i < TACKLE_TURNS/2:
				x = ball_pred_tab[i][0]
				y = ball_pred_tab[i][1]
				z = ball_pred_tab[i][2]

				if (x < 0) or (x >= pitch_len) or (y < 0) or (y >= pitch_wid):
# Ball out of bounds (So don't tackle!)
					i = 60

				if z <= PLAYER_HEIGHT/2:
# Tackling player is half height.
					d = Maths.calc_dist(x-px, y-py)

# Now the tricky bit...
# Using S=a(1-r^n)/(1-r) (S=tackle distance over time (n))
# a=(rate/8), r=tackle_decel...

					s = (rate/20)*(1-pow(TACKLE_DECEL, i))/(1-TACKLE_DECEL)	#How far in time (i)!

					if d-s > last_diff:
# Ball getting further away!
						i = 60												# End For Loop!
					else:
						last_diff = d-s

					if last_diff <= 0:
# He can get there in time!

# Take accuracy into account...

						var acc_xoff: float = (seed*(128-player.tm_ac)/4)/128
						Maths.af_randomize()
						var acc_yoff: float = (seed*(128-player.tm_ac)/4)/128
						if seed & 32:
							acc_xoff = -acc_xoff
						if seed & 16:
							acc_yoff = -acc_yoff
						if player.tm_player != KP_A and player.tm_player != KP_B:
#							init_tackle_act(player,x+acc_xoff,y+acc_yoff);				//Go to path point!
							Actions.init_tackle_act(player, x, y)
						else:
# Keeper more accurate to provide better defense...
							Actions.init_tackle_act(player, x, y)
						flag = TRUE
						i = 60												# End For Loop!
				i += 1

#******************************************************************************
#*****************************************************************************/

# void set_there_flags(short taker)
static func set_there_flags(taker: int) -> void:
	var cond: bool
	if EURO96:
		cond = ((teams[taker-1].tm_act == STAND_ACT and plr_facing(ballx-teams[taker-1].tm_x, bally-teams[taker-1].tm_y, teams[taker-1]))
			and (teams[taker-1].tm_dist < BESIDE_BALL*3
			or ((match_mode == PEN_KICK_A or match_mode == PEN_KICK_B) and teams[taker-1].tm_dist < (PEN_RUNUP_DIST+4))))
	else:
		cond = ((teams[taker-1].tm_act == STAND_ACT and plr_facing(ballx-teams[taker-1].tm_x, bally-teams[taker-1].tm_y, teams[taker-1]))
			and (teams[taker-1].tm_dist < BESIDE_BALL*3))
	if cond:
		if not already_there:
			reselection = TRUE
			already_there = TRUE

#******************************************************************************
#*****************************************************************************/

# void centre_pos(char flag,int pn,char &flag2,float &x,float &y)   -> returns [flag2, x, y]
static func centre_pos(flag: int, pn: int, flag2: int, x: float, y: float) -> Array:
# Taking centre!
	if true:
		if (((pn+1 == centre_guy_1) and (flag == 1))
			or ((pn+1 == centre_guy_1-11) and (flag == 2))):
			x = cntspot_x
			y = cntspot_y-10
			flag2 = TRUE
			set_there_flags(centre_guy_1)

		if (((pn+1 == centre_guy_2) and (flag == 1))
			or ((pn+1 == centre_guy_2-11) and (flag == 2))):
			if flag == 1:
				x = cntspot_x+5
			else:
				x = cntspot_x-5			# Receiver stands over line...

			y = cntspot_y+10
			flag2 = TRUE
	return [flag2, x, y]

#******************************************************************************
#*****************************************************************************/

# void gkick_pos(char flag,int pn,char &flag2,float &x,float &y,char &taker)   -> returns [flag2, x, y, taker]
static func gkick_pos(flag: int, pn: int, flag2: int, x: float, y: float, taker: int) -> Array:
# Taking Goal kick!
	if true:
		if (((pn+1 == gkick_taker) and (flag == 1))
			or ((pn+1 == gkick_taker-11) and (flag == 2))):
			x = taker_x
			y = taker_y

			taker = TRUE

			flag2 = TRUE
			if flag == 2:
				x = pitch_len-x
				y = pitch_wid-y

			set_there_flags(gkick_taker)
	return [flag2, x, y, taker]

#******************************************************************************
#*****************************************************************************/

# void corner_pos(char flag,int pn,char &flag2,float &x,float &y,char &taker)   -> returns [flag2, x, y, taker]
static func corner_pos(flag: int, pn: int, flag2: int, x: float, y: float, taker: int) -> Array:
# Taking Corner!
	if true:
		if (((pn+1 == corner_taker) and (flag == 1))
			or ((pn+1 == corner_taker-11) and (flag == 2))):
			x = incident_x
			y = incident_y
			taker = TRUE

			flag2 = TRUE
			if flag == 2:
				x = pitch_len-x
				y = pitch_wid-y
			set_there_flags(corner_taker)
	return [flag2, x, y, taker]

#******************************************************************************
#*****************************************************************************/

# void throw_in_pos(char flag,int pn,char &flag2,float &x,float &y,char &taker)   -> returns [flag2, x, y, taker]
static func throw_in_pos(flag: int, pn: int, flag2: int, x: float, y: float, taker: int) -> Array:
# Taking throw!
	if true:
		if flag == 2:
			pn = pn+11

		if pn+1 == throw_in_taker:
			x = incident_x
			y = incident_y+(-8 if (incident_y < cntspot_y) else 8)
			taker = TRUE

			flag2 = TRUE
			if flag == 2:
				x = pitch_len-x
				y = pitch_wid-y
			set_there_flags(throw_in_taker)
	return [flag2, x, y, taker]

#******************************************************************************
#*****************************************************************************/

# void dfkick_pos(char flag,int pn,char &flag2,float &x,float &y,char &taker)   -> returns [flag2, x, y, taker]
static func dfkick_pos(flag: int, pn: int, flag2: int, x: float, y: float, taker: int) -> Array:
# Taking F.K.!
	if true:
		if flag == 2:
			pn = pn+11

		if pn+1 == fkick_taker:
			x = taker_x
			y = taker_y
			taker = TRUE
			flag2 = TRUE
			if flag == 2:
				x = pitch_len-x
				y = pitch_wid-y

			set_there_flags(fkick_taker)
		else:
			if teams[pn].tm_wall:
				var i: int = 0
				while i < men_in_wall:
					if wguys[i].guy == pn+1:
						x = wguys[i].x
						y = wguys[i].y
						flag2 = TRUE
						i = men_in_wall
						if flag == 2:
							x = pitch_len-x
							y = pitch_wid-y
					i += 1
	return [flag2, x, y, taker]

#******************************************************************************
#*****************************************************************************/

# void fkick_pos(char flag,int pn,char &flag2,float &x,float &y,char &taker)   -> returns [flag2, x, y, taker]
static func fkick_pos(flag: int, pn: int, flag2: int, x: float, y: float, taker: int) -> Array:
# Taking F.K.!
	if true:
		if flag == 2:
			pn = pn+11

		if pn+1 == fkick_taker:
			x = taker_x
			y = taker_y
			taker = TRUE
			flag2 = TRUE
			if flag == 2:
				x = pitch_len-x
				y = pitch_wid-y
			set_there_flags(fkick_taker)
	return [flag2, x, y, taker]

#******************************************************************************
#*****************************************************************************/

# void penalty_pos(char flag,int pn,char &flag2,float &x,float &y,char &taker)   -> returns [flag2, x, y, taker]
static func penalty_pos(flag: int, pn: int, flag2: int, x: float, y: float, taker: int) -> Array:
# Taking F.K.!
	if true:
		if flag == 2:
			pn = pn+11

		if pn+1 == penalty_taker:
			x = taker_x
			y = taker_y
			taker = TRUE
			flag2 = TRUE
			if flag == 2:
				x = pitch_len-x
				y = pitch_wid-y

			set_there_flags(penalty_taker)
	return [flag2, x, y, taker]

#******************************************************************************
#*****************************************************************************/

# void tunnel_pos(char flag,int pn,float &x,float &y)   -> returns [x, y]
static func tunnel_pos(flag: int, pn: int, x: float, y: float) -> Array:
	var tx: float = stadlist[setup.stadium].tunlx
	var ty: float = -stadlist[setup.stadium].tunlz
	var tz: float = stadlist[setup.stadium].tunly
	var d: float = GO_TO_POS_DIST

	if flag == 2:
# Team B...
		pn += 11
		if (ABS(teams[pn].go_ty-ty) < prat or
			(teams[pn].tm_x >= (tx+prat-d) and teams[pn].tm_x <= (tx+prat+d))):
# In line with tunnel...
			x = pitch_len-(tx+prat)
			y = pitch_wid-(ty)

			if ABS(teams[pn].tm_y-(pitch_wid-y)) < prat*2:
# At end of tunnel...(don't draw him!)
				teams[pn].draw_me = FALSE
		else:
			x = pitch_len-(tx+prat)
			if ty > cntspot_y:
# Which goal-line...
				y = 0
			else:
				y = pitch_wid
	else:
# Team A...
		if (ABS(teams[pn].go_ty-ty) < prat or
			(teams[pn].tm_x >= (tx-prat-d) and teams[pn].tm_x <= (tx-prat+d))):
# In line with tunnel...
			x = tx-prat
			y = ty

			if ABS(teams[pn].tm_y-y) < prat*2:
# At end of tunnel...(don't draw him!)
				teams[pn].draw_me = FALSE
		else:
			x = tx-prat
			if ty > cntspot_y:
# Which goal-line...
				y = pitch_wid
			else:
				y = 0
	set_there_flags(pn+1)
	return [x, y]

#******************************************************************************
#*****************************************************************************/

# int get_tac(int *t)
# (the pointer parameter only reads *t: the value is passed instead)
static func get_tac(t: int) -> int:
#	(*t)++;
#	(*t)--;
	return t

#******************************************************************************
#*****************************************************************************/

# void get_target(char flag,int bz,int zx,int zy,int pn,float &x,float &y,int tac[(32*2)+6][10][2])   -> returns [x, y]
static func get_target(flag: int, bz: int, zx: int, zy: int, pn: int, x: float, y: float, tac: Array) -> Array:
	var ox: float
	var oy: float
	var flag2: int = FALSE
	var taker: int = FALSE
	var r: Array

	if dead_ball_cnt:
		if match_mode == SWAP_ENDS:

# Into tunnel...

			r = tunnel_pos(flag, pn, x, y); x = r[0]; y = r[1]
			flag2 = TRUE

		if (((match_mode == CENTRE_A) and (flag == 1))
			or ((match_mode == CENTRE_B) and (flag == 2))):

# Centre takers...

			r = centre_pos(flag, pn, flag2, x, y); flag2 = r[0]; x = r[1]; y = r[2]

		# (C operator precedence kept: A || (B && f==1) ...)
		if (((match_mode == GOAL_KICK_TL) or ((match_mode == GOAL_KICK_BL) and (flag == 1)))
			or ((match_mode == GOAL_KICK_TR) or ((match_mode == GOAL_KICK_BR) and (flag == 2)))):

# Goal kick takers...

			r = gkick_pos(flag, pn, flag2, x, y, taker); flag2 = r[0]; x = r[1]; y = r[2]; taker = r[3]

		if (((match_mode == CORNER_TL) or ((match_mode == CORNER_BL) and (flag == 2)))
			or ((match_mode == CORNER_TR) or ((match_mode == CORNER_BR) and (flag == 1)))):

# Corner takers...

			r = corner_pos(flag, pn, flag2, x, y, taker); flag2 = r[0]; x = r[1]; y = r[2]; taker = r[3]

		if (match_mode == THROW_IN_A) or (match_mode == THROW_IN_B):

# Throw-in taker...

			r = throw_in_pos(flag, pn, flag2, x, y, taker); flag2 = r[0]; x = r[1]; y = r[2]; taker = r[3]

		if (match_mode == DF_KICK_A) or (match_mode == DF_KICK_B):

# Direct F.K....

			r = dfkick_pos(flag, pn, flag2, x, y, taker); flag2 = r[0]; x = r[1]; y = r[2]; taker = r[3]

		if (match_mode == IF_KICK_A) or (match_mode == IF_KICK_B):

# In-direct F.K....

			r = fkick_pos(flag, pn, flag2, x, y, taker); flag2 = r[0]; x = r[1]; y = r[2]; taker = r[3]

		if (match_mode == PEN_KICK_A) or (match_mode == PEN_KICK_B):

# Penalty Kick....

			r = penalty_pos(flag, pn, flag2, x, y, taker); flag2 = r[0]; x = r[1]; y = r[2]; taker = r[3]

	if not flag2:
#**************************/
# Normal match play!
		if (man2man_b) and (flag == 2) and (teams[pn+11].tm_mark):
# Team B defends man-to-man...
			x = pitch_len-man2man[pn-1][0]
			y = pitch_wid-man2man[pn-1][1]
		else:
			if (man2man_a) and (flag == 1) and (teams[pn].tm_mark):
# Team A defends man-to-man...
				x = man2man[pn-1][0]
				y = man2man[pn-1][1]
			else:
# Normal Zonal Position...
				x = get_tac(tac[bz][pn-1][0])
				y = get_tac(tac[bz][pn-1][1])

				if flag == 1 and bz == 68 and pn == centre_guy_2-1:
					x = cntspot_x+80
					y = cntspot_y+10
					flag = 0

				if flag == 2 and bz == 69 and pn == centre_guy_2-12:
					x = cntspot_x-80
					y = cntspot_y+10
					flag = 0

				if flag:
					var bx: float = LIMIT(ballx, 0, pitch_len)
					var by: float = LIMIT(bally, 0, pitch_wid)

					if ((analogue) and (not ball_out_of_play) and
						((not dead_ball_cnt) or (match_mode < CORNER_TL) or (match_mode > THROW_IN_B))):
						if flag == 1:
							ox = bx-zx	# offset from centre of zone!
							oy = by-zy
						else:
							ox = (pitch_len-bx)-zx	# offset from centre of zone!
							oy = (pitch_wid-by)-zy

						var xa: float
						var xb: float
						var xc: float
						var ya: float
						var yb: float
						var yc: float

						if ox <= 0:
							var b: int = bz-1
							if b < 0:
								b = 0

							xa = get_tac(tac[b][pn-1][0])					#left zone
							ya = get_tac(tac[b][pn-1][1])					#left zone

							if oy <= 0:
								b = bz-8-1
								if b < 0:
									b = 0
								xb = get_tac(tac[b][pn-1][0])			#top left zone
								yb = get_tac(tac[b][pn-1][1])			#top left zone
								xc = get_tac(tac[b+1][pn-1][0])				#top zone
								yc = get_tac(tac[b+1][pn-1][1])				#top zone
							else:
								b = bz+8
								if b > 31:
									b = 31
								xb = get_tac(tac[b-1][pn-1][0])			#bot left zone
								yb = get_tac(tac[b-1][pn-1][1])			#bot left zone
								xc = get_tac(tac[b][pn-1][0])				#bot zone
								yc = get_tac(tac[b][pn-1][1])				#bot zone
						else:
							var b: int = bz+1
							if b > 31:
								b = 31
							xa = get_tac(tac[b][pn-1][0])					#right zone
							ya = get_tac(tac[b][pn-1][1])					#right zone

							if oy <= 0:
								b = bz-8
								if b < 0:
									b = 0
								xb = get_tac(tac[b+1][pn-1][0])			#top right zone
								yb = get_tac(tac[b+1][pn-1][1])			#top right zone
								xc = get_tac(tac[b][pn-1][0])				#top zone
								yc = get_tac(tac[b][pn-1][1])				#top zone
							else:
								b = bz+8+1
								if b > 31:
									b = 31
								xb = get_tac(tac[b][pn-1][0])			#bot right zone
								yb = get_tac(tac[b][pn-1][1])			#bot right zone
								xc = get_tac(tac[b-1][pn-1][0])				#bot zone
								yc = get_tac(tac[b-1][pn-1][1])				#bot zone

						var xint_ab: float = xa+((xb-xa)*ABS(oy)/zone_hgt)
						var xint_hc: float = x+((xc-x)*ABS(oy)/zone_hgt)

						var yint_cb: float = yc+((yb-yc)*ABS(ox)/zone_wid)
						var yint_ha: float = y+((ya-y)*ABS(ox)/zone_wid)

						x = xint_hc+((xint_ab-xint_hc)*ABS(ox)/zone_wid)
						y = yint_ha+((yint_cb-yint_ha)*ABS(oy)/zone_hgt)

		# (C: xoff/yoff are left uninitialised when flag==0)
		var xoff: float = 0.0
		var yoff: float = 0.0
		if flag:
			if flag == 1:
				xoff = x-incident_x
				yoff = y-incident_y
			else:
				xoff = (pitch_len-x)-incident_x
				yoff = (pitch_wid-y)-incident_y

		var dist: float
		match game_action:
# Team A and B must be 10 yards away from ball!
			-1, 1:
				dist = Maths.calc_dist(xoff, yoff)
				if dist < prat*10:
					if flag == 1:
						x = incident_x+(xoff*(INCIDENT_DIST)/dist)
						y = incident_y+(yoff*(INCIDENT_DIST)/dist)
					else:
						x = pitch_len-(incident_x+(xoff*(INCIDENT_DIST)/dist))
						y = pitch_wid-(incident_y+(yoff*(INCIDENT_DIST)/dist))

# Team A and B must be 10 yards away from ball and outside penalty box!
			2:
				if ballx < cntspot_x:
					if flag == 1:
						x = prat*19
					else:
						x = pitch_len-(prat*19)
				else:
					if flag == 1:
						x = pitch_len-(prat*19)		# On edge of 18 yard box!
					else:
						x = prat*19

				if flag == 1:
					xoff = x-incident_x
					yoff = y-incident_y
				else:
					xoff = (pitch_len-x)-incident_x
					yoff = (pitch_wid-y)-incident_y

				dist = Maths.calc_dist(xoff, yoff)
				if dist < prat*10:
					if flag == 1:
						x = incident_x+(xoff*(INCIDENT_DIST)/dist)
						y = incident_y+(yoff*(INCIDENT_DIST)/dist)
					else:
						x = pitch_len-(incident_x+(xoff*(INCIDENT_DIST)/dist))
						y = pitch_wid-(incident_y+(yoff*(INCIDENT_DIST)/dist))
	return [x, y]

#******************************************************************************
#*****************************************************************************/

# void find_zonal_target(match_player *player,float px,float py)
static func find_zonal_target(player: match_player, px: float, py: float) -> void:
	if not player.draw_me and player.tm_y > 0 and player.tm_y < pitch_wid:
		player.draw_me = TRUE

	# (C: ball_zn is uninitialised in the keeper's SWAP_ENDS call)
	var ball_zn: int = 0
	var f: int
	var tx: float = 0.0
	var ty: float = 0.0
	var sx: float
	var sy: float
	var r: Array
	if (player.tm_player == KP_A) or (player.tm_player == KP_B):

#****************
#** Goal-Keeper	**
#****************/

		if player.tm_player == KP_A:
			if ((dead_ball_cnt) and (gkick_taker == KP_A) and
				((match_mode == GOAL_KICK_TL) or (match_mode == GOAL_KICK_BL))):
# Taking Goal Kick!
				tx = taker_x
				ty = taker_y
				set_there_flags(gkick_taker)
			else:
				if match_mode == DF_KICK_B and men_in_wall > 2:
# Get keeper in position behind last man in wall...
					tx = keeper_pos_x
					ty = keeper_pos_y
				else:
					if match_mode == SWAP_ENDS:
						r = get_target(1, ball_zn, zone1_x, zone1_y, (player.tm_player)-1, tx, ty, match_tactics1); tx = r[0]; ty = r[1]
					else:
						if ball_poss >= 12 and match_mode != PEN_KICK_B and not penalty_shot:
# Opponent_has ball...
							var d: float = Maths.calc_dist(ballx, bally-cntspot_y)		# distance of centre of goal to ball!
							if (keeper_a_in_box) and (d < CLOSE_ANG_DIST+(prat*player.tm_vis)/8):
# Shut the door...
								r = close_angle(player, d, tx, ty); tx = r[0]; ty = r[1]			# Close down the angle of shot.
							else:
								tx = KP_OFFLINE
								ty = cntspot_y-1
						else:
							if match_mode == PEN_KICK_B:
								tx = 0
							else:
								if shot_pending and penalty_shot:
									tx = 0
								else:
									tx = KP_OFFLINE

							ty = cntspot_y-1
		else:
			if ((dead_ball_cnt) and (gkick_taker == KP_B) and
				((match_mode == GOAL_KICK_TR) or (match_mode == GOAL_KICK_BR))):
# Taking Goal Kick!
				tx = taker_x
				ty = taker_y
				set_there_flags(gkick_taker)
			else:
				if match_mode == DF_KICK_A and men_in_wall > 2:
# Get keeper in position behind last man in wall...
					tx = keeper_pos_x
					ty = keeper_pos_y
				else:
					if match_mode == SWAP_ENDS:
						r = get_target(2, ball_zn, zone2_x, zone2_y, (player.tm_player)-12, tx, ty, match_tactics2); tx = r[0]; ty = r[1]
						tx = pitch_len-tx
						ty = pitch_wid-ty
					else:
						if ball_poss and ball_poss < 12 and match_mode != PEN_KICK_A and not penalty_shot:
# Opponent_has ball...
							var d: float = Maths.calc_dist(pitch_len-ballx, bally-cntspot_y)		# distance of centre of goal to ball!
							if (keeper_b_in_box) and (d < CLOSE_ANG_DIST+(prat*player.tm_vis)/8):
# Shut the door...
								r = close_angle(player, d, tx, ty); tx = r[0]; ty = r[1]			# Close down the angle of shot.
							else:
								tx = pitch_len-KP_OFFLINE
								ty = cntspot_y-1
						else:
							if match_mode == PEN_KICK_A:
								tx = pitch_len-1
							else:
								if shot_pending and penalty_shot:
									tx = pitch_len-1
								else:
									tx = pitch_len-KP_OFFLINE

							ty = cntspot_y-1

		tx = tx-px
		ty = ty-py
		var s: int
		var d: float = Maths.calc_dist(tx, ty)
		if ((player.face_dir != get_dir(tx, ty)) and
			(((player.go_step) and (d < STEP_RANGE*2))
			or ((not player.go_step) and (d < STEP_RANGE)))):
# Calculate single move.
			s = TRUE
			if player.tm_rate >= d*32:
				sx = tx
				sy = ty
			else:
				sx = (player.tm_rate/(d*32))*tx
				sy = (player.tm_rate/(d*32))*ty
		else:
# Calculate single move.
			if player.tm_rate >= d*16:
				sx = tx
				sy = ty
			else:
				sx = (player.tm_rate/(d*16))*tx
				sy = (player.tm_rate/(d*16))*ty

		Actions.init_run_act(player, tx+px, ty+py, TRUE)
		if player.tm_act == RUN_ACT:
			Actions.go_forward(player)
			player.go_cnt = 0
	else:

#***********
#** PLAYER **
#***********/

		if not player.int_cnt:
			if player.tm_player < 12:			# Team A?
				if (ball_zone1 < 32) and (last_touch < 12) and (last_touch != 0):	# Team A. in possession?
					ball_zn = 32
				else:
					ball_zn = 0
				ball_zn += ball_zone1
				r = get_target(1, ball_zn, zone1_x, zone1_y, (player.tm_player)-1, tx, ty, match_tactics1); tx = r[0]; ty = r[1]

				tx = tx-px
				ty = ty-py
				var d: float = Maths.calc_dist(tx, ty)
				if ((player.tm_act == RUN_ACT) or
					(d > GO_TO_POS_DIST and player.tm_act != RUN_ACT)):
					var s: int
					# (C: inner "float d" shadows the outer d -> renamed d2)
					var d2: float = Maths.calc_dist(tx, ty)
					if ((player.face_dir != get_dir(tx, ty)) and
						(((player.go_step) and (d2 < STEP_RANGE*2))
						or ((not player.go_step) and (d2 < STEP_RANGE)))):

						s = TRUE
					else:
						s = FALSE

					Actions.init_run_act(player, tx+px, ty+py, TRUE)
					if player.tm_act == RUN_ACT:
						Actions.go_forward(player)
						player.go_cnt = 0
				else:
# There already!
					if player.int_move == I_THROW:
						player.int_cnt = 1
						reset_ideas(player)
			else:
				if (ball_zone2 < 32) and last_touch > 11:								# Team B. in possession?
					ball_zn = 32
				else:
					ball_zn = 0
				ball_zn += ball_zone2
				r = get_target(2, ball_zn, zone2_x, zone2_y, (player.tm_player)-12, tx, ty, match_tactics2); tx = r[0]; ty = r[1]
				tx = (pitch_len-tx)-px
				ty = (pitch_wid-ty)-py
				var d: float = Maths.calc_dist(tx, ty)
				if ((player.tm_act == RUN_ACT) or
					(d > GO_TO_POS_DIST and player.tm_act != RUN_ACT)):
					var s: int
					# (C: inner "float d" shadows the outer d -> renamed d2)
					var d2: float = Maths.calc_dist(tx, ty)

					# (C precedence kept: (a && (b && c)) || (d && e))
					if (((player.face_dir != get_dir(tx, ty)) and
						((player.go_step) and (d2 < STEP_RANGE*2)))
						or ((not player.go_step) and (d2 < STEP_RANGE))):

# Calculate single move.
						s = TRUE
					else:
						s = FALSE
					Actions.init_run_act(player, tx+px, ty+py, TRUE)
					if player.tm_act == RUN_ACT:
						Actions.go_forward(player)
						player.go_cnt = 0
				else:
# There already!
					if player.int_move == I_THROW:
						player.int_cnt = 1
						reset_ideas(player)

#******************************************************************************
#*****************************************************************************/

# Return closest guy to the predicted path of ball who is not busy!
# p_num = first player in team.

# int get_near_path(int p_num,int not_busy)
static func get_near_path(p_num: int, not_busy: int) -> int:
	var near_guy: int = 0
	var closest: int = 10000
	var t: int = 0

# Get average position of ball...

	var x1: float = ball_pred_tab[t][0]
	var y1: float = ball_pred_tab[t][1]
	var z1: float = ball_pred_tab[t][2]

	var px: float
	var py: float
	var points: int = 0
	var x: float = -1000
	var y: float = 0
	var z: float = 0
	var d: float

	for b in range(1, 40):
		if x < -999 and ball_pred_tab[b][2] < PLAYER_HEIGHT+4:
			x = ball_pred_tab[b][0]-x1
			y = ball_pred_tab[b][1]-y1
		else:
			if x > -999:
				x += ball_pred_tab[b][0]-x1
				y += ball_pred_tab[b][1]-y1
				points += 1

	if points:
		x = x/points
		y = y/points
		x += x1
		y += y1
	else:
		x = ball_pred_tab[40][0]
		y = ball_pred_tab[40][1]

	for i in range(p_num+10, p_num-1, -1):
		if teams[i].tm_notme:
			teams[i].tm_notme = u8(teams[i].tm_notme-1)		# he can't get there!
		else:
			if ((teams[i].tm_act <= TURN_ACT or (teams[i].tm_act == TACKLE_ACT and teams[i].control))
				and ball_poss != p_num+1):		#player is not busy!
				if (not (teams[i].int_cnt)) or (not_busy):
					px = teams[i].tm_x
					py = teams[i].tm_y

					d = Maths.calc_dist(px-x, py-y)

					if i == (KP_A-1) or i == (KP_B-1):
# Keeper only intercept if half as close as defender!

						if d*2 < closest and closest > prat*2:
							near_guy = i+1						#This guy is closer!
							closest = int(d)
					else:
						if d < closest:
							near_guy = i+1						#This guy is closer!
							closest = int(d)
	return near_guy

#******************************************************************************
#*****************************************************************************/

# Return closest guy to the predicted path of ball who is not busy!
# p_num = first player in team.

# int oget_near_path(int p_num,int not_busy)
static func oget_near_path(p_num: int, not_busy: int) -> int:
	var near_guy: int = 0
	var closest: int = 10000
	var t: int = first_bounce
	if t < 0:
		t = 0

# Get average position of ball...

	var x1: float = ball_pred_tab[t][0]
	var y1: float = ball_pred_tab[t][1]
	var z1: float = ball_pred_tab[t][2]

	var px: float
	var py: float
	var points: int = 0
	var x: float = 0
	var y: float = 0
	var z: float = 0
	var d: float

	for b in range(t+1, 40):
		if ball_pred_tab[b][2] < PLAYER_HEIGHT+4:
			x += ball_pred_tab[b][0]-x1
			y += ball_pred_tab[b][1]-y1
			points += 1

	if points:
		x = x/points
		y = y/points
		x += x1
		y += y1
	else:
		x = ball_pred_tab[40][0]
		y = ball_pred_tab[40][1]

	for i in range(p_num+10, p_num-1, -1):
		if teams[i].tm_notme:
			teams[i].tm_notme = u8(teams[i].tm_notme-1)		# he can't get there!
		else:

			if teams[i].tm_act <= TURN_ACT and ball_poss != p_num+1:		#player is not busy!
				if (not (teams[i].int_cnt)) or (not_busy):
					px = teams[i].tm_x
					py = teams[i].tm_y

					d = Maths.calc_dist(px-x, py-y)

					if i == (KP_A-1) or i == (KP_B-1):
# Keeper only intercept if half as close as defender!

						if d*2 < closest and closest > prat*2:
							near_guy = i+1						#This guy is closer!
							closest = int(d)
					else:
						if d < closest:
							near_guy = i+1						#This guy is closer!
							closest = int(d)
	return near_guy
