library(hash) 

date_str <- as.character(format(Sys.time(),format="%Y%m%d"))
REPORTDIR <- paste("/export/data/statstream/report/", date_str, sep="")

if (!file.exists(REPORTDIR)){
	dir.create(file.path(REPORTDIR))
}

# start time of the program
startTime <- format(Sys.time(),format="%Y-%m-%d %H:%M:%S")
##
## Global variables 
##
corr_report <- data.frame()  # correlation report
rdx <- 1 # data.frame index

streamData <<- data.frame()

statstream <- list() # digest /all the digests of the data streams, using rotating windows

#chopChunk <- matrix(data=0, nrow=n_stream, ncol=sw) # all data points in the sliding window
chopChunk <- list()  # raw data for each stream to compute real correlation of sw

corr_pairs <<- list() 		# list of all the correlation stats calculated on 
# each bw. keys are the bw number, values are data frames

open_positions <<- data.frame() 		# open positions at any given moment
# added when trading signal is generated, remove when closing position
# TODO: this can be linked with actual ors trade executions

all_trade_signals <<- data.frame()	# data frame to hold all of todays trading signal

sym_data <- list()
tick_data <<- data.frame()

# set up
bw <- 24
sw <- 96
holding_time <- sw/bw  # expressed in # of basic windows
threshold <- 0.8  # correlation threshold for outputs

bwdat <- data.frame()
prev_value_list <- list()

trade_period <- paste(date_str, " 09:30:00", "::", date_str, " 16:00:00", sep="")
trading_end_time <- paste(date_str, " 15:45:00", sep="")

index <- "DIA"
SYMBOLFILE <- paste("/export/FHX/fhx_java/conf/", tolower(index), ".us.csv", sep="")

symbol_data <- read.csv(SYMBOLFILE, header=TRUE)
sym_list <- as.character(symbol_data$Symbol)
sym_list <- c(index, sym_list)

#ym_list <- c("EUR", "GBP", "JPY")
n_stream <- length(sym_list)
sym_index <- sym_list[1] # to be used everywhere

order_columns <- c("Symbol","OrderType","Quantity","Price","BasicWinNum","Time","PnL","SignalType")
order_out <-  paste(REPORTDIR,"/",sym_index,"_order_",date_str,".csv",sep="")
position_columns <- c("Symbol","Quantity","Price","IdxPx","IdxQty","BasicWinNum")
position_out <- paste(REPORTDIR,"/",sym_index,"_position_",date_str,".csv",sep="")

corr_matrix <- as.data.frame(matrix(ncol = length(sym_list)+1))
corr_matrix[1,1] <- 0
cor_idx <- 0
vol_matrix  <- as.data.frame(matrix(ncol = length(sym_list)+1))
vol_matrix[1,1] <- 0

order_list <<- data.frame() # sym, shares, price, type(open/close), bwnum
ord_idx <- 0
position_hist <- as.data.frame(matrix(ncol = length(position_columns)))  # sym, qty, px, index_px, index_qty
accu_order_list <- data.frame(matrix(ncol = length(order_columns)))
position_list <- list() # sym, qty, px, index_px, index_qty

bwnum <- 0
swnum <- 0
timepointer <- c() # use timestamp as data frame rownames

add_orders <- function(order_list, sym_y, order_type, sym_y_qty, sym_px_list, bwnum, curTime) 
{
	
	# sym position
	ord_idx <- length(order_list) + 1
	order_list[ord_idx, 1] <- sym_y # sym
	order_list[ord_idx, 2] <- order_type
	order_list[ord_idx, 3] <- - sym_y_qty                              
	order_list[ord_idx, 4] <- sym_px_list[sw]
	order_list[ord_idx, 5] <- bwnum
	order_list[ord_idx, 6] <- curTime
	order_list[ord_idx, 7] <- 0  # for new orders
	
	if (order_type == "CLOSE") {
		order_list[ord_idx, 7] <- -0.99  # closing a position
	}
	
# index position
#ord_idx <- ord_idx + 1
#order_list[ord_idx, 1] <- sym_index # sym
#order_list[ord_idx, 2] <- "CLOSE" 
#order_list[ord_idx, 3] <- -sym_y_pos$index_qty
#order_list[ord_idx, 4] <- index_px[sw]
#order_list[ord_idx, 5] <- bwnum
#order_list[ord_idx, 6] <- as.character(end(bwdat))
#order_list[ord_idx, 7] <- index_pnl
	
	order_list 
}

add_new_order <- function(sym_y, order_type, sym_y_qty, sym_px_list, bwnum, curTime) 
{
	# Symbol OrderType Quantity  Price BasicWinNum  Time  PnL
	new_order <- list()
	# sym position
	
	new_order$Symbol <- sym_y # sym
	new_order$OrderType <- order_type
	new_order$Quantity <- - sym_y_qty                              
	new_order$Price <- sym_px_list[sw]
	new_order$BasicWinNum <- bwnum
	new_order$Time <- curTime
	new_order$PnL <- 0  # for new orders
	
	if (order_type == "CLOSE") {
		new_order$PnL <- -0.99  # closing a position
	}
	
	new_order 
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

close_position <- function(dataPack, chopChunk, sym_y, sym_index,bwnum)
{
	# close the position: compute pnl
	cat("$$$$ CLOSING position for ", sym_y, " \n")
	
	position_list <- dataPack[[1]] 
	position_hist <- dataPack[[2]] 
	order_list <- dataPack[[3]] 
	
	print(position_list[[sym_y]])
	
	index <- sym_list[[1]]
	sym_y_pos <- position_list[[sym_y]]  
	index_pos <- position_list[[index]]
	index_open_px <- as.numeric(sym_y_pos$index_px)  # fixed
	index_px <- chopChunk[[1]]
	index_close_px <- index_px[sw]
	
	sym_open_px <- as.numeric(sym_y_pos$px)
	sym_id <- which(sym_list == sym_y)
	sym_close_px <- chopChunk[[sym_id]][sw]
	
	# compute pnl
	sym_pnl <-  (sym_close_px - sym_open_px) * sym_y_pos$qty 
	index_pnl <- (index_close_px - index_open_px) * sym_y_pos$index_qty
	
	# sym position
	ord_idx <- nrow(order_list) + 1
	order_list[ord_idx, 1] <- sym_y # sym
	if(sym_y_pos$qty > 0) {
		order_list[ord_idx, 2] <- "sell"
	}
	else {
		order_list[ord_idx, 2] <- "buy"
	}

	order_list[ord_idx, 3] <- abs(sym_y_pos$qty)                              
	order_list[ord_idx, 4] <- sym_close_px
	order_list[ord_idx, 5] <- bwnum
	order_list[ord_idx, 6] <- Sys.time()
	order_list[ord_idx, 7] <- sym_pnl
	order_list[ord_idx, 8] <- "CLOSE"
	
	cat("generating closing order ",sym_y,"\n")
	print(order_list[ord_idx,])
	
	# index position
	ord_idx <- ord_idx + 1
	order_list[ord_idx, 1] <- index
	if(sym_y_pos$qty > 0) {
		order_list[ord_idx, 2] <- "buy"
	}
	else {
		order_list[ord_idx, 2] <- "sell"
	}

	order_list[ord_idx, 3] <- abs(sym_y_pos$index_qty)
	order_list[ord_idx, 4] <- index_px[sw]
	order_list[ord_idx, 5] <- bwnum
	order_list[ord_idx, 6] <- Sys.time()
	order_list[ord_idx, 7] <- index_pnl
	order_list[ord_idx, 8] <- "CLOSE"
	
	cat("generating closing order ",index,"\n")
	print(order_list[ord_idx,])
	
	position_list[[sym_y]] <- NULL # remove the position
	
	# adjust symbol position
	pos_idx <- nrow(position_hist) + 1
	position_hist[pos_idx, 1] <- sym_y
	position_hist[pos_idx, 2] <- 0
	position_hist[pos_idx, 6] <- bwnum
	
	# adjust index position
	pos_idx <- nrow(position_hist) + 1
	position_hist[pos_idx, 1] <- index
	if(index_pos$qty > 0) {
		position_hist[pos_idx, 2] <- position_list[[index]]$qty <- index_pos$qty - sym_y_pos$index_qty
	}
	else {
		position_hist[pos_idx, 2] <- position_list[[index]]$qty <- index_pos$qty + sym_y_pos$index_qty
	}
	position_hist[pos_idx, 6] <- bwnum
	
	dataPack[[1]] <- position_list
	dataPack[[2]] <- position_hist
	dataPack[[3]] <- order_list
	
	dataPack
}

handle_position_closing <- function(position_list,position_hist,pos_signal_list, bwnum, chopChunk)
{
	cat("Check if any position needs to be closed, ",length(position_list),"\n")
	print(position_list)
	
	dataPack <- list()
	
	if (length(position_list) > 0) {
		close_signals <- names(pos_signal_list)          
		index_close_qty <- 0 # aggregate all shares for index so we don't send mutitple orders
		
		if(length(pos_signal_list)) {
			cat("closing signals\n")
			print(names(pos_signal_list))
		}
		
		for (y in 1:length(close_signals)) {
			# close all positions that are highly correlated with index again
			# note: use order_list to find the px of OPEN position
			sym_y <- close_signals[y]
			sym_y_idx <- which(names(position_list) == sym_y)
			
			if (length(sym_y_idx) > 0) {
				# this is silly 
				dataPack[[1]] <- position_list
				dataPack[[2]] <- position_hist
				dataPack[[3]] <- order_list
				
				dataPack <- close_position(dataPack, chopChunk, sym_y, sym_y_idx,bwnum)
				
				position_list <- dataPack[[1]]
				position_hist <- dataPack[[2]] 
				order_list <- dataPack[[3]] 
			} 
		} 
		
		# if holding_time has expires, close the position even if the correlation has not come back
		for(sym in names(position_list)) {
			# index position should always be adjusted based on a non-index symbol position
			if(sym == sym_index)
				next;
			
			cat("determining to close position, ",bwnum,"-",position_list[[sym]]$bwNum,"\n");
			if((bwnum - position_list[[sym]]$bwNum) >= holding_time) {
				dataPack[[1]] <- position_list
				dataPack[[2]] <- position_hist
				dataPack[[3]] <- order_list
				dataPack <- close_position(dataPack, chopChunk, sym, sym_y_idx,bwnum)
			}
		}
		
	} # end of if close position
	
	dataPack
}

process_basic_window3 <- function(newdat) 
{		
	tick_data <- newdat
	colnames(tick_data) <- c("timeStamp", "bwNum", sym_list)

	cat("\n++++++++++++NEW BASIC WINDOW BEGIN+++++++++++++++++++++++++++++++\n")
	bwnum <- tick_data$bwNum[1]+1
	
	# preserve prior run values
	if(bwnum > 1) {
		chopChunk <- prev_value_list[[2]]
		corr_matrix <- prev_value_list[[3]]
		vol_matrix <- prev_value_list[[4]]
		position_hist <- prev_value_list[[5]]
		accu_order_list <- prev_value_list[[6]]
		position_list <- prev_value_list[[7]]
	
		cor_idx <- nrow(corr_matrix) 
		pos_idx <- nrow(position_hist)
	}

	order_list <- data.frame()
	ord_idx <- 0
	
	x_start <- 1
	x_end   <- bw
	cat("x_start: ",x_start, " ")
	cat("x_end  : ",x_end, " \n")
	
	bwdat <- tick_data[x_start:x_end, ]
	#print(bwdat)
	cat("processing bwnum...",bwnum, " time: ",bwdat$timeStamp[1], " \n")
	
	#cat("existing chopchunk\n")
	#print(chopChunk)
	# Note: bwdat is now column based
	chopChunk <- UpdateDigest(chopChunk, bwdat, bwnum)
	cat("done updating chopChunk... \n")
	#print(chopChunk)
	
	# computing correlation    
	if (bwnum >= sw/bw) {    
		cat("basic window num ", bwnum, " start computing correlations \n")
		
		pos_signal_list <- list()
		neg_signal_list <- list()
		
		index_px <- chopChunk[[1]] # index is always the first one
		cor_idx <- cor_idx + 1
		
		if (sd(index_px) == 0) {
			# need to do nothing as index prices don't change
			cat("xxx Warning: index_px for ", sym_index, " didn't change. All corr set to 0. \n ")
			corr_matrix[cor_idx, ] <- 0  # this may not work
			vol_matrix[cor_idx, ] <- 0  # this may not work
			# do nothing until the next basic window update
			next 
		}
		else {
			corr_matrix[cor_idx, 1] <- 1 		#cor(ETF,ETF)=1
			vol_matrix[cor_idx, 1] <- round(sd(index_px), digits=4)
			
			# now compute the correlations of each symbol with ETF 
			for (j in 2:length(sym_list)) {
				sym_j <- sym_list[j]
				sym_px_list <- chopChunk[[j]]
				
				if (sd(sym_px_list) == 0) {
					cat("xxxx got a constant price for ", sym_j)
					cat(" bwnum=", bwnum, "\n")
					
					corr_matrix[cor_idx, j] <- 0  # prices don't change over a sliding window, ignore
				}
				else {
					sym_cor_j <- cor(chopChunk[[1]], chopChunk[[j]])        
					
					if (sym_cor_j > threshold) {
						pos_signal_list[[sym_j]] <- sym_cor_j
					}
					
					if (sym_cor_j < -threshold) {
						neg_signal_list[[sym_j]] <- sym_cor_j            
					}
					
					#cat("correlation(1&",j,") = ",sym_cor_j,"\n")
					corr_matrix[cor_idx, j] <- round(sym_cor_j, digits=4)            
				}
				
				# log each symbol's volatility
				vol_matrix[cor_idx, j] <- sd(sym_px_list)  
				
			} # end of for(j)
			corr_matrix[cor_idx, j+1] <- bwnum	#timepoint
			vol_matrix[cor_idx, j+1] <- bwnum	#timepoint
		} # end of if(sd_index_px)==0)
		
		cat("pos_signal_list\n")
		print(names(pos_signal_list));
		
		#
		# properly close the open positions from previous windows
		# this should go to Java code
		#
		dataPack <- handle_position_closing(position_list,position_hist,pos_signal_list,bwnum,chopChunk)
		if(length(dataPack) >= 3) {
			position_list <- dataPack[[1]]
			position_hist <- dataPack[[2]] 
			order_list <- dataPack[[3]]
		}
		
		#
		# generate open signals
		#
		# index return: used by every neg_signal_list to open a position 
		index_ret <- log(index_px[sw]/index_px[1])
		
		# go through the neg_signal_list:  names(pos_signal_list[pos_signal_list<0])          
		if (length(neg_signal_list) >0 ) {
			open_signals <- names(neg_signal_list)
			index_open_qty <- 0
			
			for (x in 1:length(open_signals)) {
				sym_x <- open_signals[x]
				
				sym_x_pos <- position_list[[sym_x]]
				if (length(sym_x_pos) !=0)
					next # skip it as position has been held for sym_x 
		
				# get sym_id from sym_list
				sym_id <- which(sym_list == sym_x)
				
				if (length(sym_id)) {
					sym_px <- chopChunk[[sym_id]]  # raw price data 

					# log return in the current sliding window
					sym_ret <- log(sym_px[sw]/sym_px[1])  
					
					cat("$$$$ OPENING position for ", sym_x, " \n") 
					# now create the order based on index and sym returns
					# rule is simple: 
					# if (ret_index > sym_ret)  short index, long sym
					# else  long index, short sym
					
					cat(sym_x," return=",sym_ret,", idx_ret=",index_ret,"\n")
					
					# position_list is the real-time open positions
			        # position_hist is the cumulative positions changes so we can save them to file
					if ( sym_ret < index_ret ) {
						pos_idx <- nrow(position_hist) + 1
						position_hist[pos_idx, 1] <- sym_x
						position_list[[sym_x]]$qty <- position_hist[pos_idx, 2] <- 100 # long
						position_list[[sym_x]]$px <- position_hist[pos_idx, 3] <- sym_px[sw]
						position_list[[sym_x]]$index_px <- position_hist[pos_idx, 4] <- index_px[sw]
						
						index_qty <- floor(-100 * sym_px[sw]/index_px[sw])
						position_list[[sym_x]]$index_qty <- position_hist[pos_idx, 5] <- index_qty
						position_list[[sym_x]]$bwNum <- position_hist[pos_idx, 6] <- bwnum
						
						# notice: we want to offset the quantity for index symbol, $$$
						index_open_qty <- index_open_qty + index_qty
						
						# create order
						ord_idx <- nrow(order_list) + 1
						order_list[ord_idx, 1] <- sym_x
						order_list[ord_idx, 2] <- "buy" 
						order_list[ord_idx, 3] <- 100  # long
						order_list[ord_idx, 4] <- sym_px[sw]
						order_list[ord_idx, 5] <- bwnum
						order_list[ord_idx, 6] <- bwdat[nrow(bwdat),1]       
						order_list[ord_idx, 7] <- 0 	
						order_list[ord_idx, 8] <- "OPEN"
					}
					else {
						pos_idx <- nrow(position_hist) + 1
						
						position_hist[pos_idx, 1] <- sym_x
						position_list[[sym_x]]$qty <- position_hist[pos_idx, 2] <- -100 # short
						position_list[[sym_x]]$px <- position_hist[pos_idx, 3] <- sym_px[sw]
						position_list[[sym_x]]$index_px <- position_hist[pos_idx, 4] <- index_px[sw]
						
						index_qty <- floor(100 * sym_px[sw]/index_px[sw])
						position_list[[sym_x]]$index_qty <- position_hist[pos_idx, 5] <- index_qty
						position_list[[sym_x]]$bwNum <- position_hist[pos_idx, 6] <- bwnum

						# notice: we want to offset the quantity for index symbol, $$$
						index_open_qty <- index_open_qty + index_qty
	
						ord_idx <- nrow(order_list) + 1
						order_list[ord_idx, 1] <- sym_x
						order_list[ord_idx, 2] <- "sellshort" 
						order_list[ord_idx, 3] <- 100  # short sale
						order_list[ord_idx, 4] <- sym_px[sw]
						order_list[ord_idx, 5] <- bwnum
						order_list[ord_idx, 6] <- bwdat[nrow(bwdat),1]            
						order_list[ord_idx, 7] <- 0
						order_list[ord_idx, 8] <- "OPEN"
					}                 
				}
			} # end of for (x)
			
			# set index_open_qty
			if (index_open_qty != 0) {
				cat("$$$ open position_hist on index is: ", index_open_qty, "\n")

				pos_idx <- nrow(position_hist) + 1
				position_hist[pos_idx, 1] <- sym_index
				position_list[[sym_index]]$qty <- position_hist[pos_idx, 2] <- index_open_qty
				position_list[[sym_index]]$px <- position_hist[pos_idx, 3] <- index_px[sw]
				position_hist[pos_idx, 4] <- index_open_qty
				position_hist[pos_idx, 5] <- index_px[sw]
				position_list[[sym_index]]$bwNum <- position_hist[pos_idx, 6] <- bwnum
				
				ord_idx <- nrow(order_list) + 1
				order_list[ord_idx, 1] <- sym_index # sym
				
				if(index_open_qty > 0) { 
					order_list[ord_idx, 2] <- "buy" 
					order_list[ord_idx, 3] <- index_open_qty
				}
				else {
					order_list[ord_idx, 2] <- "sellshort" 
					order_list[ord_idx, 3] <- abs(index_open_qty)
				}
				order_list[ord_idx, 4] <- index_px[sw]
				order_list[ord_idx, 5] <- bwnum
				order_list[ord_idx, 6] <- bwdat[nrow(bwdat),1]            
				order_list[ord_idx, 7] <- 0
				order_list[ord_idx, 8] <- "OPEN"
				
				#new_order <- add_new_order(sym_index, "Open", index_open_qty, index_px, bwnum, bwdat[nrow(bwdat),1] ) 
				#order_list[ord_idx,] <- new_order
				
			} # end if index_position 
			
		} # end of if (length(neg_signal_list)		
	} #end of if (bwnum >= sw/bw)
	
	
	cat("printing position list\n")
	print(position_list)
	
	cat("------------NEW BASIC WINDOW END---------------------------------\n")

	colnames(corr_matrix) <- c(sym_list, "bwnum")
	corr_matrix[is.na(corr_matrix)] <- 0
	corr_out <- paste(REPORTDIR,"/",sym_list[1],"_corr_matrix_",date_str,".csv",sep="")
	cat("writing corr_matrix to ", corr_out, " \n")
	write.csv(corr_matrix, corr_out)
	
	colnames(vol_matrix) <- c(sym_list, "bwnum")
	vol_matrix[is.na(vol_matrix)] <- 0
	vol_out <- paste(REPORTDIR,"/",sym_list[1],"_vol_matrix_",date_str,".csv",sep="")
	cat("writing vol_matrix to ", vol_out, " \n")
	write.csv(vol_matrix, vol_out)
	
	# save the raw price data as well 
	#price_out <-  paste(WD,"/DIA_price_matrix_",date_str,".csv",sep="") 
	#cat("writing price_matrix to ", price_out, " \n")
	#price_matrix <- as.data.frame(X)
	#rownames(price_matrix) <- as.character(index(X))
	#write.csv(price_matrix, price_out, row.names = TRUE)
	
	if(length(order_list) > 0) { 
		colnames(accu_order_list) <- order_columns
		colnames(order_list) <- order_columns
		accu_order_list <- rbind(accu_order_list, order_list)
		
		cat("writing order_list to ", order_out, " \n")
		write.csv(accu_order_list, order_out)  
	}
	if(length(position_hist) > 0) { 
		colnames(position_hist) <- position_columns
		cat("writing position_hist to ", position_out, " \n")
		write.csv(position_hist, position_out)  
	}

	# return 
	retVal <- list()
	retVal[[1]] <- order_list
	retVal[[2]] <- chopChunk
	retVal[[3]] <- corr_matrix
	retVal[[4]] <- vol_matrix
	retVal[[5]] <- position_hist
	retVal[[6]] <- accu_order_list
	retVal[[7]] <- position_list
	
	retVal
}

process_basic_window4 <- function(newdat, bwnum) 
{		
	tick_data <- newdat
	
	colnames(tick_data) <- c("timeStamp", "bwNum", sym_list)

	cat("\n++++++++++++NEW BASIC WINDOW BEGIN+++++++++++++++++++++++++++++++\n")
	cat("bwnum: ", bwnum, "\n");

  tick_out <- paste(REPORTDIR,"/",index,"_bw_ticks_",bwnum,".csv",sep="")
	cat("writing bw tick data to ", tick_out, " \n")
	write.csv(tick_data, tick_out)

	# return 
	retVal <- list()
	retVal[[1]] <- order_list
	retVal[[2]] <- chopChunk
	retVal[[3]] <- corr_matrix
	retVal[[4]] <- vol_matrix
	retVal[[5]] <- position_hist
	retVal[[6]] <- accu_order_list
	retVal[[7]] <- position_list
	
	retVal
  	
}

