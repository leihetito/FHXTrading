package com.fhx.util;

import java.io.FileInputStream;
import java.io.InputStream;
import java.util.Enumeration;
import java.util.Locale;
import java.util.Properties;
import java.util.ResourceBundle;

import org.apache.log4j.Logger;

public class ConfPropertiesLoader {

	private final static ConfPropertiesLoader confPL = new ConfPropertiesLoader();
	public final static String rootConfPath = "/export/etc/fhx/metc";
	
	private Properties coreProp = new Properties();
	
    private static final boolean THROW_ON_LOAD_FAILURE = true;
    private static final boolean LOAD_AS_RESOURCE_BUNDLE = false;
    private static final String SUFFIX = ".properties";
    
    
    
	private ConfPropertiesLoader () {
		coreProp.putAll( loadProperties(rootConfPath + "/FHXCoreConfig.properties") );
		initLogging();
	}
	
	public static ConfPropertiesLoader getInstance() {
		return confPL;
	}
	
	private void initLogging () {
		if (System.getProperty(	"log4j.configuration" ) == null ) {
			System.out.println(" ====>Init Logging brand new: "  );
			System.setProperty("log4j.configuration", "file:" + rootConfPath + "/" + getProperty("com.fhx.log4j.config"));
			System.out.println(" ====>Set Log4j Config Path: " +   "file:" + rootConfPath + "/" + getProperty("com.fhx.log4j.config"));
			
		}
		System.setProperty("FHX_LOGDIR", getProperty("com.fhx.logging.dir"));
		System.out.println("====> FHX logging dir is: " + getProperty("com.fhx.logging.dir") );
	}
	
	
	
	public Properties getProperties () {
		return coreProp;
	}
	
	
	public String getProperty (String key) {
		return coreProp.getProperty(key);
	}
	
	
	public int getPropertyAsInt (String key) {
		return Integer.parseInt( coreProp.getProperty(key) );
	}
	
	
	
	public String getLoggerConfig () {
		return System.getProperty(	"log4j.configuration" ) ;
	}
	
	public String getQuickFixConfig() {
		return rootConfPath + "/" + coreProp.getProperty("com.fhx.quickfix.server.config");
	}
	

    /**
     * Looks up a resource named 'name' in the classpath. The resource must map
     * to a file with .properties extention. The name is assumed to be absolute
     * and can use either "/" or "." for package segment separation with an
     * optional leading "/" and optional ".properties" suffix. Thus, the
     * following names refer to the same resource:
     * <pre>
     * some.pkg.Resource
     * some.pkg.Resource.properties
     * some/pkg/Resource
     * some/pkg/Resource.properties
     * /some/pkg/Resource
     * /some/pkg/Resource.properties
     * </pre>
     * 
     * @param name classpath resource name [may not be null]
     * @param loader classloader through which to load the resource [null
     * is equivalent to the application loader]
     * 
     * @return resource converted to java.util.Properties [may be null if the
     * resource was not found and THROW_ON_LOAD_FAILURE is false]
     * @throws IllegalArgumentException if the resource was not found and
     * THROW_ON_LOAD_FAILURE is true
     */
    protected  Properties loadProperties (String name, ClassLoader loader)
    {
        if (name == null)
            throw new IllegalArgumentException ("null input: name");
        
        if (name.startsWith ("/")) {
        //    name = name.substring (1);
        }
            
        if (name.endsWith (SUFFIX))
            name = name.substring (0, name.length () - SUFFIX.length ());
        
        Properties result = null;
        
        InputStream in = null;
        try
        {
            if (loader == null) loader = ClassLoader.getSystemClassLoader ();
            
            if (LOAD_AS_RESOURCE_BUNDLE)
            {    
                name = name.replace ('/', '.');
                // Throws MissingResourceException on lookup failures:
                final ResourceBundle rb = ResourceBundle.getBundle (name,
                    Locale.getDefault (), loader);
                
                result = new Properties ();
                for (Enumeration keys = rb.getKeys (); keys.hasMoreElements ();)
                {
                    final String key = (String) keys.nextElement ();
                    final String value = rb.getString (key);
                    
                    result.put (key, value);
                } 
            }
            else
            {
                if (! name.endsWith (SUFFIX))
                    name = name.concat (SUFFIX);
                
            	FileInputStream inProp = new FileInputStream(name);
                result = new Properties ();
            	result.load(inProp);
            	
            	/*
                name = name.replace ('.', '/');
                

                                
                // Returns null on lookup failures:
                in = loader.getResourceAsStream (name);
                if (in != null)
                {
                    result = new Properties ();
                    result.load (in); // Can throw IOException
                }
                */
            }
        }
        catch (Exception e)
        {
            result = null;
            e.printStackTrace();
        }
        finally
        {
            if (in != null) try { in.close (); } catch (Throwable ignore) {}
        }
        
        if (THROW_ON_LOAD_FAILURE && (result == null))
        {
            throw new IllegalArgumentException ("could not load [" + name + "]"+
                " as " + (LOAD_AS_RESOURCE_BUNDLE
                ? "a resource bundle"
                : "a classloader resource"));
        }
        
        return result;
    }
    
    /**
     * A convenience overload of {@link #loadProperties(String, ClassLoader)}
     * that uses the current thread's context classloader.
     */
    protected Properties loadProperties (final String name)
    {
        return loadProperties (name,
            Thread.currentThread ().getContextClassLoader ());
    }
        


    
    public static void main(String[] argv) {
    	ConfPropertiesLoader loader = ConfPropertiesLoader.getInstance();
    	Properties test = loader.getProperties();
    	loader.getLoggerConfig();
    	System.out.println("\n The properties are:" + loader.getProperty("org.marketcetera.marketdata.fhx.start_date"));
    	
    	Logger logger = Logger.getLogger(ConfPropertiesLoader.class);
    	
    	logger.debug("debuging is good");
    }
}
