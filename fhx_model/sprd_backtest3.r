library(zoo)
library(tseries)

# clear workspace variables
rm(list=ls(all=TRUE))

HOME <- Sys.getenv("HOME")
#HOME <- "F:/DEV/fhxalgo"
WD <- paste(HOME,"/fhxmodel/statstream",sep="")

# the date to do the back test
date_str <- '20120131' # Dev test date

# use command line parms
if (length(args)>1) {
  args <- commandArgs(trailingOnly = TRUE)
  print(args)

  date_str <- args[1]
  WD <- args[2]
}

# setwd so this can be used by functions  
#setwd(WD)

# input, output directories 
DATADIR <- paste(WD,"/data",sep="")
INPUTDATADIR <- paste(DATADIR,"/input",sep="")
OUTPUTDATADIR <- paste(DATADIR,"/output",sep="")
SYMDATADIR <- paste(DATADIR,"/symbol",sep="")

# start time of the program
startTime <- format(Sys.time(),format="%Y-%m-%d %H:%M:%S")
##
## Global variables 
##
corr_report <- data.frame()  # correlation report
rdx <- 1 # data.frame index

statstream <- list() # digest /all the digests of the data streams, using rotating windows

#chopChunk <- matrix(data=0, nrow=n_stream, ncol=sw) # all data points in the sliding window
chopChunk <- list()  # raw data for each stream to compute real correlation of sw

corr_pairs <<- list() 		# list of all the correlation stats calculated on 
							# each bw. keys are the bw number, values are data frames

open_positions <<- data.frame() 		# open positions at any given moment
									# added when trading signal is generated, remove when closing position
									# TODO: this can be linked with actual ors trade executions

all_trade_signals <<- data.frame()	# data frame to hold all of todays trading signal

# set up
bw <- 24
sw <- 120 
threshold <- 0.8  # correlation threshold for outputs

# update each stream's digest for each new basic window
# Note: here the stream data are column based, i.e. AA, IBM, ...etc.
UpdateDigest3 <- function(statstream, chopChunk, newdat, bwnum)
{
  #for(j in 1:n_stream) {
  for(j in 1:ncol(newdat)) {
    
    #get new bw for each stream
    sid <- paste("s",j,sep="")
    bwdat <- newdat[,j]
    rw <- as.numeric(bwdat)
  
    if (bwnum == 1) {
      chopChunk[[j]] <- rw
    }
    else if (bwnum <= (sw/bw)) {                               
      chopChunk[[j]] <- c(chopChunk[[j]], rw)  # append to existing basicwin
    }
    else {
      # override the oldest bw : do a shift update: should use a shift function 
      chopChunk[[j]] <- c(chopChunk[[j]][(bw+1):sw], rw)
    }      
        
		#computing digest
    #statstream[[index]] <- batchDigestUpdate(statstream[[index]], rw)
    
  } # end of n_stream 

  # return data    
  retList <- list()
  retList$chopChunk <- chopChunk
  retList$statstream <- statstream
    
  retList 
}

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
                  
  order_list 
}

add_new_order <- function(sym_y, order_type, sym_y_qty, sym_px_list, bwnum, curTime) 
{
  # Symbol OrderType Quantity  Price BasicWinNum  Time  PnL
  new_order <- list()
  # sym position
  
  new_order$Symbol <- sym_y # sym
  new_order$OrderType <- order_type
  new_order$Quantity <- sym_y_qty                              
  new_order$Price <- sym_px_list[sw]
  new_order$BasicWinNum <- bwnum
  new_order$Time <- curTime
  new_order$PnL <- 0  # for new orders
  
  if (order_type == "CLOSE") {
    new_order$PnL <- -0.99  # closing a position
  }
  
  new_order 
}

sprd_stats <- function(swdat, sym_y, sym_x) 
{
  # Note: sym_y is always index symbol, x ETF components
  m <- lm(swdat[[1]] ~ swdat[[2]] + 0)  
  #summary(m) 
  beta <- coef(m)[1]
  sigma <- sqrt(deviance(m))/df.residual(m) 
  #cat("Assumed hedge ratio is", beta, "\n")

  # Now compute the spread
  sprd <- swdat[[1]] - beta*swdat[[2]]
  
  # step 3: perfrom unit root test:  
  # Setting alternative="stationary" chooses the appropriate test.
  # Setting k=0 forces a basic (not augmented) test.  See the
  # documentation for its full meaning.
  
  ht <- adf.test(as.vector(sprd), alternative="stationary", k=0)
  #cat(": ADF p-value is", ht$p.value, "\n")
  
  retlist<-list()
  retlist$sprd <- sprd
  retlist$beta <- beta
  retlist$pvalue <- ht$p.value
  
  retlist
}
                    
library(zoo)
library(xts) 

DATA_DIR <- paste("/export/data/",date_str,sep="")

trade_period <- paste(date_str, " 09:30:00", "::", date_str, " 16:00:00", sep="")
trading_end_time <- paste(date_str, " 15:45:00", sep="")

sym_list <- c("DIA",
  "AA","AXP","BAC","BA","CAT","CSCO","CVX","DD","DIS","GE",
  "HD","HPQ","IBM","INTC","JNJ","JPM","KFT","KO","MCD","MMM",
  "MRK","MSFT","PFE","PG","TRV","T","UTX","VZ","WMT","XOM")
sym_list <- c("DIA","AA","IBM", "PFE", "PG", "VZ", "XOM")

n_stream <- length(sym_list)
sym_index <- sym_list[1] # to be used everywhere

sym_data <- list()

for (n in 1:length(sym_list)) {
  tick_file <- paste(DATA_DIR,"/",sym_list[n],"_",date_str,"_tick.csv",sep="")
  if (!file.exists(tick_file)) {
    cat("cannot find tick data file for symbol: ", sym_list[n], "...skipping it.\n")  
    next
  }
  
  input_data <- read.csv(tick_file)
  sym_data[[n]] <- (input_data$Bid + input_data$Ask)*0.5
  #sym_data[[n]] <- input_data$Bid
  #sym_data[[n]] <- input_data$TradePrice
}

tick_data <- do.call(cbind, sym_data)
colnames(tick_data) <- sym_list
rownames(tick_data) <- input_data$CreateTime

# create a xts object
tick_xts <- as.xts(tick_data)
X <- tick_xts[trade_period]  # 5 seconds time series streams

# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
corr_matrix <- data.frame(ncol=length(sym_list))
corr_matrix[1,1] <- 0
cor_idx <- 1
vol_matrix  <- data.frame(ncol=length(sym_list))
vol_matrix[1,1] <- 0

sprd_list <- list() 

order_list <- data.frame() # sym, shares, price, type(open/close), bwnum
ord_idx <- 0
position_list <- list() # sym, qty, px, index_px, index_qty

bwnum <- 0
swnum <- 0
timepointer <- c() # use timestamp as data frame rownames

  # number of bw from input data files
  m <- floor(nrow(X) / bw)

  # m is for each bw update 
  for (i in 1:m) {
  #for (i in 1:19) {
    cat("\n++++++++++++NEW BASIC WINDOW BEGIN+++++++++++++++++++++++++++++++\n")
    #i <- 1
    bwnum <- i
    
    x_start <- (bwnum - 1) * bw + 1
    x_end   <- (bwnum * bw)
    #cat("x_start: ",x_start, " ")
    #cat("x_end  : ",x_end, " \n")

    bwdat <- X[x_start:x_end, ]
    cat("processing bwnum...",bwnum, " time: ", as.character(end(bwdat)), " \n")
    
    # Note: bwdat is now column based
    newdigest <- UpdateDigest3(statstream, chopChunk, bwdat, bwnum)

    # update chopChunk and statstream
    statstream <- newdigest$statstream 
    chopChunk <- newdigest$chopChunk

    # cache bwwin timestamp
    timepointer <- c(timepointer, as.character(end(bwdat)))
      
    # computing correlation    
    if (bwnum >= sw/bw) {    
      swnum <- swnum + 1
      cat("sliding window num ", swnum, " start computing correlations \n")
      
      pos_signal_list <- list() # short sell list
      neg_signal_list <- list() # long 
      close_signal_list <- list() # used to close Open positions
      
      index_px <- chopChunk[[1]] # index is always the first one
      
      if (sd(index_px) == 0) {
        # need to do nothing as index prices don't change 
        cat("xxx Warning: index_px for ", sym_index, " didn't change. All corr set to 0. \n ") 
        
        # do nothing until the next basic window update
        next 
      }
      else {
        corr_matrix[cor_idx, 1] <- 1
        vol_matrix[cor_idx, 1] <- sd(index_px)

        sprd_list[[1]] <- rep(1:sw)  # initialize sprd for index symbol 
        
        # now compute the correlations of each symbol with ETF 
        for (j in 2:n_stream) {
          sym_j <- sym_list[j]
          sym_px_list <- chopChunk[[j]]
          
          # compute spread stats
          pair_stats <- sprd_stats(chopChunk, 1, j)
          pair_sprd <- pair_stats$sprd
          sprd_list[[j]] <- pair_sprd 
          
          if (sd(sym_px_list) == 0) {
            cat("xxxx got a constant price for ", sym_j)
            cat(" bwnum=", bwnum, "\n")
            cat("Time: ")
            print(start(bwdat))
            cat(" - ")
            print(end(bwdat))
            cat(" \n ")
            
            corr_matrix[cor_idx, j] <- 0  # prices don't change over a sliding window, ignore
          }
          else {
            sym_cor_j <- cor(chopChunk[[1]], chopChunk[[j]])            
            #if (sym_cor_j > threshold) {
            #  pos_signal_list[[sym_j]] <- sym_cor_j
            #}            
            #if (sym_cor_j < -threshold) {
            #  neg_signal_list[[sym_j]] <- sym_cor_j            
            #}            
            corr_matrix[cor_idx, j] <- sym_cor_j
            
            # trading rules
            if ( pair_sprd[sw] > 2*sd(pair_sprd) ) {
              pos_signal_list[[sym_j]] <- pair_sprd[sw]
            }
            
            if ( pair_sprd[sw] < -2*sd(pair_sprd) ) {
              neg_signal_list[[sym_j]] <- pair_sprd[sw]
            }
            
            if ( abs(pair_sprd[sw] - mean(pair_sprd)) < 0.01 ) {
            
            }
          }
          
          # log each symbol's volatility
          vol_matrix[cor_idx, j] <- sd(sym_px_list)  
          
        } # end of for(j)
        
        # now we have the spread stats (pair with index) for each symbol
        # NOTE: should we RANK them and SHORT the highest spred 
        #                               LONG the lowest spread??
        # trading signal 
        # 1. if current spread is above 2*sd(sprd) ShortSell, Buy index
        #    else if current spread is below 2*sd(sprd) Buy symbol, Short index
        # 2. CLOSE Open position if spread converges to 0
        
        cat("$$$ pos_signal_list: \n") 
        print(pos_signal_list)
        cat("\n")
        cat("$$$ neg_signal_list: \n") 
        print(neg_signal_list)
        cat("\n")
          
        # now rank the correlations and create two lists: positive/negative corr
        #cor_vec <- as.numeric(corr_matrix[5,-1])  # exclude index column
        #cor_vec <- as.numeric(corr_matrix[189,])  
        #cor_sorted <- sort(cor_vec, index.return = TRUE)   # index.return = FALSE
        
        # close position first 
        if (length(position_list) >0) {                
          close_signals <- names(position_list)          
          index_close_qty <- 0 # aggregate all shares for index so we don't send mutitple orders

cat("1111 \n")
          for (y in 1:length(close_signals)) {
            # close Open positions when spread is close to mean again.
            sym_y <- close_signals[y]
cat("2222 ", sym_y, " \n")            
            if (sym_y == sym_index) 
              next # skip index symbol
cat("3333 ", sym_y, " \n")            
            # find sym position index  
            sym_y_idx <- which(sym_list == sym_y)
            
            if (length(sym_y_idx)) {
              sym_y_pos <- position_list[[sym_y]]
              sym_sprd <- sprd_list[[sym_y_idx]]
print(sym_y_pos)                
cat("4444 ", sym_y, " \n")  
print(sym_sprd)
cat("5555 \n")               
              if ( sym_y_pos$qty >0 && (sym_sprd[sw] <= mean(sym_sprd)) ) {
                # close symbol position: compute pnl
                cat("$$$$ CLOSING position for ", sym_y, " \n")              

                  index_open_px <- as.numeric(sym_y_pos$index_px)  # fixed
                  index_close_px <- index_px[sw] 

                  sym_open_px <- as.numeric(sym_y_pos$px)
                  sym_id <- which(sym_list == sym_y)
                  sym_close_px <- chopChunk[[sym_id]][sw]
                  
                  # compute pnl
                  sym_pnl <-  (sym_close_px - sym_open_px) * sym_y_pos$qty 
                  index_pnl <- (index_close_px - index_open_px) * sym_y_pos$index_qty
                                              
                  # sym position
                  ord_idx <- ord_idx + 1
                  order_list[ord_idx, 1] <- sym_y # sym
                  order_list[ord_idx, 2] <- "CLOSE" 
                  order_list[ord_idx, 3] <- - sym_y_pos$qty                              
                  order_list[ord_idx, 4] <- sym_close_px
                  order_list[ord_idx, 5] <- bwnum
                  order_list[ord_idx, 6] <- as.character(end(bwdat))
                  order_list[ord_idx, 7] <- sym_pnl
                  
                  # index position
                  ord_idx <- ord_idx + 1
                  order_list[ord_idx, 1] <- sym_index # sym
                  order_list[ord_idx, 2] <- "CLOSE" 
                  order_list[ord_idx, 3] <- -sym_y_pos$index_qty
                  order_list[ord_idx, 4] <- index_px[sw]
                  order_list[ord_idx, 5] <- bwnum
                  order_list[ord_idx, 6] <- as.character(end(bwdat))
                  order_list[ord_idx, 7] <- index_pnl
              
                  index_close_qty <- index_close_qty - sym_y_pos$index_qty
                  
                  position_list[[sym_y]] <- NULL # remove the position
              }
              
              if ( sym_y_pos$qty <0 && (sym_sprd[sw] >= mean(sym_sprd)) ) {
                # close the position: compute pnl
                cat("$$$$ CLOSING position for ", sym_y, " \n")
    
                  index_open_px <- as.numeric(sym_y_pos$index_px)  # fixed
                  index_close_px <- index_px[sw] 

                  sym_open_px <- as.numeric(sym_y_pos$px)
                  sym_id <- which(sym_list == sym_y)
                  sym_close_px <- chopChunk[[sym_id]][sw]
                  
                  # compute pnl
                  sym_pnl <-  (sym_close_px - sym_open_px) * sym_y_pos$qty 
                  index_pnl <- (index_close_px - index_open_px) * sym_y_pos$index_qty
                                              
                  # sym position
                  ord_idx <- ord_idx + 1
                  order_list[ord_idx, 1] <- sym_y # sym
                  order_list[ord_idx, 2] <- "CLOSE" 
                  order_list[ord_idx, 3] <- - sym_y_pos$qty                              
                  order_list[ord_idx, 4] <- sym_close_px
                  order_list[ord_idx, 5] <- bwnum
                  order_list[ord_idx, 6] <- as.character(end(bwdat))
                  order_list[ord_idx, 7] <- sym_pnl
                  
                  # index position
                  ord_idx <- ord_idx + 1
                  order_list[ord_idx, 1] <- sym_index # sym
                  order_list[ord_idx, 2] <- "CLOSE" 
                  order_list[ord_idx, 3] <- -sym_y_pos$index_qty
                  order_list[ord_idx, 4] <- index_px[sw]
                  order_list[ord_idx, 5] <- bwnum
                  order_list[ord_idx, 6] <- as.character(end(bwdat))
                  order_list[ord_idx, 7] <- index_pnl
              
                index_close_qty <- index_close_qty - sym_y_pos$index_qty                  
                position_list[[sym_y]] <- NULL # remove the position
              }
              
            } # end of if (y_idx)
          } # end of for(y)        
          
          # upadte position_list[[sym_index]]$qty  
          position_list[[sym_index]]$qty <- position_list[[sym_index]]$qty + index_close_qty
          position_list[[sym_index]]$px <- 0
          # position_list should be flat after the Open positions are closed
          
          # close all positions after 15:45, and turn trading flag to false
          #if (as.character(end(bwdat)) > trading_end_time && length(position_list) >0) {
          if (as.character(format(end(bwdat), format="%Y%m%d %H:%M:%S")) > trading_end_time ) {
            cat("$$$$ ending the auto trading session, liquiditing all open positions: \n");
            print(names(position_list)) 
            
            for (p in 1:length(position_list)) {
              sym <- names(position_list)[p]
              pos <- position_list[[sym]]
              cat(" sym: ", sym, " qty: ", pos$qty, " \n")
              
              position_list[[sym]] <- NULL
            }
            cat("$$$$ \n")
          }
          
        } # end of if close position
                
        # index return: used by every neg_signal_list to open a position 
        index_ret <- log(index_px[sw]/index_px[1])
        index_open_qty <- 0
        
        # LONG positions
        if (length(neg_signal_list) >0 ) {
          open_signals <- names(neg_signal_list)
                        
          for (x in 1:length(open_signals)) {
            sym_x <- open_signals[x]
              
            # check if any open position for this symbol
            sym_x_pos <- which(names(position_list) == sym_x)
            if (length(sym_x_pos) !=0)
              next # skip it as position has been held for sym_x 
              
            # get sym_id from sym_list
            sym_id <- which(sym_list == sym_x)
              
            if (length(sym_id)) {
              sym_px <- chopChunk[[sym_id]]  # raw price data 
              # log return in the current sliding window
              sym_ret <- log(sym_px[sw]/sym_px[1])  
  
              cat("$$$$ OPENING (LONG) position for ", sym_x, " \n") 

              # add to position_list
              position_list[[sym_x]]$qty <- 100 # long
              position_list[[sym_x]]$px <- sym_px[sw]
              position_list[[sym_x]]$index_px <- index_px[sw]
              index_qty <- floor(-100 * sym_px[sw]/index_px[sw])
              position_list[[sym_x]]$index_qty <- index_qty
              # notice: we want to offset the quantity for index symbol, $$$
              index_open_qty <- index_open_qty + index_qty
                  
              # create order
              ord_idx <- ord_idx + 1
              order_list[ord_idx, 1] <- sym_x
              order_list[ord_idx, 2] <- "Buy" 
              order_list[ord_idx, 3] <- 100  # long
              order_list[ord_idx, 4] <- sym_px[sw]
              order_list[ord_idx, 5] <- bwnum
              order_list[ord_idx, 6] <- as.character(end(bwdat)) 
              order_list[ord_idx, 7] <- 0 
                
              #new_order <- add_new_order(sym_x, "Buy", 100, sym_px, bwnum, as.character(end(bwdat)) ) 
              #order_list[ord_idx,] <- new_order 
            }
          } # end of for (x)
          
        } # end of if (length(neg_signal_list)

        # SHORT Sale positions
        if (length(pos_signal_list) >0 ) {
          open_signals <- names(pos_signal_list)
                        
          for (x in 1:length(open_signals)) {
            sym_x <- open_signals[x]
              
            # check if any open position for this symbol
            sym_x_pos <- which(names(position_list) == sym_x)
            if (length(sym_x_pos) !=0)
              next # skip it as position has been held for sym_x 
              
            # get sym_id from sym_list
            sym_id <- which(sym_list == sym_x)
              
            if (length(sym_id)) {
              sym_px <- chopChunk[[sym_id]]  # raw price data 
              # log return in the current sliding window
              sym_ret <- log(sym_px[sw]/sym_px[1])  
  
              cat("$$$$ OPENING (SHORT SALE) position for ", sym_x, " \n") 

              # add to position_list
              position_list[[sym_x]]$qty <- -100 # short sell
              position_list[[sym_x]]$px <- sym_px[sw]
              position_list[[sym_x]]$index_px <- index_px[sw]
              index_qty <- floor(100 * sym_px[sw]/index_px[sw])
              position_list[[sym_x]]$index_qty <- index_qty
              # notice: we want to offset the quantity for index symbol, $$$
              index_open_qty <- index_open_qty + index_qty
                  
              ord_idx <- ord_idx + 1
              order_list[ord_idx, 1] <- sym_x
              order_list[ord_idx, 2] <- "ShortSell" 
              order_list[ord_idx, 3] <- -100  # short sale
              order_list[ord_idx, 4] <- sym_px[sw]
              order_list[ord_idx, 5] <- bwnum
              order_list[ord_idx, 6] <- as.character(end(bwdat))                
              order_list[ord_idx, 7] <- 0                  
            }
          } # end of for (x)
          
        } # end of if (length(pos_signal_list)
         
        # set index_open_qty
        if (index_open_qty != 0) {
          cat("$$$ open position_list on ", sym_index, " is: ", index_open_qty, "\n")
          position_list[[sym_index]]$qty <- index_open_qty # this is hedged position for open positions    
          position_list[[sym_index]]$px <- index_px[sw]
         
          ord_idx <- ord_idx + 1                  
          #order_list <- add_orders(order_list, sym_index, "Open", index_open_qty, index_px, bwnum, as.character(end(bwdat)))
          new_order <- add_new_order(sym_index, "Open", index_open_qty, index_px, bwnum, as.character(end(bwdat)) ) 
          order_list[ord_idx,] <- new_order         
        } # end if index_position          
    }
  } # end of bwnum computing correlation  
    
    cor_idx <- cor_idx + 1
    
    cat("------------NEW BASIC WINDOW END---------------------------------\n")
  } # end of basic window loop
  
  colnames(corr_matrix) <- sym_list
  rownames(corr_matrix) <- timepointer 
  corr_matrix[is.na(corr_matrix)] <- 0
  corr_out <- paste(WD,"/DIA_corr_matrix_",date_str,".csv",sep="")
  cat("writing corr_matrix to ", corr_out, " \n")
  write.csv(corr_matrix, corr_out)

  colnames(vol_matrix) <- sym_list
  rownames(vol_matrix) <- timepointer 
  vol_matrix[is.na(vol_matrix)] <- 0
  vol_out <- paste(WD,"/DIA_vol_matrix_",date_str,".csv",sep="")
  cat("writing vol_matrix to ", vol_out, " \n")
  write.csv(vol_matrix, vol_out)
  
  # save the raw price data as well 
  price_out <-  paste(WD,"/DIA_price_matrix_",date_str,".csv",sep="") 
  cat("writing price_matrix to ", price_out, " \n")
  price_matrix <- as.data.frame(X)
  rownames(price_matrix) <- as.character(index(X))
  write.csv(price_matrix, price_out, row.names = TRUE)
  
  # now use the corr_matrix to find trading strategies 
  order_columns <- c("Symbol",	"OrderType",	"Quantity",	"Price",	"BasicWinNum", "Time", "PnL")
  colnames(order_list) <- order_columns
  order_out <-  paste(WD,"/DIA_order_list_",date_str,".csv",sep="") 
  cat("writing order_list to ", order_out, " \n")
  write.csv(order_list, order_out)  

    
  cat("back testing done with ", bwnum, " basic windows. \n")
  cat(" time:", format(Sys.time(),format="%Y-%m-%d %H:%M:%S"), "\n")

  #correlation report header
  #names(corr_report) <- c("streamID1", "streamID2", "BeginTimePoint", "EndTimePoint", "Dist", "CorrCoef", "open1", "close1", "open2", "close2","rowKey")
  #outfile <- paste(OUTPUTDATADIR,"/",sector,"_corr_report_",dateStr,".csv",sep="")
  #write.csv(corr_report, outfile)
  #cat("Writing correlation report to file: ", outfile, " .\n")
    
  #outfile <- paste(OUTPUTDATADIR,"/",sector,"_all_trade_signals_",dateStr,".csv",sep="")
  #cat("Writing all_trade_signals report to file: ", outfile, " .\n")
  #write.csv(all_trade_signals, outfile)
  
  #outfile <- paste(OUTPUTDATADIR,"/",sector,"_open_positions_",dateStr,".csv",sep="")
  #cat("Writing all open positions report to file: ", outfile, " .\n")
  #write.csv(open_positions, outfile)

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

print(order_list) 
cat("sym_list: ")
print(sym_list) 
cat("bw size =", bw, " --- sw: ", sw, " \n")
cat("threshold =", threshold, " --- trade count: ", nrow(order_list), " \n")
cat("trading_end_time =", trading_end_time, " \n")
cat("sum(order_list$PnL) =", sum(order_list$PnL), "\n")
 
cat("\nPG Started time: ", startTime, "\n");
cat("All DONE.        ", format(Sys.time(),format="%Y-%m-%d %H:%M:%S"), "\n")

# source("F:/DEV/fhxalgo/fhxmodel/statstream/corr_backtest3.r")