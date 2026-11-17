#!/usr/bin/env bash
#
# Reproduce the post-BEAST results of "Lexical contact zones in Taiwan".
# Run from the repository root: bash scripts/run_all.sh
#
# BEAST2 runs are not repeated, and the XMLs are not rebuilt: everything starts from the
# deposited XMLs, logs and trees.
# Output goes to results/ and figures/; a full log is written to run_all.log.
#
# Requirements: python3 with requirements.txt installed, a Glottolog clone configured for
# cldfcatalog (cldfbench catconfig), R with the packages loaded by the scripts, and the ABVD
# CLDF sqlite database (commit 81748db), set in ABVD_DB below.

set -euo pipefail

# --- Settings ---------------------------------------------------------------------------
XML="model/run2/nocombining1.xml"   # main analysis XML (alignment used by the filter and counts)
ABVD_DB="/Users/isaac/projects/abvd/abvd.sqlite"          # cldf createdb abvd/cldf/cldf-metadata.json abvd.sqlite
# -----------------------------------------------------------------------------------------

exec > >(tee run_all.log) 2>&1
mkdir -p results figures

step() { printf '\n=== %s\n' "$1"; }

for f in "$XML" "$ABVD_DB"; do
    [[ -f "$f" ]] || { echo "Missing $f: see settings at the top of this script"; exit 1; }
done

step "0. R packages"
Rscript scripts/install_packages.R | tee results/R_package_versions.txt

step "1. Decompress model outputs (originals kept)"
find model -name '*.xz' -exec unxz -kf {} +

step "2. Extract ACE gains and losses"
# collapse_covarion.py edits the logger files in place, so it runs on the fresh copies above.
(cd model/ace && python3 ../../scripts/collapse_covarion.py)
Rscript scripts/ace_extract.R

step "3. Filter gains to those restricted to Taiwan"
python3 scripts/filter_gains.py \
    --gains results/gainslosses.tsv \
    --xml "$XML" \
    --db "$ABVD_DB" \
    > results/filteredgainslosses.tsv

step "4. ABVD membership of the kept sets"
awk -F'\t' 'NR > 1 && $4 == "kept" {print $2}' results/filteredgainslosses.tsv \
    > results/kept_sets.txt
python3 scripts/query_abvd.py --sets results/kept_sets.txt --db "$ABVD_DB" \
    > results/real_gains_abvd.tsv

step "5. Figures"
Rscript scripts/set_network.R          # networkcutoffs.png, networkmapfiltered.png
Rscript scripts/figures.R              # consensus_tree.png
Rscript scripts/densitree.R            # densitree_formosan.png
Rscript scripts/credibletopologies.R   # summarytrees.png (slow: all-pairs RF distances)

step "6. Cognate set counts"
python3 scripts/count_sets.py "$XML" | tee results/set_counts.txt

step "7. Check results against the numbers reported in the paper"
fail=0
check() {
    local name=$1 got=$2 want=$3
    if [[ "$got" == "$want" ]]; then
        echo "PASS  $name: $got"
    else
        echo "FAIL  $name: got $got, paper reports $want"
        fail=1
    fi
}
gains=$(awk -F'\t' 'NR > 1' results/filteredgainslosses.tsv | wc -l | tr -d ' ')
kept=$(awk -F'\t' 'NR > 1 && $4 == "kept"' results/filteredgainslosses.tsv | wc -l | tr -d ' ')
check "ACE gains at nodes of interest" "$gains" 44
check "gains kept by the filter" "$kept" 29
check "gains excluded by the filter" "$((gains - kept))" 15
check "cognate sets used" "$(awk -F': ' '/^Cognate sets used/ {print $2}' results/set_counts.txt)" 9443
check "sets found only in Taiwan" \
    "$(awk -F': ' '/^Found only/ {print $2}' results/set_counts.txt)" 2952
check "  of which in 2+ doculects" \
    "$(awk -F': ' '/two or more/ {print $2}' results/set_counts.txt)" 1516

printf '\nFigures written to figures/. Compare them with the figures in the paper.\n'
exit $fail
