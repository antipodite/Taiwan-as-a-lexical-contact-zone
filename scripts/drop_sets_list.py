import re
import sys
from bisect import bisect_left, bisect_right

SRC, DST = sys.argv[1], sys.argv[2]
BAD = sys.argv[3].split() if len(sys.argv) > 3 else (
    "toswell_26 smoke_1 who_2 ininside_18 fat_grease_2 leg_foot_46 tosniffsmell_1 tooth_2 "
    "toyawn_1 other_1 towalk_21 tongue_1 tohear_2 thunder_3 at_1 if_2 toclimb_2 tostand_1 "
    "meat_flesh_1"
).split()

text = open(SRC, encoding="utf-8").read()
labels = re.findall(r'characterName="([^"]*)"', text)
col = {name: i for i, name in enumerate(labels)}  # 0-based
drop = sorted(col[b] for b in BAD)
assert len(drop) == len(BAD)
drop_set = set(drop)

# Remove columns from every sequence.
def fix_seq(m):
    s = m.group(2)
    assert len(s) == len(labels)
    return m.group(1) + "".join(c for i, c in enumerate(s) if i not in drop_set) + m.group(3)

text = re.sub(r'(<sequence [^>]*value=")([^"]*)(")', fix_seq, text)

# Remove the character-label lines.
for b in BAD:
    text, k = re.subn(r'\n[ \t]*<charstatelabels [^>]*characterName="%s"[^>]*/>' % re.escape(b), "", text)
    assert k == 1, b

# Shift 1-based inclusive filter ranges.
def fix_range(m):
    a, b = int(m.group(1)), int(m.group(2))
    na = a - bisect_left(drop, a - 1)
    nb = b - bisect_right(drop, b - 1)
    return 'filter="%d-%d"' % (na, nb)

text = re.sub(r'filter="(\d+)-(\d+)"', fix_range, text)

# Weight vector: sites per rate group excluding ascertainment columns.
old_w = [58, 292, 931, 1015, 1637, 1950, 1091, 993, 675, 474, 210, 117]
open(DST, "w", encoding="utf-8").write(text)
