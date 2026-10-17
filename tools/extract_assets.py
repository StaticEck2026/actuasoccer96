#!/usr/bin/env python3
"""Extract the in-match 3D render data of Actua Soccer / Euro 96 (Gremlin, 1996)
into modern formats for the Godot port.

Reads (never modifies) the original files in SOURCE/:
    EUROREND.DAT / EUROREND.OFF  - the match render data file (229 entries)
    DATA.OBJ                     - compiled data.c (models, mcaps8 table)
    3DENG.OBJ                    - compiled 3deng.c (teamlist/skylist/stadlist
                                   tables with the real Euro 96 file ids)
and writes  godot/assets/{textures,models,mocap}/...  plus the JSON tables.

Everything here is derived from the *compiled* Euro 96 objects (SOURCE/3DENG.OBJ,
SOURCE/DATA.OBJ, cross-checked against TEST.MAP / TEST.EXE), because the
3DENG.C / FILES.C / DATA.H text in the source release is an older revision.
See godot/docs/ASSETS.md for the documentation of every format.

Usage:  python3 tools/extract_assets.py [--src SOURCE] [--out godot/assets]
Deterministic: running it twice produces identical files.
"""
import argparse
import json
import os
import struct
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from omf import OMF  # noqa: E402

ROOT = os.path.dirname(HERE)

# ----------------------------------------------------------------------------
# Constants recovered from the compiled 3DENG.OBJ (see ASSETS.md)
# ----------------------------------------------------------------------------
X_BM, S_BM = 6, 8          # page offsets for "extra" and "stand" maps
NPAGES = 16                # MAPPAGES with NEW defined (S_BM+8)
X_TM = 533                 # first "extra" texture
S_TM = X_TM + 52 + 419     # 1004: first stadium texture (stadium TMD loaded here)
NOTEXTURES = S_TM + 500    # 1504
REMAPPED_PAGES = list(range(0, 6)) + list(range(10, 16))  # remapgfx(+1) pages

EURO_TEAMS = ["Bulgaria", "Croatia", "Czech Republic", "Denmark", "England",
              "France", "Germany", "Holland", "Italy", "Portugal", "Romania",
              "Russia", "Scotland", "Spain", "Switzerland", "Turkey"]
EURO_VENUES = ["London", "Birmingham", "Leeds", "Newcastle", "Manchester",
               "Liverpool", "Sheffield", "Nottingham"]

# Motion capture names (ids 0..116 from DATA.H; 117..131 exist only in the
# Euro 96 build, their names are not in the source release).
MC_NAMES = {
    0: "MC_AFOOTB", 1: "MC_AFOOTC", 2: "MC_ABODYB", 3: "MC_ABODYC", 4: "MC_AHEADB",
    5: "MC_AHEADC", 6: "MC_AJUMPB", 7: "MC_AJUMPC", 8: "MC_BFOOTBL", 9: "MC_BFOOTBR",
    10: "MC_BFOOTCL", 11: "MC_BFOOTCR", 12: "MC_BBODYBL", 13: "MC_BBODYBR",
    14: "MC_BBODYCL", 15: "MC_BBODYCR", 16: "MC_BHEADBL", 17: "MC_BHEADBR",
    18: "MC_BHEADCL", 19: "MC_BHEADCR", 20: "MC_BJUMPBL", 21: "MC_BJUMPBR",
    22: "MC_CFOOTBL", 23: "MC_CFOOTBR", 24: "MC_CFOOTCL", 25: "MC_CFOOTCR",
    26: "MC_CBODYBL", 27: "MC_CBODYBR", 28: "MC_CBODYCL", 29: "MC_CBODYCR",
    30: "MC_CHEADBL", 31: "MC_CHEADBR", 32: "MC_CJUMPBL", 33: "MC_CJUMPBR",
    34: "MC_SHOOTR", 35: "MC_SHOOTL", 36: "MC_CHIPR", 37: "MC_CHIPL", 38: "MC_PASSR",
    39: "MC_PASSL", 40: "MC_CROSSR", 41: "MC_CROSSL", 42: "MC_VOLLEYR", 43: "MC_VOLLEYL",
    44: "MC_TOER(unused)", 45: "MC_TOEL(unused)",
    46: "MC_DIAGPASSR", 47: "MC_DIAGPASSL", 48: "MC_DIAGBACKR", 49: "MC_DIAGBACKL",
    50: "MC_SIDEPASSR", 51: "MC_SIDEPASSL", 52: "MC_BACKHEELR", 53: "MC_BACKHEELL",
    54: "MC_TRAPR", 55: "MC_TRAPL", 56: "MC_STOSL", 57: "MC_STOSR", 58: "MC_STOSBL",
    59: "MC_STOSBR", 60: "MC_RIDEL", 61: "MC_RIDER", 62: "MC_SOCKSR", 63: "MC_SOCKSL",
    64: "MC_TROTB", 65: "MC_TROTH", 66: "MC_TROTG", 67: "MC_TROTC", 68: "MC_TROTD",
    69: "MC_TROTF", 70: "MC_TROTA", 71: "MC_TROTE", 72: "MC_RUN", 73: "MC_JOG",
    74: "MC_BARGE", 75: "MC_THROWW", 76: "MC_SHAMEW", 77: "MC_LIE(unused)",
    78: "MC_STAND", 79: "MC_S_HEAD", 80: "MC_J_HEAD", 81: "MC_D_HEAD",
    82: "MC_U_HEAD(unused)", 83: "MC_DV_HEAD", 84: "MC_CHEST", 85: "MC_S_TACKLE",
    86: "MC_STEAL", 87: "MC_OVERHEAD", 88: "MC_THROWL", 89: "MC_THROWS", 90: "MC_FALLR",
    91: "MC_FALLS(unused)", 92: "MC_CELEB", 93: "MC_SHAME", 94: "MC_GETUP",
    95: "MC_GETUPF", 96: "MC_STANDB", 97: "MC_BOUNCE", 98: "MC_KICKOUT",
    99: "MC_HALFVOLL", 100: "MC_THROW", 101: "MC_ROLL", 102: "MC_RUNWITHB",
    103: "MC_WAVEUP", 104: "MC_PENALTY", 105: "MC_PLEAD(unused)", 106: "MC_CRTOSTB",
    107: "MC_PICKBALL", 108: "MC_PLANE", 109: "MC_FINGER", 110: "MC_KNEE", 111: "MC_DUCK",
    112: "MC_MILLER", 113: "MC_BABY", 114: "MC_MOON", 115: "MC_PUMP", 116: "MC_REEVES",
}
# Aliases that DATA.H defines onto other ids (kept for reference).
MC_ALIASES = {"MC_TOER": 38, "MC_TOEL": 39, "MC_LIE": 78, "MC_U_HEAD": 79,
              "MC_FALLS": 90, "MC_PLEAD": 78}

# Point names of the 28 motion-capture points (deduced from the face lists,
# the wire-frame list player_fw and the L/R swap table in render3d; local
# axes: +x = facing direction, +y = up, +z = the player's LEFT; the engine space is
# left-handed - verified by rendering the shirt number / kicking leg).
POINT_NAMES = [
    "head_top", "head_back_marker", "chest_back_marker", "neck", "pelvis",
    "l_shoulder", "l_elbow", "l_hand", "r_shoulder", "r_elbow", "r_hand",
    "l_toe", "r_toe", "l_hip", "l_knee", "l_ankle", "l_instep",
    "r_hip", "r_knee", "r_ankle", "r_instep", "l_foot_side_marker",
    "r_foot_side_marker", "ball", "number_r_top", "number_l_top",
    "number_r_bottom", "number_l_bottom"]
MIRROR_SWAP = [0, 1, 2, 3, 4, 8, 9, 10, 5, 6, 7, 12, 11, 17, 18, 19, 20, 13, 14,
               15, 16, 22, 21, 23, 25, 24, 27, 26]


# ----------------------------------------------------------------------------
# Data access
# ----------------------------------------------------------------------------
class Dat:
    def __init__(self, src):
        self.data = open(os.path.join(src, "EUROREND.DAT"), "rb").read()
        offs = open(os.path.join(src, "EUROREND.OFF"), "rb").read()
        self.offs = [struct.unpack_from("<ii", offs, i * 8) for i in range(len(offs) // 8)]

    def __len__(self):
        return len(self.offs)

    def entry(self, i):
        o, s = self.offs[i]
        return self.data[o:o + s]

    def fid(self, file_id):
        """Read by the engine's file id (id/8 = entry, as readdatafile does,
        C division truncating towards zero, so -1 -> entry 0)."""
        return self.entry(int(file_id / 8))

    def u8(self, i):
        return np.frombuffer(self.entry(i), np.uint8)


def demangle(n):
    if n.startswith("W?"):
        n = n[2:]
        return n.split("$")[0]
    return n


class ObjData:
    """A data segment of a Watcom OMF object with public symbols + fixups."""

    def __init__(self, path, segname="_DATA"):
        self.o = OMF(path)
        self.seg = self.o.seg_index(segname)
        self.d = bytes(self.o.segdata[self.seg])
        self.pub = {}
        for n, (s, off) in self.o.pubdefs.items():
            if s == self.seg:
                self.pub[demangle(n)] = off
        order = sorted(self.pub.items(), key=lambda kv: kv[1])
        self.size = {}
        for i, (n, a) in enumerate(order):
            self.size[n] = (order[i + 1][1] if i + 1 < len(order) else len(self.d)) - a
        self.fix = {}
        for f in self.o.fixups:
            if f["seg"] == self.seg and f["tname"]:
                self.fix[f["off"]] = demangle(f["tname"])

    def ptr(self, off):
        return self.fix.get(off)


# ----------------------------------------------------------------------------
# Palettes
# ----------------------------------------------------------------------------
def vga_to_rgb8(a):
    a = np.asarray(a, np.uint32)
    return ((a * 255 + 31) // 63).astype(np.uint8)


def pal_list(b):
    a = np.frombuffer(b, np.uint8).reshape(-1, 3)
    return a


# ----------------------------------------------------------------------------
# Tables from 3DENG.OBJ
# ----------------------------------------------------------------------------
def read_tables(eng):
    d, p = eng.d, eng.pub
    teamlist = [struct.unpack_from("<8i", d, p["teamlist"] + 32 * i)
                for i in range(eng.size["teamlist"] // 32)]
    skylist = [struct.unpack_from("<4i", d, p["skylist"] + 16 * i)
               for i in range(eng.size["skylist"] // 16)]
    pitch3db = list(struct.unpack_from("<4i", d, p["pitchfile3DB"]))
    stad = []
    for i in range(eng.size["stadlist"] // 240):
        b = p["stadlist"] + 240 * i
        pf, ppf, s0, s1, tmd, sb1, sb2 = struct.unpack_from("<2i2b2x3i", d, b)
        stands = []
        for k in range(4):
            x, y, z, pts, fce = struct.unpack_from("<3f2i", d, b + 24 + 20 * k)
            stands.append(dict(x=x, y=y, z=z, pfile=pts, ffile=fce))
        st_w, st_l, st_h, noloop = struct.unpack_from("<3ih", d, b + 104)
        loop = list(struct.unpack_from("<20i", d, b + 120))
        v = struct.unpack_from("<10i", d, b + 200)
        stad.append(dict(pitchfile=pf, pitchpfile=ppf, skytypes=[s0, s1], tmdfile=tmd,
                         sb1file=sb1, sb2file=sb2, stands=stands, st_w=st_w, st_l=st_l,
                         st_h=st_h, noloop=noloop, loop=loop[:max(noloop, 0)],
                         vid1=list(v[0:3]), vid2=list(v[3:6]), tunl=list(v[6:9]), vmap=v[9]))
    texloop = []
    for i in range(6):
        b = p["texloop"] + i * 36
        texloop.append(dict(pos=struct.unpack_from("<i", d, b)[0],
                            tex=list(struct.unpack_from("<8I", d, b + 4))))
    grtexx = list(struct.unpack_from("<4I", d, p["grtexx"]))
    grtexy = list(struct.unpack_from("<4I", d, p["grtexy"]))
    return dict(teamlist=teamlist, skylist=skylist, pitch3db=pitch3db, stadlist=stad,
                texloop=texloop, grtexx=grtexx, grtexy=grtexy)


# File ids hard-coded in the compiled init3d (immediates in 3DENG.OBJ).
FID = dict(PAL_FOOTY=0, TMD_TEXDATA=8, BM_FEET=0x110, BM_REFKPTOR=0x118, BM_EXTRA1=0x120,
           BM_EXTRA3=0x128, BM_XLIMBS=0x130, BM_XRFKPLIM=0x138, BM_NETS=0x140,
           BM_KGRID1=0x320, BM_KGRID2=0x328, BM_KGRID3=0x330, BM_KGRID4=0x338,
           BM_KGRID5=0x340, BM_KGRID6=0x348, BM_KGRIDS1=0x350, BM_KGRIDS2=0x358,
           BM_REFKPLIM=0x360, BM_EXTRA2=0x3c8, TMD_MANDATA=0x10, MPB_JUGGLE=0x670)


def entry_names(tables, dat):
    """Name every entry of EUROREND.DAT (the missing actrend.equ)."""
    names = {}

    def setn(fid, n):
        e = int(fid / 8)
        names.setdefault(e, n)

    for k, v in FID.items():
        setn(v, k)
    tl = tables["teamlist"]
    for t, row in enumerate(tl):
        team = EURO_TEAMS[t].replace(" ", "")
        setn(row[1], "BM_TORSO_" + team)
        setn(row[4], "COL_KIT_" + team)
    # heads / limbs / numbers / skins / home+away palettes are shared by teams
    for fidx, prefix in ((0, "BM_HEAD"), (2, "BM_LIMBS"), (3, "BM_NUMBERS"), (5, "COL_SKIN"),
                         (6, "COL_HOME"), (7, "COL_AWAY")):
        ids = sorted(set(r[fidx] for r in tl))
        for v in ids:
            setn(v, "%s_%d" % (prefix, int(v / 8)))
    for s, row in enumerate(tables["skylist"]):
        setn(row[0], "BM_SKY%d" % s)
        setn(row[1], "COL_SKY%d" % s)
        setn(row[2], "BM_SKY3DB_%d" % int(row[2] / 8))
        setn(row[3], "COL_SKY3DB_%d" % int(row[3] / 8))
    for i, v in enumerate(tables["pitch3db"]):
        setn(v, "BM_PITCH3DB_%d" % i)
    for s, st in enumerate(tables["stadlist"]):
        setn(st["pitchfile"], "BM_PITCH_%d" % int(st["pitchfile"] / 8))
        setn(st["pitchpfile"], "COL_PITCH_%d" % int(st["pitchpfile"] / 8))
        if st["tmdfile"] >= 0:
            setn(st["tmdfile"], "TMD_STADIUM")
        setn(st["sb1file"], "BM_STAND1")
        setn(st["sb2file"], "BM_STAND2")
        for k, sd in enumerate(st["stands"]):
            setn(sd["pfile"], "PTS_STAND%d" % (k + 1))
            setn(sd["ffile"], "FCE_STAND%d" % (k + 1))
    return names


# ----------------------------------------------------------------------------
# Texture table
# ----------------------------------------------------------------------------
def decode_texture(words, np_=4):
    """texture = dword[8]: dwords 0..np-1 are V (row) 16.16 fixed point, dwords
    np..2np-1 are U (column); bits 24..31 of every V dword hold the map page.
    The engine clears the low byte at load (&0xffffff00)."""
    w = [x & 0xffffff00 for x in words]
    page = w[0] >> 24
    v = [((x >> 8) & 0xffff) / 256.0 for x in w[:np_]]
    u = [((x >> 8) & 0xffff) / 256.0 for x in w[np_:2 * np_]]
    return page, u, v


def texture_table(dat, tables):
    tex = {}
    raw = dat.entry(int(FID["TMD_TEXDATA"] / 8))
    n = len(raw) // 32
    for i in range(n):
        tex[i + 1] = list(struct.unpack_from("<8I", raw, i * 32))
    stadt = {}
    st0 = tables["stadlist"][0]
    raw = dat.fid(st0["tmdfile"])
    for i in range(len(raw) // 32):
        stadt[S_TM + i] = list(struct.unpack_from("<8I", raw, i * 32))
    return tex, stadt


# ----------------------------------------------------------------------------
# Face lists
# ----------------------------------------------------------------------------
def parse_faces(buf, a=0):
    n = struct.unpack_from("<h", buf, a)[0]
    a += 2
    out = []
    for _ in range(n):
        np_, col = struct.unpack_from("<hh", buf, a)
        a += 4
        cnt = np_ if np_ > 2 else (2 if np_ == 2 else (4 if np_ == 0 else 6))
        v = list(struct.unpack_from("<%dh" % cnt, buf, a))
        a += 2 * cnt
        out.append((np_, col, v))
    return out, a


def parse_points(buf, a=0):
    n = int(round(struct.unpack_from("<f", buf, a)[0]))
    pts = np.frombuffer(buf, np.float32, n * 3, a + 4).reshape(n, 3)
    return [[float(round(x, 5)) for x in p] for p in pts]


# ----------------------------------------------------------------------------
# Map pages (emulation of init3d, M8 / software path)
# ----------------------------------------------------------------------------
def remap_range(arr, lo, hi, add, inclusive_hi=False, exclusive_lo=False):
    if exclusive_lo:
        m = (arr > lo) & (arr <= hi)
    else:
        m = (arr >= lo) & (arr < hi)
    arr[m] = (arr[m].astype(np.int32) + add).astype(np.uint8)


class PageBuilder:
    def __init__(self, dat, tables):
        self.dat, self.t = dat, tables

    def load(self, page, file_id, offset=0):
        b = np.frombuffer(self.dat.fid(file_id), np.uint8)
        flat = page.reshape(-1)
        n = min(len(b), flat.size - offset)
        flat[offset:offset + n] = b[:n]

    def build(self, team_a, team_b, team_b_kit, stadium):
        """Returns raw (pre-remapgfx) 16 x 256 x 256 uint8 pages exactly as the
        compiled init3d leaves them (uninitialised memory = 0)."""
        T, S = self.t["teamlist"], self.t["stadlist"][stadium]
        m = np.zeros((NPAGES, 256, 256), np.uint8)
        L = self.load
        ta, tb, tk = T[team_a], T[team_b], T[team_b_kit]
        L(m[0], ta[0]); L(m[0], tb[0], 128 * 256)
        L(m[1], ta[1]); L(m[2], tk[1])
        L(m[3], ta[2]); L(m[3], tk[2], 80 * 256)
        L(m[3], FID["BM_FEET"], 158 * 256)
        L(m[4], FID["BM_REFKPTOR"])
        L(m[X_BM], FID["BM_EXTRA1"])
        L(m[X_BM], ta[3], 62 * 256)
        L(m[X_BM + 1], FID["BM_EXTRA3"])
        L(m[S_BM], S["sb1file"]); L(m[S_BM + 1], S["sb2file"])
        L(m[S_BM + 2], ta[1]); L(m[S_BM + 3], tk[1])
        L(m[S_BM + 4], FID["BM_XLIMBS"])
        L(m[S_BM + 4], ta[2]); L(m[S_BM + 4], tk[2], 80 * 256)
        L(m[S_BM + 5], FID["BM_XRFKPLIM"])
        L(m[S_BM + 6], FID["BM_REFKPTOR"])
        L(m[S_BM + 7], FID["BM_NETS"])
        # kit grids (page 5 used as scratch)
        x3 = m[X_BM + 1]
        for team, row in ((team_a, 111), (team_b_kit, 151)):
            L(m[5], FID["BM_KGRIDS1"] if team // 42 == 0 else FID["BM_KGRIDS2"])
            j = team % 42
            sy, sx = (j // 7) * 42 + 1, (j % 7) * 36 + 1
            x3[row:row + 40, 220:255] = m[5][sy:sy + 40, sx:sx + 35]
        for team, col in ((team_a, 0), (team_b_kit, 69)):
            L(m[5], FID["BM_KGRID1"] + 8 * (team // 9))
            j = team % 9
            sy, sx = (j // 3) * 83 + 2, (j % 3) * 70 + 1
            x3[0:79, col:col + 69] = m[5][sy:sy + 79, sx:sx + 69]
        L(m[5], FID["BM_REFKPLIM"])
        xb = m[X_BM]
        xb[180:207, 161:253] = xb[89:116, 161:253]
        L(xb, tk[3], 89 * 256)
        xb[180:207, 69:161] = xb[116:143, 161:253]
        L(xb, S["pitchfile"], 116 * 256)
        xb[116:143, 69:253] = xb[180:207, 69:253]
        L(xb, FID["BM_EXTRA2"], 180 * 256)
        # palette-slot remapping
        r = m[0][128:256]; remap_range(r, 80, 88, 8)
        r = m[2]; remap_range(r, 32, 56, 24); remap_range(r, 80, 88, 8)
        r = m[3][80:160]; remap_range(r, 32, 56, 24); remap_range(r, 80, 88, 8)
        r = xb[89:116]; remap_range(r, 32, 56, 24, exclusive_lo=True)
        remap_range(r, 80, 88, 8, exclusive_lo=True)
        r = xb[116:143, 69:161]; remap_range(r, 32, 56, 24, exclusive_lo=True)
        remap_range(r, 80, 88, 8, exclusive_lo=True)
        r = m[S_BM + 2]; remap_range(r, 80, 88, 16)
        r = m[S_BM + 3]; remap_range(r, 32, 56, 24); remap_range(r, 80, 88, 16)
        r = m[S_BM + 4][0:78]; remap_range(r, 80, 88, 16)
        r = m[S_BM + 4][80:158]; remap_range(r, 32, 56, 24); remap_range(r, 80, 88, 16)
        r = m[S_BM + 5:S_BM + 7]; remap_range(r, 80, 88, 8)
        return m

    def palette(self, team_a, team_b, team_b_kit, stadium, sky):
        """6-bit VGA palette (256x3) exactly as init3d composes it."""
        T, S = self.t["teamlist"], self.t["stadlist"][stadium]
        p = bytearray(self.dat.entry(0))

        def put(slot, fid):
            b = self.dat.fid(fid)
            p[slot * 3:slot * 3 + len(b)] = b

        put(32, T[team_a][4]); put(56, T[team_b_kit][4])
        put(80, T[team_a][5]); put(88, T[team_b][5])
        put(128, S["pitchpfile"])
        put(224, T[team_a][6]); put(232, T[team_b][7])
        put(208, self.t["skylist"][sky][1])
        return np.frombuffer(bytes(p), np.uint8).reshape(256, 3)


def decode_page(raw, pal_rgb8, page, mode):
    """mode 't' = polyt (transparent mapper), 'm' = polym/polyl (opaque).
    Pages 0-5,10-15 get +1 added to every texel by remapgfx(1) before rendering;
    polyt skips texel value 1 and draws value-1, polym draws the value."""
    v = raw.astype(np.int32)
    if page in REMAPPED_PAGES:
        v = (v + 1) & 255
    out = np.zeros(raw.shape + (4,), np.uint8)
    if mode == "t":
        idx = (v - 1) & 255
        out[..., :3] = pal_rgb8[idx]
        out[..., 3] = np.where(v == 1, 0, 255)
    else:
        out[..., :3] = pal_rgb8[v]
        out[..., 3] = 255
    return out


def to_rgba_t(raw, pal_rgb8, transparent_index):
    """Transparent decode of a component image: transparent_index -> alpha 0,
    colour = pal[raw - (transparent_index)] (i.e. pal[raw] for 0-keyed images,
    pal[raw-1] for 1-keyed images)."""
    v = raw.astype(np.int32)
    out = np.zeros(raw.shape + (4,), np.uint8)
    idx = (v - transparent_index) & 255
    out[..., :3] = pal_rgb8[idx]
    out[..., 3] = np.where(v == transparent_index, 0, 255)
    return out


# ----------------------------------------------------------------------------
# Writer helpers
# ----------------------------------------------------------------------------
def save_png(path, arr, mode=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im = Image.fromarray(arr, mode) if mode else Image.fromarray(arr)
    im.save(path, optimize=False, compress_level=9)


def save_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(obj, f, indent=1, sort_keys=False)
        f.write("\n")


def rgb_list(a):
    return [[int(x) for x in c] for c in a]


# ----------------------------------------------------------------------------
# Main extraction
# ----------------------------------------------------------------------------
class Extractor:
    def __init__(self, src, out):
        self.src, self.out = src, out
        self.dat = Dat(src)
        self.eng = ObjData(os.path.join(src, "3DENG.OBJ"))
        self.data = ObjData(os.path.join(src, "DATA.OBJ"))
        self.t = read_tables(self.eng)
        self.names = entry_names(self.t, self.dat)
        self.pb = PageBuilder(self.dat, self.t)
        self.base_pal6 = pal_list(self.dat.entry(0))
        self.base_rgb = vga_to_rgb8(self.base_pal6)
        self.tex, self.stadtex = texture_table(self.dat, self.t)
        self.mcaps = None

    def p(self, *a):
        return os.path.join(self.out, *a)

    # -- palettes ------------------------------------------------------------
    def team_info(self):
        T = self.t["teamlist"]
        e = lambda fid: int(fid / 8)  # noqa: E731
        teams = []
        for i, r in enumerate(T):
            teams.append(dict(
                id=i, name=EURO_TEAMS[i],
                head_entry=e(r[0]), torso_entry=e(r[1]), limbs_entry=e(r[2]),
                numbers_entry=e(r[3]), kit_palette_entry=e(r[4]), skin_palette_entry=e(r[5]),
                home_palette_entry=e(r[6]), away_palette_entry=e(r[7]),
                file_ids=list(r)))
        return teams

    def export_palettes(self):
        d = self.dat
        out = dict(
            note="8-bit RGB converted from 6-bit VGA (v*255+31)//63; 'vga' holds the raw 6-bit values",
            base=dict(vga=rgb_list(self.base_pal6), rgb=rgb_list(self.base_rgb)),
            subpalettes={})
        for e in range(43, 91):
            b = pal_list(d.entry(e))
            out["subpalettes"][self.names.get(e, "ENTRY_%d" % e)] = dict(
                entry=e, colours=len(b), vga=rgb_list(b), rgb=rgb_list(vga_to_rgb8(b)))
        out["composition"] = [
            dict(slot=0, count=256, source="base (entry 0, PAL_FOOTY)"),
            dict(slot=32, count=24, source="team A kit palette (COL_KIT_<team_a>)"),
            dict(slot=56, count=24, source="team B kit palette (COL_KIT_<team_b_kit>)"),
            dict(slot=80, count=8, source="team A skin palette"),
            dict(slot=88, count=8, source="team B skin palette"),
            dict(slot=128, count=16, source="stadium pitch palette (stadlist.pitchpfile)"),
            dict(slot=208, count=16, source="sky palette (skylist[sky].skypfile)"),
            dict(slot=224, count=8, source="team A HOME palette (teamlist[team_a].homepfile)"),
            dict(slot=232, count=8, source="team B AWAY palette (teamlist[team_b].awaypfile)"),
        ]
        out["filters"] = dict(
            f256=dict(desc="shadow: each pixel replaced by nearest palette colour (of entries 0..239) "
                           "to 50% blend towards black", blend_rgb=[0, 0, 0], amount=0.5),
            f257=dict(desc="50% blend towards VGA (48,48,48) = rgb(194,194,194)", blend_rgb=[194, 194, 194],
                      amount=0.5))
        save_json(self.p("palettes.json"), out)

    # -- textures --------------------------------------------------------------
    def export_raw_bitmaps(self):
        """All bitmap entries as 8-bit index images ('L' mode, value = palette index)."""
        manifest = {}
        for e in range(len(self.dat)):
            n = self.names.get(e)
            size = self.dat.offs[e][1]
            if n is None or not n.startswith("BM_"):
                continue
            w = 640 if size == 307200 else (64 if size == 4096 else 256)
            h = size // w
            arr = self.dat.u8(e).reshape(h, w)
            fn = "indexed/%s.png" % n
            save_png(self.p("textures", fn), arr, "L")
            manifest[n] = dict(entry=e, file=fn, width=w, height=h)
        return manifest

    def team_components(self):
        """Per-team indexed components in both palette-slot layouts + RGBA."""
        pb, T = self.pb, self.t["teamlist"]
        comps = {}
        for t in range(len(T)):
            # build a page set with this team in both slots to cut out pieces
            m = pb.build(t, t, t, 0)
            pal = vga_to_rgb8(pb.palette(t, t, t, 0, 0))
            name = "%02d_%s" % (t, EURO_TEAMS[t].replace(" ", ""))
            base = "teams/%s/" % name
            pieces = {
                "head_A": m[0][0:128], "head_B": m[0][128:256],
                "torso_A": m[1], "torso_B": m[2],
                "torso_dark_A": m[10], "torso_dark_B": m[11],
                "limbs_A": m[3][0:78], "limbs_B": m[3][80:158],
                "limbs_dark_A": m[12][0:78], "limbs_dark_B": m[12][80:158],
                "numbers_A_top": m[6][62:89], "numbers_B_top": m[6][89:116],
                "numbers_A_bottom": m[6][116:143, 161:253], "numbers_B_bottom": m[6][116:143, 69:161],
                "kitgrid_big": m[7][0:79, 0:69], "kitgrid_small": m[7][111:151, 220:255],
            }
            files = {}
            for k, arr in pieces.items():
                fn = base + "indexed/%s.png" % k
                save_png(self.p("textures", fn), np.ascontiguousarray(arr), "L")
                files[k] = fn
            # RGBA (transparent decode as drawn by polyt; numbers are 1-keyed)
            rgba = {}
            for k in ("head_A", "torso_A", "torso_dark_A", "limbs_A", "limbs_dark_A"):
                fn = base + "%s.png" % k[:-2]
                save_png(self.p("textures", fn), to_rgba_t(pieces[k], pal, 0))
                rgba[k[:-2]] = fn
            nums = np.full((54, 256), 1, np.uint8)
            nums[0:27] = pieces["numbers_A_top"]
            nums[27:54, 161:253] = pieces["numbers_A_bottom"]
            fn = base + "numbers.png"
            save_png(self.p("textures", fn), to_rgba_t(nums, pal, 1))
            rgba["numbers"] = fn
            for k in ("kitgrid_big", "kitgrid_small"):
                fn = base + "%s.png" % k
                save_png(self.p("textures", fn), to_rgba_t(pieces[k], pal, 1)[..., :3].copy())
                rgba[k] = fn
            comps[t] = dict(dir=base, indexed=files, rgba=rgba)
        return comps

    def export_fixed_pages(self):
        """Pages whose index content does not depend on the teams (4,5,8,9,13,14,15),
        page 6/7 templates, skies and pitch tiles."""
        m = self.pb.build(0, 0, 0, 0)
        files = {}
        for pg in (4, 5, 8, 9, 13, 14, 15):
            fn = "pages/indexed/page%02d.png" % pg
            save_png(self.p("textures", fn), m[pg], "L")
            files[pg] = fn
        # page 6 / 7 templates (team / stadium dependent regions are overwritten
        # at match start, see pages.json)
        for pg in (6, 7, 12):
            fn = "pages/indexed/page%02d_template.png" % pg
            save_png(self.p("textures", fn), m[pg], "L")
            files["%d_template" % pg] = fn
        return files

    def export_skies_pitches(self):
        out = dict(skies=[], pitches=[])
        for s, row in enumerate(self.t["skylist"]):
            img = self.dat.fid(row[0])
            pal = self.base_rgb.copy()
            sp = pal_list(self.dat.fid(row[1]))
            pal[208:208 + len(sp)] = vga_to_rgb8(sp)
            a = np.frombuffer(img, np.uint8).reshape(480, 640)
            fn = "sky/sky%d.png" % s
            save_png(self.p("textures", fn), pal[a])
            out["skies"].append(dict(id=s, file=fn, image_entry=int(row[0] / 8),
                                     palette_entry=int(row[1] / 8), palette_slot=208,
                                     image_name=self.names[int(row[0] / 8)],
                                     blaster_image_entry=int(row[2] / 8),
                                     blaster_palette_entry=int(row[3] / 8)))
        seen = set()
        for s, st in enumerate(self.t["stadlist"]):
            key = (st["pitchfile"], st["pitchpfile"])
            if key in seen:
                continue
            seen.add(key)
            a = np.frombuffer(self.dat.fid(st["pitchfile"]), np.uint8).reshape(64, 256)
            pal = self.base_rgb.copy()
            pp = pal_list(self.dat.fid(st["pitchpfile"]))
            pal[128:128 + len(pp)] = vga_to_rgb8(pp)
            e1, e2 = int(st["pitchfile"] / 8), int(st["pitchpfile"] / 8)
            fn64 = "pitch/pitch_e%d_p%d_tile64.png" % (e1, e2)
            fn32 = "pitch/pitch_e%d_p%d_tile32.png" % (e1, e2)
            save_png(self.p("textures", fn64), pal[a[0:64, 0:64]])
            save_png(self.p("textures", fn32), pal[a[32:64, 64:96]])
            out["pitches"].append(dict(pitch_entry=e1, palette_entry=e2, tile64=fn64, tile32=fn32))
        return out

    def export_example_match(self, team_a=4, team_b=6, stadium=0, sky=0):
        m = self.pb.build(team_a, team_b, team_b, stadium)
        pal = vga_to_rgb8(self.pb.palette(team_a, team_b, team_b, stadium, sky))
        d = "example_match/"
        files = {}
        for pg in range(NPAGES):
            save_png(self.p("textures", d + "indexed/page%02d.png" % pg), m[pg], "L")
            save_png(self.p("textures", d + "page%02d_t.png" % pg), decode_page(m[pg], pal, pg, "t"))
            save_png(self.p("textures", d + "page%02d_m.png" % pg), decode_page(m[pg], pal, pg, "m"))
            files[pg] = dict(indexed=d + "indexed/page%02d.png" % pg, t=d + "page%02d_t.png" % pg,
                             m=d + "page%02d_m.png" % pg)
        pal_img = np.zeros((1, 256, 3), np.uint8)
        pal_img[0] = pal
        save_png(self.p("textures", d + "palette.png"), pal_img)
        save_json(self.p("textures", d + "match.json"), dict(
            team_a=team_a, team_b=team_b, team_b_kit=team_b, stadium=stadium, sky=sky,
            palette_rgb=rgb_list(pal), pages=files))
        self.example_pages, self.example_pal = m, pal
        return d

    def pages_recipe(self, comps):
        """Ordered blit list that rebuilds the 16 indexed pages for any match."""
        A = "teams/{A}/indexed/"
        B = "teams/{B}/indexed/"
        ops = [
            dict(page=0, src=A + "head_A.png", dst=[0, 0]),
            dict(page=0, src=B + "head_B.png", dst=[0, 128]),
            dict(page=1, src=A + "torso_A.png", dst=[0, 0]),
            dict(page=2, src=B + "torso_B.png", dst=[0, 0]),
            dict(page=3, src=A + "limbs_A.png", dst=[0, 0]),
            dict(page=3, src=B + "limbs_B.png", dst=[0, 80]),
            dict(page=3, src="indexed/BM_FEET.png", dst=[0, 158]),
            dict(page=4, src="pages/indexed/page04.png", dst=[0, 0]),
            dict(page=5, src="pages/indexed/page05.png", dst=[0, 0]),
            dict(page=6, src="pages/indexed/page06_template.png", dst=[0, 0]),
            dict(page=6, src=A + "numbers_A_top.png", dst=[0, 62]),
            dict(page=6, src=B + "numbers_B_top.png", dst=[0, 89]),
            dict(page=6, src="indexed/{PITCH}.png", src_rect=[0, 0, 69, 64], dst=[0, 116]),
            dict(page=6, src="indexed/{PITCH}.png", src_rect=[69, 27, 187, 37], dst=[69, 143]),
            dict(page=6, src=B + "numbers_B_bottom.png", dst=[69, 116]),
            dict(page=6, src=A + "numbers_A_bottom.png", dst=[161, 116]),
            dict(page=6, src="indexed/{PITCH}.png", src_rect=[253, 0, 3, 27], dst=[253, 116]),
            dict(page=7, src="pages/indexed/page07_template.png", dst=[0, 0]),
            dict(page=7, src=A + "kitgrid_big.png", dst=[0, 0]),
            dict(page=7, src=B + "kitgrid_big.png", dst=[69, 0]),
            dict(page=7, src=A + "kitgrid_small.png", dst=[220, 111]),
            dict(page=7, src=B + "kitgrid_small.png", dst=[220, 151]),
            dict(page=8, src="pages/indexed/page08.png", dst=[0, 0]),
            dict(page=9, src="pages/indexed/page09.png", dst=[0, 0]),
            dict(page=10, src=A + "torso_dark_A.png", dst=[0, 0]),
            dict(page=11, src=B + "torso_dark_B.png", dst=[0, 0]),
            dict(page=12, src="pages/indexed/page12_template.png", dst=[0, 0]),
            dict(page=12, src=A + "limbs_dark_A.png", dst=[0, 0]),
            dict(page=12, src=B + "limbs_dark_B.png", dst=[0, 80]),
            dict(page=13, src="pages/indexed/page13.png", dst=[0, 0]),
            dict(page=14, src="pages/indexed/page14.png", dst=[0, 0]),
            dict(page=15, src="pages/indexed/page15.png", dst=[0, 0]),
        ]
        return ops

    def verify_recipe(self, ops, team_a=4, team_b=6, stadium=0):
        """Rebuild the pages through the recipe and compare with the emulation."""
        teamdir = lambda t: "%02d_%s" % (t, EURO_TEAMS[t].replace(" ", ""))  # noqa: E731
        pitch = self.names[int(self.t["stadlist"][stadium]["pitchfile"] / 8)]
        pages = np.zeros((NPAGES, 256, 256), np.uint8)
        for op in ops:
            fn = op["src"].replace("{A}", teamdir(team_a)).replace("{B}", teamdir(team_b)).replace(
                "{PITCH}", pitch)
            img = np.array(Image.open(self.p("textures", fn)))
            if "src_rect" in op:
                x, y, w, h = op["src_rect"]
                img = img[y:y + h, x:x + w]
            x, y = op["dst"]
            h, w = img.shape
            h, w = min(h, 256 - y), min(w, 256 - x)
            pages[op["page"], y:y + h, x:x + w] = img[:h, :w]
        ref = self.pb.build(team_a, team_b, team_b, stadium)
        bad = [int(p) for p in range(NPAGES) if not np.array_equal(pages[p], ref[p])]
        return bad

    # -- texture table -----------------------------------------------------------
    def export_texture_table(self):
        def rec(w):
            page, u, v = decode_texture(w)
            _, u3, v3 = decode_texture(w, 3)
            return dict(page=page, u=u, v=v, u3=u3, v3=v3, raw=["%08x" % x for x in w])
        out = {str(i): rec(self.tex[i]) for i in sorted(self.tex)}
        sout = {str(i): rec(self.stadtex[i]) for i in sorted(self.stadtex)}
        tl = []
        for i, t in enumerate(self.t["texloop"]):
            page, u, v = decode_texture(t["tex"])
            tl.append(dict(index=i, pos="0x%x" % t["pos"], page_offset=t["pos"] >> 16,
                           byte_offset=t["pos"] & 0xffff, u=u, v=v))
        save_json(self.p("textures", "textures.json"), dict(
            note=("texture[i] = dword[8]; first np dwords = V (row), next np dwords = U (column), "
                  "16.16 fixed point in texels of a 256x256 page; page = bits 24..31 of the V dwords "
                  "(low byte cleared by the engine). u/v = split for 4-vertex polygons and billboards, "
                  "u3/v3 = split for triangles. Vertex k of a polygon uses (u[k], v[k]) in texel units "
                  "(0..256, divide by 256 for normalised UV; 0 = top/left edge of the page). "
                  "'texdata' = TMD_TEXDATA loaded at textures[1..]; 'stadium' = TMD_STADIUM loaded at "
                  "textures[1004..] (overrides texdata 1004..1006)."),
            texdata=out, stadium=sout, looping=tl))

    def tex_uv(self, idx, np_):
        """Resolve a texture index for a face with np_ vertices: returns page,u[],v[]"""
        w = self.tex.get(idx) or self.stadtex.get(idx)
        if w is None:
            return None
        if np_ > 4:
            return None
        page, u, v = decode_texture(w, np_)
        return page, u, v

    # -- models -----------------------------------------------------------------
    def face_json(self, np_, col, v, stadium=False):
        f = {}
        if np_ > 2:
            f["v"] = v
        elif np_ == 2:
            f["v"] = v
            f["kind"] = "line"
        elif np_ == 0:
            f["kind"] = "cyl_billboard"
            f["v"] = v[0:2]
            f["width"] = v[2]
            f["length"] = v[3]
        else:
            f["kind"] = "ellipse_billboard"
            f["v"] = v[0:3]
            f["a"] = v[3]
            f["b"] = v[4]
            f["length"] = v[5]
        if col >= 512:
            col_eff = 257
        else:
            col_eff = col
        if col_eff < 0:
            t = -col_eff - 2000 if col_eff < -2000 else -col_eff
            mode = "transparent" if col_eff < -2000 else "tex"
            if np_ > 2:
                f["kind"] = mode
            else:
                f["tex_mode"] = mode
            f["tex"] = t
            if np_ == 0:
                f["tex_range"] = [t - 3, t + 3]      # 7 tilt frames
            elif np_ < 0 or np_ == 1:
                f["tex_range"] = [t - 12, t + 47]    # 5 elevations x 12 rotations
            if np_ > 2:
                r = self.tex_uv(t, np_)
                if r:
                    page, u, vv = r
                    f["page"] = page
                    f["uv"] = [[u[k], vv[k]] for k in range(np_)]
        elif col_eff >= 256:
            f.setdefault("kind", "filter")
            f["filter"] = col_eff - 256
            if col >= 512:
                f["looping_texture"] = col & 255
        else:
            f.setdefault("kind", "flat")
            f["color_index"] = col_eff
            f["color"] = [int(x) for x in self.base_rgb[col_eff]]
            if 32 <= col_eff < 96 or 128 <= col_eff < 144 or 208 <= col_eff < 240:
                f["palette_dependent"] = True   # slot overwritten by a match sub-palette
        f["col_raw"] = col
        return f

    def faces_json(self, buf, a=0):
        fl, _ = parse_faces(buf, a)
        return [self.face_json(*x) for x in fl]

    def export_models(self):
        D = self.data
        d = D.d

        def pts(name):
            return parse_points(d, D.pub[name])

        def fcs(name):
            return self.faces_json(d, D.pub[name])

        def detlist(name):
            a = D.pub[name]
            levels = []
            reachable = True
            for i in range(D.size[name] // 12):
                zs = struct.unpack_from("<f", d, a + 12 * i)[0]
                p = D.ptr(a + 12 * i + 4)
                f = D.ptr(a + 12 * i + 8)
                if p is None:
                    break
                levels.append(dict(zscale=zs, points=p, faces=f, reachable=reachable))
                if zs <= 0:
                    reachable = False   # objdepd() stops at the first level with zscale <= zq
            return levels

        models_dir = self.p("models")
        index = {}

        def write(name, obj):
            save_json(os.path.join(models_dir, name + ".json"), obj)
            index[name] = "models/%s.json" % name

        # --- objects with detail levels
        def lod_model(detname, extra):
            levels = []
            for lv in detlist(detname):
                levels.append(dict(zscale=lv["zscale"], reachable=lv["reachable"], points_name=lv["points"],
                                   faces_name=lv["faces"],
                                   points=pts(lv["points"]), faces=fcs(lv["faces"])))
            o = dict(lod=levels)
            o.update(extra)
            return o

        write("ball", lod_model("ball_d", dict(
            placement="ball object: position from plyrdat[25] (or the motion-captured ball), "
                      "rotated with addobjxy (yaw crot/srot, pitch frame/fstep)")))
        goals = {}
        place_goal = {"goal1_1": (0, 0, -443.5), "goal2_1": (0, 0, -356.5), "goal3_1": (0, 37, -400),
                      "goal4_1": (-28, 0, -400), "goal1_2": (1280, 0, -443.5),
                      "goal2_2": (1280, 0, -356.5), "goal3_2": (1280, 37, -400), "goal4_2": (1308, 0, -400)}
        detof = {"goal1_1": "goal1_a", "goal2_1": "goal2_a", "goal3_1": "goal3_a", "goal4_1": "goal4_a",
                 "goal1_2": "goal1_b", "goal2_2": "goal2_b", "goal3_2": "goal3_b", "goal4_2": "goal4_b"}
        for g, pos in place_goal.items():
            goals[g] = dict(position_engine=list(pos), lod_model=detof[g])
            write("goal_" + detof[g], lod_model(detof[g], dict(
                desc="goal piece; drawn with addobjnc (no rotation, points + object position)")))
        write("goals", dict(objects=goals, note="position_engine is engine world (X, Y up, Z=-game_y)"))

        lines = {}
        place_l = {"l1": ("l1_d", (210, 0, -200)), "l2": ("l2_d", (1070, 0, -200)),
                   "l3": ("l3_d", (1070, 0, -600)), "l4": ("l4_d", (210, 0, -600)),
                   "l5": ("l5_d", (640, 0, -200)), "l6": ("l6_d", (640, 0, -600)),
                   "circle": ("circle_d", (640, 0, -400)), "semi1": ("s_circle_d1", (123, 0, -400)),
                   "semi2": ("s_circle_d2", (1157, 0, -400))}
        for n, (dn, pos) in place_l.items():
            lines[n] = dict(position_engine=list(pos), lod_model=dn)
            if "lines_" + dn not in index:
                write("lines_" + dn, lod_model(dn, dict(desc="pitch marking (y=0 plane, drawn first, unsorted)")))
        spot = dict(points=pts("spot_p"), faces=fcs("spot_f"))
        write("lines_spot", spot)
        for n, pos in (("spot1", (640, 0, -400)), ("spot2", (128, 0, -400)), ("spot3", (1152, 0, -400))):
            lines[n] = dict(position_engine=list(pos), model="lines_spot")
        write("pitch_lines", dict(objects=lines,
                                  note="l1..l6 penalty/goal areas and halfway line halves; drawn with addobjfc"))

        write("pitch_simple", dict(points=pts("pitch_p"), faces=fcs("pitch_f"),
                                   note="detail.pitch==0 flat pitch; init3d moves the edge points to "
                                        "the stadium bounds: z of points 0..18 = st_w, 19..37 = -800-st_w; "
                                        "x of points 0,19 = -st_l, 18,37 = 1280+st_l"))
        write("ball_shadow", dict(points=pts("ballshad_p"), faces=fcs("ballshad_f")))
        hl = {"plshad": dict(points=pts("plshad_p"), faces=fcs("plshad_f"))}
        tab = []
        names = [["plshad_f"] * 6,
                 ["plhi1_f1", "plhi1_f2", "plhi1_f3", "plhi1_f4", "plhi1_f5", "plhi1_ff"],
                 ["plhi2_f1", "plhi2_f2", "plhi2_f3", "plhi2_f4", "plhi2_f5", "plhi2_ff"],
                 ["plhi3_f1", "plhi3_f2", "plhi3_f3", "plhi3_f4", "plhi3_f5", "plhi3_ff"],
                 ["plhi3_f1", "plhi3_f2", "plhi3_f3", "plhi3_f4", "plhi3_f5", "plhi3_ff"],
                 ["plhi4_f1", "plhi4_f2", "plhi4_f3", "plhi4_f4", "plhi4_f5", "plhi4_ff"],
                 ["plhi4_f1", "plhi4_f2", "plhi4_f3", "plhi4_f4", "plhi4_f5", "plhi4_ff"]]
        for ht in range(7):
            row = []
            for hc in range(6):
                fn = names[ht][hc]
                row.append(dict(faces_name=fn, points="plshad" if ht == 0 else "plhi",
                                faces=fcs(fn)))
            tab.append(row)
        write("player_highlights", dict(
            plshad=dict(points=pts("plshad_p")), plhi=dict(points=pts("plhi_p")),
            table=tab,
            note="plhilight[htype][hcol]; htype 0 = shadow (drawn for every player with htype==0), "
                 "htype 3 and 4 rotate with the player (crot, -srot), others are axis aligned; "
                 "htype 4 and 6 blink (visible half of a 4-unit log_factor cycle)."))
        write("flag", dict(points=pts("flag_p"), faces=fcs("flag_f"),
                           positions_engine=[[0, 0, 0], [1280, 0, 0], [0, 0, -800], [1280, 0, -800]],
                           note="point 8 is the flag tip, moved by wind; texture of faces 5 cycles "
                                "X_TM+46..X_TM+48 (579..581) with wind; see ASSETS.md"))

        # --- player
        pl = {}
        for fn in ["player_f1", "player_f2", "player_f1b", "player_f2b", "player_fg1", "player_fg2",
                   "player_f1x", "player_f2x", "player_f1xb", "player_f2xb", "player_fg1x",
                   "player_fg2x", "player_fw", "player_fl", "player_fr"]:
            pl[fn] = fcs(fn)
        pt_tab = []
        a = D.pub["playertypes"]
        for i in range(D.size["playertypes"] // 4):
            pt_tab.append(D.ptr(a + 4 * i))
        write("player", dict(
            points=28, point_names=POINT_NAMES, mirror_swap=MIRROR_SWAP,
            facelists=pl, playertypes=pt_tab,
            selection=("faces = playertypes[k]: k = type (1 team A, 2 team B, 3 referee, 4 linesman); "
                       "+5 if the anim is mirrored; +10 for players with game_data skin_tone!=0 (dark "
                       "skin, M8 only); goalkeepers (player index 0 and 11): 5/10 (team A or !M8) or "
                       "15/20 (team B); +5 when mirrored. playertypes[21] = wireframe."),
            number_patch=("face 12 (the quad on points 25,24,26,27): its col is overwritten per "
                          "player: team A tex X_TM+16+(n-1), team B X_TM+31+(n-1) (transparent); "
                          "with detail.players==0 the list is truncated to 12 faces (no number)."),
        ))
        # --- stadium stands
        st0 = self.t["stadlist"][0]
        stands = []
        for k, sd in enumerate(st0["stands"]):
            pts_ = parse_points(self.dat.fid(sd["pfile"]))
            fl, _ = parse_faces(self.dat.fid(sd["ffile"]))
            faces = []
            for np_, col, v in fl:
                c = col
                if c < 0:
                    c -= S_TM - 1  # init3d fix-up: stadium textures live at textures[S_TM..]
                faces.append(self.face_json(np_, c, v, stadium=True))
            name = "stand%d" % (k + 1)
            write("stadium_" + name, dict(points=pts_, faces=faces,
                                          position_engine=[sd["x"], sd["y"], sd["z"]],
                                          rotation=None, pfile_entry=int(sd["pfile"] / 8),
                                          ffile_entry=int(sd["ffile"] / 8)))
            stands.append(dict(name=name, model="models/stadium_%s.json" % name,
                               position_engine=[sd["x"], sd["y"], sd["z"]]))
        save_json(self.p("models", "index.json"), index)
        return stands

    # -- mocap ----------------------------------------------------------------------
    def export_mocap(self):
        D = self.data
        a = D.pub["mcaps8"]
        n = D.size["mcaps8"] // 4
        mc = [struct.unpack_from("<hh", D.d, a + 4 * i)[1] for i in range(n)]
        a4 = D.pub["mcaps4"]
        mc4 = [struct.unpack_from("<hh", D.d, a4 + 4 * i)[1] for i in range(n)]
        # file id -> capture slot, from the compiled init3d (M8 branch)
        load = mpb_load_table()
        starts, tot = [], 0
        for i in range(n):
            starts.append(tot)
            tot += mc[i]
        frames = np.zeros((tot, 85), np.float32)
        frames[:, 0] = 28.0
        filled = set()
        for fid, slot in load:
            b = np.frombuffer(self.dat.fid(fid), np.float32).reshape(-1, 85)
            assert len(b) == mc[slot], (fid, slot, len(b), mc[slot])
            frames[starts[slot]:starts[slot] + len(b)] = b
            filled.add(slot)
        jug = np.frombuffer(self.dat.fid(FID["MPB_JUGGLE"]), np.float32).reshape(-1, 85)
        allf = np.concatenate([frames, jug])
        os.makedirs(self.p("mocap"), exist_ok=True)
        allf.astype("<f4").tofile(self.p("mocap", "mocap.bin"))
        caps = []
        fid_of = {slot: fid for fid, slot in load}
        for i in range(n):
            xf = bool((i & 1) and ((8 <= i <= 69) or i >= 128))
            src = i - 1 if xf else i
            c = dict(id=i, name=MC_NAMES.get(i, "MC_EURO_%d" % i),
                     start=starts[src], frames=mc[src], mirror=xf, source_id=src,
                     stored_frames=mc[i], frames_4mb=mc4[i])
            if not xf and mc[i] == 0:
                c["unused"] = True
            if i in fid_of:
                c["dat_entry"] = int(fid_of[i] / 8)
            caps.append(c)
        caps.append(dict(id=None, name="JUGGLE (front-end only, not loaded by init3d)", start=tot,
                         frames=len(jug), mirror=False, source_id=None,
                         dat_entry=int(FID["MPB_JUGGLE"] / 8)))
        save_json(self.p("mocap", "mocap.json"), dict(
            frame_floats=85, point_count=28,
            frame_layout="float32 LE: [0] = point count (always 28.0, the engine reads it as the "
                         "object's point count), then 28 x (x,y,z) capture-local points",
            point_names=POINT_NAMES, mirror_swap=MIRROR_SWAP,
            units="1 unit = pitch unit (pitch is 1280 x 800); players are ~24 units tall",
            axes="capture local: +x = facing, +y = up, +z = player's left (left-handed engine space, see ASSETS.md); "
                 "point 23 (ball) has y = -10000 when the capture carries no ball",
            total_frames=int(len(allf)), engine_frames=int(tot),
            mirror_rule="anim is mirrored if (id & 1) and (8 <= id <= 69 or id >= 128): use "
                        "frames of id-1 with z negated (and the object drawn with addobjyf)",
            frame_index_rule="frame = mcap.start + int(plyrdat.frame * frames)  (frame in [0,1))",
            captures=caps))
        self.mocap = (allf, caps)
        return caps

    # -- tables ---------------------------------------------------------------------
    def export_tables(self, comps, stands, sky_pitch):
        teams = []
        for ti in self.team_info():
            t = ti["id"]
            ti["head_type"] = self.names[ti["head_entry"]]
            ti["components"] = comps[t]
            ti["number_style"] = self.names[ti["numbers_entry"]]
            pal = pal_list(self.dat.entry(ti["kit_palette_entry"]))
            ti["kit_palette_rgb"] = rgb_list(vga_to_rgb8(pal))
            ti["skin_palette_rgb"] = rgb_list(vga_to_rgb8(pal_list(self.dat.entry(ti["skin_palette_entry"]))))
            ti["home_palette_rgb"] = rgb_list(vga_to_rgb8(pal_list(self.dat.entry(ti["home_palette_entry"]))))
            ti["away_palette_rgb"] = rgb_list(vga_to_rgb8(pal_list(self.dat.entry(ti["away_palette_entry"]))))
            kg = "BM_KGRID%d" % (t // 9 + 1)
            ti["kitgrid_source"] = dict(big=kg, big_cell=t % 9, small="BM_KGRIDS%d" % (t // 42 + 1),
                                        small_cell=t % 42)
            teams.append(ti)
        save_json(self.p("teams.json"), dict(
            note=("16 Euro 96 teams in engine order (EURODEFS.H). In a match team A = setup.team_a, "
                  "team B = setup.team_b (head, skin, away palette) and setup.team_b_kit (torso, limbs, "
                  "numbers, kit palette). The Euro 96 front end never writes setup.team_b_kit (see "
                  "ASSETS.md open issues); use team_b_kit = team_b."),
            teams=teams))
        stads = []
        for s, st in enumerate(self.t["stadlist"]):
            o = dict(st)
            o["id"] = s
            o["venue"] = EURO_VENUES[s] if s < len(EURO_VENUES) else None
            o["pitch_entry"] = int(st["pitchfile"] / 8)
            o["pitch_name"] = self.names[o["pitch_entry"]]
            o["pitch_palette_entry"] = int(st["pitchpfile"] / 8)
            o["tmd_entry"] = int(st["tmdfile"] / 8) if st["tmdfile"] >= 0 else None
            o["stand_page_entries"] = [int(st["sb1file"] / 8), int(st["sb2file"] / 8)]
            for k, sd in enumerate(o["stands"]):
                sd["model"] = stands[k]["model"]
                sd["position_godot"] = [sd["x"], sd["y"], -sd["z"]]
                sd["rotation"] = 0
            o["bounds_note"] = ("st_l/st_w: stadium extends st_l beyond each goal line and st_w beyond "
                                "each touch line; st_h = stand height used for the sky horizon")
            stads.append(o)
        save_json(self.p("stadiums.json"), dict(
            note=("stadlist from the compiled Euro 96 3DENG.OBJ (8 venues). All 8 share the same "
                  "stand geometry/pages; they differ in pitch texture/palette and sky choices. "
                  "tmdfile=-1 in 5 entries (the engine then loads entry 0 into the stadium texture "
                  "slots - a latent bug); use TMD_STADIUM (entry 125) for all."),
            stadiums=stads))
        save_json(self.p("skies.json"), dict(
            note=("skylist from 3DENG.OBJ; skyno = stadlist[stadium].skytypes[frame_count & 1] "
                  "chosen at init3d. Sky images are 640x480, drawn with palette slots 208..223."),
            skies=sky_pitch["skies"], pitches=sky_pitch["pitches"]))

    def export_dat_index(self, raw_manifest):
        rows = []
        for e in range(len(self.dat)):
            o, s = self.dat.offs[e]
            rows.append(dict(entry=e, file_id=e * 8, offset=o, size=s,
                             name=self.names.get(e), raw_png=raw_manifest.get(self.names.get(e), {}).get("file")))
        # identify remaining entries
        extra = {2: "TMD_MANDATA (front-end 'man' textures, identical to MANDATA.TMD)",
                 26: "BM_LIMBS (not referenced by the Euro teamlist)",
                 33: "BM_LIMBS (not referenced by the Euro teamlist)",
                 111: "BM_NUMBERS (not referenced by the Euro teamlist)",
                 122: "unreferenced 256x256 bitmap", 123: "unreferenced 256x128 bitmap",
                 124: "unreferenced 256x256 bitmap",
                 206: "MPB_JUGGLE (300 frames, front-end; identical to JUGGLE.MPB)"}
        for r in rows:
            if r["name"] is None and r["entry"] in extra:
                r["name"] = extra[r["entry"]]
            if r["name"] is None and 134 <= r["entry"] <= 228:
                r["name"] = "MPB (motion capture)"
            if r["name"] is None and 102 <= r["entry"] <= 105:
                r["name"] = "BM_KGRID%d" % (r["entry"] - 99)
            if r["name"] is None and 64 <= r["entry"] <= 72:
                r["name"] = "COL_PITCH_%d (unreferenced)" % r["entry"]
        save_json(self.p("eurorend_index.json"), dict(
            note="EUROREND.DAT directory; engine file id = entry*8 (readfile uses id/8)", entries=rows))

    def run(self):
        os.makedirs(self.out, exist_ok=True)
        self.export_palettes()
        raw_manifest = self.export_raw_bitmaps()
        # unreferenced bitmaps too (keep everything for completeness)
        for e, (w, h) in {26: (256, 78), 33: (256, 78), 111: (256, 54), 102: (256, 256),
                          103: (256, 256), 104: (256, 256), 105: (256, 256), 122: (256, 256),
                          123: (256, 128), 124: (256, 256)}.items():
            if e not in [v["entry"] for v in raw_manifest.values()]:
                n = "BM_ENTRY_%d" % e
                save_png(self.p("textures", "indexed/%s.png" % n), self.dat.u8(e).reshape(h, w), "L")
                raw_manifest[n] = dict(entry=e, file="indexed/%s.png" % n, width=w, height=h)
        comps = self.team_components()
        fixed = self.export_fixed_pages()
        sky_pitch = self.export_skies_pitches()
        self.export_example_match()
        ops = self.pages_recipe(comps)
        save_json(self.p("textures", "pages.json"), dict(
            note=("Recipe to assemble the 16 indexed 256x256 map pages of a match. Apply the ops in "
                  "order (blit src [src_rect x,y,w,h] to page at dst x,y, clipping at 256). {A}/{B} "
                  "= team dirs (teams.json components.dir), {PITCH} = stadium pitch bitmap name. Pages "
                  "0-5 and 10-15 are later incremented by 1 by remapgfx (see ASSETS.md decode rules)."),
            remapped_pages=REMAPPED_PAGES, ops=ops, fixed=fixed,
            page_roles={0: "heads A (rows 0-127) / B (128-255)", 1: "torso A", 2: "torso B",
                        3: "limbs A (0-77), limbs B (80-157), feet (158-224)",
                        4: "referee/keeper torso (skin slot A)", 5: "referee/keeper limbs (skin slot A)",
                        6: "extra 1: highlights, shirt numbers, pitch tile, flag, extra 2",
                        7: "extra 3: kit grids, misc", 8: "stand page 1", 9: "stand page 2",
                        10: "torso A dark skin", 11: "torso B dark skin",
                        12: "limbs A/B dark skin + dark heads (XLIMBS)",
                        13: "keeper/linesman limbs (skin slot B)", 14: "keeper torso (skin slot B)",
                        15: "nets, ball panels"}))
        bad = self.verify_recipe(ops)
        if bad:
            raise SystemExit("page recipe mismatch on pages %s" % bad)
        self.export_texture_table()
        stands = self.export_models()
        self.export_mocap()
        self.export_tables(comps, stands, sky_pitch)
        self.export_dat_index(raw_manifest)
        print("done ->", self.out)


def mpb_load_table():
    """(file id, capture slot) pairs of the M8 load list of the compiled Euro 96
    init3d (recovered from 3DENG.OBJ; matches the frame counts of mcaps8)."""
    ids = list(range(1072, 1648, 8)) + [1656, 1664, 1672, 1680] + list(range(1688, 1808, 8)) + [1824, 1808, 1816]
    slots = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40,
             42, 46, 48, 50, 52, 56, 58, 54, 60, 62, 64, 66, 68, 70, 71, 72, 73, 74, 75, 76, 78, 79, 80,
             81, 83, 84, 85, 86, 87, 88, 89, 90, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103,
             104, 106, 107, 111, 109, 110, 108, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122,
             123, 124, 125, 126, 127, 128, 130]
    assert len(ids) == len(slots)
    return list(zip(ids, slots))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(ROOT, "SOURCE"))
    ap.add_argument("--out", default=os.path.join(ROOT, "godot", "assets"))
    a = ap.parse_args()
    Extractor(a.src, a.out).run()


if __name__ == "__main__":
    main()
