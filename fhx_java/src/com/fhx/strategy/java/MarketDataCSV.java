package com.fhx.strategy.java;

import org.marketcetera.strategy.java.Strategy;
import org.marketcetera.event.AskEvent;
import org.marketcetera.event.BidEvent;
import org.marketcetera.event.TradeEvent;
import org.marketcetera.marketdata.MarketDataRequest;
import static org.marketcetera.marketdata.MarketDataRequest.*;

/* $License$ */
/**
 * Strategy that receives market data
 *
 * @author anshul@marketcetera.com
 * @version $Id$
 * @since $Release$
 */
public class MarketDataCSV extends Strategy {
    private static final String SYMBOLS = "IBM"; //reads from GOOG.csv
    private static final String MARKET_DATA_PROVIDER = "contrib_csv"; //
    /**
     * Executed when the strategy is started.
     * Use this method to set up data flows
     * and other initialization tasks.
     */
    @Override
    public void onStart() {
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
        System.out.println("XXXX onAsk= "+ inAsk);
    }

    /**
     * Executed when the strategy receives a bid event.
     *
     * @param inBid the bid event.
     */
    @Override
    public void onBid(BidEvent inBid) {
        warn("Bid " + inBid);
        System.out.println("XXXX onBid= "+ inBid + ", eventTime: " + inBid.getTimestampAsDate());
        
        //System.exit(0);
    }

    /**
     * Executed when the strategy receives a trade event.
     *
     * @param inTrade the ask event.
     */
    @Override
    public void onTrade(TradeEvent inTrade) {
        warn("Trade " + inTrade);
        System.out.println("XXXX onTrade= "+ inTrade);
    }

    @Override
    public void onOther(Object inEvent)
    {
    	System.out.println("XXXX: onOther="+ inEvent);
    }

}
