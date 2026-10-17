# Runtime loader for the extracted match render data (res://assets, produced by
# tools/extract_assets.py, documented in docs/ASSETS.md).  Replaces the data
# loading part of 3DENG.C init3d(): palette composition, the 16 texture-map
# pages (as one 1024x1024 8-bit index atlas, 4x4 pages of 256x256), the texture
# table, models and the motion-capture tables (mcaps / player_p).
#
# Everything is read with FileAccess / Image.load_from_file (no import step).
class_name R3DAssets extends RefCounted

const ROOT := "res://assets/"

# remapgfx(+1) pages (decode rule, see ASSETS.md 5.3)
const REMAPPED_PAGES := [0, 1, 2, 3, 4, 5, 10, 11, 12, 13, 14, 15]
const X_TM := 533

static var _json_cache: Dictionary = {}

# Texture table: index -> page, u[4], v[4], u3[3], v3[3]  (texel units)
static var tex_page := PackedInt32Array()
static var tex_uv4 := PackedFloat32Array()    # 8 floats per texture: u0,v0,u1,v1,u2,v2,u3,v3
static var tex_uv3 := PackedFloat32Array()    # 6 floats per texture

# Motion capture
static var mocap := PackedFloat32Array()      # all frames, 85 floats each
static var cap_start := PackedInt32Array()    # cappts per MC id (engine accumulation)
static var cap_frames := PackedInt32Array()   # capfrms per MC id (0 for mirrored slots)
static var mocap_loaded := false

static func json(path: String):
	if _json_cache.has(path):
		return _json_cache[path]
	var f := FileAccess.open(ROOT + path, FileAccess.READ)
	if f == null:
		push_error("R3DAssets: cannot open " + ROOT + path)
		return null
	var d = JSON.parse_string(f.get_as_text())
	_json_cache[path] = d
	return d

static func image(path: String) -> Image:
	var img := Image.load_from_file(ROOT + path)
	if img == null:
		push_error("R3DAssets: cannot load image " + ROOT + path)
	return img

# ---------------------------------------------------------------------------
# Motion capture (3DENG.C init3d: mcaps[i].cappts = running total; player_p)
# ---------------------------------------------------------------------------
static func load_mocap() -> void:
	if mocap_loaded:
		return
	var f := FileAccess.open(ROOT + "mocap/mocap.bin", FileAccess.READ)
	mocap = f.get_buffer(f.get_length()).to_float32_array()
	var mj = json("mocap/mocap.json")
	var caps: Array = mj.captures
	cap_start.resize(132)
	cap_frames.resize(132)
	var tot := 0
	for i in range(132):
		var c = caps[i]
		cap_start[i] = tot
		cap_frames[i] = int(c.stored_frames)
		tot += int(c.stored_frames)
	mocap_loaded = true

# Fill the engine tables the ported game logic reads (BALLINT.CPP
# get_mcball_coords): Glob.mcaps[] (mcap) and Glob.player_p[] (capfrm).
static func install_mocap_tables() -> void:
	load_mocap()
	if not Glob.player_p.is_empty():
		return
	var mc: Array = []
	for i in range(132):
		var m := Glob.mcap.new()
		m.cappts = cap_start[i]
		m.capfrms = cap_frames[i]
		mc.append(m)
	Glob.mcaps = mc
	var n := mocap.size() / 85
	var pp: Array = []
	pp.resize(n)
	for k in range(n):
		pp[k] = mocap.slice(k * 85, k * 85 + 85)
	Glob.player_p = pp

# ---------------------------------------------------------------------------
# Texture table
# ---------------------------------------------------------------------------
static func load_texture_table() -> void:
	if tex_page.size() > 0:
		return
	var tj = json("textures/textures.json")
	var n := 1060
	tex_page.resize(n)
	tex_uv4.resize(n * 8)
	tex_uv3.resize(n * 6)
	tex_page.fill(0)
	for src in [tj.texdata, tj.stadium]:     # stadium TMD overrides 1004..1006
		for k in src.keys():
			var i := int(k)
			if i >= n:
				continue
			var t = src[k]
			tex_page[i] = int(t.page)
			for j in range(4):
				tex_uv4[i * 8 + j * 2] = float(t.u[j])
				tex_uv4[i * 8 + j * 2 + 1] = float(t.v[j])
			for j in range(3):
				tex_uv3[i * 6 + j * 2] = float(t.u3[j])
				tex_uv3[i * 6 + j * 2 + 1] = float(t.v3[j])

# ---------------------------------------------------------------------------
# Palette (init3d composition, 6-bit VGA -> 8 bit)
# ---------------------------------------------------------------------------
static func _vga8(v: int) -> int:
	return (v * 255 + 31) / 63

static func match_palette(team_a: int, team_b: int, team_b_kit: int, stadium: int, sky: int) -> PackedByteArray:
	var pj = json("palettes.json")
	var by_entry := {}
	for k in pj.subpalettes.keys():
		var s = pj.subpalettes[k]
		by_entry[int(s.entry)] = s.vga
	var vga: Array = []
	for c in pj.base.vga:
		vga.append([int(c[0]), int(c[1]), int(c[2])])
	var teams: Array = json("teams.json").teams
	var stads: Array = json("stadiums.json").stadiums
	var skies: Array = json("skies.json").skies
	var put := func(slot: int, entry: int) -> void:
		var cols: Array = by_entry[entry]
		for i in range(cols.size()):
			vga[slot + i] = [int(cols[i][0]), int(cols[i][1]), int(cols[i][2])]
	put.call(32, int(teams[team_a].kit_palette_entry))
	put.call(56, int(teams[team_b_kit].kit_palette_entry))
	put.call(80, int(teams[team_a].skin_palette_entry))
	put.call(88, int(teams[team_b].skin_palette_entry))
	put.call(128, int(stads[stadium].pitch_palette_entry))
	put.call(224, int(teams[team_a].home_palette_entry))
	put.call(232, int(teams[team_b].away_palette_entry))
	put.call(208, int(skies[sky].palette_entry))
	var out := PackedByteArray()
	out.resize(256 * 4)
	for i in range(256):
		out[i * 4] = _vga8(vga[i][0])
		out[i * 4 + 1] = _vga8(vga[i][1])
		out[i * 4 + 2] = _vga8(vga[i][2])
		out[i * 4 + 3] = 255
	return out

static func palette_texture(pal: PackedByteArray) -> ImageTexture:
	var img := Image.create_from_data(256, 1, false, Image.FORMAT_RGBA8, pal)
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------------------
# Map pages -> 1024x1024 L8 atlas  (textures/pages.json recipe == init3d)
# ---------------------------------------------------------------------------
static func team_dir(t: int) -> String:
	return json("teams.json").teams[t].components.dir.trim_prefix("teams/").trim_suffix("/")

static func build_page_atlas(team_a: int, team_b: int, stadium: int) -> Image:
	var pj = json("textures/pages.json")
	var stads: Array = json("stadiums.json").stadiums
	var pitch_name: String = stads[stadium].pitch_name
	var atlas := Image.create(1024, 1024, false, Image.FORMAT_L8)
	var cache := {}
	for op in pj.ops:
		var src: String = op.src
		src = src.replace("{A}", team_dir(team_a)).replace("{B}", team_dir(team_b)).replace("{PITCH}", pitch_name)
		var img: Image = cache.get(src)
		if img == null:
			img = image("textures/" + src)
			if img.get_format() != Image.FORMAT_L8:
				img.convert(Image.FORMAT_L8)
			cache[src] = img
		var rect := Rect2i(0, 0, img.get_width(), img.get_height())
		if op.has("src_rect"):
			rect = Rect2i(int(op.src_rect[0]), int(op.src_rect[1]), int(op.src_rect[2]), int(op.src_rect[3]))
		var dx := int(op.dst[0])
		var dy := int(op.dst[1])
		rect.size.x = mini(rect.size.x, 256 - dx)
		rect.size.y = mini(rect.size.y, 256 - dy)
		var p := int(op.page)
		atlas.blit_rect(img, rect, Vector2i((p % 4) * 256 + dx, (p / 4) * 256 + dy))
	return atlas

static func sky_texture(sky: int) -> ImageTexture:
	var skies: Array = json("skies.json").skies
	var img := image("textures/" + String(skies[sky].file))
	img.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(img)
