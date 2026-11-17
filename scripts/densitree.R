library(tidyverse)
library(ggplot2)
library(treeio)
library(rBt)
library(ggtree)

trees <- read.nexus("model/combined2_resampled200k.trees")
ccd0  <- read.beast("model/run2/ccd0map")

mrcas <- c(376, 385, 389, 393, 404, 399, 414, 410, 365, 211)

## Group tip labels into clades and assign colours
clades <- tibble(
  clade = c("Atayalic", "Northwest Formosan", "Western Plains",
            "Bunun", "Rukai", "Tsouic", "Puyuma", "Paiwan",
            "East Formosan", "Malayo-Polynesian"),
  mrca  = mrcas,
  colour = c("#f49c83", "#a8c9df", "#5d8abf",
             "#e1706d", "#d1e6f1", "#7eaacb", "#fbedb9", "#c7e9c0",
             "#f8c78e", "#d3d3d3"),
  node = sapply(mrcas, function (el) which.tips(as.phylo(ccd0), el))
) %>%
  unnest(node) %>%
  inner_join(as_tibble(ccd0), by = "node") %>%
  dplyr::select(clade, mrca, node, label, colour)

## --- Choose ONE Malayo-Polynesian doculect to retain as an outgroup ---
## Inspect candidates, then set keep_mp to one of them:
##   clades %>% filter(clade == "Malayo-Polynesian") %>% pull(label)
keep_mp <- "Tagalog_389"

## MP tips to drop = all MP except the keeper
mp_tips <- clades %>%
  filter(clade == "Malayo-Polynesian", label != keep_mp) %>%
  pull(label)

## Prune all-but-one MP tip from every posterior tree
pruned_trees <- lapply(trees, drop.tip, tip = mp_tips)
class(pruned_trees) <- "multiPhylo"

## Root on the retained MP tip (natural outgroup)
pruned_trees <- lapply(pruned_trees, function(t) {
  root(t, outgroup = keep_mp, resolve.root = TRUE)
})
class(pruned_trees) <- "multiPhylo"

## Regroup clades (MP group now just the single keeper).
## overlap = "abandon" sends contested backbone edges to group 0 (grey)
## instead of colouring them, which removes the hard mid-tree colour seams.
groups <- clades %>%
  group_by(clade) %>%
  summarise(label = list(label), .groups = "drop") %>%
  deframe()

grouped_trees <- lapply(pruned_trees, groupOTU, groups, overlap = "abandon")
class(grouped_trees) <- "multiPhylo"

## Thin if still large
if (length(grouped_trees) > 1000) {
  grouped_trees <- grouped_trees[seq(1, length(grouped_trees), by = 10)]
  class(grouped_trees) <- "multiPhylo"
}

## Named colour vector (order-independent); group 0 = grey backbone
colour_vec <- clades %>%
  dplyr::select(clade, colour) %>%
  distinct() %>%
  add_row(clade = "0", colour = "lightgrey") %>%
  deframe()

## Build densitree
dt_plot <- ggtree::ggdensitree(
  grouped_trees,
  aes(color = group),
  alpha = 0.03
) +
  scale_color_manual(
    values = colour_vec,
    breaks = clades$clade[clades$clade != "Malayo-Polynesian"]  # hide 0 and MP from legend
  )

ggsave(
  "figures/densitree_formosan.png",
  plot = dt_plot,
  width = 8,
  height = 10,
  dpi = 200,
  device = ragg::agg_png
)