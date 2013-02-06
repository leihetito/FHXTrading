package org.marketcetera.marketdata.interactivebrokers;

import java.io.File;
import java.io.IOException;
import java.math.BigDecimal;
import java.net.InetAddress;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.UnknownHostException;
import java.text.DecimalFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.marketcetera.core.ClassVersion;
import org.marketcetera.core.CoreException;
import org.marketcetera.core.IDFactory;
import org.marketcetera.core.InMemoryIDFactory;
import org.marketcetera.core.NoMoreIDsException;
import org.marketcetera.marketdata.AbstractMarketDataFeed;
import org.marketcetera.marketdata.Capability;
import org.marketcetera.marketdata.FeedException;
import org.marketcetera.marketdata.FeedStatus;
import org.marketcetera.marketdata.MarketDataFeedTokenSpec;
import org.marketcetera.marketdata.MarketDataRequest;
import org.marketcetera.marketdata.IFeedComponent.FeedType;
import org.marketcetera.marketdata.interactivebrokers.IBFeedManager.EventType;

import org.marketcetera.trade.MSymbol;
import org.marketcetera.util.log.SLF4JLoggerProxy;

import com.google.common.collect.HashMultimap;
import com.google.common.collect.SetMultimap;
import com.ib.client.EClientSocket;

/* $License$ */

/**
 * A sample implementation of a market data feed.
 *
 * <p>This feed will return random market data for every symbol queried.
 *
 * @author <a href="mailto:colin@marketcetera.com>Colin DuPlantis</a>
 * @since 0.5.0
 */
@ClassVersion("$Id: MarketceteraFeed.java 10540 2009-04-27 16:05:40Z colin $")
public class InteractiveBrokersFeed 
    extends AbstractMarketDataFeed<InteractiveBrokersFeedToken,
                                   InteractiveBrokersFeedCredentials,
                                   InteractiveBrokersFeedMessageTranslator,
                                   InteractiveBrokersFeedEventTranslator,
                                   InteractiveBrokersFeed.Request,
                                   InteractiveBrokersFeed> 
    implements Messages
    
    
{
	/**
	 * singleton instance of the interactivebrokers feed
	 */
	private static InteractiveBrokersFeed sInstance;
	
	private int percision=4;
    /**
     * active requests by handle
     */
    private static final Map<String,Request> requestsByHandle = new HashMap<String,Request>();
    /**
     * handles by associated symbol
     */
    private static final SetMultimap<String,String> handlesBySymbol = HashMultimap.create();
    
    // pass with a reference to this, so we can send events back.
    private IBFeedManager ibManager=new IBFeedManager(this);
    
	private InteractiveBrokersFeed(String inProviderName) throws CoreException  {
		super(FeedType.LIVE, inProviderName);
		        
	}
    /**
     * Gets an instance of <code>InteractiveBrokersFeed</code>.
     * 
     * @param inProviderName a <code>String</code> value
     * @return a <code>InteractiveBrokersFeed</code> value
     * @throws CoreException  
     * @throws URISyntaxException 
     */
	public static InteractiveBrokersFeed getInstance(String inProviderName) throws CoreException {
	    {
	        if(sInstance != null) {
	            return sInstance;
	        }
	        sInstance = new InteractiveBrokersFeed(inProviderName);
	        return sInstance;
	    }

	}

	@Override
	protected void doCancel(String inHandle) {
		// TODO Auto-generated method stub
		
	}

	@Override
	protected boolean doLogin(InteractiveBrokersFeedCredentials inCredentials) {
		ibManager.connect(inCredentials.getHost(), inCredentials.getPort(), inCredentials.getClientId());
		percision=inCredentials.getPercision();
		return ibManager.isConnected();
	}

	@Override
	protected void doLogout() {
		ibManager.disconnect();				
	}

	@Override
	protected List<String> doMarketDataRequest(Request inData)
			throws FeedException {
        try {
        	
            addRequest(inData);
             
            ibManager.requestMarketData(inData.getMessage(), "100", false);
            
            SLF4JLoggerProxy.debug(this,
                                   "InteractiveBrokersFeed posted query for {} and associated the request with handle {}", //$NON-NLS-1$
                                   inData.getRequest().getSymbols(),
                                   inData.getIdAsString());
            return Arrays.asList(new String[] { inData.getIdAsString() } );
        } catch (Exception e) {
            throw new FeedException(e);
        }
	}
    /**
     * Associates the given request handles with the given request object.
     * 
     * @param inRequest a <code>Request</code> v`alue
     */
    private synchronized static void addRequest(Request inRequest)
    {
    	
        requestsByHandle.put(inRequest.getIdAsString(),
                             inRequest);
        for(String symbol : inRequest.getRequest().getSymbols()) {        
            handlesBySymbol.put(symbol,
                                inRequest.getIdAsString());
        }
    }
    /**
     * Returns the handles associated with the given symbol, if any.
     *
     * @param inSymbol a <code>String</code> value
     * @return a <code>Set&lt;String&gt;</code> value
     */
    private synchronized static Set<String> getHandlesForSymbol(String inSymbol)
    {
        Set<String> handles = handlesBySymbol.get(inSymbol);
        if(handles != null) {
            return handles;
        }
        return Collections.emptySet();
    }
    /**
     * Returns the <code>Request</code> associated with the given handle.
     *
     * @param inHandle a <code>String</code> value
     * @return a <code>Request</code> value or null
     */
    synchronized static Request getRequestByHandle(String inHandle)
    {
        return requestsByHandle.get(inHandle);
    }
    
    /* (non-Javadoc)
     * @see org.marketcetera.marketdata.AbstractMarketDataFeed#generateToken(org.marketcetera.marketdata.MarketDataFeedTokenSpec)
     */
    @Override
    protected InteractiveBrokersFeedToken generateToken(MarketDataFeedTokenSpec inTokenSpec) 
        throws FeedException
    {
        return InteractiveBrokersFeedToken.getToken(inTokenSpec, 
                                              this);
    }
    /* (non-Javadoc)
     * @see org.marketcetera.marketdata.AbstractMarketDataFeed#getEventTranslator()
     */
    @Override
    protected InteractiveBrokersFeedEventTranslator getEventTranslator()
    {
        return InteractiveBrokersFeedEventTranslator.getInstance();
    }

    /* (non-Javadoc)
     * @see org.marketcetera.marketdata.AbstractMarketDataFeed#getMessageTranslator()
     */
    @Override
    protected InteractiveBrokersFeedMessageTranslator getMessageTranslator()
    {
        return InteractiveBrokersFeedMessageTranslator.getInstance();
    }
    /* (non-Javadoc)
     * @see org.marketcetera.marketdata.AbstractMarketDataFeed#isLoggedIn(org.marketcetera.marketdata.IMarketDataFeedCredentials)
     */

	@Override
	protected boolean isLoggedIn() {
		return ibManager.isConnected();
	}
    /**
     * static capabilities for this data feed
     */
    private static final Set<Capability> capabilities = Collections.unmodifiableSet(EnumSet.of(Capability.TOP_OF_BOOK,Capability.LATEST_TICK));
    /* (non-Javadoc)
     * @see org.marketcetera.marketdata.MarketDataFeed#getCapabilities()
     */
    @Override
    public Set<Capability> getCapabilities()
    {
        return capabilities;
    }
	
	@ClassVersion("$Id: MarketceteraFeed.java 10540 2009-04-27 16:05:40Z colin $")
    static final class Request
    {
        /**
         * the underlying request submitted to the adapter
         */
		private final MarketDataRequest request;
        /**
         * the unique identifier for this request
         */
        private final int id;

        /**
         * the underlying request message
         */
        private final InteractiveBrokersMessage message;
        
		public Request(int inId, InteractiveBrokersMessage inMessage, MarketDataRequest inRequest) {
			
			id=inId;
			message=inMessage;
			request=inRequest;
		}

		public int getId(){
			return id;
		}
		/***
		 * 
		 * @return
		  */
		public MarketDataRequest getRequest(){
			return request;
		}
		public InteractiveBrokersMessage getMessage() {
			return message;
		}
        /**
         * Gets the id as a <code>String</code>.
         *
         * @return a <code>String</code> value
         */
        String getIdAsString()
        {
            return Long.toHexString(getId());
        }

    }
	
	public void ibDataReceived(String symbol, BigDecimal price, BigDecimal size, EventType eventType) {
		MarketDataResponse response=new MarketDataResponse(eventType);
	
		
		//size.setScale(1, BigDecimal.ROUND_HALF_UP);
		response.setPrice(price.setScale(percision, BigDecimal.ROUND_HALF_UP));
		response.setSymbol(symbol);
		response.setSize(size);
		
		for (String handle : getHandlesForSymbol(symbol)) {			
			this.dataReceived(handle, response);
		}
		
	}

}
