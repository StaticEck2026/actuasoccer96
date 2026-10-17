"""Minimal Intel OMF (Watcom 32-bit) object parser used to recover data and
constants from the original compiled .OBJ files."""
import struct, sys

def read_index(b, i):
    v = b[i]
    if v & 0x80:
        return ((v & 0x7f) << 8) | b[i + 1], i + 2
    return v, i + 1

class OMF:
    def __init__(self, path):
        self.path = path
        self.data = open(path, 'rb').read()
        self.lnames = [None]
        self.segdefs = [None]   # (name, size)
        self.grpdefs = [None]
        self.extdefs = [None]
        self.pubdefs = {}       # name -> (seg, off)
        self.segdata = {}       # seg -> bytearray
        self.fixups = []        # (seg, off, kind, target_desc)
        self.linnums = []       # (seg, line, off)
        self.comdefs = []
        self.records = []
        self._parse()

    def _parse(self):
        d = self.data
        i = 0
        last = None  # (seg, base_off)
        while i < len(d):
            t = d[i]
            l = struct.unpack_from('<H', d, i + 1)[0]
            body = d[i + 3:i + 3 + l - 1]
            self.records.append((t, body))
            i += 3 + l
            is32 = t & 1
            rt = t & 0xfe
            if rt == 0x96:  # LNAMES
                j = 0
                while j < len(body):
                    n = body[j]; self.lnames.append(body[j + 1:j + 1 + n].decode('latin1')); j += 1 + n
            elif rt == 0x98:  # SEGDEF
                j = 1
                acbp = body[0]
                if (acbp >> 5) == 0:
                    j += 3
                if is32:
                    size = struct.unpack_from('<I', body, j)[0]; j += 4
                else:
                    size = struct.unpack_from('<H', body, j)[0]; j += 2
                ni, j = read_index(body, j)
                ci, j = read_index(body, j)
                self.segdefs.append((self.lnames[ni], size, self.lnames[ci]))
                self.segdata[len(self.segdefs) - 1] = bytearray(size)
            elif rt == 0x9a:  # GRPDEF
                ni, j = read_index(body, 0)
                self.grpdefs.append(self.lnames[ni])
            elif rt in (0x8c, 0xb4):  # EXTDEF / LEXTDEF
                j = 0
                while j < len(body):
                    n = body[j]; name = body[j + 1:j + 1 + n].decode('latin1'); j += 1 + n
                    _, j = read_index(body, j)
                    self.extdefs.append(name)
            elif rt == 0xb0:  # COMDEF
                j = 0
                while j < len(body):
                    n = body[j]; name = body[j + 1:j + 1 + n].decode('latin1'); j += 1 + n
                    _, j = read_index(body, j)
                    dt = body[j]; j += 1
                    def rdlen(j):
                        v = body[j]
                        if v <= 0x80: return v, j + 1
                        if v == 0x81: return struct.unpack_from('<H', body, j + 1)[0], j + 3
                        if v == 0x84: return body[j+1] | body[j+2] << 8 | body[j+3] << 16, j + 4
                        if v == 0x88: return struct.unpack_from('<I', body, j + 1)[0], j + 5
                        raise ValueError(v)
                    if dt == 0x61:
                        a, j = rdlen(j); b, j = rdlen(j); size = a * b
                    else:
                        size, j = rdlen(j)
                    self.extdefs.append(name)
                    self.comdefs.append((name, size))
            elif rt in (0x90, 0xb6):  # PUBDEF / LPUBDEF
                gi, j = read_index(body, 0)
                si, j = read_index(body, j)
                if si == 0:
                    j += 2
                while j < len(body):
                    n = body[j]; name = body[j + 1:j + 1 + n].decode('latin1'); j += 1 + n
                    if is32:
                        off = struct.unpack_from('<I', body, j)[0]; j += 4
                    else:
                        off = struct.unpack_from('<H', body, j)[0]; j += 2
                    _, j = read_index(body, j)
                    self.pubdefs[name] = (si, off)
            elif rt == 0xa0:  # LEDATA
                si, j = read_index(body, 0)
                if is32:
                    off = struct.unpack_from('<I', body, j)[0]; j += 4
                else:
                    off = struct.unpack_from('<H', body, j)[0]; j += 2
                chunk = body[j:]
                seg = self.segdata[si]
                if off + len(chunk) > len(seg):
                    seg.extend(bytes(off + len(chunk) - len(seg)))
                seg[off:off + len(chunk)] = chunk
                last = (si, off)
            elif rt == 0xa2:  # LIDATA
                si, j = read_index(body, 0)
                if is32:
                    off = struct.unpack_from('<I', body, j)[0]; j += 4
                else:
                    off = struct.unpack_from('<H', body, j)[0]; j += 2
                def expand(j):
                    if is32:
                        rep = struct.unpack_from('<I', body, j)[0]; j += 4
                    else:
                        rep = struct.unpack_from('<H', body, j)[0]; j += 2
                    bc = struct.unpack_from('<H', body, j)[0]; j += 2
                    if bc == 0:
                        n = body[j]; out = body[j + 1:j + 1 + n]; j += 1 + n
                    else:
                        out = b''
                        for _ in range(bc):
                            o, j = expand(j); out += o
                    return out * rep, j
                out = b''
                while j < len(body):
                    o, j = expand(j); out += o
                seg = self.segdata[si]
                if off + len(out) > len(seg):
                    seg.extend(bytes(off + len(out) - len(seg)))
                seg[off:off + len(out)] = out
                last = (si, off)
            elif rt == 0x9c:  # FIXUPP
                j = 0
                while j < len(body):
                    b0 = body[j]
                    if b0 & 0x80 == 0:  # THREAD
                        j += 1
                        method = (b0 >> 2) & 7
                        if method < 4 or (b0 & 0x40) == 0 and method < 3:
                            _, j = read_index(body, j)
                        continue
                    loc = ((b0 << 8) | body[j + 1]); j += 2
                    m = (loc >> 14) & 1
                    ltype = (loc >> 10) & 0xf
                    doff = loc & 0x3ff
                    fd = body[j]; j += 1
                    frame_thread = fd & 0x80
                    frame = (fd >> 4) & 7
                    targ_thread = fd & 0x08
                    pbit = (fd >> 2) & 1
                    targ = fd & 3
                    fdatum = None
                    if not frame_thread and frame < 3:
                        fdatum, j = read_index(body, j)
                    tdatum = None
                    if not targ_thread:
                        tdatum, j = read_index(body, j)
                    disp = 0
                    if not pbit:
                        if is32:
                            disp = struct.unpack_from('<I', body, j)[0]; j += 4
                        else:
                            disp = struct.unpack_from('<H', body, j)[0]; j += 2
                    if last:
                        tkind = ('seg', 'grp', 'ext', 'frm')[targ] if not targ_thread else 'thread'
                        if tkind == 'seg':
                            tname = self.segdefs[tdatum][0]
                        elif tkind == 'ext':
                            tname = self.extdefs[tdatum]
                        elif tkind == 'grp':
                            tname = self.grpdefs[tdatum]
                        else:
                            tname = None
                        self.fixups.append(dict(seg=last[0], off=last[1] + doff, rel=(m == 0),
                                                ltype=ltype, tkind=tkind, tidx=tdatum, tname=tname, disp=disp))
            elif rt == 0x94:  # LINNUM
                gi, j = read_index(body, 0)
                si, j = read_index(body, j)
                while j < len(body):
                    ln = struct.unpack_from('<H', body, j)[0]; j += 2
                    if is32:
                        off = struct.unpack_from('<I', body, j)[0]; j += 4
                    else:
                        off = struct.unpack_from('<H', body, j)[0]; j += 2
                    self.linnums.append((si, ln, off))

    def seg_index(self, name):
        for i, s in enumerate(self.segdefs):
            if s and s[0] == name:
                return i
        return None

if __name__ == '__main__':
    o = OMF(sys.argv[1])
    import collections
    print('segs', o.segdefs)
    print('pubs', len(o.pubdefs), 'exts', len(o.extdefs), 'fix', len(o.fixups), 'lin', len(o.linnums))
    print(collections.Counter(hex(t) for t, _ in o.records))
