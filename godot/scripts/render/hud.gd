# 2D overlay of the match: the drawing device of the 3DENG.C overlay port
# (scripts/game/eng3d.gd) and its display over the Godot 3D view.
#
# The original drew menus, banners, the scanner, the clock/score line and the
# 3D_UPD2 texts into the 8-bit screen buffer (scrb) over the rendered 3D
# picture, then copied it to VGA/VESA memory. Here:
#  * scrb is emulated by two 8-bit images: `scr_idx` (palette index of the
#    pixels the overlay wrote) and `scr_st` (0 = not written: the 3D view shows
#    through, 255 = written, 1..n = n applications of the shadow filter
#    filters[0] over the 3D picture).
#  * The sprite source is the composed "extra" map pages maps[X_BM..X_BM+3]
#    (pages 6..9, 256x1024) of this match, rebuilt from godot/assets/hud/
#    (tools/extract_hud_assets.py) exactly like init3d assembles them, decoded
#    with the draw_sprite rules (0 = transparent, 1 = 'col', t = colour t-1).
#  * The palette is composed like init3d (team kit/skin/home/away, pitch, sky)
#    and filters[0] is made by makefilter(filters[0],0,0,0,.5,.5,.5).
#  * The screen (320x200 in mode 0x13, 640x400 in VESA 0x100, 640x480 in 0x101)
#    is shown in the largest 4:3 rectangle of the window (the CRT aspect),
#    decoded through the palette by a shader.
#
# Frame flow: the driver calls update_hud() every frame. A new overlay is drawn
# when the match rendered a frame (update_3d() ran: Upd3D.text_items was
# rebuilt) - render3d()'s 2D part + the 3D_UPD2 texts; while an in-game modal
# menu runs (Eng3D.modal) the frame is driven by Eng3D.modal_frame(), which
# calls render_frame() whenever the original loop rendered.
extends CanvasLayer

const HUD_DIR := "res://assets/hud/"

var ok := false
var src_raw: PackedByteArray		# pages 6..9 raw texels (256 x 1024)
var src_idx: Image				# L8: (raw-1)&255
var m_n: Image					# LA8 masks: raw>=2
var m_c: Image					#            raw==1 ('col' pixels)
var m_nc: Image					#            raw>=1
var m_s: Image					#            raw!=1 (draw_sprite_s)
var _solids := {}
var pal6 := PackedByteArray()		# composed 6-bit VGA palette (768)
var filter0 := PackedByteArray()	# filters[0]

var scr_idx: Image
var scr_st: Image
var tex_idx: ImageTexture
var tex_st: ImageTexture
var tex_pal: ImageTexture
var dirty: Array = []				# rects written this frame
var view_rect: ColorRect
var _mark: Array = ["__hud_rendered__"]

const SHADER := """
shader_type canvas_item;
uniform sampler2D idx_tex : filter_nearest;
uniform sampler2D st_tex : filter_nearest;
uniform sampler2D pal_tex : filter_nearest;
uniform vec2 scr_size = vec2(640.0, 400.0);
uniform float row0 = 1.0;
void fragment() {
	ivec2 p = ivec2(floor(UV * scr_size));
	p.y += int(row0);
	float st = texelFetch(st_tex, p, 0).r * 255.0;
	if (st > 254.5) {
		int i = int(texelFetch(idx_tex, p, 0).r * 255.0 + 0.5);
		COLOR = vec4(texelFetch(pal_tex, ivec2(i, 0), 0).rgb, 1.0);
	} else if (st > 0.5) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0 - pow(0.5, floor(st + 0.5)));
	} else {
		COLOR = vec4(0.0);
	}
}
"""

func _ready() -> void:
	layer = 10
	ok = _load_match_graphics()
	if not ok:
		return
	view_rect = ColorRect.new()
	view_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	view_rect.material = mat
	add_child(view_rect)
	Eng3D.dev = self
	_layout()

func _exit_tree() -> void:
	if Eng3D.dev == self:
		Eng3D.dev = null

#******************************************************************************
# Match graphics: pages 6..9, palette, filter (init3d / makefilter)
#******************************************************************************

func _img(name: String) -> Image:
	var im := Image.new()
	if im.load_png_from_buffer(FileAccess.get_file_as_bytes(HUD_DIR + name)) != OK:
		push_error("hud: cannot load " + HUD_DIR + name)
		return null
	if im.get_format() != Image.FORMAT_L8:
		im.convert(Image.FORMAT_L8)
	return im

func _load_match_graphics() -> bool:
	if not Eng3D.load_data():
		return false
	var d: Dictionary = Eng3D.hud_data
	var setup = Glob.setup
	var pages := _img("xpages_base.png")
	var stad := _img("stadium_%d.png" % setup.stadium)
	var ta := _img("team_%02d.png" % setup.team_a)
	var tb := _img("team_%02d.png" % setup.team_b_kit)
	if pages == null or stad == null or ta == null or tb == null:
		return false
	# readfile(stadlist[setup.stadium].pitchfile / sb1file / sb2file ...)
	for p in d.stadium_pieces:
		pages.blit_rect(stad, Rect2i(p[5], p[6], p[3], p[4]), Vector2i(p[1], (int(p[0]) - Eng3D.X_BM) * 256 + int(p[2])))
	# team A: numbers / kit grids of teamlist[setup.team_a]; team B: of teamlist[setup.team_b_kit]
	for p in d.team_pieces.A:
		pages.blit_rect(ta, Rect2i(p[5], p[6], p[3], p[4]), Vector2i(p[1], (int(p[0]) - Eng3D.X_BM) * 256 + int(p[2])))
	for p in d.team_pieces.B:
		pages.blit_rect(tb, Rect2i(p[5], p[6], p[3], p[4]), Vector2i(p[1], (int(p[0]) - Eng3D.X_BM) * 256 + int(p[2])))
	src_raw = pages.get_data()
	_build_sources()

	# Palette (init3d): pal=PAL_FOOTY, kits, skins, pitch, home/away, sky
	var pl: Dictionary = d.palette
	pal6 = Eng3D._bytes_of(pl.base)
	_put_pal(32, pl.teams[setup.team_a].kit)
	_put_pal(56, pl.teams[setup.team_b_kit].kit)
	_put_pal(80, pl.teams[setup.team_a].skin)
	_put_pal(88, pl.teams[setup.team_b].skin)
	_put_pal(128, pl.stadiums[setup.stadium].pitch)
	_put_pal(224, pl.teams[setup.team_a].home)
	_put_pal(232, pl.teams[setup.team_b].away)
	# skyno=stadlist[setup.stadium].skytypes[(count&1)?1:0];
	var skyno: int = pl.stadiums[setup.stadium].skytypes[1 if (Glob.count & 1) else 0]
	_put_pal(208, pl.skies[skyno])
	_makefilter()
	var prgb := PackedByteArray()
	prgb.resize(768)
	for i in range(768):
		prgb[i] = (pal6[i] * 255 + 31) / 63
	tex_pal = ImageTexture.create_from_image(Image.create_from_data(256, 1, false, Image.FORMAT_RGB8, prgb))
	return true

func _put_pal(slot: int, vga: Array) -> void:
	for i in range(vga.size()):
		if slot * 3 + i < 768:
			pal6[slot * 3 + i] = int(vga[i])

# void makefilter(filter filt,byte fr,byte fg,byte fb,float mr,float mg,float mb)
#   makefilter(filters[0],0,0,0,0.5,0.5,0.5)  (as compiled: nearest of colours 0..239)
func _makefilter() -> void:
	filter0.resize(256)
	for x in range(256):
		var r1: int = int((0 - pal6[x * 3]) * 0.5 + pal6[x * 3])
		var g1: int = int((0 - pal6[x * 3 + 1]) * 0.5 + pal6[x * 3 + 1])
		var b1: int = int((0 - pal6[x * 3 + 2]) * 0.5 + pal6[x * 3 + 2])
		var d1: int = 128
		var c: int = 0
		for s in range(240):
			var r2: int = pal6[s * 3] - r1
			var g2: int = pal6[s * 3 + 1] - g1
			var b2: int = pal6[s * 3 + 2] - b1
			var d2: int = int(sqrt(r2 * r2 + g2 * g2 + b2 * b2))
			if d2 < d1:
				d1 = d2
				c = s
		filter0[x] = c

func _build_sources() -> void:
	var n: int = src_raw.size()
	var idx := PackedByteArray()
	idx.resize(n)
	var a_n := PackedByteArray()
	a_n.resize(n * 2)
	var a_c := PackedByteArray()
	a_c.resize(n * 2)
	var a_nc := PackedByteArray()
	a_nc.resize(n * 2)
	var a_s := PackedByteArray()
	a_s.resize(n * 2)
	for i in range(n):
		var v: int = src_raw[i]
		idx[i] = (v - 1) & 255
		if v >= 2:
			a_n[i * 2 + 1] = 255
		if v == 1:
			a_c[i * 2 + 1] = 255
		else:
			a_s[i * 2 + 1] = 255
		if v >= 1:
			a_nc[i * 2 + 1] = 255
	var h: int = n / 256
	src_idx = Image.create_from_data(256, h, false, Image.FORMAT_L8, idx)
	m_n = Image.create_from_data(256, h, false, Image.FORMAT_LA8, a_n)
	m_c = Image.create_from_data(256, h, false, Image.FORMAT_LA8, a_c)
	m_nc = Image.create_from_data(256, h, false, Image.FORMAT_LA8, a_nc)
	m_s = Image.create_from_data(256, h, false, Image.FORMAT_LA8, a_s)

func _solid(v: int, w: int, h: int) -> Image:
	var k := "%d:%d:%d" % [v, w, h]
	if _solids.has(k):
		return _solids[k]
	var b := PackedByteArray()
	b.resize(w * h)
	b.fill(v)
	var im := Image.create_from_data(w, h, false, Image.FORMAT_L8, b)
	if _solids.size() > 256:
		_solids.clear()
	_solids[k] = im
	return im

#******************************************************************************
# Device primitives used by Eng3D
#******************************************************************************

# Sprite copy from maps[X_BM+page] (sx, sy = column, row in pages 6..9) of a
# wid x hgt sprite, clipped to w x h, to screen position (dx, dy).
func spr(mode: int, sx: int, sy: int, wid: int, hgt: int, w: int, h: int, dx: int, dy: int, col: int) -> void:
	var src_h: int = src_idx.get_height()
	var dst := Vector2i(dx, dy)
	match mode:
		Eng3D.SPR_N:
			var r := Rect2i(sx, sy, w, h).intersection(Rect2i(0, 0, 256, src_h))
			if r.size.x <= 0 or r.size.y <= 0:
				return
			dst += r.position - Vector2i(sx, sy)
			scr_idx.blit_rect_mask(src_idx, m_n, r, dst)
			scr_idx.blit_rect_mask(_solid(col, 256, src_h), m_c, r, dst)
			scr_st.blit_rect_mask(_solid(255, 256, src_h), m_nc, r, dst)
			dirty.append(Rect2i(dst, r.size))
		Eng3D.SPR_S:
			var r := Rect2i(sx, sy, w, h).intersection(Rect2i(0, 0, 256, src_h))
			if r.size.x <= 0 or r.size.y <= 0:
				return
			dst += r.position - Vector2i(sx, sy)
			scr_idx.blit_rect_mask(src_idx, m_s, r, dst)
			scr_st.blit_rect_mask(_solid(255, 256, src_h), m_s, r, dst)
			dirty.append(Rect2i(dst, r.size))
		Eng3D.SPR_HF, Eng3D.SPR_VF, Eng3D.SPR_VHF:
			# The flipped copies read the sprite from its far edge: the w x h
			# block drawn is the top-left corner of the flipped sprite.
			var full := Rect2i(sx, sy, wid, hgt).intersection(Rect2i(0, 0, 256, src_h))
			if full.size.x <= 0 or full.size.y <= 0:
				return
			var ci := src_idx.get_region(full)
			var cn := m_n.get_region(full)
			var cc := m_c.get_region(full)
			var cnc := m_nc.get_region(full)
			for im in [ci, cn, cc, cnc]:
				if mode != Eng3D.SPR_VF:
					im.flip_x()
				if mode != Eng3D.SPR_HF:
					im.flip_y()
			var r := Rect2i(0, 0, mini(w, full.size.x), mini(h, full.size.y))
			scr_idx.blit_rect_mask(ci, cn, r, dst)
			scr_idx.blit_rect_mask(_solid(col, full.size.x, full.size.y), cc, r, dst)
			scr_st.blit_rect_mask(_solid(255, full.size.x, full.size.y), cnc, r, dst)
			dirty.append(Rect2i(dst, r.size))
		Eng3D.SPR_D:
			_spr_double(sx, sy, w, h, dx, dy, col)

# draw_sprite_d(): every texel twice across and down. The second pixel of each
# pair is decoded from the already decremented value (as the C does).
func _spr_double(sx: int, sy: int, w: int, h: int, dx: int, dy: int, col: int) -> void:
	var src_h: int = src_idx.get_height()
	if w <= 0 or h <= 0:
		return
	var ow: int = w * 2
	var oh: int = h * 2
	var bi := PackedByteArray()
	bi.resize(ow * oh)
	var bm := PackedByteArray()
	bm.resize(ow * oh * 2)
	for i in range(h):
		for rep in range(2):
			var o: int = (i * 2 + rep) * ow
			for j in range(w):
				var x: int = sx + j
				var y: int = sy + i
				var c: int = 0
				if x < 256 and y < src_h:
					c = src_raw[y * 256 + x]
				if c:
					c -= 1
					bi[o + j * 2] = col if c == 0 else c
					bm[(o + j * 2) * 2 + 1] = 255
				if c:
					c -= 1
					bi[o + j * 2 + 1] = col if c == 0 else c
					bm[(o + j * 2 + 1) * 2 + 1] = 255
	var ii := Image.create_from_data(ow, oh, false, Image.FORMAT_L8, bi)
	var mm := Image.create_from_data(ow, oh, false, Image.FORMAT_LA8, bm)
	var r := Rect2i(0, 0, ow, oh)
	var dst := Vector2i(dx, dy)
	scr_idx.blit_rect_mask(ii, mm, r, dst)
	scr_st.blit_rect_mask(_solid(255, ow, oh), mm, r, dst)
	dirty.append(Rect2i(dst, r.size))

# *sc=filters[0][*sc] over a w x h block at screen (dx, dy).
func shadow(dx: int, dy: int, w: int, h: int) -> void:
	var R := Rect2i(dx, dy, w, h).intersection(Rect2i(Vector2i.ZERO, scr_st.get_size()))
	if R.size.x <= 0 or R.size.y <= 0:
		return
	var inter := Rect2i()
	var have := false
	for d in dirty:
		if d.intersects(R):
			var x: Rect2i = d.intersection(R)
			inter = x if not have else inter.merge(x)
			have = true
	var ci: Image = null
	var cs: Image = null
	if have:
		ci = scr_idx.get_region(inter)
		cs = scr_st.get_region(inter)
	scr_st.fill_rect(R, Color(1.4 / 255.0, 1.4 / 255.0, 1.4 / 255.0))
	if have:
		var bi: PackedByteArray = ci.get_data()
		var bs: PackedByteArray = cs.get_data()
		for k in range(bs.size()):
			var s: int = bs[k]
			if s == 255:
				bi[k] = filter0[bi[k]]
			elif s < 254:
				bs[k] = s + 1
		scr_idx.blit_rect(Image.create_from_data(inter.size.x, inter.size.y, false, Image.FORMAT_L8, bi), Rect2i(Vector2i.ZERO, inter.size), inter.position)
		scr_st.blit_rect(Image.create_from_data(inter.size.x, inter.size.y, false, Image.FORMAT_L8, bs), Rect2i(Vector2i.ZERO, inter.size), inter.position)
	dirty.append(R)

# Screen area outside the render buffer (setup.screen_size > 0): colour `col`.
func border(buffer, col: int) -> void:
	var sw: int = Eng3D.scr_wid()
	var vis := Rect2i(0, 1, sw, _vis_hgt())
	var x0: int = posmod(buffer.buff_start, sw)
	var y0: int = (buffer.buff_start - x0) / sw
	var inner := Rect2i(x0, y0, buffer.clip_wid, buffer.clip_hgt)
	var parts := [Rect2i(0, vis.position.y, sw, inner.position.y - vis.position.y),
		Rect2i(0, inner.end.y, sw, vis.end.y - inner.end.y),
		Rect2i(0, inner.position.y, inner.position.x, inner.size.y),
		Rect2i(inner.end.x, inner.position.y, sw - inner.end.x, inner.size.y)]
	for p in parts:
		if p.size.x > 0 and p.size.y > 0:
			scr_idx.blit_rect(_solid(col, p.size.x, p.size.y), Rect2i(Vector2i.ZERO, p.size), p.position)
			scr_st.blit_rect(_solid(255, p.size.x, p.size.y), Rect2i(Vector2i.ZERO, p.size), p.position)
			dirty.append(p)

#******************************************************************************
# Frames
#******************************************************************************

func _vis_hgt() -> int:
	match Eng3D.scrmode:
		0x13:
			return 200
		0x101:
			return 480
	return 400

func _begin() -> void:
	var sw: int = Eng3D.scr_wid()
	var sh: int = Eng3D.SCRB_SIZE / sw
	if scr_idx == null or scr_idx.get_width() != sw:
		scr_idx = Image.create(sw, sh, false, Image.FORMAT_L8)
		scr_st = Image.create(sw, sh, false, Image.FORMAT_L8)
		tex_idx = null
		tex_st = null
	else:
		scr_idx.fill(Color(0, 0, 0))
		scr_st.fill(Color(0, 0, 0))
	dirty.clear()

func _end() -> void:
	if tex_idx == null:
		tex_idx = ImageTexture.create_from_image(scr_idx)
		tex_st = ImageTexture.create_from_image(scr_st)
	else:
		tex_idx.update(scr_idx)
		tex_st.update(scr_st)
	var mat: ShaderMaterial = view_rect.material
	mat.set_shader_parameter("idx_tex", tex_idx)
	mat.set_shader_parameter("st_tex", tex_st)
	mat.set_shader_parameter("pal_tex", tex_pal)
	mat.set_shader_parameter("scr_size", Vector2(Eng3D.scr_wid(), _vis_hgt()))
	mat.set_shader_parameter("row0", 1.0)

func _layout() -> void:
	if view_rect == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = vp.x
	var h: float = w * 3.0 / 4.0
	if h > vp.y:
		h = vp.y
		w = h * 4.0 / 3.0
	view_rect.position = ((vp - Vector2(w, h)) / 2.0).floor()
	view_rect.size = Vector2(w, h).floor()

func _update_view() -> void:
	var p := get_parent()
	if p == null:
		return
	var v = p.get("view")
	if v != null and v.has_method("update_view"):
		v.update_view()

# One render3d() (2D part) + main_buff.dump(): with_text adds the 3D_UPD2
# draw_string()s of update_3d(); update_view also redraws the 3D view.
func render_frame(with_text: bool, update_view: bool) -> void:
	if not ok:
		return
	Eng3D.render3d_keys()
	if update_view:
		_update_view()
	_begin()
	Eng3D.render3d_2d()
	if with_text:
		Eng3D.draw_text_items(Upd3D.text_items)
	_end()

func update_hud() -> void:
	if not ok:
		return
	_layout()
	if Eng3D.modal:
		Eng3D.modal_frame()
		return
	var items: Array = Upd3D.text_items
	if not items.is_empty() and is_same(items.back(), _mark):
		return		# no render3d() since the last frame (paused, quit prompt): keep the picture
	render_frame(true, false)
	Upd3D.text_items.append(_mark)
