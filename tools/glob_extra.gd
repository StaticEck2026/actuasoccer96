# Globals defined in modules compiled without debug info (3DENG.C) or in the
# runtime/OS layer, which the ported match code still references.

class detail_info:
	var sky: int = 0
	var stadia: int = 0
	var pitch: int = 0
	var players: int = 0
	var lines: int = 0
	var shadows: int = 0

class setup_info:
	var M8: int = 1
	var team_a: int = 0
	var team_b: int = 1
	var team_b_kit: int = 1
	var stadium: int = 0
	var vidi_type: int = 0
	var start_res: int = 0
	var screen_size: int = 0
	var verbose: int = 0
	var detail: detail_info = detail_info.new()

# 3DENG.C: setup_info setup;
static var setup: setup_info = setup_info.new()
# 3DENG.C: viewing angle cos/sin (extern float cth,sth)
static var cth: float = 1.0
static var sth: float = 0.0
# FOOT/NETWORK timing
static var w95: int = 0
static var anykey: int = 0
static var return_doskey: int = 0
# FOOTBALL.CPP (this source revision): short performance[] per player (0..100%),
# shown by 3D_UPD2 info lines. (The newer compiled object used a passback_per struct.)
static var performance: Array = CBase._arr(40, 0)
# 3DENG.C: int performance (machine speed index; FOOT.CPP sets 31 = Pentium)
static var machine_performance: int = 31

# needed by ball (BALL.CPP stadium_bounds; FILES.C: stad_info stadlist[135]).
# Only the numeric gameplay/camera fields of stad_info (3DENG.H) are kept; the
# file/bitmap/model fields belong to the renderer. Values from SOURCE/FILES.C.
class stad_info:
	var st_w: int = 0  # int
	var st_l: int = 0  # int
	var st_h: int = 0  # int
	var vid1x: int = 0  # int
	var vid1y: int = 0  # int
	var vid1z: int = 0  # int
	var vid2x: int = 0  # int
	var vid2y: int = 0  # int
	var vid2z: int = 0  # int
	var tunlx: int = 0  # int
	var tunly: int = 0  # int
	var tunlz: int = 0  # int
	var vmap: int = 0  # int

# runs of identical entries: [count, st_w,st_l,st_h, vid1x,vid1y,vid1z, vid2x,vid2y,vid2z, tunlx,tunly,tunlz, vmap]
const _STADLIST_RUNS := [
	[45, 180, 200, 180, -292, 202, -1066, 1569, 187, 246, 638, 28, -980, 0],
	[45, 180, 200, 180, -292, 202, -1066, 1569, 187, 246, 638, 28, -1206, 3635],
	[45, 360, 390, 820, -362, 311, -870, 1550, 313, 77, 595, 31, -1425, 1802],
]

static func _mk_stadlist() -> Array:
	var a: Array = []
	for run in _STADLIST_RUNS:
		for k in run[0]:
			var s := stad_info.new()
			s.st_w = run[1]; s.st_l = run[2]; s.st_h = run[3]
			s.vid1x = run[4]; s.vid1y = run[5]; s.vid1z = run[6]
			s.vid2x = run[7]; s.vid2y = run[8]; s.vid2z = run[9]
			s.tunlx = run[10]; s.tunly = run[11]; s.tunlz = run[12]
			s.vmap = run[13]
			a.append(s)
	return a

# FILES.C: stad_info stadlist[]
static var stadlist: Array = _mk_stadlist()  # stad_info[135]

# needed by actions_b: EXTERNS.H "extern int *tussle_ptr;" (pointer into tussle_tab[], kept as an index)
static var tussle_ptr: int = 0
# needed by football: MOUSE.H Mouse.x / Mouse.y (debug ball positioning)
static var mouse_x: int = 0
static var mouse_y: int = 0

# needed by ballint (get_mcball_coords/out_mcball_coords): 3DENG.C motion-capture
# tables, to be filled by the renderer's data loader (3DENG.C init: cappts = running
# frame total, player_p = all capture frames).
class mcap:
	var cappts: int = 0  # word
	var capfrms: int = 0  # word

# 3DENG.C: mcap *mcaps  (points to mcaps8[MC_NO] or mcaps4[MC_NO])
static var mcaps: Array = []  # mcap[MC_NO]
# 3DENG.C: capfrm *player_p  (typedef datapt capfrm[PLYRPTS*3+1]): one Array of PLYRPTS*3+1 floats per frame
static var player_p: Array = []  # capfrm[mc_tot]

# C string helpers: char arrays are stored as Arrays of byte values (or Strings
# when filled by the Godot front end).  cstr(a, off) == (char *)&a[off]
static func cstr(a, off: int = 0) -> String:
	if a is String:
		return a.substr(off)
	var s := PackedByteArray()
	var i: int = off
	while i < a.size() and a[i] != 0:
		s.append(a[i])
		i += 1
	return s.get_string_from_utf8()

static func set_cstr(a: Array, s: String) -> void:
	var b := s.to_utf8_buffer()
	for i in range(a.size()):
		a[i] = b[i] if i < b.size() else 0
# FOOT.CPP: short no_front_users;
static var no_front_users: int = 0

# C++ dynamic initialisers of glob_var.h (recovered from FOOTBALL.OBJ .fn_init):
#   float zone_wid=pitch_len/7; float zone_hgt=pitch_wid/3;
#   int top_post_y=cntspot_y-prat*4; int bot_post_y=cntspot_y+prat*4;
static func glob_var_dynamic_init() -> void:
	zone_wid = pitch_len / 7
	zone_hgt = pitch_wid / 3
	top_post_y = int(cntspot_y - prat * 4)
	bot_post_y = int(cntspot_y + prat * 4)
