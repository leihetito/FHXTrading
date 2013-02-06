package org.marketcetera.marketdata.interactivebrokers;

import org.marketcetera.core.ClassVersion;
import org.marketcetera.marketdata.AbstractMarketDataFeedToken;
import org.marketcetera.marketdata.MarketDataFeedToken;
import org.marketcetera.marketdata.MarketDataFeedTokenSpec;

/* $License$ */

/**
 * {@link MarketDataFeedToken} implementation for {@link InteractiveBrokersFeed}.
 *
 * @author <a href="mailto:colin@marketcetera.com">Colin DuPlantis</a>
 * @version $Id: MarketceteraFeedToken.java 10229 2008-12-09 21:48:48Z klim $
 * @since 1.0.0
 */
@ClassVersion("$Id: MarketceteraFeedToken.java 10229 2008-12-09 21:48:48Z klim $") //$NON-NLS-1$
public class InteractiveBrokersFeedToken
    extends AbstractMarketDataFeedToken<InteractiveBrokersFeed>
{
    /**
     * Gets a <code>MarketceteraFeedToken</code> value.
     *
     * @param inTokenSpec a <code>MarketDataFeedTokenSpec&lt;MarketceteraFeedCredentials&gt;</code> value
     * @param inFeed a <code>MarketceteraFeed</code> value
     * @return a <code>MarketceteraFeedToken</code> value
     */
    static InteractiveBrokersFeedToken getToken(MarketDataFeedTokenSpec inTokenSpec,
                                          InteractiveBrokersFeed inFeed) 
    {
        return new InteractiveBrokersFeedToken(inTokenSpec, inFeed);
    }
    /**
     * Create a new MarketceteraFeedToken instance.
     *
     * @param inTokenSpec a <code>MarketDataFeedTokenSpec&lt;MarketceteraFeedCredentials&gt;</code> value
     * @param inFeed a <code>MarketceteraFeed</code> value
     */
    private InteractiveBrokersFeedToken(MarketDataFeedTokenSpec inTokenSpec,
                                  InteractiveBrokersFeed inFeed)
    {
        super(inTokenSpec, 
              inFeed);
    }
}
