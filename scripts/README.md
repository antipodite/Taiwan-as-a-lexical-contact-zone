# How to

Follow the instructions below to set things up. After you do that, from the project root, run `bash run_all.sh`. This will decompress the BEAST2 outputs needed, collapse the covarion states, run the R code that analyses the outputs and create the figures. It will print out some checks at the end, with PASS if each one passes. It also wrties a log file to the project root. Lettuce know if you have any problems

## Before running

Make sure you have `xz` installed using `brew install xz` or install from your distribution's package manager.

### Python environment

```
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt   # includes pycldf, cldfbench, cldfcatalog, pyglottolog
```

### Glottolog

`filter_gains.py` and `query_abvd.py` classify languages with a local Glottolog clone, located
through `cldfcatalog`. If you don't already have one configured:

```
cldfbench catconfig
```

This offers to clone Glottolog (and other catalogs) and records where they are. Answer yes for
Glottolog. Then check out the version used for the paper:

```
git -C <path to glottolog clone> checkout <glottolog version>
```

### ABVD

The filter and the network use the lexibank ABVD CLDF dataset at commit 81748db (2026-10-22),
converted to a SQLite database at the repository root:

```
git clone https://github.com/lexibank/abvd.git ../abvd
git -C ../abvd checkout 81748db
cldf createdb ../abvd/cldf/cldf-metadata.json abvd.sqlite
```

`run_all.sh` expects `abvd.sqlite` in the repository root (set `ABVD_DB` at the top of the
script to change this).

### R

`Rscript scripts/install_packages.R` installs the R packages (CRAN, Bioconductor, GitHub) and
prints their versions. `ace_extract.R` loads brother Ben's `asr_functions.R` from GitHub
(king-ben/R-functions)

### Model outputs

The model outputs are compressed so they will fit into Github's stingy file size allowance
`run_all.sh` decompresses them itself. To do it by hand:
`find model -name '*.xz' -exec unxz -k {} +` (you won't need to though) (I hope)

### ???
