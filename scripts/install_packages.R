## Install the R packages used by the scripts in this folder.
## Run once from the repository root: Rscript scripts/install_packages.R
##
## sf needs the GDAL, GEOS and PROJ system libraries (on macOS: brew install gdal).

cran <- c(
    "tidyverse", "data.table", "devtools", "remotes", "XML",
    "ape", "phangorn", "phytools", "TreeTools",
    "gridExtra", "cowplot", "patchwork", "ragg", "viridis",
    "igraph", "ggraph", "ggrepel", "reshape2",
    "sf", "rnaturalearth", "rnaturalearthdata", "mapdata",
    "reticulate", "BiocManager"
)
missing <- setdiff(cran, rownames(installed.packages()))
if (length(missing) > 0) {
    install.packages(missing, repos = "https://cloud.r-project.org")
}

## Bioconductor
for (pkg in c("treeio", "ggtree")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
        BiocManager::install(pkg, update = FALSE, ask = FALSE)
    }
}

## High-resolution coastlines for ne_countries(scale = "large") in set_network.R
if (!requireNamespace("rnaturalearthhires", quietly = TRUE)) {
    install.packages("rnaturalearthhires", repos = "https://ropensci.r-universe.dev")
}

## GitHub: which.tips() and which.node()
if (!requireNamespace("rBt", quietly = TRUE)) {
    remotes::install_github("santiagosnchez/rBt")
}

## Record versions
all_pkgs <- c(cran, "treeio", "ggtree", "rnaturalearthhires", "rBt")
versions <- vapply(all_pkgs, function(p) as.character(packageVersion(p)), character(1))
cat(R.version.string, "\n")
cat(paste(all_pkgs, versions), sep = "\n")
