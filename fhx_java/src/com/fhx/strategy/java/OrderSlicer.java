package com.fhx.strategy.java;

import org.marketcetera.event.TradeEvent;
import org.marketcetera.strategy.java.Strategy;
import org.marketcetera.trade.*;

//import org.marketcetera.quickfix.FIXDataDictionary;
//import org.marketcetera.quickfix.FIXMessageFactory;
//import org.marketcetera.quickfix.FIXMessageUtil;
//import org.marketcetera.quickfix.FIXVersion;
//import org.marketcetera.quickfix.messagefactory.FIXMessageAugmentor;

import java.util.Random;
import java.util.List;
import java.util.ArrayList;
import java.util.Collections;
import java.util.concurrent.atomic.AtomicInteger;
import java.security.SecureRandom;
import java.math.BigDecimal;

/* $License$ */
/**
 * Given parameters indicating symbol and size, slices the total size into
 * smaller chunks and sends market orders off at random times.
 * 
 * @author anshul@marketcetera.com
 * @version $Id$
 * @since $Release$
 */
public class OrderSlicer extends Strategy {
	/**
	 * Executed when the strategy is started. Use this method to set up data
	 * flows and other initialization tasks.
	 */
	@Override
	public void onStart() {
		String symbol = getParameter("symbol");
		String qty = getParameter("quantity");
		// String symbol = "IBM";
		// String qty = "10000";

		if (symbol == null || qty == null) {
			String msg = "Please specify the 'symbol' and/or 'quantity' parameters (right-click on registered Strategy and go to Properties)";
			error(msg);
			notifyHigh("Strategy missing parameters", msg);
			// throw an exception to prevent the strategy from starting.
			throw new IllegalArgumentException(msg);
		}
		int quantity = Integer.parseInt(qty);
		info("Partioning " + quantity + " " + symbol);
		List<Integer> partition;
		// if it's more than 100 shares, do partitioning in "round lots"
		if (quantity > 100) {
			// Figure out if we have a odd lot
			int oddQty = quantity % 100;
			quantity = quantity / 100;
			partition = generatePartition(quantity, 100);
			if (oddQty > 0) {
				partition.add(oddQty);
			}
		} else {
			partition = generatePartition(quantity, 1);
		}
		mNumPartitions = partition.size();
		// Output the partitioning
		info("Partitions: " + partition.toString());
		// Generate order objects from partition sizes
		for (int size : partition) {
			OrderSingle order = Factory.getInstance().createOrderSingle();
			order.setOrderType(OrderType.Market);
			order.setQuantity(new BigDecimal(size));
			if (size % 2 == 0)
				order.setSide(Side.Buy);
			else
				order.setSide(Side.Sell);
			order.setSymbol(new MSymbol(symbol));
			order.setTimeInForce(TimeInForce.Day);
			// request a callback for each order at a random time (up to 10
			// seconds)
			requestCallbackAfter(1000 * sRandom.nextInt(10), order);
		}
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
		OrderID orderId = sendOrder((OrderSingle) inData);
		// this is seriablized so can be recovered upon failure
		info("sent order: " + orderId);
		
		int sent = mNumSent.incrementAndGet();
		info("sent order " + sent + "/" + mNumPartitions);

		System.out.println("XXXX OrderSlicer->onCallback() order=" + inData);
	}

	public void onExecutionReport(ExecutionReport inExecutionReport) {
		System.out
				.println("XXXX OrderSlicer->ExecutionReport() inExecutionReport="
						+ inExecutionReport);

		// String readablemsg = new
		// AnalyzedMessage(getDataDictionary(),inExecutionReport).toString();
		// create a FIX
		// Message readablemsg = inExecutionReport;
		// System.out.println("XXXX OrderSlicer->ExecutionReport() readablemsg="
		// + readablemsg);
	}

	/*
	 * (non-Javadoc)
	 * 
	 * @see
	 * org.marketcetera.strategy.RunningStrategy#onCancel(org.marketcetera.trade
	 * .OrderCancelReject)
	 */
	@Override
	public void onCancelReject(OrderCancelReject inCancel) {
		System.out.println("XXXX OrderSlicer->onCancelReject() inCancel="
				+ inCancel);
	}

	/*
	 * (non-Javadoc)
	 * 
	 * @see org.marketcetera.strategy.RunningStrategy#onOther(java.lang.Object)
	 */
	@Override
	public void onOther(Object inEvent) {
		System.out.println("XXXX OrderSlicer->onOther() inEvent=" + inEvent);
	}

	/*
	 * (non-Javadoc)
	 * 
	 * @see
	 * org.marketcetera.strategy.RunningStrategy#onTrade(org.marketcetera.event
	 * .TradeEvent)
	 */
	@Override
	public void onTrade(TradeEvent inTrade) {
		System.out.println("XXXX OrderSlicer->onTrade() inTrade=" + inTrade);
	}

	/**
	 * Generate random partitions of the given quantity. Multiplies each
	 * partition with the supplied multiple.
	 * 
	 * @param inQuantity
	 *            the quantity to be partitioned.
	 * @param inMultiple
	 *            the multiple to be applied to each partition.
	 * 
	 * @return the list of partitions.
	 */
	private static List<Integer> generatePartition(int inQuantity,
			int inMultiple) {
		List<Integer> list = new ArrayList<Integer>();
		// while (inQuantity > 0) {
		// int split = sRandom.nextInt(inQuantity) + 1;
		// list.add(split * inMultiple);
		// inQuantity -= split;
		// }
		// Collections.shuffle(list, sRandom);
		list.add(inQuantity); // just 1 order

		return list;
	}

	private volatile int mNumPartitions;
	private final AtomicInteger mNumSent = new AtomicInteger(0);
	private final static Random sRandom = new SecureRandom();
}
