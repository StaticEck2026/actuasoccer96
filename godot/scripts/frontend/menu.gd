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

var go: Button

func _ready() -> void:
	# The parent (main.gd) is a plain Node, so anchors alone don't size this
	# Control: size it to the viewport explicitly (and keep it in sync).
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func(): size = get_viewport_rect().size)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.08, 0.25)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 48
	root.offset_top = 24
	root.offset_right = -48
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	# Title + KICK OFF on the first row, so the start button is always visible.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 40)
	root.add_child(top)
	var title := Label.new()
	title.text = "ACTUA SOCCER  -  EURO 96"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	go = Button.new()
	go.text = "KICK OFF  (Enter)"
	go.add_theme_font_size_override("font_size", 24)
	go.custom_minimum_size = Vector2(280, 56)
	go.pressed.connect(_start)
	top.add_child(go)

	# Two columns: match settings | rules + controllers
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 48)
	root.add_child(cols)
	var left := _grid(cols)
	var right := _grid(cols)

	var names := MatchSetup.team_names()
	team_a = _opt(left, "Home team", names, 4)
	team_b = _opt(left, "Away team", names, 6)
	comp_opt = _opt(left, "Match type", COMPETITIONS.map(func(c): return c[0]), 1)
	time_opt = _opt(left, "Match length", TIMES, 0)
	game_type = _opt(left, "Game type", ["Arcade", "Simulation"], 1)
	venue_opt = _opt(left, "Venue", VENUES, 0)
	cam_opt = _opt(left, "Camera", CAMERAS, 0)
	wind_opt = _opt(left, "Wind", ["Off", "Light", "Medium", "Strong"], 0)
	for i in range(CONTROLS.size()):
		user_side.append(_opt(right, CONTROLS[i], SIDES, 1 if i == 0 else 0))
	var rules := Label.new()
	rules.text = "Rules"
	right.add_child(rules)
	var rbox := HFlowContainer.new()
	rbox.custom_minimum_size = Vector2(300, 0)
	right.add_child(rbox)
	for t in ["Offside", "Bookings", "Free kicks", "Substitutes"]:
		var c := CheckBox.new()
		c.text = t
		c.button_pressed = true
		toggles[t] = c
		rbox.add_child(c)

	var help := Label.new()
	help.text = "Keyboard 1: arrows move, Num0 = fire 1, Num. = fire 2.   Keyboard 2: A Z , . move, Q = fire 1, / = fire 2.\n" + \
		"In match: F1-F4 options menu (replay, subs, formation) for user 1-4, keys 1-8 cameras,\n" + \
		"keypad 4/6/8/2/5 camera distance/height, F9 manual/auto player switching, Pause = pause, Esc = quit match (Y/N)."
	help.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	root.add_child(help)
	go.grab_focus()

func _grid(parent: Control) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 8)
	parent.add_child(g)
	return g

# Enter / keypad Enter / Space / joypad Start also kick off.
func _unhandled_input(event: InputEvent) -> void:
	var start := false
	if event is InputEventKey and event.pressed and not event.echo:
		start = event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	elif event is InputEventJoypadButton and event.pressed:
		start = event.button_index == JOY_BUTTON_START
	if start:
		get_viewport().set_input_as_handled()
		_start()

func _opt(parent: Control, label: String, items: Array, sel: int) -> OptionButton:
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	parent.add_child(l)
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(sel)
	o.custom_minimum_size = Vector2(250, 0)
	parent.add_child(o)
	return o

var started := false

func _start() -> void:
	if started:
		return
	started = true
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
