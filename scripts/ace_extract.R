## Run from the repository root.

library(devtools)
library(readr)
library(data.table)
library(dplyr)
library(tibble)
library(purrr)

source_url("https://raw.githubusercontent.com/king-ben/R-functions/master/asr_functions.R")

formosan_taxa <- c("NWAtayalic", "NorthwestClade", "RukaiTsouic", "PaiwanPuyuma",
                   "RTPP", "NorthClade")

##
## Process results of ACE run
##

## Load the MRCA and origin log files for each of the nodes of interest and
## extract the gains and losses from them

get_taxon_innovations <- function(taxon, siglevel) 
{
  origin_file <- file.path("model/ace", paste("asr_logger_", taxon, "_parent.txt", sep=""))
  mrca_file <- file.path("model/ace", paste("asr_logger_", taxon, ".txt", sep=""))
  
  gains <- get_innovations(fread(mrca_file), fread(origin_file), siglevel = siglevel) |>
    round(digits = 2) |>
    enframe(name = "cognate_set", value = "posterior") |>
    mutate(type = "gain", taxon = taxon)
  
  losses <- get_innovations(fread(mrca_file), fread(origin_file), mode = "losses", siglevel = siglevel) |>
    round(digits = 2) |>
    enframe(name = "cognate_set", value = "posterior") |>
    mutate(type = "loss", taxon = taxon)
  
  return(bind_rows(gains, losses))
}

all_gains_losses <- formosan_taxa |>
  map_df(~ get_taxon_innovations(.x, siglevel = 0.5), .id = "list_element")

readr::write_tsv(all_gains_losses, "results/gainslosses.tsv")
