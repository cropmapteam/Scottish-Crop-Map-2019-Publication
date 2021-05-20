# READ AND TRANSFORM ZONAL STATS ==================================================================

library(readr)
library(dplyr)
library(stringr)
library(tidyr)
library(lubridate)
library(purrr)
library(furrr)

setwd("~/CropMap/ZonalStats/PivotZonalStats")

# Change this to TRUE to remove RFIs or FALSE to retain them:

removeRFI <- FALSE

# Load date-pass lookup ---------------------------------------------------------------------------

# This was originally generated using the Sentinel extension shapefile obtained from JNCC.

pass_lookup <- read_csv("../PassLookup/pass_lookup.csv")

# Read the RFI lookup created in SQL:

rfi_lookup <- read_csv("rfi_lookup.csv") %>%
  separate(ardname , sep = "_", into = c("Sensor", "Date", "Orbit", "Direction"), extra = "drop") %>%
  # Rename and change columns to match zonal stats & pass lookup:
  mutate(
    Date = ymd(calendardate),
    Orbit = as.numeric(Orbit),
      RFI = removeRFI
  ) %>%
  select(Id = gid, Date, Orbit, Sensor, Direction, RFI)



pass_lookup %>%
  group_by_at(vars(SixDaysCommencing, Date)) %>%
  count() %>%
  ungroup() %>%
  filter(n > 1)

# Specify location of zonal stats CSV files -------------------------------------------------------

# Dataframe with all tilenames and filepaths:

tiles <- list.files(path = "../Data", pattern = "*zonal_stats_for_ml.csv", recursive = TRUE, full.names = TRUE) %>%
  as_tibble() %>%
  rowwise() %>%
  mutate(
    # Extract the tile name ([A-Z][A-Z])([0-9][0-9]) and the direction from the file name:
    Tile = str_extract(value, pattern = "([A-Z][A-Z])([0-9][0-9])"),
    Direction = str_to_lower(str_extract(value, "Asc|Desc"))
  ) %>%
  select(Direction, Tile, FilePath = value) %>%
  ungroup()

tiles

# Define custom load function ---------------------------------------------------------------------

read_and_transform_zonal_stats <- function(filename, direction, group = NULL){
  
  require(tidyr)
  require(dplyr)
  require(readr)
  
  group = if(group == "pass"){"SixDaysCommencing"} else if(group == "week"){"CalendarWeek"} else stop("Choose either 'pass' or 'week' for grouping dates.")
  
  # Read CSV:
  zonal_stats = read_csv(filename,
                         col_types = cols(
                           .default = "d",
                           Id = col_character(),
                           FID_1 = col_character(),
                           LCGROUP = col_character(),
                           LCTYPE = col_character()
                         ),
                         na = c("", "--", " "),
                         progress = FALSE) %>%
    # Pivot so that date, band, metric are identifying columns instead of across many columns:
    pivot_longer(cols = -c(Id:AREA),
                 names_to = c("Date", "Band", "Metric"),
                 names_sep = "_",
                 values_to = "Value",
                 values_drop_na = TRUE) %>%
    # Initiate direction column and join with pass lookup:
    mutate(Date = ymd(Date),
           Direction = paste0(direction)) %>%
    left_join(pass_lookup, by = c("Date", "Direction")) %>%
    left_join(rfi_lookup, by = c("Id", "Date", "Orbit", "Sensor", "Direction")) %>%
    # Set RFI fields' values to NA:
    mutate(
      Value = case_when(
        RFI == TRUE ~ NA_real_,
        TRUE ~ Value
      )
    ) %>%
    # Take the average for each chosen period (6 days or calendar week), retaining only
    # information for the date, field, area, band, metric (mean/var/range), and direction:
    group_by_at(vars(FID_1:AREA, as.name(group), Direction, Band, Metric)) %>%
    summarise(
      Value = mean(Value, na.rm = TRUE),
      .groups = 'keep'
    ) %>%
    ungroup()
  
  return(zonal_stats)
  
}

# Example -----------------------------------------------------------------------------------------

# The original file:

tiles$FilePath[[1]]

# Read into R:

read_csv(tiles$FilePath[[1]])

# Will be pivoted and joined with pass and RFI lookups (by date/direction):

read_and_transform_zonal_stats(tiles$FilePath[[1]], "asc", "pass")

# READ ZONAL STATS ================================================================================

# This takes a while and uses quite a bit of RAM - be warned!
# Can take 10-30min depending on system...

# By 6-day pass -----------------------------------------------------------------------------------

zonal_stats <- tiles %>%
  group_by_at(vars(Direction, Tile)) %>%
  # TROUBLE-SHOOTING: Load only first 10 rows in each direction ++++++++++++++++++++++++++++++
  #group_by_at(vars(Direction)) %>%
  #filter(row_number() < 11) %>%
  # +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  mutate(
    ZonalStats = future_pmap(.l = list(FilePath, Direction, "pass"), .f = read_and_transform_zonal_stats, .progress = TRUE)
  ) %>%
  ungroup() %>%
  # Direction is now also included in zonal stats, file path is no longer needed. Remove these:
  select(-FilePath, -Direction) %>%
  # Unnest zonal stats dataset:
  unnest(ZonalStats)

zonal_stats

# Pivot to wider format and write to CSV:

zonal_stats %>%
  pivot_wider(names_from = SixDaysCommencing:Metric, names_sep = "_",
              values_from = Value) %>%
  #write_csv("zonal_stats_combined_single_csv_by_pass.csv")
  write_csv("zonal_stats_combined_over1300m2_single_csv_by_pass.csv")
