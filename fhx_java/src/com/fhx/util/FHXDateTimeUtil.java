package com.fhx.util;

import java.math.BigDecimal;
import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.GregorianCalendar;



public class FHXDateTimeUtil {
	
	public static String _FORMAT_yyyyMMdd = "yyyyMMdd";
	public static String _FORMAT_datetime01 = "yyyy-M-d k:m:s"; //"2011-6-3 9:30:00"
	public static String _FORMAT_timeonly01 = "kk:mm:ss:SSS";
	
	public static long milSecsOfDay =  86400000;
	
	/**
	 *   returns all calendar dates in yyyymmdd format.  Inclusive of startDate and endDate.
	 * @param startDt start date in yyyymmdd
	 * @param endDt	end date in yyyymmdd
	 * @return
	 * @throws ParseException 
	 */
	public static String[] getDatesInBetween (String startDt, String endDt) throws ParseException {
		return getDatesInBetween(startDt, endDt, _FORMAT_yyyyMMdd);
	}
	
	
	/**
	 *     returns all calendar dates in format specified by formatType.  Inclusive of startDate and endDate.
	 * @param startDt start date in format specified by formatType
	 * @param endDt end date in format specified by formatType
	 * @param formatType 
	 * @return
	 * @throws ParseException
	 */
	public static String[] getDatesInBetween (String startDt, String endDt, String formatType) throws ParseException {
		String[] outDts = null;
		Calendar stCal = convertString2Cal(startDt, formatType);
		Calendar endCal = convertString2Cal(endDt, formatType);
		endCal.add(Calendar.DAY_OF_MONTH, 1); // end day is inclusive.  add one day to use .before();
		
		long milsBtw = endCal.getTimeInMillis() - stCal.getTimeInMillis();
		
		String testStart = FHXDateTimeUtil.convertCal2String(stCal, formatType);
		String endStart = FHXDateTimeUtil.convertCal2String(endCal, formatType);
		
		double daysBtwD =   milsBtw / milSecsOfDay;
		int daysBtw = (int)Math.round(daysBtwD);
		daysBtw = (daysBtw < daysBtwD )? daysBtw + 1 : daysBtw; 

		System.out.println("Start to End Time: " + testStart + "/"+ stCal.getTimeInMillis() + ", TO: " + endStart + "/" + endCal.getTimeInMillis() + ", Days in between: " + daysBtw);
		
		if (daysBtw > 0) {
			Calendar cntr = Calendar.getInstance();
			cntr.setTime(stCal.getTime());
			
			outDts = new String[daysBtw];
			int i = 0;
			do {
				outDts[i] = convertCal2String(cntr, formatType);
				i++;
				cntr.add(Calendar.DATE, 1);
			}
			while (cntr.before(endCal));
		}
		
		return outDts ;
		
	}
	
	/**
	 * 
	 * @param intime with yyyy-MM-dd HH:mm:ss format
	 * @return return time in Seconds since UTC Epoch
	 * @throws ParseException
	 */
	public static long convertString2Long (String intime) throws ParseException {
		Calendar inTimeCal = convertString2Cal(intime, _FORMAT_datetime01);
		return inTimeCal.getTimeInMillis() ;
	}

	/**
	 *   same as convertString2Long with exceptions handled internally.  if exception of parsing, 
	 *   return 0
	 * @param intime
	 * @return
	 */
	public static long convertString2LongNE (String intime) {
		long rt = 0;
		try {
			rt = convertString2Long ( intime);
		} catch (ParseException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		
		return rt;
	}
	
	public static String convertLong2DateTime01 (long indate) {
		Calendar cal = GregorianCalendar.getInstance();
		cal.setTimeInMillis(indate);
		
		return convertCal2String(cal, _FORMAT_datetime01);
	}
	
	public static Calendar convertString2Cal (String date, String formatType) throws ParseException {
		Calendar outCal = Calendar.getInstance();
		DateFormat df = new SimpleDateFormat (formatType);
		outCal.setTime( df.parse(date) );
		return outCal;
	}
	
	public static String convertCal2TimeOnly (Calendar cal) {
		return convertCal2String(cal, _FORMAT_timeonly01);
	}
	
	public static String convertCal2String (Calendar cal, String formatType) {
		DateFormat df = new SimpleDateFormat (formatType);
		return df.format(cal.getTime());
	}
	
	public static void main (String[] argvs) {
		try {
			/*
			String[] days = getDatesInBetween("20110225", "20110225");
			for (String day : days){
				System.out.println (day);	
			}
			*/
			//long outTime = convertString2Long("2011-6-3 16:0:00");
			
			System.out.println( " out date is: " + convertCal2TimeOnly(Calendar.getInstance()));
			
		} catch (Exception e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		
		
    	BigDecimal size = new BigDecimal(100);
    	BigDecimal pHigh = new BigDecimal(100);
    	BigDecimal pLow = new BigDecimal(1);
    	BigDecimal pOpen = new BigDecimal(70);
    	BigDecimal pClose = new BigDecimal(150);
    	String exchange = "NYSE";
    	
    	
	BigDecimal price1 = pClose.add(pHigh.add(pLow).divide(BigDecimal.valueOf(2)));
    BigDecimal price2 = pClose.subtract(pHigh.add(pLow).divide(BigDecimal.valueOf(2)));

    System.out.println(price1.toString() + "   " + price2.toString());
		
		
	}
}
