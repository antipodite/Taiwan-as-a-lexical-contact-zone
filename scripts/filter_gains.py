#! /usr/bin/env python3
"""
Filter ACE-reconstructed gains down to innovations restricted to Taiwan.

A gain is kept only if its cognate set has no Austronesian reflex outside Taiwan, either
(1) in a sampled language, according to the alignment in the BEAST XML, or
(2) in any language in the ABVD, according to the ABVD CLDF sqlite database.

"Outside Taiwan" means: an Austronesian language whose Glottolog lineage contains
Malayo-Polynesian. Proto-languages are ignored. Non-Austronesian comparanda in the ABVD
are ignored. A language whose glottocode cannot be resolved in Glottolog is counted as a
witness outside Taiwan, so that the filter errs on the side of exclusion, and is reported.

Usage:
    cldf createdb path/to/abvd/cldf/cldf-metadata.json abvd.sqlite
    python3 filter_gains.py \
        --gains ace_original.tsv \
        --xml nocombining1.xml \
        --db abvd.sqlite \
        > ace_gains_filtered.tsv

The gains file is tab-separated with a header: cognate_set, posterior, type, taxon.
Only rows with type "gain" are filtered; losses are skipped.
"""
import csv
import re
import sqlite3
import sys
from argparse import ArgumentParser
from collections import defaultdict

from cldfcatalog import Config
from pyglottolog import Glottolog

AUSTRONESIAN = "aust1307"
MALAYO_POLYNESIAN = "mala1545"
URL = "https://abvd.clld.org/cognatesets/{}"

QUERY = """
SELECT
    ct.cldf_cognatesetReference AS cognate_set,
    lt.cldf_id AS language_id,
    lt.cldf_name AS name,
    lt.cldf_glottocode AS glottocode
FROM FormTable ft
INNER JOIN CognateTable ct ON ct.cldf_formReference = ft.cldf_id
INNER JOIN LanguageTable lt ON lt.cldf_id = ft.cldf_languageReference
WHERE lt.cldf_name NOT LIKE "%proto%"
"""


def abvd_set_id(nexus_set):
    """Convert an alignment set name (e.g. painful_sick_3) to an ABVD ID (painfulsick-3)."""
    parts = nexus_set.split("_")
    return "".join(parts[:-1]) + "-" + parts[-1]


def read_alignment(xml_path):
    """Return the character labels and a dict of taxon -> 0/1/? string from the BEAST XML."""
    with open(xml_path, encoding="utf-8") as f:
        text = f.read()
    labels = re.findall(r'characterName="([^"]*)"', text)
    sequences = dict(re.findall(r'<sequence [^>]*taxon="([^"]*)"[^>]*value="([^"]*)"', text))
    for taxon, seq in sequences.items():
        if len(seq) != len(labels):
            sys.exit(f"Sequence length for {taxon} does not match number of character labels")
    return labels, sequences


def read_abvd(db_path):
    """Return set ID -> [(language_id, name, glottocode)] and language_id -> glottocode."""
    with sqlite3.connect(db_path) as conn:
        rows = conn.execute(QUERY).fetchall()
    members = defaultdict(list)
    glottocodes = {}
    for cognate_set, language_id, name, glottocode in rows:
        members[cognate_set].append((language_id, name, glottocode))
        glottocodes[language_id] = glottocode
    return members, glottocodes


class Classifier:
    """Classify glottocodes as Austronesian outside Taiwan, Formosan, or not Austronesian."""

    def __init__(self, glottolog):
        self.glottolog = glottolog
        self.cache = {}

    def classify(self, glottocode):
        """Return "outside", "formosan", "non-an" or "unknown"."""
        if glottocode in self.cache:
            return self.cache[glottocode]
        lg = self.glottolog.languoid(glottocode) if glottocode else None
        if lg is None:
            result = "unknown"
        else:
            lineage = {code for _, code, _ in lg.lineage} | {lg.glottocode}
            if AUSTRONESIAN not in lineage:
                result = "non-an"
            elif MALAYO_POLYNESIAN in lineage:
                result = "outside"
            else:
                result = "formosan"
        self.cache[glottocode] = result
        return result

    def is_outside(self, glottocode):
        """Austronesian outside Taiwan; unresolved glottocodes are counted as outside."""
        return self.classify(glottocode) in ("outside", "unknown")


def taxon_language_id(taxon):
    """Alignment taxon names end in the ABVD language ID, e.g. Tagalog_389 -> 389."""
    return taxon.rsplit("_", 1)[1]


def main():
    parser = ArgumentParser(prog="Filter ACE gains to innovations restricted to Taiwan")
    parser.add_argument("--gains", required=True, help="TSV of ACE results")
    parser.add_argument("--xml", required=True, help="BEAST XML containing the alignment")
    parser.add_argument("--db", required=True, help="ABVD CLDF sqlite database")
    args = parser.parse_args()

    labels, sequences = read_alignment(args.xml)
    column = {label: i for i, label in enumerate(labels)}
    members, abvd_glottocodes = read_abvd(args.db)

    cfg = Config.from_file()
    glottolog = Glottolog(cfg.get_clone("glottolog"), cache=True)
    classifier = Classifier(glottolog)

    writer = csv.writer(sys.stdout, delimiter="\t", lineterminator="\n")
    writer.writerow([
        "node",
        "cognate_set",
        "posterior",
        "filter",
        "reason",
        "sample_witnesses",
        "abvd_witnesses",
        "abvd_url",
    ])

    with open(args.gains, encoding="utf-8") as f:
        rows = [r for r in csv.DictReader(f, delimiter="\t") if r.get("cognate_set")]

    unknown = set()
    for row in rows:
        if row["type"] != "gain":
            continue
        nexus_set = row["cognate_set"]
        set_id = abvd_set_id(nexus_set)

        # (1) Witnesses outside Taiwan among the sampled languages, from the alignment.
        if nexus_set not in column:
            sys.exit(f"{nexus_set} not found in alignment")
        i = column[nexus_set]
        sample_witnesses = []
        for taxon, seq in sequences.items():
            if seq[i] != "1":
                continue
            glottocode = abvd_glottocodes.get(taxon_language_id(taxon))
            if classifier.is_outside(glottocode):
                sample_witnesses.append(taxon)

        # (2) Witnesses outside Taiwan anywhere in the ABVD.
        abvd_witnesses = []
        for language_id, name, glottocode in members.get(set_id, []):
            if classifier.is_outside(glottocode):
                abvd_witnesses.append(name)
                if classifier.classify(glottocode) == "unknown":
                    unknown.add((name, glottocode))
        abvd_witnesses = sorted(set(abvd_witnesses))

        if sample_witnesses:
            status, reason = "excluded", "attested outside Taiwan in sample"
        elif abvd_witnesses:
            status, reason = "excluded", "attested outside Taiwan in ABVD"
        else:
            status, reason = "kept", ""

        writer.writerow([
            row["taxon"],
            nexus_set,
            row["posterior"],
            status,
            reason,
            "; ".join(sample_witnesses),
            "; ".join(abvd_witnesses),
            URL.format(set_id),
        ])

    for name, glottocode in sorted(unknown):
        print(f"Warning: unresolved glottocode {glottocode!r} for {name}; counted as outside",
              file=sys.stderr)


if __name__ == "__main__":
    main()
