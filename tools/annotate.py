"""Produce an annotated disassembly listing of a Watcom OMF object, interleaved
with the (aligned) original C++ source lines. Used to recover the values of
#define constants whose headers are missing from the source release."""
import sys, re, struct, bisect
sys.path.insert(0, __import__('os').path.dirname(__file__))
from omf import OMF
import capstone

def load_src(path):
    return open(path, 'rb').read().decode('latin1').replace('\r', '').split('\n')

def find_func_lines(src):
    res = {}
    for i, l in enumerate(src):
        m = re.match(r'^[A-Za-z_][\w \*&]*?\b(\w+)\s*\(([^;]*)$', l)
        if m and not l.startswith('extern') and not l.startswith('//'):
            res.setdefault(m.group(1), []).append(i + 1)
    return res

def demangle(n):
    # Watcom mangling W?name$... -> name
    m = re.match(r'W\?(\w+?)\$', n)
    if m:
        return m.group(1)
    m = re.match(r'W\?(\w+)', n)
    if m:
        return m.group(1)
    return n.lstrip('_').rstrip('_')

def main(objpath, srcpath, out):
    o = OMF(objpath)
    src = load_src(srcpath)
    fl = find_func_lines(src)
    text = o.seg_index('_TEXT')
    code = bytes(o.segdata[text])
    const = o.seg_index('CONST')
    data = o.seg_index('_DATA')
    bss = o.seg_index('_BSS')
    # public symbols per segment
    pubs = {}
    for n, (s, off) in o.pubdefs.items():
        pubs.setdefault(s, []).append((off, demangle(n)))
    for s in pubs: pubs[s].sort()
    funcs = pubs.get(text, [])
    fix = {}
    for f in o.fixups:
        if f['seg'] == text:
            fix[f['off']] = f
    lin = sorted((off, ln) for s, ln, off in o.linnums if s == text)
    loffs = [x[0] for x in lin]

    def symname(seg, disp):
        lst = pubs.get(seg, [])
        k = bisect.bisect_right([p[0] for p in lst], disp) - 1
        if k >= 0:
            off, n = lst[k]
            return n + ('+%d' % (disp - off) if disp != off else '')
        return '%s+%d' % (o.segdefs[seg][0], disp)

    def describe(f, insn_bytes_len):
        if f['tkind'] == 'ext':
            return f['tname'] and demangle(f['tname'])
        if f['tkind'] == 'seg':
            seg = f['tidx']
            disp = f['disp']
            return symname(seg, disp), seg, disp
        return str(f)

    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    md.detail = False
    md.skipdata = True
    out = open(out, 'w')
    fstarts = {off: n for off, n in funcs}
    fsorted = sorted(fstarts)
    cur_delta = 0
    lastline = None
    for insn in md.disasm(code, 0):
        a = insn.address
        if a in fstarts:
            name = fstarts[a]
            k = bisect.bisect_right(loffs, a) - 1
            objline = lin[k][1] if k >= 0 else 0
            cand = fl.get(name, [])
            if cand:
                srcline = min(cand, key=lambda c: abs(c - objline))
                cur_delta = objline - srcline
            out.write('\n========== %s  (obj line %d, delta %d)\n' % (name, objline, cur_delta))
        k = bisect.bisect_right(loffs, a) - 1
        if k >= 0 and lin[k][0] == a and lin[k][1] != lastline:
            ln = lin[k][1]
            lastline = ln
            sl = ln - cur_delta
            txt = src[sl - 1].strip() if 0 < sl <= len(src) else '?'
            out.write('  ; [%d] %s\n' % (sl, txt))
        ann = []
        for b in range(a, a + insn.size):
            if b in fix:
                f = fix[b]
                d = describe(f, insn.size)
                if isinstance(d, tuple):
                    n, seg, disp = d
                    # read in-place addend
                    if seg == const:
                        cb = bytes(o.segdata[const])
                        addend = struct.unpack_from('<I', code, b)[0]
                        p = disp + addend
                        if p + 8 <= len(cb):
                            fv = struct.unpack_from('<f', cb, p)[0]
                            dv = struct.unpack_from('<d', cb, p)[0]
                            n = 'CONST+%d f=%g d=%g' % (p, fv, dv)
                        else:
                            n = 'CONST+%d' % p
                    elif seg in (data, bss):
                        addend = struct.unpack_from('<I', code, b)[0]
                        n = symname(seg, disp + addend)
                    ann.append(n)
                else:
                    ann.append(str(d))
        out.write('    %05x: %-8s %-40s %s\n' % (a, insn.mnemonic, insn.op_str, ('; ' + ', '.join(ann)) if ann else ''))

if __name__ == '__main__':
    main(*sys.argv[1:4])
