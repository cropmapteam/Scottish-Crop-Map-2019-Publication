######################################### Script 5: Probability Cut-Off on Predictions #########################################

# Please note that this is a continuation from "4 - Running Code on Reduced Zonal Data" R script. 
# Please run the code for that script before continuing with this R script. 
# This script uses class porbabilies to prevent overestimation in total areas of crops. 




#~~~~~~~~~~~~~~~~~~~~~ Class Probabilities for all fields > 1300 - unknown/known & Cereal Estimate Comparison ~~~~~~~~~~~~~~~~~~

# Start with the unlabelled zonal dataset, using the reduced zonal dataset 
Zonal_Unlabelled <- subset(zonal_reduced, select = -c(LCTYPE))

## Creating class probabilities for each field in the unlabelled zonal dataset - using only variables selected in previous script
class_probability <- predict(model_all, Zonal_Unlabelled[, 1:116], type = "prob")

# Remove column names
colnames(class_probability) <- NULL

# Remove any rows containing missing data
class_probability <- class_probability[complete.cases(class_probability), ]

# Creating a loop to find the column with the highest probability (this should be same as type = "class" in predict function)
Prob <- numeric(nrow(class_probability))

for (i in 1:nrow(class_probability)) {
  Prob[i] <- which.max(class_probability[i,])
}

# Convert matrix to dataframe
class_probability <- as.data.frame(class_probability)

# Add column names back 
colnames(class_probability) <- c("GRS", "SB", "SO", "WB", "WW")

# Add the vector Prob (created using the loop) to the dataframe
class_probability$Prob_LCTYPE <- Prob

# Replace the numbers with the name of the crop type
class_probability$Prob_LCTYPE <- cut(Prob, breaks = c(0,1,2,3,4,5),
                                     labels = c("GRS", "SB", "SO", "WB", "WW"))



# Create a loop to show if the prediction meets the probability cut-off or not - a 0.48 cut-off was used  
Cut.off <- nrow(class_probability)
for (i in 1:nrow(class_probability)) {
  if(max(class_probability[i, 1:5]) > 0.48) {
    Cut.off[i] <- TRUE
  } else {
    Cut.off[i] <- FALSE
  }
}

Cut.off

# Convert to logical vector
Cut.off <- as.logical(Cut.off)

# Add the cut.off variable to the class_probability dataframe
class_probability$Cut_Off <- Cut.off

# Create a loop to predict only those that meet a cut-off
Cut.off.only <- nrow(class_probability)
for (i in 1:nrow(class_probability)) {
  if(class_probability$Cut_Off[i] == TRUE) {
    Cut.off.only[i] <- class_probability$Prob_LCTYPE[i]
  } else {
    Cut.off.only[i]<- NA
  }
}

# Adding vector Cutt.off.only to the dataframe - which is the predicted LCTYPE after the cut-off point was used
class_probability$Predicted_LCTYPE <- Cut.off.only

# Replace the numbers with the name of the crop type 
class_probability$Predicted_LCTYPE <- cut(Cut.off.only, breaks = c(0,1,2,3,4,5),
                                          labels = c("GRS", "SB", "SO", "WB","WW"))


# Add in the actual LCTYPE to the class probability dataframe 
class_probability$Actual_LCTYPE <- zonal_reduced$LCTYPE

#Adding in Id to the class probability dataframe
class_probability$Id <- zonal_reduced$FID_1


# Saving class_probability dataframe as a csv file - the final model output !!
write.csv(class_probability, file = "Predictions_on_rfi_removed_zonal_stats_mean_only_over1300m2_with_interpolation_and_prob_cutoff.csv")



# Finding out how many fields are predicted for each type without cut-off:
table(class_probability$Prob_LCTYPE)

# Finding out what the actual crop type is for all fields (ground truth data):
table(class_probability$Actual_LCTYPE)

#Finding the fields that meet the cut-off point
class_probability_0.48 <- class_probability[class_probability$Cut_Off == "TRUE" ,]

# Finding out how many fields are predicted for each type (taking the cut-off into consideration):
table(class_probability_0.48$Predicted_LCTYPE)

# Finding out what the actual crop type is for all fields (taking the cut-off into consideration):
table(class_probability_0.48$Actual_LCTYPE)
