#! /usr/bin/env python3
"""
Check geographical and subgroup membership of ABVD cognate sets
Isaac Aug 2024
"""
import sqlite3
from argparse import ArgumentParser
from itertools import groupby

import tqdm
import tabulate
from cldfcatalog import Config
from pyglottolog import Glottolog


QUERY = """
SELECT
ct.cldf_cognatesetReference as cognate_set,
lt.cldf_id as language_id,
lt.cldf_name,
lt.cldf_glottocode,
ft.cldf_form,
ft.cldf_segments
FROM FormTable ft
INNER JOIN CognateTable ct ON ct.cldf_formReference = ft.cldf_id
INNER JOIN LanguageTable lt ON lt.cldf_id = ft.cldf_languageReference
WHERE lt.cldf_name NOT LIKE "%proto%"
"""


def run_sql(dbfile, query):
    """Execute query against `dbfile` and return result as a list of dicts keyed by field name"""
    def dict_factory(cursor, row):
        fields = [column[0] for column in cursor.description]
        return {key: value for key, value in zip(fields, row)}
    
    with sqlite3.connect(dbfile) as conn:
        conn.row_factory = dict_factory
        rows = conn.execute(query).fetchall()
    return rows


def index_by_cognate_set(rows):
    """Get a dict of all glottocodes where the cognate set appears.
    Return: dict where keys are cognate sets and values are content
    of row.
    """
    result = {}
    for k, g in groupby(sorted(rows, key=lambda r: r["cognate_set"]), lambda r: r["cognate_set"]):
        result[k] = list(g)
    return result


def language_level(lg):
    """Make sure we're getting language level languoids and not docus / dialects"""
    if lg.level.name == "language":
        return lg
    for ancestor in reversed(lg.ancestors):
        if ancestor.level.name == "language":
            return ancestor
    return lg


def glottocodes_for_set(index, cognate_set):
    return {r["cldf_glottocode"] for r in index[cognate_set]}


def get_glottolog_mrca(glottolog, glottocodes):
    """Find the MRCA of a set of glottocodes according to Glottolog"""
    pass


def get_primary_subgroup(glottolog, glottocode):
    """Get the primary branch of the glottocode.
    Some glottocodes have been changed and now ABVD data is out of sync,
    so need to check if a valid Languoid is returned
    """
    # if not glottocode:
    #     return None
    lg = glottolog.languoid(glottocode)
    # if not lg:
    #     return None
    lineage = lg.lineage
    if not lineage:
        return lg
    family_name, family_code, _ = lineage[0]
    if len(lineage) == 1:
        primary = lg
    else:
        primary_name, primary_code, _ = lineage[1]
        primary = glottolog.languoid(primary_code)
    return primary


def main():
    parser = ArgumentParser(prog="ABVD cognate set checker")
    parser.add_argument(
        "--sets",
        required=True,
        help="Text file with cognate set IDs delimited by newlines"
    )
    parser.add_argument(
        "--db",
        required=True,
        help="Location of ABVD sqlite database"
    )
    parser.add_argument(
        "--filter",
        required=False,
        help="Filter out sets which appear in this subgroup"
    )
    parser.add_argument(
        "--family",
        required=False,
        help="Restrict to this language family"
    )
    args = parser.parse_args()

    # Load data we need
    rows = run_sql(args.db, QUERY)
    index = index_by_cognate_set(rows)

    with open(args.sets) as f:
        # Match the cognate set format in the nexus
        sets_of_interest = []
        for s in f.read().splitlines():
            els = s.split("_")
            edited = "".join(els[:-1]) + "-" + els[-1]
            sets_of_interest.append(edited)
    
    # Load Glottolog
    cfg = Config.from_file()
    glottolog = Glottolog(cfg.get_clone("glottolog"), cache=True)

    result = []
    for cognate_set in tqdm.tqdm(sets_of_interest):
        glottocodes = [r["cldf_glottocode"] for r in index[cognate_set]]
        forms = [r["cldf_form"] for r in index[cognate_set]]
        segments = [r["cldf_segments"] for r in index[cognate_set]]
        ids = [r["language_id"] for r in index[cognate_set]]
        for lid, gc, form, segments in zip(ids, glottocodes, forms, segments):
            lg = language_level(glottolog.languoid(gc))
            if lg:
                primary = get_primary_subgroup(glottolog, gc)
                family = lg.family.name if lg.family else lg.name
                row = [
                    cognate_set,
                    lid,
                    lg.name,
                    family,
                    lg.latitude,
                    lg.longitude,
                    primary.name,
                    primary.glottocode,
                    form,
                    segments
                ]
                if row not in result:
                    result.append(row)

    # Filter back to single family (What is this actually doing I ca't remember? -- ed.)
    if args.family:
        result = [r for r in result if r[2] == args.family]
    headers = [
        "cognate_set",
        "language_id",
        "name",
        "family",
        "latitude",
        "longitude",
        "primary_branch",
        "glottocode",
        "form",
        "segments"
    ]
    print(tabulate.tabulate(result, tablefmt="tsv", headers=headers))


if __name__ == "__main__":
    main()
