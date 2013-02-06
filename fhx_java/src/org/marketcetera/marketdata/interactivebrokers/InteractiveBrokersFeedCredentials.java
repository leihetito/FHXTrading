package org.marketcetera.marketdata.interactivebrokers;

import org.marketcetera.core.ClassVersion;
import org.marketcetera.marketdata.AbstractMarketDataFeed;
import org.marketcetera.marketdata.AbstractMarketDataFeedURLCredentials;
import org.marketcetera.marketdata.FeedException;
import org.marketcetera.marketdata.MarketDataFeedCredentials;

/* $License$ */

/**
 * Credentials instance for <code>MarketceteraFeed</code>.
 * 
 * @author <a href="mailto:colin@marketcetera.com">Colin DuPlantis</a>
 * @version $Id: MarketceteraFeedCredentials.java 10267 2008-12-24 16:25:11Z colin $
 * @since 0.6.0
*/
@ClassVersion("$Id: MarketceteraFeedCredentials.java 10267 2008-12-24 16:25:11Z colin $") //$NON-NLS-1$
public class InteractiveBrokersFeedCredentials implements MarketDataFeedCredentials
{
    private String            host;
    private int               port;
    private int 			  clientId;
    private int				  percision;

    /**
     * Gets a <code>InteractiveBrokersFeedCredentials</code> instance.
     *
     * @return a <code>InteractiveBrokersFeedCredentials</code> value
     * @throws FeedException 
     * @throws FeedException if an error occurs construction the credentials object
     */
    public static InteractiveBrokersFeedCredentials getInstance(String inHost,
                                                          int inPort, int inClientId, int inPercision) throws FeedException    {
        return new InteractiveBrokersFeedCredentials(inHost, inPort, inClientId, inPercision);
    }
    /**
     * Constructs a new <code>MarketceteraFeedCredentials</code> object.
     * 
     * @param inURL a <code>String</code> value
     * @throws FeedException 
     */
    private InteractiveBrokersFeedCredentials(String inHost, int inPort, int inClientId, int inPercision) throws FeedException
    {
        setHost(inHost);      
        setPort(inPort);
        setClientId(inClientId);
        setPercision(inPercision);
    }
    public int getPort()
    {
    	return port;
    
    }
    
    public int getClientId() {
    	return clientId;
    }
    @Override
    public String toString()
    {
        StringBuilder output = new StringBuilder();
        output.append("InteractiveBrokers Feed Credentials: host=").append(getHost()).append(" port=").append(getPort()); //$NON-NLS-1$ //$NON-NLS-2$ //$NON-NLS-3$
        return output.toString();
    }
	public void setHost(String host) {
		this.host = host;
	}
	public String getHost() {
		return host;
	}
	public void setPercision(int inPercision) {
		percision=inPercision;
	}
	
	public int getPercision() {
		return percision;
	}
	
	public void setPort(int port) {
		this.port = port;
	}
	public void setClientId(int clientId) {
		this.clientId = clientId;
	}


}
