# Shaders of the match renderer.  Everything is drawn in the transparent pass
# with depth testing disabled: the original engine is a pure painter's-algorithm
# renderer, the draw order is reproduced with render_priority (fixed draw
# stages) and Godot's back-to-front sorting of instances (object depth sort).
#
# Colours are 8-bit palette indices: the 16 map pages live in one 1024x1024
# L8 atlas (page p at ((p%4)*256, (p/4)*256)) and are looked up in the 256x1
# match palette, applying the remapgfx/polyt rules of 3DENG.C (ASSETS.md 5.3).
class_name R3DShaders extends RefCounted

const COMMON := """
uniform sampler2D atlas : filter_nearest;
uniform sampler2D pal : filter_nearest;

vec3 srgb_lin(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
vec3 pal_col(int idx) {
	return texelFetch(pal, ivec2(idx & 255, 0), 0).rgb;
}
int page_raw(int page, ivec2 t) {
	t = clamp(t, ivec2(0), ivec2(255));
	return int(texelFetch(atlas, ivec2((page % 4) * 256, (page / 4) * 256) + t, 0).r * 255.0 + 0.5);
}
"""

# UV  = texel coordinates inside the page (0..256)
# UV2 = (mode, page)  mode: 0 flat (COLOR.r = palette index/255), 1 opaque texture
#       (polym), 2 transparent texture (polyt), 3 filter 256 (shadow), 4 filter 257
static func poly_code(cull: String, vidi: bool) -> String:
	var s := "shader_type spatial;\nrender_mode unshaded, depth_test_disabled, depth_draw_never, blend_mix, %s;\n" % cull
	s += COMMON
	if vidi:
		s += "uniform sampler2D vidi_tex : filter_nearest;\nuniform bool vidi_on = false;\n"
	s += """
varying flat vec2 info;
void vertex() {
	info = UV2;
}
void fragment() {
	int mode = int(info.x + 0.5);
	int page = int(info.y + 0.5);
	vec3 col = vec3(0.0);
	float a = 1.0;
	if (mode == 0) {
		col = pal_col(int(COLOR.r * 255.0 + 0.5));
	} else if (mode == 3) {
		col = vec3(0.0);
		a = 0.783;   /* 50% towards black in sRGB space */
	} else if (mode == 4) {
		col = vec3(194.0 / 255.0);
		a = 0.5;
	} else {
		ivec2 t = ivec2(floor(UV));
		int raw = page_raw(page, t);
		bool remap = page < 6 || page >= 10;
		int v = remap ? ((raw + 1) & 255) : raw;
		if (mode == 2) {
			if (v == 1) { discard; }
			v = (v - 1) & 255;
		}
		col = pal_col(v);
"""
	if vidi:
		s += """
		if (vidi_on && page == 8 && t.y >= 7 && t.y < 87 && t.x >= 10 && t.x < 138) {
			col = texelFetch(vidi_tex, ivec2(t.x - 10, t.y - 7), 0).rgb;
		}
"""
	s += """
	}
	ALBEDO = srgb_lin(col);
	ALPHA = a;
}
"""
	return s

# Ground (grass) + sky: one full-screen pass reproducing 3DENG.C ground()
# (software path) for whichever camera renders it.
const GROUND_CODE := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, blend_mix, cull_disabled, skip_vertex_transform;
""" + COMMON + """
uniform sampler2D sky_tex : filter_nearest;
uniform int pitch_detail = 2;
uniform bool sky_on = true;
uniform vec3 stad = vec3(190.0, 190.0, 290.0);   // st_w, st_l, st_h
uniform float main_height = 400.0;               // engine rows of the main buffer

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.5, 1.0);
}

void corner(vec3 c, vec3 E, vec3 fwd, vec3 up, inout float ye, inout float ze, inout bool first, float q, float init_ye) {
	vec3 d = c - E;
	float rz = dot(fwd, d);
	float ry = dot(up, d);
	if (first) {
		first = false;
		if (rz > 0.0) { ye = q * ry / rz; ze = rz; } else { ye = init_ye; ze = 0.0; }
	} else if (rz > ze) {
		ye = q * ry / rz; ze = rz;
	}
}

void fragment() {
	float ps = VIEWPORT_SIZE.y >= 200.0 ? VIEWPORT_SIZE.y / main_height : 1.0;
	float W = floor(VIEWPORT_SIZE.x / ps + 0.5);
	float H = floor(VIEWPORT_SIZE.y / ps + 0.5);
	float xmid = floor(W / 2.0);
	float ymid = floor(H / 2.0);
	int ix = int(floor(SCREEN_UV.x * W));
	int iy = int(floor(SCREEN_UV.y * H));        // top-down row
	vec3 g = INV_VIEW_MATRIX[3].xyz;
	vec3 E = vec3(g.x, g.y, -g.z);
	vec3 f = -INV_VIEW_MATRIX[2].xyz;
	vec3 fe = vec3(f.x, f.y, -f.z);
	float cph = length(fe.xz);
	float sph = fe.y;
	float cth = fe.z / cph;
	float sth = fe.x / cph;
	vec3 fwd = vec3(sth * cph, sph, cth * cph);
	vec3 up = vec3(-sth * sph, cph, -cth * sph);
	float q = floor(PROJECTION_MATRIX[1][1] * ymid + 0.5);
	float st_w = stad.x, st_l = stad.y, st_h = stad.z;

	// ground horizon (pitch corners at y=0)
	float yg = 0.0; float ze = 0.0; bool first = true;
	corner(vec3(-st_l, 0.0, st_w), E, fwd, up, yg, ze, first, q, -ymid);
	corner(vec3(1280.0 + st_l, 0.0, st_w), E, fwd, up, yg, ze, first, q, -ymid);
	corner(vec3(1280.0 + st_l, 0.0, -(800.0 + st_w)), E, fwd, up, yg, ze, first, q, -ymid);
	corner(vec3(-st_l, 0.0, -(800.0 + st_w)), E, fwd, up, yg, ze, first, q, -ymid);
	int ye_g = int(min(yg, ymid));
	// sky horizon (stadium box top, 200 beyond)
	float ys = 0.0; first = true;
	corner(vec3(-(st_l + 200.0), st_h, st_w + 200.0), E, fwd, up, ys, ze, first, q, ymid);
	corner(vec3(1280.0 + st_l + 200.0, st_h, st_w + 200.0), E, fwd, up, ys, ze, first, q, ymid);
	corner(vec3(1280.0 + st_l + 200.0, st_h, -(800.0 + st_w + 200.0)), E, fwd, up, ys, ze, first, q, ymid);
	corner(vec3(-(st_l + 200.0), st_h, -(800.0 + st_w + 200.0)), E, fwd, up, ys, ze, first, q, ymid);
	int ye = int(ys);
	if (float(ye) < -ymid) ye = int(-ymid);

	int y0 = int(ymid) - ye - 1;
	vec3 col = pal_col(204);
	float y = (H - 1.0 - float(iy)) - ymid;      // scan line, y up, as ground()
	float x = float(ix) - xmid;
	float t = q * sph + y * cph;
	if (iy <= y0) {
		if (sky_on) {
			int yd = ye + int(q * sph / cph);
			if (yd < 0) yd = 0;
			if (479 - yd < 240 - ye) yd = 240 + ye;
			float sa = 2.0 * 3.1415 / 3.0;
			int off = int(640.0 * acos(clamp(cth, -1.0, 1.0)) / sa) % 640;
			int base = sth < 0.0 ? 640 * (480 - yd) - off : 640 * (479 - yd) + off;
			int idx = clamp(base - 640 * (y0 - iy) + ix, 0, 640 * 480 - 1);
			col = texelFetch(sky_tex, ivec2(idx % 640, idx / 640), 0).rgb;
		}
	} else if (t < 0.0 && y < float(ye_g) && pitch_detail > 0) {
		float d = E.y / t;
		float z = d * (q * cph - y * sph);
		float X = E.x - z * sth + x * d * cth;
		float Z = E.z - z * cth - x * d * sth;
		int raw;
		if (pitch_detail == 1) {
			raw = page_raw(6, ivec2(64 + ((int(floor(Z)) >> 1) & 31), 148 + ((int(floor(X)) >> 1) & 31)));
		} else {
			raw = page_raw(6, ivec2(int(floor(Z)) & 63, 116 + (int(floor(X)) & 63)));
		}
		col = pal_col(raw);
	}
	ALBEDO = srgb_lin(col);
	ALPHA = 1.0;
}
"""
