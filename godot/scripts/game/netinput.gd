# Port of SOURCE/NETWORK.C  (assembled by tools/assemble.py - edit the files in parts/)
class_name NetInput extends Glob
#******************************************************************************
# Local input layer of NETWORK.C (joysticks, mouse, keyboard -> users[] ->
# users_dir_i[] ring buffer) and the keyboard interrupt handler of KEYH.CPP.
# All networking parts of NETWORK.C (NetNow packets, modem, master/slave sync)
# are not ported.
#
# Device feeding (replaces the DOS hardware reads):
#   * key_handler(scancode) is called by the Godot driver with PC set-1 scan
#     codes (0xE0 prefix for extended keys, bit 7 = release), exactly as the
#     keyboard controller delivered them to INT 9.
#   * joy_pos (the struct read by ReadJoys) is filled by the driver from Godot
#     joypads as raw "counts" around the calibrated centre (see main.gd).
#   * mouse_dx/mouse_dy/mouse_b are set by the driver for MOUSE_CTRL users.
#******************************************************************************

# struct joy_struct { int FireA1,FireA2,JoyAX,JoyAY; int FireB1,FireB2,JoyBX,JoyBY; };
class joy_struct:
	var FireA1: int = 0
	var FireA2: int = 0
	var JoyAX: int = 0
	var JoyAY: int = 0
	var FireB1: int = 0
	var FireB2: int = 0
	var JoyBX: int = 0
	var JoyBY: int = 0

static var joy_pos: joy_struct = joy_struct.new()
# Raw joystick state written by the Godot driver (what the game port 0x201
# would have measured).
static var hw_joy: joy_struct = joy_struct.new()

# Mouse state written by the Godot driver.
static var mouse_x_pos: int = 160
static var mouse_y_pos: int = 100
static var mouse_b: int = 0

# KEYH.CPP: static l1=0,l2=0,l3=0;  remember last 3 codes to check for pause.
static var kh_l1: int = 0
static var kh_l2: int = 0
static var kh_l3: int = 0

#******************************************************************************
# KEYH.CPP
#******************************************************************************

# void __interrupt __far key_handler()
static func key_handler(a: int) -> void:
	kh_l1 = kh_l2
	kh_l2 = kh_l3
	kh_l3 = a
	if kh_l1 == 0xE1 and kh_l2 == 0x1d and kh_l3 == 0x45:
		if not network_on:
			paused = 0 if paused else 1

	# Ignore 0xFA...
	if a != 0xfa:
		if a != 0xe0:
			if a & 0x80:
				# key released...
				if kh_l2 != 0xe0:			# not special header.
					keys[a & 0x7f] = 0	# Normal key release!
				else:
					# special...
					keys[SPECIALK + (a & 0x7f)] = 0	# Special key release!
			else:
				# new key...
				anykey = TRUE
				if kh_l2 != 0xe0 or a != 0x2a:
					# no special pre-codes...
					if kh_l2 == 0xe0:
						if not keys[SPECIALK + a]:
							# new special...
							keys[SPECIALK + a] = 1
							key_togs[SPECIALK + a] = 0 if key_togs[SPECIALK + a] else 1
					else:
						# Normal key depress...
						if not keys[a]:
							# New norm. key...
							keys[a] = 1
							key_togs[a] = 0 if key_togs[a] else 1

	if a != 0xE1:		# trash normal pause
		if (a & 0x7f) != 0x1d and (a & 0x7f) != 0x45:
			paused = 0

# void claim_key_int(void)
static func claim_key_int() -> void:
	for i in range(128):
		keys[i] = 0

# void release_key_int(void)
static func release_key_int() -> void:
	pass

#******************************************************************************
# JOYSTICKS
#******************************************************************************

# void ReadJoys(struct joy_struct *JoyData)
static func ReadJoys(JoyData: joy_struct) -> void:
	# Hardware read of port 0x201 replaced by the driver-supplied state.
	JoyData.FireA1 = hw_joy.FireA1
	JoyData.FireA2 = hw_joy.FireA2
	JoyData.FireB1 = hw_joy.FireB1
	JoyData.FireB2 = hw_joy.FireB2
	JoyData.JoyAX = hw_joy.JoyAX
	JoyData.JoyAY = hw_joy.JoyAY
	JoyData.JoyBX = hw_joy.JoyBX
	JoyData.JoyBY = hw_joy.JoyBY

# void read_joy1(unsigned short *x, unsigned short *y, unsigned char *sw)  -> [x, y, sw]
static func read_joy1() -> Array:
	return [u16(joy_pos.JoyAX), u16(joy_pos.JoyAY), u8(joy_pos.FireA1 | (joy_pos.FireA2 << 1))]

# void read_joy2(unsigned short *x, unsigned short *y, unsigned char *sw)  -> [x, y, sw]
static func read_joy2() -> Array:
	return [u16(joy_pos.JoyBX), u16(joy_pos.JoyBY), u8(joy_pos.FireB1 | (joy_pos.FireB2 << 1))]

# void read_joystick(char j, unsigned short *x, unsigned short *y, unsigned char *sw)  -> [x, y, sw]
static func read_joystick(j: int) -> Array:
	ReadJoys(joy_pos)
	if not j:
		return read_joy1()
	else:
		return read_joy2()

# void get_joy_max_min(char j) / void calibrate_joy(char j,...)
# Interactive DOS calibration ("Please circle joystick..."): the Godot driver
# supplies calibrated ranges directly (see set_joy_calibration).
static func set_joy_calibration(j: int, cnt_x: int, cnt_y: int, min_x: int, max_x: int, min_y: int, max_y: int) -> void:
	if not j:
		joy1_cnt_x = cnt_x
		joy1_cnt_y = cnt_y
		joy1_min_x = min_x
		joy1_max_x = max_x
		joy1_min_y = min_y
		joy1_max_y = max_y
	else:
		joy2_cnt_x = cnt_x
		joy2_cnt_y = cnt_y
		joy2_min_x = min_x
		joy2_max_x = max_x
		joy2_min_y = min_y
		joy2_max_y = max_y

# int sqrt_i(int a)
static func sqrt_i(a: int) -> int:
	var x: int
	var d: int
	var b: int
	var bt: int = 0x80000000

	if a <= 0:
		return 0

	b = 32
	while b > 0:
		if a & bt:
			break
		else:
			bt >>= 1
		b -= 1

	x = 1 << (b >> 1)

	d = ((((x * x - a) / x) + 1) >> 1)
	while d:
		x -= d
		d = ((((x * x - a) / x) + 1) >> 1)
	return x

# void normalise_joy_i(volatile int *x,volatile int *y)  -> [x, y]
static func normalise_joy_i(x: int, y: int) -> Array:
	var d: int
	d = s32(((x * x) + (y * y)))
	d = s32(d << 12)
	if d > 0:
		d = sqrt_i(d)
		x = s32(x << 21)
		x /= d
		y = s32(y << 21)
		y /= d
	else:
		x = 0
		y = 0
	return [x, y]

# int calc_dist_i(int x,int y)
static func calc_dist_i(x: int, y: int) -> int:
	return sqrt_i(s32(x * x + y * y))

# The 8-way digital joystick quantisation shared by get_joy_dir1/get_joy_dir2.
# (Note the original compares the POINTER x in "if (x>(-(*y)*2))" - always true
#  for a valid pointer - so that branch always yields TUNIT,0. Kept.)
static func _digital(x: int, y: int) -> Array:
	if y >= 0:
		if x >= 0:
			if x > y:
				if x > (y * 2):
					x = TUNIT
					y = 0
				else:
					x = TDIAG
					y = TDIAG
			else:
				if y > (x * 2):
					x = 0
					y = TUNIT
				else:
					x = TDIAG
					y = TDIAG
		else:
			if -x > y:
				if -x > (y * 2):
					x = -TUNIT
					y = 0
				else:
					x = -TDIAG
					y = TDIAG
			else:
				if y > (-(x) * 2):
					x = 0
					y = TUNIT
				else:
					x = -TDIAG
					y = TDIAG
	else:
		if x >= 0:
			if x > -y:
				if true:	# (x>(-(*y)*2)) compares the pointer x
					x = TUNIT
					y = 0
				else:
					x = TDIAG
					y = -TDIAG
			else:
				if -y > (x * 2):
					x = 0
					y = -TUNIT
				else:
					x = TDIAG
					y = -TDIAG
		else:
			if -x > -y:
				if -x > (-y * 2):
					x = TUNIT		# (sic) positive in the original
					y = 0
				else:
					x = -TDIAG
					y = -TDIAG
			else:
				if -y > (-(x) * 2):
					x = 0
					y = -TUNIT
				else:
					x = -TDIAG
					y = -TDIAG
	return [x, y]

# void get_joy_dir1(volatile int *x,volatile int *y,volatile int *f)
static func get_joy_dir1() -> void:
	var rx: int
	var ry: int
	var sw: int
	var d: int
	var x: int = 0
	var y: int = 0
	var r: Array = read_joy1()
	rx = r[0]
	ry = r[1]
	sw = r[2]

	x = rx - joy1_cnt_x
	y = ry - joy1_cnt_y

	ux1 = x
	ux2 = y

	d = calc_dist_i((joy1_max_x - joy1_min_x), (joy1_max_y - joy1_min_y)) * dead_zone / 200

	if calc_dist_i(x, y) < d:
		joy1_move = FALSE
		x = 0
		y = 0
	else:
		joy1_move = TRUE
		var n: Array = normalise_joy_i(x, y)
		x = n[0]
		y = n[1]

	if digital_joy1:
		if not joy1_move:
			x = 0
			y = 0
		else:
			var q: Array = _digital(x, y)
			x = q[0]
			y = q[1]
	joy1_x = x
	joy1_y = y
	joy1_fire = sw

# void get_joy_dir2(volatile int *x,volatile int *y,volatile int *f)
static func get_joy_dir2() -> void:
	var rx: int
	var ry: int
	var sw: int
	var d: int
	var x: int = 0
	var y: int = 0
	var r: Array = read_joy2()
	rx = r[0]
	ry = r[1]
	sw = r[2]

	x = rx - joy2_cnt_x
	y = ry - joy2_cnt_y
	d = calc_dist_i((joy2_max_x - joy2_min_x), (joy2_max_y - joy2_min_y)) * dead_zone / 200

	if calc_dist_i(x, y) < d:
		joy2_move = FALSE
		x = 0
		y = 0
	else:
		joy2_move = TRUE
		var n: Array = normalise_joy_i(x, y)
		x = n[0]
		y = n[1]

	if digital_joy2:
		if not joy2_move:
			x = 0
			y = 0
		else:
			var q: Array = _digital(x, y)
			x = q[0]
			y = q[1]
	joy2_x = x
	joy2_y = y
	joy2_fire = sw

#******************************************************************************
# MOUSE
#******************************************************************************

# void get_mouse_dir(volatile struct user_config *user)
static func get_mouse_dir(user: user_config) -> void:
	var x: int
	var y: int
	x = mouse_x_pos - 160
	y = mouse_y_pos - 100
	x <<= 15
	x /= 160
	y <<= 15
	y /= 100

	user.inp_fb = mouse_b
	user.inp_x = x
	user.inp_y = y

	# MouseXYset(160,100);			// reset mouse origin.
	mouse_x_pos = 160
	mouse_y_pos = 100

#******************************************************************************
# KEYBOARD
#******************************************************************************

# short get_key_code(signed char *ks)
static func get_key_code(ks: Array) -> int:
	var k: int = 0
	var ki: int
	for i in range(6):
		ki = ks[i]
		if ki < 0:
			ki = SPECIALK - ki
			if keys[ki]:
				k += (1 << i)
		else:
			if keys[ki]:
				k += (1 << i)
	return k

# void get_key_dir(volatile struct user_config *user,signed char *kb)
static func get_key_dir(user: user_config, kb: Array) -> void:
	var k: int
	k = get_key_code(kb)
	user.inp_fb = FALSE

	if k >= 32:			# Fire 2
		user.inp_fb = 2
		k -= 32

	if k >= 16:			# Fire 1
		user.inp_fb += 1
		k -= 16

	match k:
		0:
			user.inp_x = 0
			user.inp_y = 0
		1:
			user.inp_x = 0
			user.inp_y = -32768
		2:
			user.inp_x = 0
			user.inp_y = 32767
		4:
			user.inp_x = -32768
			user.inp_y = 0
		5:
			user.inp_x = -TDIAG
			user.inp_y = -TDIAG
		6:
			user.inp_x = -TDIAG
			user.inp_y = TDIAG
		7:
			user.inp_x = -32768
			user.inp_y = 0
		8:
			user.inp_x = 32767
			user.inp_y = 0
		9:
			user.inp_x = TDIAG
			user.inp_y = -TDIAG
		10:
			user.inp_x = TDIAG
			user.inp_y = TDIAG
		11:
			user.inp_x = 32767
			user.inp_y = 0
		13:
			user.inp_x = 0
			user.inp_y = -32768
		14:
			user.inp_x = 0
			user.inp_y = 32767
		_:
			user.inp_x = 0
			user.inp_y = 0

#******************************************************************************
# GENERAL
#******************************************************************************

# void get_user_inputs()
static func get_user_inputs() -> void:
	ReadJoys(joy_pos)

	for i in range(num_of_users):
		match users[i].control:
			JOY1_CTRL:
				get_joy_dir1()
				users[i].inp_x = joy1_x
				users[i].inp_y = joy1_y
				users[i].inp_fb = joy1_fire

			JOY2_CTRL:
				get_joy_dir2()
				users[i].inp_x = joy2_x
				users[i].inp_y = joy2_y
				users[i].inp_fb = joy2_fire

			KEY1_CTRL:
				get_key_dir(users[i], key1)

			KEY2_CTRL:
				get_key_dir(users[i], key2)

			MOUSE_CTRL:
				get_mouse_dir(users[i])

# void process_user_inputs()
static func process_user_inputs() -> void:
	var x: int
	var y: int
	var a: int
	var b: int

	for i in range(num_of_users):
		if users[i].type and users[i].control != NET_CTRL:		# Not computer or net guy
			x = users[i].inp_x
			y = users[i].inp_y
			a = s32(x * icth)
			b = s32(y * isth)
			a = s32(a - b) >> 15

			if a < -32767:
				a = -32767
			if a > 32767:
				a = 32767

			users_dir_i[writeptr][i].x_f1 = s16(a)

			a = s32(y * icth)
			b = s32(x * isth)
			a = s32(a + b) >> 15

			if a < -32767:
				a = -32767
			if a > 32767:
				a = 32767

			users_dir_i[writeptr][i].y_f2 = s16(a)

			users_dir_i[writeptr][i].x_f1 = s16(users_dir_i[writeptr][i].x_f1 & 0xfffe)
			users_dir_i[writeptr][i].x_f1 = s16(users_dir_i[writeptr][i].x_f1 | (users[i].inp_fb & 1))
			users_dir_i[writeptr][i].y_f2 = s16(users_dir_i[writeptr][i].y_f2 & 0xfffe)
			users_dir_i[writeptr][i].y_f2 = s16(users_dir_i[writeptr][i].y_f2 | ((users[i].inp_fb & 2) >> 1))
			users[i].inp_ox = x
			users[i].inp_oy = y

#******************************************************************************
# INTERRUPT TIMER CODE
#******************************************************************************

# void __far nethandler(void)  -- the 200Hz timer interrupt (TIMER_SPEED).
# Called by the Godot driver once per elapsed 1/200 s.
static func nethandler() -> void:
	count += 1
	ftick += game_speed
	if ftick >= TIMER_SPEED:
		ftick -= TIMER_SPEED
		while ftick > TIMER_SPEED:
			ftick -= TIMER_SPEED
		tick += 1
		hold_loop = 1 # ACTIVE

		if not old_mf:
			if netsetup_on:  					# If in network setup...
				pass	# NETWORK: NetInitialisation();
			else:
				if network_on:					# If a network game...
					pass	# NETWORK: master/slave input exchange
				else:  				# If not a network game...
					if not paused:	# and not paused...
						get_user_inputs()
						process_user_inputs()
						writeptr += 1
						writeptr &= 511				# Move to next block

# STUB (not yet ported): void get_joy_max_min(...)
static func get_joy_max_min(j):
	pass

# STUB (not yet ported): void calibrate_joy(...)
static func calibrate_joy(j, x, y):
	pass

# STUB (not yet ported): void TickPause(...)
static func TickPause():
	pass

# STUB (not yet ported): int FindAddress(...)
static func FindAddress(daddress):
	return 0

# STUB (not yet ported): void pausehandler(...)
static func pausehandler():
	pass

# STUB (not yet ported): int Initialise_Network(...)
static func Initialise_Network():
	return 0

# STUB (not yet ported): int Poll_Network(...)
static func Poll_Network():
	return 0

# STUB (not yet ported): int Start_Network_Game(...)
static func Start_Network_Game():
	return 0

# STUB (not yet ported): void Network_Play_Ready(...)
static func Network_Play_Ready():
	pass

# STUB (not yet ported): void Quit_Network_Play(...)
static func Quit_Network_Play():
	pass

# STUB (not yet ported): void End_Network_Game(...)
static func End_Network_Game():
	pass

# STUB (not yet ported): int NetTest(...)
static func NetTest():
	return 0

# STUB (not yet ported): void crap(...)
static func crap():
	pass

