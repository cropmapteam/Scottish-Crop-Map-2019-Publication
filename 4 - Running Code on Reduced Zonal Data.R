######################################### Script 4: Running Code on Reduced Zonal Data #########################################

# Please note that this is a continuation from "3 - Model Improvements & Variable Selection" R script. 
# Please run the code for that script before continuing with this R script. 
# This script is very similar to the first two r scripts. 

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Load R Packages & Read Data ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
library(plyr)             # for count
library(dplyr)            # for renaming columns
library(ggplot2)          # for graphs
library(grid)             # for displaying multiple graphs on same page
library(gridExtra)        # for displaying multiple graphs on same page
library(randomForest)     # for Random Forest Modelling
library(caret)            # for Confusion Matrix and Kappa coefficient
library(reshape2)         # for melt function
library(readr)            # for saving datasets


# Read in the reduced zonal dataset (without rfi) for large fields > 1300 metres squared. 
# Also read in ground truth dataset.
zonal_reduced <- read.csv("src_zonal_stats_combined_over1300m2_single_csv_by_pass.csv", header = TRUE, na.strings = NA)

# Convert LCTYPE to factor
zonal_reduced$LCTYPE <- as.factor(zonal_reduced$LCTYPE)


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Data Preparation ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating labelled dataset (known fields) by first creating a vector of column names containing 'range' and 'variance'
# Afterwards, remove them from the labelled dataset along with ID and LCGROUP
to.delete <- c(grep(pattern = "range", names(zonal_reduced)))
var <- c(grep(pattern = "variance", names(zonal_reduced)))
Zonal_Labelled <- subset(zonal_reduced, select = -c (var, FID_1, AREA,to.delete))

# Create the unlabelled dataset (known and unknown fields) by removing the same variables in the labelled dataset and LCTYPE
Zonal_Unlabelled <- subset(zonal_reduced, select = -c(var, FID_1,LCTYPE, AREA, to.delete))

#Removing missing values from the labelled dataset
Zonal_Labelled <- Zonal_Labelled[complete.cases(Zonal_Labelled),]

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


# Removing rows which have an LCTYPE under 25, this is because we have chosen a model with a restricted LCTYPE of more than 25 fields
Zonal_Labelled <- ddply(Zonal_Labelled, "LCTYPE", function(d) {if(nrow(d)>=25) d else NULL})
table(droplevels(Zonal_Labelled$LCTYPE))

# Resetting factor levels after subsetting (or else model fails)
levels(Zonal_Labelled$LCTYPE)
Zonal_Labelled$LCTYPE <- factor(Zonal_Labelled$LCTYPE)
levels(Zonal_Labelled$LCTYPE)



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Random Forest Model (on reduced data) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Create the split ratio - so that 60% is assgined to the training data and 40% to the test data
trainDataSplit <- 0.6
TestDataSplit <- 1 - trainDataSplit

# Split the data into training and test subsets using the labelled dataset
set.seed(1)
trainIndex <- sample(nrow(Zonal_Labelled), trainDataSplit*nrow(Zonal_Labelled))

trainData <- droplevels(Zonal_Labelled[trainIndex, ])
testData <- droplevels(Zonal_Labelled[-trainIndex, ])

# Check that there is at least one observation for each LCTYPE in both datasets
table(trainData$LCTYPE)
table(testData$LCTYPE)

# Plot of labelled dataset 
p1 <- ggplot(Zonal_Labelled, aes(x= LCTYPE)) +
  geom_bar(fill = "lightskyblue") +
  labs(title = "Original Dataset (Zonal_Labelled)", x = "Land Cover Type (LCTYPE)", y ="Number of Farm Fields") +
  theme(axis.text.x = element_text(angle = 90, hjust =1, vjust=0.5))


#Plot of training dataset
p2 <- ggplot(trainData, aes(x= LCTYPE)) +
  geom_bar(fill = "lightskyblue") +
  labs(title = "Training Dataset (Zonal_Labelled)", x = "Land Cover Type (LCTYPE)", y ="Number of Farm Fields") +
  theme(axis.text.x = element_text(angle = 90, hjust =1, vjust=0.5))

#Plot of test dataset
p3 <- ggplot(testData, aes(x= LCTYPE)) +
  geom_bar(fill = "lightskyblue") +
  labs(title = "Test Dataset (Zonal_Labelled)", x = "Land Cover Type (LCTYPE)", y ="Number of Farm Fields") +
  theme(axis.text.x = element_text(angle = 90, hjust =1, vjust=0.5))

grid.arrange(p1,p2,p3)


#Looking at the data
glimpse(Zonal_Labelled)
glimpse(trainData)

# Noting the number of variables (exlcuing the crop type variable) for graph titles
all <- length(trainData[1,]) -1


# The Random Forest Model
set.seed(1)
model_all <- randomForest(formula = LCTYPE~., data=trainData,
                          mtry = 8,
                          ntree= 200,
                          importance =TRUE, sampsize = c(round(sum(trainData$LCTYPE == "GRS")*0.01, 0),
                                                         round(sum(trainData$LCTYPE == "SB")*0.12,0),
                                                         sum(trainData$LCTYPE == "SO"),sum(trainData$LCTYPE == "WB"),
                                                         sum(trainData$LCTYPE == "WW")))
model_all


# Plot of training Dataset against predictions 
model_all_train_plot <- ggplot(trainData, aes(x=LCTYPE, y=model_all$predicted, colour =LCTYPE)) +
  geom_boxplot(size=1, show.legend = FALSE) +
  geom_jitter(size=2, show.legend = FALSE) +
  labs(title = paste("Ramdom Forest(", all, "vars): Train data Confusion Matrix"), x = "Actual Class", y = "Predicted Class")


# Grab OOB error matrix and observe
err <- model_all$err.rate
head(err)

# Final row in OOB error rate should be same as the output for training data
oob_err <- err[ 200 , "OOB"]
oob_err

#PLot error rate only and find the minimum OOB error rate with respect to the number of trees
plot(model_all$err.rate[,1], 
     xlab= "Number of Trees", 
     ylab= "Error rate(%)",
     type ="l",
     col= "mediumpurple1",
     main= paste("Random Forest Model Results: Error Rate (", all, " vars)"),
     cex.main= 1, font.main= 2, col.main = "black")

# Which tree produces the lowest error rate 
which(model_all$err.rate[,1] == min(model_all$err.rate[,1] ))

#PLot error rate for all classes and OOB  
plot(model_all,lty =1 )
legend(x= "topright", legend = colnames(err), fill = 1:ncol(err),cex=0.6)



# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Model Performance & Predictions (on test data) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Predict using the random forest model above on the test dataset
class_prediction <- predict(model_all, testData, type = "class")
summary(class_prediction)

# Confusion Matrix 
CM <- confusionMatrix(data = class_prediction, reference = testData$LCTYPE)
CM

# Compare test set accuracy to OOB accuracy
paste0("Test Accuracy: ", CM$overall[1])
paste0("OOB Accuracy: ", 1 - oob_err)

#Plot of Test Dataset against model predictions 
model_all_test_plot <- ggplot(testData, aes(x=LCTYPE, y=class_prediction, colour =LCTYPE)) +
  geom_jitter(size=2, show.legend = FALSE) +
  labs(title = paste("Ramdom Forest(", all, "vars): Test data Confusion Matrix"), x = "Actual Class", y = "Predicted Class") 

grid.arrange(model_all_train_plot, model_all_test_plot)


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Individual Class Accuracy (on test data) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Convert confusion matrix to a matrix
as_matrix_CM <- as.matrix(x = CM, what = "xtabs")

# Manually calculate the overall accuracy
sum(diag(as_matrix_CM))/sum(as_matrix_CM)
# this should be the same as the accuracy in the confusion matrx_all


# Individual Class Accuracy is Sensitivity/Recall - quantifies how many of the actual fields (classed as x) are correctly predicted
# as class x. 
# Convert to data frame in order to plot class accuracies 
class_accuracies <- as.data.frame(CM$byClass)["Sensitivity"]
class_accuracies <- data.frame(rownames(class_accuracies), class_accuracies$Sensitivity)
colnames(class_accuracies) <- c("Class", "Accuracy")
class_accuracies$Class <- gsub("Class:", "", class_accuracies$Class)

ggplot(class_accuracies) +
  geom_bar(aes(x = Class, y = Accuracy), stat = 'identity', fill = "darkseagreen") +
  labs(x = "Class",
       y = "Accuracy") +
  coord_flip() 



######  Please continue onto "5 - Probability Cut-Off on Predictions" which continues from this R script



