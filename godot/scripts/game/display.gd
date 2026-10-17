# Port of SOURCE/DISPLAY.CPP  (assembled by tools/assemble.py - edit the files in parts/)
class_name Display extends Glob
#******************************************************************************
#******************************************************************************
#
# Display output routines...
#
# Only the routines used by the 3D match are ported; the rest of DISPLAY.CPP is
# the 2D overhead debug view (grid_map, pitch_markings, draw_team, buttons...),
# which only runs with on_3d==FALSE (development editor) and draws straight to
# VGA memory.
#
#******************************************************************************
#******************************************************************************

# void init_pitch_sprites()
static func init_pitch_sprites() -> void:
	pitch_sprs = 0
	spr_coord_tab[0] = 0

# void add_pitch_sprite(short x,short y,short z,short ref)
static func add_pitch_sprite(x: int, y: int, z: int, ref: int) -> void:
	# Set up real 3d sprite...
	spr_coord_tab[0] += 1
	spr_coord_tab[3 * pitch_sprs + 1] = x
	spr_coord_tab[3 * pitch_sprs + 2] = z
	spr_coord_tab[3 * pitch_sprs + 3] = -y
	spr_ref_tab[pitch_sprs] = ref
	pitch_sprs += 1

# int old_time=0; int prev_count=0; int times=0;  (Glob: old_time, prev_count, times)

# void frame_count()
static func frame_count() -> void:
	updates += 1
	frames += 1
	times += 1

	var cl: int = count - oldcnt

	if count - prev_count > TIMER_SPEED:
		prev_count = count
		old_time = times

	if cl > (TIMER_SPEED / 4):			# Re-time interval (1/4 sec)!
		oldcnt = count
		MF = (float(cl) * game_speed) / (frames * TIMER_SPEED)
		if MF > 6 and game_speed == REAL_SPEED:
			MF = 6
		frames = 0

# void oframe_count()
static func oframe_count() -> void:
	updates += 1
	var cl: int = int(Time.get_ticks_msec() / 10)		# clock() in CLOCKS_PER_SEC=100 ticks
	frames += 1
	var c: int = cl / 100
	if c != last_second:
		seconds += 1
		frms_per_sec = frames
		frames = 0
		last_second = c
		var frame_time: int = cl - old_clock
		old_clock = cl
		MF = (float(frame_time) * game_speed) / (frms_per_sec * 100)

# STUB (not yet ported): void grid_map(...)
static func grid_map():
	pass

# STUB (not yet ported): void line_border(...)
static func line_border(x, y, wid, hgt, col):
	pass

# STUB (not yet ported): void draw_buttons(...)
static func draw_buttons():
	pass

# STUB (not yet ported): void light_button(...)
static func light_button(b):
	pass

# STUB (not yet ported): void unlight_button(...)
static func unlight_button(b):
	pass

# STUB (not yet ported): void conv_xypitch(...)
static func conv_xypitch(x, y, screen_x, screen_y):
	pass

# STUB (not yet ported): void pitch_markings(...)
static func pitch_markings():
	pass

# STUB (not yet ported): void draw_pitch(...)
static func draw_pitch():
	pass

# STUB (not yet ported): void draw_buffer(...)
static func draw_buffer():
	pass

# STUB (not yet ported): void draw_ball(...)
static func draw_ball():
	pass

# STUB (not yet ported): void draw_team(...)
static func draw_team():
	pass

# STUB (not yet ported): void panel_data(...)
static func panel_data():
	pass

# STUB (not yet ported): void slower(...)
static func slower():
	pass

# STUB (not yet ported): void faster(...)
static func faster():
	pass

# STUB (not yet ported): void show_nums(...)
static func show_nums():
	pass

