package com.fhx.service.ib.marketdata;

import java.util.concurrent.atomic.AtomicInteger;

public final class RequestIDGenerator {

	private static RequestIDGenerator singleton;
	private AtomicInteger requestId = new AtomicInteger(1);
	private AtomicInteger orderId = new AtomicInteger(1);

	private RequestIDGenerator() {
		super();
	}

	public static synchronized RequestIDGenerator singleton() {

		if (singleton == null) {
			singleton = new RequestIDGenerator();
		}
		return singleton;
	}

	public int getNextOrderId() {
		return this.orderId.getAndIncrement();
	}

	public int getNextRequestId() {
		return this.requestId.getAndIncrement();
	}

	public void initializeOrderId(int orderId) {
		this.orderId.getAndSet(orderId);
	}

	public boolean isOrderIdInitialized() {

		return this.orderId.get() != -1;
	}
}
