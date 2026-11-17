"""
Ben's find_partitions R function is not working on the latest nexus,
don't know why but this is a rewrite which does
"""
import argparse
import re


def find_partitions(lines):
    ass = lines.index("begin assumptions;")
    partitions = []
    for line in lines[ass + 1:-1]:
        charset = line.strip().split(" ")[1]
        start, end = re.findall("\d+", line)
        partitions.append([charset, start, end])
    return partitions


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Does something.')
    parser.add_argument("filename", help='filename')
    args = parser.parse_args()
    with open(args.filename) as f:
        lines = f.read().splitlines()
        partitions = find_partitions(lines)
        for p in partitions:
            charset, start, end = p
            print(f"{charset}\t{start}\t{end}")
