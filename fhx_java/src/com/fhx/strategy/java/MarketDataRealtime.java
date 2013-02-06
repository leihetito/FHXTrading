package com.fhx.strategy.java;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.RandomAccessFile;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Date;
import java.util.List;

import org.apache.log4j.Logger;
import org.marketcetera.event.AskEvent;
import org.marketcetera.event.BidEvent;
import org.marketcetera.event.TradeEvent;
import org.marketcetera.marketdata.MarketDataRequest;
import org.marketcetera.marketdata.MarketDataRequest.Content;
import org.marketcetera.strategy.java.Strategy;

/**
 * Strategy that receives market data
 *
 * @author FHX ATMarketData processing: build the real-time correlation matrix
 * @version $Id$
 * @since $Release$
 */
public class MarketDataRealtime extends Strategy {
	
	private static Logger log = Logger.getLogger(MarketDataRealtime.class);
	
    private static final String SYMBOLS = "SPY,QQQQ,IWM,MMM,AA,AXP,T,BAC,BA,CAT,CVX,CSCO,KO,DD,XOM,GE,HPQ,HD,INTC,IBM,JNJ,JPM,KFT,MCD,MRK,MSFT,PFE,PG,TRV,UTX,VZ,WMT,DIS";
    private static final String MARKET_DATA_PROVIDER = "fhxmktdat_at"; 
	private static SimpleDateFormat DATE_FORMAT = new SimpleDateFormat("yyyyMMdd");
	private static SimpleDateFormat marketTimeFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS");	
    
    private List<String> symbolList = new ArrayList<String>();
	private RandomAccessFile[] symbolDataFileHandles;

    /**
     * Executed when the strategy is started.
     * Use this method to set up data flows
     * and other initialization tasks.
     */
    @Override
    public void onStart() {
 
    	for (String symbol : SYMBOLS.split(",")) {
			symbolList.add(symbol);
		}
		Collections.sort(symbolList);  // sort it for fast search
		
//		System.out.println("XXXX Subscribed symbols (sorted): ");
//		System.out.println(Arrays.toString(symbolList.toArray()));

		warn("XXXX Subscribed symbols (sorted): ");
		warn(Arrays.toString(symbolList.toArray()));

		// we store data each symbol file
		String fileDate = DATE_FORMAT.format(new Date());
		
		try {
    		File dataDir = new File("/export/data/"+fileDate);
			//File dataDir = new File(System.getProperty("user.home") + "/data/" + fileDate);
    		boolean mkdir = dataDir.mkdirs();
    		
    		symbolDataFileHandles = new RandomAccessFile[symbolList.size()];
    		String dataDirPath;
    		
			for (int i=0; i < symbolList.size(); i++) {
	    		dataDirPath = dataDir.getAbsolutePath();	
	    		symbolDataFileHandles[i] = new RandomAccessFile(dataDirPath+"/"+symbolList.get(i)+"_"+fileDate+"_trade.txt","rw");
			}
		}
		catch(FileNotFoundException e){
			e.printStackTrace();
		}
		
		log.info("XXXX calling requestMarketData(): ");
        requestMarketData(MarketDataRequest.newRequest().
                withSymbols(SYMBOLS).
                fromProvider(MARKET_DATA_PROVIDER).
                withContent(Content.LATEST_TICK, Content.TOP_OF_BOOK));
    }

    /**
     * Executed when the strategy receives an ask event.
     *
     * @param inAsk the ask event.
     */
    @Override
    public void onAsk(AskEvent inAsk) {
        warn("Ask " + inAsk);
        //System.out.println("XXXX onAsk= "+ inAsk.getPrice().setScale(4) + ", eventTime: " + marketTimeFormat.format(inAsk.getTimestampAsDate()));
    }

    /**
     * Executed when the strategy receives a bid event.
     *
     * @param inBid the bid event.
     */
    @Override
    public void onBid(BidEvent inBid) {
        warn("Bid " + inBid);
        //System.out.println("XXXX onBid= "+ inBid.getPrice().setScale(4) + ", eventTime: " + marketTimeFormat.format(inBid.getTimestampAsDate()));
    }

    /**
     * Executed when the strategy receives a trade event.
     *
     * @param inTrade the ask event.
     */
    @Override
    public void onTrade(TradeEvent inTrade) {
        warn("Trade " + inTrade);

		String symbol= inTrade.getSymbolAsString();
		int fileHandleIdx = getSymbolIndex(symbol);
		
		StringBuilder sb = new StringBuilder();
		sb.append("XXXX onTrade: ");
		sb.append(symbol);
		sb.append(",");
		sb.append(inTrade.getMessageId());
		sb.append(",");
		sb.append(inTrade.getPrice().setScale(4));
		sb.append(",");
		sb.append(inTrade.getSize());
		sb.append(",");
		sb.append(marketTimeFormat.format(inTrade.getTimestampAsDate()));
		sb.append("\n");
		
        log.info("XXXX onTrade= "+ sb.toString());
        
		try {
			symbolDataFileHandles[fileHandleIdx].writeBytes(sb.toString());
		}
		catch(Exception e) {
			e.printStackTrace();
		}
    }

    @Override
    public void onOther(Object inEvent)
    {
    	log.info("XXXX: onOther="+ inEvent);
    }

    // utils: other search method?, faster from a HashMap
    public int getSymbolIndex(String symbol) {
    	return Collections.binarySearch(symbolList, symbol);    	
    }
    
}
