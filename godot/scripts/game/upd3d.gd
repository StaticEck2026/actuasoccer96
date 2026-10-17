# Port of SOURCE/3D_UPD2.CPP  (assembled by tools/assemble.py - edit the files in parts/)
class_name Upd3D extends Glob
# 3D pitch test				30/9/94
#
# Port of 3D_UPD2.CPP: camera control, coordinate hand-over to the 3D engine
# (pos[] / coords_tab1/2 tweening), replays, text messages and info lines.
#
# Godot port: render3d(buffer, viewx,viewy,viewz, targx,targy,targz, vdist, pos,...)
# is replaced by storing the arguments in `view` (engine coordinates: x, height,
# depth) for the Godot renderer (scripts/render/match_view.gd) which draws pos[].
# draw_string*() calls are recorded in `text_items` for the HUD layer.

const ncb := 26			# No of coordinate blocks: 22 players + 3 officials + ball

# Values passed to render3d() this frame (engine axis order).
class view_info:
	var viewx: float = 0.0
	var viewy: float = 0.0
	var viewz: float = 0.0
	var targx: float = 0.0
	var targy: float = 0.0
	var targz: float = 0.0
	var vdist: float = 440.0
	var vidi: bool = false		# also render the vidi-wall view
	var vidi_viewx: float = 0.0
	var vidi_viewy: float = 0.0
	var vidi_viewz: float = 0.0
	var vidi_targx: float = 0.0
	var vidi_targy: float = 0.0
	var vidi_targz: float = 0.0

static var view: view_info = view_info.new()

# HUD text drawn this frame: [x, y, string, colour, just(0 left,1 right,2 centre), font]
static var text_items: Array = []

# struct message_type { char *ptr; short col; };
class message_type:
	var ptr: String = ""
	var col: int = 0

# message_type message_buffer[MAX_MESSAGES];
static var message_buffer: Array = _mk_messages()
static func _mk_messages() -> Array:
	var a: Array = []
	for i in range(MAX_MESSAGES):
		a.append(message_type.new())
	return a

# plyrdat *replay_tab;  (replay_seconds*REAL_SPEED*ncb records)
static var replay_tab_arr: Array = []

# plyrdat *new_coords=coords_tab1; plyrdat *old_coords=coords_tab2;  (held as references)
static var new_coords_ref: Array = coords_tab1
static var old_coords_ref: Array = coords_tab2

# Function-local statics of update_3d()
static var cam1_dx: float = 0.0		# camera 1 (PLAN) static float dx
static var cam1_dy: float = 0.0
static var cam2_dx: float = 0.0		# camera 2 (1/2 PLAN) static float dx
static var cam2_dy: float = 0.0
static var u3d_move_rate: float = 0.4	# static float move_rate=0.4;

# main_buff.clip_wid / clip_hgt of the original 320x200 (or 640x400) buffer;
# the HUD scales from this virtual screen.
static var clip_wid: int = 320
static var clip_hgt: int = 200

# C++ dynamic initialisers of 3D_UPD2.CPP file-scope variables
#   datapt old_tx=pitch_len/2; datapt old_ty=pitch_wid/2;
#   float old_scale=INIT_SCALE; float scale=INIT_SCALE;
static func _static_init_values() -> void:
	old_tx = pitch_len / 2
	old_ty = pitch_wid / 2
	old_scale = INIT_SCALE
	scale = INIT_SCALE
	new_coords_ref = coords_tab1
	old_coords_ref = coords_tab2

# 3DENG.C render3d(): "Prepare viewing vector vars" - the part of the engine's
# view setup that the rest of the game depends on: the global viewing angle
# cth/sth (used by play_fx) and its integer form icth/isth (used to rotate the
# user's joystick/keyboard direction relative to the camera in
# process_user_inputs()). vidi = rendering the vidi-wall buffer (no icth/isth).
static func render3d_view(viewx: float, viewy: float, viewz: float, targx: float, targy: float, targz: float, vidi: bool) -> void:
	var hr: float
	viewz = -viewz
	targz = -targz
	targx -= viewx
	targy -= viewy
	targz -= viewz

	hr = targx * targx + targz * targz
	if hr < 1:
		hr = 1
		targz = 1
	hr = sqrt(hr)
	cth = targz / hr
	sth = targx / hr
	if not vidi:
		icth = int(32767 * cth)
		isth = int(32767 * sth)

# Copy one plyrdat record (memcpy of a struct).
static func copy_plyrdat(d: plyrdat, s: plyrdat) -> void:
	d.x = s.x
	d.y = s.y
	d.z = s.z
	d.crot = s.crot
	d.srot = s.srot
	d.frame = s.frame
	d.fstep = s.fstep
	d.type = s.type
	d.number = s.number
	d.anim = s.anim
	d.sprite = s.sprite
	d.htype = s.htype
	d.hcol = s.hcol

#///////////////////////////////////////////////////////////
#///////////////////////////////////////////////////////////

# int init_3d()
static func init_3d() -> int:
#	grmode(19);
#	grmode(0x61);
	_static_init_values()

	prev_camera = camera
	mode_change = 0
	camera_dist = 280

	# Replay buffer (allocated in init_match in the original)
	init_replay_buffer()

	# Make sure vectors are corrected...
	new_update_coords()				# Initialize old tab...
	new_update_coords()				# Initialize old tab...
	return 0	# init3d(): the Godot renderer is created by the scene.

# replay_tab=(plyrdat *)mallocx(replay_seconds*ncb*20*sizeof(plyrdat));
static func init_replay_buffer() -> void:
	replay_tab_arr = []
	if replay_seconds:
		for i in range(replay_seconds * ncb * 20):
			replay_tab_arr.append(plyrdat.new())

#///////////////////////////////////////////
# FUNCTIONS CALLED FROM IN-GAME MENUS... //
#///////////////////////////////////////////

#******************************************************************************
#******************************************************************************

# void setup_replay()
static func setup_replay() -> void:
	rep_camera = camera
	if camera == 15:
		camera = old_cam

# void reset_replay()
static func reset_replay() -> void:
	camera = rep_camera

# void sub_player(short t,short p,short s)
static func sub_player(t: int, p: int, s: int) -> void:
	p += 11 * (t ^ (match_half & 1))
	player_being_subbed = p + 1
	player_on_off = p + 1
	player_coming_on = s + 1
	Intell.init_off_int(teams[p])

	if p > 10:
		Audio.PlaySubstitutionMessage(team_b, p - 11, s, FALSE)
	else:
		Audio.PlaySubstitutionMessage(team_a, p, s, FALSE)

# void do_replay_render3d(float s)
static func do_replay_render3d(s: float) -> void:
	s += float(replay_pos) / REAL_SPEED
	if s >= replay_seconds:
		s -= replay_seconds

	var is1: int = int(s * REAL_SPEED)
	var is2: int = int(s * REAL_SPEED) + 1
	if is2 >= replay_seconds * REAL_SPEED:
		is2 -= replay_seconds * REAL_SPEED

	for i in range(ncb):
		copy_plyrdat(old_coords_ref[i], replay_tab_arr[is1 * ncb + i])
		copy_plyrdat(new_coords_ref[i], replay_tab_arr[is2 * ncb + i])

	mf_scale = s * REAL_SPEED - is1
	realtime_coords()

	replay_cnt = TRUE
	update_3d()
	replay_cnt = FALSE

# void process_replay()
static func process_replay() -> void:
	replay_pos += 1
	if replay_pos >= replay_seconds * REAL_SPEED:
		replay_pos = 0

# void plr_comments()
static func plr_comments() -> void:
	for i in range(players):
		if teams[i].guy_on:
			if teams[i].tm_comm > 0:
				Intell.init_speech(i + 1, teams[i].tm_comm, 4)

# void process_pitch_sprs()
static func process_pitch_sprs() -> void:
	plr_comments()

# void init_replay()
static func init_replay() -> void:
	# Fill all replay buffer with current coords etc...
	allow_replay = TRUE
	var k: int = 0
	for reps in range(replay_seconds * 20):
		for i in range(ncb):
			copy_plyrdat(replay_tab_arr[k], pos[i])
			k += 1

#******************************************************************************
#******************************************************************************

# draw_string(buff,font,x,y,st,norm_font_col,just) -> recorded for the HUD.
static func _draw_string(x: int, y: int, st: String, just: int) -> void:
	text_items.append([x, y, st, norm_font_col, just, (1 if Eng3D.scrmode == 0x13 else 2)])

# void draw_string_center(int x,int y,char *st,buff_info *buff)
static func draw_string_center(x: int, y: int, st: String) -> void:
	_draw_string(x, y, st, 2)

# void draw_string_left(int x,int y,char *st,buff_info *buff)
static func draw_string_left(x: int, y: int, st: String) -> void:
	_draw_string(x, y, st, 0)

# void draw_string_right(int x,int y,char *st,buff_info *buff)
static func draw_string_right(x: int, y: int, st: String) -> void:
	_draw_string(x, y, st, 1)

# void set_normal_color(int c)
static func set_normal_color(c: int) -> void:
	norm_font_col = c

#******************************************************************************
#******************************************************************************

# void extra_info()
static func extra_info() -> void:
	var info_str_a: String = ""
	var info_str_b: String = ""

	for p in range(11):
		match xinfo:
			1:
				info_str_a = "SPD. %d. %d" % [(p + 1), teams[p].tm_rate]
				info_str_b = "SPD. %d. %d" % [(p + 11), teams[p + 11].tm_rate]
			2:
				info_str_a = "POW. %d. %d" % [(p + 1), teams[p].tm_pow]
				info_str_b = "POW. %d. %d" % [(p + 11), teams[p + 11].tm_pow]
			3:
				info_str_a = "CON. %d. %d" % [(p + 1), teams[p].tm_cont]
				info_str_b = "CON. %d. %d" % [(p + 11), teams[p + 11].tm_cont]
			4:
				info_str_a = "FLR. %d. %d" % [(p + 1), teams[p].tm_flair]
				info_str_b = "FLR. %d. %d" % [(p + 11), teams[p + 11].tm_flair]
			5:
				info_str_a = "VIS. %d. %d" % [(p + 1), teams[p].tm_vis]
				info_str_b = "VIS. %d. %d" % [(p + 11), teams[p + 11].tm_vis]
			6:
				info_str_a = "ACC. %d. %d" % [(p + 1), teams[p].tm_ac]
				info_str_b = "ACC. %d. %d" % [(p + 11), teams[p + 11].tm_ac]
			7:
				info_str_a = "STM. %d. %d" % [(p + 1), teams[p].tm_stam]
				info_str_b = "STM. %d. %d" % [(p + 11), teams[p + 11].tm_stam]
			8:
				info_str_a = "DIS. %d. %d" % [(p + 1), teams[p].tm_disc]
				info_str_b = "DIS. %d. %d" % [(p + 11), teams[p + 11].tm_disc]
			9:
				info_str_a = "PER. %d. %d" % [(p + 1), performance[p]]
				info_str_b = "PER. %d. %d" % [(p + 11), performance[p + 11]]
		draw_string_left(64, 32 + (p * 10), info_str_a)
		draw_string_left(192, 32 + (p * 10), info_str_b)

#******************************************************************************
#******************************************************************************

# void info_line()
static func info_line() -> void:
	set_normal_color(WHITE)

	var info_str1: String = ""
	var info_str2: String = ""
	var info_str3: String = ""
	var info_str4: String = ""
	var info_str5: String = ""

	if setp_taker:
		info_str3 = "%d    " % teams[setp_taker - 1].tm_ac
		draw_string_center(50, 60, info_str3)
		info_str3 = "%d    " % teams[setp_taker - 1].tm_flair
		draw_string_center(50, 80, info_str3)

	info_str3 = "1. %d    " % users[0].plr
	draw_string_center(150, 60, info_str3)
	info_str3 = "2. %d    " % users[1].plr
	draw_string_center(150, 80, info_str3)

	info_str3 = "3. %d    " % users[2].plr
	draw_string_center(50, 100, info_str3)
	info_str3 = "4. %d    " % users[3].plr
	draw_string_center(50, 120, info_str3)

	info_str3 = "%d    " % deb_is
	draw_string_center(150, 100, info_str3)

	info_str3 = "%d    " % good_poss

	info_str2 = "%d : %d  " % [frms_per_sec, game_speed]
#	sprintf(info_str2,"%d : %1.2f  ",frms_per_sec,poss_held);

	if CROWD:
		const moods := ["", "NORMAL   ", "PENSIVE  ", "ENCOURAGE", "EXCITED  ", "CELEBRATE", "BOO...   ", "SAVE     ", "MISS     ", "LAUGH    "]
		if crowd_mood_a >= 1 and crowd_mood_a <= 9:
			info_str4 = moods[crowd_mood_a]
		if crowd_mood_b >= 1 and crowd_mood_b <= 9:
			info_str5 = moods[crowd_mood_b]

	if replay_cnt:
		info_str1 = "REPLAY"
	else:
		if match_mode:
			match match_mode:
				CORNER_TL, CORNER_TR, CORNER_BL, CORNER_BR:
					info_str1 = "CORNER"
				CENTRE_A, CENTRE_B:
					info_str1 = "CENTRE"
				GOAL_KICK_TL, GOAL_KICK_TR, GOAL_KICK_BL, GOAL_KICK_BR:
					info_str1 = "GOAL KICK"
				THROW_IN_A, THROW_IN_B:
					info_str1 = "THROW IN"
				IF_KICK_A, IF_KICK_B:
					if offside_now:
						info_str1 = "OFFSIDE FK"
					else:
						info_str1 = "INDIRECT FK"
				DF_KICK_A, DF_KICK_B:
					info_str1 = "DIRECT FK"
				_:
					info_str1 = "STOPPED"
			# Event...
			draw_string_center(50, 4, info_str1)

	draw_string_center(270, 4, info_str3)
	draw_string_center(160, 4, ":")
	draw_string_center(270, 4, info_str3)

	# Score...
	info_str1 = "%d - %d" % [team_a_goals, team_b_goals]
	draw_string_center(160, 185, info_str1)

	# Seconds...
	info_str1 = "%02d" % u16(int(match_time.sec))
	draw_string_center(164, 4, info_str1)

	# Minutes...
	info_str1 = "%3d" % match_time.min
	draw_string_center(126, 4, info_str1)

#******************************************************************************
#******************************************************************************

# Switch off camera damping...

# void damping_off()
static func damping_off() -> void:
	old_camx = camera_x
	old_camy = camera_y
	old_camz = camera_z

#******************************************************************************
#******************************************************************************

# void add_message(char *t,short c,char force)
static func add_message(t: String, c: int, force: int) -> void:
	if force:
		# Instant display over-riding current message...
		message_buffer[current_mess].ptr = t
		message_buffer[current_mess].col = c
		new_text = MESSAGE_TIME
		if not message_cnt:
			message_cnt += 1
	else:
		if message_cnt < MAX_MESSAGES:
			# Can provide message service...
			var m: int = message_cnt + current_mess
			if m >= MAX_MESSAGES:
				m -= MAX_MESSAGES
			var lm: int = m - 1
			if lm < 0:
				lm = MAX_MESSAGES - 1
			if not message_cnt or t != str(message_buffer[lm].ptr):
				# New message...
				message_buffer[m].ptr = t
				message_buffer[m].col = c
				var was: int = message_cnt
				message_cnt += 1
				if not was:
					new_text = MESSAGE_TIME

#******************************************************************************
#******************************************************************************

# void display_messages()
static func display_messages() -> void:
	if new_text:
		set_normal_color(message_buffer[current_mess].col)
		draw_string_center(clip_wid >> 1, clip_hgt / 16, str(message_buffer[current_mess].ptr))

#******************************************************************************
#******************************************************************************

# void change_cam(short c)
static func change_cam(c: int) -> void:
	set_camera_dist = 260
	set_camera_height = 100
	camera = c
	var t: String = ""

	if not camera:
		t = "FAR"

	if camera == 1:
		t = "PLAN"

	if camera == 2:
		t = "G.LINE"

	if camera == 3:
		t = "MANUAL"

	if camera == 4:
		t = "PLAYER"

	if camera == 5:
		t = "USER"

	if camera == 6:
		t = "FOLLOW"

	if camera == 7:
		t = "REF."

	if camera == 8:
		t = "WIRE"

	if camera == 14:
		t = "ISO."

	if (camera < 14 and camera > 8) or (camera > 14):
		t = " "

	add_message(t, YELLOW, TRUE)

#///////////////////////////////////////////////////////////
#///////////////////////////////////////////////////////////

const PULL_BACK_FACTOR := 1.0

# void update_3d()
static func update_3d() -> void:
	var targ_x: float = 0.0
	var targ_y: float = 0.0
	var targ_z: float = 0.0
	var use_fixed: int = 0
	scale = INIT_SCALE
	var cam_limit: int = TRUE
	var cam_buffer: int = TRUE
	var ptr: Array = pos			# Tweened object x,y,z and orientations...

	var x: float
	var y: float

	text_items.clear()

	if not line_up:
		# Not in pre-match line-up (can use all available camera options)...

		if not replay_cnt:
			# No celebration view during replay...

			if (just_scored and just_scored < (SCORE_WAIT - 30)) and (camera != 15):
				# Camera is forced to follow scorer!
				old_cam = camera
				if WAYNE:
					camera = 20
				else:
					camera = 15			# Follow scorer.
			else:
				if not just_scored and camera == 15:
					camera = old_cam

		if not EUROmatch_info.timeit:

			if SUPPORT_LP:
				if users_dir[lp_user - 1].f & 32 or users_dir[lp_user - 1].f & 16:
					if (keys[0x4b] or (users_dir[lp_user - 1].f & 4 and users_dir[lp_user - 1].f & 32)) and (set_camera_dist > 10):			# keypad 4
						set_camera_dist -= 4

					if (keys[0x4d] or (users_dir[lp_user - 1].f & 8 and users_dir[lp_user - 1].f & 32)) and (set_camera_dist < 600):		# keypad 6
						set_camera_dist += 4

					if (keys[0x48] or (users_dir[lp_user - 1].f & 8 and users_dir[lp_user - 1].f & 16)) and (set_camera_height < 600):		# keypad 8
						set_camera_height += 4

					if (keys[0x50] or (users_dir[lp_user - 1].f & 4 and users_dir[lp_user - 1].f & 16)) and (set_camera_height > 10):		# keypad 2
						set_camera_height -= 4

			if (keys[0x4b]) and (set_camera_dist > 10):			# keypad 4
				set_camera_dist -= 4
			if (keys[0x4d]) and (set_camera_dist < 600):		# keypad 6
				set_camera_dist += 4

			if (keys[0x48]) and (set_camera_height < 600):		# keypad 8
				set_camera_height += 4

			if (keys[0x50]) and (set_camera_height > 10):		# keypad 2
				set_camera_height -= 4

			if keys[0x4c]:											# keypad 5
				set_camera_dist = 260
				set_camera_height = 100

			if replay_cnt or (not just_scored and match_mode != SWAP_ENDS):
				# Don't allow user to change camera during celebration!

				if keys[0x02]:		# 1			// Autocam
					change_cam(0)		# camera=0

				if keys[0x03]:		# 2			// Plan
					change_cam(1)		# camera=1

				if keys[0x04]:		# 3			// 1/2 Plan
					change_cam(2)		# camera=2

				if keys[0x05]:		# 4
					change_cam(3)		# camera=3

				if keys[0x06]:		# 5			// Player
					change_cam(4)		# camera=4

				if keys[0x07]:		# 6			// Wire
					change_cam(8)		# camera=8

				if keys[0x08]:		# 7			// Referee
					change_cam(7)		# camera=7

				if keys[0x09]:		# 8			// Isometric
					change_cam(14)		# camera=14

			if debug:
				# don't use these views for normal game.

				if keys[0x0a]:		# 9
					change_cam(5)		# camera=5

				if keys[0x0b]:		# 0
					change_cam(6)		# camera=6

			if camera == 4:
				if (keys[0x48]) and (play_cam < players):	# keypad 8
					play_cam += 1

				if (keys[0x50]) and (play_cam > 1):			# keypad 2
					play_cam -= 1

			# If in network game and a fixed player has been chosen,
			# then all camera views should treat the fixed player (not the ball)
			# as the target...

			if network_on and fixed_net_user:
				# Fixed player target...
				targ_x = teams[users[fixed_net_user - 1].plr - 1].tm_x
				targ_y = teams[users[fixed_net_user - 1].plr - 1].tm_y
				targ_z = teams[users[fixed_net_user - 1].plr - 1].tm_z
				use_fixed = TRUE
			else:
				if use_ball_limit:
					targ_x = ballx_out
					targ_y = bally_out
					targ_z = ballz_out
				else:
					targ_x = eff_ballx
					targ_y = eff_bally
					targ_z = eff_ballz

				use_fixed = FALSE

		#**************************************
		#  FACE CELEBRATION
		#**************************************

		if camera == 15:
			cam_buffer = TRUE
			tx = teams[goal_scorer - 1].tm_x
			ty = teams[goal_scorer - 1].tm_y
			tz = 24
			camera_x = tx + teams[goal_scorer - 1].tm_xdis * set_camera_dist / 1.5
			camera_y = ty + teams[goal_scorer - 1].tm_ydis * set_camera_dist / 1.5
			camera_z = set_camera_height / 1.5

		#**************************************
		#  TUNNEL VEIW
		#**************************************

		if camera == 16:
			cam_buffer = TRUE
			tx = stadlist[setup.stadium].tunlx
			ty = -stadlist[setup.stadium].tunlz
			tz = stadlist[setup.stadium].tunly

			camera_x = cntspot_x
			camera_y = cntspot_y
			camera_z = 40

		#**************************************
		# PLAYER ON/OFF VEIW
		#**************************************

		if camera == 17:
			var p: int = player_on_off

			if player_on_off < 0:
				p = -p

			p -= 1

			cam_buffer = TRUE
			if -stadlist[setup.stadium].tunlz > cntspot_y:
				camera_y = teams[p].tm_y - (40 + (teams[p].tm_y / 2))
			else:
				camera_y = teams[p].tm_y + (40 + ((pitch_wid - teams[p].tm_y) / 2))

			camera_x = teams[p].tm_x
			camera_z = 80

			tx = teams[p].tm_x
			ty = teams[p].tm_y
			tz = 10

		#**************************************
		#  MAN OF THE MATCH VEIW
		#**************************************

		if camera == 18:
			cam_buffer = TRUE
			tx = teams[man_of_match - 1].tm_x
			ty = teams[man_of_match - 1].tm_y
			tz = 20

			camera_x = tx + (teams[man_of_match - 1].tm_xdis * set_camera_dist)
			camera_y = ty + (teams[man_of_match - 1].tm_ydis * set_camera_dist)
			camera_z = set_camera_height / 2

		#**************************************
		#  GOAL-SCORER
		#**************************************

		if camera == 20:
			cam_buffer = TRUE
			cam_limit = FALSE
			var x2: float
			var y2: float
			var z2: float
			var d2: float

			if last_goal == 1:
				# B vidi...
				x2 = stadlist[setup.stadium].vid2x
				y2 = -stadlist[setup.stadium].vid2z
				z2 = stadlist[setup.stadium].vid2y
			else:
				# A vidi...
				x2 = stadlist[setup.stadium].vid1x
				y2 = -stadlist[setup.stadium].vid1z
				z2 = stadlist[setup.stadium].vid1y

			tx = x2 + (teams[goal_scorer - 1].tm_x - x2) * just_scored / (SCORE_WAIT - 30)
			ty = y2 + (teams[goal_scorer - 1].tm_y - y2) * just_scored / (SCORE_WAIT - 30)
			tz = z2 + (teams[goal_scorer - 1].tm_z - z2) * just_scored / (SCORE_WAIT - 30)

			x2 -= teams[goal_scorer - 1].tm_x
			y2 -= teams[goal_scorer - 1].tm_y
			z2 -= teams[goal_scorer - 1].tm_z

			d2 = Maths.calc_dist(x2, y2)

			x2 = (x2 * set_camera_dist * 0.5 / d2)
			y2 = (y2 * set_camera_dist * 0.5 / d2)
			z2 = 15

			camera_x = teams[goal_scorer - 1].tm_x - x2
			camera_y = teams[goal_scorer - 1].tm_y - y2
			camera_z = z2

		#**************************************
		#  AUTO-CAMERA
		#**************************************

		if camera == 0:
			var over: float = ((targ_x - cntspot_x) / 2 if (targ_x > cntspot_x) else (cntspot_x - targ_x) / 2)
			var target_x: float = int(targ_x)
			var target_y: float = int(pitch_wid / 2) + ((targ_y - cntspot_y) / 2) - (targ_z / 4) + 60
			var target_z: float = 0 # (int)targ_z;

			tx = target_x
			ty = target_y
			tz = target_z

			camera_x = (pitch_len / 2) + ((tx - pitch_len / 2) / 2)
			camera_y = (pitch_wid + 60) + ((targ_y - cntspot_y) / 1.5) - (over)
			camera_z = 180 - (targ_y / 12) + (over / 3)

		#**************************************
		# PLAN ( Kick-off view )
		#**************************************

		if camera == 1:
			var dcx: float
			var dcy: float
			var move_rate: float

			cam_buffer = FALSE		# Switch camera buffering off!
			cam_limit = FALSE		# Switch camera limit off!

			if game_speed:
				move_rate = (0.2 * MF * REAL_SPEED) / game_speed
			else:
				move_rate = 0.2

			if ball_still or use_fixed:
				x = targ_x
				y = targ_y
			else:
				cam1_dx += ((ballxdis * 10) - cam1_dx) * 0.8
				cam1_dy += ((ballydis * 10) - cam1_dy) * 0.8

				x = (eff_ballx + cam1_dx)
				y = (eff_bally + cam1_dy)

			dcx = x - old_tx
			dcy = y - old_ty

			cxs += (dcx * camera_inertia - cxs) * move_rate
			cys += (dcy * camera_inertia - cys) * move_rate

			x = old_tx + cxs
			y = old_ty + cys

			var xhf: int = int((set_camera_height / 2.45) - prat * 3)
			var yhf: int = int((set_camera_height / 1.6) - prat * 2)

			if x < xhf:
				x = xhf
			if x > pitch_len - xhf:
				x = pitch_len - xhf
			if y < yhf:
				y = yhf
			if y > pitch_wid - yhf:
				y = pitch_wid - yhf

			tx = x
			ty = y
			tz = 0

			camera_x = x - 1
			camera_y = y
			camera_z = prat * 6 + set_camera_height

		#**************************************
		# 1/2 PLAN ( Sensi style view )
		#**************************************

		if camera == 2:
			var dcx: float
			var dcy: float
			var move_rate: float

			cam_buffer = FALSE		# Switch camera buffering off!
			cam_limit = FALSE		# Switch camera limit off!

			if game_speed:
				move_rate = (0.2 * MF * REAL_SPEED) / game_speed
			else:
				move_rate = 0.2

			if ball_still or use_fixed:
				x = targ_x
				y = targ_y
			else:
				cam2_dx += ((ballxdis * 10) - cam2_dx) * 0.4
				cam2_dy += ((ballydis * 10) - cam2_dy) * 0.4

				x = (eff_ballx + cam2_dx)
				y = (eff_bally + cam2_dy)

			dcx = x - old_tx
			dcy = y - old_ty

			cxs += (dcx * camera_inertia - cxs) * move_rate
			cys += (dcy * camera_inertia - cys) * move_rate

			x = old_tx + cxs
			y = old_ty + cys

			var xhf: int = int(((set_camera_height + 8) / 2.45) - prat * 3)
			var yhf: int = int((Maths.calc_dist(set_camera_dist + (targ_x / 6), (set_camera_height + 8) / 2) / 1.6) - prat * 3)

			if x < xhf:
				x = xhf
			if x > pitch_len - xhf:
				x = pitch_len - xhf
			if y < yhf:
				y = yhf
			if y > pitch_wid - yhf:
				y = pitch_wid - yhf

			tx = x
			ty = y
			tz = 0

			camera_x = x - set_camera_dist - (targ_x / 6)
			camera_y = y
			camera_z = (set_camera_height + 8)

		#**************************************
		# MANUAL
		#**************************************

		if camera == 3:
			# ReportMouse();
			camera_x = mouse_x * 2.125 - 40
			camera_y = mouse_y * 4.4 - 40
			camera_z = set_camera_height

			tx = targ_x
			ty = targ_y
			tz = targ_z

		#**************************************
		# PLAYER
		#**************************************

		if camera == 4:
			cam_buffer = 2
			camera_x = ptr[play_cam - 1].x
			camera_z = ptr[play_cam - 1].y + PLAYER_HEIGHT - 3
			camera_y = ptr[play_cam - 1].z

			x = -ptr[play_cam - 1].crot
			y = (ptr[play_cam - 1].srot)

			tx = camera_x + x * 100
			ty = camera_y + y * 100
			tz = PLAYER_HEIGHT - 3

		#**************************************
		# USER
		#**************************************

		if camera == 5:
			camera_x = ptr[ball_poss - 1].x
			camera_z = ptr[ball_poss - 1].y + PLAYER_HEIGHT
			camera_y = ptr[ball_poss - 1].z + 2

			x = -ptr[ball_poss - 1].crot
			y = (ptr[ball_poss - 1].srot)

			tx = camera_x + x * 100
			ty = camera_y + y * 100
			tz = PLAYER_HEIGHT

			damping_off()

		#**************************************
		# FOLLOW BALL
		#**************************************

		if camera == 6:
			var xd: float
			var yd: float

			if ball_poss:
				xd = teams[ball_poss - 1].tm_xdis
				yd = teams[ball_poss - 1].tm_ydis
			else:
				xd = ballxdis
				yd = ballydis

			if (ABS(xd) < .1) and (ABS(yd) < .1):
				tx = old_tx
				ty = old_ty
				tz = old_tz
				camera_x = old_camx
				camera_y = old_camy
				camera_z = targ_z + 40
			else:
				var d: float = Maths.calc_dist(xd, yd)
				camera_x = targ_x - (120 * xd / d)
				camera_y = targ_y - (120 * yd / d)
				camera_z = targ_z + 40

				tx = targ_x
				ty = targ_y
				tz = targ_z

		#**************************************
		# REFEREE
		#**************************************

		if camera == 7:
			cam_buffer = 2
			camera_x = ptr[players].x
			camera_z = ptr[players].y + PLAYER_HEIGHT - 3
			camera_y = ptr[players].z

			x = -ptr[players].crot
			y = ptr[players].srot

			tx = camera_x + x * 100
			ty = camera_y + y * 100
			tz = PLAYER_HEIGHT - 3
			damping_off()

		#**************************************
		# WIRE
		#**************************************

		if camera == 8:
			var bxd: float
			var byd: float
			var d: float
			var ox: float
			var oy: float
			var nx: float
			var ny: float

			if (not match_mode) or (match_mode == CENTRE_A) or (match_mode == CENTRE_B) \
					or (match_mode >= IF_KICK_A and match_mode <= PEN_KICK_B):
				# Normal Play...
				camera_dist = set_camera_dist

				if targ_x > cntspot_x:
					# Right goal...
					bxd = pitch_len - targ_x
					byd = cntspot_y - targ_y
				else:
					# Left goal...
					bxd = -targ_x
					byd = cntspot_y - targ_y

				d = Maths.calc_dist(bxd, byd)
				bxd = bxd / d
				byd = byd / d

				ox = 0
				oy = -1

				# get difference (cos a).
				var dif: float = acos(clampf((bxd * ox) + (byd * oy), -1.0, 1.0))
				if targ_x > cntspot_x:
					dif = (((targ_x - cntspot_x) / cntspot_x) * (dif))
				else:
					dif = -(((cntspot_x - targ_x) / cntspot_x) * (dif))

				# The closer to the goal-line, the more in line with ball to goal!

				nx = (ox * cos(dif)) - (oy * sin(dif))
				ny = (oy * cos(dif)) + (ox * sin(dif))

				tx = targ_x + (nx * (set_camera_dist + 20) / 3)
				ty = targ_y + (ny * (set_camera_dist + 20) / 3)
				tx = targ_x
				ty = targ_y
				tz = targ_z / 2

				camera_x = targ_x - (nx * (set_camera_dist + 20))
				camera_y = targ_y - (ny * ((set_camera_dist + 20)
							- ((set_camera_dist + 20) * (targ_y / (pitch_wid * 2)))))
				camera_z = (set_camera_height + 20) - (((set_camera_height + 20) * .8) * (ABS((targ_y - cntspot_y) / cntspot_y)))

				if targ_y < cntspot_y:
					camera_y = camera_y + ((cntspot_y - targ_y) / 20)

				# Now bring target in according to height...

				bxd = camera_x - tx
				byd = camera_y - ty
				d = Maths.calc_dist(bxd, byd)
				bxd = tx + (bxd * camera_z / (d * 5))
				byd = ty + (byd * camera_z / (d * 5))

				tx = bxd
				ty = byd
			else:
				match match_mode:
					GOAL_KICK_TL, GOAL_KICK_BL:
						camera = 9
					GOAL_KICK_TR, GOAL_KICK_BR:
						camera = 10
					CORNER_TL, CORNER_BL:
						camera = 11
					CORNER_TR, CORNER_BR:
						camera = 12
					THROW_IN_A, THROW_IN_B:
						camera = 13

		#**************************************
		#**************************************

		if camera == 9:
			# Goal kick from left...
			camera_y = cntspot_y
			camera_x = eff_ballx - set_camera_dist
			camera_z = eff_ballz / 2 + set_camera_height
			tx = eff_ballx + ((cntspot_x - eff_ballx) / 10)
			ty = eff_bally
			tz = eff_ballz
			if match_mode != GOAL_KICK_TL and match_mode != GOAL_KICK_BL:
				camera = 8

		#**************************************
		#**************************************

		if camera == 10:
			# Goal kick from right...
			camera_y = cntspot_y
			camera_x = eff_ballx + set_camera_dist
			camera_z = eff_ballz / 2 + set_camera_height
			tx = eff_ballx - ((eff_ballx - cntspot_x) / 10)
			ty = eff_bally
			tz = eff_ballz
			if match_mode != GOAL_KICK_TR and match_mode != GOAL_KICK_BR:
				camera = 8

		#**************************************
		#**************************************

		if camera == 11:
			# Corner kick at left goal...
			var bxd: float
			var byd: float
			var d: float
			tx = prat * 12
			ty = cntspot_y
			tz = 0
			bxd = eff_ballx - tx
			byd = eff_bally - ty
			d = Maths.calc_dist(bxd, byd)
			camera_x = eff_ballx + (bxd * set_camera_dist / d)
			camera_y = eff_bally + (byd * set_camera_dist / d)
			camera_z = set_camera_height / 4
			if (not match_mode) and (last_touch != corner_taker):
				camera = 8

		#**************************************
		#**************************************

		if camera == 12:
			# Corner kick at right goal...
			var bxd: float
			var byd: float
			var d: float
			tx = pitch_len - (prat * 12)
			ty = cntspot_y
			tz = 0
			bxd = eff_ballx - tx
			byd = eff_bally - ty
			d = Maths.calc_dist(bxd, byd)
			camera_x = eff_ballx + (bxd * set_camera_dist / d) / 2
			camera_y = eff_bally + (byd * set_camera_dist / d) / 2
			camera_z = set_camera_height / 4
			if (not match_mode) and (last_touch != corner_taker):
				camera = 8

		#**************************************
		#**************************************

		if camera == 13:
			# Throw in...
			tx = eff_ballx
			ty = eff_bally
			tz = eff_ballz
			camera_x = eff_ballx
			camera_y = eff_bally

			if bally > cntspot_y:
				camera_y += set_camera_dist / 2
			else:
				camera_y -= set_camera_dist / 2

			camera_z = eff_ballz + set_camera_height / 4

			if (not match_mode) and (last_touch != throw_in_taker):
				camera = 8

		#**************************************
		# ISOMETRIC
		#**************************************

		if camera == 14:
			tx = targ_x
			ty = targ_y + ((cntspot_y - targ_y) / 4)
			tz = targ_z

			camera_x = tx - 20 - set_camera_dist * 1.4
			camera_y = ty + 20 + set_camera_dist * 1.4
			camera_z = targ_z / 3 + (set_camera_height * 2)

			scale = 512 * 2
			cam_limit = TRUE
	else:
		# Pre-match Line-up!!!

		if first_update:
			cam_buffer = FALSE
			first_update = FALSE
		else:
			cam_buffer = TRUE

		if line_up >= 40:
			# Move camera...
			cam_limit = FALSE

			var rad: float = ((LINE_UP_DELAY + 40 - line_up) * (LINE_UP_DELAY + 40 - line_up)) / 90
			var ang: float = float(line_up - 40) / LINE_UP_DELAY * PI
			tx = ballx
			ty = bally
			tz = ball_diam / 2
			camera_x = tx - (3 * rad * sin(ang))
			camera_y = ty + (3 * rad * cos(ang)) - 30
			camera_z = 20 + rad
#			y=(float)(line_up-40)/LINE_UP_DELAY;
#			camera_z=prat*2+(y*y*y*y*(prat*60));
#			camera_x=cntspot_x;
#			camera_y=cntspot_y+80+(y*y*(prat*80));
#			tx=cntspot_x;
#			ty=cntspot_y+(y*y*(prat*30));
#			tz=0;

	#**************************************
	#**************************************

	if prev_camera != camera:
		mode_change = CAM_MODE_BUFFER

	prev_camera = camera

	var cur_camx: float
	var cur_camy: float
	var cur_camz: float
	var cur_tx: float
	var cur_ty: float
	var cur_tz: float
	var dif_camx: float
	var dif_camy: float
	var dif_camz: float
	var dif_tx: float
	var dif_ty: float
	var dif_tz: float
	var dif_scale: float

	if not line_up and camera == 8 and camera == 6:
		# (never true in the original: camera can't be 8 and 6)
		var d: float = Maths.calc_dist(tx - camera_x, ty - camera_y)
		d = Maths.calc_dist(tz - camera_z, d)
		x = (camera_x - tx) / d
		y = (camera_y - ty) / d
		var z: float = (camera_z - tz) / d
		var cam_dist: float = Maths.calc_dist(set_camera_dist, set_camera_height)

		var r: float = (d / cam_dist) * PULL_BACK_FACTOR
		camera_x = tx + (r * d * x)
		camera_y = ty + (r * d * y)
		camera_z = tz + (r * d * z)

	# Stadium Perimeter as defined by 3d engine...
	var st_l: int = stadlist[setup.stadium].st_l
	var st_w: int = stadlist[setup.stadium].st_w
	var st_h: int = stadlist[setup.stadium].st_h

	if cam_limit:
		# Camera cannot go far off pitch...
		if camera_x < -st_l / 2:
			camera_x = -st_l / 2
		if camera_x > pitch_len + (st_l / 2):
			camera_x = pitch_len + (st_l / 2)
		if camera_y < -st_w / 2:
			camera_y = -st_w / 2
		if camera_y > pitch_wid + (st_w / 2):
			camera_y = pitch_wid + (st_w / 2)
		if camera_z > st_hm:
			camera_z = st_hm

	if cam_buffer:
		# Tween scale...
		dif_scale = scale - old_scale

		# Camera buffering...
		dif_camx = camera_x - old_camx
		dif_camy = camera_y - old_camy
		dif_camz = camera_z - old_camz

		dif_tx = tx - old_tx
		dif_ty = ty - old_ty
		dif_tz = tz - old_tz

		if not replay_cnt:
			# Time Camera movement...
			if count > old_count + (TIMER_SPEED / 2):
				# Half a second interval...
				old_count += (TIMER_SPEED / 2)
				if not updates:
					updates = 1

				if camera == 3:
					u3d_move_rate = 1.0 / updates		# Mouse control disregards game speed!
				else:
					u3d_move_rate = 1.0 / updates * game_speed / REAL_SPEED

				updates = 0
		else:
			# No need to time...
			u3d_move_rate = 0.2

		dif_camx = clampf(dif_camx, -MAX_CAM_DIF, MAX_CAM_DIF)
		dif_camy = clampf(dif_camy, -MAX_CAM_DIF, MAX_CAM_DIF)
		dif_camz = clampf(dif_camz, -MAX_CAM_DIF, MAX_CAM_DIF)
		dif_tx = clampf(dif_tx, -MAX_CAM_DIF, MAX_CAM_DIF)
		dif_ty = clampf(dif_ty, -MAX_CAM_DIF, MAX_CAM_DIF)
		dif_tz = clampf(dif_tz, -MAX_CAM_DIF, MAX_CAM_DIF)

		cur_camx = old_camx + (dif_camx * u3d_move_rate)
		cur_camy = old_camy + (dif_camy * u3d_move_rate)
		cur_camz = old_camz + (dif_camz * u3d_move_rate)

		cur_tx = old_tx + (dif_tx * u3d_move_rate * 1.5)
		cur_ty = old_ty + (dif_ty * u3d_move_rate * 1.5)
		cur_tz = old_tz + (dif_tz * u3d_move_rate * 1.5)
	else:
		cur_camx = camera_x
		cur_camy = camera_y
		cur_camz = camera_z
		cur_tx = tx
		cur_ty = ty
		cur_tz = tz

	var rendered: bool = false
	if not DEMO:
		if opt_user and not replay_cnt:
			# In Game options menu(Formation,Subs,Replay)
			old_rep_pos = replay_pos
			replay_pos += 1	# In case of replay point to first frame...

			if opt_user == 100:
				# Substitution Menu...
				sub_camera = camera
				camera = 17
				subbing_now = SUB_DELAY
				Eng3D.substitution(cur_camx, cur_camz, cur_camy, cur_tx, cur_tz, cur_ty, scale, opt_team)
				if not player_being_subbed:
					camera = sub_camera
				opt_user = FALSE
			else:
				opt_user -= 1
				Eng3D.options(cur_camx, cur_camz, cur_camy, cur_tx, cur_tz, cur_ty, scale, opt_user, opt_team)

#			if (buff!=new_coords)
#				switch_coords();
			replay_pos = old_rep_pos
			old_count = count
			opt_user = 0
			Football.stop_mf_time()
			rendered = true

	if not rendered:
		view.vidi = false
		if key_togs[0x0a] and not Eng3D.vidi_anim:				# 9
			# Vidi screen on...
			view.vidi = true
			view.vidi_viewx = cntspot_x
			view.vidi_viewy = cur_camz
			view.vidi_viewz = pitch_wid + 80
			view.vidi_targx = eff_ballx
			view.vidi_targy = eff_ballz
			view.vidi_targz = eff_bally
			render3d_view(view.vidi_viewx, view.vidi_viewy, view.vidi_viewz, view.vidi_targx, view.vidi_targy, view.vidi_targz, true)

		# Update display buffer...
		view.viewx = cur_camx
		view.viewy = cur_camz
		view.viewz = cur_camy
		view.targx = cur_tx
		view.targy = cur_tz
		view.targz = cur_ty
		view.vdist = scale
		render3d_view(view.viewx, view.viewy, view.viewz, view.targx, view.targy, view.targz, false)

	# Overlaid sprites...
	if debug:
		info_line()
		if xinfo:
			extra_info()

	# New Message...
	display_messages()

	if EURO96:
		# Name of player in possession...
		if last_touch and match_mode != THROW_IN_A and match_mode != THROW_IN_B:
			var c: int
			var p: int = last_touch
			var name: String

			if p < 12:
				c = (1 if match_half & 1 else 0)
			else:
				c = (0 if match_half & 1 else 1)

			p = Ball.standard_player(p)
			name = str(teams[last_touch - 1].shirt)

			var pl = game_data[Ball.country(c)].players[p - 1]
			var n: String = cstr(pl.name, pl.goal_index)
			name += ". "
			name += n

			if not c:
				set_normal_color(TEAM1COL)
				draw_string_left(8, 1, name)
			else:
				set_normal_color(TEAM2COL)
				draw_string_right(clip_wid - 8, 1, name)

#	Goal Sprite Out...
#		if (just_scored>0 && !replay_cnt)
#		{
#			shadow_sprite(160*2+6,100*2+8,0,&main_buff);
#			overlay_sprite(160*2,100*2,0,&main_buff);
#		}

	# main_buff.dump(0,0);

	old_tx = cur_tx
	old_ty = cur_ty
	old_tz = cur_tz
	old_camx = cur_camx
	old_camy = cur_camy
	old_camz = cur_camz
	old_scale = scale

#******************************************************************************
#******************************************************************************

# void pass_coords(plyrdat *ptr)
static func pass_coords(tab: Array) -> void:
	var x: float
	var y: float
	var rep_base: int = replay_pos * ncb  # Replay Frame...

	var col: int
	if replay_cnt and replay_seconds:
		# Replay On....
		# Use Replay Table only...
		for i in range(ncb):
			copy_plyrdat(tab[i], replay_tab_arr[rep_base + i])
	else:
		# Normal Game mode....
		# Update Replay table also...
		var k: int = 0
		for i in range(players + 3):
			var ptr: plyrdat = tab[k]
			if i >= players:
				# Officials
				ptr.x = refs[i - (players)].x  # x
				ptr.y = refs[i - (players)].z  # y
				ptr.z = refs[i - (players)].y  # z

				if i == players:
					ptr.type = 3 # referee colour
				else:
					ptr.type = 4 # linesman colour

				ptr.crot = refs[i - (players)].dir_x
				ptr.srot = refs[i - (players)].dir_y
				ptr.anim = int(refs[i - (players)].anim)			# anim seq.
				ptr.frame = refs[i - (players)].frm			# anim frm.
				ptr.fstep = refs[i - (players)].fstep			# anim fstep.

				ptr.htype = 0		# htype
				ptr.hcol = 0		# hcol

				if speech_tab[i].cnt:
					ptr.sprite = speech_tab[i].say
				else:
					ptr.sprite = -1
				k += 1
			else:
				ptr.x = teams[i].tm_x  # x
				ptr.y = teams[i].tm_z  # y
				ptr.z = teams[i].tm_y  # z

				if not teams[i].guy_on:
					# Not on field...
					ptr.type = FALSE
				else:
					if teams[i].draw_me:
						if match_half & 1:
							if i >= players / 2:
								col = 1
							else:
								col = 2
						else:
							if i >= players / 2:
								col = 2
							else:
								col = 1
					else:
						col = FALSE		# Don't draw him!

					ptr.type = col # colour

				ptr.number = teams[i].shirt

				x = (teams[i].tm_xdis) # x
				y = (teams[i].tm_ydis) # y

				ptr.crot = x
				ptr.srot = y

				ptr.anim = teams[i].tm_anim
				ptr.frame = teams[i].tm_frm
				ptr.fstep = teams[i].tm_fstep

				ptr.htype = teams[i].tm_htype
				ptr.hcol = teams[i].tm_hcol

				if speech_tab[i].cnt:
					ptr.sprite = speech_tab[i].say
				else:
					ptr.sprite = -1
				k += 1

		var b: plyrdat = tab[k]
		b.x = ballx
		b.y = ballz
#		ptr->y=ball_diam/2+ballz-0.5;
		b.z = bally

		b.type = 0 			# ball type

		b.crot = cos(ball_horz_ang - PI / 2)
		b.srot = sin(ball_horz_ang - PI / 2)

		b.anim = 0
		b.frame = cos(ball_vert_ang)
		b.fstep = sin(ball_vert_ang)

		b.sprite = 0
		k += 1

		# Store in replay array...
		if replay_seconds:
			for i in range(ncb):
				copy_plyrdat(replay_tab_arr[rep_base + i], tab[i])

#******************************************************************************
#******************************************************************************

# void switch_coords()
static func switch_coords() -> void:
	if new_coords_ref == coords_tab1:
		new_coords_ref = coords_tab2
		old_coords_ref = coords_tab1
	else:
		new_coords_ref = coords_tab1
		old_coords_ref = coords_tab2

# void new_update_coords()
static func new_update_coords() -> void:
	switch_coords()
	pass_coords(new_coords_ref)

#******************************************************************************
#******************************************************************************

# Tween a (cos,sin) direction pair from old towards new by mf_scale.
static func _tween_dir(ox: float, oy: float, nx: float, ny: float) -> Array:
	var dif: float = ((nx * ox) + (ny * oy))
	if dif > 1.0:
		dif = 1
	if dif < -1.0:
		dif = -1
	dif = acos(dif)
	dif = dif * mf_scale
	# Which way to turn?
	if (nx * oy) < (ny * ox):
		dif = -dif
	return [(ox * cos(dif)) + (oy * sin(dif)), (oy * cos(dif)) - (ox * sin(dif))]

# void realtime_coords()
static func realtime_coords() -> void:
	var old: Array = old_coords_ref
	var newp: Array = new_coords_ref
	var ox: float
	var oy: float
	var nx: float
	var ny: float

	if tweening:
		for i in range(players + 3):
			var p: plyrdat = pos[i]
			var o: plyrdat = old[i]
			var n: plyrdat = newp[i]
			if (i >= players) or (teams[i].guy_on):
				p.x = o.x + ((n.x - o.x) * mf_scale)
				p.y = o.y + ((n.y - o.y) * mf_scale)
				p.z = o.z + ((n.z - o.z) * mf_scale)

				p.type = n.type		# col
				p.number = n.number	# shirt no.

				var r: Array = _tween_dir(o.crot, o.srot, n.crot, n.srot)
				p.crot = -r[0]	# xd
				p.srot = r[1]	# yd

				# Animation seq...
				p.anim = n.anim

				# Animation frame...
				if (i >= players and refs[i - players].newanim) \
						or (i < players and teams[i].tm_newanim):
					p.frame = c_modf(n.frame)		# Initial frame...
					if i >= players:
						refs[i - players].newanim = FALSE
					else:
						teams[i].tm_newanim = FALSE
					o.frame = 0
				else:
					nx = n.frame
					ox = o.frame
					if nx < ox:
						# Prevent backwards tweening...(looks bad in slow motion!)
						nx += 1

					nx = ox + ((nx - ox) * mf_scale)
					nx = c_modf(nx)
					p.frame = nx
					if i == 11:
						deb_data = nx

				p.fstep = n.fstep
				p.htype = n.htype
				p.hcol = n.hcol
				p.sprite = n.sprite
			else:
				p.type = 0		# Off!

		# Ball...
		var bp: plyrdat = pos[players + 3]
		var bo: plyrdat = old[players + 3]
		var bn: plyrdat = newp[players + 3]

		bp.x = bo.x + ((bn.x - bo.x) * mf_scale)
		eff_ballx = bp.x
		bp.y = bo.y + ((bn.y - bo.y) * mf_scale)
		eff_ballz = bp.y
		bp.z = bo.z + ((bn.z - bo.z) * mf_scale)
		eff_bally = bp.z

		bp.type = 0

		var r1: Array = _tween_dir(bo.crot, bo.srot, bn.crot, bn.srot)
		bp.crot = r1[0]
		bp.srot = r1[1]

		bp.anim = 0

		var r2: Array = _tween_dir(bo.frame, bo.fstep, bn.frame, bn.fstep)
		bp.frame = r2[0]
		bp.fstep = r2[1]
		bp.sprite = 0
	else:
		for i in range(players + 3):
			var p: plyrdat = pos[i]
			var n: plyrdat = newp[i]
			if (i >= players) or (teams[i].guy_on):
				p.x = n.x
				p.y = n.y
				p.z = n.z

				p.type = n.type
				p.number = n.number	# shirt no.

				p.crot = -(n.crot)
				p.srot = n.srot

				p.anim = n.anim
				p.frame = c_modf(n.frame)
				p.fstep = n.fstep
				p.htype = n.htype
				p.hcol = n.hcol
				p.sprite = n.sprite
			else:
				p.type = 0		# Off!

		# Ball...
		var bp: plyrdat = pos[players + 3]
		var bn: plyrdat = newp[players + 3]
		bp.x = bn.x
		bp.y = bn.y
		bp.z = bn.z
		bp.crot = bn.crot
		bp.srot = bn.srot
		bp.frame = bn.frame
		bp.fstep = bn.fstep
		bp.sprite = bn.sprite

#******************************************************************************
#******************************************************************************

# void sprite3d(short x,short y,short ref)   -- debug pixel plot; speech bubbles
# are drawn by the HUD from pos[].sprite.

# STUB (not yet ported): void sprite3d(...)
static func sprite3d(x, y, ref):
	pass

