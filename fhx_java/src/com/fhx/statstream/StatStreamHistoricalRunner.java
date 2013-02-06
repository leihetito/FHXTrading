package com.fhx.statstream;

import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.math.BigDecimal;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.StringTokenizer;
import java.util.TreeMap;
import java.util.concurrent.ScheduledThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

import org.apache.log4j.Logger;
import org.apache.log4j.PropertyConfigurator;
import org.marketcetera.marketdata.interactivebrokers.LatestMarketData;
import org.rosuda.REngine.REXP;
import org.rosuda.REngine.REXPMismatchException;
import org.rosuda.REngine.REngineException;
import org.rosuda.REngine.RList;
import org.rosuda.REngine.Rserve.RserveException;

import com.fhx.service.ib.order.IBOrderSender;
import com.fhx.util.StatStreamUtil;

/*
 * Singleton class that hold one sliding window worth of data across all symbols
 * When the container is full, the data is served to the StatStreamProto
 */
public class StatStreamHistoricalRunner extends StatStreamServiceBase {

	private static Logger log = Logger.getLogger(StatStreamHistoricalRunner.class);

	private int basicWindowCnt = 1;
	private int basicWindowSize = -1;
	private int bwNum = -1;
	private int m_tickStreamSize = 0;
	private int mktOpenHr,mktOpenMin,mktOpenSec,mktClsHr,mktClsMin,mktClsSec;
	private Date mktOpenTime, mktCloseTime;
	private final Properties config = new Properties();
	private static StatStreamHistoricalService ssService = new StatStreamHistoricalService();
	private static StatStreamHistoricalRunner runner = new StatStreamHistoricalRunner();
	
	private Map<String, List<LatestMarketData>> tickDataCache = new HashMap<String, List<LatestMarketData>>();
	private List<String> symbols = new ArrayList<String>();
	
	/*
	 * Use TreeMap to guarantee ordering Example: IBM -> [LatestMarketData1,
	 * LatestMarketData2, LatestMarketData3, ... ]
	 */
	private Map<String, List<LatestMarketData>> basicWindowTicks = new TreeMap<String, List<LatestMarketData>>();

	private StatStreamHistoricalRunner() {	
		try {
			ssService.init();

			PropertyConfigurator.configure("conf/log4j.properties");

			config.load(new FileInputStream("conf/statstream.properties"));

			basicWindowSize = Integer.parseInt(config.getProperty("BASIC_WINDOW_SIZE","24"));
			
			String runDateStr = config.getProperty("RUN_DATE","20120217");
			SimpleDateFormat formatter = new SimpleDateFormat("yyyyMMdd");
			Date runDate = (Date)formatter.parse(runDateStr);  
			
			mktOpenHr = Integer.parseInt(config.getProperty("MKT_OPEN_HR","9"));
			mktOpenMin = Integer.parseInt(config.getProperty("MKT_OPEN_MIN","30"));
			mktOpenSec = Integer.parseInt(config.getProperty("MKT_OPEN_SEC","0"));
			mktClsHr = Integer.parseInt(config.getProperty("MKT_CLOSE_HR","16"));
			mktClsMin = Integer.parseInt(config.getProperty("MKT_CLOSE_MIN","0"));
			mktClsSec = Integer.parseInt(config.getProperty("MKT_CLOSE_SEC","0"));
			
			Calendar cal = Calendar.getInstance();
			cal.setTime(runDate);
			cal.set(Calendar.HOUR_OF_DAY, mktOpenHr);
			cal.set(Calendar.MINUTE, mktOpenMin);
			cal.set(Calendar.SECOND, mktOpenSec);
			mktOpenTime = cal.getTime();
			
			cal.set(Calendar.HOUR_OF_DAY, mktClsHr);
			cal.set(Calendar.MINUTE, mktClsMin);
			cal.set(Calendar.SECOND, mktClsSec);
			mktCloseTime = cal.getTime();
			
			log.info("Setting market period between " + mktOpenTime.toString() + " and " + mktCloseTime.toString());
			
		} catch (Exception e1) {
			System.out.format("ERROR HERE\n");
			log.error("Error loading config file\n");
			e1.printStackTrace();
			System.exit(1);
		}
	}
	
	public static StatStreamHistoricalRunner getInstance() {
		if(runner == null) 
			new StatStreamHistoricalRunner();
 
		return runner;
	}

	/*
	 * Replay all the ticks from the tick data files
	 */
	public void gatherAllHistTicks() {
		String dataDir = config.getProperty("TICKDATA_DIR");
		if (dataDir == null) {
			dataDir = "/export/data/";
		}

		symbols = StatStreamUtil.getAllSymbols(config);
		
		Iterator<String> iter = symbols.iterator();
		while (iter.hasNext()) {
			String symbol = (String) iter.next();

			if (tickDataCache.containsKey(symbol)) {
				log.error("Should not happen, found duplicate symbol " + symbol
						+ " in tick data directory");
			} else {
				List<LatestMarketData> tickStream = readTicksFromFile(dataDir,
						symbol);
				tickDataCache.put(symbol, tickStream);
			}
		}
	}

	private List<LatestMarketData> readTicksFromFile(String dataDir, String symbol) {
		List<LatestMarketData> tickStream = new ArrayList<LatestMarketData>();
		StringTokenizer st;

		final SimpleDateFormat SDF = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS");
		String dateStr = config.getProperty("RUN_DATE","20120217");
		String fileName = dataDir + dateStr+ "/" + symbol + "_"+dateStr+"_tick.csv";
		
		log.info("Loading tick data file " + fileName);

		FileReader fileReader;
		try {
			fileReader = new FileReader(fileName);

			BufferedReader bufferedReader = new BufferedReader(fileReader);

			// skip header
			bufferedReader.readLine();

			String line = null;
			while ((line = bufferedReader.readLine()) != null) {
				st = new StringTokenizer(line, ",");

				LatestMarketData lmd = new LatestMarketData(symbol);

				st.nextToken(); //symbol
				lmd.setBidPrice(new BigDecimal(Double.parseDouble(st.nextToken())));  //bid
				lmd.setOfferPrice(new BigDecimal(Double.parseDouble(st.nextToken())));//ask
				st.nextToken(); //trade price
				st.nextToken(); //trade size
				
				Date time = SDF.parse(st.nextToken());
				if(time.before(mktOpenTime) || time.after(mktCloseTime))
					continue;
				
				lmd.setTime(time);   //source time

				tickStream.add(lmd);
			}

			bufferedReader.close();
			fileReader.close();

		} catch (FileNotFoundException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			System.exit(-1);
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (ParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}

		log.info("Read " + tickStream.size() + " ticks for " + fileName);
		m_tickStreamSize = tickStream.size();
		return tickStream;
	}

	public void flushBasicWindow() {
		log.info("Serving basic window # " + basicWindowCnt	+ " to the StatStream model");

		/*
		 * format basic window data and serve it to StatStream model
		 */
		ssService.tick(basicWindowTicks, basicWindowCnt++);

		log.info("Flushing basic window " + basicWindowCnt
				+ ", invoking StatStreamService");
		log.info("Size of basic window = "
				+ basicWindowTicks.values().iterator().next().size());
		basicWindowTicks.clear();
	}

	public void addATick(Map<String, LatestMarketData> aTick) {
		String symbol = "";
		LatestMarketData data;

		for (Map.Entry<String, LatestMarketData> tick : aTick.entrySet()) {
			symbol = tick.getKey();
			data = tick.getValue();

			List<LatestMarketData> ticksPerSymbol = basicWindowTicks.get(symbol);
			if (ticksPerSymbol == null) {
				log.info("initializing arraylist for symbol " + symbol);
				ticksPerSymbol = new ArrayList<LatestMarketData>();
				ticksPerSymbol.add(data);
				basicWindowTicks.put(symbol, ticksPerSymbol);
			} else {
				ticksPerSymbol.add(data);
			}
		}

		if (basicWindowTicks.get(symbol).size() >= basicWindowSize)
			flushBasicWindow();
	}
	
	public void tick() {
		log.info("Processing basic window " + bwNum);
		if(basicWindowSize*bwNum >= m_tickStreamSize ) {
			log.info("Reached eod of the data stream, simulation done...");
			System.exit(0);
		}
		
		bwNum++;
		
		RList bwList = StatStreamUtil.getBasicWindowRList(tickDataCache, symbols, bwNum, basicWindowSize);

		try {
			conn.assign("streamData", REXP.createDataFrame(bwList));

			String corrFunc = "corr_report <- process_basic_window3(streamData)";
			
			log.info("calling process_basic_window");	
			
			REXP retVal = conn.parseAndEval(corrFunc);
			conn.assign("prev_value_list", retVal);
		
			//log.info(conn.eval("paste(capture.output(print(order_list)),collapse='\\n')").asString());
			
			/*
			 * parsing the order list
			 * retVal.asList()[0] is the order list of R data frame
			 * 		"Symbol",	"OrderType",	"Quantity",	"Price",	"BasicWinNum", "Time", "PnL"
			 * 1	ABC			Buy				100			10			1			12:00:00	-
			 * 1	CBA			Sell			100			10			1			12:00:00	-  
			 */			
			RList orderList = retVal.asList().at(0).asList();
			if(orderList != null && orderList.size() > 0 ) {
				int numRows = orderList.at(0).asStrings().length;
				
				String[] symbolColVal = orderList.at(0).asStrings();
				String[] sideColVal = orderList.at(1).asStrings();
				double[] qtyColVal = orderList.at(2).asDoubles();	//qty will be rounded into a round lot
				double[] priceColVal = orderList.at(3).asDoubles(); //TODO: use mid-px at this point to place order

				for(int i = 0; i < numRows; i++) {
					addOrder(symbolColVal[i], 
							 sideColVal[i], 
							 (int)qtyColVal[i],
							 priceColVal[i]);
				}
			}	
			
		} catch (RserveException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (REngineException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (REXPMismatchException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (Exception e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		
	}
	
	public boolean tick(Map<String, List<LatestMarketData>> aTick, int bwNum) {
		return true;
	}

	public static void main(String... aArgs) {
		final StatStreamHistoricalRunner runner = StatStreamHistoricalRunner.getInstance();
		runner.gatherAllHistTicks();

		new Thread(new IBOrderSender(getOrderQ())).start();
		
		// send update to work thread every 5 seconds
		ScheduledThreadPoolExecutor stpe = new ScheduledThreadPoolExecutor(5);

		// start the market data update thread
		stpe.scheduleAtFixedRate(new Runnable() {
			@Override
			public void run() {
				log.info("Running historical tick simulation");
					
				runner.tick();
			}
		}, 0, 5, TimeUnit.SECONDS);
	}

}
