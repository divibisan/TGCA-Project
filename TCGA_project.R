require(dplyr)
require(stringr)
require(MLSeq)
require(rpart)

require(MASS)
require(car)
rm(list = ls())

multmerge = function(mypath){
  # Get files from directory and load as list
  filenames = list.files(path = mypath, full.names = TRUE)
  datalist = lapply(filenames,
                    function(x){read.table(file = x,
                                           colClasses = c("character", "numeric"))})
  # Create dataframe from first file
  merged.list <- datalist[[1]]
  # Loop through all files, FULL JOIN with the dataframe on the gene variable
  for (item in datalist[-1]) {
    merged.list <- full_join(merged.list, item, by = "V1")
  }
  rownames(merged.list) <- merged.list[,1]
  merged.list <- merged.list[,-1]
  # Set filenames (stripped of extension) as column names
  colnames(merged.list) <- str_replace_all(filenames, "files/unzip/|.FPKM.txt|.htseq.counts", "")
  return(merged.list)
}
# Load expression data
lung.scc <- multmerge("files/unzip")

  # Add days to death (response variable)
lung.scc.meta <- read.csv("file_manifest.csv", header = T,
                          colClasses = c("character","character", "numeric", "factor", "factor"))
meta.column.order <- unname(sapply(colnames(lung.scc), function(x){which(lung.scc.meta$file == x)}))
lung.scc.meta <- lung.scc.meta[meta.column.order,]

head(colnames(lung.scc))
head(rownames(lung.scc))
head(lung.scc.meta[,1])

t.lung.scc <- data.frame(t(lung.scc))

t.lung.scc2 <- cbind(lung.scc.meta[,3], t.lung.scc)
colnames(t.lung.scc2)[1] <- "days.to.death"
#linear.model <- lm(days.to.death ~ ., data = t.lung.scc2)

# Order variables by highest highest variance
t.lung.scc3 <- t.lung.scc2[, c(1,order(apply(t.lung.scc2[,-1], 2, var), decreasing = TRUE))]

bins <- cut(t.lung.scc3[,1], 5, include.lowest = TRUE)


t.lung.scc3.cut150 <- cbind(bins, t.lung.scc3[,2:5000])
# Generate Training and Testing datasets 
train <- t.lung.scc3.cut150[1:180, ]
test  <- t.lung.scc3.cut150[181:247,]



class = data.frame(bins)
as.factor(class[,1])

## ----chunk7--------------------------------------------------
data = data.frame(t(t.lung.scc3[which(!is.na(class)),2:501]))
class = data.frame(class[which(!is.na(class)),])
dim(data)
## ----chunk8--------------------------------------------------
nTest = ceiling(ncol(data)*0.2)  
set.seed(12345) 
ind = sample(ncol(data), nTest, FALSE)

## ----chunk9--------------------------------------------------
data.train = data[,-ind]  
data.train = as.matrix(data.train + 1)
classtr = data.frame(condition = class[-ind,])

## ----chunk10-------------------------------------------------
data.test = data[,ind]
data.test = as.matrix(data.test + 1)
classts = data.frame(condition = class[ind,])

## ----chunk11-------------------------------------------------
dim(data.train)
dim(data.test)
dim(classtr)
str(data.train)
sum(sapply(data.train, function(x) sum(is.na(x))))

## ----chunk12, message=FALSE----------------------------------
data.trainS4 = DESeqDataSetFromMatrix(countData = data.train,
                                      colData = classtr, formula(~condition))
data.trainS4 = DESeq(data.trainS4, fitType="local")
data.trainS4

## ----chunk13, message=FALSE----------------------------------
data.testS4 = DESeqDataSetFromMatrix(countData = data.test,
                                     colData = classts, formula(~condition))
data.testS4 = DESeq(data.testS4, fitType = "local") 
data.testS4

rf = classify(data = data.trainS4, method = "randomforest", normalize = "deseq", 
              deseqTransform = "vst", cv = 5, rpt = 3)
rf

x = predictClassify(rf, data.trainS4)
table(x, classts)
###########
#RPART
dec.tree <- rpart(bins ~., data = train)

summary(dec.tree)
dec.tree


table(predict(dec.tree, type = "class", newdata = test[,-1]), test[,1])
#######
# MLSeq

de_data <- DESeqDataSetFromMatrix(train)

mlseq <- classify(train, method = "randomforest")


############
####LDA

lda <- lda(days.to.death ~ ., data = train)
# Predict categories based on LDA model
#  remove tumor column for preiction
predict <- predict(lda, newdata = test)
# Get number of correct predictions
agreement <- predict$class == test$day.to.death
# Store proportion correct guesses in vector
results[n] <- sum(agreement)/nrow(expr.test)
