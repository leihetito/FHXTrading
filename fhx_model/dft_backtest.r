#library(tseries)
#library(zoo)
# clear workspace variables
rm(list=ls(all=TRUE))

args <- commandArgs(trailingOnly = TRUE)
print(args)

# user working directory, everything should be relative to this
WD <- "C:/Projects/workspace/FHX_model/"
startTime <- format(Sys.time(),format="%Y-%m-%d %H:%M:%S")

# use command line parms
if (length(args)>0) {
  dateStr <- args[1]
  WD <- args[2]
}

setwd(WD)
source(paste(WD,"dft_streamstats_func.r",sep=""))
source(paste(WD,"fhx_statstream_trade_signal.r",sep=""))

##
## Global variables 
##
max_window_of_day <- 10

corr_pairs <<- list() 		# list of all the correlation stats calculated on 
							# each bw. keys are the bw number, values are data frames

open_positions <<- data.frame() 		# open positions at any given moment
									# added when trading signal is generated, remove when closing position
									# TODO: this can be linked with actual ors trade executions

all_trade_signals <<- data.frame()	# data frame to hold all of todays trading signal

dateStr <- '20111116' # Dev test date
sector <- "xlk"
secFile <- paste(WD,sector,".us.csv",sep="")

# input data file with sync tick for all symbols
tick_data <- as.data.frame(NA)
idx <- 1

symList <- read.csv(secFile)
syms <- as.vector(symList$Symbol)
syms <- c(toupper(sector),syms)
n_stream <- length(syms)

# contains all global variables used by all functions
# basic parameters
bw <- 24
sw <- 96
#n_stream <- 50
threshold <- 0.9  # correlation threshold for outputs

# number of input streams
streams <- paste("s",1:n_stream,sep="")
ids <- as.vector(streams)  # stream ids or names

nb <- sw/bw  # the number of basic window within a sliding window
nc <- 6  # the number of sine or cosine DFT coefficients
flagHash <- 1
flagDft <- 0

if (nc > bw) {
  nc = bw
}
nn <- nc * 2

# basic window stats
basicwin <- list()
basicwin$mean <- 0
basicwin$sum2 <- 0
# initialize DFT coeffients, start with nn/2 cosine and nn/2 sine coefficients
if (flagDft) {
  basicwin$dftcoef <- c(0,0,0,0,0,0, 0,0,0,0,0,0)
}
if (flagHash) {
  basicwin$dfthash <- c(0,0,0,0,0,0, 0,0,0,0,0,0)
}

# sliding window digest structure
digest <- list()
digest$bwwindows <- list()  # list of basic windows stats
digest$sum <- 0
digest$sum2 <- 0
digest$mean <- 0
digest$mean2 <- 0
digest$std <- 0

if (flagHash) {
  digest$dfthash <- c(0,0,0,0,0,0, 0,0,0,0,0,0)
  digest$dftnorm <- c(0,0,0,0,0,0, 0,0,0,0,0,0)
}  # DFT coefficients for the digest, or whole sliding window

digest$timepoint <- 1  # accumulating time point, no rotating
digest$ptr1 <- 1  # the window to be updated (the oldest window)
digest$ptr2 <- 0  # the position to be updated within basic window (the oldest data point)

# initialize digest$bwwindows
for (w in 1: nb+1) {
  digest$bwwindows[[w]] <- basicwin
}

# precompute before the stream come in
t <- c(0:(bw-1))
arg <- 2*3.1415926/bw
p <- seq(1,nc)
COS <- cos(arg*p%*% t(t))
SIN <- sin(arg*p%*% t(t))

dftHash <- 1
# for dfthash
if (dftHash) {
  # for the digest computing
  mm <- 1:nc
  t <- bw:1
  arg <- 2*3.1415926/sw
  REAL <- cos(arg*mm%*% t(t) )
  IMAGE <- sin(arg*mm%*% t(t) )
  PHASE1 <- cos(arg*mm*bw)
  PHASE2 <- sin(arg*mm*bw)

  # for the grid structure
  unit <- sqrt(1-threshold)
  unit_r <- 1/unit
  whole <- 0.707  # sqrt(2)/2
  P <- floor(2*(1+ whole/unit))
  PP <- P/2
  R <- 3  #grid is P*P*...*P=P^R
  List <- P^(0:(R-1))
}


#MAIN PROGRAM
outreport <- data.frame()  # output report
rdx <- 1

statstream <- list() # digest /all the digests of the data streams, using rotating windows
for (sm in 1:n_stream) {
  statstream[[sm]] <- digest
}

#chopChunk <- matrix(data=0, nrow=n_stream, ncol=sw) # all data points in the sliding window
chopChunk <- list()  # raw data for each stream to compute real correlation of sw

#	start: _t  //start time for all the computation
#	start2: 0  //start time for steady stage computing

	gridhashTime <- 0  #the time need for Grid-Hash correlation report
	readpointer <- 1
	last <- 1
	count <- 0
	total <- 0
	h <- 0

# global variables init end
# set the init_status so JAVA can verify it
init_status <- "SUCCESS"

# now all functions can be called from JAVA

# do back test
inDataDir <- paste("/data/statstream/",sep="")
outDataDir <- paste("/data/statstream/",sep="")

# load inputdata_sector_19991231.csv
newdata <- paste("/data/statstream/inputdata_",sector,"_",dateStr,".csv",sep="")
tickstream <- read.csv(newdata, header=TRUE)
#corr_report <- process_sliding_window(tickstream)

# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
corr_report <- data.frame()
swnum <- 1

  # number of bw we got from tickstream  
  m <- length(tickstream$streamID) / (bw*n_stream) 
  
  # m is for each bw update 
  for (i in 1:m) {
    cat("\n+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n")
    cat("processing bwnum...",i," \n")
    
    # get new basic window data for all stream  
    newbw <- tickstream[readpointer:(i*bw*n_stream), ]
    newdigest <- UpdateDigest(statstream, chopChunk, newbw)

    # update chopChunk and statstream
    statstream <- newdigest$statstream 
    chopChunk <- newdigest$chopChunk
      
    # update readpointer (in real-time this is timestamp)
    readpointer <- i*bw*n_stream + 1

    corr_pairs[[i]] <- c()
      
    # computing correlation    
    if (i >= sw/bw) {
      cat("sliding window num ", swnum, " start computing correlations \n")
    
      if (flagHash) {
        newCorrReport <- CorrlationReport(i)   
        names(newCorrReport) <- c("streamID1", "streamID2", "BeginTimePoint", "EndTimePoint", "Dist", "CorrCoef", "open1", "close1", "open2", "close2","rowKey")
        corr_report <- rbind(corr_report, newCorrReport)
        
        # use Lei's fhx_statstream_trade_signal.r 
        corrPairs <- GetCorrelatedDataframeWithIndex(1, newCorrReport)
        cat("xxxx streamIDs correlated with index: ", unique(corrPairs$streamID1), "| ", unique(corrPairs$streamID2), " \n")
        corr_pairs[[i]] <- corrPairs
        
        # first bw after frist sw
   	    trade_signal <- generate_signals(corr_pairs, i)
   	    cat("xxxx basic window num ", i, ", trade signals: \n")
     	  #print(trade_signal)
     	  if (length(trade_signal)>0) {
	       trade_signal_i <- as.data.frame(do.call("rbind",trade_signal))
	       print(trade_signal_i)
      	 all_trade_signals <- rbind(all_trade_signals, trade_signal_i)
      	}

        # open/close positions
      }
      
      swnum <- swnum + 1  
    } # end of basic window loop
   
    cat("\n-----------------------------------------------------------------\n")
  }
  
  cat("process_sliding_window done.  ", format(Sys.time(),format="%Y-%m-%d %H:%M:%S"), "\n")

  # outfile 0: outs2
  #streamID1	streamID2	BeginTimePoint	EndTimePoint	CorrCoef
  names(corr_report) <- c("streamID1", "streamID2", "BeginTimePoint", "EndTimePoint", "Dist", "CorrCoef", "open1", "close1", "open2", "close2","rowKey")
  #outfile <- paste("/data/statstream/","outreport_",sector,"_",dateStr,".csv",sep="")
  outfile <- paste("/data/statstream/",sector,"_corr_report_",dateStr,".csv",sep="")
  write.csv(corr_report, outfile)
  cat("Writing correlated report to file: ", outfile, " .\n")
  
  
  outfile <- paste("/data/statstream/",sector,"_all_trade_signals_",dateStr,".csv",sep="")
  cat("Writing all_trade_signals report to file: ", outfile, " .\n")
  write.csv(all_trade_signals, outfile)
  
  # write positions 
  # create the trading signal
  # 1. track corrlated pairs
  # 2. trading signal is generated if a symbol drops out of the corr_pairs list 
  #   from last to current bw update
  # 3. if it's added back to the corr_pairs, close the position.
  #   ALSO, close the position if another sliding window has passed after initial 
  #     position was created.
  # Note: trading starts after the first sliding window + 1 basic window. 

# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx 


cat("\nPG Started time: ", startTime, "\n");
cat("All DONE.        ", format(Sys.time(),format="%Y-%m-%d %H:%M:%S"), "\n")
