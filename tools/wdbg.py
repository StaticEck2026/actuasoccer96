"""Parser for Watcom (v3) debug information stored in OMF $$TYPES/$$SYMBOLS
segments. Recovers global variable types and struct layouts."""
import struct, sys
sys.path.insert(0, __import__('os').path.dirname(__file__))
from omf import OMF

def tidx(b, i):
    v = b[i]
    if v & 0x80:
        return ((v & 0x7f) << 8) | b[i + 1], i + 2
    return v, i + 1

class Types:
    def __init__(self, data):
        self.t = {}   # idx -> dict
        idx = 0
        i = 0
        cur = None
        while i < len(data):
            l = data[i]
            if l == 0: break
            rec = data[i:i + l]
            i += l
            kind = rec[1]
            cls, sub = kind & 0xf0, kind & 0x0f
            body = rec[2:]
            if cls == 0x10:
                if sub == 3:  # cue table
                    continue
                idx += 1
                if sub == 0:
                    sc = body[0]
                    self.t[idx] = dict(k='scalar', size=(sc & 0xf) + 1, cls=(sc >> 4) & 7, name=body[1:].decode('latin1'))
                elif sub == 1:
                    self.t[idx] = dict(k='scope', name=body.decode('latin1'))
                elif sub == 2:
                    s, j = tidx(body, 0); ty, j = tidx(body, j)
                    self.t[idx] = dict(k='name', scope=s, type=ty, name=body[j:].decode('latin1'))
                else:
                    self.t[idx] = dict(k='tn%d' % sub)
            elif cls == 0x20:
                idx += 1
                if sub == 0:
                    hb = body[0]; base, j = tidx(body, 1)
                    self.t[idx] = dict(k='array', n=hb + 1, base=base)
                elif sub == 1:
                    hb = struct.unpack_from('<H', body, 0)[0]; base, j = tidx(body, 2)
                    self.t[idx] = dict(k='array', n=hb + 1, base=base)
                elif sub == 2:
                    hb = struct.unpack_from('<I', body, 0)[0]; base, j = tidx(body, 4)
                    self.t[idx] = dict(k='array', n=hb + 1, base=base)
                elif sub == 3:
                    it, j = tidx(body, 0); base, j = tidx(body, j)
                    self.t[idx] = dict(k='array_t', index=it, base=base)
                else:
                    self.t[idx] = dict(k='array?%d' % sub)
            elif cls == 0x30:
                idx += 1
                if sub == 0:
                    lo, hi = struct.unpack_from('<bb', body, 0); bt, j = tidx(body, 2)
                elif sub == 1:
                    lo, hi = struct.unpack_from('<hh', body, 0); bt, j = tidx(body, 4)
                else:
                    lo, hi = struct.unpack_from('<ii', body, 0); bt, j = tidx(body, 8)
                self.t[idx] = dict(k='subrange', lo=lo, hi=hi, base=bt)
            elif cls == 0x40:
                idx += 1
                bt, j = tidx(body, 0)
                self.t[idx] = dict(k='ptr', base=bt)
            elif cls == 0x50:
                if sub == 0:
                    idx += 1
                    cnt = struct.unpack_from('<H', body, 0)[0]
                    cur = dict(k='enum', consts=[], size=body[2])
                    self.t[idx] = cur
                else:
                    if sub == 1: v = struct.unpack_from('<b', body, 0)[0]; nm = body[1:]
                    elif sub == 2: v = struct.unpack_from('<h', body, 0)[0]; nm = body[2:]
                    else: v = struct.unpack_from('<i', body, 0)[0]; nm = body[4:]
                    cur['consts'].append((nm.decode('latin1'), v))
            elif cls == 0x60:
                if sub == 0:
                    idx += 1
                    nf, size = struct.unpack_from('<HI', body, 0) if len(body) >= 6 else (struct.unpack_from('<H', body, 0)[0], 0)
                    cur = dict(k='struct', fields=[], size=size)
                    self.t[idx] = cur
                elif sub in (1, 2, 3):
                    if sub == 1: off = body[0]; j = 1
                    elif sub == 2: off = struct.unpack_from('<H', body, 0)[0]; j = 2
                    else: off = struct.unpack_from('<I', body, 0)[0]; j = 4
                    ft, j = tidx(body, j)
                    cur['fields'].append((body[j:].decode('latin1'), off, ft))
                elif sub == 7:
                    # FIELD_CLASS: attrib, location expression, type, name
                    attr = body[0]; j = 1
                    # location expr: simplified parse of constant push
                    op = body[j]
                    off = None
                    if op == 0x84:  # length-prefixed? fall back
                        pass
                    # find offset: try forms
                    loc = body[1:]
                    # common: 0x22 <byte> or 0x23 <word> / 0x24 <dword> as const
                    k = 0
                    if loc[0] & 0xf0 == 0x80:
                        ln = loc[0] & 0x0f; expr = loc[1:1 + ln]; k = 1 + ln
                    else:
                        expr = loc[:2]; k = 2
                    if expr and expr[0] == 0x22: off = expr[1]
                    elif expr and expr[0] == 0x23: off = struct.unpack_from('<H', expr, 1)[0]
                    elif expr and expr[0] == 0x24: off = struct.unpack_from('<I', expr, 1)[0]
                    ft, j2 = tidx(loc, k)
                    cur['fields'].append((loc[j2:].decode('latin1'), off, ft))
                else:
                    cur['fields'].append(('?sub%d' % sub, None, None))
            elif cls == 0x70:
                idx += 1
                self.t[idx] = dict(k='proc')
            elif cls == 0x80:
                idx += 1
                self.t[idx] = dict(k='charblock')
            else:
                idx += 1
                self.t[idx] = dict(k='?%x' % kind)

    def name(self, i, depth=0):
        t = self.t.get(i)
        if t is None: return '?%d' % i
        k = t['k']
        if k == 'scalar':
            if t['name']: return t['name']
            c = {0: 'int', 1: 'uint', 2: 'float', 3: 'void'}.get(t['cls'], '?')
            return '%s%d' % (c, t['size'] * 8)
        if k == 'name':
            return t['name'] if depth > 0 or True else self.name(t['type'])
        if k in ('array',):
            return '%s[%d]' % (self.name(t['base'], depth + 1), t['n'])
        if k == 'array_t':
            r = self.t.get(t['index'], {})
            n = (r.get('hi', 0) - r.get('lo', 0) + 1) if r.get('k') == 'subrange' else '?'
            return '%s[%s]' % (self.name(t['base'], depth + 1), n)
        if k == 'ptr':
            return self.name(t['base'], depth + 1) + '*'
        if k == 'struct':
            return 'struct#%d' % i
        if k == 'enum':
            return 'enum#%d' % i
        return k

    def resolve(self, i):
        t = self.t.get(i)
        while t and t['k'] == 'name':
            i = t['type']; t = self.t.get(i)
        return i, t

def symbols(o, types):
    s = bytes(o.segdata[o.seg_index('$$SYMBOLS')])
    i = 0
    out = []
    while i < len(s):
        l = s[i]
        if l == 0: break
        rec = s[i:i + l]; i += l
        kind = rec[1]
        if kind == 0x12:
            ty, j = tidx(rec, 8)
            out.append((rec[j:].decode('latin1'), ty))
    return out

if __name__ == '__main__':
    o = OMF(sys.argv[1])
    segs = [k for k, s in enumerate(o.segdefs) if s and s[0] == '$$TYPES']
    T = Types(bytes(o.segdata[segs[0]]))
    for n, ty in symbols(o, T):
        print(n, T.name(ty))
    if len(sys.argv) > 2:
        for n, ty in symbols(o, T):
            if n == sys.argv[2]:
                i, t = T.resolve(ty)
                while t and t['k'] in ('array', 'array_t'):
                    i, t = T.resolve(t['base'])
                print(t.get('size'))
                for f in t.get('fields', []):
                    print('  ', f[1], f[0], T.name(f[2]))
