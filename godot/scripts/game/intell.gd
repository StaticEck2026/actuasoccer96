# Port of SOURCE/INTELL.CPP  (assembled by tools/assemble.py - edit the files in parts/)
class_name Intell extends Glob
# ---- part a ----
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

# ---- part b ----
# ---- INTELL.CPP lines 4154-end (part b) ----

#/******************************************************************************
#*****************************************************************************/

# void forward_joystick(match_player *p,float &x,float &y)
# (reference params x,y -> returns [x, y])
@warning_ignore("integer_division")
static func forward_joystick(p: match_player, x: float, y: float) -> Array:
	x = p.go_txdis
	y = p.go_tydis

	if ux:
		# Turn!
		var ta: float = (PI / 12) * ux
		var nx: float = x * cos(ta) - y * sin(ta)
		var ny: float = y * cos(ta) + x * sin(ta)
		x = nx
		y = ny
	return [x, y]

#/******************************************************************************
# *****************************************************************************/

# void get_face_xy(int d,float &x,float &y)
# (reference params x,y -> returns [x, y])
@warning_ignore("integer_division")
static func get_face_xy(d: int, x: float, y: float) -> Array:
	match d:
		0:
			x = -UNIT
			y = 0
		1:
			x = -DIAG
			y = DIAG
		2:
			x = 0
			y = UNIT
		3:
			x = DIAG
			y = DIAG
		4:
			x = UNIT
			y = 0
		5:
			x = DIAG
			y = -DIAG
		6:
			x = 0
			y = -UNIT
		7:
			x = -DIAG
			y = -DIAG
	return [x, y]

#/******************************************************************************
#*****************************************************************************/

# int get_dir(float x,float y)
@warning_ignore("integer_division")
static func get_dir(x: float, y: float) -> int:
	var d: int = 0
	if y >= 0:
		if x >= 0:
			if x > y:
				if x > (y * 2):
					d = 4
				else:
					d = 3
			else:
				if y > (x * 2):
					d = 2
				else:
					d = 3
		else:
			if -x > y:
				if -x > (y * 2):
					d = 0
				else:
					d = 1
			else:
				if y > (-x * 2):
					d = 2
				else:
					d = 1
	else:
		if x >= 0:
			if x > -y:
				if x > (-y * 2):
					d = 4
				else:
					d = 5
			else:
				if -y > (x * 2):
					d = 6
				else:
					d = 5
		else:
			if -x > -y:
				if -x > (-y * 2):
					d = 0
				else:
					d = 7
			else:
				if -y > (-x * 2):
					d = 6
				else:
					d = 7
	return d

#/******************************************************************************
#*****************************************************************************/

# int angle_of_vis(match_player *player,int x,int y,float d,char cross=FALSE)
@warning_ignore("integer_division")
static func angle_of_vis(player: match_player, x: int, y: int, d: float, cross: int = FALSE) -> int:
	var a: float
	var xd: float = player.tm_xdis
	var yd: float = player.tm_ydis
	var d2: float = Maths.calc_dist(xd, yd)
	xd = xd / d2
	yd = yd / d2
	if cross:
		if player.tm_player < 12:
			#	Team A...
			if (d / 2 > (MIN_PASS_DIST + float(player.tm_pow) / 3.6)) and (x + player.tm_x > pitch_len - (prat * 18)):
				return TRUE
			else:
				return FALSE
		else:
			#	Team B...
			if (d / 2 > (MIN_PASS_DIST + float(player.tm_pow) / 3.6)) and (x + player.tm_x < (prat * 18)):
				return TRUE
			else:
				return FALSE
	if set_piece_on:
		a = ((x * setp_kick_x) + (y * setp_kick_y)) / d		# Joystick dir.
	else:
		a = ((x * xd) + (y * yd)) / d		# facing...

	if a >= DIAG:
		return TRUE
	else:
		return FALSE

#/******************************************************************************
#*****************************************************************************/

# Creates table of opponents round player within DRIB_DANGER_AREA.

# void get_opp_dir_tab(int pnum)
@warning_ignore("integer_division")
static func get_opp_dir_tab(pnum: int) -> void:
	var dist: float = DRIB_DANGER_AREA + (prat * (((128 - teams[pnum - 1].tm_flair) / 12) - 5))
	drib_opps = 0
	var op: int = 1
	if pnum < 12:
		op = 12
	var x: float
	var y: float
	var d: float
	var dif: float

	for p in range(op, op + 11):
		# Vectors for opp. to ball...

		x = (teams[p - 1].tm_x - ballx) / teams[p - 1].tm_dist
		y = (teams[p - 1].tm_y - bally) / teams[p - 1].tm_dist

		# Calculate difference range of 2(ahead) to 0(behind)...
		dif = 1 + ((teams[pnum - 1].tm_xdis * x) + (teams[pnum - 1].tm_ydis * y))
		d = dist / 4 + (dist * dif * 3 / 8)

		if teams[p - 1].guy_on and teams[p - 1].tm_dist <= d and teams[p - 1].tm_act < TURN_ACT:
			#			if (!(teams[p-1].tm_act==TACKLE_ACT && ((teams[p-1].go_txdis*teams[p-1].go_tydis)<4)))
			opp_dir_tab[drib_opps][0] = teams[p - 1].tm_x
			opp_dir_tab[drib_opps][1] = teams[p - 1].tm_y
			opp_dir_tab[drib_opps][2] = 1 - (teams[pnum - 1].tm_dist / d)	# Attack potential
			drib_opps += 1

#/******************************************************************************
#*****************************************************************************/

# Count the number of opponents around player (pnum)!

# int opp_around(int x,int y,int pnum)
@warning_ignore("integer_division")
static func opp_around(x: int, y: int, pnum: int) -> int:
	var op: int = 1
	var d: int
	var opponents: int = 0
	if pnum < 12:
		op = 12
	for p in range(op, op + 11):
		if teams[p - 1].guy_on:
			d = int(Maths.calc_dist(teams[p - 1].tm_x - x, teams[p - 1].tm_y - y))
			if ball_poss == KP_A or ball_poss == KP_B:
				if d <= (DANGER_AREA * 1.6):
					opponents += 1
			else:
				if d <= DANGER_AREA:
					opponents += 1
	return opponents

#/******************************************************************************
#*****************************************************************************/

# Count the number of opponents around player (pnum)!

# This function specific to keeper passing out...

# int kopp_around(int x,int y,int pnum)
@warning_ignore("integer_division")
static func kopp_around(x: int, y: int, pnum: int) -> int:
	var op: int = 1
	var d: int
	var opponents: int = 0
	if pnum < 12:
		op = 12
	for p in range(op, op + 11):
		if teams[p - 1].guy_on:
			d = int(Maths.calc_dist(teams[p - 1].tm_x - x, teams[p - 1].tm_y - y))
			if d <= (DANGER_AREA * 2):
				opponents += 1
	return opponents

#/******************************************************************************
#*****************************************************************************/

# float facing_opp(match_player *player,short opp)
@warning_ignore("integer_division")
static func facing_opp(player: match_player, opp: int) -> float:
	var xd: float = player.tm_xdis
	var yd: float = player.tm_ydis
	var xo: float = teams[opp - 1].tm_xdis
	var yo: float = teams[opp - 1].tm_ydis
	var a: float = ((xo * xd) + (yo * yd))
	return a

#/******************************************************************************
#*****************************************************************************/

# void player_ints(match_player *player)
@warning_ignore("integer_division")
static func player_ints(player: match_player) -> void:
	if (((player.tm_act == TACKLE_ACT and player.go_cnt > EFFECTIVE_TACK)
		or (player.tm_act == STEAL_ACT and player.tm_frm > 0.4 and player.tm_frm < 0.6))
		and (not dead_ball_cnt) and (not just_scored)):
		var x: float
		var y: float
		var z: float
		var dir: float
		var chance: int
		for i in range(1, players + 1):
			if teams[i - 1].tm_act <= TURN_ACT:
				x = player.tm_x - teams[i - 1].tm_x
				y = player.tm_y - teams[i - 1].tm_y
				z = player.tm_y - teams[i - 1].tm_y		# (sic) tm_y, not tm_z, in the original
				if (Maths.calc_dist(x, y) <= PLAYER_SIZE) and (z < PLAYER_HEIGHT / 3):
					# If the tackling player comes in from behind or the side
					# then he has a greater chance of bringing the opponent down!
					dir = facing_opp(player, i)
					chance = s16(int(seed / (dir + 2)))

					if chance < (42 + ((player.tm_pow - teams[i - 1].tm_pow) / 3)):
						# Crunching tackle...
						Actions.init_fall(teams[i - 1])
						#						if ((!player->go_step) && ((player_num<12 && i>11) || (player_num>11 && i<12)))
						if ((player_num < 12 and i > 11) or (player_num > 11 and i < 12)):
							# He is in opposing team!
							# He hasn't made contact with ball...
							# Therefore a foul has been commited...
							man_down = Maths.calc_dist(player.go_txdis,
													 player.go_tydis)

							Rules.init_foul(player.tm_player, TRUE, FALSE)	# pass no. of fouler.

							# Man appeals for f.k...
							init_speech(i, SAY_REF, REAL_SPEED)
					else:
						# Ride over tackle...
						if player.tm_act != STEAL_ACT:
							Actions.init_jump_act(teams[i - 1], TRUE, TRUE)

#/*****************************************************************************
#*****************************************************************************/

# char cross_angle(float xd,float yd,float x,float y)
@warning_ignore("integer_division")
static func cross_angle(xd: float, yd: float, x: float, y: float) -> int:
	var a: float = Actions.angle_to_xy(xd, yd, x, y)
	if a > -0.174 and a < 0.707:
		# In 55 degree threshold (100 -> 45)...
		if (xd * y) > (yd * x):
			return 1
		else:
			return 2
	else:
		return 0

#/*****************************************************************************
#*****************************************************************************/

# void new_interceptor(int p)
@warning_ignore("integer_division")
static func new_interceptor(p: int) -> void:
	if p < 12:
		# Team A...
		if interceptor_a:
			reset_ideas(teams[interceptor_a - 1])

		receiver_a = p
		near_path_a = p		# Fake passee as nearest!
	else:
		# Team B...
		if interceptor_b:
			reset_ideas(teams[interceptor_b - 1])

		receiver_b = p
		near_path_b = p		# Fake passee as nearest!

	if EURO96:		# 1-2 Pass.
		if uf1:
			# Force receiver to return ball again to complete 1-2!
			return_12 = u8(p)
		else:
			return_12 = FALSE
			User.reselect()			# Can control receiver.
	else:
		User.reselect()

#/*****************************************************************************
#*****************************************************************************/

# int pass_ahead(int ps,float &x,float &y,float &pass_speed,float &end_speed,char cross)
# (reference params -> returns [ret, x, y, pass_speed, end_speed])
@warning_ignore("integer_division")
static func pass_ahead(ps: int, x: float, y: float, pass_speed: float, end_speed: float, cross: int) -> Array:
	var i: int = 0
	var t: int = 0
	var a: float
	var b: float
	var s: float
	a = x
	b = y
	var xd: float
	var yd: float
	var dd: float = 0.0
	var extra: int

	if ball_limbo_on:
		extra = int(((ball_limbo_c - teams[ball_limbo_p - 1].tm_frm) / teams[ball_limbo_p - 1].tm_fstep) - 1)
	else:
		extra = 0

	# Get Targets movement...
	xd = teams[ps - 1].go_txdis
	yd = teams[ps - 1].go_tydis

	i = 1
	while i < 40:
		a += xd
		b += yd		# Inc running time

		dd = Maths.calc_dist(a, b)

		if cross or dd > LOW_PASS_DIST or chip_pass:
			# In air...
			pass_speed = end_speed + 4 + (dd * (1 - AIR_FRICTION))
			t = int((log((end_speed + 4) / pass_speed)) / (log(AIR_FRICTION)))
		else:
			# On grnd...
			pass_speed = end_speed + (dd * (1 - GRND_FRICTION))
			t = int((log(end_speed / pass_speed)) / (log(GRND_FRICTION)))

		if t <= (i - extra):
			i = 1000						# Intersection with run here...
		i += 1

	if i >= 1000:
		# successfull intersection....
		x = a + xd
		y = b + yd		# new offsets...

		if (x + ballx) < 0:
			x = prat - ballx

		if (x + ballx) > pitch_len:
			x = (pitch_len - prat) - ballx

		if (y + bally) < 0:
			y = prat - bally

		if (y + bally) > pitch_wid:
			y = (pitch_wid - prat) - bally

		if dd > LOW_PASS_DIST:
			ball_inair = TRUE

	return [t, x, y, pass_speed, end_speed]

#/*****************************************************************************
#*****************************************************************************/

# void choose_pass(int ps,float &x,float &y,float &pass_speed,float &end_speed,char cross)
# (reference params -> returns [x, y, pass_speed, end_speed])
@warning_ignore("integer_division")
static func choose_pass(ps: int, x: float, y: float, pass_speed: float, end_speed: float, cross: int) -> Array:
	var tx: float
	var ty: float
	var d: float
	var r: Array
	if cross:
		# Cross it ahead of him towards opponents goal...
		if ps < 12:
			# Team B's Goal!
			tx = pitch_len - teams[ps - 1].tm_x
			ty = cntspot_y - teams[ps - 1].tm_y
		else:
			# Team A's Goal!
			tx = -teams[ps - 1].tm_x
			ty = cntspot_y - teams[ps - 1].tm_y

		if (tx <= prat and ps < 12) or (tx > -prat and ps > 11):
			# Close to goal-line (straight to him instead!)...
			Actions.init_stand_act(teams[ps - 1])
			r = pass_ahead(ps, x, y, pass_speed, end_speed, cross)			# Obviously he isn't moving so it will go straight to him!
			var t: int = r[0]
			x = r[1]; y = r[2]; pass_speed = r[3]; end_speed = r[4]
		else:
			# Target aimed ahead of player towards goal...
			d = Maths.calc_dist(tx, ty)
			x += tx * prat / d
			y += ty * prat / d
			Actions.init_stand_act(teams[ps - 1])
			r = pass_ahead(ps, x, y, pass_speed, end_speed, cross)
			x = r[1]; y = r[2]; pass_speed = r[3]; end_speed = r[4]
	else:
		if ((((ps < 12 and teams[ps - 1].go_txdis > 0) or (ps > 11 and teams[ps - 1].go_txdis < 0))
			and teams[ps - 1].tm_act == RUN_ACT)):
			# Pass ahead...
			r = pass_ahead(ps, x, y, pass_speed, end_speed, cross)
			x = r[1]; y = r[2]; pass_speed = r[3]; end_speed = r[4]
		else:
			Actions.init_stand_act(teams[ps - 1])
			r = pass_ahead(ps, x, y, pass_speed, end_speed, cross)			# Obviously he isn't moving so it will go straight to him!
			var t: int = r[0]
			x = r[1]; y = r[2]; pass_speed = r[3]; end_speed = r[4]
	return [x, y, pass_speed, end_speed]

#/*****************************************************************************
#*****************************************************************************/

# void pass_ball(int ps,char cross)
@warning_ignore("integer_division")
static func pass_ball(ps: int, cross: int) -> void:
	Rules.inc_pass(ball_poss)

	receiver_a = FALSE
	receiver_b = FALSE

	var x: float = 0.0
	var y: float = 0.0
	var d: float = 0.0
	var t: int
	var r: Array

	# Speed of ball at target!

	var end_speed: float
	var pass_speed: float = 0.0

	if cross:
		Ball.new_shot(ball_poss)		# Treat crosses as shots at goal!
		# Hit it harder to cross it in...
		end_speed = 7
	else:
		end_speed = 5

	if ps <= 0:
		comm_pass = 0		# Default short pass...

		# Must pass but no-one to pass to!
		if teams[ball_poss - 1].tm_act == THROW_ACT:
			x = teams[ball_poss - 1].tm_xdis * 140		# Far forward!
			y = teams[ball_poss - 1].tm_ydis * 140
		else:
			if not user_controlled:
				# switch(must_pass)
				if must_pass == NORMAL_PLAY:
					x = teams[ball_poss - 1].tm_xdis * 10		# Tap forward!
					y = teams[ball_poss - 1].tm_ydis * 10
					end_speed = (Actions.actual_spd(teams[ball_poss - 1])) + 0.8

				elif must_pass == CORNER_TR or must_pass == CORNER_BR:
					x = pitch_len - (prat * 15) - ballx
					y = cntspot_y - bally

				elif must_pass == CORNER_TL or must_pass == CORNER_BL:
					x = (prat * 15) - ballx
					y = cntspot_y - bally

				elif must_pass == CENTRE_A or must_pass == CENTRE_B:
					x = cntspot_x - ballx
					y = cntspot_y - bally

				elif must_pass == IF_KICK_A or must_pass == IF_KICK_B or must_pass == DF_KICK_A or must_pass == DF_KICK_B:
					x = setp_kick_x * 160		# Pass forward!
					y = setp_kick_y * 160
			else:
				if (spec_kick_type == SPACT_HPASS or spec_kick_type == SPACT_DPASS
					or spec_kick_type == SPACT_FPASS or spec_kick_type == SPACT_TEE_UP):
					# User set-piece actions which should have been for team-mates...
					if chip_pass:
						x = setp_kick_x * (prat * 16)
						y = setp_kick_y * (prat * 16)
					else:
						x = setp_kick_x * (prat * 14)
						y = setp_kick_y * (prat * 14)

					d = Maths.calc_dist(x, y)

				if spec_kick_type == SPACT_GRND:
					x = setp_kick_x * (f2_down * prat)
					y = setp_kick_y * (f2_down * prat)
					d = Maths.calc_dist(x, y)
		d = Maths.calc_dist(x, y)

	if ps > 0:
		x = teams[ps - 1].tm_x - ballx
		y = teams[ps - 1].tm_y - bally
		d = Maths.calc_dist(x, y)

		comm_pass = u8(int(d / (LONG_PASS_DIST)))

		if want_pass == ps:
			# team-mate cannot stop!
			r = pass_ahead(ps, x, y, pass_speed, end_speed, cross)
			x = r[1]; y = r[2]; pass_speed = r[3]; end_speed = r[4]
		else:
			r = choose_pass(ps, x, y, pass_speed, end_speed, cross)
			x = r[0]; y = r[1]; pass_speed = r[2]; end_speed = r[3]

		d = Maths.calc_dist(x, y)

	# Get acuracy offsets!

	var ac1: float
	var ac2: float

	Maths.af_randomize()

	if (ps > 0) and (ps != KP_A) and (ps != KP_B) and want_pass != ps:
		# He is passing to an on-the-field player...
		# ac1=Direction offset!
		ac1 = ((Maths.rand_range(128 - teams[ball_poss - 1].tm_ac)) * PASS_ACC_ARC) * PI / 180	# *D2RAD

		# ac2=Power offset!
		ac2 = (float(Maths.rand_range(128 - teams[ball_poss - 1].tm_ac))) / 32

		if seed & 64:
			ac1 = -ac1
	else:
		ac1 = 0
		ac2 = 0

	if not match_info.GameType:
		# Arcade Mode...(Passing is always accurate!)
		ac1 = 0
		ac2 = 0

	var nx: float
	var ny: float
	var ox: float
	var oy: float

	ox = x / d
	oy = y / d

	nx = (ox * cos(ac1)) - (oy * sin(ac1))
	ny = (oy * cos(ac1)) + (ox * sin(ac1))

	# New Target (x,y)!
	x = nx * d
	y = ny * d

	end_speed -= ac2

	ball_zspin = 0
	ball_xyspin = 0
	full_xyspin = 0
	swerve = FALSE

	if (pass_type != 9) and ((ball_in_hands) or (heading_ball)):
		# need to throw ball!
		heading_ball = FALSE
		ball_inair = TRUE
		pass_speed = end_speed + 2 + (d * (1 - AIR_FRICTION))
		ballxdis = pass_speed * x / d
		ballydis = pass_speed * y / d

		t = int((log((end_speed + 2) / pass_speed)) / (log(AIR_FRICTION)))
		if not t:
			t = 1

		if chip_pass:
			# Aim for head...
			ballzdis = ((PLAYER_HEIGHT - ballz) / t) + (t / 2) * gravity
		else:
			ballzdis = (t / 2) * gravity - (ballz / t)

		ball_in_hands = FALSE
		# Stop run!
		if teams[ball_poss - 1].tm_act == RUN_ACT:
			teams[ball_poss - 1].go_cnt = 0

		Ball.launch_ball(1)			# Set up spin vector.
		cannot_pick_up = -ball_poss
	else:
		if (pass_type == -1 or pass_type == 16 or pass_type == 17 or
			chip_pass):
			# need to chip ball!
			ball_inair = TRUE

			if (ps <= 0) and (chip_pass):
				# Forced chip forward...
				if spec_kick_type == SPACT_CHIP:
					# Use user power setting...
					ballxdis = setp_bxd
					ballydis = setp_byd
					ballzdis = setp_bzd
				else:
					ballxdis = 4 * x / d
					ballydis = 4 * y / d
					ballzdis = 6
				cannot_pick_up = ball_poss
			else:
				# In air to team-mate...
				pass_speed = end_speed + 4 + (d * (1 - AIR_FRICTION))
				t = int((log((end_speed + 4) / pass_speed)) / (log(AIR_FRICTION)))

				ballxdis = pass_speed * x / d
				ballydis = pass_speed * y / d
				if t < 0.1:
					t = 1

				cannot_pick_up = ball_poss

				if chip_pass:
					# Aim for head...
					ballzdis = ((PLAYER_HEIGHT - ballz) / t) + (t / 2) * gravity
				else:
					ballzdis = (t / 2) * gravity - (ballz / t)

				if cross:
					ballzdis = ((PLAYER_HEIGHT - 6 - ballz) / t) + (t / 2) * gravity

				if ballzdis > 14:
					ballzdis = 14

			var angle: int = 0

			Ball.launch_ball(-1 if seed & 1 else 1)			# Set up spin vector.
		else:
			ball_inair = FALSE
			pass_speed = end_speed + (d * (1 - GRND_FRICTION))
			ballxdis = pass_speed * x / d
			ballydis = pass_speed * y / d
			cannot_pick_up = ball_poss

			ballzdis = 0
			ballz = ball_diam / 2
			ball_xyspin = 0
			ball_zspin = 0

	BallInt.holder_lose_ball()
	must_pass = FALSE

	if ps > 0:
		new_interceptor(ps)

#/******************************************************************************
#*****************************************************************************/

# void make_pass(match_player *player,int p,char cross=FALSE)
@warning_ignore("integer_division")
static func make_pass(player: match_player, p: int, cross: int = FALSE) -> void:
	kick_type = KT_PASS
	var sx: float = 0.0
	var sy: float = 0.0
	var sz: float = 0.0
	var r: Array
	cross_now = u8(cross)
	receiver = p
	comm_pass_type = 0
	match pass_type:
		# Player kick along ground, ball tweens to contact point and is then released...
		3:
			Actions.init_kick_act(teams[ball_poss - 1], MC_SIDEPASSL, MCC_SIDEPASS)

		2:
			Actions.init_kick_act(teams[ball_poss - 1], MC_DIAGBACKL, MCC_DIAGBACK)
			comm_pass_type = 1

		1:
			Actions.init_kick_act(teams[ball_poss - 1], MC_BACKHEELL, MCC_BACKHEEL)
			comm_pass_type = 1

		8:
			Actions.init_kick_act(teams[ball_poss - 1], MC_DIAGBACKR, MCC_DIAGBACK)
			comm_pass_type = 1

		7:
			Actions.init_kick_act(teams[ball_poss - 1], MC_SIDEPASSR, MCC_SIDEPASS)

		6:
			Actions.init_kick_act(teams[ball_poss - 1], MC_DIAGPASSR, MCC_DIAGPASS)

		5:
			Actions.init_kick_act(teams[ball_poss - 1], MC_PASSL, MCC_PASS)

		4:
			Actions.init_kick_act(teams[ball_poss - 1], MC_DIAGPASSL, MCC_DIAGPASS)

		-1:
			Actions.init_kick_act(teams[ball_poss - 1], MC_CHIPL, MCC_CHIP)
			comm_pass_type = 2

		16:
			Actions.init_kick_act(teams[ball_poss - 1], MC_CROSSL, MCC_CROSS)
			comm_pass_type = 2

		17:
			Actions.init_kick_act(teams[ball_poss - 1], MC_CROSSR, MCC_CROSS)
			comm_pass_type = 2
		#/*
		#		case(12):
		#			init_kick_act(&teams[ball_poss-1],MC_THROWL,MCC_THROWL);
		#			comm_pass_type=2;
		#			break;
		#
		#		case(13):
		#			init_kick_act(&teams[ball_poss-1],MC_THROWS,MCC_THROWS);
		#			break;
		#*/
		# Keeper new animation start, ball in limbo until contact...
		11:
			Actions.init_anim(teams[ball_poss - 1], MC_HALFVOLL)
			# Point at which ball leaves hand!
			# Calculate current mcap offsets for given direction (newdx,newdy)!
			r = Actions.rotate_offs(MC_HALFVOLL, sx, sy, sz, teams[ball_poss - 1].tm_xdis, teams[ball_poss - 1].tm_ydis)
			sx = r[0]; sy = r[1]; sz = r[2]
			ballx = teams[ball_poss - 1].tm_x + sx
			bally = teams[ball_poss - 1].tm_y + sy
			ballz = teams[ball_poss - 1].tm_z + sz
			Ball.ball_limbo(teams[ball_poss - 1].tm_player, MCC_HALFVOLL)
			teams[ball_poss - 1].tm_limbo = int(1 / MC_HALFVOLL_FS)
			pass_ball(receiver, FALSE)
			comm_pass_type = 2

		10:
			Actions.init_anim(teams[ball_poss - 1], MC_THROW)
			# Point at which ball leaves hand!
			# Calculate current mcap offsets for given direction (newdx,newdy)!
			r = Actions.rotate_offs(MC_THROW, sx, sy, sz, teams[ball_poss - 1].tm_xdis, teams[ball_poss - 1].tm_ydis)
			sx = r[0]; sy = r[1]; sz = r[2]
			ballx = teams[ball_poss - 1].tm_x + sx
			bally = teams[ball_poss - 1].tm_y + sy
			ballz = teams[ball_poss - 1].tm_z + sz
			Ball.ball_limbo(teams[ball_poss - 1].tm_player, MCC_THROW)
			teams[ball_poss - 1].tm_limbo = int(1 / MC_THROW_FS)
			pass_ball(receiver, FALSE)

		9:
			Actions.init_anim(teams[ball_poss - 1], MC_ROLL)
			# Point at which ball leaves hand!
			# Calculate current mcap offsets for given direction (newdx,newdy)!
			r = Actions.rotate_offs(MC_ROLL, sx, sy, sz, teams[ball_poss - 1].tm_xdis, teams[ball_poss - 1].tm_ydis)
			sx = r[0]; sy = r[1]; sz = r[2]
			ballx = teams[ball_poss - 1].tm_x + sx
			bally = teams[ball_poss - 1].tm_y + sy
			ballz = teams[ball_poss - 1].tm_z + sz
			Ball.ball_limbo(teams[ball_poss - 1].tm_player, MCC_ROLL)
			teams[ball_poss - 1].tm_limbo = int(1 / MC_ROLL_FS)
			pass_ball(receiver, FALSE)

		12:
			Actions.init_anim(teams[ball_poss - 1], MC_THROWS)
			# Point at which ball leaves hand!
			# Calculate current mcap offsets for given direction (newdx,newdy)!
			r = Actions.rotate_offs(MC_THROWS, sx, sy, sz, teams[ball_poss - 1].tm_xdis, teams[ball_poss - 1].tm_ydis)
			sx = r[0]; sy = r[1]; sz = r[2]
			ballx = teams[ball_poss - 1].tm_x + sx
			bally = teams[ball_poss - 1].tm_y + sy
			ballz = teams[ball_poss - 1].tm_z + sz
			Ball.ball_limbo(teams[ball_poss - 1].tm_player, MCC_THROWS)
			teams[ball_poss - 1].tm_limbo = int(1 / MC_THROWS_FS)
			pass_ball(receiver, FALSE)

		13:
			Actions.init_anim(teams[ball_poss - 1], MC_THROWL)
			# Point at which ball leaves hand!
			# Calculate current mcap offsets for given direction (newdx,newdy)!
			r = Actions.rotate_offs(MC_THROWL, sx, sy, sz, teams[ball_poss - 1].tm_xdis, teams[ball_poss - 1].tm_ydis)
			sx = r[0]; sy = r[1]; sz = r[2]
			ballx = teams[ball_poss - 1].tm_x + sx
			bally = teams[ball_poss - 1].tm_y + sy
			ballz = teams[ball_poss - 1].tm_z + sz
			Ball.ball_limbo(teams[ball_poss - 1].tm_player, MCC_THROWL)
			teams[ball_poss - 1].tm_limbo = int(1 / MC_THROWL_FS)
			pass_ball(receiver, FALSE)

		# Already in appropriate animation...
		15:
			# Header!
			Actions.fire_ball_off()
			Audio.PlayCommentaryMessage(CP_HEAD)

		14:
			# Volley!
			Actions.fire_ball_off()

#/******************************************************************************
#*****************************************************************************/

# void dribble_dir(match_player *player,float &xd,float &yd)
# (reference params -> returns [xd, yd])
@warning_ignore("integer_division")
static func dribble_dir(player: match_player, xd: float, yd: float) -> Array:
	var x: float
	var y: float
	var d: float
	var rate: float = Actions.actual_spd(player)
	var i: int
	var go_that_way: int = FALSE
	var a: int = (TRUE if (seed < 64) else FALSE)

	var sina: float = sin(0.174)		# approx. 10 degrees!
	var cosa: float = cos(0.174)

	var xd1: float = xd
	var yd1: float = yd

	var xd2: float = xd
	var yd2: float = yd

	var xo: float
	var yo: float
	var dif: float

	var cnt: int = 0

	while (not go_that_way) and (drib_opps):

		# Coords of future ball.
		x = ballx + (xd * DRIB_DANGER_AREA / 4)
		y = bally + (yd * DRIB_DANGER_AREA / 4)

		go_that_way = TRUE

		i = 0
		while i < drib_opps:
			xo = x - opp_dir_tab[i][0]
			yo = y - opp_dir_tab[i][1]		# offset to future ball!

			d = Maths.calc_dist(xo, yo)

			dif = (player.tm_xdis * xo / d) + (player.tm_ydis * yo / d)
			d = d * (2 - dif)

			if d < DRIB_DANGER_AREA / 2:
				go_that_way = FALSE
				break
			i += 1

		if (x < 16) or (x > pitch_len - 16) or (y < 16) or (y > pitch_wid - 16) or (not go_that_way):
			go_that_way = FALSE
			if a:
				xd = (xd1 * cosa) - (yd1 * sina)
				yd = (yd1 * cosa) + (xd1 * sina)
				xd1 = xd
				yd1 = yd
				a = bi(not a)
			else:
				xd = (xd2 * cosa) + (yd2 * sina)
				yd = (yd2 * cosa) - (xd2 * sina)
				xd2 = xd
				yd2 = yd
				a = bi(not a)

			var cnt_old: int = cnt
			cnt += 1
			if cnt_old == 36:
				# No-where to go, so go toward centre!
				xd = cntspot_x - ballx
				yd = cntspot_y - bally
				d = Maths.calc_dist(xd, yd)
				xd = xd / d
				yd = yd / d
				must_pass = TRUE
				break
	return [xd, yd]


#/******************************************************************************
#*****************************************************************************/
#/*
#int omake_run_a(match_player *player)
#{
#	if (player->tm_y>=cntspot_y)
#	{
#// DIR 4
#		if (ballx<pitch_len-32)
#		{
#			if ((opp_dir_tab[3]>=0) && (opp_dir_tab[5]>=0))
#			{
#				if (!opp_dir_tab[4])
#					return(4);
#			}
#		}
#
#// DIR 5
#		if ((ballx<pitch_len-32) && (bally>32))
#		{
#			if ((opp_dir_tab[6]>=0) && (opp_dir_tab[4]>=0))
#			{
#				if (!opp_dir_tab[5])
#					return(5);
#			}
#		}
#
#// DIR 3
#		if ((bally<pitch_wid-32) && (ballx<pitch_len-32))
#		{
#			if ((opp_dir_tab[2]>=0) && (opp_dir_tab[4]>=0))
#			{
#				if (!opp_dir_tab[3])
#					return(3);
#			}
#		}
#
#// DIR 6
#		if (bally>32)
#		{
#			if ((opp_dir_tab[7]>=0) && (opp_dir_tab[5]>=0))
#			{
#				if (!opp_dir_tab[6])
#					return(6);
#			}
#		}
#
#// DIR 2
#		if (bally<pitch_wid-32)
#		{
#			if ((opp_dir_tab[3]>=0) && (opp_dir_tab[1]>=0))
#			{
#				if (!opp_dir_tab[2])
#					return(2);
#			}
#		}
#
#// DIR 7
#		if ((bally>32) && (ballx>32))
#		{
#			if ((opp_dir_tab[0]>=0) && (opp_dir_tab[6]>=0))
#			{
#				if (!opp_dir_tab[7])
#					return(7);
#			}
#		}
#
#// DIR 1
#		if ((bally<pitch_wid-32) && (ballx>32))
#		{
#			if ((opp_dir_tab[2]>=0) && (opp_dir_tab[5]>=0))
#			{
#				if (!opp_dir_tab[1])
#					return(1);
#			}
#		}
#
#// DIR 0
#		if (ballx>32)
#		{
#			if ((opp_dir_tab[1]>=0) && (opp_dir_tab[7]>=0))
#			{
#				if (!opp_dir_tab[0])
#					return(0);
#			}
#		}
#	}
#	else
#	{
#// DIR 4
#		if (ballx<pitch_len-32)
#		{
#			if ((opp_dir_tab[3]>=0) && (opp_dir_tab[5]>=0))
#			{
#				if (!opp_dir_tab[4])
#					return(4);
#			}
#		}
#
#// DIR 3
#		if ((bally<pitch_wid-32) && (ballx<pitch_len-32))
#		{
#			if ((opp_dir_tab[2]>=0) && (opp_dir_tab[4]>=0))
#			{
#				if (!opp_dir_tab[3])
#					return(3);
#			}
#		}
#
#// DIR 5
#		if ((ballx<pitch_len-32) && (bally>32))
#		{
#			if ((opp_dir_tab[6]>=0) && (opp_dir_tab[4]>=0))
#			{
#				if (!opp_dir_tab[5])
#					return(5);
#			}
#		}
#
#// DIR 2
#		if (bally<pitch_wid-32)
#		{
#			if ((opp_dir_tab[3]>=0) && (opp_dir_tab[1]>=0))
#			{
#				if (!opp_dir_tab[2])
#					return(2);
#			}
#		}
#
#// DIR 6
#		if (bally>32)
#		{
#			if ((opp_dir_tab[7]>=0) && (opp_dir_tab[5]>=0))
#			{
#				if (!opp_dir_tab[6])
#					return(6);
#			}
#		}
#
#// DIR 1
#		if ((bally<pitch_wid-32) && (ballx>32))
#		{
#			if ((opp_dir_tab[2]>=0) && (opp_dir_tab[5]>=0))
#			{
#				if (!opp_dir_tab[1])
#					return(1);
#			}
#		}
#
#// DIR 7
#		if ((bally>32) && (ballx>32))
#		{
#			if ((opp_dir_tab[0]>=0) && (opp_dir_tab[6]>=0))
#			{
#				if (!opp_dir_tab[7])
#					return(7);
#			}
#		}
#
#// DIR 0
#		if (ballx>32)
#		{
#			if ((opp_dir_tab[1]>=0) && (opp_dir_tab[7]>=0))
#			{
#				if (!opp_dir_tab[0])
#					return(0);
#			}
#		}
#	}
#
#// Go to right corners...
#	int y;
#	int x=(pitch_len-(prat*5))-ballx;
#	if (bally>cntspot_y)
#		y=(pitch_wid-(prat*5))-bally;
#	else
#		y=((prat*5))-bally;
#	return(get_dir(x,y));
#}
#*/
#/******************************************************************************
#*****************************************************************************/
#/*
#int make_run_b(match_player *player)
#{
#	if (player->tm_y>=cntspot_y)
#	{
#// DIR 0
#		if (ballx>32)
#		{
#			if ((opp_dir_tab[1]>=0) && (opp_dir_tab[7]>=0))
#			{
#				if (!opp_dir_tab[0])
#					return(0);
#			}
#		}
#
#// DIR 7
#		if ((bally>32) && (ballx>32))
#		{
#			if ((opp_dir_tab[0]>=0) && (opp_dir_tab[6]>=0))
#			{
#				if (!opp_dir_tab[7])
#					return(7);
#			}
#		}
#
#// DIR 1
#		if ((bally<pitch_wid-32) && (ballx>32))
#		{
#			if ((opp_dir_tab[2]>=0) && (opp_dir_tab[5]>=0))
#			{
#				if (!opp_dir_tab[1])
#					return(1);
#			}
#		}
#
#// DIR 6
#		if (bally>32)
#		{
#			if ((opp_dir_tab[7]>=0) && (opp_dir_tab[5]>=0))
#			{
#				if (!opp_dir_tab[6])
#					return(6);
#			}
#		}
#
#// DIR 2
#		if (bally<pitch_wid-32)
#		{
#			if ((opp_dir_tab[3]>=0) && (opp_dir_tab[1]>=0))
#			{
#				if (!opp_dir_tab[2])
#					return(2);
#			}
#		}
#
#// DIR 5
#		if ((ballx<pitch_len-32) && (bally>32))
#		{
#			if ((opp_dir_tab[6]>=0) && (opp_dir_tab[4]>=0))
#			{
#				if (!opp_dir_tab[5])
#					return(5);
#			}
#		}
#
#// DIR 3
#		if ((bally<pitch_wid-32) && (ballx<pitch_len-32))
#		{
#			if ((opp_dir_tab[2]>=0) && (opp_dir_tab[4]>=0))
#			{
#				if (!opp_dir_tab[3])
#					return(3);
#			}
#		}
#
#// DIR 4
#		if (ballx<pitch_len-32)
#		{
#			if ((opp_dir_tab[3]>=0) && (opp_dir_tab[5]>=0))
#			{
#				if (!opp_dir_tab[4])
#					return(4);
#			}
#		}
#	}
#	else
#	{
#// DIR 0
#		if (ballx>32)
#		{
#			if ((opp_dir_tab[1]>=0) && (opp_dir_tab[7]>=0))
#			{
#				if (!opp_dir_tab[0])
#					return(0);
#			}
#		}
#
#// DIR 1
#		if ((bally<pitch_wid-32) && (ballx>32))
#		{
#			if ((opp_dir_tab[2]>=0) && (opp_dir_tab[5]>=0))
#			{
#				if (!opp_dir_tab[1])
#					return(1);
#			}
#		}
#
#// DIR 7
#		if ((bally>32) && (ballx>32))
#		{
#			if ((opp_dir_tab[0]>=0) && (opp_dir_tab[6]>=0))
#			{
#				if (!opp_dir_tab[7])
#					return(7);
#			}
#		}
#
#// DIR 2
#		if (bally<pitch_wid-32)
#		{
#			if ((opp_dir_tab[3]>=0) && (opp_dir_tab[1]>=0))
#			{
#				if (!opp_dir_tab[2])
#					return(2);
#			}
#		}
#
#// DIR 6
#		if (bally>32)
#		{
#			if ((opp_dir_tab[7]>=0) && (opp_dir_tab[5]>=0))
#			{
#				if (!opp_dir_tab[6])
#					return(6);
#			}
#		}
#
#// DIR 3
#		if ((bally<pitch_wid-32) && (ballx<pitch_len-32))
#		{
#			if ((opp_dir_tab[2]>=0) && (opp_dir_tab[4]>=0))
#			{
#				if (!opp_dir_tab[3])
#					return(3);
#			}
#		}
#
#// DIR 5
#		if ((ballx<pitch_len-32) && (bally>32))
#		{
#			if ((opp_dir_tab[6]>=0) && (opp_dir_tab[4]>=0))
#			{
#				if (!opp_dir_tab[5])
#					return(5);
#			}
#		}
#
#// DIR 4
#		if (ballx<pitch_len-32)
#		{
#			if ((opp_dir_tab[3]>=0) && (opp_dir_tab[5]>=0))
#			{
#				if (!opp_dir_tab[4])
#					return(4);
#			}
#		}
#	}
#
#// Go to left corners...
#	int y;
#	int x=(prat*5)-ballx;
#	if (bally>cntspot_y)
#		y=(pitch_wid-(prat*5))-bally;
#	else
#		y=((prat*5))-bally;
#	return(get_dir(x,y));
#}
#
#*/

#/******************************************************************************
#*****************************************************************************/

# void avoid_boundary(match_player *player)
@warning_ignore("integer_division")
static func avoid_boundary(player: match_player) -> void:
	# Just run toward opponents goal...
	var x: float
	var y: float = cntspot_y
	if player.tm_player < 12:
		# Goal B...
		x = pitch_len
	else:
		# Goal A...
		x = 0

	Actions.init_run_act(player, x, y, TRUE)
	action = "Dribble"

#/******************************************************************************
#*****************************************************************************/

# void go_dribble(match_player *player,float x,float y)
@warning_ignore("integer_division")
static func go_dribble(player: match_player, x: float, y: float) -> void:
	x = player.tm_x + (x * 500)
	y = player.tm_y + (y * 500)

	# Make target (x,y) greater than intention range!

	Actions.init_run_act(player, x, y, TRUE)
	action = "Dribble"

#/******************************************************************************
#*****************************************************************************/

# void make_run(match_player *player)
@warning_ignore("integer_division")
static func make_run(player: match_player) -> void:
	var x: float
	var y: float
	var px: float
	var r: Array

	if player.tm_player < 12:
		# Team A
		px = player.tm_x - (pitch_len - prat * 10)
		if px > 0:
			if px < prat * 10:
				x = cos(px * PI / (prat * 20))
			else:
				x = 0

			y = sqrt(1 - (x * x))

			if player.tm_y > cntspot_y:
				y = -y

		else:
			x = 1
			y = 0
		get_opp_dir_tab(player.tm_player)
		r = dribble_dir(player, x, y)
		x = r[0]; y = r[1]
		go_dribble(player, x, y)
	else:
		# Team B
		px = (prat * 10) - player.tm_x
		if px > 0:
			if px < prat * 10:
				x = -cos(px * PI / (prat * 20))
			else:
				x = 0

			y = sqrt(1 - (x * x))

			if player.tm_y > cntspot_y:
				y = -y

		else:
			x = -1
			y = 0
		get_opp_dir_tab(player.tm_player)
		r = dribble_dir(player, x, y)
		x = r[0]; y = r[1]
		go_dribble(player, x, y)
	reset_ideas(player)
	player.int_move = I_DRIBBLE
	player.int_cnt = 18 - (player.tm_flair / 8)
	player.go_cnt = 19 - (player.tm_flair / 8)

	# Where will he be at end of run!
	x = player.tm_x + (player.go_txdis * player.go_cnt)
	y = player.tm_y + (player.go_tydis * player.go_cnt)
	if x > pitch_len or x < 0 or y < 0 or y > pitch_wid:
		# Running off pitch!!!
		avoid_boundary(player)

#/******************************************************************************
#*****************************************************************************/

# int run_decide(match_player *player)
@warning_ignore("integer_division")
static func run_decide(player: match_player) -> int:
	var opps: int = (player.tm_flair) - (opponents_near_holder * 16)
	if opps <= 0:
		opps = MIN_RUN_PROB
	if seed < opps:
		return TRUE
	else:
		return FALSE

#/******************************************************************************
#*****************************************************************************/

# void make_punt(match_player *player)
@warning_ignore("integer_division")
static func make_punt(player: match_player) -> void:
	if ball_in_hands and (player.tm_player == KP_A or player.tm_player == KP_B):
		punt_ball(player)
	else:
		kick_type = KT_PUNT
		pass_type = 100
		Actions.init_kick_act(player, MC_SHOOTL, MCC_SHOOT)

#/*****************************************************************************
#*****************************************************************************/

# void punt_ball(match_player *player)
@warning_ignore("integer_division")
static func punt_ball(player: match_player) -> void:
	Rules.inc_pass(ball_poss)

	receiver_a = FALSE
	receiver_b = FALSE

	cannot_pick_up = ball_poss
	must_punt = FALSE
	var inh: int = ball_in_hands
	ball_inair = TRUE
	var r: int = Maths.rand_range(129 - player.tm_ac)

	ballxdis = player.tm_xdis * (6 + player.tm_pow / 8)
	ballydis = player.tm_ydis * (6 + player.tm_pow / 8)
	if heading_ball == 2:
		ballzdis = 4				# Diving Header!
	else:
		if heading_ball == 1:
			ballzdis = 6			# Standing or jumping header!
		else:
			if heading_ball == 3:
				ballzdis = 8
			else:
				if player.tm_player != KP_A and player.tm_player != KP_B:
					ballzdis = 10		# Kick!
				else:
					ballzdis = 12		# Kick!

	action = "Punt"
	Ball.new_shot(player.tm_player)							# Treat as shot just in case!

	if inh and (player.tm_player == KP_A or player.tm_player == KP_B):
		Actions.init_anim(player, MC_KICKOUT)
		# Kick out ball from hands!
		# Calculate current mcap offsets for given direction (newdx,newdy)!
		var sx: float = 0.0
		var sy: float = 0.0
		var sz: float = 0.0
		var ro: Array = Actions.rotate_offs(MC_KICKOUT, sx, sy, sz, player.tm_xdis, player.tm_ydis)
		sx = ro[0]; sy = ro[1]; sz = ro[2]
		ballx = player.tm_x + sx
		bally = player.tm_y + sy
		ballz = player.tm_z + sz
		Ball.ball_limbo(player.tm_player, MCC_KICKOUT)
		player.tm_limbo = int(1 / MC_KICKOUT_FS)
		Ball.launch_ball(1)			# Set up spin vector.
	BallInt.holder_lose_ball()

#/******************************************************************************
#*****************************************************************************/

# int punt_decide(match_player *player)
@warning_ignore("integer_division")
static func punt_decide(player: match_player) -> int:
	var x: float
	var y: float
	var x_factor: float
	var def: int

	x = player.tm_xdis
	y = player.tm_ydis

	if player.tm_player > 11:
		if x < 0 and (ballx < pitch_len and ballx > cntspot_x) and ((seed < -(x * 128)) or must_punt):
			def = int(ballx - cntspot_x)
		else:
			return FALSE
	else:
		if x > 0 and (ballx > 0 and ballx < cntspot_x) and ((seed < (x * 128)) or must_punt):
			def = int(cntspot_x - ballx)
		else:
			return FALSE

	if def > (cntspot_x - (10 * prat)):
		def += 128

	#	if (((user_player1==player->tm_player) || (user_player2==player->tm_player)) && (def>prat*20))
	if ((player.control) and (def > prat * 20)) or must_punt:
		def = 128 * 4
	# User must punt!

	if def / 3 > seed or (first_time_it and (def * (float(player.tm_cont) / 64) > seed)):
		# His position is defensive.
		var opps: int = (opponents_near_holder * 40) - (player.tm_flair)
		if opps < MIN_PUNT_PROB:
			opps = MIN_PUNT_PROB

		if user_controlled:
			# User must punt!
			opps = 128

		# Facing away from goal would help...
		if player.tm_player < 12:
			x_factor = (1 + x) / 2
		else:
			x_factor = -(x - 1) / 2

		if ((seed < opps * x_factor) and (x_factor > 0.5)) or must_punt:
			return TRUE

	return FALSE

#/******************************************************************************
#*****************************************************************************/

# int head_punt_decide(match_player *player)
@warning_ignore("integer_division")
static func head_punt_decide(player: match_player) -> int:
	var x: float
	var y: float
	var def: int

	x = player.tm_xdis
	y = player.tm_ydis

	if player.tm_player > 11:
		if x < 0:
			def = int(ballx - cntspot_x)
		else:
			return FALSE
	else:
		if x > 0:
			def = int(cntspot_x - ballx)
		else:
			return FALSE

	if def > (cntspot_x - (10 * prat)):
		def += 128

	if def / 4 > seed:
		# His position is defensive.
		cannot_pick_up = -player.tm_player
		BallInt.holder_lose_ball()
		ball_inair = TRUE
		ballxdis = ((float(player.tm_pow)) / 32.0) * x + (x * 6)
		ballydis = 0
		ballzdis = 10

		action = "Punt"
		Actions.init_anim(player, MC_S_HEAD)

		Ball.launch_ball(1)			# Set up spin vector.

		Audio.play_fx(PS_HARDHEAD, ballx, bally)

		return TRUE
	return FALSE

#/******************************************************************************
#*****************************************************************************/

# float get_power()
@warning_ignore("integer_division")
static func get_power() -> float:
	return (float(setp_power + 16) / 2)

#/******************************************************************************
#*****************************************************************************/

# float get_traj()
@warning_ignore("integer_division")
static func get_traj() -> float:
	return (float(setp_hgt) / 3)

#/******************************************************************************
#*****************************************************************************/

# void aim_shot_at_goal(match_player *player,float &xoff,float &yoff,int rng)
# (reference params -> returns [xoff, yoff])
@warning_ignore("integer_division")
static func aim_shot_at_goal(player: match_player, xoff: float, yoff: float, rng: int) -> Array:
	var x: float = 0.0
	var y: float = 0.0
	var d: float = 0.0
	var gx: float
	var gy: float
	var area: float = 0.0
	var side: int = 0

	if player.control and pass_type == -1:
		# User selects direction!
		x = player.tm_xdis
		y = player.tm_ydis

		var d_1: float = Maths.calc_dist(x * 128, y * 128)		# (C: inner 'float d' shadows the outer d)
		xoff = (x * rng * 128) / d_1
		yoff = (y * rng * 128) / d_1
	else:
		# Auto direction select based on (accuracy)!

		var keeper: int
		if player.tm_player < 12:
			keeper = 12
			gx = pitch_len
		else:
			keeper = 1
			gx = 0

		# get offset to keeper (x,y)!
		x = teams[keeper - 1].tm_x - ballx
		y = teams[keeper - 1].tm_y - bally

		# get offset to goal line through keeper (gx,gy)!

		gx = gx - ballx
		gy = y * gx / x

		area = gy + bally - cntspot_y

		if area > 0:
			# More area above keeper!
			if (player.tm_flair / 2) + 63 > seed:
				# Aim above!
				area = (cntspot_y + area) - top_post_y
				side = -1
			else:
				# Aim below!
				area = 0			# Doesn't aim for large gap!
				side = 1
		else:
			# More area below keeper!
			if (player.tm_flair / 2) + 63 > seed:
				# Aim below!
				area = bot_post_y - (cntspot_y + area)
				side = 1
			else:
				# Aim above!
				area = 0			# Doesn't aim for large gap!
				side = -1

		xoff = gx

		# Calculate Accuracy offset!
		var acc_off: int = (seed * (8 + (128 - player.tm_ac))) / 128
		if seed & 4:
			acc_off = int(-(acc_off * rng / (20.0 * prat)))
		else:
			acc_off = int((acc_off * rng / (20.0 * prat)))

		# Now. Direct at chosen target.
		if side > 0:
			yoff = bot_post_y - bally - 16 + acc_off
		else:
			yoff = top_post_y - bally + 16 + acc_off

	# Shot Speed...
	var shot_var: int = seed
	Maths.af_randomize()
	shot_var = (shot_var + seed) / 2			# Favour 64.

	shot_speed = 6 + (4 * rng / (prat * 60)) + (9.0 * (player.tm_pow + shot_var) / 150)

	if pass_type > 0 and pass_type < 5 and pass_type > 5:
		# Just a tap in...
		shot_speed /= 2


	# Initialise swerve on ball!
	Maths.af_randomize()
	ball_zspin = 0
	#	full_zspin=(float)player->tm_ac/(rng-sqrt(rng*4));
	swerve = 0
	spin_ball = 0
	max_sw_factor = 0

	var swerve_cond: bool
	if EURO96:
		swerve_cond = rng >= 10.0 * prat and not user_controlled and not penalty_shot
	else:
		swerve_cond = (rng >= 10.0 * prat) and (not user_controlled)
	if swerve_cond:
		Maths.af_randomize()
		full_xyspin = float(seed) / 128 * MAX_XY_CSW * player.tm_flair / 128
		full_zspin = (float(seed) / 128 * MAX_Z_CSW * player.tm_flair / 128)
		spin_ball = 0
		var d_2: float = Maths.calc_dist(xoff, yoff)		# (C: inner 'float d' shadows the outer d)

		Maths.af_randomize()

		# Time to reach (xoff,yoff)...
		var t: float = (d_2 / shot_speed * (1 - AIR_FRICTION))
		if t >= 1:
			t = 0.9998
		t = (log(1.0 - t)) / (log(AIR_FRICTION))	#	How long to go (d) dist!

		if xoff < 0:
			# Going Left
			if side < 0:
				# Left top.
				if xoff < yoff:
					swerve = -1
				else:
					swerve = 1
			# Left bot.
			else:
				if xoff < yoff:
					swerve = 1
				else:
					swerve = -1
		else:
			# Going Right
			if side < 0:
				# Right top.
				if xoff > yoff:
					swerve = 1
				else:
					swerve = -1
			# Right bot.
			else:
				if xoff > yoff:
					swerve = -1
				else:
					swerve = 1
		# Calculate Offset swerve angle...
		var a: float = 0
		var n: int = 1
		while n <= t:
			a += full_xyspin * (SW_HOLD_FACTOR / (SW_HOLD_FACTOR + n))
			n += 1

		a = (a / 2.2) + (d_2 / 4800)
		x = xoff / d_2
		y = yoff / d_2

		if swerve < 0:
			xoff = d_2 * ((x * cos(a)) - (y * sin(a)))
			yoff = d_2 * ((y * cos(a)) + (x * sin(a)))
		else:
			xoff = d_2 * ((x * cos(a)) + (y * sin(a)))
			yoff = d_2 * ((y * cos(a)) - (x * sin(a)))

		ballzdis = (7.2 + (rng / 180) + ((float(seed) / 64) * (128 - player.tm_ac) / 128)
				+ (float(full_zspin) / 2))
		spin_cnt = int(((ballzdis / gravity)) + (ABS(full_zspin)))
	else:
		if newk_shot:
			shot_speed = get_power()
			ballzdis = get_traj()
			xoff = player.tm_xdis * 10
			yoff = player.tm_ydis * 10
			ballxdis = xoff
			ballydis = yoff
		else:
			if drive_shot:
				shot_speed += 5
				ballzdis = 7 - (shot_speed / 10)
			else:
				if (area > prat * 6) and (rng < prat * 15):
					# Goal-keeper has left a large gap and attacker is close in!
					ballzdis = 1.8 + (rng / 180) + ((float(seed) / 64) * (128 - player.tm_ac) / 128)		# Place it low!
				else:
					ballzdis = 5.2 + (rng / 180) + ((float(seed) / 64) * (128 - player.tm_ac) / 128)

	if user_controlled:
		if drive_shot:
			after_touch_on = FALSE
		else:
			after_touch_on = user_controlled

		full_xyspin = MAX_XY_USW * player.tm_flair / 128
		full_zspin = MAX_Z_USW * player.tm_flair / 128
		d = Maths.calc_dist(ballxdis, ballydis)
		shoot_x = ballxdis / d
		shoot_y = ballydis / d		# Shoot direction vectors(for after-touch).
	spin_cnt = 0
	return [xoff, yoff]

#/******************************************************************************
#*****************************************************************************/

# void make_shoot(match_player *player)
@warning_ignore("integer_division")
static func make_shoot(player: match_player) -> void:
	kick_type = KT_SHOOT
	match pass_type:
		# Straight-forward shot!
		-1:
			Actions.init_kick_act(player, MC_SHOOTL, MCC_SHOOT)

		# Player kick along ground, ball tweens to contact point and is then released...
		3:
			Actions.init_kick_act(teams[ball_poss - 1], MC_SIDEPASSL, MCC_SIDEPASS)

		2:
			Actions.init_kick_act(teams[ball_poss - 1], MC_DIAGBACKL, MCC_DIAGBACK)

		1:
			Actions.init_kick_act(teams[ball_poss - 1], MC_BACKHEELL, MCC_BACKHEEL)

		8:
			Actions.init_kick_act(teams[ball_poss - 1], MC_DIAGBACKR, MCC_DIAGBACK)

		7:
			Actions.init_kick_act(teams[ball_poss - 1], MC_SIDEPASSR, MCC_SIDEPASS)

		6:
			Actions.init_kick_act(teams[ball_poss - 1], MC_DIAGPASSR, MCC_DIAGPASS)

		5:
			Actions.init_kick_act(teams[ball_poss - 1], MC_PASSL, MCC_PASS)

		4:
			Actions.init_kick_act(teams[ball_poss - 1], MC_DIAGPASSL, MCC_DIAGPASS)

#/******************************************************************************
#*****************************************************************************/

# void shoot_ball(match_player *player)
@warning_ignore("integer_division")
static func shoot_ball(player: match_player) -> void:
	receiver_a = FALSE
	receiver_b = FALSE

	if say_names:
		if not ball_poss:
			Audio.PlayTeamSample(Ball.real_player(last_touch), 2)
		else:
			Audio.PlayTeamSample(Ball.real_player(ball_poss), 2)

	# Fire shot!
	var goal_x: float
	if ball_poss <= 11:
		goal_x = pitch_len
	else:
		goal_x = 0
	var xoff: float = goal_x - ballx
	var yoff: float = cntspot_y - bally
	var range: float = Maths.calc_dist(xoff, yoff)
	if range < 1:
		range = 1

	BallInt.holder_lose_ball()
	ball_inair = TRUE
	Ball.new_shot(player.tm_player)
	real_shot = TRUE
	Maths.af_randomize()

	var r: Array = aim_shot_at_goal(player, xoff, yoff, int(range))
	xoff = r[0]; yoff = r[1]

	if heading_ball == 2:
		ballzdis = ballzdis * .5				# Diving Header!
	else:
		if heading_ball == 3:
			ballzdis = 1

	if ballzdis > 0.6:
		ball_inair = TRUE

	var d: float = Maths.calc_dist(xoff, yoff)

	ballxdis = shot_speed * xoff / d
	ballydis = shot_speed * yoff / d

	action = "Shoot"
	cannot_pick_up = player.tm_player

	drive_shot = FALSE
	newk_shot = FALSE
	Ball.launch_ball(0)			# Set up spin vector.
	Rules.inc_shot(player.tm_player)
	user_scorer = player.control

#/******************************************************************************
#*****************************************************************************/

# int shoot_decide(match_player *player)
@warning_ignore("integer_division")
static func shoot_decide(player: match_player) -> int:
	flag = FALSE
	var goal_x: float
	if ball_poss <= 11:
		goal_x = pitch_len
	else:
		goal_x = 0
	var xoff: float = goal_x - ballx
	var yoff: float = cntspot_y - bally
	var range: int = int(Maths.calc_dist(xoff, yoff))
	if range < 1:
		range = 1

	if player.tm_srng:
		if user_controlled:
			# Big shot!
			flag = TRUE			# in shooting range!
			pass_type = -1
		else:
			if plr_facing_goal(xoff, yoff, player):
				# Big shot!
				flag = TRUE			# in shooting range!
				pass_type = -1
			else:
				pass_type = in_kicking_range(player, xoff, yoff)
				if user_controlled and pass_type == 5:
					pass_type = -1

				if not pass_type:
					flag = FALSE
				else:
					flag = TRUE			# any dir shot.

	if flag:
		# He's in range!

		if (not user_controlled) and (not must_shoot):
			var opps: int = (10000 / range) + (opponents_near_holder * (16 + ((128 - player.tm_flair) / 4))) - (16 + (player.tm_flair / 3))
			if opps < MIN_SHOOT_PROB:
				opps = MIN_SHOOT_PROB
			if seed > opps and not first_time_it:
				return FALSE
		return TRUE

	if player.tm_leave:				# He cannot touch ball again!
		must_pass = TRUE

	return FALSE

#/******************************************************************************
#*****************************************************************************/

# int head_shoot_decide(match_player *player)
@warning_ignore("integer_division")
static func head_shoot_decide(player: match_player) -> int:
	flag = FALSE
	var goal_x: float

	if player.tm_player <= 11:
		goal_x = pitch_len
	else:
		goal_x = 0

	var xoff: float = goal_x - ballx
	var yoff: float = cntspot_y - bally
	var range: int = int(Maths.calc_dist(xoff, yoff))
	if range < 1:
		range = 1

	if in_header_rng:
		# He's in range!

		var opps: int = (5000 / range) + (opponents_near_holder * 32)
		if opps < MIN_SHOOT_PROB:
			opps = MIN_SHOOT_PROB
		if seed > opps:
			return FALSE

		# Fire shot!
		cannot_pick_up = -ball_poss
		BallInt.holder_lose_ball()
		ball_inair = TRUE
		Ball.new_shot(player.tm_player)
		var r: Array = aim_shot_at_goal(player, xoff, yoff, range)
		xoff = r[0]; yoff = r[1]
		var d: float = Maths.calc_dist(xoff, yoff)
		Ball.stop_ball_spin()

		ballzdis = ballzdis - 1.4
		ballxdis = (xoff * (12 + (player.tm_pow) / 4)) / (d * 3.4)
		ballydis = (yoff * (12 + (player.tm_pow) / 4)) / (d * 3.4)

		Actions.init_anim(player, MC_S_HEAD)

		Ball.launch_ball(0)			# Set up spin vector.

		Audio.play_fx(PS_HARDHEAD, ballx, bally)
		return TRUE
	return FALSE

#/******************************************************************************
#*****************************************************************************/

# qsort comparators. In C they receive pointers to the array elements and read
# the first int/short of the element; here they receive the element itself (an
# int, or an Array row whose element [0] is the key).  Use with
# Array.sort_custom(func(a, b): return sort_xxx(a, b) < 0).

# int sort_less_than(const void *op1, const void *op2)
@warning_ignore("integer_division")
static func sort_less_than(op1, op2) -> int:
	var p1: int = op1[0] if op1 is Array else op1
	var p2: int = op2[0] if op2 is Array else op2
	return (p1 - p2)

#/******************************************************************************
#*****************************************************************************/

# int sort_greater_than(const void *op1, const void *op2)
@warning_ignore("integer_division")
static func sort_greater_than(op1, op2) -> int:
	var p1: int = op1[0] if op1 is Array else op1
	var p2: int = op2[0] if op2 is Array else op2
	return (p2 - p1)

#/******************************************************************************
#*****************************************************************************/

# int sort_soonest(const void *op1, const void *op2)
@warning_ignore("integer_division")
static func sort_soonest(op1, op2) -> int:
	var p1: int = s16(op1[0] if op1 is Array else op1)
	var p2: int = s16(op2[0] if op2 is Array else op2)
	return (p1 - p2)

#/******************************************************************************
#*****************************************************************************/

# float kicking_dist(match_player *player,float x,float y,float d)
@warning_ignore("integer_division")
static func kicking_dist(player: match_player, x: float, y: float, d: float) -> float:
	# Calculate back-heel distance...
	var dist: float = MIN_PASS_DIST + float(player.tm_pow) / 3.6

	# Calculate difference range of 2(ahead) to 1(behind)...
	var dif: float = (player.tm_xdis * x / d) + (player.tm_ydis * y / d)
	var kd: float = dist * (2.0 + dif) / 2
	return kd

#/******************************************************************************
#*****************************************************************************/

# int in_kicking_range(match_player *player,float x,float y)
@warning_ignore("integer_division")
static func in_kicking_range(player: match_player, x: float, y: float) -> int:
	var d: float = Maths.calc_dist(x, y)
	x = x / d
	y = y / d

	# Calculate back-heel distance...
	var dist: float = MIN_PASS_DIST + float(player.tm_pow) / 3.6

	# Calculate difference range of 2(ahead) to 1(behind)...
	var dif: float = (player.tm_xdis * x) + (player.tm_ydis * y)
	var kd: float = dist * (1.5 + (dif / 2))

	if dif > KICK_AHEAD_ANG:
		# Straight ahead...
		if d > dist * 4:
			return 0
		else:
			if d > dist * 2:
				return -1
			else:
				return 5
	else:
		# Different dir...
		if d > kd:
			return FALSE
		else:
			var nx: float = (x * player.tm_xdis) + (y * player.tm_ydis)
			var ny: float = (y * player.tm_xdis) - (x * player.tm_ydis)
			return 1 + get_dir(nx, ny)

#/******************************************************************************
#*****************************************************************************/

# int can_i_pass(match_player *player)
@warning_ignore("integer_division")
static func can_i_pass(player: match_player) -> int:
	var p: int = pass_type
	if p > 6 and p < 9:
		p = p - 6
	else:
		if p > 0 and p < 4:
			p = 4 - p
		else:
			return pass_type		# Forward or diagonal pass requires no special ability!

	if player.tm_flair > (p * seed * 0.5):
		return pass_type			# Skillfull enough to see move!
	else:
		return FALSE

#/******************************************************************************
#*****************************************************************************/

# int pass_decide(match_player *player,char cross=FALSE)
@warning_ignore("integer_division")
static func pass_decide(player: match_player, cross: int = FALSE) -> int:
	var angle: int
	# int passee_tab[10][3]  (one spare row here: in C an 11th candidate would overrun the stack array)
	var passee_tab: Array = _narr([11, 3], 0)
	var passees: int = 0
	var vm: int
	if (bi(not player.tm_act) == THROW_ACT) and (ball_inair):		# (sic) (!tm_act)==THROW_ACT
		vm = VISION_MULT * 2 / 3
	else:
		vm = VISION_MULT

	var x: int
	var y: int
	var d: int
	var t: int
	if player.tm_player > 11:
		t = 22 - 1		  		#team B
	else:
		t = 11 - 1				#team A

	#/************/

	if want_pass:
		# Try guy shouting for pass...
		var i: int = want_pass - 1

		if ((ball_poss != KP_A and ball_poss != KP_B)
			or not kopp_around(int(teams[want_pass - 1].tm_x), int(teams[want_pass - 1].tm_y), want_pass)):
			if ((teams[i].control)
				or (plr_facing(teams[i].tm_x - ballx, teams[i].tm_y - bally, player))
				or (set_piece_on and player.tm_act != THROW_ACT)):
				x = int(teams[i].tm_x - ballx)
				y = int(teams[i].tm_y - bally)
				d = int(Maths.calc_dist(x, y))
				if (ball_in_hands) and (d < 30.0 * prat):
					# In throwing range!
					passee_tab[passees][1] = i + 1
					passee_tab[passees][2] = pass_type
					passees += 1
					# Add prospective passee!
				else:
					pass_type = in_kicking_range(player, x, y)
					pass_type = can_i_pass(player)

					if (pass_type) and (not ball_in_hands):
						# Can kick that distance...
						passee_tab[passees][1] = i + 1
						passee_tab[passees][2] = pass_type
						passees += 1
						# Add prospective passee!
					else:
						if (cross and not ball_in_hands and
							d <= (player.tm_vis * vm * 1.4) and d > (prat * 8)):
							if ((ball_poss < 12 and (teams[i].tm_x) > pitch_len - (prat * 18))
								or (ball_poss > 11 and (teams[i].tm_x) < prat * 18)):
								# In eighteen yard box!
								angle = cross_angle(teams[ball_poss - 1].tm_xdis,
													teams[ball_poss - 1].tm_ydis, x, y)

								if angle == 1:
									# Kicking at 90 degrees left...
									pass_type = 16
									passee_tab[passees][1] = i + 1
									passee_tab[passees][2] = pass_type
									passees += 1
								else:
									if angle == 2:
										# Kicking at 90 degrees right...
										pass_type = 17
										passee_tab[passees][1] = i + 1
										passee_tab[passees][2] = pass_type
										passees += 1

	#/************/

	var i: int = t
	while i > t - 11:
		if player.tm_player != i + 1:
			# Not man on ball!
			if ((ball_poss != KP_A and ball_poss != KP_B)
				or not kopp_around(int(teams[i].tm_x), int(teams[i].tm_y), i)):
				if (teams[i].tm_act <= TURN_ACT) and (teams[i].guy_on > 0) and (want_pass - 1 != i):
					# Not Busy!
					x = int(teams[i].tm_x - ballx)
					y = int(teams[i].tm_y - bally)
					d = int(Maths.calc_dist(x, y))
					pass_type = in_kicking_range(player, x, y)
					pass_type = can_i_pass(player)

					if (pass_type and not ball_in_hands) or ((ball_in_hands) and (d < 20.0 * prat)):
						# Can kick reach him...
						if d <= (player.tm_vis * vm):
							# In visible range!
							if (d / 2 < (MIN_PASS_DIST + float(player.tm_pow) / 3.6) and not ball_in_hands) or angle_of_vis(player, x, y, teams[i].tm_dist, cross):
								# Within angle of vision 90!
								if not (((i == KP_A - 1) or (i == KP_B - 1)) and (teams[i].tm_dist < KP_MIN_PASS_DIST)):
									passee_tab[passees][1] = i + 1
									passee_tab[passees][2] = pass_type
									passees += 1
								# Add prospective passee!
					else:
						if (cross and not ball_in_hands and
							d <= (player.tm_vis * vm * 1.4) and d > (prat * 8)):
							if ((ball_poss < 12 and (teams[i].tm_x) > pitch_len - (prat * 18))
								or (ball_poss > 11 and (teams[i].tm_x) < prat * 18)):
								angle = cross_angle(teams[ball_poss - 1].tm_xdis,
													teams[ball_poss - 1].tm_ydis, x, y)

								if angle == 1:
									# Kicking at 90 degrees left...
									pass_type = 16
									passee_tab[passees][1] = i + 1
									passee_tab[passees][2] = pass_type
									passees += 1
								else:
									if angle == 2:
										# Kicking at 90 degrees right...
										pass_type = 17
										passee_tab[passees][1] = i + 1
										passee_tab[passees][2] = pass_type
										passees += 1
		i -= 1

	#//********************************//
	#// Passee table has been created. //
	#//********************************//

	# Give preference values to each candidate...
	# Low being best!

	var pas: int = 0


	if passees:
		var team_mate: int

		if not user_controlled:
			# Computer decision only...

			var opps: int
			var tmx: float
			var px: float = player.tm_x

			for p in range(0, passees):

				team_mate = passee_tab[p][1] - 1

				# Get opponents near team-mate...
				opps = opp_around(int(teams[team_mate].tm_x),
									 int(teams[team_mate].tm_y), team_mate)

				# Passer takes this into consideration...
				opps = 64 + (opps * (64 + (player.tm_flair / 2)))

				# Optimum passing distance is around 10 yards...
				# Anything below should start to lessen likelyhood of passing...
				if teams[team_mate].tm_dist < OPTIMUM_PASS:
					opps = int(opps + (OPTIMUM_PASS - teams[team_mate].tm_dist))

				# But, am I under threat and have to get rid of ball???
				if not set_piece_on and match_mode > GOAL_KICK_BR and match_mode < GOAL_KICK_TL:
					opps -= opponents_near_holder * (32 + (player.tm_flair / 2))
				else:
					opps -= 64

				# Is he making run???
				if want_pass == (team_mate + 1):
					opps -= teams[team_mate].tm_flair

				# If in shooting range then less chance of passing...(greed factor)!
				if player.tm_srng:
					opps += GREED_FACTOR

				tmx = teams[team_mate].tm_x

				if team_mate > 11:
					# Team B...
					if tmx > px:
						# Passing back...
						opps = int(opps + (tmx - px) * player.tm_flair / 128)
					else:
						# Passing forward, less difference...
						opps = int(opps + ((tmx - px) / 5) * player.tm_flair / 128)
				else:
					# Team A...
					if tmx < px:
						# Passing back...
						opps = int(opps + (px - tmx) * player.tm_flair / 128)
					else:
						# Passing forward, less difference...
						opps = int(opps + ((px - tmx) / 5) * player.tm_flair / 128)

				# The more flair less likelyhood of passing especially if opps near passee!

				var op_p: int
				if team_mate < 11:
					op_p = 11
				else:
					op_p = 0

				# Get vectors for pass!
				var tx: float = teams[team_mate].tm_x - ballx
				var ty: float = teams[team_mate].tm_y - bally
				var td: float = teams[team_mate].tm_dist
				var ang: float = 0
				var ox: float
				var oy: float
				var od: float
				var a: float
				tx = tx / td
				ty = ty / td

				# Any opponents in path off prospective passed ball?

				for o in range(op_p, op_p + 11):
					if (teams[o].guy_on) and (teams[o].tm_dist < td * 1.25):				# Inside pass range!
						ox = teams[o].tm_x - ballx
						oy = teams[o].tm_y - bally
						od = teams[o].tm_dist
						ox = ox / od
						oy = oy / od
						a = ((tx * ox) + (ty * oy))
						if a > 0:
							a = a * a * (96 + (player.tm_flair / 2)) * td / od
							#							ang+=a*(player->tm_flair/64);
							ang += a * (player.tm_flair / 32)

				if passee_tab[p][2] == 16 or passee_tab[p][2] == 17:
					# Crossing over opps...
					opps = int(opps + ang / 5)
					opps = opps / 4
				else:
					opps = int(opps + ang)

				passee_tab[p][0] = opps		# Set preference level!

				Maths.af_randomize()

				# If straight ahead pass and need to chip...
				if passee_tab[p][2] == 5 and (ang > seed / 2 or (user_controlled and chip_pass)):
					# Chip over...
					passee_tab[p][2] = -1
		else:
			# User preference is for distance in facing direction only...

			var tx: float
			var ty: float
			var dif: float
			var px: float = player.tm_x
			var py: float = player.tm_y
			var xf: float = player.tm_xdis
			var yf: float = player.tm_ydis
			var min_d: float = 2000
			var pr: int = -1

			for p in range(0, passees):
				passee_tab[p][0] = 100
				team_mate = passee_tab[p][1] - 1

				tx = teams[team_mate].tm_x - px
				ty = teams[team_mate].tm_y - py

				if plr_facing(tx, ty, player):
					# Facing towards team-mate...
					d = int(Maths.calc_dist(tx, ty))

					if d < min_d:
						# Closest...
						min_d = d
						pr = p

			if pr >= 0:
				passee_tab[pr][0] = 0

		# Sort passee table in order of preference...
		# qsort(passee_tab,passees,sizeof(int)*3,sort_less_than);
		var sorted_tab: Array = passee_tab.slice(0, passees)
		sorted_tab.sort_custom(func(op1, op2): return sort_less_than(op1, op2) < 0)
		for k in range(0, passees):
			passee_tab[k] = sorted_tab[k]

		if user_controlled:
			# Take first team-mate on table...
			pas = passee_tab[0][1]
			pass_type = passee_tab[0][2]
		else:
			# Random selection weighted towards first in table...

			var chance: int

			pas = 0
			var p: int = 0
			while p < passees:
				Maths.af_randomize()
				chance = passee_tab[p][0]

				if chance < MAX_PASS_PROB:
					chance = MAX_PASS_PROB
				else:
					if chance > MIN_PASS_PROB:
						chance = MIN_PASS_PROB

				if set_piece_on:
					chance = chance / 2

				if seed > chance:
					# Choose this guy to pass to!
					pas = passee_tab[p][1]
					pass_type = passee_tab[p][2]
					p = passees + 1
				p += 1

		if not pas and (must_pass or user_controlled):
			# Must choose!
			pas = passee_tab[0][1]
			pass_type = passee_tab[0][2]
	else:
		# Absolutely no one to pass to...
		if (must_pass) or (user_controlled):
			pas = 0

	must_pass = FALSE

	if pas > 0:
		# He is passing to someone...

		d = int(Maths.calc_dist(teams[pas - 1].tm_x - ballx, teams[pas - 1].tm_y - bally))

		if ball_in_hands and (player.tm_player == KP_A or player.tm_player == KP_B):
			if opp_around(int(teams[pas - 1].tm_x), int(teams[pas - 1].tm_y), pas):
				# Don't pass it out... (opponents around!)
				pas = 0
			else:
				# Keeper must throw or something...
				if d < prat * 10:
					pass_type = 9		# Roll it.
				else:
					if d < prat * 20:
						pass_type = 10		# Throw it.
					else:
						pass_type = 11		# Halfvoll it.
		else:
			if (ball_in_hands) and (teams[ball_poss - 1].tm_act == THROW_ACT):
				# Player must throw...
				if d < prat * 15:
					pass_type = 12		# Throw short.
				else:
					pass_type = 13		# Throw Long.
			else:
				if heading_ball:
					pass_type = 15
	return pas


#/******************************************************************************
#*****************************************************************************/

# void process_comments()
@warning_ignore("integer_division")
static func process_comments() -> void:
	if want_pass_stat != last_touch:
		# His team_mate does not have ball anymore...
		if want_pass:
			teams[want_pass - 1].tm_comm = 0
			teams[want_pass - 1].tm_ccnt = 0
			reset_ideas(teams[want_pass - 1])

#/******************************************************************************
#*****************************************************************************/

# void init_speech(int p,int comm,int t)
@warning_ignore("integer_division")
static func init_speech(p: int, comm: int, t: int) -> void:
	speech_tab[p - 1].say = comm
	if t:
		speech_tab[p - 1].cnt = t
	else:
		speech_tab[p - 1].cnt = SPEECH_SECS * game_speed

#/******************************************************************************
#*****************************************************************************/

# void process_speech()
@warning_ignore("integer_division")
static func process_speech() -> void:
	for i in range(1, players + 3):
		if speech_tab[i - 1].cnt:
			speech_tab[i - 1].cnt -= 1

#/******************************************************************************
#*****************************************************************************/

# void player_comment(match_player *player)
@warning_ignore("integer_division")
static func player_comment(player: match_player) -> void:
	if player.tm_comm:
		player.tm_ccnt = s16(player.tm_ccnt - 1)
		if (not player.tm_ccnt) or (player.tm_act > TURN_ACT):
			player.tm_comm = 0
			if want_pass == player.tm_player:
				want_pass = 0

#/******************************************************************************
#*****************************************************************************/

# void tackle_decide(match_player *player)
@warning_ignore("integer_division")
static func tackle_decide(player: match_player) -> void:
	pass

#/******************************************************************************
#*****************************************************************************/

# void steal_decide(match_player *player)
@warning_ignore("integer_division")
static func steal_decide(player: match_player) -> void:
	pass

#/******************************************************************************
#*****************************************************************************/

# void block_decide(match_player *player)
@warning_ignore("integer_division")
static func block_decide(player: match_player) -> void:
	pass

#/******************************************************************************
#*****************************************************************************/

# void user_free_ball(match_player *player)
@warning_ignore("integer_division")
static func user_free_ball(player: match_player) -> void:
	player.tm_stopped = FALSE

#/******************************************************************************
#*****************************************************************************/

# void other_interceptor(match_player *player)
@warning_ignore("integer_division")
static func other_interceptor(player: match_player) -> void:
	if receiver_a == player.tm_player:
		receiver_a = FALSE
	if receiver_b == player.tm_player:
		receiver_b = FALSE

	player.tm_notme = 1 + player.tm_flair / 16

#/******************************************************************************
#*****************************************************************************/

# void free_ball(match_player *player)
@warning_ignore("integer_division")
static func free_ball(player: match_player) -> void:
	player.tm_stopped = FALSE
	if (not dead_ball_cnt) and (not player.tm_leave):
		if not ball_out_of_play:
			if (player.tm_player == KP_A) or (player.tm_player == KP_B):
				# Goal Keeper...

				if ((player.tm_player == KP_A and keeper_a_in_box)
					or (player.tm_player == KP_B and keeper_b_in_box)):

					if shot_pending > 0 and not shot_acknowledged and player.tm_dist < prat * 50:
						if (cannot_pick_up <= 0 or ((player.tm_player < 12 and cannot_pick_up > 11)
							or (player.tm_player > 11 and cannot_pick_up < 12))):
							if EURO96:
								# This looks silly but leave for time being...
								if penalty_shot and user_controlled:
									if uf1 or uf2:
										go_to_save_path(player)
								else:
									go_to_save_path(player)
							else:
								go_to_save_path(player)

					else:
						if player.tm_dist < 80 and ball_inair:
							# Ball is quite close...
							go_to_save_path(player)

			if (not penalty_game) and (player.tm_act != SAVE_ACT) and (player.int_move != I_SAVE_WAIT):
				if (thinking(player)) and (player.tm_act <= TURN_ACT):
					if player.tm_off:
						# In offside position, must get out...
						run_back(player)

				if not interceptor_a:
					if near_path_a == player.tm_player:
						if go_to_path(near_path_a):
							#							other_interceptor(player);
							#						else
							if auto_users_a and not player.control:
								User.reselect_a()
								Actions.user_conts(player)

				if not interceptor_b:
					if near_path_b == player.tm_player:
						if go_to_path(near_path_b):
							#							other_interceptor(player);
							#						else
							if auto_users_b and not player.control:
								User.reselect_b()
								Actions.user_conts(player)

#/******************************************************************************
#*****************************************************************************/

# void out_of_vis(match_player *player)
@warning_ignore("integer_division")
static func out_of_vis(player: match_player) -> void:
	pass

#/******************************************************************************
#*****************************************************************************/

# void range_flags(match_player *player)
@warning_ignore("integer_division")
static func range_flags(player: match_player) -> void:
	var x: float = player.tm_x
	var y: float = player.tm_y
	var d: float

	if player.tm_player > 11:
		# B
		d = Maths.calc_dist(x, cntspot_y - y)
	else:
		# A
		d = Maths.calc_dist(pitch_len - x, cntspot_y - y)

	if d < MIN_HEADER_RNG + (prat * player.tm_pow / 8):
		in_header_rng = TRUE
	else:
		in_header_rng = FALSE

	if d < (MIN_SHOOT_DIST + (float(player.tm_pow) * 3)):
		in_shot_rng = TRUE
	else:
		in_shot_rng = FALSE

#/******************************************************************************
#*****************************************************************************/

# Is guy with ball in "crossing area".
# Which is a diagonal line from goal post to nearest sideline.

# void cross_pos(match_player *player)
@warning_ignore("integer_division")
static func cross_pos(player: match_player) -> void:
	in_cross_area = FALSE
	if bally > bot_post_y:
		if player.tm_player > 11:
			if ballx < (bally - bot_post_y):
				# Within diagonal from bot. left post to sideline!
				in_cross_area = TRUE
		else:
			if (pitch_len - ballx) < (bally - bot_post_y):
				# Within diagonal from bot. right post to sideline!
				in_cross_area = TRUE
	else:
		if bally < top_post_y:
			if player.tm_player > 11:
				if ballx < (top_post_y - bally):
					# Within diagonal from top left post to sideline!
					in_cross_area = TRUE
			else:
				if (pitch_len - ballx) < (top_post_y - bally):
					# Within diagonal from top right post to sideline!
					in_cross_area = TRUE

#/******************************************************************************
#*****************************************************************************/

# void set_pos_flags(match_player *player)
@warning_ignore("integer_division")
static func set_pos_flags(player: match_player) -> void:
	cross_pos(player)
	range_flags(player)

#/******************************************************************************
#*****************************************************************************/

# void user_got_ball(match_player *player)
@warning_ignore("integer_division")
static func user_got_ball(player: match_player) -> void:
	var p: int = 0
	set_pos_flags(player)

	if player.tm_act == STAND_ACT:
		Actions.user_spec_kick(player)
	else:

		if uf2 and um:
			# Pass in dir!
			var p_1: int = (pass_decide(player, in_cross_area))		# (C: inner 'int p' shadows the outer p)
			if pass_type == 16 or pass_type == 17:
				make_pass(player, p_1, TRUE)
			else:
				if not p_1:
					pass_type = 5	# Forward tap...
				spec_kick_type = SPACT_FPASS
				setp_kick_x = player.tm_xdis
				setp_kick_y = player.tm_ydis
				make_pass(player, p_1, FALSE)
		else:
			if uf1 and um:
				# Try shooting...
				if shoot_decide(player):
					make_shoot(player)
				else:
					# Try punt...
					if punt_decide(player):
						make_punt(player)
					else:
						# Try high pass to head...
						chip_pass = TRUE
						var p_2: int = (pass_decide(player, FALSE))		# (C: inner 'int p' shadows the outer p)
						if p_2 and (pass_type == 16 or pass_type == 17 or pass_type == -1):
							make_pass(player, p_2, TRUE)
						else:
							p_2 = 0
							chip_pass = FALSE
							pass_type = -1	# Forward tap...
							spec_kick_type = SPACT_FPASS
							setp_kick_x = player.tm_xdis
							setp_kick_y = player.tm_ydis
							make_pass(player, p_2, FALSE)

#/*
#		else
#		{
#			if (must_punt)
#				if (punt_decide(player))
#					make_punt(player);
#			else
#			{
#				if (uf1)
#				{
#// He has pressed front fire button (1)!
#// PUNT!
#					if (punt_decide(player))
#						make_punt(player);
#					else
#					{
#// SHOOT!
#						if (player->tm_srng)
#						{
#							shoot_decide(player);
#							make_shoot(player);
#						}
#						else
#						{
#							must_pass=TRUE;
#							chip_pass=TRUE;
#							int p=pass_decide(player,FALSE);
#							make_pass(player,p,FALSE);
#						}
#					}
#				}
#				else
#				{
#					if (uf2)
#					{
#// He has pressed top fire button (2)!
#						must_pass=TRUE;
#// CROSS!
#						if (in_cross_area)
#						{
#							p=(pass_decide(player,TRUE));
#							if (p)
#								make_pass(player,p,TRUE);
#						}
#						if (!p)
#						{
#// PASS!
#							p=(pass_decide(player,FALSE));
#							if (p)
#								make_pass(player,p,FALSE);
#						}
#					}
#				}
#			}
#		}
#	}
#*/

	set_piece_on = FALSE

#/******************************************************************************
#*****************************************************************************/

# void got_ball(match_player *player)
@warning_ignore("integer_division")
static func got_ball(player: match_player) -> void:
	var p: int = 0

	if (player.tm_player == KP_A) or (player.tm_player == KP_B):

		#/****************
		#** Goal-Keeper	**
		#****************/

		# PUNT!
		if punt_decide(player):
			make_punt(player)
		else:
			# PASS!
			var p_1: int = (pass_decide(player))		# (C: inner 'int p' shadows the outer p)
			if p_1:
				make_pass(player, p_1)
			else:
				if ((player.tm_player == KP_A and keeper_a_in_box)
					or (player.tm_player == KP_B and keeper_b_in_box)):
					# Can pick ball up...

					if not ball_in_hands:
						if ((cannot_pick_up <= 0)
							or (cannot_pick_up < 12 and ball_poss > 11 and keeper_b_in_box)
							or (cannot_pick_up > 11 and ball_poss < 12 and keeper_a_in_box)):

							if opp_around(int(ballx), int(bally), player.tm_player):
								BallInt.holder_lose_ball()
								keep_dive = TRUE
								go_to_save_path(player, TRUE)
							else:
								Actions.init_pickup_act(player)
						else:
							if player.tm_poss:
								must_punt = TRUE
							if punt_decide(player):
								make_punt(player)
							else:
								# RUN!
								make_run(player)
				else:
					# Can't touch ball with hands...
					must_punt = TRUE

	else:

		#/***********
		#** PLAYER **
		#***********/

		# Not taking throw!

		set_pos_flags(player)
		# SHOOT!
		if shoot_decide(player):
			make_shoot(player)
		else:
			# CROSS!
			if in_cross_area:
				p = (pass_decide(player, TRUE))
				if p:
					if pass_type == 16 or pass_type == 17:
						make_pass(player, p, TRUE)
					else:
						make_pass(player, p, FALSE)
			if not p:
				# PASS!
				p = (pass_decide(player))
				if p:
					make_pass(player, p)
				else:
					# PUNT!
					if punt_decide(player):
						make_punt(player)
					else:
						# RUN!
						make_run(player)
	set_piece_on = FALSE

#/******************************************************************************
#*****************************************************************************/

# int help_chance(match_player *player)
@warning_ignore("integer_division")
static func help_chance(player: match_player) -> int:
	var f: int = 64 + (player.tm_flair / 2)
	var r: float
	var xd: float

	# Less calculated range if pass is to be made up-field...
	if player.tm_player > 11:
		# Team B...
		xd = player.tm_x - ballx
		if xd > 0:
			xd = xd * 2
	else:
		# Team A...
		xd = player.tm_x - ballx
		if xd < 0:
			xd = xd * 2

	r = Maths.calc_dist(xd, bally - player.tm_y) / (prat * 2)
	var help: int

	if support_me:
		help = int(512 - (r * r))
	else:
		help = int(32 + (opponents_near_holder * 80 * f / 128)
					- (opp_around(int(player.tm_x), int(player.tm_y), player.tm_player) * 64 * f / 128)
					- (r * r))

	# Dead ball situation...

	return help

#/******************************************************************************
#*****************************************************************************/

# void we_have_ball(match_player *player)
@warning_ignore("integer_division")
static func we_have_ball(player: match_player) -> void:
	if (player.tm_player != KP_A and player.tm_player != KP_B and not player.tm_stopped
		and match_mode != PEN_KICK_A and match_mode != PEN_KICK_B):
		if (thinking(player)) and (player.tm_act <= TURN_ACT):
			if player.tm_off:
				# In offside position, must get out...
				run_back(player)
			else:
				if not want_pass:
					var help: int = help_chance(player)
					if help < MIN_HELP_CHANCE:
						help = MIN_HELP_CHANCE
					if seed <= help:
						# Ask for Pass!
						if player.tm_dist < CALL_DIST:
							#				if (angle_of_vis(player,ballx-player->tm_x,bally-player->tm_y,player->tm_dist,FALSE))
							want_pass = player.tm_player
							want_pass_stat = ball_poss
							player.tm_ccnt = 40
							player.tm_comm = -SAY_PASS
							reset_ideas(player)
							player.int_move = I_RUN_ON
							player.int_cnt = 40

							if in_cross_area:
								# (C: these block-local x,y shadow the x,y declared below)
								var x_1: float = player.tm_x
								var y_1: float = player.tm_y
								var i: int = player.tm_player

								if ((i < 12) and (x_1 > (pitch_len - (prat * 15))) and (y_1 > (cntspot_y - (prat * 18)))
									and (y_1 < (cntspot_y + (prat * 18)))
									and (teams[i].tm_dist > (prat * 20))):

									player.tm_comm = -SAY_CROSS

								if ((i > 11) and (x_1 < (prat * 15)) and (y_1 > (cntspot_y - (prat * 18)))
									and (y_1 < (cntspot_y + (prat * 18)))
									and (teams[i].tm_dist > (prat * 20))):

									player.tm_comm = -SAY_CROSS
							# Run towards opponents penalty spot...
							var x: float
							var y: float
							var d: float
							if player.tm_player < 12:
								x = pitch_len - ballx
							else:
								x = -ballx

							y = cntspot_y - bally

							d = Maths.calc_dist(x, y)

							# How far is half way to goal...

							var kd: float = kicking_dist(teams[ball_poss - 1], x, y, d) - (prat * 2)
							if d / 2 < kd:
								Actions.init_run_act(player, ballx + x / 2, bally + y / 2, FALSE)
							else:
								Actions.init_run_act(player, ballx + (x / d * kd), bally + (y / d * kd), FALSE)
							player.int_cnt = player.go_cnt
							player.tm_ccnt = player.go_cnt
						else:
							if not support_me:
								player.tm_ccnt = 40
								player.tm_comm = -SAY_GIVE

#/******************************************************************************
#*****************************************************************************/

# int in_close(match_player *player)
@warning_ignore("integer_division")
static func in_close(player: match_player) -> int:
	if player.tm_dist < DRIB_DANGER_AREA:
		return TRUE
	else:
		return FALSE

#/*****************************************************************************
#*****************************************************************************/

# int can_close_down(match_player *player)
@warning_ignore("integer_division")
static func can_close_down(player: match_player) -> int:
	var p: int = player.tm_player
	if (nearest_a == p) or (nearest_b == p):
		return TRUE
	else:
		return FALSE

#/*****************************************************************************
#*****************************************************************************/

# void close_him_down(match_player *player)
@warning_ignore("integer_division")
static func close_him_down(player: match_player) -> void:
	player.int_move = I_CLOSE_DOWN
	player.int_cnt = (player.tm_flair / 4)
	if not go_to_path(player.tm_player):
		other_interceptor(player)
	action = "Close Down"

#/*****************************************************************************
#*****************************************************************************/

# void force_error(match_player *player)
@warning_ignore("integer_division")
static func force_error(player: match_player) -> void:
	if ((player.tm_player < 12 and not auto_users_a)
		or (player.tm_player > 11 and not auto_users_b)):
		# No team users so computer must control this guy...

		if player.tm_dist < STEAL_DIST or teams[ball_poss - 1].tm_act == TACKLE_ACT:
			if not go_to_path(player.tm_player):
				other_interceptor(player)
			#			else
			#				player->int_move=I_STEAL;
		else:
			var chance: int = 32
			if player.tm_player < 12:

				# The further up the park, the more chance of direct tackling!

				chance = int(chance - ((pitch_len - player.tm_x) / 48))
			else:
				chance = int(chance - (player.tm_x / 48))

			if (chance <= seed and teams[ball_poss - 1].tm_act != TACKLE_ACT
				and teams[ball_poss - 1].int_move != I_GET_UP):
				get_tack_path(player)
			else:
				go_to_between(player.tm_player)	# get yourself between him and goal!

#/*****************************************************************************
#*****************************************************************************/

# void forceful_retrieve(match_player *player)
@warning_ignore("integer_division")
static func forceful_retrieve(player: match_player) -> void:
	if ((player.tm_player < 12 and not auto_users_a)
		or (player.tm_player > 11 and not auto_users_b)):
		# No team users so computer must control this guy...
		get_tack_path(player)

#/******************************************************************************
#*****************************************************************************/

# void go_to_side(match_player *player)
# Send player to the side off opponent with ball...
@warning_ignore("integer_division")
static func go_to_side(player: match_player) -> void:
	# His intention is to intercept ball.
	# Therefore his flair determines no. of turns before rethink!

	var ff: int = 33 - (player.tm_flair / 4)
	player.int_move = I_INTERCEPT		# Intercept ball!
	player.int_cnt = ff						# Flair factor.

	var dx: float = teams[ball_poss - 1].tm_xdis
	var dy: float = teams[ball_poss - 1].tm_ydis

	var x: float = (ballx - player.tm_x) / player.tm_dist			# vector to ball...
	var y: float = (bally - player.tm_y) / player.tm_dist

	# Which side to go to...???
	if (x * dy) > (y * dx):
		x = -dy		# 90 degrees clockwise...
		y = dx
	else:
		x = dy		# 90 degrees anti-clockwise...
		y = -dx

	x = ballx + (x * prat)
	y = bally + (y * prat)

	Actions.init_run_act(player, x, y, TRUE)				#Go to path point!

#/******************************************************************************
#*****************************************************************************/

# void go_to_between(int p_num)
# Send player(p_num) to intersection point between ball path and goal centre.
# If he cannot meet ball then best try!
@warning_ignore("integer_division")
static func go_to_between(p_num: int) -> void:
	var x: int = 0
	var y: int = 0
	var z: int
	var d: int
	var px: float = teams[p_num - 1].tm_x
	var py: float = teams[p_num - 1].tm_y
	var goal_x: float
	var rate: int = int(Actions.actual_spd(teams[p_num - 1]))

	action = "Between"

	if p_num < 12:
		goal_x = 0
	else:
		goal_x = pitch_len

	# His intention is to intercept ball.
	# Therefore his flair determines no. of turns before rethink!

	var ff: int = 33 - (teams[p_num - 1].tm_flair / 4)
	teams[p_num - 1].int_move = I_INTERCEPT		# Intercept ball!
	teams[p_num - 1].int_cnt = ff						# Flair factor.

	# (Watcom: the for-loop variable i is still in scope after the loop)
	var i: int = 1
	while i < 50:
		x = int(ball_pred_tab[i][0])
		y = int(ball_pred_tab[i][1])
		z = int(ball_pred_tab[i][2])
		d = int(Maths.calc_dist(goal_x - x, cntspot_y - y))
		if d < 1:
			d = 1

		x = int(x + (((goal_x - x) * BETWEEN_DIST) / d))
		y = int(y + (((cntspot_y - y) * BETWEEN_DIST) / d))

		if z <= PLAYER_HEIGHT:
			d = int(Maths.calc_dist(x - px, y - py))
			#			d=(int)(((float)d)/rate);					//How many steps?
			d = get_there_time(p_num, x, y)					#How many steps?
			if d <= i:
				# He can get there in time!
				Actions.init_run_act(teams[p_num - 1], x, y, TRUE)				#Go to path point!
				i = 60												# End For Loop!
		i += 1
	if i < 60:
		# He cant intersect!
		Actions.init_run_act(teams[p_num - 1], x, y, FALSE)			# run toward last.

#/******************************************************************************
#*****************************************************************************/

# void user_opp_has_ball(match_player *player)
@warning_ignore("integer_division")
static func user_opp_has_ball(player: match_player) -> void:
	if uf1:
		# Tackle opp.
		Actions.user_init_tackle(player)
	else:
		if uf2:
			# Steal from opp.
			if player.tm_dist < (STEAL_DIST / 4):
				Actions.init_steal_act(player)
			elif EURO96:
				# Burst_of_speed...
				var bt_old: int = burst_timer[user_controlled - 1]
				burst_timer[user_controlled - 1] = s16(bt_old - 1)
				if not bt_old:
					burst_timer[user_controlled - 1] = REAL_SPEED
				else:
					if not burst_timer[user_controlled - 1]:
						burst_timer[user_controlled - 1] = -1
		else:
			burst_timer[user_controlled - 1] = 0

#/******************************************************************************
#*****************************************************************************/

# void opp_has_ball(match_player *player)
@warning_ignore("integer_division")
static func opp_has_ball(player: match_player) -> void:
	if (player.tm_player == KP_A) or (player.tm_player == KP_B):

		#/****************
		#** Goal-Keeper	**
		#****************/

		if player.tm_player < 12:
			# KP_A...
			if (keeper_a_in_box) and (player.tm_dist < (prat * 4)) and (seed > player.tm_flair):	# DIVE_FEET_DIST=(prat*4)
				# Can dive for ball...
				keep_dive = TRUE
				go_to_save_path(player, TRUE)
		else:
			# KP_B...
			if (keeper_b_in_box) and (player.tm_dist < (prat * 4)) and (seed > player.tm_flair):	# DIVE_FEET_DIST=(prat*4)
				# Can dive for ball...
				keep_dive = TRUE
				go_to_save_path(player, TRUE)

	if true:

		#/***********
		#** PLAYER **
		#***********/

		if (ball_in_hands) or (ball_out_of_play):
			# Don't tackle keeper directly!
			pass
		else:
			if (((player.tm_pos) and (player.tm_pos <= close_in_number)
				and ((player.tm_player != KP_A) and (player.tm_player != KP_B)))
				or (player.tm_pos == 1)):
				# There's not too many guys going for opponent with ball!

				if in_close(player):
					# I am close enough to hassle!
					var d: int = s16(get_facing_opp_dir(player))

					if d == -1:
						# He has his back to me!
						if ((ball_speed < 1) and ((seed & 4)
							or (player.tm_player > 11 and ballx < cntspot_x)
							or (player.tm_player < 12 and ballx > cntspot_x))):

							# Try and go round a bit...
							go_to_side(player)
						else:
							if ((teams[ball_poss - 1].tm_act == TACKLE_ACT and teams[ball_poss - 1].go_cnt > EFFECTIVE_TACK)
								or teams[ball_poss - 1].int_move == I_GET_UP):
								force_error(player)
							else:
								go_to_between(player.tm_player)	# get yourself between him and goal!
					else:

						# He is not shielding ball!
						if d == 1:
							# He has his side to me!
							if (seed & 8) and (teams[ball_poss - 1].tm_act == TACKLE_ACT or teams[ball_poss - 1].int_move == I_GET_UP):
								# Opponent is not able to turn and avoid... (So go directly to ball!)
								force_error(player)
							else:
								if (player.tm_player != KP_A) and (player.tm_player != KP_B):
									# Not the keeper!
									forceful_retrieve(player)	# Tackle directly!
								else:
									force_error(player)
						else:

							# He is facing towards me!
							force_error(player)			# More patient style of attack!
				else:
					# Not in close enough!
					if can_close_down(player):

						# I can close him down!
						close_him_down(player)

#/******************************************************************************
#*****************************************************************************/

# void user_intelligence(match_player *player)
@warning_ignore("integer_division")
static func user_intelligence(player: match_player) -> void:
	if match_mode or not ball_poss:
		intelligence(player)
	else:
		var busy: int = 0
		if player.int_cnt:				#Is he busy?
			player.int_cnt = s16(player.int_cnt - 1)
			if player.int_cnt:
				busy = 1
			else:
				player.int_cnt = -1
				reset_ideas(player)

		if player.tm_act <= TURN_ACT:	# Player is standing or running or turning!
			if not busy:
				if not ball_poss:
					user_free_ball(player)
				else:
					if ball_poss == player.tm_player:
						user_got_ball(player)
					else:
						if (((ball_poss < 12) and (player.tm_player > 11))
							or ((ball_poss > 11) and (player.tm_player < 12))):
							user_opp_has_ball(player)

#/******************************************************************************
#*****************************************************************************/

# void offside_rule(match_player *player)
@warning_ignore("integer_division")
static func offside_rule(player: match_player) -> void:
	if player.tm_player < 12:
		# Team A...

		if ((not match_mode) and (not ball_poss and ball_released > 0) and (last_touch < 12)
			and (last_touch != player.tm_player) and (player.tm_off) and (not just_scored)
			and (ballx < player.tm_x)):
			#			 && (ballx<player->tm_x) && receiver_a==player->tm_player)
			# His team-mate has released ball and he is in an offside pos...

			Rules.init_offside(player)	# Does Linesman see it!
		else:
			if ((ball_poss < 12) and (player.tm_x > cntspot_x)
				and (can_be_offside) and (player.tm_x > (defense_b + prat)) and (not just_scored)):
				# Player is in opponents half, his opponent doesn't have ball and
				# in normal play, and no defenders behind.
				if not player.tm_off:
					player.tm_off = -1		# Potential Offside (get back).
			else:
				player.tm_off = FALSE	# Not offside.
	else:
		# Team B...
		if ((not match_mode) and (not ball_poss and ball_released < 0) and (last_touch > 11)
			and (last_touch != player.tm_player) and (player.tm_off) and (not just_scored)
			and (ballx >= player.tm_x)):
			#			 && (ballx>=player->tm_x) && receiver_b==player->tm_player)
			# His team-mate has released ball and he is in an offside pos...

			Rules.init_offside(player)	# Does Linesman see it!
		else:
			if ((ball_poss > 11 or not ball_poss) and (player.tm_x < cntspot_x)
				and (can_be_offside) and (player.tm_x < (defense_a - prat)) and (not just_scored)):
				# Player is in opponents half, his team mate has the ball
				# in normal play, and no defenders behind.

				if not player.tm_off:
					player.tm_off = -1		# Potential Offside (get back).
			else:
				player.tm_off = FALSE	# Not offside.

	if (player.tm_off == TRUE) and (not match_mode) and (not just_scored):
		# Linesman has indicated offside...
		# Is he interfering with play...
		if player.tm_dist < ref_strictness * 1.1:
			offside_now = TRUE
			Rules.init_foul(player.tm_player, FALSE, TRUE)	# Indirect F.K. for offside!
			player.tm_off = FALSE

#/******************************************************************************
#*****************************************************************************/

# void override(match_player *player)
@warning_ignore("integer_division")
static func override(player: match_player) -> void:
	if offside_on:
		offside_rule(player)

#/******************************************************************************
#*****************************************************************************/

# void remove_player(match_player *player)
@warning_ignore("integer_division")
static func remove_player(player: match_player) -> void:
	player.guy_on = FALSE
	if not player_being_subbed:
		hold_up_play = 4 * REAL_SPEED
		camera = sub_camera
		player_on_off = FALSE
		ref_wait = (160 - ref_strictness) * REAL_SPEED / 8

#/******************************************************************************
#*****************************************************************************/

# void init_off_int(match_player *player)
@warning_ignore("integer_division")
static func init_off_int(player: match_player) -> void:
	allow_replay = FALSE
	var tx: float = stadlist[setup.stadium].tunlx
	var ty: float = -stadlist[setup.stadium].tunlz
	var tly: float
	if ty > cntspot_y:
		ty += 60
	else:
		ty -= 60

	if player_on_off > 0 and Maths.calc_dist(tx - player.tm_x, ty - player.tm_y) < prat * 2:
		# In tunnel! (get off)!
		remove_player(player)
		player.tm_trap = 0
	else:
		player.draw_me = TRUE
		player.int_cnt = 600
		player.int_move = I_OFF

		if ty > cntspot_y:
			tly = pitch_wid
		else:
			tly = 0

		if player.tm_trap or Maths.calc_dist(tx - player.tm_x, tly - player.tm_y) < prat * 2:
			# At touch-line...(send him into tunnel)!
			if player_on_off < 0:
				# Coming on...
				player.int_move = 0
				reset_ideas(player)
				player_on_off = FALSE
				camera = sub_camera
				allow_replay = TRUE
			else:
				player.tm_trap = TRUE
				Actions.init_run_act(player, tx, ty, 0)
		else:
			# send him to touch-line...
			Actions.init_run_act(player, tx, tly, 0)

#/******************************************************************************
#*****************************************************************************/

# void intelligence(match_player *player)
@warning_ignore("integer_division")
static func intelligence(player: match_player) -> void:
	if (player.control) and (not match_mode) and (ball_poss):
		# Player has just collected ball and been auto selected...
		user_controlled = player.control
		user_intelligence(player)
	else:
		var busy: int = 0
		var pnum: int = player.tm_player

		if (player.tm_leave) and (last_touch != player.tm_player):
			player.tm_leave = FALSE												# he can touch ball again!

		if player.int_cnt:				#Is he busy?
			player.int_cnt = s16(player.int_cnt - 1)
			if player.int_cnt:
				if (((pnum == KP_A) or (pnum == KP_B)) and (player.int_move == I_INTERCEPT)
					and (shot_pending > 0)):
					busy = 0
				else:
					busy = 1
					#/*
					#					if (player->int_move==I_INTERCEPT && user_controlled && player->tm_strike>0)
					#// User player is interecpting ball but hasn't chosen special move...
					#						go_to_path(player->tm_player);
					#*/
					if player.int_move == I_OFF:
						# He is going off!
						if player.tm_act == STAND_ACT:
							init_off_int(player)
					else:
						if player.int_move == I_RUN_ON:
							# Calling for pass ahead...
							if plr_facing(player.go_xoff, player.go_yoff, player):
								if player.tm_comm < 0:
									player.tm_comm = -player.tm_comm
							else:
								if player.tm_comm > 0:
									player.tm_comm = FALSE
									player.tm_ccnt = 0
									reset_ideas(player)
						else:
							if player.int_move == I_STEAL:
								if player.tm_dist < STEAL_BODY_DIST:
									reset_ideas(player)
									Actions.init_steal_act(player)
			else:
				player.int_cnt = -1
				if player.int_move == I_SAVE_WAIT:
					if player.tm_act == RUN_ACT:
						player.int_cnt = player.go_cnt + 2

					if player.int_cnt > 0:
						player.int_move = I_INTERCEPT
						busy = 1
					else:
						reset_ideas(player)
				else:
					reset_ideas(player)

		if player.tm_act <= TURN_ACT:	# Player is standing or running or turning!
			if not busy and not just_scored:
				if player.guy_on < 0:
					# He has to be sent off!
					init_off_int(player)

				if dead_ball_cnt == 0:
					# Are we in normal play...
					if not ball_poss:
						free_ball(player)
					else:
						if ball_poss == pnum:
							got_ball(player)
						else:
							if (pnum < 12) and (ball_poss < 12):
								# My team A has ball!
								we_have_ball(player)
							else:
								if (pnum > 11) and (ball_poss > 11):
									# My team B has ball!
									we_have_ball(player)
								else:
									opp_has_ball(player)
				else:
					# Is ball holder looking for support...
					if ball_poss != pnum and support_me:
						if (pnum < 12) and (ball_poss < 12):
							# My team A has ball!
							we_have_ball(player)
						else:
							if (pnum > 11) and (ball_poss > 11):
								# My team B has ball!
								we_have_ball(player)

#/******************************************************************************
#*****************************************************************************/
#/*
#void cant_block_opp(match_player *player,match_player *oplayer)
#{
# 	int vx=(int)(ballx+(oplayer->go_txdis*8));	 //look 8 turns ahead
# 	int vy=(int)(bally+(oplayer->go_tydis*8));
# 	vx-=player->tm_x;
# 	vy-=player->tm_y;
# 	if (calc_dist(vx,vy)<=tackle_range)
#
#// In tackling range!
#
# 	{
# 		tackle_decide(player);
# 		if (flag)
#			go_tackle(player,oplayer);
# 		else
# 			cant_tack_opp(player);
# 	}
# 	else
# 		cant_tack_opp(player);
#}
#*/

