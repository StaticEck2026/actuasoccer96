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

var atlas_tex: ImageTexture
var pal_tex: ImageTexture
var sky_tex: ImageTexture
var sh_world: Shader
var sh_free: Shader
var sh_world_vidi: Shader
var mat_cache := {}

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
	mat_cache[key] = m
	return m

func _build_cameras() -> void:
	cam = Camera3D.new()
	cam.near = 10.0
	cam.far = 20000.0
	cam.cull_mask = LAYER_COMMON | LAYER_MAIN
	add_child(cam)
	cam.current = true
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
	var sh := Shader.new()
	sh.code = R3DShaders.GROUND_CODE
	var m := ShaderMaterial.new()
	m.shader = sh
	m.render_priority = PRI_GROUND
	m.set_shader_parameter("atlas", atlas_tex)
	m.set_shader_parameter("pal", pal_tex)
	m.set_shader_parameter("sky_tex", sky_tex)
	m.set_shader_parameter("pitch_detail", Glob.setup.detail.pitch)
	m.set_shader_parameter("sky_on", Glob.setup.M8 != 0 and Glob.setup.detail.sky != 0)
	m.set_shader_parameter("stad", Vector3(st_w, st_l, st_h))
	var qm := QuadMesh.new()
	qm.size = Vector2(2, 2)
	ground_mi = _new_mi(LAYER_COMMON)
	ground_mi.mesh = qm
	ground_mi.material_override = m
	ground_mi.extra_cull_margin = 16384.0
	ground_mi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))

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

func _load_objects() -> void:
	var b = R3DAssets.json("models/ball.json")
	ball_lod = b.lod
	ball_mi = _new_mi(LAYER_COMMON)
	ball_mi.mesh = ImmediateMesh.new()
	var g = R3DAssets.json("models/goals.json")
	# init3d order: goal1_1 goal2_1 goal3_1 goal4_1 goal1_2 ...
	for n in ["goal1_1", "goal2_1", "goal3_1", "goal4_1", "goal1_2", "goal2_2", "goal3_2", "goal4_2"]:
		var o = g.objects[n]
		var lname: String = o.lod_model
		if not goal_lods.has(lname):
			goal_lods[lname] = R3DAssets.json("models/goal_" + lname + ".json").lod
		var p: Array = o.position_engine
		goal_objs.append([n, Vector3(p[0], p[1], p[2]), lname])
		var mi := _new_mi(LAYER_COMMON)
		mi.mesh = ImmediateMesh.new()
		goal_mis.append(mi)
	flag_model = R3DAssets.json("models/flag.json")
	for p in flag_model.positions_engine:
		flag_pos.append(Vector3(p[0], p[1], p[2]))
		var mi := _new_mi(LAYER_COMMON)
		mi.mesh = ImmediateMesh.new()
		flag_mis.append(mi)

func _build_players() -> void:
	var pj = R3DAssets.json("models/player.json")
	for k in pj.facelists.keys():
		var lst: Array = []
		for f in pj.facelists[k]:
			var e := {"kind": String(f.kind), "v": PackedInt32Array(f.v), "col": int(f.col_raw)}
			if f.has("a"):
				e.a = float(f.a); e.b = float(f.b); e.L = float(f.length)
			if f.has("width"):
				e.w = float(f.width); e.L = float(f.length)
			lst.append(e)
		player_lists[k] = lst
	playertypes = pj.playertypes
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
		var a := _new_mi(LAYER_MAIN)
		a.mesh = ImmediateMesh.new()
		player_mis_main.append(a)
		var b := _new_mi(LAYER_VIDI)
		b.mesh = ImmediateMesh.new()
		player_mis_vidi.append(b)


# ===========================================================================
# per frame
# ===========================================================================
func update_view() -> void:
	var v = Upd3D.view
	# 640x400 VESA mode, full screen: scale_x = scale_y = 1
	ecam.setup(v.viewx, v.viewy, v.viewz, v.targx, v.targy, v.targz, v.vdist, 1.0, 1.0, 640, 400)
	ecam.apply_to(cam)
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

	_update_stands(ecam, stand_main)
	if vidi_on:
		_update_stands(vcam, stand_vidi)
	_update_lines()
	_update_shadows()
	_compute_players()
	_draw_players(ecam, player_mis_main)
	if vidi_on:
		_draw_players(vcam, player_mis_vidi)
	else:
		for mi in player_mis_vidi:
			mi.visible = false
	_update_ball()
	_update_goals()
	_update_flags()

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
		mi.visible = o[1]
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
func _cmap(tp1: Vector3, tp2: Vector3, w: float, L: float, tex: int, c: R3DCam) -> Array:
	var dx1 := tp1.y - tp2.y
	var dy1 := tp1.z - tp2.z
	var dx2 := dx1 * dx1 + dy1 * dy1
	if dx2 == 0:
		dx1 = 1; dx2 = 1
	var tz2 := w * c.qa / (sqrt(dx2) * (tp1.x + tp2.x))
	var tz1 := 100 * (tp2.x - tp1.x) / L
	var dy2: float
	if tz1 >= 0:
		if tz1 > 0.78062475:
			tex += 3 if tz1 > 0.92702481 else 2
		elif tz1 > 0.48412292:
			tex += 1
		tz1 *= tz2; dy2 = tz2 * dy1; dx2 = tz2 * dx1; dy1 *= tz1; dx1 *= tz1
		return [tex, [Vector2(tp1.y + dx1 - dy2, tp1.z + dy1 + dx2), Vector2(tp1.y + dx1 + dy2, tp1.z + dy1 - dx2),
			Vector2(tp2.y - dx1 + dy2, tp2.z - dy1 - dx2), Vector2(tp2.y - dx1 - dy2, tp2.z - dy1 + dx2)]]
	else:
		if tz1 < -0.78062475:
			tex -= 3 if tz1 < -0.92702481 else 2
		elif tz1 < -0.48412292:
			tex -= 1
		tz1 *= tz2; dy2 = tz2 * dy1; dx2 = tz2 * dx1; dy1 *= tz1; dx1 *= tz1
		return [tex, [Vector2(tp1.y - dx1 - dy2, tp1.z - dy1 + dx2), Vector2(tp1.y - dx1 + dy2, tp1.z - dy1 - dx2),
			Vector2(tp2.y + dx1 + dy2, tp2.z + dy1 - dx2), Vector2(tp2.y + dx1 - dy2, tp2.z + dy1 + dx2)]]

# add3demap: head/torso/foot impostor (p = Vector3(rz, sx, sy))
func _emap(tp1: Vector3, tp2: Vector3, tp3: Vector3, a: float, b: float, L: float, tex: int, c: R3DCam) -> Array:
	var q := float(c.q)
	var dx1 := tp1.y - tp2.y
	var dy1 := tp1.z - tp2.z
	var rx := (tp3.y - tp2.y) * tp3.x / q
	var ry := (tp3.z - tp2.z) * tp3.x / q
	var dx2 := dx1 * dx1 + dy1 * dy1
	if dx2 == 0:
		dx1 = 1; dx2 = 1
	var dy2 := sqrt(dx2)
	var tz2 := c.qa / (dy2 * (tp1.x + tp2.x))
	var tz1 := (rx * dy1 - ry * dx1) / dy2
	tz1 = clampf(tz1, -1.0, 1.0)
	if tp3.x > tp2.x:
		if tz1 > -.2588:
			if tz1 <= .7071:
				tex += 9 if tz1 <= .2588 else 10
			elif tz1 <= .9659:
				tex += 11
		else:
			if tz1 > -.7071:
				tex += 8
			elif tz1 > -.9659:
				tex += 7
			else:
				tex += 6
	else:
		if tz1 <= .2588:
			if tz1 > -.7071:
				tex += 3 if tz1 > -.2588 else 4
			else:
				tex += 5 if tz1 > -.9659 else 6
		else:
			if tz1 <= .7071:
				tex += 2
			elif tz1 <= .9659:
				tex += 1
	tz1 *= tz1
	tz1 *= (a - b) * (a + b)
	dx2 = tz2 * sqrt(maxf(tz1 + b * b, 0.0))
	dy2 = 100 * (tp1.x - tp2.x) / L
	var e1: float
	var e2: float
	if dy2 >= 0:
		if dy2 > 0.555570233:
			tex += 36 if dy2 > 0.836286155 else 24
		elif dy2 > 0.195090322:
			tex += 12
		dy2 *= tz2 * sqrt(maxf(a * a - tz1, 0.0))
		e1 = dy2 * dx1; e2 = dy2 * dy1
		dx1 *= dx2; dy1 *= dx2
		return [tex, [Vector2(tp2.y + dy1 - e1, tp2.z - dx1 - e2), Vector2(tp2.y - dy1 - e1, tp2.z + dx1 - e2),
			Vector2(tp1.y - dy1 + e1, tp1.z + dx1 + e2), Vector2(tp1.y + dy1 + e1, tp1.z - dx1 + e2)]]
	else:
		if dy2 < -0.258819045:
			tex -= 12
		dy2 *= tz2 * sqrt(maxf(a * a - tz1, 0.0))
		e1 = dy2 * dx1; e2 = dy2 * dy1
		dx1 *= dx2; dy1 *= dx2
		return [tex, [Vector2(tp2.y + dy1 + e1, tp2.z - dx1 + e2), Vector2(tp2.y - dy1 + e1, tp2.z + dx1 + e2),
			Vector2(tp1.y - dy1 - e1, tp1.z + dx1 - e2), Vector2(tp1.y + dy1 - e1, tp1.z - dx1 - e2)]]

func _draw_players(c: R3DCam, mis: Array) -> void:
	var matf := _mat(sh_free, PRI_OBJECTS)
	for i in range(25):
		var mi: MeshInstance3D = mis[i]
		var im: ImmediateMesh = mi.mesh
		im.clear_surfaces()
		var p = Glob.pos[i]
		if frame_faces[i] == null:
			mi.visible = false
			continue
		var ox: float = p.x
		var oy: float = p.y
		var oz: float = -p.z
		var od := c.depth(ox, oy, oz)
		# Draw object  (objdep>15)
		if od <= 15:
			mi.visible = false
			continue
		mi.visible = true
		var gorigin := Vector3(ox, oy, -oz)
		mi.position = gorigin
		var crot: float = -p.crot
		var srot: float = p.srot
		var pts: PackedFloat32Array = frame_pts[i]
		var xf: bool = frame_xf[i]
		# rotate + project the 28 points (addobjy / addobjyf)
		var sp: Array = []
		sp.resize(PLYRPTS)
		for k in range(PLYRPTS):
			var px: float = pts[1 + k * 3]
			var py: float = pts[1 + k * 3 + 1]
			var pz: float = pts[1 + k * 3 + 2]
			if xf:
				pz = -pz
			sp[k] = c.project(Vector3(ox + crot * px + srot * pz, oy + py, oz - srot * px + crot * pz))
		var faces: Array = player_lists[frame_faces[i]]
		var nfaces := faces.size()
		# shirt number (faces[0]=13/12, faces[82]=number texture)
		var show_number: bool = i < 22 and Glob.setup.detail.players != 0
		if i < 22 and not show_number:
			nfaces = mini(nfaces, 12)
		var polys: Array = []
		for fi in range(nfaces):
			var f: Dictionary = faces[fi]
			var col: int = f.col
			if fi == 12 and i < 22:
				if p.type == 1:
					col = -X_TM - 2016 - (p.number - 1)
				else:
					col = -X_TM - 2016 - 15 - (p.number - 1)
			var trans := col < -2000
			var tex: int = (-col - 2000) if trans else -col
			var v: PackedInt32Array = f.v
			var kind: String = f.kind
			if kind == "cyl_billboard":
				var p1: Vector3 = sp[v[0]]
				var p2: Vector3 = sp[v[1]]
				if minf(p1.x, p2.x) < R3DCam.CUTOFFDIST:
					continue
				var r := _cmap(p1, p2, f.w, f.L, tex, c)
				polys.append([(p1.x + p2.x) / 2, r[1], r[0], trans])
			elif kind == "ellipse_billboard":
				var p1: Vector3 = sp[v[0]]
				var p2: Vector3 = sp[v[1]]
				if minf(p1.x, p2.x) < R3DCam.CUTOFFDIST:
					continue
				var r := _emap(p1, p2, sp[v[2]], f.a, f.b, f.L, tex, c)
				polys.append([(p1.x + p2.x) / 2, r[1], r[0], trans])
			else:
				# ordinary polygon (addpoly): visibility + facing check
				var q4: Array = []
				var zmin := 1e9
				var zsum := 0.0
				for j in v:
					var s: Vector3 = sp[j]
					q4.append(Vector2(s.y, s.z))
					zmin = minf(zmin, s.x)
					zsum += s.x
				if zmin < R3DCam.CUTOFFDIST or q4.size() < 3:
					continue
				var d1: Vector2 = q4[0] - q4[1]
				var d2: Vector2 = q4[0] - q4[2]
				if not (d1.x * d2.y < d2.x * d1.y):
					continue
				polys.append([zsum / v.size(), q4, tex, trans])
		polys.sort_custom(func(A, B): return A[0] > B[0])
		if polys.is_empty():
			continue
		var d := maxf(od, 16.0)
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, matf)
		for pl in polys:
			_emit_screen_poly(im, c, pl[1], int(pl[2]), pl[3], d, gorigin)
		im.surface_end()

func _emit_screen_poly(im: ImmediateMesh, c: R3DCam, scr: Array, tex: int, trans: bool, d: float, origin: Vector3) -> void:
	var n := scr.size()
	if tex < 0 or tex >= R3DAssets.tex_page.size():
		return
	var page: int = R3DAssets.tex_page[tex]
	var mode := 2 if trans else 1
	var g: Array = []
	for k in range(n):
		var s: Vector2 = scr[k]
		g.append(c.unproject_godot(s.x, s.y, d) - origin)
	for k in range(1, n - 1):
		for j in [0, k, k + 1]:
			im.surface_set_uv(Vector2(R3DAssets.tex_uv4[tex * 8 + j * 2], R3DAssets.tex_uv4[tex * 8 + j * 2 + 1]))
			im.surface_set_uv2(Vector2(mode, page))
			im.surface_set_color(Color(0, 0, 0))
			im.surface_add_vertex(g[j])

# ---------------------------------------------------------------------------
# ball, goals, flags (sorted objects)
# ---------------------------------------------------------------------------
# Emit model faces with engine-world points `wp` (Array of Vector3, engine
# coords).  sort: qsort polygons by average depth (sortobj) or keep list order.
func _emit_world_faces(im: ImmediateMesh, c: R3DCam, wp: Array, faces: Array, origin_g: Vector3, sort: bool, tex_override := {}) -> void:
	var polys: Array = []
	var fi := 0
	for f in faces:
		var v: Array = f.v
		if v.size() < 3:
			fi += 1
			continue
		var z := 0.0
		for j in v:
			z += c.depth(wp[int(j)].x, wp[int(j)].y, wp[int(j)].z)
		polys.append([z / v.size(), f, fi])
		fi += 1
	if sort:
		polys.sort_custom(func(A, B): return A[0] > B[0])
	if polys.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat(sh_world, PRI_OBJECTS))
	for pl in polys:
		var f: Dictionary = pl[1]
		var v: Array = f.v
		var kind: String = f.kind
		var mode := 0
		var page := 0
		var colr := 0.0
		var uv: Array = []
		if kind == "flat":
			colr = float(f.color_index) / 255.0
		elif kind == "filter":
			mode = 3 + int(f.filter)
		else:
			mode = 1 if kind == "tex" else 2
			var t: int = int(tex_override.get(pl[2], int(f.tex)))
			page = R3DAssets.tex_page[t]
			if tex_override.has(pl[2]):
				for j in range(v.size()):
					if v.size() == 3:
						uv.append([R3DAssets.tex_uv3[t * 6 + j * 2], R3DAssets.tex_uv3[t * 6 + j * 2 + 1]])
					else:
						uv.append([R3DAssets.tex_uv4[t * 8 + j * 2], R3DAssets.tex_uv4[t * 8 + j * 2 + 1]])
			else:
				uv = f.get("uv", [])
		for k in range(1, v.size() - 1):
			for j in [0, k, k + 1]:
				var e: Vector3 = wp[int(v[j])]
				im.surface_set_color(Color(colr, 0, 0))
				im.surface_set_uv(Vector2(uv[j][0], uv[j][1]) if j < uv.size() else Vector2.ZERO)
				im.surface_set_uv2(Vector2(mode, page))
				im.surface_add_vertex(Vector3(e.x, e.y, -e.z) - origin_g)
	im.surface_end()

func _update_ball() -> void:
	var bp = Glob.pos[25]
	var bpos := Vector3(bp.x, bp.y, -bp.z)
	if balld:
		bpos = ball_pos_override
	var im: ImmediateMesh = ball_mi.mesh
	im.clear_surfaces()
	var origin_g := Vector3(bpos.x, bpos.y, -bpos.z)
	ball_mi.position = origin_g
	var zs: Array = []
	for lv in ball_lod:
		zs.append(float(lv.zscale))
	var li := _lod_index(ecam, bpos, zs)
	var lv = ball_lod[li]
	if ecam.depth(bpos.x, bpos.y, bpos.z) <= R3DCam.CUTOFFDIST:
		return
	var crot: float = bp.crot
	var srot: float = bp.srot
	var cx: float = bp.frame
	var sx: float = bp.fstep
	var wp: Array = []
	for p in lv.points:
		var px: float = p[0]
		var py: float = p[1]
		var pz: float = p[2]
		wp.append(bpos + Vector3(crot * px - srot * sx * py + srot * cx * pz,
			cx * py + sx * pz,
			-srot * px - crot * sx * py + crot * cx * pz))
	var has_poly := false
	for f in lv.faces:
		if f.v.size() >= 3:
			has_poly = true
	if has_poly:
		_emit_world_faces(im, ecam, wp, lv.faces, origin_g, false)
	else:
		# far level: a 2-point line of colour 31 (one pixel) -> 1x1 engine pixel quad
		var s := ecam.project(wp[0])
		var d := maxf(s.x, 16.0)
		var colr := float(lv.faces[0].color_index) / 255.0
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat(sh_world, PRI_OBJECTS))
		var q := [Vector2(s.y - .5, s.z - .5), Vector2(s.y + .5, s.z - .5), Vector2(s.y + .5, s.z + .5), Vector2(s.y - .5, s.z + .5)]
		for j in [0, 1, 2, 0, 2, 3]:
			im.surface_set_color(Color(colr, 0, 0))
			im.surface_set_uv(Vector2.ZERO)
			im.surface_set_uv2(Vector2(0, 0))
			im.surface_add_vertex(ecam.unproject_godot(q[j].x, q[j].y, d) - origin_g)
		im.surface_end()

func _update_goals() -> void:
	for gi in range(goal_objs.size()):
		var o: Array = goal_objs[gi]
		var pos: Vector3 = o[1]
		var lods: Array = goal_lods[o[2]]
		var zs: Array = []
		for lv in lods:
			zs.append(float(lv.zscale))
		var lv = lods[_lod_index(ecam, pos, zs)]
		var wp: Array = []
		for p in lv.points:
			wp.append(pos + Vector3(p[0], p[1], p[2]))
		var mi: MeshInstance3D = goal_mis[gi]
		var origin_g := Vector3(pos.x, pos.y, -pos.z)
		mi.position = origin_g
		var im: ImmediateMesh = mi.mesh
		im.clear_surfaces()
		_emit_world_faces(im, ecam, wp, lv.faces, origin_g, true)

func _update_flags() -> void:
	var pts: Array = flag_model.points.duplicate(true)
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
		pts[8] = [fx * Glob.wind_x, 15 - fy, fx * Glob.wind_y]
	else:
		pts[8] = [1.751, 6.629, 1.751]
	var ovr := {5: flag_tex, 6: flag_tex}
	for k in range(4):
		var mi: MeshInstance3D = flag_mis[k]
		mi.visible = Glob.setup.detail.lines != 0
		var im: ImmediateMesh = mi.mesh
		im.clear_surfaces()
		if not mi.visible:
			continue
		var pos: Vector3 = flag_pos[k]
		var wp: Array = []
		for p in pts:
			wp.append(pos + Vector3(p[0], p[1], p[2]))
		var origin_g := Vector3(pos.x, pos.y, -pos.z)
		mi.position = origin_g
		_emit_world_faces(im, ecam, wp, flag_model.faces, origin_g, true, ovr)
