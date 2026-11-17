## Run from the repository root.

library(devtools)
library(XML)
library(readr)
library(data.table)
library(dplyr)
library(tibble)
library(purrr)
library(ape)
library(phangorn)

source_url("https://raw.githubusercontent.com/king-ben/R-functions/master/asr_functions.R")

##
## Setup for initial BEAST2 run
##

file <- "nexus/abvdformosan_ascwords_removecombined1.nex"

wp <- read_tsv("nexus/parts.txt")
colnames(wp) <- c("concept", "from", "to")
wp <- transform(wp, from = as.numeric(from), to = as.numeric(to))
wn <- find_site_names(file)

# order partitions and save
partitions_ordered <- order_partitions(wp)
links <- rate_links(wp)
writeLines(paste0("\t", "charset ", partitions_ordered$concept, " = ", 
                  partitions_ordered$from, "-", partitions_ordered$to, ";"), 
           "partitions_ordered.txt")

siteprobs <- siteprobs_blocks(wp, wn, logevery=5000)
saveXML(siteprobs, "siteprobs.xml")

##
## Setup for ACE run
##

## Make the logger XML blocks for each taxon set with unique names for the ID and output
## files and write everything to a single XML file that can be copied and pasted into the
## BEAST XML
formosan_taxa <- c("NWAtayalic", "NorthwestClade", "RukaiTsouic", "PaiwanPuyuma",
                   "RTPP", "NorthClade")
logger_xml_file <- "loggers.xml"
for (taxon in formosan_taxa) {
  xml_origin <- asr_blocks(wp, names=wn, links,
                           id=paste("AncestralSequenceLoggerOrigin", taxon, sep=""), 
                           logevery=5000, taxonset=taxon, logOrigin=T, 
                           fileName=paste("asr_logger_", taxon, "_parent.txt", sep=""))
  xml_mrca <- asr_blocks(wp, names=wn, links,
                         id=paste("AncestralSequenceLoggerMRCA", taxon, sep=""), 
                         logevery=5000, taxonset=taxon, logOrigin=F, 
                         fileName=paste("asr_logger_", taxon, ".txt", sep=""))
  origin_str <- toString.XMLNode(xml_origin)
  mrca_str <- toString.XMLNode(xml_mrca)
  write(paste(origin_str, "\n"), file=logger_xml_file, append=TRUE)
  write(paste(mrca_str, "\n"), file=logger_xml_file, append=TRUE)
}
