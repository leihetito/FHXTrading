package com.fhx.strategy.java;

import static org.apache.commons.csv.CSVStrategy.EXCEL_STRATEGY;

import java.io.File;
import java.io.FileReader;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ConcurrentHashMap;

import org.apache.commons.csv.CSVParser;
import org.marketcetera.trade.Order;

public class Test {

	// test git commit 
	
	// test 2
	// pair model properties
	private Map<String, IModel> pairModelParms = new ConcurrentHashMap<String, IModel>();
	// order list
	private Map<String, List<Order>> pairOrderMap = new ConcurrentHashMap<String, List<Order>>();
	private String dataDir = "C:/Users/Mandy/data/csv";
	private static final String EXTENSION = ".csv";
	

	public Test(String args[]) {
		try {
			CSVParser parser = new CSVParser(new FileReader(new File(dataDir,
					"hfx_pair_parms_20110518" + EXTENSION)), EXCEL_STRATEGY);
			String[][] all = parser.getAllValues();

			// traverse through it
			System.out.println("Header	:	" + Arrays.toString(all[0]));
			System.out.println("Row1:		" + Arrays.toString(all[1]));
			System.out.println("Column:	" + all[0].length);
			System.out.println("Row:			" + all.length);

			/*
			 * Header:[, Pair, Industry, ADF.pvalue, ts.start, ts.end, lamda,
			 * mu, sigma, beta] Row1:[1, ACE/AIG, xlf, 0.0429359714074579,
			 * 2011-05-18 09:59:00, 2011-05-18 15:30:00, 11.3516734065991,
			 * 0.0194240685055339, 0.979161110768504, 2.24997403759064]
			 * Column:10 Row:3768
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
															// all[0] contains
															// header
						// System.out.println("key=" + all[0][j] + ",value=" +
						// row[j]);
						p.put(header[j], row[j]);
					}

					IModel pmodel = new PairModel(pair, p);
					pairModelParms.put(pair, pmodel);
				}
			}

			int cnt = 0;
			for (Map.Entry<String, IModel> entry : pairModelParms.entrySet()) {
				System.out.println((cnt++) + "|" + entry.getKey() + ","
						+ entry.getValue().getProperties().toString());
			}

			System.out.println("XXX model properties: "
					+ pairModelParms.keySet().size());
			System.out.println("111 model properties: "
					+ pairModelParms.get("CAG/GIS").getProperties());
			System.out.println("444"
					+ Arrays.toString(pairModelParms.get("CAG/GIS")
							.getPropertyNames()));

			// 3. now, for each market tick, get the pair Model parameter. HOW
			// TO FIND ALL THE PAIRS FOR THIS SYMBOL QUICKLY??
			String pair = "VZ/T";
			// compute the (zscore: tickSpread - mu)/sigma
			List<Order> hasOrders = pairModelParms.get(pair).getOrders();
			if (hasOrders.size() == 0) {
				// entry
				// if zscore > 2, SELL spread: short p[0], buy p[1]
				// if zscore < 2, Buy spread: buy p[0], short p[1]
			} else {
				// update Position

				// exit

			}

		} catch (Exception e) {
			e.fillInStackTrace();
		} finally {
			// close file
		}
	}

	public static Calendar cal = Calendar.getInstance();
	/**
	 * @param args
	 */
	public static void main(String[] args) {
		// TODO Auto-generated method stub
		//new Test(args);
		
		//PairStrategy pair = new PairStrategy();
		//pair.onStart();
		
	    int hh = cal.get(Calendar.HOUR_OF_DAY);
	    int mm = cal.get(Calendar.MINUTE);
	    int ss = cal.get(Calendar.SECOND);
	    System.out.format(" hh: %d, mm: %d, ss %d \n", hh, mm, ss);	
	    
		try {
			Thread.sleep(5000);

			hh = cal.get(Calendar.HOUR_OF_DAY);
		    mm = cal.get(Calendar.MINUTE);
		    ss = cal.get(Calendar.SECOND);
		    System.out.format("xxxx hh: %d, mm: %d, ss %d \n", hh, mm, ss);		
		    
		    Thread.sleep(6000);
		    
		    cal = Calendar.getInstance();
		    
			hh = cal.get(Calendar.HOUR_OF_DAY);
		    mm = cal.get(Calendar.MINUTE);
		    ss = cal.get(Calendar.SECOND);
		    System.out.format("xxxx hh: %d, mm: %d, ss %d \n", hh, mm, ss);	
		}
		catch(Exception e) {
			e.printStackTrace();
		}
	}

}
