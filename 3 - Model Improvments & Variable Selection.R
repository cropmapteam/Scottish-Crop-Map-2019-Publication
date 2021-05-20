######################################### Script 3: Model Improvements & Variable Selection #########################################

# Please note that this is a continuation from "2 - Random Forest Modelling" R script. 
# Please run the code for that script before continuing with this R script. 


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ LCTYPE Restriction ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# In R script "1 - Interpolating & Preparing Data" under section "Data Preparation & LCTYPE Restriction" at the 
# very end of the section (and script), within the ddply function the custom function is currently set to 25. 
# This means that only crop types that have equal to or more than 25 fields will be retained.
# Initailly this was set to 50 and was reduced to 25 to help retain a greater number of cropos in the model



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ntree Argument ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# In R script "2 - Random Forest Modelling" under section "Train a Random Forest Model" within the model  
# the ntree parameter is set to 200. This was testsed against a large number (1000 trees)
# before reducing the number to find the trees that had the best accuracy (low error rate)




# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ mtry Argument ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# In R script "2 - Random Forest Modelling" under section "Train a Random Forest Model" within the model there
# is an argument called mtry which is set to 8. This was tested using different values (1-10) and the highest
# accuracy produced was chosen as the selected value. 



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Sampsize Argument  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# In R script "2 - Random Forest Modelling" under section "Train a Random Forest Model" within the model there
# is an argument called sampsize which is used due to the disproportionate number of fields known for each crop
# type in the ground truth data. Undersampling was used to (randomly) select some of the grassland and spring barley 
# crop types while retainnig all fields for the smaller crops - less than 100 fields. 
# After testing out different numbers to select for grassland and sping barley (based on accuracy) it was decided 
# that the model would be created on the training data using 1% of graslsand, 12% of spring barley and 100% of the 
# remaining crop types. 




# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Variable Selection  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Statements made above detail the model imporvements made on previous scripts.
# Next we consider reducing the number of variables in the dataset
# Numerous methods were considered with the best accuracy selected and are outlined below:
# !!!!! It is important to note that the randomforestSRC method was selected as it porduced the best accuracy !!!!!!!!!!
# Thus, please run Method 5: randomforestSRC if you wish to replicate the work. 
# Once the method has been selected please see end of script/section after all 6 methods.

################################# 1: Mean Decrease in Gini (MDG) ################################# 
# Method 1 uses the mean decrease in Gini values assigned by the model when importance is set to TRUE.
# Getting information about important variables in the model and ordering variables by importance using MDG values
# with least important variables at top
var_importance <- importance(model_all)
var_importance <- as.data.frame(var_importance)
var_importance_Gini <- var_importance[order(var_importance$MeanDecreaseGini),]

# The procedure to reduce variables is as follows:
# 1) Remove bottom 50% of MDG values from the dataset
# 2) Re-run the model with those variables (in order for fair comparison make sure set.seed is set for the train/test datasets)

# DO NOT RUN ALL OF UNIMPORTANT VARIABLES BELOW. First recall the variable importance section above where we have ordered the 
# variables by increasing MDG values. So we want to select the top 50% (ie half the variables) to be removed
# To do this run Unimportant - DONT RUN ANY OTHER 
Unimportant <- rownames(var_importance_Gini)[1:(ceiling(nrow(var_importance_Gini)/2))]
Unimportant.2 <- rownames(var_importance_Gini)[1:(ceiling(nrow(var_importance_Gini)/2))]
Unimportant.3 <- rownames(var_importance_Gini)[1:(ceiling(nrow(var_importance_Gini)/2))]
Unimportant.4 <- rownames(var_importance_Gini)[1:(ceiling(nrow(var_importance_Gini)/2))]

#Afterwards, we remove the unimportant variable(s) form the labelled dataset 
Zonal_Labelled <- select(Zonal_Labelled, -c(Unimportant)) #add addtional unimportant variables here for each iteration

##### The next few steps are for re-running the model
trainDataSplit <- 0.6
TestDataSplit <- 1 - trainDataSplit

# Split Dataset into training and test subsets using the reduced labelled zonal stats 
set.seed(1)
trainIndex <- sample(nrow(Zonal_Labelled), trainDataSplit*nrow(Zonal_Labelled))

trainData <- droplevels(Zonal_Labelled[trainIndex, ])
testData <- droplevels(Zonal_Labelled[-trainIndex, ])

# Check that there is the same number of observations for each LCTYPE as before in both datasets
table(trainData$LCTYPE)
table(testData$LCTYPE)

# Run the model 
# Next, ensure parameters of the model are same as before:
model_all <- randomForest(formula = LCTYPE~., data=trainData,
                          mtry = 8,
                          ntree= 200,
                          importance =TRUE, sampsize = c(round(sum(trainData$LCTYPE == "GRS")*0.01, 0),
                                                         round(sum(trainData$LCTYPE == "SB")*0.12,0),
                                                         sum(trainData$LCTYPE == "SO"),sum(trainData$LCTYPE == "WB"),
                                                         sum(trainData$LCTYPE == "WW")))
model_all

# Predict Output on the test dataset
class_prediction <- predict(model_all, testData, type = "class")
summary(class_prediction)

# Create the confusion Matrix 
CM <- confusionMatrix(data = class_prediction, reference = testData$LCTYPE)
CM
# Look at the error rate (1 - accuracy). Keep a note of this - if error rate increases too much (> 1%) STOP, otherwise continue...


# Now we need to re-evaluate the importance of the remaining variables used in the model, so that we can remove the next 50%.
var_importance <- importance(model_all)
var_importance <- as.data.frame(var_importance)
var_importance_Gini <- var_importance[order(var_importance$MeanDecreaseGini),]

# WARNING: Before returning to start of section to repeat these steps - DO NOT RUN THE SAME UNIMPORTANT VARIABLE !!!!!!!!
# Instead use unimportant.2 for the second iteration, unimportant.3 for the third iteration etc.
# This is because the code is created to take the top half of the variables in the Var_importance_Gini dataframe, thus
# if you overwrite it, you won't be able to take away the other iteration variables. 
# Add the unimportant variables in the labelled zonal stats before re-running the model 

#### Go back to start of section - making sure to run a different unimportant variable each time ##### 




################################# 2: MDAMDG #################################
# Method 2 uses both mean decrease in accuracy and  mean decrease in Gini values assigned by the model when importance is set to TRUE.
# This method was sourced from https://ieeexplore.ieee.org/document/7883053

# STEP 1: RANKING AND SCORING BY MDA (Mean Decrease Accuracy) AND MDG (Mean Decrease in Gini)
# Getting information about important variables in the model and ordering variables by importance using Gini Values 
# with least important variables at top
var_importance <- importance(model_all)
var_importance <- as.data.frame(var_importance)
var_importance <- var_importance[order(var_importance$MeanDecreaseGini),]

# Creating Score for each variable with 330 assigned to highest and 1 assigned to lowest
# 330 is the total number of variables in the full dataset (after range variables are removed)
var_importance$Gini_score <- 1:nrow(var_importance)

# Next we order the dataframe by Mean Decrease Accuracy and assign a score with 300 for the highest
# and 1 for the lowest. 
var_importance <- var_importance[order(var_importance$MeanDecreaseAccuracy),]
var_importance$Acc_score <- 1:nrow(var_importance)

# Now we create total score which is the two scores combined (they will be equally weighted)
var_importance$total_score <- var_importance$Gini_score + var_importance$Acc_score

# Now order the dataframe by total score so that ...
var_importance <- var_importance[order(var_importance$total_score),]

# The procedure to reduce variables is as follows:
# 1) Remove bottom 50% of total score values from the dataset
# 2) Re-run the model with those variables (in order for fair comparison make sure set.seed is set for the train/test datasets)

# DO NOT RUN ALL OF UNIMPORTANT VARIABLES BELOW. First recall the variable importance section above where we have ordered the 
# variables by increasing Gini values. So we want to select the top 50% (ie half the variables) to be removed
#To do this run Unimportant - DONT RUN ANY OTHER 
Unimportant <- rownames(var_importance)[1:(ceiling(nrow(var_importance)/2))]
Unimportant.2 <- rownames(var_importance)[1:(ceiling(nrow(var_importance)/2))]
Unimportant.3 <- rownames(var_importance)[1:(ceiling(nrow(var_importance)/2))]
Unimportant.4 <- rownames(var_importance)[1:(ceiling(nrow(var_importance)/2))]

#Afterwards, we create a duplicated labelled dataset but with unimportant variable(s) removed
Zonal_Labelled <- select(Zonal_Labelled, -c(Unimportant.2))

##### The next few steps are for re-running the model
# Training and Test split
trainDataSplit <- split
TestDataSplit <- 1 - trainDataSplit

# Split Dataset into training and test subsets using the reduced labelled zonal stats 
set.seed(1)
trainIndex <- sample(nrow(Zonal_Labelled), trainDataSplit*nrow(Zonal_Labelled))

trainData <- droplevels(Zonal_Labelled[trainIndex, ])
testData <- droplevels(Zonal_Labelled[-trainIndex, ])

# Check that there is at least one observation for each LCTYPE in both datasets
table(trainData$LCTYPE)
table(testData$LCTYPE)

# Run the model 
model_all <- randomForest(formula = LCTYPE~., data=trainData,
                          mtry = 8,
                          ntree= 200,
                          importance =TRUE, sampsize = c(round(sum(trainData$LCTYPE == "GRS")*0.01, 0),
                                                         round(sum(trainData$LCTYPE == "SB")*0.12,0),
                                                         sum(trainData$LCTYPE == "SO"),sum(trainData$LCTYPE == "WB"),
                                                         sum(trainData$LCTYPE == "WW")))
model_all

# Predict Output on the test dataset
class_prediction <- predict(model_all, testData, type = "class")
summary(class_prediction)

# Confusion Matrix  
CM <- confusionMatrix(data = class_prediction, reference = testData$LCTYPE)
CM

# Look at the error rate (1 - accuracy). Keep a note of this - if error rate increases too much (> 1%) STOP, otherwise continue...


#Now we need to re-evaluate the importance of the remaining variables used in the model, so that we can remove the next 50%.
var_importance <- importance(model_all)
var_importance <- as.data.frame(var_importance)
var_importance <- var_importance[order(var_importance$MeanDecreaseGini),]
var_importance$Gini_score <- 1:nrow(var_importance)

var_importance <- var_importance[order(var_importance$MeanDecreaseAccuracy),]
var_importance$Acc_score <- 1:nrow(var_importance)

var_importance$total_score <- var_importance$Gini_score + var_importance$Acc_score
var_importance <- var_importance[order(var_importance$total_score),]

# WARNING: Before returning to start of section to repeat these steps - DO NOT RUN THE SAME UNIMPORTANT VARIABLE !!!!!!!!
# Instead use unimportant.2 for the second iteration, unimportant.3 for the third iteration etc.
# This is due to the same reason as before; if you overwrite it, you won't be able to take away the other iteration variables. 
# Add the unimportant variables in the labelled zonal stats before re-running the model 

#### Go back to start of section - making sure to run a different unimportant variable each time #####




################################# 3: VSURF #################################
# Method 3 uses the R package VSURF and has three steps - threshold, interpretation and prediction
# Note that this method is highly time consuming  
library(VSURF)

set.seed(1)
Variable_reduction <- VSURF(formula = LCTYPE~., data=trainData,
                            mtry = 8,
                            ntree= 200,
                            sampsize = sampsize = c(round(sum(trainData$LCTYPE == "GRS")*0.01, 0),
                                                    round(sum(trainData$LCTYPE == "SB")*0.12,0),
                                                    sum(trainData$LCTYPE == "SO"),sum(trainData$LCTYPE == "WB"),
                                                    sum(trainData$LCTYPE == "WW")))

# Threshold Step
Variable_reduction$varselect.thres
length(Variable_reduction$varselect.thres) 
plot(Variable_reduction, step = "thres", imp.sd = FALSE, var.names = TRUE)

# Interpretation Step
Variable_reduction$varselect.interp
length(Variable_reduction$varselect.interp) 
plot(Variable_reduction, step = "interp", imp.sd = FALSE)

# Prediction Step
Variable_reduction$varselect.pred
length(Variable_reduction$varselect.pred) 
plot(Variable_reduction, step = "pred", imp.sd = FALSE)

# Overall computation time
Variable_reduction$overall.time

# Now let's use the variables from the threshold step:
LCTYPE <- trainData$LCTYPE
trainData <- trainData[, Variable_reduction$varselect.thres]
trainData$LCTYPE <- LCTYPE

LCTYPE <- testData$LCTYPE
testData<- testData[, Variable_reduction$varselect.thres]
testData$LCTYPE <- LCTYPE


# Now let's use the variables from the interpretation step:
Actual_LCTYPE <- trainData$LCTYPE
trainData <- trainData[, Variable_reduction$varselect.interp]
trainData$LCTYPE <- Actual_LCTYPE

Actual_LCTYPE <- testData$LCTYPE
testData  <- testData[, Variable_reduction$varselect.interp]
testData$LCTYPE <- Actual_LCTYPE


# Now let's use the variables from the prediction step:
Actual_LCTYPE <- trainData$LCTYPE
trainData <- trainData[, Variable_reduction$varselect.pred]
trainData$LCTYPE <- Actual_LCTYPE

Actual_LCTYPE <- testData$LCTYPE
testData <- testData[, Variable_reduction$varselect.pred]
testData$LCTYPE <- Actual_LCTYPE


#running model
set.seed(1)
model_all <- randomForest(formula = LCTYPE~., data=trainData,
                          mtry = 8,
                          ntree= 200,
                          importance =TRUE, sampsize = c(round(sum(trainData$LCTYPE == "GRS")*0.01, 0),
                                                         round(sum(trainData$LCTYPE == "SB")*0.12,0),
                                                         sum(trainData$LCTYPE == "SO"),sum(trainData$LCTYPE == "WB"),
                                                         sum(trainData$LCTYPE == "WW")))
model_all

# Predict output on the test dataset
class_prediction <- predict(model_all, testData, type = "class")
summary(class_prediction)

# Confusion Matrix 
CM <- confusionMatrix(data = class_prediction, reference = testData$LCTYPE)
CM




################################# 4: VarSelRF #################################
# Method 4 uses the R package varSelRF 
library(varSelRF)

# Variable Selection using OOB error
set.seed(1)
varselrf <- varSelRF(select(trainData, 1:198), trainData$LCTYPE, ntree = 200,
                     ntreeIterat = 200, returnFirstForest = TRUE, recompute.var.imp = TRUE,
                     vars.drop.frac = 0.1)

varselrf$selected.vars

# Reduce the number of variables in training/test datasets:
Actual_LCTYPE <- trainData$LCTYPE
trainData <- trainData[, varselrf$selected.vars]
trainData$LCTYPE <- Actual_LCTYPE

Actual_LCTYPE <- testData$LCTYPE
testData <- testData[, varselrf$selected.vars]
testData$LCTYPE <- Actual_LCTYPE


#running model
set.seed(1)
model_all <- randomForest(formula = LCTYPE~., data=trainData.1,
                          mtry = 8,
                          ntree= 200,
                          importance =TRUE, sampsize = c(round(sum(trainData$LCTYPE == "GRS")*0.01, 0),
                                                         round(sum(trainData$LCTYPE == "SB")*0.12,0),
                                                         sum(trainData$LCTYPE == "SO"),sum(trainData$LCTYPE == "WB"),
                                                         sum(trainData$LCTYPE == "WW")))
model_all

# Predict Output on the test dataset
class_prediction <- predict(model_all, testData, type = "class")
summary(class_prediction)

# Confusion Matrix 
CM <- confusionMatrix(data = class_prediction, reference = testData$LCTYPE)
CM




################################# 5: randomForestSRC #################################
# Method 4 uses the R package randomForestSRC
# This method was used to reduce the zonal dataset ! 
library(randomForestSRC)

# Convert character to factors,otherwise the method won't work
trainData$FID_1 <- as.factor(trainData$FID_1)
trainData$AREA <- as.factor(trainData$AREA)

set.seed(1)
src <- var.select(formula = LCTYPE~., data=trainData,
                  mtry = 8,
                  ntree= 200,
                  importance =TRUE, sampsize = c(round(sum(trainData$LCTYPE == "GRS")*0.01, 0),
                                                 round(sum(trainData$LCTYPE == "SB")*0.12,0),
                                                 sum(trainData$LCTYPE == "SO"),sum(trainData$LCTYPE == "WB"),
                                                 sum(trainData$LCTYPE == "WW")))

src$topvars

# Reduce the number of variables in training/test datasets:
Actual_LCTYPE <- trainData$LCTYPE
trainData <- trainData[, src$topvars]
trainData$LCTYPE <- Actual_LCTYPE

Actual_LCTYPE <- testData$LCTYPE
testData <- testData[, src$topvars]
testData$LCTYPE <- Actual_LCTYPE

#running model
set.seed(1)
model_all <- randomForest(formula = LCTYPE~., data=trainData,
                          mtry = 8,
                          ntree= 200,
                          importance =TRUE, sampsize = c(round(sum(trainData$LCTYPE == "GRS")*0.01, 0),
                                                         round(sum(trainData$LCTYPE == "SB")*0.12,0),
                                                         sum(trainData$LCTYPE == "SO"),sum(trainData$LCTYPE == "WB"),
                                                         sum(trainData$LCTYPE == "WW")))
model_all

# Predict output on the test dataset
class_prediction <- predict(model_all, testData, type = "class")
summary(class_prediction)

# Confusion Matrix  
CM <- confusionMatrix(data = class_prediction, reference = testData$LCTYPE)
CM




################################# 6: RRF #################################
# Method 4 uses the R package RRF 
library(RRF)

trainData$FID_1 <- as.character(trainData$FID_1)
trainData$AREA <- as.character(trainData$AREA)

set.seed(1)
rrf <- RRF(formula = LCTYPE~., data=trainData,
           mtry = 8,
           ntree= 200,
           sampsize = c(round(sum(trainData$LCTYPE == "GRS")*0.01, 0),
                        round(sum(trainData$LCTYPE == "SB")*0.12,0),
                        sum(trainData$LCTYPE == "SO"),sum(trainData$LCTYPE == "WB"),
                        sum(trainData$LCTYPE == "WW")))

rrf$feaSet

# Reduce the number of variables in training/test datasets:
Actual_LCTYPE <- trainData$LCTYPE
trainData <- trainData[, rrf$feaSet]
trainData$LCTYPE <- Actual_LCTYPE

Actual_LCTYPE <- testData$LCTYPE
testData <- testData[,  rrf$feaSet]
testData$LCTYPE <- Actual_LCTYPE

#running model
set.seed(1)
model_all <- randomForest(formula = LCTYPE~., data=trainData,
                          mtry = 8,
                          ntree= 200,
                          importance =TRUE,  sampsize = c(round(sum(trainData$LCTYPE == "GRS")*0.01, 0),
                                                          round(sum(trainData$LCTYPE == "SB")*0.12,0),
                                                          sum(trainData$LCTYPE == "SO"),sum(trainData$LCTYPE == "WB"),
                                                          sum(trainData$LCTYPE == "WW")))
model_all

# Predict Output on the test dataset
class_prediction <- predict(model_all, testData, type = "class")
summary(class_prediction)

# Confusion Matrix  
CM <- confusionMatrix(data = class_prediction, reference = testData$LCTYPE)
CM




################################# Save the dataset #################################
# Once the variable selection method has been chosen, save the dataset which will be used for the next R script.  
# Create a new zonal dataset by selecting the reduced variables from the full zonal dataset
# Ensure that FID_1, LCTYPE and AREA are included (regardless of whether the variables were selected or not)
Zonal_reduced <- select(zonal_1300, src$topvars)
Zonal_reduced$LCTYPE <- zonal_1300$LCTYPE
Zonal_reduced$FID_1 <- zonal_1300$FID_1
Zonal_reduced$AREA <- zonal_1300$AREA

Zonal_reduced %>%
  write_csv("src_zonal_stats_combined_over1300m2_single_csv_by_pass.csv")


######  Please continue onto "4 - Running Code on Reduced Zonal Data" which continues from this R script






