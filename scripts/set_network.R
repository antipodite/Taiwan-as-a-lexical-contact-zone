library(igraph)
library(tidyverse)
library(sf)
library(rnaturalearth)
library(ggrepel)
library(ggraph)
library(patchwork)

## Colours for consensus subgroups, consistent with figure colours for the rest
## of the paper.
branch_colours <- c(
  "Atayalic" = "#f49c83", "Northwest Formosan" = "#a8c9df",
  "Western Plains Austronesian" = "#5d8abf", "Bunun" = "#e1706d",
  "Rukai" = "#d1e6f1", "Tsouic" = "#7eaacb",
  "Puyuma" = "#fbedb9", "Paiwan" = "#c7e9c0",
  "East Formosan" = "#f8c78e"
)

## Load in the full list of gains and losses from the ACE run
gains_losses <- read_tsv("results/filteredgainslosses.tsv") %>%
  mutate(cognate_set = str_replace_all(cognate_set, "_", "-"))

true_gains_losses <- gains_losses %>%
  filter(filter == "kept")

gains <- true_gains_losses
##losses <- gains_losses %>% filter(type == "loss")

## Load in the full list of ABVD cognate sets
sampled <- read_lines("scripts/sampled_ids.txt")
set_members <- read_tsv("results/real_gains_abvd.tsv") %>%
  filter(language_id %in% sampled)

gain_members <- set_members %>%
  filter(cognate_set %in% gains$cognate_set) %>%
  filter(primary_branch != "Malayo-Polynesian", family == "Austronesian") %>%
  distinct(cognate_set, name, .keep_all = T)

locations <- set_members %>%
  filter(family == "Austronesian", primary_branch != "Malayo-Polynesian") %>%
  distinct(name, longitude, latitude, primary_branch)

## Build co-occurence matrix
co_occurrence <- function(df) {
  m <- reshape2::dcast(df, name ~ cognate_set, fun.aggregate = length)
  mat <- as.matrix(m[,-1])
  mat <- apply(mat, 2, function(x) as.numeric(x > 0))   # binarise
  res <- mat %*% t(mat)                                  # shared-set counts
  diag(res) <- 0
  dimnames(res) <- list(m[,1], m[,1])
  res
}

cooc <- co_occurrence(gain_members)

build_graph <- function(cooc, locations, cutoff) {
  graph_from_adjacency_matrix(cooc, mode = "undirected", weighted = TRUE) %>%
    igraph::as_data_frame(what = "edges") %>%
    left_join(locations, join_by(from == name)) %>%
    rename(long_from = longitude, lat_from = latitude, branch_from = primary_branch) %>%
    left_join(locations, join_by(to == name)) %>%
    rename(long_to = longitude, lat_to = latitude, branch_to = primary_branch) %>%
    filter(branch_from != branch_to, weight > cutoff)
}

cutoffs <- c(0, 1, 2, 3 )

all_branches <- names(branch_colours)

graphs <- lapply(cutoffs, \(c) {
  edges <- build_graph(cooc, locations, cutoff = c)
  g <- graph_from_data_frame(edges, directed = FALSE)
  V(g)$primary_branch <- factor(
    locations$primary_branch[match(V(g)$name, locations$name)],
    levels = all_branches
  )
  g
})

plots <- lapply(seq_along(graphs), \(i) {
  ggraph(graphs[[i]], layout = "kk") +
    geom_edge_link(alpha = 0.5) +
    geom_node_point(aes(fill = primary_branch), shape = 21, size = 8) +
    geom_label_repel(
      aes(x = x, y = y, label = name),
      size = 3,
      fill = alpha("white", 0.7),
      label.size = NA
    ) +
    scale_fill_manual(values = branch_colours, limits = names(branch_colours)) +
    guides(fill = "none") +
    ggtitle(paste0(letters[i], ") cutoff = ", cutoffs[i])) +
    theme_void() +
    theme(
      panel.border = element_rect(colour = "grey50", fill = NA, linewidth = 0.5),
      plot.title = element_text(size = 12, hjust = 0)
    )
})

cutoff_plot <- wrap_plots(plots, ncol = 2) +
  plot_layout(guides = "collect") &
  theme(legend.position = "none")
cutoff_plot
ggsave("figures/networkcutoffs.png", plot = cutoff_plot, width = 12, height = 12, dpi = 300)


####
#### 4. Plot network graph on top of a map of Taiwan
####

world <- ne_countries(scale = "large", returnclass = "sf")
tw.limits <- data.frame(x = c(119.5, 122.5), y = c(21.75, 25.5))

edges <- build_graph(cooc, locations, cutoff = 1)
edge_labels <- edges %>%
  mutate(
    mid_x = (long_from + long_to) / 2,
    mid_y = (lat_from + lat_to) / 2
  )

map_plot <- ggplot(data = world) +
  geom_sf(fill = "grey95", colour = "grey60") +
  coord_sf(xlim = tw.limits$x, ylim = tw.limits$y, expand = FALSE) +
  geom_segment(
    data = edges,
    aes(x = long_from, y = lat_from,
        xend = long_to, yend = lat_to,
        linewidth = weight),
    alpha = 0.5,
    colour = "grey40"
  ) +
  scale_linewidth(range = c(0.6, 3), guide = "none") +
  geom_point(data = locations,
             aes(x = longitude, y = latitude, fill = primary_branch),
             shape = 21, size = 3) +
  geom_label_repel(
    data = locations,
    aes(x = longitude, y = latitude, label = name),
    size = 5,
    box.padding = 0.5,
    min.segment.length = 0,
    label.size = 0.2,
    fill = alpha("white", 0.8),
    seed = 1
  ) +
  ## Give nodes and legend consistent colours as rest of paper
  scale_fill_manual(values = branch_colours) +
  ## Edge labels
  # geom_label(
  #   data = edge_labels,
  #   aes(x = mid_x, y = mid_y, label = weight),
  #   size = 4,
  #   fill = "white",
  #   label.size = 0.4,
  #   label.padding = unit(0.12, "lines")
  # ) +
  theme_minimal(base_size = 14) +
  theme(axis.text = element_blank(), axis.title = element_blank(),
        axis.ticks = element_blank()) +
  labs(fill = NULL) +
  theme(
    panel.grid = element_blank(),
    axis.text = element_blank(),
    axis.ticks = element_blank(),
    axis.title = element_blank(),
    legend.position = "none"
  )
map_plot
ggsave("figures/networkmapfiltered.png", plot = map_plot, width = 10, height = 12, dpi = 300)
