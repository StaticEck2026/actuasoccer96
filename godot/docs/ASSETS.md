# Euro 96 match render assets — formats and engine semantics

Everything under `godot/assets/` is produced by `tools/extract_assets.py`
(re-runnable, deterministic, ~20 s). It reads only `SOURCE/EUROREND.DAT/.OFF`,
`SOURCE/DATA.OBJ` and `SOURCE/3DENG.OBJ`.

**Important provenance note.** The `3DENG.C`, `FILES.C` and `DATA.H` texts in the source
release are an *older* revision (Actua Soccer, 47 teams, 117 captures). The compiled Euro 96
objects (`SOURCE/3DENG.OBJ`, `SOURCE/DATA.OBJ`, identical data in `TEST.EXE`, consistent
with `TEST.MAP`) were used as the ground truth: 16 teams, 8 stadiums, 6 skies, 132 capture
slots, plus the exact file ids of every `readfile()` (the missing `actrend.equ`). Where the
compiled code differs from the C text it is noted below.

All engine code references are to `SOURCE/3DENG.C` (function names) unless stated otherwise.

---------------------------------------------------------------------------------------------

## 1. Directory layout

```
assets/
  palettes.json            base palette + every sub-palette + composition rules + filters
  eurorend_index.json      directory of EUROREND.DAT (entry, file id, offset, size, name)
  teams.json               16 Euro 96 teams -> files, palettes, exported components
  stadiums.json            8 venues (stadlist): pitch/sky/stands/bounds/camera spots
  skies.json               6 skies + pitch tiles
  textures/
    textures.json          texture table (TMD_TEXDATA 1..1006 + TMD_STADIUM 1004..1052)
    pages.json             recipe to assemble the 16 indexed 256x256 map pages of a match
    indexed/*.png          every bitmap of EUROREND.DAT as 8-bit index images ('L' mode)
    pages/indexed/*.png    fixed / template pages (indexed)
    teams/NN_Name/         per-team components: indexed/*.png (palette-slot ready) + RGBA
    example_match/         England (A) v Germany (B), London, sky 0: all 16 pages indexed,
                           RGBA '_t' (transparent decode) and '_m' (opaque decode), palette.png
    sky/sky0..5.png        640x480 RGB sky panoramas (with their own palettes)
    pitch/*.png            grass tiles (64x64 hi detail, 32x32 lo detail) per pitch+palette
  models/*.json            meshes (ball, goals, lines, flags, shadows, highlights, stands, player)
  mocap/mocap.bin|json     all motion capture frames + capture table
```

---------------------------------------------------------------------------------------------

## 2. Coordinate systems and units

### 2.1 Game logic (3D_UPD2.CPP, ACTIONS.CPP ...)
* `x` 0..1280 along the pitch (`pitch_len`), `y` 0..800 across (`pitch_wid`), `z` = height.
* Goals at x=0 and x=1280, centred on y=400. Facing of a player = unit vector
  `(tm_xdis, tm_ydis)` in the x/y plane.
* Units: players are ~24 units tall, goal is 37 high x 87 wide (real 2.44 m x 7.32 m) so
  **1 unit ≈ 6.6–8.4 cm**; use 1 unit = 1/12 yard (≈ 7.6 cm) if a metric scale is needed.
  The pitch (1280 x 800 units) is ~97 m x 61 m.

### 2.2 Engine world (render3d)
`plyrdat` (built by `pass_coords`/`realtime_coords`) holds `x = game x`, `y = game z
(height)`, `z = game y`. `render3d` then places objects at **engine world**
`X = game x, Y = height, Z = -game y`. All `position_engine` values and all model points in
the JSON files are in engine space. The engine space is **left-handed** (X right, Y up, Z into
the screen for a camera looking along +Z); this was verified by rendering (shirt numbers read
correctly, right-footed kicks use the right leg).

### 2.3 Godot (right-handed, Y up)
Use the simple mapping

```
Godot = (game_x, game_z(height), game_y)  ==  (X_engine, Y_engine, -Z_engine)
```

i.e. negate the Z of every exported point / `position_engine`. (`stadiums.json` already
contains `position_godot` for the stands.) This mapping flips handedness (LH -> RH) so the
picture is identical to the original. Visible polygons in the engine are those whose screen
projection is **clockwise** (`addpoly`: `dx1*dy2 < dx2*dy1` with screen y up); Godot also
treats clockwise (on screen) as front, so keep the vertex order and use back-face culling
after converting points with `z = -z`.

### 2.4 Object placement
Objects are `obj {points, faces, x, y, z, crot, srot}`; the add routines transform a local
point `p=(px,py,pz)` to engine world as

```
addobjn/addobjnc/addobjf/addobjfc (no rotation):  W = p + (x, y, z)
addobjy/addobjyc (yaw):   Wx = x + crot*px + srot*pz
                          Wy = y + py
                          Wz = z - srot*px + crot*pz
addobjyf (players with mirrored anim): as addobjy with pz := -pz
addobjxy (ball): W = (x,y,z) + M p,  M columns (local x, y, z) =
     ( crot, 0, -srot ), ( -srot*sx, cx, -crot*sx ), ( srot*cx, sx, crot*cx )
     with cx = plyrdat.frame (= cos ball_vert_ang), sx = plyrdat.fstep (= sin ball_vert_ang),
     crot/srot = plyrdat crot/srot (= cos/sin(ball_horz_ang - pi/2))
```

**Players** (`render3d`): `x = plyr.x, y = plyr.y, z = -plyr.z, crot = -plyr.crot,
srot = plyr.srot`. Since `realtime_coords` stores `plyr.crot = -tm_xdis`, `plyr.srot =
tm_ydis`, the object yaw is simply `crot = tm_xdis, srot = tm_ydis` (the game facing vector).
In Godot coordinates a capture point `(px,py,pz)` (pz negated first if the anim is mirrored)
of a player at game position `(gx,gy,gz)` facing `(fx,fy)` = `(tm_xdis,tm_ydis)` is:

```
G.x = gx + fx*px + fy*pz
G.y = gz + py
G.z = gy + fy*px - fx*pz
```
Capture local axes: **+x = facing, +y = up, +z = the player's left**.
Players whose object depth (`objdep`) is < 15 units are not drawn.

### 2.5 Camera (3D_UPD2.CPP `update_3d` -> `render3d`)
```
render3d(buf, viewx=cam_x, viewy=cam_z(height), viewz=cam_y,
              targx=tx,     targy=tz(height),   targz=ty, vdist=scale, ...)
```
* Godot camera position = `(cam_x, cam_z, cam_y)`, look-at = `(tx, tz, ty)`, no roll
  (the view matrix is built from yaw `atan2(dx, dz)` and pitch only; if the horizontal
  distance < 1 the target is nudged: `targz = 1`).
* Focal length in pixels: `q = vdist * (buf.scale_x + buf.scale_y) / 2`.
  Projection: `sx = rx*q/rz + clip_wid/2`, `sy = ry*q/rz + clip_hgt/2` (**sy up**).
  Horizontal FOV = `2*atan((clip_wid/2)/q)`, vertical = `2*atan((clip_hgt/2)/q)` in buffer
  pixels. The default 320x200 buffer has scale 0.5 (q = vdist/2), 640x400 has 1.0, 640x480 has
  scale_x 1, scale_y 1.2 (q = 1.1*vdist). The original pixels are not square (320x200 or
  640x400 shown at 4:3), so for an identical picture on a 4:3 screen use
  `vertical_fov = 2*atan(100/(vdist*0.5))` (320x200 case) and let the viewport stretch, or
  equivalently scale projection Y by 1.2 relative to a square-pixel camera with
  `hfov = 2*atan(160/(vdist*0.5))`.
* `INIT_SCALE` (default `scale`) = **440.0**; the isometric camera uses 1024. `scale` is
  tweened between frames like the camera position.
* Near handling: points with view depth < 15 (`SCREENDIST`) are clipped (or squashed with
  the "alternative perspective" for unclipped objects); polygons with all depths < 5
  (`CUTOFFDIST`) are rejected.
* Draw order (painter's algorithm, no z-buffer): ground + sky; far stands (only stands whose
  front faces the camera, tests `vs1..vs4`); pitch markings, player shadows, ball shadow and
  highlights **without sorting** (decals on the grass); then players, ball, goals, flags
  and speech sprites sorted per object (object depth) and per polygon (average depth).
  In Godot: draw markings/shadows/highlights as ground decals (no depth write, render
  priority after the grass), everything else with normal depth testing.

---------------------------------------------------------------------------------------------

## 3. EUROREND.DAT

`EUROREND.OFF` = 229 x `(int32 offset, int32 size)`. The engine's file ids are `entry*8`
(`readdatafile` uses `load_offsets[id/8]`, C division, so `-1` reads entry 0).
`eurorend_index.json` names every entry. Summary:

| entries | content |
|---|---|
| 0 | PAL_FOOTY base palette (768 bytes, 6-bit VGA) — identical to `FOOTY.PAL` |
| 1 | TMD_TEXDATA, 1006 textures (32192 bytes) loaded at `textures[1]` |
| 2 | TMD_MANDATA (= `MANDATA.TMD`), front-end only |
| 3–7 | BM_HEAD_3..7: five head sheets 256x128 (skin 80..87, hair 2..11) |
| 8–23 | BM_TORSO_<team> 256x256 (16 torsos, one per Euro team) |
| 24–33 | BM_LIMBS 256x78 (entries 26, 33 unreferenced) |
| 34 | BM_FEET 256x67 |
| 35 | BM_REFKPTOR 256x256 referee/keeper/linesman torsos |
| 36 | BM_EXTRA1 256x62 (highlight markers) |
| 37 | BM_EXTRA3 256x256 |
| 38 | BM_XLIMBS 256x256 (dark-skin limbs/heads base page) |
| 39 | BM_XRFKPLIM 256x256 (ref/keeper/linesman limbs, second skin slot) |
| 40 | BM_NETS 256x256 (net, ball panels) |
| 41, 42 | BM_STAND1, BM_STAND2 stadium texture pages |
| 43–58 | COL_KIT_<team> 24 colours -> pal[32..55] (team A) / pal[56..79] (team B) |
| 59–63 | COL_SKIN 8 colours -> pal[80..87] (A) / pal[88..95] (B) |
| 64–72 | COL_PITCH 16 colours -> pal[128..143] |
| 73–77 / 79–83 | COL_HOME / COL_AWAY 8 colours -> pal[224..231] / pal[232..239] (78, 84 unused) |
| 85–90 | COL_SKY0..5 16 colours -> pal[208..223] |
| 91–96 | BM_SKY0..5 640x480 |
| 97–99, 117–120 | 3D Blaster skies / pitch (not used by the software renderer) |
| 100–105, 106–107 | BM_KGRID1..6 (9 kits 70x83), BM_KGRIDS1..2 (42 small kits) — Actua WC kits |
| 108 | BM_REFKPLIM 256x256 referee/keeper limbs |
| 109–112 | BM_NUMBERS 256x54 shirt numbers (111 unreferenced) |
| 113–116 | BM_PITCH 256x64 (grass tile + extras) |
| 121 | BM_EXTRA2 256x76 |
| 122–124 | unreferenced bitmaps |
| 125 | TMD_STADIUM 49 textures loaded at `textures[1004]` |
| 126–133 | PTS/FCE_STAND1..4 (point lists / face lists of the 4 stands) |
| 134–228 | MPB motion capture (85 floats per frame); 206 = JUGGLE (front-end) |

---------------------------------------------------------------------------------------------

## 4. Palette (`palettes.json`)

The VGA palette is 6-bit; `rgb = (v*255+31)//63`. A match palette is composed in
`init3d` (order matters, later writes win):

```
pal = PAL_FOOTY                       (entry 0)
pal[32..55]   = kit palette of team_a        pal[56..79] = kit palette of team_b_kit
pal[80..87]   = skin palette of team_a       pal[88..95] = skin palette of team_b
pal[128..143] = stadium pitch palette
pal[224..231] = HOME palette of team_a       pal[232..239] = AWAY palette of team_b
pal[208..223] = sky palette
```
Colours 96..103 (base palette) are the "dark skin" ramp used by the `*_dark` pages.
Flat-shaded faces whose colour index lies in a replaced range are flagged
`"palette_dependent": true` in the model JSON (their `"color"` is only the base palette value).

Filters (translucent polygons, `col` 256/257): `makefilter` builds a 256->256 table mapping
each colour to the nearest palette entry (of 0..239) of a 50% blend:
* **256 = shadow**: 50% towards black (player/ball shadows).
* **257**: 50% towards VGA (48,48,48) = rgb(194,194,194) (goal-frame shading). Faces with
  `col >= 512` ("looping" textures) are drawn as 257 by the software renderer.

---------------------------------------------------------------------------------------------

## 5. Textures

### 5.1 Texture records (`textures/textures.json`)
`texture = dword[8]`. For a polygon/billboard with `np` vertices the first `np` dwords are
**V (row)** and the next `np` dwords are **U (column)**, each 16.16 fixed point in texels of a
256x256 page; bits 24..31 of the V dwords hold the **map page** (0..15). The engine clears the
low byte. Vertex `k` of the polygon gets `(u[k], v[k])`. `textures.json` gives `u,v`
(4-vertex split) and `u3,v3` (triangle split) in texels; divide by 256 for normalised UVs
(origin = top-left of the page, v down). Values like `29.996` are the inclusive right/bottom
texel edge (`0x1dffff`). Model faces carry their resolved `page` + `uv` already.

Index ranges (by page):

| textures | page | use |
|---|---|---|
| 1–60 / 61–120 | 0 | head A / head B: 12 view angles x 5 elevations; billboard base 13 / 73 |
| 121–180 / 181–240 | 1 / 2 | torso A / B (base 133 / 193) |
| 241–268 / 269–296 | 3 | limbs A / B: 7 tilt frames each of lower leg, upper arm, upper leg, lower arm (bases 244, 251, 258, 265 / 272, 279, 286, 293) |
| 297–356 | 3 | feet (base 309) |
| 357–416 / 417–476 | 4 | referee torso (369) / goalkeeper A torso (429) |
| 477–532 | 5 | referee limbs (480,487,494,501) / keeper A limbs (508,515,522,529) |
| 533–548 | 6 | player highlight markers (stars, circles, squares, triangles) |
| 549–563 / 564–578 | 6 | shirt numbers 1–15 team A / team B |
| 579–581 | 6 | corner flag cloth (3 wind frames, triangles) |
| 585–644 / 645–704 | 10 / 11 | dark-skin torso A / B (597 / 657) |
| 705–808 (+809–820) | 12 (13) | dark-skin limbs A/B (708.. / 736..), dark-skin heads (base 773) |
| 809–876 | 13 | linesman limbs (824..845), keeper B limbs (852..873) |
| 877–996 | 14 | linesman torso (889), keeper B torso (949) |
| 997–1001 | 15 | nets (997–1000), ball panel (1001, unused LOD) |
| 1004–1052 | 8, 9 | stadium textures (TMD_STADIUM) |

### 5.2 Map pages and their assembly (`textures/pages.json`)
The renderer works on 16 pages of 256x256 8-bit texels (`maps[0..15]`, M8 mode):

| page | content |
|---|---|
| 0 | rows 0–127 head sheet of team A, rows 128–255 head sheet of team B |
| 1 / 2 | torso A / torso B |
| 3 | rows 0–77 limbs A, 80–157 limbs B, 158–224 feet |
| 4 / 5 | ref+keeper torso / limbs (skin slot A) |
| 6 | EXTRA1 (rows 0–61), numbers A (62–88), numbers B (89–115), rows 116–179: grass tile cols 0–68, numbers B lower half cols 69–160, numbers A lower half cols 161–252; EXTRA2 rows 180–255 |
| 7 | EXTRA3 + kit grids (not referenced by any texture) |
| 8 / 9 | stand pages (page 8 rows 7–86, cols 10–137 = the 128x80 "vidi" video-wall render target) |
| 10 / 11 | torso A / B with dark skin |
| 12 | XLIMBS base + dark limbs A (0–77) / B (80–157) + dark heads |
| 13 / 14 | ref/keeper/linesman limbs / torso with skin slot B |
| 15 | nets |

Palette-slot remapping done by init3d (already applied to the exported `_B` / `_dark`
components): team-B pieces add 24 to kit indices 32..55 and 8 to skin indices 80..87; dark
pieces add 16 to skin indices (team B dark: +24 kit, +16 skin); pages 13/14 add 8 to skin;
the team-B number regions use the off-by-one ranges `(32,56]` and `(80,88]`.

`pages.json` lists ordered blit ops (`src`, optional `src_rect [x,y,w,h]`, `dst [x,y]`,
clip at 256) with placeholders `{A}`, `{B}` (team component dirs from `teams.json`) and
`{PITCH}` (stadium pitch bitmap name). The extractor verifies that the recipe reproduces its
own emulation of `init3d` byte for byte. Uninitialised regions are 0.

### 5.3 Decoding texels to colours (transparency rules)
`setscreen` runs `remapgfx(+1)` on pages 0–5 and 10–15 (every texel +1, mod 256). Then:
* **`polyt` (transparent mapper, faces with `col < -2000`, kind `transparent` /
  `tex_mode: transparent`)**: texel value 1 is transparent, any other value `t` is drawn as
  colour `t-1`.
  → pages 0–5,10–15: raw 0 = transparent, colour = pal[raw];
  → pages 6–9: raw 1 = transparent, colour = pal[raw-1].
* **`polym` (opaque, `-2000 < col < 0`, kind `tex`)**: draws pal[t] → pal[raw+1] on pages
  0–5,10–15 (only the unused textured-ball LOD does this), pal[raw] on pages 6–9 (stands).

`example_match/pageNN_t.png` / `_m.png` are these two decodes; `teams/*/*.png` (RGBA) are
the transparent decodes of the team pieces with the team's own palette (the RGB is the same
whether the team plays as A or B). For full fidelity use the indexed pages + a palette
lookup shader (`texelFetch` the index, apply the rule above, look up a 256x1 palette).
Sampling is point-sampled (nearest).

### 5.4 Other images
* `sky/skyN.png`: 640x480. Software drawing (`ground()`): the panorama repeats 3 times per
  360° (`sa = 2π/3`): column offset `off = int(640*acos(cth)/sa) % 640`, taken as `+off`
  when `sth >= 0`, `640-off` otherwise (cth/sth = cos/sin of camera yaw; yaw 0 = looking
  along +Z engine = -y game). Vertically, `ye` = highest screen y (y up) of the 4 corners
  `(-(st_l+200) | 1280+st_l+200, st_h, st_w+200 | -(800+st_w+200))`, `yd = max(0, ye +
  q*sph/cph)` (if `479-yd < 240-ye` then `yd = 240+ye`); sky row `479-yd` is drawn on the
  screen line just above `ye` and the rows above it come from the rows above in the image
  (1 sky pixel = 1 screen pixel, no scaling). Without sky detail the area is filled with
  colour 204.
* `pitch/*_tile64.png` / `_tile32.png`: grass. `ground()` covers the whole ground plane up
  to the stadium horizon with the tile: hi detail texel = `tile64[floor(X) & 63][floor(Z) &
  63]` (row from engine X = game x, column from engine Z = -game y, 1 texel = 1 unit); lo
  detail `tile32[(floor(X)>>1)&31][(floor(Z)>>1)&31]`. With `detail.pitch == 0` the flat
  `pitch_simple` model is drawn instead.

---------------------------------------------------------------------------------------------

## 6. Models (`models/*.json`)

Common format:
```json
{"points": [[x,y,z], ...],            // engine object-local space (see 2.4)
 "faces":  [ {...}, ... ] }           // drawing order = list order (sorted by depth at runtime)
```
or, for objects with levels of detail, `{"lod": [{"zscale", "reachable", "points_name",
"faces_name", "points", "faces"}, ...]}`. LOD choice (`objdepd`): `zq = depth_of_origin / q`
(0 if behind); take the **first** level with `zscale <= zq` (so the first entries are the far
levels). Levels after the first `zscale == 0` are never used (`reachable: false`).

Face fields (`col_raw` = the original word):

| kind | engine meaning | fields |
|---|---|---|
| `flat` | `0 <= col < 256` solid colour (polygon `np>2`) | `v`, `color_index`, `color`, `palette_dependent?` |
| `line` | `np == 2` 1-pixel line | `v`, `color_index` |
| `filter` | `col 256/257` translucent filter (see §4); `>=512` drawn as 257 | `v`, `filter` (0/1) |
| `tex` | `-2000 < col < 0`, opaque texture `-col` (`polym`) | `v`, `tex`, `page`, `uv` (texels) |
| `transparent` | `col < -2000`, texture `-col-2000` (`polyt`) | as `tex` |
| `cyl_billboard` | `np == 0`: limb impostor | `v=[p1,p2]`, `width`, `length`, `tex`, `tex_mode` |
| `ellipse_billboard` | `np` other (−1): head/torso/foot impostor | `v=[p1,p2,p3]`, `a`, `b`, `length`, `tex`, `tex_mode` |

Files:
* `ball.json` — LODs `footys` (far: a 2-point line), `footy_f` (60 points, 32 flat faces),
  `footy_fb` (unreachable textured version). Radius ≈ 1.75; ball origin = centre.
* `ball_shadow.json` (filter 256 hexagon at `(ball.x, 0, -ball.z)`, or at the motion-captured
  ball position), `player_highlights.json` (`plshad` = player shadow hexagon, `plhi` =
  21.6-unit quad; `table[htype][hcol]` faces; htype 0 = shadow, drawn when htype==0;
  htype 3 and 4 are rotated with `crot = plyr.crot, srot = -plyr.srot` (addobjyc), others
  unrotated; htype 4 and 6 blink: visible while `hcoo >= 2` where `hcoo += log_factor` mod 4).
* `goals.json` + `goal_goal{1..4}_{a,b}.json` — 4 pieces per goal (two side nets, roof,
  back) with 5 LODs; `goals.json` gives positions (end 1 at x=0, end 2 at x=1280).
* `pitch_lines.json` + `lines_*.json` — penalty boxes (l1..l4), halfway line (l5,l6),
  centre circle, the two penalty arcs, three spots; all y=0, line width 2.4.
* `flag.json` — corner flag (4 positions). Wind (`render3d`): point 8 (flag tip) =
  `(fx*wind_x, 15-fy, fx*wind_y)` with `fs = (π/2)*(wind_speed+16)/144`, `fx = 8.5*sin(fs)+1`,
  `fy = 8.5*cos(fs)`; no wind: `(1.751, 6.629, 1.751)`. With wind the cloth texture of faces
  5 and 6 cycles 579→580→581→579 every `(128-wind_speed)/10` log_factor ticks.
* `pitch_simple.json` — low-detail pitch (see note in the file).
* `stadium_stand1..4.json` — the stands, `position_engine` = placement (no rotation; the
  geometry is pre-rotated). Texture indices are already offset to the global table
  (`tex >= 1004`); pages 8/9 are drawn opaque, a few transparent faces exist.
* `player.json` — see §7.

---------------------------------------------------------------------------------------------

## 7. Players

### 7.1 Points (28 per frame, `mocap.json: point_names`)
```
 0 head_top           1 head_back_marker   2 chest_back_marker   3 neck        4 pelvis
 5 l_shoulder  6 l_elbow  7 l_hand          8 r_shoulder  9 r_elbow  10 r_hand
11 l_toe      12 r_toe
13 l_hip  14 l_knee  15 l_ankle  16 l_instep     17 r_hip  18 r_knee  19 r_ankle  20 r_instep
21 l_foot_side_marker  22 r_foot_side_marker
23 ball (y = -10000 when the capture has no ball)
24 number_r_top  25 number_l_top  26 number_r_bottom  27 number_l_bottom   (shirt-number patch)
```
"marker" points sit ~1 unit behind/beside the body point and only orient the billboards.
**Head = 0 (top) / 3 (neck), hands = 7 / 10, feet: toes 11 / 12, ankles 15 / 19.**
Mirror pairs (`mirror_swap`): 5↔8, 6↔9, 7↔10, 11↔12, 13↔17, 14↔18, 15↔19, 16↔20, 21↔22,
24↔25, 26↔27.

### 7.2 Face lists and which one to use
`player.json: facelists` holds the 15 lists; `playertypes` (22 entries) is the engine table:

```
k = plyr.type                  (1 team A, 2 team B, 3 referee, 4 linesman; 0 = not drawn)
if player index i is 0 or 11 (goalkeepers):
      k = (type==1 or !M8) ? 5 : 15
elif game_data[team].players[i%11].skin_tone != 0 (and M8):  k += 10      (dark skin)
if anim is mirrored: k += 5
faces = playertypes[k]
```
→ `player_f1/f2` (team A/B), `player_fr` referee (head A, ref torso/limbs, skin A),
`player_fl` linesman (head B, pages 13/14, skin B), `player_fg1/fg2` keepers A/B,
`*b` dark-skin variants, `*x` mirrored variants (identical except the number-patch vertex
order), `player_fw` wireframe (unused).

Each list = 13 faces: 0 head (ellipse, points 3,0,1), 1 torso (ellipse 4,3,2), 2/3 feet
(ellipse 11,16,21 / 12,20,22), 4–7 arms (cylinders 5-6, 6-7, 8-9, 9-10), 8–11 legs
(cylinders 13-14, 14-15, 17-18, 18-19), 12 shirt number (transparent quad 25,24,26,27).
**Shirt number:** for players 0..21 the number face texture is overwritten:
team A `X_TM+16+(n-1)` = 549+n-1, team B 564+n-1 (n = 1..15, `col = -(2000+tex)`); with
`detail.players == 0` only the first 12 faces are drawn. Referee/linesmen have 12 faces.

### 7.3 Billboard impostors (exact algorithm)
All limbs/heads/torsos/feet are view-dependent sprites computed **in screen space** after
projecting the face's points. Let each projected point be `(z, x, y)` = (view depth, screen
x, screen y up) and `qa = q*2/100`. The resulting quad's 4 corners are assigned texture
vertices 0..3 in the order given; the texture index starts at `base = tex` (from the face)
and is offset as described (`tex_range` in the face gives the full frame range). The quad
is drawn like a 4-point `polyt` polygon but **without** a facing test (billboards are never
culled; they are only rejected when `min(p1.z, p2.z) < 5`).

**Cylinder** (`cyl_billboard`, points p1,p2, `width w`, `length L`):
```
dx1,dy1 = p1.xy - p2.xy ; d2 = dx1²+dy1² (if 0: dx1=d2=1)
tz2 = w*qa / (sqrt(d2)*(p1.z+p2.z))          # half width per unit of axis length
tz1 = 100*(p2.z-p1.z)/L                      # sine of tilt towards the camera
if tz1 >= 0: tex += 3 if tz1>0.92702481 else 2 if tz1>0.78062475 else 1 if tz1>0.48412292 else 0
             e = tz1*tz2
             corners = p1+ (dx1*e - dy1*tz2, dy1*e + dx1*tz2), p1+(dx1*e + dy1*tz2, dy1*e - dx1*tz2),
                       p2+(-dx1*e + dy1*tz2, -dy1*e - dx1*tz2), p2+(-dx1*e - dy1*tz2, -dy1*e + dx1*tz2)
else:        tex -= 3 if tz1<-0.92702481 else 2 if tz1<-0.78062475 else 1 if tz1<-0.48412292 else 0
             e = tz1*tz2
             corners = p1+(-dx1*e - dy1*tz2, -dy1*e + dx1*tz2), p1+(-dx1*e + dy1*tz2, -dy1*e - dx1*tz2),
                       p2+( dx1*e + dy1*tz2,  dy1*e - dx1*tz2), p2+( dx1*e - dy1*tz2,  dy1*e + dx1*tz2)
```
**Ellipse** (`ellipse_billboard`, points p1,p2,p3, radii `a`,`b`, `length L`; p3 is the
orientation marker one unit from p2):
```
dx1,dy1 = p1.xy-p2.xy ; d2 = dx1²+dy1² (if 0: dx1=d2=1) ; len = sqrt(d2)
rx,ry   = (p3.xy - p2.xy) * p3.z / q             # back to view-space units
tz2 = qa/(len*(p1.z+p2.z))
s = clamp((rx*dy1 - ry*dx1)/len, -1, 1)          # sine of rotation about the axis
angle offset (added to tex):
  if p3.z > p2.z:  s>-.2588: (s<=.2588: 9 | s<=.7071: 10 | s<=.9659: 11 | else 0)
                   else:      (s>-.7071: 8 | s>-.9659: 7 | else 6)
  else:            s<=.2588: (s>-.2588: 3 | s>-.7071: 4 | s>-.9659: 5 | else 6)
                   else:      (s<=.7071: 2 | s<=.9659: 1 | else 0)
k   = s²*(a²-b²)
w   = tz2*sqrt(k + b²)                           # half width (ellipse section a/b)
t   = 100*(p1.z-p2.z)/L                          # axis tilt
if t >= 0: tex += 36 if t>0.836286155 else 24 if t>0.555570233 else 12 if t>0.195090322 else 0
           h = t*tz2*sqrt(a²-k);  ex,ey = h*dx1, h*dy1;  px,py = dx1*w, dy1*w
           corners = p2+(py-ex, -px-ey), p2+(-py-ex, px-ey), p1+(-py+ex, px+ey), p1+(py+ex, -px+ey)
else:      tex -= 12 if t < -0.258819045 else 0
           h = t*tz2*sqrt(a²-k);  (same ex,ey,px,py)
           corners = p2+(py+ex, -px+ey), p2+(-py+ex, px+ey), p1+(-py-ex, px-ey), p1+(py-ex, -px-ey)
```
(`h` is negative in the second branch; the formulas are copied from `add3demap`.) So a
head/torso/foot set is 5 elevation rows x 12 rotation frames (base = 2nd row), and a limb
set is 7 tilt frames (base = middle). Depth for sorting: `(p1.z+p2.z)/2`.

In Godot this is easiest done each frame on the CPU (ImmediateMesh / ArrayMesh in view or
clip space) or in a vertex shader that receives p1/p2/p3 per quad.

### 7.4 Animation, frames, mirroring, tweening
`mocap/mocap.bin`: float32 LE, 85 floats per frame; float 0 = 28.0 (the point count — the
engine's point lists start with a count), floats 1..84 = 28 x (x,y,z).
`mocap/mocap.json: captures[id]` (`id` = `MC_*` value 0..131 = `plyrdat.anim`):
`start` (frame index into mocap.bin), `frames`, `mirror`, `source_id`; `stored_frames` is
the mcaps8 count (0 for mirrored / unused slots); `frames_4mb` is the 4 MB-mode table (its
MP4 data is not in EUROREND.DAT). Ids 0..116 have the DATA.H names; 117..131 are Euro-only
captures (`MC_EURO_*`, names unknown). The last record is JUGGLE (front-end, not in the
match table). `start` values reproduce init3d's `cappts` accumulation exactly.

* **Frame**: `frame = start + int(plyr.frame * frames)` with `plyr.frame` in [0,1).
* **Mirroring** (compiled rule): anim `an` is mirrored if `an & 1` and
  (`8 <= an <= 69` or `an >= 128`): use the captures of `an-1` and negate z of every point
  (`addobjyf`), and use the `*x` face list. Mirrored captures are **not** pre-generated in
  mocap.bin (flagged with `mirror: true`, `start`/`frames` of the source).
* **Motion-captured ball**: if point 23 has `y >= 0`, the ball is drawn at that point
  (transformed like the player, z negated when mirrored) instead of its game position, and
  the ball shadow uses it too.
* **Tweening between anims** (`plyrtwtb`, per player): when `anim` changes, the engine blends
  from the last displayed pose (`twnfrm`) to the current frame of the new anim:
  `tween` starts at 0 and grows by `tstep = plyr.fstep*2*log_factor` per rendered frame;
  pose = `new*tween + old*(1-tween)` per coordinate until `tween >= 1`. If the anim changes
  again mid-tween, the current blended pose becomes the new start. If exactly one of the
  two anims is mirrored, the old pose is first converted: points are swapped with
  `mirror_swap` and their z negated (point 23 is taken from the new frame if the old one has
  no ball). (`log_factor` = elapsed game ticks per rendered frame.)
* Frame interpolation in time is done by the game (`realtime_coords` tweens `frame` between
  logic updates with `mf_scale`), not by blending capture frames.

### 7.5 Textures of a player
All player textures are drawn with `polyt` (transparent). Pages and bases per list are in
`player.json`/§5.1. Skin palette: heads/limbs of team A use slots 80..87, team B 88..95,
dark skin 96..103; referee uses team A's skin, linesmen team B's skin (as in the original).

---------------------------------------------------------------------------------------------

## 8. Teams, stadiums, skies

* `teams.json` — per team: `head_entry` (one of 5 head sheets), `torso_entry`,
  `limbs_entry`, `numbers_entry` (number style), kit/skin/home/away palette entries and RGB,
  the exported components (`components.indexed` for the page recipe, `components.rgba` for
  direct use) and the kit-grid cells. In a match, team A uses `teamlist[team_a]` for
  everything; team B uses `teamlist[team_b]` for head, skin and AWAY palette and
  `teamlist[team_b_kit]` for torso, limbs, numbers and kit palette.
* `stadiums.json` — the 8 venues (`EURODEFS.H` order London, Birmingham, Leeds, Newcastle,
  Manchester, Liverpool, Sheffield, Nottingham): pitch bitmap/palette, `skytypes` (the sky is
  `skytypes[frame_counter & 1]`), stand pages, the 4 stands with placement, `st_w/st_l/st_h`
  (stadium half-margins and height; also used for the ball bounds in BALL.CPP), video screen
  / tunnel camera spots `vid1, vid2, tunl` (engine coords: 3D_UPD2 uses `x, -z, y` as game
  x, y, z), `vmap` (FAP animation offset into page 8).
* `skies.json` — 6 skies (image + 16-colour palette at slot 208) and the pitch tiles.

---------------------------------------------------------------------------------------------

## 9. Open issues / things not resolved

1. **Kit art does not match Euro 96 teams.** The Euro teamlist (compiled, identical in
   TEST.EXE) points to torso/kit-palette files whose art is clearly the Actua Soccer World Cup
   set (e.g. team 0 "Bulgaria" gets a stars-and-stripes torso, England a red kit). This data
   file is probably a development snapshot; the extraction is faithful to it.
2. **`setup.team_b_kit` is never assigned by the Euro 96 front end** (no store in any
   object; `setup` is zero-initialised) so team B would wear team 0's kit. Treat
   `team_b_kit = team_b` unless the shipped executable shows otherwise. There is no
   separate away-kit art in the data.
3. **Stadium textures for 5 venues**: `tmdfile = -1` for venues 1,3,5,6,7, which makes
   init3d load entry 0 (the palette) as stadium texture records. All venues share the same
   stands, so `TMD_STADIUM` (entry 125) is used for all.
4. Names of the Euro-only captures 117..131 are unknown (`MC_EURO_*`).
5. The pitch tile orientation (row = X, column = Z) was read from the scanline assembler and
   cannot be checked visually because the grass tile is a symmetric check pattern.
6. Speech sprites, menus, the radar/scanner, FAP video-wall animations and the 3D Blaster
   path are not part of this export (different files / not render data).
7. Uninitialised page areas (page 3 rows 78–79 and 225–255, etc.) are exported as 0.
8. Head/torso billboards: which of the 12 rotation frames is "front" is fully determined by
   the algorithm in §7.3; no semantic labels were assigned to the frames.
