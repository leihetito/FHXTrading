
load_tick_data <- function(sym_list) {
  for (n in 1:length(sym_list)) {
    tick_file <- paste(DATA_DIR,"/",sym_list[n],"_",date_str,"_tick.csv",sep="")
    if (!file.exists(tick_file)) {
    cat("cannot find tick data file : ", tick_file, "...skipping it.\n")  
      cat("cannot find tick data file for symbol: ", sym_list[n], "...skipping it.\n")  
      # remove it from sym_list
      next
    }
  
    input_data <<- read.csv(tick_file)
    cat("loading tick data from file: ",tick_file,", size: ",nrow(input_data),"\n")
    
  #  if (nrow(input_data) < 23401)
  #    next ;
    
    # update global var  
    sym_data[[n]] <<- (input_data$Bid + input_data$Ask) * 0.5
    sym_trading_list <<- c(sym_trading_list, sym_list[n])
    
  }
}

# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

tick_counter <- function(cvec) {
    score <- length(cvec[cvec >0]) - length(cvec[cvec <0])
    # Note: normalize the score by dividing it by length(cvex)
    #score <- (length(cvec[cvec >0]) - length(cvec[cvec <0]))/length(cvec)
}

ma <- function(x,n=5){filter(x,rep(1/n,n), sides=1)}

# use apply function
update_sw <- function(newbw, bwnum)
{
  for(j in 1:ncol(newbw)) {
    bwdat <- newbw[,j]
    rw <- as.numeric(bwdat)
    
    if (bwnum == 1) {
      chopChunk[[j]] <<- rw
    }
    else if (bwnum <= (sw/bw)) {
      chopChunk[[j]] <<- c(chopChunk[[j]], rw)  # append to existing basicwin
    }
    else {
      # override the oldest bw : do a shift update: should use a shift function
      chopChunk[[j]] <<- c(chopChunk[[j]][(bw+1):sw], rw)
    }
  }
  
  #return(chopChunk)
}

gen_signal_list <- function() {
  cat("\ngenerating signal list...\n")
  
  # compute swStats: bw stats, current sw
  bw_score_sd <- sd(bw_score_list)
  swStats <- sum(bw_score_list[(bwnum-sw/bw):bwnum])

  if (swStats > 2*bw_score_sd) {
    # buy
    cat("XXXX: buy signal...bwnum=",bwnum)
    signal <- list(bwnum=bwnum, t="buy")
    signalList[[bwnum]] <<- signal
  }  
  else if (swStats < -2*bw_score_sd) {
    # sell
    cat("XXXX: sell signal...bwnum=",bwnum)
    signal <- list(bwnum=bwnum, t="sell")
    signalList[[bwnum]] <<- signal
  }
  else {
    cat("XXXX: NOO signal...bwnum=",bwnum)
    signalList[[bwnum]] <<- list(bwnum=bwnum, t="NULL")   
  }
     
}

add_new_order <- function(sym, side, qty, px, bwnum, ord_time, ord_type) 
{
	# Symbol OrderType Quantity  Price BasicWinNum  Time  PnL
	new_order <- list()
	
	new_order$Symbol <- sym
	new_order$OrderType <- side
	new_order$Quantity <- qty                              
	new_order$Price <- px
	new_order$BasicWinNum <- bwnum
	new_order$Time <- ord_time
	new_order$Type <- ord_type
  		
	new_order
}

gen_entry_order <- function() {
  cat("\ngenerating entry order...\n")
  # open a long/short position 
  # long: sw_score is > 2*sd(bw_score_list)
  #       && index bw_ret > 0 && sw_ret > 0
  # short: sw_sroce is < -2*sd(bw_score_list)
  #       && index bw_ret < 0 && sw_ret < 0  
  new_order <- list()
  
  if (signalList[[bwnum]]$t=="buy" && index_bwret_list[length(index_bwret_list)] > 0) {
      
      limit_px <- index_px_list[length(index_px_list)]
	  num_shrs <- floor(total_capital*kelly/limit_px)  # round down to nearest integer
      new_order <- add_new_order(sector,"buy",num_shrs,limit_px,bwnum,idx_time[length(idx_time)],"EntryLong")  
      
      position_list <<- list(index=sector, side="long", qty=num_shrs, px=limit_px)
  }
  else if (signalList[[bwnum]]$t=="sell" && index_bwret_list[length(index_bwret_list)] < 0) {

      limit_px <- index_px_list[length(index_px_list)]
	  num_shrs <- floor(total_capital*kelly/limit_px)  # round down to nearest integer
      new_order <- add_new_order(sector,"sell",num_shrs,limit_px,bwnum,idx_time[length(idx_time)],"EntryShort")       
      
      position_list <<- list(index=sector, side="short", qty=num_shrs, px=limit_px)
  }    
  
  entry_order_list[[bwnum]] <<- new_order
}

gen_exit_order <- function() {
  cat("\ngenerating exit order...\n")
  # if holding a long position,  close when sw_score < 0
  # if holing a short position, close when sw_score > 0
  
  if ( position_list$side == "long" 
    && (sw_score_list[length(sw_score_list)] < 0) ) {
    # close long position 
      limit_px <- index_px_list[length(index_px_list)]
	  num_shrs <- floor(total_capital*kelly/limit_px)  # round down to nearest integer
      entry_order_list[[bwnum]] <<- add_new_order(sector,"sell",num_shrs,limit_px,bwnum,idx_time[length(idx_time)],"Exit")
      
      pnl_list[[bwnum]] <<- position_list$qty * ( limit_px - position_list$px )
      position_list <<- NULL
  }
  else if (position_list$side == "short" 
    && (sw_score_list[length(sw_score_list)] > 0) ) {
    # close long position 
      limit_px <- index_px_list[length(index_px_list)]
	  num_shrs <- floor(total_capital*kelly/limit_px)  # round down to nearest integer
      entry_order_list[[bwnum]] <<- add_new_order(sector,"buy",num_shrs,limit_px,bwnum,idx_time[length(idx_time)],"Exit")
      
      pnl_list[[bwnum]] <<- position_list$qty * ( position_list$px - limit_px )
      position_list <<- NULL
  }
   
  	#Generate Kelly's allocation factor using pnl_list information
	# Trade Size = Winng % of total trade - (1-Winng % of total trade)/(total profit/total loss)
	if(length(pnl_list) > 0) {
		profit_list <- pnl_list[sapply(pnl_list, function(x) !is.na(x) && x > 0 )]
		loss_list <- pnl_list[sapply(pnl_list, function(x) !is.na(x) && x < 0 )]
		# use half kelly here to be conservative
		winning_percent <- length(profit_list)/length(pnl_list) 
		kelly <<- winning_percent - (1-winning_percent)/(sum(unlist(profit_list))/sum(unlist(loss_list)))
		kelly <<- kelly/2
		
		cat("operating on new Kelly of ", kelly, "\n")
	}
	
	# sanity check 
	if(is.na(kelly) || kelly <=0 || kelly > 1)
		kelly <<- initial_allocation
}

gen_eod_order <- function() {
  # if holding a long position,  close when sw_score < 0
  # if holing a short position, close when sw_score > 0
  cat("EOD reached, gen_eod_order. \n")

  gen_exit_order()  
}

gen_eod_report <- function() {
  # if holding a long position,  close when sw_score < 0
  # if holing a short position, close when sw_score > 0
  cat("EOD reached, gen_eod_report. \n")
  #gen_plot()

  order_list <<- do.call(rbind, entry_order_list)
  write.csv(order_list,paste("/export/data/",date_str,"/",sector,"_orderlist_",date_str,".csv",sep=""))

  pnl <<- do.call(rbind, pnl_list)
  write.csv(pnl,paste("/export/data/",date_str,"/",sector,"_pnl_",date_str,".csv",sep=""))
  cat("today_pnl: ", sum(pnl))
  print(pnl)

  report_flag <- TRUE  
}

process_bw_data <- function(bwdat, bwnum) {

	# write out basic window data as reference
	write.csv(bwdat,paste("/export/data/",date_str,"/",sector,"_ticks_bw_",bwnum,".csv",sep=""))
	
	row_idx <- bwdat$timestamp
	#colnames(tick_data) <- sym_trading_list
	rownames(bwdat) <- row_idx
	#remove the first 2 cols, rownum and timstamp
	bwdat <- bwdat[,c(-1,-2)]
	bwdat <- as.matrix(bwdat) # this is required for diff(log(bwdat))

  # calling model, share with backtest 
  ret_order <- process_bw_data_backtest(bwdat, bwnum)
  ret_order  
}

test_order_func <- function(bwdat, bwnum) {
	new_order <- list()
	idx_time <<- c(idx_time, rownames(bwdat)[nrow(bwdat)])
	new_order <- add_new_order(sector,"buy",100,99,bwnum,idx_time[length(idx_time)],"EntryLong")       
	
	ret_order <- data.frame()  
	ret_order <- as.data.frame(new_order)
	
	cat("bwnum ",bwnum," order: \n")
	print(ret_order) 
	
	ret_order
}

process_bw_data_backtest <- function(bwdat, bwnum) {
  cat("\n++++++BEGIN BASIC WINDOW [",bwnum,"] ++++++++++++++++++++++\n")
  
  bwnum <<- bwnum
  # latest tick time
  z_tick <<- strptime(rownames(bwdat)[nrow(bwdat)], "%Y-%m-%d %H:%M:%OS")    

  cat("processing bwnum: ",bwnum, " \n")
  cat(" time begin: ", rownames(bwdat)[1], "\n")
  cat(" time   end: ", rownames(bwdat)[nrow(bwdat)], " \n")
  cat("trading_end: ", trading_end_time, "\n")
  
  # init it 
  entry_order_list[[bwnum]] <<- list()
  
    # the end of each bw time
    idx_time <<- c(idx_time, rownames(bwdat)[nrow(bwdat)])
    # update raw data for sw
    #chopChunk <- update_sw(chopChunk, bwdat, bwnum)
    update_sw(bwdat, bwnum)
    # now build each basic win tick count stats: use apply func
    logret <- diff(log(bwdat))
    # score of each basic win    
    bw_score <- apply(logret, 2, tick_counter) # 2: by column vector
    bw_score_sum <- sum(bw_score[-which(names(bw_score)==sector)])
    # add to global var list
    bw_score_list <<- c(bw_score_list, bw_score_sum) # global var
    index_px_vec <- as.numeric(bwdat[,which(names(bw_score)==sector)])
    index_px_list <<- c(index_px_list, index_px_vec[length(index_px_vec)])
    index_bwret <- log(index_px_vec[nrow(bwdat)]/index_px_vec[1])
    index_bwret_list <<- c(index_bwret_list, index_bwret)
	
	cat("done setting up...\n")
	
    # now process sliding window stats
    if ( bwnum >= sw/bw) {
      # lazy way: should do a 1-step update
      sw_score_list <<- ma(bw_score_list)
      
      # compute sw index return, assume index 1 is the ETF sector
      sid <- which(names(bw_score)==sector)
      index_swpx <- chopChunk[[sid]]
      index_swret <- log(index_swpx[length(index_swpx)]/index_swpx[1])
      index_swret_list <<- c(index_swret_list, index_swret)

	  cat("done computing index returns...\n")
	  
      # only gen_signals 
      if (z_tick < z_end) {  
        # 1. signal 
        gen_signal_list()
          
        # 2. order 
        if ( length(position_list) == 0 ) {
            gen_entry_order()
        }
        else if ( length(position_list) > 0 ) {
            gen_exit_order()
        }
         
        # 3. position
        
      }      
      else if ( !is.null(position_list) && length(position_list) > 0 ) {
        # 4. EOD: close all positions if any
        cat("calling gen_eod_order(), all position are to be cleared...\n")
        gen_eod_order()
      }
      else {
        # do nothing
        cat("Trading EOD ended, all position cleared. pnl=", sum(do.call(rbind, pnl_list)), " USD\n")
        
        if (!report_flag) {
          gen_eod_report()
        }
      } 

    }

    cat("\n++++++END BASIC WINDOW [",bwnum,"] ++++++++++++++++++++++++\n")
        
    # return new order 
    ret_order <- data.frame()  
    if (length(entry_order_list) > 0) {
      ret_order <- as.data.frame(entry_order_list[[bwnum]]) # could be null
    } 
    
    cat("bwnum ",bwnum," order: \n")
    print(ret_order) 
    
    ret_order
    
}

# xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

gen_report_and_plot <- function() {
  cat("EOD reached.  Generating trading reports and PnL plot...\n")
  
  # compute sw score and ret
  #sw_score_list <- ma(bw_score_list) # * (sw/bw)
  
  score_list <- cbind(idx_time, bw_score_list, sw_score_list, index_px_list, index_bwret_list, index_swret_list)
  colnames(score_list, c("time", "bw_score", "sw_score", "index_px", "bw_index_ret", "sw_index_ret"))
  
  out_report <- paste("/export/data/",date_str,"/",sector,"_score_list_",date_str,".csv",sep="")
  write.csv(score_list, out_report)
  
  cat("=========== corr summary ==================\n")
  me <- read.csv(out_report)
  print(summary(me))
  
  # corr analysis
  cat("===========",sector,",",date_str,"==================\n")
  cat("#> cor(me$bw_score_list, me$index_bwret_list) \n ")
  cat(cor(me$bw_score_list, me$index_bwret_list))
  cat("\n#> cor(me$bw_score_list[1:189], me$index_bwret_list[2:190]) \n")
  cat(cor(me$bw_score_list[1:189], me$index_bwret_list[2:190]))
  
  # sw score and ret, should be highly correlated
  cat("\n#> cor(me$sw_score_list[5:190], me$index_swret_list[5:190]) \n")
  cat(cor(me$sw_score_list[5:190], me$index_swret_list[5:190]))
  # corr between current sw_score and sw ret
  # note: 4 (sw-1) basic window data overlap
  # so likely the 1 bw prediction time is not so useful, BUT TRY it!
  cat("\n#> cor(me$sw_score_list[5:189], me$index_swret_list[6:190]) \n")
  cat(cor(me$sw_score_list[5:189], me$index_swret_list[6:190]))
  cat("\n=========== END ==================\n")
  
  # trading rules: use all bw scores stats, if current sw_score is 2 outside of 2*sd (bw_score),
  # make an entry position and exit when it's reverting back to mean.
  
  signalDf <- as.data.frame(do.call(rbind,signalList))
  buyIdx <- as.numeric(signalDf[signalDf$t=="buy",1] )
  sellIdx <- as.numeric(signalDf[signalDf$t=="sell",1] )
  zeroIdx <- as.numeric(signalDf[signalDf$t=="zero",1] )
  
  #png(filename=paste("F:/DEV/Robmind/",sector,"_",dateStr,"_figure.png",sep=""), height=295, width=600, bg="white")
  #par(mfrow=c(2,1)))
  #par(mfcol=c(2,1)))
  ptitle <- paste(sector,", ",date_str,sep="")
  #plot(me$index_px_list, type='o', ylim=range(me$index_px_list), axes=F, ann=T, xlab="", ylab="px")
  plot(me$index_px_list, type='o', ylim=range(me$index_px_list), axes=FALSE, ann=FALSE, xlab="", ylab="px")
  grid()
  abline(v=buyIdx,col='green')
  abline(v=sellIdx,col='red')
  abline(v=zeroIdx,col='yellow')
  atidx <- seq(1,length(idx_time), 5)
  timelabel <- strptime(idx_time, "%Y-%m-%d %H:%M:%OS")
  xlabel <- format(timelabel, "%H:%M")
  #axis(1,at=atidx, lab=substring(idx_time[atidx],1,5), las=2)
  axis(1,at=atidx, lab=xlabel[atidx], las=2)
  #axis(2, las=1, at=range(me$index_px_list))
  axis(2, las=1, at=seq(min(me$index_px_list), max(me$index_px_list), 0.10))
  #box()
  title(main=ptitle)
  #dev.off()
  
  #plot(me$sw_score_list, type='o')
  #axis(1, at=1:5, lab=c("Mon","Tue","Wed","Thu","Fri"))
  #abline(v=buyIdx,col='green')
  #abline(v=sellIdx,col='red')
  
  
  cat(paste("DONE. ", format(Sys.time(),format="%Y-%m-%d %H:%M:%S"), "\n"),sep="")
}


## plot price time series 
plotPriceSeries <- function(X, label="px") {
  x <- 1:NROW(X)                        # simple index 
  plot.new()                            # empty plot 
  oldpar <- par(mar=c(0,4,2,4),         # no bottom spacing 
                ylog=FALSE,              # plot on log(price) axis
                lend="square")          # square line ends

  ## set up coordinates
  plot.window(range(x), range(X, na.rm=TRUE), xaxs="i")
  grid()                                # dashed grid 

  lines(x, X, col='black')

  axis(2) 
  axis(4, pos=par("usr")[1], line=0.5)  # this would plot them 'inside'
  title(ylab=label)              # y-axis label 

  box()                                 # outer box 
  par(oldpar) 
}

gen_plot <- function() {
  cat("EOD reached.  Generating trading reports and PnL plot...\n")
  
  score_list <- cbind(idx_time, bw_score_list, sw_score_list, index_px_list, index_bwret_list, index_swret_list)
  colnames(score_list, c("time", "bw_score", "sw_score", "index_px", "bw_index_ret", "sw_index_ret"))
  
  out_report <- paste("/export/data/",date_str,"/",sector,"_score_list_",date_str,".csv",sep="")
  write.csv(score_list, out_report)
  
  cat("=========== corr summary ==================\n")
  me <- read.csv(out_report)
  print(summary(me))
  
  # trading rules: use all bw scores stats, if current sw_score is 2 outside of 2*sd (bw_score),
  # make an entry position and exit when it's reverting back to mean.
  
  signalDf <- as.data.frame(do.call(rbind,signalList))
  buyIdx <- as.numeric(signalDf[signalDf$t=="buy",1] )
  sellIdx <- as.numeric(signalDf[signalDf$t=="sell",1] )
  zeroIdx <- as.numeric(signalDf[signalDf$t=="zero",1] )
  
  # test plot
  layout(matrix(c(1,2,3),3,1,byrow=TRUE), 
         height=c(0.5,0.2,0.3), width=1)

  ## set 'global' plot parameters: horizontal y-axis labels, tighter spacing
  ## and no outer spacing
  oldpar <- par(las=1, mar=c(2,4,2,4), oma=c(2.5,0.5,1.5,0.5)) 

  plotPriceSeries(me$index_px_list, "prices")
  pnl <- formatC(sum(do.call(rbind, pnl_list)), digits=2)
  ptitle <- paste(sector,", ",date_str,", pnl: ",pnl,sep="")
  #plot(me$index_px_list, type='o', ylim=range(me$index_px_list), axes=F, ann=T, xlab="", ylab="px")
  #plot(me$index_px_list, type='o', ylim=range(me$index_px_list), axes=FALSE, ann=FALSE, xlab="", ylab="px")
  grid()
  abline(v=buyIdx,col='green')
  abline(v=sellIdx,col='red')
  #abline(v=zeroIdx,col='yellow')
  title(main=ptitle)

  order_list <- as.data.frame(do.call(rbind,entry_order_list))
  openLongIdx <- as.numeric(order_list[order_list$Type=="EntryLong",]$BasicWinNum)
  openShortIdx <- as.numeric(order_list[order_list$Type=="EntryShort",]$BasicWinNum)
  exitIdx <- as.numeric(order_list[order_list$Type=="Exit",]$BasicWinNum)
    
  plotPriceSeries(me$sw_score_list, "sw scores")
  abline(v=openLongIdx,col='green')
  abline(v=openShortIdx,col='red')
  abline(v=exitIdx,col='black')

  #plotSignalsSeries(me$sw_score_list)
  plotPriceSeries(me$bw_score_list, "bw scores")
  
  atidx <- seq(1,length(idx_time), 5)
  timelabel <- strptime(idx_time, "%Y-%m-%d %H:%M:%OS")
  xlabel <- format(timelabel, "%H:%M")
  #axis(1,at=atidx, lab=substring(idx_time[atidx],1,5), las=2)
  axis(1,at=atidx, lab=xlabel[atidx], las=2)
  #axis(2, las=1, at=range(me$index_px_list))
  axis(2, las=1, at=seq(min(me$index_px_list), max(me$index_px_list), 0.10))
  
  #hist(sprd, main="", col="lightblue")
  par(oldpar)      

  cat(paste("DONE. ", format(Sys.time(),format="%Y-%m-%d %H:%M:%S"), "\n"),sep="")
}
