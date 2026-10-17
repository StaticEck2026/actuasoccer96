# 3D view of the match: the Godot replacement of 3DENG.C render3d().
#
# The original is a software painter's-algorithm renderer.  This port keeps its
# semantics:
#  * the camera is the exact 3DENG.C view (R3DCam), q = (short)vdist in the
#    640x400 hi-res mode, mapped onto the whole viewport (2 window pixels per
#    engine pixel at 1280x800);
#  * everything is drawn without depth test, in the original order:
#      ground+sky (ground())  -> far stands (list order, facing tests vs1..vs4)
#      -> pitch markings, shadows (unsorted) -> highlights
#      -> players, ball, goals, flags sorted per object (object depth) and per
#         polygon (average depth) like qsort(objcmp)/sortobj(polcmp);
#  * players are rebuilt every frame from the motion capture with the engine's
#    screen-space impostors (add3dcmap / add3demap), frame selection, mirroring
#    (addobjyf) and anim tweening (plyrtwtb);
#  * colours go through the 8-bit match palette (palette lookup shader).
# See docs/ASSETS.md for the data formats and the original algorithms.
extends Node3D

const LAYER_COMMON := 1
const LAYER_MAIN := 2
const LAYER_VIDI := 4

# draw stages (render_priority)
const PRI_GROUND := -120
const PRI_STANDS := -110     # +0..3 in stand draw order
const PRI_LINES := -100
const PRI_PSHADOW := -90
const PRI_BSHADOW := -89
const PRI_HILITE := -80
const PRI_OBJECTS := 0

const MC_STAND := 78
const PLYRPTS := 28
const X_TM := 533

var ecam := R3DCam.new()
var vcam := R3DCam.new()
var cam: Camera3D
var vidi_vp: SubViewport
var vidi_cam: Camera3D
var vidi_enabled := true
var render_scale := 1          # 1 = the original pixel grid; 2.. = supersampled
var main_vp: SubViewport
var screen_layer: CanvasLayer
var screen_rect: TextureRect
var debug_hide_stands := false

var atlas_tex: ImageTexture
var pal_tex: ImageTexture
var sky_tex: ImageTexture
var sh_world: Shader
var sh_free: Shader
var sh_world_vidi: Shader
var mat_cache := {}
var linear_out := false

var stad: Dictionary
var st_w := 190.0
var st_l := 190.0
var st_h := 290.0
var skyno := 0

# models
var player_lists := {}         # name -> Array of face dicts (compact)
var playertypes: Array = []
var hl_tab: Array = []         # [htype][hcol] -> faces
var hl_pts: Dictionary = {}
var ball_lod: Array = []
var goal_lods := {}
var goal_objs: Array = []      # [name, engine pos, lod name]
var flag_model: Dictionary
var flag_pos: Array = []

# scene nodes
var ground_mi: MeshInstance3D
var ground_vidi_mi: MeshInstance3D
var pitch_simple_mi: MeshInstance3D
var stand_main: Array = []
var stand_vidi: Array = []
var line_objs: Array = []      # [MeshInstance3D, lod meshes(Array), engine pos, zscales, needs_lines_detail]
var shadow_mis: Array = []
var ball_shadow_mi: MeshInstance3D
var hl_mis: Array = []
var hl_meshes: Array = []      # [htype][hcol] -> ArrayMesh
var player_mis_main: Array = []
var player_mis_vidi: Array = []
var ball_mi: MeshInstance3D
var goal_mis: Array = []
var flag_mis: Array = []

# per-frame player state (render3d plyrtwtb + points)
class Tw:
	var twnfrm := PackedFloat32Array()
	var twnpts1 := PackedFloat32Array()
	var twnpts2 := PackedFloat32Array()
	var tween: float = -1.0
	var tstep: float = 0.0
	var anim: int = MC_STAND
	var animto: int = 0
var plyrtwtb: Array = []
var frame_pts: Array = []      # per player: PackedFloat32Array(85) of the drawn frame
var frame_xf: Array = []
var frame_faces: Array = []

# statics of render3d
var balld := 0
var hcoo := 0.0
var fcoo := 0.0
var mcap_ball := Vector3.ZERO
var flag_tex := X_TM + 46     # current cloth texture (faces 5,6)


# ===========================================================================
# build
# ===========================================================================
func build_match() -> void:
	# The GL compatibility renderer writes ALBEDO of unshaded materials straight
	# to the sRGB framebuffer; Forward+/Mobile expect linear colours.
	linear_out = RenderingServer.get_rendering_device() != null
	R3DAssets.install_mocap_tables()
	R3DAssets.load_texture_table()
	var setup = Glob.setup
	var team_a: int = setup.team_a
	var team_b: int = setup.team_b
	var team_b_kit: int = setup.team_b      # (team_b_kit is never set by the Euro front end)
	var stadium: int = clampi(setup.stadium, 0, 7)
	stad = R3DAssets.json("stadiums.json").stadiums[stadium]
	st_w = float(stad.st_w)
	st_l = float(stad.st_l)
	st_h = float(stad.st_h)
	# skyno=stadlist[setup.stadium].skytypes[(count&1)?1:0];  (LINK build)
	skyno = int(stad.skytypes[1 if (Glob.count & 1) else 0])

	var pal := R3DAssets.match_palette(team_a, team_b, team_b_kit, stadium, skyno)
	pal_tex = R3DAssets.palette_texture(pal)
	atlas_tex = ImageTexture.create_from_image(R3DAssets.build_page_atlas(team_a, team_b, stadium))
	sky_tex = R3DAssets.sky_texture(skyno)

	sh_world = Shader.new()
	sh_world.code = R3DShaders.poly_code("cull_back", false)
	sh_free = Shader.new()
	sh_free.code = R3DShaders.poly_code("cull_disabled", false)
	sh_world_vidi = Shader.new()
	sh_world_vidi.code = R3DShaders.poly_code("cull_back", true)

	_build_cameras()
	_build_ground()
	_build_stands()
	_build_lines()
	_build_shadows_highlights()
	_load_objects()
	_build_players()

func _mat(shader: Shader, pri: int) -> ShaderMaterial:
	var key := "%d_%d" % [shader.get_instance_id(), pri]
	if mat_cache.has(key):
		return mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = shader
	m.render_priority = pri
	m.set_shader_parameter("atlas", atlas_tex)
	m.set_shader_parameter("pal", pal_tex)
	m.set_shader_parameter("linear_out", linear_out)
	mat_cache[key] = m
	return m

func _build_cameras() -> void:
	# main view: rendered at the size of the engine's clip buffer (main_buff:
	# 640x400 in VESA 0x100, 320x200 in mode 0x13, smaller with -/= screen
	# sizes) x render_scale, shown where the original screen had it inside the
	# largest 4:3 rectangle of the window (the CRT aspect), like the HUD.
	main_vp = SubViewport.new()
	main_vp.size = Vector2i(640, 400)
	main_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	main_vp.transparent_bg = false
	add_child(main_vp)
	cam = Camera3D.new()
	cam.near = 10.0
	cam.far = 20000.0
	cam.cull_mask = LAYER_COMMON | LAYER_MAIN
	main_vp.add_child(cam)
	cam.current = true
	screen_layer = CanvasLayer.new()
	screen_layer.layer = -1
	add_child(screen_layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_layer.add_child(bg)
	screen_rect = TextureRect.new()
	screen_rect.texture = main_vp.get_texture()
	screen_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen_rect.stretch_mode = TextureRect.STRETCH_SCALE
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_layer.add_child(screen_rect)
	# vidi wall: 3DENG.C vidi_buff (clip 128x80, scale 0.175/0.183) rendered into
	# the stand page 8 at (10,7)
	vidi_vp = SubViewport.new()
	vidi_vp.size = Vector2i(128, 80)
	vidi_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vidi_vp.transparent_bg = false
	add_child(vidi_vp)
	vidi_cam = Camera3D.new()
	vidi_cam.near = 10.0
	vidi_cam.far = 20000.0
	vidi_cam.cull_mask = LAYER_COMMON | LAYER_VIDI
	vidi_vp.add_child(vidi_cam)
	vidi_cam.current = true

func _new_mi(layer: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.layers = layer
	mi.sorting_use_aabb_center = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _build_ground() -> void:
	ground_mi = _ground_quad(LAYER_MAIN)
	ground_vidi_mi = _ground_quad(LAYER_VIDI)
	# detail.pitch==0: the flat pitch object (addobjfc(&pitch)) drawn before the
	# stands; init3d moves its edge points to the stadium bounds.
	var pm = R3DAssets.json("models/pitch_simple.json")
	var pts: Array = pm.points.duplicate(true)
	for i in range(19):
		pts[i][2] = st_w
		pts[i + 19][2] = -800 - st_w
	pts[0][0] = -st_l
	pts[19][0] = -st_l
	pts[18][0] = 1280 + st_l
	pts[37][0] = 1280 + st_l
	pitch_simple_mi = _new_mi(LAYER_COMMON)
	pitch_simple_mi.mesh = _model_mesh(pts, pm.faces, _mat(sh_world, PRI_GROUND + 1), true)
	pitch_simple_mi.visible = false

func _ground_quad(layer: int) -> MeshInstance3D:
	var sh := Shader.new()
	sh.code = R3DShaders.GROUND_CODE
	var m := ShaderMaterial.new()
	m.shader = sh
	m.render_priority = PRI_GROUND
	m.set_shader_parameter("atlas", atlas_tex)
	m.set_shader_parameter("pal", pal_tex)
	m.set_shader_parameter("sky_tex", sky_tex)
	m.set_shader_parameter("linear_out", linear_out)
	m.set_shader_parameter("pitch_detail", Glob.setup.detail.pitch)
	m.set_shader_parameter("sky_on", Glob.setup.M8 != 0 and Glob.setup.detail.sky != 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(2.2, 2.2)
	var mi := _new_mi(layer)
	mi.mesh = qm
	mi.material_override = m
	mi.extra_cull_margin = 16384.0
	mi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	return mi

# 3DENG.C ground(): horizon / sky placement for this camera -> shader uniforms
func _update_ground(c: R3DCam, mi: MeshInstance3D) -> void:
	var m: ShaderMaterial = mi.material_override
	var xmid := c.W >> 1
	var ymid := c.H >> 1
	var ry: Array = []
	var rz: Array = []
	# Find highest pt of pitch
	for p in [Vector3(-st_l, 0, st_w), Vector3(1280 + st_l, 0, st_w), Vector3(1280 + st_l, 0, -(800 + st_w)), Vector3(-st_l, 0, -(800 + st_w))]:
		var v := c.to_view(p)
		ry.append(v.y)
		rz.append(v.z)
	var ye: int
	var ze: float
	if rz[0] > 0:
		ye = int(c.q * ry[0] / rz[0]); ze = rz[0]
	else:
		ye = -ymid; ze = 0
	for k in range(1, 4):
		if rz[k] > ze:
			ye = int(c.q * ry[k] / rz[k]); ze = rz[k]
	if ye > ymid:
		ye = ymid
	var ye_g := ye
	if OS.get_environment("DBG_GROUND") != "":
		print("ground ry ", ry, " rz ", rz, " ye_g ", ye_g, " q ", c.q, " view ", c.view, " sph ", c.sph)
	# Find lowest pt of sky  (ST_DP 200)
	ry.clear(); rz.clear()
	for p in [Vector3(-(st_l + 200), st_h, st_w + 200), Vector3(1280 + st_l + 200, st_h, st_w + 200),
			Vector3(1280 + st_l + 200, st_h, -(800 + st_w + 200)), Vector3(-(st_l + 200), st_h, -(800 + st_w + 200))]:
		var v := c.to_view(p)
		ry.append(v.y)
		rz.append(v.z)
	if rz[0] > 0:
		ye = int(c.q * ry[0] / rz[0]); ze = rz[0]
	else:
		ye = ymid; ze = 0
	for k in range(1, 4):
		if rz[k] > ze:
			ye = int(c.q * ry[k] / rz[k]); ze = rz[k]
	if ye < -ymid:
		ye = -ymid
	# sky source offsets (M8 && detail.sky)
	var yd: int = ye + int(c.q * c.sph / c.cph)
	if yd < 0:
		yd = 0
	if 479 - yd < 240 - ye:
		yd = 240 + ye
	var sa: float = 2 * 3.1415 / 3.0
	var off: int = int(640 * acos(clampf(c.cth, -1, 1)) / sa) % 640
	var base: int
	if c.sth < 0:
		base = 640 * (480 - yd) - off
	else:
		base = 640 * (479 - yd) + off
	m.set_shader_parameter("pitch_detail", Glob.setup.detail.pitch)
	m.set_shader_parameter("sky_on", Glob.setup.M8 != 0 and Glob.setup.detail.sky != 0)
	m.set_shader_parameter("buf", Vector2(c.W, c.H))
	m.set_shader_parameter("ang", Vector4(c.cth, c.sth, c.cph, c.sph))
	m.set_shader_parameter("eye", c.view)
	m.set_shader_parameter("q", float(c.q))
	m.set_shader_parameter("ye_g", ye_g)
	m.set_shader_parameter("ye_s", ye)
	m.set_shader_parameter("sky_base", base)

# ---------------------------------------------------------------------------
# static meshes
# ---------------------------------------------------------------------------
# Add one engine face (model JSON) with engine-local points to array buffers.
# Points are converted to Godot (x, y, -z).
func _add_face(arr: Dictionary, pts: Array, f: Dictionary, flatten_y: bool) -> void:
	var kind: String = f.kind
	var v: Array = f.v
	var n := v.size()
	if kind == "line":
		var lv: PackedVector3Array = arr.lverts
		for k in [0, 1]:
			var p: Array = pts[int(v[k])]
			lv.append(Vector3(p[0], 0.0 if flatten_y else p[1], -float(p[2])))
			arr.lcols.append(Color(float(f.color_index) / 255.0, 0, 0))
			arr.luv.append(Vector2.ZERO)
			arr.luv2.append(Vector2.ZERO)
		return
	if n < 3:
		return
	var mode := 0
	var page := 0
	var colr := 0.0
	var uv: Array = []
	if kind == "flat":
		colr = float(f.color_index) / 255.0
	elif kind == "filter":
		mode = 3 + int(f.filter)
	elif kind == "tex" or kind == "transparent":
		mode = 1 if kind == "tex" else 2
		page = int(f.get("page", 0))
		uv = f.get("uv", [])
	for k in range(1, n - 1):
		for j in [0, k, k + 1]:
			var p: Array = pts[int(v[j])]
			arr.verts.append(Vector3(p[0], 0.0 if flatten_y else p[1], -float(p[2])))
			arr.cols.append(Color(colr, 0, 0))
			arr.uv.append(Vector2(uv[j][0], uv[j][1]) if j < uv.size() else Vector2.ZERO)
			arr.uv2.append(Vector2(mode, page))

func _new_arr() -> Dictionary:
	return {"verts": PackedVector3Array(), "cols": PackedColorArray(), "uv": PackedVector2Array(),
		"uv2": PackedVector2Array(), "lverts": PackedVector3Array(), "lcols": PackedColorArray(),
		"luv": PackedVector2Array(), "luv2": PackedVector2Array()}

func _arr_to_mesh(arr: Dictionary, mat: Material) -> ArrayMesh:
	var am := ArrayMesh.new()
	if arr.verts.size() > 0:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = arr.verts
		a[Mesh.ARRAY_COLOR] = arr.cols
		a[Mesh.ARRAY_TEX_UV] = arr.uv
		a[Mesh.ARRAY_TEX_UV2] = arr.uv2
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		am.surface_set_material(am.get_surface_count() - 1, mat)
	if arr.lverts.size() > 0:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = arr.lverts
		a[Mesh.ARRAY_COLOR] = arr.lcols
		a[Mesh.ARRAY_TEX_UV] = arr.luv
		a[Mesh.ARRAY_TEX_UV2] = arr.luv2
		am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, a)
		am.surface_set_material(am.get_surface_count() - 1, mat)
	return am

func _model_mesh(points: Array, faces: Array, mat: Material, flatten_y := false) -> ArrayMesh:
	var arr := _new_arr()
	for f in faces:
		_add_face(arr, points, f, flatten_y)
	return _arr_to_mesh(arr, mat)

func _build_stands() -> void:
	for k in range(4):
		var sd = stad.stands[k]
		var m = R3DAssets.json(String(sd.model))
		var pos := Vector3(sd.x, sd.y, -float(sd.z))
		var mm := _model_mesh(m.points, m.faces, _mat(sh_world_vidi, PRI_STANDS))
		var mv := _model_mesh(m.points, m.faces, _mat(sh_world, PRI_STANDS))
		var a := _new_mi(LAYER_MAIN)
		a.mesh = mm
		a.position = pos
		var b := _new_mi(LAYER_VIDI)
		b.mesh = mv
		b.position = pos
		stand_main.append(a)
		stand_vidi.append(b)

func _build_lines() -> void:
	var mat := _mat(sh_world, PRI_LINES)
	var pl = R3DAssets.json("models/pitch_lines.json")
	var order := ["l1", "l2", "l3", "l4", "l5", "l6", "circle", "semi1", "semi2", "spot1", "spot2", "spot3"]
	var meshes_by_model := {}
	for n in order:
		var o = pl.objects[n]
		var model_name: String = o.get("model", "lines_" + String(o.get("lod_model", "")))
		if not meshes_by_model.has(model_name):
			var m = R3DAssets.json("models/" + model_name + ".json")
			var lods: Array = []
			var zs: Array = []
			if m.has("lod"):
				for lv in m.lod:
					if not lv.reachable:
						continue
					lods.append(_model_mesh(lv.points, lv.faces, mat, true))
					zs.append(float(lv.zscale))
			else:
				lods.append(_model_mesh(m.points, m.faces, mat, true))
				zs.append(0.0)
			meshes_by_model[model_name] = [lods, zs]
		var mi := _new_mi(LAYER_COMMON)
		var p: Array = o.position_engine
		mi.position = Vector3(p[0], 0.0, -float(p[2]))
		var e = meshes_by_model[model_name]
		mi.mesh = e[0][e[0].size() - 1]
		line_objs.append([mi, e[0], Vector3(p[0], p[1], p[2]), e[1], n in ["circle", "semi1", "semi2"]])

func _build_shadows_highlights() -> void:
	var hj = R3DAssets.json("models/player_highlights.json")
	var mat_ps := _mat(sh_world, PRI_PSHADOW)
	var mat_bs := _mat(sh_world, PRI_BSHADOW)
	var mat_hl := _mat(sh_world, PRI_HILITE)
	var plshad := _model_mesh(hj.plshad.points, hj.table[0][0].faces, mat_ps, true)
	for i in range(25):
		var mi := _new_mi(LAYER_COMMON)
		mi.mesh = plshad
		mi.visible = false
		shadow_mis.append(mi)
		var h := _new_mi(LAYER_COMMON)
		h.visible = false
		hl_mis.append(h)
	for ht in range(7):
		var row: Array = []
		for hc in range(6):
			var e = hj.table[ht][hc]
			var pts = hj.plshad.points if ht == 0 else hj.plhi.points
			row.append(_model_mesh(pts, e.faces, mat_hl, true))
		hl_meshes.append(row)
	var bj = R3DAssets.json("models/ball_shadow.json")
	ball_shadow_mi = _new_mi(LAYER_COMMON)
	ball_shadow_mi.mesh = _model_mesh(bj.points, bj.faces, mat_bs, true)

# Precompiled face list (world objects): flat arrays, no per-frame dictionaries.
class CFaces:
	var idx: Array = []                 # PackedInt32Array per face (polygon vertex indices)
	var mode := PackedInt32Array()
	var page := PackedInt32Array()
	var colr := PackedFloat32Array()
	var uv: Array = []                  # PackedVector2Array per face
	var tex := PackedInt32Array()
	var lines: Array = []               # [i0, i1, colour] of 2-point faces

func _compile_faces(faces: Array) -> CFaces:
	var cf := CFaces.new()
	for f in faces:
		var v: Array = f.v
		if v.size() < 3:
			if f.kind == "line":
				cf.lines.append([int(v[0]), int(v[1]), float(f.color_index) / 255.0])
			continue
		var mode := 0
		var page := 0
		var colr := 0.0
		var t := 0
		var uvs := PackedVector2Array()
		uvs.resize(v.size())
		if f.kind == "flat":
			colr = float(f.color_index) / 255.0
		elif f.kind == "filter":
			mode = 3 + int(f.filter)
		else:
			mode = 1 if f.kind == "tex" else 2
			t = int(f.tex)
			page = int(f.get("page", R3DAssets.tex_page[t]))
			var uv: Array = f.get("uv", [])
			for j in range(mini(uv.size(), v.size())):
				uvs[j] = Vector2(uv[j][0], uv[j][1])
		cf.idx.append(PackedInt32Array(v))
		cf.mode.append(mode)
		cf.page.append(page)
		cf.colr.append(colr)
		cf.uv.append(uvs)
		cf.tex.append(t)
	return cf

func _new_dyn_mi(layer: int, shader: Shader, pri: int) -> MeshInstance3D:
	var mi := _new_mi(layer)
	mi.mesh = ArrayMesh.new()
	mi.material_override = _mat(shader, pri)
	return mi

func _load_objects() -> void:
	var b = R3DAssets.json("models/ball.json")
	for lv in b.lod:
		ball_lod.append([float(lv.zscale), lv.points, _compile_faces(lv.faces),
			_model_mesh(lv.points, lv.faces, _mat(sh_world, PRI_OBJECTS))])
	ball_mi = _new_dyn_mi(LAYER_COMMON, sh_world, PRI_OBJECTS)
	ball_dot_mesh = ball_mi.mesh
	var g = R3DAssets.json("models/goals.json")
	# init3d order: goal1_1 goal2_1 goal3_1 goal4_1 goal1_2 ...
	for n in ["goal1_1", "goal2_1", "goal3_1", "goal4_1", "goal1_2", "goal2_2", "goal3_2", "goal4_2"]:
		var o = g.objects[n]
		var lname: String = o.lod_model
		if not goal_lods.has(lname):
			var lods: Array = []
			for lv in R3DAssets.json("models/goal_" + lname + ".json").lod:
				var pts := PackedVector3Array()
				for q in lv.points:
					pts.append(Vector3(q[0], q[1], q[2]))
				lods.append([float(lv.zscale), pts, _compile_faces(lv.faces)])
			goal_lods[lname] = lods
		var p: Array = o.position_engine
		goal_objs.append([n, Vector3(p[0], p[1], p[2]), lname])
		goal_mis.append(_new_dyn_mi(LAYER_COMMON, sh_world, PRI_OBJECTS))
	flag_model = R3DAssets.json("models/flag.json")
	flag_faces = _compile_faces(flag_model.faces)
	for q in flag_model.points:
		flag_pts.append(Vector3(q[0], q[1], q[2]))
	for p in flag_model.positions_engine:
		flag_pos.append(Vector3(p[0], p[1], p[2]))
		flag_mis.append(_new_dyn_mi(LAYER_COMMON, sh_world, PRI_OBJECTS))

var flag_faces: CFaces
var ball_dot_mesh: ArrayMesh
var flag_pts := PackedVector3Array()

# Player face lists -> static meshes whose vertices describe faces (the
# impostors are built in the vertex shader, R3DShaders.PLAYER_CODE).
func _facelist_mesh(faces: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uv2 := PackedVector2Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var idx := PackedInt32Array()
	var fi := 0
	for f in faces:
		var v: Array = f.v
		var kind := 2
		if f.kind == "cyl_billboard":
			kind = 0
		elif f.kind == "ellipse_billboard":
			kind = 1
		elif f.kind == "line" or v.size() < 3:
			fi += 1
			continue
		if fi == 12:
			kind = 3        # shirt number patch (faces[82] overwritten per player)
		var vv := [0, 0, 0, 0]
		for j in range(mini(4, v.size())):
			vv[j] = int(v[j])
		var pa := 0.0
		var pb := 0.0
		var pl := 1.0
		if kind == 0:
			pa = float(f.width); pl = float(f.length)
		elif kind == 1:
			pa = float(f.a); pb = float(f.b); pl = float(f.length)
		var base := verts.size()
		for corner in range(4):
			verts.append(Vector3.ZERO)
			uv2.append(Vector2(corner, int(f.col_raw)))
			c0.append_array([kind, vv[0], vv[1], vv[2]])
			c1.append_array([vv[3], pa, pb, pl])
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
		fi += 1
	var am := ArrayMesh.new()
	if verts.is_empty():
		return am		# empty face list (nothing to draw for this player type)
	var arrs := []
	arrs.resize(Mesh.ARRAY_MAX)
	arrs[Mesh.ARRAY_VERTEX] = verts
	arrs[Mesh.ARRAY_TEX_UV2] = uv2
	arrs[Mesh.ARRAY_CUSTOM0] = c0
	arrs[Mesh.ARRAY_CUSTOM1] = c1
	arrs[Mesh.ARRAY_INDEX] = idx
	var fmt := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs, [], {}, fmt)
	am.custom_aabb = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
	return am

func _build_players() -> void:
	var pj = R3DAssets.json("models/player.json")
	for k in pj.facelists.keys():
		player_lists[k] = _facelist_mesh(pj.facelists[k])
	playertypes = pj.playertypes
	# texture table as a float texture: (u0,v0,u1,v1) (u2,v2,u3,v3) (page)
	var n := R3DAssets.tex_page.size()
	var tdata := PackedFloat32Array()
	tdata.resize(n * 3 * 4)
	tdata.fill(0.0)
	for t in range(n):
		for j in range(8):
			tdata[t * 12 + j] = R3DAssets.tex_uv4[t * 8 + j]
		tdata[t * 12 + 8] = R3DAssets.tex_page[t]
	textab_tex = ImageTexture.create_from_image(Image.create_from_data(3, n, false, Image.FORMAT_RGBAF, tdata.to_byte_array()))
	pose_data.resize(32 * 25 * 4)
	pose_data.fill(0.0)
	pose_img = Image.create_from_data(32, 25, false, Image.FORMAT_RGBAF, pose_data.to_byte_array())
	pose_tex = ImageTexture.create_from_image(pose_img)
	sh_player = Shader.new()
	sh_player.code = R3DShaders.player_code()
	for i in range(25):
		var t := Tw.new()
		t.twnpts1.resize(85)
		t.twnpts2.resize(85)
		t.twnpts1[0] = PLYRPTS
		t.twnpts2[0] = PLYRPTS
		t.twnfrm = R3DAssets.mocap.slice(0, 85)      # player[0].points = player_p[0]
		plyrtwtb.append(t)
		frame_pts.append(PackedFloat32Array())
		frame_xf.append(false)
		frame_faces.append(null)
		for layer in [LAYER_MAIN, LAYER_VIDI]:
			var mi := _new_mi(layer)
			var m := ShaderMaterial.new()
			m.shader = sh_player
			m.render_priority = PRI_OBJECTS
			m.set_shader_parameter("atlas", atlas_tex)
			m.set_shader_parameter("pal", pal_tex)
			m.set_shader_parameter("linear_out", linear_out)
			m.set_shader_parameter("pose", pose_tex)
			m.set_shader_parameter("textab", textab_tex)
			m.set_shader_parameter("row", i)
			mi.material_override = m
			mi.custom_aabb = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
			if layer == LAYER_MAIN:
				player_mis_main.append(mi)
			else:
				player_mis_vidi.append(mi)

var sh_player: Shader
var textab_tex: ImageTexture
var pose_data := PackedFloat32Array()
var pose_img: Image
var pose_tex: ImageTexture


# ===========================================================================
# per frame
# ===========================================================================
# Screen mode / size (Eng3D.main_buff) -> viewport size and on-screen rect.
func _layout_screen() -> Array:
	var mb = Eng3D.main_buff
	var cw: int = mb.clip_wid
	var ch: int = mb.clip_hgt
	var sx: float = mb.scale_x
	var sy: float = mb.scale_y
	var bw: int = mb.buff_wid
	var bh: int = mb.buff_hgt
	if cw <= 0 or ch <= 0:
		cw = 640; ch = 400; sx = 1.0; sy = 1.0; bw = 640; bh = 400
	var want := Vector2i(cw, ch) * render_scale
	if main_vp.size != want:
		main_vp.size = want
	# largest 4:3 rectangle of the window (as scripts/render/hud.gd)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = vp.x
	var h: float = w * 3.0 / 4.0
	if h > vp.y:
		h = vp.y
		w = h * 4.0 / 3.0
	var r := Rect2(((vp - Vector2(w, h)) / 2.0).floor(), Vector2(w, h).floor())
	# clip window centred in the screen buffer (init3d buff_start)
	var x0: float = float((bw - cw) >> 1)
	var y0: float = float((bh - ch) >> 1)
	screen_rect.position = r.position + Vector2(x0 / bw * r.size.x, y0 / bh * r.size.y)
	screen_rect.size = Vector2(float(cw) / bw * r.size.x, float(ch) / bh * r.size.y)
	return [cw, ch, sx, sy]

func update_view() -> void:
	var v = Upd3D.view
	var lay := _layout_screen()
	ecam.setup(v.viewx, v.viewy, v.viewz, v.targx, v.targy, v.targz, v.vdist, lay[2], lay[3], lay[0], lay[1])
	ecam.apply_to(cam)
	pitch_simple_mi.visible = Glob.setup.detail.pitch == 0
	var vidi_on: bool = vidi_enabled and v.vidi
	if vidi_on:
		vcam.setup(v.vidi_viewx, v.vidi_viewy, v.vidi_viewz, v.vidi_targx, v.vidi_targy, v.vidi_targz,
			v.vdist, 0.175, 0.183, 128, 80)
		vcam.apply_to(vidi_cam)
		vidi_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		vidi_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for k in range(4):
		var vm := _mat(sh_world_vidi, PRI_STANDS + k)
		vm.set_shader_parameter("vidi_on", vidi_on)
		if vidi_on:
			vm.set_shader_parameter("vidi_tex", vidi_vp.get_texture())

	_t0 = Time.get_ticks_usec()
	_update_ground(ecam, ground_mi)
	_update_stands(ecam, stand_main)
	if vidi_on:
		_update_ground(vcam, ground_vidi_mi)
		_update_stands(vcam, stand_vidi)
	_update_lines()
	_update_shadows()
	_tick("static")
	_compute_players()
	_upload_pose()
	_tick("players_pose")
	_draw_players(ecam, player_mis_main)
	_tick("players_main")
	if vidi_on:
		_draw_players(vcam, player_mis_vidi)
	else:
		for mi in player_mis_vidi:
			mi.visible = false
	_tick("players_vidi")
	_update_ball()
	_update_goals()
	_update_flags()
	_tick("objects")
	_prof_frames += 1
	if _prof_on and _prof_frames % 100 == 0:
		var s := ""
		for k in _prof:
			s += "%s %.2fms  " % [k, _prof[k] / 1000.0 / _prof_frames]
		print("update_view profile: ", s)

var _t0 := 0
var _prof := {}
var _prof_frames := 0
var _prof_on := OS.get_environment("DBG_TIME") != ""
func _tick(name: String) -> void:
	var t := Time.get_ticks_usec()
	_prof[name] = _prof.get(name, 0) + (t - _t0)
	_t0 = t

# //// FAR STANDS
func _update_stands(c: R3DCam, mis: Array) -> void:
	var vn: float
	vn = st_w * c.r22 + c.r23
	var vs1 := vn * c.r00 - (st_w * c.r02 + c.r03) * c.r20
	vn = (-800 - st_w) * c.r22 + c.r23
	var vs2 := vn * c.r00 - ((-800 - st_w) * c.r02 + c.r03) * c.r20
	vn = -st_l * c.r20 + c.r23
	var vs3 := vn * c.r02 - (-st_l * c.r00 + c.r03) * c.r22
	vn = (1280 + st_l) * c.r20 + c.r23
	var vs4 := vn * c.r02 - ((1280 + st_l) * c.r00 + c.r03) * c.r22
	# stadium < 90: stad3, stad1, stad2, stad4 (no sorting: list order)
	var order := [[2, vs3 >= 0], [0, vs4 < 0], [1, vs1 >= 0], [3, vs2 < 0]]
	var k := 0
	for o in order:
		var mi: MeshInstance3D = mis[o[0]]
		mi.visible = o[1] and not debug_hide_stands
		if o[1]:
			# draw order via the render priority of a per-slot material
			mi.material_override = _mat(sh_world_vidi if mis == stand_main else sh_world, PRI_STANDS + k)
			k += 1

# objdepd(): choose a detail level from the object depth
func _lod_index(c: R3DCam, pos: Vector3, zscales: Array) -> int:
	var oz := c.depth(pos.x, pos.y, pos.z)
	var zq := 0.0 if oz < 0 else oz / float(c.q)
	var i := 0
	while i < zscales.size() - 1 and float(zscales[i]) > zq:
		i += 1
	return i

# //// PITCH MARKINGS
func _update_lines() -> void:
	for lo in line_objs:
		var mi: MeshInstance3D = lo[0]
		if lo[4] and not Glob.setup.detail.lines:
			mi.visible = false
			continue
		mi.visible = true
		mi.mesh = lo[1][_lod_index(ecam, lo[2], lo[3])]

# //// SHADOWS/HIGHLIGHTS
func _update_shadows() -> void:
	var pos: Array = Glob.pos
	for i in range(25):
		var p = pos[i]
		var mi: MeshInstance3D = shadow_mis[i]
		mi.visible = p.type != 0 and p.htype == 0 and Glob.setup.detail.players != 0
		if mi.visible:
			mi.position = Vector3(p.x, 0.0, p.z)
	# Ball shadow (uses balld of the previous frame; mcap_ballx/y are 0 in the
	# Euro build, so a motion-captured ball's shadow goes to the corner (0,0))
	var bp = pos[25]
	if not balld:
		ball_shadow_mi.position = Vector3(bp.x, 0.0, bp.z)
	else:
		ball_shadow_mi.position = Vector3(mcap_ball.x, 0.0, -mcap_ball.z)
	# Player hilights
	hcoo += Glob.log_factor
	while hcoo >= 4:
		hcoo -= 4
	for i in range(25):
		var p = pos[i]
		var h: MeshInstance3D = hl_mis[i]
		h.visible = false
		if p.type and p.htype:
			if (p.htype != 4 and p.htype != 6) or hcoo >= 2:
				var ht: int = clampi(p.htype, 0, 6)
				var hc: int = clampi(p.hcol, 0, 5)
				h.mesh = hl_meshes[ht][hc]
				h.visible = true
				h.position = Vector3(p.x, 0.0, p.z)
				if p.htype == 3 or p.htype == 4:
					# addobjyc: crot = plyr.crot, srot = -plyr.srot
					var cr: float = p.crot
					var sr: float = -p.srot
					h.basis = Basis(Vector3(cr, 0, sr), Vector3(0, 1, 0), Vector3(-sr, 0, cr))
				else:
					h.basis = Basis.IDENTITY

# ---------------------------------------------------------------------------
# players
# ---------------------------------------------------------------------------
static func _is_xf(an: int) -> bool:
	return (an & 1) != 0 and ((an >= 8 and an <= 69) or an >= 128)

func _cap_frame(an: int, frame: float) -> PackedFloat32Array:
	var xf := _is_xf(an)
	var mi := an - 1 if xf else an
	var idx: int = R3DAssets.cap_start[mi] + int(frame * R3DAssets.cap_frames[mi])
	idx = clampi(idx, 0, R3DAssets.mocap.size() / 85 - 1)
	return R3DAssets.mocap.slice(idx * 85, idx * 85 + 85)

const SWAP := [0, 1, 2, 3, 4, 8, 9, 10, 5, 6, 7, 12, 11, 17, 18, 19, 20, 13, 14, 15, 16, 22, 21, 23, 25, 24, 27, 26]

# render3d "Tweening" + "Motion captured ball" + face list choice
func _compute_players() -> void:
	balld = 0
	var log_factor: float = Glob.log_factor
	for i in range(25):
		var p = Glob.pos[i]
		frame_faces[i] = null
		if not p.type:
			continue
		var tw: Tw = plyrtwtb[i]
		var an: int = p.anim
		var ano: int = tw.anim
		var xf := _is_xf(an)
		var pts: PackedFloat32Array
		if an != ano or tw.tween >= 0:
			var xfo := _is_xf(ano)
			if tw.tween < 0:
				tw.tween = 0
				tw.tstep = p.fstep * 2 * log_factor
				tw.animto = an
			elif tw.animto != an:
				tw.twnpts2 = tw.twnpts1.duplicate()
				tw.twnfrm = tw.twnpts2
				tw.tween = 0
				tw.tstep = p.fstep * 2 * log_factor
				tw.anim = tw.animto
				ano = tw.anim
				tw.animto = an
				xfo = _is_xf(ano)
			tw.tween += tw.tstep
			if tw.tween >= 1:
				tw.tween = -1
				pts = _cap_frame(an, p.frame)
				tw.twnfrm = pts
				tw.anim = tw.animto
			else:
				var tw1 := _cap_frame(an, p.frame)
				var tw2 := tw.twnfrm
				var t := tw.twnpts1
				var pt1: float = tw.tween
				var pt2: float = 1 - pt1
				t[0] = PLYRPTS
				if xf != xfo:
					for k in range(PLYRPTS):
						var s: int = SWAP[k]
						var o := 1 + k * 3
						var os := 1 + s * 3
						if k == 23 and tw2[1 + 23 * 3 + 1] < 0:
							t[o] = tw1[o]; t[o + 1] = tw1[o + 1]; t[o + 2] = tw1[o + 2]
						else:
							t[o] = tw1[o] * pt1 + tw2[os] * pt2
							t[o + 1] = tw1[o + 1] * pt1 + tw2[os + 1] * pt2
							t[o + 2] = tw1[o + 2] * pt1 - tw2[os + 2] * pt2
				else:
					for j in range(1, 85):
						t[j] = tw1[j] * pt1 + tw2[j] * pt2
				tw.twnpts1 = t
				pts = t
		else:
			pts = _cap_frame(an, p.frame)
			tw.twnfrm = pts
			tw.anim = an
		frame_pts[i] = pts
		frame_xf[i] = xf
		# object placement
		var ox: float = p.x
		var oy: float = p.y
		var oz: float = -p.z
		var crot: float = -p.crot
		var srot: float = p.srot
		# Motion captured ball
		if pts[1 + 23 * 3 + 1] >= 0:
			var by: float = -pts[1 + 23 * 3]
			var bz: float = -pts[1 + 23 * 3 + 2] if xf else pts[1 + 23 * 3 + 2]
			var bx: float = -by * crot + bz * srot + ox
			bz = by * srot + bz * crot + oz
			by = pts[1 + 23 * 3 + 1] + oy
			mcap_ball_obj = Vector3(bx, by, bz)
			balld = 1
		# Face list (playertypes)
		var k: int
		var ptype: int = p.type
		var tdata = _team_data(ptype)
		var dark: bool = tdata != null and tdata.players[i % 11].skin_tone != 0 and Glob.setup.M8 != 0
		if xf:
			if i == 0 or i == 11:
				k = 10 if (ptype == 1 or not Glob.setup.M8) else 20
			elif dark:
				k = ptype + 15
			else:
				k = ptype + 5
		else:
			if i == 0 or i == 11:
				k = 5 if (ptype == 1 or not Glob.setup.M8) else 15
			elif dark:
				k = ptype + 10
			else:
				k = ptype
		var nm = playertypes[clampi(k, 0, playertypes.size() - 1)]
		if nm == null:
			nm = "player_f1"
		frame_faces[i] = nm
	if balld:
		ball_pos_override = mcap_ball_obj

var mcap_ball_obj := Vector3.ZERO
var ball_pos_override := Vector3.ZERO

func _team_data(ptype: int):
	var gd: Array = Glob.game_data
	var t: int = Glob.setup.team_a if ptype == 1 else Glob.setup.team_b
	if ptype != 1 and ptype != 2:
		return null
	if t < 0 or t >= gd.size():
		return null
	return gd[t]

# add3dcmap: limb impostor. returns [tex, corners(4 x Vector2)]
# Upload the posed points of all players (engine world coordinates).
func _upload_pose() -> void:
	var show_numbers: bool = Glob.setup.detail.players != 0
	var d := pose_data
	for i in range(25):
		if frame_faces[i] == null:
			continue
		var p = Glob.pos[i]
		var ox: float = p.x
		var oy: float = p.y
		var oz: float = -p.z
		var crot: float = -p.crot
		var srot: float = p.srot
		var pts: PackedFloat32Array = frame_pts[i]
		var zsign := -1.0 if frame_xf[i] else 1.0
		var b := i * 32 * 4
		for k in range(PLYRPTS):
			var px: float = pts[1 + k * 3]
			var py: float = pts[1 + k * 3 + 1]
			var pz: float = pts[1 + k * 3 + 2] * zsign
			d[b + k * 4] = ox + crot * px + srot * pz
			d[b + k * 4 + 1] = oy + py
			d[b + k * 4 + 2] = oz - srot * px + crot * pz
		# shirt number texture: team A X_TM+16+(n-1), team B X_TM+31+(n-1)
		var numtex := -1
		if i < 22 and show_numbers:
			numtex = X_TM + 16 + (p.number - 1) if p.type == 1 else X_TM + 31 + (p.number - 1)
		d[b + 28 * 4] = numtex
		d[b + 29 * 4] = ox
		d[b + 29 * 4 + 1] = oy
		d[b + 29 * 4 + 2] = oz
	pose_img.set_data(32, 25, false, Image.FORMAT_RGBAF, d.to_byte_array())
	pose_tex.update(pose_img)

func _draw_players(c: R3DCam, mis: Array) -> void:
	var R0 := Vector4(c.r00, c.r01, c.r02, c.r03)
	var R1 := Vector4(c.r10, c.r11, c.r12, c.r13)
	var R2 := Vector4(c.r20, c.r21, c.r22, c.r23)
	var bufv := Vector2(c.W, c.H)
	var qf := float(c.q)
	for i in range(25):
		var mi: MeshInstance3D = mis[i]
		if frame_faces[i] == null:
			mi.visible = false
			continue
		var p = Glob.pos[i]
		var ox: float = p.x
		var oy: float = p.y
		var oz: float = -p.z
		# Draw object  (objdep>15)
		if ox * c.r20 + oy * c.r21 + oz * c.r22 + c.r23 <= 15:
			mi.visible = false
			continue
		mi.visible = true
		mi.position = Vector3(ox, oy, -oz)
		mi.mesh = player_lists[frame_faces[i]]
		var m: ShaderMaterial = mi.material_override
		m.set_shader_parameter("R0", R0)
		m.set_shader_parameter("R1", R1)
		m.set_shader_parameter("R2", R2)
		m.set_shader_parameter("buf", bufv)
		m.set_shader_parameter("qf", qf)

# ---------------------------------------------------------------------------
# ball, goals, flags (sorted objects)
# ---------------------------------------------------------------------------
# Build the mesh of a world object: `wp` = engine-world points, polygons are
# sorted by average depth (sortobj / polcmp) when `sort`, else kept in list order.
func _set_world_mesh(mi: MeshInstance3D, c: R3DCam, wp: PackedVector3Array, cf: CFaces, origin_g: Vector3,
		sort: bool, tex_override := {}) -> void:
	var am: ArrayMesh = mi.mesh
	var nf := cf.idx.size()
	if nf == 0:
		am.clear_surfaces()
		mi.remove_meta("sig")
		return
	var np := wp.size()
	var dep := PackedFloat32Array()
	dep.resize(np)
	var g := PackedVector3Array()
	g.resize(np)
	for k in range(np):
		var e := wp[k]
		dep[k] = e.x * c.r20 + e.y * c.r21 + e.z * c.r22 + c.r23
		g[k] = Vector3(e.x, e.y, -e.z) - origin_g
	var order: Array = []
	order.resize(nf)
	for fi in range(nf):
		var v: PackedInt32Array = cf.idx[fi]
		var z := 0.0
		for j in v:
			z += dep[j]
		order[fi] = [z / v.size(), fi]
	if sort:
		order.sort_custom(func(A, B): return A[0] > B[0])
	# skip the rebuild when nothing changed (same faces, order, textures, points)
	var sig := PackedInt32Array()
	sig.resize(nf)
	for k in range(nf):
		sig[k] = order[k][1]
	var key := [cf.get_instance_id(), sig, tex_override.duplicate(), wp]
	if mi.has_meta("sig") and mi.get_meta("sig") == key:
		return
	mi.set_meta("sig", key)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()
	for o in order:
		var fi: int = o[1]
		var v: PackedInt32Array = cf.idx[fi]
		var nv := v.size()
		var base := verts.size()
		var mode: int = cf.mode[fi]
		var uv: PackedVector2Array = cf.uv[fi]
		var page: int = cf.page[fi]
		if tex_override.has(fi):
			var t: int = tex_override[fi]
			page = R3DAssets.tex_page[t]
			uv = PackedVector2Array()
			for j in range(nv):
				if nv == 3:
					uv.append(Vector2(R3DAssets.tex_uv3[t * 6 + j * 2], R3DAssets.tex_uv3[t * 6 + j * 2 + 1]))
				else:
					uv.append(Vector2(R3DAssets.tex_uv4[t * 8 + j * 2], R3DAssets.tex_uv4[t * 8 + j * 2 + 1]))
		var info := Vector2(mode, page)
		var col := Color(cf.colr[fi], 0, 0)
		for j in range(nv):
			verts.append(g[v[j]])
			uvs.append(uv[j])
			uv2s.append(info)
			cols.append(col)
		for k in range(1, nv - 1):
			idx.append(base)
			idx.append(base + k)
			idx.append(base + k + 1)
	am.clear_surfaces()
	if verts.is_empty():
		return		# nothing visible this frame (all polygons culled)
	var arrs := []
	arrs.resize(Mesh.ARRAY_MAX)
	arrs[Mesh.ARRAY_VERTEX] = verts
	arrs[Mesh.ARRAY_COLOR] = cols
	arrs[Mesh.ARRAY_TEX_UV] = uvs
	arrs[Mesh.ARRAY_TEX_UV2] = uv2s
	arrs[Mesh.ARRAY_INDEX] = idx
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrs)

func _lod_pick(c: R3DCam, pos: Vector3, lods: Array) -> Array:
	var oz := c.depth(pos.x, pos.y, pos.z)
	var zq := 0.0 if oz < 0 else oz / float(c.q)
	var i := 0
	while i < lods.size() - 1 and float(lods[i][0]) > zq:
		i += 1
	return lods[i]

func _update_ball() -> void:
	var bp = Glob.pos[25]
	var bpos := Vector3(bp.x, bp.y, -bp.z)
	if balld:
		bpos = ball_pos_override
	var origin_g := Vector3(bpos.x, bpos.y, -bpos.z)
	ball_mi.position = origin_g
	var lv: Array = _lod_pick(ecam, bpos, ball_lod)
	var cf: CFaces = lv[2]
	if ecam.depth(bpos.x, bpos.y, bpos.z) <= R3DCam.CUTOFFDIST:
		ball_mi.visible = false
		return
	ball_mi.visible = true
	var crot: float = bp.crot
	var srot: float = bp.srot
	var cx: float = bp.frame
	var sx: float = bp.fstep
	var pts: Array = lv[1]
	if cf.idx.size() > 0:
		# addobjxy: rotate in y then x (engine matrix M, in Godot space F*M*F);
		# the ball's polygons are not sorted (list order + facing test)
		ball_mi.mesh = lv[3]
		ball_mi.basis = Basis(Vector3(crot, 0, srot), Vector3(-srot * sx, cx, crot * sx), Vector3(-srot * cx, -sx, crot * cx))
	else:
		ball_mi.mesh = ball_dot_mesh
		ball_mi.basis = Basis.IDENTITY
		# far level: a line between two identical points = one pixel of colour 31
		var s := ecam.project(bpos)
		var d := maxf(s.x, 16.0)
		var colr: float = cf.lines[0][2] if cf.lines.size() > 0 else 31.0 / 255.0
		var wp := PackedVector3Array()
		for o in [Vector2(-.5, -.5), Vector2(.5, -.5), Vector2(.5, .5), Vector2(-.5, .5)]:
			var gp := ecam.unproject_godot(s.y + o.x, s.z + o.y, d)
			wp.append(Vector3(gp.x, gp.y, -gp.z))
		var dot := CFaces.new()
		dot.idx = [PackedInt32Array([0, 1, 2, 3])]
		dot.mode = PackedInt32Array([0])
		dot.page = PackedInt32Array([0])
		dot.colr = PackedFloat32Array([colr])
		dot.uv = [PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])]
		dot.tex = PackedInt32Array([0])
		_set_world_mesh(ball_mi, ecam, wp, dot, origin_g, false)

func _update_goals() -> void:
	for gi in range(goal_objs.size()):
		var o: Array = goal_objs[gi]
		var pos: Vector3 = o[1]
		var lv: Array = _lod_pick(ecam, pos, goal_lods[o[2]])
		var lp: PackedVector3Array = lv[1]
		var wp := PackedVector3Array()
		wp.resize(lp.size())
		for k in range(lp.size()):
			wp[k] = pos + lp[k]
		var mi: MeshInstance3D = goal_mis[gi]
		var origin_g := Vector3(pos.x, pos.y, -pos.z)
		mi.position = origin_g
		_set_world_mesh(mi, ecam, wp, lv[2], origin_g, true)

func _update_flags() -> void:
	var tip: Vector3
	# wind (render3d end): flag tip point 8 and cloth texture cycling
	if Glob.wind_on:
		fcoo += Glob.log_factor
		if fcoo >= (128 - Glob.wind_speed) / 10:
			if flag_tex == X_TM + 48:
				flag_tex = X_TM + 46
			else:
				flag_tex += 1
			fcoo = 0
		var fs: float = (3.1415 / 2) * (Glob.wind_speed + 16) / 144
		var fx: float = 8.5 * sin(fs) + 1
		var fy: float = 8.5 * cos(fs)
		tip = Vector3(fx * Glob.wind_x, 15 - fy, fx * Glob.wind_y)
	else:
		tip = Vector3(1.751, 6.629, 1.751)
	var ovr := {5: flag_tex, 6: flag_tex}
	for k in range(4):
		var mi: MeshInstance3D = flag_mis[k]
		mi.visible = Glob.setup.detail.lines != 0
		if not mi.visible:
			continue
		var pos: Vector3 = flag_pos[k]
		var wp := PackedVector3Array()
		wp.resize(flag_pts.size())
		for j in range(flag_pts.size()):
			wp[j] = pos + (tip if j == 8 else flag_pts[j])
		var origin_g := Vector3(pos.x, pos.y, -pos.z)
		mi.position = origin_g
		_set_world_mesh(mi, ecam, wp, flag_faces, origin_g, true, ovr)
