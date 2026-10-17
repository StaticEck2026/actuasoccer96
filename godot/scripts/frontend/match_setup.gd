# Pre-match setup: the hand-over from the Euro 96 front end to the match engine.
# Mirrors what FOOT.CPP main() (defaults, users, keyboard, init_team) and
# EURO_MAT.CPP (EUROmatch_info / match_info / setup from the front-end choices)
# did before calling match().  The front-end menus themselves are not part of
# the match port; scripts/frontend/menu.gd provides a minimal selection screen.
class_name MatchSetup extends Glob

static var squads: Dictionary = {}

const FORMATIONS := {"4-3-3": F_4_3_3, "5-3-2": F_5_3_2, "6-3-1": F_6_3_1, "4-2-4": F_4_2_4,
	"5-1-4": F_5_1_4, "4-0-6": F_4_0_6, "3-1-6": F_3_1_6, "4-1-5": F_4_1_5,
	"5-2-3": F_5_2_3, "4-4-2": F_4_4_2}

static func load_squads() -> void:
	if not squads.is_empty():
		return
	var f := FileAccess.open("res://data/squads.json", FileAccess.READ)
	squads = JSON.parse_string(f.get_as_text())

static func team_names() -> Array:
	load_squads()
	var a: Array = []
	for t in squads.teams:
		a.append(t.name)
	return a

# Fill game_data[] (team_info) for all 16 Euro teams from SCRIPT.96 data.
# (game_data is indexed with setup.team_a / setup.team_b by FOOTBALL.CPP.)
static func fill_game_data() -> void:
	load_squads()
	var n: int = squads.teams.size()
	while game_data.size() < n:
		game_data.append(team_info.new())
	# Arcade mode ("GameType 0") uses a world ranking per team; the Euro build
	# had no ranking table in the source, so rank the 16 teams by squad average.
	var avg: Array = []
	for ti in range(n):
		var s: float = 0
		for p in squads.teams[ti].players.slice(0, 11):
			s += p.pace + p.power + p.control + p.flair + p.vision + p.accuracy + p.stamina + p.discipline
		avg.append([s, ti])
	avg.sort_custom(func(a, b): return a[0] > b[0])
	for ti in range(n):
		var t = squads.teams[ti]
		var g: team_info = game_data[ti]
		set_cstr(g.name, t.name)
		g.team_no = ti
		g.team_number = ti
		for k in range(avg.size()):
			if avg[k][1] == ti:
				g.ranking = k + 1
		g.formation = FORMATIONS.get(t.formation, F_4_4_2)
		for pi in range(min(22, t.players.size())):
			var src = t.players[pi]
			var d: player_info = g.players[pi]
			set_cstr(d.name, src.name)
			# goal_index: offset of the surname (capitalised part) in the name
			var gi: int = 0
			var parts: PackedStringArray = src.name.split(" ")
			for w in range(parts.size()):
				if parts[w].length() > 1 and parts[w] == parts[w].to_upper():
					gi = src.name.find(parts[w])
					break
			d.goal_index = gi
			d.pace = src.pace
			d.power = src.power
			d.control = src.control
			d.flair = src.flair
			d.vision = src.vision
			d.accuracy = src.accuracy
			d.stamina = src.stamina
			d.discipline = src.discipline
			d.squad_number = pi + 1
			d.position = ["GK", "DF", "MD", "FD"].find(src.posn)
			d.flags = 0

# The Euro 96 build's stad_info table (compiled 3DENG.OBJ; FILES.C in the source
# release is the older Actua Soccer table): 8 venues, used by the logic for the
# ball/camera bounds (st_w/st_l/st_h), the tunnel and the vidi screens.
static func install_euro_stadiums() -> void:
	var f := FileAccess.open("res://assets/stadiums.json", FileAccess.READ)
	if f == null:
		return
	var st: Array = JSON.parse_string(f.get_as_text()).stadiums
	for i in range(st.size()):
		var d: stad_info = stadlist[i]
		var s = st[i]
		d.st_w = int(s.st_w)
		d.st_l = int(s.st_l)
		d.st_h = int(s.st_h)
		d.vid1x = int(s.vid1[0]); d.vid1y = int(s.vid1[1]); d.vid1z = int(s.vid1[2])
		d.vid2x = int(s.vid2[0]); d.vid2y = int(s.vid2[1]); d.vid2z = int(s.vid2[2])
		d.tunlx = int(s.tunl[0]); d.tunly = int(s.tunl[1]); d.tunlz = int(s.tunl[2])
		d.vmap = int(s.vmap)

# cfg keys: team_a, team_b (0..15), time (0..4 -> 5,10,20,40,90 min), game_type
# (0 arcade / 1 simulation), competition (FRIENDLY / CUP / PRACTICE / PENALTIES),
# camera (index into cam_array), users: [{team:0|1, control:0..5 (keys1,keys2,joy1,joy2,mouse,logpad)}],
# offside, bookings, freekicks, substitutes, wind (0..3), vidi, referee_vision,
# referee_discipline, rand, stadium.
static func prepare(cfg: Dictionary) -> void:
	fill_game_data()
	glob_var_dynamic_init()
	install_euro_stadiums()
	# 3DENG init3d(): motion-capture tables (mcaps/player_p) are also read by
	# the game logic (BALLINT get_mcball_coords), so load them before the match.
	R3DAssets.install_mocap_tables()

	# ---- FOOT.CPP main() defaults ----
	w95 = 0
	no_front_users = 0
	num_of_users = 0
	NetInput.claim_key_int()		# init_joys(); claim_key_int()
	Football.init_joys()

	machine_performance = 31			# Pentium speed!
	setup.team_a = cfg.get("team_a", 4)
	setup.team_b = cfg.get("team_b", 6)
	setup.team_b_kit = setup.team_b
	setup.stadium = cfg.get("stadium", 0)
	setup.start_res = 0
	setup.vidi_type = 0		# 0=norm, 1=filtered
	setup.verbose = 0
	setup.screen_size = 0
	setup.detail.stadia = 1	# 0=simple,1=complex
	setup.detail.pitch = 2	# 0=simple,1=lo,2=hi
	setup.detail.sky = 1		# 0=off,1=on
	setup.detail.players = 1	# 0=simple,1=full
	setup.detail.lines = 1	# 0=simple,1=full
	setup.detail.shadows = 1	# 0=simple,1=full
	setup.M8 = 1

	game_data[setup.team_a].player_control = 0
	game_data[setup.team_b].player_control = 0

	# Setup Subs...
	for i in range(11, 15):
		game_data[setup.team_a].players[i].flags = 1
		game_data[setup.team_b].players[i].flags = 1

	EUROmatch_info.camera = cfg.get("camera", 0)
	EUROmatch_info.audio = cfg.get("audio", FALSE)
	EUROmatch_info.timeit = FALSE
	EUROmatch_info.offside = cfg.get("offside", TRUE)
	EUROmatch_info.bookings = cfg.get("bookings", TRUE)
	EUROmatch_info.freekicks = cfg.get("freekicks", TRUE)
	EUROmatch_info.substitutes = cfg.get("substitutes", TRUE)
	EUROmatch_info.time = cfg.get("time", 0)
	EUROmatch_info.tac_1 = game_data[setup.team_a].formation
	EUROmatch_info.tac_2 = game_data[setup.team_b].formation
	match_info.CompetitionType = cfg.get("competition", CUP)
	EUROmatch_info.crowd = 0x1fff	# Crowd noise level!
	EUROmatch_info.pitch = 0x7fff	# Pitch noise level!
	EUROmatch_info.commentary = 0x7fff	# Commentary level!
	EUROmatch_info.master = 0x7fff	# Master noise level!
	EUROmatch_info.referee_vision = cfg.get("referee_vision", 120)
	EUROmatch_info.referee_discipline = cfg.get("referee_discipline", 80)
	EUROmatch_info.rand = cfg.get("rand", 3523)
	match_info.GameType = cfg.get("game_type", 1)		# 0 Arcade 1 Simulation...
	EUROmatch_info.GameType = match_info.GameType
	match_info.referee = 0
	EUROmatch_info.wind = cfg.get("wind", 0)
	EUROmatch_info.vidi = cfg.get("vidi", 1)

	net_half = 1				# Network game time...
	say_names = TRUE
	audio_version = EUROmatch_info.audio
	network_on = 0
	old_mf = TRUE

	# Timer stuff...
	ftick = 0
	tick = 0
	count = 0
	game_speed = REAL_SPEED
	readptr = 0
	writeptr = 0

	injury_time = 0

	# ---- EURO_MAT.CPP: users of this match ----
	for c in range(4):
		EUROmatch_info.CntrlTypes[c] = -1
	EUROmatch_info.TeamA_users = 0
	EUROmatch_info.TeamB_users = 0
	var user_flag: int = 1
	var cntrl_cnt: int = 0
	for u in cfg.get("users", []):
		if u.team == 0:
			EUROmatch_info.TeamA_users |= user_flag
		else:
			EUROmatch_info.TeamB_users |= user_flag
		EUROmatch_info.CntrlTypes[cntrl_cnt] = u.control
		EUROmatch_info.PlyrTypes[cntrl_cnt] = 0
		user_flag += user_flag
		cntrl_cnt += 1

	set_cstr(EUROmatch_info.TeamAname, cstr(game_data[setup.team_a].name))
	set_cstr(EUROmatch_info.TeamBname, cstr(game_data[setup.team_b].name))
	set_cstr(EUROmatch_info.RefsName, "TOM JONES")
	for p in range(20):
		EUROmatch_info.TeamAsquad[p] = p
		EUROmatch_info.TeamBsquad[p] = p
		var a: player_info = game_data[setup.team_a].players[p]
		var b: player_info = game_data[setup.team_b].players[p]
		var da = EUROmatch_info.TeamA[p]
		var db = EUROmatch_info.TeamB[p]
		da.pace = a.pace; da.power = a.power; da.control = a.control; da.flair = a.flair
		da.vision = a.vision; da.accuracy = a.accuracy; da.stamina = a.stamina; da.discipline = a.discipline; da.fitness = 99
		db.pace = b.pace; db.power = b.power; db.control = b.control; db.flair = b.flair
		db.vision = b.vision; db.accuracy = b.accuracy; db.stamina = b.stamina; db.discipline = b.discipline; db.fitness = 99

	# FOOT.CPP order: init_users(); init_team(); ... init_keyboard();
	User.init_users()
	Actions.init_team()
	User.init_keyboard()
