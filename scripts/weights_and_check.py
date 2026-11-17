import re
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict

OLD, TMP, DST = sys.argv[1:4]

def groups(path):
    root = ET.parse(path).getroot()
    ids = {x.get("id"): x for x in root.iter() if x.get("id")}
    w, order, parts = defaultdict(int), [], []
    for d in root.iter("distribution"):
        if d.get("spec") != "TreeLikelihood":
            continue
        sm = d.get("siteModel") or [x for x in d if x.tag == "siteModel"][0].get("id")
        sm = sm.lstrip("@").split(":")[1]
        if sm not in order:
            order.append(sm)
        fs = [x.get("filter") for x in d.iter() if x.get("filter") not in (None, "-")]
        if not fs:
            refs = [x.get("data") or x.get("idref") for x in d.iter("data")]
            fs = [
                ids[r.lstrip("@")].get("filter")
                for r in refs
                if r and r.lstrip("@") in ids
                and ids[r.lstrip("@")].get("filter") not in (None, "-")
            ]
        a, b = map(int, fs[0].split("-"))
        w[sm] += b - a
        parts.append((d.get("id"), a, b))
    return [w[s] for s in order], parts

def table(path):
    t = open(path, encoding="utf-8").read()
    labs = re.findall(r'characterName="([^"]*)"', t)
    seqs = dict(re.findall(r'<sequence [^>]*taxon="([^"]*)"[^>]*value="([^"]*)"', t))
    return t, labs, seqs

new_w, _ = groups(TMP)
text = open(TMP, encoding="utf-8").read()
text, k = re.subn(
    r'(<weightvector [^>]*>)[^<]*(</weightvector>)',
    lambda m: m.group(1) + " ".join(map(str, new_w)) + m.group(2),
    text,
)
assert k == 1
open(DST, "w", encoding="utf-8").write(text)

# Checks.
_, labs0, seq0 = table(OLD)
_, labs1, seq1 = table(DST)
old_w, parts0 = groups(OLD)
new_w2, parts1 = groups(DST)
print("columns", len(labs0), "->", len(labs1))
print("weights", old_w, "->", new_w2, "diff", sum(old_w) - sum(new_w2))
kept = [i for i, l in enumerate(labs0) if l in set(labs1)]
assert [labs0[i] for i in kept] == labs1
for tx in seq0:
    assert len(seq1[tx]) == len(labs1)
    assert "".join(seq0[tx][i] for i in kept) == seq1[tx]
# Each partition keeps the same labels, minus the dropped ones.
dropped = set(labs0) - set(labs1)
for (p0, a0, b0), (p1, a1, b1) in zip(parts0, parts1):
    assert p0 == p1
    old_l = [l for l in labs0[a0 - 1:b0] if l not in dropped]
    assert old_l == labs1[a1 - 1:b1], p0
    assert labs1[a1 - 1].endswith("0ascertainment")
print("dropped", sorted(dropped))
print("all checks passed")
