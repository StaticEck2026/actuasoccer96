# Pre-match selection screen.
# The Euro 96 front end (EURO_*.CPP: tournament, squads, redefine keys...) is not
# part of the match port; this screen sets the same values the front end handed
# to the match engine through EUROmatch_info / match_info / setup (see
# scripts/frontend/match_setup.gd).
extends Control

signal start_requested(cfg: Dictionary)

const VENUES := ["London (Wembley)", "Birmingham (Villa Park)", "Leeds (Elland Road)", "Newcastle (St James' Park)",
	"Manchester (Old Trafford)", "Liverpool (Anfield)", "Sheffield (Hillsborough)", "Nottingham (City Ground)"]
const TIMES := ["5 minutes", "10 minutes", "20 minutes", "40 minutes", "90 minutes"]
const CONTROLS := ["Keyboard 1 (arrows, Num0/Num.)", "Keyboard 2 (A Z , . Q /)", "Joypad 1", "Joypad 2", "Mouse"]
const SIDES := ["Not playing", "Team A (home)", "Team B (away)"]
const CAMERAS := ["Wire", "Far (auto)", "Plan", "Goal line", "Isometric", "Player", "Referee"]
const COMPETITIONS := [["Friendly", 0], ["Cup (extra time & penalties)", 2], ["Practice", 3], ["Penalty shoot-out", 5]]

var team_a: OptionButton
var team_b: OptionButton
var time_opt: OptionButton
var game_type: OptionButton
var comp_opt: OptionButton
var venue_opt: OptionButton
var cam_opt: OptionButton
var wind_opt: OptionButton
var user_side: Array = []
var toggles: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.08, 0.25)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.position = Vector2(140, 40)
	root.size = Vector2(1000, 720)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title := Label.new()
	title.text = "ACTUA SOCCER  -  EURO 96"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	root.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	root.add_child(grid)

	var names := MatchSetup.team_names()
	team_a = _opt(grid, "Home team", names, 4)
	team_b = _opt(grid, "Away team", names, 6)
	comp_opt = _opt(grid, "Match type", COMPETITIONS.map(func(c): return c[0]), 1)
	time_opt = _opt(grid, "Match length", TIMES, 0)
	game_type = _opt(grid, "Game type", ["Arcade", "Simulation"], 1)
	venue_opt = _opt(grid, "Venue", VENUES, 0)
	cam_opt = _opt(grid, "Camera", CAMERAS, 0)
	wind_opt = _opt(grid, "Wind", ["Off", "Light", "Medium", "Strong"], 0)
	for t in ["Offside", "Bookings", "Free kicks", "Substitutes"]:
		var c := CheckBox.new()
		c.text = t
		c.button_pressed = true
		toggles[t] = c
		var l := Label.new()
		l.text = "Rule"
		grid.add_child(l)
		grid.add_child(c)
	for i in range(CONTROLS.size()):
		user_side.append(_opt(grid, CONTROLS[i], SIDES, 1 if i == 0 else 0))

	var help := Label.new()
	help.text = "In match: F1-F4 options menu for user 1-4, keys 1-8 cameras, keypad 4/6/8/2/5 camera distance/height,\nF9 manual/auto player switching, Pause = pause, Esc = quit match."
	help.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	root.add_child(help)

	var go := Button.new()
	go.text = "KICK OFF"
	go.custom_minimum_size = Vector2(240, 48)
	go.pressed.connect(_start)
	root.add_child(go)
	go.grab_focus()

func _opt(parent: Control, label: String, items: Array, sel: int) -> OptionButton:
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	parent.add_child(l)
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(sel)
	o.custom_minimum_size = Vector2(380, 0)
	parent.add_child(o)
	return o

func _start() -> void:
	var users: Array = []
	var ctrl_map := [0, 1, 2, 3, 4]		# front-end control ids (convert_control: 0 key1,1 key2,2 joy1,3 joy2,4 mouse)
	for i in range(user_side.size()):
		var s: int = user_side[i].selected
		if s > 0:
			users.append({"team": s - 1, "control": ctrl_map[i]})
	var cfg := {
		"team_a": team_a.selected, "team_b": team_b.selected,
		"competition": COMPETITIONS[comp_opt.selected][1],
		"time": time_opt.selected, "game_type": game_type.selected,
		"stadium": venue_opt.selected, "camera": cam_opt.selected, "wind": wind_opt.selected,
		"offside": int(toggles["Offside"].button_pressed), "bookings": int(toggles["Bookings"].button_pressed),
		"freekicks": int(toggles["Free kicks"].button_pressed), "substitutes": int(toggles["Substitutes"].button_pressed),
		"rand": randi() & 0x7fff, "users": users,
	}
	start_requested.emit(cfg)
