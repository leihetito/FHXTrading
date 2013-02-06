package com.fhx.statstream;

import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.math.BigDecimal;
import java.text.DecimalFormat;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;

import org.apache.log4j.Logger;
import org.apache.log4j.PropertyConfigurator;
import org.marketcetera.marketdata.interactivebrokers.LatestMarketData;
import org.marketcetera.trade.Factory;
import org.marketcetera.trade.MSymbol;
import org.marketcetera.trade.OrderID;
import org.marketcetera.trade.OrderSingle;
import org.marketcetera.trade.OrderType;
import org.marketcetera.trade.Side;
import org.marketcetera.trade.TimeInForce;
import org.rosuda.REngine.REXP;
import org.rosuda.REngine.Rserve.RConnection;

import com.fhx.service.ib.marketdata.RequestIDGenerator;
import com.fhx.service.ib.order.IBOrderSender;
import com.fhx.util.StatStreamUtil;


public abstract class StatStreamServiceBase {

	private static Logger log = Logger.getLogger(StatStreamServiceBase.class);
	protected final Properties config = new Properties();
	
	protected int basicWindowSize = -1;
	protected List<String> symbols = new ArrayList<String>();
	
	protected static RConnection conn;  // have a global R connection handler for simplicity
	
	private static BlockingQueue<OrderSingle> orderQ = new ArrayBlockingQueue<OrderSingle>(1024);
	
	public StatStreamServiceBase() {
	}
	
	public void init() {
		PropertyConfigurator.configure("conf/log4j.properties");
		
		try {
			config.load(new FileInputStream("conf/statstream.properties"));
		} catch (FileNotFoundException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return;
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return;
		}
		
		String basicWin = config.getProperty("BASIC_WINDOW_SIZE");
		if(basicWin== null) {
			log.error("Must define basic window size");
		}
		basicWindowSize = Integer.parseInt(basicWin);
		
		symbols = StatStreamUtil.getAllSymbols(config);
		
		log.info("About to set up Rserve env");
		/*
		 * set up Rserve run environment
		 */
		setupRServe();  // establish RConnection
		setupREnvironment();  // initialize R model script
		log.info("Connected to Rserve env.  Starting IBOrder sender thread...");
		
		/*
		 * start the IB order sender consumer thread 
		 */
		new Thread(new IBOrderSender(getOrderQ())).start();
		log.info("IBOrder sender thread started...");
	}
	
	public void setupRServe() {
		
		try {
			config.load(new FileInputStream("conf/statstream.properties"));
		} catch (IOException e1) {
			log.error("Error loading config file\n");
			e1.printStackTrace();
			return;
		}
		
		// start up Rserve service if not running 
		log.info("result="+StatStreamUtil.checkLocalRserve());
		try {
			String host = config.getProperty("HOST");
			conn = new RConnection(host);
		} catch (Exception e) {
			e.printStackTrace();
			log.error("Error creating new RConnection on localhost, exiting...\n" );
			System.exit(-1);
		};
	}
	
	public void setupREnvironment() {
		String funcRFile = config.getProperty("R_MAIN_SCRIPT");
		String cmdStr = "source('"+funcRFile+"')";
		
		try {
			// source the main R file to initialize global variables referenced by R functions
			log.info("try to source R (main) file: " + cmdStr);
			conn.parseAndEval(cmdStr);
			
			// check that all global variables exists 
			REXP cmd_ls = conn.parseAndEval("ls()");
			log.info("R->ls(): "+cmd_ls.toDebugString());
			
		} catch (Exception e) {
			log.error("Failed in Rserver call: " + cmdStr);
			e.printStackTrace();
			// think about recover here, i.e. Re-intialize R session and try again.
			// recover is important as all important data are stored in R.
			
			// fail it for now.
			System.exit(-2);
		}
	}

	protected synchronized void addOrder(String symbol, String type, int qty, double price) {
		int orderNumber = RequestIDGenerator.singleton().getNextOrderId();
		//order.setNumber(orderNumber);
		OrderSingle order = Factory.getInstance().createOrderSingle();
		order.setOrderID(new OrderID(orderNumber+""));
		
		//order.setOrderType(OrderType.Limit);
		order.setOrderType(OrderType.Market);
		order.setQuantity(new BigDecimal(qty));	
		
		double pxDbl = Double.parseDouble(new DecimalFormat("#.##").format(price));
		order.setPrice(new BigDecimal(pxDbl));
		
		if (type.equalsIgnoreCase("buy"))
			order.setSide(Side.Buy);
		else if (type.equalsIgnoreCase("sell"))
			order.setSide(Side.Sell);
		else if (type.equalsIgnoreCase("shortsell"))
			order.setSide(Side.SellShort); 
			
		order.setSymbol(new MSymbol(symbol));
		order.setTimeInForce(TimeInForce.Day);

		//log.info("NewIBOrderInfo - "+order.getSide()+" "+order.getQuantity()+" "+order.getSymbol()+" @ "+order.getPrice().doubleValue());
		log.info("NewIBOrderInfo - " + order.toString());

		// turn on/off the model output if running simulation
		if (Boolean.parseBoolean(config.getProperty("SIMULATION","false"))) {
			log.info("Running in simulation mode, not sending orders to IB. ");				
			return ;
		}
		
		//Sending order to IB
		log.info("Sending order to IB - "+order.getSide()+" "+order.getQuantity()+" "+order.getSymbol()+" @ "+order.getPrice().doubleValue());
		orderQ.add(order);
	}
	
	public static BlockingQueue<OrderSingle> getOrderQ() {
		return orderQ;
	}

	public abstract boolean tick(Map<String, List<LatestMarketData>> aTick, int bwNum);
		
}
