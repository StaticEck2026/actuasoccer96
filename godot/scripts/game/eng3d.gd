# Port of the parts of SOURCE/3DENG.C (Laurent Noel's 3D engine) that are not the
# software rasteriser: the 2D overlay drawn over the 3D view (in-game menus and
# banners, draw_sprite/draw_string, scanner, clock/score line, screen buffers),
# the modal in-game menus (options / formation / substitution / replay) with
# their input reader get_dir(), the vidi-wall animation triggers, the stadium
# table hooks and screen setup.
#
# Port notes
# * The software rasteriser (render3d's 3D part, dump*() to VGA memory) is
#   replaced by the Godot renderer (scripts/render/match_view.gd).
# * The overlay is drawn into an emulated 8-bit screen buffer `scrb` by a
#   drawing device (scripts/render/hud.gd, `Eng3D.dev`) that implements the two
#   pixel primitives used here: sprite copies from the "extra" map pages
#   maps[X_BM..] (spr()) and the filters[0] shadow (shadow()). All the address
#   arithmetic, clipping and table logic of 3DENG.C is here, line by line.
#   Buffer pointers (buff_info.buff_start) are byte offsets into scrb.
# * The modal loops options(), formation(), substitution(), replay() were
#   blocking loops with their own render3d()/dump() calls. Here options() /
#   substitution() (called from update_3d()) set up the loop and `modal`; the
#   driver then calls hud.update_hud() -> Eng3D.modal_frame() once per Godot
#   frame, which runs exactly one iteration (= one rendered frame) of the
#   current loop. The code that ran in update_3d() after options()/
#   substitution() returned is redone when the loop ends (_modal_end()).
# * 3D Blaster (scrmode3DB>=0) branches are not ported (scrmode3DB is -1).
@warning_ignore("integer_division")
class_name Eng3D extends Glob

# Stadium table: stadlist[] / stad_info live in Glob (tools/glob_extra.gd).

#******************************************************************************
# Constants (3DENG.C / EURO_SYM.H / EURODEFS.H / EURO_DEF.H)
#******************************************************************************

const X_BM := 6				# Bitmap offset for extra maps
const S_BM := 8				# Bitmap offset for stand maps
const SCRSIZES := 10			# Screen buffer sizes
const VESAMODES := 2
const NO_MENUS := 24
const M_WIDTH := 256

# get_dir() bits
const RIGHT_DIR := 1
const LEFT_DIR := 2
const DOWN_DIR := 4
const UP_DIR := 8
const FIRE1_DIR := 16
const FIRE2_DIR := 32
const F1_DIR := 64
const F2_DIR := 128
const F3_DIR := 256
const F4_DIR := 512
const BUTT_WAIT := 65

# EURO_SYM.H text numbers (GetTEXT)
const PLYR_NMES := 0
const TEAM_NMES := 320
const QUIT_TEXT := 1600
const GLSC_TEXT := 1700
const YLCD_TEXT := 1701
const RDCD_TEXT := 1702
const DRKC_TEXT := 1703
const IDKC_TEXT := 1704
const PENK_TEXT := 1705
const CORK_TEXT := 1706
const THIN_TEXT := 1707
const GKIK_TEXT := 1708
const KIOF_TEXT := 1709
const OFFS_TEXT := 1710
const PLIN_TEXT := 1711
const FLTM_TEXT := 1712
const EXTM_TEXT := 1713
const HFTM_TEXT := 1714
const PNST_TEXT := 1715
const FNSP_TEXT := 1716
const OWGL_TEXT := 1717
const RPLY_TEXT := 1718
const SBTN_TEXT := 1719
const FRMN_TEXT := 1720
const CANL_TEXT := 1721
const SLCT_TEXT := 1722
const SOFF_TEXT := 1723
const SUBT_TEXT := 1724
const SBON_TEXT := 1725
const DONE_TEXT := 1726
const OPTN_TEXT := 1727
const RFRE_TEXT := 1728
const PENS_TEXT := 1729
const OWNG_TEXT := 1730

# EURODEFS.H name formats INITIAL_SURNAME/SURNAME/FULL_NAME, EURO_DEF.H
# NAME_BUFFER_LEN and the IsUpper[] values na/lw/up are in consts.gd.

# 3DENG.C: #define TEMPa 0 / TEMPb 1 -> game_data[TEMPa] is team A's data. The
# port keeps all 16 teams in game_data[] indexed by setup.team_a / team_b.
static func _gd(t: int) -> team_info:
	return game_data[setup.team_a if t == 0 else setup.team_b]

#******************************************************************************
# Screen buffer info (3DENG.H buff_info)
#******************************************************************************

class buff_info:
	var buff_start: int = 0		# BYTE *  (offset into scrb)
	var buff_wid: int = 0		# scrpt
	var buff_hgt: int = 0
	var clip_wid: int = 0
	var clip_hgt: int = 0
	var scale_x: float = 0.0
	var scale_y: float = 0.0
	var dump: int = 0			# 0 dumpnull, 1 dumpMCGA, 2 dumpV256
	func _init(bw: int = 0, bh: int = 0, cw: int = 0, ch: int = 0, sx: float = 0.0, sy: float = 0.0, d: int = 0) -> void:
		buff_wid = bw
		buff_hgt = bh
		clip_wid = cw
		clip_hgt = ch
		scale_x = sx
		scale_y = sy
		dump = d
	func copy_from(o: buff_info) -> void:
		buff_start = o.buff_start
		buff_wid = o.buff_wid
		buff_hgt = o.buff_hgt
		clip_wid = o.clip_wid
		clip_hgt = o.clip_hgt
		scale_x = o.scale_x
		scale_y = o.scale_y
		dump = o.dump

static func _bt(rows: Array, d: int) -> Array:
	var a: Array = []
	for r in rows:
		a.append(buff_info.new(r[0], r[1], r[2], r[3], r[4], r[5], d))
	return a

# Space for main screen buffer: BYTE *scrb  (mallocx(640*482))
const SCRB_SIZE := 640 * 482

# VESA mode list
static var modelist: Array = [0x100, 0x101, -1]
# Modes the (emulated) VESA BIOS supports. VESAmode(modelist) returns the first
# mode of the preference list that the card supports -> 0x100 (640x400).
static var vesa_supported: Array = [0x100, 0x101]

# Screen buffer information (w%8=0,h%2=0)
static var MCGA_buff: Array = _bt([
	[320, 200, 320, 200, 0.5, 0.5],
	[320, 200, 296, 184, 0.4625, 0.46],
	[320, 200, 320, 158, 0.5, 0.3975],
	[320, 200, 264, 166, 0.4125, 0.4175],
	[320, 200, 296, 142, 0.4625, 0.355],
	[320, 200, 240, 150, 0.375, 0.375],
	[320, 200, 264, 124, 0.4125, 0.3125],
	[320, 200, 216, 132, 0.3375, 0.3325],
	[320, 200, 240, 108, 0.375, 0.2725],
	[320, 200, 216, 92, 0.3375, 0.23],
	], 1)
static var VESA_buff: Array = [
	_bt([
	[640, 400, 640, 400, 1, 1],
	[640, 400, 584, 366, 0.9125, 0.9175],
	[640, 400, 640, 316, 1, 0.79],
	[640, 400, 528, 332, 0.825, 0.8325],
	[640, 400, 584, 284, 0.9125, 0.71],
	[640, 400, 480, 300, 0.75, 0.75],
	[640, 400, 528, 250, 0.825, 0.625],
	[640, 400, 424, 266, 0.6625, 0.6675],
	[640, 400, 480, 216, 0.75, 0.54],
	[640, 400, 424, 184, 0.6625, 0.46],
	], 2),
	_bt([
	[640, 480, 640, 480, 1, 1.2],
	[640, 480, 584, 440, 0.9125, 1.1],
	[640, 480, 640, 380, 1, 0.95],
	[640, 480, 528, 400, 0.825, 1],
	[640, 480, 584, 340, 0.9125, 0.85],
	[640, 480, 480, 360, 0.75, 0.9],
	[640, 480, 528, 300, 0.825, 0.75],
	[640, 480, 424, 320, 0.6625, 0.8],
	[640, 480, 480, 260, 0.75, 0.65],
	[640, 480, 424, 220, 0.6625, 0.55],
	], 2),
	]

static var menu_buff_l: Array = _bt([
	[320, 64, 320, 64, 0, 0],
	[320, 64, 320, 64, 0, 0],
	[320, 64, 320, 64, 0, 0],
	[320, 64, 224, 64, 0, 0],
	[320, 64, 224, 64, 0, 0],
	[320, 64, 192, 64, 0, 0],
	[320, 64, 192, 64, 0, 0],
	[320, 64, 192, 64, 0, 0],
	[320, 64, 192, 64, 0, 0],
	[320, 64, 192, 64, 0, 0],
	[320, 64, 224, 64, 0, 0],
	[320, 64, 320, 64, 0, 0],
	[320, 128, 288, 128, 0, 0],
	[320, 128, 288, 128, 0, 0],
	[320, 128, 288, 128, 0, 0],
	[320, 128, 288, 128, 0, 0],
	[320, 128, 288, 128, 0, 0],
	[320, 64, 320, 64, 0, 0],
	[320, 128, 160, 128, 0, 0],
	[320, 112, 160, 112, 0, 0],
	[320, 128, 224, 128, 0, 0],
	[320, 80, 288, 80, 0, 0],
#	 {NULL, 320,64, 224,64, 0, 0, dumpnull},
	[320, 64, 320, 64, 0, 0],
	[320, 160, 256, 160, 0, 0],
	], 0)
static var menu_buff_h: Array = _bt([
	[640, 128, 640, 128, 0, 0],
	[640, 128, 640, 128, 0, 0],
	[640, 128, 640, 128, 0, 0],
	[640, 128, 448, 128, 0, 0],
	[640, 128, 448, 128, 0, 0],
	[640, 128, 384, 128, 0, 0],
	[640, 128, 384, 128, 0, 0],
	[640, 128, 384, 128, 0, 0],
	[640, 128, 384, 128, 0, 0],
	[640, 128, 384, 128, 0, 0],
	[640, 128, 448, 128, 0, 0],
	[640, 128, 640, 128, 0, 0],
	[640, 256, 576, 256, 0, 0],
	[640, 256, 576, 256, 0, 0],
	[640, 256, 576, 256, 0, 0],
	[640, 256, 576, 256, 0, 0],
	[640, 256, 576, 256, 0, 0],
	[640, 128, 640, 128, 0, 0],
	[640, 256, 320, 256, 0, 0],
	[640, 224, 320, 224, 0, 0],
	[640, 256, 448, 256, 0, 0],
	[640, 160, 576, 160, 0, 0],
#	 {NULL, 640,128, 448,128, 0, 0, dumpnull},
	[640, 128, 640, 128, 0, 0],
	[640, 320, 512, 320, 0, 0],
	], 0)

static var main_buff: buff_info = buff_info.new()		# Current main screen buffer info
static var menu_buff: buff_info = buff_info.new()		# Current menu buffer info
static var render_buff: buff_info = buff_info.new()	# (buff_info_ext) Extended buffer info for rendering

# word scrmode;  (S)VGA mode number (including VESA). The match used 0x13
# (320x200, fonts 0/1) or the first supported VESA mode (640x400, font 2).
static var scrmode: int = 0x100
static var scrmode3DB: int = -1		# 3D Blaster mode number (-ve if not available)

# Front-end resolution choice (EURO_MAT.CPP: setup.start_res=EUROresoln). The
# port defaults to high resolution; set to 0 for 320x200, -1 to keep setup.start_res.
static var start_res_choice: int = 1

static var _buffers_ready: bool = false

#******************************************************************************
# FGFX.C (#included by 3DENG.C): fonts and sprites on maps[X_BM+page]
#******************************************************************************

# struct {int page,x,y,n,off; BYTE wid,hgt; BYTE prp[43];} font_data[]
static var font_data: Array = [
	[0, 168, 171, 11, 0, 8, 5, [
	5,5,5,5,5,5,5,5,5,5,2,4,5,5,5,2,
	1,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
	5,5,5,5,5,5,5,5,5,5,5,
	]],
	[0, 96, 143, 9, 0, 8, 7, [
	7,6,7,7,7,7,7,7,7,7,3,4,6,7,6,4,
	3,7,7,7,7,7,7,7,7,6,7,7,7,7,7,7,
	7,7,7,7,6,7,7,7,7,7,7,
	]],
	[0, 96, 191, 10, 7, 16, 13, [
	11,8,11,11,11,10,11,11,11,11,5,9,11,11,11,7,
	5,14,11,12,12,9,9,14,12,5,8,13,9,16,13,14,
	11,14,12,10,11,12,13,16,14,11,13
	]],
	]

# Sprite 0 is variable, don't use
# struct {int page,x,y,wid,hgt;} spr_data[]
static var spr_data: Array = [
	[0,0,0,16,16],
	[1,0,192,48,240],
	[0,0,180,24,24],
	[0,24,180,24,24],
	[0,48,180,24,24],
	[0,72,180,24,24],
	[0,0,204,24,24],
	[0,24,204,24,24],
	[0,48,204,24,24],
	[0,72,204,24,24],
	[0,0,228,24,24],
	[0,24,228,24,24],
	[0,48,228,24,24],
	[0,72,228,24,24],
	[0,96,180,24,24],
	[0,120,180,24,24],
	[0,144,180,24,24],
	[0,0,49,39,12],
	[0,168,192,39,12],
	[1,0,0,69,79],
	[1,69,0,69,79],
	[1,138,0,21,22],
	[1,191,0,32,9],
	[1,171,0,9,32],
	[1,91,81,165,30],
	[1,0,81,91,30],
	[1,170,35,57,30],
	[1,181,0,9,18],
	[1,159,0,12,18],
	[1,76,111,52,53],
	[1,220,111,35,40],
	[1,220,151,35,40],
	[1,227,29,11,11],
	[1,138,23,32,5],
	[1,250,35,5,32],
	[1,167,65,83,15],
	[1,181,19,46,15],
	[1,137,65,29,15],
	[1,197,9,4,9],
	[1,191,9,5,9],
	[1,228,1,27,27],
	[1,37,111,39,48],
	[1,170,34,39,47],
	[1,210,40,39,41],
	[1,122,173,70,83],
	[1,52,173,70,83],
	[1,176,111,44,77],
	[1,134,111,21,26],
	[1,155,133,21,27],
	[1,155,111,21,22],
	[1,16,170,36,43],
	[1,16,213,36,43],
	[1,15,111,22,41],
	[0,0,62,23,27],
	[0,23,62,23,27],
	[0,46,62,23,27],
	[0,69,62,23,27],
	[0,92,62,23,27],
	[0,115,62,23,27],
	[0,138,62,23,27],
	[0,161,62,23,27],
	[0,184,62,23,27],
	[0,207,62,23,27],
	[0,230,62,23,27],
	[0,69,116,23,27],
	[0,92,116,23,27],
	[0,115,116,23,27],
	[0,138,116,23,27],
	[0,0,89,23,27],
	[0,23,89,23,27],
	[0,46,89,23,27],
	[0,69,89,23,27],
	[0,92,89,23,27],
	[0,115,89,23,27],
	[0,138,89,23,27],
	[0,161,89,23,27],
	[0,184,89,23,27],
	[0,207,89,23,27],
	[0,230,89,23,27],
	[0,161,116,23,27],
	[0,184,116,23,27],
	[0,207,116,23,27],
	[0,230,116,23,27],
	[1,250,35,5,16],
	[1,0,111,14,16],
	[1,0,127,14,16],
	[1,38,111,18,20],
	[1,56,111,18,20],
	[1,129,112,34,46],
	[1,129,158,4,4],
	[1,133,158,7,7],
	[1,140,158,4,4],
	[1,144,158,7,7],
	[1,192,192,64,63],	# 93
	[1,192,192,32,63], 	# 94
	[1,192,192,16,63],	# 95
	[1,192,192,8 ,63],	# 96
	[1,192,192,4 ,63], 	# 97
	[1,192,192,2 ,63],	# 98
	[1,192,192,64,32],	# 99
	[1,192,192,32,32],	# 100
	[1,192,192,16,32], 	# 101
	[1,192,192,8 ,32], 	# 102
	[1,192,192,4 ,32], 	# 103
	[1,192,192,2 ,32], 	# 104
	[1,192,192,64,16],	# 105
	[1,192,192,32,16],	# 106
	[1,192,192,16,16],	# 107
	[1,192,192,8 ,16], 	# 108
	[1,192,192,4 ,16], 	# 109
	[1,192,192,2 ,16], 	# 110
	[1,192,192,64,8 ], 	# 111
	[1,192,192,32,8 ], 	# 112
	[1,192,192,16,8 ], 	# 113
	[1,192,192,8 ,8 ], 	# 114
	[1,192,192,4 ,8 ],	# 115
	[1,192,192,2 ,8 ], 	# 116
	[1,192,192,64,4 ], 	# 117
	[1,192,192,32,4 ], 	# 118
	[1,192,192,16,4 ], 	# 119
	[1,192,192,8 ,4 ], 	# 120
	[1,192,192,4 ,4 ], 	# 121
	[1,192,192,2 ,4 ], 	# 122
	[1,192,192,64,2 ], 	# 123
	[1,192,192,32,2 ], 	# 124
	[1,192,192,16,2 ], 	# 125
	[1,192,192,8 ,2 ], 	# 126
	[1,192,192,4 ,2 ], 	# 127
	[1,192,192,2 ,2 ], 	# 128
	]

# The font tables are followed by spr_data in memory: an out-of-range
# font_data[f].prp[c] (characters the fonts do not have) reads those bytes.
static func _prp(font_no: int, c: int) -> int:
	var off: int = font_no * 68 + 22 + c
	if off < 3 * 68:
		var f: Array = font_data[off / 68]
		var o: int = off % 68
		if o < 20:
			return (int(f[o / 4]) >> (8 * (o % 4))) & 255
		if o == 20:
			return f[5]
		if o == 21:
			return f[6]
		if o < 65:
			return f[7][o - 22]
		return 0
	var so: int = off - 3 * 68
	var e: Array = spr_data[so / 20]
	return (int(e[(so % 20) / 4]) >> (8 * (so % 4))) & 255

#******************************************************************************
# Menu state (3DENG.C)
#******************************************************************************

static var slco: float = 0.0		# float slco;  Slide counter
static var slide: int = 0
static var oslide: int = 0
static var mcount: int = 0		# Menu display time
static var menu: int = 0			# Current overlay menu (0 = none)
static var mhgt: int = 0
static var rdmenu: int = 0		# Redraw menu flag
static var mdata1: int = 0
static var mdata2: int = 0
static var mdata3: int = 0

# word menx3DB,meny3DB;  Offset for menus on 3D Blaster
static var menx3DB: int = 0
static var meny3DB: int = 0

# char sub_pending;  (bit 0: team 0 wants a substitution, bit 1: team 1)
static var sub_pending: int = 0
static var sub_p_a: int = 0
static var sub_p_b: int = 0

# struct {int formation; int sub_off,sub_on;} option_info;
static var option_info_formation: int = 0
static var option_info_sub_off: int = 0
static var option_info_sub_on: int = 0
static var sub_c: int = 0

static var opt_b: int = 0
static var for_b: int = 0
static var sub_b: int = 0
static var rep_b: int = 0
static var play: int = 0
static var speed: int = 0
static var reppos: float = 0.0

static var forms: Array = [
	"4=3=3",
	"5=3=2",
	"6=3=1",
	"4=2=4",
	"5=1=4",
	"4=0=6",
	"3=1=6",
	"4=1=5",
	"5=2=3",
	"4=4=2",
	]

# static short kco (render3d)
static var kco: int = 0

# Drawing device (scripts/render/hud.gd): spr(), shadow(), fill(), scr_wid
static var dev = null

#******************************************************************************
# Front-end text (EURO_INT.CPP GetTEXT / GetPLAYERSname, Text[] of SCRIPT.96)
#******************************************************************************

const HUD_JSON := "res://assets/hud/hud.json"
static var hud_data: Dictionary = {}

static func load_data() -> bool:
	if not hud_data.is_empty():
		return true
	var f := FileAccess.open(HUD_JSON, FileAccess.READ)
	if f == null:
		push_error("Eng3D: cannot open " + HUD_JSON)
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		push_error("Eng3D: bad " + HUD_JSON)
		return false
	hud_data = d
	return true

static func _bytes_of(a) -> PackedByteArray:
	var b := PackedByteArray()
	for v in a:
		b.append(int(v))
	return b

# char *GetTEXT( short StringNumber )
static func GetTEXT(StringNumber: int) -> PackedByteArray:
	if not load_data():
		return PackedByteArray()
	var t: Dictionary = hud_data.text
	if StringNumber >= PLYR_NMES and StringNumber < PLYR_NMES + 320:
		return _bytes_of(t.player_names[StringNumber - PLYR_NMES])
	if StringNumber >= TEAM_NMES and StringNumber < TEAM_NMES + 16:
		return _bytes_of(t.team_names[StringNumber - TEAM_NMES])
	var k := str(StringNumber)
	if t.strings.has(k):
		return _bytes_of(t.strings[k])
	return PackedByteArray()

# EURO_VAR.CPP: signed char IsUpper[255]  (CP437)
static var IsUpper: PackedInt32Array = _mk_isupper()
static func _mk_isupper() -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(256)
	a.fill(na)
	for c in range(65, 91):
		a[c] = up
	for c in range(97, 123):
		a[c] = lw
	var hi: Array = [
		up, lw, lw, lw, lw, lw, lw, lw,
		lw, lw, lw, lw, lw, lw, up, up,
		up, lw, up, lw, lw, lw, lw, lw,
		lw, up, up, na, na, na, na, na,
		lw, up, lw, lw, lw, up, na, na]
	for i in range(hi.size()):
		a[128 + i] = hi[i]
	a[225] = up
	a[253] = up
	return a

# EURO_VAR.CPP: unsigned char ToLower[255]
static func ToLower(c: int) -> int:
	if c < 32:
		return 0
	if c >= 65 and c <= 90:
		return c + 32
	if c < 128:
		return c
	# CP437 accented capitals -> small letters
	var m := {128: 135, 142: 132, 143: 134, 144: 130, 146: 145, 153: 148, 154: 129, 165: 164}
	return m.get(c, c)

# char StringBuffer[NAME_BUFFER_LEN+1]
static var StringBuffer: PackedByteArray = _mk_sbuf()
static func _mk_sbuf() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(NAME_BUFFER_LEN + 1)
	return b

static func _at(s: PackedByteArray, i: int) -> int:
	# *(Search+i): the string's terminating 0 (and the previous string's 0
	# before it in TextStrings) read as 0.
	if i < 0 or i >= s.size():
		return 0
	return s[i]

static func _sb(i: int) -> int:
	if i < 0 or i >= StringBuffer.size():
		return 0
	return StringBuffer[i]

static func _name_prefix(p: int) -> int:
	if not load_data():
		return 0
	var a: Array = hud_data.text.name_prefix
	return int(a[p]) if p >= 0 and p < a.size() else 0

# char *GetPLAYERSname( char player, char team, char format )
static func GetPLAYERSname(player: int, team: int, format: int) -> PackedByteArray:
	var Prefix: int = (team * 20) + player
	var Search: PackedByteArray = GetTEXT(PLYR_NMES + Prefix)
	var NAMEoffset: int = 0
	var Searchlen: int = Search.size()
	var c: int

	if format == FULL_NAME:
		var x: int = 0
		while x < Searchlen:
			StringBuffer[x] = _at(Search, x)
			x += 1
		StringBuffer[x] = 0

	if format == INITIAL_SURNAME:
		# *** Get players initials ***
		for x in range(Searchlen):
			if IsUpper[_at(Search, x)] == up and \
					IsUpper[_at(Search, x + 1)] == lw and \
					NAMEoffset < (NAME_BUFFER_LEN - 3):
				StringBuffer[NAMEoffset] = _at(Search, x)
				NAMEoffset += 1

				if _at(Search, x) == 45:		# '-'
					StringBuffer[NAMEoffset] = 45
				else:
					StringBuffer[NAMEoffset] = 46	# '.'

				StringBuffer[NAMEoffset + 1] = 32
				NAMEoffset += 2

			if _at(Search, x) == 45 and NAMEoffset > 1:
				StringBuffer[NAMEoffset - 2] = 45
				NAMEoffset -= 1

	if format == INITIAL_SURNAME or format == SURNAME:
		# *** Get players surname ***
		for y in range(Searchlen):
			if IsUpper[_at(Search, y)] == up and \
					IsUpper[_at(Search, y + 1)] == up and \
					NAMEoffset < (NAME_BUFFER_LEN - 3):
				StringBuffer[NAMEoffset] = _at(Search, y)

#				if ( (IsUpper[ *(Search+(y-1) ) ] == up && y>0) &&
#				     NamePREFIXtbl[Prefix] == 1 && ...

				if IsUpper[_at(Search, y - 1)] == up and y > 0:
					c = StringBuffer[NAMEoffset]

					if _sb(NAMEoffset - 2) == 77 and _sb(NAMEoffset - 1) == 99 and \
							NAMEoffset > 1 and _name_prefix(Prefix) == 1:	# 'M' 'c'
						c = StringBuffer[NAMEoffset]
					else:
						c = StringBuffer[NAMEoffset]
						StringBuffer[NAMEoffset] = ToLower(c)

				NAMEoffset += 1

			else:
				if IsUpper[_at(Search, y)] == up and \
						IsUpper[_at(Search, y - 1)] == up and \
						NAMEoffset < (NAME_BUFFER_LEN - 3) and y > 0:
					StringBuffer[NAMEoffset] = _at(Search, y)

					if IsUpper[_at(Search, y - 1)] == up and y > 0:
						c = StringBuffer[NAMEoffset]
						StringBuffer[NAMEoffset] = ToLower(c)

					NAMEoffset += 1

					if _at(Search, y + 1) == 32:
						StringBuffer[NAMEoffset] = 32
						NAMEoffset += 1

		StringBuffer[NAMEoffset] = 0	# end of line.

	return _cstring(StringBuffer)

static func _cstring(b: PackedByteArray) -> PackedByteArray:
	var n: int = b.find(0)
	if n < 0:
		return b.duplicate()
	return b.slice(0, n)

# Convert a GDScript string to the bytes of a C string (CP437 for the accented
# letters of the Latin-1 range).
const _CP437 := {"Ç": 128, "ü": 129, "é": 130, "â": 131, "ä": 132, "à": 133, "å": 134, "ç": 135,
	"ê": 136, "ë": 137, "è": 138, "ï": 139, "î": 140, "ì": 141, "Ä": 142, "Å": 143, "É": 144,
	"æ": 145, "Æ": 146, "ô": 147, "ö": 148, "ò": 149, "û": 150, "ù": 151, "ÿ": 152, "Ö": 153,
	"Ü": 154, "á": 160, "í": 161, "ó": 162, "ú": 163, "ñ": 164, "Ñ": 165, "ß": 225}
static func _b(s) -> PackedByteArray:
	if s is PackedByteArray:
		return s
	var t: String = str(s)
	var b := PackedByteArray()
	for ch in t:
		var u: int = ch.unicode_at(0)
		if u < 128:
			b.append(u)
		else:
			b.append(int(_CP437.get(ch, 63)))
	return b

static func _cat(a, b) -> PackedByteArray:
	var r: PackedByteArray = _b(a).duplicate()
	r.append_array(_b(b))
	return r

#******************************************************************************
# Goals table (front end: goal_table goals[]; RESULTS / 3DENG.C GOAL_SCORED)
#******************************************************************************

class goal_info:
	var used: int = 0		# char
	var scorer: int = 0		# int
	var time: int = 0		# int

static var goals: Array = _mk_goals()
static func _mk_goals() -> Array:
	var a: Array = []
	for i in range(MAX_GOALS + 1 + 4):		# (+ slack: the score breakdown reads one past the last used slot)
		a.append(goal_info.new())
	return a

static func clear_goals() -> void:
	for g in goals:
		g.used = 0
		g.scorer = 0
		g.time = 0

# void GOAL_SCORED( int team, int scorer, int time )
static func GOAL_SCORED(team: int, scorer: int, time: int) -> void:
	var goal_slot: int = -1
	var goal_count: int = 0

	# FIND AN EMPTY GOAL SLOT WITHIN GOAL DATA...

	while goal_slot == -1:
		if goals[goal_count].used == 0:
			goal_slot = goal_count
			goals[goal_slot].used = ACTIVE
		else:
			goal_count += 1

			if goal_count > 90:
				goals[0].used = 0
				goal_count = 0

	goals[goal_slot].time = time + 1

	# CALCULATE NORMAL GOAL....

	if (time & O_G) == 0:
		if scorer < 11:
			goals[goal_slot].scorer = _gd(0).players[scorer].squad_number	# was scorer-1
			goals[goal_slot].used = u8(goals[goal_slot].used | CREDIT_TEAMa)
			EUROmatch_info.Team_A_goals += 1
		else:
			goals[goal_slot].scorer = _gd(1).players[scorer - 11].squad_number	# was scorer-12
			goals[goal_slot].used = u8(goals[goal_slot].used | CREDIT_TEAMb)
			EUROmatch_info.Team_B_goals += 1

	# CALCULATE OWN GOAL....

	if (time & O_G) != 0:
		goals[goal_slot].used = u8(O_G >> 8)

		if scorer < 11:
			goals[goal_slot].scorer = _gd(0).players[scorer].squad_number	# was scorer-1
			goals[goal_slot].used = u8(goals[goal_slot].used | CREDIT_TEAMb)
			EUROmatch_info.Team_B_goals += 1
		else:
			goals[goal_slot].scorer = _gd(1).players[scorer - 11].squad_number	# was scorer-12
			goals[goal_slot].used = u8(goals[goal_slot].used | CREDIT_TEAMa)
			EUROmatch_info.Team_A_goals += 1

#******************************************************************************
# Screen setup (init3d buffer part, setscreen, switchmode)
#******************************************************************************

# init3d(): "Set screen mode and set buffer info"
static func init3d_buffers() -> void:
	var i: int
	var j: int
	for i2 in range(SCRSIZES):
		i = i2
		MCGA_buff[i].buff_start = 320 + ((320 - MCGA_buff[i].clip_wid) >> 1) + ((200 - MCGA_buff[i].clip_hgt) >> 1) * 320
		for j2 in range(VESAMODES):
			j = j2
			var v: buff_info = VESA_buff[j][i]
			v.buff_start = 640 + ((v.buff_wid - v.clip_wid) >> 1) + ((v.buff_hgt - v.clip_hgt) >> 1) * v.buff_wid
	for i3 in range(NO_MENUS):
		var l: buff_info = menu_buff_l[i3]
		var h: buff_info = menu_buff_h[i3]
		l.scale_x = (MCGA_buff[0].clip_wid - l.clip_wid) >> 1
		l.scale_y = MCGA_buff[0].clip_hgt - l.buff_hgt
		l.buff_start = MCGA_buff[0].buff_start + int(l.scale_y) * MCGA_buff[0].buff_wid + int(l.scale_x)
		h.scale_x = (VESA_buff[0][0].clip_wid - h.clip_wid) >> 1
		h.scale_y = VESA_buff[0][0].clip_hgt - h.buff_hgt
		h.buff_start = VESA_buff[0][0].buff_start + int(h.scale_y) * VESA_buff[0][0].buff_wid + int(h.scale_x)
	_buffers_ready = true

# int VESAmode(int *modelist)  (VESA.OBJ: first mode of the list the card supports)
static func VESAmode(ml: Array) -> int:
	var i: int = 0
	while ml[i] != -1:
		if vesa_supported.has(ml[i]):
			return ml[i]
		i += 1
	return -1

# The screen geometry the rest of the port reads (3D_UPD2 main_buff.clip_wid/hgt).
static func _main_buff_changed() -> void:
	Upd3D.clip_wid = main_buff.clip_wid
	Upd3D.clip_hgt = main_buff.clip_hgt

# setscreen()
static func setscreen() -> void:
	if not _buffers_ready:
		init3d_buffers()
	# (match start: the front end cleared its results tables for the new match)
	clear_goals()
	menu = 0
	slide = 0
	mcount = 0
	slco = 0
	sub_pending = 0
	modal = 0
	mstate = ST_NONE
	if start_res_choice >= 0:
		setup.start_res = start_res_choice
	# if ((scrmode3DB=Init3DB(modelist3DB))<0)   (no 3D Blaster)
	scrmode3DB = -1
	# remapgfx(1);  (map pages are decoded by the Godot renderer)
	if setup.start_res == 0:
		scrmode = 0x13
		# VGAmode(scrmode);
		main_buff.copy_from(MCGA_buff[setup.screen_size])
	else:
		# testVESA=0;
		scrmode = VESAmode(modelist)
		match scrmode:
			0x100:
				main_buff.copy_from(VESA_buff[0][setup.screen_size])
			0x101:
				main_buff.copy_from(VESA_buff[1][setup.screen_size])
			_:
				# VGAmode(0x13);
				main_buff.copy_from(MCGA_buff[setup.screen_size])
				scrmode = 0x13

	setup.start_res = (0 if scrmode == 0x13 else 1)
	_main_buff_changed()
	# Set palette: setpal();  Clear screen: vclear/mcgacpy  (HUD device)

# void switchmode()
# Switch screen mode through VESAmode list & MCGA (0x13)
static func switchmode() -> void:
	var i: int
	if scrmode3DB < 0:
		if scrmode == 0x13:
			# testVESA=0;
			i = 0
			scrmode = VESAmode(modelist)
			while scrmode != modelist[i]:
				i += 1
				if i == VESAMODES:
					break
			if i != VESAMODES:
				main_buff.copy_from(VESA_buff[i][setup.screen_size])
			else:
				scrmode = 0x13
		else:
			# VGAmode(0x13);
			main_buff.copy_from(MCGA_buff[setup.screen_size])
			scrmode = 0x13
		# setpal();
	_main_buff_changed()

static func end3d() -> void:
	pass

#******************************************************************************
# draw_sprite & co.  (software path; the pixel copy is done by the device)
#******************************************************************************

const SPR_N := 0		# draw_sprite
const SPR_S := 1		# draw_sprite_s
const SPR_VF := 2		# draw_sprite_vf
const SPR_HF := 3		# draw_sprite_hf
const SPR_VHF := 4	# draw_sprite_vhf
const SPR_D := 5		# draw_sprite_d

# Screen line width of scrb in the current mode (all buffers share it).
static func scr_wid() -> int:
	return 320 if scrmode == 0x13 else 640

static func _blit(mode: int, sprite_no: int, buff: buff_info, x: int, y: int, w: int, h: int, col: int) -> void:
	if dev == null:
		return
	var s: Array = spr_data[sprite_no]
	# BYTE *spt=buff->buff_start+y*buff->buff_wid+x;
	var spt: int = buff.buff_start + y * buff.buff_wid + x
	var sw: int = scr_wid()
	var sx: int = posmod(spt, sw)
	var sy: int = (spt - sx) / sw
	# BYTE *spd=maps[X_BM+spr_data[sprite_no].page]+spr_data[sprite_no].y*256+spr_data[sprite_no].x;
	dev.spr(mode, s[1], s[0] * 256 + s[2], s[3], s[4], w, h, sx, sy, col)

# draw_sprite(buff_info *buff,int sprite_no,int x,int y,BYTE col)
static func draw_sprite(buff: buff_info, sprite_no: int, x: int, y: int, col: int) -> void:
	var w: int = mini(spr_data[sprite_no][3], buff.clip_wid - x)
	var h: int = mini(spr_data[sprite_no][4], buff.clip_hgt - y)
	if w < 0 or h < 0:
		return
	_blit(SPR_N, sprite_no, buff, x, y, w, h, col)

# draw_sprite_d(buff_info *buff,int sprite_no,int x,int y,BYTE col)  (double size)
static func draw_sprite_d(buff: buff_info, sprite_no: int, x: int, y: int, col: int) -> void:
	var w: int = mini(spr_data[sprite_no][3], buff.clip_wid - x)
	var h: int = mini(spr_data[sprite_no][4], buff.clip_hgt - y)
	if w < 0 or h < 0:
		return
	_blit(SPR_D, sprite_no, buff, x, y, w, h, col)

# draw_sprite_s(buff_info *buff,int sprite_no,int x,int y,BYTE col)  (solid: 1 transparent)
static func draw_sprite_s(buff: buff_info, sprite_no: int, x: int, y: int, col: int) -> void:
	var w: int = mini(spr_data[sprite_no][3], buff.clip_wid - x)
	var h: int = mini(spr_data[sprite_no][4], buff.clip_hgt - y)
	if w < 0 or h < 0:
		return
	_blit(SPR_S, sprite_no, buff, x, y, w, h, col)

# draw_sprite_vf(buff_info *buff,int sprite_no,int x,int y,BYTE col)  (vertical flip)
static func draw_sprite_vf(buff: buff_info, sprite_no: int, x: int, y: int, col: int) -> void:
	var w: int = mini(spr_data[sprite_no][3], buff.clip_wid - x)
	var h: int = mini(spr_data[sprite_no][4], buff.clip_hgt - y)
	if w <= 0 or h <= 0:
		return		# (no explicit test in the C: the copy loops do nothing)
	_blit(SPR_VF, sprite_no, buff, x, y, w, h, col)

# draw_sprite_r(): rotated copy, not used by the match.

# draw_sprite_hf(buff_info *buff,int sprite_no,int x,int y,BYTE col)  (horizontal flip)
static func draw_sprite_hf(buff: buff_info, sprite_no: int, x: int, y: int, col: int) -> void:
	var w: int = mini(spr_data[sprite_no][3], buff.clip_wid - x)
	var h: int = mini(spr_data[sprite_no][4], buff.clip_hgt - y)
	if w <= 0 or h <= 0:
		return
	_blit(SPR_HF, sprite_no, buff, x, y, w, h, col)

# draw_sprite_vhf(buff_info *buff,int sprite_no,int x,int y,BYTE col)
static func draw_sprite_vhf(buff: buff_info, sprite_no: int, x: int, y: int, col: int) -> void:
	var w: int = mini(spr_data[sprite_no][3], buff.clip_wid - x)
	var h: int = mini(spr_data[sprite_no][4], buff.clip_hgt - y)
	if w <= 0 or h <= 0:
		return
	_blit(SPR_VHF, sprite_no, buff, x, y, w, h, col)

# Apply filters[0] (shadow) to a w x h block at buffer address sc (row stride sw).
static func _shadow_at(sc: int, w: int, h: int) -> void:
	if dev == null or w <= 0 or h <= 0:
		return
	var sw: int = scr_wid()
	var sx: int = posmod(sc, sw)
	dev.shadow(sx, (sc - sx) / sw, w, h)

# Map a character like string_len()/draw_string() do (c is a BYTE)
static func _font_char(c: int) -> int:
	if c == 32:			# ' '
		c = 59			# ';'
	if c == 46:			# '.'
		c = 64			# '@'
	if c == 44:			# ','
		c = 63			# '?'
	if c == 62:			# '>'
		c = 65			# 'A'
	if c >= 97 and c <= 122:	# 'a'..'z'
		c -= 32
	if c == 79:			# 'O'
		c = 48			# '0'
	if c == 38:			# '&'
		c = 79			# 'O'
	return (c - 48) & 255

# int string_len(int font_no,char *string)
static func string_len(font_no: int, string) -> int:
	var s: PackedByteArray = _b(string)
	var len: int = 0
	for c0 in s:
		if c0 == 0:
			break
		var c: int = _font_char(c0)
		len += _prp(font_no, c) + 1
	return len

# int draw_string(buff_info *buff,int font_no,int x,int y,char *string,BYTE col,short just)
static func draw_string(buff: buff_info, font_no: int, x: int, y: int, string, col: int, just: int) -> int:
	var s: PackedByteArray = _b(string)
	var c: int
	var ec: int
	var len: int
	var f: Array = font_data[font_no]
	len = string_len(font_no, s)
	match just:
		1:
			x -= len
		2:
			x -= len >> 1
	for c0 in s:
		c = c0
		if c == 0:
			break
		if c == 32:
			c = 59
		if c == 46:
			c = 64
		if c == 44:
			c = 63
		if c == 62:		# '>'
			c = (c - 48) & 255
			ec = (c + f[4]) & 255
			spr_data[0][0] = f[0]
			spr_data[0][1] = f[1] + f[5] * (ec % f[3])
			spr_data[0][2] = f[2] + f[6] * (ec / f[3])
			spr_data[0][3] = _prp(font_no, c)
			spr_data[0][4] = f[6]
			draw_sprite(buff, 0, x, y - f[6], col)
			c = 65		# 'A'
		if c >= 97 and c <= 122:
			c -= 32
		if c == 79:
			c = 48
		if c == 38:
			c = 79
		c = (c - 48) & 255
		ec = (c + f[4]) & 255
		spr_data[0][0] = f[0]
		spr_data[0][1] = f[1] + f[5] * (ec % f[3])
		spr_data[0][2] = f[2] + f[6] * (ec / f[3])
		spr_data[0][3] = _prp(font_no, c)
		spr_data[0][4] = f[6]
		draw_sprite(buff, 0, x, y, col)
		x += _prp(font_no, c) + 1
	return len

# rectshadow3DB(): 3D Blaster only.

# draw_menu_box(buff_info *buff)
static func draw_menu_box(buff: buff_info) -> void:
	var f: int
	var wd: int
	var hd: int
	if scrmode != 0x13:
		hd = mini(buff.buff_hgt - (19 + 32) * 2, buff.clip_hgt - 19 - 32)
		if hd > 0:
			# if (scrmode3DB<0)
			wd = buff.clip_wid - 20 * 2
			_shadow_at(buff.buff_start + (19 + 32) * buff.buff_wid + 20, wd, hd)
		draw_sprite(buff, 21, 11, 10 + 32, 0)
		draw_sprite_hf(buff, 21, buff.clip_wid - 32, 10 + 32, 0)
		draw_sprite_vhf(buff, 21, buff.clip_wid - 32, buff.buff_hgt - 32 - 32, 0)
		draw_sprite_vf(buff, 21, 11, buff.buff_hgt - 32 - 32, 0)
		f = 32
		while f < buff.clip_wid - 32:
			draw_sprite(buff, 22, f, 10 + 32, 0)
			draw_sprite(buff, 22, f, buff.buff_hgt - 19 - 32, 0)
			f += 32
		f = 32 + 32
		while f < buff.buff_hgt - 32 - 32:
			draw_sprite(buff, 23, 11, f, 0)
			draw_sprite(buff, 23, buff.clip_wid - 20, f, 0)
			f += 32
	else:
		hd = mini(buff.buff_hgt - (10 + 16) * 2, buff.clip_hgt - 10 - 16)
		if hd > 0:
			wd = buff.clip_wid - 10 * 2
			_shadow_at(buff.buff_start + (10 + 16) * buff.buff_wid + 10, wd, hd)
		draw_sprite(buff, 32, 5, 5 + 16, 0)
		draw_sprite_hf(buff, 32, buff.clip_wid - 16, 5 + 16, 0)
		draw_sprite_vhf(buff, 32, buff.clip_wid - 16, buff.buff_hgt - 16 - 16, 0)
		draw_sprite_vf(buff, 32, 5, buff.buff_hgt - 16 - 16, 0)
		f = 16
		while f < buff.clip_wid - 16:
			draw_sprite(buff, 33, f, 5 + 16, 0)
			draw_sprite(buff, 33, f, buff.buff_hgt - 10 - 16, 0)
			f += 32
		f = 16 + 16
		while f < buff.buff_hgt - 32 - 16:
			draw_sprite(buff, 34, 5, f, 0)
			draw_sprite(buff, 34, buff.clip_wid - 10, f, 0)
			f += 32
		if f < buff.buff_hgt - 16 - 16:
			draw_sprite(buff, 83, 5, f, 0)
			draw_sprite(buff, 83, buff.clip_wid - 10, f, 0)

#******************************************************************************
# Menus
#******************************************************************************

# shirt=ppt[player+((match_half&1)?11:0)].number-1;   (ppt = plyrtb of render3d = pos[])
static func _shirt(team: int, player: int) -> int:
	var i: int
	if not team:
		i = player + (11 if match_half & 1 else 0)
	else:
		i = player + (0 if match_half & 1 else 11)
	if i < 0 or i >= pos.size():
		return 0
	return pos[i].number - 1

static func _pname(team: int, player: int) -> PackedByteArray:
	if not team:
		return GetPLAYERSname(_squad(EUROmatch_info.TeamAsquad, player), setup.team_a, INITIAL_SURNAME)
	return GetPLAYERSname(_squad(EUROmatch_info.TeamBsquad, player), setup.team_b, INITIAL_SURNAME)

static func _squad(a: Array, i: int) -> int:
	if i < 0 or i >= a.size():
		return i
	return a[i]

# Common part of goal_menu / booked_menu / off_menu / injured_menu / owngoal_menu
static func _player_menu(buff: buff_info, team: int, player: int, text: int, tcol: int, lo_spr: Array, hi_spr: Array) -> void:
	var shirt: int = _shirt(team, player)
	draw_menu_box(buff)
	if scrmode == 0x13:
		draw_sprite(buff, 30 + team, 10, 11, 0)
		draw_sprite(buff, 2 + shirt, 16, 21, 0)
		draw_string(buff, 0, 160, 30, GetTEXT(text), tcol, 1)
		draw_string(buff, 0, 160, 30, _pname(team, player), 31, 0)
		for s in lo_spr:
			draw_sprite(buff, s[0], s[1], s[2], 0)
	else:
		draw_sprite(buff, 19 + team, 20, 24, 0)
		draw_string(buff, 2, 320, 56, GetTEXT(text), tcol, 1)
		if not team:
			draw_sprite_s(buff, 53 + shirt, 42, 51, 0)
		else:
			draw_sprite_s(buff, 68 + shirt, 42, 51, 0)
		draw_string(buff, 2, 320, 56, _pname(team, player), 31, 0)
		for s in hi_spr:
			draw_sprite(buff, s[0], s[1], s[2], 0)

# goal_menu(buff_info *buff, int team, int player, int time)
static func goal_menu(buff: buff_info, team: int, player: int, time: int) -> void:
	_player_menu(buff, team, player, GLSC_TEXT, 207, [[40, 278, 18]], [[29, 556, 38]])

# booked_menu(buff_info *buff, int team, int player)
static func booked_menu(buff: buff_info, team: int, player: int) -> void:
	_player_menu(buff, team, player, YLCD_TEXT, 157, [[51, 276, 9], [52, 276, 11]], [[45, 552, 18], [46, 552, 24]])

# off_menu(buff_info *buff, int team, int player)
static func off_menu(buff: buff_info, team: int, player: int) -> void:
	_player_menu(buff, team, player, RDCD_TEXT, 127, [[50, 276, 9], [52, 276, 11]], [[44, 552, 18], [46, 552, 24]])

# direct_menu / indirect_menu / ... / offside_menu: a team kit, a text and an icon
static func _team_text_menu(buff: buff_info, team: int, text: int, lo: Array, hi: Array) -> void:
	draw_menu_box(buff)
	if scrmode == 0x13:
		draw_sprite(buff, 30 + team, 10, 11, 0)
		draw_string(buff, 0, lo[0], 30, GetTEXT(text), 31, 2)
		draw_sprite(buff, lo[1], lo[2], lo[3], 0)
	else:
		draw_sprite(buff, 19 + team, 20, 24, 0)
		draw_string(buff, 2, hi[0], 56, GetTEXT(text), 31, 2)
		draw_sprite(buff, hi[1], hi[2], hi[3], 0)

static func direct_menu(buff: buff_info, team: int) -> void:
	_team_text_menu(buff, team, DRKC_TEXT, [112, 52, 188, 11], [224, 46, 376, 24])

static func indirect_menu(buff: buff_info, team: int) -> void:
	_team_text_menu(buff, team, IDKC_TEXT, [112, 52, 188, 11], [224, 46, 376, 24])

static func penalty_menu(buff: buff_info, team: int) -> void:
	_team_text_menu(buff, team, PENK_TEXT, [96, 52, 151, 11], [192, 46, 302, 24])

static func corner_menu(buff: buff_info, team: int) -> void:
	_team_text_menu(buff, team, CORK_TEXT, [96, 40, 151, 18], [192, 29, 302, 38])

static func throw_menu(buff: buff_info, team: int) -> void:
	_team_text_menu(buff, team, THIN_TEXT, [96, 40, 151, 18], [192, 29, 302, 38])

static func goalkick_menu(buff: buff_info, team: int) -> void:
	_team_text_menu(buff, team, GKIK_TEXT, [96, 40, 151, 18], [192, 29, 302, 38])

static func kickoff_menu(buff: buff_info, team: int) -> void:
	_team_text_menu(buff, team, KIOF_TEXT, [96, 40, 151, 18], [192, 29, 302, 38])

static func offside_menu(buff: buff_info, team: int) -> void:
	_team_text_menu(buff, team, OFFS_TEXT, [112, 52, 188, 11], [224, 46, 376, 24])

# injured_menu(buff_info *buff, int team, int player)
static func injured_menu(buff: buff_info, team: int, player: int) -> void:
	_player_menu(buff, team, player, PLIN_TEXT, 127, [[52, 280, 11]], [[46, 560, 24]])

# ref_menu(buff_info *buff)
static func ref_menu(buff: buff_info) -> void:
	var tlstr: PackedByteArray
	draw_menu_box(buff)
	if scrmode == 0x13:
		draw_sprite(buff, 52, 13, 11, 0)
		draw_string(buff, 0, 160, 30, GetTEXT(RFRE_TEXT), 207, 1)
		tlstr = _b(cstr(EUROmatch_info.RefsName))
#		strcat(tlstr," = ");
#		strcat(tlstr,game_data[ referee_data[match_info.match_referee].country ].Nickname);
		draw_string(buff, 0, 160, 30, tlstr, 31, 0)
		draw_sprite(buff, 52, 284, 11, 0)
	else:
		draw_sprite(buff, 46, 26, 24, 0)
		draw_string(buff, 2, 320, 56, GetTEXT(RFRE_TEXT), 207, 1)
		tlstr = _b(cstr(EUROmatch_info.RefsName))
		draw_string(buff, 2, 320, 56, tlstr, 31, 0)
		draw_sprite(buff, 46, 578, 24, 0)

# for (int sf=0;sf<22;sf++) if (game_data[TEMPx].players[sf].squad_number==scorer) break;
static func _scorer_index(t: int, scorer: int) -> int:
	var sf: int = 0
	while sf < 22:
		if _gd(t).players[sf].squad_number == scorer:
			break
		sf += 1
	return sf

# sprintf(tstr,"%s ",&GetPLAYERSname( EUROmatch_info.TeamXsquad[sf], setup.team_x, INITIAL_SURNAME )[0]);
static func _scorer_str(t: int, scorer: int) -> PackedByteArray:
	var sf: int = _scorer_index(t, scorer)
	if t == 0:
		return _cat(GetPLAYERSname(_squad(EUROmatch_info.TeamAsquad, sf), setup.team_a, INITIAL_SURNAME), " ")
	return _cat(GetPLAYERSname(_squad(EUROmatch_info.TeamBsquad, sf), setup.team_b, INITIAL_SURNAME), " ")

static func _goal_time_str(gt: int) -> PackedByteArray:
	if gt & 256:
		return _cat("%d " % (gt & 255), GetTEXT(PENS_TEXT))
	return _cat("%d " % (gt & 255), GetTEXT(OWNG_TEXT))

# One column of score_breakdown_l/_h: cr = credit bit (4 team A, 8 team B),
# xo = column x, font, line height, (l limits), m start, limit.
# Returns the final m (or -1 - m when the "goto mendN" exit was taken).
static func _breakdown_col(buff: buff_info, cr: int, xo: int, font: int, dm: int, l1: int, l2: int, m0: int, mlim: int) -> int:
	var g: int = 0
	var gc: int
	var l: int
	var m: int = m0
	var tstr: PackedByteArray
	while goals[g].used:
		if (goals[g].used & (cr | 1)) == cr:
			l = 0
			# (team of the scorer: own goals are listed under the team credited)
			var own: int = 1 if (cr == 4) else 0
			if not (goals[g].time & 512):
				tstr = _scorer_str(0 if cr == 4 else 1, goals[g].scorer)
			else:
				tstr = _scorer_str(own, goals[g].scorer)
			l += draw_string(buff, font, l + xo, m, tstr, 157, 0)
			gc = g
			while true:		# do {
				if goals[gc].time & 768:
					if l >= l1:
						# if ((m+=d,l=0)>52+n*d) goto mend;  (comma expression: tests l=0)
						m += dm
						l = 0
					tstr = _goal_time_str(goals[gc].time)
				else:
					if l >= l2:
						m += dm
						l = 0
					tstr = _b("%d" % goals[gc].time)
				l += draw_string(buff, font, l + xo, m, tstr, 157, 0)
				goals[gc].used = u8(goals[gc].used | 1)
				while true:		# do {
					gc += 1
					if (goals[gc].used & (cr | 1)) == cr and goals[gc].scorer == goals[g].scorer and (goals[gc].time & 512) == (goals[g].time & 512):
						l += draw_string(buff, font, l + xo, m, ",", 157, 0)
						break
					if not goals[gc].used:
						break		# } while (goals[gc].goal_data.used);
				if not goals[gc].used:
					break		# } while (goals[gc].goal_data.used);
			m += dm
			if m > mlim:
				return -1 - m		# goto mend
		g += 1
	return m

# score_breakdown_l(buff_info *buff)
static func score_breakdown_l(buff: buff_info) -> void:
	var m: int = _breakdown_col(buff, 4, 40, 0, 8, 50, 78, 52, 52 + 5 * 8)
	if m < 0:
		m = -1 - m
	# mend1:;
	mhgt = ((m + 40) >> 4) << 4

	m = _breakdown_col(buff, 8, 178, 0, 8, 50, 78, 52, 52 + 5 * 8)
	if m < 0:
		m = -1 - m
	# mend2:;
	if mhgt < ((m + 40) >> 4) << 4:
		mhgt = ((m + 40) >> 4) << 4

	var gc: int = 0
	while goals[gc].used:
		goals[gc].used = goals[gc].used & 0xfe
		gc += 1

# score_breakdown_h(buff_info *buff)
static func score_breakdown_h(buff: buff_info) -> void:
	var m: int = _breakdown_col(buff, 4, 80, 2, 13, 120, 176, 104, 104 + 6 * 13)
	if m < 0:
		m = -1 - m
	# mend3:;
	mhgt = ((m + 84) >> 5) << 4

	m = _breakdown_col(buff, 8, 356, 2, 13, 120, 176, 104, 104 + 6 * 13)
	if m < 0:
		m = -1 - m
	# mend4:;
	if mhgt < ((m + 84) >> 5) << 4:
		mhgt = ((m + 84) >> 5) << 4

	var gc: int = 0
	while goals[gc].used:
		goals[gc].used = goals[gc].used & 0xfe
		gc += 1

# fulltime_menu / extratime_menu / halftime_menu / penalty_shootout_menu / final_score_menu
static func _score_menu(buff: buff_info, text: int) -> void:
	var tstr: String
	draw_menu_box(buff)
	if scrmode == 0x13:
		draw_sprite(buff, 30, 10, 11, 0)
		draw_sprite(buff, 31, 243, 11, 0)
		draw_string(buff, 1, 144, 30, GetTEXT(text), 207, 2)
		draw_string(buff, 0, 110, 42, _b(cstr(EUROmatch_info.TeamAname)), 31, 1)
		tstr = "%d" % team_a_goals
		draw_string(buff, 0, 131, 42, tstr, 31, 1)
		tstr = "%d" % team_b_goals
		draw_string(buff, 0, 157, 42, tstr, 31, 0)
		draw_string(buff, 0, 178, 42, _b(cstr(EUROmatch_info.TeamBname)), 31, 0)
#		draw_sprite(buff,49,134,38,0);
		score_breakdown_l(buff)
	else:
		draw_sprite(buff, 19, 20, 24, 0)
		draw_sprite(buff, 20, 486, 24, 0)
		draw_string(buff, 2, 288, 56, GetTEXT(text), 207, 2)
		draw_string(buff, 2, 220, 80, _b(cstr(EUROmatch_info.TeamAname)), 31, 1)
		tstr = "%d" % team_a_goals
		draw_string(buff, 2, 262, 80, tstr, 31, 1)
		tstr = "%d" % team_b_goals
		draw_string(buff, 2, 314, 80, tstr, 31, 0)
		draw_string(buff, 2, 356, 80, _b(cstr(EUROmatch_info.TeamBname)), 31, 0)
#		draw_sprite(buff,43,268,72,0);
		score_breakdown_h(buff)

static func fulltime_menu(buff: buff_info) -> void:
	_score_menu(buff, FLTM_TEXT)

static func extratime_menu(buff: buff_info) -> void:
	_score_menu(buff, EXTM_TEXT)

static func halftime_menu(buff: buff_info) -> void:
	_score_menu(buff, HFTM_TEXT)

static func penalty_shootout_menu(buff: buff_info) -> void:
	_score_menu(buff, PNST_TEXT)

static func final_score_menu(buff: buff_info) -> void:
	_score_menu(buff, FNSP_TEXT)

# owngoal_menu(buff_info *buff, int team, int player, int time)
static func owngoal_menu(buff: buff_info, team: int, player: int, time: int) -> void:
	_player_menu(buff, team, player, OWGL_TEXT, 207, [[40, 278, 18]], [[29, 556, 38]])

# stats_menu(buff_info *buff)
static func stats_menu(buff: buff_info) -> void:
	draw_menu_box(buff)
	if scrmode == 0x13:
		draw_sprite(buff, 30, 8, 8, 0)	# Kit
		draw_sprite(buff, 31, 256 - 48, 8, 0)	# Kit
		draw_string(buff, 0, M_WIDTH / 2, 32, "MATCH STATISTICS", 207, 2)
		draw_string(buff, 0, M_WIDTH / 2, 54, "Tackling", 31, 2)
		draw_string(buff, 0, M_WIDTH / 2, 61, "Passing", 31, 2)
		draw_string(buff, 0, M_WIDTH / 2, 68, "Shooting", 31, 2)
		draw_string(buff, 0, M_WIDTH / 2, 75, "Possession", 31, 2)
		draw_string(buff, 0, M_WIDTH / 2, 82, "Work", 31, 2)
		draw_string(buff, 0, M_WIDTH / 2, 89, "Corners", 31, 2)
		draw_string(buff, 0, M_WIDTH / 2, 96, "Direct Free-kicks", 31, 2)
		draw_string(buff, 0, M_WIDTH / 2, 103, "Penalties", 31, 2)
		draw_string(buff, 0, M_WIDTH / 2, 110, "Offsides committed", 31, 2)
		draw_string(buff, 0, M_WIDTH / 2, 117, "Yellow cards", 31, 2)
		draw_string(buff, 0, M_WIDTH / 2, 124, "Red cards", 31, 2)

		var str1: String
		var str2: String
		for i in range(11):
			if i < 4:
				str1 = "%d%%" % stat_sheet[i][0]
				str2 = "%d%%" % stat_sheet[i][1]
			else:
				str1 = "%d" % stat_sheet[i][0]
				str2 = "%d" % stat_sheet[i][1]

			draw_string(buff, 0, 16, 54 + (i * 7), str1, 31, 0)
			draw_string(buff, 0, 256 - 32, 54 + (i * 7), str2, 31, 1)
	else:
		draw_string(buff, 2, 192, 56, GetTEXT(KIOF_TEXT), 31, 2)

# void draw_m_butt(buff_info *buff,int x,int y,char *string,BYTE col,char *legend)
static func draw_m_butt(buff: buff_info, x: int, y: int, string, col: int, legend) -> void:
	if scrmode == 0x13:
		draw_sprite(buff, 36, x, y, 0)
		draw_string(buff, 0, x + 23, y + 5, string, col, 2)
		if legend != null:
			draw_string(buff, 0, x + 2, y - 1, legend, 157, 2)
	else:
		draw_sprite(buff, 25, x, y, 0)
		draw_string(buff, 2, x + 45, y + 8, string, col, 2)
		if legend != null:
			draw_string(buff, 2, x + 4, y - 2, legend, 157, 2)

# void draw_l_butt(buff_info *buff,int x,int y,char *string,BYTE col,char *legend)
static func draw_l_butt(buff: buff_info, x: int, y: int, string, col: int, legend) -> void:
	if scrmode == 0x13:
		draw_sprite(buff, 35, x, y, 0)
		draw_string(buff, 0, x + 41, y + 5, string, col, 2)
		if legend != null:
			draw_string(buff, 0, x + 2, y - 1, legend, 157, 2)
	else:
		draw_sprite(buff, 24, x, y, 0)
		draw_string(buff, 2, x + 82, y + 8, string, col, 2)
		if legend != null:
			draw_string(buff, 2, x + 4, y - 2, legend, 157, 2)

# void draw_s_butt(buff_info *buff,int x,int y,char *string,BYTE col,char *legend)
static func draw_s_butt(buff: buff_info, x: int, y: int, string, col: int, legend) -> void:
	if scrmode == 0x13:
		draw_sprite(buff, 37, x, y, 0)
		draw_string(buff, 0, x + 15, y + 5, string, col, 2)
		if legend != null:
			draw_string(buff, 0, x, y - 1, legend, 157, 2)
	else:
		draw_sprite(buff, 26, x, y, 0)
		draw_string(buff, 2, x + 29, y + 8, string, col, 2)
		if legend != null:
			draw_string(buff, 2, x, y - 2, legend, 157, 2)

static func _no_replay() -> bool:
	return replay_seconds == 0 or not allow_replay

static func _no_subs() -> bool:
	return bool(match_mode) or not EUROmatch_info.substitutes or sub_c < 2

# options_menu(buff_info *buff, int team, int user_no)
static func options_menu(buff: buff_info, team: int, user_no: int) -> void:
	var tstr: String
	if scrmode == 0x13:
		if opt_b != 0:
			draw_l_butt(buff, 62, 32, GetTEXT(RPLY_TEXT), 2 if _no_replay() else 31, "F1")
		if opt_b != 1:
			draw_l_butt(buff, 62, 48, GetTEXT(SBTN_TEXT), 2 if (_no_subs() or user_no <= 0) else 31, "F2")
		if opt_b != 2:
			draw_l_butt(buff, 62, 64, GetTEXT(FRMN_TEXT), 2 if user_no <= 0 else 31, "F3")
		if opt_b != 3:
			draw_l_butt(buff, 62, 80, GetTEXT(CANL_TEXT), 31, "F4")
		draw_menu_box(buff)
		if opt_b == 0:
			draw_l_butt(buff, 62, 32, GetTEXT(RPLY_TEXT), 31, "F1")
		if opt_b == 1:
			draw_l_butt(buff, 62, 48, GetTEXT(SBTN_TEXT), 31, "F2")
		if opt_b == 2:
			draw_l_butt(buff, 62, 64, GetTEXT(FRMN_TEXT), 31, "F3")
		if opt_b == 3:
			draw_l_butt(buff, 62, 80, GetTEXT(CANL_TEXT), 31, "F4")
		if user_no > 0:
			draw_sprite(buff, 30 + team, 18, 38, 0)
			tstr = "PLAYER %d" % user_no
			draw_string(buff, 0, 36, 87, tstr, 157, 2)
		else:
			draw_sprite(buff, 52, 22, 45, 0)
	else:
		if opt_b != 0:
			draw_l_butt(buff, 124, 64, GetTEXT(RPLY_TEXT), 2 if _no_replay() else 31, "F1")
		if opt_b != 1:
			draw_l_butt(buff, 124, 96, GetTEXT(SBTN_TEXT), 2 if (_no_subs() or user_no <= 0) else 31, "F2")
		if opt_b != 2:
			draw_l_butt(buff, 124, 128, GetTEXT(FRMN_TEXT), 2 if user_no <= 0 else 31, "F3")
		if opt_b != 3:
			draw_l_butt(buff, 124, 160, GetTEXT(CANL_TEXT), 31, "F4")
		draw_menu_box(buff)
		if opt_b == 0:
			draw_l_butt(buff, 124, 64, GetTEXT(RPLY_TEXT), 31, "F1")
		if opt_b == 1:
			draw_l_butt(buff, 124, 96, GetTEXT(SBTN_TEXT), 31, "F2")
		if opt_b == 2:
			draw_l_butt(buff, 124, 128, GetTEXT(FRMN_TEXT), 31, "F3")
		if opt_b == 3:
			draw_l_butt(buff, 124, 160, GetTEXT(CANL_TEXT), 31, "F4")
		if user_no > 0:
			draw_sprite(buff, 19 + team, 36, 76, 0)
			tstr = "PLAYER %d" % user_no
			draw_string(buff, 2, 72, 174, tstr, 157, 2)
		else:
			draw_sprite(buff, 46, 45, 90, 0)

# formation_menu(buff_info *buff, int team, int user_no)
static func formation_menu(buff: buff_info, team: int, user_no: int) -> void:
	if scrmode == 0x13:
		if for_b != 0:
			draw_l_butt(buff, 62, 32, forms[option_info_formation], 31, "F1")
		if for_b != 1:
			draw_l_butt(buff, 62, 48, GetTEXT(SLCT_TEXT), 31, "F2")
		if for_b != 2:
			draw_l_butt(buff, 62, 64, GetTEXT(CANL_TEXT), 31, "F3")
		draw_menu_box(buff)
		if for_b == 0:
			draw_l_butt(buff, 62, 32, forms[option_info_formation], 31, "F1")
		if for_b == 1:
			draw_l_butt(buff, 62, 48, GetTEXT(SLCT_TEXT), 31, "F2")
		if for_b == 2:
			draw_l_butt(buff, 62, 64, GetTEXT(CANL_TEXT), 31, "F3")
		draw_sprite(buff, 30 + team, 18, 34, 0)
	else:
		if for_b != 0:
			draw_l_butt(buff, 124, 64, forms[option_info_formation], 31, "F1")
		if for_b != 1:
			draw_l_butt(buff, 124, 96, GetTEXT(SLCT_TEXT), 31, "F2")
		if for_b != 2:
			draw_l_butt(buff, 124, 128, GetTEXT(CANL_TEXT), 31, "F3")
		draw_menu_box(buff)
		if for_b == 0:
			draw_l_butt(buff, 124, 64, forms[option_info_formation], 31, "F1")
		if for_b == 1:
			draw_l_butt(buff, 124, 96, GetTEXT(SLCT_TEXT), 31, "F2")
		if for_b == 2:
			draw_l_butt(buff, 124, 128, GetTEXT(CANL_TEXT), 31, "F3")
		draw_sprite(buff, 19 + team, 36, 68, 0)

# substitution_menu(buff_info *buff, int team, int user_no)
static func substitution_menu(buff: buff_info, team: int, user_no: int) -> void:
	var off_i: int = option_info_sub_off + ((11 if match_half & 1 else 0) if not team else (0 if match_half & 1 else 11))
	var off_shirt: int = teams[off_i].shirt
	var off_name: PackedByteArray
	var on_name: PackedByteArray
	if not team:
		off_name = GetPLAYERSname(_squad(EUROmatch_info.TeamAsquad, option_info_sub_off), setup.team_a, INITIAL_SURNAME)
		on_name = GetPLAYERSname(_squad(EUROmatch_info.TeamAsquad, option_info_sub_on), setup.team_a, INITIAL_SURNAME)
	else:
		off_name = GetPLAYERSname(_squad(EUROmatch_info.TeamBsquad, option_info_sub_off), setup.team_b, INITIAL_SURNAME)
		on_name = GetPLAYERSname(_squad(EUROmatch_info.TeamBsquad, option_info_sub_on), setup.team_b, INITIAL_SURNAME)
	if scrmode == 0x13:
		if sub_b != 0:
			draw_m_butt(buff, 88, 32, GetTEXT(SOFF_TEXT), 31, "F1")
		if sub_b != 1:
			draw_l_butt(buff, 70, 48, GetTEXT(SUBT_TEXT), 31, "F2")
		if sub_b != 2:
			draw_l_butt(buff, 70, 64, GetTEXT(CANL_TEXT), 31, "F3")
		if sub_b != 3:
			draw_m_butt(buff, 88, 80, GetTEXT(SBON_TEXT), 31, "F4")
		draw_menu_box(buff)
		if sub_b == 0:
			draw_m_butt(buff, 88, 32, GetTEXT(SOFF_TEXT), 31, "F1")
		if sub_b == 1:
			draw_l_butt(buff, 70, 48, GetTEXT(SUBT_TEXT), 31, "F2")
		if sub_b == 2:
			draw_l_butt(buff, 70, 64, GetTEXT(CANL_TEXT), 31, "F3")
		if sub_b == 3:
			draw_m_butt(buff, 88, 80, GetTEXT(SBON_TEXT), 31, "F4")
		draw_sprite(buff, 30 + team, 23, 48, 0)
		draw_sprite(buff, 30 + team, 166, 38, 0)
		draw_string(buff, 0, 41, 37, off_name, 157, 2)
		draw_sprite(buff, 2 + off_shirt - 1, 29, 58, 0)
		draw_string(buff, 0, 183, 85, on_name, 157, 2)
		draw_sprite(buff, 2 + option_info_sub_on, 172, 48, 0)
	else:
		if sub_b != 0:
			draw_m_butt(buff, 176, 64, GetTEXT(SOFF_TEXT), 31, "F1")
		if sub_b != 1:
			draw_l_butt(buff, 140, 96, GetTEXT(SUBT_TEXT), 31, "F2")
		if sub_b != 2:
			draw_l_butt(buff, 140, 128, GetTEXT(CANL_TEXT), 31, "F3")
		if sub_b != 3:
			draw_m_butt(buff, 176, 160, GetTEXT(SBON_TEXT), 31, "F4")
		draw_menu_box(buff)
		if sub_b == 0:
			draw_m_butt(buff, 176, 64, GetTEXT(SOFF_TEXT), 31, "F1")
		if sub_b == 1:
			draw_l_butt(buff, 140, 96, GetTEXT(SUBT_TEXT), 31, "F2")
		if sub_b == 2:
			draw_l_butt(buff, 140, 128, GetTEXT(CANL_TEXT), 31, "F3")
		if sub_b == 3:
			draw_m_butt(buff, 176, 160, GetTEXT(SBON_TEXT), 31, "F4")
		draw_sprite(buff, 19 + team, 46, 96, 0)
		draw_sprite(buff, 19 + team, 332, 76, 0)
		draw_string(buff, 2, 81, 72, off_name, 157, 2)
		if not team:
			draw_sprite_s(buff, 53 + off_shirt - 1, 68, 123, 0)
		else:
			draw_sprite_s(buff, 68 + off_shirt - 1, 68, 123, 0)
		draw_string(buff, 2, 366, 168, on_name, 157, 2)
		if not team:
			draw_sprite_s(buff, 53 + option_info_sub_on, 354, 103, 0)
		else:
			draw_sprite_s(buff, 68 + option_info_sub_on, 354, 103, 0)

# replay_menu(buff_info *buff, int user_no)
static func replay_menu(buff: buff_info, user_no: int) -> void:
	var tstr: String
	if scrmode == 0x13:
		if rep_b != 0:
			draw_s_butt(buff, 112, 32, "", 31, "F1")
			draw_sprite_hf(buff, 39, 121, 35, 0)
			draw_sprite_hf(buff, 39, 127, 35, 0)
		if rep_b != 1:
			draw_s_butt(buff, 146, 32, "", 31, "F2")
			draw_sprite(buff, 39, 155, 35, 0)
			draw_sprite(buff, 39, 161, 35, 0)
		if rep_b != 2:
			draw_s_butt(buff, 185, 32, "", 31, "F3")
		if not play:
			draw_sprite(buff, 39, 197, 35, 0)
		if rep_b != 3:
			draw_m_butt(buff, 225, 32, GetTEXT(DONE_TEXT), 31, "F4")
		draw_menu_box(buff)
		tstr = "%.2f" % reppos
		draw_m_butt(buff, 17, 32, tstr, 157, null)
		tstr = "%d" % speed
		draw_s_butt(buff, 69, 32, tstr, 31, null)
		if rep_b == 0:
			draw_s_butt(buff, 112, 32, "", 31, "F1")
			draw_sprite_hf(buff, 39, 121, 35, 0)
			draw_sprite_hf(buff, 39, 127, 35, 0)
		if rep_b == 1:
			draw_s_butt(buff, 146, 32, "", 31, "F2")
			draw_sprite(buff, 39, 155, 35, 0)
			draw_sprite(buff, 39, 161, 35, 0)
		if rep_b == 2:
			draw_s_butt(buff, 185, 32, "", 31, "F3")
		if play or rep_b == 2:
			draw_sprite(buff, 39, 197, 35, 0)
		if rep_b == 3:
			draw_m_butt(buff, 225, 32, GetTEXT(DONE_TEXT), 31, "F4")
	else:
		if rep_b != 0:
			draw_s_butt(buff, 224, 64, "", 31, "F1")
			draw_sprite_hf(buff, 28, 240, 70, 0)
			draw_sprite_hf(buff, 28, 252, 70, 0)
		if rep_b != 1:
			draw_s_butt(buff, 292, 64, "", 31, "F2")
			draw_sprite(buff, 28, 310, 70, 0)
			draw_sprite(buff, 28, 322, 70, 0)
		if rep_b != 2:
			draw_s_butt(buff, 370, 64, "", 31, "F3")
		if not play:
			draw_sprite(buff, 28, 394, 70, 0)
		if rep_b != 3:
			draw_m_butt(buff, 447, 64, GetTEXT(DONE_TEXT), 31, "F4")
		draw_menu_box(buff)
		tstr = "%.2f" % reppos
		draw_m_butt(buff, 34, 64, tstr, 157, null)
		tstr = "%d" % speed
		draw_s_butt(buff, 138, 64, tstr, 31, null)
		if rep_b == 0:
			draw_s_butt(buff, 224, 64, "", 31, "F1")
			draw_sprite_hf(buff, 28, 240, 70, 0)
			draw_sprite_hf(buff, 28, 252, 70, 0)
		if rep_b == 1:
			draw_s_butt(buff, 292, 64, "", 31, "F2")
			draw_sprite(buff, 28, 310, 70, 0)
			draw_sprite(buff, 28, 322, 70, 0)
		if rep_b == 2:
			draw_s_butt(buff, 370, 64, "", 31, "F3")
		if play or rep_b == 2:
			draw_sprite(buff, 28, 394, 70, 0)
		if rep_b == 3:
			draw_m_butt(buff, 447, 64, GetTEXT(DONE_TEXT), 31, "F4")

#******************************************************************************
# do_*_menu(): start an overlay menu
#******************************************************************************

# do_goal_menu(int team, int player, int time)
static func do_goal_menu(team: int, player: int, time: int) -> void:
	mdata1 = team
	mdata2 = player
	mdata3 = time
	slco = 0
	slide = 44
	oslide = 44
	mcount = 240
	if menu:
		rdmenu = 1
	menu = 1

static func do_booked_menu(team: int, player: int) -> void:
	mdata1 = team
	mdata2 = player
	slco = 0
	slide = 44
	oslide = 44
	mcount = 240
	if menu:
		rdmenu = 1
	menu = 2

static func do_off_menu(team: int, player: int) -> void:
	mdata1 = team
	mdata2 = player
	slco = 0
	slide = 44
	oslide = 44
	mcount = 240
	if menu:
		rdmenu = 1
	menu = 3

static func _team_menu(team: int, m: int) -> void:
	mdata1 = team
	slco = 0
	slide = 44
	oslide = 44
	mcount = 240
	if menu:
		rdmenu = 1
	menu = m

static func do_direct_menu(team: int) -> void: _team_menu(team, 4)
static func do_indirect_menu(team: int) -> void: _team_menu(team, 5)
static func do_penalty_menu(team: int) -> void: _team_menu(team, 6)
static func do_corner_menu(team: int) -> void: _team_menu(team, 7)
static func do_throw_menu(team: int) -> void: _team_menu(team, 8)
static func do_goalkick_menu(team: int) -> void: _team_menu(team, 9)
static func do_kickoff_menu(team: int) -> void: _team_menu(team, 10)
static func do_offside_menu(team: int) -> void: _team_menu(team, 11)

static func do_injured_menu(team: int, player: int) -> void:
	mdata1 = team
	mdata2 = player
	slco = 0
	slide = 44
	oslide = 44
	mcount = 240
	if menu:
		rdmenu = 1
	menu = 12

static func _big_menu(m: int, count_v: int) -> void:
	slco = 0
	slide = 108
	oslide = 108
	mcount = count_v
	if menu:
		rdmenu = 1
	menu = m
	mhgt = 128

static func do_fulltime_menu() -> void: _big_menu(13, 240000)
static func do_extratime_menu() -> void: _big_menu(14, 240000)
static func do_halftime_menu() -> void: _big_menu(15, 240000)
static func do_penalty_shootout_menu() -> void: _big_menu(16, 340)
static func do_final_score_menu() -> void: _big_menu(17, 240)

static func do_owngoal_menu(team: int, player: int, time: int) -> void:
	mdata1 = team
	mdata2 = player
	mdata3 = time
	slco = 0
	slide = 44
	oslide = 44
	mcount = 240
	if menu:
		rdmenu = 1
	menu = 18

static func do_options_menu(team: int, user_no: int) -> void:
	mdata1 = team
	mdata2 = user_no + 1
	slco = 0
	slide = 108
	oslide = 108
	mcount = 1000000
	if menu:
		rdmenu = 1
	menu = 19

static func do_formation_menu(team: int, user_no: int) -> void:
	mdata1 = team
	mdata2 = user_no + 1
	slco = 0
	slide = 92
	oslide = 92
	mcount = 1000000
	if menu:
		rdmenu = 1
	menu = 20

static func do_substitution_menu(team: int, user_no: int) -> void:
	mdata1 = team
	mdata2 = user_no + 1
	slco = 0
	slide = 108
	oslide = 108
	mcount = 1000000
	if menu:
		rdmenu = 1
	menu = 21

static func do_replay_menu(user_no: int) -> void:
	mdata1 = user_no + 1
	slco = 0
	slide = 34
	oslide = 34
	mcount = 1000000
	if menu:
		rdmenu = 1
	menu = 22

static func do_ref_menu() -> void:
	slco = 0
	slide = 44
	oslide = 44
	mcount = 240
	if menu:
		rdmenu = 1
	menu = 23

static func do_stats_menu() -> void:
	slco = 0
	slide = 140
	oslide = 140
	mcount = 200 * 6
	if menu:
		rdmenu = 1
	menu = 24

# adjust_menu()
static func adjust_menu() -> void:
	var l: buff_info = menu_buff_l[menu - 1]
	var h: buff_info = menu_buff_h[menu - 1]
	l.buff_hgt = mhgt
	l.clip_hgt = mhgt
	h.buff_hgt = mhgt << 1
	h.clip_hgt = mhgt << 1
	l.buff_start = MCGA_buff[0].buff_start + (MCGA_buff[0].clip_hgt - l.buff_hgt) * MCGA_buff[0].buff_wid + ((MCGA_buff[0].clip_wid - l.clip_wid) >> 1)
	var vb: buff_info = VESA_buff[1 if scrmode == 0x101 else 0][0]		# VESA_buff[scrmode-0x100][0]
	h.buff_start = vb.buff_start + (vb.clip_hgt - h.buff_hgt) * vb.buff_wid + ((vb.clip_wid - h.clip_wid) >> 1)
	# if (scrmode3DB>=0) ... (3D Blaster)
	if slide > mhgt - 20:
		slide = mhgt - 20
		oslide = slide

#******************************************************************************
# render3d(): key handling (top) and the 2D overlay (end)
#******************************************************************************

# render3d(): if (!kco&buffer!=&vidi_buff) { ... keys ... } else if (kco&&buffer!=&vidi_buff) kco--;
static func render3d_keys() -> void:
	if not kco:
		if keys[0x44] and setup.M8:		# F10
			var oscrmode: int = scrmode
			switchmode()
			if scrmode3DB < 0 and scrmode != oscrmode:
				setup.start_res = (setup.start_res + 1) & 1
				# vclear/svgacpy: clear screen
			else:
				setup.start_res = (1 if scrmode3DB > 0 else 0)
				scrmode = (0x100 if setup.start_res else 0x13)
			kco = 8

		if keys[0xc] and setup.screen_size < SCRSIZES - 1 and scrmode3DB < 0:	# -
			# clearbuffer(buffer,5);
			rdmenu = 1
			setup.screen_size += 1
			_set_main_buff_size()
			kco = 8

		if keys[0xd] and setup.screen_size > 0:		# =
			rdmenu = 1
			setup.screen_size -= 1
			_set_main_buff_size()
			kco = 8

		# if (keys[0x0e]) ... 3D Blaster on/off (not available)

		if scrmode3DB < 0:
			if keys[0x3f]:		# F5
				setup.detail.pitch = (setup.detail.pitch + 1) % 3
				kco = 8
			if setup.detail.pitch == 0 and setup.start_res == 1:
				setup.detail.pitch = 1
			if keys[0x40]:		# F6
				setup.detail.lines = (setup.detail.lines + 1) & 1
				kco = 8
			if keys[0x41]:		# F7
				setup.detail.sky = (setup.detail.sky + 1) & 1
				kco = 8
			if keys[0x42]:		# F8
				setup.detail.players = (setup.detail.players + 1) & 1
				kco = 8
#			if (keys[0x3f]) ++setup.detail.shadows&=1,kco=8;
			# F9: TGA screen dump (EUROmatch_info.tga_enable) - not ported
	else:
		if kco:
			kco -= 1

static func _set_main_buff_size() -> void:
	if scrmode == 0x13:
		main_buff.copy_from(MCGA_buff[setup.screen_size])
	else:
		var i: int = 0
		while scrmode != modelist[i]:
			i += 1
			if i == VESAMODES:
				break
		if i != VESAMODES:
			main_buff.copy_from(VESA_buff[i][setup.screen_size])
	_main_buff_changed()

# The 2D part of render3d(buffer==&main_buff): scanner, menus, clock / score.
static func render3d_2d() -> void:
	var buffer: buff_info = main_buff
	var i: int
	render_buff.copy_from(buffer)

	# (screen border: setup.screen_size>0 leaves the area around the render
	#  buffer in colour 5 - vclear(...,5) of setscreen / clearbuffer)
	if dev != null and setup.screen_size:
		dev.border(buffer, 5)

#// SCANNER

	if key_togs[0xf]:
		if scrmode == 0x13:
			# scrpt scanner_l[]={8,56, 44,56, 44,8, 8,8};  polyf(...,filters[0])  (y up)
			_shadow_at(render_buff.buff_start + (render_buff.clip_hgt - 56) * render_buff.buff_wid + 8, 44 - 8, 56 - 8)
			draw_sprite(buffer, 88, 9, buffer.clip_hgt - 55, 0)
			for i2 in range(22):
				i = i2
				var p: plyrdat = pos[i]
				if p.type:
					draw_sprite(buffer, 89 + (0 if ((i < 11 and (not (match_half & 1))) or (i >= 11 and (match_half & 1))) else 2),
						int(8 + (p.z * 34) / 800), int(buffer.clip_hgt - 10 - (p.x * 46) / 1280), 0)
			# plyrpt+=3;  (ball; ball.x = the drawn ball, = pos[25].x)
			draw_sprite(buffer, 89, int(8 + (pos[25].z * 34) / 800), int(buffer.clip_hgt - 10 - (pos[25].x * 46) / 1280), 31)
		else:
			# scrpt scanner_h[]={16,112, 88,112, 88,16, 16,16};
			_shadow_at(render_buff.buff_start + (render_buff.clip_hgt - 112) * render_buff.buff_wid + 16, 88 - 16, 112 - 16)
			draw_sprite_d(buffer, 88, 18, buffer.clip_hgt - 110, 0)
			for i2 in range(22):
				i = i2
				var p: plyrdat = pos[i]
				if p.type:
					draw_sprite(buffer, 90 + (0 if ((i < 11 and (not (match_half & 1))) or (i >= 11 and (match_half & 1))) else 2),
						int(15 + 2 * (p.z * 34) / 800), int(buffer.clip_hgt - 21 - 2 * (p.x * 46) / 1280), 0)
			draw_sprite(buffer, 89, int(16 + 2 * (pos[25].z * 34) / 800), int(buffer.clip_hgt - 20 - 2 * (pos[25].x * 46) / 1280), 31)

#// ANIMATE TEXTURES (vidi, flags): Godot renderer

	if menu:
		slco += log_factor * 5
		if mcount > 0:
			if slide > 0:
				while slco >= 1 and slide > 0:
					slco -= 1
					slide -= 1
			else:
				while slco >= 1:
					slco -= 1
					mcount -= 1
		else:
			while slco >= 1 and slide < oslide:
				slco -= 1
				slide += 1
			if slide >= oslide:
				menu = 0
				rdmenu = 1
		if menu:
			var sh: int = slide + 12 + (10 if menu == 22 else 0)
			if scrmode == 0x13:
				var ml: buff_info = menu_buff_l[menu - 1]
				menx3DB = int(ml.scale_x)
				meny3DB = int(ml.scale_y) + sh
				menu_buff.buff_start = ml.buff_start + MCGA_buff[0].buff_wid * sh
				menu_buff.buff_wid = ml.buff_wid
				menu_buff.buff_hgt = ml.buff_hgt
				menu_buff.clip_wid = ml.clip_wid
				menu_buff.clip_hgt = ml.clip_hgt - (slide + 12)
			else:
				var mh: buff_info = menu_buff_h[menu - 1]
				menx3DB = int(mh.scale_x)
				meny3DB = int(mh.scale_y) + (sh << 1)
				menu_buff.buff_start = mh.buff_start + VESA_buff[0 if scrmode == 0x100 else 1][0].buff_wid * (sh << 1)
				menu_buff.buff_wid = mh.buff_wid
				menu_buff.buff_hgt = mh.buff_hgt
				menu_buff.clip_wid = mh.clip_wid
				menu_buff.clip_hgt = mh.clip_hgt - ((slide + 12) << 1)
		match menu:
			1:
				goal_menu(menu_buff, mdata1, mdata2, mdata3)
			2:
				booked_menu(menu_buff, mdata1, mdata2)
			3:
				off_menu(menu_buff, mdata1, mdata2)
			4:
				direct_menu(menu_buff, mdata1)
			5:
				indirect_menu(menu_buff, mdata1)
			6:
				penalty_menu(menu_buff, mdata1)
			7:
				corner_menu(menu_buff, mdata1)
			8:
				throw_menu(menu_buff, mdata1)
			9:
				goalkick_menu(menu_buff, mdata1)
			10:
				kickoff_menu(menu_buff, mdata1)
			11:
				offside_menu(menu_buff, mdata1)
			12:
				injured_menu(menu_buff, mdata1, mdata2)
			13:
				fulltime_menu(menu_buff)
				adjust_menu()
			14:
				extratime_menu(menu_buff)
				adjust_menu()
			15:
				halftime_menu(menu_buff)
				adjust_menu()
			16:
				penalty_shootout_menu(menu_buff)
				adjust_menu()
			17:
				final_score_menu(menu_buff)
				adjust_menu()
			18:
				owngoal_menu(menu_buff, mdata1, mdata2, mdata3)
			19:
				options_menu(menu_buff, mdata1, mdata2)
			20:
				formation_menu(menu_buff, mdata1, mdata2)
			21:
				substitution_menu(menu_buff, mdata1, mdata2)
			22:
				replay_menu(menu_buff, mdata1)
			23:
				ref_menu(menu_buff)
			24:
				stats_menu(menu_buff)

	# (key_togs[0x0a]: vidi on/off - Godot renderer)

	var tstr: PackedByteArray
	var mid: int = buffer.clip_wid >> 1
	var end: int = buffer.clip_hgt
	menx3DB = 0
	meny3DB = 0
	# (3DENG.C declares struct mtime {unsigned short min; float secs;}: Glob mtime.sec)
	if menu < 19 or menu > 22:
		if match_time.sec < 10:
			tstr = _b("%d:0%d" % [match_time.min, int(match_time.sec)])
		else:
			tstr = _b("%d:%2d" % [match_time.min, int(match_time.sec)])
	else:
		match menu:
			19:
				tstr = GetTEXT(OPTN_TEXT)
			20:
				tstr = GetTEXT(FRMN_TEXT)
			21:
				tstr = GetTEXT(SBTN_TEXT)
			22:
				tstr = GetTEXT(RPLY_TEXT)
	if scrmode == 0x13:
		draw_string(buffer, 1, mid, 1, tstr, 31, 2)
		if not menu:
#			draw_string(&MCGA_buff[0],end-8,140,0,EUROmatch_info.TeamAname,31,1);
			i = draw_string(buffer, 1, mid - 20, end - 8, _b(cstr(EUROmatch_info.TeamAname)), 32, 1)
			if sub_pending & 1:
				draw_sprite(buffer, 84, mid - 20 - i - 16, end - 16, 0)
			tstr = _b("%d=%d" % [team_a_goals, team_b_goals])
			draw_string(buffer, 1, mid, end - 8, tstr, 31, 2)
			i = draw_string(buffer, 1, mid + 20, end - 8, _b(cstr(EUROmatch_info.TeamBname)), 56, 0)
			if sub_pending & 2:
				draw_sprite(buffer, 85, mid + 20 + i + 2, end - 16, 0)
	else:
		draw_string(buffer, 2, mid, 1, tstr, 31, 2)
		if not menu:
#			draw_string(&VESA_buff[0][0],end-14,mid-40,0,EUROmatch_info.TeamAname,31,1);
			i = draw_string(buffer, 2, mid - 40, end - 14, _b(cstr(EUROmatch_info.TeamAname)), 32, 1)
			if sub_pending & 1:
				draw_sprite(buffer, 86, mid - 40 - i - 20, end - 20, 0)
			tstr = _b("%d=%d" % [team_a_goals, team_b_goals])
			draw_string(buffer, 2, mid, end - 14, tstr, 31, 2)
			i = draw_string(buffer, 2, mid + 40, end - 14, _b(cstr(EUROmatch_info.TeamBname)), 56, 0)
			if sub_pending & 2:
				draw_sprite(buffer, 87, mid + 40 + i + 4, end - 20, 0)

# The draw_string() calls of 3D_UPD2 recorded this frame (Upd3D.text_items):
# [x, y, string, colour, just, font] drawn on main_buff after render3d().
static func draw_text_items(items: Array) -> void:
	for it in items:
		if it is Array and it.size() >= 6:
			draw_string(main_buff, it[5], it[0], it[1], it[2], it[3], it[4])

#******************************************************************************
# Vidi-wall (stadium video screen) animations: FAP clips (extra time, foul,
# full/half time, penalty, goal, winners). The renderer plays them on the
# stadium screen; the logic only triggers them.
#******************************************************************************

static var vidi_anim: int = 0
static var vidi_in: int = 0

static func do_extra_time_anim(sp: int) -> void: vidi_anim = 1
static func do_foul_anim(sp: int) -> void: vidi_anim = 2
static func do_full_time_anim(sp: int) -> void: vidi_anim = 3
static func do_half_time_anim(sp: int) -> void: vidi_anim = 4
static func do_penalty_anim(sp: int) -> void: vidi_anim = 5
static func do_goal_anim(sp: int) -> void: vidi_anim = 6
static func do_win_f_anim(sp: int) -> void: vidi_anim = 8
static func do_win_g_anim(sp: int) -> void: vidi_anim = 10
static func do_win_s_anim(sp: int) -> void: vidi_anim = 12

#******************************************************************************
# get_dir(int user_no): menu input reader (LINK build)
#******************************************************************************

static var count_ur: int = 0
static var count_ul: int = 0
static var count_ud: int = 0
static var count_uu: int = 0
static var count_uf1: int = 0
static var count_uf2: int = 0
static var uf1_p: int = 0
static var uf2_p: int = 0
static var uf3_p: int = 0
static var uf4_p: int = 0

# int get_dir(int user_no)
static func get_dir(user_no: int) -> int:
	var out: int
	# #ifdef LINK
	if user_no >= 0:
		icth = 32767
		isth = 0
		NetInput.get_user_inputs()
		NetInput.process_user_inputs()
		writeptr += 1
		writeptr &= 511
		User.convert_inputs()
		readptr += 1
		readptr &= 511
	else:
		users_dir[0].x = 0
		users_dir[0].y = 0
		users_dir[0].f = 0
		# #ifdef LINK  (extended cursor keys: SPECIALK+code)
		if keys[0xcd]:
			users_dir[0].x = 1
		if keys[0xcb]:
			users_dir[0].x = -1
		if keys[0xd0]:
			users_dir[0].y = 1
		if keys[0xc8]:
			users_dir[0].y = -1
		if keys[0x52]:
			users_dir[0].f = 1
		if keys[0x53]:
			users_dir[0].f = 1
		user_no = 0

	out = 0
	if users_dir[user_no].x > 0.1:
		if count > count_ur + 50:
			out |= RIGHT_DIR
			count_ur = count + 100
	else:
		if users_dir[user_no].x < -0.1:
			if count > count_ul + 50:
				out |= LEFT_DIR
				count_ul = count + 100
		else:
			count_ul = 0
			count_ur = 0
	if users_dir[user_no].y > 0.1:
		if count > count_ud + 50:
			out |= DOWN_DIR
			count_ud = count + 100
	else:
		if users_dir[user_no].y < -0.1:
			if count > count_uu + 50:
				out |= UP_DIR
				count_uu = count + 100
		else:
			count_uu = 0
			count_ud = 0
	if users_dir[user_no].f & 1:
		if count > count_uf1 + 50:
			out |= FIRE1_DIR
			count_uf1 = count + 100
	else:
		count_uf1 = 0
	if users_dir[user_no].f & 2:
		if count > count_uf2 + 50:
			out |= FIRE2_DIR
			count_uf2 = count + 100
	else:
		count_uf2 = 0
	if not keys[0x3b]:
		uf1_p = 0
	elif not uf1_p:
		out |= F1_DIR | FIRE1_DIR
		uf1_p = 1
	if not keys[0x3c]:
		uf2_p = 0
	elif not uf2_p:
		out |= F2_DIR | FIRE1_DIR
		uf2_p = 1
	if not keys[0x3d]:
		uf3_p = 0
	elif not uf3_p:
		out |= F3_DIR | FIRE1_DIR
		uf3_p = 1
	if not keys[0x3e]:
		uf4_p = 0
	elif not uf4_p:
		out |= F4_DIR | FIRE1_DIR
		uf4_p = 1

	return out

#******************************************************************************
# Modal in-game menus: options() / formation() / substitution() / replay()
#
# Each call of modal_frame() runs one iteration (one render3d+dump+frame_count)
# of the loop the original would be executing.
#******************************************************************************

static var modal: int = 0			# 0 none, 1 options, 2 substitution
static var modal_user: int = 0
static var modal_team: int = 0
static var modal_cam: Array = []		# viewx,viewy,viewz,targx,targy,targz,vdist of the call

const ST_NONE := 0
const ST_OPT_SLIDE := 1
const ST_OPT_LOOP := 2
const ST_REP_SLIDE := 3
const ST_REP_LOOP := 4
const ST_FOR_SLIDE := 5
const ST_FOR_LOOP := 6
const ST_SUB_SLIDE := 7
const ST_SUB_LOOP := 8
const ST_WAIT := 9			# while (users_dir[user_no].f&3) get_dir(user_no);

const W_REP_DONE := 1		# replay(): re_exit
const W_OPT_DONE := 2		# options(): op_exit
const W_FOR_ESC := 3		# formation(): Esc path
const W_SUB_DONE := 4		# substitution(): su_exit

static var mstate: int = ST_NONE
static var wait_user: int = 0
static var wait_then: int = 0
static var oform: int = 0			# formation(): int oform
static var rep_dir: int = 0			# replay(): dir of the iteration
static var repcount: int = 0		# replay(): int repcount
static var rep_post: bool = false	# second half of a replay iteration pending
static var _mstarted: bool = false
static var _rep_pos_in: int = 0

# void options(buff_info *buffer,datapt viewx,...,int user_no,int team)
static func options(viewx: float, viewy: float, viewz: float, targx: float, targy: float, targz: float, vdist: float, user_no: int, team: int) -> void:
	opt_b = 0
	uf1_p = 1
	uf2_p = 1
	uf3_p = 1
	uf4_p = 1
	if _no_replay():
		opt_b = 3
	if user_no < 0:
		if _no_replay():
			return
		sub_c = 0
	else:
		sub_c = (_gd(team).players[11].flags & 1)
		sub_c += (_gd(team).players[12].flags & 1)
		sub_c += (_gd(team).players[13].flags & 1)
		sub_c += (_gd(team).players[14].flags & 1)
	option_info_formation = (tactics_a if team == 0 else tactics_b)
	modal = 1
	modal_user = user_no
	modal_team = team
	modal_cam = [viewx, viewy, viewz, targx, targy, targz, vdist]
	_mstarted = false
	_rep_pos_in = replay_pos
	_op_loop()

static func _op_loop() -> void:
	# op_loop:
	do_options_menu(modal_team, modal_user)
	mstate = ST_OPT_SLIDE

# void substitution(buff_info *buffer,datapt viewx,...,int team)
static func substitution(viewx: float, viewy: float, viewz: float, targx: float, targy: float, targz: float, vdist: float, team: int) -> void:
	var user_no: int
	user_no = (sub_p_a if team == 0 else sub_p_b)
	option_info_sub_off = 0
	option_info_sub_on = 11
	while option_info_sub_off < 21 and _gd(team).players[option_info_sub_off].flags & 2:
		option_info_sub_off += 1
	while option_info_sub_on < 21 and (int(not _gd(team).players[option_info_sub_on].flags) & 1):
		option_info_sub_on += 1
	sub_b = 0
	uf1_p = 1
	uf2_p = 1
	uf3_p = 1
	uf4_p = 1
	modal = 2
	modal_user = user_no
	modal_team = team
	modal_cam = [viewx, viewy, viewz, targx, targy, targz, vdist]
	_mstarted = false
	_rep_pos_in = replay_pos
	do_substitution_menu(team, user_no)
	mstate = ST_SUB_SLIDE

# FOOT.CPP / CONTROL.CPP: void SubstituePlayers(int a,int b,int c) {}  (empty)
static func SubstituePlayers(a: int, b: int, c: int) -> void:
	pass

# One render3d(buffer, viewx...) + main_buff.dump() of a modal loop.
static func _render_frozen() -> void:
	var c: Array = modal_cam
	Upd3D.view.viewx = c[0]
	Upd3D.view.viewy = c[1]
	Upd3D.view.viewz = c[2]
	Upd3D.view.targx = c[3]
	Upd3D.view.targy = c[4]
	Upd3D.view.targz = c[5]
	Upd3D.view.vdist = c[6]
	Upd3D.view.vidi = false
	Upd3D.render3d_view(c[0], c[1], c[2], c[3], c[4], c[5], false)
	if dev != null:
		dev.render_frame(false, true)

static func _clear_fkeys() -> void:
	keys[0x3b] = 0
	keys[0x3c] = 0
	keys[0x3d] = 0
	keys[0x3e] = 0

# if (user_no>=0) while (users_dir[user_no].f&3) get_dir(user_no);   then continue with `then`
static func _wait_release(user_no: int, then: int) -> void:
	if user_no >= 0 and (users_dir[user_no].f & 3):
		wait_user = user_no
		wait_then = then
		mstate = ST_WAIT
		return
	_continue(then)

static func _continue(code: int) -> void:
	match code:
		W_REP_DONE:
			_clear_fkeys()
			Upd3D.reset_replay()
			mcount = 1
			# (back in options(): goto op_exit)
			_wait_release(modal_user, W_OPT_DONE)
		W_OPT_DONE:
			_clear_fkeys()
			mcount = 1
			_modal_end()
		W_FOR_ESC:
			_clear_fkeys()
			_fo_exit()
		W_SUB_DONE:
			_clear_fkeys()
			sub_pending &= (2 if modal_team == 0 else 1)
			mcount = 1
			_modal_end()

static func _fo_exit() -> void:
	# fo_exit:;
	mcount = 1
	# (back in options(): case 2)
	if for_b == 2:
		_op_loop()
	else:
		_wait_release(modal_user, W_OPT_DONE)

# What update_3d() did after options()/substitution() returned.
static func _modal_end() -> void:
	if modal == 2:
		# if (!player_being_subbed) camera=sub_camera;  (camera was 17 during the call)
		if player_being_subbed:
			camera = 17
		else:
			camera = sub_camera
	replay_pos = old_rep_pos
	old_count = count
	opt_user = 0
	Football.stop_mf_time()
	modal = 0
	mstate = ST_NONE

# Run one frame of the current modal loop.
static func modal_frame() -> void:
	var dir: int
	if not modal:
		return
	if not _mstarted:
		# update_3d(): replay_pos++ while the menus run
		_mstarted = true
		replay_pos = _rep_pos_in
	var user_no: int = modal_user
	var team: int = modal_team
	match mstate:
		ST_WAIT:
			get_dir(wait_user)
			if not (users_dir[wait_user].f & 3):
				_continue(wait_then)

		ST_OPT_SLIDE, ST_REP_SLIDE, ST_FOR_SLIDE, ST_SUB_SLIDE:
			# do { render3d(...); main_buff.dump(0,0); frame_count(); } while (slide>0);
			_render_frozen()
			Display.frame_count()
			if not (slide > 0):
				mstate += 1

		ST_OPT_LOOP:
			dir = get_dir(user_no)
			if dir & F1_DIR:
				if _no_replay():
					dir ^= FIRE1_DIR
				else:
					opt_b = 0
			if dir & F2_DIR:
				if match_mode or not EUROmatch_info.substitutes or sub_c < 2:
					dir ^= FIRE1_DIR
				else:
					opt_b = 1
			if dir & F3_DIR:
				if user_no < 0:
					dir ^= FIRE1_DIR
				else:
					opt_b = 2
			if dir & F4_DIR:
				opt_b = 3
			while true:		# re_opt:;
				if dir & UP_DIR:
					if user_no < 0 and opt_b == 3:
						opt_b = 2
						continue
					if (match_mode or not EUROmatch_info.substitutes or sub_c < 2) and opt_b == 2:
						opt_b = 1
						continue
					if _no_replay() and opt_b == 1:
						opt_b = 0
						continue
					opt_b = (opt_b + 3) % 4
				if dir & DOWN_DIR:
					if user_no < 0 and opt_b == 1:
						opt_b = 2
						continue
					if (match_mode or not EUROmatch_info.substitutes or sub_c < 2) and opt_b == 0:
						opt_b = 1
						continue
					if _no_replay() and opt_b == 3:
						opt_b = 0
						continue
					opt_b = (opt_b + 1) % 4
				break
			_render_frozen()
			Display.frame_count()
			if dir & (FIRE1_DIR | FIRE2_DIR):
				match opt_b:
					0:
						_replay_start(user_no)
						return
					1:
						if team == 0:
							sub_pending ^= 1
							sub_p_a = user_no
						else:
							sub_pending ^= 2
							sub_p_b = user_no
#						substitution(buffer,viewx,viewy,viewz,targx,targy,targz,vdist,plyrtb,xyz_ptr,ref_ptr,user_no,team);
						_wait_release(user_no, W_OPT_DONE)
						return
					2:
						_formation_start(user_no, team)
						return
					3:
						_wait_release(user_no, W_OPT_DONE)
						return
			if keys[1]:
				keys[1] = 0
				_wait_release(user_no, W_OPT_DONE)

		ST_REP_LOOP:
			if rep_post:
				# (second half of the previous iteration: repstep is the time the
				#  iteration's render took, i.e. one frame)
				rep_post = false
				var repstep: float = (count - repcount) / 200.0
				if rep_dir & (FIRE1_DIR | FIRE2_DIR):
					match rep_b:
						0:
							if speed > 0:
								speed -= 1
						1:
							if speed < 5:
								speed += 1
						2:
							if speed:
								play = int(not play)
							else:
								reppos += repstep * 3 / 5.0
						3:
							_rep_exit(user_no)
							return
				if play:
					reppos += repstep * speed / 5.0
				if reppos >= replay_seconds:
					reppos = 0
					play = 0
				if keys[1]:		# } while (!keys[1]);
					keys[1] = 0
					_rep_exit(user_no)
					return
			dir = get_dir(user_no)
			if dir & F1_DIR:
				rep_b = 0
			if dir & F2_DIR:
				rep_b = 1
			if dir & F3_DIR:
				rep_b = 2
			if dir & F4_DIR:
				rep_b = 3
			if dir & LEFT_DIR:
				rep_b = (rep_b + 3) % 4
			if dir & RIGHT_DIR:
				rep_b = (rep_b + 1) % 4
			rep_dir = dir
			repcount = count
			Upd3D.do_replay_render3d(reppos)
			# (LINK: render3d() is called by update_3d())
			if dev != null:
				dev.render_frame(true, true)
			Display.frame_count()
			rep_post = true

		ST_FOR_LOOP:
			dir = get_dir(user_no)
			if dir & F1_DIR:
				for_b = 0
			if dir & F2_DIR:
				for_b = 1
			if dir & F3_DIR:
				for_b = 2
			if dir & UP_DIR:
				for_b = (for_b + 2) % 3
			if dir & DOWN_DIR:
				for_b = (for_b + 1) % 3
			_render_frozen()
			Display.frame_count()
			if dir & (FIRE1_DIR | FIRE2_DIR):
				match for_b:
					0:
						if dir & FIRE1_DIR:
							option_info_formation = (option_info_formation + 1) % 10
						else:
							option_info_formation = (option_info_formation + 9) % 10
					1:
						if team == 0:
							tactics_a = option_info_formation
						else:
							tactics_b = option_info_formation
						Football.load_new_tactics()
						_fo_exit()
						return
					2:
						option_info_formation = oform
						_fo_exit()
						return
			if keys[1]:
				keys[1] = 0
				_wait_release(user_no, W_FOR_ESC)

		ST_SUB_LOOP:
			dir = get_dir(user_no)
			if dir & F1_DIR:
				sub_b = 0
			if dir & F2_DIR:
				sub_b = 1
			if dir & F3_DIR:
				sub_b = 2
			if dir & F4_DIR:
				sub_b = 3
			if dir & UP_DIR:
				sub_b = (sub_b + 3) % 4
			if dir & DOWN_DIR:
				sub_b = (sub_b + 1) % 4
			_render_frozen()
			Display.frame_count()
			if dir & (FIRE1_DIR | FIRE2_DIR):
				match sub_b:
					0:
						while true:
							if dir & FIRE1_DIR:
								option_info_sub_off = (option_info_sub_off + 1) % 11
							else:
								option_info_sub_off = (option_info_sub_off + 10) % 11
							if not (_gd(team).players[option_info_sub_off].flags & 2):
								break
					1:
						Upd3D.sub_player(team, option_info_sub_off, option_info_sub_on)
						SubstituePlayers((setup.team_a if team == 0 else setup.team_b), option_info_sub_off, option_info_sub_on)
						_wait_release(user_no, W_SUB_DONE)
						return
					2:
						_wait_release(user_no, W_SUB_DONE)
						return
					3:
						var guard: int = 0
						while true:
							if dir & FIRE1_DIR:
								option_info_sub_on += 1
								if option_info_sub_on > 14:
									option_info_sub_on = 11
							else:
								option_info_sub_on -= 1
								if option_info_sub_on < 11:
									option_info_sub_on = 14
							guard += 1
							if not (int(not _gd(team).players[option_info_sub_on].flags) & 1) or guard > 4:
								break
			if keys[1]:
				keys[1] = 0
				_wait_release(user_no, W_SUB_DONE)

# replay(buffer,...,user_no): set-up part
static func _replay_start(user_no: int) -> void:
	rep_b = 3
	uf1_p = 1
	uf2_p = 1
	uf3_p = 1
	uf4_p = 1
	play = 1
	speed = 5
	reppos = 0
	Upd3D.setup_replay()
	do_replay_menu(user_no)
	rep_post = false
	mstate = ST_REP_SLIDE

static func _rep_exit(user_no: int) -> void:
	# re_exit:;
	_wait_release(user_no, W_REP_DONE)

# formation(buffer,...,user_no,team): set-up part
static func _formation_start(user_no: int, team: int) -> void:
	oform = option_info_formation
	for_b = 0
	uf1_p = 1
	uf2_p = 1
	uf3_p = 1
	uf4_p = 1
	do_formation_menu(team, user_no)
	mstate = ST_FOR_SLIDE
