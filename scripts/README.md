# Scripts: Lexical contact zones in Taiwan

To reproduce everything in one go: `bash scripts/run_all.sh` (set the XML and ABVD database
paths at the top of the script first). It ends by checking the counts against the numbers
reported in the paper and prints PASS or FAIL for each.

All scripts are run from the repository root (`Rscript scripts/<name>.R`,
`python3 scripts/<name>.py`). BEAST2 runs are not repeated: the scripts start from the
deposited XMLs, logs and trees in `model/`.

## Before running

- Decompress the model outputs: `find model -name '*.xz' -exec unxz -k {} +`
- Python: `pip install -r requirements.txt`; `filter_gains.py` and `query_abvd.py` also need
  a Glottolog clone configured for `cldfcatalog` (`cldfbench catconfig`)
- ABVD: lexibank/abvd CLDF at commit 81748db (2026-10-22), converted to sqlite with
  `cldf createdb abvd/cldf/cldf-metadata.json abvd.sqlite`
- R: `process_data.R` loads Ben King's `asr_functions.R` from GitHub
  (king-ben/R-functions)

## Run order (`run_all.sh`)

| Step | Script | Input | Output | In the paper |
|---|---|---|---|---|
| 1 | `collapse_covarion.py` (run in `model/ace/`) | `asr_logger_*` files | same files, states 2→0, 3→1 | covarion states collapsed |
| 2 | `ace_extract.R` | `model/ace/asr_logger_*` | `results/gainslosses.tsv` | ACE gains and losses |
| 3 | `filter_gains.py` | `results/gainslosses.tsv`, `nocombining1.xml`, `abvd.sqlite` | `results/filteredgainslosses.tsv` | 44 gains: 29 kept, 15 excluded |
| 4 | `query_abvd.py` | kept sets, `abvd.sqlite` | `results/real_gains_abvd.tsv` | network input |
| 5 | `set_network.R` | steps 3 and 4, `sampled_ids.txt` | `networkcutoffs.png`, `networkmapfiltered.png` | network figures |
| 6 | `figures.R` | `model/run2/ccd0map` | `consensus_tree.png` | CCD0 figure |
| 7 | `densitree.R` | `model/combined2_resampled200k.trees`, `ccd0map` | `densitree_formosan.png` | Densitree |
| 8 | `credibletopologies.R` (uses `multiRF.R`) | `model/combined2_resampled200k.trees` | `summarytrees.png` | credible topologies (slow: all-pairs RF distances) |
| 9 | `count_sets.py` | `nocombining1.xml` | printed counts | 9,443 / 2,952 / 1,516 |
| — | (made by hand) | | `formosan_map.png` | map of Taiwan (Figure 2) |

## Building the XMLs (not rerun; the XMLs are deposited as they are)

- `fix_nexus.py`, `find_partitions.py`, `process_data.R`: partitions, rate groups
  (`partitions_ordered.txt`) and the ACE logger blocks pasted into the BEAST XML
- `drop_sets_list.py`, then `weights_and_check.py`: the drop8 XML for the sensitivity run

Step 4 commands:

```
awk -F'\t' 'NR > 1 && $4 == "kept" {print $2}' results/filteredgainslosses.tsv > results/kept_sets.txt
python3 scripts/query_abvd.py --sets results/kept_sets.txt --db abvd.sqlite > results/real_gains_abvd.tsv
```

drop8 commands (the eight sets removed for the sensitivity run):

```
python3 scripts/drop_sets_list.py model/nocombining1.xml tmp.xml \
    "toswell_26 who_2 ininside_18 fat_grease_2 leg_foot_46 tooth_2 toyawn_1 tohear_2"
python3 scripts/weights_and_check.py model/nocombining1.xml tmp.xml model/drop8/nocombining1_drop8.xml
```
