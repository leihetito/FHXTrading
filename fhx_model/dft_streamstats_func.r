
test <- function(bw,sw,n_stream,threshold)
{
  me <- c(bw,sw,n_stream,threshold)
  me 
}

# common functions
process_args <- function(args)   
{
  cat(args, "\n")
}

#Discret Fourier Transform in one line
dft <- function(x)
{
  #(+/x*COS),(+/x*SIN))*2/bw
  c(sum(x%*%COS),sum(x%*%SIN))*2/bw
}

dfthash <- function(x) 
{
	# x: the data
	# return the 1 to m coefficient components
	#:(+/REAL*x),(+/IMAGE*x)
	c(REAL%*%x, IMAGE%*%x)
}
	
batchDigestUpdate <- function(digest, x)
{
  # note: inlcuding the init bw, we have 5 bw in the sliding window
  digest$timepoint <- digest$timepoint + bw
  i <- digest$ptr1
  oldbw <- 1
  nb <- sw/bw 
  if (i != nb+1) {
    oldbw <- i + 1
  }
  
  # new basic window digest 
  basicwin <- list()
  basicwin$mean <- mean(x)
  basicwin$sum2 <- sum(x^2)
  #basicwin$dft <- c(x%*%COS,x%*%SIN)*2/bw
  basicwin$dfthash <- c(REAL%*%x, IMAGE%*%x)

  # add current bw to the list
	digest$bwwindows[[i]] <- basicwin			
		
	digest$sum <- digest$sum + bw*(digest$bwwindows[[i]]$mean - digest$bwwindows[[oldbw]]$mean)
  digest$sum2 <- digest$sum2 + digest$bwwindows[[i]]$sum2 - digest$bwwindows[[oldbw]]$sum2
			
  N <- sw
	if (digest$timepoint < sw) { N <- digest$timepoint - 1 }
			
  digest$mean <- digest$sum / N
  digest$mean2 <- digest$sum2 / N
  digest$std <- sqrt( digest$mean2 - digest$mean^2 )			
	             
  # compute digest.dfthash, dftnorm   
  digest$dfthash <- c( (digest$dfthash[1:6]*PHASE1 - digest$dfthash[7:12]*PHASE2),
    (digest$dfthash[1:6]*PHASE2 + digest$dfthash[7:12]*PHASE1) )  
  digest$dfthash <- digest$dfthash + digest$bwwindows[[i]]$dfthash - digest$bwwindows[[oldbw]]$dfthash
  
  digest$dftnorm <- digest$dfthash/(digest$std*sw)
      			
	digest$ptr1 <- oldbw
	#cat(" ... digest.ptr1=", digest$ptr1)		
  digest      
}

Hash <- function(x)   
{
  # for the grid structure
  unit <- sqrt(1-threshold)
  unit_r <- 1/unit
  whole <- 0.707  # sqrt(2)/2
  P <- floor(2*(1+ whole/unit))
  PP <- P/2
  R <- 3  #grid is P*P*...*P=P^R
  List <- P^(0:(R-1))
  
  floor(PP + x*unit_r)
}

Neighbor <- function(x)   
{
#x <- x[1]
  a <- x
  
  if (x > 0) {
    a <- c(x -1, x)
  }
  
  if (x < P-1) {
    a <- c(a, x+1)
  } 
  
  a
}

NeighborCells <- function(x)
{
  # in Kdb, this is one line: a:,/a,/:\:Neighbor[x[i]]
  a <- c()
  
  xx <- Neighbor(x[1])
  yy <- Neighbor(x[2])
  zz <- Neighbor(x[3])

  R <- 3
  # this is probably not that efficient, find a better impl        
  for (r1 in 1:R) {
    for (r2 in 1:R) {
      for (r3 in 1:R) {
        a <- c(a, c(xx[r1], yy[r2], zz[r3]))
      }
    }    
  }

  a <- matrix(a, nrow=27, ncol=3, byrow = TRUE)
  #cat("xxxx a=", length(a), " \n") 
  a
}

# actually dist^2
Dist <- function(x,y)
{
  sum((x-y)^2)
} 	

# update each stream's digest for each new basic window
UpdateDigest <- function(statstream, chopChunk, newdat)
{
  index <- 1
  
  for(j in 1:n_stream) {
    
    #get new bw for each stream
    sid <- paste("s",j,sep="")
    bwdat <- newdat[newdat$streamID==sid,]
    rw <- bwdat$value
  
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
    statstream[[index]] <- batchDigestUpdate(statstream[[index]], rw)
        
		index <- index + 1
  } # end of n_stream 

  # return data    
  retList <- list()
  retList$chopChunk <- chopChunk
  retList$statstream <- statstream
    
  retList 
}

# this is called for each stream for each new basic window
ComputeCorrelation <- function(index, corrtype, gridc, bwnum)
{
  # output report 
  outreport <- data.frame()

  # current sliding window datapoint range 
  initInd <- 1+(bwnum-sw/bw)*bw
  endInd <- sw+(bwnum-sw/bw)*bw 
            
  # 1. report negative correlated pairs 
  if (corrtype == "negative") {
    g <- -statstream[[index]]$dftnorm[1:3] # R=3, use the first 3 coefficients  
  }
          
  if (corrtype == "positive") {
    g <- statstream[[index]]$dftnorm[1:3] # R=3, use the first 3 coefficients  
    g <- -g       
  }
          
  x <- Hash(g)
          
  a <- NeighborCells(x)
                  
  for (i in 1:nrow(a)) {
    gidx <- sum(a[i,]*List)
  
    t <- gridc[[gidx]]
                
    if (length(t) <2) 
      next 
             
    for (k in 1:length(t)) {
      j <- t[k]
  
      if (j <1) 
        next  
                
      # compute the Dist 
      if (corrtype == "negative") {
 			  corr2 <- -1+Dist(-statstream[[index]]$dftnorm, statstream[[j]]$dftnorm)
 			  #cat("stream ID:", index, ":", j, " Dist=", corr2, " \n")
         			  
  		  if (corr2 < -threshold) {
          accurate_corr <- cor(unlist(chopChunk[index]), unlist(chopChunk[j]))
                                      
          if (accurate_corr < -threshold) {
          
            logReport <- LogCorrReport(index, j, initInd, endInd, corr2, accurate_corr)
            outreport <- rbind(outreport, logReport)
  
          } # end of accurate_corr 
        } # end of corr2 
      } # end of negative

      if (corrtype == "positive") {
 			  corr2 <- 1 - Dist(statstream[[index]]$dftnorm, statstream[[j]]$dftnorm)
 			  #cat("stream ID:", index, ":", j, " Dist=", corr2, " \n")
         			  
  		  if (corr2 > threshold) {
          accurate_corr <- cor(unlist(chopChunk[index]), unlist(chopChunk[j]))
                                      
          if (accurate_corr > threshold) {
            
            logReport <- LogCorrReport(index, j, initInd, endInd, corr2, accurate_corr)
            outreport <- rbind(outreport, logReport)
                        
          } # end of accurate_corr 
        } # end of > threshold 
      } # end of positive
         			
    } # end of k 
  } # end of i

  gridc[[sum(x*List)]] <- c(gridc[[sum(x*List)]], index)
      
  retList <- list()
  retList$x <- x
  retList$corrReport <- outreport
      
  retList
}

LogCorrReport <- function(streamID1, streamID2, initInd, endInd, corr2, accurate_corr)
{
  #cat("stream ID:",streamID1, "," ,streamID2, ", Time:" ,initInd, "," ,endInd, ", Dist=" ,corr2, ", accurate_corr=" , accurate_corr, " \n")
  
  logreport <- data.frame()
  rdx <- 1      					
  logreport[rdx,1] <- streamID1
  logreport[rdx,2] <- streamID2
  logreport[rdx,3] <- initInd
  logreport[rdx,4] <- endInd
  logreport[rdx,5] <- corr2
  logreport[rdx,6] <- accurate_corr
  logreport[rdx,7] <- chopChunk[[streamID1]][1]
  logreport[rdx,8] <- chopChunk[[streamID1]][sw]
  logreport[rdx,9] <- chopChunk[[streamID2]][1]
  logreport[rdx,10] <- chopChunk[[streamID2]][sw]
  #logreport[rdx,11] <- paste(streamID1,streamID2,sep="")
  logreport[rdx,11] <- paste(streamID1,"-",streamID2,sep="")
    
  logreport 
}

CorrlationReport <- function(h)
{
  # after digest update
  outreport <- data.frame()
  
  # init grid 
  gridc <- as.list(rep(0, P^R))
        
  #for (index in 1:n_stream) {
  # note streamID1 is the index stream, i.e. SPY
  # other streams are constituents.
  for (index in 1:n_stream) {
        
    # negatively correlated streams 
    negList <- ComputeCorrelation(index, "negative", gridc, h)
    x <- negList$x
    #gridc[[sum(x*List)]] <- c(gridc[[sum(x*List)]], index)
                  
    # negatively correlated streams 
    posList <- ComputeCorrelation(index, "positive", gridc, h)
    x <- posList$x           
    # update the grid
    gridc[[sum(x*List)]] <- c(gridc[[sum(x*List)]], index)
  
    outreport <- rbind(outreport, negList$corrReport, posList$corrReport)  
          
  } # end of n_stream

  outreport   
}

GetCorrelatedDataframeWithIndex <- function(index, corrReport)
{
  # 1. negative correlated
  negCorrStreams <- corrReport[corrReport$streamID1==index | corrReport$streamID2==index & corrReport$CorrCoef < -threshold,]
  # 2. positive correlated 
  posCorrStreams <- corrReport[corrReport$streamID1==index | corrReport$streamID2==index & corrReport$CorrCoef > threshold,]

  retdata <- rbind(negCorrStreams, posCorrStreams)
}

GetCorrelatedStreamsWithIndex <- function(index, corr_report)
{
  retList <- list()
  #index <- 50
  # 1. negative correlated
  negCorrStreams <- corr_report[corr_report$streamID1==index | corr_report$streamID2==index & corr_report$CorrCoef < -threshold,]
  retList$negCorrStreams <- unique(c(unique(negCorrStreams$streamID1), unique(negCorrStreams$streamID2)))
  
  # 2. positive correlated 
  posCorrStreams <- corr_report[corr_report$streamID1==index | corr_report$streamID2==index & corr_report$CorrCoef > threshold,]
  retList$posCorrStreams <- unique(c(unique(posCorrStreams$streamID1), unique(posCorrStreams$streamID2)))
  
  retList 
}


comparelists <- function(dx,dy, ...) {
        # Given two vectors, report on there similarity and difference
        # Often used if comparing genelists after filtering

        facChar<-function(x) {
            if(is.factor(x)) x<-as.character(x)
            return(x)
            }

        dx<-facChar(dx)
        dy<-facChar(dy)

        if(!is.vector(dx)) 
             stop("the first vector is not a vector")

        if(!is.vector(dy)) 
             stop("the second vector is not a vector")
	
        
	inter<-intersect(dx, dy)
	setd <- setdiff(dx, dy)

	xiny<-length(dx[dx%in%dy])
	yinx<-length(dx[dy%in%dx])

	
   compres<-list("intersect"=inter, "Set.Diff"=setd, "XinY"=xiny, "YinX"=yinx, "Length.X"=length(dx), 
        "Length.Y"=length(dy))
        class(compres)="comparelists"
	return(compres)
}

print.comparelists <- function(x, ...)  {
        if (!inherits(x, "comparelists")) 
                  stop("to be used with 'comp.res' object")


        cat("Items in X:", x$Length.X, "\n")
        cat("Items in Y:", x$Length.Y, "\n\n")

	      cat("No of vecX in vecY", x$XinY, "\n")
        cat("No of vecY in vecX", x$YinX, "\n\n")

      	cat("Intersection of sets is", length(x$intersect), "\n")
        cat("Difference in sets is", length(x$Set.Diff), "\n")        
}


