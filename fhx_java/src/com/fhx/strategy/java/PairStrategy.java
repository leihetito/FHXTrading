package com.fhx.strategy.java;

import static org.apache.commons.csv.CSVStrategy.EXCEL_STRATEGY;

import org.apache.commons.csv.CSVParser;
import org.marketcetera.event.AskEvent;
import org.marketcetera.event.BidEvent;
import org.marketcetera.event.QuoteEvent;
import org.marketcetera.event.TradeEvent;
import org.marketcetera.marketdata.MarketDataRequest;
import org.marketcetera.marketdata.MarketDataRequest.Content;
import org.marketcetera.strategy.java.Strategy;
import org.marketcetera.trade.*;
import org.marketcetera.util.log.SLF4JLoggerProxy;

import com.fhx.strategy.java.IModel;

//import org.marketcetera.quickfix.FIXDataDictionary;
//import org.marketcetera.quickfix.FIXMessageFactory;
//import org.marketcetera.quickfix.FIXMessageUtil;
//import org.marketcetera.quickfix.FIXVersion;
//import org.marketcetera.quickfix.messagefactory.FIXMessageAugmentor;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Calendar;
import java.util.Date;
import java.util.GregorianCalendar;
import java.util.Map;
import java.util.Properties;
import java.util.Random;
import java.util.List;
import java.util.ArrayList;
import java.util.Collections;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.logging.FileHandler;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.logging.SimpleFormatter;
import java.security.SecureRandom;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileReader;
import java.io.IOException;
import java.math.BigDecimal;

/**
 * ####################################### # Very simple pairs-trading strategy
 * 1. use 1 minute intraday time series data to run co-integration 2. use OU
 * model parameter to initialize trading strategy 3. simulate using a
 * CSVMarketData feed #######################################
 * 
 * 1. loading OU model parameters for each pair: BidirStrategy.java
 * "","Pair","Industry","ADF.pvalue"
 * ,"ts.start","ts.end","lamda","mu","sigma","beta"
 * "4274","S/VZ","XLK",0.0113707144524314
 * ,"2011-05-24 09:59:00","2011-05-24 15:30:00"
 * ,37.2527144930539,0.00119677399073219,0.331105691288937,0.156354525582822
 * 
 * 2. for each pair, load the model parameters, initialize orderList that stores
 * the orders traded for each pair Map<String, PairModel> pairModelParms
 * Map<String, List<Orders>> pairOrders
 * 
 * 3. request for market data for all symbols
 * 
 * 4. for each onQuote(onBid, onAsk) and onTrade Event, calculate zscore for the
 * pair: if |zscore| > 2, Buy/Sell pair, if no Open position.
 * 
 * - genOrders - if (pairOrders.get(pair).size > 0) // has Open orders,
 */

public class PairStrategy extends Strategy {

	// private static final String SYMBOLS = "MMM,AA,AXP,T,BAC,BA,CAT,CVX,CSCO,KO,DD,XOM,GE,HPQ,HD,INTC,IBM,JNJ,JPM,KFT,MCD,MRK,MSFT,PFE,PG,TRV,UTX,VZ,WMT,DIS";
	private static final String SYMBOLS = "IBM,GS,AAPL";
	private static final String MARKET_DATA_PROVIDER = "contrib_csv"; 

    public static final String APP_DIR_PROP="appDir"; //$NON-NLS-1$
    public static final String APP_DIR;
    public static final String CONF_DIR;
    
    public static DateFormat df  = new SimpleDateFormat("yyyyMMdd");
    public static String TRADE_DATE;
    public static String PARM_DATE;
    public static String PARM_DIR;
    public static String DATA_DIR;
    public static String SECTOR;
    	
    static {
        String appDir = System.getProperty(APP_DIR_PROP);
        if (appDir==null) {
            appDir = System.getProperty("user.home")+File.separator;
        }
        if (!appDir.endsWith(File.separator)) {
            appDir += File.separator;
        }
        APP_DIR = appDir;
        CONF_DIR = APP_DIR + "conf" + File.separator;
        
        System.out.println("xxxx APP_DIR=" + APP_DIR);
        System.out.println("xxxx CONF_DIR=" + CONF_DIR);
        
        // load properties file.
        Properties appProp = new Properties();
        try {
        	appProp.load(new FileInputStream(CONF_DIR+"parms.properties"));
        	
        	TRADE_DATE = appProp.getProperty("tradeDate"); 
        	PARM_DATE = appProp.getProperty("parmDate"); 
    		PARM_DIR=APP_DIR+"model" + File.separator + PARM_DATE+File.separator; 
    		DATA_DIR=APP_DIR+"data" + File.separator + TRADE_DATE+File.separator; 
    		SECTOR = appProp.getProperty("sector");
    			
            System.out.println("xxxx TRADE_DATE=" + TRADE_DATE);
            System.out.println("xxxx PARM_DIR=" + PARM_DIR);
            System.out.println("xxxx DATA_DIR=" + DATA_DIR);
            System.out.println("xxxx SECTOR=" + SECTOR);
            
        } catch (IOException e) {
        	e.printStackTrace();
        }
    }
    
	/**
	 * Executed when the strategy is started. Use this method to set up data
	 * flows and other initialization tasks.
	 */
	@Override
	public void onStart() {

		System.getProperties().list(System.out);

		System.out.println("XXXX PairStrategy -> onStart() ");
		
//		requestMarketData(MarketDataRequest.newRequest().withSymbols(SYMBOLS)
//				.fromProvider(MARKET_DATA_PROVIDER).withContent(
//						Content.LATEST_TICK, Content.TOP_OF_BOOK));
//		System.out.println("XXXX requestMarketData Done. ");

		try {
			CSVParser parser = new CSVParser(
					new FileReader(new File(PARM_DIR,
							"fhx_pair_parms_"+PARM_DATE +"_"+SECTOR+ EXTENSION)), 
							EXCEL_STRATEGY);
			
			String[][] all = parser.getAllValues();

			// traverse through it
			System.out.println("Header	:	" + Arrays.toString(all[0]));
			System.out.println("Row1:		" + Arrays.toString(all[1]));
			System.out.println("Column:	" + all[0].length);
			System.out.println("Column:	" + all[0].length);
			System.out.println("Row:			" + all.length);

			/*
			 * Header: [, Pair, Industry, ADF.pvalue, ts.start, ts.end, lamda,mu, sigma, beta] 
			 * Row1:[1, ACE/AIG, xlf, 0.0429359714074579,2011-05-18 09:59:00, 2011-05-18 15:30:00, 11.3516734065991,0.0194240685055339, 0.979161110768504, 2.24997403759064]
			 * Column:10 
			 * Row:3768
			 */

			if (all != null) {
				String[] header = new String[all[0].length];
				System.arraycopy(all[0], 0, header, 0, all[0].length);

				for (String[] row : all) {
					String pair = row[1]; // row[0] is rowId

					// 1. initialize order List
					pairOrderMap.put(pair, new ArrayList<Order>());

					// 2. initialize model parameter
					Properties p = new Properties();
					for (int j = 1; j < row.length; j++) { // skip header row:
						// all[0] contains header
						System.out.println("key=" + all[0][j] + ",value=" + row[j]);
						p.put(header[j], row[j]);
					}

					IModel pmodel = new PairModel(pair, p);
					pairModelParms.put(pair, pmodel);
				}
			}
		} catch (Exception e) {
			e.printStackTrace();
		} finally {
			// close file
			System.out.println("XXXX onStart() Done. ");
		}
	}

	/**
	 * Executed when the strategy receives an ask event.
	 * 
	 * @param inAsk
	 *            the ask event.
	 */
	@Override
	public void onAsk(AskEvent inAsk) {
		// warn("Ask " + inAsk);
		System.out.println("XXXX inAsk= " + inAsk);
		System.out.println("XXXX HAHA inAsk= " + inAsk.getTimestampAsDate());

		// ` calculatePairSpread(inAsk, "Ask");
	}

	/**
	 * Executed when the strategy receives a bid event.
	 * 
	 * @param inBid
	 *            the bid event.
	 */
	@Override
	public void onBid(BidEvent inBid) {
		// warn("Bid " + inBid);
		System.out.println("XXXX onBid= " + inBid);
		System.out.println("XXXX HEHE inBid= " + inBid.getTimestampAsDate());

		// calculatePairSpread(inBid, "Bid");
	}

	// compute the spread for all relevant pairs, use IModel params to compute
	// zscore.
	private void calculatePairSpread(QuoteEvent quote, String description) {
		// cache the latest tick, delegate to another thread (QuoteEvent,
		// IModel)
		System.out.println("$$$$ calculateCurrentSpread: " + quote);

		String symbol = quote.getSymbolAsString();
		double price = quote.getPrice().floatValue();

		System.out.println("$$$$ symbol: " + symbol + ", price=" + price + ", "
				+ description);
		// add to QuoteEvent cache

		// search for the counterpart to get all pairs contains this Symbol
		// HOW TO FIND ALL THE PAIRS FOR THIS SYMBOL QUICKLY?? FastHashMap? or
		// search algorithm

		// 3. get the pair Model parameter.
		// String pair="ACE/AIG"; // VZ/T
		String[] pairs = getAllPairs(symbol);
		System.out.println("$$$$ got pairs: HOW MANY:" + pairs.length);

		for (String pair : pairs) {

			IModel model = pairModelParms.get(pair);
			System.out.print("#### ");
			model.getProperties().list(System.out);

			// 4. using model properties to compute the zscore <- (tickSpread -
			// mu)/sigma

			// 5. if no open orders and zscore > 2 s.d, gen entry orders
			// else if mean is reached, close out
			List<Order> hasOrders = pairModelParms.get(pair).getOrders();

			if (hasOrders.size() == 0) {
				// entry
				// if zscore > 2, SELL spread: short p[0], buy p[1]
				// else if zscore < -2, Buy spread: buy p[0], short p[1]

				System.out.println("==== hasOrders=" + hasOrders.size());
			} else {
				// if zscore == mu, exit

				// update Position

			}
		}
	}

	public String[] getAllPairs(String symbol) {
		List<String> list = new ArrayList<String>();
		// String[pairModelParms.keySet().size()]);
		// a linear search

		for (String pair : pairModelParms.keySet()) {
			String[] symbols = pair.split("/");
			if (symbol.equals(symbols[0]) || symbol.equals(symbols[1])) {

				System.out.println("$$$$ got pairs:" + pair);
				list.add(pair);
			}
		}
		return list.toArray(new String[list.size()]);
	}

	/*
	 * @see
	 * org.marketcetera.strategy.RunningStrategy#onTrade(org.marketcetera.event
	 * .TradeEvent)
	 */
	@Override
	public void onTrade(TradeEvent inTrade) {
		// this would be used as Quote event for CSV market data simulation
		warn("onTrade " + inTrade);
		System.out.println("XXXX PairStrategy->onTrade() inTrade=" + inTrade);
		
		SLF4JLoggerProxy.info(this, inTrade.toString());
	}

	public void onExecutionReport(ExecutionReport inExecutionReport) {
		// if for close position, calculate PnL

		System.out.println("XXXX PairStrategy->ExecutionReport() inExecutionReport=" + inExecutionReport);

		// String readablemsg = new
		// AnalyzedMessage(getDataDictionary(),inExecutionReport).toString();
		// create a FIX
		// Message readablemsg = inExecutionReport;
		// System.out.println("XXXX OrderSlicer->ExecutionReport() readablemsg="
		// + readablemsg);
	}

	/*
	 * @see
	 * org.marketcetera.strategy.RunningStrategy#onCancel(org.marketcetera.trade
	 * .OrderCancelReject)
	 */
	@Override
	public void onCancelReject(OrderCancelReject inCancel) {
		// clear orders

		System.out.println("XXXX PairStrategy->onCancelReject() inCancel="
				+ inCancel);
	}

	/*
	 * @see org.marketcetera.strategy.RunningStrategy#onOther(java.lang.Object)
	 */
	@Override
	public void onOther(Object inEvent) {
		System.out.println("XXXX PairStrategy->onOther() inEvent=" + inEvent);
	}

	/**
	 * @return Order to be sent
	 */
	private Order generateOrders(Side side, String symbol, int qty, double price) {
		List<Order> list = new ArrayList<Order>();

		OrderSingle order = Factory.getInstance().createOrderSingle();
		order.setOrderType(OrderType.Market);
		order.setQuantity(new BigDecimal(qty));
		order.setSide(Side.SellShort);
		// order.setSide(Side.Buy);
		order.setSymbol(new MSymbol(symbol));
		order.setTimeInForce(TimeInForce.Day);

		// request a callback for each order
		requestCallbackAfter(1000, order); // set send time, 1 second later

		return order;
	}

	/**
	 * Executed when the strategy receives a callback requested via
	 * {@link #requestCallbackAt(java.util.Date, Object)} or
	 * {@link #requestCallbackAfter(long, Object)}. All timer callbacks come
	 * with the data supplied when requesting callback, as an argument.
	 * 
	 * @param inData
	 *            the callback data
	 */
	@Override
	public void onCallback(Object inData) {
		// this should close the Open positions based on lamda value.

		sendOrder((OrderSingle) inData);
		int sent = mNumSent.incrementAndGet();
		info("sent order " + sent + "/" + mNumPartitions);

		System.out.println("XXXX PairStrategy->onCallback() order=" + inData);
	}

	protected static Logger logger;
	protected static String logFilePath;
	private static FileHandler fileTxt;
	private static SimpleFormatter formatterTxt;
	
	private void configureLogging(String logFilePath) {
		
		logger = Logger.getLogger(PairStrategy.class.getName());
		logger.setLevel(Level.INFO);
		try{
			fileTxt = new FileHandler(logFilePath);
			formatterTxt = new SimpleFormatter();
			fileTxt.setFormatter(formatterTxt);
			logger.addHandler(fileTxt);
	
		}catch(IOException e){
			System.out.println("Problem initialising logger...");
			e.printStackTrace();
		}
	}
	
	private volatile int mNumPartitions;
	private final AtomicInteger mNumSent = new AtomicInteger(0);
	private final static Random sRandom = new SecureRandom();

	// pair model properties
	private Map<String, IModel> pairModelParms = new ConcurrentHashMap<String, IModel>();

	// order list
	private Map<String, List<Order>> pairOrderMap = new ConcurrentHashMap<String, List<Order>>();
	private String dataDir = "C:/Users/Mandy/data/csv";
	private static final String EXTENSION = ".csv";

}
