package com.fhx.service.ib.marketdata;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;

import org.marketcetera.trade.*;

import com.ib.client.Contract;

public class IBUtil {

	private static SimpleDateFormat dayFormat = new SimpleDateFormat("yyyyMMdd");
	private static SimpleDateFormat monthFormat = new SimpleDateFormat("yyyyMM");
	private static SimpleDateFormat executionFormat = new SimpleDateFormat("yyyyMMdd  HH:mm:ss");

	public static Contract getContract(String symbol) {

		Contract contract=new Contract();
		contract.m_secType="STK";
		contract.m_exchange="SMART";
		contract.m_currency="USD";
		contract.m_symbol=symbol;
		
		return contract;
	}

	public static String getIBOrderType(OrderSingle order) {

		if (order.getOrderType().equals(OrderType.Market)) {
			return "MKT";
		}
		else if (order.getOrderType().equals(OrderType.Limit)) {
			return "LMT";
		} else if (order.getOrderType().equals(OrderType.Unknown)) {
			return "Unknown";
		}
		else 
			return "";

	}

	public static Date getExecutionDateTime(String input) throws ParseException {

		return executionFormat.parse(input);
	}

	public static Date getLastDateTime(String input) {

		return new Date(Long.parseLong(input + "000"));
	}
}
