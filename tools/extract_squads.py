"""Extract the Euro 96 squads (names, positions, the 8 match attributes and
fitness) and team names/default formations from SOURCE/SCRIPT.96 (the
front-end script compiled by EURO_GEN.CPP process_script_file) into
godot/data/squads.json."""
import re, json, os
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, '..', 'SOURCE', 'SCRIPT.96'), 'rb').read().decode('cp437').replace('\r', '')
lines = src.split('\n')
teams = []
i = lines.index(next(l for l in lines if l.strip(' \t\x7f').startswith('PLYR_NMES')))
cur = None
for l in lines[i + 1:]:
    if l.strip().startswith('> Team/Country Names'):
        break
    m = re.match(r'\s*>\s*(.+?)\s*$', l)
    if m:
        cur = {'country': m.group(1), 'players': []}
        teams.append(cur)
        continue
    m = re.match(r'\s*t:\s*"([^"]*)"\s*(\S*)?.*?posn:\s*(\w+)\s+pace:(\d+)\s+pow:(\d+)\s+cntl:(\d+)\s+flar:(\d+)\s+visn:(\d+)\s+acc:(\d+)\s+stam:(\d+)\s+disc:(\d+)\s+fit:(\d+)', l)
    if m and cur is not None:
        name = m.group(1)
        star = '[*]' in l
        cur['players'].append(dict(name=name, star=star, posn=m.group(3),
            pace=int(m.group(4)), power=int(m.group(5)), control=int(m.group(6)), flair=int(m.group(7)),
            vision=int(m.group(8)), accuracy=int(m.group(9)), stamina=int(m.group(10)),
            discipline=int(m.group(11)), fitness=int(m.group(12))))
j = lines.index(next(l for l in lines if l.strip(' \t\x7f').startswith('TEAM_NMES')))
k = 0
for l in lines[j + 1:]:
    m = re.match(r'\s*t:\s*"([^"]*)"\s*form:\s*([\d-]+)', l)
    if m:
        teams[k]['name'] = m.group(1)
        teams[k]['formation'] = m.group(2)
        k += 1
        if k == len(teams):
            break
# squad numbers
j = lines.index(next(l for l in lines if l.strip(' \t\x7f').startswith('SQUD_NMBS')))
nums = []
for l in lines[j + 1:j + 40]:
    m = re.match(r'\s*t:\s*"([^"]*)"', l)
    if m:
        nums.append(m.group(1))
json.dump({'teams': teams, 'squad_numbers': nums}, open(os.path.join(HERE, '..', 'godot', 'data', 'squads.json'), 'w'), indent=1)
print(len(teams), [len(t['players']) for t in teams], [t.get('name') for t in teams][:4], nums[:5])
