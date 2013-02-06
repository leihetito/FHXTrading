package org.marketcetera.marketdata.interactivebrokers;

import javax.management.MXBean;

import org.marketcetera.core.ClassVersion;
import org.marketcetera.marketdata.AbstractMarketDataModuleMXBean;
import org.marketcetera.module.DisplayName;

/* $License$ */

/**
 * Defines the set of attributes and operations available from the {@link InteractiveBrokersFeed}.
 *
 * @author <a href="mailto:colin@marketcetera.com">Colin DuPlantis</a>
 * @version $Id: MarketceteraFeedMXBean.java 10229 2008-12-09 21:48:48Z klim $
 * @since 1.0.0
 */
@ClassVersion("$Id: MarketceteraFeedMXBean.java 10229 2008-12-09 21:48:48Z klim $") //$NON-NLS-1$
@MXBean(true)
@DisplayName("Management Interface for InteractiveBrokers Marketdata Feed")
public interface InteractiveBrokersFeedMXBean
    extends AbstractMarketDataModuleMXBean
{
    /**
     * Returns the URL that describes the location of the Marketcetera Exchange server.
     *
     * @return a <code>String</code> value
     */
    @DisplayName("The hostname for the InteractiveBrokers Client")
    public String getHost();
    /**
     * Sets the URL that describes the location of the Marketcetera Exchange server.
     *
     * @param inURL a <code>String</code> value
     */
    @DisplayName("The hostname for the InteractiveBrokers Client")
    public void setHost(@DisplayName("The hostname for the InteractiveBrokers Exchange Server")
                       String inHost);

    @DisplayName("The port for the InteractiveBrokers Exchange Server")
    public String getPort();
    
    @DisplayName("The port for the InteractiveBrokers Exchange Server")    
    public void setPort(@DisplayName("The port for the InteractiveBrokers Exchange Server") String inPort);
    
    @DisplayName("The clientId for the InteractiveBrokers Exchange Server")
    public String getClientId();
    
    @DisplayName("The clientId for the InteractiveBrokers Exchange Server")    
    public void setClientId(@DisplayName("The port for the InteractiveBrokers Exchange Server") String inClientId);
    
    @DisplayName("The percision for market data prices")
    public void setPercision(@DisplayName("The percision for market data prices") String percision);
    
    @DisplayName("The percision for market data prices")
    public String getPercision();
    
}
