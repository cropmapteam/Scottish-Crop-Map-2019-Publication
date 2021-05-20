######################################### Script 2: Random Forest Modelling #########################################


# Please note that this is a continuation from "1 - Interpolating & Preparing Data" R script. 
# Please run the first script before continuing with this R script. 




# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Training & Test Dataset ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Create the split ratio - so that 60% is assgined to the training data and 40% to the test data
trainDataSplit <- 0.6
TestDataSplit <- 1 - trainDataSplit

# Split the data into training and test subsets using the labelled dataset
set.seed(1) # Please run the set.seed throughut the scripts to ensure results are reproducible 
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




# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Train a Random Forest Model ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
set.seed(1)
model_all <- randomForest(formula = LCTYPE~., data=trainData,
                          mtry = 8,
                          ntree= 200,
                          importance =TRUE, sampsize = c(round(sum(trainData$LCTYPE == "GRS")*0.01, 0),
                                                         round(sum(trainData$LCTYPE == "SB")*0.12,0),
                                                         sum(trainData$LCTYPE == "SO"),sum(trainData$LCTYPE == "WB"),
                                                         sum(trainData$LCTYPE == "WW")))
model_all
# Please see "3 - Model Improvements & Varable Reduction" for more detail on improvments made to the model

# Plot of training Dataset against predictions 
model_all_train_plot <- ggplot(trainData, aes(x=LCTYPE, y=model_all$predicted, colour =LCTYPE)) +
  geom_boxplot(size=1, show.legend = FALSE) +
  geom_jitter(size=2, show.legend = FALSE) +
  labs(title = paste("Ramdom Forest(", all, "vars): Train data Confusion Matrix"), x = "Actual Class", y = "Predicted Class")




# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ OOB Error Rate ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Grab OOB error matrix and observe
err <- model_all$err.rate
head(err)

# Final row in OOB error rate should be same as the output for training data
oob_err <- err[ 200 , "OOB"]
oob_err

# Plot error rate only and find the minimum OOB error rate with respect to the number of trees
plot(model_all$err.rate[,1], 
     xlab= "Number of Trees", 
     ylab= "Error rate(%)",
     type ="l",
     col= "mediumpurple1",
     main= paste("Random Forest Model Results: Error Rate (", all, " vars)"),
     cex.main= 1, font.main= 2, col.main = "black")

# Which tree produces the lowest error rate 
which(model_all$err.rate[,1] == min(model_all$err.rate[,1] ))

# Plot error rate for all classes and OOB  
plot(model_all,lty =1 )
legend("topright", legend = colnames(err), fill = 1:ncol(err),cex=0.5)




# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Model Performance on Test Data ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Predict using the random forest model above on the test dataset
class_prediction <- predict(model_all, testData, type = "class")
summary(class_prediction)

# Confusion Matrix (CM)
CM <- confusionMatrix(data = class_prediction, reference = testData$LCTYPE)
CM

# Compare test set accuracy to OOB accuracy
paste0("Test Accuracy: ", CM$overall[1])
paste0("OOB Accuracy: ", 1 - oob_err)

# Plot of Test Dataset against model predictions
model_all_test_plot <- ggplot(testData, aes(x=LCTYPE, y=class_prediction, colour =LCTYPE)) +
  geom_jitter(size=2, show.legend = FALSE) +
  labs(title = paste("Ramdom Forest(", all, "vars): Test data Confusion Matrix"), x = "Actual Class", y = "Predicted Class") 

grid.arrange(model_all_train_plot, model_all_test_plot)




#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Individual Class Accuracy on Test Data ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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



######  Please continue onto "3 - Model Improvements & Variable Selection" which continues from this R script




