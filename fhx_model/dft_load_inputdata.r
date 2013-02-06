#install.packages(c("zoo","tseries","gregmisc","gdata","gtools","gmodels","gplots"))
#rm(list=ls(all=TRUE))
library(IBrokers)
library(zoo)
library(xts)
library(tseries)

args <- commandArgs(trailingOnly = TRUE)
print(args) 

# user working directory, everything should be relative to this
WD <- "C:/Projects/workspace/FHX_model/"
dateStr <- '20111116' # Dev test date
startTime <- format(Sys.time(),format="%Y-%m-%d %H:%M:%S")

# use command line parms
if (length(args)>0) {
  dateStr <- args[1]
  WD <- args[2]
}

setwd(WD)
source(paste(WD,"ib_callback.r",sep=""))

# dft parms 
bwsize <- 12
swsize <- 48

# main program
#secList <- c("xlf","xle","xlu", "xlk", "xlb", "xlp", "xly","xli","xlv") # with header=Symbol
secList <- c("xlk") # test run

for (m in 1:length(secList))
{
  sector <- secList[m]
  secFile <- paste(WD,sector,".us.csv",sep="")

  # input data file with sync tick for all symbols
  tick_data <- as.data.frame(NA)
  idx <- 1
    
  symList <- read.csv(secFile)
  syms <- as.vector(symList$Symbol)
  syms <- c(toupper(sector), syms)
  
  if (length(syms) < 2) # no pair found 
    next 
    
  cat("Load ", length(syms), " symbols in ", toupper(sector), " \n")
  
  # create a data frame with # of syms as columns
  #syms <- c("XLK", "AAPL", "IBM")
  minbarList <- list()
  # load IB 1 minute bar data
  for (n in 1:length(syms))
  {
    # get each minute's close price
    datDir <- paste("/data/",dateStr,sep="")
    if (!file.exists(datDir))
      next 

    inputFile <- paste(datDir,"/minbar_",syms[n],"_",dateStr,".csv",sep="")  
    
    cat(n, " loading data file ", inputFile, "\n")
    inputDat <- read.csv(inputFile);
    minbarList[[n]] <- inputDat[,5]    
  }  
  # big data frame
  secData <- do.call(cbind, minbarList)
  
  # create the input data file
  inputData <- data.frame(matrix(ncol = 7, nrow = length(syms)*nrow(secData)))
  colnames(inputData) <- c("streamID", "datapoint", "value", "symbol", "bid", "ask", "time")
  # allocate memory space
  index <- 1
  for (datapoint in 1:nrow(secData)) 
  {
    cat("processing realtime tick...datapoint: ", datapoint, " \n")
    
    for (cn in 1:length(syms))
    { 
      inputData[index,1] <- paste("s",cn,sep="")  # streamId 
      inputData[index,2] <- datapoint  # dataPoint
      inputData[index,3] <- secData[datapoint,cn]  # value
      inputData[index,4] <- syms[cn]  # symbol
      inputData[index,5] <- secData[datapoint,cn]  # bid
      inputData[index,6] <- secData[datapoint,cn]  # ask
      #inputData[rowId,7] <- format(index(secData)[rw], "%Y%m%d %H:%M:%OS") 

      index <- index + 1
    }
    
    # foreach basic window 
    if (datapoint %% bwsize == 0) {
      cat(" new basic window: ", datapoint/bwsize, "\n")
    }
    
    if (datapoint %% swsize ==0) {
      cat(" new sliding window: ", datapoint/swsize, "\n")    
    }
    
  }
  
  # create zoo object for all symbol's data series
  dataFile <- paste("/data/statstream/inputdata_",sector,"_",dateStr,"_XLK.csv",sep="")
  write.csv(inputData, dataFile)
      
  # create pair list with each index
  #pairList <- combn(names(zooObj), 2) 
  
  # compute correlations 
  
  

}# end secList

cat("\nPG Started time: ", startTime, "\n");
cat("All DONE. ", format(Sys.time(),format="%Y-%m-%d %H:%M:%S"), "\n")
