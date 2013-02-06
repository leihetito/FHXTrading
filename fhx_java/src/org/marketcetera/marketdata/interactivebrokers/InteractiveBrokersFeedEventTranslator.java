package org.marketcetera.marketdata.interactivebrokers;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

import org.apache.commons.lang.ObjectUtils;
import org.marketcetera.core.ClassVersion;
import org.marketcetera.core.CoreException;
import org.marketcetera.event.AskEvent;
import org.marketcetera.event.BidEvent;
import org.marketcetera.event.EventBase;
import org.marketcetera.event.EventTranslator;
import org.marketcetera.event.TradeEvent;
import org.marketcetera.event.UnsupportedEventException;
import org.marketcetera.marketdata.MarketDataRequest.Content;
import org.marketcetera.marketdata.interactivebrokers.IBFeedManager.EventType;
import org.marketcetera.marketdata.interactivebrokers.InteractiveBrokersFeed.Request;
import org.marketcetera.trade.MSymbol;
import org.marketcetera.util.log.I18NBoundMessage1P;

import com.ib.client.Contract;

import quickfix.FieldNotFound;
import quickfix.Group;
import quickfix.field.MDEntryPx;
import quickfix.field.MDEntrySize;
import quickfix.field.MDEntryType;
import quickfix.field.MDMkt;
import quickfix.field.NoMDEntries;
import quickfix.field.Symbol;
import quickfix.fix44.MarketDataSnapshotFullRefresh;



/* $License$ */

/**
 * Market data feed implementation that connects to Marketcetera's
 * exchange simulator.
 *
 * @author <a href="mailto:colin@marketcetera.com">Colin DuPlantis</a>
 * @version $Id: MarketceteraFeedEventTranslator.java 10525 2009-04-23 13:45:15Z colin $
 * @since 0.5.0
 */
@ClassVersion("$Id: MarketceteraFeedEventTranslator.java 10525 2009-04-23 13:45:15Z colin $") //$NON-NLS-1$
public class InteractiveBrokersFeedEventTranslator
    implements EventTranslator, Messages
{
    private static final String UNKNOWN = "?"; //$NON-NLS-1$
    private static final InteractiveBrokersFeedEventTranslator sInstance = new InteractiveBrokersFeedEventTranslator();
    public static InteractiveBrokersFeedEventTranslator getInstance()
    {
        return sInstance;
    }
    private InteractiveBrokersFeedEventTranslator()
    {        
    }
    /* (non-Javadoc)
     * @see org.marketcetera.event.IEventTranslator#translate(java.lang.Object)
     */
    public List<EventBase> toEvent(Object inData,
                                   String inHandle) 
        throws CoreException
    {

        if(!(inData instanceof MarketDataResponse)) {
            throw new UnsupportedEventException(new I18NBoundMessage1P(UNKNOWN_EVENT_TYPE,
                                                                       ObjectUtils.toString(inData,
                                                                                            null)));
        }

        MarketDataResponse response = (MarketDataResponse)inData;

        List<EventBase> events = new ArrayList<EventBase>();
            //int entries = refresh.getInt(NoMDEntries.FIELD);
            // marketcetera feed returns bid/ask/trade for every query (each entry corresponds to one of these).
            // we have to decide which data to convert to events and pass along.  we know the symbol and the handle.
            // the handle is sufficient to determine what content was requested with the original request.
            Request request = InteractiveBrokersFeed.getRequestByHandle(inHandle);
            if (request == null) {
                // this could happen if the request were canceled (and removed from the collection) but the feed
          //  is still sending updates.  just bail out, no worries, the feed will stop soon.
                return events;
            }
            //int entries = refresh.getContracts()).size();
            
            Set<Content> requestedContent = request.getRequest().getContent();

                String symbol = response.getSymbol();
                // exchange is *somewhat* optional
                if (EventType.Bid.equals(response.getEventType())) {
                	if(requestedContent.contains(Content.TOP_OF_BOOK)) {
                		BidEvent bid = new BidEvent(System.nanoTime(), 
                				System.currentTimeMillis(),
                                new MSymbol(symbol),
                                "NA",
                                response.getPrice(),
                                response.getSize());
                        events.add(bid);
                	}
                } else if (EventType.Offer.equals(response.getEventType())) {                        
                	if(requestedContent.contains(Content.TOP_OF_BOOK)) {
                		AskEvent ask = new AskEvent(System.nanoTime(),
                				System.currentTimeMillis(),
                                new MSymbol(symbol),
                                "NA",
                                response.getPrice(),
                                response.getSize());
                        events.add(ask);
                	}
                } else if (EventType.Trade.equals(response.getEventType())) {
                    if(requestedContent.contains(Content.LATEST_TICK)) {
                    	TradeEvent trade = new TradeEvent(System.nanoTime(),
                    			System.currentTimeMillis(),
                                new MSymbol(symbol),
                                "NA",
                                response.getPrice(),
                                response.getSize());

                         events.add(trade);
                    }
                        
                } else {
                	throw new UnsupportedEventException(new I18NBoundMessage1P(UNKNOWN_MESSAGE_ENTRY_TYPE, response.getEventType()));                
                }
        return events;
    }
    
    /* (non-Javadoc)
     * @see org.marketcetera.event.IEventTranslator#translate(org.marketcetera.event.EventBase)
     */
    public Object fromEvent(EventBase inEvent) 
        throws CoreException
    {
        throw new UnsupportedOperationException();
    }
}
