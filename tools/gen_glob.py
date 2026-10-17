"""Generate godot/scripts/core/glob.gd: every global variable of the original
match engine (types + initial values recovered from the Watcom debug info and
_DATA segments of the original object files) as GDScript static vars, and every
struct used by them as an inner class."""
import sys, os, struct, re
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from omf import OMF
from wdbg import Types, symbols
from annotate import demangle
SRC = os.path.join(HERE, '..', 'SOURCE')
OUT = os.path.join(HERE, '..', 'godot', 'scripts', 'core', 'glob.gd')

SKIP = {'state1', 'state2', 'state_ptr', 'checksum_ptr', 'var_start', 'var_end', 'Sample', 'filters',
        'InitString', 'DialString', 'resync_tab', 'laddress', 'p_multiple', 'p_header', 'p_info', 'p_single',
        'joy_pos', 'batch_info', 'results', 'goals', 'restore_cup_data', 'redefine_data', 'demo_data',
        'GDVvidmode', 'MENUvidmode', 'RESTOREvidmode', 'cup_games', 'detail_defaults', 'screen_defaults',
        'spin_y_offsets', 'friendly_controls', 'rep', 'poswr', 'new_coords', 'old_coords', 'replay_tab',
        'text_mess', 'message_buffer', 'tussle_ptr', 'NetworkHandle', 'performance'}
MODULES = [('FOOTBALL', None), ('3D_UPD2', None), ('ACTIONS', None), ('INTELL', None), ('RULES', None),
           ('DISPLAY', None), ('NETWORK', None), ('GAMEDATA', ['game_data', 'match_info', 'referee_data']),
           ('EURO_INT', ['EUROmatch_info'])]

structs = {}      # name -> (T, typeidx)
# Structs whose layout in THIS source revision differs from the (newer) objects.
STRUCT_OVERRIDE = {
    'user_vectors_i': ['\tvar x_f1: int = 0  # short (EXTERNS.H/NETWORK.C of this source revision)',
                       '\tvar y_f2: int = 0  # short'],
}
order = []
out_vars = []
seen = set()

def scalar_gd(T, i):
    i, t = T.resolve(i)
    if t is None: return 'int'
    if t['k'] == 'scalar':
        return 'float' if t['cls'] == 2 else 'int'
    if t['k'] == 'enum': return 'int'
    if t['k'] == 'ptr': return 'Variant'
    return None

def dims(T, i):
    ds = []
    i, t = T.resolve(i)
    while t and t['k'] in ('array', 'array_t'):
        if t['k'] == 'array': n = t['n']
        else:
            r = T.t.get(t['index'], {})
            n = r['hi'] - r['lo'] + 1 if r.get('k') == 'subrange' else 1
        ds.append(n)
        i, t = T.resolve(t['base'])
    return ds, i, t

def struct_name(T, i):
    # find NAME record pointing to this struct
    for k, v in T.t.items():
        if v['k'] == 'name' and T.resolve(v['type'])[0] == i and v['name']:
            m = re.match(r'^__[0-9a-z]{6}(.+)$', v['name'])
            return m.group(1) if m else v['name']
    return 'struct%d' % i

def register_struct(T, i):
    n = struct_name(T, i)
    if n not in structs:
        structs[n] = (T, i)
        t = T.t[i]
        for f in t['fields']:
            if f[2] is None: continue
            d, bi, bt = dims(T, f[2])
            if bt and bt['k'] == 'struct':
                register_struct(T, bi)
        order.append(n)
    return n

def default_expr(T, ti, raw=None, off=0):
    """GDScript initialiser for a value of type ti; raw = initial bytes (or None)."""
    d, bi, bt = dims(T, ti)
    if bt is None: return '0', 'int'
    if bt['k'] == 'struct':
        sn = register_struct(T, bi)
        base = '%s.new()' % sn
        gdt = sn
    else:
        gdt = scalar_gd(T, bi)
        base = None
    def elem(o):
        if base: return base
        if gdt == 'Variant': return 'null'
        if raw is None or o + 1 > len(raw): return '0.0' if gdt == 'float' else '0'
        t = T.resolve(bi)[1]
        sz = t.get('size', 4) if t['k'] == 'scalar' else 4
        signed = t.get('cls', 0) == 0
        if gdt == 'float':
            v = struct.unpack_from('<f' if sz == 4 else '<d', raw, o)[0]
            return repr(float('%.7g' % v)) if sz == 4 else repr(v)
        fmt = {1: 'b', 2: 'h', 4: 'i'}[sz]
        if not signed: fmt = fmt.upper()
        return str(struct.unpack_from('<' + fmt, raw, o)[0])
    if not d:
        return elem(off), gdt
    t = T.resolve(bi)[1]
    esz = t.get('size', 4)
    def build(level, o):
        n = d[level]
        stride = esz
        for x in d[level + 1:]: stride *= x
        if level == len(d) - 1:
            items = [elem(o + k * esz) for k in range(n)]
            if base or all(x in ('0', '0.0') for x in items):
                return 'CBase._arr(%d, %s)' % (n, '"%s"' % gdt if base else items[0]) if not base else 'CBase._sarr(%d, %s)' % (n, gdt)
            return '[' + ', '.join(items) + ']'
        return '[' + ', '.join(build(level + 1, o + k * stride) for k in range(n)) + ']'
    # C arrays: debug info lists outer dim first
    r = build(0, off)
    stripped = re.sub(r'CBase\._arr\(\d+, ', '', r)
    if len(d) > 1 and re.fullmatch(r'[\[\], ()0.]*', stripped):
        z = '0.0' if gdt == 'float' else ('null' if gdt == 'Variant' else '0')
        if base:
            return 'CBase._snarr(%s, %s)' % (list(d), gdt), 'Array'
        return 'CBase._narr(%s, %s)' % (list(d), z), 'Array'
    if len(d) > 1 and base:
        return 'CBase._snarr(%s, %s)' % (list(d), gdt), 'Array'
    return r, 'Array'

for mod, only in MODULES:
    o = OMF(os.path.join(SRC, mod + '.OBJ'))
    segs = [k for k, s in enumerate(o.segdefs) if s and s[0] == '$$TYPES']
    T = Types(bytes(o.segdata[segs[0]]))
    pubs = {demangle(n): (s, off) for n, (s, off) in o.pubdefs.items()}
    for name, ti in symbols(o, T):
        if only and name not in only: continue
        if name in SKIP or name in seen: continue
        seen.add(name)
        raw = None
        if name in pubs:
            s, off = pubs[name]
            if o.segdefs[s][0] in ('_DATA', 'CONST'):
                raw = bytes(o.segdata[s])[off:]
        expr, gdt = default_expr(T, ti, raw)
        out_vars.append((mod, name, gdt, expr, T.name(ti)))

lines = ['# AUTO-GENERATED by tools/gen_glob.py from the original Watcom object files.',
         '# Global state of the Actua Soccer / Euro 96 match engine (glob_var.h, network.c,',
         '# gamedata.cpp, 3d_upd2.cpp ...). Every module script extends this class so the',
         '# globals can be used unqualified, exactly like the C code.',
         '# Original C types are given in the trailing comments. NOTE: Watcom "char" is unsigned.',
         'class_name Glob extends GlobConsts', '']
for sn in order:
    T, i = structs[sn]
    lines.append('class %s:' % sn)
    if sn in STRUCT_OVERRIDE:
        lines += STRUCT_OVERRIDE[sn] + ['']
        continue
    fields = sorted(T.t[i]['fields'], key=lambda f: f[1] or 0)
    if not fields: lines.append('\tpass')
    for fname, foff, ft in fields:
        if ft is None: continue
        expr, gdt = default_expr(T, ft)
        tdecl = '' if gdt == 'Variant' else ': ' + gdt
        lines.append('\tvar %s%s = %s  # %s' % (fname, tdecl, expr, T.name(ft)))
    lines.append('')
cur = None
for mod, name, gdt, expr, ctype in out_vars:
    if mod != cur:
        lines.append('\n# ---- from %s ----' % mod); cur = mod
    tdecl = '' if gdt == 'Variant' else ': ' + gdt
    lines.append('static var %s%s = %s  # %s' % (name, tdecl, expr, ctype))
extra = os.path.join(HERE, 'glob_extra.gd')
if os.path.exists(extra):
    lines.append('\n# ---- hand-written additions (tools/glob_extra.gd) ----')
    lines += open(extra).read().rstrip('\n').split('\n')
open(OUT, 'w').write('\n'.join(lines) + '\n')
print('wrote', OUT, len(out_vars), 'vars', len(order), 'structs')
