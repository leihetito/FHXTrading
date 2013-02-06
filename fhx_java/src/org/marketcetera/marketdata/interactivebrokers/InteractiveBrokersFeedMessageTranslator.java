package org.marketcetera.marketdata.interactivebrokers;

import static org.marketcetera.marketdata.MarketDataRequest.Content.LATEST_TICK;
import static org.marketcetera.marketdata.MarketDataRequest.Content.TOP_OF_BOOK;
import static org.marketcetera.marketdata.Messages.UNSUPPORTED_REQUEST;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import org.marketcetera.core.CoreException;
import org.marketcetera.marketdata.DataRequestTranslator;
import org.marketcetera.marketdata.MarketDataRequest;
import org.marketcetera.marketdata.interactivebrokers.InteractiveBrokersFeed.Request;

import org.marketcetera.trade.MSymbol;
import org.marketcetera.util.log.I18NBoundMessage1P;



/* $License$ */

/**
 * Marketcetera feed implementation of {@link DataRequestTranslator}.
 *
 * @author <a href="mailto:colin@marketcetera.com">Colin DuPlantis</a>
 * @version $Id: MarketceteraFeedMessageTranslator.java 10525 2009-04-23 13:45:15Z colin $
 * @since 0.5.0
 */
public class InteractiveBrokersFeedMessageTranslator
    implements DataRequestTranslator<Request>
{

    /**
     * the instance used for all message translations
     */
    private static final InteractiveBrokersFeedMessageTranslator sInstance = new InteractiveBrokersFeedMessageTranslator();
    /**
     * counter used to identify translated messages
     */
    private static final AtomicInteger counter = new AtomicInteger(0);
    /* (non-Javadoc)
     * @see org.marketcetera.marketdata.DataRequestTranslator#translate(org.marketcetera.marketdata.DataRequest)
     */
    @Override
    public Request fromDataRequest(MarketDataRequest inRequest)
            throws CoreException
    {
        if(inRequest.validateWithCapabilities(TOP_OF_BOOK,LATEST_TICK)) {
            return messageFromMarketDataRequest((MarketDataRequest)inRequest);
        }
        throw new CoreException(new I18NBoundMessage1P(UNSUPPORTED_REQUEST,
                                                       String.valueOf(inRequest.getContent())));
    }
    /**
     * Gets a <code>MarketceteraFeedMessageTranslator</code> instance.
     *
     * @return a <code>MarketceteraFeedMessageTranslator</code> value
     */
    static InteractiveBrokersFeedMessageTranslator getInstance()
    {
        return sInstance;
    }
    /**
     * Create a new <code>MarketceteraFeedMessageTranslator</code> instance.
     */
    private InteractiveBrokersFeedMessageTranslator()
    {        
    }
    /**
     * Creates a <code>Message</code> value representing a market data request to pass to the feed server. 
     *
     * @param inRequest a <code>MarketDataRequest</code> value
     * @return a <code>Message</code> value
     */
    private static Request messageFromMarketDataRequest(MarketDataRequest inRequest)
    {
        List<MSymbol> symbolList = new ArrayList<MSymbol>();
        for(String symbol : inRequest.getSymbols()) {
            symbolList.add(new MSymbol(symbol));
        }
        int id = counter.incrementAndGet();
        
        MSymbol symbol;
        
        InteractiveBrokersMessage message=new InteractiveBrokersMessage();
        
        // sets symbols and requestId
        message.setRequestId(Integer.toString(id));
        message.setSymbolList(symbolList);
        // set the update type indicator
        return new Request(id,message,inRequest);
    }
}
