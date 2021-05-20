######################################### Script 1: Interpolating & Preparing Data #########################################


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Load R Packages & Read Data ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Load necessary R packages
library(zoo)                # for interpolating     
library(dplyr)              # for renaming columns, joining datasets
library(plyr)               # for count
library(ggplot2)            # for graphs
library(grid)               # for displaying multiple graphs on same page
library(gridExtra)          # for displaying multiple graphs on same page
library(randomForest)       # for Random Forest Modelling
library(caret)              # for Confusion Matrix and Kappa coefficient
library(reshape2)           # for melt function
library(readr)              # for saving datasets


# Read in the full zonal dataset (without rfi) for large fields > 1300 metres squared. 
# Also read in ground truth dataset.
zonal_1300 <- read.csv("zonal_stats_combined_over1300m2_single_csv_by_pass_rfi_removed.csv", header = TRUE, na.strings = NA)
FieldBound <- read.csv("FieldBoundaries2019.csv", header = TRUE, na.strings = c("", NA))

# Removing empty columns from the zonal dataset and irrelevant Tile column
zonal_1300 <- subset(zonal_1300, select = -c(LCGROUP, LCTYPE, Tile))




# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Interpolate Zonal Data ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Interpolate zonal dataset - taking into account the band, direction and measure
# First subset by direction - asc & desc
Asc <- zonal_1300[, c(grep(pattern = "asc", names(zonal_1300)))]
Desc <- zonal_1300[, c(grep(pattern = "desc", names(zonal_1300)))]

# Then subset by band using the previous two direction datasets - VH & VV
Asc_VH <- Asc[, c(grep(pattern = "VH", names(Asc)))]
Asc_VV <- Asc[, c(grep(pattern = "VV", names(Asc)))]

Desc_VH <- Desc[, c(grep(pattern = "VH", names(Desc)))]
Desc_VV <- Desc[, c(grep(pattern = "VV", names(Desc)))]

# Finally subset all band datasets by measure - mean, varaince & range
Asc_VH_mean <- Asc_VH[, c(grep(pattern = "mean", names(Asc_VH)))]
Asc_VH_var <- Asc_VH[, c(grep(pattern = "variance", names(Asc_VH)))]
Asc_VH_range <- Asc_VH[, c(grep(pattern = "range", names(Asc_VH)))]

Asc_VV_mean <- Asc_VV[, c(grep(pattern = "mean", names(Asc_VV)))]
Asc_VV_var <- Asc_VV[, c(grep(pattern = "variance", names(Asc_VV)))]
Asc_VV_range <- Asc_VV[, c(grep(pattern = "range", names(Asc_VV)))]

Desc_VH_mean <- Desc_VH[, c(grep(pattern = "mean", names(Desc_VH)))]
Desc_VH_var <- Desc_VH[, c(grep(pattern = "variance", names(Desc_VH)))]
Desc_VH_range <- Desc_VH[, c(grep(pattern = "range", names(Desc_VH)))]

Desc_VV_mean <- Desc_VV[, c(grep(pattern = "mean", names(Desc_VV)))]
Desc_VV_var <- Desc_VV[, c(grep(pattern = "variance", names(Desc_VV)))]
Desc_VV_range <- Desc_VV[, c(grep(pattern = "range", names(Desc_VV)))]


# Check to see how many rows contain NA's for both directions - 6303 & 11 rows contain NA's for
# ascending and descending, respectively. 
sum(is.na(rowSums(Asc)))
sum(is.na(rowSums(Desc)))

# Now we need to interpolate via rows - we do this for Ascending VV bands first
Asc_VV_mean_int <- as.data.frame(t(na.approx(t(Asc_VV_mean))))
Asc_VV_var_int <- as.data.frame(t(na.approx(t(Asc_VV_var))))
Asc_VV_range_int <- as.data.frame(t(na.approx(t(Asc_VV_range))))

# Change column names back
colnames(Asc_VV_mean_int) <- colnames(Asc_VV_mean)
colnames(Asc_VV_var_int) <- colnames(Asc_VV_var)
colnames(Asc_VV_range_int) <- colnames(Asc_VV_range)

# Repeat for ascending VH band
Asc_VH_mean_int <- as.data.frame(t(na.approx(t(Asc_VH_mean))))
Asc_VH_var_int <- as.data.frame(t(na.approx(t(Asc_VH_var))))
Asc_VH_range_int <- as.data.frame(t(na.approx(t(Asc_VH_range))))
colnames(Asc_VH_mean_int) <- colnames(Asc_VH_mean)
colnames(Asc_VH_var_int) <- colnames(Asc_VH_var)
colnames(Asc_VH_range_int) <- colnames(Asc_VH_range)


#Similarly, do the same for descending VV and VH bands - interpolate and add column names
Desc_VV_mean_int <- as.data.frame(t(na.approx(t(Desc_VV_mean))))
Desc_VV_var_int <- as.data.frame(t(na.approx(t(Desc_VV_var))))
Desc_VV_range_int <- as.data.frame(t(na.approx(t(Desc_VV_range))))
colnames(Desc_VV_mean_int) <- colnames(Desc_VV_mean)
colnames(Desc_VV_var_int) <- colnames(Desc_VV_var)
colnames(Desc_VV_range_int) <- colnames(Desc_VV_range)

Desc_VH_mean_int <- as.data.frame(t(na.approx(t(Desc_VH_mean))))
Desc_VH_var_int <- as.data.frame(t(na.approx(t(Desc_VH_var))))
Desc_VH_range_int <- as.data.frame(t(na.approx(t(Desc_VH_range))))
colnames(Desc_VH_mean_int) <- colnames(Desc_VH_mean)
colnames(Desc_VH_var_int) <- colnames(Desc_VH_var)
colnames(Desc_VH_range_int) <- colnames(Desc_VH_range)


# Combining interpolated data with zonal_1300 dataset
zonal_1300 <- cbind(zonal_1300[,1:2], Asc_VH_mean_int, Asc_VH_var_int, Asc_VH_range_int, 
                    Asc_VV_mean_int, Asc_VV_var_int, Asc_VV_range_int,
                    Desc_VH_mean_int, Desc_VH_var_int, Desc_VH_range_int,
                    Desc_VV_mean_int, Desc_VV_var_int, Desc_VV_range_int)

# Let's check to see how many rows contain NA's in the interpolated zonal data - 1915 rows 
sum(is.na(rowSums(zonal_1300[, 3:494])))

# Removing NA's, otherwise the model won't work
zonal_1300 <- zonal_1300[complete.cases(zonal_1300), ]




# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Creation of Labelled and Unlabelled Data ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Extract relevant columns from the ground truth dataset
CropType <- FieldBound[,c(1,4,5)]

# Remove rows which contain no Field ID and no Crop Type
CropType <- CropType[complete.cases(CropType$FID_1.C.14),]
CropType <- CropType[!is.na(CropType$LCTYPE.C.254),]

# Check to see if there are any duplicated rows in the dataframes - both should be TRUE
nrow(zonal_1300) == length(unique(zonal_1300$FID_1))
nrow(CropType)==length(unique(CropType$FID_1.C.14))

# Since CropType is FALSE there are duplicated rows which need to be removed before merging dataframes
CropType <- distinct(CropType)

# Change the first column name to FID_1 to merge the dataframes together
colnames(CropType)[1] <- "FID_1"

# Merging the ground truth data with zonal data 
zonal_1300 <- left_join(zonal_1300, CropType, by= "FID_1")

# Change variable names
zonal_1300 <- dplyr::rename(zonal_1300, LCGROUP = LCGROUP.C.254,
                            LCTYPE = LCTYPE.C.254)

# Need to convert LCGROUP/LCTYPE from character to factor 
str(zonal_1300)
zonal_1300$LCGROUP <- as.factor(zonal_1300$LCGROUP)
zonal_1300$LCTYPE <- as.factor(zonal_1300$LCTYPE)

# Creating labelled dataset (known fields) by first creating a vector of column names containing 'range' 
# Afterwards, remove them from the labelled dataset along with ID and LCGROUP
to.delete <- c(grep(pattern = "range", names(zonal_1300)))
Zonal_Labelled <- subset(zonal_1300, select = -c (LCGROUP, to.delete))

# Create the unlabelled dataset (known and unknown fields) by removing the same variables in the labelled dataset and LCTYPE
Zonal_Unlabelled <- subset(zonal_1300, select = -c(LCGROUP, LCTYPE, to.delete))

# Removing missing values from the labelled dataset
Zonal_Labelled <- Zonal_Labelled[complete.cases(Zonal_Labelled),]




# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Data Preparation & LCTYPE Restriction ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# A dataframe showing how many fields belong to which crop type
Ground_Data<- as.data.frame(plyr::count(Zonal_Labelled, 'LCTYPE'))
Ground_Data <- Ground_Data[complete.cases(Ground_Data$LCTYPE),]
names(Ground_Data) <- c("LCTYPE", "Fields")

# Negate %in% function from dplyr
`%notin%` <- purrr::negate(`%in%`)

# Identify and remove the crop types that have less than 5 fields, non- crops and temporary grassland 
Zonal_Labelled <- Zonal_Labelled %>%
  group_by(LCTYPE) %>%
  filter(n() >=5 , LCTYPE %notin% c("FALW", "FALW_5", "NETR_NA", "RGR", "WDG","EXCL", "TGRS")) %>%
  ungroup()

# Now remove unused factors in the LCTYPE variable using 'droplevels' function - this will drop factor levels from the
# LCTYPE variable that have been removed above
table(Zonal_Labelled$LCTYPE)
table(droplevels(Zonal_Labelled$LCTYPE))

# Plot of Classes - bar chart showing number of fields for each class
number_of_classes_plot <- ggplot(Zonal_Labelled, aes(x= LCTYPE)) +
  geom_bar(fill = "mediumpurple1")  +
  labs(x = "LCTYPE", y = "Count") +
  coord_flip()


# Remove rows which have an LCTYPE under 25, this is because we have chosen a model with a restricted LCTYPE of more than 25 fields
# Please see "3 - Model Improvements & Variable Reduction" R script for more detail !
Zonal_Labelled <- ddply(Zonal_Labelled, "LCTYPE", function(d) {if(nrow(d)>=25) d else NULL})
table(droplevels(Zonal_Labelled$LCTYPE))

# Resetting factor levels after subsetting (or else model fails)
levels(Zonal_Labelled$LCTYPE)
Zonal_Labelled$LCTYPE <- factor(Zonal_Labelled$LCTYPE)
levels(Zonal_Labelled$LCTYPE)



###### Please move onto "2 - Random Forest Modelling" which continues from this R script



