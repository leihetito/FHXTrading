
# create the trading signal
# 1. track corrlated pairs
# 2. trading signal is generated if a symbol drops out of the corr_pairs list 
#   from last to current bw update
# 3. if it's added back to the corr_pairs, close the position.
#   ALSO, close the position if another sliding window has passed after initial 
#     position was created.
# 4. track open positions, track all trades
# 5. allocate trade sizes based on relative prices
# Note: trading starts after the first sliding window + 1 basic window. 

HOME <- Sys.getenv("HOME")  
WD <- paste(HOME,"/dev/FHX/workspace_java/FHX_model/",sep="")
#WD <- "/projects/workspace/FHX_model/"
source(paste(WD,"dft_streamstats_func.r",sep=""))

##
## Global variables
##
#max_window_of_day <- 10

#corr_pairs <<- list() 		# list of all the correlation stats calculated on 
							# each bw. keys are the bw number, values are data frames

#open_positions <<- data.frame() 		# open positions at any given moment
									# added when trading signal is generated, remove when closing position
									# TODO: this can be linked with actual ors trade executions

#all_trade_signals <<- data.frame()	# data frame to hold all of todays trading signal

set_corr_pairs <- function( pairs, bw_num )
{
	# TODO: get pricing data into the pairs dataframe
	corr_pairs[[bw_num]] <<- pairs
}

open_signals <- function( x, win_num )
{
	#
	# for positively correlated pairs, long under-performed stock and short over-performed using period return
	# for negatively correlated pairs, long over-performed stock and short under-performed using period return
	#
	# calc period return to determine which one to long and short, assuming I have a sliding window of px
  
  if (is.null(x))
    return 	
    
	trade_row <- data.frame(streamID1=x[1], streamID2=x[2], rowKey=x[11], 
			              streamID1Side=NA, streamID2Side=NA,
						  streamID1Qty=0, streamID2Qty=0,
						  streamID1Px=0, streamID2Px=0, bwNumTradeEntered=win_num)
	
	#print(x)
	# simple return of the open/close of the sliding window
	return1 <- log(as.numeric(x[8]) / as.numeric(x[7]))  #close1/open1
	return2 <- log(as.numeric(x[10]) / as.numeric(x[9])) #close2/open2
	
	#cat("return1",return1,"\n")
	#cat("return2",return2,"\n")
	
	#CorrCoef
	if(as.numeric(x[5]) > 0) {
		if(return1 > return2) {
			trade_row$streamID1Side <- "S"
			trade_row$streamID2Side <- "B"
			trade_row$buySideReturn <- return2
			trade_row$sellSideReturn <- return1
		}
		else
		{
			trade_row$streamID1Side <- "B"
			trade_row$streamID2Side <- "S"
			trade_row$buySideReturn <- return1
			trade_row$sellSideReturn <- return2
		}
	}
	else {	# negative corrlation
		if(return1 > return2) {
			trade_row$streamID1Side <- "B"
			trade_row$streamID2Side <- "S"
			trade_row$buySideReturn <- return1
			trade_row$sellSideReturn <- return2
		}
		else
		{
			trade_row$streamID1Side <- "S"
			trade_row$streamID2Side <- "B"
			trade_row$buySideReturn <- return2
			trade_row$sellSideReturn <- return1
		}
	}
	
	# TODO: this allocation logic needs to be refined
	# problems with odd-lots, bid-ask spread, limit price
	trade_row$streamID1Qty = 100
	trade_row$streamID2Qty = (as.numeric(x[9]) / as.numeric(x[7])) * trade_row$streamID1Qty
	trade_row$streamID1Px = as.numeric(x[8])	  #close1
	trade_row$streamID2Px = as.numeric(x[10])   #close2
	trade_row$CorrCoef = as.numeric(x[5])
	
	#all_trade_signals <<- rbind(all_trade_signals, trade_row)
	trade_row
}

rank_signals <- function( win_num )
{
	# TODO: need to revisit if one of the side of an ETF
	pos_corr <- all_trade_signals[all_trade_signals$bwNumTradeEntered==win_num && all_trade_signals$CorrCoef>0 ,]
	neg_corr <- all_trade_signals[all_trade_signals$bwNumTradeEntered==win_num && all_trade_signals$CorrCoef<0 ,]
	
	print("all window signals")
	print(pos_corr)
	
	# should sort the returns here for all pairs: 
	# 1. > index return (for those we think they are over valued.)
	# 2. < index return (under valued? )
	# Note: we should closely track the reurn of this list. 
	# what happens to those that no longer have high correlation with index? 
	# this is crucial to develop trading strategies.
	
	
	buy_signals <- pos_corr[which.min(pos_corr$buySideReturn), ]
	sell_signals <- pos_corr[which.max(pos_corr$sellSideReturn), ]
	
	signals <- list(buy_signals=buy_signals, sell_signals=sell_signals)
}

close_signals <- function( x, win_num )
{
	position <- open_positions[streamID1==x$streamID1 & streamID2==x$streamID2,]
	
	trade_row <- data.frame(streamID1=position$streamID1, streamID2=position$streamID2, 
							streamID1Side=NA, streamID2Side=NA,
							streamID1Qty=position$streamID1Qty, streamID2Qty=positon$streamID2Qty,
							streamID1Px=0, streamID2Px=0, bwNumTradeEntered=win_num)
	if(position$streamID1Side == "B") {
		trade_row$streamID1Side = "S"
		trade_row$streamID1Side = "B"
	}
	else {
		trade_row$streamID1Side = "B"
		trade_row$streamID1Side = "S"
	}
	
	trade_row$streamID1Px = x$close1
	trade_row$streamID2Px = x$close2
	
	# remove the position from open_positions
	# this is a bit silly, must be a better way to do it
	open_positions <<- open_positions[-(streamID1=x$streamID1 & streamID2=x$streamID2),]
	all_trade_signals <<- rbind(all_trade_signals, trade_row)
}

timeout_signals <- function( x, win_num )
{
	position <- open_positions[(win_num - open_positions$bwNumTradeEntered) >= sw/bw,]
	
	trade_row <- data.frame(streamID1=position$streamID1, streamID2=position$streamID2, 
			streamID1Side=NA, streamID2Side=NA,
			streamID1Qty=position$streamID1Qty, streamID2Qty=positon$streamID2Qty,
			streamID1Px=0, streamID2Px=0, bwNumTradeEntered=win_num)
	if(position$streamID1Side == "B") {
		trade_row$streamID1Side = "S"
		trade_row$streamID1Side = "B"
	}
	else {
		trade_row$streamID1Side = "B"
		trade_row$streamID1Side = "S"
	}
	
	# market price to close???
	trade_row$streamID1Px = 0
	trade_row$streamID2Px = 0
	
	# remove the position from open_positions
	# this is a bit silly, must be a better way to do it
	open_positions <<- open_positions[-(streamID1=x$streamID1 & streamID2=x$streamID2),]
	all_trade_signals <<- rbind(all_trade_signals, trade_row)
}

eod_signals <- function( x, win_num )
{
	if(win_num > max_window_of_day) {
		position <- x
	
		trade_row <- data.frame(streamID1=position$streamID1, streamID2=position$streamID2, 
				streamID1Side=NA, streamID2Side=NA,
				streamID1Qty=position$streamID1Qty, streamID2Qty=positon$streamID2Qty,
				streamID1Px=0, streamID2Px=0, bwNumTradeEntered=win_num)
		if(position$streamID1Side == "B") {
			trade_row$streamID1Side = "S"
			trade_row$streamID1Side = "B"
		}
		else {
			trade_row$streamID1Side = "B"
			trade_row$streamID1Side = "S"
		}
	
		# market price to close???
		trade_row$streamID1Px = 0
		trade_row$streamID2Px = 0
	
		# remove the position from open_positions
		# this is a bit silly, must be a better way to do it
		open_positions <<- open_positions[-(streamID1=x$streamID1 & streamID2=x$streamID2),]
		all_trade_signals <<- rbind(all_trade_signals, trade_row)
	}
}

generate_signals <- function(allPairList, bw_num )
{	
	#
	# corrlation only between component and ETF
	# divide into 2 groups based on return against return of ETF
	# postive corrlation: short the most over-performed and long the most under-performed
	# negative correlation: opposite
	# if no symbol in either group, long/short the ETF
	#
	
	#corr_pairs[[bw_num]] <<- pairs
	
	#if(bw_num >= max_window_of_day)
	#	return(data.frame())
	
	signals <- list()
	
	if (bw_num <= sw/bw) {
		return(signals)
	}

	prev_pairs <- allPairList[[bw_num-1]]
	curr_pairs <- allPairList[[bw_num]]
	
	# get list of correlated pairs that was in prev window, but dropped off the curr window
	#dropped_pairs <- subset(prev_pairs,!(prev_pairs$rowKey %in% curr_pairs$rowKey))
	dropped_pairs <- XnotinY(prev_pairs, curr_pairs, by=c("streamID1", "streamID2"))
	print("dropped")
	print(dropped_pairs)
	# get list of correlated pairs that was not in prev window, but emerged in the curr window
	#new_pairs <- subset(curr_pairs,!(curr_pairs$rowKey %in% prev_pairs$rowKey))
	new_pairs <- XnotinY(curr_pairs, prev_pairs, by=c("streamID1", "streamID2"))
	print("new")
	print(new_pairs)
	# calculate open trade signals for each row of the data frame
	
	if (nrow(dropped_pairs) >0) {
    apply(dropped_pairs, 1, open_signals, win_num=bw_num )	
  }
  #signals <- rank_signals( bw_num )

	# calculate closing trade signals for each row of the data frame
	# Conditions for closing a trade
	# 1. corrlation re-emerged 
	# 2. pre-defined time has elapsed
	# 3. market close as defined by the last bw_num - close all positions
	
	# Condition 1
	#apply(close_pairs, 1, close_signals, win_num=bw_num )
	
	# Condition 2
	#apply(open_positions, 1, timeout_signals, win_num=bw_num )
	
	# Condition 3
	#apply(open_positions, 1, eod_signals, win_num=bw_num )
	
}

unit_test <- function( )
{
	inDataDir <- paste("/data/statstream/",sep="")
	sw1File <- paste(inDataDir,"outreport_1.csv",sep="")
	sw1Result <- read.csv(sw1File, header=TRUE)
	
	sw2File <- paste(inDataDir,"outreport_2.csv",sep="")
	sw2Result <- read.csv(sw2File, header=TRUE)
	
	trade_signal_1 <- generate_signals(sw1Result, 1 )
	print(trade_signal_1)
	
	trade_signal_2 <- generate_signals(sw2Result, 2 )
	print(trade_signal_2)

}

#out <- unit_test()
#print(out)

XinY <-
    function(x, y, by = intersect(names(x), names(y)), by.x = by, by.y = by,
             notin = FALSE, incomparables = NULL,
             ...)
{
    fix.by <- function(by, df)
    {
        ## fix up 'by' to be a valid set of cols by number: 0 is row.names
        if(is.null(by)) by <- numeric(0L)
        by <- as.vector(by)
        nc <- ncol(df)
        if(is.character(by))
            by <- match(by, c("row.names", names(df))) - 1L
        else if(is.numeric(by)) {
            if(any(by < 0L) || any(by > nc))
                stop("'by' must match numbers of columns")
        } else if(is.logical(by)) {
            if(length(by) != nc) stop("'by' must match number of columns")
            by <- seq_along(by)[by]
        } else stop("'by' must specify column(s) as numbers, names or logical")
        if(any(is.na(by))) stop("'by' must specify valid column(s)")
        unique(by)
    }

    nx <- nrow(x <- as.data.frame(x)); ny <- nrow(y <- as.data.frame(y))
    by.x <- fix.by(by.x, x)
    by.y <- fix.by(by.y, y)
    if((l.b <- length(by.x)) != length(by.y))
        stop("'by.x' and 'by.y' specify different numbers of columns")
    if(l.b == 0L) {
        ## was: stop("no columns to match on")
        ## returns x
        x
    }
    else {
        if(any(by.x == 0L)) {
            x <- cbind(Row.names = I(row.names(x)), x)
            by.x <- by.x + 1L
        }
        if(any(by.y == 0L)) {
            y <- cbind(Row.names = I(row.names(y)), y)
            by.y <- by.y + 1L
        }
        ## create keys from 'by' columns:
        if(l.b == 1L) {                  # (be faster)
            bx <- x[, by.x]; if(is.factor(bx)) bx <- as.character(bx)
            by <- y[, by.y]; if(is.factor(by)) by <- as.character(by)
        } else {
            ## Do these together for consistency in as.character.
            ## Use same set of names.
            bx <- x[, by.x, drop=FALSE]; by <- y[, by.y, drop=FALSE]
            names(bx) <- names(by) <- paste("V", seq_len(ncol(bx)), sep="")
            bz <- do.call("paste", c(rbind(bx, by), sep = "\r"))
            bx <- bz[seq_len(nx)]
            by <- bz[nx + seq_len(ny)]
        }
        comm <- match(bx, by, 0L)
        if (notin) {
            res <- x[comm == 0,]
        } else {
            res <- x[comm > 0,]
        }
    }
    ## avoid a copy
    ## row.names(res) <- NULL
    attr(res, "row.names") <- .set_row_names(nrow(res))
    res
}

XnotinY <-
    function(x, y, by = intersect(names(x), names(y)), by.x = by, by.y = by,
             notin = TRUE, incomparables = NULL,
             ...)
{
    XinY(x,y,by,by.x,by.y,notin,incomparables)
}
