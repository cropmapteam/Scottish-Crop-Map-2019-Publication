
# GENERATE DATES FOR PYTHON VALIDATION SCRIPT =====================================================

# This script uses the many output CSVs generated using python and creates a single output
# CSV for use in the random forest script.

library(dplyr)
library(readr)

generate_dates_text <- function(metadata_csv, output_txt){
  
  # metadata_csv: location of metadata CSV (character string)
  # output_txt: location to write dates text file to
  
  dates_processed <- read_csv(paste0(metadata_csv)) %>%
    select(image_year, image_month, image_day) %>%
    transmute(Date = paste0(image_year, "-", image_month, "-", image_day)) %>%
    unique() %>%
    pull()
  
  write_lines(paste0(1:length(dates_processed), ":", "'", dates_processed, "',"), paste0(output_txt))
  
  
}