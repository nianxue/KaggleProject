library(plyr)
library(dplyr)
library(caret)
library(lubridate)
library(car)
library(doParallel)
library(glmnet)
library(earth)
library(randomForest)
library(kernlab)

setwd("E:/KaggleProject/RestaurantRevenuePrediction")
trainIni <- read.csv("E:/KaggleProject/RestaurantRevenuePrediction/train.csv/train.csv")
testIni <- read.csv("E:/KaggleProject/RestaurantRevenuePrediction/test.csv/test.csv")
submission <- read.csv("E:/KaggleProject/RestaurantRevenuePrediction/sampleSubmission.csv")

trainIni$revenue[trainIni$revenue > 1.0e+7] = 1.0e+7

revenue <- trainIni$revenue
trainIni$revenue <- NULL

trainIni$split <- 1
testIni$split <- 0

data <- bind_rows(trainIni, testIni)
split <- data$split

data$Open.Date <- mdy(data$Open.Date)
data$duration <- (mdy("3/1/2015") - data$Open.Date) / dyears(1)


data$City <- recode(data$City, "'Ä°stanbul' = 'Astanbul'; 'Ankara' = 'Ankara'; 'Ä°zmir' = 'Azmir';else = 'otherCity'")
data$Type <- recode(data$Type, "'IL' = 'IL'; else = 'FC'")

#remove high corelation features
Pvars <- grep("^P.*\\d$", names(data), value = T)
correlation <- cor(trainIni[, Pvars], method = "spearman")
highCorVars <- Pvars[findCorrelation(correlation, cutoff = 0.8)]
keep <- setdiff(names(data), highCorVars)
data <- data[,keep]


#recode P variabls to reduce the risk of overfitting
data$P2 <- recode(data$P2, "c(1, 1.5, 2, 3) = 3; c(4, 4.5) = 4; 5 = 5; else = 7")
data$P3 <- recode(data$P3, "c(0, 2, 3) = 3; 4 = 4; else = 5")
data$P4 <- recode(data$P4, "c(2, 3) = 3; c(4, 4.5) = 4; c(6, 7.5) = 6")
data$P5 <- recode(data$P5, "1 = 1; 2 = 2; else = 4")
data$P6 <- recode(data$P6, "c(6, 8, 10) = 8")
data$P7 <- recode(data$P7, "1:4 = 1; 5:6 = 5")
data$P8 <- recode(data$P8, "c(1, 2, 3, 6) = 3")
data$P10 <- recode(data$P10, "c(6,10) = 10")
data$P11 <- recode(data$P11, "c(6, 8, 10) = 10")
data$P12 <- recode(data$P12, "2:4 = 4; c(6,8,10) = 10")
data$P19 <- recode(data$P19, "c(10, 15, 20, 25) = 10")
data$P20 <- recode(data$P20, "c(6, 9, 12, 15) = 15")
data$P21 <- recode(data$P21, "c(4, 5, 6, 9, 12, 15) = 6")
data$P22 <- recode(data$P22, "c(4, 5, 6, 9, 12, 15) = 6")
data$P23 <- recode(data$P23, "3:4 = 3; c(10, 15, 20, 25) = 10")
data$P27 <- recode(data$P27, "c(1, 2, 2.5) = 1; c(3, 4, 5, 7.5, 10, 12.5) = 5")
data$P28 <- recode(data$P28, "c(2, 2.5) = 2; c(4, 5, 7.5, 10, 12.5) = 5")
data$P29 <- recode(data$P29, "0:1 = 1; c(2, 2.5) = 2; c(5, 7.5, 10) = 7.5")


data$duration <- log(data$duration)

data$Open.Date <- NULL
data$split <- NULL

###############build linear models#####################################################

#set parallel calculation
cl <- makeCluster(detectCores())
registerDoParallel(cl)


# set repeatedcv for measure model performace
trCtrl <- trainControl(method = "repeatedcv", 
                       number = 30, 
                       repeats = 5, 
                       seeds = NULL,
                       returnData = FALSE,
                       savePredictions = T)


###############train a glmnet model regard pVars as numerical#################
data.num <- model.matrix(~.- Id - 1, data = data)
data.num <- as.data.frame(data.num)


train <- data.num[split == 1, ]
train$large <- trainPred

test <- data.num[split != 1, ]
test$large <- testPred


set.seed(4632)
glmnet.num <- train(x = train,
                    y = revenue, 
                    method = "glmnet", 
                    metric = "RMSE", 
                    trControl = trCtrl,
                    family = "gaussian",
#                     tuneLength = 12,
#                     penalty.factor = penalty.factor,
                    tuneGrid = expand.grid(alpha = c(0.2636364), 
                                           lambda = c(3)),
                    dfmax = 10)



predGlmnet <- predict(glmnet.num, test)


stopCluster(cl)


