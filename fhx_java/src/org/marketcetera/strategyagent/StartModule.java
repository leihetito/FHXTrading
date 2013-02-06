package org.marketcetera.strategyagent;

import org.marketcetera.util.misc.ClassVersion;
import org.marketcetera.module.ModuleManagerMXBean;

/* $License$ */
/**
 * The startModule command. This command starts the module
 * with the specified URN.
 *
 * @author anshul@marketcetera.com
 */
@ClassVersion("$Id: StartModule.java 9860 2008-10-10 22:00:53Z klim $") //$NON-NLS-1$
final class StartModule extends CommandRunner {
    /**
     * Creates an instance.
     */
    protected StartModule() {
        super("startModule");  //$NON-NLS-1$
    }

    @Override
    final Object runCommand(ModuleManagerMXBean inManager, String inCmdString) {
    	
System.out.println("SSSSSS inCmdString="+inCmdString) ;   	
        inManager.start(inCmdString);
        //Return true as it looks better in the log message.
        return true;
    }
}