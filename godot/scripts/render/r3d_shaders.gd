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
# screen = true: vertices are engine screen coordinates (sx, sy up, 0) of the
# camera described by `buf` (clip size) and `qf` (focal length); they are put
# back into view space at a fixed depth (the 3DENG.C player impostors are 2D).
static func poly_code(cull: String, vidi: bool, screen := false) -> String:
	var s := "shader_type spatial;\nrender_mode unshaded, depth_test_disabled, depth_draw_never, blend_mix, %s%s;\n" % [cull, ", skip_vertex_transform" if screen else ""]
	s += COMMON
	if screen:
		s += "uniform vec2 buf = vec2(640.0, 400.0);\nuniform float qf = 440.0;\n"
	if vidi:
		s += "uniform sampler2D vidi_tex : filter_nearest;\nuniform bool vidi_on = false;\n"
	s += """
varying flat vec2 info;
void vertex() {
	info = UV2;
"""
	if screen:
		s += """
	float D = 100.0;
	VERTEX = vec3((VERTEX.x - floor(buf.x * 0.5)) * D / qf, (VERTEX.y - floor(buf.y * 0.5)) * D / qf, -D);
"""
	s += """
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
uniform bool flip_y = false;         // set if SCREEN_UV had a bottom-left origin
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
	if (iy <= y0) {
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

# 3DENG.C player construction on the GPU.  Each vertex belongs to one face of
# a face list (static mesh); the vertex shader reads the 28 posed points of
# its player from `pose` (engine world coordinates), projects them with the
# engine camera (addobjy incl. the alternative perspective), builds the
# add3dcmap / add3demap impostor or the plain polygon (number patch, facing
# test) and selects the texture frame exactly like the original.
# Draw order: depth = object depth (objdep) with the polygon's average depth as
# a minor key, so a depth test reproduces "sort objects, then sortobj()".
const PLAYER_CODE := """
shader_type spatial;
render_mode unshaded, depth_draw_always, blend_mix, cull_disabled, skip_vertex_transform;
""" + COMMON + """
uniform sampler2D pose : filter_nearest;     // RGBAF 32 x 25: points 0..27, 28=(numtex,..), 29=origin
uniform sampler2D textab : filter_nearest;   // RGBAF 4 x N: (u0,v0,u1,v1) (u2,v2,u3,v3) (page)
uniform int row = 0;
uniform vec4 R0;    // r00 r01 r02 r03
uniform vec4 R1;
uniform vec4 R2;
uniform vec2 buf = vec2(640.0, 400.0);
uniform float qf = 440.0;
varying flat vec2 info;

const float SCREENDIST = 15.0;
const float CUTOFFDIST = 5.0;

vec3 proj(int k) {
	vec3 w = texelFetch(pose, ivec2(k, row), 0).xyz;
	float rx = dot(R0.xyz, w) + R0.w;
	float ry = dot(R1.xyz, w) + R1.w;
	float rz = dot(R2.xyz, w) + R2.w;
	float qrz;
	if (rz < SCREENDIST) {
		qrz = 1.5 - rz / SCREENDIST;
		qrz *= qrz;
		qrz = qf / SCREENDIST * (qrz + 0.75);
	} else {
		qrz = qf / rz;
	}
	return vec3(rz, rx * qrz + floor(buf.x * 0.5), ry * qrz + floor(buf.y * 0.5));
}

void vertex() {
	int kind = int(CUSTOM0.x + 0.5);
	int corner = int(UV2.x + 0.5);
	int col = int(round(UV2.y));
	vec4 ex = texelFetch(pose, ivec2(28, row), 0);
	vec3 org = texelFetch(pose, ivec2(29, row), 0).xyz;
	float od = dot(R2.xyz, org) + R2.w;
	bool ok = true;
	vec2 c[4];
	float pz = 0.0;
	if (kind == 3) {             // shirt number: per-player texture
		if (ex.x < 0.0) ok = false;
		col = -2000 - int(ex.x + 0.5);
	}
	bool trans = col < -2000;
	int tex = trans ? (-col - 2000) : -col;
	vec3 p1 = proj(int(CUSTOM0.y + 0.5));
	vec3 p2 = proj(int(CUSTOM0.z + 0.5));
	if (kind == 0) {
		// add3dcmap
		float w = CUSTOM1.y, L = CUSTOM1.w;
		if (min(p1.x, p2.x) < CUTOFFDIST) ok = false;
		float qa = qf * 2.0 / 100.0;
		float dx1 = p1.y - p2.y, dy1 = p1.z - p2.z;
		float dx2 = dx1 * dx1 + dy1 * dy1;
		if (dx2 == 0.0) { dx1 = 1.0; dx2 = 1.0; }
		float tz2 = w * qa / (sqrt(dx2) * (p1.x + p2.x));
		float tz1 = 100.0 * (p2.x - p1.x) / L;
		if (tz1 >= 0.0) {
			if (tz1 > 0.78062475) tex += tz1 > 0.92702481 ? 3 : 2;
			else if (tz1 > 0.48412292) tex += 1;
			tz1 *= tz2; float dy2 = tz2 * dy1; dx2 = tz2 * dx1; dy1 *= tz1; dx1 *= tz1;
			c[0] = vec2(p1.y + dx1 - dy2, p1.z + dy1 + dx2); c[1] = vec2(p1.y + dx1 + dy2, p1.z + dy1 - dx2);
			c[2] = vec2(p2.y - dx1 + dy2, p2.z - dy1 - dx2); c[3] = vec2(p2.y - dx1 - dy2, p2.z - dy1 + dx2);
		} else {
			if (tz1 < -0.78062475) tex -= tz1 < -0.92702481 ? 3 : 2;
			else if (tz1 < -0.48412292) tex -= 1;
			tz1 *= tz2; float dy2 = tz2 * dy1; dx2 = tz2 * dx1; dy1 *= tz1; dx1 *= tz1;
			c[0] = vec2(p1.y - dx1 - dy2, p1.z - dy1 + dx2); c[1] = vec2(p1.y - dx1 + dy2, p1.z - dy1 - dx2);
			c[2] = vec2(p2.y + dx1 + dy2, p2.z + dy1 - dx2); c[3] = vec2(p2.y + dx1 - dy2, p2.z + dy1 + dx2);
		}
		pz = (p1.x + p2.x) / 2.0;
	} else if (kind == 1) {
		// add3demap
		float a = CUSTOM1.y, b = CUSTOM1.z, L = CUSTOM1.w;
		vec3 p3 = proj(int(CUSTOM0.w + 0.5));
		if (min(p1.x, p2.x) < CUTOFFDIST) ok = false;
		float qa = qf * 2.0 / 100.0;
		float dx1 = p1.y - p2.y, dy1 = p1.z - p2.z;
		float rx = (p3.y - p2.y) * p3.x / qf;
		float ry = (p3.z - p2.z) * p3.x / qf;
		float dx2 = dx1 * dx1 + dy1 * dy1;
		if (dx2 == 0.0) { dx1 = 1.0; dx2 = 1.0; }
		float dy2 = sqrt(dx2);
		float tz2 = qa / (dy2 * (p1.x + p2.x));
		float tz1 = clamp((rx * dy1 - ry * dx1) / dy2, -1.0, 1.0);
		if (p3.x > p2.x) {
			if (tz1 > -0.2588) {
				if (tz1 <= 0.7071) tex += tz1 <= 0.2588 ? 9 : 10;
				else if (tz1 <= 0.9659) tex += 11;
			} else {
				if (tz1 > -0.7071) tex += 8;
				else if (tz1 > -0.9659) tex += 7;
				else tex += 6;
			}
		} else {
			if (tz1 <= 0.2588) {
				if (tz1 > -0.7071) tex += tz1 > -0.2588 ? 3 : 4;
				else tex += tz1 > -0.9659 ? 5 : 6;
			} else {
				if (tz1 <= 0.7071) tex += 2;
				else if (tz1 <= 0.9659) tex += 1;
			}
		}
		tz1 *= tz1;
		tz1 *= (a - b) * (a + b);
		dx2 = tz2 * sqrt(max(tz1 + b * b, 0.0));
		dy2 = 100.0 * (p1.x - p2.x) / L;
		float e1, e2;
		if (dy2 >= 0.0) {
			if (dy2 > 0.555570233) tex += dy2 > 0.836286155 ? 36 : 24;
			else if (dy2 > 0.195090322) tex += 12;
			dy2 *= tz2 * sqrt(max(a * a - tz1, 0.0));
			e1 = dy2 * dx1; e2 = dy2 * dy1; dx1 *= dx2; dy1 *= dx2;
			c[0] = vec2(p2.y + dy1 - e1, p2.z - dx1 - e2); c[1] = vec2(p2.y - dy1 - e1, p2.z + dx1 - e2);
			c[2] = vec2(p1.y - dy1 + e1, p1.z + dx1 + e2); c[3] = vec2(p1.y + dy1 + e1, p1.z - dx1 + e2);
		} else {
			if (dy2 < -0.258819045) tex -= 12;
			dy2 *= tz2 * sqrt(max(a * a - tz1, 0.0));
			e1 = dy2 * dx1; e2 = dy2 * dy1; dx1 *= dx2; dy1 *= dx2;
			c[0] = vec2(p2.y + dy1 + e1, p2.z - dx1 + e2); c[1] = vec2(p2.y - dy1 + e1, p2.z + dx1 + e2);
			c[2] = vec2(p1.y - dy1 - e1, p1.z + dx1 - e2); c[3] = vec2(p1.y + dy1 - e1, p1.z - dx1 - e2);
		}
		pz = (p1.x + p2.x) / 2.0;
	} else {
		// addpoly (4 points): CUTOFF and facing check
		vec3 p3 = proj(int(CUSTOM0.w + 0.5));
		vec3 p4 = proj(int(CUSTOM1.x + 0.5));
		if (min(min(p1.x, p2.x), min(p3.x, p4.x)) < CUTOFFDIST) ok = false;
		float dx1 = p1.y - p2.y, dy1 = p1.z - p2.z;
		float dx2 = p1.y - p3.y, dy2 = p1.z - p3.z;
		if (!(dx1 * dy2 < dx2 * dy1)) ok = false;
		c[0] = p1.yz; c[1] = p2.yz; c[2] = p3.yz; c[3] = p4.yz;
		pz = (p1.x + p2.x + p3.x + p4.x) / 4.0;
	}
	if (od <= 15.0) ok = false;
	tex = clamp(tex, 0, textureSize(textab, 0).y - 1);
	vec4 t0 = texelFetch(textab, ivec2(0, tex), 0);
	vec4 t1 = texelFetch(textab, ivec2(1, tex), 0);
	float page = texelFetch(textab, ivec2(2, tex), 0).x;
	vec2 uvs[4] = vec2[](t0.xy, t0.zw, t1.xy, t1.zw);
	UV = uvs[corner];
	info = vec2(trans ? 2.0 : 1.0, page);
	vec2 s = c[corner];
	float key = od + (pz - od) * 0.01;          // object major, polygon minor
	float dv = 11.0 + key * 0.01;
	if (!ok) {
		VERTEX = vec3(0.0, 0.0, 1.0);           // degenerate, behind the camera
	} else {
		VERTEX = vec3((s.x - floor(buf.x * 0.5)) * dv / qf, (s.y - floor(buf.y * 0.5)) * dv / qf, -dv);
	}
}
"""

static func player_code() -> String:
	# reuse the fragment of the polygon shader
	var frag := poly_code("cull_disabled", false)
	frag = frag.substr(frag.find("void fragment()"))
	return PLAYER_CODE + frag
