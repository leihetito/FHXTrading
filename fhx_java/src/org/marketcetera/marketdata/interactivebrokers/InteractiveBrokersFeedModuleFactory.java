package org.marketcetera.marketdata.interactivebrokers;

import static org.marketcetera.marketdata.interactivebrokers.Messages.PROVIDER_DESCRIPTION;

import java.io.IOException;
import java.util.Arrays;
import java.util.Properties;

import org.marketcetera.core.ClassVersion;
import org.marketcetera.core.CoreException;
import org.marketcetera.module.ModuleCreationException;
import org.marketcetera.module.ModuleFactory;
import org.marketcetera.module.ModuleURN;

/* $License$ */

/**
 * <code>ModuleFactory</code> implementation for the <code>MarketceteraFeed</code> market data provider.
 *
 * @author <a href="mailto:colin@marketcetera.com">Colin DuPlantis</a>
 * @version $Id: MarketceteraFeedModuleFactory.java 10390 2009-03-07 04:53:17Z colin $
 * @since 1.0.0
 */
@ClassVersion("$Id: MarketceteraFeedModuleFactory.java 10390 2009-03-07 04:53:17Z colin $") //$NON-NLS-1$
public class InteractiveBrokersFeedModuleFactory
        extends ModuleFactory
{
    /**
     * Create a new MarketceteraFeedModuleFactory instance.
     */
    public InteractiveBrokersFeedModuleFactory()
    {
        super(PROVIDER_URN,
              PROVIDER_DESCRIPTION,
              false,
              false);
        
    }
    /* (non-Javadoc)
     * @see org.marketcetera.module.ModuleFactory#create(java.lang.Object[])
     */
    @Override
    public InteractiveBrokersFeedModule create(Object... inParameters)
            throws ModuleCreationException
    {
        try {
            return new InteractiveBrokersFeedModule();
        } catch (CoreException e) {
            throw new ModuleCreationException(e.getI18NBoundMessage());
        }
    }
    public static final String IDENTIFIER = "interactivebrokers";  //$NON-NLS-1$
    public static final ModuleURN PROVIDER_URN = new ModuleURN("metc:mdata:" + IDENTIFIER);  //$NON-NLS-1$
    public static final ModuleURN INSTANCE_URN = new ModuleURN(PROVIDER_URN,
                                                               "single");  //$NON-NLS-1$
}
