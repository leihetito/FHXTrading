library(zoo)
#library(xts)

# clear workspace variables
rm(list=ls(all=TRUE))

source("~/dev/FHX/fhx_model/tickcount_func.r")

sector <- "QQQ"
qdate_str <- "2012.06.25"
#qdate_str <- format(Sys.time(),format="%Y%m%d")
date_str <- gsub("\\.", "", qdate_str, ignore.case=T, fixed=F)

# kelly formula
total_capital <- 10000 	
initial_allocation <- 0.2
kelly <- initial_allocation

trade_period <- paste(date_str, " 09:30:00", "::", date_str, " 16:00:00", sep="")
trading_end_time <- paste(date_str, " 15:45:59", sep="")
#z_tick <- strptime("20/2/06 11:16:16.683", "%d/%m/%y %H:%M:%OS")
z_end <- z_tick <- strptime(trading_end_time, "%Y%m%d %H:%M:%S")

default_qty <- 100 # default trading size
order_columns <- c("Symbol","OrderType","Quantity","Price","BasicWinNum","Time")
order_out <-  paste("/export/data/",date_str,"/",sector,"_order_",date_str,".csv",sep="")
entry_order_list <- list() 

position_list <- list() # holding corrent open position
pnl_list <- list() # holding all pnl
pnl <- 0           # global pnl update 
report_flag <- FALSE
    
# test
sym_list <- c("DIA", #"AA",
  "AXP","BAC","BA","CAT","CSCO","CVX","DD","DIS","GE",
  "HD","HPQ","IBM","INTC","JNJ","JPM","KFT","KO","MCD","MMM",
  "MRK","MSFT","PFE","PG","TRV","T","UTX","VZ","WMT","XOM")
SYMBOLFILE <- paste("~/dev/FHX/fhx_java/conf/", tolower(sector), ".us.csv", sep="")
sym_list <- c(sector, as.character(read.csv(SYMBOLFILE)$Symbol))

# list holding each sym's tick data
sym_trading_list <- c()
sym_data <- list()

DATA_DIR <- paste("/export/data/",date_str,sep="")
# load simulation tick data 
load_tick_data(sym_list)

# the actual n_stream can be different from sym_list
n_stream <- length(sym_trading_list)
cat("tickcount stategy started with the following symbols: total=",n_stream,"\n")
print(sym_trading_list)

# create tick data matrix
tick_data <- do.call(cbind, sym_data)
row_idx <- input_data$CreateTime
colnames(tick_data) <- sym_trading_list
rownames(tick_data) <- row_idx
# create a xts object
#tick_xts <- as.xts(tick_data)
#X <- tick_xts[trade_period]  # 5 seconds time series streams

X <- tick_data
# if raw data is 1 second ticks, change it to every 5 seconds
#row_idx <- as.character(row_idx)
#sel_rows <- seq(1,length(row_idx),5)  # every 5 seconds
#T5 <- X[sel_rows,] # 5 second tick data
#X <- T5

# model set up
bw <- 24
sw <- 120

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

m <- floor(nrow(X) / bw)
m <- m - sw/bw  # trading cutoff 1 sliding window time before end of trading

# simulation testing  
for (i in 1:m) {

    bwnum <- i
    x_start <- (bwnum - 1) * bw + 1
    x_end   <- (bwnum * bw)
    #x_start <- x_end - bw
    bwdat <- X[x_start:x_end, ]
    
    # call this from Java 
    me <- process_bw_data_backtest(bwdat, bwnum)

}

# call this from Java after EOD
#gen_report_and_plot()
#
#source("C:/Projects/workspace/fhx_model/tickcount_func.r")
gen_plot()

order_list <- do.call(rbind, entry_order_list)
write.csv(order_list,paste("/export/data/",date_str,"/",sector,"_orderlist_",date_str,".csv",sep=""))

pnl <- do.call(rbind, pnl_list)
write.csv(pnl,paste("/export/data/",date_str,"/",sector,"_pnl_",date_str,".csv",sep=""))
cat("pnl: ", sum(pnl))
print(pnl)

# source("F:/DEV/fhxalgo/fhxmodel/statstream/tickcount.r")

cat(format(Sys.time(),format="%Y-%m-%d %H:%M:%S"), "\n")