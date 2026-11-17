#!/usr/bin/env python3
# coding=utf-8
"""
Fix assumptions block. Give it a file containing only the
assumptions block as input
"""

import re
from collections import Counter, defaultdict

is_unique = re.compile(r"""^(.*)_u_(.*)$""")

def parse_sites(x):
    if '-' in x:
        x = [int(_) for _ in x.split("-")]
        assert len(x) == 2, 'badly formatted'
        yield from range(x[0], x[1]+1)
    else:
        yield int(x)


def fix(filename):
    blocks = defaultdict(list)
    
    with open(args.filename, 'r') as handle:
        for line in handle:
            line = line.strip().lstrip()
            if not len(line):
                continue
            elif line.lower() in ('end;', 'begin assumptions;'):
                continue
            else:
                _, label, _, sites = line.strip(";").split()
                if m:= is_unique.findall(label):
                    blocks[m[0][0]].extend(parse_sites(sites))
                else:
                    blocks[label].extend(parse_sites(sites))
    return blocks


def is_sequential(sites):
    return sorted(sites) == sorted(range(min(sites), max(sites) + 1))


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Does something.')
    parser.add_argument("filename", help='filename')
    args = parser.parse_args()
    
    charsets = fix(args.filename)
    seen_sites = Counter()
    
    print("begin assumptions;")
    for word in sorted(charsets):
        assert is_sequential(charsets[word]), '%s is not sequential' % word
        print("\tcharset %s = %d-%d;" % (word, min(charsets[word]), max(charsets[word])))
        seen_sites.update(charsets[word])
    print('end;')
        
    # sanity check that we've seen everything once and only once
    assert min(seen_sites) == 1, 'should start at 1'
    for i in range(1, max(seen_sites) + 1):
        if seen_sites[i] != 1:
            raise ValueError("Should have seen site %d only once, not %d" % (i, seen_sites[i]))
    assert max(seen_sites) == len(seen_sites)
