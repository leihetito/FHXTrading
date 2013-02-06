library(tseries)
library(zoo)

# clear workspace variables
rm(list=ls(all=TRUE))
# working dir, everything should be relative to this
DRIVE <- "C:"  
# or use DRIVE <- Sys.getenv("HOME")  # create your project directory relative to HOME
WD <- paste(DRIVE,"/Projects/workspace/FHX_model/",sep="") # working dir
source(paste(WD,"dft_func.r",sep=""))

# basic parameters
bw <- 32
sw <- 128
n_stream <- 50
threshold <- 0.9  # correlation threshold for outputs

args <- commandArgs(trailingOnly = TRUE)
process_args(args)

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

cat("start...\n")
#	start: _t  //start time for all the computation
#	start2: 0  //start time for steady stage computing

	gridhashTime <- 0  #the time need for Grid-Hash correlation report
	readpointer <- 1
	last <- 1
	count <- 0
	total <- 0
	h <- 0

  
# load input newdata.csv
newdata <- paste(WD,"newdata.csv",sep="")
dat <- read.csv(newdata, header=TRUE)
m <- length(dat$streamID) / (bw*n_stream) # number of bw from input file 

# m is for each bw update 
#m <- 4   # for testing
for (i in 1:m) {
  index <- 1
  
  # get new basic window data for all stream  
  newdat <- dat[readpointer:(i*bw*n_stream), ]
	
  for(j in 1:n_stream) {
  
			#get new bw for each stream
			sid <- paste("s",j,sep="")
      bwdat <- newdat[newdat$streamID==sid,]
			rw <- bwdat$value

      cat("xxxx: new basicwin: ", sid)
      
      if (readpointer == 1) {
        chopChunk[[j]] <- rw
      }
      else if (readpointer < (n_stream * sw)) {                               
        chopChunk[[j]] <- c(chopChunk[[j]], rw)  # append to existing basicwin
      }
      else {
        # override the oldest bw : do a shift update 
        chopChunk[[j]] <- c(chopChunk[[j]][(bw+1):sw], rw)
      }      
      
   		#computing digest
      statstream[[index]] <- batchDigestUpdate(statstream[[index]], rw, bw, sw)
      
			index <- index + 1
  } 

  # update readpointer (in real-time this is timestamp)
  readpointer <- i*bw*n_stream + 1


  # computing correlation
  index <- 1 
  
  if (h >= nb-1) {
    cat("\n start computing correlations...\n")    
  
    if (flagHash) {
    
      # init grid 
      gridc <- as.list(rep(0, P^R))
      
      for (index in 1:n_stream) {
        #computeCorr(statstream, index)
        #cat("stream ID=", index, " dftnorm=", statstream[[index]]$dftnorm, "\n")

        # report negative correlated pairs 
        g <- -statstream[[index]]$dftnorm[1:3] # R=3, use the first 3 coefficients  
        x <- Hash(g)
        
        a <- NeighborCells(x)
                
        for (i in 1:nrow(a)) {
          gidx <- sum(a[i,]*List)

          t <- gridc[[gidx]]
              
          if (length(t) <2) next 
           
          for (k in 1:length(t)) {
            j <- t[k]

            if (j <1) next  
              
            # compute the Dist 
       			corr2 <- -1+Dist(-statstream[[index]]$dftnorm, statstream[[j]]$dftnorm)
       			#cat("stream ID:", index, ":", j, " Dist=", corr2, " \n")
       			
      		  if (corr2 < -threshold) {
              accurate_corr <- cor(unlist(chopChunk[index]), unlist(chopChunk[j]))
                                    
              if (accurate_corr < -threshold) {
                initInd <- 1+(h-3)*bw
                endInd <- sw+(h-3)*bw                              
      
      					cat("stream ID:",index, "," ,j, ", Time:" ,initInd, "," ,endInd, ", Dist=" ,corr2, ", accurate_corr=" , accurate_corr, " \n")
      					
      					outreport[rdx,1] <- index
       					outreport[rdx,2] <- j
                outreport[rdx,3] <- initInd
       					outreport[rdx,4] <- endInd
       					outreport[rdx,5] <- corr2
       					outreport[rdx,6] <- accurate_corr
       					rdx <- rdx + 1

              } # end of accurate_corr 
            } # end of corr2 
          } # end of k 
        } # end of i
      
        # report positive correlated pairs 
        g <- statstream[[index]]$dftnorm[1:3] # R=3, use the first 3 coefficients  
        g <- -g 
        x <- Hash(g)
        
        a <- NeighborCells(x) 
        
        for (i in 1:nrow(a)) {
          gidx <- sum(a[i,]*List)

          t <- gridc[[gidx]]
              
          if (length(t) <2) next
         
          for (k in 1:(length(t))) {
            j <- t[k]

            if (j <1) next 
              
            # compute the Dist 
       			corr2 <- 1 - Dist(statstream[[index]]$dftnorm, statstream[[j]]$dftnorm)
       			#if (index == 13) cat("stream ID:", index, ":", j, " Dist=", corr2, " \n")
       			
      		  if (corr2 > threshold) {
              accurate_corr <- cor(unlist(chopChunk[index]), unlist(chopChunk[j]))
                                    
              if (accurate_corr > threshold) {
                initInd <- 1+(h-3)*bw
                endInd <- sw+(h-3)*bw                              
      
      					cat("stream ID:",index, "," ,j, ", Time:" ,initInd, "," ,endInd, ", Dist=" ,corr2, ", accurate_corr=" , accurate_corr, " \n")
      					
      					outreport[rdx,1] <- index
       					outreport[rdx,2] <- j
                outreport[rdx,3] <- initInd
       					outreport[rdx,4] <- endInd
       					outreport[rdx,5] <- corr2
       					outreport[rdx,6] <- accurate_corr
       					rdx <- rdx + 1

              } # end of accurate_corr 
            } # end of corr2
          } # end of k 
        } # end of i
        
        gridc[[sum(x*List)]] <- c(gridc[[sum(x*List)]], index)
  
      } # end of index n_stream
    }
  } # end of for m, or each bw update 
  
  h <- h+1  
}

# outfile 0: outs2
#streamID1	streamID2	BeginTimePoint	EndTimePoint	CorrCoef
names(outreport) <- c("streamID1", "streamID2", "BeginTimePoint", "EndTimePoint", "Dist", "CorrCoef")
outfile <- paste(WD,"outreport.csv",sep="")
write.csv(outreport, outfile)

# http://www.rforge.net/JRI/
cat("All DONE.  ", format(Sys.time(),format="%Y-%m-%d %H:%M:%S"), "\n")


