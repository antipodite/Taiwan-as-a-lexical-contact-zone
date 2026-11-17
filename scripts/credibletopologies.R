## Ben's credible topology set analysis

library(devtools)
library(XML)
library(readr)
library(data.table)
library(dplyr)
library(tibble)
library(purrr)
library(ape)
library(phangorn)
library(ggtree)
library(ggplot2)
library(gridExtra)

source("scripts/multiRF.R")

##
## Analysis
##

thinned_trees <- read.nexus("model/combined2_resampled200k.trees")

# Representative tips for each clade
tenbranch_tips <- c("Amis_Central_350", # East Formosan
                    "Rukai_Tona_815", # Rukai
                    "Tsou_T63_138", # Tsouic
                    "Puyuma_Katipul_L04_811", # Puyuma
                    "Paiwan_Tjubar_L04_808", # Paiwan
                    "Atayal_Squliq_L04_819", # Atayalic
                    "Pazih_F69_266", # NW Formosan
                    "Papora_Ts82_637", # W Plains
                    "Bunun_Iskubun_805", # Bunun
                    "Maori_85") # Malayo-Polynesian
group_names <- c("East Formosan",
                 "Rukai",
                 "Tsouic",
                 "Puyuma",
                 "Paiwan",
                 "Atayalic",
                 "Northwest Formosan",
                 "Western Plains",
                 "Bunun",
                 "Malayo-Polynesian")

# Prune trees back to representative tips
thinned_trees <- lapply(thinned_trees, keep.tip, tip = tenbranch_tips)
class(thinned_trees) <- "multiPhylo"

# Replace tip names with group names
subst_groups <- function(tree, tip_names, group_names) {
  for (i in seq_along(tip_names)) {
    tip <- tip_names[i]
    group <- group_names[i]
    tree$tip.label[which(tree$tip.label == tip)] <- group
  }
  return(tree)
}

thinned_trees <- lapply(thinned_trees, 
                        partial(subst_groups,
                                tip_names = tenbranch_tips, 
                                group_names = group_names))

# Calculate RF distance between all trees. When RF distance == 0, trees are
# the same.
rfsamples_rooted <- RFsample_rooted(thinned_trees, thinned_trees)
rfsamples_unrooted <- RFsample_unrooted(thinned_trees, thinned_trees)

## Remove duplicates and trees identical to themselves in terms of RF distance
remove_identical_trees <- function(sample)
{
  u <- list()
  for (i in 1:nrow(sample)) {
    u[[i]] <- c(i, which(sample[i,] == 0))
  }
  u <- u |> 
    lapply(unique) |>
    lapply(sort) |>
    unique()
  return(u[order(sapply(u, length), decreasing = T)])
}

## Convert to a list containing tree and posterior probability
make_rf_treelist <- function(posterior, rootedrf, unrootedrf)
{
  tl <- list()
  for(i in 1:length(rootedrf)){
    tl[[i]] <- list()
    tl[[i]][[1]] <- thinned_trees[[rootedrf[[i]][1]]]
    tl[[i]][[2]] <- length(rootedrf[[i]]) / length(posterior)
    unrootind <- which(lapply(unrootedrf, intersect, rootedrf[[i]][1]) > 0)
    tl[[i]][[3]] <- length(unrootedrf[[unrootind]]) / length(posterior)
    names(tl[[i]]) <- c("tree", "posterior", "unrootedposterior") 
  }
  return(tl)
}

treelist <- make_rf_treelist(thinned_trees,
                             remove_identical_trees(rfsamples_rooted),
                             remove_identical_trees(rfsamples_unrooted))

##
## Plots
##


## Plot trees and posterior probability - basic plot

pdf(file = "figures/summary trees.pdf", width = 4)
par(mar = c(0, 0, 2, 0))
par(mfrow = c(5, 3))

for(i in 1:15){
  plot(treelist[[i]]$tree, 
       use.edge.length = F, 
       main = round(treelist[[i]]$posterior, digits=3), 
       cex = 0.5, 
       type = "phylogram")
}
dev.off()

## ggtree plot with colours. library(xlsx) crashes R for some reason

branch_colours <- c(
    "Atayalic" = "#f49c83",
    "Northwest Formosan" = "#a8c9df",
    "Western Plains" = "#5d8abf",
    "Bunun" = "#e1706d",
    "Rukai" = "#d1e6f1",
    "Tsouic" = "#7eaacb",
    "Puyuma" = "#fbedb9",
    "Paiwan" = "#c7e9c0",
    "East Formosan" = "#f8c78e",
    "Malayo-Polynesian" = "#d3d3d3"
)

cred <- 0
colour_tip_plot <- list()
for (i in 1:15) {
    q <- ggtree(treelist[[i]]$tree, branch.length = "none", right = TRUE, size = 0.7) +
        geom_tiplab(aes(color = label), size = 1.8, offset = 0.4) +
        scale_color_manual(values = branch_colours) +
        guides(color = "none") +
        xlim(0, 12) +
        labs(title = round(treelist[[i]]$posterior, digits = 3)) +
        theme(plot.title = element_text(hjust = 0.5, size = 8))
    colour_tip_plot[[i]] <- q
    cred <- cred + treelist[[i]]$posterior
}

grid.arrange(grobs = colour_tip_plot[1:15], ncol = 3, nrow = 5)

colour_branch_plot <- lapply(1:15, function(i) {
    tr <- treelist[[i]]$tree
    groups <- as.list(setNames(group_names, group_names))
    tr <- groupOTU(tr, groups)
    ggtree(tr, aes(color = group), branch.length = "none",
           right = TRUE, size = 4) +
        geom_tiplab(size = 8, offset = 0.4, color = "black") +
        scale_color_manual(
            values = c("0" = "grey60", branch_colours),
            limits = c("0", names(branch_colours))
        ) +
        guides(color = "none") +
        xlim(0, 12) +
        labs(title = paste("P =", round(treelist[[i]]$posterior, digits = 3))) +
        theme(plot.title = element_text(hjust = 0.5, size = 32))
})
summary_plot <- cowplot::plot_grid(plotlist = colour_branch_plot[1:15], ncol = 3, nrow = 5)
summary_plot
cat("Credible set coverage of the 15 topologies:", round(cred, 3), "\n")
ggsave("figures/summarytrees.png", plot = summary_plot, width = 24, height = 40, dpi = 150)
