"""For each undefined constant, print the source lines that use it together
with the disassembly the original compiler produced for those lines."""
import re, sys, os, glob, collections
L = os.path.join(os.path.dirname(__file__), 'listings')
mods = ['FOOTBALL', 'ACTIONS', 'INTELL', 'BALL', 'BALLINT', 'RULES', 'USER', '3D_UPD2', 'MATHS', 'DISPLAY']
blocks = {}
for m in mods:
    cur = None
    for line in open(os.path.join(L, m + '.lst')):
        mm = re.match(r'  ; \[(\d+)\] (.*)', line)
        if mm:
            cur = (m, int(mm.group(1)))
            blocks.setdefault(cur, [mm.group(2)])
            continue
        if line.startswith('=========='):
            cur = None
            continue
        if cur and line.startswith('    '):
            blocks[cur].append(line.rstrip())
names = [l.split()[0] for l in open(sys.argv[1])]
maxn = int(sys.argv[2]) if len(sys.argv) > 2 else 3
for n in names:
    print('#' * 10, n)
    shown = 0
    pat = re.compile(r'\b' + re.escape(n) + r'\b')
    for (m, ln), b in sorted(blocks.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        if pat.search(b[0]):
            print('--- %s:%d  %s' % (m, ln, b[0]))
            for x in b[1:40]:
                print(x)
            shown += 1
            if shown >= maxn:
                break
    if not shown:
        print('  (no aligned code found)')
