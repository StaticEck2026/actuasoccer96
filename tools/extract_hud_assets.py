"""Extract the data used by the 2D in-match overlay of 3DENG.C (menus, banners,
fonts, scanner, clock/score line) into godot/assets/hud/.

The overlay draws with draw_sprite()/draw_string() from the "extra" map pages
maps[X_BM] and maps[X_BM+1] (pages 6 and 7) using the tables of FGFX.C
(spr_data[], font_data[]); font glyphs that are out of range read further into
memory, so pages 8 and 9 (the stand pages that follow in the same allocation)
are exported too. Pages 6-9 are match dependent (shirt numbers / kit grids of
the two teams, pitch tile and stand pages of the stadium), exactly as init3d
assembles them (emulated by tools/extract_assets.py PageBuilder).

Outputs (all indexed images are 8-bit 'L' PNGs holding the raw texel values):
  hud/xpages_base.png      256x1024: pages 6..9 of a reference match (team 0 v
                           team 0, stadium 0); team/stadium regions are replaced
                           at run time with the pieces below.
  hud/team_NN.png          256x160: the regions of page 6/7 written for team NN
                           as team A and as team B (see hud.json "team_pieces").
  hud/stadium_N.png        256x576: page 6 rows 116..179 + pages 8, 9 of venue N
                           (see hud.json "stadium_pieces").
  hud/hud.json             tables: compiled FGFX tables (spr_data, font_data
                           checked against 3DENG.OBJ), palettes (6-bit VGA) for
                           the init3d palette composition, the in-game texts of
                           SCRIPT.96 (Text[] of the front end: GetTEXT /
                           GetPLAYERSname) as CP437 byte lists.

Usage: python3 tools/extract_hud_assets.py [--src SOURCE] [--out godot/assets/hud]
"""
import argparse
import json
import os
import re
import struct
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from extract_assets import (Dat, ObjData, read_tables, PageBuilder, X_BM, S_BM,  # noqa: E402
                            EURO_TEAMS, EURO_VENUES)

ROOT = os.path.dirname(HERE)

# Regions of pages 6/7 that init3d writes per team (page, x, y, w, h), as left by
# the init3d copies (see PageBuilder.build): team A / team B roles.
TEAM_PIECES = {
    "A": [(6, 0, 62, 256, 27),     # shirt numbers 1..11 (top half of the numbers file)
          (6, 161, 116, 92, 27),   # bottom half (numbers 12..15) of the A numbers file
          (7, 0, 0, 69, 79),       # big kit (BM_KGRID cell)
          (7, 220, 111, 35, 40)],  # small kit (BM_KGRIDS cell)
    "B": [(6, 0, 89, 256, 27),     # (remapped +24 kit / +8 skin)
          (6, 69, 116, 92, 27),
          (7, 69, 0, 69, 79),
          (7, 220, 151, 35, 40)],
}
# Where each piece is stored in team_NN.png (x, y)
TEAM_STORE = {"A": [(0, 0), (0, 54), (0, 81), (138, 81)],
              "B": [(0, 27), (92, 54), (69, 81), (173, 81)]}
# Stadium regions: page 6 rows 116..179 (pitch tile + flag), pages 8, 9 (stands).
STADIUM_PIECES = [(6, 0, 116, 256, 64), (8, 0, 0, 256, 256), (9, 0, 0, 256, 256)]
STADIUM_STORE = [(0, 0), (0, 64), (0, 320)]


def save_png(path, arr):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(np.ascontiguousarray(arr, np.uint8), "L").save(path, optimize=False, compress_level=9)


def vga(b):
    return [int(x) for x in b]


def read_fgfx(eng):
    """font_data[3] / spr_data[129] of the compiled 3DENG.OBJ (FGFX.C)."""
    d, p = eng.d, eng.pub
    fonts = []
    for f in range(eng.size["font_data"] // 68):
        b = p["font_data"] + 68 * f
        page, x, y, n, off = struct.unpack_from("<5i", d, b)
        wid, hgt = d[b + 20], d[b + 21]
        fonts.append(dict(page=page, x=x, y=y, n=n, off=off, wid=wid, hgt=hgt,
                          prp=list(d[b + 22:b + 65]), pad=list(d[b + 65:b + 68])))
    sprs = [list(struct.unpack_from("<5i", d, p["spr_data"] + 20 * i))
            for i in range(eng.size["spr_data"] // 20)]
    forms = [s.decode("ascii") for s in d[p["forms"]:p["forms"] + 60].split(b"\0")[:10]]
    return fonts, sprs, forms


def read_buffs(eng):
    """buff_info tables (MCGA_buff, VESA_buff, menu_buff_l/h): 32-byte records
    {BYTE *buff_start; scrpt(int) buff_wid,buff_hgt,clip_wid,clip_hgt; float scale_x,
    scale_y; void (*dump)()}"""
    d, p = eng.d, eng.pub

    def tab(name):
        out = []
        for i in range(eng.size[name] // 32):
            b = p[name] + 32 * i
            bw, bh, cw, ch = struct.unpack_from("<4i", d, b + 4)
            sx, sy = struct.unpack_from("<2f", d, b + 20)
            out.append([bw, bh, cw, ch, round(sx, 6), round(sy, 6)])
        return out
    return {n: tab(n) for n in ("MCGA_buff", "VESA_buff", "menu_buff_l", "menu_buff_h")}


def script_texts(src):
    """Text[] strings of SCRIPT.96 used by the match: player names (PLYR_NMES,
    16 teams x 20, with the [Mc]/[Le] NamePREFIXtbl switch), Andy's (1600..)
    and Laurent's (1700..) in-game texts. Strings are CP437 byte lists, as
    GetTextString() copies them ('/' escapes the next character)."""
    raw = open(os.path.join(src, "SCRIPT.96"), "rb").read().replace(b"\r", b"")
    lines = raw.split(b"\n")

    def tstring(l):
        i = l.index(b'"') + 1
        out = []
        while i < len(l) and l[i] != ord('"'):
            if l[i] == ord('/') and i + 1 < len(l) and l[i + 1] > 31:
                out.append(l[i + 1])
                i += 2
                continue
            if l[i] > 31:
                out.append(l[i])
            i += 1
        return out

    def index_of(tag):
        for i, l in enumerate(lines):
            if l.strip(b" \t\x7f") == tag:
                return i
        raise SystemExit("tag not found " + tag.decode())

    names, prefix = [], []
    i = index_of(b"PLYR_NMES")
    for l in lines[i + 1:]:
        if l.strip().startswith(b"> Team/Country Names"):
            break
        if re.match(rb"\s*t:\s*\"", l):
            names.append(tstring(l))
            sw = re.search(rb"\"[^\"]*\"\s*\[([^\]]*)\]", l)
            prefix.append(1 if sw and sw.group(1).upper() in (b"MC", b"LE") else 0)
    assert len(names) == 320, len(names)
    texts = {}
    # EURO_SYM.H: QUIT_TEXT 1600 .. USRSLEFT_TEXT 1617, GLSC_TEXT 1700 .. OWNG_TEXT 1730
    for start, last, tag in ((1600, 1617, b"QUIT_TEXT"), (1700, 1730, b"GLSC_TEXT")):
        k = start
        for l in lines[index_of(tag):]:
            if k > last:
                break
            if re.match(rb"\s*t:\s*\"", l):
                texts[k] = tstring(l)
                k += 1
    team_names = []
    for l in lines[index_of(b"TEAM_NMES") + 1:]:
        if re.match(rb"\s*t:\s*\"", l):
            team_names.append(tstring(l))
            if len(team_names) == 16:
                break
    return names, prefix, texts, team_names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(ROOT, "SOURCE"))
    ap.add_argument("--out", default=os.path.join(ROOT, "godot", "assets", "hud"))
    a = ap.parse_args()
    dat = Dat(a.src)
    eng = ObjData(os.path.join(a.src, "3DENG.OBJ"))
    t = read_tables(eng)
    pb = PageBuilder(dat, t)
    fonts, sprs, forms = read_fgfx(eng)
    buffs = read_buffs(eng)

    # Reference pages 6..9 (stacked: maps[X_BM] .. maps[X_BM+3] are contiguous)
    m = pb.build(0, 0, 0, 0)
    save_png(os.path.join(a.out, "xpages_base.png"), m[X_BM:X_BM + 4].reshape(1024, 256))

    # Team pieces (team t as A and as B: build(t, t, t, 0))
    for team in range(len(t["teamlist"])):
        mt = pb.build(team, team, team, 0)
        img = np.zeros((160, 256), np.uint8)
        for role in ("A", "B"):
            for (pg, x, y, w, h), (sx, sy) in zip(TEAM_PIECES[role], TEAM_STORE[role]):
                img[sy:sy + h, sx:sx + w] = mt[pg][y:y + h, x:x + w]
        save_png(os.path.join(a.out, "team_%02d.png" % team), img)

    # Stadium pieces
    for st in range(len(t["stadlist"])):
        ms = pb.build(0, 0, 0, st)
        img = np.zeros((576, 256), np.uint8)
        for (pg, x, y, w, h), (sx, sy) in zip(STADIUM_PIECES, STADIUM_STORE):
            img[sy:sy + h, sx:sx + w] = ms[pg][y:y + h, x:x + w]
        save_png(os.path.join(a.out, "stadium_%d.png" % st), img)

    # Palettes (6-bit VGA), composed at run time like init3d:
    #   pal = PAL_FOOTY; pal[32..55] = kit(team_a); pal[56..79] = kit(team_b_kit);
    #   pal[80..87] = skin(team_a); pal[88..95] = skin(team_b); pal[128..143] = pitch;
    #   pal[224..231] = home(team_a); pal[232..239] = away(team_b); pal[208..223] = sky
    T = t["teamlist"]
    teams = [dict(name=EURO_TEAMS[i], kit=vga(dat.fid(r[4])), skin=vga(dat.fid(r[5])),
                  home=vga(dat.fid(r[6])), away=vga(dat.fid(r[7]))) for i, r in enumerate(T)]
    stads = [dict(name=EURO_VENUES[i] if i < len(EURO_VENUES) else str(i),
                  pitch=vga(dat.fid(s["pitchpfile"])), skytypes=s["skytypes"])
             for i, s in enumerate(t["stadlist"])]
    skies = [vga(dat.fid(s[1])) for s in t["skylist"]]

    names, prefix, texts, team_names = script_texts(a.src)

    out = dict(
        note=("2D overlay data of 3DENG.C (see tools/extract_hud_assets.py). Images hold raw "
              "texel values; draw_sprite: 0 = transparent, 1 = the 'col' argument, t = colour t-1; "
              "draw_sprite_s: 1 = transparent, else colour t-1 (0 -> 255)."),
        font_data=fonts, spr_data=sprs, forms=forms, buffs=buffs,
        team_pieces=dict(A=[list(p) + list(s) for p, s in zip(TEAM_PIECES["A"], TEAM_STORE["A"])],
                         B=[list(p) + list(s) for p, s in zip(TEAM_PIECES["B"], TEAM_STORE["B"])]),
        stadium_pieces=[list(p) + list(s) for p, s in zip(STADIUM_PIECES, STADIUM_STORE)],
        palette=dict(base=vga(dat.entry(0)), teams=teams, stadiums=stads, skies=skies),
        text=dict(player_names=names, name_prefix=prefix, team_names=team_names,
                  strings={str(k): v for k, v in sorted(texts.items())}),
    )
    os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.out, "hud.json"), "w") as f:
        json.dump(out, f, separators=(",", ":"))
        f.write("\n")
    print("done ->", a.out, "texts:", len(texts), "names:", len(names))


if __name__ == "__main__":
    main()
