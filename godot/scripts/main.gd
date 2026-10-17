# Godot driver for the ported match engine.
#
# Replaces the DOS runtime around match():
#  * the 200Hz timer interrupt (NETWORK.C nethandler)      -> _process() time accumulator
#  * the keyboard interrupt (KEYH.CPP key_handler)         -> _input() -> PC set-1 scan codes
#  * the analogue joystick port 0x201 (NETWORK.C ReadJoys)  -> Godot joypads
#  * render3d()/dump()                                      -> MatchView (3D) + Hud (2D)
extends Node

const MatchViewScript = preload("res://scripts/render/match_view.gd")
const HudScript = preload("res://scripts/render/hud.gd")
const MenuScript = preload("res://scripts/frontend/menu.gd")

var view: Node3D = null
var hud: CanvasLayer = null
var menu: Control = null
var running := false
var timer_acc := 0.0

# Godot keycode -> [scan code, extended(0xE0) prefix]
const SCANCODES := {
	KEY_ESCAPE: [0x01, false], KEY_1: [0x02, false], KEY_2: [0x03, false], KEY_3: [0x04, false],
	KEY_4: [0x05, false], KEY_5: [0x06, false], KEY_6: [0x07, false], KEY_7: [0x08, false],
	KEY_8: [0x09, false], KEY_9: [0x0a, false], KEY_0: [0x0b, false], KEY_MINUS: [0x0c, false],
	KEY_EQUAL: [0x0d, false], KEY_BACKSPACE: [0x0e, false], KEY_TAB: [0x0f, false],
	KEY_Q: [0x10, false], KEY_W: [0x11, false], KEY_E: [0x12, false], KEY_R: [0x13, false],
	KEY_T: [0x14, false], KEY_Y: [0x15, false], KEY_U: [0x16, false], KEY_I: [0x17, false],
	KEY_O: [0x18, false], KEY_P: [0x19, false], KEY_BRACKETLEFT: [0x1a, false], KEY_BRACKETRIGHT: [0x1b, false],
	KEY_ENTER: [0x1c, false], KEY_CTRL: [0x1d, false], KEY_A: [0x1e, false], KEY_S: [0x1f, false],
	KEY_D: [0x20, false], KEY_F: [0x21, false], KEY_G: [0x22, false], KEY_H: [0x23, false],
	KEY_J: [0x24, false], KEY_K: [0x25, false], KEY_L: [0x26, false], KEY_SEMICOLON: [0x27, false],
	KEY_APOSTROPHE: [0x28, false], KEY_QUOTELEFT: [0x29, false], KEY_SHIFT: [0x2a, false],
	KEY_BACKSLASH: [0x2b, false], KEY_Z: [0x2c, false], KEY_X: [0x2d, false], KEY_C: [0x2e, false],
	KEY_V: [0x2f, false], KEY_B: [0x30, false], KEY_N: [0x31, false], KEY_M: [0x32, false],
	KEY_COMMA: [0x33, false], KEY_PERIOD: [0x34, false], KEY_SLASH: [0x35, false],
	KEY_KP_MULTIPLY: [0x37, false], KEY_ALT: [0x38, false], KEY_SPACE: [0x39, false],
	KEY_CAPSLOCK: [0x3a, false], KEY_F1: [0x3b, false], KEY_F2: [0x3c, false], KEY_F3: [0x3d, false],
	KEY_F4: [0x3e, false], KEY_F5: [0x3f, false], KEY_F6: [0x40, false], KEY_F7: [0x41, false],
	KEY_F8: [0x42, false], KEY_F9: [0x43, false], KEY_F10: [0x44, false], KEY_NUMLOCK: [0x45, false],
	KEY_SCROLLLOCK: [0x46, false], KEY_KP_7: [0x47, false], KEY_KP_8: [0x48, false], KEY_KP_9: [0x49, false],
	KEY_KP_SUBTRACT: [0x4a, false], KEY_KP_4: [0x4b, false], KEY_KP_5: [0x4c, false], KEY_KP_6: [0x4d, false],
	KEY_KP_ADD: [0x4e, false], KEY_KP_1: [0x4f, false], KEY_KP_2: [0x50, false], KEY_KP_3: [0x51, false],
	KEY_KP_0: [0x52, false], KEY_KP_PERIOD: [0x53, false], KEY_F11: [0x57, false], KEY_F12: [0x58, false],
	KEY_KP_ENTER: [0x1c, true], KEY_KP_DIVIDE: [0x35, true],
	KEY_HOME: [0x47, true], KEY_UP: [0x48, true], KEY_PAGEUP: [0x49, true], KEY_LEFT: [0x4b, true],
	KEY_RIGHT: [0x4d, true], KEY_END: [0x4f, true], KEY_DOWN: [0x50, true], KEY_PAGEDOWN: [0x51, true],
	KEY_INSERT: [0x52, true], KEY_DELETE: [0x53, true],
}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--quick"):
		start_match({"team_a": 4, "team_b": 6, "time": 0, "users": [{"team": 0, "control": 0}]})
	else:
		show_menu()

func show_menu() -> void:
	running = false
	if view:
		view.queue_free()
		view = null
	if hud:
		hud.queue_free()
		hud = null
	menu = MenuScript.new()
	menu.start_requested.connect(start_match)
	add_child(menu)

func start_match(cfg: Dictionary) -> void:
	if menu:
		menu.queue_free()
		menu = null
	MatchSetup.prepare(cfg)
	_init_joysticks()
	var err := Football.match_start()
	if err:
		push_error("match_start failed: %d" % err)
		show_menu()
		return
	view = MatchViewScript.new()
	add_child(view)
	view.build_match()
	hud = HudScript.new()
	add_child(hud)
	timer_acc = 0.0
	running = true

func _init_joysticks() -> void:
	# Joystick "calibration": the DOS game measured centre/min/max counts of the
	# analogue port. Godot axes (-1..1) are presented as counts 0..1000.
	NetInput.set_joy_calibration(0, 500, 500, 0, 1000, 0, 1000)
	NetInput.set_joy_calibration(1, 500, 500, 0, 1000, 0, 1000)
	var pads := Input.get_connected_joypads()
	Glob.joystick1_on = 1 if pads.size() > 0 else 0
	Glob.joystick2_on = 1 if pads.size() > 1 else 0

func _read_joypads() -> void:
	var pads := Input.get_connected_joypads()
	var j := NetInput.hw_joy
	if pads.size() > 0:
		var d: int = pads[0]
		j.JoyAX = int(500 + 500 * _axis(d, JOY_AXIS_LEFT_X, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT))
		j.JoyAY = int(500 + 500 * _axis(d, JOY_AXIS_LEFT_Y, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN))
		j.FireA1 = 1 if Input.is_joy_button_pressed(d, JOY_BUTTON_A) else 0
		j.FireA2 = 1 if Input.is_joy_button_pressed(d, JOY_BUTTON_B) or Input.is_joy_button_pressed(d, JOY_BUTTON_X) else 0
	if pads.size() > 1:
		var d: int = pads[1]
		j.JoyBX = int(500 + 500 * _axis(d, JOY_AXIS_LEFT_X, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT))
		j.JoyBY = int(500 + 500 * _axis(d, JOY_AXIS_LEFT_Y, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN))
		j.FireB1 = 1 if Input.is_joy_button_pressed(d, JOY_BUTTON_A) else 0
		j.FireB2 = 1 if Input.is_joy_button_pressed(d, JOY_BUTTON_B) or Input.is_joy_button_pressed(d, JOY_BUTTON_X) else 0

func _axis(dev: int, axis: int, neg_btn: int, pos_btn: int) -> float:
	var v := Input.get_joy_axis(dev, axis)
	if Input.is_joy_button_pressed(dev, neg_btn):
		v = -1.0
	if Input.is_joy_button_pressed(dev, pos_btn):
		v = 1.0
	return clampf(v, -1.0, 1.0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var e: InputEventKey = event
		if e.keycode == KEY_PAUSE:
			if e.pressed:
				# Pause key: E1 1D 45 E1 9D C5
				for sc in [0xE1, 0x1d, 0x45, 0xE1, 0x9d, 0xc5]:
					NetInput.key_handler(sc)
			return
		var k = SCANCODES.get(e.keycode)
		if k == null:
			k = SCANCODES.get(e.physical_keycode)
		if k == null:
			return
		if k[1]:
			NetInput.key_handler(0xE0)
		NetInput.key_handler(k[0] | (0 if e.pressed else 0x80))
	elif event is InputEventMouseMotion and running:
		NetInput.mouse_x_pos += int(event.relative.x)
		NetInput.mouse_y_pos += int(event.relative.y)
		Glob.mouse_x = clampi(Glob.mouse_x + int(event.relative.x), 0, 319)
		Glob.mouse_y = clampi(Glob.mouse_y + int(event.relative.y), 0, 199)
	elif event is InputEventMouseButton and running:
		var bit := 1 if event.button_index == MOUSE_BUTTON_LEFT else (2 if event.button_index == MOUSE_BUTTON_RIGHT else 0)
		if event.pressed:
			NetInput.mouse_b |= bit
		else:
			NetInput.mouse_b &= ~bit

func _process(delta: float) -> void:
	if not running:
		return
	_read_joypads()
	# The DOS timer interrupt ran at TIMER_SPEED (200) Hz.
	timer_acc += delta * Glob.TIMER_SPEED
	var n := int(timer_acc)
	timer_acc -= n
	if Glob.paused or Eng3D.modal:
		# (game frozen: the original sat in a loop; the timer kept counting)
		Glob.count += n
	else:
		for i in n:
			NetInput.nethandler()
	if Eng3D.modal:
		hud.update_hud()
		return
	if not Football.match_frame():
		running = false
		Football.match_end()
		show_menu()
		return
	view.update_view()
	hud.update_hud()
