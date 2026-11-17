library(treeio)
library(ape)
library(dplyr)
library(phytools)
library(TreeTools)
library(rBt)
library(viridis)
library(ggplot2)
library(ggtree)
library(mapdata)
library(reticulate)

##
## Helper functions for accessing glottolog data via pyglottolog
##

# use_virtualenv("./venv")
#
# glottolog.init <- function() {
#   Config <- import("cldfcatalog")$Config
#   cfg <- Config$from_file()
#   Glottolog <- import("pyglottolog")$Glottolog
#   gl <- Glottolog(cfg$get_clone("glottolog"))
#   return(gl)
# }



##
## ggtree version
##

tree <- read.beast("model/run2/ccd0map")
ggtree(tree) |>
  collapse(211) +
  geom_text(aes(label = node)) +
  geom_text(aes(label = label))


## Some node numbers we're going to need for building the figures.
mp.clade <- 211 # MalayoPolynesian

## ... and node numbers for the nodes we want to extract the innovations for:


bunun_tips <- c("Bunun_F69_Southern_202",
                "Bunun_Iskubun_805",
                "Bunun_Takbanuaz_804",
                "Bunun_Takituduh_L04_803",
                "Bunun_Takituduh_L88_726")
wplains_tips <- c("Papora_Ts82_637",
                  "Hoanya_Ts82_636",
                  "Taokas_Ts82_638",
                  "Babuza_Ts82_635",
                  "Thao_B96_241")
atayalic_tips <- c("Atayal_Culi_F69_Bandai_256",
                   "Atayal_Squliq_F69_255",
                   "Atayal_Culi_L04_Mayrinax_742",
                   "Atayal_Squliq_L04_819",
                   "Atayal_Culi_L04_Skikun_802",
                   "Seediq_F69_Sakura_275",
                   "Seediq_L04_Paran_820",
                   "Seediq_L04_Toda_821",
                   "Seediq_L04_Truku_823",
                   "Seediq_L04_Hecuo_822")
northwest_tips <- c("Saisiyat_F69_274",
                    "Saisiyat_L04_Taai_818",
                    "Saisiyat_L04_Tungho_817",
                    "Pazih_LTs_Auran_760",
                    "Pazih_F69_266")
east_tips <- c("Kavalan_F69_260",
               "Kavalan_LTs_720",
               "Basay_L04_832",
               "Basay_TsYM91_369",
               "Sakizaya_801",
               "Amis_Central_350",
               "Amis_Farang_800",
               "Amis_Fataan_799")
paiwan_tips <- c("Paiwan_Kulalao_F82_177",
                 "Paiwan_Tjatjigel_Egli_1328",
                 "Paiwan_Stimul_L04_807",
                 "Paiwan_Butanglu_L04_806",
                 "Paiwan_Tjubar_L04_808")
puyuma_tips <- c("Puyuma_Chihpen_F69_271",
                 "Puyuma_Katipul_L04_811",
                 "Puyuma_Lower_Pinlang_L04_810",
                 "Puyuma_Nanwang_Cq_759",
                 "Puyuma_Pilam_L04_809")
tsouic_tips <- c("Tsou_Duhtu_L04_824",
                 "Tsou_T63_138",
                 "Saaroa_F69_273",
                 "Saaroa_L04_826",
                 "Kanakanabu_F69_203",
                 "Kanakanabu_L04_825")
rukai_tips <- c("Rukai_Mantauran_L04_816",
                "Rukai_Tona_815",
                "Rukai_Maga_L04_814",
                "Rukai_Budai_F69_272",
                "Rukai_Tanan_L04_812",
                "Rukai_Budai_L04_813")
wplains_tips_nothao <- c("Papora_Ts82_637",
                         "Hoanya_Ts82_636",
                         "Taokas_Ts82_638",
                         "Babuza_Ts82_635")
thao_tips <- c("Thao_B96_241")

mp_tip_ids <- as.phylo(tree) %>%
  which.tips(mp.clade)

## OK so you can assign intermediate vars in pipes, just have to use %>%. Cool
mp_tips <- as_tibble(tree) %>%
  filter(node %in% mp_tip_ids) %>%
  dplyr::select(label) %>%
  pull(label) # Doesn't attach colname to resulting vec

group_names <- c("Atayalic", "Northwest Formosan", "Western Plains", "Bunun",
                 "Rukai", "Tsouic", "Puyuma", "Paiwan", "East Formosan",
                 "Malayo-Polynesian")

tip_vectors <- list(
  atayal = atayalic_tips,
  northwest = northwest_tips, 
  wplains = wplains_tips, 
  bunun = bunun_tips, 
  rukai = rukai_tips, 
  tsouic = tsouic_tips,
  puyuma = puyuma_tips, 
  paiwan = paiwan_tips, 
  ef = east_tips,
  mp = mp_tips
)
subgroup_data <- tibble(tips = unlist(tip_vectors), 
                        subgroup = rep(group_names,
                                       purrr::map_int(tip_vectors, length))) %>% 
  inner_join(as_tibble(tree), by = join_by("tips" == "label")) %>%
  dplyr::select(node, tips, subgroup)

## FUCK
## Collect node tip numbers for each named clade, as collapsing the tree to
## one with polytomies renumbers the node labels.

subgroup_nodes <- data.frame(
  names = group_names[-length(group_names)],
  nodes = sapply(tip_vectors[-length(tip_vectors)], function (tips) which.node(as.phylo(tree), tips))
)

clade_colors <- c(
  "Atayalic" = "#d73027",
  "Bunun" = "#f46d43",
  "East Formosan" = "#fdae61",
  "Northwest Formosan" = "#fee090",
  "Paiwan" = "#c7efc4",
  "Puyuma" = "#e0f3f8",
  "Rukai" = "#abd9e9",
  "Tsouic" = "#74add1",
  "Western Plains" = "#4575b4"
)
subgroup_nodes <- subgroup_nodes %>%
  mutate(barcolor = clade_colors[names])

##
## CCD0 tree with posteriors labelled, and subtrees coloured accoring to
## AN primary branch membership. ChatGPT is magic for this shit. Dotted lines
## for P < .7
##

binary.tree <- groupClade(tree, subgroup_nodes$node)

make_consensus <- function () {
  ## Create base plot, then apply scaleClade and collapse to that plot
  formosan_tree <- ggtree(binary.tree, ladderize = TRUE, size = 0) |>
    scaleClade(node = mp.clade, scale = 0.03) |>
    collapse(node = mp.clade, fill = "lightgrey") |>
    revts()
  
  ## Add linetype to the tree data
  formosan_tree$data <- formosan_tree$data |>
    mutate(linetype = ifelse(posterior < 0.7, "dotted", "solid"))
  
  ## Begin building the full plot
  p <- formosan_tree +
    geom_tree(aes(linetype = linetype),
              size = 2.6) +
    scale_linetype_manual(values = c(solid = "solid", dotted = "dotted")) +
    geom_nodelab(geom = "label",
                 aes(label = round(posterior, 2)),
                 size = 5.5) +
    theme(legend.position = "off") +
    scale_y_continuous(expand = expansion(mult = c(0.1, 0.1))) +
    theme_tree2() +
    scale_x_continuous(
      labels = abs,
      limits = c(-5500, 1500),
      breaks = c(0, -1000, -2000, -3000, -4000, -5000)
    ) +
    theme(
      legend.position = "none",
      axis.text = element_text(size = 24)
    )
  ## Add colored clade labels to `p`
  for (i in seq_len(nrow(subgroup_nodes))) {
    node_i <- subgroup_nodes$nodes[i]
    name_i <- subgroup_nodes$names[i]
    color_i <- clade_colors[[name_i]]
  
    p <- p + geom_cladelab(
      node = node_i,
      label = name_i,
      extend = 0.5,
      offset = 160,
      offset.text = 50,
      barsize = 5.0,
      fontsize = 6.5,
      barcolor = color_i,
      textcolor = "black"
    )
  }
  ## Draw a triangle manually under the collapsed MP node
  mp_loc <- formosan_tree |>
    filter(node == mp.clade) |>
    dplyr::select(x, y)

  triangle_x <- mp_loc$x[1]
  triangle_y <- mp_loc$y[1]

  triangle_points <- data.frame(
    x = c(triangle_x + 100, 0, 0),
    y = c(triangle_y, triangle_y + 3, triangle_y + 0.5)
  )
  p <- p + geom_polygon(data = triangle_points,
                        aes(x = x, y = y),
                        fill = "lightgrey",
                        color = "black",
                        size = 1,
                        alpha = 0.5)
  p <- p + annotate(
    "text",
    x = 160 + 50,                # same offset as the other clade labels
    y = triangle_y + 1.5,        # middle of the triangle
    label = "Malayo-Polynesian",
    hjust = 0,
    size = 6.5
  )
  p
}
p <- make_consensus()
p
## Save plot
ggsave("figures/consensus_tree.png",
       plot = p,
       width = 12,
       height = 8,
       dpi = 300)
