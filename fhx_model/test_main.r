# clear all exsiting workspace variables
rm(list=ls(all=TRUE))

date_str <- as.character(format(Sys.time(),format="%Y%m%d"))
REPORTDIR <- paste("/export/data/statstream/report/", date_str, sep="")
DATADIR <- paste("/export/data/", date_str, sep="")

if (!file.exists(REPORTDIR)){
	dir.create(file.path(REPORTDIR))
}

if (!file.exists(DATADIR)){
	dir.create(file.path(DATADIR))
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

