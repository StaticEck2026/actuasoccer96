# The parts of 3DENG.C (Laurent Noel's 3D engine) that the match logic calls:
# in-match overlay menus (state machine; drawn by scripts/render/hud.gd), the
# vidi-wall animation triggers, the stadium table and screen setup hooks.
# The software rasteriser itself is replaced by the Godot renderer.
class_name Eng3D extends Glob

# Stadium table: stadlist[] / stad_info live in Glob (tools/glob_extra.gd).

#******************************************************************************
# Menu state (3DENG.C)
#******************************************************************************

static var menu: int = 0		# Current overlay menu (0 = none)
static var rdmenu: int = 0		# Redraw menu flag
static var mdata1: int = 0
static var mdata2: int = 0
static var mdata3: int = 0
static var slco: int = 0		# Slide counter
static var slide: int = 0
static var oslide: int = 0
static var mcount: int = 0		# Menu display time (frames)
static var mhgt: int = 0

# char sub_pending;  (bit 0: team 0 wants a substitution, bit 1: team 1)
static var sub_pending: int = 0

# void do_goal_menu(int team, int player, int time)
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
# Screen / engine lifetime hooks
#******************************************************************************

# word scrmode;  (S)VGA mode number: the match ran in VESA hi-res (font 2)
static var scrmode: int = 0x101

#******************************************************************************
# Modal in-game menus entered from update_3d(): options (formation, subs,
# replay, stats...) and substitution. In the original these were blocking loops
# with their own rendering; here they open a modal menu state that the driver
# runs (scripts/render/hud.gd) while the match is frozen.
#******************************************************************************

static var modal: int = 0			# 0 none, 1 options, 2 substitution
static var modal_user: int = 0
static var modal_team: int = 0
static var modal_cam: Array = []

# void options(buff_info *buffer,datapt viewx,...,int user_no,int team)
static func options(viewx: float, viewy: float, viewz: float, targx: float, targy: float, targz: float, vdist: float, user_no: int, team: int) -> void:
	modal = 1
	modal_user = user_no
	modal_team = team
	modal_cam = [viewx, viewy, viewz, targx, targy, targz, vdist]

# void substitution(buff_info *buffer,datapt viewx,...,int team)
static func substitution(viewx: float, viewy: float, viewz: float, targx: float, targy: float, targz: float, vdist: float, team: int) -> void:
	modal = 2
	modal_user = 0
	modal_team = team
	modal_cam = [viewx, viewy, viewz, targx, targy, targz, vdist]

# RESULTS.H: void GOAL_SCORED(int team,int scorer,int time)  (front-end results log)
static var goals_log: Array = []
static func GOAL_SCORED(team: int, scorer: int, time: int) -> void:
	goals_log.append([team, scorer, time])

static func setscreen() -> void:
	pass

static func end3d() -> void:
	pass
