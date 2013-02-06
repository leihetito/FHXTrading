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
