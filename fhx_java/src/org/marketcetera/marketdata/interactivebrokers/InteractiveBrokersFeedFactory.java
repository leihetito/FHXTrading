package org.marketcetera.marketdata.interactivebrokers;

import java.net.URISyntaxException;

import org.marketcetera.core.ClassVersion;
import org.marketcetera.core.CoreException;
import org.marketcetera.core.NoMoreIDsException;
import org.marketcetera.marketdata.AbstractMarketDataFeedFactory;
import org.marketcetera.marketdata.FeedException;

/* $License$ */

/**
 * {@link InteractiveBrokersFeed} constructor factory.
 *
 * @author <a href="mailto:colin@marketcetera.com">Colin DuPlantis</a>
 * @version $Id: MarketceteraFeedFactory.java 10039 2008-11-18 08:44:26Z klim $
 * @since 0.5.0
 */
@ClassVersion("$Id: MarketceteraFeedFactory.java 10039 2008-11-18 08:44:26Z klim $")  //$NON-NLS-1$
public class InteractiveBrokersFeedFactory 
    extends AbstractMarketDataFeedFactory<InteractiveBrokersFeed,InteractiveBrokersFeedCredentials> 
{
    private final static InteractiveBrokersFeedFactory sInstance = new InteractiveBrokersFeedFactory();
    public static InteractiveBrokersFeedFactory getInstance()
    {
        return sInstance;
    }
	public String getProviderName() 
	{
		return "InteractiveBrokers"; //$NON-NLS-1$
	}
    /* (non-Javadoc)
     * @see org.marketcetera.marketdata.IMarketDataFeedFactory#getMarketDataFeed()
     */
    @Override
    public InteractiveBrokersFeed getMarketDataFeed() 
        throws CoreException
    {
            return InteractiveBrokersFeed.getInstance(getProviderName());
    }
}
