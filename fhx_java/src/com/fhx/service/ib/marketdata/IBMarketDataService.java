package com.fhx.service.ib.marketdata;

import java.util.Date;
import java.util.Hashtable;
import java.util.Map.Entry;
import java.util.concurrent.atomic.AtomicInteger;

import org.apache.log4j.Logger;

import com.ib.client.Contract;

public class IBMarketDataService extends IBMarketDataEventListener {

	private static final long serialVersionUID = -4704799803078842628L;

	private static Logger logger = Logger.getLogger(IBMarketDataService.class.getName());
	
	private static IBClient client;
	private static boolean simulation = Boolean.parseBoolean(System.getProperty("simulation"));
	//private static String genericTickList = System.getProperty("ib.genericTickList");
	private static String genericTickList = "100";
	
	private Hashtable<Integer, String> requestSymbols=new Hashtable<Integer, String>();
	private AtomicInteger reqId = new AtomicInteger();
	
	final private static String[] SYMBOLS = {"DIA","SPY","QQQ","IWM","MMM","AA","AXP","T","BAC","BA",
		"CAT","CVX","CSCO","KO","DD","XOM","GE","HPQ","HD","INTC",
		"IBM","JNJ","JPM","KFT","MCD","MRK","MSFT","PFE","PG","TRV",
		"UTX","VZ","WMT","DIS","GS","C"};
	
	private static AtomicInteger count = new AtomicInteger();

	public void handleInit() {

//		if (!simulation) {
//			client = IBClient.getDefaultInstance();
//		}
		
		client = IBClient.getDefaultInstance();
		client.getIbAdapter().setRequestSymbols(requestSymbols);
	}

	protected void handleInitWatchlist() {

		if ((client.getIbAdapter().getState().equals(ConnectionState.READY) || client.getIbAdapter().getState().equals(ConnectionState.SUBSCRIBED))
				//&& !client.getIbAdapter().isRequested() && !simulation) {
				&& !client.getIbAdapter().isRequested() ) {

			client.getIbAdapter().setRequested(true);
			client.getIbAdapter().setState(ConnectionState.SUBSCRIBED);

		}
	}

	protected void handlePutOnExternalWatchlist(String symbol) throws Exception {

//		if (!client.getIbAdapter().getState().equals(ConnectionState.READY) && !client.getIbAdapter().getState().equals(ConnectionState.SUBSCRIBED)) {
//			throw new Exception("IB is not ready for market data subscription.");
//		}

		// create the SubscribeTickEvent (must happen before reqMktData so that Esper is ready to receive marketdata)
//		if (!requestSymbols.containsKey(symbol)) {
			int tickerId = reqId.getAndIncrement();
			Contract contract = getContractFromSymbol(symbol);
			//Contract contract = getFXContractFromSymbol(symbol);

			requestSymbols.put(tickerId,symbol);  // so IB callback to map tickerId to symbol
			
			// try historical data files yyyymmdd hh:mm:ss tmz
	        //ibManager.requestMarketData(inData.getMessage(), "100", false);
			//clientSocket.reqHistoricalData(tickerId, contract, "20111206 16:00:00", "1 D", "1 min", "TRADES", 1, 1);
			//clientSocket.reqHistoricalData(tickerId, contract, "20111206 16:00:00", "7200 S", "5 secs", "TRADES", 1, 1); // good
			//clientSocket.reqHistoricalData(tickerId, contract, "20111209 16:00:00", "1800 S", "1 secs", "TRADES", 1, 1); // good
			//clientSocket.reqHistoricalData(tickerId, contract, "20111205 16:00:00", "3600 S", "1 sec", "BID", 1, 1);

			// requestMarketData from IB
			//this.client.reqMktData(tickerId, contract, genericTickList, false);
			this.client.reqHistoricalData(tickerId, contract, "20120103 16:00:00", "1 D", "1 min", "TRADES", 1, 1);
			
			System.out.println("request " + tickerId + " for : " + symbol);
//		}
//		else {
//			System.out.println("already subscribe for : " + symbol);
//		}
		
	}

	protected void handleRemoveFromExternalWatchlist(String symbol) throws Exception {

//		if (!client.getIbAdapter().getState().equals(ConnectionState.SUBSCRIBED)) {
//			throw new Exception("IB ist not subscribed, security cannot be unsubscribed " + symbol);
//		}

		if (requestSymbols.containsValue(symbol)) {
			for (Entry<Integer, String> entry : requestSymbols.entrySet()) {
				if (entry.getValue().equals(symbol)) {
					client.cancelMktData(entry.getKey());
					logger.debug("cancelled market data for : " + symbol);
					
					// reduce requestId? 
					//reqId.decrementAndGet();
				}
			}
		} else {
			//throw new Exception("symbol " + symbol + " was not found on subscribed list.");
			logger.debug("cancelled market data for : " + symbol);
        }
	}

	private Contract getContractFromSymbol(String symbol) {
		Contract contract=new Contract();
		contract.m_secType="STK";
		contract.m_exchange="SMART";
		contract.m_currency="USD";
		contract.m_symbol=symbol;
		return contract;
	}

	private Contract getFXContractFromSymbol(String symbol) {
		Contract contract=new Contract();
		contract.m_secType="CASH";
		contract.m_exchange="IDEALPRO";
		contract.m_currency="USD";
		contract.m_symbol=symbol;
		return contract;
	}
	
	public void destroy() throws Exception {

		if (client != null && client.isConnected()) {
			client.disconnect();
		}
	}
	
	
	public static void main(String[] args) {
		
		String reqStr = System.getProperty("reqInterval", "5");
		int reqInterval = Integer.parseInt(reqStr);
		
		final IBMarketDataService mds = new IBMarketDataService();
		
		try {
			mds.handleInit();
			Thread.sleep(10*1000);
			mds.handleInitWatchlist();

			while (true) {
				int index = count.getAndIncrement()%SYMBOLS.length;
				String symbol = SYMBOLS[index];
				System.out.format("XXXX requesting reqHistoricalData...symbol: %s, %s \n", symbol, new Date());
				
				mds.handlePutOnExternalWatchlist(symbol);
				//mds.handlePutOnExternalWatchlist("EUR");
				Thread.sleep(reqInterval*1000);
				
				// do a cancel as IB only allows up to 50 simultaneous historical requests 
				mds.handleRemoveFromExternalWatchlist(symbol);
			}
			
//			ScheduledThreadPoolExecutor stpe = new ScheduledThreadPoolExecutor(1);
//			stpe.scheduleAtFixedRate(new Runnable() {
//				@Override
//				public void run() {
//					try {
//						int index = count.getAndIncrement()%SYMBOLS.length;
//						String symbol = SYMBOLS[index];
//						System.out.format("XXXX requesting reqHistoricalData...symbol: %s, %s \n", symbol, new Date());
//						mds.handlePutOnExternalWatchlist(symbol);
//						//mds.handlePutOnExternalWatchlist("EUR");
//					}
//					catch(Exception e) {
//						e.printStackTrace();
//					}					
//				}		
//				
//			}, 0, 1, TimeUnit.MINUTES);
			
		}
		catch(Exception e) {
			e.printStackTrace();
		}
		finally {
			try {
				mds.destroy();
			}
			catch(Exception e) {
				e.printStackTrace();
			}
		}
		
	}
	
	@Override
	public void onIBEvent(IBEventData event) {
		// TODO Auto-generated method stub
		System.out.println("XXXXXXXXXXXXXXXXXXXXXXXX IBMarketDataService->onIBEvent=" + event);
	}
}
