library(zoo)

# clear workspace variables
rm(list=ls(all=TRUE))

#source("/export/FHX/fhx_model/tickcount_func.r")

sector <- "DIA"
date_str <- format(Sys.time(),format="%Y%m%d")

trade_period <- paste(date_str, " 09:30:00", "::", date_str, " 16:00:00", sep="")
trading_end_time <- paste(date_str, " 15:45:59", sep="")
z_end <- z_tick <- strptime(trading_end_time, "%Y%m%d %H:%M:%S")

total_capital <- 10000 	
order_columns <- c("Symbol","OrderType","Quantity","Price","BasicWinNum","Time")
order_out <-  paste("/export/data/",date_str,"/",sector,"_order_",date_str,".csv",sep="")
entry_order_list <- list() 

position_list <- list() # holding corrent open position
pnl_list <- list() # holding all pnl
pnl <- 0           # global pnl update 

SYMBOLFILE <- paste("/export/FHX/fhx_java/conf/", tolower(sector), ".us.csv", sep="")
sym_list <- c(sector, as.character(read.csv(SYMBOLFILE)$Symbol))

# list holding each sym's tick data
sym_trading_list <- sym_list

# the actual n_stream can be different from sym_list
n_stream <- length(sym_trading_list)
#cat("tickcount stategy started with the following symbols: total=",n_stream,"\n")
#print(sym_trading_list)


# model set up
bw <- 24
sw <- 120

initial_allocation <- 0.2
kelly <- initial_allocation

bwnum <- 0
chopChunk <- list()  # raw data in a sw
swStats <- list()    # stats in a sw
signalList <- list() # bullish/bearish signals 
order_list <- list() # holds order report at EOD
posList <- list()    # hold all posList at EOD 

tick_stats <- data.frame(nrow=0, ncol=n_stream)
ts_idx <- 1
idx_time <- c()

index_px_list <- c()
bw_score_list <- c()
sw_score_list <- c(rep(NA,sw/bw-1))
index_bwret_list <- c()
index_swret_list <- c(rep(NA,sw/bw-1))

report_flag <- FALSE
#cat(format(Sys.time(),format="%Y-%m-%d %H:%M:%S"), "\n")

