
test <- function() {
  bw_tick <- streamData
  bwnum <<- as.character(bw_tick$winNum[1]) # note this changes global var bwnum

  tick_out <- paste(DATADIR,"/",index,"_ticks_bw_",bwnum,".csv",sep="")
  write.csv(bw_tick, tick_out)

  retList <- list()

  retList$rnorm <- rnorm(10)
  retList$bw <- bw
  retList$sw <- sw
  retList$streamData <- streamData
  retList$bwnum <- bwnum


  retList
}

# update each stream's digest for each new basic window
# Note: here the stream data are column based, i.e. AA, IBM, ...etc.
UpdateDigest <- function(chopChunk, bw_tick, bw_num)
{
	for(j in 1:length(sym_list)) {
		bwdat <- bw_tick[,j+2]
		rw <- as.numeric(bwdat)
		
		if (bw_num == 1) {
			chopChunk[[j]] <- rw
		}
		else if (bw_num <= (sw/bw)) {
			chopChunk[[j]] <- c(chopChunk[[j]], rw)  # append to existing basicwin
		}
		else {
			# override the oldest bw : do a shift update: should use a shift function
			chopChunk[[j]] <- c(chopChunk[[j]][(bw+1):sw], rw)
		}
		
	} # end of n_stream
	
	chopChunk
}

process_bw_ticks <- function(newdat, bwnum) 
{		
	tick_data <- newdat
	
	colnames(tick_data) <- c("timeStamp", "bwNum", sym_list)

	cat("\n++++++++++++NEW BASIC WINDOW BEGIN+++++++++++++++++++++++++++++++\n")
	cat("bwnum: ", bwnum, "\n");

  tick_out <- paste(REPORTDIR,"/",index,"_ticks_bw_",bwnum,".csv",sep="")
	cat("writing bw tick data to ", tick_out, " \n")
	write.csv(tick_data, tick_out)

  cat("\n++++++++++++NEW BASIC WINDOW END+++++++++++++++++++++++++++++++++\n")
  
	# return 
  tick_data
  	
}
