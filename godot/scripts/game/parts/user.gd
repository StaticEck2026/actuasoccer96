#******************************************************************************
#******************************************************************************

# User Interface routines...

#******************************************************************************
#******************************************************************************

# (#include <math.h> <string.h> <stdio.h> "defines.h" "mouse.h" "externs.h")
# extern char on_3d;          -> glob.gd
# extern void editor_main();
# MOUSE.H: Mouse.x / Mouse.y  -> mouse_x / mouse_y (glob.gd)
# MOUSE.H: MouseRelease()     -> hardware (waits for the mouse button release): kept as comment "# MOUSE:"

#******************************************************************************
#******************************************************************************

# void init_keyboard()
static func init_keyboard() -> void:
	key2[UP_KEY] = 0x1e		# A
	key2[DN_KEY] = 0x2c		# Z
	key2[LF_KEY] = 0x33		# <
	key2[RT_KEY] = 0x34		# >
	key2[F1_KEY] = 0x10		# Q
	key2[F2_KEY] = 0x35		# /

	key1[UP_KEY] = -0x48		# Arrow Up
	key1[DN_KEY] = -0x50		# Arrow Dn
	key1[LF_KEY] = -0x4b		# Arrow Lf
	key1[RT_KEY] = -0x4d		# Arrow Rt
	key1[F1_KEY] = 0x52		# 0(num)
	key1[F2_KEY] = 0x53		# .(num)

#******************************************************************************
#******************************************************************************

# NETWORK-ONLY: called when a network user quits (magic quit data in convert_inputs).
# void delete_net_user(int u)
static func delete_net_user(u: int) -> void:
	users_left -= 1
	if u == user_taker:
		user_taker = FALSE

	var tm: int = 0

	var i: int
	var copy: int = FALSE

	var type: int = users[u-1].type

	if type < 0:
# Auto Player...
		if type == -1:
# Auto-user A.
			# NOTE: as in the original, auto_users_list_a[i+1] is read past the end
			# of the 10-entry list when auto_users_a==10.
			for ii in range(0, auto_users_a):
				i = ii
				if auto_users_list_a[i] == u:
# Found user...
#					if (last_user_a>=i && last_user_a)
#						last_user_a--;
#
#					if (play_ball_a>=i && play_ball_a)
#						play_ball_a--;
					copy = TRUE

				if copy and i < auto_users_a:
					auto_users_list_a[i] = auto_users_list_a[i+1]

			auto_users_a -= 1
		else:
# Auto-user B.
			for ii in range(0, auto_users_b):
				i = ii
				if auto_users_list_b[i] == u:
# Found user...
#					if (last_user_b>=i && last_user_b)
#						last_user_b--;
#
#					if (play_ball_b>=i && play_ball_b)
#						play_ball_b--;
					copy = TRUE

				if copy and i < auto_users_b:
					auto_users_list_b[i] = auto_users_list_b[i+1]

			auto_users_b -= 1
	else:
# Fixed Player...
		if fixed_net_user == u:
			fixed_net_user = 0

	for ii in range(0, 22):
		if teams[ii].control == u:
			teams[ii].control = FALSE		# No user control of player!

	users[u-1].type = 0
	users[u-1].control = NO_CTRL

	# sprintf(glob_str1,"USER %d has quit!",u);
	var s1: String = "USER %d has quit!" % u
	_set_cstr(glob_str1, s1)
	Upd3D.add_message(s1, RED, TRUE)

	var s2: String
	if users_left == 1:
		s2 = "You are now the only user in the game!"
	else:
		s2 = "There are %d users left in the game!" % users_left
	_set_cstr(glob_str2, s2)

	Upd3D.add_message(s2, YELLOW, FALSE)

# sprintf() helper: store a String into a char[] global (NUL terminated, truncated to fit).
static func _set_cstr(arr: Array, s: String) -> void:
	var b: PackedByteArray = s.to_ascii_buffer()
	var n: int = mini(b.size(), arr.size() - 1)
	for k in range(0, n):
		arr[k] = b[k]
	arr[n] = 0

#******************************************************************************
#******************************************************************************

# Add team user.

# void add_team_user(short t,short c)
static func add_team_user(t: int, c: int) -> void:
	users[num_of_users].type = t						# User team.
	users[num_of_users].control = c					# Control type.
	users[num_of_users].plr = -1						# Current player.
	num_of_users += 1

#	if (c==JOY1_CTRL)
#		joystick1_on=TRUE;
#	if (c==JOY2_CTRL)
#		joystick2_on=TRUE;
	if t == -1:
		auto_users_list_a[auto_users_a] = num_of_users
		auto_users_a += 1
	if t == -2:
		auto_users_list_b[auto_users_b] = num_of_users
		auto_users_b += 1

	if SUPPORT_LP:
		if c == LOGPAD_CTRL:
			lp_user = num_of_users

#******************************************************************************
#******************************************************************************

# Add User as fixed player.

# void add_fixed_user(short p,short c)
static func add_fixed_user(p: int, c: int) -> void:
	users[num_of_users].type = p						# User fixed player.
	users[num_of_users].control = c					# Control type.
	users[num_of_users].plr = s8(p)						# Current player.
	num_of_users += 1

#	if (c==JOY1_CTRL)
#		joystick1_on=TRUE;
#	if (c==JOY2_CTRL)
#		joystick2_on=TRUE;

	teams[p-1].control = u8(num_of_users)					# Tag player as user controlled!

	if c != NET_CTRL and network_on:
		fixed_net_user = num_of_users

	if SUPPORT_LP:
		if c == LOGPAD_CTRL:
			lp_user = num_of_users

#******************************************************************************
#******************************************************************************

# Initialise Fixed control players.

# void clear_all_fixed()
static func clear_all_fixed() -> void:
	for i in range(0, players):
		teams[i].control = FALSE

#******************************************************************************
#******************************************************************************

# Initialise User Configuration Table...

# void init_users()
static func init_users() -> void:
	# memset((void *)users,0,MAX_NET_USERS*(sizeof(user_config)));
	for k in range(0, MAX_NET_USERS):
		var uc: user_config = users[k]
		uc.type = 0
		uc.control = 0
		uc.inp_x = 0
		uc.inp_y = 0
		uc.inp_ox = 0
		uc.inp_oy = 0
		uc.inp_fb = 0
		uc.chng = 0
		uc.plr = 0
	num_of_users = 0
	auto_users_a = 0
	auto_users_b = 0
	fixed_net_user = 0
	clear_all_fixed()

#	add_team_user(TEAM_A,MOUSE_CTRL);
#	add_team_user(TEAM_A,KEY1_CTRL);
#	add_team_user(TEAM_A,KEY2_CTRL);
#	add_team_user(TEAM_A,JOY1_CTRL);
#	add_team_user(TEAM_A,KEY2_CTRL);
#	add_fixed_user(15,JOY2_CTRL);
#	add_team_user(TEAM_A,KEY2_CTRL);
#	add_fixed_user(11,KEY1_CTRL);

#******************************************************************************
#******************************************************************************

# void go_button()
static func go_button() -> void:
	match button_lit:
		1:
			in_game = FALSE
		2:
			Display.grid_map()					#Draw zonal grid on pitch.
			# MOUSE: MouseRelease();
		3:
			Display.faster()					#Speed up.
		4:
			Display.slower()					#Slow down.
		5:
			Display.show_nums()				#Show player nos.
			# MOUSE: MouseRelease();
		6:
			set_xyspin += 1				#Add clockwise swerve.
			# MOUSE: MouseRelease();
		7:
			set_xyspin -= 1				#Add anti-clockwise swerve.
			# MOUSE: MouseRelease();
		8:
			set_zspin += 1				#Add Top-spin swerve.
			# MOUSE: MouseRelease();
		9:
			set_zspin -= 1				#Add Back-spin swerve.
			# MOUSE: MouseRelease();
		10:
#  			on_3d=TRUE;					//Use 3d display.
			pass

#******************************************************************************
#******************************************************************************

# void mouse_fired()
static func mouse_fired() -> void:
	if not on_3d:
		if button_lit:
			go_button()

#******************************************************************************
#******************************************************************************

# void process_butts()
static func process_butts() -> void:
	var x: int
	var y: int
	var w: int
	for i in range(0, max_butts):
		x = us_buttons[i].x
		y = us_buttons[i].y
		w = us_buttons[i].w
		if ((mouse_x/2 >= x-4) and (mouse_x/2 <= x+(w*8)+4)
				and (mouse_y >= y-4) and (mouse_y <= y+12)):
			if not us_buttons[i].l:
				Display.light_button(i)			#Mouse will highlight button.
				us_buttons[i].l = 1
		else:
			if us_buttons[i].l:
				Display.unlight_button(i)
				us_buttons[i].l = 0

#******************************************************************************
#******************************************************************************


# Low level input code has moved to network.c...


#******************************************************************************
#******************************************************************************

# Converts integer input from interrupts into expected data in users_dir array

# void convert_inputs()
static func convert_inputs() -> void:
	var x: int
	var y: int
	for i in range(0, num_of_users):
		x = s16(users_dir_i[readptr][i].x_f1)
		y = s16(users_dir_i[readptr][i].y_f2)

		if x == 12345 and y == 12345:	# Magic quit data from master in network game
			delete_net_user(i+1)		# NETWORK-ONLY
		else:
			users_dir[i].f = u8((x & 1) | ((y & 1) << 1))

			if EURO96:
				users_dir[i].f = u8(users_dir[i].f + ((x & 6) << 1))
				users_dir[i].f = u8(users_dir[i].f + ((y & 6) << 3))

				x = s16(x & 0xfff8)
				y = s16(y & 0xfff8)
			else:
				if SUPPORT_LP:
					if users[i].control == LOGPAD_CTRL:
						users_dir[i].f = u8(users_dir[i].f + ((x & 6) << 1))
						users_dir[i].f = u8(users_dir[i].f + ((y & 6) << 3))

					x = s16(x & 0xfff8)
					y = s16(y & 0xfff8)
				else:
					x = s16(x & 0xfffe)
					y = s16(y & 0xfffe)

			users_dir[i].m = bi(x or y)
			users_dir[i].x = x/32768.0
			users_dir[i].y = y/32768.0


#******************************************************************************
#******************************************************************************

# Reset Auto-selected User...

# void clear_auto(short u)
static func clear_auto(u: int) -> void:
	users[u-1].plr = 0

	for i in range(1, players+1):
		if teams[i-1].control == u:
			teams[i-1].control = FALSE
			teams[i-1].tm_htype = FALSE

#******************************************************************************
#******************************************************************************

# Reset All Auto-selected Users...

# void clear_all_autos()
static func clear_all_autos() -> void:
	for i in range(0, auto_users_a):
		clear_auto(auto_users_list_a[i])
	for i in range(0, auto_users_b):
		clear_auto(auto_users_list_b[i])

#******************************************************************************
#******************************************************************************

# void reset_f_held()
static func reset_f_held() -> void:
	f1_down = FALSE
	f2_down = FALSE

#******************************************************************************
#******************************************************************************

# short user_keeper_a()
static func user_keeper_a() -> int:
	var u: int = teams[KP_A-1].control
	if not u:
		if auto_users_a:
			play_ball_a += 1
			if play_ball_a >= auto_users_a:
				play_ball_a = 0
			u = auto_users_list_a[play_ball_a]
			clear_auto(u)
		else:
			u = 0

	return u

#******************************************************************************
#******************************************************************************

# short user_keeper_b()
static func user_keeper_b() -> int:
	var u: int = teams[KP_B-1].control
	if not u:
		if auto_users_b:
			play_ball_b += 1
			if play_ball_b >= auto_users_b:
				play_ball_b = 0
			u = auto_users_list_b[play_ball_b]
			clear_auto(u)
		else:
			u = 0

	return u

#******************************************************************************
#******************************************************************************

# short user_taker_a(short p)
static func user_taker_a(p: int) -> int:
	reset_f_held()
	var u: int = teams[p-1].control
	if not u:
		if auto_users_a:
			play_ball_a += 1
			if play_ball_a >= auto_users_a:
				play_ball_a = 0
			u = auto_users_list_a[play_ball_a]
			clear_auto(u)
		else:
			u = 0
	return u

#******************************************************************************
#******************************************************************************

# short user_taker_b(short p)
static func user_taker_b(p: int) -> int:
	reset_f_held()
	var u: int = teams[p-1].control
	if not u:
		if auto_users_b:
			play_ball_b += 1
			if play_ball_b >= auto_users_b:
				play_ball_b = 0
			u = auto_users_list_b[play_ball_b]
			clear_auto(u)
		else:
			u = 0
	return u

#******************************************************************************
#******************************************************************************

# void auto_select_a(short u)
static func auto_select_a(u: int) -> void:
# Team A...
	closest = FALSE

	last_plr_a = users[u-1].plr

	if not (ball_poss and u == teams[ball_poss-1].control):
# This guy doesn't have ball!
		if (ball_poss != KP_A and ball_poss <= players/2 and ball_poss
				and not teams[ball_poss-1].control):
# His team-mate has ball who isn't a user... (make him this user!)
			clear_auto(u)
			users[u-1].chng = TRUE				# changed control.

			Intell.reset_ideas(teams[ball_poss-1])
			teams[ball_poss-1].control = u8(u)
			users[u-1].plr = s8(ball_poss)
		else:
# Get closest...
			var main_guy: int
			if user_taker2 == u:
				main_guy = KP_A
			else:
				if receiver_a:
					main_guy = receiver_a
				else:
					if interceptor_a:
						main_guy = interceptor_a
					else:
						if near_path_a:
							main_guy = near_path_a
						else:
							main_guy = 0

			var d: float
			var guy: int = 0
			var lowest: float = 2000

			for i in range(1, 12):
				if ((i != KP_A or match_mode == GOAL_KICK_BL or match_mode == GOAL_KICK_TL or user_taker2)
						and teams[i-1].guy_on > 0 and (not teams[i-1].control or teams[i-1].control == u)):
					if teams[i-1].tm_act != FALL_ACT:
						if i == main_guy:
							d = 1
						else:
							d = teams[i-1].tm_dist

						if d < lowest:
							guy = i
							lowest = d

			if (guy != last_plr_a and guy and
					(last_plr_a <= 0 or (last_plr_a > 0 and not sel_circle[last_plr_a-1]) or receiver_a)):
				clear_auto(u)
				teams[guy-1].control = u8(u)
				users[u-1].chng = TRUE				# changed control
				users[u-1].plr = s8(guy)


#******************************************************************************
#******************************************************************************

# void auto_select_b(short u)
static func auto_select_b(u: int) -> void:
# Team B...
	closest = FALSE

	last_plr_b = users[u-1].plr

	if not (ball_poss and u == teams[ball_poss-1].control):
# This guy doesn't have ball!
		if (ball_poss != KP_B and ball_poss > players/2
				and not teams[ball_poss-1].control):
# His team-mate has ball who isn't a user... (make him this user!)
			clear_auto(u)
			users[u-1].chng = TRUE				# changed control.

			Intell.reset_ideas(teams[ball_poss-1])
			teams[ball_poss-1].control = u8(u)
			users[u-1].plr = s8(ball_poss)
		else:
# Get closest...
			var main_guy: int
			if user_taker2 == u:
				main_guy = KP_B
			else:
				if receiver_b:
					main_guy = receiver_b
				else:
					if interceptor_b:
						main_guy = interceptor_b
					else:
						if near_path_b:
							main_guy = near_path_b
						else:
							main_guy = 0

			var d: float
			var guy: int = 0
			var lowest: float = 2000

			for i in range(12, players+1):
				if ((i != KP_B or match_mode == GOAL_KICK_BR or match_mode == GOAL_KICK_TR or user_taker2)
						and teams[i-1].guy_on > 0 and (not teams[i-1].control or teams[i-1].control == u)):
					if teams[i-1].tm_act != FALL_ACT:
						if i == main_guy:
							d = 1
						else:
							d = teams[i-1].tm_dist

						if d < lowest:
							guy = i
							lowest = d

			if (guy != last_plr_b and guy and
					(last_plr_b <= 0 or (last_plr_b > 0 and not sel_circle[last_plr_b-1]) or receiver_b)):
				clear_auto(u)
				teams[guy-1].control = u8(u)
				users[u-1].chng = TRUE				# changed control
				users[u-1].plr = s8(guy)

#******************************************************************************
#******************************************************************************

# void reselect_a()
static func reselect_a() -> void:
# Team A!
	var user: int
	var maxu: int
	var au: int
	var max_au: int
	var p: int		# signed char
	var max: float = -1
	var d: float

	if auto_users_a:
		if last_user_a == auto_users_a:
			last_user_a = 0

		maxu = auto_users_list_a[last_user_a]

		last_user_a += 1
		if last_user_a == auto_users_a:
			last_user_a = 0

		au = last_user_a
		max_au = au

		for i in range(1, auto_users_a):
			if au == auto_users_a:
				au = 0

			user = auto_users_list_a[au]
			p = users[user-1].plr
			if p <= 0:
				d = 1500
			else:
				d = (teams[p-1].tm_dist)

			if d > max:
				max = d
				maxu = user
				max_au = au
			au += 1
		auto_select_a(maxu)			# Team Control.
		if not ball_poss:
			last_user_a = max_au

#******************************************************************************
#******************************************************************************

# void reselect_b()
static func reselect_b() -> void:
# Team B!
	var user: int
	var maxu: int
	var au: int
	var max_au: int
	var p: int		# signed char
	var max: float = -1
	var d: float

	if auto_users_b:
		if last_user_b == auto_users_b:
			last_user_b = 0

		maxu = auto_users_list_b[last_user_b]

		last_user_b += 1
		if last_user_b == auto_users_b:
			last_user_b = 0

		au = last_user_b
		max_au = au

		for i in range(1, auto_users_b):
			if au == auto_users_b:
				au = 0

			user = auto_users_list_b[au]
			p = users[user-1].plr
			if p <= 0:
				d = 1500
			else:
				d = (teams[p-1].tm_dist)

			if d > max:
				max = d
				maxu = user
				max_au = au
			au += 1
		auto_select_b(maxu)			# Team Control.
		if not ball_poss:
			last_user_b = max_au

#******************************************************************************
#******************************************************************************

# void reselect()
static func reselect() -> void:
	BallInt.predict_ball()
	BallInt.get_nearest()
	new_select = FALSE		# Can be same player...
	closest = FALSE
	reselect_a()
	reselect_b()

#******************************************************************************
#******************************************************************************

# void reselect_all_users()
static func reselect_all_users() -> void:
	for i in range(0, num_of_users):
		reselect()

#******************************************************************************
#******************************************************************************

# #ifdef FORCE_SELECT
# void force_users()
static func force_users() -> void:
	if not FORCE_SELECT:
		return
	if not match_mode and num_of_users:
		var f_user: int
		f_user = 1
		while f_user <= MAX_USERS:
			if not (forced & 1):
				forced >>= 1
			else:
				break
			f_user += 1

		var p: int = users[f_user-1].plr
		var tm: int = (12 if p < 12 else 23)
		var i: int = 1
		while i <= 10:
			p += 1
			if p == tm:
				p -= 10				# Can't be keeper!

			if sel_circle[p-1] and not teams[p-1].control:
				break
			i += 1
		if i != 11:
# Successfull forced selection...
			if p < 12:
				last_plr_a = users[f_user-1].plr
			else:
				last_plr_b = users[f_user-1].plr

			clear_auto(f_user)
			teams[p-1].control = u8(f_user)
			users[f_user-1].chng = TRUE				# changed control
			users[f_user-1].plr = s8(p)
# #endif

#******************************************************************************
#******************************************************************************

# void new_users()
static func new_users() -> void:
	# #ifdef NO_AUTO_SEL: if (!key_togs[0x43]) guards the following if-statement
	if (not NO_AUTO_SEL) or (not key_togs[0x43]):

		if ball_poss and num_of_users and not match_mode:
# Normal play with users and some-one on ball!

			var bt: int = ball_travel		# ball_travel++ > select_cnt
			ball_travel = s16(ball_travel + 1)
			if bt > select_cnt:
				ball_travel = 0
				new_select = FALSE		# Can be same player...
				closest = TRUE

				reselect_a()
				reselect_b()

	if FORCE_SELECT:
		if forced:
			force_users()
