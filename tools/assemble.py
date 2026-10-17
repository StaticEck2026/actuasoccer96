"""Assemble godot/scripts/game/<module>.gd from ported parts, filling every
original function that has not been ported yet with a stub (so that every
module always compiles and cross-module calls resolve).

Parts live in godot/scripts/game/parts/<module>_<letter>.gd (letters a,b,...),
or a whole-module port in godot/scripts/game/parts/<module>.gd.
Usage: python3 tools/assemble.py [module ...]   (default: all)"""
import re, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'SOURCE')
GAME = os.path.join(HERE, '..', 'godot', 'scripts', 'game')
PARTS = os.path.join(GAME, 'parts')

MODULES = {  # module -> (class, source file, [(part letter, first line, last line)])
    'maths': ('Maths', 'MATHS.CPP', None),
    'ball': ('Ball', 'BALL.CPP', None),
    'ballint': ('BallInt', 'BALLINT.CPP', None),
    'actions': ('Actions', 'ACTIONS.CPP', [('a', 1, 3047), ('b', 3048, 99999)]),
    'intell': ('Intell', 'INTELL.CPP', [('a', 1, 4153), ('b', 4154, 99999)]),
    'rules': ('Rules', 'RULES.CPP', None),
    'user': ('User', 'USER.CPP', None),
    'football': ('Football', 'FOOTBALL.CPP', None),
    'upd3d': ('Upd3D', '3D_UPD2.CPP', None),
    'netinput': ('NetInput', 'NETWORK.C', None),
    'display': ('Display', 'DISPLAY.CPP', None),
}

def c_funcs(srcfile):
    src = open(os.path.join(SRC, srcfile), 'rb').read().decode('latin1').replace('\r', '')
    nc = re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group(0).count('\n'), src, flags=re.S)
    res = []
    seen = set()
    for m in re.finditer(r'^([A-Za-z_][\w \*&]*?)\b(\w+)\s*\(([^{;]*?)\)\s*\n?\s*\{', nc, flags=re.M):
        name = m.group(2)
        if name in ('if', 'while', 'for', 'switch') or name in seen:
            continue
        rt = m.group(1).strip()
        if rt.startswith('extern') or rt in ('else', 'return'):
            continue
        seen.add(name)
        line = nc[:m.start()].count('\n') + 1
        params = []
        for p in m.group(3).split(','):
            p = p.strip()
            if not p or p == 'void':
                continue
            dm = re.search(r'=\s*(.+)$', p)
            p2 = re.sub(r'=.*$', '', p).strip()
            pm = re.search(r'(\w+)\s*(\[.*\])*\s*$', p2)
            pname = pm.group(1) if pm else 'p%d' % len(params)
            ref = '&' in p2
            params.append((pname, dm.group(1).strip() if dm else None, ref, p2))
        res.append(dict(name=name, rtype=rt, params=params, line=line))
    return res

def stub(f):
    ps = []
    for pname, dflt, ref, decl in f['params']:
        if dflt is not None:
            d = {'FALSE': '0', 'TRUE': '1'}.get(dflt, dflt)
            ps.append('%s = %s' % (pname, d))
        else:
            ps.append(pname)
    refs = [p for p in f['params'] if p[2]]
    rt = f['rtype'].replace('inline', '').strip()
    if refs:
        ret = '\treturn [%s]' % ', '.join((['0'] if rt != 'void' else []) + [p[0] for p in refs])
    elif rt == 'void':
        ret = '\tpass'
    elif 'float' in rt:
        ret = '\treturn 0.0'
    else:
        ret = '\treturn 0'
    return '# STUB (not yet ported): %s %s(...)\nstatic func %s(%s):\n%s\n' % (rt, f['name'], f['name'], ', '.join(ps), ret)

def defined_funcs(gd):
    return set(re.findall(r'^static func (\w+)\s*\(', gd, flags=re.M))

def assemble(mod):
    cls, srcfile, parts = MODULES[mod]
    funcs = c_funcs(srcfile)
    out = ['# Port of SOURCE/%s  (assembled by tools/assemble.py - edit the files in parts/)' % srcfile,
           'class_name %s extends Glob' % cls, '']
    whole = os.path.join(PARTS, mod + '.gd')
    bodies = []
    have = set()
    if parts is None:
        if os.path.exists(whole):
            t = open(whole).read()
            t = re.sub(r'^class_name .*\n', '', t, flags=re.M)
            bodies.append(t)
            have |= defined_funcs(t)
        missing = [f for f in funcs if f['name'] not in have]
        bodies += [stub(f) for f in missing]
    else:
        for letter, lo, hi in parts:
            p = os.path.join(PARTS, '%s_%s.gd' % (mod, letter))
            if os.path.exists(p):
                t = open(p).read()
                t = re.sub(r'^class_name .*\n', '', t, flags=re.M)
                bodies.append('# ---- part %s ----\n' % letter + t)
                have |= defined_funcs(t)
            else:
                bodies += [stub(f) for f in funcs if lo <= f['line'] <= hi]
                have |= {f['name'] for f in funcs if lo <= f['line'] <= hi}
        bodies += [stub(f) for f in funcs if f['name'] not in have]
    open(os.path.join(GAME, mod + '.gd'), 'w').write('\n'.join(out) + '\n'.join(bodies) + '\n')
    return len(funcs), len(have)

if __name__ == '__main__':
    mods = sys.argv[1:] or list(MODULES)
    for m in mods:
        n, h = assemble(m)
        print('%s: %d C functions, %d ported' % (m, n, h))
