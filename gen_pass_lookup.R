
# Generate date-pass lookup =======================================================================

# This is used to generate (from the Sentinel footprint shapefile) a list of dates and passes.

setwd('~/CropMap/ZonalStats')

library(sf)
library(dplyr)
library(stringr)
library(tidyr)
library(readr)
library(lubridate)
library(purrr)

# Custom pass generate function -------------------------------------------------------------------

generate_pass <- function(dates, current_date, interval){
  
  require(tidyr)
  require(dplyr)
  require(purrr)
  require(lubridate)
  
  `%notin%` <- negate(`%in%`)
  
  if(class(dates) != "Date") stop("Vector must be in <Date> format")
  if(class(interval) %notin% c("integer", "numeric")) stop("Interval must be in <Integer> or <Numeric> format")
  
  # Elapsed number of days:
  elapsed_days = length(seq(from = min(dates, na.rm = TRUE), to = current_date, by = "day"))
  
  # Pass number:
  pass <- floor(elapsed_days/interval)+1
  
  return(as.numeric(pass))
  
}

# Pass lookup function ----------------------------------------------------------------------------

generate_pass_lookup <- function(footprint, output_csv){
  
  # sentinel_footprint: location of sentinel footprint shapefile (character string)
  # output_csv: output location of the pass lookup CSV
  
  # Ascending only ----------------------------------------------------------------------------------
  
  sentinel_footprint <- st_read(paste0(footprint))
  
  # Turn into dataframe by removing geometry:
  
  st_geometry(sentinel_footprint) <- NULL
  
  # Generate relevant columns, arrange by date, and select unique rows only:
  
  sentinel_tibble <- sentinel_footprint %>%
    as_tibble() %>%
    mutate(
      Date = ymd(Date),
      Direction = str_extract(ARDName, "asc|desc")
    ) %>%
    select(Date, Orbit, Sensor, Direction) %>%
    arrange(Date) %>%
    distinct()
  
  # Generate pass lookup ----------------------------------------------------------------------------
  
  # Arrange the rows by date and filter out ascending passes only:
  
  sentinel_tibble <- sentinel_tibble %>%
    rowwise() %>%
    mutate(
      Pass = generate_pass(dates = .$Date, current_date = Date, interval = 6),
      CalendarWeek = isoweek(Date)
    ) %>%
    ungroup()
  
  
  sentinel_tibble <- sentinel_tibble %>%
    # Generate SixDaysCommencing:
    group_by(Pass) %>%
    mutate(
      SixDaysCommencing = min(Date, na.rm = TRUE)
    ) %>%
    ungroup()
  
  sentinel_tibble %>%
    write_csv(paste(output_csv))
  
}

