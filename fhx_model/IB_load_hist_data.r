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

#if (!is.null(tws))
#  twsDisconnect(tws)
# get IB connection
tws <- twsConnect()
reqHistoricalData(tws, twsSTK("XLK"), barSize="1 min", duration = "1 D")[,4]

# main program
#secList <- c("xlf","xle","xlu", "xlk", "xlb", "xlp", "xly","xli","xlv") # with header=Symbol
#secList <- c("xlk","xly") # test run
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
  
  if (length(syms) < 2) # no pair found 
    next 
    
  cat("Got ", length(syms), " symbols in ", toupper(sector), " \n")
  
  # create a data frame with # of syms as columns
  #syms <- c("XLK", "AAPL", "IBM", "AMZN")
  # load IB 1 minute bar data
  for (n in 1:length(syms))
  {
    #if (n < 70)
    #  next 
      
    # get each minute's close price
    cat(n, " loading minute bar data ", syms[n], "\n")
    #oneMinbar <- reqHistoricalData(tws, twsSTK(syms[n]), barSize="1 min", duration = "1 D")
    oneMinbar <- reqHistoricalData(tws, twsSTK("XLK"), barSize="1 min", duration = "1 D")
    
    datDir <- paste("/data/",dateStr,sep="")
    if (!file.exists(datDir))
      dir.create(datDir)
    
    outFile <- paste(datDir,"/minbar_",syms[n],"_",dateStr,".csv",sep="")  
    write.csv(oneMinbar,outFile)    
  }  
  
}# end secList

cat("\nPG Started time: ", startTime, "\n");
cat("All DONE. ", format(Sys.time(),format="%Y-%m-%d %H:%M:%S"), "\n")
