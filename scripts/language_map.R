
library(tidyverse)
library(dplyr)
library(ggplot2)
library(rnaturalearth)
library(rnaturalearthdata)
library(viridis)
library(RColorBrewer)

## Mapping setup
world <- ne_countries(scale = "large", returnclass = "sf")
class(world)
tw_limits <- data.frame(x = c(120, 122.5),y = c(26, 22))

geo_data <- sf::read_sf("~/projects/languageatlasofthepacificarea/cldf/languages.geojson")

formosan_sf <- read_tsv("results/tkan.tsv") |>
  # Remove Kradai and Malayo-Polynesian
  filter(str_detect(Classification, "Austronesian")) |>
  filter(!str_detect(Classification, "Malayo-Polynesian")) |>
  select(Glottocode, Language, Slug, Classification) |>

  # Trim and clean up the classification column to primary branch
  mutate(Classification = word(Classification, 2) |> str_remove(",")) |>
  mutate(Classification = Classification |>
           str_replace("East", "East Formosan") |>
           str_replace("Western", "Western Plains") |>
           str_replace("Northwest", "Northwest Formosan")) |>
  inner_join(geo_data, by = join_by("Glottocode" == "cldf:languageReference")) |>
  select(-family, -fill, -Language, -Slug) |>
  unique() |>

  # Convert to sf spatial dataframe
  sf::st_as_sf()

custom_pastel <- colorspace::qualitative_hcl(
  n = length(unique(formosan_sf$Classification)),
  palette = "Pastel 1",
  l = 80,  # lightness
  c = 60   # chroma (less = softer)
)

formosan_map <- ggplot(data = world) +
  geom_sf() +
  geom_sf(data = formosan_sf, aes(fill = Classification)) +
  geom_sf_text(data = formosan_sf, aes(label = title), size = 3, color = "black") +
  coord_sf(xlim = tw_limits$x, ylim = tw_limits$y) +
  theme(panel.background = element_rect(fill = "white")) +
  labs(fill = "Primary branch") +
  scale_fill_manual(values = c(
    "#e5726f",  # softer red
    "#f49c83",  # softer orange
    "#f8c78e",  # light warm yellow
    "#fbedb9",  # pale yellow
    "#c7e9c0",  # pale green (replacement)
    "#d1e6f1",  # light sky blue
    "#a8c9df",  # soft blue
    "#7eaacb",  # muted blue
    "#5d8abf"   # medium blue
  )) +
  theme(
    plot.margin = margin(1, 1, 1, 1),
    panel.background = element_rect(fill = "white"),
    axis.title.x = element_blank(),
    axis.title.y = element_blank(),
    axis.text.x = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks = element_blank()
  )

ggsave("figures/formosan_map.png",
       plot = formosan_map,
       width = 10,
       height = 8,
       dpi = 300)
