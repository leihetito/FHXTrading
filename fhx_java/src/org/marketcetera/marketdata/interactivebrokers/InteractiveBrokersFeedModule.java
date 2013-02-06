package org.marketcetera.marketdata.interactivebrokers;

import java.io.FileInputStream;
import java.io.IOException;
import java.util.Properties;

import org.marketcetera.core.CoreException;
import org.marketcetera.marketdata.AbstractMarketDataModule;
import org.marketcetera.util.misc.ClassVersion;

/* $License$ */

/**
 * StrategyAgent module for {@link InteractiveBrokersFeed}.
 * 
 * <p>Note that in case of a credentials change via {@link #setSenderCompID(String)},
 * {@link #setTargetCompID(String)}, or {@link #setURL(String)}, this module must be
 * restarted for the changes to take effect.
 *
 * @author <a href="mailto:colin@marketcetera.com">Colin DuPlantis</a>
 * @version $Id: MarketceteraFeedModule.java 10229 2008-12-09 21:48:48Z klim $
 * @since 1.0.0
 */
@ClassVersion("$Id: MarketceteraFeedModule.java 10229 2008-12-09 21:48:48Z klim $")  //$NON-NLS-1$
public class InteractiveBrokersFeedModule
        extends AbstractMarketDataModule<InteractiveBrokersFeedToken,
                                         InteractiveBrokersFeedCredentials>
		implements InteractiveBrokersFeedMXBean
{
    /**
     * Create a new MarketceteraFeedEmitter instance.
     * @throws CoreException 
     */
    InteractiveBrokersFeedModule()
        throws CoreException
    {
        super(InteractiveBrokersFeedModuleFactory.INSTANCE_URN,
              InteractiveBrokersFeedFactory.getInstance().getMarketDataFeed());
        
        loadIBConfProperties();
    }
    @Override
    public final String getHost()
    {
        return host;
    }
    @Override
    public final void setHost(String inHost)
    {
        host = inHost;
    }
    @Override
    public final String getPort()
    {
    	return port;   
    }
    @Override
    public final void setPort(String inPort)
    {
    	port=inPort;   
    }
    @Override
    public final String getClientId() {
    	return clientId;
    }
    @Override
    public final void setClientId(String inClientId) {
    	clientId=inClientId;
    }
    @Override
    public final String getPercision()
    {
    	return percision.isEmpty() ? "3" : percision;    	
    }
    @Override
    public final void setPercision(String inPercision)
    {
    	percision=inPercision;
    }
    /* (non-Javadoc)
     * @see org.marketcetera.marketdata.AbstractMarketDataModule#getCredentials()
     */
    @Override
    protected final InteractiveBrokersFeedCredentials getCredentials()
            throws CoreException
    {
    	String mhost = getHost();
    	String mport = getPort();
    	String mclientId = getClientId();
    	String mprecision = getPercision();
    	
System.out.println("xxxx mhost=" + mhost);
System.out.println("xxxx mport=" + mport);
System.out.println("xxxx mclientId=" + mclientId);
System.out.println("xxxx mprecision(market data precision on BigDecimal)=" + mprecision);

      return InteractiveBrokersFeedCredentials.getInstance(getHost(),Integer.parseInt(getPort()), Integer.parseInt(getClientId()), Integer.parseInt(getPercision()));
    }
    
    private String host="127.0.0.1";
    private String port="7496";  // connect to TWS
    //private String port="4001";  // connect to IB gateway
    private String clientId="0";
    private String percision="2";  // man, this sucks, took me a night's work
    
//	private static int defaultClientId = ConfigurationUtil.getBaseConfig().getInt("ib.defaultClientId"); //0
//	private static int port = ConfigurationUtil.getBaseConfig().getInt("ib.port"); //7496;//
//	private static String host = ConfigurationUtil.getBaseConfig().getString("ib.host"); // "127.0.0.1";
//	private static long connectionTimeout = ConfigurationUtil.getBaseConfig().getInt("ib.connectionTimeout"); //10000;//
    
	public void loadIBConfProperties()
	{
		Properties prop = System.getProperties();
		
        // load IB conf properties file.
        try {
        	//prop.load(this.getClass().getResourceAsStream("conf-base.properties"));
        	String ibconf = System.getProperty("ibconf.file");
        	prop.load(new FileInputStream(ibconf));

        	if (prop.containsKey("ib.clientId")) {
        		setClientId(prop.getProperty("ib.clientId"));
        	}

        	if (prop.containsKey("ib.host")) {
        		setHost(prop.getProperty("ib.host"));
        	}

        	if (prop.containsKey("ib.port")) {
        		setPort(prop.getProperty("ib.port"));
        	}

        } catch (IOException e) {
        	System.err.println("ERROR: loading IB conf-base.properties error " + e.toString());
        	e.printStackTrace();
        }

		System.out.println("\n===========loadIBConfProperties(begin)================== ");
        prop.list(System.out);
        System.out.println("\n===========loadIBConfProperties(end)==================== ");
	}

}
