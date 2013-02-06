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

import org.apache.log4j.Logger;
import org.apache.log4j.PropertyConfigurator;
import org.marketcetera.marketdata.interactivebrokers.LatestMarketData;
import org.rosuda.REngine.REXP;
import org.rosuda.REngine.REXPMismatchException;
import org.rosuda.REngine.REngineException;
import org.rosuda.REngine.RList;
import org.rosuda.REngine.Rserve.RserveException;

import com.fhx.util.StatStreamUtil;

public class StatStreamHistoricalService extends StatStreamServiceBase {
	
	private static Logger log = Logger.getLogger(StatStreamHistoricalService.class);

	private int basicWindowSize = -1;
	private int mktOpenHr,mktOpenMin,mktOpenSec,mktClsHr,mktClsMin,mktClsSec;
	private Date mktOpenTime, mktCloseTime;
	private final Properties config = new Properties();
	
	private Map<String, List<LatestMarketData>> tickDataCache = new HashMap<String, List<LatestMarketData>>();
	private List<String> symbols = new ArrayList<String>();
	private Map<String, List<LatestMarketData>> basicWinTicks = new HashMap<String, List<LatestMarketData>>();
	
	public StatStreamHistoricalService() {
		try {
			super.init();

			PropertyConfigurator.configure("conf/log4j.properties");

			config.load(new FileInputStream("conf/statstream.properties"));

			basicWindowSize = Integer.parseInt(config.getProperty("BASIC_WINDOW_SIZE","24"));
			
			SimpleDateFormat formatter = new SimpleDateFormat("yyyyMMdd");
			String runDateStr = config.getProperty("RUN_DATE", formatter.format(new Date()));
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
			
			gatherAllHistTicks();			
			
		} catch (Exception e1) {
			System.out.format("ERROR HERE\n");
			log.error("Error loading config file\n");
			e1.printStackTrace();
			System.exit(1);
		}
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
		final SimpleDateFormat formatter = new SimpleDateFormat("yyyyMMdd");
		String dateStr = config.getProperty("RUN_DATE",formatter.format(new Date()));
		String fileName = dataDir + dateStr + "_md/" + symbol + "_"+dateStr+"_tick.csv";
		
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
		return tickStream;
	}

	@Override
	public boolean tick(Map<String, List<LatestMarketData>> aTick, int bwNum) {
		log.info("Processing basic window " + bwNum);
		
		basicWinTicks.clear();
		Iterator<Map.Entry<String, List<LatestMarketData>>> iter = tickDataCache.entrySet().iterator();
		while(iter.hasNext()) {
			Map.Entry<String, List<LatestMarketData>> tick = (Map.Entry<String, List<LatestMarketData>>)iter.next();
			List<LatestMarketData> basicWinList = tick.getValue().subList(basicWindowSize*bwNum, basicWindowSize*(bwNum+1));
			basicWinTicks.put(tick.getKey(), basicWinList);
		}
		RList bwList = StatStreamUtil.getBasicWindowRList(basicWinTicks, symbols, bwNum, basicWindowSize);

		try {
			// source the func file, do this everytime so the function file can be updated real-time, COOL
			String funcRFile = config.getProperty("R_FUNC_SCRIPT");
			String cmdStr = "source('"+funcRFile+"')";
			
			log.info("try to source R (func) file: " + cmdStr);
			conn.parseAndEval(cmdStr);
			
			// next process func call
			conn.assign("streamData", REXP.createDataFrame(bwList));
			String execFunc = config.getProperty("R_FUNC_EXEC");
			
			if("True".equals(config.getProperty("TEST_ORDER_MODE")))
				execFunc = config.getProperty("R_FUNC_TEST_ORDER");
			
			String funcExpr = String.format("%s(%s, %d)", execFunc, "streamData", bwNum); 			
			log.info("R_FUNC_EXEC: " + funcExpr);
			
			REXP retVal = conn.parseAndEval(funcExpr);
		
			log.info("order_list from R: " +conn.eval("paste(capture.output(print(do.call(rbind,entry_order_list))),collapse='\\n')").asString());
			
			//log.info(conn.eval("paste(capture.output(print(order_list)),collapse='\\n')").asString());
			/*
			 * parsing the order list
			 * retVal.asList()[0] is the order list of R data frame
			 * 		"Symbol",	"OrderType",	"Quantity",	"Price",	"BasicWinNum", "Time", "PnL"
			 * 1	ABC			Buy				100			10			1			12:00:00	-
			 * 1	CBA			Sell			100			10			1			12:00:00	-  
			 */			
			if(retVal == null) {
				log.error("retVal is null");
				return false;
			}
			if(retVal.asList() == null) {
				log.error("retVal.asList is null");
				return false;
			}
			if(retVal.asList().at(0) == null) {
				log.error("retVal.asList.at(0) is null");
				return false;
			}
			else {
				log.info("retVal.asList()[0] = " + retVal.asList().at(0));
				log.info(retVal.asList().at(0).asString());
			}				
			
			RList orderList = retVal.asList();
			log.info("order list size = " + orderList.size());
			if(orderList != null && orderList.size() > 0 ) {
				String[] symbolColVal = orderList.at(0).asStrings();
				String[] sideColVal = orderList.at(1).asStrings();
				double[] qtyColVal = orderList.at(2).asDoubles();	//qty will be rounded into a round lot
				double[] priceColVal = orderList.at(3).asDoubles(); //TODO: use mid-px at this point to place order

				log.info("model returned order "+symbolColVal[0]+"|"+sideColVal[0]+"|"+(int)qtyColVal[0]+"|"+priceColVal[0]);
				addOrder(symbolColVal[0], 
						 sideColVal[0], 
						 (int)qtyColVal[0],
						 priceColVal[0]);
			}	
			
		} catch (RserveException e) {
			e.printStackTrace();
			System.exit(-4);
		} catch (REngineException e) {
			e.printStackTrace();
			log.error("Calling process_bw_ticks() ran into error, bwNum="+bwNum+", exiting...");
			System.exit(-4);
		} catch (REXPMismatchException e) {
			e.printStackTrace();
			System.exit(-4);
		} catch (Exception e) {
			e.printStackTrace();
			System.exit(-4);
		}
		
		return true;
	}
}
