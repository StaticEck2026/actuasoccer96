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

uniform bool linear_out = false;   // true: renderer converts linear->sRGB (Forward+/Mobile)
vec3 srgb_lin(vec3 c) {
	if (!linear_out) return c;
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
		a = linear_out ? 0.783 : 0.5;   /* 50% towards black in sRGB space */
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
uniform bool flip_y = true;          // SCREEN_UV origin bottom-left (GL)
// per-camera values computed on the CPU exactly as 3DENG.C ground() does
uniform vec2 buf = vec2(640.0, 400.0);   // clip_wid, clip_hgt
uniform vec4 ang = vec4(1.0, 0.0, 1.0, 0.0);   // cth, sth, cph, sph
uniform vec3 eye = vec3(0.0);            // camera, engine coords
uniform float q = 440.0;
uniform int ye_g = 0;                    // ground limit (scan lines y < ye_g)
uniform int ye_s = 0;                    // sky limit
uniform int yd = 0;
uniform int sky_base = 0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.5, 1.0);
}

void fragment() {
	float W = buf.x;
	float H = buf.y;
	float xmid = floor(W / 2.0);
	float ymid = floor(H / 2.0);
	int ix = int(floor(SCREEN_UV.x * W));
	int iy = int(floor((flip_y ? 1.0 - SCREEN_UV.y : SCREEN_UV.y) * H));   // top-down row
	float cth = ang.x, sth = ang.y, cph = ang.z, sph = ang.w;
	int y0 = int(ymid) - ye_s - 1;
	vec3 col = pal_col(204);
	float y = (H - 1.0 - float(iy)) - ymid;      // scan line, y up, as ground()
	// hlinp2 writes each scan line right to left: step k -> pixel W-1-k
	float x = (W - 1.0 - float(ix)) - xmid;
	float t = q * sph + y * cph;
	if (iy >= 399) { col = vec3(1.0, 0.0, 0.0); } else if (iy < 0) { col = vec3(1.0,1.0,0.0); } else if (iy <= y0) {
		if (sky_on) {
			int idx = clamp(sky_base - 640 * (y0 - iy) + ix, 0, 640 * 480 - 1);
			col = texelFetch(sky_tex, ivec2(idx % 640, idx / 640), 0).rgb;
		}
	} else if (t < 0.0 && y < float(ye_g) && pitch_detail > 0) {
		float d = eye.y / t;
		float z = d * (q * cph - y * sph);
		float X = eye.x - z * sth + x * d * cth;
		float Z = eye.z - z * cth - x * d * sth;
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
